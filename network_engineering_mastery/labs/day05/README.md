# Day 5 lab — BGP between four routers, and a Transit Gateway in a box

## At a glance

- **Runs in:** `netlab` (see `labs/netlab/README.md`), from `/course`.
- **Commands:** `bash labs/day05/topo.sh up`, the Prove walkthrough below,
  `bash labs/day05/break.sh`, `bash labs/day05/verify.sh`, `bash labs/day05/topo.sh down`.
  Then the second lab: `bash labs/day05/vrf.sh up`, `vrf.sh leak`, `vrf.sh down`.
- **Time:** about 1 h 45 m (40 m guided proof, 25 m break and diagnose, 25 m TGW box with
  its AWS emulation, 15 m verify and journal; skip the hold-timer demo if short on time). `topo.sh up` waits up to 40 s for BGP, so allow a minute.
- **Success signal:** `show bgp ipv4 unicast 10.50.100.0/24` on r1 marks the r3 path
  as best, the failover test moves traffic to r2, and `verify.sh` prints
  `PASS: day 05 is healthy.` after you fix both faults. In the TGW box, `vrf.sh leak`
  prints a matrix where only prod-dev is `✗`.

## Topology

```
                 10.5.12.0/30                10.5.24.0/30
   r1 AS65001 eth0 ---------- eth0 r2 AS65002 eth1 ---------- eth0
   "on-prem"  .1               .2  "VPN path"  .1               .2   r4 AS64512
   lo1 10.50.1.1/24                                               "AWS"
              eth1 ---------- eth0 r3 AS65003 eth1 ---------- eth1  lo1 10.50.100.1/24
                  .1  10.5.13.0/30 .2 "DX path"  .1  10.5.34.0/30 .2
```

Each router is a namespace running its own `zebra` and `bgpd` (FRR). The configs are in
`labs/day05/frr/`. r1 applies `route-map FROM-R3` inbound from r3, which sets
`local-preference 200`. `no bgp ebgp-requires-policy` lets the other sessions exchange
routes without a policy. r1 advertises `10.50.1.0/24`, r4 advertises `10.50.100.0/24`.
r2 and r3 are transit routers that only pass routes along.

Talk to a router's FRR with `vty`, for example
`ip netns exec r1 vtysh -N r1 -c 'show bgp summary'`. Inside a sourced shell, the helper
`. labs/lib/common.sh; vty r1 'show bgp summary'` does the same.

## Prove it on the wire

```bash
bash labs/day05/topo.sh up
ip netns exec r1 vtysh -N r1 -c 'show bgp summary'
ip -n r1 route show 10.50.100.0/24
```

### 1. Session establishment

The sessions are already up, so reset one while you capture. Shell 1:

```bash
ip netns exec r1 tcpdump -ni eth1 -w /tmp/bgp.pcap tcp port 179
```

Shell 2:

```bash
ip netns exec r1 vtysh -N r1 -c 'clear bgp 10.5.13.2'
```

Wait 5 s, stop the capture, then read it: `tshark -r /tmp/bgp.pcap` (or tcpdump). Find, in
order: the TCP handshake, an OPEN from each side, a KEEPALIVE from each side (this is
the OPEN-confirm), then UPDATE messages. Now read the attributes:

```bash
tshark -r /tmp/bgp.pcap -V -Y bgp | /usr/bin/grep -E 'Type:|AS number|Hold|Identifier|AS_PATH|NEXT_HOP|NLRI|ORIGIN|MULTI|Prefix'
```

In the OPEN find `My AS`, `Hold Time` and `BGP Identifier`. In the UPDATE from r3, find
ORIGIN, AS_PATH (`65003 64512`), NEXT_HOP (`10.5.13.2`) and the NLRI `10.50.100.0/24`.
Note what is missing: LOCAL_PREF. It is not carried between ASes. r1 adds it on
receipt, from the route-map.

### 2. Both paths and the reason for "best"

```bash
ip netns exec r1 vtysh -N r1 -c 'show bgp ipv4 unicast 10.50.100.0/24'
```

You see two paths: `65003 64512` with `localpref 200`, ending in `best (Local Pref)`,
and `65002 64512` with `localpref 100`. The reason for the winner is the suffix on the
best path's attribute line. (The `bestpath` keyword only filters the output to the
best path; it does not explain it.) Confirm the kernel agrees:
`ip -n r1 route show 10.50.100.0/24` shows one route,
`via 10.5.13.2 proto bgp metric 20`.

### 3. Predict first, then run

For each change, write your prediction (best next hop, and the suffix you expect) in
`journal.md` before you run it. Define a helper once in your shell. It sends each
argument to the router's `vtysh` as one command:

