# Day 6 — Overlays, IPsec and names

**Truth of the day:** encapsulation costs bytes, and a name is an answer that depends on who asks
**Budget:** 3 h — 45 m theory, 1 h 45 m lab (guided proof, GENEVE and resolver
mapping, break and diagnose), 30 m exercises

**At a glance — how to work through this day:**
1. Read "Why this matters", then draw the VXLAN frame and the DNS walk from memory
   ("Draw it first"). Correct the drawing against the page.
2. Read "Core concepts".
3. Do the lab in `labs/day06/`: `topo.sh up`, the proof walkthrough, `geneve.sh`, then
   `break.sh`, `journal.md`, `verify.sh`.
4. Read "Where AWS hides this", then do the exercises whenever you like.

## Why this matters

A service in the VPC calls `db.onprem.corp` and gets the public address of a load
balancer instead of the private address of the database. Meanwhile the team's tunnel to
the data center looks healthy: pings pass, small API calls pass, and any response
larger than a screenful of JSON hangs. Two reports, one afternoon, no obvious link.

The link is that both are about what happens between "I have a packet or a question"
and "the thing on the other side sees it". A tunnel wraps your packet in another one,
and the wrapper takes bytes the path may not have. A resolver answers from whichever
view it holds, and the view depends on which server your client was pointed at. This day
rebuilds both mechanisms from the wire: the overlay encapsulations and their byte
cost, IPsec, and the DNS resolution path. Then you reproduce both faults in a box.

## Draw it first

Draw these two on a blank page before you read on, then compare.

The VXLAN-encapsulated frame, with the byte count of each layer:

```
+----------------+----------+--------+--------------+-------------------------------+
| Outer Ethernet | Outer IP | UDP    | VXLAN header | Inner Ethernet frame          |
| 14 (underlay)  | 20       | 8      | 8            | 14 + inner IP packet (<=1450) |
|                | VTEP->VTEP | dst 4789 | flags, VNI 100 | the frame the VM sent     |
+----------------+----------+--------+--------------+-------------------------------+
                 |<-- 50 bytes of tax against the underlay's IP MTU, counting ---->|
                 |    the inner Ethernet header: 20 + 8 + 8 + 14                   |
```

The overhead against the underlay's IP MTU is 50 bytes: 14 (inner Ethernet) + 20 + 8 + 8.
The outer Ethernet header is the underlay's own and does not count against its MTU.

The DNS resolution walk for `app.example.com`, with every question marked:

```
 stub (your app)  --1 A app.example.com?-->  recursive resolver (cache, forwarders)
                                                 |  2 . NS?                  -> root
                                                 |  3 com. NS?               -> TLD (.com)
                                                 |  4 example.com. NS?       -> authoritative
                                                 |  5 app.example.com. A?    -> authoritative
 stub  <--6 answer, TTL 60--  recursive resolver (stores it: answer for TTL seconds)
```

Steps 2 to 5 are skipped when the resolver already holds the answer, or when a
forwarding rule sends the whole name somewhere else.

## Core concepts

### Tunnels are encapsulation, and every layer has a tax

A tunnel puts a packet inside another packet. The outer packet crosses a network that
does not need to understand the inner one. The cost is the extra header, taken from the
space the path allows.

| Encapsulation | Overhead (bytes) | Inner MTU on a 1500 path |
|---|---|---|
| IP-in-IP | 20 | 1480 |
| GRE | 24 (20 outer IP + 4 GRE) | 1476 |
| VXLAN over IPv4 | 50 (14 + 20 + 8 + 8) | 1450 |
| GENEVE over IPv4 | 50 + options (8-byte base header, TLV options in 4-byte steps) | 1450 minus the options |
| IPsec ESP, tunnel mode | about 50 to 75 for common ciphers, by cipher and padding | about 1425 to 1450 |

