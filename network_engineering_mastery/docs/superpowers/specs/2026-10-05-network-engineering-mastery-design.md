# Network Engineering Mastery — Design Spec

**Date:** 2026-10-05
**Location:** `network_engineering_mastery/`
**Duration:** 7 days, 3 h/day (21 h total)
**Path type:** Applied / engineering. Every lab is local Docker, except one optional AWS
lab (Day 4, TGW appliance mode), kept only because that behaviour exists nowhere but AWS.
**Sibling courses:** `linux_ops_mastery/` (box-level ops), `aws_network_components/` (AWS constructs)

## Purpose & Goals

The learner is a senior software engineer who works daily with AWS ECS/EC2 and an
integration-platform network (VPCs, Transit Gateway, VPN, PrivateLink, Route 53
Resolver). They learned networking theory at university. Since then it has decayed
into habit: they can operate the tools but can no longer rebuild the model underneath
them. Two existing courses sit either side of this gap. `aws_network_components`
teaches the AWS constructs, and `linux_ops_mastery` Day 6 teaches reading the network
from one box. Neither one rebuilds the protocols.

This course rebuilds the protocol-level model, from L2 up through routing protocols
and overlays. Every concept is proven on the wire in a local lab, then named as the
AWS construct that hides it. The weighting is deliberate: about 70% protocol theory
and proof, and about 30% AWS mapping and work application. AWS networking is
TCP/IP behind an API, so a learner who owns the protocols can reason about any AWS
construct, including ones this course never names.

Mastery means the learner can explain, predict and diagnose any packet's path through
a Linux host or through AWS from evidence (a capture, a table, a counter), never from
memory of what a tool usually prints.

## Success Criteria

By the end of Day 7 the learner, without notes, can:

1. Draw the Ethernet, ARP, IPv4, IPv6, ICMP, TCP, UDP and VXLAN headers, and name the
   fields that matter for debugging along with what each one reveals.
2. Do CIDR and subnet arithmetic mentally (split, summarize, test containment), and
   resolve longest-prefix match across overlapping route tables.
3. Walk the TCP state machine. From a capture, distinguish a RST from a timeout,
   identify retransmissions and window stalls, and explain a TIME_WAIT pile-up.
4. Build a two-subnet routed network with NAT from bare network namespaces, and write
   a stateful nftables policy for it by hand.
5. Run BGP between FRR routers and steer traffic with local-preference, AS-path
   prepending and MED, predicting the winner from the best-path order before checking.
6. Explain the AWS packet path through SG, NACL, NAT Gateway, TGW route tables,
   Site-to-Site VPN with BGP, GWLB and Route 53 Resolver in protocol terms.
7. Diagnose 5 previously unseen network incidents within a 20-minute budget each,
   using captures and kernel tables only.

## Constraints & Environment

- **Host:** macOS on Apple Silicon with Docker Desktop. All core labs run locally and cost nothing.
- **Lab runtime:** one privileged `netlab` container (Ubuntu 24.04) with `NET_ADMIN`.
  Each day's topology is built from bare network namespaces inside it. It ships iproute2,
  nftables, conntrack-tools, tcpdump, tshark, iputils, traceroute, `tc` (iproute2),
  iperf3, FRR, unbound, curl, dnsutils, python3 and neovim. IPsec is shown with static
  `ip xfrm` SAs (ESP on the wire, no IKE daemon); IKE is taught in theory.
- **Local-first rule:** every concept is labbed locally. An AWS lab exists only where
  the technology's behaviour cannot be reproduced on Linux. Under this rule the only
  AWS lab is Day 4 (TGW per-AZ path selection and appliance mode). For general AWS
  hands-on, "Where AWS hides this" points to the sibling `aws_network_components` day
  that already labs it.
- **The AWS lab (optional):** profile `sandbox`, region `ap-southeast-1`, Terraform
  ≥ 1.6. A small root at `aws_lab/day04/` that reuses
  `../../../aws_network_components/terraform/modules/vpc` by relative path. It states
  its hourly cost and ends with `terraform destroy` plus
  `aws_network_components/scripts/sweep.sh`.
- **Authoring rules:**
  - No real credentials, account IDs or keys in any file; ship `*.tfvars.example`.
  - Subagents run no git commands.
  - The AWS lab is `terraform validate`d during authoring, never applied.
  - Local Docker labs **are** live-verified during authoring. They are free, local and disposable.
- **Git:** authoring happens on the scratch branch
  `authoring/network_engineering_mastery` (approved by the learner for this build).
  WIP commits exist only so reviews can use diffs. Nothing is ever pushed. Before
  handoff the branch is torn down with the `skill.md` Phase 0 sequence, and the course
  is left untracked on `master` for the learner to commit.
