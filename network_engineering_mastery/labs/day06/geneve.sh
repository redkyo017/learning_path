#!/usr/bin/env bash
# GWLB on the wire: src -> gwlb -> (GENEVE) -> appl -> (GENEVE) -> gwlb -> dst.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

build() {
  ns_add src gwlb appl dst
  veth src eth0 gwlb s0
  veth gwlb d0 dst eth0
  veth gwlb u0 appl u0
  addr src eth0 10.61.0.10/24; route src add default via 10.61.0.1
  addr gwlb s0 10.61.0.1/24
  addr gwlb d0 10.62.0.1/24
  addr dst eth0 10.62.0.10/24; route dst add default via 10.62.0.1

  # Underlay 10.60.0.0/30 and the GENEVE tunnel (VNI 1, UDP 6081) on top of it.
  addr gwlb u0 10.60.0.1/30
  addr appl u0 10.60.0.2/30
  ip -n gwlb link add gnv0 type geneve id 1 remote 10.60.0.2 dstport 6081
  ip -n appl link add gnv0 type geneve id 1 remote 10.60.0.1 dstport 6081
  addr gwlb gnv0 10.60.1.1/30
  addr appl gnv0 10.60.1.2/30
  ip -n gwlb link set gnv0 up
  ip -n appl link set gnv0 up

  forwarding gwlb
  forwarding appl
  # Packets come back in on the interface they must leave by, and the inner
  # source is not the tunnel peer: no redirects, no reverse-path filtering.
  local ns i
  for ns in gwlb appl; do
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.all.send_redirects=0
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.all.rp_filter=0
  done
  for i in s0 d0 u0 gnv0; do ip netns exec gwlb sysctl -qw "net.ipv4.conf.$i.rp_filter=0"; done
  ip netns exec appl sysctl -qw net.ipv4.conf.gnv0.rp_filter=0

  # gwlb: everything that arrives from src or dst goes to the appliance first.
  route gwlb add default via 10.60.1.2 dev gnv0 table 100
  ip -n gwlb rule add iif s0 lookup 100 priority 100
  ip -n gwlb rule add iif d0 lookup 100 priority 100
  # appl: forward, then hairpin back through the same tunnel.
  route appl add 10.0.0.0/8 via 10.60.1.1 dev gnv0
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    echo "GWLB lab is up: src 10.61.0.10 -> gwlb -> appl (GENEVE VNI 1) -> gwlb -> dst 10.62.0.10"
    ip netns exec src ping -c3 -W2 10.62.0.10
    ;;
  down)
    require_netlab
    topo_down
    echo "GWLB lab is down."
    ;;
  *)
    echo "usage: bash labs/day06/geneve.sh up|down" >&2
    exit 2
    ;;
esac
