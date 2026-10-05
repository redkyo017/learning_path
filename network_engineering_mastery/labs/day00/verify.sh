#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 00

lap_has_lease()  { ip -n lap -4 -o addr show dev eth0 | /usr/bin/grep -q 'inet 192\.168\.1\.'; }
lap_default()    { ip -n lap -4 route show default | /usr/bin/grep -q 'via 192\.168\.1\.1 '; }
lap_resolves()   { [ "$(ip netns exec lap dig +short +time=2 +tries=1 www.example.test)" = "203.0.113.10" ]; }
lap_gets_200()   { [ "$(ip netns exec lap curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://www.example.test:8080/)" = "200" ]; }
srv_sees_cgnat() {
  local v="$RANDOM$RANDOM"
  ip netns exec lap curl -s -o /dev/null --max-time 3 "http://www.example.test:8080/?v=$v" || return 1
  sleep 0.3
  /usr/bin/grep "v=$v" "$STATE_DIR/web.log" | /usr/bin/grep -q '^198\.51\.100\.1 '
}

echo "Day 0 checks:"
check "lap has a DHCP lease from 192.168.1.0/24 (not 169.254)" lap_has_lease
check "lap default route is via 192.168.1.1" lap_default
check "lap resolves www.example.test to 203.0.113.10" lap_resolves
check "lap fetches http://www.example.test:8080/ with 200 within 3 s" lap_gets_200
check "srv sees a fresh request from 198.51.100.1 (home NAT, then CGNAT)" srv_sees_cgnat
verify_finish 00
