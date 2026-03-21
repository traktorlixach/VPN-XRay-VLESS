#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONNECTION_FILE="$SCRIPT_DIR/connection.json"

export PATH="$HOME/.local/bin:$PATH"

if [ ! -f "$CONNECTION_FILE" ]; then
  echo "FATAL: $CONNECTION_FILE не найден" >&2
  exit 1
fi

NEW_UUID=$(cat /proc/sys/kernel/random/uuid)

DOMAIN=$(python3 -c "import json; print(json.load(open('$CONNECTION_FILE'))['domain'])")
WS_PATH=$(python3 -c "import json; print(json.load(open('$CONNECTION_FILE'))['ws_path'])")
PORT=$(python3 -c "import json; print(json.load(open('$CONNECTION_FILE'))['port'])")
NAME=$(python3 -c "import json; print(json.load(open('$CONNECTION_FILE'))['name'])")

python3 -c "
import json
with open('$CONNECTION_FILE', 'r') as f:
    data = json.load(f)
data['uuid'] = '$NEW_UUID'
with open('$CONNECTION_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"

echo "UUID обновлён в connection.json: $NEW_UUID"

railway variable set XRAY_UUID="$NEW_UUID" --service xray

LINK="vless://${NEW_UUID}@${DOMAIN}:${PORT}?type=ws&security=tls&path=/${WS_PATH}&sni=${DOMAIN}&host=${DOMAIN}#${NAME}"

echo ""
echo "Новая ссылка:"
echo "$LINK"
echo ""
echo "Контейнер перезапустится автоматически."
echo "Отправь новую ссылку всем пользователям или открой qr.html для QR-кода."