```bash
V() { local n=$1 c a=(); shift; for c in "$@"; do a+=(-c "$c"); done; ip netns exec "$n" vtysh -N "$n" "${a[@]}"; }
show() { V r1 'show bgp ipv4 unicast 10.50.100.0/24' | /usr/bin/grep -E '^ +[0-9]|best|Origin'; }
```

Start every sub-step from a fresh `bash labs/day05/topo.sh up`.

**a. Remove the local-pref.**

```bash
V r1 'configure terminal' 'router bgp 65001' 'address-family ipv4 unicast' \
  'no neighbor 10.5.13.2 route-map FROM-R3 in'
V r1 'clear bgp * soft in'
show
```

Both paths now tie on weight, local-pref, AS-path length, origin and MED. FRR's default
for an eBGP tie is the oldest path, ahead of the router-id. Expected here: the path via
r3, suffix `best (Older Path)`, because the r3 path was received first (r3's session
came up before the r2 route was refreshed). The winner depends on timing, so it is not
a stable result. To make it deterministic, tell r1 to compare router-ids instead:

```bash
V r1 'configure terminal' 'router bgp 65001' 'bgp bestpath compare-routerid'
V r1 'clear bgp * soft in'
show
```

Expected: now the path via r2 (router-id 2.2.2.2 is lower than 3.3.3.3), suffix
`best (Router ID)`.

**b. Prepend on r4 toward r3.**

```bash
V r4 'configure terminal' 'route-map PREPEND permit 10' 'set as-path prepend 64512 64512' \
  'exit' 'router bgp 64512' 'address-family ipv4 unicast' \
  'neighbor 10.5.34.1 route-map PREPEND out'
V r4 'clear bgp * soft out'
sleep 2; show
```

Expected: the r3 path now shows `65003 64512 64512 64512`, and it is still the best, with
`best (Local Pref)`: local-pref (step 2) is compared before AS-path length (step 4).
Now take the local-pref away:

```bash
V r1 'configure terminal' 'router bgp 65001' 'address-family ipv4 unicast' \
  'no neighbor 10.5.13.2 route-map FROM-R3 in'
V r1 'clear bgp * soft in'
show
```

Expected: the path via r2, suffix `best (AS Path)`. That ordering is why you steer
outbound traffic with local-pref and inbound traffic with prepending.

**c. MED.** MED is not transitive: a MED that r4 sets is not passed on by r2 or r3 to
r1. The routers adjacent to r1 must set it. First recreate step a (no `FROM-R3`, with
`compare-routerid`), so the starting winner is r2:

```bash
V r1 'configure terminal' 'router bgp 65001' 'address-family ipv4 unicast' \
  'no neighbor 10.5.13.2 route-map FROM-R3 in'
V r1 'configure terminal' 'router bgp 65001' 'bgp bestpath compare-routerid'
V r1 'clear bgp * soft in'
show                                  # via r2, best (Router ID)
```

Make r3 the lower-MED path, so MED, if it counts, changes the answer:

```bash
V r2 'configure terminal' 'route-map MED-OUT permit 10' 'set metric 50' 'exit' \
  'router bgp 65002' 'address-family ipv4 unicast' 'neighbor 10.5.12.1 route-map MED-OUT out'
V r3 'configure terminal' 'route-map MED-OUT permit 10' 'set metric 10' 'exit' \
  'router bgp 65003' 'address-family ipv4 unicast' 'neighbor 10.5.13.1 route-map MED-OUT out'
V r2 'clear bgp * soft out'; V r3 'clear bgp * soft out'
sleep 2; show
```

Predict, then read: both paths now list a `metric` (50 and 10), yet the best is still
the path via r2, `best (Router ID)`. The neighbouring ASes differ (65002 and 65003), so
by default MED is not compared. Now tell r1 to compare it anyway:

```bash
V r1 'configure terminal' 'router bgp 65001' 'bgp always-compare-med'
V r1 'clear bgp * soft in'
show
```

Expected: the path via r3, suffix `best (MED)`.

### 4. A more-specific route wins whatever the attributes

```bash
bash labs/day05/topo.sh up
ip -n r2 link add lo2 type dummy
ip -n r2 addr add 10.50.100.128/25 dev lo2
ip -n r2 link set lo2 up
V r2 'configure terminal' 'ip prefix-list P25 seq 5 permit 10.50.100.128/25' \
  'route-map TO-R4 deny 10' 'match ip address prefix-list P25' 'exit' \
  'route-map TO-R4 permit 20' 'exit' \
  'router bgp 65002' 'network 10.50.100.128/25' \
  'address-family ipv4 unicast' 'neighbor 10.5.24.2 route-map TO-R4 out'
V r2 'clear bgp * soft out'
sleep 3
V r1 'show bgp ipv4 unicast 10.50.100.0/24 longer-prefixes' | /usr/bin/grep -E '^ *\*|Network'
ip -n r1 route get 10.50.100.200
ip -n r1 route get 10.50.100.1
```

