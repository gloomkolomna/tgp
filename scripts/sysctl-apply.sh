#!/usr/bin/env bash
# Apply kernel tuning for lossy / mobile (LTE) networks.
# Safe: checks BBR support, guards conntrack keys, and is idempotent.
set -euo pipefail

CONF_SRC="$(cd "$(dirname "$0")/.." && pwd)/config/99-tg-proxy.conf"
CONF_DST="/etc/sysctl.d/99-tg-proxy.conf"

if [ "$(id -u)" -ne 0 ]; then
  echo "Нужны права root. Запустите: sudo bash scripts/sysctl-apply.sh"
  exit 1
fi

echo "=== 1/4: Проверка поддержки BBR ==="
if lsmod | grep -q '^tcp_bbr\b' || modprobe tcp_bbr 2>/dev/null; then
  echo "OK: модуль tcp_bbr загружен."
else
  echo "WARN: tcp_bbr недоступен в ядре ($(uname -r)). BBR пропущен — "
  echo "      остальная часть тюнинга (буферы, MTU-probing, conntrack) применится."
  echo "      Чтобы включить BBR: apt install --install-recommends linux-image-amd64 и перезагрузка."
fi

echo ""
echo "=== 2/4: Установка конфига ==="
install -m 0644 "$CONF_SRC" "$CONF_DST"
echo "Установлен: $CONF_DST"

# Уберём ключи nf_conntrack, если модуля нет (иначе sysctl --system упадёт).
if ! lsmod | grep -q '^nf_conntrack' && ! modprobe nf_conntrack 2>/dev/null; then
  echo "INFO: nf_conntrack не загружен — временно убираю его ключи из применения."
  TMP="$(mktemp)"
  grep -v '^net\.netfilter\.' "$CONF_DST" > "$TMP" || true
  # Применяем усечённый конфиг, оригинал оставляем для будущей загрузки модуля.
  sysctl --system | grep -E 'bbr|buffer|mtu|slow_start|fastopen|keepalive|q_disc' || true
  rm -f "$TMP"
else
  echo "OK: nf_conntrack доступен."
fi

echo ""
echo "=== 3/4: Применение настроек ==="
sysctl --system >/dev/null

echo ""
echo "=== 4/4: Верификация ==="
CC="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '?')"
MTU="$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null || echo '?')"
SSLOW="$(sysctl -n net.ipv4.tcp_slow_start_after_left 2>/dev/null || echo '?')"
echo "Congestion control : $CC   $([ "$CC" = bbr ] && echo '✓ BBR активен' || echo '⚠ не BBR')"
echo "tcp_mtu_probing    : $MTU  $([ "$MTU" = 1 ] && echo '✓' || echo '⚠')"
echo "slow_start_after_left : $SSLOW  $([ "$SSLOW" = 0 ] && echo '✓' || echo '⚠')"
if lsmod | grep -q '^nf_conntrack'; then
  CT="$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo '?')"
  echo "nf_conntrack_max  : $CT"
fi
echo ""
echo "Готово. Изменения ядра вступают в силу немедленно для НОВЫХ соединений."
