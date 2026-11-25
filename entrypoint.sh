#!/bin/bash
set -e

PORT="${PORT:-443}"

if [ -z "$XRAY_UUID" ]; then
  echo "FATAL: XRAY_UUID is not set. Generate with: cat /proc/sys/kernel/random/uuid" >&2
  exit 1
fi

if [ -z "$REALITY_PRIVATE_KEY" ]; then
  echo "FATAL: REALITY_PRIVATE_KEY is not set. Generate with: xray x25519" >&2
  exit 1
fi

REALITY_DEST="${REALITY_DEST:-www.microsoft.com:443}"
REALITY_SERVER_NAME="${REALITY_SERVER_NAME:-www.microsoft.com}"
REALITY_SHORT_ID="${REALITY_SHORT_ID:-}"

if [ -z "$REALITY_SHORT_ID" ]; then
  echo "FATAL: REALITY_SHORT_ID is not set. Generate with: openssl rand -hex 8" >&2
  exit 1
fi

echo "Xray starting on port ${PORT}, reality dest: ${REALITY_DEST}, sni: ${REALITY_SERVER_NAME}"

export PORT XRAY_UUID REALITY_PRIVATE_KEY REALITY_DEST REALITY_SERVER_NAME REALITY_SHORT_ID
envsubst < /etc/xray/config.json.template > /etc/xray/config.json

exec xray run -config /etc/xray/config.json