The route-map keeps the `/25` away from r4, so the only path to it is from r2
(local-pref 100). Otherwise r4 would pass it to r3 and r1 would learn it with
local-pref 200 as well. Expected: the `/25` line reads `*> 10.50.100.128/25  10.5.12.2 ... 65002 i`. `route get 10.50.100.200` says `via 10.5.12.2` even
though r3 has local-pref 200 for the `/24`, and `10.50.100.1` says `via 10.5.13.2`.
Prefix length is decided in the forwarding table, before any BGP attribute. A ping to
`.200` gets no reply (r2 has the `/25` only on a dummy interface). That is the point:
you hijacked it.

### 5. Fail the DX link and time the failover

```bash
bash labs/day05/topo.sh up
ip netns exec r1 ping -I 10.50.1.1 10.50.100.1 > /dev/null &
date +%T; ip -n r3 link set eth0 down
for i in $(seq 1 20); do ip -n r1 route get 10.50.100.1 | /usr/bin/grep -q 'via 10.5.12.2' && { date +%T; break; }; sleep 0.5; done
kill %1
```

The route flips within about a second. The veth reports carrier loss, and FRR's
`fast-external-failover` tears down a directly connected eBGP session at once. A real
fibre cut behind a provider switch gives no carrier event, so the hold timer decides.
Reproduce that. r1 proposes hold time 9, and the lower value in the OPEN exchange
wins, so only r1 needs the change:

```bash
bash labs/day05/topo.sh up
V r1 'configure terminal' 'router bgp 65001' 'no bgp fast-external-failover' \
  'neighbor 10.5.13.2 timers 3 9'
V r1 'clear bgp 10.5.13.2'
for i in $(seq 1 40); do ip -n r1 route get 10.50.100.1 | /usr/bin/grep -q 'via 10.5.13.2' && break; sleep 1; done
ip netns exec r1 nft add table inet f
ip netns exec r1 nft add chain inet f i '{ type filter hook input priority 0; }'
ip netns exec r1 nft add rule inet f i ip saddr 10.5.13.2 drop
date +%T
for i in $(seq 1 60); do ip -n r1 route get 10.50.100.1 | /usr/bin/grep -q 'via 10.5.12.2' && { date +%T; break; }; sleep 1; done
```

The loop waits for the session to come back with the route via r3, then drops
everything r3 sends to r1. Expected: the two timestamps are about 9 s apart, the hold
time. With the defaults (keepalive 60, hold 180) it would be up to 3 minutes.
Production designs add BFD, which detects loss in well under a second: FRR runs it as a
separate daemon (`bfdd`), which this lab does not start.

## Break it and diagnose

```bash
bash labs/day05/topo.sh up
bash labs/day05/break.sh
```

Read the symptom. Write the evidence chain in `journal.md` (one sentence per
command you ran and what it showed), then fix, then run:

```bash
bash labs/day05/verify.sh
```

`verify.sh` prints one line per check. It waits up to 40 s for a session to come up, so
a failing BGP check takes a while. `SOLUTION.md` has the evidence chain. Read it after
you have written your own.

## Second lab: the TGW in a box (`vrf.sh`)

This lab is independent of the BGP topology. `vrf.sh up` removes any other lab first.

```bash
bash labs/day05/vrf.sh up        # isolated: every off-diagonal cell is ✗
ip -n tgw route show table 10    # rt-prod: only 10.51.0.0/24
ip -n tgw rule show              # the association rules
bash labs/day05/vrf.sh leak      # shared propagated into prod and dev, and back
bash labs/day05/vrf.sh down
```

The kernel here has no VRF devices, so a route table is a plain Linux routing table.
`ip rule add iif att-prod lookup 10` makes table 10 the table for packets that arrive on
the `prod` attachment. A final rule at preference 32000 per attachment returns
"unreachable" if the table had no match, so a packet never falls through to the main
table (which knows all three connected networks and would defeat the isolation).

| Linux (this lab) | Transit Gateway |
|---|---|
| a routing table (10, 20, 30) | a TGW route table (`rt-prod`, `rt-dev`, `rt-shared`) |
| `ip rule iif att-X lookup N` | **association**: the table an attachment uses for lookups |
| `ip route add ... dev att-shared table 10` | **propagation**: the table learns the attachment's routes |
| a static route in a table | a TGW static route |
| `ip route add blackhole ... table N` | a TGW blackhole route |

Try: add `ip -n tgw route replace blackhole 10.52.0.0/24 table 30` and note the effect on
`shared`'s reach to `dev`. Then try the same with a more-specific blackhole `/25` in
`rt-prod` for a host that `leak` made reachable. The longest prefix wins, as on a TGW.

Expected `leak` matrix: prod-shared, shared-prod, dev-shared and shared-dev are `✓`;
prod-dev and dev-prod stay `✗`.
