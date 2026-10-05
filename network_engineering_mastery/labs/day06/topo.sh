#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

DAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

build() {
  # --- Underlay and overlay: va == vb over 10.6.0.0/24, VXLAN VNI 100 on top ---
  ns_add va vb
  veth va u0 vb u0
  addr va u0 10.6.0.1/24
  addr vb u0 10.6.0.2/24
  ip -n va link add vxlan100 type vxlan id 100 local 10.6.0.1 remote 10.6.0.2 dstport 4789 dev u0
  ip -n vb link add vxlan100 type vxlan id 100 local 10.6.0.2 remote 10.6.0.1 dstport 4789 dev u0
  addr va vxlan100 172.16.0.1/24
  addr vb vxlan100 172.16.0.2/24
  ip -n va link set vxlan100 mtu 1450 up
  ip -n vb link set vxlan100 mtu 1450 up

  # --- DNS: five hosts on one bridge in sw, 10.6.10.0/24 ---
  ns_add sw dnsi dnsp cli app odns
  veth dnsi eth0 sw pdnsi
  veth dnsp eth0 sw pdnsp
  veth cli  eth0 sw pcli
  veth app  eth0 sw papp
  veth odns eth0 sw podns
  bridge_ns sw br0 pdnsi pdnsp pcli papp podns
  addr dnsi eth0 10.6.10.53/24
  addr dnsp eth0 10.6.10.54/24
  addr cli  eth0 10.6.10.10/24
  addr app  eth0 10.6.10.20/24
  addr odns eth0 10.6.10.60/24

  bg dnsi dns-internal unbound -d -c "$DAY_DIR/dns/internal.conf"
  bg dnsp dns-public   unbound -d -c "$DAY_DIR/dns/public.conf"
  bg odns dns-onprem   unbound -d -c "$DAY_DIR/dns/onprem.conf"

  # topo_down wiped /etc/netns, so write the client's resolver config now.
  mkdir -p /etc/netns/cli
  printf 'nameserver 10.6.10.53\noptions ndots:1\n' > /etc/netns/cli/resolv.conf

  wait_dns 10.6.10.53 app.corp.internal 10.6.10.20
  wait_dns 10.6.10.54 app.corp.internal 203.0.113.20
  wait_dns 10.6.10.53 db.onprem.corp 192.168.20.5   # dnsi -> odns forwarding
  wait_dns 10.6.10.60 app.corp.internal 10.6.10.20  # odns -> dnsi forwarding
}

# wait_dns SERVER NAME EXPECTED -> poll up to ~5 s until cli gets the expected answer.
wait_dns() {
  local i got
  for i in $(seq 1 20); do
    got=$(ip netns exec cli dig +short +time=1 +tries=1 "@$1" "$2" 2>/dev/null || true)
    [ "$got" = "$3" ] && return 0
    sleep 0.25
  done
  echo "unbound at $1 did not answer $2 with $3 (got '${got}'); see /run/netlab/dns-*.log" >&2
  exit 1
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    topo_mark 06
    echo "Day 6 topology is up: va == vb (VXLAN 100); cli, dnsi .53, dnsp .54, odns .60, app .20 on sw"
    ;;
  down)
    require_netlab
    topo_down
    echo "Day 6 topology is down."
    ;;
  *)
    echo "usage: bash labs/day06/topo.sh up|down" >&2
    exit 2
    ;;
esac
