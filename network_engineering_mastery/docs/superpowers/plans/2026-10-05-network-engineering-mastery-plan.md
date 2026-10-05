# Network Engineering Mastery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the 7-day, 21 h `network_engineering_mastery/` course. It rebuilds
protocol-level networking (L2 → BGP → overlays), proves each concept with captures
in local network-namespace labs, and maps each concept onto AWS.

**Architecture:**
- **Content:** markdown day files follow the `skill.md` skeleton, plus a "Draw it first"
  section and a "Where AWS hides this" section.
- **Labs:** every lab runs inside one privileged `netlab` container. Each day's `topo.sh`
  builds bare network namespaces. `break.sh` injects faults; `verify.sh` checks the
  healthy state and exits 0 or 1.
- **Local first:** every AWS construct is also *emulated* locally: NLB-style DNAT with
  an idle timeout, two-AZ inspection, TGW route tables as policy-routing tables (VRF-lite), Resolver endpoints as
  forwarders, GWLB as GENEVE. The one AWS lab is `aws_lab/day04/` (optional): TGW
  appliance mode, whose per-AZ behaviour has no local equivalent.

**Tech Stack:** Ubuntu 24.04, iproute2, nftables, conntrack-tools, tcpdump/tshark,
`tc netem`, FRR 8.x (Ubuntu apt), unbound, python3, Docker Desktop (Apple Silicon),
Terraform ≥ 1.6 with hashicorp/aws ≥ 5.0.

**Spec:** `network_engineering_mastery/docs/superpowers/specs/2026-10-05-network-engineering-mastery-design.md`

## Global Constraints

### Files and layout
- All paths are relative to `network_engineering_mastery/` unless written otherwise.
- Day file headings are exactly these, in this order:
  `## Why this matters`, `## Draw it first`, `## Core concepts`, `## Prove it on the wire`,
  `## Lab`, `## Where AWS hides this`, `## Exercises`, `## Anti-patterns / Common mistakes`,
  `## Teardown`.
- Day files are 300–450 lines. Exercises: 8–12 per day. Each exercise is one numbered item
  containing both `**Hint:**` and `**Solution sketch:**`.
- Every lab dir has `README.md`, `SOLUTION.md` (Day 7: `ANSWERS.md`) and `teardown.md`.
  Each lab README opens with an `## At a glance` block giving: where it runs (inside
  `netlab`), the commands, time, and success signal.
- Out-of-folder edits: exactly one line appended to `aws_network_components/README.md`
  and one line to `linux_ops_mastery/README.md`, both in Task 11.

### Lab scripts
- Scripts run **inside** the netlab container from `/course` (the course root
  bind-mounted). Each one starts with `#!/usr/bin/env bash`, `set -euo pipefail`, then
  sources common.sh with this exact idiom:
  `. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"`
- Exit codes: `verify.sh` exits 0 for PASS, 1 for FAIL, 2 for "topology not up".
- Fault markers: `break.sh` writes the fault number to `/run/netlab/dayNN.fault`.
- Namespace names are lowercase and ≤ 8 chars. Interface names are ≤ 15 chars. All
  daemons a lab starts live inside a lab netns, so `topo_down` reaches them.

### Safety and content rules
- No real credentials, account IDs, keys or PSKs in any file. The one Terraform root
  (`aws_lab/day04`) ships `terraform.tfvars.example` only, with `aws_profile = "sandbox"` and
  `region = "ap-southeast-1"`.
- Subagents run no git commands, no `terraform apply`/`plan`, and no `docker` commands.
  The controller runs Docker live checks serially (Tasks 1, 3–9, 12), because all
  labs share one container and `topo_down` deletes every netns.
- Linking instead of repeating: TLS → `../network_certificates_and_more/`; ALB/NLB
  feature depth → `../aws_computing_loadbalancing_communication_components/`;
  WAF/Shield/CloudFront → `../aws_security_components/`.
- Every AWS figure quoted in content carries an inline `<!-- fact-check -->` comment the
  first time it appears in a file, so Task 12 can find each one.
- Prose voice matches `linux_ops_mastery/content/*.md`: second person, plain, concrete,
  no hype words ("simply", "just", "easy", "powerful").

## Review Focus

1. **`topo.sh up` run twice, or after a crashed run:** it must not error with
   "File exists". `up` calls `topo_down` first. *Test:* Task 1 Step 4 and each day's
   live check run `up` twice in a row.
2. **`verify.sh`/`break.sh` run before `topo.sh up`:** they must print
   "Topology for day NN is not up — run: bash labs/dayNN/topo.sh up" and exit 2, not
   produce a confusing ip error. *Test:* Task 1 Step 4 (`require_topo`) and each day's
   live check.
3. **Any script run on the macOS host instead of inside netlab:** it must print the two
   commands to enter the container and exit 2. *Test:* Task 1 Step 4 runs `verify.sh`
   on the host.
4. **Leftover daemons** (unbound, FRR, python http.server) after `topo.sh down`: none
   may survive. *Test:* every live check ends with `ps -e` showing none, and
   `verify-teardown.sh` exits 0.
5. **Partial fix** (one of two injected faults repaired): `verify.sh` must report each
   check on its own line and still FAIL. *Test:* each day's live check repairs one
   fault, then confirms FAIL, then repairs the other.

---

## File Structure

```
network_engineering_mastery/
├── README.md, STRATEGY.md, journal.md                        (Task 2)
├── COVERAGE.md                                               (Task 11)
├── content/day01..day07.md                                   (Tasks 3–9)
├── content/GLOSSARY.md, content/primers/{headers,subnet-math,tcpdump-filters,bgp-best-path}.md  (Task 10)
├── labs/netlab/{Dockerfile,docker-compose.yml,README.md,probe.sh,PROBE.md}  (Task 1)
├── labs/lib/common.sh, labs/verify-teardown.sh               (Task 1)
├── labs/day01..day06/{README.md,topo.sh,break.sh,verify.sh,SOLUTION.md,teardown.md}  (Tasks 3–8)
├── labs/day05/frr/{r1,r2,r3,r4}.conf                         (Task 7)
├── labs/day06/dns/{internal,public}.conf                     (Task 8)
├── labs/day07/{README.md,topo.sh,gauntlet.sh,ANSWERS.md,teardown.md}  (Task 9)
├── labs/day04/inspection.sh, labs/day05/vrf.sh, labs/day06/{geneve.sh,dns/onprem.conf}  (Tasks 6–8, local AWS emulations)
└── aws_lab/day04/{main.tf,variables.tf,outputs.tf,terraform.tfvars.example,user_data.sh.tftpl,README.md,.gitignore}  (Task 6, the only AWS lab)
```

Task order and parallelism:
- Task 1 runs first and gates all lab work.
- Task 2 can run alongside Task 1.
- Tasks 3–8 are independent of each other. Dispatch them in parallel (3 at a time); the
  controller live-checks each one serially as it completes.
- Task 9 depends on Tasks 7 and 8 (it reuses the FRR and unbound launch patterns).
- Task 10 depends on Tasks 3–9 (the glossary and primers are drawn from day content).
- Tasks 11–13 run last, in order.

---

### Task 1: netlab runtime, shared lab library, environment probe

**Files:**
- Create: `labs/netlab/Dockerfile`, `labs/netlab/docker-compose.yml`, `labs/netlab/README.md`, `labs/netlab/probe.sh`
- Create: `labs/lib/common.sh`, `labs/verify-teardown.sh`
- Create (controller, from the probe output): `labs/netlab/PROBE.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the `common.sh` functions every later lab uses, with these exact names:
  `require_netlab`, `require_topo DAY`, `ns_add NS…`, `veth NS_A IF_A NS_B IF_B`,
  `addr NS IF CIDR`, `route NS ARGS…`, `forwarding NS`, `bridge_ns NS BR IF…`,
  `bg NS NAME CMD…`, `frr_up NS CONF`, `vty NS CMD [CMD…]`, `topo_mark DAY`, `topo_down`, `symptom MSG`, `fault_set DAY N`,
  `fault_get DAY`, `check DESC CMD…`, `verify_finish DAY`.
  Lab state lives in `/run/netlab/`.
  PROBE.md records, for each feature, `OK` or `FALLBACK: <what to do>`.

- [ ] **Step 1: Write `labs/netlab/Dockerfile`**

```dockerfile
# netlab — one privileged box; every lab topology is built from bare network
# namespaces inside it. See labs/netlab/README.md.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
# No init system here: stop package postinst scripts from trying to start services.
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d
RUN apt-get update && apt-get install -y --no-install-recommends \
      iproute2 iputils-ping iputils-tracepath traceroute ethtool kmod procps less \
      tcpdump tshark nftables conntrack iperf3 netcat-openbsd curl dnsutils \
      frr unbound python3 neovim ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Marker that common.sh's require_netlab checks for.
RUN touch /.netlab && mkdir -p /run/netlab
WORKDIR /course
CMD ["sleep", "infinity"]
```

- [ ] **Step 2: Write `labs/netlab/docker-compose.yml`**

```yaml
# Network Engineering Mastery — the lab box.
#
#   cd network_engineering_mastery/labs/netlab
#   docker compose -p netlab up -d --build
#   docker compose -p netlab exec netlab bash      # every lab runs from here, in /course
#   docker compose -p netlab down
name: netlab
services:
  netlab:
    build: .
    # privileged: ip netns needs to mount /run/netns and remount /sys per
    # namespace; nft, tc and conntrack need NET_ADMIN on every namespace.
    privileged: true
    init: true
    hostname: netlab
    volumes:
      - ../..:/course          # course root; scripts and journal.md are shared with the host
    working_dir: /course
```

- [ ] **Step 3: Write `labs/lib/common.sh`**

```bash
#!/usr/bin/env bash
# Shared helpers for labs/dayNN/{topo,break,verify}.sh and labs/day07/gauntlet.sh.
# Sourced, never executed. Runs INSIDE the netlab container, from /course.
#
#   . "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
set -euo pipefail

STATE_DIR=/run/netlab
_CHECK_FAILS=0

require_netlab() {
  if [ ! -f /.netlab ]; then
    echo "This script runs inside the netlab container, not on your Mac." >&2
    echo "  cd network_engineering_mastery/labs/netlab && docker compose -p netlab up -d --build" >&2
    echo "  docker compose -p netlab exec netlab bash     # then re-run from /course" >&2
    exit 2
  fi
  mkdir -p "$STATE_DIR"
}

# require_topo 03  -> exit 2 unless labs/day03/topo.sh up has run.
require_topo() {
  require_netlab
  if [ ! -f "$STATE_DIR/day$1.up" ]; then
    echo "Topology for day $1 is not up — run: bash labs/day$1/topo.sh up" >&2
    exit 2
  fi
}

ns_add() { local ns; for ns in "$@"; do ip netns add "$ns"; ip -n "$ns" link set lo up; done; }

# veth h1 eth0 r1 eth1  -> a veth pair with one end in each namespace, both up.
veth() {
  ip link add "$2" netns "$1" type veth peer name "$4" netns "$3"
  ip -n "$1" link set "$2" up
  ip -n "$3" link set "$4" up
}

addr()  { ip -n "$1" addr add "$3" dev "$2"; }
route() { local ns="$1"; shift; ip -n "$ns" route "$@"; }

forwarding() {
  ip netns exec "$1" sysctl -qw net.ipv4.ip_forward=1
  ip netns exec "$1" sysctl -qw net.ipv6.conf.all.forwarding=1
}