- **Out-of-folder edits:** exactly two. Each is a one-line "next course" pointer, in
  `aws_network_components/README.md` and in `linux_ops_mastery/README.md`.
- **Not repeated, linked instead:**
  - TLS and certificates → `network_certificates_and_more/`
  - ALB/NLB feature depth → `aws_computing_loadbalancing_communication_components/`
  - WAF, Shield and CloudFront → `aws_security_components/`

## Strategy (the core design decision)

**"The header is the truth."** This is the network form of `linux_ops_mastery`'s "the
file is the truth". Every protocol is a header plus a state machine. A learner who can
draw the header and walk the state machine can predict any tool's output and any
failure mode. A learner who memorized tool output owns a vocabulary that fails on the
first unfamiliar symptom.

**The daily loop** (the same five steps every day):

1. **Draw it first.** On a blank page, draw today's header or state machine from
   memory before reading anything. Then correct it against the content. Retrieval
   before review is the fastest path back to decayed knowledge.
2. **Build it from nothing.** Create interfaces, bridges, routes, NAT and peers by
   hand in network namespaces. AWS networking is these primitives behind an API.
3. **Prove it in a capture.** No claim counts until a `tcpdump`/`tshark` line, a
   routing-table lookup or a conntrack entry confirms it.
4. **Break, then diagnose from evidence.** `break.sh` injects a fault with no
   explanation. The learner writes the chain of evidence in `journal.md` *before*
   fixing anything.
5. **Name the AWS construct.** Each concept ends as a sentence of the form "X in AWS is
   Y on the wire". Examples: "a security group is conntrack", "a TGW route table is a
   VRF", "GWLB is GENEVE".

**Why approach A (bottom-up through the stack, proven by capture) won:**

- *Rejected: follow-one-packet as the main spine.* It is work-shaped, but it delivers
  theory in hop order rather than dependency order, which fragments subnetting and
  TCP congestion control. It is kept as the Day 7 capstone instead.
- *Rejected: incident-first* (the `linux_ops_mastery` style). It is strong for
  reinforcement but wrong for a learner whose stated gap is forgotten concepts.
- *Rejected: extending either existing course.* Each has a coherent spine (the four
  kernel truths; one growing AWS topology), and protocol days would break it.

**The eight mistakes that waste 80% of learners' time** (each gets a callout on the day
where it bites):

1. Memorizing the OSI model instead of the actual headers. (Day 1)
2. Learning tool flags instead of the protocol underneath. (Day 1)
3. Treating AWS networking as magic separate from TCP/IP. (Day 2)
4. Debugging without a capture. (Day 3)
5. Confusing a timeout with a reset: they mean opposite things. (Day 3)
6. Assuming a filter is stateless, or stateful, without checking. (Day 4)
7. Assuming routing is symmetric. (Day 4, Day 5)
8. Blaming DNS by reflex, or never testing it at all. (Day 6)

## Curriculum

Daily block structure (3 h):
- **Model:** 60 min
- **Prove:** build and capture, 60 min
- **Break & diagnose:** 30 min
- **AWS map + local emulation of the AWS construct:** 30 min

Exercises are mainly theory drills (subnet math, header decoding, best-path puzzles,
capture reading), because the learner's stated gap is concepts.

### Day 1 — L2 and the wire
- **Concepts:**
  - Encapsulation as nested headers.
  - The Ethernet II frame: dst/src MAC, EtherType, FCS.
  - Unicast, broadcast and multicast MACs.
  - ARP request/reply and the neighbour table with its states (REACHABLE, STALE, FAILED).
  - The bridge forwarding database and MAC learning, flooding, broadcast domains.
  - 802.1Q VLAN tag.
- **Prove:** two netns, a veth pair, then a Linux bridge with three ports. Capture an
  ARP exchange; watch `ip neigh` and `bridge fdb` populate; add a VLAN sub-interface
  and see the tag in the capture.
- **Break:** duplicate MAC on two ports; a stale static neighbour entry.
- **AWS:**
  - A VPC has no broadcast and no real L2.
  - ARP is answered by the hypervisor (Nitro), so ARP spoofing and gratuitous ARP failover do not work.
  - What this implies for ENIs, secondary IPs and floating-IP designs; why "move an ENI" replaces VRRP.
  - No AWS lab: the sibling `aws_network_components` Day 1 covers ENIs hands-on.

