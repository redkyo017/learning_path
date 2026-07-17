# Day 8 — Debugging and Reachability Analysis

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Apply the 5-layer debugging ladder to any connectivity failure, in order,
  without skipping layers
- Run a VPC Reachability Analyzer analysis and interpret the output — both
  when the path is reachable and when it is not
- Write a Flow Logs Insights query to find REJECT entries for a specific
  source/destination pair
- Predict which layer is responsible for a failure given a symptom description
- Identify when to use Reachability Analyzer vs Flow Logs vs manual inspection

---

## The 5-layer debugging ladder

When a connectivity complaint arrives, work through these layers bottom-up.
Eliminate each layer before moving to the next. Most failures are at layers
1–3; don't start at 5.

```
Layer 5: IAM
  - Does the calling identity have permission for the API/resource?
  - Symptom: 403 AccessDenied or AuthFailure from the service
  - Tool: CloudTrail, IAM policy simulator

Layer 4: Endpoint policy
  - If a VPC endpoint is in the path, does its resource policy allow the action?
  - Symptom: 403 from S3/Secrets Manager/etc even though IAM is correct
  - Tool: VPC endpoint policy, CloudTrail

Layer 3: Security Group
  - Does an inbound SG rule on the destination ENI allow the traffic?
  - Symptom: connection refused or timed out, Flow Logs show REJECT at ENI
  - Tool: VPC Reachability Analyzer, Flow Logs, Console SG viewer

Layer 2: NACL
  - Does a NACL rule block the traffic (inbound or outbound ephemeral)?
  - Symptom: connection hangs (SYN sent, no SYN-ACK), Flow Logs show REJECT
  - Tool: VPC Reachability Analyzer, Flow Logs, NACL rule view

Layer 1: Route
  - Does a route exist from source to destination at every hop?
  - Symptom: connection timed out with no Flow Log entry at destination
  - Tool: VPC Reachability Analyzer, route table inspection, TGW route table
```

**Where to start:** Layer 1. If the route doesn't exist, nothing else matters.
A missing route means the packet is never even delivered to the destination
subnet — Flow Logs on the destination ENI will show nothing.

**The classic mistake:** starting at layer 5 (IAM) because the error message
mentions "Access Denied." Access denied errors can come from IAM (layer 5)
OR from an endpoint policy (layer 4). Check both. But confirm layers 1–3
are fine first — a misconfigured SG can make an application return an
HTTP 403 that looks like an IAM error.

---

## VPC Reachability Analyzer

Reachability Analyzer is a static network path analysis tool. You define a
source and destination (ENI, instance, subnet, gateway, etc.), and it
analyzes whether a packet can travel from source to destination given the
current network configuration.

**What it checks:**
- Route tables (every hop, including TGW route tables)
- Security Groups (inbound and outbound rules)
- NACLs (inbound and outbound rules)
- VPC endpoint policies
- TGW route table associations and propagations

**What it does NOT check:**
- IAM permissions
- Application-layer issues
- Route 53 DNS resolution
- Whether the destination application is listening

**Cost:** $0.10 per analysis. Run it before filing a ticket.

**How to interpret results:**

*Reachable:*
```
Status: Reachable
Network path found: Yes
Path: EC2-A ENI → Subnet-A NACL → TGW → Subnet-B NACL → EC2-B ENI
```
Each hop is shown with the specific rule or route table entry that allowed
the traffic. This also tells you the exact path the packet takes — useful
for understanding your topology.

*Not reachable:*
```
Status: Not reachable
Explanation: NACL rule 50 in nacl-0abc123 denies traffic
Component: network-acl (nacl-0abc123)
Direction: Ingress
Rule action: Deny
Rule number: 50
```
The output names the exact blocking resource with its AWS resource ID.
Copy that ID and go fix it.

**Running from CLI:**
```bash
# Create a path
aws ec2 create-network-insights-path \
  --source i-0abc123 \
  --destination i-0def456 \
  --protocol TCP \
  --destination-port 8080 \
  --profile sandbox --region ap-southeast-1

# Start an analysis
aws ec2 start-network-insights-analysis \
  --network-insights-path-id nip-xxx \
  --profile sandbox --region ap-southeast-1

# Get the result (wait ~30 seconds)
aws ec2 describe-network-insights-analyses \
  --network-insights-analysis-ids nia-xxx \
  --profile sandbox --region ap-southeast-1 \
  --query "NetworkInsightsAnalyses[0].{Reachable:NetworkPathFound,Explanation:Explanations}"
```

---

## Network Access Analyzer

Network Access Analyzer is different from Reachability Analyzer. Instead of
checking "can A reach B," it scans your entire network for paths that violate
a policy you define.

Example policies:
- "No resources in isolated subnets should have a path to the internet"
- "Only resources with tag `Tier=public` should be reachable from the internet"
- "No direct VPC-to-VPC paths should exist without going through our inspection firewall"

