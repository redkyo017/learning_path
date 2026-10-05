# Network Engineering Mastery

A 2-hour orientation day (Day 0) plus a 7-day, 3 h/day path (about 23 hours in all) that rebuilds the protocol-level model of
networking underneath the tools you already operate. It is for a senior engineer who
works daily with AWS ECS, EC2, VPCs, Transit Gateway, VPN, PrivateLink and Route 53
Resolver, learned networking theory at university, and now runs on habit. Each day
draws a header or state machine from memory, builds the thing from bare network
namespaces in one local Docker container, proves it in a capture, breaks it with no
explanation, and ends by naming the AWS construct that hides it: "X in AWS is Y on
the wire". About 70% of the time goes to protocol theory and proof, and about 30% to
AWS mapping. See `STRATEGY.md` for the full reasoning behind this design.

## Prerequisites

- Docker Desktop for Mac, Apple Silicon build. The `netlab` image needs about 2 GB of
  free disk.
- Nothing else for Days 1-7. Every core lab runs inside one privileged container
  (Ubuntu 24.04, `NET_ADMIN`), and no AWS account is touched.
- **Only for the optional Day 4 AWS lab** (`aws_lab/day04/`): an AWS CLI profile named
  `sandbox` and Terraform 1.6 or later. Skip this and you lose nothing from the core
  path.

## Bring-up

```bash
cd network_engineering_mastery/labs/netlab
docker compose -p netlab up -d --build
docker compose -p netlab exec netlab bash      # your shell for every lab
```

The compose project name is fixed at `netlab`. The course root is bind-mounted into the
container at `/course`, so every lab command below runs from `/course` inside the
container. If a lab script is run on the macOS host by mistake, it prints these two
commands and exits with status 2. See `labs/netlab/README.md` for the image contents and
bring-down.

## The day map

Day 0 is the orientation day: the map of how a laptop reaches a server (modem, router, ISP, route table, DHCP, the OSI and TCP/IP models). Days 1-7 each zoom into one hop of it. Do Day 0 first, in about 2 hours.

| Day | Concept core | Lab | Break | AWS construct emulated | Content | Lab dir |
|---|---|---|---|---|---|---|
| 0 | The map: devices, last mile, ISP and Internet structure, DHCP, first routing table, OSI vs TCP/IP | Five namespaces `lap`, `hr`, `isp`, `transit`, `srv`; DHCP by `dnsmasq`; capture DORA, read routes, traceroute, watch the double NAT | The DHCP server dies (laptop falls to 169.254); the ISP loses its CGNAT rule | VPC DHCP option sets and DNS at +2; IGW 1:1 NAT vs NAT Gateway; AWS as an AS | `content/day00.md` | `labs/day00/` |
| 1 | L2 and the wire: Ethernet frame, ARP, bridge, MAC learning, 802.1Q | Two namespaces, a veth pair, then a Linux bridge with three ports; capture ARP, add a VLAN tag | Duplicate MAC on two ports; a stale permanent neighbour entry | Hypervisor answers ARP, no broadcast in a VPC (ENI move replaces VRRP) | `content/day01.md` | `labs/day01/` |
| 2 | L3: IPv4 and IPv6 headers, CIDR, longest-prefix match, ICMP, MTU, PMTUD | Two routers h1 - r1 = r2 - h2 with a 1400-MTU link between them; `ip route get`, traceroute decoded, frag-needed with DF | A more-specific route that hijacks traffic; frag-needed dropped (MTU black hole) | VPC router and MTU tiers (jumbo 9001 inside, 1500 at the edge <!-- fact-checked 2026-10-05 -->) | `content/day02.md` | `labs/day02/` |
| 3 | L4: TCP header, 11-state machine, retransmit and RTO, congestion control, UDP | One connection captured and annotated; `tc netem` loss and delay; `ss -ti` | Filtered port 8080 (timeout, not RST); `tc netem` loss and delay; the load balancer rewriting the client source (SNAT). In Prove: port exhaustion, idle-timeout RST | NLB idle timeout and client-IP preservation (an `lb` namespace DNATs a VIP) | `content/day03.md` | `labs/day03/` |
| 4 | NAT, conntrack, netfilter hooks, stateful vs stateless filtering | A hand-written stateful nftables policy plus masquerade for a two-LAN firewall + NAT topology | Asymmetric return path (dropped as INVALID); lost masquerade. Conntrack-full is theory and an exercise | Security group = conntrack; two-AZ inspection with appliance mode (`labs/day04/inspection.sh`) | `content/day04.md` | `labs/day04/` |
| 5 | Routing protocols and BGP: FSM, path attributes, best-path order, route policy | Four FRR routers (r1–r4) in namespaces; steer with local-pref, AS-path prepend and MED | Wrong peer ASN (session stuck in Active); a static route that beats BGP. In Prove: a /25 more-specific | TGW route tables as policy-routing tables (`labs/day05/vrf.sh`); VPN and Direct Connect BGP | `content/day05.md` | `labs/day05/` |
| 6 | Overlays and names: VXLAN, GENEVE, IPsec ESP, DNS resolution, split-horizon | VXLAN tunnel with outer and inner headers captured; an unbound forwarder with split-horizon | Overlay MTU black hole; resolver pointed at the public view. In Prove: TTL and negative caching | GWLB as GENEVE (`labs/day06/geneve.sh`); Route 53 Resolver endpoints as unbound forwarders | `content/day06.md` | `labs/day06/` |
| 7 | Capstone: one packet, end to end, then a timed gauntlet | The Day 1-6 path rebuilt as one topology; captures at three points; `gauntlet.sh` | Five unseen incidents, 20 minutes each, no hints | The full ECS, TGW, VPN and on-prem path | `content/day07.md` | `labs/day07/` |

