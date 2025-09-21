#!/bin/bash
TARGET=${1:-127.0.0.1}
COUNT=${2:-30}
for i in $(seq 1 $COUNT); do
  logger -p auth.warning -t sshd "Failed password for invalid user test from 192.0.2.$((100 + i)) port $((20000 + i)) ssh2"
  sleep 0.2
done
echo "simulate_ssh_failures: done"
