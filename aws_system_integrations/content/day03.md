# Day 3 — Egress + VPC Boundary Patterns

## Why this matters

A payment processor calling a card vault service over the public internet is a PCI DSS scope explosion. Every network device on the path — the NAT gateway, the internet gateway, any peering device — is now in scope for your annual audit. Scope creep means auditor time, remediation cost, and the constant risk of a gap being found.

Egress patterns let you keep data on the AWS backbone entirely. The payment processor calls the vault through a private IP that lives inside your VPC. The packet never leaves the AWS network. No internet gateway, no NAT gateway, no public IP. The PCI assessor scopes only the two VPCs and the endpoint between them.

Beyond PCI, the economics matter too. A single NAT gateway processing 1 TB/month costs ~$45 in data-processing charges alone. A Gateway Endpoint for S3 costs nothing. An Interface Endpoint for SQS costs ~$10/month for the same volume. Fixing the architecture pays back quickly.

## The boundary this manages

The **egress boundary**: what leaves your VPC, to where, and under what security and cost terms.

```
┌───────────────────────────────────────────────────────────┐
│                        VPC                                │
│                                                           │
│  ┌─────────────────┐                                      │
│  │  Private subnet  │                                     │
│  │  (Lambda, EC2)   │                                     │
│  └────────┬────────┘                                      │
│           │  ← Egress boundary decisions happen here      │
│    ┌──────┴──────────────────────────────────┐            │
│    │  What path does this traffic take?      │            │
│    │  NAT GW → internet?                     │            │
│    │  Gateway Endpoint → S3/DynamoDB?        │            │
│    │  Interface Endpoint → AWS service?      │            │
│    │  PrivateLink → your own service?        │            │
│    │  VPC Peering → another VPC?             │            │
│    └──────────────────────────────────────────┘           │
└───────────────────────────────────────────────────────────┘
```

Decisions made here: which traffic stays on-backbone, what exits to the internet, which cross-account paths are permitted, and what DNS name resolves to.

---

## Core patterns

### 1. NAT Gateway

**Problem:** Private subnet instances need outbound internet access — OS patches from package mirrors, third-party payment APIs, webhook deliveries to external SaaS. They have no public IP and cannot route directly to the internet gateway.

**How it works:** A NAT Gateway lives in a public subnet and has an Elastic IP. The private subnet route table sends `0.0.0.0/0` to the NAT GW. The NAT GW performs source NAT, replacing the private instance IP with its Elastic IP, then forwards the packet to the Internet Gateway.

**AWS implementation:**
```
Private route table:
  0.0.0.0/0  →  nat-xxxxxxxx

NAT Gateway sits in public subnet with EIP.
Internet Gateway handles the outbound leg.
```

**Cost:** $0.045/hour (~$32/month) + $0.045/GB of data processed. One NAT GW per AZ for HA doubles or triples the cost.

**When it's wrong:** Using NAT Gateway for S3 or SQS traffic. Both have free or low-cost private paths (Gateway Endpoint and Interface Endpoint, respectively). Any service behind NAT is on an internet-routable path, which triggers PCI and FedRAMP scope concerns even if the destination is another AWS service.

---

### 2. VPC Gateway Endpoint (S3 and DynamoDB)

**Problem:** Lambda and EC2 in private subnets commonly read/write S3 and DynamoDB. With NAT GW, this traffic travels through NAT and incurs data-processing charges. S3 and DynamoDB are AWS-managed services — there is no reason for their traffic to touch the internet at all.

**How it works:** A Gateway Endpoint adds a route table entry pointing S3/DynamoDB prefix lists to the endpoint. Traffic is routed within the AWS backbone, not through NAT. No ENI is created. DNS does not change — the endpoint works through route table matching.

**AWS implementation:**
```
Route table entry added automatically:
  pl-xxxxxxxx (S3 prefix list)  →  vpce-xxxxxxxx

Bucket policy restriction:
  Condition: aws:SourceVpce == vpce-xxxxxxxx
```

