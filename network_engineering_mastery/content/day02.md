# Day 2 — L3 Addressing and Forwarding

**Truth of the day:** the IP header, and the routing table that reads it
**Budget:** 3 h — 45 m draw and read; 45 m prove it on the wire; 60 m lab; 30 m exercises

**At a glance — how to work through this day:**
1. Draw both IP headers from memory, then read "Core concepts".
2. Run `labs/day02/` inside `netlab`: build, prove, `break.sh`, write `journal.md`, `verify.sh`.
3. Optional, standalone: "Exercises" (see `STRATEGY.md`, "Where Exercises fit").
4. Read "Where AWS hides this" and write the "X in AWS is Y on the wire" sentences.
5. Teardown: `labs/day02/teardown.md`.

## Why this matters

A team moves a service behind a site-to-site VPN. Health checks pass. Logins work. Small
API calls work. Then a report endpoint that returns 80 KB hangs for every client until
the load balancer gives up. Nothing is down, nothing logs an error, and a restart changes
nothing. The cause is a path whose MTU is smaller than the packets the server sends, and
a firewall that discards the one ICMP message that would have told the server so. This is
an MTU black hole. The bytes that fit get through; the bytes that do not vanish.

You cannot find that by thinking in layers. You find it by knowing what is in the IP
header (the DF bit, the total length), what a router does with a packet it cannot
forward (drop it and send ICMP type 3 code 4), and which table decides where a packet
goes next. Today is that header and that table. Day 3 puts TCP on top of it.

## Draw it first

On blank paper, before reading anything else, draw the IPv4 header as rows of 32 bits and
the IPv6 fixed header beside it. Label every field and its width in bits. Then compare.

```
IPv4 header, 20 bytes without options (each row is 32 bits)
 0       4       8              16      19                 31
+-------+-------+--------------+-------+-------------------+
|Version|  IHL  | DSCP |  ECN  |        Total length       |
+-------+-------+--------------+-------+-------------------+
|        Identification        |Flags  |  Fragment offset  |
+---------------+--------------+-------+-------------------+
|      TTL      |   Protocol   |      Header checksum      |
+---------------+--------------+---------------------------+
|                    Source address                        |
+----------------------------------------------------------+
|                 Destination address                      |
+----------------------------------------------------------+
Version 4b, IHL 4b, DSCP 6b, ECN 2b, Total length 16b, ID 16b,
Flags 3b (reserved, DF, MF), Fragment offset 13b, TTL 8b, Protocol 8b, Checksum 16b.

IPv6 fixed header, 40 bytes
+-------+----------------+--------------------------------+
|Version| Traffic class  |           Flow label           |   4b, 8b, 20b
+-------+----------------+----------+---------+-----------+
|        Payload length  |Next hdr  |Hop limit|               16b, 8b, 8b
+------------------------+----------+---------+-----------+
|                Source address (128 bits)                 |
|             Destination address (128 bits)               |
+----------------------------------------------------------+
```

Check your drawing for the three things people drop: IHL counts 32-bit words (so 5 means
20 bytes), the fragment offset counts 8-byte units, and IPv6 has no header checksum and no
fragmentation fields at all.

## Core concepts

### The IPv4 header, field by field

| Field | Bits | What it does |
|---|---|---|
| Version | 4 | 4. |
| IHL | 4 | Header length in 32-bit words. 5 is 20 bytes; the maximum 15 is 60 bytes. |
| DSCP / ECN | 6 / 2 | Priority marking, and congestion notification (the router sets ECN instead of dropping). |
| Total length | 16 | Header plus payload in bytes. Maximum 65,535. This is the number a link MTU limits. |
| Identification | 16 | Groups the fragments of one original packet. |
| Flags | 3 | Reserved, **DF** (do not fragment), **MF** (more fragments follow). |
| Fragment offset | 13 | Where this fragment's data starts, in 8-byte units. |
| TTL | 8 | Decremented by every router. At 0 the router drops it and sends ICMP 11. |
| Protocol | 8 | What the payload is: 1 ICMP, 6 TCP, 17 UDP, 47 GRE, 50 ESP. |
| Header checksum | 16 | Covers the header only. Every router recomputes it because TTL changed. |
| Source, destination | 32 + 32 | The addresses. |

