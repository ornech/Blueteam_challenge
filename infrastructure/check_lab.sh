#!/usr/bin/env bash
# Script de diagnostic Wazuh Lab (version Fluent Bit, sans SSL)

set -euo pipefail

LAB_NAME="${1:-lab1}"
LAB_DIR="labs/$LAB_NAME"
ENV_FILE="$LAB_DIR/${LAB_NAME}.env"

RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RESET=$(tput sgr0)
ok()    { echo "${GREEN}[ OK ]${RESET} $*"; }
warn()  { echo "${YELLOW}[WARN]${RESET} $*"; }
err()   { echo "${RED}[ERR ]${RESET} $*"; }
info()  { echo "${YELLOW}[INFO]${RESET} $*"; }

# ----------------------------------------------------------
# Vérification fichiers critiques
# ----------------------------------------------------------
info "=== Vérification fichiers ==="
check_file() {
    local file="$1"
    local pattern="${2:-}"
    if [ ! -f "$file" ]; then err "Manquant : $file"; return 1; fi
    ok "Présent : $file"
    perms=$(stat -c "%U:%G %a" "$file")
    echo "     ↳ Permissions: $perms"
    if [ -n "$pattern" ]; then
        grep -q "$pattern" "$file" && ok "     ↳ Contenu OK ($pattern)" || warn "     ↳ Pattern $pattern non trouvé"
    fi
}
check_file "$ENV_FILE"
check_file "$LAB_DIR/wazuh_server/config/ossec.conf" "<ossec_config>"
check_file "$LAB_DIR/wazuh_indexer/config/opensearch.yml" "plugins.security.disabled: true"
check_file "$LAB_DIR/fluentbit/fluent-bit.conf" "OUTPUT"

# ----------------------------------------------------------
# Vérification conteneurs
# ----------------------------------------------------------
info "=== Vérification conteneurs ==="
containers=( "${LAB_NAME}_wazuh_indexer" "${LAB_NAME}_wazuh_server" "${LAB_NAME}_wazuh_dashboard" "${LAB_NAME}_fluentbit" )

for c in "${containers[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^$c\$"; then
        ok "Conteneur $c en cours d’exécution"
    else
        err "Conteneur $c absent ou arrêté"
        continue
    fi
    echo "----- Logs $c -----"
    docker logs --tail 10 "$c" || warn "Impossible de lire logs $c"
    echo "-------------------"
done

# ----------------------------------------------------------
# Tests spécifiques
# ----------------------------------------------------------
info "=== Tests spécifiques ==="

# API Wazuh server
if docker exec -i ${LAB_NAME}_wazuh_server curl -s -o /dev/null -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' http://localhost:55000/security/user/authenticate | grep -q "200"; then
    ok "API Wazuh répond sur 55000"
else
    err "API Wazuh ne répond pas ou credentials invalides"
fi

# Indexer
if docker exec -i ${LAB_NAME}_wazuh_indexer curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green"\\|"status":"yellow"'; then
    ok "Indexer cluster health = green/yellow"
else
    err "Indexer cluster non healthy"
fi

# Dashboard
code=$(docker exec -i ${LAB_NAME}_wazuh_dashboard curl -s -o /dev/null -w "%{http_code}" http://localhost:5601 || true)
[[ "$code" == "200" ]] && ok "Dashboard accessible (HTTP 200)" || err "Dashboard inaccessible (code=$code)"

# Fluent Bit → OpenSearch
if docker exec -i ${LAB_NAME}_fluentbit curl -s http://${LAB_NAME}_wazuh_indexer:9200/_cat/indices?v | grep -q wazuh-alerts; then
    ok "Fluent Bit index wazuh-alerts trouvé dans OpenSearch"
else
    warn "Fluent Bit n’a pas encore indexé de wazuh-alerts"
fi

echo "=== État global des conteneurs ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
