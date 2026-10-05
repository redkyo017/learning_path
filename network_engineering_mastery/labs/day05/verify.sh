#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 05

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

# poll SECONDS CMD... -> succeed as soon as CMD succeeds, give up after SECONDS.
poll() { local n=$1 i; shift; for ((i = 0; i < n; i++)); do "$@" && return 0; sleep 1; done; return 1; }

r2_est()      { poll 40 peer_est 10.5.12.2; }
r3_est()      { poll 40 peer_est 10.5.13.2; }
best_via_r3() { poll 15 bash -c "ip -n r1 route get 10.50.100.1 | /usr/bin/grep -q 'via 10.5.13.2'"; }
no_static()   { ! ip -n r1 route show 10.50.100.0/24 proto static | /usr/bin/grep -q .; }
lan_reaches() { poll 10 ip netns exec r1 ping -c2 -W1 -I 10.50.1.1 10.50.100.1; }

echo "Day 5 checks:"
check "r1<->r2 Established" r2_est
check "r1<->r3 Established" r3_est
check "r1 best path to 10.50.100.0/24 is via r3 (local-pref 200)" best_via_r3
check "no static route for 10.50.100.0/24 on r1" no_static
check "r1 lan reaches AWS prefix" lan_reaches
verify_finish 05
