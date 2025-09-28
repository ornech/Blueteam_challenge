#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Nom du script : create_lab.sh
# Auteur : Jean-Francois Ornech '@ornech'
# Description : Crée et déploie un labo complet (conteneurs, volumes, fichiers, conf Nginx)
# Usage : ./create_lab.sh <lab_name>

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
DATA_DIR="$LAB_DIR/data"
CONFIG_DIR="$LAB_DIR/configs"
CERTS_DIR="$LAB_DIR/certs"
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

# -------- Préparation --------
log_info "Création des dossiers nécessaires..."
mkdir -p "$LAB_DIR" "$DATA_DIR/wazuh_manager" "$DATA_DIR/wazuh_indexer" "$DATA_DIR/mariadb" \
         "$CONFIG_DIR/ossec" "$CONFIG_DIR/wazuh-dashboard" "$CERTS_DIR" "$NGINX_CONF_DIR"

log_ok "Dossiers prêts : $LAB_DIR"

# -------- Config Dashboard --------
log_info "Génération de opensearch_dashboards.yml pour Wazuh Dashboard"
cat > "$CONFIG_DIR/wazuh-dashboard/opensearch_dashboards.yml" <<YML
server.host: "0.0.0.0"
server.port: 5601
opensearch.hosts: ["http://${LAB_NAME}_wazuh_indexer:9200"]
opensearch.ssl.verificationMode: "none"
opensearch.requestHeadersAllowlist: ["securitytenant","Authorization"]
YML

touch "$CONFIG_DIR/wazuh-dashboard/opensearch_dashboards.keystore"
sudo chown 1000:1000 "$CONFIG_DIR/wazuh-dashboard/"*
sudo chmod 644 "$CONFIG_DIR/wazuh-dashboard/opensearch_dashboards.yml"
sudo chmod 660 "$CONFIG_DIR/wazuh-dashboard/opensearch_dashboards.keystore"

# -------- Opensearch disable security --------
log_info "Désactivation du plugin security"
cat > "$LAB_DIR/opensearch-disable-security.yml" <<EOF
cluster.name: wazuh-indexer
path.data: /var/lib/wazuh-indexer
plugins.security.disabled: true
network.host: 0.0.0.0
discovery.type: single-node
EOF

# -------- Fix perms --------
fix_perms_certs() {
    if [ -d "$CERTS_DIR" ]; then
        log_info "Correction des permissions des certificats pour $LAB_NAME..."
        sudo chown -R 1000:1000 "$CERTS_DIR"
        sudo chmod 755 "$CERTS_DIR"
        sudo chmod 644 "$CERTS_DIR"/*.{pem,key,yml} 2>/dev/null || true
        log_ok "Permissions corrigées sur $CERTS_DIR"
    fi
}

fix_perms_data() {
    if [ -d "$DATA_DIR" ]; then
        log_info "Correction des permissions des données pour $LAB_NAME..."
        sudo chown -R 1000:1000 "$DATA_DIR"
        sudo chmod -R 755 "$DATA_DIR"
        log_ok "Permissions corrigées sur $DATA_DIR"
    fi
}

# -------- Run workflow --------
ensure_lab_network "$LAB_NAME"
generate_certs "$LAB_NAME" "$CERTS_DIR"
generate_env "$LAB_NAME" "$LAB_DIR"
generate_fileossec "$LAB_NAME" "$CONFIG_DIR/ossec"
generate_compose "$LAB_NAME" "$COMPOSE_TEMPLATE" "$COMPOSE_FILE"
generate_nginx_conf "$LAB_NAME" "$NGINX_CONF_DIR"

fix_perms_certs
fix_perms_data

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
echo
