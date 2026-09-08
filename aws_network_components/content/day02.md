# Day 2 — Security Layer

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain precisely why Security Groups are stateful and NACLs are stateless,
  and what "stateful" means at the TCP level
- Name the OSI layer at which each operates
- Explain why a missing NACL ephemeral-port rule breaks TCP, **in either
  direction**, and work out which direction's rule a given failure needs
- Use VPC Flow Logs to confirm whether a packet was allowed or rejected at
  the network level
- Reference a Security Group by ID in another Security Group's rule, and
  explain why this is better than CIDR-based rules for service-to-service

---

## Security Groups

A Security Group (SG) is a stateful, virtual firewall attached to an ENI
(Elastic Network Interface). It is not attached to an instance — it is
attached to the network interface. This distinction matters when you work with
ECS (each task has its own ENI), RDS (multi-AZ has multiple ENIs), and Lambda
in VPC mode (Lambda creates ENIs in your subnet). When you think "what SG
controls this resource," ask "what ENI does this resource use."

**Stateful** means the SG tracks connection state. If you allow inbound TCP
on port 443, the response traffic (the TCP packets coming back from the server
to the client on an ephemeral port) is automatically allowed without any
explicit outbound rule. The SG tracks the connection tuple
(src IP, src port, dst IP, dst port, protocol) and knows the outbound
packet is a response to an allowed inbound connection.

**Default behaviour:**
- Inbound: deny all (no inbound rules = nothing can reach the ENI)
- Outbound: allow all (default rule: `0.0.0.0/0` on all protocols)

You explicitly add inbound rules. The default outbound allow is commonly
kept as-is, though you can restrict it for high-security environments.

**SG-to-SG referencing:**
Instead of allowing port 8080 from `10.0.0.0/24` (a CIDR), allow it from
`sg-app-web-sg` (a SG ID). When the app SG's ENIs scale out (new tasks,
auto-scaling), the rule doesn't need updating — it already applies to all
ENIs in that SG. CIDR-based rules require knowing the IP range in advance
and fail when IPs change.

```
# Bad: CIDR rule
Inbound: TCP 8080 from 10.0.2.0/24

# Good: SG reference
Inbound: TCP 8080 from sg-0abc123 (web-sg)
```

SG references also reach across some network boundaries, but the restrictions
matter more than the capability:

- **Intra-region VPC peering:** supported. **Cross-region peering: not
  supported** — you must fall back to CIDR rules.
- **Transit Gateway (same region):** supported, but **off by default**. It has
  to be turned on explicitly, on both the TGW and the attachment
  (`security_group_referencing_support = "enable"`). The Day 4 TGW module in
  this course leaves it disabled, so do not expect a cross-VPC SG reference to
  work there unless you enable it.

If a SG reference silently behaves as "deny", check that you are in one of the
supported cases before debugging anything else.

---

## Network ACLs

A Network ACL (NACL) is a stateless firewall attached to a subnet. Every
subnet has exactly one NACL. Rules are evaluated in order by rule number
(lowest first); the first matching rule wins.

**Stateless** means the NACL has no memory of connections. Every packet is
judged on its own, against the rules for the direction it happens to be
travelling. A reply is not "the other half of a connection" — it is a brand
new packet arriving from the opposite direction.

That single fact produces **two** distinct failure modes, and confusing them is
the most common mistake in this entire topic. Which ephemeral rule you need
depends on **who opened the connection**.

**Case 1 — something outside connects *in* to a server in your subnet.**
Inbound TCP 8080 is allowed, so the client's SYN arrives fine. Your server
replies with a SYN-ACK **from** port 8080 **to** the client's ephemeral port.
That reply is an *outbound* packet whose destination port is ephemeral, so it
is judged by the **outbound** rules. With no outbound ephemeral rule it is
dropped, and the client's connection hangs.

```
client:54321  ──SYN──────────▶  server:8080     inbound rule: port 8080   ✅
client:54321  ◀─SYN-ACK──────   server:8080     OUTBOUND rule: port 54321 ← needs ephemeral
```

