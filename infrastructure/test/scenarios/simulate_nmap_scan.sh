#!/bin/bash
# simulate_nmap_scan.sh <target_ip>
# Usage: ./simulate_nmap_scan.sh 10.10.1.10

TARGET=${1:-127.0.0.1}

# SYN scan (fast) - limit to local lab targets
nmap -sS -Pn -p 1-65535 --min-rate 1000 --max-retries 1 $TARGET -oN /tmp/nmap_${TARGET}.txt
echo "nmap output -> /tmp/nmap_${TARGET}.txt"
