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

if [[ ! -f "$ENV_FILE" ]]; then
  echo "FATAL: $ENV_FILE not found" >&2
  exit 1
fi

docker compose rm -sf "xray-${NAME}" >/dev/null 2>&1 || true

rm -f "instances/${NAME}.env" "instances/${NAME}.json" "instances/${NAME}.png"

if compgen -G "instances/*.env" >/dev/null; then
  python3 render-configs.py
  docker compose up -d --remove-orphans >/dev/null
else
  docker compose down >/dev/null 2>&1 || true
  rm -f docker-compose.yml
fi

echo "Removed VPN instance: ${NAME}"
