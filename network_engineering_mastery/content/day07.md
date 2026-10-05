# Day 7 — Capstone: one packet end to end

**Truth of the day:** a request is one packet followed through every table that touches it
**Budget:** 3 h — 3 h lab (60 m model including the refresh, 30 m prove, 90 m gauntlet); exercises optional, after the course

**At a glance — how to work through this day:**
1. Read "Why this matters", then draw the whole path from memory ("Draw it first").
2. Read "Core concepts" as a walk, one hop at a time. At each hop name the table that
   decides and the fields that change.
3. Do the lab in `labs/day07/`: `topo.sh up`, fill the hop table, capture the packet in
   three places, then `gauntlet.sh start 1` through `start 5`.
4. Read "Where AWS hides this", then do the exercises whenever you like.

## Why this matters

At 02:10 the on-call page says "orders are failing". The service team sees timeouts
calling a partner API that lives in a data center. The platform team sees a healthy
Transit Gateway attachment and a VPN tunnel marked up. The network team on the
data-center side sees a firewall that logged nothing. The DNS owner sees query logs
with correct answers. Four teams each look at their own box, each box is green, and the
orders are still failing, because the fault is in the space between two boxes: a table
that one team owns and another team's change touched.

Nobody on that call can win by knowing one layer well. The person who closes the incident
carries the whole path in their head: the name is resolved by this server, the packet
leaves by this route, crosses this device that rewrites these fields, enters a tunnel
that costs this many bytes, is carried by a protocol that advertises this prefix, meets a
filter that keeps this state, and arrives at a socket. They then pick the first place
the packet could be missing and look there with one command.

Days 1 to 6 gave you the parts. Today you assemble them in one lab and run one request
through all of them. You first write down what should happen at each hop, then capture
it in three places and compare, and finally break it five ways without being told where.
The skill you are building is not any single command. It is choosing which
command to run first, and knowing what its output will prove.

## Draw it first

Before you read further, draw the full path on a blank page. Every box is a device; every
arrow is a hop. Next to each arrow write the table that decides what happens there.
Then compare with the drawing below.

```
 task            vpcr (VPC router + resolver)      tgw (Transit Gateway)           onp (on-prem edge)         api
 10.70.1.10      10.70.1.1  10.70.1.2   .255.1     10.70.255.2  gre1 169.254.10.1  gre1 169.254.10.2          192.168.10.10
    |                |  eth0             | eth1        | eth0         | wan 100.64.0.1    | wan 100.64.0.2 |lan   |
    +---- eth0 ------+                   +-------------+              +=== underlay =====+                +------+
                                                                       100.64.0.0/30

 (1) name            resolv.conf -> 10.70.1.2 -> forward-zone onprem.corp -> odns 192.168.20.53 (via the same path)
 (2) L2              task ARPs for 10.70.1.1: neighbour table decides the destination MAC
 (3) VPC route       vpcr: longest prefix match, 192.168.0.0/16 via 10.70.255.2
 (4) TGW route       tgw: route lookup -> 192.168.0.0/16 learned by BGP -> gre1. MSS clamp on SYN
 (5) encapsulation   GRE: outer IP 100.64.0.1 > 100.64.0.2, +24 bytes, inner MTU 1476
 (6) underlay        100.64.0.0/30: a plain L3 hop, the inner packet is opaque
 (7) decap + route   onp: decapsulate, route 192.168.10.0/24 on lan; return route 10.70.0.0/16 learned by BGP
 (8) filter          onp: nft forward chain + conntrack, policy drop
 (9) socket          api: listener on :8080; the SYN-ACK retraces (8), (7), (5), (4), (3)
```

Checkpoints for your own drawing: do you have **ten tables** on it (resolver config,
neighbour table, VPC route table, TGW route table, tunnel MTU, BGP RIB, kernel FIB,
conntrack, firewall rules, socket table)? Does your drawing show the return path using a
different route from the forward path, even though it crosses the same devices? If
not, add them.

## Core concepts

### One request, nine hops

The request is `curl http://api.onprem.corp:8080/` from `task`. Follow it like a
packet, not like a diagram.