Everything a router needs is in those 20 bytes. It never reads the payload to forward.

### The IPv6 fixed header and the extension chain

The fixed header is 40 bytes: traffic class, flow label, payload length, **next header**
(the same job as the IPv4 protocol field), hop limit (the TTL), and two 128-bit
addresses. Optional features moved out of the header into **extension headers** chained by
the next-header field: hop-by-hop options, routing, fragment, destination options, then
the transport header (6 TCP, 17 UDP, 58 ICMPv6, 50 ESP).

Two consequences you will meet in labs. Routers do not fragment IPv6 packets: only the
source may, using the fragment extension header, so a too-big packet is dropped and the
router sends ICMPv6 type 2 "packet too big". And that makes ICMPv6 mandatory, not
optional: block it and path MTU discovery and neighbour discovery both die.

### CIDR: the mental method

A prefix `/n` fixes the first n bits. Find the interesting octet, the one the mask cuts
through, and use **block size = 256 − mask octet value**. A /26 mask is 255.255.255.192,
so the block size in the last octet is 256 − 192 = 64, and blocks start at 0, 64, 128, 192.

Three worked splits:

- **10.0.0.0/24 into four equal subnets.** Two more bits, so /26, block 64: 10.0.0.0/26,
  .64/26, .128/26, .192/26. Each has 64 addresses, 62 usable on a classic LAN.
- **172.16.0.0/16 into eight.** Three more bits give /19. The mask cuts the third octet
  (224), so the block size is 256 − 224 = 32: 172.16.0.0/19, 172.16.32.0/19, ...,
  172.16.224.0/19.
- **192.168.10.0/24 unequal, 100 + 50 + 20 hosts.** Largest first: 100 hosts needs /25
  (126 usable) at .0; 50 needs /26 (62) at .128; 20 needs /27 (30) at .192. Allocating
  largest first keeps blocks aligned and leaves .224/27 free.

**Summarization** is the same arithmetic in reverse. 192.168.4.0/24 through
192.168.7.0/24 are four consecutive blocks starting on a multiple of 4 in the third
octet, so they collapse to 192.168.4.0/22. Four blocks starting at 5 would not: the
start must be aligned to the group size.

**Containment test:** is 172.16.35.200 in 172.16.32.0/21? The mask cuts the third octet,
block size 8, so the block containing 35 starts at 32. Yes. The test is: round the
interesting octet down to a multiple of the block size and compare.

**Longest-prefix match (LPM)** picks, among all routes that contain the destination, the
one with the longest prefix, no matter in what order they were added or which is
"preferred". With 10.0.0.0/8, 10.2.0.0/16 and 10.2.2.0/24 all present, 10.2.2.10 uses
the /24, 10.2.7.1 uses the /16. A default route is the /0 that everything contains.
Day 2's Fault B is a /25 beating the default.

**Private and special ranges.** RFC 1918: 10.0.0.0/8, 172.16.0.0/12 (172.16 to 172.31),
192.168.0.0/16. 100.64.0.0/10 is the shared address space for carrier-grade NAT (CGNAT):
not private in the RFC 1918 sense, not routable on the internet, and a common source of
overlaps when it appears on a customer's carrier link. 169.254.0.0/16 is link-local and
127.0.0.0/8 is loopback.

### What a router does with every packet

1. **Look up** the destination in the forwarding table (longest prefix wins).
2. **Decrement the TTL**, recompute the checksum. If TTL hit 0, drop and send ICMP 11.
3. **Resolve the next hop** at layer 2: ARP (or NDP) for the `via` address if the route
   has one, or for the destination itself on a connected route.
4. **Check the outgoing MTU.** If the packet is larger and DF is set, drop it and send
   ICMP 3/4. If DF is clear, fragment it.
5. **Rewrite the Ethernet header** (new source and destination MAC) and send. The IP
   source and destination do not change.

A **connected** route appears when you add an address to an interface: `10.2.1.1/24` on
`eth1` creates `10.2.1.0/24 dev eth1`, meaning "deliver directly, ARP for the destination".
A **static** route has a `via`: "send to that router instead". The `via` address must
itself be reachable on a connected route, or step 3 fails. That is Fault B: `via 10.2.1.99`
is on-link but nothing owns it, so the neighbour entry goes FAILED and the packet is
never sent.

### ICMP and traceroute

