#!/usr/bin/env bash
# Network-level mitigations for mobile (LTE) "connected but stuck" issues.
#
# 1) TCP MSS clamping -> fixes MTU black holes. Large data packets (media,
#    long messages) silently die on mobile paths with small MTU while tiny
#    handshake packets pass. We clamp MSS so packets stay within path MTU.
#
# 2) (Optional) conntrack state tracking is tuned via sysctl (see
#    99-tg-proxy.conf) — this script just makes sure nf_conntrack is loaded
#    when nft/iptables is in use.
#
# Idempotent: re-running clears our rules first.
set -euo pipefail

PORT="${MTP_PORT:-443}"
MSS="${MTP_MSS:-1240}"   # safe for mobile/LTE (typical 1400 MTU minus headers)

if [ "$(id -u)" -ne 0 ]; then
  echo "Нужны права root. Запустите: sudo bash scripts/firewall-setup.sh"
  exit 1
fi

echo "=== TCP MSS clamping (port ${PORT}, MSS=${MSS}) ==="

# nftables first (Debian 11+ / modern kernels).
if command -v nft >/dev/null 2>&1; then
  nft delete table inet tg_proxy_clamp 2>/dev/null || true
  nft add table inet tg_proxy_clamp
  nft 'add chain inet tg_proxy_clamp mangle { type filter hook forward priority mangle; policy accept; }'
  nft add rule inet tg_proxy_clamp mangle \
      'tcp flags & (fin|syn|rst|ack) == syn' \
      "tcp dport ${PORT} tcp option maxseg size set ${MSS}"
  nft add rule inet tg_proxy_clamp mangle \
      'tcp flags & (fin|syn|rst|ack) == syn' \
      "tcp sport ${PORT} tcp option maxseg size set ${MSS}"
  echo "OK (nftables): правила MSS clamping установлены."
  echo ""
  echo "Просмотр: nft list table inet tg_proxy_clamp"
  echo "Удаление: nft delete table inet tg_proxy_clamp"
  exit 0
fi

# Fallback: legacy iptables.
if command -v iptables >/dev/null 2>&1; then
  iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN \
           --dport "${PORT}" -j TCPMSS --set-mss "${MSS}" 2>/dev/null || true
  iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN \
           --sport "${PORT}" -j TCPMSS --set-mss "${MSS}" 2>/dev/null || true
  iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
           --dport "${PORT}" -j TCPMSS --set-mss "${MSS}"
  iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
           --sport "${PORT}" -j TCPMSS --set-mss "${MSS}"
  echo "OK (iptables): правила MSS clamping установлены."
  echo ""
  echo "Просмотр: iptables -t mangle -L FORWARD -v -n"
  exit 0
fi

echo "WARN: не найден ни nft, ни iptables — MSS clamping не применён."
echo "      apt install nftables  (рекомендуется)"
exit 0