**Case 2 — a client in your subnet connects *out* to something else.**
This is what any instance doing `yum update`, calling an API, or registering
with SSM is doing. Your client sends a SYN **from** its ephemeral port **to**
the server's port 443, judged by the **outbound** rules (destination port 443).
The server's SYN-ACK comes back **to** your ephemeral port — an *inbound*
packet, judged by the **inbound** rules.

```
client:54321  ──SYN──────────▶  server:443      outbound rule: port 443   ✅
client:54321  ◀─SYN-ACK──────   server:443      INBOUND rule: port 54321  ← needs ephemeral
```

Same missing concept, opposite rule. **Ask "who sent the first packet?" and the
direction follows.** Case 1 needs outbound ephemeral; Case 2 needs inbound
ephemeral. A subnet that both hosts services and makes outbound calls — which
is nearly every private subnet — needs **both**.

The symptom is identical in both cases: a connection that appears to establish
(no immediate `Connection refused`) and then times out. Engineers assume it's an
application issue; it's a NACL missing an ephemeral rule in one direction.

**Ephemeral port range:** TCP clients pick a random source port for each
connection from the ephemeral range (OS-dependent, but 1024–65535 covers all
common cases).

**The source/destination CIDR is the part people get wrong.** It is tempting to
scope the inbound ephemeral rule to your VPC CIDR, "to be safe." But in Case 2
the reply comes from wherever the server lives — an S3 endpoint, an SSM
endpoint, some vendor API — so an inbound ephemeral rule scoped to
`10.0.0.0/16` silently bans every reply from outside the VPC. The instance can
still talk to its neighbours and nothing else, which reads like a broken NAT
Gateway or broken DNS and sends you debugging the wrong layer entirely.

The **port range** is the control on an ephemeral rule. The source cannot be.
Scope inbound ephemeral to `0.0.0.0/0` and rely on the fact that nothing is
listening on those ports; if you need real inbound protection, that is the SG's
job, not the NACL's.

**Rule number ordering:** NACL rules are numbered and evaluated in ascending
order. Rule 100 is checked before rule 200. If rule 100 ALLOWS and rule 200
DENIES for the same traffic, rule 100 wins. This is opposite to SG logic
(SGs always take the most permissive match). Use rule numbers with gaps
(100, 200, 300…) so you can insert rules later without renumbering.

**Default NACL:** The default NACL that comes with a new VPC allows all
inbound and outbound traffic. If you create a custom NACL, it denies
everything by default (implicit DENY at the end). You must explicitly add
ALLOW rules.

---

## VPC Flow Logs

Flow Logs capture metadata about IP traffic flowing through a VPC, subnet,
or ENI. They record:
- Source and destination IPs and ports
- Protocol
- Packets and bytes
- Start and end time
- **Action: ACCEPT or REJECT**

They do NOT capture packet content. Use them to answer: "did this packet
arrive at the ENI? Was it allowed or rejected?"

Flow Logs are sent to CloudWatch Logs, S3, or Kinesis Data Firehose.
CloudWatch Logs is easiest for ad-hoc queries during this course.

The aggregation interval determines how often log records are flushed:
1-minute intervals mean you wait at most 1 minute to see a record after
the event. 10-minute is the default and cheaper, but too slow for debugging.

**Reading a Flow Log record:**
```
2 123456789 eni-xxx 10.0.2.5 203.0.113.1 443 54321 6 10 840 1234567890 1234567900 ACCEPT OK
```
Fields (v2 format): version, account-id, interface-id, srcaddr, dstaddr,
srcport, dstport, protocol (6=TCP), packets, bytes, start, end, action, log-status.

**CloudWatch Logs Insights query pattern:**
```
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, action
| filter action = "REJECT"
| sort @timestamp desc
| limit 50
```
This is your first debugging step when a connection fails: confirm whether
the packet is being rejected at the network layer before suspecting the
application.

---

## The two-gate model

Think of the security architecture as two independent gates in series:

