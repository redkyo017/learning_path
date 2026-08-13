# Day 17 — Cloud Network Security

## Objectives

By the end of today you should be able to:

- Say precisely what a **VPC** and a **subnet** are, and what makes a subnet
  **public** vs **private** — not "public subnets have public IPs" (a symptom) but the
  actual mechanism (whether its route table sends `0.0.0.0/0` to an Internet Gateway).
- Read a **security group**'s rules and identify exactly which ones are over-permissive,
  and why `0.0.0.0/0` on a sensitive port is a categorically different risk than
  `0.0.0.0/0` on an intentionally public one.
- Explain the mechanical difference between a **security group** and a **NACL** —
  stateful vs stateless, instance-level vs subnet-level, allow-only vs allow-and-deny,
  unordered vs rule-number-ordered — precisely enough to say when you'd reach for each.
- Scan a real EC2 instance's public IP from outside its VPC with `nmap` and read the
  result as *evidence* of what its security group actually allows, not just trust the
  rule table on paper.
- Tighten an over-permissive security group, add a NACL rule as a second layer, and
  re-run the same scan to prove — not assume — that the fix worked.
- Read what a **VPC Flow Log** record actually captures (and doesn't) for a scan
  against your instance, and say why that's a fundamentally different kind of evidence
  than a packet capture.

This day assumes you already know how to *build* a VPC — subnets, route tables,
Internet Gateways, NAT — from prior AWS networking work. Today doesn't re-teach that
construction; it puts a **security lens** on the same constructs: which of them create
exposure, how an attacker finds that exposure from outside, and how you'd catch them
doing it. If any term below (route table, IGW, NAT gateway) is unfamiliar as a
*mechanism*, that's a gap to close with general AWS networking material first — this
day only covers the security-specific layer on top.

## 1. Concept — VPC, Subnets, SG vs NACL, Exposure, and Flow Logs

### VPC and subnets, restated through a security lens

A **VPC** (Virtual Private Cloud) is an isolated IPv4/IPv6 address space you define
inside an AWS account — nothing inside it is reachable from outside unless you
explicitly build a path in. A **subnet** is a slice of that address space pinned to one
Availability Zone. Subnets don't inherently have any security properties of their own —
what makes a subnet **public** or **private** is entirely about its **route table**:

- **Public subnet** — its route table has a route for `0.0.0.0/0` pointing at an
  **Internet Gateway (IGW)**. An instance in it *can* be reached from the internet, but
  only if it *also* has a public IP **and** its security group allows the inbound
  traffic. All three conditions — IGW route, public IP, permissive SG — have to hold
  together; missing any one of them means no direct inbound path exists.
- **Private subnet** — no route to an IGW. Instances here can't be reached directly
  from the internet no matter what their security group says, because there's no path
  in at the network-routing layer at all. They can still reach *out* to the internet
  (for package updates, API calls) via a **NAT Gateway** sitting in a public subnet,
  which lets outbound traffic leave and its replies come back, without ever opening an
  inbound path.

The security implication: **a subnet's route table is a precondition for exposure, and
a security group is a second, independent gate on top of it.** Today's lab plants the
misconfiguration entirely in the second gate — a public subnet with a security group
that's far more open than the instance's actual job requires — because that's the
single most common real-world cloud network mistake: the routing is (correctly) public,
but nobody scoped the SG down from "wide open" to "only what this instance needs."

### Security groups vs NACLs — two different gates, not one gate twice

Both **security groups (SGs)** and **network ACLs (NACLs)** filter traffic in a VPC, and
it's tempting to treat them as redundant. They are not — they operate at different
layers with different semantics, and knowing exactly which is which is the difference
between correctly layering defenses and just duplicating the same rule twice:

| | Security Group | NACL |
|---|---|---|
| **Attaches to** | An instance / ENI | A subnet (every instance in the subnet inherits it) |
| **State** | **Stateful** — allow the inbound request, and the matching outbound reply is automatically allowed, no matching rule needed | **Stateless** — inbound and outbound are two completely separate rule sets; a reply needs its own explicit outbound rule (commonly, ephemeral high ports) |
| **Rule types** | **Allow only** — there's no "deny" rule; anything not explicitly allowed is implicitly denied | **Allow and explicit Deny** — you can write a rule that actively blocks specific traffic even if something else would otherwise allow it |
| **Evaluation** | All rules across all attached SGs are evaluated together; if *any* rule allows it, it's allowed | Rules are evaluated **in ascending rule-number order**, and the **first match wins** — order matters |
| **Default** | A new custom SG denies all inbound, allows all outbound | The VPC's **default NACL** allows all inbound and outbound (it looks permissive by design, precisely so a fresh VPC's SGs are the layer doing real filtering out of the box) |

