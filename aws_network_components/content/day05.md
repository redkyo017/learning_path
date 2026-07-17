# Day 5 — VPC Endpoints + PrivateLink

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Distinguish gateway endpoints from interface endpoints — mechanism, cost,
  and which services use each
- Explain why S3 traffic through NAT Gateway is both expensive and unnecessary
- Describe what "private DNS enabled" does for an interface endpoint
- Explain the PrivateLink architecture: NLB, endpoint service, consumer endpoint
- State why PrivateLink is the canonical pattern for integration platforms
  exposing services cross-account

---

## Gateway endpoints

Gateway endpoints are for S3 and DynamoDB only. They work by injecting a
route into your VPC route tables that redirects traffic destined for these
services to the endpoint, rather than sending it through the NAT Gateway or
Internet Gateway.

**How they work:**
When you create a gateway endpoint and associate it with route tables, AWS
adds a route entry:
```
Destination: pl-xxxxxxxxx (prefix list for S3 or DynamoDB)  Target: vpce-xxx
```
This is a managed prefix list — it contains all the public IP ranges for S3
(or DynamoDB) in your region. When your EC2 sends traffic to an S3 IP, the
route table matches this prefix list entry and redirects to the endpoint.
Traffic stays on the AWS backbone; it never leaves to the internet.

**Cost:**
Gateway endpoints are free. There is no per-hour charge and no per-GB
data processing charge.

**Why this matters:**
Without a gateway endpoint, S3 traffic from a private subnet goes through
the NAT Gateway, which charges $0.045/GB of data processed (Singapore
region rate). For a team that moves gigabytes of data to/from S3 daily —
common for data pipelines and log aggregation — this is a significant
unplanned cost. Always create S3 and DynamoDB gateway endpoints for
every VPC that uses these services.

**Limitation:**
Gateway endpoints only work within the same region. You cannot use a gateway
endpoint in `ap-southeast-1` to reach an S3 bucket in `us-east-1`.

---

## Interface endpoints

Interface endpoints work differently from gateway endpoints. Instead of
injecting a route, they create an ENI (Elastic Network Interface) in your
subnet with a private IP address. AWS modifies the DNS record for the service
so that its hostname resolves to the ENI's private IP (when "private DNS
enabled" is checked).

**How they work:**
1. You create an interface endpoint for, say, `ssm.ap-southeast-1.amazonaws.com`
2. AWS creates an ENI in each selected subnet
3. When private DNS is enabled, the DNS resolver inside the VPC returns the
   ENI's private IP when any resource queries `ssm.ap-southeast-1.amazonaws.com`
4. Traffic goes to the ENI, which forwards it to the SSM service over the
   AWS backbone

Without private DNS enabled, the public hostname still resolves to a public
IP. The private endpoint exists but isn't used unless you explicitly change
your application to use the endpoint DNS name.

**Cost:**
Interface endpoints cost $0.01/hr per AZ (for the ENI) plus $0.01/GB data
processed. For high-volume services (ECR image pulls, Secrets Manager),
the per-GB cost can exceed NAT Gateway costs — evaluate per service.

**SSM Session Manager requires three endpoints:**
- `com.amazonaws.REGION.ssm`
- `com.amazonaws.REGION.ssmmessages`
- `com.amazonaws.REGION.ec2messages`

Without all three, Session Manager fails silently. This is the most common
reason "why doesn't SSM work in my private subnet" — one of the three
endpoints is missing.

**Security group for endpoints:**
Interface endpoint ENIs have security groups. The SG must allow inbound TCP
443 from your VPC CIDR (or from the specific SGs of resources that will use
the endpoint). If the SG is too restrictive, the endpoint exists but cannot
be reached.

---

## PrivateLink

AWS PrivateLink is the mechanism for exposing your own services privately to
consumers in other VPCs (including other accounts), without requiring VPC
peering, TGW attachments, or route table changes on the consumer side.

**Architecture:**

```
Provider side (your account):
  [Your service] ← [Target Group] ← [NLB] ← [VPC Endpoint Service]

Consumer side (other team's account):
  [Consumer application] → [Interface Endpoint] → [VPC Endpoint Service]
```

