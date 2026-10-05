#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 05

r3_est() {
  vty r1 'show bgp summary json' 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for afi in d.values():
    if isinstance(afi, dict) and afi.get("peers", {}).get("10.5.13.2", {}).get("state") == "Established":
        sys.exit(0)
sys.exit(1)'
}

# Change 1: neighbour statement for 10.5.13.2.
vty r1 'configure terminal' 'router bgp 65001' 'neighbor 10.5.13.2 remote-as 65099' >/dev/null
vty r1 'clear bgp 10.5.13.2' >/dev/null 2>&1 || true
for _ in $(seq 1 15); do r3_est || break; sleep 1; done

# Change 2: a route entry for the AWS prefix.
ip -n r1 route add 10.50.100.0/24 via 10.5.12.2 proto static metric 10

fault_set 05 1
symptom "The DX path should be primary. Traffic is on the VPN path, and when we shut the VPN path in the last drill, traffic did not move."
