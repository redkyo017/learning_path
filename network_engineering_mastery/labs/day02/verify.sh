#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 02

route_via_r1() { ip -n h1 route get 10.2.2.10 | /usr/bin/grep -q 'via 10.2.1.1'; }

check "h1 routes to h2 via r1" route_via_r1
check "h1 pings h2 (v4)" ip netns exec h1 ping -c2 -W1 10.2.2.10
check "h1 pings h2 (v6)" ip netns exec h1 ping -6 -c2 -W1 fd00:2:2::10
check "200 KB transfer h1→h2 completes in 5 s" ip netns exec h1 curl -s -o /dev/null --max-time 5 http://10.2.2.10:8080/big.bin

verify_finish 02
