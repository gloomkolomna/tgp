# MTProto Telegram Proxy

Официальный MTProto-прокси от Telegram в Docker.

## Требования

- Linux-сервер (Debian/Ubuntu)
- Docker и Docker Compose
- Открыт порт: 443 (TCP+UDP)

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

Скрипт создаст `.env` и запросит настройку секрета.

### 4. Генерация секрета

```bash
openssl rand -hex 16
```

### 5. Настройка

```bash
nano /opt/tg-proxy/.env
```

Укажите `SECRET=<32 hex символа>`.

### 6. Запуск

```bash
bash scripts/deploy.sh
```

## Подключение в Telegram

- Тип: **MTProto**
- Хост: `5.188.20.78`
- Порт: `443`
- Секрет: из `.env`

## Команды

```bash
docker compose ps              # Статус
docker compose logs -f         # Логи
docker compose restart         # Перезапуск
bash scripts/deploy.sh         # Полный деплой (git pull + up)
```

## Файлы

```
├── docker-compose.yml       # Docker Compose
├── .env / .env.example      # Настройки
├── scripts/
│   ├── deploy.sh            # Деплой
│   ├── generate-secret.sh   # Генерация секрета (Linux)
│   └── generate-secret.ps1  # Генерация секрета (Windows)
└── README.md
```
