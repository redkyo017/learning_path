# AWS Network Mastery Plan

**Date:** 2026-07-17
**Status:** Approved design

## Purpose

Reach production-credible AWS networking competence in 8 days (4–6 hours/day,
~40–48 hours total) for an integration platform engineer whose team owns
cross-service, cross-account, and hybrid connectivity on AWS. The goal is not
certification — it is the ability to design, build, debug, and reason about
real integration platform networks confidently: VPCs, Transit Gateway,
PrivateLink, hybrid VPN, and multi-account topologies. All lab infrastructure
is cumulative and Terraform-managed, ending in a working reference architecture
that mirrors real team infrastructure.

## Learner context

- Background: AWS basics (EC2, S3, IAM), networking is largely a black box.
  Fast learner. Terraform experience exists but is rusty (was used previously,
  not recently active — expects to rebuild fluency quickly through labs).
- Role: integration platform team. Responsible for connecting services, teams,
  and accounts — cross-service connectivity, cross-account exposure, hybrid
  on-prem links, and inheriting/reasoning about existing network infrastructure.
- Motivation: catching up with the team's existing depth on AWS networking
  as fast as possible, while building genuine understanding rather than
  surface-level familiarity.
- Tooling: AWS Console (primary for learning) + Terraform (team's production
  stack). Labs always run Console first, then Terraform — console visibility
  builds the mental model, Terraform codifies what is already understood.
- AWS access: full personal sandbox account, no restrictions. Resources are
  torn down at the end of each day to control cost.

## Unconventional strategy — what the top 1% actually do

Most beginners read docs, watch videos, then try a tutorial. They waste time
because they learn concepts in isolation, without a forcing function that
requires them to *explain* what they built or *fix* what broke.

The accelerated approach used here has three rules:

**1. Trace every packet.**
Before touching any service, internalize one question: *where does this packet
enter, what decision point does it hit, and where does it exit?* Every AWS
networking concept is just a decision point on a packet's path. Security groups,
NACLs, route tables, NAT Gateway, TGW — they are all packet-routing decisions.
This mental model collapses weeks of memorization into a single framework.

**2. Build one coherent infrastructure, not isolated toy labs.**
Each day's lab extends the previous day's Terraform module. By Day 8, the
accumulated infrastructure is a real reference architecture: two VPCs, a
Transit Gateway, a simulated on-prem VPN endpoint, a PrivateLink service,
cross-account connectivity, and DNS spanning all boundaries. Understanding how
each day's addition interacts with previous days is what makes knowledge stick.

**3. Break it deliberately after building it.**
After every lab, introduce one intentional misconfiguration and diagnose it
using the correct tools (Reachability Analyzer, Flow Logs, the 5-layer ladder).
Debugging under controlled conditions — when you already know the answer —
builds the intuition that makes real incidents fast to resolve.

## Mistakes that waste 80% of beginners' time

1. **Treating Security Groups and NACLs as the same thing.** They are not.
   SGs are stateful and attached to ENIs. NACLs are stateless and attached to
   subnets. Forgetting NACLs are stateless — and not allowing ephemeral ports
   on outbound rules — causes hours of silent failures that look like
   application bugs.

2. **Building flat single-subnet VPCs.** Beginners put everything in one
   subnet. Real architectures always have three tiers: public (load balancers,
   NAT), private (application), isolated/data (RDS, ElastiCache). Retrofitting
   tiers into a flat VPC is painful — design correctly on day one.

3. **Thinking VPC peering is transitive.** It is not. VPC A peered to B, B
   peered to C — A cannot reach C. This surprises almost every beginner and
   leads to over-peering or broken topologies. Transit Gateway exists precisely
   to solve this.

4. **Routing S3 traffic through NAT Gateway.** NAT Gateway charges per GB
   of data processed. S3 gateway endpoints are free and keep traffic on the
   AWS backbone. This is a common hidden cost and a simple fix.

5. **Hardcoding IP addresses instead of DNS names.** One redeployment or
   failover changes the IP, and everything that references it breaks silently.
   DNS names are the contract; IPs are an implementation detail.

