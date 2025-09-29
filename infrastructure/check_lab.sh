#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# check_lab.sh
# Vérifie montages déclarés dans labs/<lab>/docker-compose.yml
# Usage: ./check_lab.sh <lab_name>

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <lab_name>"
  exit 1
fi

LAB_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR/labs/$LAB_NAME"
COMPOSE_FILE="$LAB_DIR/docker-compose.yml"

CSI='\033['
RESET="${CSI}0m"
GREEN="${CSI}32m"
RED="${CSI}31m"
YELLOW="${CSI}33m"
BLUE="${CSI}34m"

log_info(){ echo -e "${BLUE}[INFO]${RESET} $*"; }
log_ok(){   echo -e "${GREEN}[ OK ]${RESET}  $*"; }
log_err(){  echo -e "${RED}[ERR ]${RESET} $*"; }
log_warn(){ echo -e "${YELLOW}[WARN]${RESET} $*"; }

# Basic checks
log_info "Vérification des fichiers de configuration..."
if [ ! -f "$COMPOSE_FILE" ]; then
  log_err "docker-compose absent : $COMPOSE_FILE"
  exit 1
fi
log_ok "docker-compose trouvé : $COMPOSE_FILE"

[ -f "$LAB_DIR/${LAB_NAME}.env" ] && log_ok ".env trouvé : $LAB_DIR/${LAB_NAME}.env" || log_warn ".env manquant : $LAB_DIR/${LAB_NAME}.env"
[ -f "$LAB_DIR/configs/ossec/ossec.conf" ] && log_ok "ossec.conf trouvé : $LAB_DIR/configs/ossec/ossec.conf" || log_warn "ossec.conf manquant : $LAB_DIR/configs/ossec/ossec.conf"
[ -f "$LAB_DIR/configs/wazuh-dashboard/opensearch_dashboards.yml" ] && log_ok "opensearch_dashboards.yml trouvé" || log_warn "opensearch_dashboards.yml manquant"

log_info "Vérification des montages déclarés dans $COMPOSE_FILE ..."
echo

# We only match lines that look like docker volume mounts starting with - ./ or - / (ignore env lines)
# grep with line numbers then parse safely in bash
grep -nE '^\s*-\s*(\./|/)' "$COMPOSE_FILE" || true | while IFS=: read -r lineno rawline; do
    # rawline contains the whole line, e.g. "    - ./labs/lab1/data/wazuh_manager:/var/ossec/data"
    # normalize: remove leading whitespace and leading '-'
    line="$(echo "$rawline" | sed -E 's/^[[:space:]]*-[[:space:]]*//')"

    # Extract host (before first ':') and container (after first ':')
    host_part="${line%%:*}"                # shortest substring before first colon
    container_part="${line#${host_part}:}" # rest after first colon (may contain more colons like :ro)

    # Trim spaces
    host_part="$(echo -n "$host_part" | xargs)"
    container_part="$(echo -n "$container_part" | xargs)"

    # If container_part begins with a colon (unlikely), strip
    container_part="${container_part#/:}"
    # Determine resolved host path
    if [[ "$host_part" == .* ]]; then
        # relative path -> interpret relative to SCRIPT_DIR (repo root)
        resolved_host="$SCRIPT_DIR/${host_part#./}"
    else
        resolved_host="$host_part"
    fi

    # Print info
    echo
    log_info "Ligne $lineno → $rawline"
    printf "    ↳ Host (déclaré)     : %s\n" "$host_part"
    printf "    ↳ Host (résolu)      : %s\n" "$resolved_host"
    printf "    ↳ Container (dest)   : %s\n" "$container_part"

    # Existence check
    if [ -e "$resolved_host" ]; then
        if [ -d "$resolved_host" ]; then
            log_ok "Présent sur l’hôte (dir) : $resolved_host"
        elif [ -f "$resolved_host" ]; then
            log_ok "Présent sur l’hôte (fichier) : $resolved_host"
        else
            log_ok "Présent sur l’hôte (autre type) : $resolved_host"
        fi
    else
        log_err "Manquant sur l’hôte : $resolved_host (attendu pour $container_part)"
        # give a hint for common permission issue
        if [ -d "$(dirname "$resolved_host")" ] && ! [ -w "$(dirname "$resolved_host")" ]; then
            log_warn "Le répertoire parent $(dirname "$resolved_host") n'est peut-être pas inscriptible : problème de permissions."
        fi
    fi
done

echo
log_info "Contrôle terminé pour $LAB_NAME."
