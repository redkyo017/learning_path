# Day 5 — Routing protocols and BGP

**Truth of the day:** the best-path algorithm, and the administrative distance that decides
before it
**Budget:** 3 h — 45 m theory, 1 h 45 m lab (guided proof, break and diagnose, then the
TGW box with its AWS emulation), 30 m exercises

**At a glance — how to work through this day:**
1. Read "Why this matters", then draw the BGP state machine and the best-path list from
   memory ("Draw it first"). Correct the drawing against the page.
2. Read "Core concepts".
3. Do the lab in `labs/day05/`: `topo.sh up`, the proof walkthrough, `break.sh`,
   `journal.md`, `verify.sh`. Then `vrf.sh` for the Transit Gateway in a box.
4. Write the "X in AWS is Y on the wire" sentences in `journal.md`.
5. Read "Where AWS hides this", then do the exercises whenever you like.

## Why this matters

A team builds a Site-to-Site VPN as the backup for a Direct Connect link. The drill
plan says: shut the VPN, nothing should happen, because the DX carries production. Last
quarter's drill said the opposite. Production traffic was on the VPN the whole time, and
when the VPN went down the traffic did not move to the DX.

Two faults explain it, and neither one is a BGP preference. The DX session was never
Established, because the ASN in the neighbour statement was wrong, so BGP held no DX
route at all. And a static route to the same prefix, left over from the day the VPN was
the only link, pinned traffic to the VPN with an administrative distance of 1. No BGP
preference was ever in play: there was nothing to prefer, and nothing that would
have been consulted if there had been. Checking "is DX preferred in BGP" finds
nothing, because the question is wrong.

This day rebuilds the routing model that makes that story readable: what each routing
source is worth, how BGP builds sessions and picks one path out of many, and how a
Transit Gateway is a set of routing tables with rules about who reads and writes them.
Then you reproduce the incident with four routers in namespaces.

## Draw it first

Draw the BGP finite state machine and the best-path list from memory, then compare.

```
        +------+  start    +---------+  TCP up   +----------+  OPEN ok  +-------------+
        | Idle |---------->| Connect |---------->| OpenSent |---------->| OpenConfirm |
        +------+           +---------+           +----------+           +-------------+
           ^                  |    ^                  |                        |
           |              TCP fails |  retry           | error (NOTIFICATION)   | KEEPALIVE
           |                  v    |                  v                        v
           |               +--------+   TCP up, send OPEN              +-------------+
           +---- error ----| Active |------------------> OpenSent     | Established |
                           +--------+  (listens, waits for peer)       +-------------+
                                                                       UPDATE/KEEPALIVE flow
```

`Idle` is the start and the state after an error. `Connect` is "trying to open TCP".
`Active` is the confusing name: it means TCP failed and the router is trying again and
listening. A session stuck cycling between `Active` and `Connect` never got to
`OpenSent`. A session that reaches `OpenSent` and drops back to `Idle` got a
NOTIFICATION: the OPEN was refused (wrong ASN, bad hold time, bad router-id).

```
Best-path order (first difference wins; the highest/lowest rule is in brackets)
  0. Longest prefix       (forwarding table, before BGP attributes)
  1. Weight               (highest; FRR and Cisco only, never sent to a peer)
  2. LOCAL_PREF           (highest; sent only inside one AS)
  3. Locally originated   (prefer routes this router itself injected)
  4. AS_PATH length       (shortest)
  5. ORIGIN               (IGP < EGP < incomplete)
  6. MED                  (lowest; compared only between paths from the same neighbouring AS)
  7. eBGP over iBGP
  8. Lowest IGP metric to the next hop
  9. Oldest path, then lowest router-id, then lowest neighbour address
```

## Core concepts

### Static versus dynamic routing

A static route is a line you wrote. It costs nothing, never flaps, and never changes
when the network does. A dynamic route is learned from a neighbour, so it follows the
topology: when a link fails, the route is withdrawn and another is used. You use static
routes where the topology is fixed and small (a default route to a gateway, a single
path to a remote office) and a routing protocol wherever there is more than one path or
more than a few prefixes.

When two sources offer a route to the same prefix, the router does not compare their
metrics. A metric means something only inside one protocol. It first compares
**administrative distance** (AD), a trust rating per source, and installs the route from
the lowest one.

