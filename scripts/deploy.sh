#!/usr/bin/env bash
set -euo pipefail

if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    echo "Файл .env не найден. Создаю из .env.example..."
    cp .env.example .env
    echo ""
    echo "ВАЖНО: Отредактируйте .env — укажите свой SECRET (см. scripts/generate-secret.sh)"
    echo "  nano .env"
    echo "  Или автоматически сгенерировать: openssl rand -hex 16"
    exit 1
  else
    echo "Файл .env не найден. Создайте его (см. .env.example)"
    exit 1
  fi
fi

echo "Запуск MTProto-прокси..."
docker compose up -d --remove-orphans
echo ""

sleep 2

if docker compose ps --status running | grep -q "tg-proxy"; then
  echo "Прокси запущен!"

  SECRET=$(grep ^SECRET .env | cut -d= -f2-)
  SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || echo "УЗНАТЬ IP ВРУЧНУЮ")

  echo ""
  echo "=== Ссылки для подключения ==="
  echo "Обычный:  https://t.me/proxy?server=$SERVER_IP&port=443&secret=$SECRET"
  echo "Фейк TLS: https://t.me/proxy?server=$SERVER_IP&port=443&secret=ee$SECRET"
else
  echo "Ошибка: контейнер не запустился. Смотрите логи:"
  docker compose logs --tail=20
  exit 1
fi
