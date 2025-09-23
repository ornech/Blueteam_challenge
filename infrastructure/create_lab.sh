#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose-template.yml"
ENV_DIR="$SCRIPT_DIR/envs"
DATA_DIR="$SCRIPT_DIR/data"
NGINX_CONF_DIR="$SCRIPT_DIR/nginx/conf.d"
PROXY_CONTAINER="nginx_reverse_proxy"
PROJECT_NAME=$(basename "$SCRIPT_DIR")
PROXY_COMPOSE_FILE="$SCRIPT_DIR/nginx-proxy.yml"

# --- ARG CHECK ---
if [ $# -ne 1 ]; then
    echo "Usage: $0 <lab_name> (ex: lab1)"
    exit 1
fi

LAB_NAME="$1"
ENV_FILE="${ENV_DIR}/${LAB_NAME}.env"
NGINX_FILE="${NGINX_CONF_DIR}/${LAB_NAME}.conf"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose-${LAB_NAME}.yml"

mkdir -p "$ENV_DIR" "$NGINX_CONF_DIR" \
         "$DATA_DIR/${LAB_NAME}/wazuh_manager" \
         "$DATA_DIR/${LAB_NAME}/wazuh_indexer"

# --- ASSURE LE RÉSEAU EXTERNE POUR LE PROXY (création si manquant) ---
PROJECT_NAME=$(basename "$SCRIPT_DIR")
FULL_NET_NAME="${PROJECT_NAME}_${LAB_NAME}_net"
# calcul du subnet (même logique que plus bas dans le script)
LAB_NUM=$(echo "$LAB_NAME" | grep -o '[0-9]*$' || echo "1")
BASE_SUBNET=30
LAB_SUBNET="172.${BASE_SUBNET}.${LAB_NUM}.0/24"

# Si le réseau n'existe pas, le créer avec le subnet calculé
if ! docker network inspect "$FULL_NET_NAME" >/dev/null 2>&1; then
  echo "DEBUG: réseau $FULL_NET_NAME absent → création automatique (subnet $LAB_SUBNET)"
  docker network create --driver bridge --subnet "$LAB_SUBNET" "$FULL_NET_NAME" || true
fi


# --- ENSURE PROXY IS RUNNING ---
echo "[*] Vérification du conteneur proxy $PROXY_CONTAINER..."
if ! docker ps -a --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}\$"; then
    echo "DEBUG: proxy absent → lancement via $PROXY_COMPOSE_FILE"
    docker compose -f "$PROXY_COMPOSE_FILE" up -d
elif ! docker inspect -f '{{.State.Running}}' $PROXY_CONTAINER 2>/dev/null | grep -q true; then
    echo "DEBUG: proxy présent mais arrêté → démarrage"
    docker start $PROXY_CONTAINER
else
    echo "DEBUG: proxy déjà en cours d'exécution"
fi

# --- CLEAN OLD RESOURCES FOR THIS LAB ---
echo "[*] Nettoyage de l'ancien environnement Docker pour ${LAB_NAME}..."

old_containers=$(docker ps -a --format '{{.Names}}' | grep "^${LAB_NAME}_" || true)
if [ -z "$old_containers" ]; then
    echo "DEBUG: aucun conteneur trouvé pour ${LAB_NAME}"
else
    echo "DEBUG: conteneurs trouvés -> $old_containers"
    for cname in $old_containers; do
        echo "DEBUG: suppression du conteneur $cname"
        docker rm -f "$cname" || true
    done
fi

FULL_NET_NAME="${PROJECT_NAME}_${LAB_NAME}_net"
if docker network inspect "$FULL_NET_NAME" >/dev/null 2>&1; then
    echo "DEBUG: déconnexion du proxy du réseau $FULL_NET_NAME (si connecté)"
    docker network disconnect "$FULL_NET_NAME" $PROXY_CONTAINER 2>/dev/null || true

    echo "DEBUG: suppression du réseau $FULL_NET_NAME"
    docker network rm "$FULL_NET_NAME" || true