The ESP range comes from its parts: outer IP 20, ESP header 8 (SPI and sequence),
an IV of 8 or 16 bytes, padding of 0 to 15 bytes to the cipher block size, a 2-byte
trailer (pad length, next header), and an integrity tag of 12 to 32 bytes. Authenticated
ciphers such as AES-GCM sit at the lower end, CBC with a long MAC at the upper end.
The overheads stack: VXLAN inside an ESP tunnel pays both, and the VXLAN packet carries
its own outer IP header. The lab's ESP demo uses transport mode, which has no outer IP
header: about 36 bytes with AES-GCM, as you can measure in the capture.

The **MTU rule** that follows: the inner MTU is the path MTU minus the tax, and it
must be set on the overlay device. If it is set too high, the inner sender builds
packets the encapsulated form of which cannot fit. With the DF bit set, they vanish;
with it clear, the outer packet fragments and the receiver must reassemble, and
fragments are what firewalls and ECMP hashing handle worst.

### The encapsulations you will meet

- **IP-in-IP** and **GRE** are the plain forms: an outer IP header (protocol 4 or 47)
  and, for GRE, a 4-byte header with optional key, checksum and sequence. They are
  stateless and have no inherent encryption. Because they are IP protocols, not UDP,
  they carry no port entropy for ECMP.
- **VXLAN** (RFC 7348) carries Ethernet frames over UDP destination port **4789**. The
  8-byte header holds a flags byte and a 24-bit **VNI** (VXLAN Network Identifier),
  so about 16 million segments. The endpoint that wraps and unwraps is a **VTEP**.
  The UDP source port is a hash of the inner flow, so the underlay's ECMP spreads
  tunnels across paths. To find which VTEP holds a MAC, a plain VXLAN **floods and
  learns** like a switch (BUM traffic goes to every VTEP). The scalable alternative is
  **EVPN**, which carries MAC and IP routes in BGP, so VTEPs learn without flooding.
  This lab uses a static `remote` and flood-and-learn.
- **GENEVE** (RFC 8926) is the same idea with a variable header: UDP port **6081**,
  a 24-bit VNI, and **TLV options** that carry metadata with the packet (a tenant, a
  policy decision, a flow cookie). That metadata channel is why services that need to
  steer traffic through appliances use it.

### IPsec in one page

IPsec protects IP packets between two gateways or hosts. The key exchange and the data
path are separate protocols.

- **IKEv2** negotiates and authenticates. `IKE_SA_INIT` is the first exchange (two
  messages): the peers agree on algorithms, run a Diffie-Hellman exchange, and swap
  nonces. After it, both hold keys that protect the rest. `IKE_AUTH` is the second:
  encrypted under that key, the peers prove identity (certificates or a pre-shared key)
  and create the first **child SA**. More child SAs come from `CREATE_CHILD_SA`, and a
  rekey creates a new SA before the old one is deleted. IKE runs on UDP 500.
- **ESP** (IP protocol 50) is the data path. The header is the **SPI** (a 32-bit label
  that tells the receiver which SA decrypts this packet) and a **sequence number**
  (replay protection), followed by the encrypted payload and an integrity tag. Child
  SAs are one-way: a tunnel is two SAs, one per direction, each with its own SPI.
- **Tunnel mode** wraps the whole original IP packet in a new outer IP header, so the
  inner addresses are hidden. It is what gateways and VPNs use. **Transport mode**
  keeps the original header and protects only the payload. It is for host-to-host.
- **NAT-T:** a NAT between the peers cannot rewrite ESP, which has no ports. When the
  peers detect a NAT in the IKE exchange, they move to **UDP 4500** and wrap ESP in UDP.
  That adds 8 bytes.
- **DPD** (dead peer detection) is a periodic empty IKE message. If the peer does not
  answer, the SA is torn down so the failure is noticed.

### DNS in the depth you need

- **Recursive vs authoritative.** An authoritative server holds the zone data and
  answers only for it. A recursive resolver walks the tree (root, TLD, authoritative)
  on behalf of its clients and caches. A stub is the resolver library in your process.
