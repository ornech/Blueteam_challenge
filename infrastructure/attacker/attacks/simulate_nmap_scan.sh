#!/bin/bash
TARGET=${1:-127.0.0.1}
nmap -sS -Pn -p1-65535 --min-rate 1000 --max-retries 1 $TARGET -oN /tmp/nmap_${TARGET}.txt || true
echo "simulate_nmap_scan: saved /tmp/nmap_${TARGET}.txt"
