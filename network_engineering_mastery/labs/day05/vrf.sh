#!/usr/bin/env bash
# "TGW in a box": three spokes and a tgw namespace with three route tables.
# This kernel has no VRF devices, so a route table is a Linux routing table and an
# attachment is tied to it with `ip rule iif <attachment> lookup <table>`.
#   rt-prod = table 10, rt-dev = table 20, rt-shared = table 30
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

SPOKES="prod dev shared"
ip_of()    { case "$1" in prod) echo 10.51.0.10;; dev) echo 10.52.0.10;; shared) echo 10.53.0.10;; esac; }
net_of()   { case "$1" in prod) echo 10.51.0.0/24;; dev) echo 10.52.0.0/24;; shared) echo 10.53.0.0/24;; esac; }
gw_of()    { case "$1" in prod) echo 10.51.0.1;; dev) echo 10.52.0.1;; shared) echo 10.53.0.1;; esac; }
table_of() { case "$1" in prod) echo 10;; dev) echo 20;; shared) echo 30;; esac; }
att_of()   { echo "att-$1"; }

build() {
  ns_add prod dev shared tgw
  forwarding tgw
  ip netns exec tgw sysctl -qw net.ipv4.conf.all.rp_filter=0
  ip netns exec tgw sysctl -qw net.ipv4.conf.default.rp_filter=0
  local s
  for s in $SPOKES; do
    ip link add eth0 netns "$s" type veth peer name "$(att_of "$s")" netns tgw
    ip -n "$s" link set eth0 up
    ip -n tgw link set "$(att_of "$s")" up
    ip netns exec tgw sysctl -qw "net.ipv4.conf.$(att_of "$s").rp_filter=0"
    addr "$s" eth0 "$(ip_of "$s")/24"
    route "$s" add default via "$(gw_of "$s")"
    addr tgw "$(att_of "$s")" "$(gw_of "$s")/24"
    # Association: lookups for packets arriving on this attachment use this table.
    ip -n tgw rule add pref 100 iif "$(att_of "$s")" lookup "$(table_of "$s")"
    # Isolation: if the table has no match, do not fall through to the main table.
    ip -n tgw rule add pref 32000 iif "$(att_of "$s")" unreachable
    # The table starts with only its own attachment's connected route.
    ip -n tgw route add "$(net_of "$s")" dev "$(att_of "$s")" table "$(table_of "$s")"
  done
}

# propagate FROM TO -> table TO learns the route of attachment FROM.
propagate() { ip -n tgw route replace "$(net_of "$1")" dev "$(att_of "$1")" table "$(table_of "$2")"; }

show_tables() {
  local s
  echo "--- ip rule (association) ---"
  ip -n tgw rule show | /usr/bin/grep -v -E 'from all lookup (local|main|default)$' || true
  for s in $SPOKES; do
    echo "--- rt-$s (table $(table_of "$s")) ---"
    ip -n tgw route show table "$(table_of "$s")"
  done
}

matrix() {
  local a b mark
  echo
  echo "Reachability (row = source, column = destination)"
  printf '%-8s' ""; for b in $SPOKES; do printf '%-8s' "$b"; done; echo
  for a in $SPOKES; do
    printf '%-8s' "$a"
    for b in $SPOKES; do
      if [ "$a" = "$b" ]; then mark="-"
      elif ip netns exec "$a" ping -c1 -W1 "$(ip_of "$b")" >/dev/null 2>&1; then mark="✓"
      else mark="✗"; fi
      printf '%s       ' "$mark"
    done
    echo
  done
  echo
}

need_up() {
  ip netns list | awk '{print $1}' | /usr/bin/grep -qx tgw || {
    echo "The TGW box is not up. Run: bash labs/day05/vrf.sh up" >&2; exit 2; }
}

case "${1:-}" in
  up)
    require_netlab
    topo_down
    build
    echo "Isolated: every table holds only its own attachment's route."
    show_tables
    matrix
    ;;
  leak)
    require_netlab
    need_up
    # Shared services: prod and dev learn shared, shared learns prod and dev.
    propagate shared prod; propagate shared dev
    propagate prod shared; propagate dev shared
    echo "Propagated: shared into rt-prod and rt-dev; prod and dev into rt-shared."
    show_tables
    matrix
    ;;
  down)
    require_netlab
    topo_down
    echo "TGW box is down."
    ;;
  *)
    echo "usage: bash labs/day05/vrf.sh up|leak|down" >&2
    exit 2
    ;;
esac
