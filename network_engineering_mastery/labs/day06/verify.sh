#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 06

cli_internal()  { [ "$(ip netns exec cli dig +short +time=2 +tries=1 app.corp.internal)" = 10.6.10.20 ]; }
# A 1472-byte DF ping must never vanish: it succeeds, or the kernel refuses it locally.
overlay_big()   { local out; out=$(ip netns exec va ping -c1 -W1 -M do -s 1472 172.16.0.2 2>&1 || true)
                  case "$out" in *"1 received"*|*"message too long"*) return 0;; *) return 1;; esac; }
overlay_mtu()   { ip -n va -j link show vxlan100 | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)[0]["mtu"] <= 1450 else 1)'; }
cli_onprem()    { [ "$(ip netns exec cli dig +short +time=2 +tries=1 db.onprem.corp)" = 192.168.20.5 ]; }

echo "Day 6 checks:"
check "cli resolves app.corp.internal to the internal view" cli_internal
check "overlay never black-holes a 1472-byte DF ping" overlay_big
check "overlay MTU <= 1450" overlay_mtu
check "cli resolves db.onprem.corp via forwarding" cli_onprem
verify_finish 06
