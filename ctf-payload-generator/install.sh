#!/usr/bin/env bash
set -Eeuo pipefail
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
python3 -m venv "$BASE_DIR/.venv"
chmod +x "$BASE_DIR/run.sh"
printf 'Installed. Run: %s/run.sh --eve /var/log/suricata/eve.json\n' "$BASE_DIR"
