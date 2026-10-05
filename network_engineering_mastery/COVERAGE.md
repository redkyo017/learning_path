# Coverage Audit

This course is ordered by the packet's path down the stack (frame, packet, segment,
translation, routing, tunnel), not by a certification syllabus. The risk of ordering
it that way is silently dropping something a systematic sweep would have caught, so
this file is the proof that nothing was missed by accident.

Every topic below is either mapped to the day that covers it, pointed at the sibling
course that does, or marked **SKIPPED** with its reason in the third section. There is
no fourth category.

Day map: 0 The map (devices, last mile, ISP, DHCP, OSI). 1 Ethernet, ARP, VLANs. 2 IP, ICMP, MTU. 3 TCP and UDP. 4 NAT, conntrack,
firewalls. 5 Routing and BGP. 6 Tunnels, IPsec, DNS. 7 One packet end to end plus the
five-incident timed gauntlet.

---

## Networking fundamentals coverage

Topic names follow the commonly published CCNA 200-301 blueprint ("Network
Fundamentals", "IP Connectivity", "Network Access") and CompTIA Network+ concept
areas. This is a topic-level audit, not an exam-objective crosswalk.

| Topic | Source | Day | Where |
|---|---|---|---|
| OSI and TCP/IP models, encapsulation | CCNA Fundamentals, Network+ | 0, 1 | encapsulation as nested headers; read on the wire with `tcpdump -e` |
| Ethernet frames, MAC addressing | CCNA Fundamentals, Network+ | 1 | Ethernet II frame, unicast/broadcast/multicast MACs |
| ARP and the neighbour table | CCNA Fundamentals | 1 | ARP resolution, neighbour states (`ip neigh`) |
| Switching, bridges, MAC learning | CCNA Network Access | 1 | Linux bridge as a learning switch; STP depth **SKIPPED** |
| VLANs and 802.1Q trunking | CCNA Network Access | 1 | tagged sub-interfaces and the tag on the wire |
| IPv4 addressing and subnetting | CCNA Fundamentals | 2 | CIDR mental method, header fields |
| IPv6 addressing | CCNA Fundamentals | 2 | fixed header, extension chain, essentials |
| ICMP, ping, traceroute | CCNA Fundamentals, Network+ | 2 | ICMP types, TTL-based traceroute |
| Fragmentation, MTU, MSS, PMTUD | Network+ | 2 | DF bit, "fragmentation needed", MSS clamping |
| TCP and UDP operation | CCNA Fundamentals | 3 | header, handshake, sequence arithmetic, states, TIME_WAIT, retransmission, keepalive; UDP |
| Ports and sockets | Network+ | 3 | refused vs ignored vs reset; `ss` |
| NAT and PAT | CCNA IP Services, Network+ | 4 | SNAT, DNAT, masquerade; conntrack tuples |
| Stateful vs stateless filtering, ACLs | CCNA Security Fundamentals | 4 | nftables model, NACL-style stateless rules, asymmetric routing |
| Routing table, longest-prefix match, static routes | CCNA IP Connectivity | 2, 5 | router forwarding decision (Day 2); static vs dynamic (Day 5) |
| Dynamic routing concepts | CCNA IP Connectivity | 5 | distance-vector vs link-state; OSPF configuration **SKIPPED** |
| BGP (eBGP basics, best path, policy, timers) | beyond CCNA; ANS-C01 | 5 | FRR `bgpd` in network namespaces |
| VRF-style segmentation | beyond CCNA | 5 | TGW route tables as VRFs; policy-routing tables in one `tgw` namespace (VRF-lite) |
| Tunnels: GRE, VXLAN, GENEVE, IPsec | Network+, beyond CCNA | 6 | the encapsulation tax, IPsec in one page |
| DNS | CCNA IP Services, Network+ | 6 | resolution path, record types, the `ndots` and TTL traps |
| DHCP (DORA, leases, options, relay, 169.254 fallback) | CCNA IP Services, Network+ | 0 | `dnsmasq` and `dhcpcd` in namespaces; DORA captured |
| Network device taxonomy (hub, switch, router, modem, ONT, AP, firewall, load balancer) | CCNA Fundamentals, Network+ | 0 | what the consumer router box contains |
| Last mile and modems (DSL, cable, fiber, cellular, PPPoE) | Network+ | 0 | concept level; Day 2 covers MTU, PMTUD and MSS clamping, which is how PPPoE's 1492 bites |
| ISP structure, IXP, transit, peering, Tier 1, ASNs | Network+, ANS-C01 | 0 (BGP: 5) | concept level plus the lab's home, ISP and transit hops |
| CGNAT and double NAT, public vs private vs shared addresses | CCNA IP Services, Network+ | 0, 4 | 100.64.0.0/10, captured source rewrites |
| Load balancing, proxies | Network+ | 3, 4 | NLB/ALB as conntrack and TCP-termination behaviour |
| Troubleshooting methodology | Network+ | 7 | five-incident timed gauntlet, one packet traced end to end |
| Network security concepts (firewalls, segmentation) | CCNA Security Fundamentals, Network+ | 4, 5, 7 | nftables, stateless vs stateful, TGW segmentation, on-prem firewall hop |
| Wireless (802.11, WLC, APs) | CCNA Network Access, Network+ | — | **SKIPPED** |
| QoS | CCNA IP Services | — | **SKIPPED** |
| Network automation, SNMP, syslog | CCNA Automation, Network+ | — | **SKIPPED** |

---

## AWS Advanced Networking Specialty (ANS-C01) domain coverage

Domain names follow the commonly published exam guide. <!-- fact-checked 2026-10-05: ANS-C01 domain
names and weights: Network Design 30%, Network Implementation 26%, Network Management
and Operation 20%, Network Security, Compliance and Governance 24% -->

| Domain | Weight | Days here | Notes |
|---|---|---|---|
| Network Design | ~30% | 2, 4, 5, 6, 7 | CIDR and route-table design, inspection VPC, TGW segmentation, hybrid routing; hands-on in `aws_network_components` Days 1, 4, 6, 7 |
| Network Implementation | ~26% | 5, 6, 7 | BGP over VPN/DX, tunnels, DNS resolver behaviour; hands-on in `aws_network_components` Days 1, 3, 4, 5, 6 |
| Network Management and Operation | ~20% | 3, 7 | timers, MTU and idle-timeout diagnosis, the gauntlet; `aws_network_components` Day 8 (Reachability Analyzer, flow logs) |
| Network Security, Compliance and Governance | ~24% | 4, 5, 6 | NACLs, Network Firewall, GWLB, appliance mode; `aws_network_components` Day 2 (security groups, NACLs), Day 5 (endpoints, PrivateLink) |

Topic-level mapping:

| ANS-C01 topic | Day / Where |
|---|---|
| VPC router, route tables, longest prefix | 2 (Where AWS hides this); sibling Day 1 |
| MTU tiers (9001 in VPC, 1500 across gateways), PMTUD | 2 |
| IPv6, egress-only IGW | 2 |
| NLB/ALB timeouts, client IP preservation | 3 |
| NAT Gateway port arithmetic | 3, 4 |
| Security groups (stateful) vs NACLs (stateless) | 4; sibling Day 2 |
| Network Firewall, centralized inspection, GWLB | 4, 6 |
| TGW appliance mode | 4 (local lab); `aws_lab/day04` (the only lab that runs on AWS) |
| Peering and Transit Gateway attachments | 5, 7; sibling Day 4 |
| Site-to-Site VPN, Direct Connect, BGP route preference | 5, 6; sibling Day 6 |
| TGW route tables, segmentation | 5 |
| Route 53 Resolver, DNS Firewall | 6; sibling Day 3 (Resolver) |
| VPC endpoints, PrivateLink | sibling course: `aws_network_components` Day 5 |
| Multi-account networking, RAM sharing | sibling course: `aws_network_components` Day 7 |
| Reachability Analyzer, flow logs, debugging | 7 (by hand); sibling Day 8 |
| ECS/EKS networking (awsvpc, no overlay) | 6 |
| Cloud WAN, VPC Lattice, IPAM | **SKIPPED** |

---

## Deliberately skipped, and why

Each gap is a choice. The reason has one shape: the item does not occur in the work this
course is for, which is explaining and debugging packets in AWS from first principles,
or it is a configuration skill that a vendor course teaches better than a lab here can.

**Wireless (802.11, controllers, access points).** No instance, task or gateway in AWS
has a radio. Needs hardware or a simulator you do not have locally.

**STP depth (PVST, RSTP, root election tuning).** Day 1 builds a bridge and learns
MACs, which is the part that appears in cloud debugging. A VPC has no loops to prevent.

**OSPF configuration.** Day 5 teaches the link-state idea; the cloud speaks BGP, not
OSPF, to anything you configure. Hands-on OSPF is vendor-CLI practice.

**QoS (queuing, marking, shaping).** AWS gives you no queues to configure. You meet it
as bandwidth limits and congestion, which Day 3's congestion section covers.

**SD-WAN.** A product category built from tunnels and BGP, both of which you lab.

**Multicast.** A VPC does not carry it. Transit Gateway multicast is a niche feature
named on Day 1 and not drilled.

**Cloud WAN, VPC Lattice, IPAM.** Managed control planes. They change who writes the
route tables, not what a packet looks like, so a wire-level course has little to add.

**SNMP, network automation.** Named in the fundamentals table. They are tooling topics, not packet-level protocols you debug in a cloud network. (DHCP is no longer skipped: Day 0 covers it.)

### Closing a gap later, if the job asks

One line each, and the cheapest path from here.

- **Wireless:** read a one-hour 802.11 capture in Wireshark (a public pcap with
  beacons, association and a 4-way handshake) and trace the management frames.
- **STP:** in `netlab`, build three bridges in a triangle with `ip link add type
  bridge`, set `stp_state 1` on each, and watch `bridge link` for the blocked port.
  Then remove STP and watch the broadcast storm in `tcpdump`.
- **OSPF:** run FRR `ospfd` in three namespaces joined by veth pairs, as Day 5 does for
  `bgpd`, and compare `show ip ospf neighbor` with the BGP session states.
- **QoS:** apply `tc qdisc add dev <if> root netem delay 50ms` plus `tbf` on a veth and
  measure the throughput change with `iperf3`.
- **SD-WAN:** take your Day 6 GRE or IPsec tunnels, run two of them to one peer, and
  steer traffic between them with BGP local preference.
- **Multicast:** join a group with `socat` on two namespaces over a bridge, with
  `ip maddr` and IGMP snooping (`bridge` `mcast_snooping`) toggled.
- **Cloud WAN, VPC Lattice, IPAM:** build one of each in a scratch account from the
  console and read the generated routes, service networks and allocations; teardown the
  same day.
