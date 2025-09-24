#!/usr/bin/env bash
# Logging helpers with colors

CSI='\033['
RESET="${CSI}0m"
BOLD="${CSI}1m"
GREEN="${CSI}32m"
YELLOW="${CSI}33m"
RED="${CSI}31m"
BLUE="${CSI}34m"

log_info(){ echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_ok(){   echo -e "${GREEN}[ OK ]${RESET}  $*"; }
log_warn(){ echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error(){ echo -e "${RED}[ERR ]${RESET}  $*" >&2; }
