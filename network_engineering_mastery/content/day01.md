# Day 1 — L2 and the wire

**Truth of the day:** the Ethernet frame, and the two tables that move it: the
neighbour table (IP to MAC) on each host and the forwarding database (MAC to port) on
each switch.
**Budget:** 3 h — 1 h draw and read; 1 h lab; 30 m AWS mapping; 30 m exercises.

## Why this matters

A team built a two-node active/standby service on EC2. The design came from the data
centre: the standby takes the shared IP when the active node dies, then sends a
gratuitous ARP so every neighbour updates its cache. They tested the failover by
stopping the active node, and the standby logged "VIP acquired, GARP sent". Traffic
never moved. The standby was configured correctly and the packet was sent correctly. It
was addressed to a network that does not forward it.

That failure has no log line, because nothing failed on the wire. You can only
diagnose it if you know what ARP is for, who listens, and which part of a VPC answers
instead of the host you expected. <!-- fact-checked 2026-10-05: a gratuitous ARP from an instance does not redirect VPC traffic to it; the VPC mapping service is updated through the EC2 API -->
This day rebuilds that knowledge from the frame up, proves it in a capture, and then
shows where AWS replaces each mechanism with an API call.

## Draw it first

On a blank page, from memory, draw two things before you read further.

1. **An Ethernet II frame.** Every field in order, with its width in bytes. Mark which
   fields the NIC handles for you.
2. **An ARP packet** for IPv4 over Ethernet: every field, its width, and the values in
   a request.

Then compare against the next section. Write what you got wrong in `journal.md`. The
usual misses are the EtherType position, the ARP hardware/protocol length fields and
the all-zero target MAC in a request.

## Core concepts

### Encapsulation is nested headers

Every packet is a stack of headers, each one the payload of the one below it. The
Ethernet header says who gets the frame on this link. The IP header says who gets the
packet across links. The TCP header says which process gets the stream.

```
+----------------------------------------------------------------------+
| Ethernet II  dst MAC | src MAC | EtherType 0x0800                     |
| +------------------------------------------------------------------+ |
| | IPv4  ver/IHL | ... | proto 6 | src IP | dst IP                    | |
| | +--------------------------------------------------------------+ | |
| | | TCP  src port | dst port | seq | ack | flags | window        | | |
| | | +----------------------------------------------------------+ | | |
| | | | payload (HTTP, TLS records, ...)                         | | | |
| | | +----------------------------------------------------------+ | | |
| | +--------------------------------------------------------------+ | |
| +------------------------------------------------------------------+ |
+----------------------------------------------------------------------+
```

Each header carries a field that names the next one down: EtherType picks IPv4 or ARP,
the IPv4 protocol field picks TCP or UDP, the port picks the process. A switch reads
only the outer layer. A router strips the Ethernet header, reads IP and builds a new
Ethernet header for the next link. This is why "layer 2" and "layer 3" are not stages
of a pipeline, they are separate headers owned by separate devices.

### The Ethernet II frame

```
 6 bytes     6 bytes     2 bytes     46-1500 bytes      4 bytes
+-----------+-----------+-----------+------------------+---------+
| dst MAC   | src MAC   | EtherType | payload          | FCS     |
+-----------+-----------+-----------+------------------+---------+
```

- **Preamble and start delimiter** (8 bytes before the frame) and the **FCS** (a CRC-32
  at the end) are added and checked by the NIC. `tcpdump` normally never shows them,
  which is why an ARP frame prints as `length 42` (14 + 28) although the minimum frame
  on the wire is 64 bytes. The NIC pads the payload up to 46 bytes.
- **dst MAC** is first so a NIC can decide in the first 6 bytes whether the frame is
  for it.
- **EtherType** says what the payload is: `0x0800` IPv4, `0x0806` ARP, `0x86DD` IPv6,
  `0x8100` an 802.1Q VLAN tag follows. Values of 1500 or below mean length in the
  older 802.3 format, which is why Ethernet II types start at 0x0600.
- **MTU** (the largest payload) is 1500 bytes by convention. The largest untagged
  frame is therefore 1518 bytes with FCS, and 1522 with a VLAN tag.

### MAC addresses: unicast, broadcast, multicast

A MAC address is 48 bits, written as six hex bytes. Two bits in the **first byte**
carry meaning:

- **Bit 0 (the I/G bit)**: 0 means individual (unicast), 1 means group (multicast).
  `ff:ff:ff:ff:ff:ff` is the all-ones group address, the broadcast.
  `01:00:5e:…` is IPv4 multicast. `33:33:…` is IPv6 multicast.
- **Bit 1 (the U/L bit)**: 0 means universally administered (a vendor burned it in),
  1 means locally administered (software chose it).

The lab uses `02:00:00:00:01:0N`. `0x02` is binary `00000010`: I/G = 0 (unicast), U/L = 1
(local). Locally administered addresses never collide with a real vendor's, which
makes them safe for a lab, and you will see them in containers and virtual NICs
(Docker uses `02:42:…`).

### ARP: resolving IP to MAC on one link

Before a host can send an IP packet to a neighbour on its own subnet, it needs the
neighbour's MAC. It asks, in a broadcast frame, and the owner answers by unicast.

```
ARP packet (28 bytes, IPv4 over Ethernet)
+------------------+-------------------+---------+---------+
| HTYPE 0x0001     | PTYPE 0x0800      | HLEN 6  | PLEN 4  |
+------------------+-------------------+---------+---------+
| OPER 1=request 2=reply                                    |
+-----------------------------------------------------------+
| sender MAC (6) | sender IP (4)                            |
| target MAC (6) | target IP (4)                            |
+-----------------------------------------------------------+
```

In a **request**, the sender fields are filled, the target MAC is all zeros, and the
frame goes to `ff:ff:ff:ff:ff:ff` with EtherType `0x0806`. In a **reply**, the owner
swaps roles, fills in its own MAC as sender and sends it unicast to the asker. ARP is
not carried inside IP. It is its own EtherType, which is why it never crosses a
router: a router does not forward ARP, it answers its own.

Every host that hears a request can also learn the sender from it. Linux does this for
requests addressed to it, and ignores the rest unless configured otherwise.

### The neighbour table and its states

The kernel keeps the answers in the **neighbour table** (`ip neigh`). Each entry has a
state machine:

| State | Meaning |
|---|---|
| INCOMPLETE | A request was sent, no reply yet. Packets queue behind it. |
| REACHABLE | A reply or confirmation arrived recently. Valid for `base_reachable_time` (about 30 s, randomised). |
| STALE | The timer ran out. The entry is still used, but it is unconfirmed. |
| DELAY | A packet used a STALE entry. The kernel waits about 5 s for upper-layer confirmation (a TCP ACK coming back, for example) before probing. |
| PROBE | The kernel sends unicast requests to re-confirm. |
| FAILED | Probes got no answer. Packets to this IP fail with "host unreachable". |
| PERMANENT | Set by an administrator. Never ages, never probed, never overwritten by ARP. |

The flow is INCOMPLETE to REACHABLE on a reply (or to FAILED if no reply ever comes), REACHABLE to STALE on a timer, STALE to
DELAY on use, DELAY to REACHABLE on confirmation or to PROBE on silence, PROBE to
REACHABLE on a reply or to FAILED after the retries. Traffic that the stack can confirm skips the probe: iputils `ping` sends with
`MSG_CONFIRM`, so one ping takes a STALE entry straight to REACHABLE within a second.
A host that only replies (no confirmation) goes STALE, DELAY, PROBE, REACHABLE.
PERMANENT sits outside the flow,
which makes it the most dangerous entry type: it is a lie that nothing corrects.

A **gratuitous ARP** is a request (or reply) where the sender IP and the target IP are
both the sender's own address. Nobody is asking a question. It announces "this IP is at
this MAC now". Receivers that already have an entry for that IP update it. Failover
tools (keepalived, VRRP implementations) use it to move a shared IP to a new MAC. It
works only because every host on the segment hears the broadcast and trusts it.

### Bridges and switches

A **bridge** connects ports into one broadcast domain and forwards frames by MAC. It
keeps a **forwarding database** (FDB) that maps MAC to port, and it fills the table by
reading source addresses:

1. **Learn.** For every frame, record `source MAC to ingress port`.
2. **Forward.** Look up the destination MAC. If it is known, send out that port only.
3. **Flood.** If the destination is a broadcast, a multicast or an unknown unicast,
   send the frame out every port except the one it arrived on.
4. **Age.** Delete an entry unused for the ageing time (300 s by default in Linux).