# bridge_ns sw br0 p1 p2 p3  -> bridge br0 inside namespace sw, ports enslaved, all up.
bridge_ns() {
  local ns="$1" br="$2"; shift 2
  ip -n "$ns" link add "$br" type bridge
  ip -n "$ns" link set "$br" up
  local p; for p in "$@"; do ip -n "$ns" link set "$p" master "$br"; ip -n "$ns" link set "$p" up; done
}

# bg h2 web python3 -m http.server 8080  -> daemon inside h2, log in /run/netlab/web.log
bg() {
  local ns="$1" name="$2"; shift 2
  ip netns exec "$ns" setsid "$@" >"$STATE_DIR/$name.log" 2>&1 < /dev/null &
  echo $! > "$STATE_DIR/$name.pid"
}

topo_mark() { touch "$STATE_DIR/day$1.up"; }

# frr_up r1 labs/day05/frr/r1.conf  -> zebra + bgpd for namespace r1 (FRR pathspace = ns name).
frr_up() {
  local ns="$1" conf="$2" d
  mkdir -p "$STATE_DIR/frr-$ns"
  for d in zebra bgpd; do
    ip netns exec "$ns" /usr/lib/frr/$d -d -N "$ns" -A 127.0.0.1 -f "$conf" \
      -i "$STATE_DIR/frr-$ns/$d.pid"
  done
}

# vty r1 'configure terminal' 'router bgp 65001' 'neighbor 10.5.13.2 remote-as 65003'
# -> every argument after the namespace becomes one vtysh -c.
vty() {
  local ns="$1"; shift
  local args=() c; for c in "$@"; do args+=(-c "$c"); done
  ip netns exec "$ns" vtysh -N "$ns" "${args[@]}"
}

