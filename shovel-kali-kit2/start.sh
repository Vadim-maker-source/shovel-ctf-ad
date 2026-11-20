#!/usr/bin/env bash
set -Eeuo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
if docker info >/dev/null 2>&1; then
  docker compose -f docker-compose.yml -f compose.live.yaml up -d --build db webapp suricata
else
  sudo docker compose -f docker-compose.yml -f compose.live.yaml up -d --build db webapp suricata
fi
printf '\nShovel: http://localhost:8000\n'