**Hop 1 — the name (Day 6).** `curl` calls `getaddrinfo`, which reads `/etc/resolv.conf`:
`nameserver 10.70.1.2`. That address sits on the same subnet as `task`, so the query is
one L2 hop away. `vpcr` runs unbound with `forward-zone: onprem.corp -> 192.168.20.53`,
so the answer comes from the on-prem server, and the query itself crosses the whole
path described below (source `10.70.255.1`). The resolver caches the answer for its TTL,
which is why a name can keep working for a minute after the path behind it breaks
(the lab sets `cache-max-ttl: 1` to shorten that, so faults show on the next lookup).
Two things to hold: the client does not decide the path to the answer, the resolver
does; and a failure to resolve can be a DNS fault or a routing fault underneath DNS.

**Hop 2 — ARP to the gateway (Day 1).** `task` has `default via 10.70.1.1`. It ARPs for
`10.70.1.1`, gets the MAC of `vpcr`'s `eth0`, and builds the frame: destination MAC =
`vpcr`, source MAC = `task`, IP source 10.70.1.10, IP destination 192.168.10.10. The
IP addresses will not change for the rest of the trip. The MACs change on every link.

**Hop 3 — the VPC router (Day 2).** `vpcr` receives the frame, strips the Ethernet
header, and runs longest prefix match on 192.168.10.10. The matching entry is
`192.168.0.0/16 via 10.70.255.2`. It decrements the TTL (64 to 63), recomputes the
header checksum, ARPs for `10.70.255.2`, and forwards. Nothing else about the packet
changes. The VPC route table in AWS makes exactly this decision, and
`10.70.1.0/24` in the VPC is a connected route that wins for local destinations.

**Hop 4 — the TGW lookup and the clamp (Days 2, 3, 5).** `tgw` routes on the same
destination. The matching route is `192.168.0.0/16`, learned from BGP, with next hop
`169.254.10.2` out of `gre1`. Before the packet leaves, the SYN passes a rule in the
forward hook: `tcp flags syn tcp option maxseg size set rt mtu`. It reads the MTU of the
outgoing route (1476), subtracts 40 bytes of IP and TCP header, and rewrites the MSS
option in the SYN to 1436. Both ends now promise never to send a segment larger than 1436
bytes of payload, so no packet exceeds 1476 bytes. TTL becomes 62.

**Hop 5 — encapsulation and MTU (Day 6).** `gre1` wraps the packet: a new outer IP header
(100.64.0.1 to 100.64.0.2, protocol 47, TTL 64) and a 4-byte GRE header. That is 24 bytes
of tax, so the tunnel's MTU is 1500 minus 24, which is 1476. The outer packet for a
full-size inner packet is exactly 1500 bytes. If the inner packet is larger and carries
DF, the tunnel must refuse it and send ICMP "fragmentation needed" back. If nobody
receives that ICMP, the sender never learns, and the packet vanishes. The MSS clamp
exists so that the ICMP is never needed.

**Hop 6 — the underlay (Day 2).** `100.64.0.0/30` is an ordinary link. The underlay
routes only on the outer header. It cannot see ports, flags or the inner addresses, and
it does not need to. Anything you capture here shows GRE with the inner packet inside.

**Hop 7 — decapsulate, then route (Days 2, 5).** `onp` receives protocol 47, removes the
outer header, and treats the inner packet as new input on `gre1`. It routes
`192.168.10.10` out of `lan`, decrementing the TTL once more (61). The *return* route
matters too: `onp` needs a route to `10.70.1.10`. It has `10.70.0.0/16 via 169.254.10.1`,
learned from BGP because `tgw` advertises that prefix (`network 10.70.0.0/16`, backed by
a blackhole route so the prefix exists locally). `tgw` has the specific `10.70.1.0/24`,
so the blackhole never catches real traffic. The advertisement is a summary: neither
side needs to learn every subnet of the other.

