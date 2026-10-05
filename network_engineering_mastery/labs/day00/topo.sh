#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# The home router's DHCP server and DNS forwarder: one dnsmasq in namespace hr.
start_dnsmasq() {
  bg hr dhcp dnsmasq --no-daemon --conf-file=/dev/null --interface=lan0 --bind-interfaces \
    --dhcp-range=192.168.1.100,192.168.1.150,12h \
    --dhcp-option=option:router,192.168.1.1 \
    --dhcp-option=option:dns-server,192.168.1.1 \
    --dhcp-leasefile="$STATE_DIR/leases" --pid-file="$STATE_DIR/dnsmasq.pid" --log-dhcp \
    --address=/www.example.test/203.0.113.10 --port=53
  local i
  for i in $(seq 1 20); do
    ip netns exec hr ss -ulnp 2>/dev/null | /usr/bin/grep -q ':67 ' && return 0
    sleep 0.25
  done
  echo "dnsmasq did not start; see $STATE_DIR/dhcp.log" >&2
  return 1
}

build() {
  ns_add lap hr isp transit srv
  veth lap eth0 hr lan0
  veth hr wan0 isp cust0
  veth isp up0 transit down0
  veth transit srv0 srv eth0

  # Home router: LAN side, WAN side, default route to the ISP, many-to-one NAT.
  addr hr lan0 192.168.1.1/24
  addr hr wan0 100.64.0.2/30
  route hr add default via 100.64.0.1
  forwarding hr
  ip netns exec hr nft add table ip nat
  ip netns exec hr nft add chain ip nat postrouting '{ type nat hook postrouting priority 100; }'
  ip netns exec hr nft add rule ip nat postrouting oifname wan0 masquerade

  # ISP edge: carrier-grade NAT for the shared space 100.64.0.0/10.
  addr isp cust0 100.64.0.1/30
  addr isp up0 198.51.100.1/30
  route isp add default via 198.51.100.2
  forwarding isp
  ip netns exec isp nft add table ip nat
  ip netns exec isp nft add chain ip nat postrouting '{ type nat hook postrouting priority 100; }'
  ip netns exec isp nft add rule ip nat postrouting ip saddr 100.64.0.0/10 oifname up0 masquerade

  # Transit: knows its two neighbours and nothing about private or shared space.
  addr transit down0 198.51.100.2/30
  addr transit srv0 203.0.113.1/24
  forwarding transit

  # The server.
  addr srv eth0 203.0.113.10/24
  route srv add default via 203.0.113.1
  # Served content is created after topo_down, which wipes /run/netlab.
  echo "hello from the server" > "$STATE_DIR/index.html"
  bg srv web python3 -m http.server 8080 --directory "$STATE_DIR"
  local i
  for i in $(seq 1 20); do
    ip netns exec srv ss -ltn 2>/dev/null | /usr/bin/grep -q ':8080 ' && break
    sleep 0.25
  done

  # DHCP and DNS on the home router, then the laptop asks for an address.
  start_dnsmasq
  # The file must exist before the namespace command runs, so ip netns exec bind-mounts it
  # over /etc/resolv.conf and dhcpcd can write the DNS option into it.
  mkdir -p /etc/netns/lap && : > /etc/netns/lap/resolv.conf
  # A lease stored by an earlier run lives outside /run/netlab; forget it.
  rm -rf /var/lib/dhcpcd/* 2>/dev/null || true
  ip netns exec lap timeout 20 dhcpcd -4 -1 -L -B --nobackground -f /dev/null -o domain_name_servers eth0 >"$STATE_DIR/dhcpcd-lap.log" 2>&1 || true
  if ! ip -n lap -4 -o addr show dev eth0 | /usr/bin/grep -q 'inet 192\.168\.1\.'; then
    echo "The laptop got no DHCP lease; see $STATE_DIR/dhcpcd-lap.log and $STATE_DIR/dhcp.log" >&2
    exit 1
  fi
  # resolv.conf comes from the DHCP lease itself (option 6), written by dhcpcd.
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    topo_mark 00
    echo "Day 0 topology is up: lap -- hr (home) -- isp (CGNAT) -- transit -- srv (www.example.test)"
    ip -n lap -4 -o addr show dev eth0 | awk '{print "laptop address by DHCP: " $4}'
    ;;
  down)
    require_netlab
    topo_down
    echo "Day 0 topology is down."
    ;;
  *)
    echo "usage: bash labs/day00/topo.sh up|down" >&2
    exit 2
    ;;
esac