6. **Using static routes in VPN instead of BGP.** Static routes require manual
   intervention during tunnel failover. BGP handles it automatically. There is
   no good reason to use static routes in a production VPN.

7. **Running a single VPN tunnel.** AWS terminates VPN endpoints for
   maintenance. Two tunnels (different Availability Zones) is the minimum for
   any non-trivial workload.

8. **Not knowing Reachability Analyzer exists.** Most engineers spend hours
   guessing which rule is blocking traffic. Reachability Analyzer runs a
   path analysis and tells you exactly which rule is the blocker, down to the
   resource ID and rule number. It takes 60 seconds to run.

9. **Confusing "private subnet" with "isolated subnet."** A private subnet has
   a route to NAT Gateway (can reach the internet outbound). An isolated subnet
   has no outbound internet route at all (database tier). Calling both "private"
   causes architectural confusion.

10. **Writing Terraform before understanding what the Console built.**
    When Terraform fails or produces unexpected state, engineers who skipped the
    console step have no reference for what correct looks like. Always build
    console-first.

## Structure

### Daily format

Each day follows four sequential blocks:

| Block | Duration | Content |
|---|---|---|
| Theory | ~1.5 hrs | Concepts, mental models, diagrams, key distinctions, anti-patterns |
| Lab guide | ~30 min | Step-by-step walkthrough — exactly what to build and why |
| Console lab | ~1.5 hrs | Execute in AWS Console; every setting is visible |
| Terraform lab | ~1.5 hrs | Rebuild the same infrastructure as code |

Total per day: ~5 hours. On higher-energy days, extend the Terraform lab or
add the "break it" exercise (intentional misconfiguration + diagnosis).

### 8-day arc

| Phase | Days | Theme |
|---|---|---|
| Foundation | 1–3 | VPC anatomy, security layer, DNS |
| Cross-boundary | 4–6 | Peering/TGW, PrivateLink/Endpoints, Hybrid/VPN |
| Integration Platform | 7–8 | Multi-account networking, debugging and reachability |

### Cumulative infrastructure

Labs are not isolated. Each day's Terraform extends a shared module:

- Days 1–3: Base VPC (`shared-services-vpc`) — 3 tiers, 2 AZs, security, DNS
- Day 4: Second VPC (`app-vpc`) + Transit Gateway connecting both
- Day 5: VPC endpoints on both VPCs + PrivateLink service on shared-services
- Day 6: Simulated on-prem EC2 + Site-to-Site VPN into TGW
- Day 7: Second AWS account consuming shared-services via RAM + cross-account TGW attachment
- Day 8: Intentional failure injection across the full topology + reachability analysis

By Day 8 the Terraform codebase is a working reference architecture for an
integration platform network.

## Day-by-day breakdown

---

### Day 1 — VPC Anatomy

**Theory**

Start with the packet-tracing mental model: every packet has an origin, hits
decision points, and reaches a destination or is dropped. CIDR blocks define
address space. Subnets divide that space across Availability Zones. Route
tables define where packets go. The Internet Gateway (IGW) is the on-ramp to
the public internet. NAT Gateway lets private-subnet resources initiate
outbound internet connections without being directly reachable inbound.

Key distinctions:
- **Public subnet:** has a route to IGW (`0.0.0.0/0 → igw-xxx`)
- **Private subnet:** has a route to NAT Gateway (`0.0.0.0/0 → nat-xxx`)
- **Isolated subnet:** no default route at all — database tier

Design rule: always allocate CIDRs with room to grow. A `/16` VPC with `/24`
subnets gives 256 subnets — use at least `/20` per VPC in real environments.

**Lab guide**

Build `shared-services-vpc`:
- CIDR: `10.0.0.0/16`
- 2 Availability Zones (AZ-a and AZ-b)
- Per AZ: one public subnet (`/24`), one private subnet (`/24`), one isolated subnet (`/24`)
- One IGW attached to the VPC
- One NAT Gateway in each public subnet (two total — one per AZ for HA)
- Public route table: `0.0.0.0/0 → IGW`, associated to all public subnets
- Private route table per AZ: `0.0.0.0/0 → NAT-{az}`, associated to private subnets
- Isolated route table: no default route, associated to isolated subnets

