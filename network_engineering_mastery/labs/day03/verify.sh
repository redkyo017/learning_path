#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 03

c1_no_netem()    { ! tc -n c1 qdisc show dev eth0 | /usr/bin/grep -q netem; }
vip_ten_ok()     { local i; for i in $(seq 1 10); do ip netns exec c1 curl -s -o /dev/null --max-time 2 http://10.3.9.100/ || return 1; done; }
s1_no_drop()     { ! ip netns exec s1 nft list ruleset | /usr/bin/grep -q 'dport 8080 drop'; }
lb_no_snat()     { ! ip netns exec lb nft list table ip nlb | /usr/bin/grep -q 'snat\|masquerade'; }

echo "Day 3 checks:"
check "c1 has no netem qdisc" c1_no_netem
check "10 sequential requests to the VIP succeed within 2 s each" vip_ten_ok
check "s1 does not silently drop 8080" s1_no_drop
check "s1 sees the real client IP (no SNAT on lb)" lb_no_snat
verify_finish 03
