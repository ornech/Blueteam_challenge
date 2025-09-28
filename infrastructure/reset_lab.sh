#!/usr/bin/env bash
# reset_lab.sh - Stoppe un lab, nettoie volumes/docker et supprime le dossier labs/<lab>
# Usage: ./reset_lab.sh <lab_name> [--force] [--purge-network]
set -euo pipefail

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

if [ $# -lt 1 ]; then
  echo "Usage: $0 <lab_name> [--force] [--purge-network]"
  exit 1
fi

LAB_NAME="$1"
shift || true

FORCE=false
PURGE_NET=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --purge-network) PURGE_NET=true ;;
    *) log_warn "Unknown option: $arg" ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR/labs/$LAB_NAME"
COMPOSE_FILE_CAND1="$LAB_DIR/docker-compose.yml"
COMPOSE_FILE_CAND2="$SCRIPT_DIR/docker-compose-${LAB_NAME}.yml"
COMPOSE_FILE=""

if [ -f "$COMPOSE_FILE_CAND1" ]; then
  COMPOSE_FILE="$COMPOSE_FILE_CAND1"
elif [ -f "$COMPOSE_FILE_CAND2" ]; then
  COMPOSE_FILE="$COMPOSE_FILE_CAND2"
fi

if [ ! -d "$LAB_DIR" ]; then
  log_warn "Répertoire du labo introuvable : $LAB_DIR"
  exit 1
fi

echo
log_warn "ATTENTION : ceci arrêtera et supprimera le lab '$LAB_NAME'."
if [ "$FORCE" = false ]; then
  read -p "Confirmer suppression complète de '$LAB_NAME' ? (o/N) " confirm
  case "$confirm" in
    [oO]|[yY]) ;;
    *) log_info "Annulation."; exit 0 ;;
  esac
fi

# 1) Stopper docker-compose si possible
if [ -n "$COMPOSE_FILE" ]; then
  log_info "Arrêt avec docker-compose : $COMPOSE_FILE"
  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || {
    log_warn "Échec docker compose down (continuation...)"
  }
else
  log_warn "Aucun fichier docker-compose trouvé pour '$LAB_NAME' (vérifier $COMPOSE_FILE_CAND1 et $COMPOSE_FILE_CAND2). On tente d'arrêter les conteneurs par nom."
fi

# 2) Supprimer les conteneurs nommés (prudent)
containers=$(docker ps -a --format '{{.Names}}' | grep -E "^${LAB_NAME}_" || true)
if [ -n "$containers" ]; then
  log_info "Suppression conteneurs: $containers"
  docker rm -f $containers || log_warn "Impossible de supprimer certains conteneurs (peut-être déjà supprimés)."
else
  log_info "Aucun conteneur ${LAB_NAME}_* trouvé."
fi

# 3) Supprimer volumes Docker orphelins et spécifiques si nommés
log_info "Nettoyage des volumes orphelins Docker (docker volume prune)..."
docker volume prune -f || log_warn "Échec prune volumes (continuer)."

# Optionnel: suppression réseau créé par compose
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-blueteam}"
NET_NAME="${COMPOSE_PROJECT_NAME}_${LAB_NAME}_net"
if [ "$PURGE_NET" = true ]; then
  if docker network inspect "$NET_NAME" >/dev/null 2>&1; then
    log_info "Suppression réseau: $NET_NAME"
    docker network rm "$NET_NAME" || log_warn "Impossible de supprimer le réseau $NET_NAME"
  else
    log_info "Réseau $NET_NAME absent."
  fi
else
  log_info "Réseau $NET_NAME conservé (passer --purge-network pour le supprimer)."
fi

# 4) Fix permissions récursifs sur le dossier labs/<lab> pour permettre suppression
log_info "Réaffectation des fichiers à l'utilisateur $(id -un) pour pouvoir supprimer : $LAB_DIR"
sudo chown -R "$(id -u):$(id -g)" "$LAB_DIR" || log_warn "Impossible de changer propriétaire (permission?)."

# 5) Suppression effective du répertoire labs/<lab>
log_info "Suppression du dossier $LAB_DIR"
sudo rm -rf "$LAB_DIR" || {
  log_error "Échec suppression $LAB_DIR. Vérifier permissions."
  exit 1
}

log_ok "Dossier $LAB_DIR supprimé."

# 6) Cleanup final (optionnel)
log_info "Vérification : conteneurs restants portant le préfixe ${LAB_NAME}_"
docker ps -a --format '{{.Names}}' | grep -E "^${LAB_NAME}_" || log_info "Aucun conteneur restant."

log_ok "Reset du lab '$LAB_NAME' terminé."
