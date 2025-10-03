#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Script de validation pour lab1 Wazuh
# Usage : ./test_lab1.sh

set -euo pipefail

LAB_NAME="lab1"
serverr="${LAB_NAME}_wazuh_server"
INDEXER="${LAB_NAME}_wazuh_indexer"
DASHBOARD="${LAB_NAME}_wazuh_dashboard"
FLUENTBIT="${LAB_NAME}_fluentbit"


echo "=== Vérification containers en cours ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$LAB_NAME" || {
  echo "❌ Aucun conteneur $LAB_NAME trouvé"
  exit 1
}
echo "✅ Conteneurs actifs"

echo
echo "=== Etat des démons Wazuh serverr ==="
docker exec -it "$serverr" /var/ossec/bin/wazuh-control status || echo "❌ Impossible d'obtenir le status"
echo

echo "=== Test API Wazuh (authentification) ==="
API_RESP=$(docker exec -it "$serverr" curl -sk -u admin:admin https://localhost:55000/security/user/authenticate || true)
if echo "$API_RESP" | grep -q "token"; then
  echo "✅ API Wazuh OK"
else
  echo "❌ API Wazuh ne répond pas correctement"
fi
echo

echo "=== Etat cluster OpenSearch ==="
docker exec -it "$serverr" curl -sk http://$INDEXER:9200/_cluster/health -u admin:admin | jq || {
  echo "❌ Cluster OpenSearch inaccessible"
}
echo

echo "=== Test Dashboard (port exposé) ==="
PORT=$(docker ps --format "{{.Names}} {{.Ports}}" | grep "$DASHBOARD" | awk -F'[:>]' '{print $2}')
if [ -n "$PORT" ]; then
  echo "➡️  Dashboard accessible sur http://localhost:$PORT"
else
  echo "❌ Dashboard non trouvé"
fi
echo

echo "=== Logs Fluent Bit (50 dernières lignes) ==="
docker logs "$FLUENTBIT" --tail=50 || echo "❌ Impossible de lire les logs Fluent Bit"
echo
