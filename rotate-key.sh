#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

NAME="${1:-}"

if [[ ! "$NAME" =~ ^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$ ]]; then
  echo "Usage: $0 <name>" >&2
  echo "Example: $0 vpn1" >&2
  exit 1
fi

ENV_FILE="instances/${NAME}.env"
JSON_FILE="instances/${NAME}.json"
QR_FILE="instances/${NAME}.png"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "FATAL: $ENV_FILE not found. Deploy first: ./deploy-vpn.sh $NAME" >&2
  exit 1
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

set -a
# shellcheck disable=SC1091
source "$ENV_FILE"
set +a

NEW_UUID="$(cat /proc/sys/kernel/random/uuid)"
XRAY_UUID="$NEW_UUID"

# Update env file in place, preserving other keys
TMP_ENV="$(mktemp)"
while IFS= read -r line; do
  case "$line" in
    XRAY_UUID=*) echo "XRAY_UUID=${NEW_UUID}" ;;
    *) echo "$line" ;;
  esac
done < "$ENV_FILE" > "$TMP_ENV"
mv "$TMP_ENV" "$ENV_FILE"
chmod 600 "$ENV_FILE"

# Update JSON file if present
if [[ -f "$JSON_FILE" ]]; then
  TMP_JSON="$(mktemp)"
  python3 - "$JSON_FILE" "$TMP_JSON" "$NEW_UUID" <<'PY'
import json, sys
src, dst, uuid = sys.argv[1:4]
with open(src, encoding='utf-8') as f:
    data = json.load(f)
data['uuid'] = uuid
with open(dst, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY
  mv "$TMP_JSON" "$JSON_FILE"
fi

python3 render-configs.py

docker compose up -d >/dev/null

LINK="vless://${NEW_UUID}@${SERVER_ADDR}:${HOST_PORT}?encryption=none&flow=${FLOW}&security=reality&sni=${REALITY_SERVER_NAME}&fp=${CLIENT_FP}&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&type=tcp#${NAME}"

if command -v qrencode >/dev/null 2>&1; then
  qrencode -o "$QR_FILE" -s 10 "$LINK"
fi

MESSAGE="VPN ${NAME} key rotated
Server: ${SERVER_ADDR}:${HOST_PORT}

Link:
${LINK}"

./send-telegram.sh "$MESSAGE" "$QR_FILE" || echo "WARN: failed to send Telegram notification" >&2

echo ""
echo "Rotated key for ${NAME}: ${SERVER_ADDR}:${HOST_PORT}"
echo "$LINK"
