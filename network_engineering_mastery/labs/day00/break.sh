#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 00

# Fault A
for p in $(ip netns pids hr); do kill -9 "$p" 2>/dev/null || true; done
ip -n lap addr flush dev eth0
rm -f /var/lib/dhcpcd/* /var/db/dhcpcd/* 2>/dev/null || true
ip netns exec lap timeout 25 dhcpcd -4 -1 -B --nobackground -f /dev/null -o domain_name_servers -t 10 eth0 >/dev/null 2>&1 || true

# Fault B
ip netns exec isp nft flush chain ip nat postrouting
ip netns exec isp conntrack -F >/dev/null 2>&1 || true

fault_set 00 1
symptom "The laptop says connected, but nothing loads. Its IP address looks strange. And a request made from the home router itself towards the web server (203.0.113.10:8080) hangs too."
