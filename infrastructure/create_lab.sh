#!/usr/bin/env bash
# create_lab.sh - Crée un lab docker Wazuh (manager, indexer, dashboard, dvwa, mariadb, attacker)
# Version corrigée : réseau proxy créé au bon endroit, nettoyage safe, messages clairs.
set -euo pipefail

# ----- Helpers (affichage coloré & utilitaires) -----
_red()   { printf "\033[1;31m%s\033[0m\n" "$*"; }
_green() { printf "\033[1;32m%s\033[0m\n" "$*"; }
_yellow(){ printf "\033[1;33m%s\033[0m\n" "$*"; }
_blue()  { printf "\033[1;34m%s\033[0m\n" "$*"; }

log_info()  { _blue "[INFO]  $*"; }
log_ok()    { _green "[OK]    $*"; }
log_warn()  { _yellow "[WARN]  $*"; }
log_error() { _red "[ERROR] $*"; }

# ----- CONFIG -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose-template.yml"
ENV_DIR="$SCRIPT_DIR/envs"
DATA_DIR="$SCRIPT_DIR/data"
NGINX_CONF_DIR="$SCRIPT_DIR/nginx/conf.d"
PROXY_CONTAINER="nginx_reverse_proxy"
PROJECT_NAME=$(basename "$SCRIPT_DIR")
PROXY_COMPOSE_FILE="$SCRIPT_DIR/nginx-proxy.yml"

# ----- ARG CHECK -----
if [ $# -ne 1 ]; then
    log_error "Usage: $0 <lab_name> (ex: lab1)"
    exit 1
fi
LAB_NAME="$1"

# ----- PATHS & FILES -----
ENV_FILE="${ENV_DIR}/${LAB_NAME}.env"
NGINX_FILE="${NGINX_CONF_DIR}/${LAB_NAME}.conf"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose-${LAB_NAME}.yml"

# ----- PREPARE DIRECTORIES -----
log_info "Création des dossiers nécessaires..."
mkdir -p "$ENV_DIR" "$NGINX_CONF_DIR" \
         "$DATA_DIR/${LAB_NAME}/wazuh_manager" \
         "$DATA_DIR/${LAB_NAME}/wazuh_indexer"
log_ok "Dossiers prêts : $ENV_DIR, $NGINX_CONF_DIR, $DATA_DIR/${LAB_NAME}/..."

# ----- PORTS & SUBNET (doit être connu avant création réseau) -----
LAB_NUM=$(echo "$LAB_NAME" | grep -o '[0-9]*$' || echo "1")
BASE_1514=1500
BASE_1515=1510
BASE_55000=55000
BASE_5601=5600
BASE_SUBNET=30 # 172.30.X.0/24

PORT_1514=$((BASE_1514 + LAB_NUM))
PORT_1515=$((BASE_1515 + LAB_NUM))
PORT_55000=$((BASE_55000 + LAB_NUM))
PORT_5601=$((BASE_5601 + LAB_NUM))
LAB_SUBNET="172.${BASE_SUBNET}.${LAB_NUM}.0/24"

# Nom du réseau lab (utilisé pour le proxy aussi)
FULL_NET_NAME="${PROJECT_NAME}_${LAB_NAME}_net"

# ----- ASSURE LE RÉSEAU EXTERNE POUR LE PROXY (création si manquant) -----
# IMPORTANT : on crée le réseau *avant* le déploiement mais *on ne le supprime pas*
# dans la phase de nettoyage qui suit (pour éviter le bug où on recrée puis supprime).
if ! docker network inspect "$FULL_NET_NAME" >/dev/null 2>&1; then
  log_info "Réseau $FULL_NET_NAME absent → création (subnet=$LAB_SUBNET)..."
  if docker network create --driver bridge --subnet "$LAB_SUBNET" "$FULL_NET_NAME" >/dev/null 2>&1; then
    log_ok "Réseau $FULL_NET_NAME créé avec subnet $LAB_SUBNET"
  else
    log_warn "Création du réseau avec subnet $LAB_SUBNET échouée. Création sans subnet..."
    docker network create --driver bridge "$FULL_NET_NAME" >/dev/null 2>&1 || {
      log_error "Impossible de créer le réseau $FULL_NET_NAME"
      exit 1
    }
    log_ok "Réseau $FULL_NET_NAME créé (sans subnet explicit)."
  fi
else
  log_ok "Réseau $FULL_NET_NAME déjà présent"
fi

# ----- ENSURE PROXY IS RUNNING -----
log_info "Vérification du conteneur proxy $PROXY_CONTAINER..."
if ! docker ps -a --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}\$"; then
    log_warn "Proxy absent → démarrage via $PROXY_COMPOSE_FILE"
    if [ -f "$PROXY_COMPOSE_FILE" ]; then
        docker compose -f "$PROXY_COMPOSE_FILE" up -d
        log_ok "Proxy lancé depuis $PROXY_COMPOSE_FILE"
    else
        log_error "Fichier proxy introuvable : $PROXY_COMPOSE_FILE. Abandon."
        exit 1
    fi
