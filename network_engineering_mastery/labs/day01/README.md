# Day 1 lab — a switch and three hosts

## At a glance

- **Runs inside:** the `netlab` container, from `/course`. Enter it with
  `cd network_engineering_mastery/labs/netlab && docker compose -p netlab exec netlab bash`.
- **Commands:** `bash labs/day01/topo.sh up`, then the "Prove" steps below, then
  `bash labs/day01/break.sh`, `bash labs/day01/verify.sh`, `bash labs/day01/topo.sh down`.
- **Time:** about 60 minutes (30 for Prove, 30 for the break).
- **Success signal:** you can annotate every field of an ARP request from a capture, and
  `verify.sh` prints `PASS: day 01 is healthy.` after you repair the break from evidence.

## The topology

```
 h1 eth0 (02:00:00:00:01:01, 10.1.0.1/24) --- p1 \
 h2 eth0 (02:00:00:00:01:02, 10.1.0.2/24) --- p2  >-- br0   (all inside namespace "sw")
 h3 eth0 (02:00:00:00:01:03, 10.1.0.3/24) --- p3 /
```

`sw` is the switch: a Linux bridge with three ports. Each `hN` is a bare namespace with
one interface. Open two shells in the container. Shell A runs captures, shell B
generates traffic.

```bash
bash labs/day01/topo.sh up
```

## Prove it

### Step 1 — an ARP request and reply

Shell A:

```bash
ip -n h1 neigh flush dev eth0
ip netns exec h1 tcpdump -eni eth0 -c 4 arp
```

Shell B:

```bash
ip netns exec h1 ping -c 8 10.1.0.2
```

Expected, timestamps removed:

```
02:00:00:00:01:01 > ff:ff:ff:ff:ff:ff, ethertype ARP (0x0806), length 42: Request who-has 10.1.0.2 tell 10.1.0.1, length 28
02:00:00:00:01:02 > 02:00:00:00:01:01, ethertype ARP (0x0806), length 42: Reply 10.1.0.2 is-at 02:00:00:00:01:02, length 28
02:00:00:00:01:02 > 02:00:00:00:01:01, ethertype ARP (0x0806), length 42: Request who-has 10.1.0.1 tell 10.1.0.2, length 28
02:00:00:00:01:01 > 02:00:00:00:01:02, ethertype ARP (0x0806), length 42: Reply 10.1.0.1 is-at 02:00:00:00:01:01, length 28
```

Lines 1 and 2 appear at once. Lines 3 and 4 arrive about 5 s later, and line 3 is
a **unicast** request from h2 to h1. h2 learned h1 from the first request, but h2 only
replies, so nothing ever confirmed its entry for h1. The entry went STALE, then DELAY,
and after about 5 s h2 probed h1 to revalidate it. h1 never needed that step for h2,
because its own pings confirmed the entry (see Step 2).

Annotate line 1 against the frame diagram you drew:

| Output text | Field | Bytes |
|---|---|---|
| `02:00:00:00:01:01 >` | Source MAC | 6 |
| `ff:ff:ff:ff:ff:ff` | Destination MAC (broadcast: I/G bit set) | 6 |
| `ethertype ARP (0x0806)` | EtherType | 2 |
| `length 42` | 14-byte Ethernet header + 28-byte ARP packet. No FCS, no padding: the NIC adds them | |
| `Request` | ARP opcode 1 (a reply is 2) | 2 |
| `who-has 10.1.0.2` | Target protocol address. The target MAC is all zeros and tcpdump hides it | 4 |
| `tell 10.1.0.1` | Sender protocol address. The sender MAC is the frame source MAC | 4 |

Add `-xx` to a capture to see the same frame as hex and check each row of the table.

### Step 2 — the neighbour table moves through states

```bash
ip -n h1 neigh show dev eth0
```

Right after the ping you expect `10.1.0.2 lladdr 02:00:00:00:01:02 REACHABLE`. Wait 30 to
60 seconds without sending traffic and repeat: the entry becomes `STALE`. REACHABLE lasts
a randomised time centred on 30 s (`base_reachable_time_ms`). Now ping again and
watch it go STALE, then REACHABLE (a quick `DELAY` is possible in between). Do not skip
this one: Step 2 is the state machine you will meet again in the break.

