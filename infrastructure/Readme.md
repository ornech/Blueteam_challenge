

Wazuh serverr = moteur qui génère les alertes

Wazuh Indexer (OpenSearch) = base qui stocke/cherche

Dashboard = interface graphique pour consulter et analyser




Avancement : 
sudo chown 999:999 labs/lab1/wazuh_server/config/ossec.conf
sudo chown 999:999 labs/lab1/wazuh_server/config/local_decoder.xml
sudo chown 999:999 labs/lab1/wazuh_server/config/local_rules.xml

Le Bind de ces fichiers provoque l'erreur:
2025/10/02 19:03:03 wazuh-analysisd: WARNING: (1103): Could not open file '/var/ossec/etc/rules/local_rules.xml' due to [(2)-(No such file or directory)].
