# Day 1 — VPC Anatomy

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain what a VPC is and why it exists (not just "a virtual network")
- Name the three subnet tiers and state the routing difference between each
- Trace a packet from an EC2 instance in a private subnet to the internet,
  naming every hop and decision point
- State why two NAT Gateways are required for high availability
- Read a route table and explain what each entry means

---

## The packet-tracing mental model

Before memorising any AWS service name, internalise one question you will ask
for the rest of this course:

> **Where does this packet enter, what decision point does it hit, and where
> does it exit?**

Every AWS networking concept is a decision point on a packet's path. Route
tables decide which next-hop to send a packet to. Security Groups decide
whether to allow or drop a packet at an ENI. NACLs decide whether to allow
or drop at a subnet boundary. NAT Gateways rewrite source IPs. This mental
model collapses weeks of memorisation into a single framework.

When something breaks, you trace the packet path and find which decision
point is dropping it. That is the entire job.

---

## VPC and CIDR

A VPC (Virtual Private Cloud) is a logically isolated network inside AWS
with an IP address range you control. You define the range as a CIDR block
(Classless Inter-Domain Routing) — a notation that expresses both a network
address and its size.

`10.0.0.0/16` means:
- Network address: `10.0.0.0`
- Prefix length: 16 bits fixed
- Usable host addresses: 2^(32-16) - 5 = 65,531 (AWS reserves 5 per subnet)

The `/16` gives you 65,536 addresses to divide across subnets. A `/24` subnet
within it gives you 251 usable host IPs. Choose CIDR ranges that:
- Don't overlap with other VPCs you will peer or connect via TGW
- Leave room to grow (a `/20` VPC is too small for a real platform)
- Avoid the `10.0.0.0/8` ranges your on-prem network already uses

Rule of thumb for integration platforms: use `/16` VPCs, `/24` subnets.

---

## The three-tier subnet model

Real architectures use three subnet tiers. Putting everything in one subnet
is the most common beginner mistake — it breaks every security assumption.

| Tier | Route | Who lives here |
|---|---|---|
| Public | `0.0.0.0/0 → Internet Gateway` | NAT Gateways, Application Load Balancers, bastion hosts |
| Private | `0.0.0.0/0 → NAT Gateway` | Application servers, ECS tasks, Lambda (VPC-attached) |
| Isolated | No default route | RDS, ElastiCache, internal services that must never reach the internet |

**Private vs Isolated — the distinction that trips everyone up:**
A private subnet has a route to a NAT Gateway, which means resources inside
it can initiate outbound connections to the internet (for package downloads,
API calls, etc.) but cannot be reached inbound from the internet. An isolated
subnet has no default route at all — nothing inside it can reach the internet
in either direction. Database servers belong in isolated subnets.

---

## Internet Gateway (IGW)

The IGW is the VPC's on-ramp to the public internet. It is a managed AWS
resource — you don't size it, it has no bandwidth limit, and it is highly
available by design. There is exactly one IGW per VPC.

An IGW does two things:
1. Provides a route target for public subnets (`0.0.0.0/0 → igw-xxx`)
2. Performs 1:1 NAT between a resource's private IP and its Elastic IP (for
   resources that have an EIP assigned)

A subnet is "public" if and only if its route table has a route to an IGW.
The IGW itself doesn't make a subnet public — the route table does.

---

## NAT Gateway

A NAT Gateway allows resources in private subnets to initiate outbound
internet connections while remaining unreachable inbound. It sits in a
public subnet (it needs internet access to forward traffic) and rewrites
outbound packets: source IP changes from the private EC2's IP to the NAT
Gateway's Elastic IP. Return traffic comes back to the NAT Gateway, which
rewrites the destination IP back to the EC2's private IP.

**Why one per AZ:**
A NAT Gateway is an Availability Zone-scoped resource. If you have one NAT
Gateway in AZ-a and your AZ-b private subnet routes through it, all
AZ-b traffic crosses AZ boundaries — which costs money (cross-AZ data
transfer) and means a single AZ failure takes down all outbound connectivity.
The standard pattern: one NAT Gateway per AZ, each private subnet routes to
the NAT Gateway in its own AZ.

---

## Route tables

A route table is a set of rules that determine where to send a packet based
on its destination IP. Every subnet must be associated with exactly one route
table. If you don't explicitly associate one, it uses the VPC's main route table.

A route entry has two parts:
- **Destination:** an IP range (CIDR), e.g. `10.0.0.0/16` or `0.0.0.0/0`
- **Target:** where to send matching packets (igw, nat, tgw, vpc endpoint, etc.)