The practical reason to use both together: a **security group is your primary,
per-instance control** — day to day, this is what you should be tightening to least
privilege. A **NACL is a coarser, subnet-wide backstop** — useful for a rule you want
enforced *regardless* of what any individual instance's SG says (e.g., "nothing in this
subnet ever talks to this one bad IP range, full stop, even if someone fat-fingers an SG
rule later"). Today's Defense Lab uses exactly this pattern: fix the SG (the real
fix), then add a NACL deny as a second, independent layer that doesn't depend on anyone
remembering the SG fix later.

### VPC Flow Logs — connection metadata, not packet contents

A **VPC Flow Log** is a capture of the *metadata* AWS's network layer sees for every
"flow" (roughly: one connection attempt) at an ENI, subnet, or VPC level: source and
destination IP, source and destination port, protocol, packet/byte counts, and —
critically for security work — whether the flow was **ACCEPT**ed or **REJECT**ed, which
directly reflects the SG/NACL decision that let it through or blocked it. This is a
fundamentally different kind of evidence than a **packet capture** (Day 2's `tcpdump`):
Flow Logs never contain payload — you cannot recover *what* was sent, only *that* an
attempted connection happened, from where, to what port, and whether it was allowed.
That's exactly the right level of detail for "did someone scan me, and did my
defenses hold" — which is precisely today's Defense Lab question — without the
storage cost or sensitivity of capturing full traffic.

## 2. Attack/Assess Lab — Find the Over-Permissive SG, Scan It From Outside

**Authorized sandbox only.** Everything below runs in **your own AWS sandbox
account**, using a **named AWS CLI profile** (`export AWS_PROFILE=<your-profile>` —
never a hardcoded access key). Do not point any command below, or the `nmap` scan in
Step 3, at any AWS account, instance, or IP address you don't own or don't have
explicit written authorization to test. This lab's `setup.sh` plants a genuinely
internet-reachable, deliberately over-permissive instance — treat it with the same
care as any real exposed asset, and tear it down promptly (`teardown.sh`, see
`labs/day17/README.md`).

### Step 0 — Stand up the lab

```sh
cd cyber_security/labs/day17
export AWS_PROFILE=<your-sandbox-profile>
./setup.sh
```

This provisions a VPC, a public subnet (route table → IGW), a security group with
**one intended rule and two planted risky rules**, and a `t3.micro` EC2 instance
running a small web server — the "legitimate" service the SG is nominally there to
protect. `setup.sh` prints the instance's `SG_ID`, `INSTANCE_ID`, and public IP at the
end; you'll need the public IP for Step 3. Full detail: `labs/day17/README.md`.

### Step 1 — Read the security group's rules, don't assume them

```sh
aws ec2 describe-security-groups --group-ids <SG_ID> \
  --query 'SecurityGroups[0].IpPermissions'
```

**What you should see:** three ingress rules. One (`80/tcp` from `0.0.0.0/0`) is the
service this instance is actually meant to run. The other two are the planted
misconfiguration — full detail on exactly what and why is in
[`labs/day17/SOLUTION.md`](../labs/day17/SOLUTION.md), but the general method is: for
*every* ingress rule with a source of `0.0.0.0/0`, ask "does the world genuinely need
to reach this specific port on this specific instance?" A public web server answering
on `80` or `443` — yes, that's the job. `22` (SSH), `3389` (RDP), a database port
(`3306`, `5432`), or an internal admin/API port open the same way — no, and each is a
real, common finding in actual cloud security assessments.

### Step 2 — Look for the widest possible rule: a full port-range open to the world

The single most dangerous pattern to check for specifically — worse than any one named
port — is a rule spanning a **large port range** (or literally `0-65535`) from
`0.0.0.0/0`. That single rule silently makes *every* future service anyone starts on
this instance internet-reachable by default, with no additional SG change needed —
which is exactly why it's worth calling out as its own category in the drills below,
separate from any individual named-port rule.

### Step 3 — Scan the instance from outside its VPC

Run this from your own machine (or the `labs/base` attacker container — either is
"outside" in the sense that matters here: neither is inside this instance's VPC, so
this reproduces what an actual internet-based attacker sees, unlike Day 2's ARP-spoof
lab which required being on the *same local segment*):

```sh
nmap -Pn -p 22,80,443,3306,3389,8080 <PUBLIC_IP>
```

**What you should see:** `80/tcp open` (the intended service) **and** `22/tcp open`
(the planted risky rule) — both reachable from the public internet, confirmed by an
actual external scan rather than inferred from the rule table alone. This is the
whole point of "assess," not just "read": Step 1 told you what the rules *say*; Step 3
proves what's *actually reachable*, which is the only thing that matters to a real
attacker.

### Step 4 — Confirm the full-range rule's blast radius

```sh
nmap -Pn -p1-1000 <PUBLIC_IP>
```

**What you should see:** still just `22` and `80` open right now, because nothing
else is *listening* on this instance yet — but every one of those 1000 ports is
*reachable* at the network layer because of the `0-65535` rule from Step 2. That
distinction matters: the SG isn't currently exposing anything extra today, but it has
zero ability to stop whatever gets started on this box tomorrow (a debug server, a
forgotten test service, malware) from being instantly internet-facing. That's the
real risk a full-range `0.0.0.0/0` rule represents — not what's open *now*, but the
complete absence of a gate for what opens *later*.

### Verify

```sh
nmap -Pn -p 22,80 <PUBLIC_IP> | grep -c "open" 
```

Expected: `2` — both the intended (`80`) and the planted risky (`22`) rule confirmed
open from outside. Full walkthrough: `labs/day17/SOLUTION.md`.

## 3. Defense Lab — Least Privilege, NACL Layering, and Flow Logs

### Defense 1 — Tighten the security group to least privilege (re-verify with the same scan)

Remove both planted risky rules, then replace the SSH rule with one scoped to only
your own IP (if you need SSH at all — for this lab's purposes, you don't, since
nothing here requires an interactive session):

```sh
SG_ID=<from setup.sh output>
aws ec2 revoke-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 0-65535 --cidr 0.0.0.0/0
aws ec2 revoke-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr 0.0.0.0/0
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr "${MY_IP}/32"
```

Re-run **exactly** Step 3's scan from Section 2:

```sh
nmap -Pn -p 22,80,443,3306,3389,8080 <PUBLIC_IP>
```

**What you should see now:** `80/tcp open` (unchanged — still the intended service)
and `22/tcp filtered` or `closed` from any vantage point other than your own IP — the
identical scan, against the identical instance, now reports a materially different
result purely because the SG rules changed. This is the same "fix, rebuild, re-attack,
prove it" discipline Day 4's defenses used: a fix you haven't re-verified with the same
tool you attacked with is still just a claim.

### Defense 2 — Add a NACL rule as a second, independent layer

Find the subnet's (default) NACL and add an explicit deny for the same risky port,
as a backstop that doesn't depend on the SG staying correct forever:

```sh
SUBNET_ID=<from setup.sh output>
NACL_ID=$(aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=${SUBNET_ID}" \
  --query 'NetworkAcls[0].NetworkAclId' --output text)
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" \
  --rule-number 90 --protocol tcp --port-range From=22,To=22 \
  --cidr-block 0.0.0.0/0 --rule-action deny --ingress
```

Why this is genuinely a *second* layer and not a duplicate of Defense 1: if someone
later re-opens `22/tcp` on the security group by mistake (a very common real-world
regression), this NACL rule still blocks it at the subnet boundary — because NACL
evaluation doesn't consult the SG at all, and vice versa. Losing one layer doesn't
silently lose both.

### Defense 3 — Turn on VPC Flow Logs, then read what the Attack Lab's scan actually left behind

```sh
VPC_ID=<from setup.sh output>
aws logs create-log-group --log-group-name /cyberlab/day17/vpc-flow-logs
ROLE_ARN=$(aws iam create-role --role-name day17-flow-logs-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"vpc-flow-logs.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  --tags Key=Project,Value=cyberlab-day17 --query 'Role.Arn' --output text)
aws iam put-role-policy --role-name day17-flow-logs-role \
  --policy-name day17-flow-logs-write \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["logs:CreateLogStream","logs:PutLogEvents","logs:DescribeLogGroups","logs:DescribeLogStreams"],"Resource":"*"}]}'
aws ec2 create-flow-logs --resource-type VPC --resource-ids "$VPC_ID" \
  --traffic-type ALL --log-destination-type cloud-watch-logs \
  --log-group-name /cyberlab/day17/vpc-flow-logs \
  --deliver-logs-permission-arn "$ROLE_ARN" \
  --tag-specifications 'ResourceType=vpc-flow-log,Tags=[{Key=Project,Value=cyberlab-day17}]'
```

Give it a few minutes to start delivering, then re-run Section 2's Step 3 scan once
more and query for it:

```sh
aws logs filter-log-events --log-group-name /cyberlab/day17/vpc-flow-logs \
  --filter-pattern "ACCEPT"
```

**What you should see:** flow records for your scanning IP against ports `22` and
`80` marked `ACCEPT` (before Defense 1) — matching exactly what `nmap` independently
observed as "open," from a second, completely different source of evidence. After
Defense 1's fix, re-running the same query (now filtering for `REJECT` on port `22`)
shows the identical scan traffic now logged as blocked — the SG's decision made
visible after the fact, without needing to have been watching live when it happened.
This is precisely why Flow Logs matter for detection: you don't need to catch a scan
in progress to know it happened — the ACCEPT/REJECT record is durable evidence,
queryable well after the fact. Drill 3 below asks you to reason through this
ACCEPT-vs-REJECT distinction without needing a live account.

### Defense 4 — Named but not re-demonstrated here: private subnets + NAT, full segmentation

Migrating this lab's running instance into a private subnet (no public IP, no IGW
route, egress only via a NAT Gateway in a paired public subnet) is the architecturally
correct fix for anything that doesn't need to be *directly* internet-reachable at all —
stricter than "tighten the SG," because it removes the network path entirely rather
than gating it. This lab names the pattern precisely rather than re-building it live,
for the same honest-scoping reason Day 4 named session regeneration without
re-attacking it: doing so here would mean re-architecting (and re-provisioning) the
instance mid-lab rather than demonstrating the fix on the exact resource the Attack Lab
already assessed. The concrete shape of the fix: put the instance in a private subnet;
put a NAT Gateway (or NAT instance, for stricter cost control) in a public subnet; add
a private route table sending `0.0.0.0/0` to the NAT Gateway; if the instance's job
genuinely requires being reachable from the internet, front it with a load balancer or
bastion in the public subnet instead of giving the instance itself a public IP directly
— the general segmentation principle from Day 2, applied at the cloud-network layer.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Given these SG rules, list the risky ones and the fix

