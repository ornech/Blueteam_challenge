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
DATA_PATH="${DATA_DIR}/${LAB_NAME}"

# --- STOP & REMOVE LAB ---
if [ -f "$ENV_FILE" ]; then
    echo "[*] Arrêt et suppression des conteneurs du lab ${LAB_NAME}..."
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down -v
else
    echo "[!] Aucun fichier .env trouvé pour ${LAB_NAME}, on tente un down direct..."
    docker compose -f "$COMPOSE_FILE" down -v || true
fi

# --- REMOVE NGINX CONF ---
if [ -f "$NGINX_FILE" ]; then
    rm -f "$NGINX_FILE"
    echo "[+] Config Nginx supprimée : $NGINX_FILE"

    # Reload Nginx
    if docker ps --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}\$"; then
        docker exec $PROXY_CONTAINER nginx -s reload
        echo "[✔] Nginx rechargé avec succès"
    else
        echo "[!] Le conteneur $PROXY_CONTAINER n'existe pas ou n'est pas démarré"
    fi
fi

# --- REMOVE DATA ---
if [ -d "$DATA_PATH" ]; then
    echo "[*] Suppression des données persistantes de ${LAB_NAME}..."
    rm -rf "$DATA_PATH"
fi

# --- REMOVE ENV FILE ---
if [ -f "$ENV_FILE" ]; then
    rm -f "$ENV_FILE"
    echo "[+] Fichier .env supprimé : $ENV_FILE"
fi

echo "[✔] Lab ${LAB_NAME} supprimé avec succès !"
