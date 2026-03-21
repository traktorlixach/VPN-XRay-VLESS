# Инструкции по использованию VPN

## Ссылка для подключения

Актуальная ссылка хранится в `connection.json` — единственный источник истины.
QR-код и текст ссылки — открой `qr.html` в браузере.

Формат ссылки:
```
vless://<UUID>@<ДОМЕН>:443?type=ws&security=tls&path=/<WS_PATH>&sni=<ДОМЕН>&host=<ДОМЕН>#<НАЗВАНИЕ>
```

---

## Подключение клиентов

### Android — v2rayNG (бесплатно)
1. Установить [v2rayNG](https://play.google.com/store/apps/details?id=com.v2ray.ang) из Google Play
2. Скопировать ссылку `vless://...`
3. В приложении: "+" -> "Импорт конфигурации из буфера обмена"
4. Нажать кнопку подключения (значок V внизу экрана)

### iOS — Streisand (бесплатно) или Shadowrocket ($2.99)
1. Установить из App Store
2. Скопировать ссылку или сканировать QR-код
3. Streisand: "+" -> "Из буфера обмена"
4. Shadowrocket: "+" -> "Тип: VLESS" (или вставить ссылку)
5. Нажать переключатель подключения

### Windows — v2rayN
1. Скачать [v2rayN](https://github.com/2dust/v2rayN/releases) (файл `v2rayN-With-Core.zip`)
2. Распаковать, запустить `v2rayN.exe`
3. Серверы -> "Импорт из буфера обмена"
4. Правый клик на иконку в трее -> "Системный прокси" -> "Авто-настройка системного прокси"
5. Для проверки: открыть браузер, зайти на заблокированный ресурс

### macOS — FoXray (бесплатно)
1. Установить [FoXray](https://apps.apple.com/app/foxray/id6448898396) из App Store
2. "+" -> "Из буфера обмена"
3. Нажать "Подключиться"

### Linux — Nekoray
1. Скачать [Nekoray](https://github.com/MatsuriDayo/nekoray/releases)
2. Серверы -> "Добавить профиль из буфера обмена"
3. Подключиться

---

## Один пользователь

Текущая конфигурация — **один UUID на всех**. Все устройства и пользователи подключаются с одним и тем же ключом. Это:
- Просто в настройке
- Нет лимита на количество одновременных подключений
- Нельзя отозвать доступ одному пользователю, не затронув остальных

### Смена ключа (UUID)

**Когда нужно менять**: утечка ключа, хочешь отозвать доступ всем, ротация по расписанию.

**Что произойдёт**: все текущие клиенты мгновенно отключатся. Нужно обновить ссылку на всех устройствах.

**Одна команда**:

```bash
./rotate-key.sh
```

Скрипт:
1. Генерирует новый UUID
2. Обновляет `connection.json`
3. Устанавливает в Railway ENV (контейнер перезапустится автоматически)
4. Выводит новую ссылку

**После смены**: открой `qr.html` — там уже актуальный QR-код. Отправь его пользователям.

### Смена WS_PATH

WS_PATH меняется вручную — это редкая операция:

```bash
export PATH="$HOME/.local/bin:$PATH"
NEW_PATH=$(head -c 16 /dev/urandom | xxd -p)
railway variable set WS_PATH=$NEW_PATH --service xray
```

После смены WS_PATH нужно также обновить значение `ws_path` в `connection.json`.

---

## Несколько пользователей с разными ключами

Если нужно дать доступ нескольким людям с возможностью отозвать доступ у конкретного — нужно добавить несколько clients в конфиг Xray.

### Шаг 1: Сгенерировать UUID для каждого пользователя

```bash
# Пользователь 1 (ты)
cat /proc/sys/kernel/random/uuid
# Пользователь 2 (друг)
cat /proc/sys/kernel/random/uuid
# Пользователь 3 (семья)
cat /proc/sys/kernel/random/uuid
```

### Шаг 2: Обновить config.json.template

Заменить блок `clients` на список:

```json
"clients": [
  {
    "id": "${XRAY_UUID_1}",
    "email": "user1@vpn",
    "level": 0
  },
  {
    "id": "${XRAY_UUID_2}",
    "email": "user2@vpn",
    "level": 0
  },
  {
    "id": "${XRAY_UUID_3}",
    "email": "user3@vpn",
    "level": 0
  }
]
```

Поле `email` — это метка для логов (не настоящий email), помогает различать пользователей.

### Шаг 3: Обновить entrypoint.sh

Добавить экспорт новых переменных:

```bash
export PORT WS_PATH XRAY_UUID_1 XRAY_UUID_2 XRAY_UUID_3
```

### Шаг 4: Установить переменные в Railway

```bash
export PATH="$HOME/.local/bin:$PATH"
railway variable set \
  XRAY_UUID_1=<uuid-1> \
  XRAY_UUID_2=<uuid-2> \
  XRAY_UUID_3=<uuid-3> \
  --service xray
```

### Шаг 5: Задеплоить

```bash
railway up --service xray --detach -m "Добавлены отдельные UUID для пользователей"
```

### Шаг 6: Сгенерировать ссылки

Каждый пользователь получает свою ссылку (отличается только UUID):

```
vless://<UUID-1>@<ДОМЕН>:443?type=ws&security=tls&path=/<WS_PATH>&sni=<ДОМЕН>&host=<ДОМЕН>#VPN-User1
vless://<UUID-2>@...#VPN-User2
vless://<UUID-3>@...#VPN-User3
```

### Отзыв доступа у конкретного пользователя

Чтобы отключить пользователя 2:
1. Удалить его блок из `config.json.template`
2. Удалить переменную: `railway variable delete XRAY_UUID_2 --service xray`
3. Задеплоить: `railway up --service xray --detach -m "Отозван доступ user2"`

Остальные пользователи продолжат работать без переподключения.

---

## Деплой и обновления

### Обновить конфиг / Dockerfile

```bash
export PATH="$HOME/.local/bin:$PATH"
# Отредактировать файлы, затем:
railway up --service xray --detach -m "описание изменений"
```

### Обновить версию Xray-core

1. Изменить `ARG XRAY_VERSION=vXX.XX.XX` в `Dockerfile`
2. Задеплоить: `railway up --service xray --detach -m "Обновлён Xray до vXX.XX.XX"`

### Просмотреть логи

```bash
export PATH="$HOME/.local/bin:$PATH"
# Runtime-логи
railway logs --service xray --lines 50
# Build-логи
railway logs --service xray --build --lines 50
```

### Перезапустить без пересборки

```bash
railway restart --service xray --yes
```

### Перестроить и задеплоить

```bash
railway redeploy --service xray --yes
```

---

## Диагностика проблем

| Проблема                       | Причина                         | Решение                                                          |
|--------------------------------|---------------------------------|------------------------------------------------------------------|
| Клиент не подключается         | Неправильный UUID или WS_PATH   | Проверь ссылку, сверь с `railway variable list --service xray`   |
| "Connection refused"           | Контейнер не запущен            | `railway logs --service xray --lines 20` — смотри ошибки         |
| Медленно работает              | Далёкий регион сервера          | Сменить регион в дашборде Railway                                |
| Обрывы соединения              | Railway перезапускает контейнер | Проверь health, лимиты RAM                                       |
| Сайты не открываются через VPN | DNS-проблемы на клиенте         | В клиенте включить "DNS over VPN" или вручную задать DNS 1.1.1.1 |
| "FATAL: XRAY_UUID is not set"  | Не задана переменная            | `railway variable set XRAY_UUID=<uuid> --service xray`           |

---

## Безопасность

- **UUID = пароль** — не передавать по незащищённым каналам. Отправлять через Signal, Telegram (secret chat), или лично
- **WS_PATH = дополнительный секрет** — без знания пути WebSocket подключиться нельзя, даже зная UUID
- **TLS** — шифрование от клиента до Railway. Railway терминирует TLS, внутри сети Railway трафик по HTTP (безопасно, внутренняя сеть)
- **Routing правило `geoip:private`** — блокирует доступ к приватным IP через VPN (защита от сканирования сети Railway)
- **Ротация ключей** — рекомендуется менять UUID раз в 3-6 месяцев или при подозрении на утечку

---

## FAQ

### Сколько пользователей по одному ключу?
Без ограничений. По одному UUID могут подключаться одновременно сколько угодно устройств.

### Нужен ли Git?
Нет. `railway up` загружает файлы напрямую. Но Git рекомендуется для бэкапа — при потере файлов обновлять контейнер будет нечем.

### Можно ли сменить домен *.up.railway.app?
Да. В дашборде Railway: удалить автогенерированный домен, создать новый с желаемым именем (например, `vpn-uncleyaroslav.up.railway.app`). Для полностью своего домена — купить домен и привязать через `railway domain my.domain.com --service xray`.

### Что такое `railway up`?
Команда CLI, которая пакует файлы из текущей директории, загружает на Railway, Railway собирает Docker-образ и запускает контейнер. Аналог `docker build + push`, но без реестра.

### Как добавить кастомный домен?
```bash
# 1. Купить домен (Cloudflare, Namecheap, etc.)
# 2. Привязать к Railway
railway domain vpn.mydomain.com --service xray --port 8080 --json
# 3. Настроить DNS (Railway покажет CNAME-запись)
# 4. Обновить ссылку для клиентов — заменить домен
```
