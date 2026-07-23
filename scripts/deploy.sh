#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gloomkolomna/tgp.git"
PROJECT_DIR="/opt/tg-proxy"
IPV4="5.188.20.78"
DOMAIN="www.google.com"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=== 1/5: Получение свежего кода ==="
if [ -d "$PROJECT_DIR/.git" ]; then
  cd "$PROJECT_DIR"; git pull
else
  git clone "$REPO_URL" "$PROJECT_DIR"; cd "$PROJECT_DIR"
fi

echo ""
echo "=== 2/5: Проверка .env ==="
[ ! -f .env ] && cp .env.example .env && { echo "Укажите SECRET: nano $PROJECT_DIR/.env"; exit 1; }
set -a; . ./.env; set +a

echo ""
echo "=== 3/5: Генерация config.py ==="
cat > config/config.py << PYEOF
PORT = 443
USERS = {"user": "${SECRET}"}
MODES = {"classic": False, "secure": False, "tls": True}
TLS_DOMAIN = "${DOMAIN}"
AD_TAG = "00000000000000000000000000000000"
USE_MIDDLE_PROXY = True
PYEOF
echo "Конфиг: TLS=${DOMAIN}, TLS-only"

echo ""
echo "=== 4/5: Тюнинг (опционально) ==="
if [ "$(id -u)" -eq 0 ]; then
  bash "$HERE/sysctl-apply.sh" || true
  bash "$HERE/firewall-setup.sh" || true
fi

echo ""
echo "=== 5/5: Запуск ==="
docker compose pull 2>/dev/null || echo "Образ не найден на Docker Hub, пробую сборку..."
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d
sleep 4

if docker compose ps --status running | grep -q "tg-proxy"; then
  DOMAIN_HEX=$(printf '%s' "$DOMAIN" | xxd -p | tr -d '\n')
  LINK_SECRET="ee${SECRET}${DOMAIN_HEX}"
  echo ""
  echo "=========================================="
  echo " Прокси запущен (alexbers/mtprotoproxy)"
  echo "=========================================="
  echo "Ссылка: https://t.me/proxy?server=$IPV4&port=443&secret=$LINK_SECRET"
  echo "Ручной ввод: MTProto, $IPV4:443, секрет $LINK_SECRET"
  echo ""
  echo "Логи: docker compose logs -f"
  echo "=========================================="
else
  echo "Ошибка. Логи:"
  docker compose logs --tail=30
  exit 1
fi
