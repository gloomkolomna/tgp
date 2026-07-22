#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gloomkolomna/tgp.git"
PROJECT_DIR="/opt/tg-proxy"
IPV4="5.188.20.78"

echo "=== 1/5: Получение свежего кода из $REPO_URL ==="
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
echo "=== 2/5: Проверка .env ==="
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
echo "=== 3/5: Генерация TLS-сертификата ==="
if [ -f "$PROJECT_DIR/scripts/gen-cert.sh" ]; then
  bash "$PROJECT_DIR/scripts/gen-cert.sh"
else
  echo "ВНИМАНИЕ: scripts/gen-cert.sh не найден"
fi

echo ""
echo "=== 4/5: Загрузка образов и запуск ==="
docker compose pull
docker compose up -d --remove-orphans
sleep 4

echo ""
echo "=== 5/5: Проверка и ссылки ==="
TG_TLS=$(docker compose ps --status running | grep "tg-tls" || true)
TG_PROXY=$(docker compose ps --status running | grep "tg-proxy" || true)

if [ -n "$TG_TLS" ] && [ -n "$TG_PROXY" ]; then
  echo "Прокси успешно запущен!"

  SECRET=$(grep ^SECRET .env | cut -d= -f2- | head -1)

  echo ""
  echo "=========================================="
  echo " Ссылки для подключения:"
  echo "=========================================="
  echo ""
  echo "--- LTE (порт 443, TLS) — быстрее ---"
  echo "https://t.me/proxy?server=$IPV4&port=443&secret=$SECRET"
  echo ""
  echo "--- WiFi (порт 443, без TLS) ---"
  echo "https://t.me/proxy?server=$IPV4&port=443&secret=$SECRET"
  echo ""
  echo "ВАЖНО: На LTE порт 443 теперь идёт через реальный TLS."
  echo "  Оператор видит обычный HTTPS, скорость не режется."
  echo "  Секрет указывай обычный (без ee/dd)."
  echo ""
  echo "Проверка статуса: docker compose ps"
  echo "Логи TLS:         docker compose logs tg-tls -f"
  echo "Логи прокси:      docker compose logs tg-proxy -f"
  echo "=========================================="
else
  echo "ОШИБКА: один из контейнеров не запустился. Логи:"
  docker compose logs --tail=20
  exit 1
fi