Day 0 is a single 2-hour block (45 minutes of model, 60 of lab, 15 of exercises). Each of Days 1-7 splits into four blocks: about 60 minutes of model, 60 minutes of build and
capture, 30 minutes of break and diagnose, and 30 minutes of AWS mapping plus the local
emulation. Day 7 replaces the break block with the 90-minute gauntlet. The only AWS lab is
the optional one in `aws_lab/day04/`.

## The daily loop

Five steps, every day (Day 0 follows the same loop at 2 hours). Full reasoning for each is in
[`STRATEGY.md`](STRATEGY.md#the-daily-loop).

1. Draw it first. Draw today's header or state machine from memory, then correct it.
2. Build it from nothing. Interfaces, bridges, routes and NAT by hand, in namespaces.
3. Prove it in a capture. No claim counts without a `tcpdump` line, a route lookup or a
   conntrack entry.
4. Break, then diagnose from evidence. Run `break.sh` and write the chain in
   `journal.md` before any repair.
5. Name the AWS construct. End with "X in AWS is Y on the wire" in `journal.md`.

The mistakes each day warns about are in
[`STRATEGY.md`](STRATEGY.md#the-eight-mistakes).

## How a lab works

Every lab command runs inside `netlab`, from `/course`. `journal.md` is one shared file
at the course root, never a file inside `labs/dayNN/`.

```
bash labs/dayNN/topo.sh up       # builds the topology; safe to re-run
# explore: capture, read tables, map every field back to the header you drew
bash labs/dayNN/break.sh         # injects the fault, no explanation, prints the symptom
# write the evidence chain in journal.md, before touching the fix
# fix it
bash labs/dayNN/verify.sh        # PASS (exit 0), FAIL (exit 1), or not up (exit 2)
bash labs/dayNN/topo.sh down     # removes every namespace and daemon the day created
```

`verify.sh` reports each check on its own line, so a partial fix shows which fault is
still live. `SOLUTION.md` in each lab directory holds the full chain of evidence, not
only the fix. Read it after your own attempt, or after `verify.sh` tells you the repair
did not take. Each `labs/dayNN/README.md` opens with an "At a glance" block giving where
it runs, the commands, the time and the success signal.

Some days add a local emulation script that rebuilds an AWS construct from Linux
primitives. They run in the same container, from `/course`:

| Day | Script | What it emulates |
|---|---|---|
| 4 | `bash labs/day04/inspection.sh up\|asym\|appliance\|down` | Two-AZ inspection: asymmetric flows die as INVALID, then appliance mode pins both directions to one firewall |
| 5 | `bash labs/day05/vrf.sh up\|leak\|down` | TGW route tables as policy-routing tables (VRF-lite) in one `tgw` namespace: association, propagation, prod/dev isolation |
| 6 | `bash labs/day06/geneve.sh up\|down` | GWLB as a GENEVE interface on UDP 6081 <!-- fact-checked 2026-10-05 --> |

Day 7 uses `bash labs/day07/gauntlet.sh` to deliver the five incidents. Its answers are in
`labs/day07/ANSWERS.md`. Read them only after your own diagnosis.

## Cost

Every lab is local and costs $0. The one exception is the optional Day 4 AWS lab in
`aws_lab/day04/`, which costs about $0.60 per hour in ap-southeast-1 (six NAT gateways and three TGW attachments dominate; before data transfer) <!-- fact-checked 2026-10-05 --> while it runs (a Transit
Gateway with three attachments, two small firewall instances and two small test instances).

**Rule:** destroy it the same day with `terraform destroy`, then run
`../aws_network_components/scripts/sweep.sh` to confirm nothing is left billing.

**Why only one AWS lab.** This course follows a local-first rule: a concept is labbed
locally wherever Linux can reproduce it, and gets an AWS lab only where it cannot. Linux
namespaces reproduce L2, routing, NAT, conntrack, BGP, policy-routing tables (VRF-lite), VXLAN and GENEVE faithfully,
so those are proved locally for free. TGW per-AZ path selection and the `appliance_mode`
flag have no local equivalent, so that one case gets an AWS lab. For general AWS
hands-on, each day's "Where AWS hides this" section points to the sibling
`aws_network_components` day that already labs the construct.

## Teardown

At the end of each day:

```bash
bash labs/dayNN/topo.sh down        # inside netlab, from /course
```

Before you close out for the day, run this on the macOS host, from the course root:

```bash
bash labs/verify-teardown.sh
```

It confirms no `netlab` container is left (the namespaces die with it). To remove the
container yourself, run `docker compose -p netlab down` from `labs/netlab/`. After the
Day 4 AWS lab, also run `terraform destroy` and
`../aws_network_components/scripts/sweep.sh`.

## Reference material

| File | What it is |
|---|---|
| `STRATEGY.md` | The header-is-truth doctrine, the daily loop, the eight mistakes, rejected approaches |
| `COVERAGE.md` | Concepts mapped to CCNA/Network+ fundamentals and the ANS-C01 domains, each tied to a day or marked skipped with a reason |
| `content/GLOSSARY.md` | Plain-English terms, alphabetical |
| `content/primers/headers.md` | Every header as ASCII art, with the debugging fields marked |
| `content/primers/subnet-math.md` | The mental CIDR method plus 30 drills with answers |
| `content/primers/tcpdump-filters.md` | Capture recipes and BPF filters for each day |
| `content/primers/bgp-best-path.md` | The best-path order, FRR and AWS route preference side by side |

TLS and certificates are not repeated here. See `../network_certificates_and_more/`. For
ALB and NLB feature depth, see `../aws_computing_loadbalancing_communication_components/`.
For WAF, Shield and CloudFront, see `../aws_security_components/`.
