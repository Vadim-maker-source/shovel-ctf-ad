#!/usr/bin/env bash
set -Eeuo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
if docker info >/dev/null 2>&1; then
  docker compose -f docker-compose.yml -f compose.live.yaml exec suricata pkill -USR2 suricata
else
  sudo docker compose -f docker-compose.yml -f compose.live.yaml exec suricata pkill -USR2 suricata
fi
printf 'Suricata was asked to reload its rules. Check ./logs.sh for parse errors.\n'
