# Правила и ограничения

## Безопасность

- **Ключи только в `.env` и `instances/*.env`** — никогда не коммитить UUID, REALITY private key, Telegram token в код или Git
- **UUID + REALITY private key + HOST_PORT = полный доступ к VPN** — кто знает эти значения, тот имеет доступ
- **`instances/*.env` создаются с правами 600** — не менять на более открытые
- **REALITY private key нельзя терять** — при смене ключей клиенты должны получить новую ссылку
- **Routing правило `geoip:private`** — блокирует доступ к приватным IP-адресам через VPN
- **Firewall** — открывать только порты `HOST_PORT` нужных инстансов; SSH не трогать

## VPS / Docker

- **Деплой через `./deploy-vpn.sh <name>`** — он генерирует env, ключи, compose и отправляет ссылку в Telegram
- **`docker-compose.yml` генерируется** — не редактировать вручную, менять `instances/*.env` и перезапускать `python3 render-configs.py`
- **Один инстанс = один человек/устройство** — не раздавать один UUID семье, если нужен отзыв доступа
- **Порты `HOST_PORT` уникальны** — `render-configs.py` упадёт при конфликте
- **`PORT=443` внутри контейнера** — менять не нужно; клиент видит `HOST_PORT`

## Xray-core

- **Версия фиксирована** — `ARG XRAY_VERSION=v26.11.9` в Dockerfile. Обновлять вручную
- **envsubst** — `entrypoint.sh` генерирует `config.json` из `config.json.template`, подставляя `${PORT}`, `${XRAY_UUID}`, `${REALITY_*}` из ENV
- **REALITY** — `dest`/`serverNames` должны совпадать по домену; `shortIds` — hex-строка
- **flow `xtls-rprx-vision`** — обязателен и в конфиге, и в ссылке клиента

## Telegram

- **Токен бота — секрет** — хранить только в `.env`, не в Git и не в логах
- **QR отправляется как фото** — нужен `qrencode` на VPS (`init-vps.sh` ставит его)
- **Если Telegram не настроен** — `deploy-vpn.sh` всё равно печатает ссылку в stdout
