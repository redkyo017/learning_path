# Day 4 — NAT, conntrack and filtering

**Truth of the day:** the netfilter hook order, plus the conntrack table
**Budget:** 3 h — 1 h theory refresh, 1 h 45 m lab (guided proof, the two-AZ inspection
emulation, then break and diagnose), 15 m exercises you can finish later

**At a glance — how to work through this day:**
1. Read "Why this matters", then draw the hook diagram from memory ("Draw it first").
   Correct it against the page.
2. Read "Core concepts".
3. Do the lab in `labs/day04/`: `topo.sh up`, write your own firewall, the proof
   walkthrough, `inspection.sh asym` and `appliance`, then `topo.sh up` again, `break.sh`,
   `journal.md`, `verify.sh`.
4. Read "Where AWS hides this", then do the exercises whenever you like. The AWS lab
   in `aws_lab/day04/` is optional.

## Why this matters

A platform team puts a central inspection VPC behind a Transit Gateway. Two spoke VPCs, two
Availability Zones, a pair of firewall instances, one in each zone. The rollout
passes its smoke test. Then the reports begin: some requests between services hang for
a long time and fail, others are fine, a retry sometimes works, and the pattern
follows no deployment, no instance and no time of day. The firewall logs show no
denies. The security groups are open. The route tables are correct, and every hop is
up. No component reports an error anywhere.

The explanation is that a stateful device holds half a conversation. The request went
through the firewall in one zone and the reply came back through the firewall in the other.
The second firewall saw a SYN-ACK for a connection it had never heard of, marked it
INVALID, and dropped it quietly. Whether a given flow breaks depends only on which
zones its two ends sit in, so a fleet that mixes zones loses a fraction of its flows.

To read that story you need three things: where in the packet path a filter and a NAT
run, what a connection-tracking table stores for one flow, and what makes a stateful
device distrust a packet. This day rebuilds those, then reproduces the incident with
two firewalls and policy routing, and finally (optionally) on a real Transit Gateway.

## Draw it first

On a blank page, draw the netfilter hook path for a router, including where `nat` and
`filter` chains sit. Then compare.

```
                       +-----------+     +---------+
  from the wire -----> | PREROUTING| --> | routing | --+--> FORWARD ---------------+
                       | raw  -300 |     | decision|   |    filter 0               |
                       | conntrack |     +---------+   |                           v
                       |      -200 |                   +--> INPUT --> local     POSTROUTING --> to the wire
                       | dstnat    |                        filter 0  process    srcnat 100
                       |      -100 |                                    |        conntrack confirm
                       +-----------+                                    v           ^
                                                                    OUTPUT ---------+
                                                                    filter 0 (+ re-route)
```

The same thing as an ordered list, with what runs where in the `nft` model:

```
  forwarded packet : PREROUTING -> routing decision -> FORWARD -> POSTROUTING
  packet for me    : PREROUTING -> routing decision -> INPUT -> process
  packet from me   : process -> OUTPUT -> (routing) -> POSTROUTING

  PREROUTING   dstnat chains (DNAT, redirect), priority -100
  FORWARD      filter chains: your firewall policy for transit traffic, priority 0
  INPUT        filter chains: protect the box itself
  OUTPUT       filter chains for local traffic
  POSTROUTING  srcnat chains (SNAT, masquerade), priority 100
  conntrack looks up the flow at priority -200 in PREROUTING and OUTPUT, and
  stores a new entry when the packet leaves POSTROUTING or INPUT.
```

Two consequences to write beside the drawing. The destination NAT happens **before**
the routing decision, so the routing decision sees the translated address. The source
NAT happens **after** it, so the filter in FORWARD sees the original source address,
not the translated one.

## Core concepts

### NAT: SNAT, DNAT, masquerade and port translation

- **SNAT** rewrites the source address of packets leaving. Use it when many private
  hosts share one public address.