**Console lab**

Create the VPC via the VPC Console wizard. Observe every field: CIDR validation,
subnet association panels, route table entries, IGW attachment state. Use the
VPC resource map view to confirm the topology visually before moving on.

Break-it exercise: delete one NAT Gateway route from a private route table.
Try to reach `8.8.8.8` from an EC2 in that private subnet. Observe the failure
and restore.

**Terraform lab**

Resources: `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, `aws_eip`,
`aws_nat_gateway`, `aws_route_table`, `aws_route_table_association`.

Structure the code as a reusable `vpc` module from day one — subsequent days
pass new variables rather than rewriting the module.

---

### Day 2 — Security Layer

**Theory**

Two independent security gates, different levels, different semantics:

- **Security Groups (SGs):** stateful (return traffic is automatically allowed),
  attached to ENIs (not instances — this matters for ECS, Lambda, RDS),
  evaluated as a set (all rules checked, most permissive wins). Default: deny
  all inbound, allow all outbound.
- **NACLs:** stateless (return traffic must be explicitly allowed), attached to
  subnets, evaluated in rule-number order (first match wins). Default: allow all.

Because NACLs are stateless, inbound port 443 allowed is not enough — outbound
ephemeral ports (1024–65535) must also be allowed or the response is dropped.
This is the single most common NACL debugging failure.

VPC Flow Logs capture metadata (src IP, dst IP, port, protocol, action) at
the ENI, subnet, or VPC level. They do not capture packet payload. Use them to
confirm whether traffic is reaching an ENI and whether SG/NACL is allowing it.

**Lab guide**

Add to `shared-services-vpc`:
- SG for a web tier: allow inbound 443 from `0.0.0.0/0`, allow outbound to app-tier SG on port 8080
- SG for an app tier: allow inbound 8080 from web-tier SG only (reference by SG ID, not CIDR)
- SG for a data tier: allow inbound 5432 from app-tier SG only
- NACL for private subnets: allow inbound 8080, allow outbound ephemeral 1024–65535 back to web tier
- VPC Flow Logs → CloudWatch Logs, 1-minute aggregation, `ALL` traffic

**Console lab**

Build and test each SG. Verify that web-tier cannot directly reach data-tier.
Enable Flow Logs and trigger a rejected connection — observe the `REJECT` entry
in CloudWatch within 1–2 minutes.

Break-it exercise: remove the ephemeral outbound NACL rule. Observe connection
establishment fails even though the inbound rule allows it. Restore and
re-verify.

**Terraform lab**

Resources: `aws_security_group`, `aws_security_group_rule`,
`aws_network_acl`, `aws_network_acl_rule`, `aws_cloudwatch_log_group`,
`aws_flow_log`, `aws_iam_role` (for Flow Logs delivery).

---

### Day 3 — DNS Inside VPC

**Theory**

By default, AWS provides DNS resolution via the VPC DNS resolver (at the
base CIDR + 2 address, e.g., `10.0.0.2`). This resolves public AWS service
endpoints and gives EC2 instances their internal hostnames.

Route 53 private hosted zones extend this: you define a domain (e.g.,
`internal.platform`) and associate it with one or more VPCs. Resources in
those VPCs resolve names in that zone — resources outside do not (split-horizon
DNS).

Route 53 Resolver endpoints handle hybrid DNS:
- **Inbound endpoint:** on-prem DNS servers forward AWS-bound queries to this ENI
- **Outbound endpoint:** AWS forwards on-prem-bound queries out to on-prem DNS servers via a Resolver rule

Plan your DNS namespace before you build anything else. Retrofitting DNS names
across a multi-account organization — after teams have hardcoded IPs and
endpoints — is one of the most disruptive migrations an integration team faces.

**Lab guide**

Add to `shared-services-vpc`:
- Enable `enableDnsSupport` and `enableDnsHostnames` on the VPC (verify they are on)
- Private hosted zone: `internal.platform` associated to `shared-services-vpc`
- A record: `api.internal.platform → 10.0.1.10` (placeholder for a future service)
- Resolver inbound endpoint: two ENIs in private subnets (one per AZ)
- Resolver outbound endpoint: two ENIs in private subnets, with a forward rule for `corp.internal → 10.10.0.2` (simulated on-prem DNS, used fully in Day 6)

**Console lab**

Create the hosted zone and verify resolution from an EC2 instance using
`dig api.internal.platform`. Confirm the record resolves inside the VPC and
does not resolve from outside it (split-horizon behavior).

Break-it exercise: disassociate the hosted zone from the VPC. Run the same
`dig` — observe NXDOMAIN. Reassociate and verify resolution restores.

**Terraform lab**

Resources: `aws_route53_zone`, `aws_route53_record`,
`aws_route53_resolver_endpoint`, `aws_route53_resolver_rule`,
`aws_route53_resolver_rule_association`.

---

### Day 4 — VPC Peering vs Transit Gateway

**Theory**

When services in different VPCs need to communicate, there are two options:

- **VPC Peering:** a direct, bilateral connection between exactly two VPCs.
  Non-transitive: A↔B and B↔C does not give A↔C. Route tables on both sides
  must be updated manually. Cost: free (data transfer charges still apply).
  Use case: 2–3 VPCs, simple mesh.

- **Transit Gateway (TGW):** a managed regional hub. VPCs attach to the TGW;
  the TGW routes between them. Transitive by design. Supports multiple TGW
  route tables — use them to segment prod/dev/shared traffic. Cost: per-hour
  per attachment + per-GB data transfer.

Decision rule: if you have more than 3 VPCs or expect growth, use TGW.
N VPCs fully meshed with peering requires N*(N-1)/2 peering connections —
45 connections for 10 VPCs. TGW requires N attachments.

TGW route table segmentation is the underused power feature. A separate route
table for `shared-services` (reachable from all attachments) versus `prod` and
`dev` (isolated from each other) gives you network-level blast radius control
without additional cost.

**Lab guide**

Create `app-vpc`:
- CIDR: `10.1.0.0/16`, same 3-tier subnet structure as Day 1
- TGW: attach both `shared-services-vpc` and `app-vpc`
- TGW route tables:
  - `shared-services-rt`: propagate routes from all attachments (reachable by all)
  - `app-rt`: propagate only `shared-services-vpc` routes (app VPC cannot reach other app VPCs)
- Update VPC route tables: private subnets in each VPC add a route for the other VPC's CIDR via TGW attachment

**Console lab**

Create the TGW, attach both VPCs, configure route tables. Launch EC2s in the
private subnets of each VPC and verify cross-VPC connectivity. Then verify
that two hypothetical "app VPCs" cannot reach each other (demonstrate the
route table isolation).

Break-it exercise: remove the TGW route from `app-vpc`'s private route table.
Confirm connectivity fails. Restore and re-verify.

**Terraform lab**

Resources: `aws_ec2_transit_gateway`, `aws_ec2_transit_gateway_vpc_attachment`,
`aws_ec2_transit_gateway_route_table`,
`aws_ec2_transit_gateway_route_table_association`,
`aws_ec2_transit_gateway_route_table_propagation`.

---

### Day 5 — VPC Endpoints + PrivateLink

**Theory**

Two types of VPC endpoints keep traffic off the public internet:

- **Gateway endpoints** (S3, DynamoDB only): free, implemented as route table
  entries. Traffic stays on the AWS backbone. No ENI, no DNS change.
- **Interface endpoints**: an ENI in your subnet with a private IP. Most AWS
  services support these (SSM, Secrets Manager, ECR, STS, etc.). DNS resolves
  the service's public hostname to the private ENI IP inside the VPC.

**PrivateLink** is the mechanism for exposing *your own services* privately.
You front your service with a Network Load Balancer (NLB), create an endpoint
service from the NLB, and consumers create interface endpoints that point to
your endpoint service. The consumer VPC never needs peering, TGW attachment, or
route table changes — they just create an endpoint.

For an integration platform: PrivateLink is the canonical pattern for exposing
shared services to consuming teams. You own and manage the NLB and endpoint
service; consumers manage their own endpoint. Clean, scalable, no route table
sprawl.

**Lab guide**

On `shared-services-vpc`:
- S3 gateway endpoint: add to all private and isolated route tables
- SSM interface endpoint: ENIs in both private subnets (enable private DNS)
- Secrets Manager interface endpoint: ENIs in both private subnets
- PrivateLink service: deploy a placeholder Nginx on an EC2, front with NLB,
  create endpoint service, whitelist the `app-vpc` account for consumption
- On `app-vpc`: create interface endpoint pointing to the PrivateLink service,
  verify that an EC2 in `app-vpc` can reach the Nginx through the endpoint

**Console lab**

Verify S3 traffic uses the gateway endpoint by checking the route table entry
and using VPC Flow Logs to confirm no traffic leaves to the internet.
Verify SSM Session Manager works from a private EC2 (no public IP, no bastion)
via the interface endpoint.

Break-it exercise: disable private DNS on the SSM endpoint. Observe that
`ssm.eu-west-1.amazonaws.com` now resolves to a public IP. Session Manager
fails. Re-enable and verify.

**Terraform lab**

Resources: `aws_vpc_endpoint` (gateway and interface types), `aws_lb`,
`aws_lb_listener`, `aws_lb_target_group`, `aws_vpc_endpoint_service`,
`aws_vpc_endpoint_service_allowed_principal`.

---

### Day 6 — Hybrid Connectivity

**Theory**

Site-to-Site VPN connects an on-premises network to AWS over the public
internet using IPSec tunnels. Each VPN connection has two tunnels (different
AWS endpoints in different AZs) — both should be active (active/active) for HA.

Key components:
- **Virtual Private Gateway (VGW)** or TGW VPN attachment: the AWS side
- **Customer Gateway (CGW):** represents the on-prem VPN device (IP + BGP ASN)
- **VPN connection:** the logical IPSec connection between CGW and VGW/TGW

Use BGP (dynamic routing) over static routes. BGP advertises routes
automatically and withdraws them on tunnel failure — static routes require
manual updates. BGP ASNs: AWS side is 64512 by default; use a private ASN
(64512–65534) for the customer gateway.

Route 53 Resolver outbound endpoints (built on Day 3) are now activated: the
Resolver rule forwards `corp.internal` queries to the simulated on-prem DNS
server over the VPN tunnel.

Direct Connect (DX) is not lab-able without real hardware, but understand the
concepts: dedicated circuit from on-prem to an AWS Direct Connect Location,
private VIF (to a VGW) or transit VIF (to TGW), hosted or dedicated connection.
DX is for bandwidth-sensitive or latency-sensitive workloads where VPN
throughput (max ~1.25 Gbps per tunnel) is insufficient.

**Lab guide**

Simulate on-prem using an EC2 in a separate, non-peered VPC (`onprem-sim-vpc`,
CIDR `192.168.0.0/16`):
- Install strongSwan on the EC2 to act as a software VPN router
- Customer Gateway: use the EC2's Elastic IP
- VPN connection: attach to the TGW (not a VGW — TGW is the correct hub for
  multi-VPC hybrid)
- TGW route table: add a route for `192.168.0.0/16` via the VPN attachment
- BGP: advertise `192.168.0.0/16` from strongSwan, receive `10.0.0.0/8` summary

Activate the Day 3 Resolver rule: verify that `nslookup corp.internal` from
an EC2 in `shared-services-vpc` resolves via the VPN to the simulated on-prem DNS.

**Console lab**

Monitor both VPN tunnel states in the Console (target: both UP). Run a
`traceroute` from `shared-services-vpc` to the simulated on-prem EC2 to
confirm traffic traverses the VPN. Observe BGP-learned routes in the TGW
route table.

Break-it exercise: bring down one tunnel (stop strongSwan on one VPN config).
Verify traffic fails over to the second tunnel automatically. Restore and verify
both tunnels return to UP.

**Terraform lab**

Resources: `aws_customer_gateway`, `aws_vpn_connection`,
`aws_ec2_transit_gateway_vpn_attachment`,
`aws_ec2_transit_gateway_route_table_propagation` (for VPN attachment).

strongSwan configuration on the EC2 is applied via `user_data` in
`aws_instance` — the tunnel config is generated from Terraform output values
(pre-shared keys, tunnel IPs) so nothing is hardcoded.

---

### Day 7 — Multi-Account Networking

**Theory**

AWS accounts are security blast-radius boundaries, not network boundaries.
A misconfiguration in one account should not cascade to others. The network
spans accounts — the integration platform team owns the shared network
infrastructure that other teams consume.

Patterns:

- **Resource Access Manager (RAM):** share a subnet (from a VPC you own) to
  another account. That account can launch resources directly into your subnet.
  They don't own the VPC — just the ENIs they create in it.
- **Cross-account TGW attachment:** a second account's VPC can attach to
  your TGW (with the owner's acceptance). Traffic routes through the TGW as
  normal.
- **Cross-account PrivateLink:** a consumer account creates an interface endpoint
  pointing to your endpoint service in a different account. No peering, no TGW
  needed — just the endpoint and the service.

The integration platform topology: you own the TGW, the shared-services VPC,
and the PrivateLink endpoint services. Other teams own their workload VPCs and
attach to your TGW. They consume your services via PrivateLink. You control
connectivity policy; they control their workloads.

**Lab guide**

Using a second AWS account (sandbox sub-account or a second personal account):
- RAM: share a private subnet from `shared-services-vpc` to account B
- Account B: launch an EC2 into the shared subnet (no VPC setup required)
- Cross-account TGW: create a VPC in account B (`tenant-vpc`, CIDR `10.2.0.0/16`),
  request attachment to the TGW in account A, accept in account A, add routes
- Cross-account PrivateLink: account B creates an interface endpoint pointing
  to the Day 5 endpoint service in account A — verify connectivity

**Console lab**

Use two browser sessions (one per account). Observe that account B sees the
shared subnet in its subnet list even though the VPC belongs to account A.
Verify cross-account PrivateLink connection goes through `pending acceptance →
available` state transition.

Break-it exercise: revoke account B's principal from the endpoint service
allowlist. Observe the endpoint moves to `rejected` state. Re-allow and verify
it returns to `available`.

**Terraform lab**

Resources: `aws_ram_resource_share`, `aws_ram_resource_association`,
`aws_ram_principal_association`. For cross-account, use a second Terraform
provider block with `assume_role` pointing to account B's role ARN.

```hcl
provider "aws" {
  alias  = "account_b"
  region = "eu-west-1"
  assume_role {
    role_arn = var.account_b_role_arn
  }
}
```

---

### Day 8 — Debugging and Reachability Analysis

**Theory**

The 5-layer debugging ladder — work bottom-up, eliminate each layer before
moving to the next:

1. **Route table:** does a route exist from source to destination?
2. **NACL:** does a stateless rule allow the traffic in both directions?
3. **Security Group:** does a stateful rule allow the inbound connection?
4. **Endpoint policy:** if a VPC endpoint is in the path, does its resource policy allow the action?
5. **IAM:** does the calling identity have permission for the API/resource?

Most connectivity failures live at layers 1–3. Most "I can reach the endpoint
but the call fails" issues live at layers 4–5.

**VPC Reachability Analyzer:** define a source ENI and a destination ENI
(or gateway), run an analysis. It returns either "reachable" with the path, or
"not reachable" with the exact blocking component (route table entry, SG rule,
NACL rule) and its resource ID. Costs ~$0.10 per analysis. Use it before filing
any networking ticket.

**Network Access Analyzer:** org-wide scan that checks for network paths that
violate policy (e.g., "no internet-facing resources in isolated subnets").
Useful for compliance and drift detection.

**VPC Flow Logs query pattern (Athena):**
```sql
SELECT srcaddr, dstaddr, srcport, dstport, protocol, action
FROM vpc_flow_logs
WHERE dstport = 443
  AND action = 'REJECT'
  AND starttime >= 1700000000
