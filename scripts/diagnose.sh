#!/usr/bin/env bash
# Diagnostics for the MTProto proxy, focused on mobile (LTE) failure modes:
#   - is BBR active?
#   - MTU probing on?
#   - per-connection retransmits / send & recv rate (ss -ti)
#   - conntrack state counts and drops
#   - is MSS clamping installed?
#   - container status and counters
#
# Read-only. Safe to run anytime.
set -euo pipefail

mark() { [ "$(printf '%s' "$2")" = "$3" ] && printf '  [%sOK]   %s\n' '' "$1" || printf '  [%sWARN] %s (получили: %s, ожидаем: %s)\n' '' "$1" "$2" "$3"; }

echo "################################################################"
echo "# MTProto proxy diagnostics"
echo "################################################################"

echo ""
echo "=== Memory & swap (1 GB server — главное) ==="
free -h 2>/dev/null | awk 'NR==1{print "  "$0} /Mem|Swap/{print "  "$0}' || echo "  free недоступен"
MEMAVAIL_KB="$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null || echo 0)"
MEMAVAIL_MB=$(( MEMAVAIL_KB / 1024 ))
if [ "$MEMAVAIL_MB" -lt 150 ]; then
  echo "  [WARN] доступно < 150 MB RAM — риск OOM. Проверьте swap и mem_limit контейнера."
else
  echo "  [OK]   доступно ${MEMAVAIL_MB} MB RAM"
fi

echo ""
echo "=== Kernel: congestion control & buffers ==="
  CC="$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo '?')"
  mark "BBR активен" "$CC" "bbr"
  [ -f /proc/sys/net/ipv4/tcp_mtu_probing ] && MTU="$(cat /proc/sys/net/ipv4/tcp_mtu_probing)" || MTU="N/A"
  mark "tcp_mtu_probing" "$MTU" "1"
  [ -f /proc/sys/net/ipv4/tcp_slow_start_after_left ] && SSLOW="$(cat /proc/sys/net/ipv4/tcp_slow_start_after_left)" || SSLOW="N/A"
  mark "slow_start_after_left=0" "$SSLOW" "0"
  RMEM="$(cat /proc/sys/net/core/rmem_max 2>/dev/null || echo '?')"
  WMEM="$(cat /proc/sys/net/core/wmem_max 2>/dev/null || echo '?')"
  printf '  rmem_max / wmem_max : %s / %s\n' "$RMEM" "$WMEM"

echo ""
echo "=== conntrack (NAT state table) ==="
if lsmod | grep -q '^nf_conntrack'; then
  CT="$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo '?')"
  CTMAX="$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo '?')"
  printf '  active / max : %s / %s\n' "$CT" "$CTMAX"
  printf '  established timeout: %ss\n' "$(sysctl -n net.netfilter.nf_conntrack_tcp_timeout_established 2>/dev/null || echo '?')"
else
  echo "  nf_conntrack не загружен (нормально при network_mode: host без nft/iptables NAT)."
fi

echo ""
echo "=== TCP connections to/from :443 (top by retransmits/rate) ==="
if command -v ss >/dev/null 2>&1; then
  # field selection: show established conns on :443 with extended TCP info.
  ss -tinH 'state established' '( sport = :443 or dport = :443 )' 2>/dev/null \
    | awk '
      { for (i=1;i<=NF;i++){ if($i ~ /retrans/){rt=$i} if($i ~ /rtt:/){rtt=$i} if($i ~ /bbr/){cc="bbr"} if($i ~ /cubic/){cc="cubic"} }
        n++; printf "  %-3d rtt=%-14s %s %s\n", n, rtt, (cc==""?"":cc), (rt==""?"":rt) }
      END { if(n==0) print "  нет активных соединений на :443" }
    '
else
  echo "  ss не установлен (apt install iproute2)."
fi

echo ""
echo "=== MSS clamping rules ==="
if command -v nft >/dev/null 2>&1 && nft list table inet tg_proxy_clamp >/dev/null 2>&1; then
  echo "  [OK]   nftables MSS clamp активен"
  nft list chain inet tg_proxy_clamp output 2>/dev/null | grep -q maxseg && echo "  [OK]     OUTPUT chain (host-network)" || echo "  [WARN]   нет OUTPUT-правила (нужно для host-network)"
elif command -v iptables >/dev/null 2>&1; then
  if iptables -t mangle -S OUTPUT 2>/dev/null | grep -q TCPMSS; then
    echo "  [OK]   iptables MSS clamp активен (OUTPUT)"
  elif iptables -t mangle -S FORWARD 2>/dev/null | grep -q TCPMSS; then
    echo "  [WARN] iptables MSS только на FORWARD — переключитесь на host-network firewall"
  else
    echo "  [WARN] MSS clamping не найден"
  fi
else
  echo "  [WARN] MSS clamping не найден — большие пакеты могут пропадать на LTE. Запустите:"
  echo "         sudo bash scripts/firewall-setup.sh"
fi

echo ""
echo "=== Container ==="
if command -v docker >/dev/null 2>&1; then
  docker ps --filter name=tg-proxy --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
  echo ""
  # Memory of the container — critical on a 1 GB host (mem_limit is 384 MB).
  if docker stats --no-stream --format '  RSS: {{.MemUsage}}   (limit {{.MemPerc}})' tg-proxy 2>/dev/null; then :; fi
  echo ""
  echo "  RX/TX bytes (host eth0):"
  ip -s link show eth0 2>/dev/null | awk '/RX:|TX:/{getline; print "    "$1": "$2" bytes"}' || true
else
  echo "  docker не найден на этой машине (скрипт рассчитан на запуск на сервере)."
fi

echo ""
echo "=== Quick interpretation ==="
echo "  - retrans:N>0 на множестве соединений -> потери на пути; BBR + MSS clamp должны помогать."
echo "  - rtt высокий/прыгающий, cubic вместо bbr -> BBR не применился, проверьте sysctl-apply.sh."
echo "  - много TIME_WAIT -> поднимите reset_close_socket (уже handshake_error)."
echo "  - nf_conntrack_count близко к max -> поднимите nf_conntrack_max (99-tg-proxy.conf)."
