#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gloomkolomna/tgp.git"
PROJECT_DIR="/opt/tg-proxy"
IPV4="5.188.20.78"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=== 1/5: Получение свежего кода ==="
if [ -d "$PROJECT_DIR/.git" ]; then
  cd "$PROJECT_DIR"
  git pull
else
  git clone "$REPO_URL" "$PROJECT_DIR"
  cd "$PROJECT_DIR"
fi

echo ""
echo "=== 2/5: Проверка .env ==="
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Создан .env из .env.example"
  echo "Укажите SECRET: nano $PROJECT_DIR/.env"
  exit 1
fi

set -a; . ./.env; set +a

echo ""
echo "=== 3/5: Тюнинг системы ==="
if [ "$(id -u)" -eq 0 ]; then
  bash "$HERE/sysctl-apply.sh" || true
  bash "$HERE/firewall-setup.sh" || true
else
  echo "SKIP: не root. Выполните вручную:"
  echo "  sudo bash $HERE/sysctl-apply.sh"
  echo "  sudo bash $HERE/firewall-setup.sh"
fi

echo ""
echo "=== 4/5: Загрузка образов ==="
docker compose pull

echo ""
echo "=== 5/5: Запуск ==="
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d
sleep 3

if docker compose ps --status running | grep -q "tg-proxy"; then
  SECRET=$(grep ^SECRET .env | cut -d= -f2- | head -1)
  echo ""
  echo "Прокси запущен."
  echo "Ссылка: https://t.me/proxy?server=$IPV4&port=443&secret=$SECRET"
  echo "Ручной ввод: MTProto, $IPV4:443, секрет $SECRET"
  echo ""
  echo "Диагностика: bash $HERE/diagnose.sh"
else
  echo "Ошибка. Логи:"
  docker compose logs --tail=30
  exit 1
fi
