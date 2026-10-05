#!/usr/bin/env bash
# Two-AZ centralized inspection, imitated with policy routing.
#   bash labs/day04/inspection.sh up | asym | appliance | down
# Self-contained: it builds its own topology and removes the Day 4 main lab.
# Redo the main lab afterwards with: bash labs/day04/topo.sh up
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# The stateful forward policy both inspection firewalls run.
fw_policy() {
  cat <<'NFT'
flush ruleset
table inet filter {
  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    ct state invalid counter drop
    ip saddr 10.0.0.0/8 ct state new accept
  }
}
NFT
}

build() {
  ns_add spa spb tgw fwa fwb

  veth spa eth0 tgw eth0          # spoke A  (AZ-a side)
  veth spb eth0 tgw eth1          # spoke B
  veth tgw eth2 fwa eth0          # transit link to the AZ-a firewall
  veth tgw eth3 fwb eth0          # transit link to the AZ-b firewall

  addr spa eth0 10.41.0.10/24
  route spa add default via 10.41.0.1
  addr spb eth0 10.42.0.10/24
  route spb add default via 10.42.0.1

  addr tgw eth0 10.41.0.1/24
  addr tgw eth1 10.42.0.1/24
  addr tgw eth2 10.40.1.1/30
  addr tgw eth3 10.40.2.1/30
  forwarding tgw

  addr fwa eth0 10.40.1.2/30
  route fwa add default via 10.40.1.1
  addr fwb eth0 10.40.2.2/30
  route fwb add default via 10.40.2.1
  forwarding fwa
  forwarding fwb

  # A packet leaves the same interface it came in on: no ICMP redirects.
  local ns
  for ns in tgw fwa fwb; do
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.all.send_redirects=0
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.default.send_redirects=0
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.all.rp_filter=0
    ip netns exec "$ns" sysctl -qw net.ipv4.conf.default.rp_filter=0
  done
  ip netns exec tgw sysctl -qw net.ipv4.conf.eth2.rp_filter=0
  ip netns exec tgw sysctl -qw net.ipv4.conf.eth3.rp_filter=0

  # Tables 100 and 200 are the two steering choices.
  route tgw add default via 10.40.1.2 table 100
  route tgw add default via 10.40.2.2 table 200
  # Post-inspection traffic coming back from a firewall goes straight to the spoke.
  ip -n tgw rule add iif eth2 lookup main pref 50
  ip -n tgw rule add iif eth3 lookup main pref 51

  reset_fw
  echo "spb says hello" > "$STATE_DIR/index.html"
  bg spb web python3 -m http.server 8080 --directory "$STATE_DIR"
  local i
  for i in $(seq 1 20); do
    ip netns exec spb ss -ltn 2>/dev/null | /usr/bin/grep -q ':8080 ' && break
    sleep 0.25
  done
}

# Reload the policy on both firewalls: zero counters, empty flow tables.
reset_fw() {
  local ns
  for ns in fwa fwb; do
    fw_policy | ip netns exec "$ns" nft -f -
    ip netns exec "$ns" conntrack -F >/dev/null 2>&1 || true
  done
}

need_up() {
  if ! ip netns list 2>/dev/null | /usr/bin/grep -q '^tgw\b'; then
    echo "The inspection topology is not up — run: bash labs/day04/inspection.sh up" >&2
    exit 2
  fi
}

# steer 100 200 -> spoke A traffic uses table 100, spoke B traffic uses table 200.
# Replaces the two spoke rules every time, so the mode can change repeatedly.
steer() {
  local a="$1" b="$2"
  while ip -n tgw rule del pref 100 2>/dev/null; do :; done
  while ip -n tgw rule del pref 101 2>/dev/null; do :; done
  ip -n tgw rule add iif eth0 lookup "$a" pref 100
  ip -n tgw rule add iif eth1 lookup "$b" pref 101
  sleep 3       # let retransmissions of the previous mode drain before counting
  reset_fw
}

invalid_count() {
  ip netns exec "$1" nft list chain inet filter forward \
    | awk '/ct state invalid/ { for (i = 1; i <= NF; i++) if ($i == "packets") print $(i + 1) }'
}

report() {
  local code
  code=$(ip netns exec spa curl -s -o /dev/null --max-time 4 -w '%{http_code}' \
    http://10.42.0.10:8080/ 2>/dev/null) || true
  [ "${code:-000}" = "200" ] && echo "curl spa -> spb:8080 : OK (HTTP 200)" \
    || echo "curl spa -> spb:8080 : FAILED (no answer within 4 s)"
  sleep 1
  echo "fwa invalid-drop packets: $(invalid_count fwa)"
  echo "fwb invalid-drop packets: $(invalid_count fwb)"
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    echo "Inspection topology is up: spa, spb, tgw, fwa (AZ-a), fwb (AZ-b)."
    echo "Next: bash labs/day04/inspection.sh asym   (then: appliance)"
    ;;
  asym)
    require_netlab
    need_up
    steer 100 200
    echo "Mode asym: spa traffic -> fwa, spb traffic -> fwb (each AZ inspects its own spoke)."
    report
    ;;
  appliance)
    require_netlab
    need_up
    steer 100 100
    echo "Mode appliance: both directions -> fwa (the flow is pinned to one AZ)."
    report
    ;;
  down)
    require_netlab
    topo_down
    echo "Inspection topology is down. Redo the main lab with: bash labs/day04/topo.sh up"
    ;;
  *)
    echo "usage: bash labs/day04/inspection.sh up|asym|appliance|down" >&2
    exit 2
    ;;
esac
