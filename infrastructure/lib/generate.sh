#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Nom du script : create_lab.sh
# Auteur : Jean-Francois Ornech '@ornech'
# Description : Génère les fichiers nécessaires pour un labo (fichier .env, docker-compose, conf Nginx, certificats)
# Usage : ./create_lab.sh <lab_name>

generate_env() {
    local LAB_NAME="$1"
    local LAB_NUM=$(echo "$LAB_NAME" | grep -o '[0-9]*$' || echo "1")
    local ENV_FILE="${ENV_DIR}/${LAB_NAME}.env"

    if [ -f "$ENV_FILE" ]; then
        log_warn "$ENV_FILE existe déjà"
        return
    fi

    log_info "Génération du fichier .env pour $LAB_NAME..."
    cat > "$ENV_FILE" <<EOF
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
LAB_NAME=${LAB_NAME}
LAB_SUBNET=172.30.${LAB_NUM}.0/24
WAZUH_PORT_1514=$((1500 + LAB_NUM))
WAZUH_PORT_1515=$((1510 + LAB_NUM))
WAZUH_PORT_55000=$((55000 + LAB_NUM))
WAZUH_PORT_5601=$((5600 + LAB_NUM))
EOF
    log_ok ".env généré : $ENV_FILE"
}

generate_fileossec() {
    local LAB_NAME="$1"
    local FILEOSSEC_DIR="$SCRIPT_DIR/configs/${LAB_NAME}/ossec"
    local FILEOSSEC_FILE="$FILEOSSEC_DIR/ossec.conf"

    mkdir -p "$FILEOSSEC_DIR"

    if [ -f "$FILEOSSEC_FILE" ]; then
        log_warn "$FILEOSSEC_FILE existe déjà"
        return
    fi

    log_info "Génération du fichier ossec.conf pour $LAB_NAME..."
    cat > "$FILEOSSEC_FILE" <<EOF
<ossec_config>
  <wazuh_db>
    <indexer>
      <enabled>yes</enabled>
      <hosts>
        <host>http://${LAB_NAME}_wazuh_indexer:9200</host>
      </hosts>
      <user>admin</user>
      <password>admin</password>
      <ssl>
        <verify_peer>no</verify_peer>
      </ssl>
    </indexer>
  </wazuh_db>
</ossec_config>
EOF

    sudo chown root:root "$FILEOSSEC_FILE"
    sudo chmod 644 "$FILEOSSEC_FILE"

    log_ok "$FILEOSSEC_FILE généré"
}




generate_compose() {
    local LAB_NAME="$1"
    local COMPOSE_FILE="$SCRIPT_DIR/docker-compose-${LAB_NAME}.yml"

    log_info "Génération docker-compose pour $LAB_NAME..."
    export LAB_NAME COMPOSE_PROJECT_NAME
    envsubst < "$COMPOSE_TEMPLATE" > "$COMPOSE_FILE"
    log_ok "docker-compose généré : $COMPOSE_FILE"
}

generate_nginx_conf() {
    local LAB_NAME="$1"
    local NGINX_FILE="/etc/nginx/conf.d/${LAB_NAME}.conf"   # <--- direct host

    log_info "Génération config Nginx pour $LAB_NAME..."
    sudo tee "$NGINX_FILE" >/dev/null <<EOF
server {
    listen 80;
    server_name dvwa.${LAB_NAME}.local;

    location / {
        proxy_pass http://${LAB_NAME}_dvwa:80;
    }
}

server {
    listen 80;
    server_name wazuh.${LAB_NAME}.local;

    location / {
        proxy_pass https://${LAB_NAME}_wazuh_dashboard:5601;
        proxy_ssl_verify off;
    }
}
EOF
    log_ok "Nginx conf générée : $NGINX_FILE"
}

generate_certs() {
    local LAB_NAME="$1"
    local CERTS_DIR="$SCRIPT_DIR/certs/${LAB_NAME}"
    local CERTS_YML="$CERTS_DIR/certs.yml"

    if [ -f "$CERTS_DIR/root-ca.pem" ]; then
        log_ok "Certificats déjà présents pour $LAB_NAME → on les réutilise"
        return
    fi

    log_info "Génération des certificats pour $LAB_NAME..."

    # Créer un certs.yml minimal si absent
    if [ ! -f "$CERTS_YML" ]; then
        cat > "$CERTS_YML" <<EOF
nodes:
  - name: ${LAB_NAME}_wazuh_indexer
    dns:
      - ${LAB_NAME}_wazuh_indexer
      - localhost
EOF
        log_info "Fichier certs.yml généré : $CERTS_YML"
    fi

    # Lancer le conteneur générateur
    docker run --rm \
        -v "$CERTS_DIR:/certificates" \
        -v "$CERTS_YML:/config/certs.yml" \
        wazuh-indexer-certs >/dev/null 2>&1

    if [ -f "$CERTS_DIR/root-ca.pem" ]; then
        log_ok "Certificats générés avec succès dans $CERTS_DIR"
    else
        log_error "Échec de génération des certificats pour $LAB_NAME"
        exit 1
    fi
}
