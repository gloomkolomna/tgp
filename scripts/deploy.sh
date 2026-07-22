#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gloomkolomna/tgp.git"
PROJECT_DIR="/opt/tg-proxy"
IPV4="5.188.20.78"

echo "=== 1/4: Получение свежего кода из $REPO_URL ==="
if [ -d "$PROJECT_DIR/.git" ]; then
  echo "Репозиторий уже склонирован. Обновляю..."
  cd "$PROJECT_DIR"
  git pull
else
  echo "Клонирование репозитория..."
  git clone "$REPO_URL" "$PROJECT_DIR"
  cd "$PROJECT_DIR"
fi

echo ""
echo "=== 2/4: Проверка .env ==="
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "Создан .env из .env.example"
    echo ""
    echo "ВАЖНО: Укажите SECRET в .env:"
    echo "  nano $PROJECT_DIR/.env"
    echo "  Сгенерировать: openssl rand -hex 16"
    exit 1
  else
    echo "Ошибка: .env не найден"
    exit 1
  fi
fi

export $(grep -v '^#' .env | xargs)

echo ""
echo "=== 3/4: Генерация конфигурации mtproto.toml ==="
SECRET=$(grep ^SECRET .env | cut -d= -f2- | head -1)
TLS_DOMAIN="rutube.ru"
cat > "$PROJECT_DIR/config/mtproto.toml" << TOMLEOF
[general]
use_middle_proxy = true

[upstream]
type = "auto"

[server]
port = 443
max_connections = 512
idle_timeout_sec = 120
handshake_timeout_sec = 15
log_level = "info"
rate_limit_per_subnet = 0

[censorship]
tls_domain = "$TLS_DOMAIN"
mask = true
mask_port = 443
fast_mode = true
drs = true

[access.users]
default = "$SECRET"

[access.direct_users]
default = true
TOMLEOF
echo "Конфиг создан (TLS-маскировка: $TLS_DOMAIN)"

echo ""
echo "=== 4/4: Загрузка образа и запуск ==="
docker compose down --remove-orphans 2>/dev/null || true
docker compose pull
docker compose up -d
sleep 3

echo ""
echo "=== Проверка и ссылки ==="
if docker compose ps --status running | grep -q "tg-proxy"; then
  echo "Прокси успешно запущен!"
  echo ""
  echo "=========================================="
  echo " Ссылка для подключения:"
  echo "=========================================="
  echo "https://t.me/proxy?server=$IPV4&port=443&secret=$SECRET"
  echo ""
  echo "Как подключаться (вручную):"
  echo "  Тип:     MTProto"
  echo "  Хост:    $IPV4"
  echo "  Порт:    443"
  echo "  Секрет:  $SECRET"
  echo ""
  echo "Трафик маскируется под TLS 1.3 HTTPS ($TLS_DOMAIN)."
  echo "Оператор видит обычный HTTPS. Секрет БЕЗ ee/dd."
  echo ""
  echo "Проверка статуса: docker compose ps"
  echo "Логи прокси:      docker compose logs -f"
  echo "=========================================="
else
  echo "ОШИБКА: контейнер не запустился. Логи:"
  docker compose logs --tail=30
  exit 1
fi
