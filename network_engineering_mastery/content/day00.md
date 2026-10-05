# Day 0 — The map: how the Internet is put together

**Truth of the day:** a packet crosses about a dozen boxes, and each box reads one header
**Budget:** 2 h — 45 m theory, 1 h lab (guided proof, then break and diagnose), 15 m
exercises

**At a glance — how to work through this day:**
1. Read "Why this matters", then draw the path from your laptop to a server from memory
   ("Draw it first"). Correct the drawing against the page.
2. Read "Core concepts".
3. Do the lab in `labs/day00/`: `topo.sh up`, the proof walkthrough, then `break.sh`,
   `journal.md`, `verify.sh`.
4. Read "Where AWS hides this", then do the exercises whenever you like.

## Why this matters

You debug VPCs, gateways and resolvers every day, and you do it well. Ask for the whole
path from a laptop in a flat to a server on the other side of the world, and the picture
gets fuzzy: what is the modem, what does "the router" mean, who gave the laptop its
address, why a home user's "public IP" may belong to someone else, and where the
Internet itself begins. The fuzz costs you on the day a customer says "it works on my
phone and not my laptop" or "everyone on one ISP cannot reach us".

This day draws the map. Days 1 to 7 each zoom into one hop of it: Day 1 the frame on
the first link, Day 2 the IP hops, Day 3 the connection at the ends, Day 4 the NAT boxes
in the middle, Day 5 how the boxes learn where to send, Day 6 tunnels and names, Day 7
the whole trip. You also meet the one protocol the course would otherwise skip: DHCP,
the first packet any device sends, and the reason a laptop has an address at all.

## Draw it first

On a blank page draw the path from a laptop to a web server, one box per stop, and write
under each box which header it reads and which address it rewrites. Then compare.

```
 laptop ~~Wi-Fi~~ [ home router box ] --- [ modem / ONT ] === ISP access network
 192.168.1.1xx     switch+AP+router        converts the        DSLAM / CMTS / OLT
                  +NAT+DHCP+DNS          last-mile signal    (many homes, one box)
                  src 192.168.1.1xx
                  -> 100.64.0.2    <- NAT #1 (home)
                                                    |
   ISP core --- [ ISP edge / CGNAT ] --- IXP or transit ---> content network --- server
   (routers,    src 100.64.0.2          (where two ASes       (own AS, often       203.0.113.10
    one AS)     -> 198.51.100.1          connect: ASN, BGP)    a CDN)
                <- NAT #2 (carrier)
```

Three things the picture must show. The laptop's address (private, from DHCP) is not the
address the server sees. Every router in the middle looks only at the destination IP and
forwards. And the Internet is not one network: it is tens of thousands of separately run
networks (autonomous systems) joined at meeting points.

The lab builds exactly this, in five namespaces: `lap`, `hr` (home router), `isp`,
`transit`, `srv`.

## Core concepts

### The OSI and TCP/IP models, the useful way

Two models describe the same stack. **OSI model**: seven layers, a teaching vocabulary.
**TCP/IP model**: four layers (link, internet, transport, application), which is how the
protocols were built. The word "layer N" in a conversation is OSI numbering. Use it as
shorthand and always translate it into a header.

| OSI layer | TCP/IP layer | Real header you read | Device that acts on it | Failure you see | Day |
|---|---|---|---|---|---|
| 1 Physical | link | bits, signal, a link light | **hub**, **repeater**, modem and ONT (L1, often bridging at L2) | no link, CRC errors, flapping | 1 |
| 2 Data link | link | Ethernet (or 802.11): MACs, EtherType, VLAN tag | **switch**, **access point** | wrong MAC, ARP unanswered, loop | 1 |
| 3 Network | internet | IPv4 or IPv6: addresses, TTL, protocol | **router**; NAT and firewall also act here | no route, TTL expired, MTU black hole | 2, 5 |
| 4 Transport | transport | TCP or UDP: ports, flags, sequence numbers | firewall, NAT (L3-4), load balancer (L4) | refused, timeout, reset | 3, 4 |
| 5 Session, 6 Presentation, 7 Application | application | TLS, HTTP, DNS, DHCP: one payload, no separate header per layer | proxy, L7 load balancer, DNS server | bad certificate, 502, NXDOMAIN | 6 |

Layers 5 and 6 have no header of their own in TCP/IP practice. TLS (session and
presentation in the OSI story) and HTTP both live inside the application payload, so
treat "5-6-7" as one box. **Encapsulation** is what links the rows: each layer's header
and data become the next layer's payload. An HTTP request sits inside a TCP segment, inside
an IP packet, inside an Ethernet frame. A router strips and rebuilds the Ethernet frame at
every hop and leaves the IP packet alone (apart from TTL and checksum). A NAT box also
rewrites the addresses and ports.

