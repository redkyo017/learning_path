#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

DAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

build() {
  ns_add h1 fw r2 h2 ext sw1 sw2

  # Inside LAN 10.4.1.0/24: bridge in sw1 with h1, fw and r2.
  veth h1 eth0 sw1 p1
  veth fw eth1 sw1 p2
  veth r2 eth1 sw1 p3
  bridge_ns sw1 br0 p1 p2 p3

  # Server LAN 10.4.2.0/24: bridge in sw2 with h2, fw and r2.
  veth h2 eth0 sw2 p1
  veth fw eth2 sw2 p2
  veth r2 eth2 sw2 p3
  bridge_ns sw2 br0 p1 p2 p3

  # Outside link.
  veth fw eth9 ext eth0

  addr h1 eth0 10.4.1.10/24
  route h1 add default via 10.4.1.1

  addr fw eth1 10.4.1.1/24
  addr fw eth2 10.4.2.1/24
  addr fw eth9 198.51.100.1/24
  forwarding fw

  addr r2 eth1 10.4.1.2/24
  addr r2 eth2 10.4.2.2/24
  forwarding r2

  addr h2 eth0 10.4.2.10/24
  route h2 add default via 10.4.2.1

  addr ext eth0 198.51.100.10/24      # no route to 10.4.0.0/16 on purpose

  ip netns exec fw nft -f "$DAY_DIR/fw.nft"

  # Served content is created after topo_down, which wipes /run/netlab.
  echo "hello from the server" > "$STATE_DIR/index.html"
  bg h2 web2 python3 -m http.server 8080 --directory "$STATE_DIR"
  bg ext webx python3 -m http.server 8080 --directory "$STATE_DIR"

  local i
  for i in $(seq 1 20); do
    ip netns exec h2 ss -ltn 2>/dev/null | /usr/bin/grep -q ':8080 ' \
      && ip netns exec ext ss -ltn 2>/dev/null | /usr/bin/grep -q ':8080 ' && break
    sleep 0.25
  done
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    topo_mark 04
    echo "Day 4 topology is up: h1 -- fw -- h2 (r2 beside fw), fw -- ext"
    ;;
  down)
    require_netlab
    topo_down
    echo "Day 4 topology is down."
    ;;
  *)
    echo "usage: bash labs/day04/topo.sh up|down" >&2
    exit 2
    ;;
esac