# Remove every lab namespace and every process inside one. Idempotent.
topo_down() {
  mkdir -p "$STATE_DIR"
  local ns pid
  for ns in $(ip netns list 2>/dev/null | awk '{print $1}'); do
    for pid in $(ip netns pids "$ns" 2>/dev/null); do kill -9 "$pid" 2>/dev/null || true; done
  done
  ip -all netns delete 2>/dev/null || true
  rm -rf /etc/netns/* "$STATE_DIR"/* 2>/dev/null || true
}

symptom() { printf '\nSYMPTOM: %s\n\nNothing else will be explained.\n' "$1"; }

fault_set() { echo "$2" > "$STATE_DIR/day$1.fault"; }
fault_get() { cat "$STATE_DIR/day$1.fault" 2>/dev/null || echo none; }

# check "h1 reaches h2" ip netns exec h1 ping -c1 -W1 10.1.0.2
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '  ok    %s\n' "$desc"
  else printf '  FAIL  %s\n' "$desc"; _CHECK_FAILS=$((_CHECK_FAILS + 1)); fi
}

verify_finish() {
  if [ "$_CHECK_FAILS" -eq 0 ]; then echo "PASS: day $1 is healthy."; exit 0; fi
  echo "FAIL: day $1 — $_CHECK_FAILS check(s) failed. Write the evidence chain in journal.md before fixing." >&2
  exit 1
}
```

- [ ] **Step 4: Write `labs/netlab/probe.sh`.** This is the test for this task. It runs
  one check per feature and prints `OK <feature>` or `MISSING <feature>: <stderr first
  line>`. It sources `common.sh`, calls `require_netlab` then `topo_down`, and exercises
  each feature in throwaway namespaces `pa`/`pb`:
  1. netns + veth + ping across them
  2. bridge with `vlan_filtering 1` and a VLAN on a port
  3. a VXLAN pair (`ip link add vx0 type vxlan id 100 local 10.99.0.1 remote 10.99.0.2 dstport 4789 dev e0`) with a ping across the overlay
  4. an nft `ip nat` table with a `masquerade` rule loaded in `pa`
  5. `conntrack -L` inside `pa`
  6. `tc qdisc add dev e0 root netem delay 50ms` and ping RTT ≥ 50 ms
  7. FRR per netns: `frr_up pa /run/netlab/pa.conf` and `frr_up pb /run/netlab/pb.conf`
     with a minimal eBGP config (AS 65001 ↔ 65002, `no bgp ebgp-requires-policy`), then
     poll `vty pa 'show bgp summary json'` for up to 30 s for state `Established`
  8. `unbound -d -c <minimal conf on 10.99.0.1:53>` via `bg pa`, then `dig @10.99.0.1` from `pb`
  9. `ip xfrm state add` with a static ESP SA in `pa`
  10. `mkdir -p /etc/netns/pb && echo nameserver 10.99.0.1 > /etc/netns/pb/resolv.conf`,
      then `ip netns exec pb cat /etc/resolv.conf` shows `10.99.0.1`
  11. policy-routing tables (VRF-lite; the VRF device is absent from Docker Desktop's
      kernel): a route only in table 10 plus an `ip rule iif … lookup 10` makes a
      ping from pb succeed while `main` lacks the route
  12. GENEVE: `ip link add gn0 type geneve id 7 remote <peer>` pair with a ping across
  13. per-netns conntrack knobs: `ip netns exec pa sysctl -w net.netfilter.nf_conntrack_tcp_loose=0`
      and `...nf_conntrack_tcp_timeout_established=20` both succeed **and** read back
      inside `pa` while `pb` keeps the defaults

  It ends with `topo_down` and exits 0 only if everything is OK. (The Review Focus
  checks are run by the controller in Step 7, not by probe.sh.)

- [ ] **Step 5: Write `labs/verify-teardown.sh`** (host side, read-only). It exits 0 when
  `docker compose -p netlab ps -q` is empty, and otherwise prints
  `LEFT netlab container running — docker compose -p netlab down` and exits 1. If
  `docker` is missing or the daemon is unreachable, it exits 2 with a message (copy the
  message shape from `linux_ops_mastery/labs/verify-teardown.sh`). It also prints
  `note: inside netlab, 'ip netns list' should be empty after topo.sh down`.

- [ ] **Step 6: Write `labs/netlab/README.md`.** Cover: bring-up/down commands, why the
  container is privileged, that all lab commands run from `/course` inside the
  container, the `/run/netlab/` state files, a "the probe failed" section pointing to
  PROBE.md, and the arm64 note (all packages are multi-arch).

- [ ] **Step 7 (controller): build and probe live**

Run:
```bash
cd network_engineering_mastery/labs/netlab
docker compose -p netlab up -d --build
docker compose -p netlab exec -T netlab bash labs/netlab/probe.sh
```
Expected: thirteen `OK` lines and exit 0. For each `MISSING`, record the fallback in
PROBE.md. The pre-agreed fallbacks are:
- FRR → a compose overlay `labs/netlab/docker-compose.frr.yml` with
  `quay.io/frrouting/frr:10.1.1` containers, and Day 5/7 rewritten around it
- VXLAN → a GRE tunnel (`ip link add gre0 type gre`)
- `/etc/netns` bind → use `dig @server` explicitly in labs
- VRF → RESOLVED by ruling: policy-routing tables (VRF-lite) are the primary design
- GENEVE → show VXLAN only and teach GENEVE from the header diagram
- per-netns conntrack knobs → the Day 3 idle-timeout demo uses
  `conntrack -D` on `lb` to expire the flow by hand (same on-the-wire result)

Then exercise Review Focus 1–3:
```bash
docker compose -p netlab exec -T netlab bash -c '. labs/lib/common.sh; require_netlab; topo_down; topo_down; echo idempotent-ok'
docker compose -p netlab exec -T netlab bash -c '. labs/lib/common.sh; require_topo 01'; echo "exit=$?"   # expect exit=2 + message
bash -c '. network_engineering_mastery/labs/lib/common.sh; require_netlab'; echo "exit=$?"         # host: expect exit=2 + enter-container hint
bash network_engineering_mastery/labs/verify-teardown.sh; echo "exit=$?"                            # expect 1 while up
docker compose -p netlab down && bash network_engineering_mastery/labs/verify-teardown.sh; echo "exit=$?"  # expect 0
```

- [ ] **Step 8: Static checks** — `bash -n` on every `.sh` in this task, and
  `docker compose -f labs/netlab/docker-compose.yml config -q`.

- [ ] **Step 9: Commit (controller, scratch branch)**
```bash
git add network_engineering_mastery/labs && git commit -m "WIP: task 1 netlab runtime + probe (scratch)"
```

---

### Task 2: Course frame — README, STRATEGY, journal

**Files:**
- Create: `README.md`, `STRATEGY.md`, `journal.md`

**Interfaces:**
- Consumes: the spec (Strategy, Curriculum and Success Criteria sections); the day map in this plan.
- Produces: the anchor names that day files link to:
  `STRATEGY.md#the-daily-loop`, `STRATEGY.md#the-eight-mistakes`, `README.md#cost`.

- [ ] **Step 1: Write `STRATEGY.md`** (~200–260 lines). Sections, in order:
  - `# The Top 1% Strategy for Network Engineering`
  - `## The header is the truth`: the doctrine, with 2 worked examples. (a) "Connection
    timed out" vs "Connection refused" decoded from the TCP header (silence vs a RST
    from the far end). (b) "An SG is conntrack": a stateful SG explained as a
    conntrack lookup on the 5-tuple.
  - `## The daily loop`: the 5 steps from the spec, each with its *why*.
  - `## The eight mistakes`: the 8 from the spec, each with the day where it bites and
    the corrective habit.
  - `## How this course fits`: a 3-row table relating this course to
    `linux_ops_mastery` (box) and `aws_network_components` (constructs), with links.
  - `## Rejected approaches`: the three rejected options from the spec with one paragraph each.
- [ ] **Step 2: Write `README.md`** (~150–220 lines). Mirror the shape of
  `linux_ops_mastery/README.md`:
  - a one-paragraph pitch
  - Prerequisites (Docker Desktop on Apple Silicon, ~2 GB; only for the optional Day 4 AWS lab: AWS `sandbox` profile + Terraform ≥ 1.6)
  - Bring-up (the commands from netlab README)
  - `## The 7-day map` table with columns Day | Concept core | Lab | Break | AWS construct emulated | Content | Lab dir
  - `## The daily loop` (5 numbered lines linking to STRATEGY)
  - `## How a lab works` (`topo.sh up` → explore → `break.sh` → journal → fix → `verify.sh` → `topo.sh down`)
  - `## Cost`: every lab is local, at $0. The one exception is the optional Day 4 AWS
    lab, ≈ $0.60/h `<!-- fact-check -->`. Rule: destroy it the same day, then run
    `../aws_network_components/scripts/sweep.sh`. A short "Why only one AWS lab"
    paragraph explains the local-first rule.
  - `## Teardown`
  - `## Reference material` table (STRATEGY, COVERAGE, GLOSSARY, 4 primers)
- [ ] **Step 3: Write `journal.md`**: a template block (Day / Header I drew from memory
  and what I got wrong / Evidence chain for the break, written before fixing / The AWS
  sentence "X in AWS is Y on the wire") followed by 7 empty `### Day N —` headings.
- [ ] **Step 4: Static checks**
```bash
for f in README.md STRATEGY.md; do /usr/bin/grep -c '^## ' $f; done      # README ≥ 7, STRATEGY ≥ 5
/usr/bin/grep -n -i -E '\b(simply|just|easy|powerful)\b' README.md STRATEGY.md   # expect no output
```
- [ ] **Step 5: Commit (controller)** `git add network_engineering_mastery && git commit -m "WIP: task 2 course frame (scratch)"`

---

### Day-task contract (applies to Tasks 3–8)

Each day task writes `content/dayNN.md` and the full `labs/dayNN/` set. The content
items listed per task are **mandatory coverage**; the writer chooses wording and order
within the fixed headings. `topo.sh` takes `up` or `down`. `up` runs `require_netlab`,
`topo_down`, builds the topology, starts any daemons with `bg`, then calls
`topo_mark NN`. `break.sh` runs `require_topo NN`, injects every fault listed, runs
`fault_set NN 1`, and prints the `symptom` line given in the task. `verify.sh` runs
`require_topo NN`, one `check` per listed check, then `verify_finish NN`.

**Live check (controller)**, run after the implementer finishes:
```bash
docker compose -p netlab up -d
X() { docker compose -p netlab exec -T netlab bash -c "$1"; }
X 'bash labs/dayNN/verify.sh'; echo "exit=$?"                      # expect 2 (not up)
X 'bash labs/dayNN/topo.sh up && bash labs/dayNN/topo.sh up'       # idempotent
X 'bash labs/dayNN/verify.sh'; echo "exit=$?"                      # expect 0 (healthy)
X 'bash labs/dayNN/break.sh'; X 'bash labs/dayNN/verify.sh'; echo "exit=$?"   # expect 1, every fault's check FAIL
# apply fix #1 from SOLUTION.md → verify expect 1 with only fault-2 checks FAIL
# apply fix #2 from SOLUTION.md → verify expect 0
X 'bash labs/dayNN/topo.sh down; ip netns list; ps -e | /usr/bin/grep -E "unbound|zebra|bgpd|python3" || true'   # expect empty
```
Any deviation is a defect, sent back to the implementer.

**Static checks per day task:**
```bash
d=content/dayNN.md
for h in 'Why this matters' 'Draw it first' 'Core concepts' 'Prove it on the wire' 'Lab' 'Where AWS hides this' 'Exercises' 'Anti-patterns / Common mistakes' 'Teardown'; do /usr/bin/grep -qx "## $h" $d || echo "MISSING $h"; done
n=$(/usr/bin/grep -cE '^[0-9]+\. ' <(sed -n '/^## Exercises/,/^## Anti/p' $d)); h=$(/usr/bin/grep -c '\*\*Hint:\*\*' $d); s=$(/usr/bin/grep -c '\*\*Solution sketch:\*\*' $d); echo "ex=$n hint=$h sol=$s"   # all equal, 8–12
wc -l $d                                                          # 300–450
for f in labs/dayNN/*.sh; do bash -n $f; done
ls labs/dayNN/{README.md,SOLUTION.md,teardown.md}
```

---

### Task 3: Day 1 — L2 and the wire

**Files:** Create `content/day01.md`, `labs/day01/{README.md,topo.sh,break.sh,verify.sh,SOLUTION.md,teardown.md}`

**Interfaces:** Consumes the `common.sh` functions (Task 1). Produces nothing used later.

- [ ] **Step 1: Write `labs/day01/topo.sh`.**
  - Namespaces `sw h1 h2 h3`. `veth h1 eth0 sw p1`, `veth h2 eth0 sw p2`,
    `veth h3 eth0 sw p3`; `bridge_ns sw br0 p1 p2 p3`.
  - Addresses: h1 `10.1.0.1/24`, h2 `10.1.0.2/24`, h3 `10.1.0.3/24`.
  - Set fixed MACs so captures in SOLUTION match: h1 `02:00:00:00:01:01`,
    h2 `02:00:00:00:01:02`, h3 `02:00:00:00:01:03`.
- [ ] **Step 2: Write `labs/day01/verify.sh`** with these checks:
  1. `h1 reaches h2` — `ip netns exec h1 ping -c3 -W1 10.1.0.2`
  2. `h1 reaches h3` — `ip netns exec h1 ping -c3 -W1 10.1.0.3`
  3. `MACs on h1..h3 are unique` — compare `ip -n hX -br link show eth0` field 3, with `sort | uniq -d` empty
  4. `h1 has no PERMANENT neighbour entries` — `! ip -n h1 neigh show nud permanent | /usr/bin/grep -q .`
- [ ] **Step 3: Write `labs/day01/break.sh`.**
  - Fault A: `ip -n h3 link set eth0 address 02:00:00:00:01:02` (a duplicate of h2).
  - Fault B: `ip -n h1 neigh replace 10.1.0.3 lladdr 02:00:00:00:01:99 dev eth0 nud permanent`.
  - Symptom: "h1 can reach h2 only sometimes, and never h3. Nobody changed an IP address."
- [ ] **Step 4: Write `labs/day01/SOLUTION.md`.** Chain of evidence:
  1. Ping fails.
  2. `tcpdump -eni eth0 arp or icmp` in h1 shows no ARP request for .3 (the static entry answers locally).
  3. `ip -n h1 neigh` shows PERMANENT with the wrong MAC.
  4. `bridge -n sw fdb show br br0` shows `02:00:00:00:01:02` flapping between p2 and p3 (run it twice).

  Fixes: (1) `ip -n h1 neigh del 10.1.0.3 dev eth0`; (2) `ip -n h3 link set eth0 address 02:00:00:00:01:03`. Then rerun verify.
- [ ] **Step 5: Write `labs/day01/README.md`** (At a glance + a guided "Prove" walkthrough):
  - capture an ARP request/reply with `tcpdump -eni eth0 -c 4 arp` in h1 while pinging
    h2, and annotate each field against the frame diagram
  - watch `ip -n h1 neigh` move through REACHABLE → STALE (wait ~30 s)
  - watch `bridge -n sw fdb show br br0` learn MACs
  - VLAN: enable `vlan_filtering`, put p3 in VLAN 20 (`bridge -n sw vlan add dev p3 vid 20 pvid untagged`), show h1 can no longer reach h3, capture on `br0` with `-e` to see the 802.1Q tag
- [ ] **Step 6: Write `labs/day01/teardown.md`**: `bash labs/day01/topo.sh down`,
  `ip netns list` (expect empty), and on the host `bash labs/verify-teardown.sh` if you
  are stopping for the day.
- [ ] **Step 7: Write `content/day01.md`.** Mandatory coverage:
  - **Why this matters:** a failover design that relied on gratuitous ARP and silently did nothing on AWS.
  - **Draw it first:** the Ethernet II frame and an ARP packet, from memory.
  - **Core concepts:**
    - Encapsulation as nested headers, with one ASCII diagram of Ethernet ⊃ IPv4 ⊃ TCP ⊃ payload
    - The Ethernet II fields (preamble/FCS noted as NIC-handled), EtherType values 0x0800/0x0806/0x86DD/0x8100
    - Unicast/broadcast/multicast and the I/G bit; locally administered addresses (why the lab uses `02:`)
    - ARP request/reply fields; the neighbour states (INCOMPLETE, REACHABLE, STALE, DELAY, PROBE, FAILED, PERMANENT); gratuitous ARP
    - Bridges and switches: learning, flooding of unknown unicast, aging; broadcast domains
    - 802.1Q tag layout (TPID, PCP, VID); access vs trunk
  - **Prove it on the wire:** walk through README Step 5 with expected output snippets.
  - **Where AWS hides this:**
    - VPC is L3-only. The hypervisor answers ARP for the VPC router and peers.
    - No broadcast or multicast (except Transit Gateway multicast, named only).
    - Gratuitous ARP and VRRP do not move traffic. Use an ENI move, a secondary-IP move,
      or a route-table update instead.
    - The source/destination check, and why appliances turn it off.
    - Each of these as an "X in AWS is Y on the wire" line.
  - **Exercises:** 10, including:
    - decode a hex dump of an ARP frame
    - classify 5 MACs as unicast/multicast/local
    - predict the FDB after a given ping sequence
    - explain why a duplicate MAC causes intermittent loss
    - VLAN membership puzzle
    - "design a floating-IP failover for two EC2 instances"
  - **Anti-patterns:** mistakes 1 and 2 from STRATEGY (memorizing OSI; learning tool flags).
- [ ] **Step 8:** Run the static checks; the controller runs the live check (Day-task contract).
- [ ] **Step 9: Commit (controller)** `git commit -m "WIP: task 3 day01 (scratch)"`

---

### Task 4: Day 2 — L3 addressing and forwarding

**Files:** Create `content/day02.md`, `labs/day02/{README.md,topo.sh,break.sh,verify.sh,SOLUTION.md,teardown.md}`

- [ ] **Step 1: Write `topo.sh`.**
  - Namespaces `h1 r1 r2 h2`. `veth h1 eth0 r1 eth1`; `veth r1 eth2 r2 eth1`;
    `veth r2 eth2 h2 eth0`.
  - IPv4: h1 `10.2.1.10/24` via `10.2.1.1`; r1 `10.2.1.1/24` + `10.2.12.1/30`;
    r2 `10.2.12.2/30` + `10.2.2.1/24`; h2 `10.2.2.10/24` via `10.2.2.1`. Routes:
    r1 `10.2.2.0/24 via 10.2.12.2`, r2 `10.2.1.0/24 via 10.2.12.1`.
  - IPv6: h1 `fd00:2:1::10/64`, r1 `fd00:2:1::1/64` + `fd00:2:12::1/64`, r2
    `fd00:2:12::2/64` + `fd00:2:2::1/64`, h2 `fd00:2:2::10/64`, with default routes on
    hosts and the matching static routes on the routers.
  - `forwarding r1`, `forwarding r2`. Set **both ends** of the r1–r2 link (r1 `eth2`,
    r2 `eth1`) to MTU 1400, so the PMTUD lesson exists in the healthy state too. The
    bottleneck must sit between two routers: a veth drops oversized frames at the
    receiving end with no ICMP, and a host-side 1400 MTU would shrink the TCP MSS
    so PMTUD never ran.
  - Create a 200 KB file `/run/netlab/big.bin` (`head -c 200000 /dev/urandom`) and
    `bg h2 web python3 -m http.server 8080 --directory /run/netlab`.
- [ ] **Step 2: Write `verify.sh`** with these checks:
  1. `h1 routes to h2 via r1` — `ip -n h1 route get 10.2.2.10 | /usr/bin/grep -q 'via 10.2.1.1'`
  2. `h1 pings h2 (v4)` and `h1 pings h2 (v6)`
  3. `200 KB transfer h1→h2 completes in 5 s` — `ip netns exec h1 curl -s -o /dev/null --max-time 5 http://10.2.2.10:8080/big.bin`
- [ ] **Step 3: Write `break.sh`.**
  - Fault A: in **both** r1 and r2, `nft add table inet lab; nft add chain inet lab out '{ type filter hook output priority 0; }'; nft add rule inet lab out icmp type destination-unreachable icmp code frag-needed drop`
    (r2 originates frag-needed for h2's large responses, and r1 for h1's large pings).
  - Fault B: in h1, `ip route add 10.2.2.0/25 via 10.2.1.99` (an on-link, non-existent next hop).
  - Symptom: "Pings to 10.2.2.10 fail; nobody touched the default route. Earlier,
    with ping working, a download from h2 hung forever."
- [ ] **Step 4: Write `SOLUTION.md`.** Chain of evidence:
  - Fault B: `ip -n h1 route get 10.2.2.10` shows `via 10.2.1.99` (longest prefix /25
    wins); `ip -n h1 neigh` shows 10.2.1.99 FAILED.
  - Fault A: after removing B, ping works but curl hangs. `ping -M do -s 1472` from h1
    gets no "Frag needed" back. `tcpdump -ni eth2` in r2 shows h2's full-size
    1500-byte segments arriving, nothing leaving toward r1, and no ICMP back to h2.
    `nft list ruleset` in r1 and r2 shows the drop. Explain PMTUD and the black hole.

  Fixes: `ip -n h1 route del 10.2.2.0/25`; `ip netns exec r1 nft delete table inet lab`;
  `ip netns exec r2 nft delete table inet lab`.
  Then show `ping -M do -s 1472` returning `Frag needed ... mtu = 1400`.
- [ ] **Step 5: Write `README.md`.** The guided Prove section:
  - `ip -n h1 route get` for 3 destinations
  - traceroute h1→h2 with the TTL=1/2 probes captured and decoded (`tcpdump -vni eth0 'icmp or udp'`)
  - an IPv4 header decoded field by field from `tcpdump -vvx`
  - `ping -M do -s 1372` passes and `-s 1373` triggers frag-needed (1400 − 28)
  - `tracepath 10.2.2.10` showing the pmtu
  - IPv6: `ip -n h1 -6 neigh` (NDP), and `ping -6` captured to show ICMPv6 NS/NA
  - **AWS emulation, the MTU tiers:** `ip -n h1 link set eth0 mtu 9001;
    ip -n r1 link set eth1 mtu 9001` (the jumbo "inside the VPC" link). Then
    `tracepath -n 10.2.2.10` from h1 shows pmtu 9001, dropping to 1400 at the r1–r2 "edge",
    and `ping -M do -s 8973 10.2.1.1` succeeds on the jumbo hop. Restore with
    `topo.sh up`.
- [ ] **Step 6: Write `teardown.md`** (the Day 1 shape, with day02).
- [ ] **Step 7: (removed: no AWS lab for Day 2; the sibling course's Day 1 labs VPCs on AWS)**
- [ ] **Step 8: Write `content/day02.md`.** Mandatory coverage:
  - **Why this matters:** large API responses hanging over VPN while health checks pass (an MTU black hole).
  - **Draw it first:** the IPv4 header (20 bytes, every field) and the IPv6 fixed header.
  - **Core concepts:**
    - IPv4 fields (version, IHL, DSCP/ECN, total length, ID, flags DF/MF, fragment offset,
      TTL, protocol 1/6/17/47/50, checksum, addresses); IPv6 fixed header and extension
      chain; no fragmentation by routers in v6
    - CIDR mental method (block size = 256 − mask octet), 3 worked splits, summarization,
      containment test, longest-prefix match across overlapping tables, RFC 1918, 100.64/10 (CGNAT)
    - A router's per-packet decision (lookup → TTL−1 → neighbour resolve → forward); connected vs static routes
    - ICMP type 0/8/3 (codes 0,1,3,4,13)/11; how traceroute uses TTL; why `* * *` lines appear
    - Fragmentation; MTU vs MSS; PMTUD (RFC 1191/8201); the black hole; MSS clamping as the band-aid
    - IPv6 essentials: link-local, SLAAC, NDP (NS/NA/RS/RA), ICMPv6 is mandatory
  - **Where AWS hides this:**
    - The VPC router is the +1 address, with 5 reserved IPs per subnet.
    - Route tables pick the longest prefix; local routes cannot be overridden by a less
      specific route (more-specific routes for middlebox insertion are allowed).
    - MTU 9001 in-VPC, 1500 via IGW and VPN, 8500 via TGW and inter-Region peering
      (fact-check).
    - Egress-only IGW; IPv6 has no NAT in AWS.
    - "Lab it on AWS": the sibling `aws_network_components` Day 1 and Day 2.
  - **Exercises:** 12, including:
    - 5 subnet-math drills
    - LPM puzzles over a 6-route table
    - decode a hex IPv4 header
    - compute an MSS for a 1400 MTU path
    - explain a traceroute with `* * *`
    - pick a VPC CIDR plan for 4 accounts × 3 tiers × 2 AZs without overlap
  - **Anti-patterns:** mistake 3 (treating AWS networking as magic); "blocking all ICMP for security".
- [ ] **Step 9:** Run the static checks; the controller runs the live check, including
  the MTU-tier emulation commands from Step 5.
- [ ] **Step 10: Commit (controller)** `git commit -m "WIP: task 4 day02 (scratch)"`

---

### Task 5: Day 3 — L4: TCP and UDP

**Files:** Create `content/day03.md`, `labs/day03/{README.md,topo.sh,break.sh,verify.sh,SOLUTION.md,teardown.md,client.py,lb.nft}`

- [ ] **Step 1: Write `topo.sh` and `lb.nft`.**
  - Namespaces `c1 lb s1`; `veth c1 eth0 lb eth1`; `veth lb eth2 s1 eth0`.
  - Addresses: c1 `10.3.1.10/24` via `.1`; lb `10.3.1.1/24`, `10.3.2.1/24`, plus the VIP
    `10.3.9.100/32` on `lo`; s1 `10.3.2.20/24` via `10.3.2.1`.
  - `forwarding lb`. In lb: `sysctl -w net.netfilter.nf_conntrack_tcp_loose=0`
    (mid-stream packets of an unknown flow are not adopted) and
    `nf_conntrack_tcp_timeout_established=20` (a 20 s "NLB idle timeout").
  - `ip netns exec lb nft -f labs/day03/lb.nft`:
    - `table ip nlb` with chain `prerouting` (`type nat hook prerouting priority -100`)
      containing `ip daddr 10.3.9.100 tcp dport 80 dnat to 10.3.2.20:8080`.
    - Chain `input` (`type filter hook input priority 0`) containing
      `ip daddr 10.3.9.100 tcp dport 80 reject with tcp reset`. Any packet reaching
      `lb` itself on the VIP was *not* DNATed, which means its flow has expired; NLB
      and NAT GW answer such packets with RST.
    - An empty `postrouting` nat chain whose comment shows the SNAT line for the
      "ALB mode" demo.
  - `bg s1 web python3 -m http.server 8080 --directory /run/netlab`. Nothing listens on 8081.
- [ ] **Step 2: Write `labs/day03/client.py`.** A stdlib-only TCP client:
  `client.py HOST PORT N`. It opens N sequential connections, sends `HEAD / HTTP/1.0`,
  reads, closes **client-first** (so TIME_WAIT lands on the client), then prints counts
  of ok/errors and the first error string. It is used in the Prove section for
  ephemeral-port exhaustion: with `sysctl net.ipv4.ip_local_port_range="40000 40009"` in
  c1, N=20 hits `EADDRNOTAVAIL`.
- [ ] **Step 3: Write `verify.sh`** with these checks:
  1. `c1 has no netem qdisc` — `! tc -n c1 qdisc show dev eth0 | /usr/bin/grep -q netem`
  2. `10 sequential requests to the VIP succeed within 2 s each` — a loop of
     `ip netns exec c1 curl -s -o /dev/null --max-time 2 http://10.3.9.100/`
  3. `s1 does not silently drop 8080` — `! ip netns exec s1 nft list ruleset | /usr/bin/grep -q 'dport 8080 drop'`
  4. `s1 sees the real client IP (no SNAT on lb)` — `! ip netns exec lb nft list table ip nlb | /usr/bin/grep -q 'snat\|masquerade'`
- [ ] **Step 4: Write `break.sh`.**
  - Fault A: in s1, `nft add table inet lab; nft add chain inet lab in '{ type filter hook input priority 0; }'; nft add rule inet lab in tcp dport 8080 drop`.
  - Fault B: `tc -n c1 qdisc add dev eth0 root netem delay 200ms loss 30%`.
  - Fault C: `ip netns exec lb nft add rule ip nlb postrouting ip daddr 10.3.2.20 snat to 10.3.2.1`.
  - Symptom: "Through the VIP, everything hangs. Directly, port 8081 says 'refused'
    instantly and 8080 hangs. Pings feel slow. And the app team says every request now
    comes from 10.3.2.1."
- [ ] **Step 5: Write `SOLUTION.md`.** Chain of evidence:
  - `curl` to 8081 gives an immediate RST (`tcpdump -ni eth0 tcp` shows `[R.]`): the host
    is alive and nothing listens there.
  - 8080 gives SYN retransmits at 1 s, 2 s, 4 s with no reply. Silence means a filter.
    `nft list ruleset` in s1 shows it.
  - Ping RTT ~200 ms with loss. `ss -ti` in c1 shows `rto` and `retrans` climbing.
    `tc -n c1 qdisc` shows netem.
  - Fault C: s1's access log and `ss -tn` in s1 show the peer `10.3.2.1`.
    `conntrack -L` in lb shows the reply tuple rewritten. `nft list table ip nlb`
    shows the snat rule. Explain NLB (client IP preserved) vs ALB/proxy (new
    connection from the LB) and where `X-Forwarded-For` / proxy protocol come in.

  Fixes: `ip netns exec s1 nft delete table inet lab`; `tc -n c1 qdisc del dev eth0 root`;
  `ip netns exec lb nft flush chain ip nlb postrouting`. Run verify once per fix; the
  partial-fix behaviour is part of the live check.
- [ ] **Step 6: Write `README.md`.** The guided Prove section:
  - capture one full HTTP connection with `tcpdump -ni eth0 -S tcp port 8080` and label
    SYN/SYN-ACK/ACK, data, FIN/ACK; identify who enters TIME_WAIT via `ss -tan state time-wait`
  - read MSS/SACK/wscale/TS from the SYN options
  - netem `loss 10%` → `ss -ti` before and after (cwnd, rtt, retrans)
  - UDP: `nc -u` to a closed port → ICMP port-unreachable in the capture
  - ephemeral exhaustion with `client.py` as above, then restore the default range
  - **AWS emulation, the NLB idle timeout:** in c1 run
    `python3 -c` (inline: connect to `10.3.9.100:80`, send one request, `sleep 25`,
    send again, print the exception), with `tcpdump -ni eth0 'tcp[tcpflags] & tcp-rst != 0'`
    running. Expect `ConnectionResetError` and an RST from 10.3.9.100. Read
    `conntrack -L` in lb before and after the 20 s. Repeat with `SO_KEEPALIVE` and
    `TCP_KEEPIDLE=10` and show no reset. Map: NLB 350 s, NAT GW 350 s.
  - **AWS emulation, client-IP preservation:** add the SNAT line, show s1's view of the
    peer change, then remove it.
- [ ] **Step 7: Write `teardown.md`.**
- [ ] **Step 8: (removed: no AWS lab for Day 3; the local `lb` namespace is the NLB)**
- [ ] **Step 9: Write `content/day03.md`.** Mandatory coverage:
  - **Why this matters:** intermittent "connection reset by peer" from a backend behind
    an NLB after quiet periods.
  - **Draw it first:** the TCP header plus the state machine.
  - **Core concepts:**
    - TCP header fields and options (MSS, SACK, wscale, TS); seq/ack arithmetic with a
      worked 3-segment example
    - All 11 states; active vs passive close; TIME_WAIT = 2×MSL and why it exists; the
      4-tuple and ephemeral ports (Linux default 32768–60999)
    - RST semantics (closed port, abort, mid-path device) vs silence (filter, black hole, dead host)
    - Retransmission and RTO back-off; flow control (rwnd) vs congestion control (cwnd):
      slow start, congestion avoidance, fast retransmit on 3 dup ACKs, CUBIC default on
      Linux, BBR concept
    - Keepalive vs application-level idle timeouts; half-open connections
    - UDP header and statelessness; ICMP port-unreachable
  - **Where AWS hides this:**
    - NLB TCP idle timeout (350 s default, now configurable — fact-check) and the RST it
      sends after; ALB idle timeout 60 s, and the rule that backend keep-alive must
      exceed the LB idle timeout
    - NAT Gateway: 55,000 simultaneous connections per unique destination (fact-check),
      ErrorPortAllocation, and the 350 s idle timeout
    - Client-IP preservation, and proxy protocol v2 on NLB
    - Link to the sibling LB course for listener and target-group depth
  - **Exercises:** 10, including:
    - fill seq/ack numbers in a 6-packet exchange
    - classify 5 capture snippets as refused / filtered / reset-by-middlebox / slow / healthy
    - compute time to exhaust 28k ports at 500 conn/s with TIME_WAIT 60 s
    - choose keepalive settings for a service behind NLB + NAT
    - read an `ss -ti` line
  - **Anti-patterns:** mistakes 4 and 5; "raising the timeout until it goes away".
- [ ] **Step 10:** Static checks; `nft -c -f labs/day03/lb.nft` inside netlab (controller).
  The controller runs the live check, including the idle-timeout RST emulation (expect
  `ConnectionResetError` after 25 s idle).
- [ ] **Step 11: Commit (controller)** `git commit -m "WIP: task 5 day03 (scratch)"`

---

### Task 6: Day 4 — NAT, conntrack and filtering

**Files:** Create `content/day04.md`, `labs/day04/{README.md,topo.sh,break.sh,verify.sh,SOLUTION.md,teardown.md,fw.nft,inspection.sh}`, `aws_lab/day04/{main.tf,variables.tf,outputs.tf,terraform.tfvars.example,user_data.sh.tftpl,README.md,.gitignore}`

- [ ] **Step 1: Write `labs/day04/fw.nft`** (the reference policy; the learner writes their own first):
```nft
#!/usr/sbin/nft -f
# Day 4 reference firewall for namespace fw. Inside = 10.4.1.0/24 (eth1),
# servers = 10.4.2.0/24 (eth2), outside = 198.51.100.0/24 (eth9).
flush ruleset
table inet filter {
  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    ct state invalid counter drop
    iifname "eth1" oifname "eth2" tcp dport 8080 ct state new accept
    iifname "eth1" oifname "eth9" ct state new accept
    icmp type { echo-request, destination-unreachable, time-exceeded } accept
  }
}
table ip nat {
  chain postrouting {
    type nat hook postrouting priority 100;
    oifname "eth9" ip saddr 10.4.1.0/24 masquerade
  }
}
```
- [ ] **Step 2: Write `topo.sh`.**
  - Namespaces `h1 fw r2 h2 ext sw1 sw2`.
  - Inside LAN: bridge in sw1 with h1, fw(eth1) and r2(eth1).
  - Server LAN: bridge in sw2 with h2, fw(eth2) and r2(eth2).
  - `veth fw eth9 ext eth0`.
  - Addresses: h1 `10.4.1.10/24` via `.1`; fw `10.4.1.1`, `10.4.2.1`, `198.51.100.1/24`;
    r2 `10.4.1.2`, `10.4.2.2`; h2 `10.4.2.10/24` via `10.4.2.1`;
    ext `198.51.100.10/24` with **no route** to 10.4.0.0/16.
  - `forwarding fw`, `forwarding r2`.
  - `ip netns exec fw nft -f labs/day04/fw.nft`.
  - `bg h2 web2 python3 -m http.server 8080 --directory /run/netlab`;
    `bg ext webx python3 -m http.server 8080 --directory /run/netlab`.
- [ ] **Step 3: Write `verify.sh`** with these checks:
  1. `h1 → h2:8080` — curl with `--max-time 3`
  2. `h1 → ext:8080 (via NAT)` — curl to 198.51.100.10
  3. `h2 returns to 10.4.1.0/24 via fw` — `ip -n h2 route get 10.4.1.10 | /usr/bin/grep -q 'via 10.4.2.1'`
  4. `fw masquerades outbound` — `ip netns exec fw nft list table ip nat | /usr/bin/grep -q masquerade`
- [ ] **Step 4: Write `break.sh`.**
  - Fault A: `ip -n h2 route add 10.4.1.0/24 via 10.4.2.2` (the return path goes through r2).
  - Fault B: `ip netns exec fw nft flush chain ip nat postrouting`.
  - Symptom: "h1 can ping h2 but HTTP to h2 hangs after the SYN. h1 cannot reach the outside at all."
- [ ] **Step 5: Write `SOLUTION.md`.** Chain of evidence:
  - Fault A: `conntrack -L` in fw shows the flow stuck in `SYN_SENT`. The `ct state
    invalid` counter rises (`nft list ruleset`). tcpdump on fw eth2 shows the SYN going
    out but the SYN-ACK never coming back through fw, while tcpdump on r2 shows it. The
    route on h2 is asymmetric. Ping still works because the ICMP accept rule doesn't
    need state; explain that.
  - Fault B: tcpdump on ext shows `10.4.1.10` as the source, and ext has no route back,
    so no NAT means no return.

  Fixes: `ip -n h2 route del 10.4.1.0/24 via 10.4.2.2`; `ip netns exec fw nft -f labs/day04/fw.nft`.
- [ ] **Step 6: Write `README.md`.** The guided Prove section:
  - **write your own policy first** into `/run/netlab/my.nft` from the spec in the
    README (allow h1→h2:8080, h1→outside, NAT out, drop everything else), load it,
    run verify, then diff it against `fw.nft`
  - `conntrack -E` in fw while curling; read the tuple and its reply direction (the
    NAT-ed address shows in the reply tuple)
  - `nft list ruleset` counters
  - the netfilter hook order with a `meta nftrace set 1` trace (`nft monitor trace`)
  - **AWS emulation, two-AZ inspection** with `labs/day04/inspection.sh` (the next step)
- [ ] **Step 6b: Write `labs/day04/inspection.sh {up|asym|appliance|down}`.** It is
  self-contained: it calls `topo_down` first and builds its own topology, so the main
  Day 4 lab must be redone afterwards with `topo.sh up`.
  - Namespaces `spa` (`10.41.0.10/24`), `spb` (`10.42.0.10/24`) and `tgw`.
  - `tgw` has `10.41.0.1`, `10.42.0.1` and two transit links: to `fwa` (AZ-a)
    `10.40.1.0/30`, and to `fwb` (AZ-b) `10.40.2.0/30`.
  - `fwa`/`fwb` each load the stateful forward policy (established/related accept,
    invalid counter drop, `10.0.0.0/8` new accept) and route everything back to `tgw`.
  - `spb` runs `python3 -m http.server 8080`.
  - Steering is policy routing in `tgw` with two tables, `100 → via fwa` and
    `200 → via fwb`, and an `ip rule iif <transit-link>` that sends post-inspection
    traffic straight to the spoke via `main`:
    - `asym`: `ip rule add iif <to-spa> table 100` and `iif <to-spb> table 200`. The
      request goes through fwa and the reply through fwb, so fwb sees a SYN-ACK with no
      flow and drops it as INVALID.
    - `appliance`: both spoke rules point at table 100.
  - The script prints the curl result plus both firewalls' invalid counters after each mode.
  - `down` = `topo_down`.
  - README walkthrough: run `asym` and observe curl failing and the `fwb` invalid
    counter rising. Run `appliance` and observe success. Then map it: TGW picks the
    inspection-VPC ENI in the *source's* AZ per direction; `appliance_mode_support`
    pins a flow to one AZ, using a flow hash (fact-check).
- [ ] **Step 7: Write `teardown.md`** (includes `bash labs/day04/inspection.sh down`).
- [ ] **Step 8: Write the `aws_lab/day04` Terraform root** — the course's only AWS lab,
  optional (inspection with an appliance-mode toggle, ~60 min, ≈ $0.60/h). Its README
  opens with "Why this one is on AWS": TGW's per-AZ path choice and the
  `appliance_mode_support` flag are AWS behaviour, and `inspection.sh` only imitates
  their effect.
  - **VPCs** (three `vpc` module instances from `../../../aws_network_components/terraform/modules/vpc`,
    2 AZs each): `spoke-a` `10.41.0.0/16`, `spoke-b` `10.42.0.0/16`, `inspection` `10.40.0.0/16`.
  - **TGW** (raw resources):
    - `aws_ec2_transit_gateway` with `default_route_table_association = "disable"` and `default_route_table_propagation = "disable"`
    - three `aws_ec2_transit_gateway_vpc_attachment` resources on the private subnets;
      the inspection one has `appliance_mode_support = var.appliance_mode ? "enable" : "disable"`
    - two TGW route tables:
      - `spokes`: associated with both spokes, static `0.0.0.0/0` → inspection attachment
      - `inspection`: associated with inspection, with propagations from both spokes
  - **Routes:**
    - spoke private route tables: `10.0.0.0/8` → TGW
    - inspection private route tables per AZ: `10.0.0.0/8` → the firewall ENI in the same AZ
    - inspection "tgw" routing: the attachment subnets reuse the inspection private
      subnets, so the per-AZ firewall route also covers returning traffic. A README
      paragraph explains that production uses dedicated TGW subnets.
  - **Firewalls:** two `aws_instance` "fw" resources (one per AZ) in the inspection
    private subnets: AL2023 via the same SSM parameter as `ec2_test`, `t3.micro`,
    `source_dest_check = false`, the SSM instance profile from a local role (copy the
    ec2_test IAM shape), and an SG allowing all traffic from `10.0.0.0/8`.
    - `user_data` = `templatefile("user_data.sh.tftpl", {})`, which installs `nftables`,
      sets `net.ipv4.ip_forward=1`, and loads a stateful forward policy: established
      accept, invalid drop with a counter, `10.0.0.0/8` new accept.
  - **Test instances:** `module "ec2_a"` / `module "ec2_b"` from `ec2_test`, in
    spoke-a AZ-a and spoke-b AZ-b (`subnet_ids = [module.spoke_a.private_subnet_ids[0]]`
    and `[module.spoke_b.private_subnet_ids[1]]`, so the flow crosses AZs),
    `allowed_cidr = "10.0.0.0/8"`.
  - `variables.tf`: `region`, `aws_profile`, `appliance_mode` (bool, default `false`).
  - `outputs.tf`: instance IDs and private IPs, and the firewall instance IDs.
  - **README:** apply with `appliance_mode=false`. From ec2_a run `curl -m 5 <ec2_b>:8080`
    repeatedly (some flows hang). On both firewalls, read `nft list ruleset` (the
    invalid counter rises on one), plus `conntrack -L`. Explain why: the TGW picks the
    AZ per direction. Then `terraform apply -var appliance_mode=true` and observe 100%
    success. Teardown and `sweep.sh`. Note: "the firewall here is your Day 4 policy".
- [ ] **Step 9: Write `content/day04.md`.** Mandatory coverage:
  - **Why this matters:** centralized inspection that drops a fraction of cross-AZ
    flows with no error anywhere.
  - **Draw it first:** the netfilter hook diagram (prerouting → routing decision →
    input/forward → output → postrouting) with the nat/filter positions marked.
  - **Core concepts:**
    - SNAT/DNAT/masquerade; port translation; why NAT needs state
    - conntrack: the original and reply tuples, states NEW/ESTABLISHED/RELATED/INVALID,
      TCP tracking and timeouts, the table limit and `nf_conntrack: table full`
    - Stateful vs stateless filters, and the return-traffic ephemeral range
    - Asymmetric routing: why a stateful device sees only half a flow and marks the
      ACK INVALID
    - nftables model: tables/chains/hooks/priorities/policy, sets, counters, tracing
  - **Where AWS hides this:**
    - An SG is stateful (conntrack per ENI); tracked vs untracked connections, and the
      SG connection-tracking timeouts (fact-check)
    - A NACL is stateless with ephemeral 1024–65535 return rules, evaluated in rule-number order
    - AWS Network Firewall: stateless and stateful engines, Suricata-compatible rules (named)
    - The centralized inspection VPC; TGW appliance mode keeping both directions on one
      AZ's appliance
    - GWLB named as the next level (Day 6)
    - NAT Gateway as a managed SNAT
    - "Lab it locally": `inspection.sh`. "Lab it on AWS" (optional): `aws_lab/day04/`
  - **Exercises:** 10, including:
    - write nft rules for 3 policies
    - read a `conntrack -L` line (orig/reply, NAT-ed)
    - a NACL rule-set puzzle with missing return rules
    - predict which flows break under asymmetric routing
    - explain why ping survived Fault A
    - SG vs NACL decision for 4 scenarios
  - **Anti-patterns:** mistakes 6 and 7; "opening 0.0.0.0/0 to fix a return-path problem".
- [ ] **Step 10:** Static checks; `nft -c -f labs/day04/fw.nft` inside netlab
  (controller); `terraform fmt -check && terraform init -backend=false && terraform validate`
  in `aws_lab/day04` (controller). The controller runs the live check plus
  `inspection.sh up; inspection.sh asym` (expect curl fail and the fwb invalid counter
  > 0), then `inspection.sh appliance` (expect curl 200), then `inspection.sh down`.
- [ ] **Step 11: Commit (controller)** `git commit -m "WIP: task 6 day04 (scratch)"`

---

### Task 7: Day 5 — Routing protocols and BGP

**Files:** Create `content/day05.md`, `labs/day05/{README.md,topo.sh,break.sh,verify.sh,SOLUTION.md,teardown.md}`, `labs/day05/frr/{r1,r2,r3,r4}.conf`, `labs/day05/vrf.sh`

**Interfaces:** Consumes `frr_up NS CONF` and `vty NS CMD [CMD…]` from `common.sh`
(Task 1). These are the same functions the probe already proved. Task 9 reuses them.
If PROBE.md says FALLBACK for FRR, follow the compose fallback recorded there instead,
keeping the same addresses and check names.

- [ ] **Step 1: Write the topology** (`topo.sh` + 4 configs).
  - **Routers and AS numbers:** r1 AS 65001 ("on-prem"), r2 AS 65002 ("VPN path"),
    r3 AS 65003 ("DX path"), r4 AS 64512 ("AWS").
  - **Links and addresses:**

    | Link | Subnet | Left | Right |
    |---|---|---|---|
    | r1–r2 | `10.5.12.0/30` | r1 `.1` | r2 `.2` |
    | r1–r3 | `10.5.13.0/30` | r1 `.1` | r3 `.2` |
    | r2–r4 | `10.5.24.0/30` | r2 `.1` | r4 `.2` |
    | r3–r4 | `10.5.34.0/30` | r3 `.1` | r4 `.2` |

  - **Prefixes:** r4 has a dummy `lo1` `10.50.100.1/24` and advertises `10.50.100.0/24`.
    r1 has dummy `10.50.1.1/24` and advertises `10.50.1.0/24`.
  - **Policy:** `forwarding` on all four. r1 applies `route-map FROM-R3 permit 10 / set local-preference 200` inbound from r3.
  - **FRR settings:** `no bgp ebgp-requires-policy`, plus explicit `network` statements.
  - **Readiness:** after `frr_up` on all four, poll up to 40 s until
    `vty r1 'show bgp summary json'` shows both peers `Established`.
- [ ] **Step 2: Write `verify.sh`** with these checks:
  1. `r1↔r2 Established` and `r1↔r3 Established` (parse `show bgp summary json` with python3)
  2. `r1 best path to 10.50.100.0/24 is via r3 (local-pref 200)` — `ip -n r1 route get 10.50.100.1 | /usr/bin/grep -q 'via 10.5.13.2'`
  3. `no static route for 10.50.100.0/24 on r1` — `! ip -n r1 route show 10.50.100.0/24 proto static | /usr/bin/grep -q .`
  4. `r1 lan reaches AWS prefix` — `ip netns exec r1 ping -c2 -W1 -I 10.50.1.1 10.50.100.1`
- [ ] **Step 3: Write `break.sh`.**
  - Fault A: `vty r1 'configure terminal' 'router bgp 65001' 'neighbor 10.5.13.2 remote-as 65099'`
    (a wrong ASN, so the r3 session never establishes).
  - Fault B: `ip -n r1 route add 10.50.100.0/24 via 10.5.12.2 proto static metric 10`.
  - Symptom: "The DX path should be primary. Traffic is on the VPN path, and when we
    shut the VPN path in the last drill, traffic did not move."
- [ ] **Step 4: Write `SOLUTION.md`.** Chain of evidence:
  - `show bgp summary` shows r3 in `Active` or `Connect`. `show bgp neighbor 10.5.13.2`
    reports "Bad Peer AS" in the last error (or the OPEN notification in a capture of
    `tcp port 179`).
  - `ip -n r1 route show 10.50.100.0/24` shows a `proto static` route, and
    `show ip route 10.50.100.0/24` in vtysh shows the kernel/static route beating BGP
    (explain administrative distance).

  Fixes: `vty r1` with `neighbor 10.5.13.2 remote-as 65003`; `ip -n r1 route del 10.50.100.0/24 proto static`.
- [ ] **Step 5: Write `README.md`.** The guided Prove section:
  - capture the session establishment on `tcp port 179` (OPEN, KEEPALIVE, UPDATE) and
    read the attributes in the UPDATE with `tshark -V -Y bgp`
  - `show bgp ipv4 unicast 10.50.100.0/24` (both paths, the "best" reason)
  - **predict first, then run:** remove local-pref → best path by router-id/age;
    prepend `64512 64512` on r4 toward r3 → AS-path wins; set MED (explain that MED
    compares only same-neighbour-AS paths)
  - advertise a more-specific `/25` from r2 and watch it win regardless of attributes
  - shut r3's link (`ip -n r3 link set eth0 down`) and time the failover (hold timer;
    note BFD)
- [ ] **Step 6: Write `teardown.md`.**
- [ ] **Step 7: Write `labs/day05/vrf.sh {up|leak|down}`** — the AWS emulation "TGW in a box".
  Self-contained; it calls `topo_down` first. **Ruling (live probe): the Docker
  Desktop kernel has no VRF device (`CONFIG_NET_VRF` not set), so route tables are
  policy-routing tables (VRF-lite). Do not use `type vrf`.**
  - Namespaces `prod` (`10.51.0.10/24`, gw `.1`), `dev` (`10.52.0.10/24`) and
    `shared` (`10.53.0.10/24`), plus `tgw`, which has attachments `att-prod`,
    `att-dev` and `att-shared` with the `.1` addresses. `forwarding tgw`.
  - In `tgw`, route tables 10 (`rt-prod`), 20 (`rt-dev`) and 30 (`rt-shared`), named
    in `/etc/iproute2/rt_tables.d/tgw.conf`.
  - **Association** = `ip -n tgw rule add iif att-prod lookup 10` (likewise dev→20,
    shared→30), each with a priority below the `main` rule (e.g. `pref 100`).
  - **Isolation:** add `ip -n tgw rule add pref 32000 iif att-prod unreachable` for each
    attachment, so a miss in the associated table never falls through to `main`.
  - **Propagation** = adding a route into a table: an attachment's own subnet route
    goes into the tables that "learn" it.
  - `up`: each table holds only its own attachment's connected subnet, so every ping
    between spokes fails. Show `ip -n tgw route show table 10` and `ip -n tgw rule`.
  - `leak`:
    - `ip -n tgw route add 10.53.0.0/24 dev att-shared table 10` (and the same into table 20)
    - `ip -n tgw route add 10.51.0.0/24 dev att-prod table 30`, and the same for dev
  - Result: prod↔shared and dev↔shared work, prod↔dev still fails. That is the
    classic shared-services segmentation.
  - The script prints a 3×3 reachability matrix after each step.
  - README walkthrough plus a table: policy-routing table ↔ TGW route table;
    `ip rule iif … lookup` ↔ association; route added to a table ↔ propagation; static
    route ↔ TGW static route; `blackhole` route ↔ TGW blackhole. Add one paragraph on
    real VRFs (`ip link add … type vrf`): what they add (an L3 master device that
    binds sockets) and that this kernel lacks them.
- [ ] **Step 8: Write `content/day05.md`.** Mandatory coverage:
  - **Why this matters:** the backup VPN carrying production traffic because a static
    route outranked BGP.
  - **Draw it first:** the BGP FSM (Idle, Connect, Active, OpenSent, OpenConfirm,
    Established) and the best-path list.
  - **Core concepts:**
    - Static vs dynamic routing; administrative distance (connected 0, static 1, eBGP
      20, OSPF 110, iBGP 200, as in FRR/Cisco); distance-vector vs link-state at concept
      level (Bellman-Ford vs Dijkstra; OSPF areas named)
    - BGP: path-vector, TCP 179, message types, eBGP vs iBGP (the iBGP split-horizon rule,
      route reflectors named), private ASNs 64512–65534 and 4-byte
    - Best-path order: weight (FRR/Cisco-local), local-pref, locally originated, AS-path
      length, origin, MED, eBGP over iBGP, IGP metric, oldest/router-id; and the rule
      that prefix length is decided before any attribute
    - ECMP and multipath; route policy (prefix-list, route-map); hold and keepalive
      timers; BFD
  - **Where AWS hides this:**
    - VPN and DX use eBGP; the AWS side ASN is 64512 by default
    - The AWS route-preference order for VGW and TGW (longest prefix first, then static
      over propagated, DX over VPN; fact-check), and how AS-path prepending and MED are
      honoured for VPN/DX
    - TGW route tables as VRFs; association = which table an attachment uses for lookups;
      propagation = which tables learn its routes; segmentation patterns (shared services,
      isolated spokes)
    - "Lab it locally": `vrf.sh` and the BGP topology. "Lab it on AWS": the sibling
      `aws_network_components` Day 4 (TGW) and Day 6 (VPN/BGP)
  - **Exercises:** 12, including:
    - 4 best-path puzzles
    - an AD puzzle
    - an FSM diagnosis from symptoms
    - design TGW route tables for 3 segments (prod, dev, shared)
    - choose prepend vs local-pref for making DX primary inbound vs outbound
    - explain why MED was ignored
- [ ] **Step 9:** Static checks. The controller runs the live check (this is the probe's
  biggest risk; budget for one fix round), plus `vrf.sh up` (matrix all ✗ off-diagonal),
  `vrf.sh leak` (prod↔dev ✗, everything to/from shared ✓), then `vrf.sh down`.
- [ ] **Step 10: Commit (controller)** `git commit -m "WIP: task 7 day05 (scratch)"`

---

### Task 8: Day 6 — Overlays and names

**Files:** Create `content/day06.md`, `labs/day06/{README.md,topo.sh,break.sh,verify.sh,SOLUTION.md,teardown.md}`, `labs/day06/dns/{internal.conf,public.conf,onprem.conf}`, `labs/day06/geneve.sh`

**Interfaces:** Produces the unbound launch pattern reused by Task 9:
`bg NS dns-NAME unbound -d -c CONF`. Configs set `interface:`, `access-control: 0.0.0.0/0 allow`,
`do-daemonize: no`, `chroot: ""`, `username: ""`, `pidfile: ""`.

- [ ] **Step 1: Write `topo.sh`.**
  - **Underlay:** namespaces `va vb`, `veth va u0 vb u0`, `10.6.0.1/24` and
    `10.6.0.2/24`, MTU 1500.
  - **Overlay:** `vxlan100` in each with `id 100 local <own> remote <peer> dstport 4789 dev u0`,
    overlay `172.16.0.1/24` and `172.16.0.2/24`, MTU 1450.
  - **DNS:** namespaces `dnsi dnsp cli` on a bridge in `sw` (`10.6.10.0/24`): dnsi `.53`,
    dnsp `.54`, cli `.10`. Also put a host `app` at `10.6.10.20`.
  - `internal.conf` serves `local-zone: "corp.internal." static`, with
    `local-data: "app.corp.internal. 60 IN A 10.6.10.20"`.
  - `public.conf` serves the same name as `203.0.113.20` (the split-horizon public view).
  - Write `/etc/netns/cli/resolv.conf` = `nameserver 10.6.10.53` and `options ndots:1`.
  - Add `odns` `10.6.10.60` on the same bridge running unbound with `onprem.conf`
    (see Step 7: the Resolver-endpoint emulation lives in this topology).
- [ ] **Step 2: Write `verify.sh`** with these checks:
  1. `cli resolves app.corp.internal to the internal view` —
     `[ "$(ip netns exec cli dig +short app.corp.internal)" = 10.6.10.20 ]`
  2. `overlay passes a 1422-byte DF ping` — `ip netns exec va ping -c2 -W1 -M do -s 1422 172.16.0.2`
  3. `overlay MTU ≤ 1450` — read `ip -n va -j link show vxlan100` and test `mtu <= 1450` with python3
  4. `cli resolves db.onprem.corp via forwarding` — `[ "$(ip netns exec cli dig +short db.onprem.corp)" = 192.168.20.5 ]`
- [ ] **Step 3: Write `break.sh`.**
  - Fault A: `ip -n va link set vxlan100 mtu 1500; ip -n vb link set vxlan100 mtu 1500`,
    and set the DF policy on the vxlan so the outer packet cannot fragment
    (`ip -n va link set vxlan100 type vxlan df set`, likewise vb). If the probe/live
    check shows the kernel silently fragments anyway, the fallback is to drop outer
    fragments in `vb` with `nft ... ip frag-off & 0x1fff != 0 drop`. Record whichever was
    used in SOLUTION.
  - Fault B: rewrite `/etc/netns/cli/resolv.conf` to `nameserver 10.6.10.54`.
  - Symptom: "Small requests across the overlay work and large ones vanish. And
    app.corp.internal now resolves to an address nobody recognizes."
- [ ] **Step 4: Write `SOLUTION.md`.** Chain of evidence:
  - Fault A: `ping -M do -s 1422` fails and `-s 1400` passes. tcpdump on `u0` shows the
    outer UDP 4789 packet size of 1550 > 1500. Explain the 50-byte VXLAN tax
    (14 + 20 + 8 + 8).
  - Fault B: `dig app.corp.internal` shows `SERVER: 10.6.10.54`. Compare
    `dig @10.6.10.53` with `@10.6.10.54`; explain split horizon.

  Fixes: MTU 1450 on both ends; restore resolv.conf to `.53`.
- [ ] **Step 5: Write `README.md`.** The guided Prove section:
  - capture on `u0` and show the outer Ethernet/IP/UDP 4789/VXLAN (VNI 100) wrapped
    around the inner frame with `tshark -V -d udp.port==4789,vxlan`
  - ESP: add static `ip xfrm state` and `ip xfrm policy` between va and vb for
    `10.6.0.0/24` (the SPI and keys are given in the README as obvious lab
    placeholders, e.g. `0x$(printf 'a%.0s' {1..64})`, with a comment saying never reuse
    them), ping, and capture ESP with the SPI and sequence visible and the payload
    opaque; then delete the state and policy
  - DNS: `dig +trace`-style reasoning without internet, using `dig +norecurse` against
    each server; TTL countdown on repeated queries to a forwarding config (add
    `forward-zone` in a copy); NXDOMAIN and negative caching; the `ndots`/`search`
    effect with `search corp.internal` and `ndots:5`
- [ ] **Step 6: Write `teardown.md`.**
- [ ] **Step 7: Write the two AWS emulations.**
  - **Resolver endpoints** are part of the main topology, not a separate script:
    - Add namespace `odns` (`10.6.10.60`), running unbound with `onprem.conf`. It
      serves `local-zone "onprem.corp."` with `db.onprem.corp. A 192.168.20.5`, and
      `forward-zone "corp.internal." → 10.6.10.53`. This is the on-prem DNS
      forwarding to an *inbound endpoint*.
    - `internal.conf` gains `forward-zone "onprem.corp." → 10.6.10.60`, the
      *outbound endpoint + forwarding rule*.
    - The README walkthrough: `dig db.onprem.corp` from `cli` (via .53 → .60), and
      `dig @10.6.10.60 app.corp.internal` (on-prem → inbound). It includes the mapping
      table: VPC +2 resolver ↔ dnsi; outbound endpoint + rule ↔ forward-zone in dnsi;
      inbound endpoint ↔ dnsi's listening address that odns forwards to; PHZ ↔
      local-zone.
  - **`labs/day06/geneve.sh {up|down}`** (GWLB on the wire). Self-contained; it calls
    `topo_down` first.
    - Namespaces `src` (`10.61.0.10`), `gwlb` (the router), `appl` and `dst`
      (`10.62.0.10`).
    - `gwlb` and `appl` are linked by an underlay `10.60.0.0/30` plus
      `ip link add gnv0 type geneve id 1 remote <peer> dstport 6081` on both ends.
    - `gwlb` uses policy routing: everything arriving from `src` goes into `gnv0`; the
      `appl` side hairpins it back through `gnv0` (it forwards and routes 10.0.0.0/8
      back via gnv0); `gwlb` then forwards it on to `dst`.
    - It prints a ping result. The README shows
      `tcpdump -ni <underlay> -w /run/netlab/gnv.pcap udp port 6081`, then
      `tshark -r ... -V` displaying outer IP/UDP 6081/GENEVE (VNI 1) around the
      **unchanged** inner `10.61.0.10 → 10.62.0.10` packet. Map: GWLB keeps the
      original src/dst, adds GENEVE, and uses 5-tuple stickiness.
- [ ] **Step 8: Write `content/day06.md`.** Mandatory coverage:
  - **Why this matters:** an on-prem name resolving to the public IP from inside the VPC
    while overlay traffic dies on large payloads.
  - **Draw it first:** the VXLAN-encapsulated frame (outer Eth/IP/UDP/VXLAN + inner
    frame) and the DNS resolution walk.
  - **Core concepts:**
    - Tunneling as encapsulation with an MTU tax table (GRE 24, VXLAN 50, GENEVE 50+
      options, IPsec ESP ~50–73 depending on cipher/mode); IP-in-IP, GRE, VXLAN (VNI,
      VTEP, UDP 4789, flood-and-learn vs EVPN named), GENEVE (TLV options, UDP 6081)
    - IPsec: IKEv2 SA_INIT and AUTH exchanges, child SAs, ESP header (SPI, sequence),
      tunnel vs transport mode, NAT-T on UDP 4500, DPD
    - DNS: the resolution walk (root → TLD → authoritative), recursive vs authoritative,
      forwarding and conditional forwarding, caching and TTL, negative caching (SOA
      minimum), split-horizon, `search`/`ndots`, the 512-byte UDP limit and EDNS0, TCP
      fallback
    - "L3 without an overlay": ECS awsvpc (ENI per task, ENI trunking) and EKS VPC CNI
      (pods get VPC IPs, warm pools, prefix delegation /28, IP exhaustion symptoms)
  - **Where AWS hides this:**
    - Site-to-Site VPN = 2 IPsec tunnels per connection
    - GWLB = GENEVE to the appliances, carrying the original packet unchanged, with
      flow stickiness (5-tuple)
    - Route 53 Resolver = the VPC +2 resolver; inbound/outbound endpoints and forwarding
      rules; a PHZ is split-horizon
    - DNS Firewall named
    - Link to the TLS course for certificate-related DNS (CAA)
    - "Lab it locally": the resolver forwarding in the main topology and `geneve.sh`.
      "Lab it on AWS": the sibling `aws_network_components` Day 3 (Resolver) and Day 6 (VPN)
  - **Exercises:** 10, including:
    - compute the inner MTU for 4 tunnel stacks (e.g. VXLAN over IPsec over 1500)
    - decode a VXLAN capture
    - a split-horizon design for an on-prem ↔ VPC name
    - an `ndots` puzzle (how many queries does `curl api` make?)
    - when EKS runs out of IPs and the two fixes
    - TTL and negative-cache timing
  - **Anti-patterns:** mistake 8; "raising the MTU on the overlay to match the underlay".
- [ ] **Step 9:** Static checks. The controller runs the live check (confirm which
  Fault A mechanism works and that SOLUTION matches; verify check 4 included), plus
  `geneve.sh up` (ping OK, the capture shows GENEVE with the original inner
  addresses), then `geneve.sh down`.
- [ ] **Step 10: Commit (controller)** `git commit -m "WIP: task 8 day06 (scratch)"`

---

### Task 9: Day 7 — Capstone: one packet end to end + gauntlet

**Files:** Create `content/day07.md`, `labs/day07/{README.md,topo.sh,gauntlet.sh,ANSWERS.md,teardown.md}`

**Interfaces:** Consumes `frr_up`/`vty` from `common.sh` (Task 1) and the unbound
pattern (Task 8). Produces `gauntlet.sh {list|start N|check N|reset}`.

- [ ] **Step 1: Write `topo.sh`** (an AWS-shaped topology in namespaces). Path:
  task → vpcr → tgw → (GRE "VPN") → onp → api.
  - `task` `10.70.1.10/24` gw `.1` (the "ECS task"); its resolv.conf points to `10.70.1.2`.
  - `vpcr` (the "VPC router"): `10.70.1.1`, plus `10.70.255.1/30` to tgw.
    - It also holds `10.70.1.2/24` for the resolver role: unbound in `vpcr`, with
      `forward-zone onprem.corp → 192.168.20.53`.
  - `tgw`: `10.70.255.2/30`; GRE `gre1` local `100.64.0.1` remote `100.64.0.2` over
    `veth tgw wan onp wan` (`100.64.0.0/30`); tunnel `169.254.10.1/30`; FRR AS 64512
    peering with onp over the tunnel.
  - `onp`: tunnel `169.254.10.2/30`; FRR AS 65000 advertising `192.168.0.0/16`
    (a summary via `aggregate-address` with dummy members) and learning `10.70.0.0/16`
    from tgw (tgw advertises `10.70.0.0/16` via a `network` + blackhole null route).
    - LANs: `192.168.10.1/24` to api, `192.168.20.1/24` to odns.
    - nft stateful forward policy: established accept, from 10.70.0.0/16 to
      192.168.10.10 tcp 8080 accept, DNS to odns accept, policy drop.
  - `api` `192.168.10.10/24`: `python3 -m http.server 8080`.
  - `odns` `192.168.20.53/24`: unbound serving `api.onprem.corp → 192.168.10.10`.
  - Set the tunnel MTU to 1476 (GRE: 1500 − 24) and MSS-clamp on tgw
    (`tcp flags syn tcp option maxseg size set rt mtu`).
  - Healthy check:
    `ip netns exec task curl -s --max-time 3 http://api.onprem.corp:8080/` → 200.
  - If PROBE.md recorded FALLBACK for FRR, use static routes on tgw and onp and skip
    incident 3's BGP variant (incident 3 becomes "missing static route").
- [ ] **Step 2: Write `gauntlet.sh`.**
  - `list` prints the 5 symptoms only.
  - `start N` runs `reset` (= `topo.sh up`), injects N, and writes the fault.
  - `check N` runs the healthy check plus incident-specific checks and prints PASS/FAIL.
  - `reset` rebuilds.
  - Incidents (symptom → injection):
    1. "Health check OK, large responses hang" → remove the MSS clamp on tgw, set
       `ip -n onp link set gre1 mtu 1500`, and drop ICMP frag-needed on tgw output.
    2. "Name resolves, connect times out" → in tgw, `ip route add 192.168.10.0/24 via 10.70.255.1`
       (a more-specific route back into the VPC = a routing loop / TTL-exceeded).
    3. "Everything on-prem unreachable since the change window" → `vty onp` with
       `'configure terminal' 'route-map OUT deny 10' 'router bgp 65000'
       'address-family ipv4 unicast' 'neighbor 169.254.10.1 route-map OUT out'` (the summary is no longer
       advertised).
    4. "curl: Could not resolve host api.onprem.corp" → remove the forward-zone from
       the vpcr unbound config and restart it via `bg`.
    5. "SYN reaches on-prem, nothing comes back" → in onp, delete
       `ct state established,related accept` from the forward chain.
- [ ] **Step 3: Write `ANSWERS.md`.** For each incident: symptom, the first three
  commands a top engineer runs, the evidence line that proves it, the fix, and the AWS
  equivalent (1: VPN MTU and MSS clamping on the CGW; 2: TGW static route
  more-specific; 3: on-prem BGP filter, so TGW propagated routes disappear; 4: Resolver
  outbound rule missing; 5: an on-prem firewall that is not stateful for return
  traffic, or a NACL return range).
- [ ] **Step 4: Write `README.md`.**
  - **Model block (60 min):** a hop table to fill in. For each hop, the learner writes
    the header fields that change (src/dst MAC, TTL, outer IPs, conntrack entries) and
    which table decides.
  - **Prove (30 min):** capture at `task eth0`, `tgw wan` and `onp lan` simultaneously
    (three `tcpdump -w` in the background), then compare.
  - **Gauntlet (90 min):** `gauntlet.sh start 1..5` in order, 20 min each, journal
    evidence first. Then a self-score rubric (diagnosed with evidence in time = 2,
    diagnosed late = 1, guessed = 0).
- [ ] **Step 5: Write `content/day07.md`** (300–400 lines).
  - **Why this matters:** an outage that crossed four teams' boundaries.
  - **Draw it first:** the full path with every table that decides.
  - **Core concepts:** the hop-by-hop walkthrough (DNS → ARP to the gateway → VPC
    router LPM → TGW RT lookup → IPsec/GRE encapsulation + MTU → BGP-learned route →
    on-prem firewall conntrack → app socket), with an "AWS readout" table mapping each
    local hop to the AWS construct and its failure signature.
  - **Prove it on the wire:** reading the three captures.
  - **Lab:** gauntlet instructions.
  - **Where AWS hides this:** the readout table again, plus the sibling course Day 8
    Reachability Analyzer as the AWS-side tool.
  - **Exercises:** 8 cross-day synthesis problems.
  - **Anti-patterns:** a recap of all 8 mistakes.
  - **Teardown.**
- [ ] **Step 6: Write `teardown.md`.**
- [ ] **Step 7:** Static checks (the Day-task contract with dayNN=07, minus SOLUTION
  which is ANSWERS here).
- [ ] **Step 7b (controller): live check.**
  - `topo.sh up` → healthy curl = 200.
  - For N in 1..5: `gauntlet.sh start N`, then `gauntlet.sh check N` (expect FAIL),
    apply the ANSWERS fix, then `gauntlet.sh check N` (expect PASS).
  - `topo.sh down`, and confirm no daemons are left.
- [ ] **Step 8: Commit (controller)** `git commit -m "WIP: task 9 day07 capstone (scratch)"`

---

### Task 10: Primers and glossary

**Files:** Create `content/primers/headers.md`, `content/primers/subnet-math.md`,
`content/primers/tcpdump-filters.md`, `content/primers/bgp-best-path.md`, `content/GLOSSARY.md`

**Interfaces:** Consumes the day files (Tasks 3–9): the terms and commands actually used.

- [ ] **Step 1: Write `headers.md`.** ASCII bit-layout diagrams (RFC style, 32-bit rows)
  for Ethernet II, 802.1Q, ARP, IPv4, IPv6, ICMP, ICMPv6 NS/NA, TCP, UDP, GRE, VXLAN,
  GENEVE and ESP. Under each: a "debug fields" list (field → what it tells you →
  where you saw it in the labs: `dayNN`).
- [ ] **Step 2: Write `subnet-math.md`.**
  - The block-size method, a /8–/32 table (hosts, block, mask)
  - Summarization and containment
  - IPv6 nibble boundaries
  - 30 drills with answers in a collapsed `<details>` per drill (hint + answer)
- [ ] **Step 3: Write `tcpdump-filters.md`.**
  - Per-day recipes (exact commands used in the labs)
  - BPF primitives: `host`, `net`, `port`, `tcp[tcpflags]`, `icmp[icmptype]`, `vlan`,
    `udp port 4789`, `esp`
  - `-e -n -v -S -x -w/-r`
  - tshark display-filter equivalents
  - Reading a three-point capture
- [ ] **Step 4: Write `bgp-best-path.md`.** The FRR best-path order and the AWS
  route-preference order side by side, the AD table, and 6 worked decisions.
- [ ] **Step 5: Write `GLOSSARY.md`.** Alphabetical, plain English, ≥ 80 terms drawn
  from the day files (every term in a day file's `## Core concepts` bold text must
  appear). Each entry: one or two sentences plus `(Day N)`.
- [ ] **Step 6: Static checks.**
  - Every `**term**` in `content/day0*.md` Core concepts appears in GLOSSARY: a script
    extracts `\*\*[^*]+\*\*` from the day files and checks each term case-insensitively
    with `/usr/bin/grep -qi`; print the missing ones (expect none).
  - Drill count in subnet-math = 30.
- [ ] **Step 7: Commit (controller)** `git commit -m "WIP: task 10 primers + glossary (scratch)"`

---

### Task 11: COVERAGE.md and sibling cross-links

**Files:**
- Create: `COVERAGE.md`
- Modify: `../aws_network_components/README.md` (append 1 line at the end)
- Modify: `../linux_ops_mastery/README.md` (append 1 line at the end)

- [ ] **Step 1: Write `COVERAGE.md`.** Mirror the shape of `linux_ops_mastery/COVERAGE.md`:
  - (a) a networking-fundamentals objective table (CCNA 200-301 "Network Fundamentals"
    and "IP Connectivity" topics, plus CompTIA Network+ concepts) → Day / Where.
  - (b) an AWS ANS-C01 domain table (Network Design, Network Implementation,
    Management & Operation, Security/Compliance/Governance) → Day / Where, or
    "sibling course: aws_network_components Day N".
  - (c) "Deliberately skipped, and why": wireless, STP depth, OSPF configuration, QoS,
    SD-WAN, multicast, Cloud WAN, VPC Lattice, IPAM. Each gets a one-line "closing the
    gap later" recipe.
- [ ] **Step 2: Append the cross-links.**
  - `aws_network_components/README.md`: `> **Next:** go below the constructs to the protocols — see [../network_engineering_mastery/README.md](../network_engineering_mastery/README.md).`
  - `linux_ops_mastery/README.md`: `> **Next:** Day 6 seen from the wire — see [../network_engineering_mastery/README.md](../network_engineering_mastery/README.md).`
- [ ] **Step 3: Check** — `tail -1` of each sibling README shows the line, and
  `git diff --stat ../aws_network_components ../linux_ops_mastery` shows exactly 2 files,
  +1 line each (controller).
- [ ] **Step 4: Commit (controller)** `git commit -m "WIP: task 11 coverage + links (scratch)"`

---

### Task 12: Whole-course live verification + fact-check

**Files:** Modify any file with defects found. Write the results into the
`labs/netlab/PROBE.md` `## Verification log` section.

- [ ] **Step 1 (controller):** From a fresh `docker compose -p netlab down && up -d --build`,
  rerun the Day-task live check for Days 1–6 back to back and the Day 7 gauntlet loop.
  Log each result line.
- [ ] **Step 2 (controller):** Run the whole-tree sweeps:
```bash
cd network_engineering_mastery
/usr/bin/grep -rnE '\b[0-9]{12}\b' . --include='*' | /usr/bin/grep -v '/.terraform/'          # no account IDs
/usr/bin/grep -rniE '(aws_secret|secret_key|BEGIN (RSA|OPENSSH)|psk *=)' .                   # expect none
for f in $(find . -name '*.sh'); do bash -n "$f" || echo "SYNTAX $f"; done
/usr/bin/grep -rnL '## Teardown' content/day0*.md                                           # expect none
```
- [ ] **Step 3: Fact-check dispatch** (one subagent, model `sonnet`, with WebSearch).
  - Input: the list of `<!-- fact-check -->` lines
    (`/usr/bin/grep -rn 'fact-check' content labs aws_lab README.md`) plus the protocol
    claims in the Core concepts sections.
  - It verifies against current AWS docs and RFC 9293/4271/7348/8926/1191/8201.
  - It returns a table: claim | file:line | verdict | correct value | source URL. It
    must not edit files.
- [ ] **Step 4 (controller):** Apply the corrections, remove the `<!-- fact-check -->`
  markers from verified lines, and commit
  `git commit -m "WIP: task 12 live verification + fact-check (scratch)"`.

---

### Task 13: Final review + scratch-branch teardown

- [ ] **Step 1:** Dispatch one final reviewer (most capable model).
  - Input: the spec, this plan, and a **file manifest** (`find network_engineering_mastery -type f | sort`),
    not full contents. It reads selectively.
  - It checks: the spec's success criteria each map to a day and an exercise or lab;
    the skeleton is consistent; links resolve; the voice is consistent.
- [ ] **Step 2 (controller):** Fix what the reviewer finds (Critical/Important); log
  Minor items in `ENHANCEMENTS.md` at the course root.
- [ ] **Step 3 (controller):** Teardown, in this exact order:
```bash
git reset --soft master
git switch master
git reset
git branch -D authoring/network_engineering_mastery
git status      # expect: network_engineering_mastery/ untracked, 2 sibling READMEs modified, nothing else
```
- [ ] **Step 4:** Hand off. Summarize to the learner what was built and verified, the
  open items in ENHANCEMENTS.md, and that the single AWS lab (`aws_lab/day04`) was validated but not
  applied. The learner commits.
