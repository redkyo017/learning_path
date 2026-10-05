#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 06

# Fault A: each VTEP is rebuilt with MTU 1500 and DF set on the outer packet.
# (No "dev u0": a VXLAN bound to a lower device refuses an MTU above lower minus 50.)
rebuild() {  # rebuild NS LOCAL REMOTE OVERLAY-ADDR  (mtu is a link option: before "type")
  ip -n "$1" link del vxlan100
  ip -n "$1" link add vxlan100 mtu 1500 type vxlan id 100 local "$2" remote "$3" dstport 4789 df set
  ip -n "$1" addr add "$4" dev vxlan100
  ip -n "$1" link set vxlan100 up
  ip -n "$1" route flush cache
}
rebuild va 10.6.0.1 10.6.0.2 172.16.0.1/24
rebuild vb 10.6.0.2 10.6.0.1 172.16.0.2/24

# Fault B: the client now asks the public view (unbound caches are per server).
printf 'nameserver 10.6.10.54\noptions ndots:1\n' > /etc/netns/cli/resolv.conf

fault_set 06 1
symptom "Small requests across the overlay work and large ones vanish. And app.corp.internal now resolves to an address nobody recognizes."
