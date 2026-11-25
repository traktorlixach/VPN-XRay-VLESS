#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

TEXT="${1:-}"
PHOTO="${2:-}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
  echo "Telegram is not configured (TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID). Skipping send." >&2
  exit 0
fi

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
CURL_CONFIG="$(mktemp)"
chmod 600 "$CURL_CONFIG"
trap 'rm -f "$CURL_CONFIG"' EXIT

if [[ -n "$PHOTO" && -f "$PHOTO" ]]; then
  printf 'url = "%s/sendPhoto"\n' "$API" > "$CURL_CONFIG"
  curl -fsS -K "$CURL_CONFIG" \
    -F "chat_id=${TELEGRAM_CHAT_ID}" \
    -F "photo=@${PHOTO}" \
    -F "caption=${TEXT}" \
    >/dev/null
else
  printf 'url = "%s/sendMessage"\n' "$API" > "$CURL_CONFIG"
  curl -fsS -K "$CURL_CONFIG" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${TEXT}" \
    >/dev/null
fi
