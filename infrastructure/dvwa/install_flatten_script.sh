#!/usr/bin/env bash
set -eo pipefail

# ================================================================
# setup_flatten_all.sh
# - Installe /usr/local/bin/flatten_modsec.py
# - Crée flatten-modsec.service et flatten-modsec.timer (systemd)
# - Ajoute /var/log/modsec_flat.log à /var/ossec/etc/ossec.conf (si absent)
# - Active et démarre le timer
# ================================================================
if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être lancé en root. Utilise sudo." >&2
  exit 1
fi

PYTHON_PATH="/usr/local/bin/flatten_modsec.py"
SERVICE_PATH="/etc/systemd/system/flatten-modsec.service"
TIMER_PATH="/etc/systemd/system/flatten-modsec.timer"
SRC="/var/log/apache2/modsec_audit.log"
DST="/var/log/modsec_flat.log"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

echo "=== Installation du script de flatten ModSecurity et service systemd ==="

cat > "${PYTHON_PATH}" <<'PY'
#!/usr/bin/env python3
"""
flatten_modsec.py
Transforme les entrées JSON (modsec_audit.log standard) en NDJSON 'flat'
prêt pour ingestion par Wazuh (une ligne JSON par alerte).

Option A (percent-encode) :
  - remplace <, >, & dans uri, msg et data par leurs %3C %3E %26
  - conserve raw_uri/raw_msg/raw_data pour forensics
"""
import json, re, os, sys

SRC = "/var/log/apache2/modsec_audit.log"
DST = "/var/log/modsec_flat.log"
TMP = "/tmp/modsec_flat.tmp"

def sanitize_field(s):
    """
    Percent-encode only a small set of problematic characters that
    historically cause parsers/issues in the Wazuh manager:
      <  -> %3C
      >  -> %3E
      &  -> %26
    Keep the rest intact to preserve readability.
    """
    if s is None:
        return s
    try:
        return s.replace('<', '%3C').replace('>', '%3E').replace('&', '%26')
    except Exception:
        return s

def extract_alerts(entry):
    alerts = []
    audit = entry.get("audit_data", {})
    messages = audit.get("messages", [])
    for m in messages:
        # m est une chaîne contenant [file "..."] [id "..."] [msg "..."] etc.
        rule_id = None
        msg = None
        severity = None
        tags = []
        data_field = None

        # extractions robustes
        id_m = re.search(r'\[id\s+"([^"]+)"\]', m)
        if id_m:
            rule_id = id_m.group(1)
        msg_m = re.search(r'\[msg\s+"([^"]+)"\]', m)
        if msg_m:
            msg = msg_m.group(1)
        sev_m = re.search(r'\[severity\s+"([^"]+)"\]', m)
        if sev_m:
            severity = sev_m.group(1)
        tags = re.findall(r'\[tag\s+"([^"]+)"\]', m)
        data_m = re.search(r'\[data\s+"([^"]+)"\]', m)
        if data_m:
            data_field = data_m.group(1)

        alert = {
            "time": entry.get("transaction", {}).get("time"),
            "srcip": entry.get("transaction", {}).get("remote_address"),
            "host": (entry.get("request", {}).get("headers") or {}).get("Host"),
            "uri": None,
            "rule_id": rule_id,
            "msg": msg,
            "severity": severity,
            "tags": tags,
            "data": data_field
        }

        req_line = (entry.get("request") or {}).get("request_line")
        if req_line:
            parts = req_line.split()
            if len(parts) >= 2:
                alert["uri"] = parts[1]

        # Déduire attack_type depuis les tags OWASP_CRS si possible
        attack_type = None
        for t in tags:
            # les tags CRS sont souvent 'OWASP_CRS/ATTACK-SQLI' etc.
            if t.startswith("OWASP_CRS"):
                parts = t.split('/')
                if len(parts) > 1:
                    attack_type = parts[-1]
                    break
        alert["attack_type"] = attack_type

        # --- Sanitization (Option A) ---
        # Keep raw values for forensics, then sanitize the working fields.
        if alert.get("uri") is not None:
            alert["raw_uri"] = alert["uri"]
            alert["uri"] = sanitize_field(alert["uri"])
        if alert.get("msg") is not None:
            alert["raw_msg"] = alert["msg"]
            alert["msg"] = sanitize_field(alert["msg"])
        if alert.get("data") is not None:
            alert["raw_data"] = alert["data"]
            alert["data"] = sanitize_field(alert["data"])
        # --------------------------------

        alerts.append(alert)
    return alerts