fi

old_volumes=$(docker volume ls --format '{{.Name}}' | grep "^${LAB_NAME}_" || true)
if [ -n "$old_volumes" ]; then
    for vname in $old_volumes; do
        echo "DEBUG: suppression du volume $vname"
        docker volume rm "$vname" || true
    done
fi

echo "[✔] Nettoyage terminé pour ${LAB_NAME}"

# --- PORTS & SUBNET ---
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

# --- CREATE .env ---
if [ -f "$ENV_FILE" ]; then
    echo "[!] Le fichier $ENV_FILE existe déjà. On ne l'écrase pas."
else
    cat > "$ENV_FILE" <<EOF
LAB_NAME=${LAB_NAME}
LAB_SUBNET=${LAB_SUBNET}
WAZUH_PORT_1514=${PORT_1514}
WAZUH_PORT_1515=${PORT_1515}
WAZUH_PORT_55000=${PORT_55000}
WAZUH_PORT_5601=${PORT_5601}
EOF
    echo "[+] Fichier .env généré : $ENV_FILE"
fi

# --- GENERATE COMPOSE FILE ---
echo "[*] Génération du docker-compose spécifique pour ${LAB_NAME}..."
export LAB_NAME LAB_SUBNET WAZUH_PORT_1514 WAZUH_PORT_1515 WAZUH_PORT_55000 WAZUH_PORT_5601
envsubst < "$COMPOSE_TEMPLATE" > "$COMPOSE_FILE"
echo "[+] Fichier généré : $COMPOSE_FILE"

# --- DEPLOY LAB ---
echo "[*] Déploiement du lab ${LAB_NAME}..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

# --- CONNECT PROXY TO LAB NETWORK ---
echo "[*] Connexion du proxy nginx_reverse_proxy au réseau ${FULL_NET_NAME}..."
docker network connect "${FULL_NET_NAME}" $PROXY_CONTAINER 2>/dev/null || true

# --- ENSURE DEFAULT.CONF EXISTS ---
DEFAULT_CONF="$NGINX_CONF_DIR/default.conf"
if [ ! -f "$DEFAULT_CONF" ]; then
    echo "DEBUG: génération d'un default.conf"
    cat > "$DEFAULT_CONF" <<EOF
server {
    listen 80 default_server;
    server_name _;
    return 404;
}
EOF
fi

# --- REMOVE OLD LAB CONF ---
if [ -f "$NGINX_FILE" ]; then
    echo "DEBUG: suppression de l'ancienne conf Nginx $NGINX_FILE"
    rm -f "$NGINX_FILE"
fi

# --- NGINX CONF FOR THIS LAB ---
cat > "$NGINX_FILE" <<EOF

server {
    server_name dvwa.${LAB_NAME}.local;

    resolver 127.0.0.11 valid=30s;

    location / {
        proxy_pass http://${LAB_NAME}_dvwa:80/;
        proxy_set_header Host localhost;
        proxy_set_header X-Real-IP \$remote_addr;
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
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}


EOF

echo "[+] Config Nginx générée : $NGINX_FILE"

# --- RELOAD NGINX ---
echo "[*] Reload de Nginx dans le conteneur $PROXY_CONTAINER..."
if docker inspect -f '{{.State.Running}}' $PROXY_CONTAINER 2>/dev/null | grep -q true; then
    if docker exec -i $PROXY_CONTAINER nginx -t; then
        docker exec -i $PROXY_CONTAINER nginx -s reload
        echo "[✔] Nginx rechargé avec succès"
    else
        echo "[!] Erreur dans la configuration Nginx, reload annulé"
    fi
else
    echo "[!] Impossible de recharger Nginx : conteneur $PROXY_CONTAINER non démarré"
fi

echo "[✔] Lab ${LAB_NAME} déployé avec succès !"
echo "    Accès DVWA   : http://dvwa.${LAB_NAME}.local"
echo "    Accès Wazuh  : http://wazuh.${LAB_NAME}.local"