| Type | Code | Meaning |
|---|---|---|
| 8 / 0 | 0 | Echo request / echo reply (ping). |
| 3 | 0 / 1 | Network / host unreachable (no route; or ARP failed). |
| 3 | 3 | Port unreachable (UDP to a closed port: the host answers). |
| 3 | 4 | **Fragmentation needed and DF set.** Carries the next-hop MTU. |
| 3 | 13 | Administratively prohibited (a filter said no). |
| 11 | 0 | TTL exceeded in transit. |

**Traceroute** sends probes with TTL 1, 2, 3, ... The router that takes TTL to 0 answers
with type 11 from its own address, which names that hop. The last probe reaches the
destination, which answers with type 3 code 3 (UDP probes) or an echo reply (ICMP
probes). A `* * *` line means no answer arrived for that TTL: the router does not send
ICMP 11, rate-limits it, or a filter drops it (or the reply). A `* * *` is not proof the
hop is broken. Traffic can pass through a router that never answers; look at whether the
**later** hops respond.

### Fragmentation, MTU, MSS, and path MTU discovery

**MTU** is the largest IP packet a link carries (1500 on Ethernet). A router that must
forward a larger packet either fragments it (IPv4, DF clear) or drops it and tells the
sender (IPv4 with DF set, and always in IPv6). Fragmenting is costly (the receiver must
reassemble, and losing one fragment loses the packet), so modern TCP sets DF on every
segment and relies on **path MTU discovery** (RFC 1191 for IPv4, RFC 8201 for IPv6):

1. Send full-size packets with DF set.
2. A router that cannot forward one returns ICMP 3/4 (ICMPv6 type 2) with the next-hop MTU.
3. The sender lowers its path MTU for that destination and resends smaller segments.

The sender remembers the discovered MTU per destination for 10 minutes
(`net.ipv4.route.mtu_expires = 600` seconds on Linux). That cache is why a black hole can
appear and disappear: a host that learned 1400 earlier sends small segments and works,
and the same path fails again after the entry expires or on a host that never learned it.

**MSS** is the TCP payload limit, announced in the SYN: MTU minus 20 (IP) minus 20 (TCP)
= 1460 on a 1500 link, or 1440 over IPv6. MSS is negotiated once from the endpoint MTUs
and knows nothing about links in the middle. That is why PMTUD is needed at all.

**The black hole.** A firewall that drops ICMP 3/4 removes step 2. The sender keeps
retransmitting segments that never fit. Anything smaller than the bottleneck (SYN, small
requests, pings, health checks) works, so the path looks healthy. **MSS clamping** is the
band-aid: the device at the narrow link rewrites the MSS in SYN packets so neither end
ever sends something too big (`1400 - 40 = 1360`). It works without ICMP, and breaks
for traffic that is not TCP.

### IPv6 essentials

- **Link-local** `fe80::/10`: every interface has one, valid on one link only, and the
  basis for neighbour discovery and routers' next hops.
- **SLAAC:** a host builds its own global address from a router's advertised /64 prefix
  plus an interface identifier (EUI-64 or random).
- **NDP** replaces ARP and runs over ICMPv6: **NS** (135) asks "who has this address",
  **NA** (136) answers, **RS** (133) asks for routers, **RA** (134) announces prefixes and
  the default gateway. NS goes to the solicited-node multicast address `ff02::1:ffXX:XXXX`
  (last 24 bits of the target), so only a few hosts hear it.
- **ICMPv6 is mandatory.** Filtering it by habit from IPv4 breaks NDP and PMTUD.

## Prove it on the wire

Run `bash labs/day02/topo.sh up` first. Every command is in `labs/day02/README.md`
("Prove it"). The claims to confirm:

- **`ip -n h1 route get 10.2.2.10`** prints `via 10.2.1.1`. Ask three destinations
  (`10.2.2.10`, `10.2.1.1`, `8.8.8.8`) and name the matching route for each: on-link,
  on-link, default.
- **Traceroute.** Capture `tcpdump -vni eth0 'icmp or udp'` in h1 during
  `traceroute -n 10.2.2.10`. Find the three UDP probes (`ttl 1`, `ttl 2`, `ttl 3`), the two
  `time exceeded in-transit` replies from `10.2.1.1` and `10.2.12.2`, and the final
  `udp port ... unreachable`.
