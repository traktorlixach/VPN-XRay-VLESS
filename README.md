# VPN-XRay-VLESS

Личный VPN на базе Xray-core. Протокол VLESS + WebSocket + TLS — трафик неотличим от HTTPS, не детектируется DPI (РКН).

## Быстрый старт

1. Открой `qr.html` — там актуальная ссылка и QR-код
2. Импортируй ссылку в VPN-клиент (подробнее — [vpn-usage.md](.windsurf/vpn-usage.md))

Клиенты: **v2rayNG** (Android), **Streisand** (iOS), **v2rayN** (Windows), **FoXray** (macOS), **Nekoray** (Linux).

## Смена ключа

```bash
./rotate-key.sh
```

Подробнее — [vpn-usage.md](.windsurf/vpn-usage.md).

## Деплой

Автоматический: `git push` в `master` → Railway собирает и деплоит.

```bash
git add -A && git commit -m "Описание изменений" && git push
```

## Документация

- [vpn-usage.md](.windsurf/vpn-usage.md) — подключение клиентов, смена ключей, несколько пользователей, диагностика
- [CLAUDE.md](CLAUDE.md) — архитектура, инфраструктура Railway, ENV-переменные, Code Tree
- [rules.md](.windsurf/rules.md) — правила безопасности и ограничения
- [Дашборд Railway](https://railway.com/project/8ae04c87-e798-49fa-9fee-bd5aaf9a2254)
