#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Crée et déploie un labo complet (conteneurs, volumes, fichiers, conf Nginx)

set -euo pipefail

# -------- Args check --------
if [ $# -ne 1 ]; then
    echo "Usage: $0 <lab_name>"
    echo "Exemple: $0 lab1"
    exit 1
fi
LAB_NAME="$1"

# -------- Paths --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

LAB_DIR="$SCRIPT_DIR/labs/$LAB_NAME"
ENV_FILE="$LAB_DIR/${LAB_NAME}.env"
COMPOSE_FILE="$LAB_DIR/docker-compose.yml"

# Charger les libs
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/network.sh"
source "$LIB_DIR/generate.sh"

# -------- Defaults --------
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-blueteam}"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose-template.yml"
NGINX_CONF_DIR="/etc/nginx/conf.d"   # nginx sur l’hôte

# -------- Création des répertoires --------
if [ -d "$LAB_DIR" ]; then
    log_warn "Le labo $LAB_NAME existe déjà dans $LAB_DIR"
    exit 1
fi

mkdir -p "$LAB_DIR/wazuh_manager/config" "$LAB_DIR/wazuh_manager/data" "$LAB_DIR/wazuh_manager/certs" \
         "$LAB_DIR/wazuh_indexer/config" "$LAB_DIR/wazuh_indexer/data" "$LAB_DIR/wazuh_indexer/certs" \
         "$LAB_DIR/wazuh_dashboard/config" "$LAB_DIR/wazuh_dashboard/certs" \
         "$LAB_DIR/mariadb/data" \
         "$LAB_DIR/dvwa" \
         "$LAB_DIR/common" \
         "$LAB_DIR/filebeat/data"

log_ok "Dossiers prêts : $LAB_DIR"

# -------- Run workflow --------
generate_env "$LAB_NAME" "$LAB_DIR"
generate_fileossec "$LAB_NAME" "$LAB_DIR"
generate_opensearch_disable_security "$LAB_NAME" "$LAB_DIR"
generate_dashboard_conf "$LAB_NAME" "$LAB_DIR"
generate_compose "$LAB_NAME" "$COMPOSE_TEMPLATE" "$COMPOSE_FILE"
generate_nginx_conf "$LAB_NAME" "$NGINX_CONF_DIR"
generate_certs "$LAB_NAME" "$LAB_DIR"
generate_filebeat_config "$LAB_NAME" "$LAB_DIR"
generate_disable_filebeat "$LAB_NAME" "$LAB_DIR"

# -------- Fix perms --------
fix_perms_certs() {
    if [ -d "$LAB_DIR/common" ]; then
        log_info "Correction des permissions des certificats pour $LAB_NAME..."
        sudo chown -R 1000:1000 "$LAB_DIR/common"
        sudo chmod 755 "$LAB_DIR/common"
        sudo chmod 644 "$LAB_DIR/common"/*.{pem,key,yml} 2>/dev/null || true
        log_ok "Permissions corrigées sur $LAB_DIR/common"
    fi
}

fix_perms_data() {
    for d in "$LAB_DIR"/*/data; do
        if [ -d "$d" ]; then
            log_info "Correction des permissions sur $d..."
            sudo chown -R 1000:1000 "$d"
            sudo chmod -R 755 "$d"
            log_ok "Permissions corrigées sur $d"
        fi
    done
}

fix_perms_certs
fix_perms_data
fix_perms_filebeat "$LAB_DIR"

# -------- Deploy lab --------
log_info "Déploiement du lab ${LAB_NAME}..."
docker compose --project-name "${COMPOSE_PROJECT_NAME}" \
    -f "$COMPOSE_FILE" \
    --env-file "$ENV_FILE" up -d

# -------- Reload nginx --------
log_info "Reload de Nginx système..."
if sudo nginx -t >/dev/null 2>&1; then
    sudo systemctl reload nginx
    log_ok "Nginx rechargé avec succès."
else
    log_warn "Erreur dans la configuration Nginx; reload annulé."
fi

# -------- Infos --------
log_ok "Lab ${LAB_NAME} déployé !"
echo
echo "  - Accès DVWA  : http://dvwa.${LAB_NAME}.local"
echo "  - Accès Wazuh : http://wazuh.${LAB_NAME}.local"
