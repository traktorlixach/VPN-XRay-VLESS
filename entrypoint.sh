#!/bin/bash
set -e

PORT="${PORT:-8080}"

if [ -z "$XRAY_UUID" ]; then
  echo "FATAL: XRAY_UUID is not set. Generate with: cat /proc/sys/kernel/random/uuid" >&2
  exit 1
fi

WS_PATH="${WS_PATH:-xray-ws}"

echo "Xray starting on port ${PORT}, ws path: /${WS_PATH}"

export PORT WS_PATH XRAY_UUID
envsubst < /etc/xray/config.json.template > /etc/xray/config.json

exec xray run -config /etc/xray/config.json