else
    if ! docker inspect -f '{{.State.Running}}' $PROXY_CONTAINER 2>/dev/null | grep -q true; then
        log_warn "Proxy présent mais arrêté → démarrage"
        docker start $PROXY_CONTAINER
        log_ok "Proxy démarré"
    else
        log_ok "Proxy déjà en cours d'exécution"
    fi
fi

# ----- CLEAN OLD RESOURCES FOR THIS LAB -----
log_info "Nettoyage des anciens conteneurs/volumes pour ${LAB_NAME} (réseau conservé)..."

old_containers=$(docker ps -a --format '{{.Names}}' | grep "^${LAB_NAME}_" || true)
if [ -z "$old_containers" ]; then
    log_info "Aucun conteneur ${LAB_NAME}_* trouvé."
else
    log_warn "Conteneurs trouvés -> $old_containers"
    for cname in $old_containers; do
        log_info "Suppression du conteneur $cname ..."
        docker rm -f "$cname" >/dev/null 2>&1 || log_warn "Impossible de supprimer $cname (ignoring)."
        log_ok "Conteneur $cname supprimé"
    done
fi

# NOTE: on NE SUPPRIME PAS le réseau FULL_NET_NAME ici (évite le bug).
# Par contre si tu veux forcer la suppression, ajoute un flag ou supprime manuellement.

old_volumes=$(docker volume ls --format '{{.Name}}' | grep "^${LAB_NAME}_" || true)
if [ -n "$old_volumes" ]; then
    log_warn "Volumes Docker liés au lab trouvés :"
    for vname in $old_volumes; do
        log_info "Suppression du volume $vname ..."
        docker volume rm "$vname" >/dev/null 2>&1 || log_warn "Impossible de supprimer volume $vname (ignoring)."
        log_ok "Volume $vname supprimé"
    done
else
    log_info "Aucun volume Docker lié au lab trouvé."
fi

log_ok "Nettoyage terminé pour ${LAB_NAME} (réseau conservé : $FULL_NET_NAME)"

# ----- CREATE .env -----
if [ -f "$ENV_FILE" ]; then
    log_warn "Le fichier $ENV_FILE existe déjà. On ne l'écrase pas."
else
    cat > "$ENV_FILE" <<EOF
LAB_NAME=${LAB_NAME}
LAB_SUBNET=${LAB_SUBNET}
WAZUH_PORT_1514=${PORT_1514}
WAZUH_PORT_1515=${PORT_1515}
WAZUH_PORT_55000=${PORT_55000}
WAZUH_PORT_5601=${PORT_5601}
EOF
    log_ok "Fichier .env généré : $ENV_FILE"
fi

# ----- GENERATE COMPOSE FILE -----
log_info "Génération du docker-compose spécifique pour ${LAB_NAME}..."
export LAB_NAME LAB_SUBNET WAZUH_PORT_1514 WAZUH_PORT_1515 WAZUH_PORT_55000 WAZUH_PORT_5601
if [ ! -f "$COMPOSE_TEMPLATE" ]; then
    log_error "Template $COMPOSE_TEMPLATE introuvable. Abandon."
    exit 1
