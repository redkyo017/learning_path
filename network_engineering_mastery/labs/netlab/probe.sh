#!/usr/bin/env bash
# probe.sh — does this Docker host's kernel and the netlab image support every
# feature the course needs? Run it inside netlab, from /course:
#
#   docker compose -p netlab exec netlab bash labs/netlab/probe.sh
#
# Prints "OK <feature>" or "MISSING <feature>: <first stderr line>" for each of
# 13 features, then exits 0 only if all 13 are OK.
#
# Each check runs in its own child bash process (probe.sh --one NAME) so that
# `set -e` works inside the check and a failure cannot abort the other checks.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# ---- the checks (run only in --one mode) -----------------------------------

# Two namespaces joined by a veth pair on 10.99.0.0/24.
base() { ns_add pa pb; veth pa e0 pb e0; addr pa e0 10.99.0.1/24; addr pb e0 10.99.0.2/24; }

c_netns_veth() {
  base
  ip netns exec pa ping -c1 -W2 10.99.0.2 >/dev/null
}

c_bridge_vlan() {
  ns_add pa
  ip -n pa link add br0 type bridge vlan_filtering 1
  ip -n pa link add d0 type dummy
  ip -n pa link set d0 master br0
  ip netns exec pa bridge vlan add dev d0 vid 10
  ip netns exec pa bridge vlan show dev d0 | grep -w 10 >/dev/null
}

c_vxlan() {
  base
  ip -n pa link add vx0 type vxlan id 100 local 10.99.0.1 remote 10.99.0.2 dstport 4789 dev e0
  ip -n pb link add vx0 type vxlan id 100 local 10.99.0.2 remote 10.99.0.1 dstport 4789 dev e0
  addr pa vx0 172.16.0.1/24; addr pb vx0 172.16.0.2/24
  ip -n pa link set vx0 up; ip -n pb link set vx0 up
  ip netns exec pa ping -c1 -W2 172.16.0.2 >/dev/null
}

c_nft_nat() {
  ns_add pa
  ip netns exec pa nft -f - <<'EOF'
table ip nat {
  chain post {
    type nat hook postrouting priority 100; policy accept;
    oifname "e0" masquerade
  }
}
EOF
  ip netns exec pa nft list ruleset | grep masquerade >/dev/null
}

c_conntrack() {
  base
  ip netns exec pa ping -c1 -W2 10.99.0.2 >/dev/null
  ip netns exec pa conntrack -L >/dev/null
}

c_netem() {
  base
  ip netns exec pa tc qdisc add dev e0 root netem delay 50ms
  local out rtt
  out=$(ip netns exec pa ping -c2 -W3 10.99.0.2)
  rtt=$(printf '%s\n' "$out" | sed -n -E 's#^rtt min/avg/max/mdev = ([0-9.]+)/.*#\1#p')
  [ -n "$rtt" ] || { echo "no rtt line in ping output" >&2; return 1; }
  awk -v v="$rtt" 'BEGIN { exit !(v >= 50) }' || { echo "rtt ${rtt} ms is below 50 ms" >&2; return 1; }
}

c_frr_bgp() {
  base
  local ns peer asn rid
  for ns in pa pb; do
    if [ "$ns" = pa ]; then peer=10.99.0.2; asn=65001; rid=1.1.1.1; else peer=10.99.0.1; asn=65002; rid=2.2.2.2; fi
    cat > "$STATE_DIR/$ns.conf" <<EOF
frr defaults traditional
hostname $ns
router bgp $asn
 bgp router-id $rid
 no bgp ebgp-requires-policy
 neighbor $peer remote-as $((asn == 65001 ? 65002 : 65001))
EOF
    chmod 644 "$STATE_DIR/$ns.conf"
  done
  frr_up pa "$STATE_DIR/pa.conf"
  frr_up pb "$STATE_DIR/pb.conf"
  local i
  for i in $(seq 1 30); do
    if vty pa 'show bgp summary json' 2>/dev/null | grep -E '"state": ?"Established"' >/dev/null; then return 0; fi
    sleep 1
  done
  echo "BGP session did not reach Established within 30 s" >&2
  return 1
}

c_unbound() {
  base
  cat > "$STATE_DIR/probe-unbound.conf" <<'EOF'
server:
  interface: 10.99.0.1
  access-control: 0.0.0.0/0 allow
  do-daemonize: no
  chroot: ""
  username: ""
  pidfile: ""
  local-zone: "probe.test." static
  local-data: "probe.test. A 10.99.0.99"
EOF
  bg pa unbound unbound -d -c "$STATE_DIR/probe-unbound.conf"
  local i got
  for i in 1 2 3 4 5; do
    got=$(ip netns exec pb dig +short +time=1 +tries=1 @10.99.0.1 probe.test 2>/dev/null || true)
    if [ "$got" = 10.99.0.99 ]; then return 0; fi
    sleep 1
  done
  echo "dig got '${got}', expected 10.99.0.99 (unbound log: $(head -n1 "$STATE_DIR/unbound.log" 2>/dev/null))" >&2
  return 1
}

c_xfrm() {
  ns_add pa
  ip netns exec pa ip xfrm state add src 10.99.0.1 dst 10.99.0.2 proto esp spi 0x1000 \
    reqid 1 mode tunnel aead 'rfc4106(gcm(aes))' 0x0102030405060708090a0b0c0d0e0f1011121314 128
  ip netns exec pa ip xfrm state list | grep 'spi 0x00001000' >/dev/null
}