### Day 2 — L3 addressing and forwarding
- **Concepts:**
  - IPv4 header field by field (TTL, protocol, DF bit, ID, checksum); IPv6 header and extension-header chain.
  - CIDR and subnet arithmetic, summarization, longest-prefix match.
  - ICMP types that matter: echo, unreachable codes, time-exceeded, frag-needed / packet-too-big.
  - How traceroute works; fragmentation, MTU, PMTUD and its black-hole failure.
  - IPv6 essentials: SLAAC, link-local, NDP replacing ARP.
- **Prove:** a router namespace between two subnets with `ip_forward`. Resolve
  lookups with `ip route get`; decode traceroute hop by hop from the capture;
  provoke frag-needed with DF set.
- **Break:** ICMP frag-needed dropped (MTU black hole); a more-specific route that hijacks traffic.
- **AWS:**
  - The VPC router (the "+1" address) and the 5 reserved IPs per subnet.
  - Main vs custom route tables evaluated by longest prefix.
  - The MTU tiers: 9001 inside a VPC, 1500 through the IGW and over Site-to-Site VPN,
    8500 across TGW and inter-Region peering. Exact figures are confirmed in the
    fact-check pass.
  - Egress-only IGW for IPv6.
  - **Local emulation (Prove):** the MTU tiers. Hosts and router get a jumbo 9001
    "VPC" link plus a 1500 "edge" link; `tracepath` shows the pmtu dropping at the edge.

### Day 3 — L4: TCP and UDP
- **Concepts:**
  - TCP header (ports, seq/ack, flags, window, options: MSS, SACK, window scale, timestamps).
  - The 11-state machine.
  - Three-way handshake and four-way close; who enters TIME_WAIT and why.
  - Retransmission and RTO; flow control vs congestion control (slow start, AIMD, CUBIC, BBR at concept level).
  - RST semantics vs silent drop.
  - Ephemeral ports and the 4-tuple; UDP and why it has no state.
- **Prove:** capture one full connection and annotate every packet. Use `tc netem`
  loss/delay to watch retransmits and RTO back-off; watch `ss -ti` cwnd and rtt change.
- **Break:** connection refused vs filtered (RST vs timeout); ephemeral port exhaustion; an idle connection killed mid-stream.
- **AWS:**
  - NAT Gateway connection limits per destination.
  - NLB idle timeout (350 s TCP default) and ALB keep-alive mismatch with backends.
  - Client-IP preservation and proxy protocol.
  - Why a dropped idle flow shows up as an RST from the AWS side.
  - **Local emulation (topology):** an `lb` namespace owns a VIP and DNATs it to the
    server, the way an NLB does, with a short conntrack established-timeout and a TCP
    RST for packets of an expired flow. Idle past the timeout and the next send gets an
    RST, which is the NLB/NAT GW idle-timeout signature. Switch to SNAT mode and the
    server sees `lb`'s address instead of the client's (ALB-style vs NLB client-IP
    preservation).

### Day 4 — NAT, conntrack and filtering
- **Concepts:**
  - SNAT, DNAT and masquerade; the conntrack tuple and states (NEW, ESTABLISHED, RELATED, INVALID).
  - netfilter hook order (prerouting, input, forward, output, postrouting).
  - Stateful vs stateless filtering; asymmetric routing and why stateful firewalls drop it.
  - conntrack table limits.
- **Prove:** write by hand a stateful nftables forward policy plus masquerade for the
  Day 2 topology. Read `conntrack -L`/`-E` while a connection lives.