- **Header on the wire.** `tcpdump -vvx` of one ping starts `4500 0054`. Decode: version 4,
  IHL 5, total length 84; then ID, then `4000` (DF, offset 0); TTL `40` (64), protocol `01`.
- **The 1400 limit.** `ping -M do -s 1372` passes; `-s 1373` returns `From 10.2.1.1 ...
  Frag needed ... mtu = 1400`. The number is 1400 minus 20 minus 8.
- **`tracepath -n 10.2.2.10`** starts at `pmtu 1500` and reports `pmtu 1400` on the hop 10.2.1.1 line; it ends with `Resume: pmtu 1400 hops 3 back 3`.
- **NDP.** After `ip -n h1 neigh flush dev eth0`, `ping -6` produces an NS and an NA.
- **MTU tiers (AWS emulation).** Set h1 `eth0` and r1 `eth1` to 9001 <!-- fact-checked 2026-10-05 -->, and `tracepath` shows
  `pmtu 9001` first, then `pmtu 1400` at the r1–r2 link, while `ping -M do -s 8973 10.2.1.1`
  succeeds. Details are in the README; `topo.sh up` restores it.

The point of every command is the same: read the header or the table, not the tool's
summary of it.

## Lab

`labs/day02/` builds `h1 - r1 = r2 - h2`, two subnets joined by a /30, with the r1–r2
link at MTU 1400 on both ends. The 1400 sits between two routers on purpose: a veth
silently drops an oversized frame at the receiving end with no ICMP, and an MTU on a host
would shrink its MSS so PMTUD would never run. h2 serves a 200 KB file over HTTP.

1. `bash labs/day02/topo.sh up`, then the Prove section in the README.
2. `bash labs/day02/break.sh` prints one symptom: pings to h2 fail, and earlier a
   download hung. Two faults are in.
3. Write the evidence chain in `journal.md` before fixing: what `ip route get` says, what
   the neighbour table says, what two captures on r2 show, what the rules say.
4. Fix with `SOLUTION.md` as the check, then `bash labs/day02/verify.sh` until it prints
   `PASS`. A partial repair still fails, each check on its own line.

## Where AWS hides this

**Name the construct: "the VPC router in AWS is the `via` hop of a routing table on the
wire."**

- **The VPC router is an address, not a box.** In every subnet, the router answers at
  the base address plus 1 <!-- fact-checked 2026-10-05 --> (10.0.1.1 in 10.0.1.0/24), and the DNS resolver at base plus 2. Five addresses per subnet are reserved and unusable: network, VPC
  router, DNS, one reserved for future use, and broadcast <!-- fact-checked 2026-10-05 -->. A /28
  subnet therefore gives 11 usable hosts. VPC CIDR blocks run from /16 to /28
  <!-- fact-checked 2026-10-05 -->. This is your lab's `via 10.2.1.1`.
- **Route tables use longest-prefix match.** The `local` route for the VPC CIDR is always
  present and cannot be overridden by a less specific route (a `0.0.0.0/0` to a NAT
  gateway does not capture VPC-internal traffic). A more specific route can be added for
  middlebox insertion, such as a /24 pointing at a firewall appliance's ENI inside the
  VPC. That is the same mechanism as Fault B, used on purpose.
- **MTU is tiered.** 9001 bytes inside a VPC, 1500 through an internet gateway and over
  a VPN, 8500 over a transit gateway and over inter-Region peering <!-- fact-checked 2026-10-05 -->.
  Instances send full 9001-byte packets inside the VPC, so the first time one crosses an
  IGW or VPN boundary, PMTUD has to work. ICMP 3/4 must be allowed in security groups
  and NACLs, or you rebuild Fault A. Steps 4 and 7 of the Prove section show the tiers.
- **Egress-only IGW; no NAT for IPv6.** IPv6 addresses in a VPC are globally unique, so
  there is no NAT66 in AWS. An **egress-only internet gateway** gives the "outbound only"
  behaviour that NAT gave for IPv4: it is stateful, allows replies to outbound flows and
  refuses inbound-initiated ones.
- **Lab it on AWS.** The sibling course `aws_network_components` builds this for real:
  Day 1 (VPC, subnets, route tables) and Day 2 (gateways and NAT). Read them to see the
  `local` route and the +1 router in the console.

