#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

DAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# peer_est PEER -> success when r1 reports PEER as Established.
peer_est() {
  vty r1 'show bgp summary json' 2>/dev/null | python3 -c '
import json, sys
peer = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for afi in d.values():
    if isinstance(afi, dict) and afi.get("peers", {}).get(peer, {}).get("state") == "Established":
        sys.exit(0)
sys.exit(1)' "$1"
}

both_est()   { peer_est 10.5.12.2 && peer_est 10.5.13.2; }
via_r3()     { ip -n r1 route get 10.50.100.1 2>/dev/null | /usr/bin/grep -q 'via 10.5.13.2'; }
lan_reaches() { ip netns exec r1 ping -c1 -W1 -I 10.50.1.1 10.50.100.1 >/dev/null 2>&1; }

build() {
  ns_add r1 r2 r3 r4
  veth r1 eth0 r2 eth0       # 10.5.12.0/30
  veth r1 eth1 r3 eth0       # 10.5.13.0/30
  veth r2 eth1 r4 eth0       # 10.5.24.0/30
  veth r3 eth1 r4 eth1       # 10.5.34.0/30

  addr r1 eth0 10.5.12.1/30; addr r2 eth0 10.5.12.2/30
  addr r1 eth1 10.5.13.1/30; addr r3 eth0 10.5.13.2/30
  addr r2 eth1 10.5.24.1/30; addr r4 eth0 10.5.24.2/30
  addr r3 eth1 10.5.34.1/30; addr r4 eth1 10.5.34.2/30

  ip -n r1 link add lo1 type dummy; addr r1 lo1 10.50.1.1/24;   ip -n r1 link set lo1 up
  ip -n r4 link add lo1 type dummy; addr r4 lo1 10.50.100.1/24; ip -n r4 link set lo1 up

  local ns ifc
  for ns in r1 r2 r3 r4; do
    forwarding "$ns"
    # Replies can return on a different link than the best path, so no strict reverse-path check.
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.all.rp_filter=0
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.default.rp_filter=0
    for ifc in eth0 eth1; do ip netns exec "$ns" sysctl -qw "net.ipv4.conf.$ifc.rp_filter=0"; done
    frr_up "$ns" "$DAY_DIR/frr/$ns.conf"
  done
}

wait_ready() {
  local i
  for i in $(seq 1 40); do both_est && break; sleep 1; done
  both_est || { echo "r1 did not reach both peers Established within 40 s" >&2; return 1; }
  # Established is not converged: wait for the best path and a working return path.
  for i in $(seq 1 20); do via_r3 && lan_reaches && return 0; sleep 1; done
  echo "BGP is up but routes did not converge within 20 s" >&2
  return 1
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    wait_ready
    topo_mark 05
    echo "Day 5 topology is up: r1(65001) -- r2(65002) / r3(65003) -- r4(64512, 10.50.100.0/24)"
    ;;
  down)
    require_netlab
    topo_down
    echo "Day 5 topology is down."
    ;;
  *)
    echo "usage: bash labs/day05/topo.sh up|down" >&2
    exit 2
    ;;
esac
