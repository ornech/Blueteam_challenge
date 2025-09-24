#!/usr/bin/env bash
# Nginx reverse proxy handling

ensure_proxy() {
    local PROXY_CONTAINER="nginx_reverse_proxy"

    log_info "Vérification du conteneur proxy $PROXY_CONTAINER..."
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}\$"; then
        log_warn "Proxy absent → lancement via $PROXY_COMPOSE_FILE"
        docker compose -f "$PROXY_COMPOSE_FILE" up -d
    elif ! docker inspect -f '{{.State.Running}}' $PROXY_CONTAINER | grep -q true; then
        log_warn "Proxy présent mais arrêté → démarrage"
        docker start $PROXY_CONTAINER
    else
        log_ok "Proxy déjà en cours d'exécution"
    fi
}

reload_proxy_nginx() {
    local PROXY_CONTAINER="nginx_reverse_proxy"
    log_info "Reload Nginx dans $PROXY_CONTAINER..."
    if docker inspect -f '{{.State.Running}}' $PROXY_CONTAINER | grep -q true; then
        docker exec -i $PROXY_CONTAINER nginx -t >/dev/null 2>&1 \
        && docker exec -i $PROXY_CONTAINER nginx -s reload \
        && log_ok "Nginx rechargé" \
        || log_warn "Erreur dans la config Nginx (reload annulé)"
    fi
}
