#!/usr/bin/env bash
# -*- coding: utf-8 -*-

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <lab_name>"
    exit 1
fi
LAB_NAME="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

LAB_DIR="$SCRIPT_DIR/labs/$LAB_NAME"
ENV_FILE="$LAB_DIR/${LAB_NAME}.env"
COMPOSE_FILE="$LAB_DIR/docker-compose.yml"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/network.sh"
source "$LIB_DIR/generate.sh"

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-blueteam}"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose-template.yml"
NGINX_CONF_DIR="/etc/nginx/conf.d"

if [ -d "$LAB_DIR" ]; then
    log_warn "Le labo $LAB_NAME existe déjà"
    exit 1
fi

mkdir -p "$LAB_DIR/wazuh_manager/config" "$LAB_DIR/wazuh_manager/data" \
         "$LAB_DIR/wazuh_indexer/config" "$LAB_DIR/wazuh_indexer/data" \
         "$LAB_DIR/wazuh_dashboard/config" \
         "$LAB_DIR/mariadb/data" \
         "$LAB_DIR/dvwa" \
         "$LAB_DIR/common" \
         "$LAB_DIR/filebeat/data"

log_ok "Dossiers prêts : $LAB_DIR"

generate_env "$LAB_NAME" "$LAB_DIR"
generate_fileossec "$LAB_NAME" "$LAB_DIR"
generate_filebeat_config "$LAB_NAME" "$LAB_DIR"
generate_compose "$LAB_NAME" "$COMPOSE_TEMPLATE" "$COMPOSE_FILE"

log_info "Déploiement du lab ${LAB_NAME}..."
docker compose --project-name "${COMPOSE_PROJECT_NAME}" \
    -f "$COMPOSE_FILE" \
    --env-file "$ENV_FILE" up -d

log_ok "Lab ${LAB_NAME} déployé !"
echo "Accès Wazuh Dashboard : http://wazuh.${LAB_NAME}.local"