**Hop 8 — the firewall and conntrack (Day 4).** The forward chain on `onp` is
`policy drop` with a short list: established and related accept; invalid drop; new
TCP to `192.168.10.10:8080` from `10.70.0.0/16`; DNS to and from `192.168.20.53`;
selected ICMP types. The SYN matches the new-connection rule, and conntrack records an
entry in state NEW, with the original tuple and the reversed one. When the SYN-ACK
returns, it matches the entry and is accepted by `ct state established`. If that one
rule is missing, new connections start and nothing comes back.

**Hop 9 — the socket (Day 3).** `api` has a listener on `0.0.0.0:8080`. The SYN creates
a new half-open connection in SYN_RCVD (the listener stays in LISTEN), the SYN-ACK
leaves, and the final ACK moves that connection to ESTABLISHED and into the accept
queue. `python3 -m http.server` calls `accept()` and writes the response.

The reply retraces hops 8, 7, 5, 4 and 3 in reverse (the firewall at hop 8 sees it first, as an established flow), each with its own table lookup. The
path back is its own decision at every router. A route that exists only in one direction
produces the most confusing failure in networking, a SYN that arrives and an answer that
never does.

### Which table decides, and what it tells you when it is wrong

| Layer of the walk | The table | A wrong value looks like |
|-------------------|-----------|---------------------------|
| Name | resolver config, forward rules, cache | `could not resolve host`, or a name that works from some clients |
| L2 | neighbour table / FDB | wrong MAC, frames to nowhere (Day 1) |
| VPC route | `ip route` on `vpcr` | `Network is unreachable`, or traffic going the wrong way |
| TGW route | `ip route` + BGP RIB on `tgw` | a route missing from the RIB, or a more specific route that wins |
| Tunnel | interface MTU, clamp, ICMP | small things work and large things hang |
| BGP | advertised and received routes, filters | session up, prefix missing |
| Firewall | rules and conntrack | silence after the SYN, a RST, or an `INVALID` drop |
| Socket | listener, backlog | connection refused (RST) or SYN dropped |

Read the table from the failure toward the cause: the symptom column picks the row, and
the row tells you which command to run first.

## Prove it on the wire

Three captures taken at once, while one `curl` fetches the 300000-byte file:

```bash
ip netns exec task tcpdump -ni eth0 -e -w /run/netlab/task.pcap 'tcp port 8080' &
ip netns exec tgw  tcpdump -ni wan  -e -w /run/netlab/wan.pcap  'ip proto 47'   &
ip netns exec onp  tcpdump -ni lan  -e -w /run/netlab/lan.pcap  'tcp port 8080' &
```

Read them with `tcpdump -nver FILE`. These five comparisons are the proof that the model
in "Core concepts" is true.