```
Internet / another VPC
        │
   NACL gate (subnet boundary)
   - Stateless
   - Rule-number ordered
   - Must allow both inbound AND outbound (ephemeral ports)
        │
   SG gate (ENI boundary)
   - Stateful (return traffic auto-allowed)
   - Allow-only (no explicit DENY rules)
   - Can reference other SGs
        │
   EC2 / Lambda / ECS task ENI
```

A packet must pass BOTH gates. A misconfigured NACL can block traffic even
if the SG allows it, and vice versa. When debugging, check both.

---

## Best practices

- Reference Security Groups by ID for service-to-service rules, not CIDR.
  This is the most underused feature of SGs and the most important for
  platform-scale environments.
- Never use `allow all` as your final NACL configuration. The default NACL
  allows everything — create custom NACLs with explicit rules for any subnet
  that handles sensitive traffic.
- Allow ephemeral ports (TCP 1024–65535) in **both** directions on any NACL
  attached to a subnet that both serves traffic and makes outbound calls —
  which is nearly every private subnet. Outbound ephemeral covers replies your
  servers send; inbound ephemeral covers replies your clients receive. Scope
  the inbound one to `0.0.0.0/0` — the port range is the control, not the source.
- Enable Flow Logs on every VPC in production, with 1-minute aggregation.
  The cost is low; the debugging value is high.
- Put Flow Logs in a separate CloudWatch Log Group per VPC so queries don't
  mix traffic from different networks.

---

## Common pitfalls

- **Missing a NACL ephemeral rule — in whichever direction.** The symptom is
  the same either way: the connection hangs rather than being refused. Work out
  who opened the connection. Inbound connections to your servers need
  *outbound* ephemeral; outbound connections from your clients need *inbound*
  ephemeral. Fixing the wrong direction changes nothing and burns an hour.
- **Scoping the inbound ephemeral rule to the VPC CIDR.** Replies arrive from
  wherever the far end lives, which is usually outside the VPC. This one breaks
  package installs, SSM registration and S3 access while leaving VPC-internal
  traffic working — a confusing partial failure.
- **Forgetting SGs are attached to ENIs.** Changing an instance's SG doesn't
  move the SG to a new ENI — if you're using ECS with awsvpc mode, each
  task gets its own ENI and its own SG assignment. Check the task definition,
  not the cluster.
- **Using CIDR rules for service-to-service in a VPC.** IP addresses change.
  Auto-scaling changes which IPs are active. SG-to-SG references are stable.
- **Trusting the default NACL.** The default NACL allows all traffic — it is
  not a security control. Create custom NACLs with explicit allow rules for
  any subnet where you want to enforce traffic policy.
- **Not checking Flow Logs before escalating.** Most networking tickets can
  be closed in 5 minutes by searching Flow Logs for REJECT entries. Check
  them first.

---

## Exercises

Answer before starting the lab:

1. Two scenarios on the same NACL. Trace the packet path for each and name
   the exact rule direction that is missing:
   a. A client outside sends a TCP SYN to port 443 on an EC2 in the subnet.
      The NACL allows inbound 443 but has no outbound ephemeral rule.
   b. An EC2 in the subnet runs `curl https://example.com`. The NACL allows
      outbound 443 but has no inbound ephemeral rule.
   Why is the observed symptom identical, and how would you tell them apart?
2. You have 5 microservices. Service A must reach Services B, C, and D on
   port 8080, but not Service E. How would you configure SGs so this works
   without any CIDR rules?
3. VPC Flow Logs show `REJECT` for packets from `10.0.0.5` to `10.0.2.10`
   on port 5432. You check the SG on the destination ENI and it allows port
   5432 from `10.0.0.0/16`. What should you check next?
4. What is the difference between a Security Group with no inbound rules
   and a NACL that denies all inbound traffic? Are they equivalent?

## Lab reference

Follow Day 2 in the implementation plan:
`aws_network_components/docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`

## Journal template

```
### Day 2 — Security Layer
Key concept in my own words: ...
What confused me (NACL stateless behaviour, SG referencing, Flow Logs): ...
Break-it exercise — missing ephemeral port rule: what I observed in Flow Logs: ...
```
