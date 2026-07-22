# MTProto Telegram Proxy (mtproto.zig)

Прокси с автоматической маскировкой трафика под TLS 1.3 HTTPS.
Оператор видит обычный HTTPS — не режет, не тормозит.

## Требования

- Linux-сервер (Debian/Ubuntu)
- Docker и Docker Compose
- Открыт порт: 443 (TCP)

## Пошаговая установка

### 1. Подготовка сервера

```bash
apt update && apt upgrade -y
apt install -y docker.io docker-compose-v2 git curl openssl
systemctl enable --now docker
```

### 2. Клонировать репозиторий

```bash
git clone https://github.com/gloomkolomna/tgp.git /opt/tg-proxy
cd /opt/tg-proxy
```

### 3. Первый запуск

```bash
bash scripts/deploy.sh
```

Скрипт создаст `.env` из шаблона и завершится с просьбой указать секрет.

### 4. Генерация секрета

```bash
openssl rand -hex 16
```

Скопируйте вывод (32 hex-символа).

### 5. Настройка

```bash
nano /opt/tg-proxy/.env
```

Укажите `SECRET=...`

### 6. Запуск

```bash
bash scripts/deploy.sh
```

Скрипт сгенерирует конфиг, загрузит образ и запустит прокси.

## Подключение в Telegram

Вручную:
1. Настройки → Дата и сеть → Настройки прокси
2. Добавить → MTProto
3. Хост: `5.188.20.78`, Порт: `443`, Секрет: из `.env`

**Секрет всегда обычный (32 символа, без ee/dd).**
Трафик автоматически маскируется под TLS 1.3.

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

# Полный деплой (git pull + запуск)
bash scripts/deploy.sh
```

## Архитектура

```
                  443/tcp (TLS 1.3)
Клиент ──▶ tg-proxy (mtproto.zig) ──▶ Telegram
               │
               ├── mtproto.toml (генерится из .env)
               ├── tls_domain = rutube.ru (SNI маскировка)
               ├── mask = true (TLS 1.3 поверх MTProto)
               └── drs = true (динамический размер записей)
```

Оператор LTE видит TLS 1.3 к `rutube.ru` — обычный HTTPS.

## Файлы проекта

```
├── docker-compose.yml       # Docker Compose (один сервис)
├── config/
│   └── mtproto.toml         # Конфиг прокси (генерится из .env)
├── .env                     # Секрет (НЕ КОММИТИТЬ)
├── .env.example             # Шаблон .env
├── scripts/
│   ├── deploy.sh            # Деплой: pull → конфиг → up → ссылки
│   ├── generate-secret.sh   # Генерация секрета (Linux/macOS)
│   └── generate-secret.ps1  # Генерация секрета (Windows)
└── README.md
```
