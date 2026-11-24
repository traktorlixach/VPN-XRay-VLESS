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

if [[ -n "$PHOTO" && -f "$PHOTO" ]]; then
  curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" \
    -F "chat_id=${TELEGRAM_CHAT_ID}" \
    -F "photo=@${PHOTO}" \
    --data-urlencode "caption=${TEXT}" \
    >/dev/null
else
  curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${TEXT}" \
    >/dev/null
fi
