# Day 3 — DNS Inside VPC

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain what `enableDnsSupport` and `enableDnsHostnames` actually control
- Describe split-horizon DNS and give a concrete reason it matters for
  integration platforms
- Explain the difference between a Route 53 private hosted zone and a
  public hosted zone
- Describe what an inbound Resolver endpoint does vs an outbound endpoint
- Explain why hardcoding IP addresses instead of DNS names is a reliability risk

---

## DNS basics in a VPC

Every VPC has a built-in DNS resolver provided by AWS, available at the
"base CIDR + 2" address. For a VPC with CIDR `10.0.0.0/16`, the resolver
is at `10.0.0.2`. This resolver handles:
- Public DNS lookups (forwarded to the internet via AWS's DNS infrastructure)
- Internal AWS service endpoint resolution (e.g. `ec2.ap-southeast-1.amazonaws.com`)
- EC2 instance hostnames (`ip-10-0-2-5.ap-southeast-1.compute.internal`)

Two VPC settings control DNS behaviour:

**`enableDnsSupport` (must be ON):**
Enables the DNS resolver itself. If off, nothing resolves — not even
`google.com`. Always leave this on.

**`enableDnsHostnames` (must be ON for Route 53 PHZ and VPC endpoints):**
Causes EC2 instances to receive DNS hostnames (e.g.
`ip-10-0-2-5.ap-southeast-1.compute.internal`). Also required for interface
endpoints to work with private DNS overrides. Enable this on every VPC.

---

## Route 53 private hosted zones

A private hosted zone (PHZ) is a DNS zone that is only resolvable inside
specific VPCs. You associate it with one or more VPCs; resources inside those
VPCs can resolve names in the zone. Resources outside those VPCs cannot —
even if they know the exact record name, the resolver returns NXDOMAIN.

Example:
- Zone: `internal.platform`
- Record: `api.internal.platform → 10.0.2.10`
- Inside `shared-services-vpc`: `dig api.internal.platform` returns `10.0.2.10`
- From the internet: `dig api.internal.platform` returns NXDOMAIN

**Split-horizon DNS** is when the same domain name resolves differently
depending on where the query comes from. For example:
- `api.mycompany.com` resolves to the public load balancer IP from the internet
- `api.mycompany.com` resolves to the private ALB IP (`10.0.2.x`) from inside the VPC

This is achieved by having both a public hosted zone and a private hosted zone
for the same domain. The PHZ associated with the VPC takes precedence for
queries from inside that VPC.

Why this matters for integration platforms: your internal services should
always talk to each other over private IPs, never hairpinning out through
the internet. Split-horizon DNS makes this transparent — the same hostname
resolves to the right IP depending on the network the caller is on.

---

## Why DNS names, not IPs

Hardcoding IP addresses creates dependencies that break silently:

- RDS creates a new IP address on failover — anything using the old IP breaks
- ECS tasks get new IPs on every restart
- NLB targets change as capacity scales
- A Terraform redeploy of an instance allocates a new private IP

DNS names are stable contracts. The IP behind them can change (failover,
scaling, redeployment) without breaking consumers. The DNS TTL controls
how long consumers cache stale IPs, but the contract — the name — doesn't
change.

Rule: never hardcode an IP address in a service configuration, even for
internal services. Use a DNS record, and control the TTL based on how
fast the underlying resource can change.

---

## Route 53 Resolver endpoints

Private hosted zones are enough for DNS within a single VPC. But integration
platform teams also need DNS to cross boundaries:
- On-prem systems need to resolve AWS-internal names (e.g. `api.internal.platform`)
- AWS services need to resolve on-prem names (e.g. `corp-erp.corp.internal`)

This is where Resolver endpoints come in. They are ENIs in your VPC that
act as DNS proxy endpoints.

**Inbound endpoint:**
An inbound endpoint is a set of ENIs (one per AZ) in your VPC's private
subnets. External DNS servers (on-prem) can forward DNS queries to these ENI
IPs. The queries are processed by the VPC's Route 53 Resolver, which can
resolve names in your private hosted zones and AWS service endpoints.

Use case: on-prem application needs to resolve `api.internal.platform` to
reach a service running in the VPC. Configure the on-prem DNS server to
forward queries for `internal.platform` to the inbound endpoint IPs.

**Outbound endpoint:**
An outbound endpoint is a set of ENIs used by the Resolver to forward
queries to external DNS servers. You configure Resolver Rules that say
"for queries matching `corp.internal`, forward to `192.168.1.2`" (an
on-prem DNS server's IP). The query goes out through the outbound endpoint
ENIs, travels over the VPN connection, and is answered by the on-prem server.

Use case: an EC2 in the VPC needs to resolve `corp-erp.corp.internal` (an
on-prem service). Without the outbound rule, the VPC resolver has no idea
what `corp.internal` is. With the rule, the query is forwarded over the VPN.

**In this lab:**
- The inbound endpoint is built today but not fully tested until the VPN
  is set up on Day 6 (on-prem needs a path to reach the endpoint IPs).
- The outbound endpoint and forward rule for `corp.internal` are built today;
  the target IP (`192.168.1.2`) is a placeholder for the simulated on-prem
  DNS server, which is provisioned on Day 6.

---

## DHCP options sets

The VPC's DHCP options set controls what DNS server address and domain name
are given to EC2 instances when they receive a DHCP lease. The default DHCP
options set points instances at the VPC resolver (`169.254.169.253` alias or
`base CIDR + 2`). You rarely need to change this, but if your on-prem
network has custom DNS servers that instances should use by default, you can
create a custom DHCP options set.

For this course, use the default DHCP options set. The Resolver endpoint
approach is more flexible than pushing custom DNS servers via DHCP.

---

## Best practices

- Plan your DNS namespace before building anything. Decide on `internal.platform`
  (or whatever convention your team uses) before the first service is deployed.
  Changing names later means updating every consumer.
- Keep TTLs low (300 seconds) for records that back resources that can failover
  or change. Higher TTLs reduce resolver load but increase the window during
  which stale IPs are served after a change.
- Always associate PHZs with the VPC explicitly in Terraform — do not rely on
  default association behaviour.
- Create inbound and outbound endpoints in at least two AZs (two IP addresses
  each) for HA. A single-AZ endpoint is a single point of failure for DNS.
- Associate outbound Resolver rules with all VPCs that need the forwarding,
  not just the VPC where the endpoint lives. Rules can be shared via RAM.

---

## Common pitfalls

- **Forgetting `enableDnsHostnames`.** Interface endpoints with private DNS
  enabled require this setting. The endpoint creates a private DNS record that
  overrides the public service hostname — but only works if DNS hostnames are
  enabled. The symptom is SSM Session Manager timing out even though the
  endpoint exists and the SG is correct.
- **Using the same domain in a public and private hosted zone without
  understanding precedence.** AWS resolves the private zone first for
  queries from associated VPCs. If you create both zones but associate the
  PHZ with the wrong VPC, queries from that VPC fall through to the public zone.
- **Hardcoding endpoint IPs instead of DNS names.** Resolver endpoint IPs are
  stable but can change during maintenance or recreation. Always use the DNS
  name that resolves to the endpoint IPs, not the IPs themselves.
- **Building a Resolver outbound rule but forgetting to associate it with
  the VPC.** A rule exists independently of its VPC association. A rule with
  no association forwards nothing.

---

## Exercises

Answer before starting the lab:

1. An EC2 in your VPC queries `api.internal.platform`. Trace the exact path
   the DNS query takes from the instance to getting an answer.
2. You have a private hosted zone for `internal.platform` associated with
   `shared-services-vpc`. A developer in `app-vpc` (a separate VPC) complains
   that they can't resolve `api.internal.platform`. What is the cause and fix?
3. What is the purpose of the Resolver inbound endpoint if the private hosted
   zone already handles resolution inside the VPC?
4. Why would you set a DNS record TTL of 60 seconds for an RDS primary endpoint
   record but 3600 seconds for a static internal API record?

## Lab reference

Follow Day 3 in the implementation plan:
`aws_network_components/docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`

## Journal template

```
### Day 3 — DNS Inside VPC
Key concept in my own words: ...
What confused me (split-horizon, inbound vs outbound endpoint): ...
Break-it exercise — dissociating the PHZ: what NXDOMAIN looked like: ...
```
