#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 04

h1_to_h2()    { ip netns exec h1 curl -sf -o /dev/null --max-time 3 http://10.4.2.10:8080/; }
h1_to_ext()   { ip netns exec h1 curl -sf -o /dev/null --max-time 3 http://198.51.100.10:8080/; }
h2_via_fw()   { ip -n h2 route get 10.4.1.10 | /usr/bin/grep -q 'via 10.4.2.1'; }
fw_masq()     { ip netns exec fw nft list table ip nat | /usr/bin/grep -q masquerade; }

echo "Day 4 checks:"
check "h1 -> h2:8080" h1_to_h2
check "h1 -> ext:8080 (via NAT)" h1_to_ext
check "h2 returns to 10.4.1.0/24 via fw" h2_via_fw
check "fw masquerades outbound" fw_masq
verify_finish 04