Flooding is how the first frame to an unknown host still arrives, and it is why a
switch is not a security boundary: any host on the segment sees every broadcast. A
**broadcast domain** is the set of ports a broadcast reaches. Every ARP request in your
subnet reaches every host in it. Make a subnet large and you make that cost large.

The FDB also explains the duplicate-MAC fault in the lab. The table has one port per
MAC. If two hosts use the same MAC, the entry moves every time either one transmits,
and unicast frames go to whichever host spoke last.

### 802.1Q VLANs

A VLAN splits one physical switch into several broadcast domains. The tag is 4 bytes
inserted after the source MAC:

```
 dst MAC | src MAC | TPID 0x8100 | PCP:3  DEI:1  VID:12 | EtherType | payload
                     2 bytes      2 bytes (TCI)          2 bytes
```

- **TPID** (`0x8100`) sits where EtherType normally is. That is how a receiver knows a
  tag follows.
- **PCP** is a 3-bit priority. **DEI** is 1 bit (drop eligible). **VID** is the 12-bit
  VLAN ID: 0 and 4095 are reserved, so usable IDs are 1 to 4094.
- An **access port** belongs to one VLAN and carries untagged frames. The switch tags
  on ingress (the PVID) and strips on egress. A **trunk port** carries several VLANs
  with their tags intact, plus optionally one untagged "native" VLAN.
- Hosts in different VLANs cannot exchange frames. They need a router, which is an L3
  device with one interface (or one tagged subinterface) per VLAN.

The tag adds 4 bytes, so a tagged full-size frame is 1522 bytes. A trunk that only
passes 1518 will drop it.

## Prove it on the wire

The lab is three namespaces on a bridge. `labs/day01/README.md` has the full
walkthrough. This is what you should see, so a different output is a finding.

**1. ARP request and reply** (`tcpdump -eni eth0 -c 4 arp` in h1 while h1 pings h2):

```
02:00:00:00:01:01 > ff:ff:ff:ff:ff:ff, ethertype ARP (0x0806), length 42: Request who-has 10.1.0.2 tell 10.1.0.1, length 28
02:00:00:00:01:02 > 02:00:00:00:01:01, ethertype ARP (0x0806), length 42: Reply 10.1.0.2 is-at 02:00:00:00:01:02, length 28
```

The first line is a broadcast from h1. The second is a unicast reply. Map every
printed token to a field in your ARP drawing.

**2. The neighbour table** (`ip -n h1 neigh`):

```
10.1.0.2 dev eth0 lladdr 02:00:00:00:01:02 REACHABLE
   ... about 30 s idle ...
10.1.0.2 dev eth0 lladdr 02:00:00:00:01:02 STALE
```

**3. The bridge learning** (`bridge -n sw fdb show br br0 | grep 02:00:00:00:01`):

```
02:00:00:00:01:01 dev p1 master br0
02:00:00:00:01:02 dev p2 master br0
```

Entries appear only for hosts that have transmitted. h3 is absent until it sends a
frame.

**4. A VLAN tag on a trunk port** (`ip netns exec sw tcpdump -eni br0 -c 4`, with `p2` as the trunk view):

```
02:00:00:00:01:03 > ff:ff:ff:ff:ff:ff, ethertype 802.1Q (0x8100), length 46: vlan 20, p 0, ethertype ARP (0x0806), Request who-has 10.20.0.2 tell 10.20.0.3, length 28
```

The length is 46: 42 plus the 4-byte tag. The ICMP echo that follows shows the same
`vlan 20` with length 102. h3 never tagged the frame. The switch did, on the port where
the frame left in VLAN 20.

## Lab

The full lab is in `labs/day01/README.md`. In outline:

1. `bash labs/day01/topo.sh up` builds `sw` with a bridge `br0`, and h1, h2, h3 at fixed
   MACs and `10.1.0.1` to `.3`.
2. Do Prove steps 1 to 4 from the README: capture ARP, watch the neighbour states, watch
   the FDB learn, then enable VLAN filtering and put p3 in VLAN 20.
3. `bash labs/day01/break.sh` injects two faults. Write the evidence chain in
   `journal.md` before you change anything.
4. `bash labs/day01/verify.sh` exits 0 when both are repaired. `SOLUTION.md` holds the
   chain of evidence.
5. Write the "X in AWS is Y on the wire" sentences in `journal.md`.