| Source | AD (FRR/Cisco) |
|---|---|
| Connected | 0 |
| Static | 1 |
| eBGP | 20 |
| OSPF | 110 |
| IS-IS | 115 |
| RIP | 120 |
| iBGP | 200 |

This is the Day 5 incident: a static route (AD 1) beats an eBGP route (AD 20) for the same
prefix, however good the BGP path is. The route with the lower AD is installed, and the
other source's route stays in its own table, unused. Note the one exception that
matters in practice: a *floating static route* is a static with a deliberately higher
distance (say 250), so it is installed only when the dynamic route is gone. On Linux, the
kernel itself compares only prefix length and then metric, so what zebra installs and
what a hand-typed `ip route` adds can compete (Exercise 2).

### Distance-vector versus link-state

Both families compute shortest paths. They differ in what a router knows.

- **Distance-vector** (RIP, and BGP in a related form): each router tells its neighbours
  "I can reach X at cost N". Nobody has the map, only the neighbours' claims. The maths is
  Bellman-Ford, and the weakness is slow convergence and loops ("count to infinity").
- **Link-state** (OSPF, IS-IS): each router floods a description of its own links to
  everyone in the area. Every router then holds the same map and runs Dijkstra on it.
  Convergence is fast and loop-free, at the cost of memory and CPU growing with the
  area. OSPF splits a network into **areas** around a backbone, area 0, so that a flood
  stays inside one area.

BGP is a **path-vector** protocol. A route carries the list of ASes it crossed (the
AS_PATH). A router rejects any route that already contains its own AS, which is how BGP
avoids loops without a map.

### BGP in one page

- **Transport.** BGP runs over TCP port 179 between configured neighbours. There is no
  discovery: you name each neighbour and its ASN. One side opens the connection and the
  other listens.
- **Messages.** OPEN (version, my ASN, hold time, router-id, capabilities), KEEPALIVE
  (sent every one third of the hold time, and also the reply that confirms an OPEN),
  UPDATE (new routes with attributes, or withdrawn routes), NOTIFICATION (an error, then
  the session closes). Default timers in FRR and Cisco: keepalive 60 s, hold 180 s. Each
  side proposes a hold time and the lower one wins.
- **eBGP and iBGP.** eBGP is between different ASes. The next hop changes to the sender,
  and the AS_PATH gets the sender's ASN prepended. iBGP is inside one AS. The next hop
  is not changed by default, the AS_PATH is not changed, and one rule applies: a route
  learned from an iBGP peer is not sent to another iBGP peer (iBGP split horizon). So
  iBGP needs a full mesh of sessions, or **route reflectors** (one router re-advertises
  to its clients) or confederations to avoid it.
- **ASNs.** Public ASNs are assigned. The private range is 64512–65534 (16-bit) and
  4200000000–4294967294 (32-bit). The 4-byte form (RFC 6793) is carried as a
  capability in the OPEN, and as `AS_TRANS` (23456) to peers that do not support it.
- **Advertising.** A router advertises what you tell it to (`network` statements, or
  redistribution) *and* that is in its routing table. That last condition surprises people:
  a `network` for a prefix the router has no route to is silently not advertised.
- **FRR default.** Since FRR 7.4, eBGP sessions exchange no routes until a policy is
  attached (`bgp ebgp-requires-policy`). The lab sets `no bgp ebgp-requires-policy` to
  keep the configs short. Real routers should keep it on.

### Best path in detail

A router may hold several paths for one prefix. It picks one in the order in the "Draw it
first" list, stopping at the first rule that separates them. Three points to hold on to.

1. **Prefix length is not a BGP rule.** The forwarding table does longest-prefix
   match first. A `/25` with terrible attributes carries traffic ahead of a `/24` with
   perfect ones. That is why a hijack by a more-specific route works.
2. **Local-pref beats AS-path.** Local-pref is the knob for choosing the exit from your
   AS (outbound). It is set on routes you receive. AS-path prepending is the knob for
   influencing how others reach you (inbound), because it lengthens the path you
   advertise. Use each for the direction it controls.
3. **MED is polite, not binding.** It is compared only between paths from the same
   neighbouring AS, unless you enable `always-compare-med`. It is a hint from the
   neighbour about which of its links to use, and the network receiving it may ignore it.