LIMIT 100;
```

**Lab**

Introduce 5 intentional failures in the Day 1–7 infrastructure, one at a time.
Diagnose each using the 5-layer ladder and Reachability Analyzer:

1. Remove the TGW route from `app-vpc` private route table (layer 1 failure)
2. Add a NACL DENY rule for port 8080 before the ALLOW rule (layer 2 failure)
3. Remove the inbound rule from the app-tier SG (layer 3 failure)
4. Add a restrictive endpoint policy to the S3 gateway endpoint (layer 4 failure)
5. Revoke the cross-account TGW attachment acceptance (multi-layer failure)

For each: predict the failure before running Reachability Analyzer, then
confirm with the tool. This calibrates intuition against the tool.

**Terraform lab**

Resources: `aws_ec2_network_insights_path`,
`aws_ec2_network_insights_analysis`. Automate the reachability checks as
Terraform data sources — if the analysis returns `not_reachable`, the
`terraform plan` surface shows it.

---

## Terraform module structure

```
aws_network_components/
  terraform/
    modules/
      vpc/           # reusable VPC module (Day 1)
      security/      # SGs, NACLs, Flow Logs (Day 2)
      dns/           # Route 53 PHZ, Resolver (Day 3)
      tgw/           # Transit Gateway, attachments, route tables (Day 4)
      endpoints/     # VPC endpoints, PrivateLink service (Day 5)
      vpn/           # Customer GW, VPN connection (Day 6)
      ram/           # Resource Access Manager shares (Day 7)
    envs/
      sandbox/       # root module wiring everything together
        main.tf
        variables.tf
        outputs.tf
