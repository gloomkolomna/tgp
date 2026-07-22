# MTProto Telegram Proxy

Официальный MTProto-прокси от Telegram в Docker. Поднимается одной командой.

## Требования

- Linux-сервер (Debian/Ubuntu рекомендуется)
- Docker и Docker Compose (`docker compose` plugin)
- Открытые порты: 443 (TCP+UDP), 80 (TCP), 8888 (TCP)
- Права root или пользователь в группе `docker`

## Быстрый старт

### 1. Клонировать и перейти в папку

```bash
git clone <repo> ~/tg-proxy
cd ~/tg-proxy
```

### 2. Сгенерировать секрет

```bash
# Linux/MacOS
openssl rand -hex 16
```

или через скрипт:

```bash
bash scripts/generate-secret.sh
```

### 3. Настроить

```bash
cp .env.example .env
nano .env
```

В `.env` укажите:
- `SECRET` — скопировать из вывода `openssl rand -hex 16` (32 hex-символа)
- `TAG` — опционально, получить у [@MTProxybot](https://t.me/MTProxybot)
- `WORKERS` — число ядер CPU

### 4. Запустить

```bash
bash scripts/deploy.sh
```

или вручную:

```bash
docker compose up -d
```

### 5. Получить ссылки

Скрипт `deploy.sh` выведет ссылки автоматически. Если запускали вручную:

```bash
SECRET=$(grep ^SECRET .env | cut -d= -f2-)
SERVER_IP=$(curl -s https://api.ipify.org)

echo "https://t.me/proxy?server=$SERVER_IP&port=443&secret=$SECRET"
echo "https://t.me/proxy?server=$SERVER_IP&port=443&secret=ee$SECRET"
```

## Подключение в Telegram

Откройте ссылку в браузере на телефоне — Telegram сам предложит применить прокси.

Либо вручную:
1. Telegram → Настройки → Дата и сеть → Настройки прокси
2. Добавить прокси → MTProto
3. Хост: IP сервера, Порт: 443, Секрет: из `.env`

**Фейковый TLS** — если обычный заблокирован провайдером:
- Добавьте `ee` в начало секрета (уже в ссылке с `ee$SECRET`)
- Прокси будет маскироваться под HTTPS-трафик на `cloudflare.com`

## Команды

```bash
# Статус
docker compose ps

# Логи
docker compose logs -f

# Перезапуск
docker compose restart

# Остановка
docker compose down

# Обновление образа и перезапуск
docker compose pull && docker compose up -d
```

## Проверка работы

Подключитесь к прокси и отправьте в Telegram:

```
/info
```

боту [@MTProxybot](https://t.me/MTProxybot) — он покажет статус и статистику.

## Архитектура

```
                                    443/tcp + 443/udp (MTProto)
Сервер ──▶ docker-compose ──▶ tg-proxy ──▶ Telegram
                │                │
                │                └── /data (volume — секреты, кэш)
                │
                ├── .env (SECRET, WORKERS)
                └── docker-compose.yml
```

## Файлы проекта

```
├── docker-compose.yml       # Docker Compose конфиг
├── .env                     # Переменные окружения (НЕ КОММИТИТЬ)
├── .env.example             # Шаблон .env
├── .gitignore               # Игнор .env и proxy-data/
├── scripts/
│   ├── deploy.sh            # Деплой (генерация ссылок, проверка)
│   ├── generate-secret.sh   # Генерация секрета (Linux/macOS)
│   └── generate-secret.ps1  # Генерация секрета (Windows)
└── README.md
```
