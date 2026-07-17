# Day 7 — Multi-Account Networking

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain what AWS Resource Access Manager (RAM) does and what types of
  resources can be shared
- Distinguish between sharing a subnet (RAM) and sharing a full VPC
- Describe the flow for a cross-account TGW attachment (request → share →
  accept → route table update)
- Explain why PrivateLink is the preferred pattern for cross-account service
  consumption vs cross-account TGW
- State the integration platform team's ownership model: who owns TGW, who
  owns shared subnets, who owns consuming VPCs

---

## Why multiple accounts

AWS accounts are the primary security blast-radius boundary. A misconfiguration,
a compromised credential, or a permission error in one account cannot directly
affect resources in another account (assuming no cross-account roles are
overly permissive). For organisations of any meaningful size, each team or
application runs in its own account, inside an AWS Organization.

The integration platform team typically owns the "network account" — the
account containing the TGW, shared VPCs, PrivateLink services, and Direct
Connect gateways. Other teams own "spoke" accounts with their workload VPCs
and connect into the network account's infrastructure.

This is the AWS recommended pattern for enterprise networking — the "landing
zone" model. The integration platform team IS the networking team.

---

## Resource Access Manager (RAM)

RAM lets you share AWS resources from one account to other accounts (or to
an entire Organisation or OU). Resources shared via RAM appear in the
recipient account as if they were native to that account.

**Shareable networking resources:**
- Subnets (from a VPC you own)
- Transit Gateways
- Route 53 Resolver rules
- VPC prefix lists

**Subnet sharing mechanics:**
When you share a subnet from Account A to Account B:
- Account B can launch resources (EC2, ECS tasks, RDS, Lambda) into that subnet
- Account B's resources receive IPs from the subnet's CIDR
- The VPC, subnet, route tables, and NACLs remain owned by Account A
- Account B cannot modify the VPC configuration — only Account A can
- Account B's SGs for those resources are created in Account B and attached
  to the ENIs Account B creates in the subnet

This is useful for the platform team: you create and govern the subnet
(its CIDR, its route table, its NACL), but other teams use the subnet as
if it were their own — without needing their own VPC setup.

**Subnet sharing vs full VPC sharing:**
RAM shares subnets, not VPCs. Account B cannot:
- See or modify the VPC's route tables
- Create subnets in the shared VPC
- Attach an IGW or change the VPC's DHCP settings
- Create VPC peering or TGW attachments for the VPC

Account B only gets the ability to launch resources into the shared subnet
and create SGs in Account B that are associated with those ENIs.

---

## Cross-account TGW attachment

Sharing a TGW via RAM allows other accounts to create VPC attachments to
your TGW. This is how spoke accounts connect their VPCs to the platform
team's hub.

**Flow:**
1. Account A shares the TGW resource via RAM to Account B (or the whole org)
2. Account B sees the TGW ID in its Console under Transit Gateways
3. Account B creates a TGW VPC attachment: specifies Account A's TGW ID,
   Account B's VPC, and Account B's subnets
4. The attachment appears as "pending" in Account A's TGW Attachments view
5. Account A accepts the attachment
6. Account A updates its TGW route table to propagate or add Account B's
   VPC CIDR routes
7. Account B updates its VPC route tables to send traffic to the TGW

Both sides must be configured. The TGW route table in Account A must know
how to reach Account B's VPC CIDRs (via propagation or static routes).
Account B's VPC route tables must know to send traffic destined for Account A's
CIDRs to the TGW.

---

## Cross-account PrivateLink

The PrivateLink endpoint service built on Day 5 can be consumed cross-account
with minimal coordination:

1. Account A adds Account B's account ID (or IAM principal ARN) to the
   endpoint service's allowed principals list
2. Account B creates an interface endpoint pointing to the endpoint service name
3. Account A accepts the endpoint connection request
4. Account B's application uses the endpoint's DNS name to reach the service

No route table changes needed on Account B's side. No VPC topology changes.
Account B only interacts with an endpoint in their own VPC. This is the
cleanest integration boundary.

**Cross-account PrivateLink vs cross-account TGW:**

| Factor | PrivateLink | TGW Cross-Account |
|---|---|---|
| Consumer route table changes | None | Yes (add CIDR route) |
| Network scope | One service (NLB) | Full VPC CIDR (all resources) |
| Blast radius | Application-level | Network-level |
| Cost | $0.01/hr endpoint ENI | $0.05/hr TGW attachment |
| Use case | Expose one service | Full network access between VPCs |