c_netns_resolv() {
  ns_add pb
  mkdir -p /etc/netns/pb
  echo "nameserver 10.99.0.1" > /etc/netns/pb/resolv.conf
  ip netns exec pb cat /etc/resolv.conf | grep 10.99.0.1 >/dev/null
}

c_vrf() {
  # VRF devices are not in Docker Desktop's kernel; VRF-lite = policy routing tables.
  base
  ns_add pc
  veth pa f0 pc f0
  ip -n pa addr add 10.98.0.1/24 dev f0 noprefixroute   # no connected route in main
  addr pc f0 10.98.0.2/24
  route pc add default via 10.98.0.1
  route pb add 10.98.0.0/24 via 10.99.0.1
  forwarding pa
  ip netns exec pa sysctl -qw net.ipv4.conf.all.rp_filter=0
  ip netns exec pa sysctl -qw net.ipv4.conf.e0.rp_filter=0
  ip netns exec pa sysctl -qw net.ipv4.conf.f0.rp_filter=0
  ip -n pa route add 10.98.0.0/24 dev f0 table 10
  ip -n pa rule add iif e0 lookup 10 priority 100
  if ip -n pa route show table main | grep 10.98.0.0 >/dev/null; then
    echo "10.98.0.0/24 unexpectedly present in main" >&2; return 1
  fi
  ip netns exec pb ping -c1 -W2 10.98.0.2 >/dev/null
}

c_geneve() {
  base
  ip -n pa link add gn0 type geneve id 7 remote 10.99.0.2
  ip -n pb link add gn0 type geneve id 7 remote 10.99.0.1
  addr pa gn0 172.17.0.1/24; addr pb gn0 172.17.0.2/24
  ip -n pa link set gn0 up; ip -n pb link set gn0 up
  ip netns exec pa ping -c1 -W2 172.17.0.2 >/dev/null
}

c_conntrack_knobs() {
  ns_add pa pb
  local ns
  # Make sure conntrack is active in both namespaces so the sysctls exist there.
  for ns in pa pb; do
    ip netns exec "$ns" nft add table ip ctprobe
    ip netns exec "$ns" nft add chain ip ctprobe c '{ type filter hook input priority 0; }'
    ip netns exec "$ns" nft add rule ip ctprobe c ct state established accept
  done
  ip netns exec pa sysctl -qw net.netfilter.nf_conntrack_tcp_loose=0
  ip netns exec pa sysctl -qw net.netfilter.nf_conntrack_tcp_timeout_established=20
  local loose est pbloose pbest
  loose=$(ip netns exec pa sysctl -n net.netfilter.nf_conntrack_tcp_loose)
  est=$(ip netns exec pa sysctl -n net.netfilter.nf_conntrack_tcp_timeout_established)
  pbloose=$(ip netns exec pb sysctl -n net.netfilter.nf_conntrack_tcp_loose)
  pbest=$(ip netns exec pb sysctl -n net.netfilter.nf_conntrack_tcp_timeout_established)
  [ "$loose" = 0 ] && [ "$est" = 20 ] || { echo "pa did not read back 0/20 (got $loose/$est)" >&2; return 1; }
  [ "$pbloose" = 1 ] && [ "$pbest" != 20 ] || { echo "pb did not keep defaults (got $pbloose/$pbest)" >&2; return 1; }
}

# ---- child mode: run one check with set -e live ----------------------------
if [ "${1:-}" = "--one" ]; then
  set -eEu
  trap 'echo "check failed: $BASH_COMMAND (line $LINENO)" >&2' ERR
  require_netlab
  topo_down
  "c_$2"
  exit 0
fi

# ---- parent: run every check in a fresh process ----------------------------
require_netlab
topo_down

FEATURES=(
  "netns_veth:netns + veth + ping"
  "bridge_vlan:bridge with vlan_filtering and a VLAN on a port"
  "vxlan:VXLAN pair with ping across the overlay"
  "nft_nat:nft ip nat table with masquerade"
  "conntrack:conntrack -L inside a namespace"
  "netem:tc netem delay 50ms (ping RTT >= 50 ms)"
  "frr_bgp:FRR per netns, eBGP Established"
  "unbound:unbound in a namespace answering dig from another"
  "xfrm:ip xfrm static ESP SA"
  "netns_resolv:/etc/netns/<ns>/resolv.conf bind"
  "vrf:policy-routing tables (VRF-lite), route only in table 10"
  "geneve:GENEVE pair with ping across"
  "conntrack_knobs:per-netns conntrack sysctls"
)

fails=0
for f in "${FEATURES[@]}"; do
  name=${f%%:*}; label=${f#*:}
  errf="$STATE_DIR/.probe-err"
  if timeout 90 bash "$0" --one "$name" >/dev/null 2>"$errf"; then
    echo "OK $label"
  else
    echo "MISSING $label: $(head -n1 "$errf" 2>/dev/null)"
    fails=$((fails + 1))
  fi
  topo_down
done

topo_down
if [ "$fails" -eq 0 ]; then echo "All 13 features OK."; exit 0; fi
echo "$fails of 13 features MISSING — see labs/netlab/README.md and PROBE.md." >&2
exit 1