A security group for a production database-backing instance has these ingress rules:

| Protocol | Port | Source |
|---|---|---|
| tcp | 443 | 0.0.0.0/0 |
| tcp | 3306 | 0.0.0.0/0 |
| tcp | 22 | 10.0.0.0/16 |
| udp | 0-65535 | 0.0.0.0/0 |

Identify every risky rule and state the fix for each.

**Hint:** ask, for each rule, "does the entire internet genuinely need this," and
separately, "is this rule scoped to an exact port, or does it cover an unnecessarily
wide range." One rule here isn't risky at all.

**Solution sketch:**
- `tcp 443 from 0.0.0.0/0` — **not risky**. HTTPS to the world is exactly what a
  public-facing service should allow.
- `tcp 3306 from 0.0.0.0/0` — **risky**. `3306` is MySQL; a database port should
  never be reachable from the entire internet. Fix: restrict the source to only the
  specific security group (or CIDR) of the application tier that actually needs to
  query it — e.g. `--source-group <app-tier-sg-id>` instead of `0.0.0.0/0`.
- `tcp 22 from 10.0.0.0/16` — **not risky as written** (scoped to an internal CIDR,
  not the whole internet) — but worth tightening further in a real environment to the
  specific bastion/admin subnet rather than the entire VPC CIDR, which is a smaller,
  secondary finding, not a critical one.
