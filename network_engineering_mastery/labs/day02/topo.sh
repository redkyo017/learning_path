#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# Day 2 topology:  h1 --- r1 === r2 --- h2     (=== is the MTU 1400 link)
#   h1 eth0 10.2.1.10/24  <-> r1 eth1 10.2.1.1/24
#   r1 eth2 10.2.12.1/30  <-> r2 eth1 10.2.12.2/30
#   r2 eth2 10.2.2.1/24   <-> h2 eth0 10.2.2.10/24
# IPv6 mirrors it with fd00:2:1::/64, fd00:2:12::/64, fd00:2:2::/64.

# addr6 ns dev addr -> IPv6 address without the DAD delay (lab hosts are used at once).
addr6() { ip -n "$1" addr add "$3" dev "$2" nodad; }

build() {
  ns_add h1 r1 r2 h2
  veth h1 eth0 r1 eth1
  veth r1 eth2 r2 eth1
  veth r2 eth2 h2 eth0

  addr h1 eth0 10.2.1.10/24
  addr r1 eth1 10.2.1.1/24
  addr r1 eth2 10.2.12.1/30
  addr r2 eth1 10.2.12.2/30
  addr r2 eth2 10.2.2.1/24
  addr h2 eth0 10.2.2.10/24

  addr6 h1 eth0 fd00:2:1::10/64
  addr6 r1 eth1 fd00:2:1::1/64
  addr6 r1 eth2 fd00:2:12::1/64
  addr6 r2 eth1 fd00:2:12::2/64
  addr6 r2 eth2 fd00:2:2::1/64
  addr6 h2 eth0 fd00:2:2::10/64

  route h1 add default via 10.2.1.1
  route h2 add default via 10.2.2.1
  route r1 add 10.2.2.0/24 via 10.2.12.2
  route r2 add 10.2.1.0/24 via 10.2.12.1
  ip -n h1 -6 route add default via fd00:2:1::1
  ip -n h2 -6 route add default via fd00:2:2::1
  ip -n r1 -6 route add fd00:2:2::/64 via fd00:2:12::2
  ip -n r2 -6 route add fd00:2:1::/64 via fd00:2:12::1

  forwarding r1
  forwarding r2

  # The bottleneck sits between two routers, on BOTH ends of the link. A veth drops an
  # oversized frame at the receiver with no ICMP, and a 1400 MTU on a host would shrink
  # its TCP MSS so path MTU discovery would never run.
  ip -n r1 link set eth2 mtu 1400
  ip -n r2 link set eth1 mtu 1400
}

up() {
  require_netlab
  topo_down
  build
  # topo_down wipes /run/netlab, so the payload is created after it.
  head -c 200000 /dev/urandom > "$STATE_DIR/big.bin"
  bg h2 web python3 -m http.server 8080 --directory "$STATE_DIR"
  local i
  for i in $(seq 1 25); do
    if ip netns exec h2 ss -ltn | awk '$4 ~ /:8080$/ {f=1} END {exit !f}'; then break; fi
    sleep 0.2
  done
  topo_mark 02
  echo "Day 2 topology is up: h1 - r1 = r2 - h2 (r1 eth2 and r2 eth1 at MTU 1400)."
}

down() { require_netlab; topo_down; echo "Day 2 topology removed."; }

case "${1:-}" in
  up)   up ;;
  down) down ;;
  *)    echo "usage: bash labs/day02/topo.sh up|down" >&2; exit 2 ;;
esac
