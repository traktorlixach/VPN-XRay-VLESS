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
SERVICE="xray-${NAME}"
CONTAINER="xray-${NAME}"
HAS_OTHER=0
for env_path in instances/*.env; do
  if [[ "$env_path" != "$ENV_FILE" ]]; then
    HAS_OTHER=1
    break
  fi
done

CONTAINER_ID=""
if [[ -f docker-compose.yml ]]; then
  CONTAINER_ID="$(docker compose ps -q "$SERVICE" 2>/dev/null | sed -n '1p' || true)"
fi

container_exists() {
  if [[ -n "$CONTAINER_ID" ]] && docker inspect "$CONTAINER_ID" >/dev/null 2>&1; then
    return 0
  fi
  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    return 0
  fi
  return 1
}

if [[ "$HAS_OTHER" -eq 1 ]]; then
  TMP_DIR="$(mktemp -d)"
  for suffix in env json png; do
    src="instances/${NAME}.${suffix}"
    if [[ -f "$src" ]]; then
      mv "$src" "$TMP_DIR/${NAME}.${suffix}"
    fi
  done

  restore_instance() {
    trap - ERR
    for suffix in env json png; do
      if [[ -f "$TMP_DIR/${NAME}.${suffix}" ]]; then
        mv "$TMP_DIR/${NAME}.${suffix}" "instances/${NAME}.${suffix}"
      fi
    done
    python3 render-configs.py >/dev/null 2>&1 || true
    rm -rf "$TMP_DIR"
  }

  # Render first: if another instance file is invalid, leave everything unchanged.
  if ! python3 render-configs.py; then
    restore_instance
    echo "FATAL: cannot render remaining instances; ${NAME} was not removed" >&2
    exit 1
  fi

  # Compose no longer contains this service, so remove the container directly.
  if [[ -n "$CONTAINER_ID" ]]; then
    docker rm -f "$CONTAINER_ID" >/dev/null || true
  fi
  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    docker rm -f "$CONTAINER" >/dev/null || true
  fi

  if ! docker info >/dev/null 2>&1; then
    restore_instance
    echo "FATAL: Docker became unreachable while removing ${NAME}" >&2
    exit 1
  fi

  if container_exists; then
    restore_instance
    echo "FATAL: container ${CONTAINER} still exists after removal" >&2
    exit 1
  fi

  rm -rf "$TMP_DIR"
else
  if [[ -f docker-compose.yml ]]; then
    docker compose rm -sf "$SERVICE" >/dev/null
  fi
  if [[ -f docker-compose.yml ]] && docker compose ps -aq "$SERVICE" 2>/dev/null | grep -q .; then
    echo "FATAL: containers for ${SERVICE} still exist after removal" >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "FATAL: Docker became unreachable while removing ${NAME}" >&2
    exit 1
  fi

  if container_exists; then
    echo "FATAL: container ${CONTAINER} still exists after removal" >&2
    exit 1
  fi
  if [[ -f docker-compose.yml ]]; then
    docker compose down >/dev/null
  fi

  rm -f "instances/${NAME}.env" "instances/${NAME}.json" "instances/${NAME}.png"
fi

# Close the firewall rule opened by deploy-vpn.sh.
if [[ -n "${HOST_PORT:-}" ]] && command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw delete allow "${HOST_PORT}/tcp" >/dev/null 2>&1 || true
fi

if [[ "$HAS_OTHER" -eq 0 ]]; then
  rm -f docker-compose.yml
fi

echo "Removed VPN instance: ${NAME}"
