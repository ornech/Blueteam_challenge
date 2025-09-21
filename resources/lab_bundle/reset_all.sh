#!/bin/bash
for d in labs/lab*; do
  if [ -d "$d" ]; then
    echo "Stopping compose in $d"
    (cd "$d" && docker compose -p "$(basename $d)" down -v) || true
  fi
done
for n in $(docker network ls --format '{{.Name}}' | grep '^labnet' || true); do
  echo "Removing network $n"
  docker network rm $n || true
done
echo "Reset complete"