- **Break:** asymmetric return path dropped as INVALID; conntrack table full; a stateless rule missing the return ephemeral range.
- **AWS:**
  - Security group = conntrack; NACL = stateless with an explicit return range.
  - Untracked and tracked SG connections.
  - AWS Network Firewall; centralized inspection VPC; TGW appliance mode as the fix for asymmetric inspection.
  - **Local emulation (Prove):** a two-AZ inspection layout. Spokes `a` and `b` sit
    behind a `tgw` namespace with two stateful firewalls, `fwa` and `fwb`.
    `inspection.sh asym` sends a→b through `fwa` and b→a through `fwb`, so flows die
    as INVALID. `inspection.sh appliance` pins both directions to one firewall, which
    is what appliance mode does.
  - **AWS lab (the course's only one, optional, ~60 min, ≈ $0.60/h):** the same
    pattern on real TGW. It is kept because TGW's per-AZ path selection and the
    `appliance_mode` flag have no local equivalent. It uses three `vpc` module
    instances plus raw TGW resources (the sibling `tgw` module is hard-wired to two
    VPCs). The firewall EC2 runs the learner's own Day 4 nftables policy. Reproduce the
    asymmetric drop with `appliance_mode = false`, then fix it.

### Day 5 — Routing protocols and BGP
- **Concepts:**
  - Static vs dynamic routing; distance-vector vs link-state (concept, with OSPF named).
  - Administrative distance / route preference.
  - BGP: TCP 179 session, the FSM (Idle → Established), eBGP vs iBGP, path attributes.
  - The best-path selection order; ECMP; route policy (prefix-lists, route-maps).
  - Prefix length beats every attribute.
- **Prove:** three FRR routers in namespaces. Establish eBGP, advertise prefixes, then
  steer with local-pref, AS-path prepend and MED. Predict each winner before
  `show ip bgp`, and confirm it with a capture of UPDATE messages.
- **Break:** session stuck in Active; an accidental more-specific advertisement hijacking traffic; failover that never happens because of a static route.
- **AWS:**
  - Site-to-Site VPN and Direct Connect use BGP.
  - The AWS route-preference order (longest prefix → static over propagated → DX over VPN → AS-path).
  - TGW route tables as VRFs; association vs propagation; segmentation.
  - **Local emulation (Prove):** "TGW in a box". A `tgw` namespace holds
    policy-routing tables `rt-prod`, `rt-dev` and `rt-shared` (VRF-lite; Docker
    Desktop's kernel has no VRF device). `ip rule iif <attachment> lookup <table>` =
    association. Adding a route into another table = propagation. Show that prod and dev are isolated but both reach shared.

### Day 6 — Overlays and names
- **Concepts:**
  - Tunneling as encapsulation (IP-in-IP, GRE, VXLAN, GENEVE) and its MTU tax.
  - IPsec IKE phases, ESP, NAT-T on UDP 4500.
  - DNS: the resolution walk, recursive vs authoritative, forwarding, caching and TTL, negative caching.
  - Split-horizon; `search` / `ndots` behaviour.
- **Prove:** a VXLAN tunnel between two namespaces (capture the outer and inner
  headers); an unbound forwarder with a split-horizon zone and a conditional forward.
- **Break:** overlay MTU drop; NXDOMAIN from querying the wrong resolver; a stale cached answer.
- **AWS:**
  - VPN tunnels as IPsec; GWLB as GENEVE carrying the original packet.
  - Route 53 Resolver inbound/outbound endpoints and forwarding rules; private hosted zones as split-horizon.
  - ECS `awsvpc` (ENI per task, trunking) and EKS VPC CNI (prefix delegation, IP exhaustion) as "L3 without an overlay".
  - **Local emulation (Prove):**
    - Resolver endpoints as unbound conditional forwarders. A "VPC resolver" forwards
      `onprem.corp` to an on-prem server (the outbound rule). The on-prem server
      forwards `corp.internal` back (the inbound endpoint).
    - GWLB as a Linux `geneve` interface (UDP 6081) carrying the untouched original
      packet to an "appliance" namespace. Capture both headers.

### Day 7 — Capstone: one packet, end to end
- **Model (60 min):** trace one request with every header and table hit named at every
  hop: ECS task → DNS → VPC router → TGW → VPN/BGP → on-prem API. No new theory.
- **Prove (30 min):** the same path rebuilt locally as one namespace topology. Capture at three points.
- **Gauntlet (90 min):** 5 unseen incidents, 20 min each, delivered by `gauntlet.sh`,
  drawn from Days 1–6 failure classes. Diagnosis from captures and tables only;
  answers in `ANSWERS.md`.
- **AWS readout:** a table mapping each local hop to its AWS construct and its failure signature.

## Directory Layout

```
network_engineering_mastery/
├── README.md                 # quickstart, day map, daily loop, cost table, teardown
├── STRATEGY.md               # header-is-truth doctrine, 5-step loop, 8 mistakes
├── COVERAGE.md               # concept map vs CCNA/Network+ fundamentals and ANS-C01
│                             #   domains; every item mapped to a day or SKIPPED + reason
├── journal.md                # template + one entry per day
├── content/
│   ├── GLOSSARY.md           # plain-English terms, alphabetical
│   ├── day01.md … day07.md
│   └── primers/
│       ├── headers.md        # every header as ASCII art, debug fields marked
│       ├── subnet-math.md    # mental CIDR method + 30 drills with answers
│       ├── tcpdump-filters.md# capture recipes and BPF filters for each day
│       └── bgp-best-path.md  # best-path order, FRR and AWS route-preference side by side
├── labs/
│   ├── netlab/               # Dockerfile, docker-compose.yml, README (bring-up, down)
│   ├── lib/common.sh         # netns helpers (ns_add, veth_link, pass/fail output)
│   ├── day01 … day06/        # README.md, topo.sh {up|down}, break.sh, verify.sh,
│   │                         #   SOLUTION.md, teardown.md
│   ├── day07/                # topo.sh, gauntlet.sh, ANSWERS.md, README.md, teardown.md
│   └── verify-teardown.sh    # no namespaces, no netlab container left running
├── aws_lab/
│   └── day04/                # the only AWS lab (optional): 3 VPCs, TGW with an
│                             #   appliance_mode toggle, nft firewall EC2 per AZ;
│                             #   main.tf, variables.tf, outputs.tf, user_data.sh.tftpl,
│                             #   terraform.tfvars.example, README.md (cost + teardown)
└── docs/superpowers/
    ├── specs/2026-10-05-network-engineering-mastery-design.md
    └── plans/2026-10-05-network-engineering-mastery-plan.md
```

Lab contract (same as `linux_ops_mastery`):
- Commands run from the course root.
- `topo.sh up` builds the topology; `break.sh` injects the fault with no explanation.
- `verify.sh` gives an objective PASS or FAIL with a non-zero exit on FAIL.
- `SOLUTION.md` holds the full chain of evidence, not only the fix.
- `teardown.md` calls `topo.sh down` and `labs/verify-teardown.sh`.

## Content Day Skeleton

```markdown
# Day N — <Title>

## Why this matters
<one concrete work incident this day's concepts explain>

## Draw it first
<blank-page recall prompt: the header / state machine to draw before reading on>

## Core concepts
<theory refresh: headers as ASCII, state machines, algorithms, worked numbers>

## Prove it on the wire
<lab walkthrough: build → capture → map each captured field back to the model>

## Lab
See `labs/dayNN/`. The goal: <one line>. Success signal: <one line>.

## Where AWS hides this
<construct mapping as "X in AWS is Y on the wire" lines, work pain points,
the local emulation of the AWS construct, a pointer to the sibling
`aws_network_components` day that labs it on AWS, and (Day 4 only) `aws_lab/day04/`>

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
… (8–12 per day, mostly theory drills)

## Anti-patterns / Common mistakes
<2–4 bullets, including the day's "80% mistake" callout>

## Teardown
<`bash labs/dayNN/topo.sh down`, `bash labs/verify-teardown.sh`; Day 4 AWS lab only:
`terraform destroy` + `aws_network_components/scripts/sweep.sh`>
```

Target size is about 300–450 lines per day file.

## Verification

1. **Static, per task:**
   - `bash -n` on every `.sh`.
   - `terraform fmt -check` and `terraform validate` (with `-backend=false` init) on `aws_lab/day04`.
   - A section sweep: every day file has all skeleton headings, and every exercise has
     both `**Hint:**` and `**Solution sketch:**`.
   - Every lab directory has README, SOLUTION (or ANSWERS) and teardown.
   - All checks use `/usr/bin/grep`. The credential and account-ID sweep runs `-r` over
     the whole course tree, not only `content/`.
2. **Live lab verification (local, free):** for each of Days 1–6 inside `netlab`:
   `topo.sh up` → `verify.sh` (must PASS: every `verify.sh` checks the healthy
   state, so a fresh topology passes) → `break.sh` → `verify.sh` (expect FAIL) → apply the `SOLUTION.md`
   fix → `verify.sh` (expect PASS) → `topo.sh down` → `verify-teardown.sh`. For
   Day 7, each gauntlet incident is injected and its documented answer confirmed.
3. **Environment probe first (gates all lab tasks):** confirm that the Docker
   Desktop kernel supports netns, veth, bridge with VLAN filtering, VXLAN, GENEVE,
   policy-routing tables (VRF device absent: ruled VRF-lite), nftables NAT, conntrack (with per-netns `nf_conntrack_tcp_loose` and
   established-timeout sysctls), `tc netem`, and one FRR instance per netns. Any unsupported feature
   gets a documented fallback before lab tasks start. The Day 5 fallback is a compose
   file of `frrouting/frr` containers.
4. **Fact-check pass:** one reviewer focused on protocol accuracy (RFC 9293 TCP,
   RFC 4271 BGP best-path, RFC 7348 VXLAN, RFC 8926 GENEVE) and on current AWS
   figures quoted in the content (NLB idle timeout, NAT Gateway connection limits,
   TGW MTU, reserved IPs, route-preference order).
5. **Final review:** one whole-course review pointed at a file manifest, not full
   contents.

## Authoring Phases

- **Spec and plan:** main model.
- **Content, labs, primers and the AWS lab:** Sonnet subagents (learner preference), with
  independent day tasks dispatched in parallel. Fix rounds and live verification run
  in the main session.
- **Checkpoints:** a WIP commit on the scratch branch after each completed task, taken
  only when no implementer is running.