fi
envsubst < "$COMPOSE_TEMPLATE" > "$COMPOSE_FILE"
log_ok "Fichier généré : $COMPOSE_FILE"

# ----- DEPLOY LAB -----
log_info "Déploiement du lab ${LAB_NAME} (docker compose up -d)..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
log_ok "Services démarrés (si tout s'est bien passé)."

# ----- CONNECT PROXY TO LAB NETWORK -----
log_info "Connexion du proxy $PROXY_CONTAINER au réseau ${FULL_NET_NAME}..."
# docker network connect échoue si déjà connecté -> on ignore l'erreur
if docker network connect "${FULL_NET_NAME}" $PROXY_CONTAINER 2>/dev/null; then
    log_ok "Proxy connecté au réseau ${FULL_NET_NAME}"
else
    log_info "Proxy déjà connecté au réseau ou connexion non nécessaire."
fi

# ----- ENSURE DEFAULT.CONF EXISTS (NGINX) -----
DEFAULT_CONF="$NGINX_CONF_DIR/default.conf"
if [ ! -f "$DEFAULT_CONF" ]; then
    log_info "Création d'un default.conf Nginx minimal : $DEFAULT_CONF"
    cat > "$DEFAULT_CONF" <<EOF
server {
    listen 80 default_server;
    server_name _;
    return 404;
}
EOF
    log_ok "default.conf créé"
else
    log_info "default.conf Nginx déjà présent"
fi

# ----- NGINX CONF FOR THIS LAB -----
log_info "Génération de la conf Nginx pour le lab ($NGINX_FILE)..."
cat > "$NGINX_FILE" <<'EOF'

server {
    server_name dvwa.${LAB_NAME}.local;

    resolver 127.0.0.11 valid=30s;

    location / {
        proxy_pass http://${LAB_NAME}_dvwa:80/;
        proxy_set_header Host localhost;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    listen 80;
    server_name wazuh.${LAB_NAME}.local;

    resolver 127.0.0.11 valid=30s;

    location / {
        proxy_pass https://${LAB_NAME}_wazuh_dashboard:5601;
        proxy_ssl_verify off;         # certificat auto-signé ignoré
        proxy_set_header Host localhost;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

EOF
log_ok "Config Nginx générée : $NGINX_FILE"

# ----- RELOAD NGINX -----
log_info "Reload de Nginx dans le conteneur $PROXY_CONTAINER..."
if docker inspect -f '{{.State.Running}}' $PROXY_CONTAINER 2>/dev/null | grep -q true; then
    if docker exec -i $PROXY_CONTAINER nginx -t >/dev/null 2>&1; then
        docker exec -i $PROXY_CONTAINER nginx -s reload
        log_ok "Nginx rechargé avec succès dans $PROXY_CONTAINER"
    else
        log_error "Erreur de configuration Nginx (nginx -t a échoué). Reload annulé."
    fi
else
    log_warn "Impossible de recharger Nginx : conteneur $PROXY_CONTAINER non démarré"
fi

# ----- SUMMARY -----
log_ok "Lab ${LAB_NAME} déployé avec succès !"
echo
printf "    %-12s : %s\n" "Accès DVWA" "http://dvwa.${LAB_NAME}.local"
printf "    %-12s : %s\n" "Accès Wazuh" "http://wazuh.${LAB_NAME}.local"
printf "    %-12s : %s\n" "Réseau" "$FULL_NET_NAME ($LAB_SUBNET)"
printf "    %-12s : %s\n" "Compose file" "$COMPOSE_FILE"
echo
log_info "Conseils :"
echo " - Si tu veux forcer un nettoyage complet (network inclus), supprime manuellement le réseau :"
echo "     docker network rm $FULL_NET_NAME"
echo " - Pour voir les logs des services : docker compose -f $COMPOSE_FILE logs -f"
echo " - Si le proxy ne sert pas les noms *.local, vérifie /etc/hosts ou ton DNS local."

exit 0
