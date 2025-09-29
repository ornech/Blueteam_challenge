#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Supprime les anciennes arborescences "configs", "certs" et "data"
# restées dans labs/<lab>/ après la refonte par conteneur.

set -euo pipefail

LABS_DIR="./labs"

for LAB in "$LABS_DIR"/*; do
    [ -d "$LAB" ] || continue
    echo "[INFO] Nettoyage de $LAB ..."

    for OLD in configs certs data; do
        if [ -d "$LAB/$OLD" ]; then
            echo "  [DEL] Suppression de $LAB/$OLD"
            rm -rf "$LAB/$OLD"
        fi
    done
done

echo "[OK] Nettoyage terminé."
