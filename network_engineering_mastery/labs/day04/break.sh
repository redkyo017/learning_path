#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_topo 04

# h2's route back to the inside LAN.
ip -n h2 route add 10.4.1.0/24 via 10.4.2.2

# fw's outbound translation.
ip netns exec fw nft flush chain ip nat postrouting

# Flush fw's flow table so old, healthy entries cannot mask the change.
ip netns exec fw conntrack -F >/dev/null 2>&1 || true

fault_set 04 1
symptom "h1 can ping h2 but HTTP to h2 hangs after the SYN. h1 cannot reach the outside at all."
