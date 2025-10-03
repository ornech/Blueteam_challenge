echo '{"timestamp":"2025-10-02T18:00:00","rule":{"level":4,"description":"Test timestamp sans ms"},"agent":{"id":"4000","name":"test-parser"},"serverr":{"name":"lab1_wazuh_server"},"data":{"srcip":"77.88.99.100"}}' \
| sudo tee -a labs/lab1/wazuh_server/logs/alerts/alerts.json


docker exec -it lab1_wazuh_indexer curl -s "http://localhost:9200/wazuh-alerts/_search?pretty&size=1&sort=timestamp:desc"