Routing is longest-prefix match: the most specific matching CIDR wins.
`10.0.2.5` matches both `10.0.0.0/16` and `10.0.2.0/24` — the `/24` wins.

The implicit local route (`10.0.0.0/16 → local`) is always present and
cannot be deleted. It ensures traffic between resources in the same VPC
always routes locally, regardless of other route table entries.

---

## Availability Zones

An Availability Zone (AZ) is a physically separate data centre (or cluster
of data centres) within a region, with independent power, networking, and
cooling. Distributing resources across AZs ensures that a single facility
failure doesn't take down your entire application.

For a two-AZ setup, the subnet layout is:
- AZ-a: `public-1a`, `private-1a`, `isolated-1a`
- AZ-b: `public-1b`, `private-1b`, `isolated-1b`

Each AZ has its own NAT Gateway in its public subnet. Each AZ's private
subnet has its own route table pointing to that AZ's NAT Gateway.

---

## Best practices

- Design with three tiers from day one. Retrofitting an isolated tier into
  a flat VPC means moving running databases — painful and risky.
- One NAT Gateway per AZ — never share across AZs in production.
- Use `10.0.0.0/16` for the first VPC, `10.1.0.0/16` for the second, etc.
  Reserve adjacent CIDRs for future VPCs before you need them.
- Tag every subnet with `Tier = public|private|isolated` — it makes filtering
  in the Console and in Terraform much easier.
- Enable `enable_dns_support` and `enable_dns_hostnames` on every VPC — you
  will need them for Route 53 private hosted zones and VPC endpoints.

---

## Common pitfalls

- **Single flat subnet with everything in it.** Breaks every security control
  downstream — you can't enforce "databases cannot reach the internet" if
  they're in the same subnet as load balancers.
- **One NAT Gateway shared across AZs.** Cross-AZ data transfer is billed,
  and a single AZ failure brings down outbound connectivity for all AZs.
- **Not leaving CIDR headroom.** A `/20` VPC (4,096 addresses) fills up
  faster than you expect when ECS tasks, Lambda ENIs, and RDS instances all
  consume IPs. Start with `/16`.
- **Assuming the VPC is private by default.** A new VPC has no IGW and
  no public route — it *is* private. The moment you attach an IGW and add
  a default route to a subnet's route table, that subnet becomes public.

---

## Worked example — tracing a packet

An EC2 instance in `private-1a` (IP `10.0.2.5`) makes an HTTPS request to `api.example.com`.

1. The packet is generated with source `10.0.2.5`, destination `93.184.216.34` (resolved from DNS).
2. The instance's ENI is checked against its Security Group outbound rules. Default SG allows all outbound — packet passes.
3. The packet hits the subnet's NACL outbound rules. Default NACL allows all — packet passes.
4. The route table for `private-1a` is consulted. Destination `93.184.216.34` matches `0.0.0.0/0 → nat-gateway-1a`. Packet forwarded to NAT Gateway.
5. NAT Gateway rewrites source IP from `10.0.2.5` to its own Elastic IP (e.g. `13.251.x.x`). Packet forwarded to the IGW.
6. IGW forwards the packet to the internet.
7. Response arrives at the IGW addressed to `13.251.x.x` (the NAT Gateway's EIP).
8. NAT Gateway rewrites destination from `13.251.x.x` back to `10.0.2.5`.
9. Packet arrives at the ENI. NACL inbound rules checked — must allow TCP ephemeral ports (1024–65535). SG inbound rules checked — stateful, so the return traffic is automatically allowed.
10. Packet delivered to the application.

Tracing this path manually is the fastest way to debug "why can't this instance reach the internet."

---

## Exercises

Answer before starting the lab:

1. What is the difference between a private subnet and an isolated subnet?
   What specific route table entry exists in one but not the other?
2. Why does the IGW perform 1:1 NAT for resources with an Elastic IP,
   but the NAT Gateway performs many-to-one NAT?
3. You have 3 VPCs and want to avoid CIDR overlap for future TGW connectivity.
   You're using `10.0.0.0/16` for VPC-1. What CIDRs would you choose for
   VPC-2 and VPC-3?
4. A route table has two entries: `10.0.0.0/16 → local` and `0.0.0.0/0 → nat-xxx`.
   A packet is destined for `10.0.2.50`. Which entry wins? Why?

## Lab reference

Follow Day 1 in the implementation plan:
`aws_network_components/docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 1 — VPC Anatomy
Key concept in my own words: ...
What confused me and how I resolved it: ...
Break-it exercise — what I misconfigured and how I found it: ...
```