**Cost:** Free. No hourly charge, no data processing charge.

**When it's wrong:** Gateway Endpoints exist only for S3 and DynamoDB. Any other AWS service (SQS, SNS, Secrets Manager) requires an Interface Endpoint instead.

---

### 3. VPC Interface Endpoint (PrivateLink — AWS services)

**Problem:** Private subnets need to call AWS managed services such as SQS, SNS, ECR, Secrets Manager, API Gateway, and over 100 others. A NAT Gateway works but sends the traffic through the internet path and costs more.

**How it works:** An Interface Endpoint creates an Elastic Network Interface (ENI) inside your subnet with a private IP. When `private_dns_enabled = true`, the endpoint overrides the default AWS service DNS name — `sqs.ap-southeast-1.amazonaws.com` resolves to the ENI's private IP inside the VPC. Your code calls the same SDK endpoint URL but the packet goes to the ENI, which forwards it on the AWS backbone.

**AWS implementation:**
```
Interface Endpoint: com.amazonaws.ap-southeast-1.sqs
  private_dns_enabled = true
  subnet_ids = [private subnet IDs]
  security_group: allow 443 from Lambda SG
```

**Cost:** $0.01/hour per AZ endpoint + $0.01/GB processed. For a 2-AZ setup: ~$14.40/month fixed + data charges. Cheaper than NAT for high-volume intra-AWS traffic.

**When it's wrong:** If your service endpoint is S3 or DynamoDB, prefer the Gateway Endpoint (free). Interface Endpoints have a per-AZ hourly cost, so for extremely low-traffic services the cost difference versus NAT may be negligible — but the security and compliance benefit usually wins.

---

### 4. PrivateLink — exposing your own service

