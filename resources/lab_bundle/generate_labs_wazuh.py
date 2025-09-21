#!/usr/bin/env python3
import os, argparse, subprocess, shutil, textwrap, json

COMPOSE_TEMPLATE = json.loads("version: \"3.8\"\nservices:\n  elasticsearch:\n    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0\n    container_name: lab{g}_elasticsearch\n    environment:\n      - discovery.type=single-node\n      - ES_JAVA_OPTS=-Xms512m -Xmx512m\n    ulimits:\n      memlock:\n        soft: -1\n        hard: -1\n    volumes:\n      - lab{g}_esdata:/usr/share/elasticsearch/data\n    networks:\n      - labnet{g}\n\n  kibana:\n    image: docker.elastic.co/kibana/kibana:8.8.0\n    container_name: lab{g}_kibana\n    environment:\n      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200\n    ports:\n      - \"{kibana_port}:5601\"\n    networks:\n      - labnet{g}\n\n  wazuh:\n    image: wazuh/wazuh:4.4.0\n    container_name: lab{g}_wazuh\n    depends_on:\n      - elasticsearch\n    environment:\n      - ELASTICSEARCH_URL=http://elasticsearch:9200\n    networks:\n      - labnet{g}\n\n  mariadb:\n    image: mariadb:10.6\n    container_name: lab{g}_mariadb\n    restart: always\n    environment:\n      MYSQL_ROOT_PASSWORD: rootpass\n      MYSQL_DATABASE: dvwa\n      MYSQL_USER: dvwa\n      MYSQL_PASSWORD: dvwa\n    networks:\n      - labnet{g}\n\n  dvwa:\n    image: vulnerables/web-dvwa:latest\n    container_name: lab{g}_dvwa\n    depends_on:\n      - mariadb\n    environment:\n      - MYSQL_HOST=mariadb\n    ports:\n      - \"{dvwa_port}:80\"\n    networks:\n      - labnet{g}\n\n  attacker:\n    image: lab_attacker:latest\n    container_name: lab{g}_attacker\n    command: sleep infinity\n    volumes:\n      - ./attacks:/opt/attacks:ro\n    networks:\n      - labnet{g}\n\nnetworks:\n  labnet{g}:\n    driver: bridge\n    ipam:\n      config:\n        - subnet: 172.18.{g}.0/24\n\nvolumes:\n  lab{g}_esdata:\n")

def run(cmd, cwd=None):
    print("+", " ".join(cmd))
    subprocess.check_call(cmd, cwd=cwd)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--count", type=int, default=3, help="nombre de labos")
    p.add_argument("--output", default="labs", help="répertoire de sortie")
    args = p.parse_args()

    os.makedirs(args.output, exist_ok=True)
    attacks_src = os.path.join(os.path.dirname(__file__), "attacker", "attacks")
    if not os.path.isdir(attacks_src):
        raise SystemExit("Crée le dossier attacker/attacks avec les scripts d'attaque avant d'exécuter.")

    for g in range(1, args.count+1):
        labdir = os.path.join(args.output, f"lab{g}")
        os.makedirs(labdir, exist_ok=True)
        kibana_port = 5600 + g
        dvwa_port = 8080 + g
        subnet = f"172.18.{g}.0/24"
        compose = COMPOSE_TEMPLATE.format(g=g, kibana_port=kibana_port, dvwa_port=dvwa_port)
        with open(os.path.join(labdir, "docker-compose.yml"), "w") as f:
            f.write(compose)
        # copy attacks dir
        dst_attacks = os.path.join(labdir, "attacks")
        if os.path.isdir(dst_attacks):
            shutil.rmtree(dst_attacks)
        shutil.copytree(attacks_src, dst_attacks)
        # create network
        netname = f"labnet{g}"
        try:
            run(["docker", "network", "create", "--driver", "bridge", "--subnet", subnet, netname])
        except subprocess.CalledProcessError:
            print("network maybe exists:", netname)
        # start compose
        try:
            run(["docker", "compose", "-p", f"lab{g}", "up", "-d"], cwd=labdir)
        except subprocess.CalledProcessError as e:
            print("compose up failed for", labdir, e)
    print(f"Finished: {args.count} labs created under {args.output}")

if __name__ == "__main__":
    main()
