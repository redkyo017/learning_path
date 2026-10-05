#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

DAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

build() {
  ns_add c1 lb s1
  veth c1 eth0 lb eth1
  veth lb eth2 s1 eth0

  addr c1 eth0 10.3.1.10/24
  route c1 add default via 10.3.1.1

  addr lb eth1 10.3.1.1/24
  addr lb eth2 10.3.2.1/24
  addr lb lo   10.3.9.100/32        # the VIP lives on lb's loopback
  forwarding lb

  addr s1 eth0 10.3.2.20/24
  route s1 add default via 10.3.2.1

  # Load the rules first: the per-namespace conntrack sysctls exist only once
  # conntrack is active in that namespace, and the NAT table activates it.
  ip netns exec lb nft -f "$DAY_DIR/lb.nft"
  ip netns exec lb sysctl -qw net.netfilter.nf_conntrack_tcp_loose=0
  ip netns exec lb sysctl -qw net.netfilter.nf_conntrack_tcp_timeout_established=20

  # Served content is created after topo_down, which wipes /run/netlab.
  echo "hello from s1" > "$STATE_DIR/index.html"
  bg s1 web python3 -m http.server 8080 --directory "$STATE_DIR"

  local i
  for i in $(seq 1 20); do
    ip netns exec s1 ss -ltn 2>/dev/null | /usr/bin/grep -q ':8080 ' && break
    sleep 0.25
  done
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    topo_mark 03
    echo "Day 3 topology is up: c1 -- lb(VIP 10.3.9.100) -- s1"
    ;;
  down)
    require_netlab
    topo_down
    echo "Day 3 topology is down."
    ;;
  *)
    echo "usage: bash labs/day03/topo.sh up|down" >&2
    exit 2
    ;;
esac