This is why the course says "do not memorize OSI, read headers"
([`../STRATEGY.md`](../STRATEGY.md), mistake 1). Seven names tell you nothing about a
failure. "Layer 2 problem" is a claim you prove with a field: which MAC, in which frame,
answered by whom. Use the table as a map from header to device, not as trivia.

### Devices, and what the box on your shelf really is

| Device | Reads | Does | Typical mistake |
|---|---|---|---|
| **Hub** / **repeater** | nothing (L1) | repeats every bit out of every other port; one collision domain | thinking a "switch" in a cheap box still repeats |
| **Switch** | Ethernet destination MAC | forwards a frame only toward the port that learned that MAC; floods unknown and broadcast | confusing it with a router: a switch does not cross subnets |
| **Router** | IP destination | picks the next hop from the routing table; joins different networks | |
| **Modem** | the line signal | converts between the carrier's signal (DSL, DOCSIS, radio) and Ethernet | assuming it routes |
| **ONT** | the optical signal | the fiber equivalent of a modem; ends the fiber at your home | |
| **Access point** (**AP**) | 802.11 frames | bridges Wi-Fi to Ethernet: a switch with a radio | |
| **Firewall** | L3-L4 (L7 for next-gen) | allows or drops flows by policy, usually tracking state | |
| **Load balancer** | L4 ports, or L7 HTTP | spreads connections or requests across servers | |

