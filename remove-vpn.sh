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

# Never delete local credentials before Docker confirms the container is gone.
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "FATAL: Docker is not available or the current user lacks Docker access. Fix access before removing ${NAME}." >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "FATAL: Docker Compose plugin is missing." >&2
  exit 1
fi

HOST_PORT="$(awk -F= '$1 == "HOST_PORT" { print $2; exit }' "$ENV_FILE")"
HAS_OTHER=0
for env_path in instances/*.env; do
  if [[ "$env_path" != "$ENV_FILE" ]]; then
    HAS_OTHER=1
    break
  fi
done

# Remove only this service; this must not restart VPNs that were stopped.
if [[ -f docker-compose.yml ]]; then
  docker compose rm -sf "xray-${NAME}" >/dev/null
else
  docker rm -f "xray-${NAME}" >/dev/null 2>&1 || true
fi

if docker ps -a --format '{{.Names}}' | grep -qx "xray-${NAME}"; then
  echo "FATAL: container xray-${NAME} still exists after removal" >&2
  exit 1
fi

# For the last instance, bring the Compose project down before deleting its env_file.
if [[ "$HAS_OTHER" -eq 0 && -f docker-compose.yml ]]; then
  docker compose down >/dev/null
fi

rm -f "instances/${NAME}.env" "instances/${NAME}.json" "instances/${NAME}.png"

# Close the firewall rule opened by deploy-vpn.sh.
if [[ -n "${HOST_PORT:-}" ]] && command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw delete allow "${HOST_PORT}/tcp" >/dev/null 2>&1 || true
fi

if [[ "$HAS_OTHER" -eq 1 ]]; then
  python3 render-configs.py
else
  rm -f docker-compose.yml
fi

echo "Removed VPN instance: ${NAME}"
