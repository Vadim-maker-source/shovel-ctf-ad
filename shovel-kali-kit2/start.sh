#!/usr/bin/env bash
set -Eeuo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
fi

for image in \
  ghcr.io/fcsc-fr/shovel/suricata:dev \
  ghcr.io/fcsc-fr/shovel/webapp:dev \
  ghcr.io/fcsc-fr/shovel/grafana:dev; do
  if ! "${DOCKER[@]}" image inspect "$image" >/dev/null 2>&1; then
    echo "Missing local image: $image" >&2
    echo "This no-build launcher needs the Shovel images preloaded or pulled from GitHub Container Registry before the restricted network is used." >&2
    exit 1
  fi
done

if ! "${DOCKER[@]}" image inspect postgres:18 >/dev/null 2>&1 \
  && ! "${DOCKER[@]}" image inspect docker.io/library/postgres:18 >/dev/null 2>&1; then
  echo "Missing local database image: postgres:18" >&2
  echo "Preload the PostgreSQL image before starting Shovel on the restricted network." >&2
  exit 1
fi

"${DOCKER[@]}" compose -f docker-compose.yml -f compose.live.yaml up -d --no-build db webapp suricata
printf '\nShovel: http://localhost:8000\n'
