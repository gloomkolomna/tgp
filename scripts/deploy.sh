#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gloomkolomna/tgp.git"
PROJECT_DIR="/opt/tg-proxy"
IPV4="5.188.20.78"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=== 1/4: Получение свежего кода ==="
if [ -d "$PROJECT_DIR/.git" ]; then cd "$PROJECT_DIR"; git pull
else git clone "$REPO_URL" "$PROJECT_DIR"; cd "$PROJECT_DIR"; fi

echo ""
echo "=== 2/4: Проверка .env ==="
[ ! -f .env ] && cp .env.example .env && { echo "Укажите SECRET: nano $PROJECT_DIR/.env"; exit 1; }
set -a; . ./.env; set +a

echo ""
echo "=== 3/4: Тюнинг ==="
if [ "$(id -u)" -eq 0 ]; then
  bash "$HERE/sysctl-apply.sh" || true
  bash "$HERE/firewall-setup.sh" || true
fi

echo ""
echo "=== 4/4: Запуск ==="
docker compose pull
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
  echo "WiFi: быстро. LTE: медленно, но стабильно."
  echo "BBR + MSS clamping применены для ускорения."
else
  docker compose logs --tail=30
  exit 1
fi
