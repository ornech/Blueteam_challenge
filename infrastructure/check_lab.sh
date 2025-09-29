#!/usr/bin/env bash
# test_end2end_wazuh.sh

LAB=lab1
INDEXER=${LAB}_wazuh_indexer
MANAGER=${LAB}_wazuh_manager
FILEBEAT=${LAB}_filebeat
DASHBOARD=${LAB}_wazuh_dashboard

echo "=== Test end-to-end Wazuh (${LAB}) ==="

# 1. Vérifier la version de Filebeat
docker exec -it $FILEBEAT filebeat version

# 2. Vérifier que Filebeat utilise bien le pipeline
if docker exec -it $FILEBEAT grep -q "pipeline: \"wazuh-alerts-pipeline\"" /usr/share/filebeat/filebeat.yml; then
  echo "✅ Filebeat pointe vers wazuh-alerts-pipeline"
else
  echo "❌ Filebeat ne pointe PAS vers wazuh-alerts-pipeline"
fi

# 3. Injection d’un faux log JSON dans les logs de Wazuh
echo '{"timestamp":"2025-09-29T15:45:00Z","rule":{"id":"100001","level":3},"agent":{"id":"001"},"data":{"srcip":"1.2.3.4"}}' \
  | docker exec -i $MANAGER tee -a /var/ossec/logs/alerts/alerts.json >/dev/null
echo "✅ Faux log injecté dans Wazuh"

# 4. Attendre que Filebeat envoie
sleep 5

# 5. Vérifier que le document est dans l’index
if docker exec -it $INDEXER curl -s "http://localhost:9200/wazuh-alerts-*/_search?q=data.srcip:1.2.3.4&pretty" | grep -q '"hits"'; then
  echo "✅ Document retrouvé dans l’index"
else
  echo "❌ Aucun document retrouvé"
fi

# 6. Vérifier que le Dashboard est up
if docker exec -it $DASHBOARD curl -s -o /dev/null -w "%{http_code}" http://localhost:5601 | grep -q "200"; then
  echo "✅ Dashboard répond sur le port 5601"
else
  echo "❌ Dashboard ne répond pas"
fi

# 7. Vérifier que le Dashboard “voit” bien l’index
if docker exec -it $INDEXER curl -s "http://localhost:9200/_cat/indices?v" | grep -q "wazuh-alerts"; then
  echo "✅ Dashboard devrait voir l’index wazuh-alerts-*"
else
  echo "❌ Aucun index wazuh-alerts-* détecté"
fi

echo "=== Fin du test ==="