## Where AWS hides this

A VPC looks like a flat Ethernet. It is not one. Each statement below pairs the AWS
behaviour with what is on the wire.

**A VPC is L3-only.** <!-- fact-checked 2026-10-05: a VPC does not carry L2 broadcast; instances' ARP is answered by the virtual network layer, not by other instances --> The
instance sends an ARP request for its default gateway or for a neighbour on the same
subnet, and the hypervisor's virtual network answers it. You see a normal reply, but
no other instance ever saw your request. The MAC you get back for another instance is
whatever the platform says, not a MAC that instance owns. Nothing you can capture inside
the guest tells you the topology below it.

- **The VPC router is an ARP answer.** The default gateway `.1` of each subnet replies
  to ARP. There is no switch behind it that you can reach, and you cannot ARP-spoof a
  neighbour: <!-- fact-checked 2026-10-05: VPC prevents ARP spoofing and rejects frames with a source MAC/IP that does not belong to the ENI --> the platform drops frames whose source does not match the ENI.
- **No broadcast, no multicast.** A broadcast sent from an instance is not delivered to
  its subnet neighbours. <!-- fact-checked 2026-10-05: VPC does not support broadcast or multicast; Transit Gateway multicast is the only multicast option --> Multicast exists only through the Transit Gateway multicast
  feature, which this course names and does not lab.
- **Gratuitous ARP and VRRP do not move traffic.** A GARP is a broadcast that only
  works when other hosts' caches are real. Here the mapping lives in the platform, so
  your GARP changes nothing. VRRP and keepalived-style failover that depend on it
  silently do nothing. The failover mechanisms that do work are API calls:
  - reassign a **secondary private IP** to the standby's ENI <!-- fact-checked 2026-10-05: EC2 allows reassigning a secondary private IP between ENIs (AssignPrivateIpAddresses with AllowReassignment), detaching/attaching ENIs, and ReplaceRoute to a new ENI target -->;
  - **detach and attach an ENI** (or an Elastic IP) to the standby;
  - **replace a route** in the route table so a prefix targets the standby's ENI.
- **The source/destination check.** <!-- fact-checked 2026-10-05: EC2 source/destination check is on by default and drops traffic that neither originates from nor is destined to the instance's own IP --> The check drops packets
  whose source (outbound) or destination (inbound) is not the instance's own IP. A
  NAT instance, a router or a firewall forwards packets for other addresses, so you
  must turn the check off on its ENI, or the platform drops the forwarded packets.
- **Jumbo frames and MTU.** Inside a VPC the MTU is higher than 1500 on current
  instance types, <!-- fact-checked 2026-10-05: ENIs support 9001-byte MTU within a VPC; IGW, VPN and inter-Region traffic without a TGW are 1500; TGW, NAT gateway and inter-Region VPC peering are 8500 --> but some paths are lower: an internet gateway, a VPN, and inter-Region traffic that does not use a Transit Gateway are capped at 1500, while a Transit Gateway, NAT gateway, and inter-Region peering allow 8500. The EtherType and 802.1Q arithmetic in
  this day still holds: the MTU limits the payload, not the frame.

"X in AWS is Y on the wire", for this day:

- A VPC subnet in AWS is an L3 domain with a platform-answered ARP on the wire.
- A secondary-IP move in AWS is a control-plane update to the mapping, not a
  gratuitous ARP on the wire.
- The source/destination check in AWS is an IP-address filter on the virtual NIC. (The
  separate spoofing protection above is what stops a wrong source MAC or ARP.)
- An ENI in AWS is a veth with a fixed MAC and IP set on the wire (you built this one).
- A VLAN-like boundary in AWS is a subnet plus route table plus security group, not a
  tag on the wire.

For AWS hands-on with these constructs, do `../aws_network_components/` Day 1 (VPC
anatomy): subnets, route tables, ENIs and the source/destination check, in a real
account.

## Exercises

These are standalone. Do them before or after the lab.

