#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gloomkolomna/tgp.git"
PROJECT_DIR="/opt/tg-proxy"
IPV4="5.188.20.78"
DOMAIN="Xmax.ru"

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
DOMAIN_HEX=$(echo -n "$DOMAIN" | xxd -p | tr -d '\n')
LINK_SECRET="ee${SECRET}${DOMAIN_HEX}"

if docker compose ps --status running | grep -q "tg-proxy"; then
  echo ""
  echo "=========================================="
  echo " Прокси запущен"
  echo "=========================================="
  echo ""
  echo "Ссылка:"
  echo "https://t.me/proxy?server=$IPV4&port=443&secret=$LINK_SECRET"
  echo ""
  echo "Ручное подключение:"
  echo "  Тип:    MTProto"
  echo "  Хост:   $IPV4"
  echo "  Порт:   443"
  echo "  Секрет: $LINK_SECRET"
  echo ""
  echo "Маскировка: TLS 1.2 под $DOMAIN"
  echo "Оператор LTE видит HTTPS — скорость без ограничений."
  echo ""
  echo "Команды:"
  echo "  Статус:      docker compose ps"
  echo "  Логи:        docker compose logs -f"
  echo "  Перезапуск:  docker compose restart"
  echo "=========================================="
else
  echo "Ошибка. Логи:"
  docker compose logs --tail=30
  exit 1
fi
