#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

require_topo 01

# Inject the day's faults.
ip -n h3 link set eth0 address 02:00:00:00:01:02
ip -n h1 neigh replace 10.1.0.3 lladdr 02:00:00:00:01:99 dev eth0 nud permanent
# h3 sends a little background traffic (inside h3, so topo.sh down removes it).
bg h3 chatter ping -i 1 10.1.0.1

fault_set 01 1
symptom "h1 can reach h2 only sometimes, and never h3. Nobody changed an IP address."
