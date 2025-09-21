# Infrastructure labs (Wazuh-per-lab)

Contenu :
- labs/ (généré) : dossiers lab1, lab2, lab3 si generate_labs utilisé
- docker-compose.secure.yml : compose unique avec bastion (Option A)
- attacker/ : builder image attacker + scripts d'attaque
- bastion/ : Dockerfile + README pour jump-host
- orchestrator_multi.sh : orchestration d'attaques
- reset_all.sh : nettoyage

Quick start (dev):
1. Build attacker & bastion images:
   docker build -t lab_attacker:latest ./infrastructure/labs/attacker
   docker build -t lab_bastion:latest ./infrastructure/labs/bastion

2. Launch compose (secure):
   docker compose -f infrastructure/docker-compose.secure.yml up -d

3. Use bastion tunnels for Kibana/DVWA:
   ssh -p 2222 root@127.0.0.1 -L 5601:lab1_kibana:5601 -N

Notes:
- Run on an isolated host.
- See bastion/README.md for details.
