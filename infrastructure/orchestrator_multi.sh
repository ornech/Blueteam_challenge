#!/bin/bash
SCEN=${1:?scenario}
LABS=${2:-all}

if [ "$LABS" = "all" ]; then
  LABS=$(docker ps --format '{{.Names}}' | grep '_attacker$' | sed -E 's/lab([0-9]+)_attacker/\1/' | tr '\n' ',' | sed 's/,$//')
fi
IFS=',' read -ra ARRLABS <<< "$LABS"
for g in "${ARRLABS[@]}"; do
  c="lab${g}_attacker"
  if ! docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
    echo "attacker container $c not found, skipping"
    continue
  fi
  case "$SCEN" in
    ssh_fail)
      docker exec -d "$c" /bin/bash -lc "/opt/attacks/simulate_ssh_failures.sh 10.10.${g}.10 40"
      ;;
    nmap)
      docker exec -d "$c" /bin/bash -lc "/opt/attacks/simulate_nmap_scan.sh 10.10.${g}.10"
      ;;
    sqlmap)
      docker exec -d "$c" /bin/bash -lc "/opt/attacks/simulate_sqlmap.sh 'http://10.10.${g}.20/DVWA/vulnerabilities/sqli/?id=1&Submit=Submit'"
      ;;
    web_upload)
      docker exec -d "$c" /bin/bash -lc "/opt/attacks/simulate_web_upload.sh 'http://10.10.${g}.20/DVWA/vulnerabilities/upload/' uploaded marker.php"
      ;;
    dns_exfil)
      docker exec -d "$c" /bin/bash -lc "/opt/attacks/simulate_dns_exfil.sh exfil.test.local 'group${g}-DATA'"
      ;;
    *)
      echo "unknown scenario $SCEN"
      ;;
  esac
  echo "Launched $SCEN on lab $g"
done