- **Masquerade** is SNAT that takes the address from the outgoing interface at the time
  of the packet. It suits an uplink whose address changes. It also forgets all its
  entries if the interface goes down, which `snat to <addr>` does not.
- **DNAT** rewrites the destination, usually to publish a service (`VIP:80` to
  `backend:8080`). Day 3's load balancer was a DNAT.
- **Port translation** is why one public address serves thousands of private hosts.
  When two inside hosts use the same source port, the NAT picks a different port
  for one of them. This is also the NAT's capacity limit: one address, one protocol, one
  destination offers about 64k source ports.

NAT needs **state**. The first packet of a flow picks a translation. The reply has to be
translated back by the inverse mapping, and only a table that remembers the mapping can
do that. This is why a NAT is also a conntrack user, and why a flow that loses its
entry (a timeout, a reboot, the wrong box) cannot be repaired by a retransmission.

### conntrack: the table, the tuples, the states

For each flow the kernel stores one entry with **two tuples**:

```
tcp 6 431999 ESTABLISHED src=10.4.1.10 dst=198.51.100.10 sport=41234 dport=8080 \
                         src=198.51.100.10 dst=198.51.100.1 sport=8080 dport=41234 [ASSURED]
      original direction                  reply direction (what the answer will look like)
```

The first tuple is the packet as the sender wrote it. The second is the packet the reply
is expected to be, **after** any NAT. Where the two do not mirror each other, a
translation is active: here the reply goes to `198.51.100.1`, the NAT-ed address,
instead of `10.4.1.10`. The tuple is the key. A packet that matches either tuple
belongs to the entry, and if the entry says so, the kernel rewrites the packet on
the way through.

The states a filter can match with `ct state`:

| State | A packet that... |
|---|---|
| `new` | starts a flow: a SYN, or the first packet of a UDP exchange |
| `established` | belongs to a flow that has seen traffic in both directions |
| `related` | starts a new flow tied to an old one, such as an ICMP error about it, or an FTP data channel |
| `invalid` | fits no flow and cannot start one: a SYN-ACK or a bare ACK with no entry, an out-of-window segment |
| `untracked` | was exempted with a `notrack` rule |

For TCP, conntrack follows the handshake and the teardown as a state machine
(`SYN_SENT`, `SYN_RECV`, `ESTABLISHED`, `FIN_WAIT`, `TIME_WAIT` and so on), and each
state has its own timeout. The common values on Linux: `ESTABLISHED` is 5 days
(432000 s), `SYN_SENT` 120 s, `TIME_WAIT` 120 s, and a UDP flow with replies is 120 s
(30 s with none). A tracker also checks sequence numbers against the window, so an
ACK for data it has not seen is `invalid`. A device that begins mid-stream may adopt a
flow when `nf_conntrack_tcp_loose=1` (the default). A SYN-ACK, though, is never adopted
as the first packet of a flow: a firewall that sees a SYN-ACK first calls it `invalid`.
Day 3's lab turned `loose` off to mimic the NLB.

The table has a **size limit** (`net.netfilter.nf_conntrack_max`). When it is full, the
kernel drops new flows and logs `nf_conntrack: table full, dropping packet`.
Existing flows keep working, new ones fail, and the symptom comes and goes with load.
Check `conntrack -C` (the current count) against the maximum. The usual causes are
a flood of short flows, long timeouts, a scan, or a table that is much too small for the
box.

### Stateful and stateless filters

A **stateless** filter judges each packet alone, from its header. To allow a client's
reply you must write a rule for it, and because the client's source port is ephemeral
(Linux picks from 32768–60999, Windows and many others from 49152–65535, so allow
1024–65535 to be safe), the rule has to allow that whole range. A **stateful** filter
remembers the flow: allow the request, and the reply is allowed because it matches the
reverse tuple of an `established` flow. No return rule, no port range, and it also
closes holes: a packet from the outside to an inside high port is not a reply to anything
and is dropped.

The cost is the table. A stateful filter can run out of entries, can lose its state
(reboot, timeout, failover) and then drops the survivors of the flows, and **needs to
see both directions** of every flow it judges.

