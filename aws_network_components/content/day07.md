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
- Describe the flow for associating a Route 53 private hosted zone with a VPC
  in another account (authorize → associate), and why this is a separate
  mechanism from RAM sharing
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
| Cost | ~$0.01–0.013/hr per endpoint ENI | ~$0.05–0.07/hr per attachment (region-dependent) |
| Use case | Expose one service | Full network access between VPCs |

For an integration platform exposing APIs and shared services: PrivateLink.
For a scenario where Account B needs full network access to Account A's VPC
(e.g., a shared tooling VPC): TGW.

---

## Cross-account Route 53 private hosted zone association

The private hosted zones (PHZ) built on Day 3 are associated with a VPC.
When that VPC lives in a *different* account than the one that owns the
zone, you cannot associate it directly — the owning account must first
authorize the association, then the VPC's account confirms it.

**This is not a RAM share.** RAM shares a *resource* (a subnet, a TGW, a
Resolver rule) into another account so that account can use it. PHZ
cross-account association is a distinct two-party handshake API
(`route53:CreateVPCAssociationAuthorization` /
`route53:AssociateVPCWithHostedZone`) that exists only for this one
purpose. A PHZ is never RAM-shareable — don't go looking for it in the
RAM console.

**Flow:**
1. Account A (owns the hosted zone, e.g. `internal.platform`) runs
   `create-vpc-association-authorization`, naming Account B's VPC ID and
   region. This grants Account B's account permission to associate that one
   VPC — nothing else changes yet, and Account B's VPC still cannot resolve
   the zone.
2. Account B runs `associate-vpc-with-hosted-zone`, naming Account A's
   hosted zone ID and its own VPC ID. This must be run from Account B (or a
   role in Account B) — Account A cannot complete this half.
3. The VPC is now associated. Resources in Account B's VPC resolve records
   in Account A's zone, same as a same-account association.
4. (Optional cleanup) Account A can run
   `delete-vpc-association-authorization` after the association completes —
   this only removes the *authorization* record, not the association
   itself. To remove the association, Account B must disassociate the VPC
   (or Account A can force-disassociate if it still owns the zone).

Both `enableDnsHostnames` and `enableDnsSupport` must be `true` on Account
B's VPC, exactly as for a same-account PHZ association (Day 3) — this is
easy to miss because the failure looks identical to a missing
authorization.

**Ownership after association:** Account A still owns the zone and all its
records. Account B's VPC is only a resolution target — Account B cannot
create, edit, or delete records in Account A's zone, and cannot see the
zone's record set unless also given `route53:ListResourceRecordSets` via
IAM.

---

## Cross-account Route 53 Resolver rule sharing

Unlike PHZ association, Resolver rules (the outbound rules built on Day 3
that forward queries for on-prem domains to Route 53 Resolver endpoints)
*are* shared via RAM — they were listed as shareable back in the RAM
section, but the flow is worth walking through since it differs from
subnet sharing in one important way.

**Flow:**
1. Account A shares the Resolver rule via RAM to Account B (or the org)
2. Account B sees the rule under Route 53 → Resolver → Rules → Shared with
   me
3. Account B associates the shared rule with one or more of *its own* VPCs
   — this is the step RAM sharing alone does not do. Sharing makes the rule
   visible; Account B must still explicitly associate it per-VPC.
4. Once associated, DNS queries from that VPC matching the rule's domain
   are forwarded through Account A's outbound Resolver endpoint

Account B cannot see or modify the rule's forwarding targets (the IPs it
forwards to) — only Account A controls that. Account B only controls
*which of its VPCs* use the rule.

**Choosing PHZ association vs Resolver rule sharing:** if the domain is
one you own end-to-end in Route 53 (e.g., internal services with records
you manage), use PHZ association. If the domain is external/on-prem (e.g.,
`corp.internal` resolved by an on-prem DNS server) and you're forwarding
queries out of AWS, use Resolver rule sharing — that's what the rule
exists for.

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
  ├── May also use RAM-shared subnets for shared tooling
  └── VPC associated with Account A's internal.platform PHZ (authorized by A)
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
- Grant RAM access to the entire Organisation (`allow_external_principals =
  false`, principal = the org ARN) rather than listing individual account IDs.
  Adding an account doesn't require a RAM share update.

  **But check which case you are actually in.** `allow_external_principals =
  false` restricts the share to accounts inside your AWS Organization. If your
  account B is a *separate personal account* — which is exactly what this
  course's Day 7 lab allows — the share is created without error, the principal
  association is accepted, and account B **never sees it**. There is no failure
  message anywhere; the share simply does nothing. For an account outside your
  Organization you must set `allow_external_principals = true`. Decide which
  case you are in before you start debugging the acceptance flow.
- Create separate TGW route tables for each security domain (prod, dev,
  shared, sandbox) — don't put everything on the default route table.
- Keep the TerraformDeployRole in spoke accounts narrow: only the permissions
  needed to create VPC attachments and route table entries, not broad
  AdministratorAccess.
- Centralize internal DNS in the network account: own the PHZ there, and
  authorize spoke VPCs to associate rather than letting each spoke team run
  its own copy of `internal.platform`. One zone, one source of truth.

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
- **Associating a VPC to a hosted zone in another account without
  authorizing it first.** `associate-vpc-with-hosted-zone` from Account B
  fails until Account A has run `create-vpc-association-authorization` for
  that exact VPC ID and region. The error names the missing authorization,
  but it's easy to skip Account A's half and only remember Account B's.
- **Deleting the authorization and assuming the association is gone.**
  `delete-vpc-association-authorization` only revokes future re-association
  rights — an already-associated VPC stays associated until it is
  explicitly disassociated.

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
5. Account B needs to resolve `internal.platform` records that live in
   Account A's hosted zone. Walk through both required API calls, and say
   which account runs each one. Then: Account B also needs to forward
   queries for `corp.internal` to an on-prem DNS server — is that the same
   mechanism, or something different?

## Lab reference

Follow Day 7 in the implementation plan:
`aws_network_components/docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`

## Journal template

```
### Day 7 — Multi-Account Networking
Key concept in my own words: ...
What confused me (RAM sharing scope, TGW acceptance flow, PrivateLink cross-account, PHZ authorize-vs-associate): ...
Break-it exercise — rejected PrivateLink endpoint: what I observed: ...
```
