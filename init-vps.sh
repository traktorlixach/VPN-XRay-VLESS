#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo $0)" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

export DEBIAN_FRONTEND=noninteractive

. /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) echo "Unsupported OS: ${ID:-unknown}. Use Ubuntu or Debian." >&2; exit 1 ;;
esac

if [[ "${ID}" == "ubuntu" ]]; then
  DOCKER_REPO="https://download.docker.com/linux/ubuntu"
else
  DOCKER_REPO="https://download.docker.com/linux/debian"
fi

apt-get update
apt-get install -y ca-certificates curl gnupg python3 qrencode ufw iproute2

if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "${DOCKER_REPO}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${DOCKER_REPO} ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

systemctl enable --now docker

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example. Fill TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID before deploy."
fi

mkdir -p instances

docker build -t vpn-xray:latest .

echo ""
echo "VPS is ready. Next steps:"
echo "1. Edit .env: set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID (optional PUBLIC_IP/SERVER_ADDR)."
echo "2. Deploy VPNs: ./deploy-vpn.sh vpn1 && ./deploy-vpn.sh vpn2 ..."
echo "3. Open firewall ports printed by deploy-vpn.sh if you use a firewall other than UFW."