1. **MACs change, IPs do not.** At `task eth0` the destination MAC is `vpcr`'s. At `onp
   lan` it is `api`'s. The IP pair `10.70.1.10 > 192.168.10.10` is identical in both.
   A router replaces the Ethernet header and leaves the IP header alone except for TTL
   and checksum.
2. **TTL counts routers.** 64 at `task`. On `wan`, the inner packet shows 62, the outer
   GRE header shows 64 (it is a new packet with its own TTL). At `lan` it is 61.
3. **The underlay sees only GRE.** On `wan`, `tcpdump -v` prints
   `100.64.0.1 > 100.64.0.2: GREv0 ...` and then the inner packet. The outer IP header is
   all the underlay routes on.
4. **The clamp rewrote one option.** The SYN at `task` carries `mss 1460`. The same SYN
   inside GRE on `wan` carries `mss 1436`. Nothing else in the SYN differs. That field is
   the reason a full-size segment ends at 1500 bytes on the underlay, with no
   fragmentation anywhere.
5. **Conntrack holds the flow.** `ip netns exec onp conntrack -L` prints one entry with
   two tuples. The second tuple is the reply, with source and destination swapped. The
   SYN-ACK matches it, which is how `ct state established` accepts it with no port rule.

When the packet is missing from a capture, the fault is between the previous capture
and this one. That is Day 3's rule for debugging with a capture, applied to three
points at once.

## Lab

See `labs/day07/`. The goal: fill in a hop table from the model, prove it with the three
captures, then run the gauntlet: five incidents, each injected by
`gauntlet.sh start N`, each diagnosed from evidence before you read `ANSWERS.md`.
The rubric rewards the order of operations (evidence, then fix), not the speed of the
fix. Success signal: `bash labs/day07/gauntlet.sh check N` prints
`PASS: day 07 is healthy.` for N = 1 to 5.

The five symptoms, and the Day each one draws on:

| # | Symptom | Draws on |
|---|---------|----------|
| 1 | Health check OK, large responses hang | Days 2, 3, 6 |
| 2 | Name resolves, connect times out | Days 2, 5 |
| 3 | Everything on-prem unreachable since the change window | Day 5 |
| 4 | `curl: Could not resolve host api.onprem.corp` | Day 6 |
| 5 | SYN reaches on-prem, nothing comes back | Days 3, 4 |

For each incident, your first three commands should each cut the search space in half.
A command that cannot change your next decision is a waste of the 20 minutes.

## Where AWS hides this

Each line is "X in AWS is Y on the wire". The table maps every local hop to the AWS
construct and the failure signature you saw in the gauntlet.

| Local hop | AWS construct | Failure signature |
|-----------|---------------|-------------------|
| `vpcr` resolver `10.70.1.2` | VPC resolver, the base of the VPC range plus two <!-- fact-checked 2026-10-05 --> | name fails while the IP works (incident 4) |
| `forward-zone onprem.corp` | Route 53 Resolver outbound endpoint with a forwarding rule <!-- fact-checked 2026-10-05 --> | `NXDOMAIN` or `SERVFAIL` for the on-prem domain only |
| `vpcr` route table | VPC route table: local route plus targets such as a Transit Gateway attachment <!-- fact-checked 2026-10-05 --> | `Network unreachable` or traffic to the wrong target |
| `tgw` route lookup | Transit Gateway route table, with static and propagated routes <!-- fact-checked 2026-10-05 --> | an on-prem prefix missing (incident 3) or a more specific static route winning (incident 2) |
| `gre1` + clamp | Site-to-Site VPN tunnel (IPsec) <!-- fact-checked 2026-10-05 -->; the customer gateway must clamp MSS | small things work, large things hang (incident 1) |
| BGP `tgw <-> onp` | BGP over the VPN, with routes propagated to the TGW route table <!-- fact-checked 2026-10-05 --> | tunnel `UP`, routes absent |
| `onp` forward chain | the on-prem firewall; AWS side: security groups (stateful) and network ACLs (stateless) <!-- fact-checked 2026-10-05 --> | SYN seen, no reply (incident 5) |
| `api` socket | the target service behind a security group | RST (refused) versus silence (filtered) |

Three habits to carry from the table:

- **A VPN that is "up" is a statement about IKE, not about your routes.** The console can
  show a tunnel `UP` <!-- fact-checked 2026-10-05 --> while the route table has lost the prefix, because the up/down
  state does not read the BGP table.
- **A NACL is the on-prem firewall you forgot is stateless.** Its outbound rules must
  allow the ephemeral return range (1024-65535 is the usual choice) <!-- fact-checked 2026-10-05 -->,
  or you get incident 5 without any firewall appliance.
- **Static analysis catches configuration, not behavior.** The sibling course's Day 8,
  VPC Reachability Analyzer (`../aws_network_components/`), takes a source and a
  destination and walks the *configured* tables, naming the first one that blocks <!-- fact-checked 2026-10-05 -->.
  It analyses AWS-side configuration only. It would find incident 2 (a route) and show
  the missing propagated TGW route in incident 3, though it cannot name the on-prem
  filter that caused it. It cannot see incident 5 as built (an on-prem conntrack rule);
  only a NACL variant would be found. It cannot find incident 1 (an MTU black hole is a
  runtime property) or incident 4 (it does not run DNS). Use it first for the configuration questions and a capture for the rest.

## Exercises

1. **Byte arithmetic for the tunnel.** The underlay MTU is 1500 and the tunnel is GRE.
   (a) What are the tunnel MTU and the largest TCP payload per segment, assuming the
   TCP timestamp option (12 bytes) is on? (b) The tunnel changes to GRE with a 4-byte
   key field (8 bytes of GRE header). What do both numbers become? — **Hint:** MTU is
   1500 minus outer IP (20) minus GRE; the payload is MTU minus IP (20) minus TCP (20)
   minus options. — **Solution sketch:** (a) 1500 - 24 = 1476; payload = 1476 - 40 = 1436
   without options, 1424 with timestamps, so the lab's clamp (MSS 1436) already counts
   the 40 bytes of IP and TCP. (b) MTU 1472, MSS 1432, and 1420 payload with timestamps.
2. **A packet's journey as a table.** A packet leaves `task` with TTL 64, destination
   MAC `M1`. Give the TTL and the destination MAC type (whose MAC) at: `vpcr` eth1 out,
   the inner header at `tgw` wan, the outer header at `tgw` wan, `onp` lan out. —
   **Hint:** a router decrements TTL when it forwards; encapsulation creates a new
   outer TTL; the MAC is that of the next L2 neighbour. — **Solution sketch:** `vpcr`
   eth1 out: TTL 63, destination = `tgw`'s eth0. Inner at `wan`: TTL 62 (tgw
   decremented it before encapsulating). Outer at `wan`: TTL 64 (set on the tunnel),
   destination MAC `onp`'s `wan`. `onp` lan out: TTL 61, destination = `api`'s eth0.
3. **The loop's lifetime.** In incident 2 the packet circulates between `vpcr` and
   `tgw`. It enters `vpcr` with TTL 64. Which router drops it, with what TTL on arrival,
   and why does `task` see a time-exceeded and not a RST? — **Hint:** list the TTL on
   arrival at each router in turn; a router forwards only when TTL is greater than 1. —
   **Solution sketch:** arrivals alternate `vpcr` (64, 62, ...) and `tgw` (63, 61, ...,
   1). `tgw` receives TTL 1 and sends ICMP time-exceeded to `task`. A RST needs a
   listener on the far side to reply, and no host ever got the SYN. TCP treats ICMP as
   a soft error, so `curl` ends on its own timeout.
4. **Pick the bigger hammer last.** A colleague proposes, for incident 1, to set both
   `gre1` MTUs to 1400 "to be safe". Does that close the black hole? — **Hint:** the
   state is: no clamp, ICMP frag-needed dropped. What size does `api` still send? —
   **Solution sketch:** no. `api` still sends 1500-byte packets, which exceed 1400, as
   they exceeded 1476, and the frag-needed that would tell it so is still dropped.
   Only restoring ICMP (path MTU discovery) or the clamp fixes it. With the clamp
   back, a 1400 MTU lowers the MSS to 1360 and wastes capacity compared with 1476. For
   UDP the clamp does nothing, so ICMP must flow too.
5. **Draw the BGP policy.** `onp` must advertise `192.168.0.0/16` but never
   `192.168.20.0/24` (DNS) to `tgw`, and `tgw` must prefer a second tunnel (a backup)
   only when the first is down. Name the attribute you set on each side and in which
   direction. — **Hint:** an attribute you set on routes you *send* influences the
   neighbour's inbound choice; local preference works on routes you *receive*. —
   **Solution sketch:** `aggregate-address ... summary-only` already hides the `/24`
   (that is incident 3's mechanism used correctly). For the backup: on `tgw`, set a
   lower local preference on routes received from the backup neighbour, so the
   primary wins. For the return direction, on `onp` set a lower local preference on routes received
   from the backup neighbour (or prepend the AS path on `tgw`'s announcements over the
   backup). Prepending on `onp`'s own announcements would steer `tgw`'s forward path,
   not `onp`'s return choice.
6. **Idle timeouts across the whole path.** A client keeps an HTTP connection idle for
   10 minutes, then sends a request and gets a RST. Which devices on this path hold
   per-flow state, and which one has the shortest timer? — **Hint:** list the devices
   with a table of flows, then recall Day 3's NLB incident. — **Solution sketch:**
   `onp` conntrack, and any stateful device in the path (in AWS a NAT gateway or a
   load balancer has an idle timeout <!-- fact-checked 2026-10-05 -->). The shortest timer on the
   path wins: its entry expires, the next packet is `INVALID` or no longer matches, and a
   device resets or drops. Fix with TCP keepalives shorter than the smallest timer.
7. **Classify the incidents.** For each of the five incidents, say whether VPC
   Reachability Analyzer would find it, which Day's tool you would use otherwise, and
   the first capture point. — **Hint:** ask whether the fault is a configured table
   entry or a runtime behavior. — **Solution sketch:** 1: no (MTU/ICMP is runtime), use
   a DF ping ladder (Day 2) and capture on both sides of the tunnel. 2: yes (a more
   specific route), `ip route get` on each hop. 3: partly (it shows the missing propagated TGW route, not the on-prem filter), `show bgp ... advertised-routes`. 4: no (DNS), `dig @server` for each
   resolver. 5: no as built (an on-prem conntrack rule is outside AWS config; a NACL variant would be found), capture on both sides of the firewall.
8. **Write the on-call prompt.** The page says "intermittent timeouts to the partner
   API, only from one of two AZs". Write the first four checks in order, each with the
   evidence it produces, and what the result sends you to next. — **Hint:** split by
   layer and by what is different between the two AZs. — **Solution sketch:** (1) `dig`
   from a task in each AZ at the resolver it really uses: same answer? (2) `ip route
   get` the partner IP in each AZ's subnet route table: same target? (3) a DF ping
   ladder in both AZs: same MTU limit? (4) capture on both sides of the filter in the
   bad AZ: does the SYN-ACK come back? The first one that differs is the fault
   domain. Check what is *different* between the AZs (route table association, NACL,
   a second tunnel with a different MTU or filter) before checking what is shared.

## Anti-patterns / Common mistakes

Each of the eight mistakes from `STRATEGY.md` appears in the gauntlet. Check yourself
against all eight.

- **Mistake 1: memorizing the OSI model instead of the headers.** "It's a layer 3
  problem" fits incidents 2 and 3 and tells you nothing. The useful sentence names a
  field: the destination address matched a route with a next hop pointing back, or the
  prefix is absent from the table.
- **Mistake 2: learning tool flags instead of the protocol.** If you could not say what
  table `ip route get` or `show bgp ... advertised-routes` reads, you were reciting.
  Say the table before you run the command.
- **Mistake 3: treating AWS networking as magic.** The TGW, the VPN and the resolver
  endpoint are a route table, a tunnel with an MTU, and a forwarder. For every AWS
  component in your incident notes, write the "Y on the wire" half.
- **Mistake 4: debugging without a capture.** Incident 1 cannot be solved from logs:
  the app sees nothing wrong, the health check is green. Two captures, one on each side
  of the tunnel, show the packet that leaves and does not arrive.
- **Mistake 5: confusing a timeout with a reset.** Incident 2 and 5 end in a timeout
  (nothing came back); a closed port ends in a RST (someone answered). Read the error
  as a wire event first.
- **Mistake 6: assuming a filter is stateless, or stateful, without checking.**
  Incident 5 exists because the policy depended on connection state, and one rule was
  gone. For each filter on the path write down whether it keeps a table.
- **Mistake 7: assuming routing is symmetric.** The reply takes its own route at every
  hop. Check forward and return tables separately (incidents 2 and 5 both involve the
  return leg).
- **Mistake 8: not knowing which view of a name you are asking.** "It resolves" is not
  an answer: `dig` shows the server. In incident 4 the client's resolver failed while
  the authoritative server, asked directly, was fine.
- **Changing two things at once.** You cannot tell which one worked. One hypothesis,
  one change, one check.
- **Fixing by `reset`.** It restores the lab and teaches nothing. In production the
  equivalent is a rollback with no root cause: the next change window repeats it.
- **Trusting a green health check as proof of a working path.** It proves the
  small-packet path. Test the largest payload and the slowest path as well.

## Teardown

```bash
bash labs/day07/topo.sh down
bash labs/verify-teardown.sh
```

Full checklist in `labs/day07/teardown.md`.
