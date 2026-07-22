# MTProto Telegram Proxy

Официальный MTProto-прокси от Telegram в Docker. Поднимается одной командой.

## Требования

- Linux-сервер (Debian/Ubuntu рекомендуется)
- Docker и Docker Compose (`docker compose` plugin)
- Открытые порты: 443 (TCP+UDP), 80 (TCP), 8888 (TCP)
- Права root или пользователь в группе `docker`

## Пошаговая установка

### 1. Подготовка сервера

```bash
apt update && apt upgrade -y
apt install -y docker.io docker-compose-v2 git curl openssl
systemctl enable --now docker
```

Проверить, что Docker работает:

```bash
docker --version
docker compose version
```

### 2. Установка прокси

Скрипт сам склонирует репозиторий, соберёт образ и запустит контейнер:

```bash
bash scripts/deploy.sh
```

При первом запуске он создаст `/opt/tg-proxy/.env` из шаблона и завершится с
просьбой указать секрет.

### 3. Генерация секрета

```bash
openssl rand -hex 16
```

Скопируйте вывод (32 hex-символа).

### 4. Настройка

```bash
nano /opt/tg-proxy/.env
```

В файле `.env` укажите:

- `SECRET` — вставить сгенерированный секрет
- `WORKERS` — количество ядер CPU (для вашего сервера: `1`)
- `TAG` — опционально, можно получить у [@MTProxybot](https://t.me/MTProxybot)

### 5. Запуск

```bash
bash scripts/deploy.sh
```

Скрипт соберёт образ, запустит контейнер и выведет ссылки для подключения.

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
docker compose build --pull && docker compose up -d

# Полный деплой с git pull + build + up (одной командой)
bash scripts/deploy.sh
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
├── Dockerfile               # Сборка образа (на основе официального)
├── docker-compose.yml       # Docker Compose конфиг
├── .env                     # Переменные окружения (НЕ КОММИТИТЬ)
├── .env.example             # Шаблон .env
├── .gitignore               # Игнор .env и proxy-data/
├── scripts/
│   ├── deploy.sh            # Деплой: git pull → build → up → ссылки
│   ├── generate-secret.sh   # Генерация секрета (Linux/macOS)
│   └── generate-secret.ps1  # Генерация секрета (Windows)
└── README.md
```
