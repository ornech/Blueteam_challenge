#!/usr/bin/env bash
# Clean old containers/volumes for a lab

cleanup_lab() {
    local LAB_NAME="$1"

    log_info "Nettoyage anciens conteneurs pour $LAB_NAME..."
    local old_containers=$(docker ps -a --format '{{.Names}}' | grep "^${LAB_NAME}_" || true)
    for c in $old_containers; do
        docker rm -f "$c" >/dev/null 2>&1 && log_ok "Supprimé $c"
    done

    local old_volumes=$(docker volume ls --format '{{.Name}}' | grep "^${LAB_NAME}_" || true)
    for v in $old_volumes; do
        docker volume rm "$v" >/dev/null 2>&1 && log_ok "Supprimé volume $v"
    done
}
