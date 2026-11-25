# VPN-XRay-VLESS

Личный VPN на базе Xray-core: **VLESS + REALITY + TCP**. Не нужен домен и Let's Encrypt — REALITY маскирует трафик под реальный TLS-сайт, что делает его устойчивым к DPI/РКН.

## Что изменилось по сравнению с Railway-версией

- Нет зависимости от Railway и её reverse proxy/TLS.
- Нет домена: клиент подключается по `IP:PORT`.
- Каждый VPN — отдельный контейнер со своими ключами и портом.
- UUID, REALITY-ключи и shortId генерируются автоматически при деплое.
- После деплоя ссылка и QR-код отправляются в Telegram через бота.

## Быстрый старт на VPS

Требования к серверу: Ubuntu/Debian, Docker, SSH-доступ root/sudo.

```bash
git clone https://github.com/traktorlixach/VPN-XRay-VLESS.git
cd VPN-XRay-VLESS
sudo ./init-vps.sh
```

Отредактируйте `.env`:

```bash
nano .env
```

Обязательно заполните:

- `TELEGRAM_BOT_TOKEN` — токен от [@BotFather](https://t.me/BotFather)
- `TELEGRAM_CHAT_ID` — ваш chat id

Опционально:

- `PUBLIC_IP` / `SERVER_ADDR` — если автоопределение IP не сработает или нужен домен позже
- `REALITY_DEST` / `REALITY_SERVER_NAME` — другой сайт для маскировки, если `github.com` недоступен с VPS

Деплой первого VPN:

```bash
./deploy-vpn.sh vpn1
```

Повторите для остальных пользователей:

```bash
./deploy-vpn.sh vpn2
./deploy-vpn.sh vpn3
./deploy-vpn.sh vpn4
```

После каждого деплоя в Telegram придёт сообщение с QR-кодом и ссылкой. Клиенты: **v2rayNG** (Android), **Streisand/Shadowrocket** (iOS), **v2rayN** (Windows), **FoXray** (macOS), **Nekoray** (Linux).

## Полезные команды

```bash
# Логи конкретного VPN
docker compose logs -f xray-vpn1

# Перезапуск всех VPN
docker compose restart

# Остановить все VPN
docker compose down

# Сменить UUID одного VPN (старая ссылка перестанет работать)
./rotate-key.sh vpn1

# QR/ссылка без Telegram: только через SSH-туннель, не открывайте порт наружу
python3 -m http.server 8000 --bind 127.0.0.1
# на вашем компьютере: ssh -L 8000:127.0.0.1:8000 user@server
# затем откройте http://127.0.0.1:8000/qr.html?name=vpn1
```

## Минимальные требования для 4 VPN-контейнеров

Для 4 лёгких Xray-контейнеров достаточно минимального VPS:

- **CPU:** 1 vCPU
- **RAM:** 1 GB
- **Disk:** 20 GB SSD/NVMe
- **Network:** стабильный канал; bandwidth важнее CPU/RAM

Комфортный вариант: **2 vCPU / 2 GB RAM / 40 GB NVMe**. Если пользователи будут смотреть видео одновременно, выбирайте тариф с хорошим трафиком/скоростью, а не с большим CPU.

## Безопасность

- `.env` и `instances/*.env` содержат секреты и не коммитятся; `deploy-vpn.sh` создаёт их с правами `600`.
- UUID + REALITY private key + порт = полный доступ к VPN. Не пересылайте `instances/*.env`.
- После деплоя откройте в firewall только нужные порты (`deploy-vpn.sh` делает это для UFW автоматически).
- Ротация UUID: `./rotate-key.sh <name>`.

## Документация

- [vpn-usage.md](.windsurf/vpn-usage.md) — подключение клиентов, ротация ключей, несколько пользователей, диагностика
- [CLAUDE.md](CLAUDE.md) — архитектура, инфраструктура VPS, ENV-переменные, Code Tree
- [rules.md](.windsurf/rules.md) — правила безопасности и ограничения
