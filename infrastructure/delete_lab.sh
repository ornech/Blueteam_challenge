#!/usr/bin/env bash
set -euo pipefail
# delete_lab.sh - Supprime un labo et ses ressources (conteneurs, volumes, fichiers, conf Nginx)

# -------- Logging utils --------
CSI='\033['
RESET="${CSI}0m"
GREEN="${CSI}32m"
YELLOW="${CSI}33m"
RED="${CSI}31m"
BLUE="${CSI}34m"

log_info(){ echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_ok(){   echo -e "${GREEN}[ OK ]${RESET}  $*"; }
log_warn(){ echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error(){ echo -e "${RED}[ERR ]${RESET}  $*" >&2; }

# -------- Args --------
if [ $# -lt 1 ]; then
  echo "Usage: $0 <lab_name> [--purge-network]"
  exit 1
fi

LAB_NAME="$1"
PURGE_NET="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/envs"
DATA_DIR="$SCRIPT_DIR/data"
NGINX_CONF_DIR="$SCRIPT_DIR/nginx/conf.d"

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-blueteam}"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose-${LAB_NAME}.yml"
ENV_FILE="${ENV_DIR}/${LAB_NAME}.env"
NGINX_FILE="${NGINX_CONF_DIR}/${LAB_NAME}.conf"
FULL_NET_NAME="${COMPOSE_PROJECT_NAME}_${LAB_NAME}_net"

# -------- Delete containers --------
log_info "Arrêt et suppression des conteneurs pour $LAB_NAME..."
containers=$(docker ps -a --format '{{.Names}}' | grep "^${LAB_NAME}_" || true)
if [ -n "$containers" ]; then
  docker rm -f $containers >/dev/null 2>&1 || true
  log_ok "Conteneurs supprimés : $containers"
else
  log_info "Aucun conteneur trouvé pour $LAB_NAME."
fi

# -------- Delete volumes --------
log_info "Suppression des volumes liés à $LAB_NAME..."
volumes=$(docker volume ls --format '{{.Name}}' | grep "^${LAB_NAME}_" || true)
if [ -n "$volumes" ]; then
  docker volume rm $volumes >/dev/null 2>&1 || true
  log_ok "Volumes supprimés : $volumes"
else
  log_info "Aucun volume trouvé pour $LAB_NAME."
fi

# -------- Delete files --------
if [ -f "$COMPOSE_FILE" ]; then
  rm -f "$COMPOSE_FILE"
  log_ok "Fichier docker-compose supprimé : $COMPOSE_FILE"
fi
if [ -f "$ENV_FILE" ]; then
  rm -f "$ENV_FILE"
  log_ok "Fichier env supprimé : $ENV_FILE"
fi
if [ -d "$DATA_DIR/$LAB_NAME" ]; then
  rm -rf "$DATA_DIR/$LAB_NAME"
  log_ok "Répertoire data supprimé : $DATA_DIR/$LAB_NAME"
fi
if [ -f "$NGINX_FILE" ]; then
  rm -f "$NGINX_FILE"
  log_ok "Config Nginx supprimée : $NGINX_FILE"
fi

# -------- Purge network (optional) --------
if [ "$PURGE_NET" == "--purge-network" ]; then
  if docker network inspect "$FULL_NET_NAME" >/dev/null 2>&1; then
    docker network rm "$FULL_NET_NAME" >/dev/null 2>&1 || true
    log_ok "Réseau supprimé : $FULL_NET_NAME"
  else
    log_info "Réseau $FULL_NET_NAME non trouvé (déjà supprimé ?)."
  fi
else
  log_info "Réseau $FULL_NET_NAME conservé (utiliser --purge-network pour le supprimer)."
fi

log_ok "Lab $LAB_NAME supprimé."
