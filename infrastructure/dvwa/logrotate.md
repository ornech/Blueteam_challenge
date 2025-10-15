# Agent Wazuh

## Rotation automatique des log

Créer le fichier /etc/logrotate.d/modsec_flat

```bash
/var/log/modsec_flat.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 640 root root
    postrotate
        /usr/local/bin/modsec_flatten.py >/dev/null 2>&1 || true
    endscript
}
```

