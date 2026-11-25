#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

fix_owner() {
  if [[ -n "${SUDO_USER:-}" ]]; then
    chown "$SUDO_USER" "$@"
  fi
}

NAME="${1:-}"

if [[ ! "$NAME" =~ ^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$ ]]; then
  echo "Usage: $0 <name>" >&2
  echo "Name must be a lowercase DNS label, e.g. vpn1, home, work-pc" >&2
  exit 1
fi

# Values passed on the command line (PUBLIC_IP=... ./deploy-vpn.sh) override .env.
CLI_PUBLIC_IP="${PUBLIC_IP:-}"
CLI_SERVER_ADDR="${SERVER_ADDR:-}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

PUBLIC_IP="${CLI_PUBLIC_IP:-${PUBLIC_IP:-}}"
SERVER_ADDR="${CLI_SERVER_ADDR:-${SERVER_ADDR:-}}"

mkdir -p instances
chmod 700 instances
ENV_FILE="instances/${NAME}.env"
JSON_FILE="instances/${NAME}.json"
QR_FILE="instances/${NAME}.png"

# Shared defaults from .env
DEFAULT_REALITY_DEST="${REALITY_DEST:-github.com:443}"
DEFAULT_REALITY_SERVER_NAME="${REALITY_SERVER_NAME:-github.com}"
DEFAULT_CLIENT_FP="${CLIENT_FP:-chrome}"
DEFAULT_FLOW="${FLOW:-xtls-rprx-vision}"
SHARED_SERVER_ADDR="${SERVER_ADDR:-}"
SHARED_PUBLIC_IP="${PUBLIC_IP:-}"

# Load existing instance values, if any
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ENV_FILE"
  set +a
fi

# Secrets and ports are per-instance; shared link/REALITY settings are refreshed from .env.
INSTANCE_SERVER_ADDR="${SERVER_ADDR:-}"
REALITY_DEST="$DEFAULT_REALITY_DEST"
REALITY_SERVER_NAME="$DEFAULT_REALITY_SERVER_NAME"
CLIENT_FP="$DEFAULT_CLIENT_FP"
FLOW="$DEFAULT_FLOW"
PORT="${PORT:-443}"
SERVER_ADDR="$SHARED_SERVER_ADDR"
PUBLIC_IP="$SHARED_PUBLIC_IP"
if [[ -z "$SERVER_ADDR" && -n "$PUBLIC_IP" ]]; then
  SERVER_ADDR="$PUBLIC_IP"
fi
if [[ -z "$SERVER_ADDR" ]]; then
  SERVER_ADDR="$INSTANCE_SERVER_ADDR"
fi

# Build image first: instance env generation uses the xray binary for REALITY keys.
docker build -t vpn-xray:latest . >/dev/null

# Generate UUID
if [[ -z "${XRAY_UUID:-}" ]]; then
  XRAY_UUID="$(cat /proc/sys/kernel/random/uuid)"
fi

# Generate REALITY keypair if missing
if [[ -z "${REALITY_PRIVATE_KEY:-}" || -z "${REALITY_PUBLIC_KEY:-}" ]]; then
  KEY_OUT="$(docker run --rm --entrypoint xray vpn-xray:latest x25519 2>/dev/null)"
  REALITY_PRIVATE_KEY="$(awk 'tolower($0) ~ /^private ?key:/ { print $NF; exit }' <<<"$KEY_OUT")"
  REALITY_PUBLIC_KEY="$(awk 'tolower($0) ~ /^(public ?key:|password)/ { print $NF; exit }' <<<"$KEY_OUT")"
  if [[ -z "$REALITY_PRIVATE_KEY" || -z "$REALITY_PUBLIC_KEY" ]]; then
    echo "FATAL: failed to generate REALITY keys" >&2
    exit 1
  fi
fi

# Generate short id
if [[ -z "${REALITY_SHORT_ID:-}" ]]; then
  REALITY_SHORT_ID="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
fi

# Resolve server address for clients
if [[ -z "${SERVER_ADDR:-}" ]]; then
  SERVER_ADDR="${PUBLIC_IP:-}"
fi
if [[ -z "$SERVER_ADDR" ]]; then
  SERVER_ADDR="$(curl -4 -fsS --max-time 10 https://ifconfig.me 2>/dev/null || true)"
fi
if [[ -z "$SERVER_ADDR" ]]; then
  SERVER_ADDR="$(curl -4 -fsS --max-time 10 https://checkip.amazonaws.com 2>/dev/null || true)"
