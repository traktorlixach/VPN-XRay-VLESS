# VPN-XRay-VLESS

Личный VPN на базе Xray-core. Протокол VLESS через WebSocket поверх TLS.
Трафик выглядит как обычный HTTPS — не детектируется DPI (РКН).

## Архитектура

```
Клиент (v2rayNG / Streisand / v2rayN)
    |  VLESS over WebSocket (TLS)
Railway reverse proxy (*.up.railway.app, порт 443)
    |  HTTP (внутренний порт 8080)
Xray-core контейнер
    |  freedom
Интернет
```

Railway терминирует TLS автоматически. Клиент подключается на порт 443 с TLS.

## Ссылка для подключения

Актуальная ссылка генерируется из `connection.json` — единственный источник истины.
Чтобы посмотреть ссылку и QR-код — открой `qr.html` в браузере.

Формат ссылки:
```
vless://<UUID>@<ДОМЕН>:443?type=ws&security=tls&path=/<WS_PATH>&sni=<ДОМЕН>&host=<ДОМЕН>#<НАЗВАНИЕ>
```

## Настройка клиентов

### Android — v2rayNG
1. Установить [v2rayNG](https://play.google.com/store/apps/details?id=com.v2ray.ang) из Google Play
2. Нажать "+" -> "Импорт из буфера обмена" (скопировав ссылку выше)
3. Нажать кнопку подключения

### iOS — Streisand (бесплатно) или Shadowrocket ($2.99)
1. Установить из App Store
2. Добавить сервер -> "Из буфера обмена" или сканировать QR
3. Подключиться

### Windows — v2rayN
1. Скачать [v2rayN](https://github.com/2dust/v2rayN/releases)
2. Серверы -> "Импорт из буфера обмена"
3. Правый клик на иконку в трее -> "Системный прокси" -> "Авто-настройка"

### macOS — FoXray или V2rayU
1. Скачать из App Store (FoXray) или GitHub (V2rayU)
2. Импортировать ссылку из буфера обмена
3. Подключиться

### Linux — Nekoray
1. Скачать [Nekoray](https://github.com/MatsuriDayo/nekoray/releases)
2. Серверы -> "Из буфера обмена"
3. Подключиться

## Переменные окружения (Railway)

| Переменная | Описание |
|---|---|
| `XRAY_UUID` | UUID клиента (секрет, не передавать третьим лицам) |
| `WS_PATH` | Путь WebSocket (секрет, рандомная строка) |
| `PORT` | Внутренний порт контейнера (8080) |

## Управление доступом

### Смена ключа (одна команда)

```bash
./rotate-key.sh
```

Скрипт генерирует новый UUID, обновляет `connection.json`, устанавливает в Railway ENV.
Контейнер перезапустится автоматически. После смены — открой `qr.html` для нового QR-кода.

### Примечания
- Все пользователи одного UUID отключатся при смене ключа
- Для раздельного доступа — добавить несколько clients в `config.json.template` (см. `.windsurf/vpn-usage.md`)

## Деплой обновлений

```bash
export PATH="$HOME/.local/bin:$PATH"
railway up --service xray --detach -m "описание изменений"
```

## Дашборд Railway

https://railway.com/project/8ae04c87-e798-49fa-9fee-bd5aaf9a2254