Why does a single ping take STALE straight to REACHABLE? iputils `ping` sends with
`MSG_CONFIRM`, which tells the kernel "the other side is answering", so the entry is
confirmed within a second. Traffic that gives no such upper-layer confirmation (h2
above, which only replies) goes STALE, then DELAY (about 5 s), then PROBE, then
REACHABLE when the probe is answered.

### Step 3 — the bridge learns MACs

```bash
bash labs/day01/topo.sh up        # fresh topology, empty table
bridge -n sw fdb show br br0 | grep 02:00:00:00:01
ip netns exec h1 ping -c1 10.1.0.2
bridge -n sw fdb show br br0 | grep 02:00:00:00:01
```

Before the ping, no `02:00:00:00:01:xx` entries (there can be none at all). After it you
expect `02:00:00:00:01:01 dev p1 master br0` and `02:00:00:00:01:02 dev p2 master br0`.
h3 has not sent a frame, so the bridge has not learned it. Now run
`ip netns exec h3 ping -c1 10.1.0.1` and see `…:03 dev p3` appear.

While you are here, run `ip netns exec h3 tcpdump -eni eth0 -c 2 arp` and then ping h2
from h1. h3 sees the ARP request (broadcast: flooded to every port) and never sees the
ICMP echo (known unicast: forwarded to one port).

### Step 4 — a VLAN splits the broadcast domain

```bash
ip -n sw link set br0 type bridge vlan_filtering 1
bridge -n sw vlan add dev p3 vid 20 pvid untagged
bridge -n sw vlan del dev p3 vid 1
bridge -n sw vlan show
ip netns exec h1 ping -c2 -W1 10.1.0.3      # fails: h3 is now in VLAN 20
ip netns exec h1 ping -c2 -W1 10.1.0.2      # still works: p1 and p2 stay in VLAN 1
```

With `vlan_filtering` on, every port starts as an access port in VLAN 1. The `vlan add`
line makes p3 an access port for VLAN 20 (`pvid` tags untagged ingress frames as 20,
`untagged` strips the tag on egress). The `vlan del` removes its VLAN 1 membership.

Now put a tag on the wire. Make p2 a trunk member of VLAN 20, and give h2 a tagged
interface:

```bash
bridge -n sw vlan add dev p2 vid 20
ip -n h2 link add link eth0 name eth0.20 type vlan id 20
ip -n h2 addr add 10.20.0.2/24 dev eth0.20
ip -n h2 link set eth0.20 up
ip -n h3 addr add 10.20.0.3/24 dev eth0
```

Shell A: `ip netns exec sw tcpdump -eni br0 -c 4` (the bridge device itself). Shell B: `ip netns exec h3 ping -c2 10.20.0.2`. Expect lines
like (the ICMP lines show the same tag, with length 102):

```
02:00:00:00:01:03 > ff:ff:ff:ff:ff:ff, ethertype 802.1Q (0x8100), length 46: vlan 20, p 0, ethertype ARP (0x0806), Request who-has 10.20.0.2 tell 10.20.0.3, length 28
```

h3 sent the frame untagged. The switch put it in VLAN 20 on ingress and tagged it on the
trunk port p2. `ethertype 802.1Q (0x8100)` is the TPID, `vlan 20` is the VID, and `p 0` is
the PCP. Capture on `p2` too (`ip netns exec sw tcpdump -eni p2 -c 4 vlan`) to see
the trunk port's view. Run the capture on `p3` without the `vlan` filter (frames there
are untagged, so the filter would hide them) and the tag is gone. Capture on `p1`
and nothing appears: VLAN 20 never reaches that port. If your tcpdump version prints the
tag differently (for example `vlan 20` without the 8100 wording), the VID is what matters.

## Break it

```bash
bash labs/day01/topo.sh up        # reset to healthy
bash labs/day01/break.sh
```

Do not read `break.sh` or `SOLUTION.md`. Write your evidence chain in `journal.md`
before you fix anything, then run `bash labs/day01/verify.sh`. Every `FAIL` line is one
fault's footprint. Compare with `SOLUTION.md` only after `verify.sh` passes.

Finish with the sentence: "X in AWS is Y on the wire" for L2 (the content file's last
AWS section has the pairs). Teardown: `teardown.md`.
