#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

require_topo 01

# Field 3 of 'ip -br link' is the MAC address.
macs_unique() {
  local h
  for h in h1 h2 h3; do ip -n "$h" -br link show eth0 | awk '{print $3}'; done | sort | uniq -d | wc -l | /usr/bin/grep -qx 0
}
no_permanent_neigh() { ! ip -n h1 neigh show nud permanent | /usr/bin/grep -q .; }

check "h1 reaches h2" ip netns exec h1 ping -c3 -W1 10.1.0.2
check "h1 reaches h3" ip netns exec h1 ping -c3 -W1 10.1.0.3
check "MACs on h1..h3 are unique" macs_unique
check "h1 has no PERMANENT neighbour entries" no_permanent_neigh

verify_finish 01
