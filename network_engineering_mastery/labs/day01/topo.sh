#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# Day 1 topology: three hosts on one bridge (a learning switch).
#
#   h1 eth0 --- p1 \
#   h2 eth0 --- p2  >-- br0 (inside namespace "sw")
#   h3 eth0 --- p3 /
#
# One broadcast domain, 10.1.0.0/24. Fixed locally administered MACs
# (02: prefix) so captures match SOLUTION.md.

build() {
  ns_add sw h1 h2 h3
  veth h1 eth0 sw p1
  veth h2 eth0 sw p2
  veth h3 eth0 sw p3
  bridge_ns sw br0 p1 p2 p3
  local i
  for i in 1 2 3; do
    ip -n "h$i" link set eth0 address "02:00:00:00:01:0$i"
    addr "h$i" eth0 "10.1.0.$i/24"
  done
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    topo_mark 01
    echo "Day 1 topology is up: h1 10.1.0.1, h2 10.1.0.2, h3 10.1.0.3 on bridge br0 in sw."
    ;;
  down)
    require_netlab
    topo_down
    echo "Day 1 topology removed."
    ;;
  *)
    echo "usage: bash labs/day01/topo.sh up|down" >&2
    exit 2
    ;;
esac
