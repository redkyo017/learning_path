#!/usr/bin/env bash
# Shared helpers for labs/dayNN/{topo,break,verify}.sh and labs/day07/gauntlet.sh.
# Sourced, never executed. Runs INSIDE the netlab container, from /course.
#
#   . "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
set -euo pipefail

STATE_DIR=/run/netlab
_CHECK_FAILS=0

require_netlab() {
  if [ ! -f /.netlab ]; then
    echo "This script runs inside the netlab container, not on your Mac." >&2
    echo "  cd network_engineering_mastery/labs/netlab && docker compose -p netlab up -d --build" >&2
    echo "  docker compose -p netlab exec netlab bash     # then re-run from /course" >&2
    exit 2
  fi
  mkdir -p "$STATE_DIR"
}

# require_topo 03  -> exit 2 unless labs/day03/topo.sh up has run.
require_topo() {
  require_netlab
  if [ ! -f "$STATE_DIR/day$1.up" ]; then
    echo "Topology for day $1 is not up — run: bash labs/day$1/topo.sh up" >&2
    exit 2
  fi
}

ns_add() { local ns; for ns in "$@"; do ip netns add "$ns"; ip -n "$ns" link set lo up; done; }

# veth h1 eth0 r1 eth1  -> a veth pair with one end in each namespace, both up.
veth() {
  ip link add "$2" netns "$1" type veth peer name "$4" netns "$3"
  ip -n "$1" link set "$2" up
  ip -n "$3" link set "$4" up
}

addr()  { ip -n "$1" addr add "$3" dev "$2"; }
route() { local ns="$1"; shift; ip -n "$ns" route "$@"; }

forwarding() {
  ip netns exec "$1" sysctl -qw net.ipv4.ip_forward=1
  ip netns exec "$1" sysctl -qw net.ipv6.conf.all.forwarding=1
}

# bridge_ns sw br0 p1 p2 p3  -> bridge br0 inside namespace sw, ports enslaved, all up.
bridge_ns() {
  local ns="$1" br="$2"; shift 2
  ip -n "$ns" link add "$br" type bridge
  ip -n "$ns" link set "$br" up
  local p; for p in "$@"; do ip -n "$ns" link set "$p" master "$br"; ip -n "$ns" link set "$p" up; done
}

# bg h2 web python3 -m http.server 8080  -> daemon inside h2, log in /run/netlab/web.log
bg() {
  local ns="$1" name="$2"; shift 2
  ip netns exec "$ns" setsid "$@" >"$STATE_DIR/$name.log" 2>&1 < /dev/null &
  echo $! > "$STATE_DIR/$name.pid"
}

topo_mark() { touch "$STATE_DIR/day$1.up"; }

# frr_up r1 labs/day05/frr/r1.conf  -> zebra + bgpd for namespace r1 (FRR pathspace = ns name).
frr_up() {
  local ns="$1" conf="$2" d
  mkdir -p "$STATE_DIR/frr-$ns" "/var/run/frr/$ns"
  chown frr:frr "$STATE_DIR/frr-$ns" "/var/run/frr/$ns"
  # vtysh -N NS reads /etc/frr/NS/vtysh.conf; an empty file silences its warning.
  mkdir -p "/etc/frr/$ns" && touch "/etc/frr/$ns/vtysh.conf"
  chown -R frr:frr "/etc/frr/$ns" && chmod 644 "/etc/frr/$ns/vtysh.conf"
  for d in zebra bgpd; do
    ip netns exec "$ns" /usr/lib/frr/$d -d -N "$ns" -A 127.0.0.1 -f "$conf" \
      -i "$STATE_DIR/frr-$ns/$d.pid"
  done
}

# vty r1 'configure terminal' 'router bgp 65001' 'neighbor 10.5.13.2 remote-as 65003'
# -> every argument after the namespace becomes one vtysh -c.
vty() {
  local ns="$1"; shift
  local args=() c; for c in "$@"; do args+=(-c "$c"); done
  ip netns exec "$ns" vtysh -N "$ns" "${args[@]}"
}

# Remove every lab namespace and every process inside one. Idempotent.
topo_down() {
  mkdir -p "$STATE_DIR"
  local ns pid
  for ns in $(ip netns list 2>/dev/null | awk '{print $1}'); do
    for pid in $(ip netns pids "$ns" 2>/dev/null); do kill -9 "$pid" 2>/dev/null || true; done
    # Per-namespace FRR dirs, only for names of lab namespaces (never /etc/frr itself).
    if [ -n "$ns" ]; then rm -rf "/etc/frr/$ns" "/var/run/frr/$ns" 2>/dev/null || true; fi
  done
  ip -all netns delete 2>/dev/null || true
  rm -rf /etc/netns/* "$STATE_DIR"/* 2>/dev/null || true
}

symptom() { printf '\nSYMPTOM: %s\n\nNothing else will be explained.\n' "$1"; }

fault_set() { echo "$2" > "$STATE_DIR/day$1.fault"; }
fault_get() { cat "$STATE_DIR/day$1.fault" 2>/dev/null || echo none; }

# check "h1 reaches h2" ip netns exec h1 ping -c1 -W1 10.1.0.2
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '  ok    %s\n' "$desc"
  else printf '  FAIL  %s\n' "$desc"; _CHECK_FAILS=$((_CHECK_FAILS + 1)); fi
}

verify_finish() {
  if [ "$_CHECK_FAILS" -eq 0 ]; then echo "PASS: day $1 is healthy."; exit 0; fi
  echo "FAIL: day $1 — $_CHECK_FAILS check(s) failed. Write the evidence chain in journal.md before fixing." >&2
  exit 1
}
