# Инструкции по использованию VPN

## Ссылка для подключения

Актуальная ссылка хранится в `instances/<name>.json` на сервере и дублируется в Telegram-сообщении после деплоя/ротации.

Формат ссылки:

```
vless://<UUID>@<SERVER>:<HOST_PORT>?encryption=none&flow=xtls-rprx-vision&security=reality&sni=<SNI>&fp=chrome&pbk=<PUBLIC_KEY>&sid=<SHORT_ID>&type=tcp#<NAME>
```

`SERVER` — обычно публичный IP VPS (`SERVER_ADDR` в `instances/<name>.env`).

---

## Подключение клиентов

### Android — v2rayNG (бесплатно)
1. Установить [v2rayNG](https://play.google.com/store/apps/details?id=com.v2ray.ang) из Google Play
2. Скопировать ссылку `vless://...`
3. В приложении: "+" -> "Импорт конфигурации из буфера обмена"
4. Нажать кнопку подключения

### iOS — Streisand (бесплатно) или Shadowrocket ($2.99)
1. Установить из App Store
2. Скопировать ссылку или сканировать QR-код
3. Streisand: "+" -> "Из буфера обмена"
4. Shadowrocket: "+" -> вставить ссылку
5. Нажать переключатель подключения

### Windows — v2rayN
1. Скачать [v2rayN](https://github.com/2dust/v2rayN/releases) (`v2rayN-With-Core.zip`)
2. Распаковать, запустить `v2rayN.exe`
3. Серверы -> "Импорт из буфера обмена"
4. Правый клик на иконку в трее -> "Системный прокси" -> "Авто-настройка системного прокси"

### macOS — FoXray (бесплатно)
1. Установить [FoXray](https://apps.apple.com/app/foxray/id6448898396) из App Store
2. "+" -> "Из буфера обмена"
3. Нажать "Подключиться"

### Linux — Nekoray
1. Скачать [Nekoray](https://github.com/MatsuriDayo/nekoray/releases)
2. Серверы -> "Добавить профиль из буфера обмена"
3. Подключиться

---

## Несколько пользователей

Каждый пользователь = отдельный инстанс = отдельный контейнер, UUID, REALITY-ключи и порт.

```bash
./deploy-vpn.sh vpn1   # для первого человека
./deploy-vpn.sh vpn2   # для второго
./deploy-vpn.sh vpn3
./deploy-vpn.sh vpn4
```

После каждого деплоя в Telegram приходит отдельное сообщение с QR и ссылкой для этого пользователя.

### Отозвать доступ пользователю

Автоматического скрипта пока нет. Вручную на VPS:

```bash
# 1. Остановить и удалить контейнер
docker compose rm -sf xray-<name>

# 2. Удалить env/json инстанса
rm -f instances/<name>.env instances/<name>.json instances/<name>.png

# 3. Перегенерировать compose и применить
python3 render-configs.py
docker compose up -d
```

Остальные VPN продолжат работать.

---

## Смена ключа (UUID)

Когда нужно: утечка ссылки, ротация по расписанию (раз в 3-6 месяцев).

```bash
./rotate-key.sh vpn1
```

Скрипт:
1. Генерирует новый UUID
2. Обновляет `instances/vpn1.env` и `instances/vpn1.json`
3. Перезапускает контейнер
4. Отправляет новую ссылку и QR в Telegram

Все текущие подключения этого VPN разорвутся; нужно обновить ссылку на устройствах.

---

## Обслуживание

### Логи

```bash
docker compose logs -f xray-vpn1
docker compose logs --tail=100 xray-vpn1
```

### Перезапуск/остановка

```bash
docker compose restart xray-vpn1
docker compose down
```

### Обновить версию Xray-core

1. Изменить `ARG XRAY_VERSION=vXX.XX.XX` в `Dockerfile`
2. `git add -A && git commit -m "Update Xray" && git push`
3. На VPS: `git pull && docker build -t vpn-xray:latest . && docker compose up -d`

---

## Диагностика проблем

| Проблема | Причина | Решение |
|----------|---------|---------|
| Клиент не подключается | Неверный UUID/port/sid | Сверь ссылку с `instances/<name>.json` |
| Подключение есть, сайты не открываются | DNS на клиенте | В клиенте включить "DNS over VPN" или указать 1.1.1.1 |
| Резкие обрывы | Нестабильный канал VPS или блокировка порта | Проверь `docker compose logs`, смени `HOST_PORT`, проверь firewall |
| После деплоя нет Telegram | Не заполнен `.env` или нет `qrencode` | Заполни `TELEGRAM_*`, выполни `sudo ./init-vps.sh` |
| `render-configs.py` падает | Конфликт `HOST_PORT` или неполный `instances/*.env` | Удали/исправь `instances/*.env`, перезапусти `./deploy-vpn.sh <name>` |
| VPN работает, но медленно | Далёкий/перегруженный VPS | Сменить тариф/регион, проверить канал |

---

## FAQ

### Сколько пользователей на одном VPN?

Один инстанс = один UUID. По нему может подключаться сколько угодно устройств одновременно, но отозвать доступ одному из них нельзя. Для семьи лучше отдельные инстансы.

### Можно ли использовать домен вместо IP?

Да. В `.env` задай `SERVER_ADDR=your.domain.com` (и DNS A-запись на IP VPS). REALITY не требует домена, но домен удобнее, если IP меняется.

### Почему не WebSocket+TLS как раньше?

WebSocket+TLS требует домен и Let's Encrypt. REALITY не требует домена и обычно устойчивее к DPI/РКН.