**Problem:** You have a card vault service in Account A (PCI scope). Your payment processor runs in Account B. Account B needs to call the vault privately, without internet traversal and without full VPC peering (which would expose all resources in Account A's VPC, not just the vault).

**How it works:**
1. Account A puts an NLB in front of the card vault service.
2. Account A creates a VPC Endpoint Service backed by that NLB.
3. Account B creates an Interface Endpoint pointing to the Account A Endpoint Service.
4. Account A approves the endpoint request (or pre-configures auto-acceptance for the Account B principal).
5. Account B's DNS resolves the vault hostname to the Interface Endpoint's private IP.
6. Account B's Lambda calls the vault — traffic stays on the AWS backbone, no CIDR overlap concerns.

**AWS implementation:**
```
Account A:
  aws_lb (NLB) → aws_vpc_endpoint_service (nlb ARN, acceptance required)
  allowed_principals = ["arn:aws:iam::ACCOUNT_B_ID:root"]

Account B:
  aws_vpc_endpoint (service_name = Account A endpoint service name)
  private_dns_enabled = true (if custom DNS is configured)
```

**When it's wrong:** PrivateLink requires an NLB in the provider VPC. NLBs cost ~$22/month minimum. For internal service communication within the same account/VPC, an Interface Endpoint to a service in the same VPC is overkill — use VPC peering or direct service communication instead.

---

### 5. VPC Peering

**Problem:** Two VPCs need low-latency, private, bidirectional connectivity. Classic use case: a shared services VPC (DNS resolvers, logging, monitoring) that many application VPCs need to reach.

**How it works:** A peering connection is created between two VPCs. Both sides must add route table entries pointing the peer's CIDR to the peering connection. CIDRs must not overlap. The connection is non-transitive — if VPC A peers with VPC B, and VPC B peers with VPC C, VPC A cannot reach VPC C through B.

**AWS implementation:**
```
aws_vpc_peering_connection: requester VPC → accepter VPC
Both route tables: peer CIDR → pcx-xxxxxxxx
Security groups: allow traffic from peer CIDR
```

**Cost:** No hourly charge. Data transfer: $0.01/GB within region, standard cross-region rates across regions.

**When it's wrong:** More than ~10 VPCs. With N VPCs in a full mesh, you need N*(N-1)/2 peering connections. At 12 VPCs, that is 66 connections — each with its own pair of route table entries and security group rules. This does not scale. Non-transitivity also means you cannot centralize inspection (firewall, IDS) in a hub VPC.

---

### 6. Transit Gateway

**Problem:** An organization with dozens of VPCs (dev, staging, prod, shared services, security) needs a scalable, manageable connectivity model. VPC peering mesh does not scale beyond ~10 VPCs and has no transitivity for centralized inspection.

**How it works:** Each VPC attaches to a Transit Gateway. The TGW holds route tables that determine which VPCs can reach which others. A "hub-and-spoke" model: shared services VPC is always routable; prod VPCs can reach shared services but not each other; security VPC can reach all (for inspection). Adding a new VPC = one attachment + one route entry on TGW.

**AWS implementation:**
```
aws_ec2_transit_gateway
aws_ec2_transit_gateway_vpc_attachment (one per VPC)
aws_ec2_transit_gateway_route_table (control what can talk to what)
Each VPC route table: points target CIDRs to the TGW attachment
```

**Cost:** $0.05/hour per attachment (~$36/month) + $0.02/GB processed. At 20 VPCs: ~$720/month in attachment fees alone. Significant, but cheaper than the operational overhead of a 190-connection peering mesh.

**When it's wrong:** Fewer than 5 VPCs with simple, stable topology. VPC peering is cheaper and simpler at small scale. TGW is also overkill when the VPCs are in different AWS Organizations with no shared network team — in that case, PrivateLink per-service is more controlled.

---

### 7. Split-horizon DNS

**Problem:** The card vault service needs a stable hostname (`vault.internal.bank.com`) that resolves to a private IP when called from inside the payment VPC, and is unreachable from outside. Using a public DNS record would expose the hostname and potentially the IP to the internet.

**How it works:** A Route 53 Private Hosted Zone is created for `internal.bank.com` and associated with the consumer VPC. Inside the VPC, the Route 53 resolver returns the private IP (the Interface Endpoint ENI IP, or the NLB IP). Outside the VPC, the public DNS has no record for `vault.internal.bank.com` — the name does not resolve. The VPC's DHCP options set points resolver traffic to the Route 53 resolver (169.254.169.253).

**AWS implementation:**
```
aws_route53_zone (private = true)
aws_route53_zone_association (to consumer VPC)
aws_route53_record: vault.internal.bank.com → Interface Endpoint DNS alias

Outside VPC: nslookup vault.internal.bank.com → NXDOMAIN
Inside VPC:  nslookup vault.internal.bank.com → 10.0.3.45 (ENI private IP)
```

**When it's wrong:** When the consuming service uses a custom DNS resolver that bypasses Route 53 (common in containers with custom `resolv.conf`). Always verify that your runtimes honor VPC DNS settings before relying on split-horizon for security enforcement.

---

## Decision tree

```
Traffic destination?
│
├── S3 or DynamoDB?
│   └── → VPC Gateway Endpoint (free, no NAT needed)
│
├── AWS managed service (SQS, SNS, ECR, Secrets Manager, etc.)?
│   └── → VPC Interface Endpoint (PrivateLink)
│          private_dns_enabled = true
│
├── Your own service in another VPC / account?
│   ├── Same account, same VPC CIDR space, simple topology (< 10 VPCs)?
│   │   └── → VPC Peering
│   ├── Cross-account, must not expose full VPC?
│   │   └── → PrivateLink (NLB → Endpoint Service → Interface Endpoint)
│   └── Many VPCs, need transitive routing, centralized inspection?
│       └── → Transit Gateway
│
└── External internet destination (public APIs, package repos)?
    └── → NAT Gateway (route 0.0.0.0/0 through NAT GW)
         Note: S3/SQS traffic should bypass NAT via endpoints above
```

**Pattern comparison**

| Pattern | Fixed cost (per AZ/hr) | Per-GB cost | Transitive routing | PCI / internet exposure |
|---|---|---|---|---|
| NAT Gateway | $0.045 | $0.045/GB | N/A | Internet-routable path |
| VPC Gateway Endpoint | Free | Free | No | Private (AWS backbone) |
| VPC Interface Endpoint | ~$0.01 | $0.01/GB | No | Private (AWS backbone) |
| PrivateLink (your service) | ~$0.01 (NLB) + $0.01 (ep) | $0.01/GB | No | Private (AWS backbone) |
| VPC Peering | Free | $0.01/GB cross-AZ | No (non-transitive) | Private |
| Transit Gateway | $0.05/attachment | $0.02/GB | Yes | Private |

---

## Exercises

### Exercise 1

Your Lambda function runs in a private subnet. It writes transaction logs to S3 and sends audit events to SQS. Currently both calls go through a NAT Gateway. Monthly traffic: 500 GB to S3, 200 GB to SQS. What changes reduce both cost and blast radius?

**Hint:** For each destination, ask: does this service have a private AWS backbone path? Does it require internet routing at all?

**Solution sketch:**
1. Add a Gateway Endpoint for S3. Update the private subnet route table — it happens automatically when the endpoint is created with `route_table_ids`. Remove S3 traffic from NAT entirely. Savings: $0.045 × 500 GB = $22.50/month in NAT processing. Gateway Endpoint is free.
2. Add an Interface Endpoint for SQS with `private_dns_enabled = true`. Lambda SDK calls `sqs.region.amazonaws.com` — DNS now resolves to the ENI. No code change needed. Cost: $0.01/hr × 2 AZs × 730 hrs = $14.60/month fixed + $0.01 × 200 GB = $2/month data. NAT equivalent: $0.045 × 200 GB = $9/month data processing + hourly NAT cost.
3. Add a bucket policy condition `aws:SourceVpce` to restrict S3 to traffic through the Gateway Endpoint only. Add an SQS policy `aws:SourceVpce` condition for the Interface Endpoint.
4. If Lambda calls nothing else on the internet, remove the NAT Gateway entirely — saves $32/month per AZ.

---

### Exercise 2

Your card vault service runs in Account A (PCI scope). Your payment processor Lambda runs in Account B. The vault must be reachable from Account B without VPC peering and without any traffic touching the internet. Design the connectivity in both accounts.

**Hint:** You need to expose a single service across account boundaries, privately, without granting Account B access to Account A's entire VPC address space.

**Solution sketch:**
1. **Account A (provider):** Deploy the card vault service on EC2 or ECS. Put an NLB in front of it (NLB is required for PrivateLink). Create a `aws_vpc_endpoint_service` backed by the NLB. Set `acceptance_required = true`. Add Account B's root ARN or specific IAM role to `allowed_principals`.
2. **Account B (consumer):** Create an `aws_vpc_endpoint` with `service_name = <Account A endpoint service name>`. This sends a pending request to Account A.
3. **Account A (approval):** Accept the endpoint connection request. In automation, use `aws_vpc_endpoint_connection_accepter`.
4. **DNS (Account B):** Create a Route 53 Private Hosted Zone for `vault.internal.bank.com`, associate it with Account B's consumer VPC. Create an A record (or alias) pointing to the Interface Endpoint DNS name. Account B Lambda calls `vault.internal.bank.com` — resolves to the Interface Endpoint ENI private IP — traffic traverses PrivateLink to Account A's NLB — reaches the vault service. No CIDR overlap concern; no VPC peering; no internet.

---

### Exercise 3

You manage 12 VPCs across three AWS regions (4 per region). Dev and staging VPCs need access to a shared services VPC (logging, monitoring) in each region. Prod VPCs must not communicate with each other directly. Teams report that adding a new VPC requires updating many peering connections. What architecture removes this pain?

**Hint:** Consider whether point-to-point or hub-and-spoke better matches the routing policy "all talk to shared services, prod VPCs don't talk to each other."

**Solution sketch:**
1. Deploy one Transit Gateway per region (3 TGWs total).
2. Attach each VPC to its region's TGW (one `aws_ec2_transit_gateway_vpc_attachment` per VPC).
3. Create two TGW route tables per region: "shared-access" (shared services VPC attachment) and "prod-isolated" (prod VPC attachments). Configure routes so all VPCs can reach shared services, but prod VPCs' route tables do not have routes to each other.
4. For cross-region: create TGW peering connections between region TGWs. Route shared-services CIDRs across peers.
5. Adding a new VPC = one TGW attachment + one route table association. No mesh of peering connections.
6. To add centralized inspection later: attach a security/inspection VPC to TGW and route all prod traffic through it — non-transitive peering cannot do this.

---

## Anti-patterns / Common mistakes

**Using NAT Gateway for S3 and SQS traffic.** This is the most common waste pattern in AWS architectures. Gateway Endpoints for S3/DynamoDB are free. Interface Endpoints for SQS/SNS pay for themselves in avoided NAT processing charges at moderate traffic volumes. Beyond cost, traffic through NAT is on an internet-routable path — this triggers PCI and SOC 2 audit questions that a private endpoint path avoids entirely.

**Interface Endpoints to AWS services without endpoint policies.** An Interface Endpoint with no endpoint policy defaults to full access — any principal who can reach the endpoint can attempt any action on the service (IAM permitting). For the payment processor's SQS endpoint, the endpoint policy should allow only `sqs:SendMessage` on the audit queue to the Lambda's execution role. Without this, a compromised workload in the same VPC could use the endpoint to reach any SQS queue its IAM role allows — including `sqs:PurgeQueue` on queues in other environments. Endpoint policies are a second access control layer on top of IAM. Caveat: endpoint policies apply only to endpoints for **AWS services**; an endpoint to your own VPC Endpoint Service (like the card vault) does not support them — there, access control lives in the endpoint service's `allowed_principals`, the NLB's security posture, and the vault's own authentication.

**VPC Peering beyond ~10 VPCs.** The mesh model fails on two dimensions: operational (66 connections for 12 VPCs, each with manual route table updates) and functional (non-transitive routing prevents centralized inspection). Teams that start with peering often realize the mistake only when a security requirement demands a centralized firewall — at which point migrating to TGW while keeping services running is painful.

**Relying on split-horizon DNS without verifying resolver settings.** Containers, Lambdas in custom VPCs, and EKS pods sometimes override `/etc/resolv.conf` with a custom DNS server. If that server does not forward to `169.254.169.253` (Route 53 resolver), split-horizon DNS is silently bypassed. Always validate DNS resolution from within the runtime environment, not just from the EC2 host.

---

## Lab

See `labs/day03/`.

**Goal:** Convert a simulated payment processor service from NAT Gateway egress to VPC Gateway Endpoint (S3) + Interface Endpoint (SQS). Then add a PrivateLink connection to a mock card vault service in a second VPC.

**What you will build:**
- Consumer VPC with a private subnet and no NAT GW
- S3 Gateway Endpoint and SQS Interface Endpoint in the consumer VPC
- Lambda in the private subnet that writes to S3 and publishes to SQS
- Provider VPC with a mock NLB-backed service and a VPC Endpoint Service (PrivateLink)
- Interface Endpoint in the consumer VPC for the vault service
- VPC Flow Logs to CloudWatch for the Break it exercise

**Success signal:** Lambda in private subnet reaches S3 and SQS with no NAT GW present. VPC Flow Logs show no traffic to an internet gateway or NAT gateway for S3/SQS calls.

---

## Teardown

See `labs/day03/teardown.md`. Interface Endpoints accrue $0.01/hour per AZ even when idle — run teardown promptly after the lab.