**ECMP and multipath.** BGP installs one best path unless you enable multipath
(`maximum-paths N`). Paths are then used together if they tie on every rule down to the
IGP metric, with the AS-path *length* equal (and for eBGP, optionally the same
neighbouring AS too). The router hashes each flow onto one path, so the packets of one
flow keep their order.

### Policy

A routing policy decides what you accept, what you advertise, and what attributes you set.
Two tools, used together. A **prefix-list** matches prefixes (`10.50.0.0/16 le 24`). A
**route-map** is an ordered list of `permit` or `deny` clauses, each with matches (a
prefix-list, an AS-path, a community) and sets (local-pref, MED, prepend, community).
The lab's `FROM-R3` is a one-clause route-map that sets local-pref 200. Applied inbound
(`neighbor X route-map NAME in`), it touches routes as they arrive. Applied outbound,
it changes what the neighbour sees. A route-map with no matching clause ends in an
implicit deny.

### Timers and fast failure

If a neighbour stops sending, nothing happens until the hold timer expires: up to 180 s
with the defaults. That is far too slow for a failover. There are three remedies:
lower the timers (`timers 3 9`), react to a link-down event (FRR's fast external
failover does so for directly connected eBGP), or use **BFD** (bidirectional forwarding
detection): a tiny hello protocol, often at 300 ms intervals, that tells BGP the path is
dead in about a second. BFD works well because it runs separately from the BGP session.

## Prove it on the wire

The full walkthrough is in `labs/day05/README.md`. The lab builds four namespaces, `r1`
to `r4`, each running its own `zebra` and `bgpd`. r1 is "on-prem" (AS 65001), r2 is the VPN
path (65002), r3 is the DX path (65003), and r4 is "AWS" (AS 64512 <!-- fact-checked 2026-10-05 -->) with the prefix
`10.50.100.0/24`. r1 gives routes from r3 a local-pref of 200. Here is what to capture, and what
each line must prove.

1. **Session establishment.** `tcpdump -ni eth1 tcp port 179` on r1 while you run
   `clear bgp 10.5.13.2`. Label: TCP handshake, OPEN from each side, KEEPALIVE from each
   side, then UPDATE. `tshark -V -Y bgp` shows the attributes in the UPDATE: ORIGIN,
   AS_PATH (`65003 64512`), NEXT_HOP and the prefix. LOCAL_PREF is absent. The peer never
   sent it, and r1 sets it on receipt.
2. **Two paths and the reason.** `show bgp ipv4 unicast 10.50.100.0/24` lists both paths
   and marks the r3 path `best`. `ip -n r1 route show 10.50.100.0/24` shows exactly one
   route, `proto bgp metric 20`. Zebra puts only the winner in the kernel.
3. **Predict, then run.** The reason for the best path is the suffix in
   `show bgp ipv4 unicast <prefix>`: `best (Local Pref)`, `best (AS Path)`,
   `best (MED)`, `best (Router ID)`. Remove the route-map and the tie falls to the
   oldest path first (`best (Older Path)`, the r3 path); only with
   `bgp bestpath compare-routerid` does the lower router-id win (`best (Router ID)`, r2). Put it back and prepend `64512 64512` on r4 toward r3: the local-pref
   still wins, step 2 of the list beating step 4. Then set MED on r2 and r3 toward r1
   (MED is not transitive, so it must be set by the neighbour that sends it to r1) and
   watch it fail to matter across two different neighbouring ASes, until
   `always-compare-med`.
4. **A more-specific route.** Advertise `10.50.100.128/25` from r2 to r1 only. Traffic
   to `.200` goes via r2, traffic to `.1` stays on r3. No attribute was changed.
5. **Failover** (the hold-timer demo; optional if short on time). Shut `r3 eth0`. The route flips in about a second, thanks to the carrier
   event. Remove that shortcut, drop the packets with `nft` instead, lower the timers to
   `3 9`, and the flip takes about nine seconds: the hold timer, measured.

## Lab

See `labs/day05/`. The goal: bring up the four-router topology, prove each best-path
rule above on the wire, then diagnose two independent faults (a wrong remote ASN and a
static route that outranks BGP) from `show` output and a capture, before you read
`SOLUTION.md`. Success signal: `bash labs/day05/verify.sh` exits `0` and prints
`PASS: day 05 is healthy.`