For an integration platform exposing APIs and shared services: PrivateLink.
For a scenario where Account B needs full network access to Account A's VPC
(e.g., a shared tooling VPC): TGW.

---

## Terraform cross-account pattern

To manage resources in two accounts from a single Terraform root module,
use provider aliases with `assume_role`:

```hcl
provider "aws" {
  region  = "ap-southeast-1"
  profile = "sandbox"
}

provider "aws" {
  alias   = "account_b"
  region  = "ap-southeast-1"
  assume_role {
    role_arn = "arn:aws:iam::<account-b-id>:role/TerraformDeployRole"
  }
}
```

Resources in Account A use the default provider. Resources in Account B
use `provider = aws.account_b`. IAM roles must exist in Account B granting
the Account A identity (or a CI/CD role) permission to assume the Account B
role.

**Important:** the Terraform state for Account B resources can be in the
same state file or a separate one. For real environments, separate state
files per account with a remote backend. For this lab, the same local state
file is fine.

---

## Integration platform ownership model

The canonical multi-account network topology for an integration platform:

```
Network Account (platform team owns this)
  ├── TGW (shared via RAM to all spoke accounts)
  ├── shared-services-vpc
  │     ├── Private subnets (shared via RAM to spoke accounts)
  │     └── PrivateLink endpoint services
  └── Direct Connect gateway / VPN connections

Spoke Account A (product team)
  ├── app-vpc (attaches to TGW via cross-account attachment)
  └── Consumes shared services via PrivateLink endpoints

Spoke Account B (another team)
  ├── tenant-vpc (attaches to TGW)
  └── May also use RAM-shared subnets for shared tooling
```

As the integration platform team, you are the TGW owner. Other teams
request attachments; you accept and control which route tables they're
associated with. This gives you traffic segmentation control across the
entire organisation's network.

---

## Best practices

- Share the TGW at the Organisation or OU level (not per-account) so new
  accounts automatically see it without needing a new RAM share.
- Always set `acceptance_required = true` for cross-account TGW attachments.
  Auto-acceptance means any account in your org can attach and route traffic
  — verify first.
- Grant RAM access to the entire Organisation (`allow_external_principals = false`,
  principal = the org ARN) rather than listing individual account IDs. Adding
  an account doesn't require a RAM share update.
- Create separate TGW route tables for each security domain (prod, dev,
  shared, sandbox) — don't put everything on the default route table.
- Keep the TerraformDeployRole in spoke accounts narrow: only the permissions
  needed to create VPC attachments and route table entries, not broad
  AdministratorAccess.

---

## Common pitfalls

- **Sharing a subnet and expecting Account B to control its routing.** They
  can't — Account A owns the route table. Account B's resources in the
  subnet are subject to Account A's routing decisions. Make this clear when
  onboarding teams.
- **Forgetting to accept the cross-account TGW attachment.** The attachment
  stays in `pending` indefinitely. Account A must explicitly accept it in
  the Console or via CLI.
- **PrivateLink endpoint in `rejected` state after adding it.** This means
  Account A hasn't accepted the connection, OR Account A removed Account B
  from the allowed principals list after the connection was established.
- **Both sides updating the same TGW route table.** Only the TGW owner
  (Account A) can modify TGW route tables. Account B can only create
  attachments — they cannot add routes to Account A's TGW route tables.
- **Cross-account Terraform `assume_role` failing.** The Account B role
  must have a trust policy allowing Account A's caller identity (or the IAM
  role) to assume it. A missing or incorrect trust policy causes `Access Denied`
  on the STS AssumeRole call.

---

## Exercises

Answer before starting the lab:

1. Your team shares a private subnet to Account B. Account B launches an EC2
   in that subnet. Can Account B modify the subnet's route table? Who controls
   the NACL on that subnet?
2. Account B creates a TGW attachment to your TGW and you accept it. What
   must you do next in the TGW route table for traffic to actually flow
   between Account B's VPC and your shared-services-vpc?
3. Account B reports they can reach your PrivateLink endpoint service's DNS
   name but get `Connection refused` on the NLB listener port. What are the
   two most likely causes on the Account A side?
4. When would you choose to share a subnet via RAM vs connecting Account B
   via a cross-account TGW attachment?

## Lab reference

Follow Day 7 in the implementation plan:
`aws_network_components/docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`

## Journal template

```
### Day 7 — Multi-Account Networking
Key concept in my own words: ...
What confused me (RAM sharing scope, TGW acceptance flow, PrivateLink cross-account): ...
Break-it exercise — rejected PrivateLink endpoint: what I observed: ...
```
