#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose-template.yml"
ENV_DIR="$SCRIPT_DIR/envs"
DATA_DIR="$SCRIPT_DIR/data"
NGINX_CONF_DIR="$SCRIPT_DIR/nginx/conf.d"
PROXY_CONTAINER="nginx_reverse_proxy"

# --- ARG CHECK ---
if [ $# -ne 1 ]; then
    echo "Usage: $0 <lab_name> (ex: blueteam1)"
    exit 1
fi

LAB_NAME="$1"
ENV_FILE="${ENV_DIR}/${LAB_NAME}.env"
NGINX_FILE="${NGINX_CONF_DIR}/${LAB_NAME}.conf"

mkdir -p "$ENV_DIR" "$NGINX_CONF_DIR" "$DATA_DIR/${LAB_NAME}/wazuh_manager" "$DATA_DIR/${LAB_NAME}/wazuh_indexer"

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
SUBNET="172.${BASE_SUBNET}.${LAB_NUM}.0/24"

# --- CREATE .env ---
if [ -f "$ENV_FILE" ]; then
    echo "[!] Le fichier $ENV_FILE existe déjà. On ne l'écrase pas."
else
    cat > "$ENV_FILE" <<EOF
LAB_NAME=${LAB_NAME}
LAB_SUBNET=${SUBNET}
WAZUH_PORT_1514=${PORT_1514}
WAZUH_PORT_1515=${PORT_1515}
WAZUH_PORT_55000=${PORT_55000}
WAZUH_PORT_5601=${PORT_5601}
EOF
    echo "[+] Fichier .env généré : $ENV_FILE"
fi

# --- DEPLOY LAB ---
echo "[*] Déploiement du lab ${LAB_NAME}..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d

# --- NGINX CONF ---
cat > "$NGINX_FILE" <<EOF
server {
    server_name dvwa.${LAB_NAME}.local;

    location / {
        proxy_pass http://${LAB_NAME}_dvwa:80;
    }
}

server {
    server_name wazuh.${LAB_NAME}.local;

    location / {
        proxy_pass http://${LAB_NAME}_wazuh_dashboard:5601;
    }
}
EOF
echo "[+] Config Nginx générée : $NGINX_FILE"

# --- RELOAD NGINX ---
echo "[*] Reload de Nginx dans le conteneur $PROXY_CONTAINER..."
if docker ps --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}\$"; then
    docker exec $PROXY_CONTAINER nginx -s reload
    echo "[✔] Nginx rechargé avec succès"
else
    echo "[!] Le conteneur $PROXY_CONTAINER n'existe pas ou n'est pas démarré"
fi

echo "[✔] Lab ${LAB_NAME} déployé avec succès !"
echo "    Accès DVWA   : http://dvwa.${LAB_NAME}.local"
echo "    Accès Wazuh  : http://wazuh.${LAB_NAME}.local"
