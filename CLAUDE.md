# VPN-XRay-VLESS

## Quick Reference

- **Назначение**: личный VPN для обхода блокировок РКН
- **Стек**: Xray-core v26.2.6, VLESS + REALITY + TCP, Docker (Alpine 3.24)
- **Хостинг**: любой VPS с Ubuntu/Debian и Docker; домен не нужен
- **Протокол**: VLESS over TCP with REALITY (маскировка под TLS-сайт)
- **Правила**: [rules.md](.windsurf/rules.md)
- **Инструкции по VPN**: [vpn-usage.md](.windsurf/vpn-usage.md)

## Architecture

```
Клиент (v2rayNG / Streisand / v2rayN / FoXray / Nekoray)
    |  VLESS + REALITY (TCP, IP:PORT)
Xray-core контейнер (Alpine 3.24)
    |  freedom outbound
Интернет
```

| Решение | Обоснование |
|---------|-------------|
| VLESS + REALITY | Не нужен домен/TLS-сертификат; трафик выглядит как TLS к реальному сайту, устойчивее к DPI/РКН |
| Один контейнер на пользователя | Отдельные UUID/REALITY-ключи/порт; можно отозвать доступ одному, не трогая остальных |
| envsubst в entrypoint | Ключи хранятся в `instances/*.env`, не в коде |
| `render-configs.py` | Генерирует `docker-compose.yml` из `instances/*.env` |
| Telegram-бот | Ссылка и QR отправляются после деплоя/ротации |
| Alpine 3.24 | Минимальный образ (~20 MB) |

## Infrastructure

### VPS

| Параметр | Значение |
|----------|----------|
| ОС | Ubuntu/Debian |
| Docker | Docker Engine + Compose plugin |
| Домен | Не нужен; подключение по `SERVER_ADDR:HOST_PORT` |
| Firewall | Открыты только порты `HOST_PORT` для каждого инстанса |

### ENV-переменные

| Файл | Переменные | Назначение |
|------|------------|------------|
| `.env` | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `PUBLIC_IP`, `SERVER_ADDR`, `REALITY_DEST`, `REALITY_SERVER_NAME`, `CLIENT_FP`, `FLOW` | Общие настройки и секреты Telegram |
| `instances/<name>.env` | `NAME`, `XRAY_UUID`, `REALITY_PRIVATE_KEY`, `REALITY_PUBLIC_KEY`, `REALITY_SHORT_ID`, `REALITY_DEST`, `REALITY_SERVER_NAME`, `PORT`, `HOST_PORT`, `SERVER_ADDR`, `CLIENT_FP`, `FLOW` | Секреты конкретного VPN-канала |

`PORT` внутри контейнера обычно `443`; `HOST_PORT` — порт на VPS, который видит клиент.

### Деплой

```bash
sudo ./init-vps.sh          # один раз: Docker, qrencode, python3
./deploy-vpn.sh vpn1        # создать/обновить инстанс и отправить ссылку в Telegram
./rotate-key.sh vpn1        # сменить UUID и отправить новую ссылку
```

`docker-compose.yml` генерируется скриптом и не коммитится.

## Code Tree

```
vpn/
  .gitignore                # Исключает .env, instances/*, docker-compose.yml
  .env.example              # Шаблон общих ENV
  deploy-vpn.sh             # Генерация env/ключей, render, up, Telegram
  init-vps.sh               # Первичная настройка Ubuntu/Debian VPS
  render-configs.py         # instances/*.env -> docker-compose.yml
  send-telegram.sh          # Отправка сообщения/QR в Telegram
  rotate-key.sh             # Смена UUID для одного инстанса
  remove-vpn.sh             # Отзыв доступа: удалить инстанс и его контейнер
  qr.html                   # QR/ссылка по instances/<name>.json (?name=<name>)
  Dockerfile                # Alpine 3.24 + Xray-core бинарник
  config.json.template      # Шаблон конфига Xray с ${ENV} плейсхолдерами
  entrypoint.sh             # Подстановка ENV -> config.json + запуск xray
  README.md                 # Инструкция по VPS-деплою
  CLAUDE.md                 # Этот файл — контекст проекта
  .windsurf/
    rules.md                # Правила и ограничения
    vpn-usage.md            # Инструкции по использованию VPN
```

## Tech Debt

- [ ] `REALITY_DEST=github.com` может перестать работать, если GitHub заблокирует/изменит TLS; тогда поменять в `.env`
- [ ] Нет мониторинга/алертов — если контейнер упадёт, узнаешь только при попытке подключиться