fi
if [[ -z "$SERVER_ADDR" ]]; then
  echo "FATAL: cannot detect public IP. Set PUBLIC_IP or SERVER_ADDR in .env" >&2
  exit 1
fi

if [[ "$SERVER_ADDR" =~ ^\[[0-9A-Fa-f:.]+\]$ ]] || [[ "$SERVER_ADDR" =~ ^[A-Za-z0-9.-]+$ ]]; then
  :
else
  echo "FATAL: invalid SERVER_ADDR: ${SERVER_ADDR}. Use hostname/IPv4 or bracketed IPv6 like [2001:db8::1]" >&2
  exit 1
fi

# Choose host port if not set
if [[ -z "${HOST_PORT:-}" ]]; then
  used_ports="$(grep -h '^HOST_PORT=' instances/*.env 2>/dev/null | cut -d= -f2- | sort -u || true)"
  for candidate in 443 8443 9443 10443 11443 12443 13443 14443 15443 16443 17443 18443; do
    if grep -qx "$candidate" <<<"$used_ports"; then
      continue
    fi
    if command -v ss >/dev/null 2>&1 && ss -tlnH "sport = :${candidate}" 2>/dev/null | grep -q .; then
      continue
    fi
    HOST_PORT="$candidate"
    break
  done
  if [[ -z "${HOST_PORT:-}" ]]; then
    HOST_PORT="$(( (RANDOM % 20000) + 30000 ))"
  fi
fi

# Persist instance env
umask 077
cat > "$ENV_FILE" <<EOF
NAME=${NAME}
XRAY_UUID=${XRAY_UUID}
REALITY_PRIVATE_KEY=${REALITY_PRIVATE_KEY}
REALITY_PUBLIC_KEY=${REALITY_PUBLIC_KEY}
REALITY_SHORT_ID=${REALITY_SHORT_ID}
REALITY_DEST=${REALITY_DEST}
REALITY_SERVER_NAME=${REALITY_SERVER_NAME}
PORT=${PORT}
HOST_PORT=${HOST_PORT}
SERVER_ADDR=${SERVER_ADDR}
CLIENT_FP=${CLIENT_FP}
FLOW=${FLOW}
EOF

# Persist connection info for qr.html
cat > "$JSON_FILE" <<EOF
{
  "name": "${NAME}",
  "uuid": "${XRAY_UUID}",
  "server": "${SERVER_ADDR}",
  "port": ${HOST_PORT},
  "flow": "${FLOW}",
  "security": "reality",
  "sni": "${REALITY_SERVER_NAME}",
  "fingerprint": "${CLIENT_FP}",
  "public_key": "${REALITY_PUBLIC_KEY}",
  "short_id": "${REALITY_SHORT_ID}",
  "type": "tcp"
}
EOF
fix_owner "$ENV_FILE" "$JSON_FILE"

python3 render-configs.py

# Allow port in firewall if UFW is active
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow "${HOST_PORT}/tcp" >/dev/null || true
fi

docker compose up -d --remove-orphans >/dev/null
docker compose up -d --force-recreate "xray-${NAME}" >/dev/null

# Basic check that the service is running
sleep 2
if ! docker compose ps "xray-${NAME}" --format '{{.State}}' 2>/dev/null | grep -q running; then
  echo "WARN: xray-${NAME} is not running. Recent logs:" >&2
  docker compose logs --tail=30 "xray-${NAME}" >&2 || true
fi

LINK="vless://${XRAY_UUID}@${SERVER_ADDR}:${HOST_PORT}?encryption=none&flow=${FLOW}&security=reality&sni=${REALITY_SERVER_NAME}&fp=${CLIENT_FP}&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&type=tcp#${NAME}"

if command -v qrencode >/dev/null 2>&1; then
  qrencode -o "$QR_FILE" -s 10 "$LINK"
  fix_owner "$QR_FILE"
else
  echo "WARN: qrencode is not installed; QR will not be sent" >&2
fi

MESSAGE="VPN ${NAME} deployed
Server: ${SERVER_ADDR}:${HOST_PORT}
SNI: ${REALITY_SERVER_NAME}

Link:
${LINK}"

./send-telegram.sh "$MESSAGE" "$QR_FILE" || echo "WARN: failed to send Telegram notification" >&2

echo ""
echo "Deployed ${NAME}: ${SERVER_ADDR}:${HOST_PORT}"
echo "$LINK"