- **Forwarding and conditional forwarding.** A resolver may hand a query to another
  resolver instead of walking. A *conditional* forward does that only for one
  domain: "ask this server about `onprem.corp`, walk for everything else".
- **Caching and TTL.** Each record carries a TTL. A cache serves it with a falling TTL
  and fetches again at zero. The TTL is the only knob: lowering it before a change is
  how you shorten the stale window.
- **Negative caching.** An NXDOMAIN or empty answer is cached too. Its lifetime is
  the smaller of the SOA record's TTL and its **minimum** field (RFC 2308). Creating a
  record does not help clients that cached the absence until that timer runs out.
- **Split horizon.** One name, different answers by client: a private view returns the
  internal address, the public view the external one. The cost is that "which view am I
  asking?" becomes part of every diagnosis.
- **`search` and `ndots`.** The stub library decides how to try a short name. A name
  with at least `ndots` dots is tried as-is first, otherwise the `search` suffixes
  are tried first. Kubernetes sets `ndots:5`, so `api.example.com` (two dots) runs
  through every search domain before the real name. A trailing dot (`api.`) skips it all.
- **Size.** Classic DNS over UDP is limited to 512 bytes. **EDNS0** lets the client
  advertise a larger buffer. If an answer does not fit, the server sets the **TC** bit
  and the client retries over **TCP**. A 4,096-byte buffer makes UDP answers fragment;
  a value near 1232 avoids fragmentation, so large buffers are a MTU problem too.

### L3 without an overlay: containers and pods on AWS

Not every cluster adds a tunnel. Two AWS designs give each workload a real VPC address:

- **ECS `awsvpc`** gives each task its own ENI, so security groups and flow logs see
  the task. The cost is ENI count per instance. **ENI trunking** <!-- fact-checked 2026-10-05 --> raises the number of
  task ENIs a supported instance can hold.
- **EKS VPC CNI** assigns pods VPC IP addresses from the node's ENIs. The `ipamd` daemon
  keeps a **warm pool** <!-- fact-checked 2026-10-05 --> of spare addresses so a pod starts without an API call.
  **Prefix delegation** <!-- fact-checked 2026-10-05 --> assigns a /28 (16 addresses) per ENI slot instead of one
  address, which multiplies pod capacity per node.
  The failure mode is **IP exhaustion**: pods stuck in `ContainerCreating`, with
  `failed to assign an IP address to container` in the CNI log, while the subnet shows
  few free addresses. No overlay means no MTU tax, and also no private address space
  of its own.

## Prove it on the wire

The full walkthrough is in `labs/day06/README.md`. The lab builds `va` and `vb`
(VXLAN VNI 100 on 10.6.0.0/24), and five namespaces on a bridge for DNS.

1. **The VXLAN frame.** `tcpdump -ni u0 -w /run/netlab/vx.pcap udp port 4789` in `va`
   during a ping, then `tshark -r ... -d udp.port==4789,vxlan -V`. Identify the five
   layers and count the 50 bytes.
2. **ESP** (optional if short on time). Add static `ip xfrm state` and `policy` between `va` and `vb`, ping, and
   capture `esp`. The SPI and a counting sequence number are readable, the payload is
   not. The ESP packet is longer than the ICMP packet it carries; measure by how
   much, and compare with the table above.
3. **Split horizon.** `dig +norecurse` against `10.6.10.53` and `10.6.10.54` returns two
   answers for one name.
4. **Forwarding.** `dig db.onprem.corp` from `cli` goes `cli -> dnsi -> odns`. The
   reverse, `dig @10.6.10.60 app.corp.internal`, goes `odns -> dnsi`.
5. **TTL.** Query `odns` for a forwarded name three times, five seconds apart. The TTL
   counts down because `odns` caches. An NXDOMAIN shows the SOA and its TTL, which
   bounds the negative cache.
