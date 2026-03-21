# VPN-XRay-VLESS

## Quick Reference

- **Назначение**: личный VPN для обхода блокировок РКН
- **Стек**: Xray-core v24.12.31, VLESS + WebSocket, Docker (Alpine 3.20)
- **Хостинг**: Railway.com
- **Протокол**: VLESS over WebSocket over TLS (маскировка под HTTPS)
- **Правила**: [rules.md](.windsurf/rules.md)
- **Инструкции по VPN**: [vpn-usage.md](.windsurf/vpn-usage.md)

## Architecture

```
Клиент (v2rayNG / Streisand / v2rayN / FoXray / Nekoray)
    |  VLESS over WebSocket (TLS, порт 443)
Railway reverse proxy (*.up.railway.app)
    |  HTTP (внутренний порт 8080)
Xray-core контейнер (Alpine 3.20)
    |  freedom outbound
Интернет
```

| Решение               | Обоснование                                                    |
|-----------------------|----------------------------------------------------------------|
| VLESS + WebSocket     | Максимальная устойчивость к DPI/РКН, трафик неотличим от HTTPS |
| Railway reverse proxy | Автоматическая TLS-терминация, домен `*.up.railway.app`        |
| envsubst в entrypoint | Ключи хранятся в ENV Railway, не в коде                        |
| connection.json       | Единый источник истины для ссылки (UUID, домен, WS_PATH)       |
| rotate-key.sh         | Смена UUID одной командой (JSON + Railway ENV)                 |
| Alpine 3.20           | Минимальный образ (~20 MB)                                     |
| Один inbound          | Простота, достаточно для личного использования                 |

## Infrastructure

### Railway

| Параметр        | Значение                                                               |
|-----------------|------------------------------------------------------------------------|
| Проект          | VPN-XRay-VLESS                                                         |
| Project ID      | `8ae04c87-e798-49fa-9fee-bd5aaf9a2254`                                 |
| Service ID      | `6b34806d-49d3-4193-a776-fd2fb0da79f2`                                 |
| Environment     | production (`a630bc87-a07f-4183-aea2-b1f5c9a7410e`)                    |
| Workspace       | Likhachev Yaroslav's Projects (`8681766b-e2f4-4786-b177-bbe030604d3f`) |
| Домен           | `vpn-uncleyaroslav.up.railway.app`                                     |
| Внешний порт    | 443 (TLS)                                                              |
| Внутренний порт | 8080                                                                   |
| Builder         | RAILPACK (автодетект Dockerfile в корне)                               |
| Регион          | US East                                                                |
| CPU лимит       | 0.5 vCPU                                                               |
| RAM лимит       | 512 MB                                                                 |
| Metal Build     | Включен                                                                |
| Дашборд         | https://railway.com/project/8ae04c87-e798-49fa-9fee-bd5aaf9a2254       |

### Railway CLI

- Установлен в `$HOME/.local/bin/railway` (v4.33.0)
- Перед использованием: `export PATH="$HOME/.local/bin:$PATH"`
- Авторизация: уже выполнена (`railway whoami`)
- Проект слинкован с директорией `/home/user/projects/vpn`

### Переменные окружения (Railway ENV)

| Переменная  | Описание                              | Секрет? |
|-------------|---------------------------------------|---------|
| `XRAY_UUID` | UUID клиента для аутентификации VLESS | Да      |
| `WS_PATH`   | Путь WebSocket (рандомная строка)     | Да      |
| `PORT`      | Внутренний порт контейнера (8080)     | Нет     |

### Деплой

Деплой автоматический: `git push` в `master` → Railway собирает Docker-образ и деплоит.

```bash
git add -A && git commit -m "Описание изменений" && git push
```

**Git**: приватный репозиторий `traktorlixach/VPN-XRay-VLESS` на GitHub. SSH-алиас: `github_traktorlixach`. Ветка: `master`.

## Code Tree

```
vpn/
  .gitignore                # Исключает connection.json
  .mcp.json                 # MCP-сервер Railway
  connection.json           # Единый источник истины: UUID, домен, WS_PATH (не в Git!)
  connection.json.example   # Шаблон без секретов (в Git)
  rotate-key.sh             # Смена UUID одной командой (обновляет JSON + Railway ENV)
  qr.html                   # QR-код — читает connection.json, без хардкода
  Dockerfile                # Alpine 3.20 + Xray-core бинарник
  config.json.template      # Шаблон конфига Xray с ${ENV} плейсхолдерами
  entrypoint.sh             # Подстановка ENV -> config.json + запуск xray
  README.md                 # Инструкция, ссылается на connection.json
  CLAUDE.md                 # Этот файл — контекст проекта
  .windsurf/
    rules.md                # Правила и ограничения
    vpn-usage.md            # Инструкции по использованию VPN
```

## Tech Debt

- [ ] Один UUID на всех пользователей — нельзя отозвать доступ одному, не затронув остальных
- [ ] Xray предупреждает о депрекации WebSocket в пользу XHTTP — в будущем стоит мигрировать
- [ ] Нет мониторинга/алертов — если контейнер упадёт, узнаешь только при попытке подключиться