This is a compliance and drift detection tool. Run it periodically (or via
a scheduled Lambda) to catch networking misconfigurations before they cause
a security incident.

---

## VPC Flow Logs — query patterns

When Reachability Analyzer says "reachable" but the application still fails,
or when you need to confirm a packet is arriving at the right ENI, query Flow
Logs.

**Setup (if not already done on Day 2):**
Enable VPC-level flow logs to CloudWatch with 1-minute aggregation. Log
group: `/vpc/shared-services/flow-logs`.

**Query: find all REJECT entries in the last hour**
```
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, protocol, action
| filter action = "REJECT"
| sort @timestamp desc
| limit 100
```

**Query: did this specific source IP reach this destination?**
```
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, action
| filter srcAddr = "10.0.2.5" and dstAddr = "10.1.2.10"
| sort @timestamp desc
| limit 20
```

**Query: is traffic reaching the destination ENI at all?**
```
fields @timestamp, interfaceId, srcAddr, dstAddr, dstPort, action
| filter interfaceId = "eni-0abc123" and dstPort = 8080
| sort @timestamp desc
| limit 20
```

If no records appear for an expected flow, the packet is not reaching that
ENI — a routing or upstream NACL issue. If records appear with `ACCEPT`, the
packet is reaching the ENI — check the SG and NACL on the destination, or the
application itself.

---

## Failure symptom → likely layer mapping

| Symptom | Start checking |
|---|---|
| `Connection timed out`, no Flow Log at destination | Layer 1 (route) |
| `Connection timed out`, REJECT in Flow Logs before destination | Layer 2 (NACL) |
| `Connection refused` immediately | Layer 3 (SG) or application not listening |
| Connection established, then `Access Denied` from service | Layer 4 (endpoint policy) |
| `AuthFailure` or `AccessDenied` from AWS API | Layer 5 (IAM) |
| Intermittent failures, one AZ only | Missing route or NACL in one AZ's route table |
| Works from one subnet, not another | NACL or route table difference between subnets |

---

## Best practices

- Run Reachability Analyzer before touching any configuration. It takes 30
  seconds and tells you exactly what's wrong. Don't guess.
- Keep Flow Logs retention at 7 days minimum. Connectivity issues often
  surface hours after they began — you need the history.
- When a developer reports a connectivity issue, ask them for:
  1. The source instance ID or private IP
  2. The destination IP/hostname and port
  3. The protocol (TCP/UDP)
  This is the minimum information to run Reachability Analyzer.
- Always check both directions. A connection from A to B might succeed
  but B to A might be blocked — this matters for stateful protocols.
- Network Access Analyzer is your drift detection tool. Set it up once,
  run it on a schedule, alert on findings.

---

## Common pitfalls

- **Running Reachability Analyzer between a hostname and an IP.** Reachability
  Analyzer works on ENI/instance/gateway resource IDs, not IP addresses or
  DNS names. Find the instance ID or ENI ID first.
- **Checking SG before checking the route.** A packet that has no route is
  never inspected by an SG. Check routes first.
- **Missing the ephemeral port check in NACLs.** A Reachability Analyzer
  result of "reachable" for the forward direction doesn't guarantee the
  return traffic is allowed. The tool checks a single direction per analysis.
  Run a second analysis for the return path if needed.
- **Assuming Flow Logs capture dropped packets immediately.** With 1-minute
  aggregation, you wait up to 1 minute after an event. With 10-minute
  aggregation (the default), you wait up to 10 minutes. Don't conclude
  "no traffic is arriving" after looking at logs for 30 seconds.
- **Not checking TGW route tables.** Reachability Analyzer does check TGW
  route tables, but manual inspection sometimes misses them. When traffic
  crosses VPCs, always check the TGW route table for both the source
  attachment and the destination attachment.

---

## Exercises

Answer before starting the lab:

1. A developer says "Service A (in `shared-services-vpc`) cannot reach
   Service B (in `app-vpc`) on port 8080." Walk through the 5 layers in
   order. At each layer, state what you would check and what tool you would use.
2. Reachability Analyzer returns `not reachable` and identifies a NACL as
   the blocking component. The NACL is on the destination subnet and has
   rule 100 ALLOW TCP 8080 inbound. What might explain the block?
3. Flow Logs for `eni-abc` show no records for traffic from `10.0.2.5` to
   `eni-abc` on port 5432, even though you expected traffic to be flowing.
   What does this tell you about where the packet is being dropped?
4. After fixing a NACL rule, Reachability Analyzer now shows `reachable`,
   but the developer still reports the connection failing. What should you
   check next?

## Lab reference

Follow Day 8 in the implementation plan:
`aws_network_components/docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`

## Journal template

```
### Day 8 — Debugging and Reachability
Key concept in my own words: ...
Which failure layer was hardest to predict, and why: ...
5-layer ladder applied to the 5 failures: which layer each was at, and what
the Reachability Analyzer output told me: ...
```