```

Each day: add one new module. The `sandbox` root module imports and wires them.
By Day 8 the root module is the full reference architecture.

## Cost control

| Resource | Daily cost estimate | Teardown |
|---|---|---|
| NAT Gateway (2x) | ~$0.10/hr each = ~$1.00/day | `terraform destroy` each evening |
| Transit Gateway | ~$0.05/hr + $0.02/GB | destroy each evening |
| VPN connection | ~$0.05/hr per tunnel | destroy after Day 6 |
| EC2 instances (t3.micro) | ~$0.01/hr each | destroy each evening |
| Reachability Analyzer | ~$0.10 per analysis | pay-per-use |

Estimated total: ~$15–20 for all 8 days if resources are torn down each evening.

## Tools and setup

- AWS CLI configured with sandbox account credentials
- Terraform >= 1.6, AWS provider >= 5.0
- strongSwan (for Day 6 VPN simulation) — installed via EC2 `user_data`
- A second AWS account for Day 7 (sub-account in the same organization, or a
  separate personal account)
- `dig`, `nslookup`, `traceroute`, `curl` available on EC2 AMIs (Amazon Linux 2023)

## Success criteria

By the end of Day 8, the learner should be able to:

- Design a multi-tier VPC from a blank CIDR block, with correct subnet sizing,
  route tables, and HA across AZs
- Explain exactly why a packet is dropped or allowed, citing the specific
  SG rule, NACL rule, or route table entry responsible
- Build any of the above infrastructure in Terraform from memory, referencing
  the AWS provider docs for argument names — not copying from tutorials
- Read an existing VPC topology in the Console or Terraform state and explain
  what each component does and why it exists
- Diagnose a connectivity failure in under 10 minutes using the 5-layer ladder
  and Reachability Analyzer
- Explain the trade-off between VPC Peering and Transit Gateway, and choose
  correctly for a given topology
- Expose a service privately to another account using PrivateLink
- Explain how hybrid DNS resolution works and configure Resolver endpoints
  for an on-prem/AWS split-horizon setup