6. **`ndots`.** `dig +search +domain=corp.internal +ndots=5 +showsearch app` shows the
   order of tries. Count the queries in a `udp port 53` capture.
7. **GENEVE.** `geneve.sh up`, capture on the underlay, and find the unchanged inner
   `10.61.0.10 -> 10.62.0.10` packet inside outer UDP 6081.

## Lab

See `labs/day06/`. The goal: prove the VXLAN and ESP framing and the DNS paths, then
diagnose two independent faults (an overlay whose MTU equals the underlay's, and a
client that asks the wrong view of a split-horizon name) from captures, before you read
`SOLUTION.md`. Success signal: `bash labs/day06/verify.sh` exits `0` and prints
`PASS: day 06 is healthy.`

## Where AWS hides this

Each line is "X in AWS is Y on the wire".

- **Site-to-Site VPN is IPsec, twice.** Each VPN connection has two tunnels
  <!-- fact-checked 2026-10-05 -->, each an IKE session with its own child SAs, ending in two
  different AWS endpoints so one can be maintained while the other carries traffic. What you
  configure on the customer gateway is the Day 6 chain: IKEv2, a DH group, an ESP
  cipher, and NAT-T on UDP 4500 if a NAT sits in front. The tunnel's MTU is the
  Exercise 1 arithmetic. See `../aws_network_components/` Day 6 for the VPN build.
- **Gateway Load Balancer is GENEVE on UDP 6081.** The GWLB sends traffic to the
  appliance fleet inside GENEVE <!-- fact-checked 2026-10-05 -->, keeping the **original packet
  unchanged**: same source, same destination, so the appliance sees real addresses.
  A flow stays on one appliance by 5-tuple stickiness (the default; 3-tuple and 2-tuple are also available) <!-- fact-checked 2026-10-05 -->. That is
  `geneve.sh`: `gwlb` keeps the packet, adds GENEVE, and the appliance hairpins it back.
