#!/usr/bin/env bash
# Network handling

ensure_lab_network() {
    local LAB_NAME="$1"
    local LAB_NUM=$(echo "$LAB_NAME" | grep -o '[0-9]*$' || echo "1")
    local BASE_SUBNET=30
    local LAB_SUBNET="172.${BASE_SUBNET}.${LAB_NUM}.0/24"
    local FULL_NET_NAME="${COMPOSE_PROJECT_NAME}_${LAB_NAME}_net"
    local EXPECTED_COMPOSE_NETWORK_LABEL="${LAB_NAME}_net"

    log_info "Réseau attendu pour le lab : ${FULL_NET_NAME} (subnet=${LAB_SUBNET})."

    if ! docker network inspect "$FULL_NET_NAME" >/dev/null 2>&1; then
        log_info "Création du réseau $FULL_NET_NAME..."
        docker network create \
            --driver bridge \
            --subnet "$LAB_SUBNET" \
            --label "com.docker.compose.project=${COMPOSE_PROJECT_NAME}" \
            --label "com.docker.compose.network=${EXPECTED_COMPOSE_NETWORK_LABEL}" \
            "$FULL_NET_NAME" >/dev/null 2>&1 \
        && log_ok "Réseau $FULL_NET_NAME créé" \
        || log_error "Impossible de créer le réseau $FULL_NET_NAME"
    else
        log_ok "Réseau $FULL_NET_NAME déjà présent"
    fi
}