**How it works:**
1. You deploy your service behind a Network Load Balancer (NLB)
2. You create an endpoint service from the NLB (`aws_vpc_endpoint_service`)
3. You whitelist accounts or IAM principals that are allowed to connect
4. A consumer creates an interface endpoint pointing to your endpoint service
5. If you set `acceptance_required = true`, you accept the connection request
6. DNS in the consumer's VPC resolves the endpoint's DNS name to private IPs

The consumer never has visibility into your VPC or your network topology.
They only see the endpoint DNS name and the private IPs of the ENIs it creates
in their subnet. No peering, no route tables to manage on their side.

**Why PrivateLink for integration platforms:**
An integration platform typically owns a set of shared services (an event
bus endpoint, a secrets distribution API, an internal registry). Consuming
teams need to reach these services from their own VPCs and accounts. PrivateLink
gives each team a clean interface: create an endpoint, configure DNS, done.
No coordination needed on routing. No access to your VPC. No shared security
groups. Clean blast-radius isolation.

Compare to TGW-based access: TGW requires both sides to manage route tables,
creates full network reachability (a misconfigured TGW can expose more than
intended), and all traffic is visible to your network team. PrivateLink is
application-level connectivity, not network-level connectivity.

---

## Choosing between endpoint types

| Factor | Use | Endpoint Type |
|---|---|---|
| S3, DynamoDB same region | Gateway (free) |
| AWS services (SSM, ECR, Secrets Manager) | Interface |
| Your own service, same VPC | TGW or direct |
| Your own service, other VPC/account | PrivateLink |
| High-volume traffic cost concern | Compare NAT GW vs interface endpoint $/GB |

---

## Best practices

- Always create S3 and DynamoDB gateway endpoints for every VPC. It's free
  and eliminates accidental NAT Gateway data transfer charges.
- Use the same SG for all interface endpoints in a VPC (`endpoints-sg`) —
  all need port 443 inbound from the VPC CIDR. Don't create per-endpoint SGs.
- Set `acceptance_required = true` on your PrivateLink endpoint service.
  This means you explicitly accept each consumer connection — you control
  who can consume your service, not just who can request it.
- Create endpoints in at least two AZs (two subnets). A single-AZ endpoint
  is a single point of failure.
- For PrivateLink, the NLB must be in the same VPC as the endpoint service.
  The NLB can be internal (private subnets) — it does not need a public
  IP to serve PrivateLink traffic.

---

## Common pitfalls

- **Missing one of the three SSM endpoints.** The symptom is SSM Session
  Manager timing out during connection establishment. Check all three service
  names are present as endpoints.
- **Not enabling private DNS on interface endpoints.** Without it, the service
  hostname resolves to its public IP, and traffic goes through NAT Gateway.
  The endpoint exists but is bypassed.
- **S3 gateway endpoint not added to isolated route tables.** Isolated subnets
  have no default route, but they still need to reach S3 (e.g. for RDS
  enhanced monitoring). Add the gateway endpoint to isolated route tables too.
- **Exposing a service via TGW when PrivateLink is the right choice.**
  TGW gives the consumer full network reachability (potentially to all your
  private subnets), not just access to one service. PrivateLink is
  application-scoped, not network-scoped.
- **PrivateLink NLB health check failures.** If the NLB target group is
  unhealthy, the endpoint service is unreachable even though the endpoint
  connection is `available`. Always check target group health before
  debugging the PrivateLink layer.

---

## Exercises

Answer before starting the lab:

1. Why does an S3 gateway endpoint not appear as a network interface in
   your subnet, but an SSM interface endpoint does?
2. You enable an interface endpoint for Secrets Manager with private DNS.
   An EC2 in the same VPC queries `secretsmanager.ap-southeast-1.amazonaws.com`.
   What IP address does it receive? What path does the request take?
3. A consuming team in another account says they can create an endpoint
   to your service but get `Connection refused` when they try to connect.
   What are the three most likely causes?
4. Your team runs a high-throughput service that processes 10 TB/day from
   S3. You have a gateway endpoint for S3. What is the cost difference
   vs routing through NAT Gateway?

## Lab reference

Follow Day 5 in the implementation plan:
`aws_network_components/docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`

## Journal template

```
### Day 5 — VPC Endpoints + PrivateLink
Key concept in my own words: ...
What confused me (gateway vs interface, private DNS): ...
Break-it exercise — disabling private DNS: what SSM failure looked like: ...
```
