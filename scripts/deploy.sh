#!/usr/bin/env bash
# Full deploy: git pull -> .env check -> kernel tuning -> firewall ->
#              pull image -> up -> verify -> print connection link.
#
# Kernel / firewall steps require root; if not root they are skipped with a
# warning (run them manually with sudo) so the proxy itself still deploys.
set -euo pipefail

REPO_URL="https://github.com/gloomkolomna/tgp.git"
PROJECT_DIR="/opt/tg-proxy"
IPV4="5.188.20.78"
DOMAIN="Xmax.ru"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=== 1/7: Получение свежего кода из $REPO_URL ==="
if [ -d "$PROJECT_DIR/.git" ]; then
  cd "$PROJECT_DIR"
  git pull
else
  git clone "$REPO_URL" "$PROJECT_DIR"
  cd "$PROJECT_DIR"
fi

echo ""
echo "=== 2/7: Проверка .env ==="
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Создан .env из .env.example"
  echo "Укажите SECRET: nano $PROJECT_DIR/.env"
  echo "Сгенерировать: openssl rand -hex 16"
  exit 1
fi

# Load .env into the environment so docker compose can interpolate ${SECRET}.
set -a
# shellcheck disable=SC1091
. ./.env
set +a

# Health check: on a 1 GB / 1 vCPU box, lack of swap is the #1 cause of OOM
# kills when Erlang + Docker spike together. Warn (don't fail) if absent.
echo ""
echo "=== 2b/7: Проверка ресурсов сервера ==="
RAM_KB="$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0)"
SWAP_KB="$(awk '/SwapTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0)"
RAM_MB=$(( RAM_KB / 1024 ))
SWAP_MB=$(( SWAP_KB / 1024 ))
echo "RAM: ${RAM_MB} MB, Swap: ${SWAP_MB} MB"
if [ "$SWAP_MB" -lt 256 ]; then
  echo "WARN: swap < 256 MB. На сервере с ${RAM_MB} MB RAM настоятельно рекомендуется swap"
  echo "      (хотя бы 1 GB), иначе при пиках Erlang+Docker может быть OOM-killed."
  echo "      Создать swap:"
  echo "        fallocate -l 1G /swapfile && chmod 600 /swapfile"
  echo "        mkswap /swapfile && swapon /swapfile"
  echo "        echo '/swapfile none swap sw 0 0' >> /etc/fstab"
fi

# 3/7: kernel tuning for lossy/mobile networks (best-effort).
echo ""
echo "=== 3/7: Тюнинг ядра под LTE (BBR, буферы, MTU-probing, conntrack) ==="
if [ "$(id -u)" -eq 0 ]; then
  bash "$HERE/sysctl-apply.sh" || echo "WARN: sysctl-apply завершился с ошибкой (продолжаем)."
else
  echo "SKIP: не root. Примените вручную:  sudo bash $HERE/sysctl-apply.sh"
fi

# 4/7: firewall MSS clamping for MTU black holes (best-effort).
echo ""
echo "=== 4/7: Firewall: MSS clamping (фикс MTU black hole на LTE) ==="
if [ "$(id -u)" -eq 0 ]; then
  bash "$HERE/firewall-setup.sh" || echo "WARN: firewall-setup завершился с ошибкой (продолжаем)."
else
  echo "SKIP: не root. Примените вручную:  sudo bash $HERE/firewall-setup.sh"
fi

echo ""
echo "=== 5/7: Загрузка образа ==="
docker compose pull

echo ""
echo "=== 6/7: Запуск ==="
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d
sleep 3

# 7/7: verify + build link.
echo ""
echo "=== 7/7: Проверка ==="
DOMAIN_HEX=$(printf '%s' "$DOMAIN" | xxd -p | tr -d '\n')
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
  echo "Оптимизация под LTE:"
  CC="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '?')"
  echo "  Congestion control: $CC   (ожидается bbr)"
  echo "  Сервер: ~5 пользователей, лимит RAM контейнера 384 MB, max_connections=500"
  echo "  Маскировка: TLS 1.3 под $DOMAIN + domain_fronting (DPI-пробы форвардятся)"
  echo ""
  echo "Команды:"
  echo "  Статус:      docker compose ps"
  echo "  Логи:        docker compose logs -f"
  echo "  Перезапуск:  docker compose restart"
  echo "  Диагностика: bash $HERE/diagnose.sh"
  echo "=========================================="
else
  echo "Ошибка запуска. Логи:"
  docker compose logs --tail=40
  exit 1
fi
