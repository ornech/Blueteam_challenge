#!/usr/bin/env bash
set -euo pipefail
# create_lab.sh - version améliorée : logs, création réseau robuste, compatibilité compose

# -------- Logging utils (couleurs, niveaux) --------
CSI='\033['
RESET="${CSI}0m"
BOLD="${CSI}1m"
GREEN="${CSI}32m"
YELLOW="${CSI}33m"
RED="${CSI}31m"
BLUE="${CSI}34m"

log_info(){ echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_ok(){   echo -e "${GREEN}[ OK ]${RESET}  $*"; }
log_warn(){ echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error(){ echo -e "${RED}[ERR ]${RESET}  $*" >&2; }

# -------- Setup paths & defaults --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose-template.yml"
ENV_DIR="$SCRIPT_DIR/envs"
DATA_DIR="$SCRIPT_DIR/data"
NGINX_CONF_DIR="$SCRIPT_DIR/nginx/conf.d"
PROXY_CONTAINER="nginx_reverse_proxy"
PROXY_COMPOSE_FILE="$SCRIPT_DIR/nginx-proxy.yml"
COMPOSE_FILE_TEMPLATE="$SCRIPT_DIR/docker-compose-{{LAB}}.yml"  # placeholder for info only

# Allow override of the compose project name if desired (avoid unwanted prefixes).
# By default we keep the folder name (e.g., "infrastructure") to preserve legacy behaviour,
# but you can export COMPOSE_PROJECT_NAME before calling the script to change it.

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-blueteam}"
# --- ARG CHECK ---
if [ $# -ne 1 ]; then
    echo "Usage: $0 <lab_name> (ex: lab1)"
    exit 1
fi

LAB_NAME="$1"
ENV_FILE="${ENV_DIR}/${LAB_NAME}.env"
NGINX_FILE="${NGINX_CONF_DIR}/${LAB_NAME}.conf"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose-${LAB_NAME}.yml"

# --- Create required directories ---
log_info "Création des dossiers nécessaires..."
mkdir -p "$ENV_DIR" "$NGINX_CONF_DIR" \
         "$DATA_DIR/${LAB_NAME}/wazuh_manager" \
         "$DATA_DIR/${LAB_NAME}/wazuh_indexer"
log_ok "Dossiers prêts : ${ENV_DIR}, ${NGINX_CONF_DIR}, ${DATA_DIR}/${LAB_NAME}/..."

# --- Compute network name & subnet (consistent with compose template) ---
LAB_NUM=$(echo "$LAB_NAME" | grep -o '[0-9]*$' || echo "1")
BASE_SUBNET=30
LAB_SUBNET="172.${BASE_SUBNET}.${LAB_NUM}.0/24"

# Compose will create a network named: <project>_<network_key>
# Our compose network key in template is "${LAB_NAME}_net", so expected network name:
FULL_NET_NAME="${COMPOSE_PROJECT_NAME}_${LAB_NAME}_net"
EXPECTED_COMPOSE_NETWORK_LABEL="${LAB_NAME}_net"

log_info "Réseau attendu pour le lab : ${FULL_NET_NAME} (subnet=${LAB_SUBNET})."

# ----- ASSURE LE RÉSEAU EXTERNE POUR LE PROXY (création si manquant) -----
if ! docker network inspect "$FULL_NET_NAME" >/dev/null 2>&1; then
  log_info "Réseau $FULL_NET_NAME absent → tentative de création (subnet=$LAB_SUBNET)..."
  if docker network create \
      --driver bridge \
      --subnet "$LAB_SUBNET" \
      --label "com.docker.compose.project=${COMPOSE_PROJECT_NAME}" \
      --label "com.docker.compose.network=${EXPECTED_COMPOSE_NETWORK_LABEL}" \
      "$FULL_NET_NAME" >/dev/null 2>&1; then
    log_ok "Réseau $FULL_NET_NAME créé avec subnet ${LAB_SUBNET} et labels Compose."
  else
    log_warn "Création du réseau avec subnet $LAB_SUBNET échouée. Tentative sans subnet..."
    if docker network create \
        --driver bridge \
        --label "com.docker.compose.project=${COMPOSE_PROJECT_NAME}" \
        --label "com.docker.compose.network=${EXPECTED_COMPOSE_NETWORK_LABEL}" \
        "$FULL_NET_NAME" >/dev/null 2>&1; then
      log_ok "Réseau $FULL_NET_NAME créé (sans subnet explicite), labels Compose appliqués."
    else
      log_error "Impossible de créer le réseau $FULL_NET_NAME. Vérifie les droits Docker."
      exit 1
    fi
  fi
else
  lbl_net=$(docker network inspect -f '{{index .Labels "com.docker.compose.network"}}' "$FULL_NET_NAME" 2>/dev/null || true)
  lbl_proj=$(docker network inspect -f '{{index .Labels "com.docker.compose.project"}}' "$FULL_NET_NAME" 2>/dev/null || true)
  if [ -z "$lbl_net" ] || [ -z "$lbl_proj" ]; then
    log_warn "Réseau $FULL_NET_NAME trouvé mais labels Compose incomplets."
    log_warn "Attendus: com.docker.compose.project=${COMPOSE_PROJECT_NAME}, com.docker.compose.network=${EXPECTED_COMPOSE_NETWORK_LABEL}"
  else
    log_ok "Réseau $FULL_NET_NAME déjà présent (labels OK)."
  fi
fi


# --- ENSURE PROXY IS RUNNING (nginx_reverse_proxy container) ---
log_info "Vérification du conteneur proxy ${PROXY_CONTAINER}..."
if ! docker ps -a --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}\$"; then
    log_warn "Proxy absent → lancement via ${PROXY_COMPOSE_FILE}"
    docker compose -f "$PROXY_COMPOSE_FILE" up -d
elif ! docker inspect -f '{{.State.Running}}' $PROXY_CONTAINER 2>/dev/null | grep -q true; then
    log_warn "Proxy présent mais arrêté → démarrage"
    docker start $PROXY_CONTAINER
else
    log_ok "Proxy déjà en cours d'exécution"
fi

# --- CLEAN OLD RESOURCES FOR THIS LAB (but keep the network) ---
log_info "Nettoyage des anciens conteneurs/volumes pour ${LAB_NAME} (le réseau ${FULL_NET_NAME} est conservé)..."

old_containers=$(docker ps -a --format '{{.Names}}' | grep "^${LAB_NAME}_" || true)
if [ -z "$old_containers" ]; then
    log_info "Aucun conteneur ${LAB_NAME}_* trouvé."
else
    log_info "Conteneurs trouvés -> ${old_containers}"
    for cname in $old_containers; do
        log_info "Suppression du conteneur $cname ..."
        docker rm -f "$cname" >/dev/null 2>&1 || log_warn "Impossible de supprimer $cname (ignorer)."
    done
fi

old_volumes=$(docker volume ls --format '{{.Name}}' | grep "^${LAB_NAME}_" || true)
if [ -z "$old_volumes" ]; then
    log_info "Aucun volume Docker lié au lab trouvé."
else
    for vname in $old_volumes; do
        log_info "Suppression du volume $vname ..."
        docker volume rm "$vname" >/dev/null 2>&1 || log_warn "Impossible de supprimer volume $vname (ignorer)."
    done
fi

log_ok "Nettoyage des anciens conteneurs/volumes terminé (réseau conservé : ${FULL_NET_NAME})"

# --- CREATE .env (if missing) ---
if [ -f "$ENV_FILE" ]; then
    log_warn "Le fichier $ENV_FILE existe déjà. On ne l'écrase pas."
else
    log_info "Génération du fichier .env pour ${LAB_NAME}..."
        cat > "$ENV_FILE" <<EOF
        COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
        LAB_NAME=${LAB_NAME}
        LAB_SUBNET=${LAB_SUBNET}
        WAZUH_PORT_1514=$((1500 + LAB_NUM))
        WAZUH_PORT_1515=$((1510 + LAB_NUM))
        WAZUH_PORT_55000=$((55000 + LAB_NUM))
        WAZUH_PORT_5601=$((5600 + LAB_NUM))
        EOF
    log_ok "Fichier .env généré : $ENV_FILE"
fi

# --- GENERATE COMPOSE FILE FROM TEMPLATE ---
if [ ! -f "$COMPOSE_TEMPLATE" ]; then
    log_error "Template docker-compose missing: $COMPOSE_TEMPLATE"
    exit 1
fi
log_info "Génération du docker-compose spécifique pour ${LAB_NAME}..."
export LAB_NAME LAB_SUBNET
envsubst < "$COMPOSE_TEMPLATE" > "$COMPOSE_FILE"
log_ok "Fichier généré : $COMPOSE_FILE"

# --- DEPLOY LAB with explicit project name for reproducibility ---
log_info "Déploiement du lab ${LAB_NAME} (docker compose with project='${COMPOSE_PROJECT_NAME}')..."
# Use --project-name to make resource names predictable; pass the env file too.
docker compose --project-name "${COMPOSE_PROJECT_NAME}" -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

# --- CONNECT PROXY TO LAB NETWORK (if not already connected) ---
log_info "Connexion du proxy ${PROXY_CONTAINER} au réseau ${FULL_NET_NAME} (si non connecté)..."
# check if proxy is connected:
if docker network inspect -f '{{range $k,$v := .Containers}}{{.Name}} {{end}}' "$FULL_NET_NAME" 2>/dev/null | grep -q "$PROXY_CONTAINER"; then
  log_ok "Proxy déjà connecté au réseau ${FULL_NET_NAME}."
else
  docker network connect "${FULL_NET_NAME}" $PROXY_CONTAINER 2>/dev/null && log_ok "Proxy connecté au réseau ${FULL_NET_NAME}." || log_warn "Impossible de connecter le proxy (déjà connecté ? privilèges ?) : tenter manuellement."
fi

# --- ENSURE DEFAULT.CONF EXISTS (nginx conf fallback) ---
DEFAULT_CONF="$NGINX_CONF_DIR/default.conf"
if [ ! -f "$DEFAULT_CONF" ]; then
    log_info "Génération d'un default.conf Nginx par défaut..."
    cat > "$DEFAULT_CONF" <<EOF
server {
    listen 80 default_server;
    server_name _;
    return 404;
}
EOF
    log_ok "default.conf généré : $DEFAULT_CONF"
fi

# --- NGINX conf pour ce lab ---
log_info "Génération de la config Nginx pour ${LAB_NAME} → $NGINX_FILE"
cat > "$NGINX_FILE" <<EOF

server {
    listen 80;
    server_name dvwa.${LAB_NAME}.local;

    # DNS Docker interne dans le conteneur nginx
    resolver 127.0.0.11 valid=30s ipv6=off;

    location / {
        proxy_pass http://${LAB_NAME}_dvwa:80;
        proxy_http_version 1.1;
        proxy_set_header Host $host;                # ⬅ corrige "localhost"
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name wazuh.${LAB_NAME}.local;

    resolver 127.0.0.11 valid=30s ipv6=off;

    location / {
        proxy_pass https://${LAB_NAME}_wazuh_dashboard:5601;
        proxy_ssl_server_name on;
        proxy_ssl_verify off;                       # self-signed dans le lab
        proxy_http_version 1.1;
        proxy_set_header Host $host;                # ⬅ corrige "localhost"
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket / SSE (Kibana dashboard)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}


EOF
log_ok "Config Nginx générée : $NGINX_FILE"

# --- RELOAD NGINX in proxy container (if running) ---
log_info "Reload de Nginx dans le conteneur ${PROXY_CONTAINER} (si actif)..."
if docker inspect -f '{{.State.Running}}' $PROXY_CONTAINER 2>/dev/null | grep -q true; then
    if docker exec -i $PROXY_CONTAINER nginx -t >/dev/null 2>&1; then
        docker exec -i $PROXY_CONTAINER nginx -s reload >/dev/null 2>&1
        log_ok "Nginx rechargé avec succès dans ${PROXY_CONTAINER}."
    else
        log_warn "Erreur dans la configuration Nginx; reload annulé. Vérifie $NGINX_FILE"
    fi
else
    log_warn "Impossible de recharger Nginx : conteneur ${PROXY_CONTAINER} non démarré."
fi

log_ok "Lab ${LAB_NAME} déployé !"
echo
echo "  - Accès DVWA  : http://dvwa.${LAB_NAME}.local"
echo "  - Accès Wazuh : http://wazuh.${LAB_NAME}.local"
echo
log_info "Conseils:"
echo "  * Si tu veux changer le préfixe utilisé par docker-compose, exporte COMPOSE_PROJECT_NAME avant d'appeler le script."
echo "    Exemple : export COMPOSE_PROJECT_NAME=lab && ./create_lab.sh lab1"
echo "  * Si nginx-proxy.yml référence en dur 'infrastructure_lab1_net', remplace cette référence par un réseau générique"
echo "    ou marque la section 'networks' dans nginx-proxy.yml comme 'external: true' puis ajuste le nom si nécessaire."
