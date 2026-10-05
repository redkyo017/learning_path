#!/usr/bin/env bash
# Day 7 gauntlet.   bash labs/day07/gauntlet.sh list | start N | check N | reset
#   list     print the five symptoms
#   start N  rebuild the topology, inject incident N, print its symptom
#   check N  PASS (exit 0) / FAIL (exit 1) / topology not up (exit 2)
#   reset    rebuild the healthy topology
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

DAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SYM=(
  ""
  "The health check is green, but downloads of anything large hang. Small pages load."
  "The name resolves. The connection to the app times out."
  "Everything on-prem is unreachable since last night's change window."
  "curl: (6) Could not resolve host: api.onprem.corp"
  "We can see the SYN arrive on-prem. Nothing ever comes back."
)

usage() { echo "usage: bash labs/day07/gauntlet.sh list | start N | check N | reset   (N = 1..5)" >&2; exit 2; }

flush_caches() {
  local ns
  for ns in task vpcr tgw onp api; do ip -n "$ns" route flush cache 2>/dev/null || true; done
}

# poll_gone FUNC -> wait up to 20 s for FUNC to fail.
poll_gone() { local i; for i in $(seq 1 20); do "$1" || return 0; sleep 1; done; return 1; }

tgw_has_onprem() { local o; o=$(ip -n tgw route show 192.168.0.0/16 2>/dev/null || true); [[ "$o" == *gre1* ]]; }

inject_1() {
  ip netns exec tgw nft delete table ip clamp 2>/dev/null || true
  ip -n onp link set gre1 mtu 1500
  local ns
  for ns in tgw onp; do
    ip netns exec "$ns" nft delete table inet o2 2>/dev/null || true
    ip netns exec "$ns" nft -f - <<'NFT'
table inet o2 {
  chain c {
    type filter hook output priority 0; policy accept;
    icmp type 3 icmp code 4 drop
  }
}
NFT
  done
  flush_caches
}

inject_2() {
  ip -n tgw route replace 192.168.10.0/24 via 10.70.255.1
  flush_caches
}

inject_3() {
  vty onp 'configure terminal' 'route-map OUT deny 10' 'exit' 'router bgp 65000' \
    'address-family ipv4 unicast' 'neighbor 169.254.10.1 route-map OUT out' >/dev/null
  vty onp 'clear bgp * soft out' >/dev/null 2>&1 || true
  if ! poll_gone tgw_has_onprem; then
    vty onp 'clear bgp *' >/dev/null 2>&1 || true
    poll_gone tgw_has_onprem || true
  fi
  flush_caches
}

inject_4() {
  sed -i '/^forward-zone:/,$d' "$STATE_DIR/vpcr-dns.conf"
  local pid
  for pid in $(ip netns pids vpcr); do kill "$pid" 2>/dev/null || true; done
  sleep 1
  bg vpcr vpcr-dns unbound -d -c "$STATE_DIR/vpcr-dns.conf"
  local i
  for i in $(seq 1 20); do
    ip netns exec task dig +time=1 +tries=1 @10.70.1.2 localhost >/dev/null 2>&1 && break
    sleep 0.5
  done
}

inject_5() {
  local h
  h=$(ip netns exec onp nft -a list chain inet filter forward | awk '/ct state established,related accept/ {print $NF}')
  [ -z "$h" ] || ip netns exec onp nft delete rule inet filter forward handle "$h"
  ip netns exec onp conntrack -F >/dev/null 2>&1 || true
}

# --- checks ---------------------------------------------------------------------------
http_code() { ip netns exec task curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://api.onprem.corp:8080/ 2>/dev/null || true; }
healthy()   { [ "$(http_code)" = 200 ]; }
big_fetch() {
  local n
  n=$(ip netns exec task curl -s -o /dev/null -w '%{size_download}' --max-time 6 http://api.onprem.corp:8080/big.bin 2>/dev/null || true)
  [ "$n" = 300000 ]
}
tgw_via_tunnel() { local o; o=$(ip -n tgw route get 192.168.10.10 2>/dev/null || true); [[ "$o" == *"dev gre1"* ]]; }
tgw_learns() {
  local i; for i in $(seq 1 10); do tgw_has_onprem && return 0; sleep 1; done; return 1
}
name_ok() { local a; a=$(ip netns exec task dig +short +time=2 +tries=1 api.onprem.corp 2>/dev/null || true); [ "$a" = "192.168.10.10" ]; }
onp_tracks() { local o; o=$(ip netns exec onp nft list chain inet filter forward 2>/dev/null || true); [[ "$o" == *"ct state established,related accept"* ]]; }

do_check() {
  case "$1" in
    1) check "incident 1 check" big_fetch ;;
    2) check "incident 2 check" tgw_via_tunnel ;;
    3) check "incident 3 check" tgw_learns ;;
    4) check "incident 4 check" name_ok ;;
    5) check "incident 5 check" onp_tracks ;;
  esac
  check "healthy curl returns 200" healthy
  verify_finish 07
}

N="${2:-}"
valid_n() { [[ "$N" =~ ^[1-5]$ ]]; }

case "${1:-}" in
  list)
    for i in 1 2 3 4 5; do printf '%d. %s\n' "$i" "${SYM[$i]}"; done
    ;;
  reset)
    require_netlab
    bash "$DAY_DIR/topo.sh" up
    ;;
  start)
    valid_n || usage
    require_netlab
    bash "$DAY_DIR/topo.sh" up >/dev/null
    "inject_$N"
    fault_set 07 "$N"
    symptom "${SYM[$N]}"
    ;;
  check)
    valid_n || usage
    require_topo 07
    do_check "$N"
    ;;
  *)
    usage
    ;;
esac
