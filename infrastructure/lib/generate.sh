#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Nom : generate.sh
# Desc: Génère les fichiers du labo (env, Wazuh manager, OpenSearch, Filebeat 8.x)

generate_env() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local LAB_NUM
    LAB_NUM=$(echo "$LAB_NAME" | grep -o '[0-9]*$' || echo "1")
    local ENV_FILE="$LAB_DIR/${LAB_NAME}.env"

    if [ -f "$ENV_FILE" ]; then
        log_warn "$ENV_FILE existe déjà"
        return
    fi

    log_info "Génération du fichier .env pour $LAB_NAME..."
    cat > "$ENV_FILE" <<EOF
COMPOSE_PROJECT_NAME=\${COMPOSE_PROJECT_NAME}
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
  <global>
    <jsonout_output>yes</jsonout_output>
    <alerts_log>yes</alerts_log>
  </global>

  <remote>
    <connection>secure</connection>
    <port>1514</port>
    <protocol>udp</protocol>
  </remote>

  <indexer>
    <enabled>yes</enabled>
    <hosts>
      <host>http://${LAB_NAME}_wazuh_indexer:9200</host>
    </hosts>
  </indexer>
</ossec_config>
EOF

    chmod 644 "$FILE"
    log_ok "$FILE généré"
}

generate_opensearch_disable_security() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local FILE="$LAB_DIR/wazuh_indexer/config/opensearch.yml"

    mkdir -p "$LAB_DIR/wazuh_indexer/config"

    if [ -f "$FILE" ]; then
        log_warn "$FILE existe déjà"
        return
    fi

    log_info "Génération de la config OpenSearch (security OFF) pour $LAB_NAME..."
    cat > "$FILE" <<EOF
cluster.name: wazuh
node.name: ${LAB_NAME}_wazuh_indexer
path.data: /var/lib/wazuh-indexer
network.host: 0.0.0.0
discovery.type: single-node

# Désactive complètement le plugin de sécurité (sinon il tente de lire /etc/wazuh-indexer/certs)
plugins.security.disabled: true
EOF

    chmod 644 "$FILE"
    log_ok "OpenSearch config générée : $FILE"
}

generate_filebeat_config() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local FILE="$LAB_DIR/filebeat/filebeat.yml"

    mkdir -p "$LAB_DIR/filebeat"

    if [ -f "$FILE" ]; then
        log_warn "$FILE existe déjà"
        return
    fi

    log_info "Génération du filebeat.yml (Filebeat 8.x standalone) pour $LAB_NAME..."
    cat > "$FILE" <<EOF
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/ossec/logs/alerts/alerts.json
    json.keys_under_root: true
    json.add_error_key: true

setup.ilm.enabled: false

output.elasticsearch:
  hosts: ["http://${LAB_NAME}_wazuh_indexer:9200"]
  username: "admin"
  password: "admin"

logging.metrics.enabled: false
EOF

    # Filebeat 8 exige root:root et 0644
    sudo chown 0:0 "$FILE" 2>/dev/null || true
    chmod 644 "$FILE"
    log_ok "Config Filebeat générée : $FILE"
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
