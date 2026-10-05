#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 02

# Fault A: both routers silently drop the ICMP "fragmentation needed" they originate.
for ns in r1 r2; do
  ip netns exec "$ns" nft add table inet lab
  ip netns exec "$ns" nft add chain inet lab out '{ type filter hook output priority 0; }'
  ip netns exec "$ns" nft add rule inet lab out icmp type destination-unreachable icmp code frag-needed drop
done

# Drop any PMTU exception learned while the topology was healthy; a cached 1400 in h2
# would let h2 send small segments and hide the black hole.
for ns in h1 h2 r1 r2; do ip -n "$ns" route flush cache; done

# Fault B: a more specific route in h1 pointing at an on-link next hop that does not exist.
ip -n h1 route add 10.2.2.0/25 via 10.2.1.99

fault_set 02 1
symptom "Pings to 10.2.2.10 fail; nobody touched the default route. Earlier, with ping working, a download from h2 hung forever."