### Asymmetric routing: half a flow

The forward path and the return path are chosen independently, by different route
lookups on different devices, so they can differ. A router does not mind. A
stateful device does. If it is on only one of the paths, it sees half a flow:

- Request through the firewall, reply around it: the firewall has the flow stuck in
  `SYN_SENT`. The client's ACK and later data arrive at it with no SYN-ACK seen, and they
  are `invalid`. If the rules drop invalid, the connection stalls after the handshake.
- Reply through a firewall that never saw the request (the incident in "Why this
  matters"): the SYN-ACK is the first packet it sees, so it is `invalid`.
- Stateless traffic crosses unharmed. ICMP echo has no handshake and no policy that
  needs a flow.

The fix is never "turn off the invalid rule" (see Anti-patterns). It is to make the
return path match the forward path, or to put one state-holding device on both.

### The nftables model

`nft` organizes rules like this:

- A **table** belongs to an address family (`ip`, `ip6`, `inet` for both, `bridge`).
- A **chain** inside it is either a plain chain (a jump target) or a **base chain**
  attached to a hook with `type`, `hook` and a `priority`. A lower priority number runs
  earlier within a hook.
- A base chain has a **policy** (`accept` or `drop`) for packets that no rule decides.
  Several chains on one hook run in priority order, and a drop by any of them is final.
- **Rules** match packet fields and the conntrack state, optionally add a `counter`, and
  end with a verdict: `accept`, `drop`, `reject`, `jump`, `masquerade`, `snat to`, `dnat to`.
- **Sets** hold addresses, ports or interfaces: `tcp dport { 80, 443 }`, or a named
  set you can update while the rules are running. A lookup in a set does not slow down
  as the set grows, so use sets instead of a rule per address.
- **Counters** count packets and bytes per rule. Read them with `nft list ruleset`.
- **Tracing**: `meta nftrace set 1` on a packet makes every chain it later passes
  print what it matched, and `nft monitor trace` shows it. It is the way to settle
  "which rule dropped this".

## Prove it on the wire

The full walkthrough is in `labs/day04/README.md`. The lab builds seven namespaces:
`h1` and `h2` (hosts), `fw` (the firewall and NAT), `r2` (a second router that is
unused until you break the lab), `ext` (the outside) and two bridge namespaces `sw1`,
`sw2`. The proof steps, and what each must show:

0. **Build it from nothing.** Before `topo.sh up`, type a three-namespace network
   (`bh1`, `bfw`, `bext`) by hand: veth pairs, addresses, a default route, forwarding
   and one masquerade rule. The ping from `bh1` to `bext` works and `tcpdump` on `bext`
   shows the source `198.51.100.1`. Then read `topo.sh` and see the same commands
   wrapped in helpers. The block is in `labs/day04/README.md`, step 0.
1. **Write your own policy first.** From the spec (allow h1 to h2:8080 and h1 to the
   outside, NAT out, drop the rest), write `/run/netlab/my.nft`, load it, run
   `verify.sh`, then diff it against `fw.nft`. Each difference is a decision you
   can defend or fix.
2. **`conntrack -E` in fw while you curl.** You see `[NEW]`, state updates and
   `[DESTROY]`. Read the two tuples of the flow to ext: the reply tuple's destination is
   `198.51.100.1`, the NAT-ed address. For the flow to h2 the tuples mirror each
   other.
3. **Counters.** `nft list ruleset` after traffic. A rule with no hits is
   shadowed or unreachable. The invalid counter stays at 0 in a healthy lab.
4. **The hook order.** `meta nftrace set 1` in a prerouting chain, then
   `nft monitor trace`: prerouting, then `forward`, then `postrouting` (the
   masquerade), in the order the diagram shows. The NAT chain only traces for the first
   packet of the flow.
5. **Two-AZ inspection.** `labs/day04/inspection.sh asym` gives a failing curl and a
   rising `fwb` invalid counter. `appliance` gives HTTP 200 and `fwb` shows no invalid packets.

## Lab

See `labs/day04/`. The goal: build and prove the firewall and NAT, reproduce the two-AZ
asymmetric-routing incident and its cure, then diagnose two independent faults (a
return path around the firewall, and a lost NAT) from captures and counters before you read
`SOLUTION.md`. Success signal: `bash labs/day04/verify.sh` exits `0` and prints
`PASS: day 04 is healthy.` Remember `inspection.sh` tears down the main lab: rebuild
with `topo.sh up` before `break.sh`.

## Where AWS hides this

The same machinery sits inside managed services, with the same failure modes. Each
line below is "X in AWS is Y on the wire".

- **A security group is a stateful filter, with a conntrack table per network
  interface.** A reply to an allowed connection is allowed automatically, as in the
  `established` rule you wrote. Connections the SG tracks are subject to timeouts:
  an established TCP connection idles out after 432000 seconds (5 days) on most instance types, or 350 seconds by default on Nitro v6 instance types; both are configurable per network interface (60 to 432000 seconds)
  <!-- fact-checked 2026-10-05 -->, a UDP flow after 30 seconds for one-way traffic or a single request and reply, and after 180 seconds once it is classified as a stream (more than one request-response); both are configurable per interface (30 to 60 and 60 to 180 seconds) <!-- fact-checked 2026-10-05 -->. One catch makes this matter: rules that
  allow the flow for any address (`0.0.0.0/0`) in one direction and all response traffic on all ports (0-65535) in the other
  make a TCP or UDP connection **untracked** (ICMP is always tracked, and flows through a NAT gateway, NLB, egress-only IGW or PrivateLink are tracked regardless) <!-- fact-checked 2026-10-05 -->. An untracked flow has no state
  and no timeout, but it also has no automatic reply allowance, so the return path
  depends on the rules alone. A stateful device elsewhere on the other path drops the
  packet whether or not the SG tracks the flow, so untracking does not cure asymmetry. This
  is the SG version of "check whether the filter is stateful".
- **A NACL is a stateless filter on the subnet boundary.** It judges every packet in
  each direction alone, so a reply needs its own rule. For an inbound HTTPS rule you
  must also allow outbound TCP to the ephemeral range, 1024–65535 <!-- fact-checked 2026-10-05 -->
  (the range clients choose from varies by operating system). Rules are
  evaluated in ascending rule number, the first match decides, and the final
  `*` rule denies everything. Order matters: a deny at 90 beats an allow at 100.
- **AWS Network Firewall** is a managed inspection service in a VPC with two engines.
  The **stateless** engine looks at each packet against rules in priority order and
  can pass, drop or forward to the stateful engine. The **stateful** engine tracks flows and
  takes **Suricata-compatible** rules <!-- fact-checked 2026-10-05 -->, plus simple domain and 5-tuple
  rule groups. You attach firewall endpoints in dedicated subnets, one per AZ, and steer
  traffic to them with route tables. It is the managed form of the policy you wrote,
  and it needs the same symmetric path.
- **The centralized inspection VPC** puts firewalls (Network Firewall endpoints, or
  your own appliance instances as in the lab) in one VPC, with spokes attached through a
  Transit Gateway. The TGW sends traffic to the inspection VPC through its attachment, and
  it chooses the attachment's network interface **in the same AZ as the traffic's
  source**, once for each direction <!-- fact-checked 2026-10-05 -->. With a firewall in each
  zone, a flow between two zones is therefore split across two firewalls: the incident.
- **TGW appliance mode** (`appliance_mode_support` on the inspection VPC's attachment)
  tells the TGW to keep both directions of a flow on **one** AZ's network interface,
  chosen by a flow hash <!-- fact-checked 2026-10-05 -->. Each firewall now sees whole flows. In the
  lab, `inspection.sh appliance` is the same effect on the wire. Without appliance mode
  the usual cure is to run the firewalls in one zone only, which loses zone
  redundancy.
- **GWLB** (Gateway Load Balancer) is the next level: it spreads flows over a fleet of
  appliances with a flow hash that keeps both directions together, and
  tunnels the traffic with GENEVE. Day 6 covers the overlay side.
- **NAT Gateway is a managed SNAT.** It is the masquerade on `fw`, with an Elastic IP as
  the translated address, a limit of 55,000 simultaneous connections per IP address to each unique destination (destination IP, port and protocol), raised by adding IP addresses (up to 8) <!-- fact-checked 2026-10-05 -->, and the idle timeout from Day 3.
  `ErrorPortAllocation` is "the port range ran out" from the NAT section above.
- **Link to the depth.** Security groups and NACLs as constructs, Network Firewall rule
  groups and logging, and WAF/Shield belong to
  [`../../aws_security_components/`](../../aws_security_components/). The Transit Gateway
  hands-on is in [`../../aws_network_components/`](../../aws_network_components/).

**Lab it locally:** `bash labs/day04/inspection.sh up`, then `asym`, then `appliance`.
`fwa` and `fwb` are the two zone firewalls, `tgw` steers with `ip rule`.

**Lab it on AWS (optional):** `aws_lab/day04/` builds three VPCs, a TGW with two route
tables, two nftables firewall instances and the appliance-mode toggle. Read its README
for the cost before you apply.

## Exercises

1. **Three policies in nft.** Write the forward chain rules (assume `policy drop` and
   `ct state established,related accept` already exist) for: (a) allow inside
   `10.4.1.0/24` to reach anything on TCP 443 and UDP 53; (b) allow the outside to
   reach `10.4.2.10` on TCP 8080 only, with DNAT from `198.51.100.1:80`; (c) allow SSH
   (TCP 22) only from the set `{ 10.4.1.5, 10.4.1.6 }` and rate-limit new ones to 10
   per minute. — **Hint:** (b) needs two chains, one at prerouting for the DNAT and one
   at forward for the filter, and the filter sees the translated address. —
   **Solution sketch:** (a) `ip saddr 10.4.1.0/24 tcp dport 443 ct state new accept` and
   the same with `udp dport 53`. (b) `table ip nat { chain pre { type nat hook
   prerouting priority -100; ip daddr 198.51.100.1 tcp dport 80 dnat to 10.4.2.10:8080 } }`
   plus `ip daddr 10.4.2.10 tcp dport 8080 ct state new accept` in forward, because DNAT
   has already rewritten the destination. (c) `ip saddr { 10.4.1.5, 10.4.1.6 } tcp dport
   22 ct state new limit rate 10/minute accept`.
2. **Read a conntrack line.** `tcp 6 431994 ESTABLISHED src=10.4.1.10 dst=198.51.100.10
   sport=51000 dport=8080 src=198.51.100.10 dst=198.51.100.1 sport=8080 dport=51000
   [ASSURED]`. What is the client? What does the outside server see? Which rule created
   the translation? What does 431994 mean? — **Hint:** the reply tuple is what the
   answer will look like on the outside. — **Solution sketch:** the client is
   `10.4.1.10:51000`. The server sees the source `198.51.100.1:51000`, since the reply
   goes to `198.51.100.1`, the NAT-ed address (the port was kept). The postrouting
   masquerade did it. 431994 is the seconds left on the entry's timer. It counts down while
   the flow is idle and resets on every packet. A fresh `ESTABLISHED` TCP entry
   starts at 432000 (5 days), so a value of 431994 would mean 6 s idle.
3. **A NACL puzzle.** A subnet has an inbound allow for TCP 443 from `0.0.0.0/0` (rule
   100) and an outbound allow for TCP 443 to `0.0.0.0/0` (rule 100). Both have the
   default deny after. Clients outside report that HTTPS to a server in the subnet
   hangs, and the server's own outbound curl to port 443 hangs too. Why, and what do you add? —
   **Hint:** which port does each direction of a reply use? — **Solution sketch:** a
   NACL has no state. The inbound request is allowed, but the reply goes out from
   port 443 to the client's ephemeral port, and the outbound rule allows only a
   *destination* of 443. Add an outbound allow for TCP destination ports 1024–65535
   to `0.0.0.0/0`. For the server's own curl to port 443, the *reply* arrives inbound
   at an ephemeral port, so you also need an inbound allow for TCP 1024–65535.
4. **Which flows break?** `fwa` serves AZ-a and `fwb` serves AZ-b. The TGW has no
   appliance mode, and each firewall accepts `ct state new` from `10/8` plus
   `established,related`, and drops `invalid`. Which of these break: (a) a client in AZ-a
   calling a server in AZ-a; (b) AZ-a to AZ-b over TCP; (c) AZ-a to AZ-b ping; (d) a UDP
   DNS query from AZ-a to a resolver in AZ-b; (e) a client in AZ-b calling a server in
   AZ-b? — **Hint:** the TGW picks the firewall by the AZ of the sender of each
   packet, so ask what the second firewall does with the first packet it sees. —
   **Solution sketch:** (a) and (e) work: each flow stays in one AZ, on one firewall.
   (b) breaks: the SYN-ACK is `invalid` at `fwb`, and `fwa` has a flow stuck in SYN_SENT.
   (c) breaks: conntrack starts an ICMP flow only from an echo-request, so an echo-reply
   with no flow is `invalid` at `fwb`. (d) works: the first packet of any UDP exchange is
   `new`, so the reply is accepted by the `10/8` rule as a new flow at `fwb`. Each
   firewall holds a half flow until it times out. Only a policy that accepts nothing but
   `established` replies would notice the UDP asymmetry. TCP, whose handshake
   needs state, is the case that always breaks.
5. **Why did ping survive Fault A?** Fault A makes h2 return through r2. HTTP hangs,
   ping works. Explain with the packets. — **Hint:** which path does the echo-reply
   take, and does any rule need state for the echo-request? — **Solution sketch:** the
   echo-request crosses fw and is accepted by the `icmp type echo-request` rule, which
   needs no flow. The echo-reply takes the same route h2 uses for all traffic to
   `10.4.1.0/24`, which is via r2, so it never crosses fw. No state is needed on
   either leg. TCP needs fw to see the SYN-ACK, or the flow stays in SYN_SENT and
   everything that follows is `invalid`.
6. **SG or NACL?** Choose for each: (a) block one abusive address across a whole subnet
   right now; (b) let web servers answer clients without writing return rules; (c) allow
   a database port only from the application tier, by group, not by address; (d) deny
   one port that an SG allowed everywhere, as a second layer. — **Hint:** SGs have only
   allow rules and attach to a network interface. NACLs have allow and deny and attach
   to a subnet. — **Solution sketch:** (a) NACL: it has a deny, and a low rule number
   wins. (b) SG: it is stateful. (c) SG: it can reference another SG as the source.
   (d) NACL: the only place that can deny.
7. **conntrack table full.** A box logs `nf_conntrack: table full, dropping packet`
   and new connections fail while existing ones live. `nf_conntrack_max` is 65536 and
   `conntrack -C` is 65536. Give three possible causes and two fixes. — **Hint:** what
   fills the table? — **Solution sketch:** causes: a burst of short flows (a scan, or
   a retry storm), long timeouts holding finished flows (TIME_WAIT, an established
   timeout of 5 days for dead clients), or a table too small for the traffic. Fixes:
   raise `nf_conntrack_max` (and the hash size with it, which uses memory), shorten the
   timeouts that hold the entries, or exempt traffic that needs no tracking with a
   `notrack` rule in a raw-priority chain.
8. **SNAT or masquerade?** Pick one for each: (a) an uplink with a DHCP address; (b) a
   fixed public address and an interface that sometimes flaps; (c) many inside hosts,
   one address, and a destination that applies a limit per source port. —
   **Hint:** masquerade looks up the address when the packet goes. —
   **Solution sketch:** (a) masquerade, it follows the address. (b) `snat to <addr>`: masquerade
   flushes its entries when the interface goes down. (c) either one, and the fix lies
   outside the choice: add more addresses to the SNAT range, because the limit is on the
   `(address, port)` pair per destination.
9. **Appliance mode, step by step.** With two firewalls and appliance mode on, spoke A
   in AZ-a calls spoke B in AZ-b. Trace the two directions and say which firewall each
   one meets. Name one cost. — **Hint:** appliance mode pins a flow, by a hash, to one
   inspection interface. — **Solution sketch:** both the request and the reply meet the
   same firewall, say `fwa`. The request leaves AZ-a, the reply AZ-b, and the TGW sends
   both to the `fwa` interface that the hash picked, so `fwa` sees the whole flow and
   `fwb` sees none of it. The cost: the traffic crosses an AZ boundary on its way
   (cross-AZ data charges and latency), and the load is no longer split by zone,
   only by the hash.
10. **Tracked or untracked?** An SG allows inbound TCP 443 from `0.0.0.0/0` and has
    outbound `0.0.0.0/0` all protocols. A second SG on the same instance allows
    inbound all traffic from `0.0.0.0/0`. What is the result for a connection to port
    443, and what changes when asymmetric routing delivers the reply through another
    stateful device? — **Hint:** a connection is untracked only if the rules allow the
    flow in both directions with no restriction. — **Solution sketch:** the union of
    the rules on the interface decides. All inbound and all outbound traffic
    from and to `0.0.0.0/0` are allowed, so the connection is untracked: no state, no
    idle timeout. A reply routed through some other stateful hop is still dropped
    there, and the instance itself would not mind. The lesson: check which filter
    actually holds state for a flow before you blame (or trust) it.

11. **Hand-built NAT: what does the capture show?** In the build-it-from-nothing
    network, `bh1` (10.40.1.10) pings `bext` (198.51.100.10) through `bfw`. What source
    address does `tcpdump` on `bext` show, and what happens to the ping if you flush the
    `post` chain? — **Hint:** `bext` has no route to 10.40.1.0/24. — **Solution sketch:**
    The source is `198.51.100.1`, the masqueraded address of `bfw-out`. After the flush
    the request still leaves `bfw` with source 10.40.1.10; `bext` has no route back to
    that address, so no reply comes and the ping times out. The capture on `bext` shows
    requests from an address it cannot answer.

## Anti-patterns / Common mistakes

- **Assuming a filter is stateless, or stateful, without checking (mistake 6).** An SG
  tracks flows, a NACL does not, and an `ESTABLISHED`-only iptables rule does. Getting
  it wrong gives you a missing return-port rule, or a flow dropped as invalid. For every
  filter in the path, write down whether it keeps a table, how long entries live, and
  how big the table is.
- **Assuming routing is symmetric (mistake 7).** The return packet gets its own route
  lookups, device by device. A stateful device on one path sees half a flow, and the
  failure looks like a hang in the middle of a handshake with no deny anywhere. Trace the
  reply's route separately every time, and put the capture where the half-flow shows:
  one side with a SYN, none with a SYN-ACK.
- **Opening `0.0.0.0/0` to fix a return-path problem.** When a flow dies at a stateful
  device, the temptation is to allow everything in from the other side, or to drop the
  `invalid` rule. That hides the path bug instead of fixing it, widens the attack
  surface, and the flow stays asymmetric and fails again when something else (a second
  firewall, a changed route) takes the state away. Find the path that returns the
  packet, and repair that.

## Teardown

```bash
bash labs/day04/topo.sh down          # and inspection.sh down if you used it
bash labs/verify-teardown.sh
```

Full checklist in `labs/day04/teardown.md`. If you ran the AWS lab, `terraform destroy`
and `aws_network_components/scripts/sweep.sh`.