The second lab, `bash labs/day05/vrf.sh up`, is a Transit Gateway in one box. It is
independent of the BGP topology and has its own walkthrough in the README.

## Where AWS hides this

AWS hybrid networking is eBGP and a handful of routing tables, with the knobs renamed.

- **VPN and Direct Connect speak eBGP.** The AWS side is the one you labelled r4. Its
  ASN is 64512 <!-- fact-checked 2026-10-05 --> unless you choose another when you create the virtual
  private gateway or the Transit Gateway. You pick your own ASN for the customer
  gateway. Because the sessions are eBGP, your route-maps, local-pref and prepending
  behave as on any other router.
- **The route preference order is a policy you do not write.** When a VPC route table
  or a TGW route table has several routes for one destination, AWS applies fixed rules.
  The first is the longest prefix. Among equal prefixes in a VPC or TGW table, a static route wins over a
  propagated one, and propagated routes are ranked by source (on a virtual private gateway: Direct Connect, then static VPN routes, then VPN BGP routes; on a Transit Gateway: Direct Connect gateway before Site-to-Site VPN) <!-- fact-checked 2026-10-05 -->. Only then does AS-path length
  count, and for VPN the AWS side honours AS-path length (prepending works, though AWS recommends it only for customer gateways that cannot handle asymmetric routing) and, between paths of equal length from
  the same neighbouring ASN, MED <!-- fact-checked 2026-10-05 -->. The lab's incident is the same
  rule in AWS clothing: a static route in the table outranks everything BGP learned.
- **Make DX primary, in both directions.** The view here is the on-prem router's.
  Outbound (traffic leaving on-prem for the VPC): your router chooses, so set a
  higher local-pref on routes learned over the DX, exactly like `FROM-R3`. For DX, AWS
  also lets you tag the prefixes you advertise with local-preference communities
  (7224:7100 low, 7224:7200 medium, 7224:7300 high) <!-- fact-checked 2026-10-05 --> to steer
  AWS's choice among your DX links. Inbound (traffic AWS sends to on-prem): AWS
  already prefers DX over VPN by its own rule. To reinforce it, or to steer over a
  path AWS ranks equally, prepend your ASN on the advertisement over the VPN. A more
  specific prefix advertised over the VPN would still win, whatever you prepend.
- **Timers.** An AWS VPN tunnel uses a BGP hold time of 30 seconds
  <!-- fact-checked 2026-10-05 -->, much shorter than the 180 s default, and for DX the guidance is to
  enable BFD. In the lab you measured why: without it, a silent failure takes the
  whole hold time to detect.
- **TGW route tables are VRFs.** A Transit Gateway has any number of route tables.
  An attachment (VPC, VPN, DX gateway, peering) is **associated** with exactly one
  table, which it uses to look up where to send the traffic it receives
  <!-- fact-checked 2026-10-05 -->. It can **propagate** its routes into any number of tables,
  which is how the other attachments learn how to reach it. Association is "which table
  do my lookups use", propagation is "which tables learn me". Static routes and
  blackhole routes can be added to any table.
- **Segmentation patterns.** *Isolated spokes*: each spoke is associated with its own
  table and propagates to none (or only to a shared table). *Shared services*: prod
  and dev both propagate into a `shared` table, and shared propagates into both prod
  and dev, but prod and dev do not propagate to each other. That is the pattern the
  `vrf.sh leak` step builds.
- **Lab it locally.** `bash labs/day05/vrf.sh up` then `leak`: three route tables, the
  association rules, and the 3×3 reachability matrix. `labs/day05/topo.sh up` is the
  hybrid-routing half: AS 64512 as "AWS", with a VPN and a DX path.
- **Lab it on AWS.** The hands-on belongs to the sibling course,
  [`../../aws_network_components/`](../../aws_network_components/): Day 4 builds a Transit
  Gateway with route tables, and Day 6 builds the VPN and the BGP session.

**Local emulation.** Four namespaces with FRR are the four routers. Linux policy-routing
tables stand in for VRFs, because this kernel has no VRF device: `ip rule iif att-X
lookup N` is association, a route added into table N is propagation, and a per-attachment
`unreachable` rule at preference 32000 is the isolation that keeps lookups out of the
main table.

## Exercises