def main():
    if not os.path.exists(SRC):
        print(f"Source absente: {SRC}", file=sys.stderr)
        # rien à faire : sortie 0 pour que systemd oneshot ne soit pas considéré fail si pas de log
        sys.exit(0)

    alerts = []
    try:
        with open(SRC, "r", encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    # ignore les lignes non-JSON
                    continue
                alerts.extend(extract_alerts(obj))
    except Exception as e:
        print(f"Erreur lecture {SRC}: {e}", file=sys.stderr)
        sys.exit(2)

    # écriture atomique
    try:
        with open(TMP, "w", encoding="utf-8") as out:
            for a in alerts:
                out.write(json.dumps(a, ensure_ascii=False) + "\n")
        os.replace(TMP, DST)
        print(f"✅ {len(alerts)} alertes CRS exportées vers {DST}")
    except Exception as e:
        print(f"Erreur écriture {DST}: {e}", file=sys.stderr)
        sys.exit(3)

if __name__ == "__main__":
    main()
PY

chmod 755 "${PYTHON_PATH}"
echo "Script Python créé : ${PYTHON_PATH}"

# ----- systemd service -------------------------------------------------
cat > "${SERVICE_PATH}" <<EOF
[Unit]
Description=Convert ModSecurity audit log to flattened NDJSON for Wazuh
After=network.target

[Service]
Type=oneshot
ExecStart=${PYTHON_PATH}
User=root
Group=root
Nice=10
StandardOutput=journal
StandardError=journal
EOF
echo "Service créé : ${SERVICE_PATH}"

# ----- systemd timer --------------------------------------------------
cat > "${TIMER_PATH}" <<EOF
[Unit]
Description=Run flatten-modsec every minute
After=network.target

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=10s
Persistent=true

[Install]
WantedBy=timers.target
EOF
echo "Timer créé : ${TIMER_PATH}"

# ----- reload systemd & enable ----------------------------------------
systemctl daemon-reload
systemctl enable --now flatten-modsec.timer
echo "Timer activé et démarré : flatten-modsec.timer"

# ----- ensure destination file exists with proper perms ---------------
if [ ! -e "${DST}" ]; then
  touch "${DST}"
  chown root:root "${DST}"
  chmod 644 "${DST}"
  echo "Fichier de destination créé : ${DST}"
fi

# ----- ajouter dans ossec.conf si absent --------------------------------
if [ -f "${OSSEC_CONF}" ]; then
  if ! grep -q "/var/log/modsec_flat.log" "${OSSEC_CONF}"; then
    # insertion avant la balise de fermeture </ossec_config>
    sed -i '/<\/ossec_config>/i \
  <localfile>\
    <log_format>json</log_format>\
    <location>/var/log/modsec_flat.log</location>\
  </localfile>' "${OSSEC_CONF}"
    echo "Entrée ajoutée à ${OSSEC_CONF} pour /var/log/modsec_flat.log"
    # redémarrer l'agent si présent
    if systemctl list-units --type=service --all | grep -q wazuh-agent; then
      systemctl restart wazuh-agent || true
      echo "wazuh-agent redémarré (si présent)"
    fi
  else
    echo "Configuration Wazuh déjà présente dans ${OSSEC_CONF} (pas de changement)."
  fi
else
  echo "Attention : ${OSSEC_CONF} introuvable. N'ajouté aucune config Wazuh."
fi

# ----- Affichage d'aide / vérification --------------------------------
echo
echo "✅ Installation terminée."
echo "Vérifications utiles :"
echo "  journalctl -u flatten-modsec.service --no-pager -n 20"
echo "  systemctl status flatten-modsec.timer --no-pager"
echo "  tail -n 5 ${DST}"
echo
echo "Si tu veux forcer une exécution immédiate :"
echo "  systemctl start flatten-modsec.service && tail -n 10 ${DST}"
echo
echo "Si le manager ne voit rien, vérifie côté agent :"
echo "  sudo tail -n 200 /var/ossec/logs/ossec.log | grep -E 'Analyzing file|modsec_flat|logcollector'"
echo
exit 0

