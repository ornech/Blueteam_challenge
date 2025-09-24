#!/usr/bin/env bash
set -euo pipefail

# -------- Paths --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Charger les libs
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/network.sh"
source "$LIB_DIR/generate.sh"


# -------- Defaults --------
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-blueteam}"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose-template.yml"
ENV_DIR="$SCRIPT_DIR/envs"
DATA_DIR="$SCRIPT_DIR/data"
NGINX_CONF_DIR="/etc/nginx/conf.d"   # <--- nginx sur l’hôte maintenant

# -------- Args check --------
if [ $# -ne 1 ]; then
    echo "Usage: $0 <lab_name>"
    echo "Exemple: $0 lab1"
    exit 1
fi
LAB_NAME="$1"

# -------- Prepare directories --------
log_info "Création des dossiers nécessaires..."
mkdir -p "$ENV_DIR" "$NGINX_CONF_DIR" \
         "$DATA_DIR/${LAB_NAME}/wazuh_manager" \
         "$DATA_DIR/${LAB_NAME}/wazuh_indexer" \
         "$DATA_DIR/${LAB_NAME}/mariadb" \
         "$SCRIPT_DIR/certs/${LAB_NAME}"

log_ok "Dossiers prêts : $ENV_DIR, $DATA_DIR/${LAB_NAME}/..."

fix_perms_certs() {
    local LAB_NAME="$1"
    local CERTS_DIR="$SCRIPT_DIR/certs/$LAB_NAME"

    if [ -d "$CERTS_DIR" ]; then
        log_info "Correction des permissions des certificats pour $LAB_NAME..."
        sudo chown -R 1000:1000 "$CERTS_DIR"
        sudo chmod 755 "$CERTS_DIR"
        sudo chmod 644 "$CERTS_DIR"/*.pem "$CERTS_DIR"/*.key || true    
        sudo chmown -R 1000:1000 "$CERTS_DIR"/*.pem "$CERTS_DIR"/*.key || true 
        log_ok "Permissions corrigées sur $CERTS_DIR"
    else
        log_warn "Pas de dossier de certificats pour $LAB_NAME ($CERTS_DIR absent)"
    fi
}



# -------- Run workflow --------
ensure_lab_network "$LAB_NAME"
generate_certs "$LAB_NAME"
generate_env "$LAB_NAME"
generate_compose "$LAB_NAME"
generate_nginx_conf "$LAB_NAME"
fix_perms_certs "$LAB_NAME"

# -------- Deploy lab --------
log_info "Déploiement du lab ${LAB_NAME}..."
docker compose --project-name "${COMPOSE_PROJECT_NAME}" \
    -f "$SCRIPT_DIR/docker-compose-${LAB_NAME}.yml" \
    --env-file "$ENV_DIR/${LAB_NAME}.env" up -d

# -------- Reload nginx hôte --------
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
log_info "Conseils :"
echo "  * Si tu veux changer le préfixe utilisé par docker-compose,"
echo "    exporte COMPOSE_PROJECT_NAME avant d'appeler le script."
echo "    Exemple : export COMPOSE_PROJECT_NAME=lab && ./create_lab.sh lab1"
