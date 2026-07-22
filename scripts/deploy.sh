#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gloomkolomna/tgp.git"
PROJECT_DIR="/opt/tg-proxy"
IPV4="5.188.20.78"

echo "=== 1/4: Получение свежего кода из $REPO_URL ==="
if [ -d "$PROJECT_DIR/.git" ]; then
  cd "$PROJECT_DIR"
  git pull
else
  git clone "$REPO_URL" "$PROJECT_DIR"
  cd "$PROJECT_DIR"
fi

echo ""
echo "=== 2/4: Проверка .env ==="
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Создан .env из .env.example"
  echo "Укажите SECRET: nano $PROJECT_DIR/.env"
  echo "Сгенерировать: openssl rand -hex 16"
  exit 1
fi

export $(grep -v '^#' .env | xargs)

echo ""
echo "=== 3/4: Загрузка образа ==="
docker compose pull

echo ""
echo "=== 4/4: Запуск ==="
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d
sleep 3

SECRET=$(grep ^SECRET .env | cut -d= -f2- | head -1)

if docker compose ps --status running | grep -q "tg-proxy"; then
  echo ""
  echo "Прокси запущен."
  echo "Ссылка: https://t.me/proxy?server=$IPV4&port=443&secret=$SECRET"
  echo ""
  echo "Ручное подключение: MTProto, $IPV4:443, секрет $SECRET"
  echo ""
  echo "На LTE подключение медленное — оператор инспектирует пакеты."
  echo "После соединения скорость нормальная."
else
  echo "Ошибка. Логи:"
  docker compose logs --tail=30
  exit 1
fi
