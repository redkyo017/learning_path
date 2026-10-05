#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 03

# Fault A: s1 silently drops its service port.
ip netns exec s1 nft add table inet lab
ip netns exec s1 nft add chain inet lab in '{ type filter hook input priority 0; }'
ip netns exec s1 nft add rule inet lab in tcp dport 8080 drop

# Fault B: the client link is slow and lossy.
tc -n c1 qdisc add dev eth0 root netem delay 200ms loss 30%

# Fault C: the load balancer rewrites the client source address.
ip netns exec lb nft add rule ip nlb postrouting ip daddr 10.3.2.20 snat to 10.3.2.1

fault_set 03 1
symptom "Through the VIP, everything hangs. Directly, port 8081 says 'refused' instantly and 8080 hangs. Pings feel slow. And the app team says every request now comes from 10.3.2.1."
