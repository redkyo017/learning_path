#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

DAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# bgp_est PEER -> success when tgw reports PEER as Established.
bgp_est() {
  vty tgw 'show bgp summary json' 2>/dev/null | python3 -c '
import json, sys
peer = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for afi in d.values():
    if isinstance(afi, dict) and afi.get("peers", {}).get(peer, {}).get("state") == "Established":
        sys.exit(0)
sys.exit(1)' "$1"
}

tgw_has_onprem() { local o; o=$(ip -n tgw route show 192.168.0.0/16 2>/dev/null || true); [[ "$o" == *gre1* ]]; }
onp_has_vpc()    { local o; o=$(ip -n onp route show 10.70.0.0/16 2>/dev/null || true); [[ "$o" == *gre1* ]]; }
dns_ok()         { local a; a=$(ip netns exec task dig +short +time=1 +tries=1 api.onprem.corp 2>/dev/null || true); [ "$a" = "192.168.10.10" ]; }
http_code()      { ip netns exec task curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://api.onprem.corp:8080/ 2>/dev/null || true; }

build() {
  ns_add task vpcr tgw onp api odns

  veth task eth0 vpcr eth0     # 10.70.1.0/24   the VPC subnet
  veth vpcr eth1 tgw eth0      # 10.70.255.0/30 the TGW attachment
  veth tgw wan onp wan         # 100.64.0.0/30  the "internet" under the tunnel
  veth onp lan api eth0        # 192.168.10.0/24
  veth onp dns odns eth0       # 192.168.20.0/24

  addr task eth0 10.70.1.10/24
  addr vpcr eth0 10.70.1.1/24
  addr vpcr eth0 10.70.1.2/24  # the resolver address (a second address on the same subnet)
  addr vpcr eth1 10.70.255.1/30
  addr tgw  eth0 10.70.255.2/30
  addr tgw  wan  100.64.0.1/30
  addr onp  wan  100.64.0.2/30
  addr onp  lan  192.168.10.1/24
  addr api  eth0 192.168.10.10/24
  addr onp  dns  192.168.20.1/24
  addr odns eth0 192.168.20.53/24

  # GRE "VPN": 1500 - 20 (outer IP) - 4 (GRE) = 1476. No "dev" binding on the tunnel.
  ip -n tgw link add gre1 type gre local 100.64.0.1 remote 100.64.0.2 ttl 64
  ip -n onp link add gre1 type gre local 100.64.0.2 remote 100.64.0.1 ttl 64
  ip -n tgw link set gre1 mtu 1476 up
  ip -n onp link set gre1 mtu 1476 up
  addr tgw gre1 169.254.10.1/30
  addr onp gre1 169.254.10.2/30

  local ns
  for ns in vpcr tgw onp; do
    forwarding "$ns"
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.all.rp_filter=0
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.default.rp_filter=0
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.all.send_redirects=0
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.default.send_redirects=0
  done
  ip netns exec tgw sysctl -qw net.ipv4.conf.eth0.send_redirects=0
  ip netns exec vpcr sysctl -qw net.ipv4.conf.eth1.send_redirects=0

  # Static routes: the VPC side. tgw learns the on-prem summary from BGP.
  route task add default via 10.70.1.1
  route vpcr add 192.168.0.0/16 via 10.70.255.2
  route tgw  add 10.70.1.0/24 via 10.70.255.1
  route tgw  add blackhole 10.70.0.0/16
  route api  add default via 192.168.10.1
  route odns add default via 192.168.20.1

  ip netns exec tgw nft -f "$DAY_DIR/clamp.nft"
  ip netns exec onp nft -f "$DAY_DIR/fw.nft"

  frr_up tgw "$DAY_DIR/frr/tgw.conf"
  frr_up onp "$DAY_DIR/frr/onp.conf"

  # Web root for the app: a small page and a 300000-byte file.
  mkdir -p "$STATE_DIR/www"
  echo ok > "$STATE_DIR/www/index.html"
  head -c 300000 /dev/zero > "$STATE_DIR/www/big.bin"
  bg api web python3 -m http.server 8080 --directory "$STATE_DIR/www"

  # The resolver runs from a copy so a runtime change never edits the tracked file.
  cp "$DAY_DIR/dns/vpcr.conf" "$STATE_DIR/vpcr-dns.conf"
  bg vpcr vpcr-dns unbound -d -c "$STATE_DIR/vpcr-dns.conf"
  bg odns odns unbound -d -c "$DAY_DIR/dns/odns.conf"

  # topo_down wiped /etc/netns, so write the task's resolver config now.
  mkdir -p /etc/netns/task
  printf 'nameserver 10.70.1.2\n' > /etc/netns/task/resolv.conf
}

# poll DESC FUNC -> run FUNC once a second for up to 40 s.
poll() {
  local desc="$1" fn="$2" i
  for i in $(seq 1 40); do "$fn" && return 0; sleep 1; done
  echo "not ready within 40 s: $desc (see /run/netlab/*.log)" >&2
  return 1
}
bgp_up() { bgp_est 169.254.10.2; }
web_ok() { [ "$(http_code)" = 200 ]; }

wait_ready() {
  poll "BGP Established between tgw and onp" bgp_up
  poll "tgw learned 192.168.0.0/16" tgw_has_onprem
  poll "onp learned 10.70.0.0/16" onp_has_vpc
  poll "api.onprem.corp resolves from task" dns_ok
  poll "healthy curl returns 200" web_ok
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    wait_ready
    topo_mark 07
    echo "Day 7 topology is up: task - vpcr - tgw ==GRE== onp - api, odns"
    ;;
  down)
    require_netlab
    topo_down
    echo "Day 7 topology is down."
    ;;
  *)
    echo "usage: bash labs/day07/topo.sh up|down" >&2
    exit 2
    ;;
esac