1. **Read the FSM.** `show bgp summary` shows a neighbour in `Active` for ten minutes.
   Which two classes of cause do you check first, and with which commands? — **Hint:**
   `Active` means TCP is not completing. — **Solution sketch:** reachability and port:
   `ping` the neighbour, then `ss -ltn` on the peer for 179, and look for a filter (a
   security group, an ACL, an `nft` rule) dropping TCP 179 in one direction. If TCP works,
   the symptom would be `Idle` or `OpenSent`, not `Active`. Capture `tcp port 179`: SYNs
   with no SYN-ACK means a filter or a wrong address.
2. **AD puzzle.** On one router: OSPF offers `10.9.0.0/24` with cost 10, eBGP offers the
   same prefix, and a static route exists with the next hop of another link. Which is
   installed, and how do you make the static a backup? — **Hint:** compare distances, not
   metrics. — **Solution sketch:** the static (AD 1) beats eBGP (20) and OSPF (110). To
   make it a floating backup, give the static a distance above the dynamic one, for
   example `ip route 10.9.0.0/24 192.0.2.1 250`. It is installed only if the
   better route disappears.
3. **FSM diagnosis from symptoms.** Session A cycles `Connect`, `Active`, `Connect`. Session
   B reaches `OpenSent`, then `Idle`, every 30 s. Session C sits in `Established` but
   receives zero prefixes. Name a likely cause for each. — **Hint:** which message type
   is each state waiting for? — **Solution sketch:** A: TCP never completes (route, ACL,
   wrong neighbour address). B: the peer sends a NOTIFICATION after the OPEN (wrong
   remote ASN, hold-time or router-id clash). C: the session is fine and the policy
   is not: `ebgp-requires-policy` with no route-map, a missing `network` statement, or
   an inbound filter. Check `show bgp neighbor X advertised-routes`.
4. **Best path 1.** r1 has two paths to `10.0.0.0/16`: path P via AS 100 with local-pref
   100 and AS-path length 2; path Q via AS 200 with local-pref 150 and AS-path length 5.
   Which wins? — **Hint:** which rule comes first, local-pref or AS-path length? —
   **Solution sketch:** Q. Weight ties (default 0), then local-pref is compared and 150
   beats 100. Path length is never reached.
5. **Best path 2.** Same prefix, two paths with equal local-pref, no weight, both
   learned over eBGP: P has AS-path `100 300`, Q has AS-path `200 300 300`. What if
   Q is locally originated instead of learned? — **Hint:** step 3 comes before step 4.
   — **Solution sketch:** first case: P, the shorter path (2 against 3). If Q were
   locally originated by this router, Q wins before AS-path length is looked at (FRR
   even gives locally originated routes weight 32768, so they win at weight), because
   "locally originated" is rule 3.
6. **Best path 3.** Paths to one prefix from two different neighbouring ASes, 65010
   (MED 5) and 65020 (MED 500). Everything before MED ties. Which wins and why? —
   **Hint:** is MED compared across neighbours? — **Solution sketch:** MED is not
   compared, since the neighbouring ASes differ, so the decision falls to eBGP vs
   iBGP, IGP metric, and then the oldest path or router-id. Enable `always-compare-med`
   and 65010 wins. This is also the answer to "why was my MED ignored?" (Exercise 10).
7. **Best path 4.** r1 holds `10.50.100.0/24` via r3 (local-pref 200) and
   `10.50.100.128/25` via r2 (local-pref 100). Where does a packet to `10.50.100.130`
   go, and one to `10.50.100.10`? — **Hint:** which table does the packet consult?
   — **Solution sketch:** `.130` matches both, the `/25` is longer, so it goes via r2.
   `.10` matches only the `/24` and goes via r3. The forwarding table applies
   longest-prefix match before any BGP attribute. A hijack and a deliberate
   traffic-engineering split are the same mechanism.