The consumer "router" is up to eight functions in one plastic box: a **switch** (the LAN
ports), an access point (Wi-Fi), a router (LAN to WAN), **NAT** (many private addresses
behind one), a DHCP server, a DNS forwarder, a stateful firewall, and often the modem
too. When a colleague says "restart the router" they may mean any of those. The lab's `hr`
namespace is this box, with the radio left out: router, NAT, `dnsmasq` as DHCP server and
DNS forwarder. **Bridge mode** turns the box (or an ISP's combined modem-router) into a
modem only: it stops doing NAT and DHCP and passes the public address through to the next
device, which you then run yourself.

### The last mile

The part between your home and the first ISP building is the access network, and its
technology decides how the **modem** or ONT looks.

- **DSL**: data over the phone line. A **DSLAM** at the exchange terminates many lines.
  Often **PPPoE** carries the session: a PPP login over Ethernet, which adds an 8-byte
  header and so lowers the usable MTU from 1500 to 1492. Day 2 covers MTU, PMTUD and MSS
  clamping, which is how PPPoE's 1492 bites.
- **Cable** (**DOCSIS**): data over the TV coax. The **CMTS** at the head-end talks to your
  cable modem, and the coax segment is shared between the neighbours, so upload and
  download rates depend on neighbourhood load.
- **Fiber** (**GPON**): light on glass. The **ONT** in your home talks to an **OLT** at the
  ISP over a passive splitter shared by a few dozen homes, with upstream time slots
  the OLT assigns so they do not collide (downstream is broadcast and encrypted).
- **Cellular (4G/5G)**: radio to a tower, then the carrier's core. Almost always behind
  CGNAT, and the handset's address may change as it moves.

Whatever the technology, the end of the last mile is an Ethernet-looking link into your
router's WAN port, and the first IP hop beyond it is the ISP's.

### The structure of the Internet

An **autonomous system** (AS) is a network run by one organisation under one routing
policy, identified by an **ASN**. The Internet is tens of thousands of ASes, joined where two of
them agree to exchange traffic.

- **Access ISP**: sells you a connection. Regional ISPs aggregate access ISPs.
- **Transit**: an AS you pay to carry your traffic to the rest of the Internet. It is a
  customer-provider relationship, priced by bandwidth.
- **Peering**: two ASes exchange traffic for their own customers only, at no charge
  (settlement-free). It saves transit cost and shortens the path.
- **Tier 1**: a network that reaches the whole Internet without buying transit, by
  peering settlement-free with every other Tier 1.
- **IXP**: Internet exchange point, a shared switch in one building where many ASes
  connect and peer with each other over one port each. Content networks (a **CDN** or a
  cloud) sit at IXPs to hand traffic to access ISPs close to the user.

The protocol between ASes is **BGP**: each AS announces which address prefixes it can
reach and the path of ASNs to them. Your laptop never speaks BGP, but every packet it
sends is steered by routes BGP built. Day 5 builds that in FRR.

### Public, private and shared addresses, and why CGNAT exists

Public IPv4 addresses are scarce. Three ranges you meet daily are not routed on the Internet: private
(`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, RFC 1918), **shared address space**
`100.64.0.0/10` (RFC 6598), and link-local `169.254.0.0/16`. Every home reuses
`192.168.1.0/24`, so a backbone router cannot route to it: there are millions of
different 192.168.1.0/24 networks and no way to say which one you mean. Transit
providers carry no route for them: a packet to such a destination is dropped, and a
reply to such a source address has nowhere to go.

When an ISP has too few public addresses for its customers, it runs **CGNAT**
(carrier-grade NAT): the home router gets a `100.64.0.0/10` WAN address, and an ISP box
translates many such customers onto a handful of public addresses. The result is **double NAT**: your laptop's address is translated by the home router, then by the ISP. Side
effects: you cannot accept inbound connections (no port-forwarding, because you do not
own the outer address), several customers share one public IP so IP-based blocks and
rate limits hit them together, and "what is my IP" tells you the ISP's NAT address, not
yours. The lab shows it in a capture: `192.168.1.x`, then `100.64.0.2`, then
`198.51.100.1`. (The lab's `198.51.100.0/24` and `203.0.113.0/24` are RFC 5737
documentation ranges standing in for public space.)

### DHCP: how a device gets an address

A device on a link with no configuration needs an address, a mask, a gateway and a DNS
server. **DHCP** (Dynamic Host Configuration Protocol, UDP 67 server and 68 client) gives
all four in four packets, called **DORA**:

1. **Discover**: the client broadcasts, source `0.0.0.0`, destination
   `255.255.255.255`. It has no address and does not know any server, so broadcast is the
   only way to speak.
2. **Offer**: a server proposes an address and options.
3. **Request**: the client broadcasts its choice (broadcast so that other servers learn
   their offer was declined).
4. **Ack**: the server confirms. The client now configures the address.

The options carry the rest: **router** (becomes the default route), **DNS server**,
domain name, and **lease time**. The address is leased, not owned. At 50% of the lease
(**T1**) the client asks the same server to renew (unicast). At 87.5% (**T2**) it
broadcasts to any server. If the lease expires with no answer, the address is dropped.

Broadcasts do not cross routers, so a DHCP server on another subnet would never hear a
Discover. A **DHCP relay** (relay agent) on the router listens for broadcasts and forwards
them as unicast to the server, adding the client's subnet (`giaddr`). That is how one server
serves many VLANs.

If no server answers, the client gives up and uses **APIPA** (automatic private IP
addressing), an address of its own in `169.254.0.0/16`, also called IPv4 **link-local**.
It works only on the local link, has no gateway, and means one thing: DHCP failed. A
`169.254` address is never a valid network to troubleshoot, only a symptom.

IPv6 note: a host builds an address itself from a router advertisement (**SLAAC**) and
may ask a DHCPv6 server for the rest. Day 2 covers it.

### The routing table, first contact

The routing table answers one question: for this destination, where does this box send
the packet? `ip route` prints it, and `ip route get <addr>` shows the answer for one
address. Three kinds of line matter now:

- A **connected route**, `192.168.1.0/24 dev eth0`: this network is on this link, send
  the frame straight to the destination.
- A **default route**, `default via 192.168.1.1`: for everything not listed, send it to
  that router. A laptop has one. The DHCP "router" option writes it.
- A specific route, `100.64.0.0/30 dev wan0`: the more specific prefix wins (Day 2).

Compare the laptop with the ISP edge. The laptop: one connected route plus a default.
The ISP edge: connected routes for each customer link plus a default toward its transit.
A transit router has no default at all: it holds the full routing table learned by BGP,
and it has no entry for `192.168.0.0/16` or `100.64.0.0/10`. "Where would this box send
it?" is the reading skill. Day 2 teaches the rest.

## Prove it on the wire

The full walkthrough is in `labs/day00/README.md`. The lab builds `lap`, `hr`, `isp`,
`transit` and `srv`, with the laptop getting its address by DHCP, and a web server named
`www.example.test`. Capture and prove:

1. **DORA.** `tcpdump -vni eth0 port 67 or port 68` on the laptop while it asks for an
   address. Name the four messages, the `0.0.0.0` source, the broadcast destination,
   and the router, DNS server and lease-time options.
2. **Routing tables.** `ip route` and `ip route get 203.0.113.10` on the laptop, the home
   router and the ISP edge. Say in one sentence where each would send the packet.
3. **Hops.** `traceroute -n` from the laptop to the server: home router, ISP, transit,
   server.
4. **Two rewrites.** Capture the same request at `lan0`, `wan0` and the server side:
   the source is `192.168.1.x`, then `100.64.0.2`, then `198.51.100.1`.
5. **Layers.** Take one captured frame and label each header with its OSI and TCP/IP
   layer, and the device that reads it.

## Lab

See `labs/day00/`. The goal: build home, ISP and server in namespaces, watch DHCP and the
double NAT, then diagnose two independent faults (the DHCP server dies, the ISP loses its
NAT rule) from captures, before you read `SOLUTION.md`. Success signal:
`bash labs/day00/verify.sh` exits `0` and prints `PASS: day 00 is healthy.`

## Where AWS hides this

AWS runs the same map inside a VPC, with the home-router functions split into services.
Each line below is "X in AWS is Y on the wire".

- **DHCP is the VPC's DHCP option set.** Instances get their address, DNS server and
  domain by DHCP from the VPC. The option set holds the domain name, domain name servers,
  NTP servers, NetBIOS name servers and node type, and the IPv6 preferred lease time. It
  does not hold the router: the VPC router is the subnet's base address plus one (for
  example `10.0.0.1`). An option set is immutable and a VPC uses one at a time: create a
  new set and associate it <!-- fact-checked 2026-10-05 -->.
- **Amazon-provided DNS is a forwarder.** It answers at `169.254.169.253`, at
  `fd00:ec2::253` (IPv6), and at the VPC's primary CIDR base address plus 2 (`10.0.0.2` for
  a `10.0.0.0/16` VPC) <!-- fact-checked 2026-10-05 -->. It is your home router's DNS forwarder, delivered by the
  DHCP option.
- **The internet gateway is a one-to-one NAT.** An instance with a public IPv4 address
  holds a private address in the VPC. The IGW translates between the two, one address
  for one address, with no port arithmetic <!-- fact-checked 2026-10-05 -->. A **NAT Gateway** is your home router's
  NAT: many private sources behind one public address, with port translation (Days 3 and 4
  cover its limits).
- **No CGNAT inside a VPC, but `100.64.0.0/10` is usable.** AWS does not put a carrier NAT
  between you and the Internet. A VPC may use a /16 to /28 block from `100.64.0.0/10`, as
  its primary or a secondary CIDR (with restrictions when mixed with RFC 1918 ranges) <!-- fact-checked 2026-10-05 -->.
- **AWS is an autonomous system.** Amazon announces AWS prefixes from AS16509 (also AS14618
  and others) <!-- fact-checked 2026-10-05: source PeeringDB/ARIN, not AWS docs -->, and
  peers with ISPs at IXPs and private interconnects, like a CDN. A **Direct Connect
  location** is a colocation facility where your router connects, by a fiber cross-connect
  (or through a partner), to an AWS Direct Connect router: the same idea as a meet-me room
  at an IXP. BGP runs over a virtual interface <!-- fact-checked 2026-10-05 -->.
- **Link to the depth.** Console and CLI hands-on for VPCs, route tables, internet
  gateways and NAT gateways is in
  [`../../aws_network_components/`](../../aws_network_components/).

**Local emulation.** `hr` is the home router: masquerade out `wan0`, `dnsmasq` for DHCP
and DNS. `isp` is the carrier NAT. The AWS parallels are an internet gateway (a
translation) and a NAT Gateway (the same masquerade). Day 4 builds both properly.

## Exercises

1. **Name the box.** Your ISP's installer leaves a white box with one fiber input, four
   Ethernet ports, Wi-Fi and a login page. List every function in it. — **Hint:** use the
   device table and the paragraph after it that lists what the consumer box contains. —
   **Solution sketch:** eight functions: an ONT (fiber to Ethernet), a router, NAT, a DHCP
   server, a DNS forwarder, a firewall, a switch (the four ports) and an access point
   (Wi-Fi). Eight functions behind one word, "router".
2. **Label a frame.** A capture line reads `aa:bb:.. > ff:ff:..., ethertype IPv4,
   0.0.0.0.68 > 255.255.255.255.67: BOOTP/DHCP`. Give the layers and protocols, outermost
   first. — **Hint:** what contains what. — **Solution sketch:** Ethernet II (L2, link,
   destination broadcast), IPv4 (L3), UDP (L4, ports 68 to 67), DHCP (L7, application).
   Layers 5 and 6 add no header.
3. **Which device?** For each, name the first device that can act on it: (a) a frame to an
   unknown MAC; (b) a packet to `8.8.8.8`; (c) TCP port 25 blocked; (d) an HTTP request
   routed by URL path. — **Hint:** which header does each read. — **Solution sketch:**
   (a) a switch, floods it; (b) a router; (c) a firewall; (d) an L7 load balancer.
4. **Why broadcast?** Why must a DHCP Discover be a broadcast from `0.0.0.0`? Why is the
   Request a broadcast too? — **Hint:** what does the client know? —
   **Solution sketch:** it has no address and does not know a server, so it cannot unicast. The
   Request is broadcast so every server hears which offer was taken and the others can
   withdraw theirs.
5. **Lease arithmetic.** A lease is 12 h. When does the client first try to renew, when
   does it fall back to broadcasting, and when does the address disappear? — **Hint:**
   T1 is 50%, T2 is 87.5%. — **Solution sketch:** at 6 h it renews by unicast to the
   same server, at 10 h 30 m it broadcasts to any server, at 12 h it must drop the
   address.
6. **Read the address.** A laptop reports `169.254.17.9/16` and no gateway. What happened,
   and what do you check first? — **Hint:** who assigns 169.254? —
   **Solution sketch:** nobody; the client assigned it to itself after DHCP got no answer.
   Capture Discover packets: if there is no Offer, check the server or the relay on that
   segment.
7. **Relay.** The DHCP server is in the data-centre subnet and the clients are in a
   branch subnet. What makes it work, and what does the server use to choose the pool? —
   **Hint:** broadcasts stop at the router. — **Solution sketch:** a DHCP relay on the
   branch router forwards the Discover as unicast and stamps the branch gateway address
   (`giaddr`). The server picks the pool matching `giaddr`.
8. **Read a table.** The ISP edge shows `default via 198.51.100.2`, `100.64.0.0/30 dev
   cust0`. A customer at `100.64.0.2` pings `203.0.113.10`. Where does it go, and where
   does the reply go? — **Hint:** the reply's destination is the NAT address. —
   **Solution sketch:** matches the default, sent to `198.51.100.2` after NAT rewrites
   the source to `198.51.100.1`. The reply returns to `198.51.100.1`, and the NAT table
   restores `100.64.0.2` and sends it out `cust0`.
9. **Why not routed?** Why can `100.64.0.2` reach nothing without the ISP's NAT? —
   **Hint:** think about every other home. — **Solution sketch:** shared space is reused
   by every ISP, so the Internet has no route to it. A packet with that source is
   forwarded but the reply has no route back (or is dropped as a bogon), so nothing
   returns.
10. **Double NAT effects.** A customer hosts a game server behind a home router on a
    CGNAT line. Why can nobody connect, and what are the options? — **Hint:** who owns
    the public address? — **Solution sketch:** the ISP's NAT has no inbound mapping for
    the customer, and the customer cannot configure it. Options: ask for a public address,
    use IPv6, or use a relay or tunnel (an outbound connection to a public host).
11. **PPPoE MTU.** Why is the usable MTU 1492 on a PPPoE line, and what breaks if a host
    still sends 1500-byte packets with DF set? — **Hint:** 8 bytes of PPP header. —
    **Solution sketch:** PPPoE adds 8 bytes inside the 1500-byte Ethernet payload, leaving
    1492. Big DF packets are dropped, and if the ICMP "fragmentation needed" is lost, web
    pages hang (an MTU black hole). Day 2 covers MTU, PMTUD and MSS clamping, which is how PPPoE's
    1492 bites. The fix is MSS clamping or the right MTU.

## Anti-patterns / Common mistakes

- **Memorizing OSI layers as trivia (mistake 1).** Reciting "Please Do Not Throw Sausage
  Pizza Away" earns nothing in an incident. Map every layer to a header and a device, as in
  the table, and say "the Ethernet destination is wrong", not "a layer 2 problem".
- **"The router" meaning five different boxes.** A ticket that says "the router is down"
  could be the modem, the NAT, the DHCP server, the DNS forwarder or the Wi-Fi. Ask which
  function failed and test that function: link light, address, route, name.
- **Assuming your public IP is yours.** On CGNAT, cellular and some fibre lines the address
  you see on a "what is my IP" site is shared with strangers. Compare the router's WAN
  address with that site: if the WAN address is in `100.64.0.0/10`, you are behind
  CGNAT. Do not use an IP allow-list for a person, and do not promise inbound access.
- **Treating 169.254 as a valid network.** Pinging the neighbour's 169.254 address works
  and proves nothing. Fix DHCP, do not configure around it.

## Teardown

```bash
bash labs/day00/topo.sh down
bash labs/verify-teardown.sh
```

Full checklist in `labs/day00/teardown.md`.
