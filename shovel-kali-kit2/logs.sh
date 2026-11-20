#!/usr/bin/env bash
set -Eeuo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
if docker info >/dev/null 2>&1; then
  docker compose -f docker-compose.yml -f compose.live.yaml logs -f --tail=100 suricata webapp db
else
  sudo docker compose -f docker-compose.yml -f compose.live.yaml logs -f --tail=100 suricata webapp db
fi
