Lab bundle for Wazuh-per-lab setup (3 labs example)

Structure:
- generate_labs_wazuh.py  -- generator that creates labs/lab{N}/docker-compose.yml and starts them
- attacker/Dockerfile      -- image to build for attacker containers
- attacker/attacks/*.sh   -- attack scripts used by orchestrator
- orchestrator_multi.sh   -- launches scenarios on labs
- reset_all.sh            -- stops all labs and removes networks

Quick start (on a Linux host with docker & docker-compose):
1) Build attacker image:
   cd attacker
   docker build -t lab_attacker:latest .

2) Generate labs (creates labs/ and starts them):
   python3 generate_labs_wazuh.py --count 3

3) Trigger an attack on lab 1:
   ./orchestrator_multi.sh web_upload 1

4) Reset everything:
   ./reset_all.sh

Warnings:
- This setup runs multiple Elasticsearch instances and Kibana; they consume RAM.
- Run on an isolated host (no connection to production).
- For production use, secure Kibana with auth and enable TLS.
