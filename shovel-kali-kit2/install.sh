#!/usr/bin/env bash
set -Eeuo pipefail

KIT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/shovel"
INTERFACE_LIST=""
START_AFTER_INSTALL=0

usage() {
  cat <<'HELP'
Usage: ./install.sh [--interfaces eth0,wlan0,tun0] [--start] [target-directory]

Options:
  --interfaces LIST   Comma-separated interfaces. Default: detect UP host interfaces,
                      excluding loopback and common container/bridge interfaces.
  --start             Start Shovel after setup. Without this flag, only prepare it.
  -h, --help          Show this help.
HELP
}

while (($#)); do
  case "$1" in
    --interfaces)
      [[ $# -ge 2 ]] || { echo "Missing value for --interfaces" >&2; exit 2; }
      INTERFACE_LIST="$2"; shift 2 ;;
    --start)
      START_AFTER_INSTALL=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    --*)
      echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      TARGET_DIR="$1"; shift ;;
  esac
done

for cmd in curl tar ip; do
  command -v "$cmd" >/dev/null || { echo "Missing '$cmd'. Install it first (Kali: sudo apt install curl tar iproute2)." >&2; exit 1; }
done
command -v docker >/dev/null || { echo "Docker is missing. Install Docker Engine and Compose, then rerun this script." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose plugin is missing. Install it, then rerun this script." >&2; exit 1; }

TARGET_DIR="$(mkdir -p -- "$TARGET_DIR" && cd -- "$TARGET_DIR" && pwd)"
if [[ ! -f "$TARGET_DIR/docker-compose.yml" ]]; then
  if [[ -n "$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "Target directory is not empty and does not look like a Shovel checkout: $TARGET_DIR" >&2
    exit 1
  fi
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf -- "$TMP_DIR"' EXIT
  echo "Downloading Shovel source..."
  curl --fail --location --silent --show-error --retry 3 --retry-delay 1 \
    https://github.com/FCSC-FR/shovel/archive/refs/heads/main.tar.gz \
    --output "$TMP_DIR/shovel.tar.gz"
  tar -xzf "$TMP_DIR/shovel.tar.gz" --strip-components=1 -C "$TARGET_DIR"
fi

[[ -f "$TARGET_DIR/example.env" ]] || { echo "Not a Shovel source directory: $TARGET_DIR" >&2; exit 1; }
[[ -f "$TARGET_DIR/.env" ]] || cp "$TARGET_DIR/example.env" "$TARGET_DIR/.env"
mkdir -p "$TARGET_DIR/input_pcaps" "$TARGET_DIR/output_suricata"

if [[ -n "$INTERFACE_LIST" ]]; then
  IFS=',' read -r -a INTERFACES <<< "$INTERFACE_LIST"
else
  mapfile -t INTERFACES < <(ip -o link show up | awk -F': ' '{n=$2; sub(/@.*/, "", n); print n}' | while IFS= read -r n; do
    case "$n" in
      lo|docker*|podman*|br-*|veth*|virbr*|cni*|flannel*) continue ;;
    esac
    printf '%s\n' "$n"
  done)
fi

if ((${#INTERFACES[@]} == 0)); then
  echo "No capture interfaces found. Rerun with --interfaces eth0,wlan0,tun0." >&2
  exit 1
fi
for iface in "${INTERFACES[@]}"; do
  [[ "$iface" =~ ^[[:alnum:]_.:-]+$ ]] || { echo "Invalid interface name: $iface" >&2; exit 1; }
  ip link show dev "$iface" >/dev/null 2>&1 || { echo "Interface not found: $iface" >&2; exit 1; }
done

cat > "$TARGET_DIR/compose.live.yaml" <<'YAML'
services:
  suricata:
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - DATABASE_URL=postgres://shovel:unsecure_password@127.0.0.1/shovel
      - PCAP_LOG=yes
    command:
YAML
for iface in "${INTERFACES[@]}"; do
  printf '      - "-i"\n      - "%s"\n' "$iface" >> "$TARGET_DIR/compose.live.yaml"
done

RULES_FILE="$TARGET_DIR/suricata/rules/suricata.rules"
if ! grep -q 'Codex local starter detections' "$RULES_FILE"; then
  if grep -q 'sid:9000001;' "$RULES_FILE"; then
    echo "SID 9000001 is already used. Review $RULES_FILE before installing the starter rules." >&2
    exit 1
  fi
  cat >> "$RULES_FILE" <<'RULES'

# Codex local starter detections (heuristics; review alerts before treating them as incidents)
# SIDs 9000001+ are reserved here for local additions.
alert tcp any any -> any any (msg:"Possible TCP SYN scan: 30+ SYN packets in 10 seconds"; flags:S; flow:stateless; detection_filter:track by_src, count 30, seconds 10; metadata: tag LOCAL SCAN, color danger; sid:9000001; rev:1;)
alert tcp any any -> any 22 (msg:"SSH connection burst: 8+ attempts in 60 seconds (heuristic)"; flags:S; flow:stateless; detection_filter:track by_src, count 8, seconds 60; metadata: tag LOCAL SSH BURST, color warning; sid:9000002; rev:1;)
alert http any any -> any any (msg:"Repeated HTTP 401 responses to one client (heuristic)"; flow:established,to_client; http.stat_code; content:"401"; startswith; detection_filter:track by_dst, count 10, seconds 60; metadata: tag LOCAL AUTH BURST, color warning; sid:9000003; rev:1;)
alert http any any -> any any (msg:"Web probe for exposed .env file"; flow:established,to_server; http.uri; content:"/.env"; nocase; metadata: tag LOCAL SECRET FILE PROBE, color danger; sid:9000010; rev:1;)
alert http any any -> any any (msg:"Web probe for exposed Git configuration"; flow:established,to_server; http.uri; content:"/.git/config"; nocase; metadata: tag LOCAL SECRET FILE PROBE, color danger; sid:9000011; rev:1;)
alert http any any -> any any (msg:"Web probe for wp-config.php"; flow:established,to_server; http.uri; content:"/wp-config.php"; nocase; metadata: tag LOCAL WEB PROBE, color warning; sid:9000012; rev:1;)
alert http any any -> any any (msg:"Web probe for Spring actuator env endpoint"; flow:established,to_server; http.uri; content:"/actuator/env"; nocase; metadata: tag LOCAL WEB PROBE, color danger; sid:9000013; rev:1;)
RULES
fi

for helper in start.sh stop.sh status.sh logs.sh reload-rules.sh; do
  install -m 0755 "$KIT_DIR/$helper" "$TARGET_DIR/$helper"
done

printf '\nShovel is prepared in: %s\n' "$TARGET_DIR"
printf 'Capture interfaces: %s\n' "${INTERFACES[*]}"
printf 'Custom starter rules: %s\n' "$RULES_FILE"
printf 'Open the web interface at http://localhost:8000 after starting.\n'
if ((START_AFTER_INSTALL)); then
  "$TARGET_DIR/start.sh"
else
  printf 'To start later: cd "%s" && ./start.sh\n' "$TARGET_DIR"
fi
