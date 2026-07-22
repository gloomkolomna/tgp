#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gloomkolomna/tgp.git"
PROJECT_DIR="/opt/tg-proxy"

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
echo "=== 3/5: Загрузка образа ==="
docker compose pull

echo ""
echo "=== 4/5: Запуск контейнера ==="
docker compose up -d --remove-orphans
sleep 3

echo ""
echo "=== 5/5: Проверка и ссылки ==="
if docker compose ps --status running | grep -q "tg-proxy"; then
  echo "Прокси успешно запущен!"

  SECRET=$(grep ^SECRET .env | cut -d= -f2- | head -1)
  IPV4="5.188.20.78"

  echo ""
  echo "=========================================="
  echo " Ссылки для подключения:"
  echo "=========================================="
  echo "Обычный:"
  echo "  https://t.me/proxy?server=$IPV4&port=443&secret=$SECRET"
  echo ""
  echo "Фейк TLS (если обычный заблокирован):"
  echo "  https://t.me/proxy?server=$IPV4&port=443&secret=ee$SECRET"
  echo ""
  echo "Проверка статуса: docker compose ps"
  echo "Логи:           docker compose logs -f"
  echo "=========================================="
else
  echo "ОШИБКА: контейнер не запустился. Логи:"
  docker compose logs --tail=30
  exit 1
fi