- `udp 0-65535 from 0.0.0.0/0` — **risky**, and the worst rule in the table for the
  same reason as this lab's planted `tcp 0-65535` rule: a full port range open to the
  world means anything that ever starts listening on UDP on this instance is
  automatically internet-reachable, regardless of whether it's needed today. Fix:
  remove the rule entirely and add only the specific UDP ports (if any) this instance
  actually requires.

### Drill 2 — Security group vs NACL: when does each apply

Give one concrete scenario where a **security group** is the right tool, and one
concrete scenario where a **NACL** is the right tool — and explain why the other one
wouldn't fit as well.

**Hint:** think about the difference between "this one instance's normal job" and "a
rule that must hold no matter what any individual instance's config says."

**Solution sketch:**
- **Security group scenario:** "this specific EC2 instance runs a web server on `443`
  and needs SSH only from the bastion." This is inherently per-instance, stateful
  (you want the reply to an inbound HTTPS request auto-allowed, not a separate
  outbound rule to maintain), and allow-only is fine because there's nothing here you
  need to explicitly block — a NACL would work but adds unnecessary stateless
  bookkeeping (separate inbound/outbound rules for ephemeral ports) for a job an SG
  already does more simply.
- **NACL scenario:** "block a known-malicious CIDR block from reaching *any* instance
  in this entire subnet, regardless of what any individual instance's security group
  allows." This needs an explicit **deny**, which SGs cannot express at all, and it
  needs to apply uniformly to every instance in the subnet without relying on each
  one's SG being configured correctly — exactly Defense 2's pattern above. An SG could
  approximate this only by editing every single attached SG individually, which is
  both more work and one missed instance away from a gap.