8. **Prepend or local-pref?** Your on-prem has DX and VPN to AWS. You want DX primary.
   From the on-prem router's view, for outbound traffic (on-prem to AWS) and inbound
   traffic (AWS to on-prem), which knob do you use, and where? — **Hint:** local-pref
   never leaves your AS. — **Solution sketch:** outbound: set local-pref higher on
   routes your router learns over the DX, inside your AS. Inbound: prepend your ASN on
   the routes you advertise over the VPN, so the AWS side sees a longer path via the
   VPN. Local-pref cannot work in the inbound direction because it is not carried
   across the AS boundary (AWS's own rules also rank DX above VPN).
9. **Design TGW route tables.** Three segments: `prod`, `dev` and `shared` (DNS,
   logging). Prod and dev must reach shared and must not reach each other. List the tables,
   the associations and the propagations. — **Hint:** association is "my lookups",
   propagation is "who learns me". — **Solution sketch:** three tables: `rt-prod`,
   `rt-dev`, `rt-shared`. Associate each VPC attachment with its own table. Propagate
   the shared attachment into `rt-prod` and `rt-dev`. Propagate prod and dev into
   `rt-shared`. Do not propagate prod into `rt-dev` or the reverse. A forgotten
   propagation to `rt-shared` gives a one-way failure: requests arrive, replies have
   no route.
10. **Why was MED ignored?** You set MED 10 on the DX advertisement and 100 on the VPN, to
    prefer DX. The router at the other end still prefers the VPN. Give three reasons. —
    **Hint:** read the best-path list from the top. — **Solution sketch:** an earlier rule
    decided (local-pref, weight, a shorter AS-path); the two paths come from different
    neighbouring ASes (the DX and VPN peers are different), so MED is not compared; or
    the receiving router discards or resets MED by policy. A static route would also
    beat both. Use local-pref on the receiving side, which no earlier rule overrides.
11. **iBGP split horizon.** Three routers R1, R2, R3 in AS 65000 are in a line: R1-R2 and
    R2-R3 have iBGP sessions, R1-R3 does not. R1 originates a prefix. Does R3 learn it? —
    **Hint:** who is allowed to re-advertise an iBGP-learned route? — **Solution sketch:** no.
    R2 learned it from an iBGP peer and does not pass it to another iBGP peer. Fix with a
    full mesh (R1-R3 session), a route reflector (R2 as a reflector with R1 and R3 as
    clients), or a confederation.
12. **Make the failover fast.** The DX path fails silently, behind a provider switch,
    and traffic takes 3 minutes to move to the VPN. How do you reduce that, and what does
    each option cost? — **Hint:** which timer fired? — **Solution sketch:** the hold time
    (180 s default) expired. Options: lower the BGP timers (for example `3 9`; costs more
    keepalives and a risk of flapping on a busy link), enable BFD on the session (sub-second
    detection, a dedicated protocol and more CPU on the router), or use a physical
    mechanism that reports carrier loss (not available behind a provider switch). BFD is
    the standard answer.

## Anti-patterns / Common mistakes

- **Leaving a static route behind (the lab's Fault B).** A static route has AD 1 and
  silently beats every BGP route for its prefix. Audit statics when a dynamic link is
  added, and prefer a floating static (a higher distance) for a deliberate backup.
- **Checking only the BGP table.** `show bgp` says what BGP wants. `show ip route` and
  `ip route get` say what the router does. When they disagree, something with a lower
  AD or a longer prefix is overriding BGP. Compare both tables before you conclude
  anything.
- **Using the wrong knob for the direction.** Local-pref changes where *you* send traffic,
  and prepending changes where *others* send traffic to you. Prepending to move
  your own outbound traffic does nothing, and local-pref cannot move inbound traffic.
- **Trusting MED across neighbours.** MED is compared only between paths from the same
  neighbouring AS. For two providers it does nothing unless `always-compare-med` is
  set on the receiving side. Use local-pref where you control the router.
- **Advertising what you do not have.** A `network` statement for a prefix absent from the
  routing table advertises nothing. Conversely, a loose prefix-list lets a customer
  announce your address space. Filter both ways, and keep `ebgp-requires-policy`.
- **Defaults on a link that must fail fast.** A 180 s hold time is a three minute outage
  on a silent failure. Set short timers and BFD where failover time is a requirement,
  and test it by dropping packets, not by pulling a cable that reports carrier loss.
- **Assuming one path in both directions (mistake 7).** BGP chooses the forward and
  the return path independently: traffic can leave over Direct Connect and come back
  over the VPN. A stateful device on one of those paths sees half the flow and drops
  it as invalid. Check both directions before you put a firewall on a hybrid path.

## Teardown

```bash
bash labs/day05/topo.sh down
bash labs/day05/vrf.sh down
bash labs/verify-teardown.sh
```

Full checklist in `labs/day05/teardown.md`.