1. **Decode a hex dump.** This is an Ethernet frame:
   `ff ff ff ff ff ff 02 00 00 00 01 01 08 06 00 01 08 00 06 04 00 01 02 00 00 00 01 01 0a 01 00 01 00 00 00 00 00 00 0a 01 00 02`.
   Name every field, give its value in plain words and say how many bytes the frame
   has. What would `tcpdump -e` print?
   **Hint:** the first 6 bytes are the destination, the next 6 the source, then 2 for
   EtherType. Then walk the ARP layout from the diagram.
   **Solution sketch:** destination broadcast, source `02:00:00:00:01:01`, EtherType
   `0x0806`. ARP: HTYPE 1, PTYPE 0x0800, HLEN 6, PLEN 4, OPER 1 (request), sender MAC
   `02:00:00:00:01:01`, sender IP 10.1.0.1, target MAC zeros, target IP 10.1.0.2. It is
   42 bytes (14 + 28). tcpdump prints `Request who-has 10.1.0.2 tell 10.1.0.1, length 28`.

2. **Classify five MACs** as unicast, multicast or broadcast, and as universal or
   locally administered: `01:00:5e:00:00:fb`, `02:42:ac:11:00:02`,
   `33:33:00:00:00:01`, `00:1a:2b:3c:4d:5e`, `ff:ff:ff:ff:ff:ff`.
   **Hint:** only the first byte matters. Write it in binary. Bit 0 (the least
   significant) is I/G, bit 1 is U/L.
   **Solution sketch:** `01` = `00000001`: multicast, universal (IPv4 mDNS group).
   `02` = `00000010`: unicast, local (Docker's range). `33` = `00110011`: both bits
   set, multicast and local (IPv6 all-nodes). `00` : unicast, universal (a vendor
   address). `ff`: broadcast, which is multicast with every bit set, so it also has the
   local bit set.

3. **Predict the FDB.** From a freshly built lab, run in this order: h1 pings h2 once,
   then h3 pings h1 once. After each command, list the FDB entries and say which hosts'
   captures saw which frames.
   **Hint:** the bridge learns from the source MAC of every frame it sees, and floods
   broadcasts.
   **Solution sketch:** after the first ping, entries for `…:01` on p1 and `…:02` on p2.
   h3 saw the ARP request (broadcast) and not the echo. After the second ping, `…:03`
   on p3 is added. h2 sees h3's ARP request as a broadcast. h1's reply is unicast, so
   h2 sees nothing of it.

4. **Why does a duplicate MAC cause intermittent loss?** Two hosts, h2 and h3, share a
   MAC and h1 pings h2 once a second.
   **Hint:** how many ports can one FDB entry name?
   **Solution sketch:** the FDB maps a MAC to a single port. Each frame from h2 or h3
   re-learns the entry on the port it came from. A frame for that MAC goes only to the
   port learned last. If h3 spoke last, h2 does not get h1's echo and the ping is lost.
   When h2 speaks again the entry moves back. Loss is proportional to how often the
   other host transmits, hence "sometimes".

5. **Walk the neighbour states.** h1 has no entry for h2. Name the state after each
   event: (a) h1 sends a ping, (b) the reply arrives, (c) 40 s pass with no traffic,
   (d) h1 pings again, (e) 5 s later h2 is switched off.
   **Hint:** states are INCOMPLETE, REACHABLE, STALE, DELAY, PROBE, FAILED. iputils
   `ping` sets `MSG_CONFIRM`.
   **Solution sketch:** (a) INCOMPLETE; (b) REACHABLE; (c) STALE; (d) the entry is used
   at once, and because ping confirms it, it returns to REACHABLE within a second (a
   sender that gives no confirmation would sit in DELAY for about 5 s); (e) ping to a
   dead host gets no confirmation: STALE, DELAY, PROBE after the delay, then FAILED once the unicast probes (and
   the retries) get no reply. `ip neigh` shows `FAILED` and new pings print "Destination
   Host Unreachable".

6. **VLAN membership puzzle.** A switch has ports 1 to 4. P1 and P3 are access ports
   for VLAN 10. P2 and P4 are access ports for VLAN 20. P5 is a trunk to a second
   switch and allows only VLAN 10. All hosts use 10.0.0.0/24. Which pairs communicate?
   Where does a broadcast from P1 go? Does P4 reach a VLAN-20 host behind P5?
   **Hint:** a frame stays inside the VLAN it was tagged with on ingress.
   **Solution sketch:** P1 and P3 talk, P2 and P4 talk, and no pair across VLANs. A
   broadcast from P1 reaches P3 and the trunk P5 (tagged 10) and nothing else. A
   VLAN-20 host behind P5 is unreachable, because the trunk does not carry VLAN 20.

7. **Aged-out entry.** Assume `ageing_time` on `br0` is lowered (the FDB default is
   300 s against about 30 s for a neighbour entry, so you cannot see this by waiting).
   The FDB entry for h2 has aged out a moment ago. h1 pings h2 again (h1's
   neighbour entry is still REACHABLE). What does h3 capture, and why does the ping
   still work?
   **Hint:** distinguish the neighbour table from the FDB.
   **Solution sketch:** h1 knows h2's MAC, so it sends the unicast echo without ARP.
   The bridge has no entry for that MAC and floods it as unknown unicast, so h3 sees an
   ICMP echo not addressed to it. h2 replies, the bridge relearns h2 on p2 from the
   reply's source MAC, and later frames are no longer flooded.

8. **Why is the ARP frame 42 bytes in tcpdump but 64 on the wire?** What is added,
   and who adds it?
   **Hint:** the Ethernet minimum frame is 64 bytes including FCS.
   **Solution sketch:** 14 header + 28 ARP = 42. The NIC pads the payload to 46 bytes
   (so 14 + 46 = 60) and appends a 4-byte FCS (64 total). The capture is taken before
   the NIC does either.

9. **Gratuitous ARP.** Write the packet that announces 10.1.0.9 at
   `02:00:00:00:01:09`. What do other hosts do with it, and what could go wrong?
   **Hint:** the sender and target IP are the same.
   **Solution sketch:** an ARP request (or reply) to broadcast with sender MAC
   `02:00:00:00:01:09`, sender IP 10.1.0.9, target IP 10.1.0.9. Hosts with a cache
   entry for 10.1.0.9 overwrite the MAC; hosts without one may ignore it. A wrong or
   malicious sender poisons every cache on the segment, which is why ARP-spoofing
   defences exist and why a VPC drops these.

10. **Design a floating-IP failover for two EC2 instances.** Active and standby share a
    service IP. The standby must take over within seconds. Gratuitous ARP is out.
    Pick a mechanism, say what triggers it and name the permissions it needs.
    **Hint:** think of what moves in the AWS control plane: a secondary IP, an ENI, an
    Elastic IP or a route.
    **Solution sketch:** keep a health check (keepalived with a script, or a small
    agent) on the standby. On active failure the standby calls the EC2 API to reassign
    the secondary private IP to its own ENI with reassignment allowed (or
    `ReplaceRoute` for a VIP outside the CIDR, which needs the source/destination check
    off). The role needs `ec2:AssignPrivateIpAddresses` and `ec2:UnassignPrivateIpAddresses`
    (or `ec2:ReplaceRoute`, or `ec2:AttachNetworkInterface` and
    `ec2:DetachNetworkInterface`), scoped to those resources. Fence
    the old active before taking over. No packet on the wire moves the address.

## Anti-patterns / Common mistakes

**Memorizing the OSI model instead of the actual headers.** "It's a layer 2 problem"
names a bucket. It does not name a field. When someone says it, ask which field in
which header: a wrong destination MAC, a stale neighbour entry, a MAC that moves
between ports in the FDB. Start from the frame on the wire, draw it, then find the
field. Today's break has a PERMANENT neighbour entry and a duplicate MAC. Neither is
solvable by reciting layer names.

**Learning tool flags instead of the protocol underneath.** `ip neigh`, `bridge fdb`
and `tcpdump -e` are three views of two tables and one header. A flag set goes stale
with the tool version and is missing from a minimal container. Before you run a
command, say what packet or table it reads. If you cannot, you are reciting: go back
to the frame.

**Trusting a static entry.** A PERMANENT neighbour entry never self-corrects, so it
stays wrong until a person deletes it. Check `ip neigh show nud permanent` early.

**Assuming a switch sends traffic only where it should.** Unknown unicast and broadcast
flood. If a capture on a third host shows traffic it should not see, the bridge has no
entry for the destination.

**Carrying data-centre failover patterns onto AWS unchanged.** Gratuitous ARP and VRRP
assume a shared broadcast domain. A VPC does not provide one, so use an API-driven move.

## Teardown

```bash
bash labs/day01/topo.sh down
ip netns list          # expect: empty
```

Stopping for the day? On the host run `bash labs/verify-teardown.sh`. Details:
`labs/day01/teardown.md`.