### Drill 3 — What would Flow Logs show for this lab's external scan

Before Defense 1's fix, and after it, what specifically would a VPC Flow Log record
show for the `nmap` scan in Section 2, Step 3 — and what would it *not* be able to
tell you?

**Hint:** separate "what decision got logged" (Defense 3's ACCEPT/REJECT field) from
"what data got logged" (5-tuple + counts, never payload) from "what nmap itself does
at the packet level" (Day 2's SYN-scan mechanics) — three different layers of the same
question.

**Solution sketch:** before the fix, Flow Logs would show `ACCEPT` records for the
scanning source IP against destination ports `22` and `80` on the instance's ENI —
because the SG allowed both, and Flow Logs record the actual allow/deny outcome of
that check, not the scan's intent. After Defense 1's fix, an identical scan against
port `22` would instead show a `REJECT` record for that same source/destination/port
combination — the SG's new decision, made durably visible after the fact. What Flow
Logs would **not** show, in either case: any payload, banner, or response content (Day
2's `tcpdump`/`tshark` is the tool for that, not Flow Logs), nor which specific nmap
scan *technique* was used (SYN vs connect vs UDP) — Flow Logs record connection
metadata and the SG/NACL decision, not packet-level protocol behavior.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name the exact risky SG rules you found and confirmed reachable
  with `nmap`, distinguishing what you scanned live from Section 2's own note that
  "outside" here just meant outside the VPC, not a literal different machine.
- **How:** which of the two planted rules (the named `22/tcp` rule, or the full-range
  `0-65535` rule) did you find first by reading the rule table, versus which one the
  scan itself made concrete?
- **What defended it:** of Defense 1–3 (SG tightening, NACL layering, Flow Logs), which
  did you actually run and re-verify with a second scan or a log query, and what
  changed in the observed output?
- **What confused me:** anything about *why* NACLs need separate inbound/outbound rules
  when SGs don't (the stateful/stateless distinction), or about what Flow Logs can and
  can't tell you compared to a packet capture, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (VPC, subnet, security group,
  NACL, Flow Logs, public/private subnet, egress control) to re-explain from memory
  before Day 18, without looking back at this file.