- **Route 53 Resolver is the VPC `+2` resolver.** Every VPC has a resolver at the base
  of the VPC range plus two <!-- fact-checked 2026-10-05 -->. A **private hosted zone** is the
  split-horizon view: names that exist only inside the associated VPCs. An
  **outbound endpoint** with a **forwarding rule** is `forward-zone` in `dnsi` (it
  sends `onprem.corp` to the data center). An **inbound endpoint** is the address
  on-prem DNS forwards to (`dnsi`'s listening address). The lab's `odns` and `dnsi` are
  that pair. Endpoints are ENIs in your subnets, so they have a security group and
  an address you pay for. See `../aws_network_components/` Day 3 for the real setup.
- **Route 53 Resolver DNS Firewall** filters DNS queries that leave the VPC by domain
  list. In the lab it is a `local-zone` with `refuse` or `always_nxdomain`.
- **EKS and ECS are the "no overlay" case.** The VPC CNI gives a pod a VPC address,
  so a subnet's usable address count is the pod budget. A subnet reserves 5 addresses
  <!-- fact-checked 2026-10-05 -->. An `m5.large`-class node with 3 ENIs and 10 IPv4 addresses each
  allows `3 * (10 - 1) + 2 = 29` pods <!-- fact-checked 2026-10-05 --> without prefix delegation.
- **Certificates and DNS meet at CAA.** A `CAA` record says which authority may
  issue for a name. For that and the rest of the TLS story, see
  `../../network_certificates_and_more/`.

**Lab it locally:** the resolver forwarding in the main topology and `geneve.sh`.
**Lab it on AWS:** the sibling `../aws_network_components/` Day 3 (Resolver) and
Day 6 (VPN).

## Exercises

1. **MTU of four stacks.** The path MTU is 1500. Give the inner MTU for: (a) GRE;
   (b) VXLAN over IPv4; (c) GENEVE with 16 bytes of options; (d) VXLAN carried
   inside an ESP tunnel using AES-GCM (assume 20 + 8 + 8 + 2 + 16 bytes of ESP cost
   and up to 3 bytes of padding). — **Hint:** subtract the tax; for (d) the VXLAN
   packet, with its own outer IP header, is the ESP payload, so subtract ESP first,
   then the VXLAN tax of 50. — **Solution sketch:** (a) 1500 - 24 = 1476. (b) 1500 - 50 =
   1450. (c) 1450 - 16 = 1434. (d) ESP leaves 1500 - 54 = 1446 (1443 with worst-case
   padding) for the VXLAN outer IP packet. Subtract its 20 + 8 + 8 + 14 = 50 and the
   overlay MTU is about 1396 (1393 worst case), so set 1380. Setting 1400 would black-hole.
2. **Decode a VXLAN capture.** `tshark -V` prints: outer IP `10.6.0.1 -> 10.6.0.2`, total
   length 1550, DF set; UDP dst 4789; VXLAN flags `0x08`, VNI 100; inner Ethernet, inner
   IP `172.16.0.1 -> 172.16.0.2`, total length 1500, ICMP echo request. The ping
   gets no reply. Say why. — **Hint:** add the 50 bytes and compare with the underlay.
   — **Solution sketch:** the inner packet is 1500, so the outer is 1550 and has DF
   set. It cannot fit through a 1500-byte link and cannot fragment. It is dropped
   at the first hop that notices. The fix is overlay MTU 1450, not underlay changes.
3. **Split-horizon design.** `db.example.com` must resolve to `10.0.5.9` for VPC clients
   and for on-prem clients over the VPN, but to `198.51.100.7` for the internet. Place
   the zones, the forwarding and the endpoints. — **Hint:** two views of one name,
   and on-prem needs a way in. — **Solution sketch:** a public hosted zone holds
   `198.51.100.7`. A private hosted zone of the same name, associated with the VPC,
   holds `10.0.5.9`; VPC clients reach it through the `+2` resolver. On-prem DNS
   conditionally forwards `example.com` to the inbound endpoint's addresses over the
   VPN. If on-prem names must be reachable from the VPC, add an outbound endpoint
   and a rule. Watch the name collision: a private zone hides public names it
   shadows.
4. **The `ndots` puzzle.** A pod has `search ns.svc.cluster.local svc.cluster.local
   cluster.local ec2.internal` and `ndots:5`. The only name that exists is `api` as
   a plain name in the root-level zone the upstream serves. How many DNS queries does
   `curl api` send before it gets an answer, if the stub asks for both A and AAAA? How
   many for `api.` (trailing dot)? — **Hint:** `api` has zero dots, fewer than 5, so
   each suffix is tried first. — **Solution sketch:** four suffixes, each A and AAAA,
   return NXDOMAIN: eight queries. Then `api.` itself: two more, ten in total. With
   the trailing dot the stub asks only `api.`: two queries. Lower `ndots` or end names
   in a dot.
5. **When EKS runs out of IPs.** A /24 subnet holds 12 nodes of the `m5.large` class.
   Pods stay in `ContainerCreating`. Explain, and give the two fixes. — **Hint:**
   count the addresses the nodes claim, including the warm pool. **Solution sketch:** a /24 has 256 addresses and AWS reserves 5. Each node's ENIs claim
   addresses ahead of use (the warm pool), so 12 nodes of up to 30 addresses each can
   hold all 251. Fixes: prefix delegation (a /28 per slot, if the subnet has
   contiguous space) or custom networking, which puts pods on secondary-CIDR subnets
   (for example `100.64.0.0/10`) separate from the nodes'.
6. **TTL and negative-cache timing.** A record has TTL 60. A cache fetched it at
   t=0. (a) What TTL does a client see at t=25 and at t=61? (b) A name returned NXDOMAIN
   at t=0 with an SOA TTL of 3600 and minimum 30. You create the record at t=10. When
   can a client resolve it through that cache? — **Hint:** negative lifetime is the
   smaller of SOA TTL and minimum. — **Solution sketch:** (a) 35 at t=25. At t=61 the
   entry expired and the cache fetches again, so a new TTL of 60 (or the remainder
   if the upstream also caches). (b) min(3600, 30) = 30, so at t=30. Not at t=10.
7. **IKE and NAT-T.** A capture shows `IKE_SA_INIT` on UDP 500, then `IKE_AUTH` and
   everything after on UDP 4500, and the data packets are UDP 4500 with no bare ESP.
   Explain. — **Hint:** ESP has no ports. — **Solution sketch:** the peers detected a
   NAT during `IKE_SA_INIT` (NAT-detection payloads) and moved to NAT-T: from
   `IKE_AUTH` on, IKE uses UDP 4500 (RFC 7296 section 2.23), and each ESP packet is
   carried inside UDP 4500. `tshark` shows ESP inside UDP. The tunnel pays 8 more bytes.
8. **A large DNS answer.** A server returns 1,800 bytes of records. A client that does
   not support EDNS0 asks over UDP. What happens, and what changes with EDNS0 at 1232?
   — **Hint:** the 512-byte rule and the TC bit. — **Solution sketch:** without
   EDNS0 the answer is cut and TC is set, so the client retries over TCP. With EDNS0
   at 1232 the 1,800-byte answer still does not fit, so TC still triggers TCP, but
   answers under 1232 now fit in UDP without fragmenting. A buffer of 4096 would
   allow a fragmented UDP answer, which a firewall may drop.
9. **Trace the forwarding.** From `cli`, name every hop and cache for
   `dig db.onprem.corp` and for `dig @10.6.10.60 app.corp.internal`. Which AWS
   component is each? — **Hint:** follow the `forward-zone` lines. **Solution sketch:** the first goes `cli -> dnsi (+2 resolver) -> forward rule (outbound
   endpoint) -> odns`, and `dnsi` caches the answer. The second goes `odns -> dnsi
   (inbound endpoint address)`, `dnsi` answers from its private zone, and `odns`
   caches it with the falling TTL.
10. **GWLB stickiness.** Why must the return path of a flow go through the same
    appliance as the forward path, and how does GENEVE's 5-tuple stickiness give you
    that? — **Hint:** a stateful appliance keeps a flow table. **Solution sketch:** the appliance learned the flow from the first packet. A reply that went
    to another appliance would be an unknown flow and be dropped. The GWLB hashes
    the 5-tuple (and treats the reverse tuple as the same flow), so both directions
    hit one appliance, and GENEVE carries the original packet to it unchanged so
    that its policy sees real addresses.

## Anti-patterns / Common mistakes

- **Mistake 8: not knowing which view of a name you are asking.** "It resolves" is not
  an answer; `dig` shows `SERVER:` and the answer section. With split horizon,
  the first diagnostic is which resolver the client really uses
  (`cat /etc/resolv.conf`, the DHCP options, the pod's `dnsPolicy`) and what each view
  returns. Compare `dig @server` for each. The wrong resolver is a config fault, not a
  DNS fault.
- **Raising the MTU on the overlay to match the underlay.** It makes `ip link` look
  consistent and silences the warning, and it creates the black hole Day 6 breaks
  on purpose: the encapsulated packet is 50 bytes larger than the link. Small packets
  work, large ones vanish, and nothing logs. Set the overlay MTU to the underlay minus
  the tax, and verify with a DF ping at the limit and one above it.
- **Trusting `ping` to prove a tunnel.** A 64-byte ping crosses a tunnel that is
  broken for every real payload. Test with `-M do` at the boundary size, and check the
  capture for the outer packet length.
- **Lowering a TTL after the change.** A cache holds the old answer for the old TTL
  and an NXDOMAIN for the SOA minimum. Lower the TTL before the change, by at least
  the old TTL's length, and create records before anything asks for them.

## Teardown

```bash
bash labs/day06/topo.sh down
bash labs/verify-teardown.sh
```

Full checklist in `labs/day06/teardown.md`.
