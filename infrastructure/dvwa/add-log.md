# Agent Wazuh

## Déclarez un nouveau fichier de log a transmettre au manager

Dans /var/ossec/etc/ossec.conf, ajoutez un section

```bash
<localfile>
  <location>/var/log/modsec_flat.log</location>
  <log_format>json</log_format>
</localfile>
```

Puis rédémarrez l'agent
```bash
sudo systemctl restart wazuh-agent
```
