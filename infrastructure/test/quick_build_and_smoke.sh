#!/bin/bash
set -euo pipefail
# build attacker + bastion (adjust paths)
docker build -t lab_attacker:latest ./infrastructure/labs/attacker
docker build -t lab_bastion:latest ./infrastructure/labs/bastion

# start only the secure compose but limit to lab1 for a quick smoke:
docker compose -f infrastructure/docker-compose.secure.yml up -d lab1_elasticsearch lab1_kibana lab1_wazuh lab1_mariadb lab1_dvwa lab1_attacker lab_bastion

sleep 20
docker ps --filter name=lab1_ -a
# quick test: attempt to curl lab1_kibana from bastion (via docker exec)
docker exec -it lab_bastion curl -sS http://lab1_kibana:5601 || echo "curl failed (maybe Kibana not ready yet)"

# teardown
docker compose -f infrastructure/docker-compose.secure.yml down -v
