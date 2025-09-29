#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Nom du script : generate.sh
# Auteur : Jean-Francois Ornech '@ornech'
# Description : Génère les fichiers nécessaires pour un labo (arbo par conteneur)

generate_env() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local LAB_NUM=$(echo "$LAB_NAME" | grep -o '[0-9]*$' || echo "1")
    local ENV_FILE="$LAB_DIR/${LAB_NAME}.env"

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
    local LAB_DIR="$2"
    local FILE="$LAB_DIR/wazuh_manager/config/ossec.conf"

    if [ -f "$FILE" ]; then
        log_warn "$FILE existe déjà"
        return
    fi

    log_info "Génération du fichier ossec.conf pour $LAB_NAME..."
    cat > "$FILE" <<EOF
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

    chmod 644 "$FILE"
    log_ok "$FILE généré"
}

generate_opensearch_disable_security() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local FILE="$LAB_DIR/wazuh_indexer/config/opensearch-disable-security.yml"

    if [ -f "$FILE" ]; then
        log_warn "$FILE existe déjà"
        return
    fi

    log_info "Désactivation du plugin security pour $LAB_NAME..."
    cat > "$FILE" <<EOF
cluster.name: wazuh-indexer
path.data: /var/lib/wazuh-indexer
plugins.security.disabled: true
network.host: 0.0.0.0
discovery.type: single-node
EOF

    chmod 644 "$FILE"
    log_ok "$FILE généré"
}


generate_dashboard_conf() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local CONF_DIR="$LAB_DIR/wazuh_dashboard/config"

    if [ -f "$CONF_DIR/opensearch_dashboards.yml" ]; then
        log_warn "$CONF_DIR/opensearch_dashboards.yml existe déjà"
        return
    fi

    log_info "Génération de la config Wazuh Dashboard pour $LAB_NAME..."
    cat > "$CONF_DIR/opensearch_dashboards.yml" <<YML
server.host: "0.0.0.0"
server.port: 5601
opensearch.hosts: ["http://${LAB_NAME}_wazuh_indexer:9200"]
opensearch.ssl.verificationMode: "none"
opensearch.requestHeadersAllowlist: ["securitytenant","Authorization"]
YML

    touch "$CONF_DIR/opensearch_dashboards.keystore"
    chmod 644 "$CONF_DIR/opensearch_dashboards.yml"
    chmod 660 "$CONF_DIR/opensearch_dashboards.keystore"

    log_ok "Config Dashboard générée dans $CONF_DIR"
}

generate_compose() {
    local LAB_NAME="$1"
    local TEMPLATE="$2"
    local OUTPUT="$3"

    log_info "Génération docker-compose pour $LAB_NAME..."
    export LAB_NAME COMPOSE_PROJECT_NAME
    envsubst < "$TEMPLATE" > "$OUTPUT"
    log_ok "docker-compose généré : $OUTPUT"
}

generate_nginx_conf() {
    local LAB_NAME="$1"
    local NGINX_FILE="$2/${LAB_NAME}.conf"

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
        proxy_pass http://${LAB_NAME}_wazuh_dashboard:5601;
        proxy_ssl_verify off;
    }
}
EOF
    log_ok "Nginx conf générée : $NGINX_FILE"
}

generate_certs() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local CERTS_DIR="$LAB_DIR/common"          # <-- PAS $LAB_DIR/certs/common
    local CERTS_YML="$CERTS_DIR/certs.yml"

    if [ -f "$CERTS_DIR/root-ca.pem" ]; then
        log_ok "Certificats déjà présents pour $LAB_NAME → on les réutilise"
        # ensure symlinks exist
        ln -sfn ../common "$LAB_DIR/wazuh_manager/certs"
        ln -sfn ../common "$LAB_DIR/wazuh_indexer/certs"
        ln -sfn ../common "$LAB_DIR/wazuh_dashboard/certs"
        return
    fi

    log_info "Génération des certificats pour $LAB_NAME..."
    mkdir -p "$CERTS_DIR"

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

    docker run --rm \
        -v "$CERTS_DIR:/certificates" \
        -v "$CERTS_YML:/config/certs.yml" \
        wazuh-indexer-certs >/dev/null 2>&1

    if [ -f "$CERTS_DIR/root-ca.pem" ]; then
        log_ok "Certificats générés avec succès dans $CERTS_DIR"
        ln -sfn ../common "$LAB_DIR/wazuh_manager/certs"
        ln -sfn ../common "$LAB_DIR/wazuh_indexer/certs"
        ln -sfn ../common "$LAB_DIR/wazuh_dashboard/certs"
    else
        log_error "Échec de génération des certificats pour $LAB_NAME"
        exit 1
    fi
}