Mistake 3 from `STRATEGY.md` applies here: when you write "IGW", write what it does to a
packet. Fill in "X in AWS is Y on the wire" before moving on.

## Exercises

These are theory drills. They do not depend on the lab.

1. **Subnet math: usable hosts.** How many usable hosts are in 10.2.12.0/30 on a classic
   LAN, and how many in an AWS /28 subnet?
   **Hint:** total addresses is 2^(32 − n); subtract the reserved ones.
   **Solution sketch:** a /30 has 4 addresses, minus network and broadcast leaves 2 (the
   r1–r2 link uses both). An AWS /28 has 16, minus 5 reserved, leaves 11.

2. **Subnet math: split.** Split 10.20.0.0/16 into four equal subnets, and list them.
   **Hint:** how many extra bits give four blocks, and what is the block size in the third
   octet?
   **Solution sketch:** two bits, /18, mask 192, block 256 − 192 = 64: 10.20.0.0/18,
   10.20.64.0/18, 10.20.128.0/18, 10.20.192.0/18.

3. **Subnet math: containment.** Is 172.16.35.200 in 172.16.32.0/21? Is 172.16.40.1?
   **Hint:** the mask cuts the third octet; find the block size and the block start.
   **Solution sketch:** /21 means mask 248, block 8, so 172.16.32.0/21 covers third
   octets 32 to 39. 35 is inside; 40 is not (it starts the next block).

4. **Subnet math: summarize.** Summarize 192.168.4.0/24, 192.168.5.0/24, 192.168.6.0/24,
   192.168.7.0/24 into one route, then say whether 192.168.5.0/24 through 192.168.8.0/24
   can be one route.
   **Hint:** the group must start on a multiple of its own size.
   **Solution sketch:** 4 to 7 is four blocks starting at a multiple of 4: 192.168.4.0/22.
   5 to 8 starts at 5, which is not aligned.
   The third octets 5 (0000 0101) and 8 (0000 1000) share only their top 4 bits, so
   the smallest single prefix is 192.168.0.0/20 (0 to 15), far wider than the four
   blocks. Use several routes instead.

5. **Subnet math: sizing.** What is the smallest prefix for a subnet of 500 instances in
   AWS, and how many addresses are left over?
   **Hint:** add 5 reserved addresses before choosing the power of two.
   **Solution sketch:** 505 addresses needed. /23 has 512, and 512 − 5 = 507 usable, so
   /23 with 7 spare (507 − 500). Do not subtract the reserved
   addresses twice. /24 (251 usable) is too small.

6. **Longest-prefix match.** The table is: `0.0.0.0/0` A, `10.0.0.0/8` B, `10.2.0.0/16` C,
   `10.2.2.0/24` D, `10.2.2.0/25` E, `10.2.2.128/26` F. Where do 10.2.2.10, 10.2.2.200,
   10.2.7.1, 10.9.9.9 and 11.0.0.1 go? Where does 10.2.2.10 go if E is deleted?
   **Hint:** list the routes that contain the address and take the longest.
   **Solution sketch:** 10.2.2.10 is in /25 E (0–127). 10.2.2.200 is outside F (128–191)
   but inside D, so D. 10.2.7.1 matches C, 10.9.9.9 matches B, 11.0.0.1 only the default A.
   Without E, 10.2.2.10 falls back to D.

7. **Decode a hex IPv4 header.** Decode `4500 003c a1b2 4000 3f11 82e7 0a02 020a 0a02 010a`.
   Give every field, and say what you can infer about where the packet has been.
   **Hint:** every group is 16 bits; flags and offset share `4000`.
   **Solution sketch:** version 4, IHL 5, DSCP/ECN 0, length 0x3c = 60, ID 0xa1b2, flags
   `010` (DF set, MF clear), offset 0, TTL 0x3f = 63, protocol 0x11 = UDP, checksum
   0x82e7, source 10.2.2.10, destination 10.2.1.10. TTL 63 suggests a sender TTL of 64
   and one router crossed so far. A header checksum can be checked by summing all ten
   words with carry: the result is 0xffff.

