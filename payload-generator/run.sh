#!/usr/bin/env bash
set -Eeuo pipefail
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$BASE_DIR/.venv/bin/python" ]]; then
  exec "$BASE_DIR/.venv/bin/python" "$BASE_DIR/generator.py" "$@"
fi
exec python3 "$BASE_DIR/generator.py" "$@"
