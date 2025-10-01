#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Script de diagnostic Wazuh Lab
# Vérifie la présence des fichiers, leurs permissions et les logs des conteneurs.

set -euo pipefail

LAB_NAME="${1:-lab1}"
LAB_DIR="labs/$LAB_NAME"
ENV_FILE="$LAB_DIR/${LAB_NAME}.env"
COMPOSE_FILE="$LAB_DIR/docker-compose.yml"

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

ok()    { echo "${GREEN}[ OK ]${RESET} $*"; }
warn()  { echo "${YELLOW}[WARN]${RESET} $*"; }
err()   { echo "${RED}[ERR ]${RESET} $*"; }
info()  { echo "${YELLOW}[INFO]${RESET} $*"; }

# ----------------------------------------------------------
# Vérification des fichiers critiques
# ----------------------------------------------------------
check_file() {
    local file="$1"
    local pattern="${2:-}"
    if [ ! -f "$file" ]; then
        err "Manquant : $file"
        return 1
    fi
    ok "Présent : $file"
    # Vérifie propriétaire/permissions
    perms=$(stat -c "%U:%G %a" "$file")
    echo "     ↳ Permissions: $perms"
    # Vérifie contenu si un pattern est donné
    if [ -n "$pattern" ]; then
        if grep -q "$pattern" "$file"; then
            ok "     ↳ Contenu vérifié ($pattern)"
        else
            warn "     ↳ Contenu inattendu (pattern $pattern non trouvé)"
        fi
    fi
}

info "=== Vérification fichiers ==="
check_file "$ENV_FILE"
check_file "$LAB_DIR/wazuh_manager/config/ossec.conf" "<ossec_config>"
check_file "$LAB_DIR/wazuh_indexer/config/opensearch.yml" "plugins.security.disabled: true"
check_file "$LAB_DIR/filebeat/filebeat.yml" "output.elasticsearch"

# ----------------------------------------------------------
# Vérification conteneurs
# ----------------------------------------------------------
info "=== Vérification conteneurs ==="
containers=( "${LAB_NAME}_wazuh_indexer" "${LAB_NAME}_wazuh_manager" "${LAB_NAME}_wazuh_dashboard" "${LAB_NAME}_filebeat" )

for c in "${containers[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^$c\$"; then
        ok "Conteneur $c en cours d’exécution"
    else
        err "Conteneur $c absent ou arrêté"
        continue
    fi

    # Affiche 20 dernières lignes de logs
    echo "----- Logs $c -----"
    docker logs --tail 20 "$c" || warn "Impossible de lire logs $c"
    echo "-------------------"
done

# ----------------------------------------------------------
# Tests spécifiques Filebeat et Indexer
# ----------------------------------------------------------
info "=== Tests spécifiques ==="

# Vérifie que l’indexer répond
if docker exec -it ${LAB_NAME}_wazuh_indexer curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    ok "Indexer répond sur port 9200"
else
    err "Indexer ne répond pas sur 9200"
fi

# Vérifie que Filebeat n’a pas d’erreur "_type"
if docker logs ${LAB_NAME}_filebeat 2>&1 | grep -q "_type"; then
    err "Filebeat remonte encore des erreurs liées à _type"
else
    ok "Pas d’erreurs _type dans Filebeat"
fi

# Vérifie que l’indexer n’essaie pas de charger le plugin security
if docker logs ${LAB_NAME}_wazuh_indexer 2>&1 | grep -q "OpenSearchSecurityPlugin"; then
    err "Indexer tente encore de charger le plugin OpenSearchSecurityPlugin"
else
    ok "Indexer : plugin sécurité bien désactivé"
fi

echo
info "=== Diagnostic terminé ==="