8. **MSS for a 1400 path.** What MSS should you clamp to for IPv4 and for IPv6 over a path
   with MTU 1400? What if TCP timestamps are on?
   **Hint:** MSS = MTU − IP header − TCP header.
   **Solution sketch:** IPv4: 1400 − 20 − 20 = 1360. IPv6: 1400 − 40 − 20 = 1340. With
   timestamps the TCP header is 32 bytes, so each segment carries 12 fewer data bytes, but the clamp
   value in the SYN stays 1360 because the sender subtracts its own options from it.

9. **Explain a traceroute.** From h1: hop 1 `10.2.1.1`, hop 2 `* * *`, hop 3 `* * *`, hop 4
   `10.8.0.5`, hop 5 the destination. Is hop 2 broken?
   **Hint:** can a packet cross a router whose ICMP 11 you never see?
   **Solution sketch:** no. The probes at TTL 2 and 3 were forwarded (hops 4 and 5 answered
   with larger TTLs), so those routers forward fine. They do not send time-exceeded, or
   a filter drops it or the return. Look at the end of the path, not the middle.

10. **Plan a VPC CIDR scheme.** Four accounts, three tiers (public, app, data), two AZs
    each: 24 subnets. Pick ranges that never overlap, leave room to grow, and stay clear
    of 100.64.0.0/10.
    **Hint:** give each account a /16 and each tier-AZ pair a fixed slot inside it.
    **Solution sketch:** accounts 10.10.0.0/16, 10.11.0.0/16, 10.12.0.0/16, 10.13.0.0/16
    (keep 10.0.0.0/16 for on-prem or shared services). Per account use /20 slots (16 fit in a
    /16): public in 10.X.0.0/20 and 10.X.16.0/20 (AZ-a, AZ-b), app in .32.0/20 and
    .48.0/20, data in .64.0/20 and .80.0/20, leaving .96 onward free. A /20 is generous; /22 slots would also work.
    Non-overlap is what a transit gateway needs.

11. **Diagnose the hang.** A service over a VPN passes health checks, but responses
    larger than about 1.4 KB hang. Name the cause, one proof, and three fixes.
    **Hint:** what is smaller than the packets, and who should have said so?
    **Solution sketch:** a PMTUD black hole. Proof: `ping -M do -s 1372` works and `-s 1472`
    gets no reply and no frag-needed; capture at the narrow link shows full-size
    segments in, none out. Fixes: allow ICMP 3/4 (v6: type 2) end to end; clamp the MSS
    at the tunnel; lower the MTU on the sender's interface or the route.

12. **IPv6 addresses.** Give the link-local address of an interface with MAC
    `02:00:00:00:01:01` (EUI-64), and the solicited-node multicast address a neighbour
    sends an NS to.
    **Hint:** insert `ff:fe` in the middle of the MAC and flip the universal/local bit (0x02) of the first byte.
    **Solution sketch:** `02` with the 0x02 bit flipped becomes `00`, so the identifier is
    `0000:00ff:fe00:0101`, and the address is `fe80::ff:fe00:101`. The solicited-node
    address is `ff02::1:ff` plus the last 24 bits: `ff02::1:ff00:101`.

## Anti-patterns / Common mistakes

- **Treating AWS networking as magic separate from TCP/IP (mistake 3).** "The VPC router"
  and "the IGW" are forwarding behaviour you rebuilt today with `ip route`: a base+1
  next hop, longest-prefix match, a MTU that changes at the edge. If you cannot write
  the "Y on the wire" half of the sentence, you have not learned the concept.
- **Blocking all ICMP for security.** This reflex from the 1990s breaks path MTU
  discovery, so large transfers stall while small ones work, which is the worst kind of
  failure to diagnose. Allow ICMP 3/4 (and v6 types 2, 128, 129, and NDP). Filter what
  you must by type and code, not by protocol.
- **Reading `* * *` as a dead hop.** It means no answer, which is not the same as no
  forwarding.
- **Confusing MTU and MSS.** MTU is a link limit in IP bytes; MSS is a TCP payload number
  agreed once by two endpoints. Neither knows what is in the middle.
- **Assuming the route you added is the route used.** `ip route get` shows what the kernel
  will use. A longer prefix you forgot about wins silently.

## Teardown

See `labs/day02/teardown.md`: `bash labs/day02/topo.sh down`, then `ip netns list` shows
nothing. If you are stopping for the day, run `bash labs/verify-teardown.sh` on the Mac.
