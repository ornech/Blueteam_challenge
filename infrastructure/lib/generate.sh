#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Génère les fichiers nécessaires pour un labo

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

generate_dashboard_conf() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local FILE="$LAB_DIR/wazuh_dashboard/config/opensearch_dashboards.yml"

    mkdir -p "$LAB_DIR/wazuh_dashboard/config"

    cat > "$FILE" <<YML
server.host: "0.0.0.0"
server.port: 5601

opensearch.hosts: ["http://${LAB_NAME}_wazuh_indexer:9200"]
opensearch.ssl.verificationMode: "none"

# Auth par défaut (admin/admin)
opensearch.username: "admin"
opensearch.password: "admin"

# Permet à Wazuh APP de passer des headers
opensearch.requestHeadersAllowlist: ["securitytenant","Authorization"]

# Wazuh app settings
wazuh.manager: "https://${LAB_NAME}_wazuh_manager:55000"
wazuh.username: "admin"
wazuh.password: "SecretPass123"
YML

    chmod 644 "$FILE"
    log_ok "$FILE généré"
}



generate_fileossec() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local FILE="$LAB_DIR/wazuh_manager/config/ossec.conf"

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

    cat > "$FILE" <<EOF
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
    local FILE="$LAB_DIR/wazuh_dashboard/config/opensearch_dashboards.yml"

    mkdir -p "$LAB_DIR/wazuh_dashboard/config"

    cat > "$FILE" <<YML
server.host: "0.0.0.0"
server.port: 5601
opensearch.hosts: ["http://${LAB_NAME}_wazuh_indexer:9200"]
opensearch.ssl.verificationMode: "none"
opensearch.requestHeadersAllowlist: ["securitytenant","Authorization"]

YML

    chmod 644 "$FILE"
    log_ok "$FILE généré"
}

generate_compose() {
    local LAB_NAME="$1"
    local TEMPLATE="$2"
    local OUTPUT="$3"
    export LAB_NAME COMPOSE_PROJECT_NAME
    envsubst < "$TEMPLATE" > "$OUTPUT"
    log_ok "docker-compose généré : $OUTPUT"
}

generate_nginx_conf() {
    local LAB_NAME="$1"
    local FILE="$2/${LAB_NAME}.conf"

    sudo tee "$FILE" >/dev/null <<EOF
server {
    listen 80;
    server_name dvwa.${LAB_NAME}.local;
    location / { proxy_pass http://127.0.0.1:8080; }   # <-- port publié DVWA
}
server {
    listen 80;
    server_name wazuh.${LAB_NAME}.local;
    location / { proxy_pass http://127.0.0.1:\${WAZUH_PORT_5601}; proxy_ssl_verify off; }  # <-- port publié Dashboard
}
EOF
    log_ok "Nginx conf générée : $FILE"
}



generate_certs() { :; } # inchangé

generate_fluentbit_config() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local DIR="$LAB_DIR/fluentbit"

    mkdir -p "$DIR"

    # Config Fluent Bit
    cat > "$DIR/fluent-bit.conf" <<EOF
[SERVICE]
    Flush        1
    Daemon       Off
    Log_Level    debug
    Parsers_File parsers.conf

[INPUT]
    Name   tail
    Path   /var/ossec/logs/alerts/alerts.json
    Tag    wazuh.alerts
    Parser json
    Read_From_Head On
    Skip_Long_Lines On

[FILTER]
    Name   modify
    Match  wazuh.alerts
    Rename log message

[OUTPUT]
    Name   opensearch
    Match  *
    Host   ${LAB_NAME}_wazuh_indexer
    Port   9200
    Index  wazuh-alerts
    Suppress_Type_Name On
    Replace_Dots On

[OUTPUT]
    Name   stdout
    Match  *
    Format json_lines

EOF

    # Parser JSON
    cat > "$DIR/parsers.conf" <<EOF
[PARSER]
    Name        json
    Format      json
    Time_Key    timestamp
    Time_Format %Y-%m-%dT%H:%M:%S.%L%z
    Time_Keep   On
    Decode_Field_As   json message
EOF

    chmod 644 "$DIR"/*.conf
    log_ok "Fluent Bit configs générés : $DIR"
}




generate_disable_filebeat() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local FILE="$LAB_DIR/wazuh_manager/config/disable-filebeat.sh"

    cat > "$FILE" <<EOF
#!/bin/sh
exit 0
EOF
    chmod +x "$FILE"
    log_ok "Script disable-filebeat généré : $FILE"
}

fix_perms_filebeat() { :; } # inchangé

generate_opensearch_template() {
    local LAB_NAME="$1"
    local LAB_DIR="$2"
    local FILE="$LAB_DIR/wazuh_indexer/config/wazuh-alerts-template.json"

    mkdir -p "$LAB_DIR/wazuh_indexer/config"

    cat > "$FILE" <<EOF
{
  "index_patterns": ["wazuh-alerts*"],
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  },
  "mappings": {
    "properties": {
      "timestamp": { "type": "date", "format": "strict_date_optional_time||epoch_millis" },
      "rule":      { "type": "object" },
      "agent":     { "type": "object" },
      "manager":   { "type": "object" },
      "data":      { "type": "object" },
      "message":   { "type": "text" }
    }
  }
}
EOF

    chmod 644 "$FILE"
    log_ok "Template OpenSearch généré : $FILE"
}
