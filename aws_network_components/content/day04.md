# Day 4 — VPC Peering vs Transit Gateway

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain what "non-transitive" means for VPC peering and give a concrete example
- Calculate the number of peering connections needed to fully mesh N VPCs
- Explain what a TGW route table does and how it differs from a VPC route table
- Configure TGW route table segmentation to isolate two application VPCs from
  each other while both can reach a shared-services VPC
- State the cost difference between peering and TGW and when each is justified

---

## VPC Peering

A VPC peering connection is a direct, private networking connection between
exactly two VPCs. Traffic flows over the AWS backbone (not the internet),
using private IP addresses. Both VPCs must have non-overlapping CIDRs.

**Characteristics:**
- Bilateral: both VPCs must update their route tables to route to each other
- Non-transitive: if A peers with B, and B peers with C, A cannot reach C
  through B. The traffic from A would need to exit B's ENI, be processed by
  B's routing, and then... B has no route to C (because B's route table only
  has the B↔C peering route, not a transit route). Transitive routing is
  explicitly not supported.
- Free (no per-hour charge): you pay only for data transfer
- Manual route table management: on both sides

**The full-mesh problem:**
If you have N VPCs that all need to reach each other, you need N*(N-1)/2
peering connections. For 10 VPCs, that's 45 connections. For each new VPC
added, you must create N new peering connections and update N route tables.
This does not scale.

**When peering is appropriate:**
- 2–3 VPCs with stable, small topology
- You need to minimize cost (peering has no per-hour charge)
- The topology is simple and not expected to grow

---

## Transit Gateway

A Transit Gateway (TGW) is a regional, managed hub that connects multiple
VPCs (and on-prem networks via VPN or Direct Connect). VPCs attach to the
TGW; the TGW routes between them. Adding a new VPC requires creating one
new attachment, not N new peering connections.

**Characteristics:**
- Transitive: A attached to TGW, B attached to TGW, A can reach B (if route
  tables allow it)
- Hub-and-spoke topology: all traffic between VPCs flows through the TGW
- Supports up to 5,000 attachments
- Crosses account boundaries (via RAM sharing)
- Cost: $0.05/hr per attachment + $0.02/GB data processed

**TGW route tables:**
The TGW maintains its own routing table(s), separate from VPC route tables.
A TGW route table has entries of the form:
`destination CIDR → attachment-id`

When a packet enters the TGW from one attachment, the TGW looks up the
destination in the route table associated with that attachment and forwards
the packet to the matching attachment.

**Multiple TGW route tables:**
You can create multiple TGW route tables and associate different attachments
to different route tables. This is the key feature for blast radius control.

Example for an integration platform:

| TGW Route Table | Associated Attachments | Propagations (routes it knows about) |
|---|---|---|
| `shared-services-rt` | `shared-services-vpc` | All VPC attachments |
| `app-rt` | `app-vpc-1`, `app-vpc-2` | `shared-services-vpc` only |

Result:
- `app-vpc-1` can reach `shared-services-vpc` (route is in `app-rt`)
- `app-vpc-2` can reach `shared-services-vpc` (route is in `app-rt`)
- `app-vpc-1` cannot reach `app-vpc-2` (no route for `10.2.0.0/16` in `app-rt`)
- `shared-services-vpc` can reach all VPCs (all routes are in `shared-services-rt`)

This isolation is achieved with route table configuration, not with SG rules
or NACLs — it's enforced at the network routing layer.

**How routes get into TGW route tables:**
- **Propagation:** an attachment advertises its VPC's CIDR into one or more
  route tables automatically. When you enable propagation from an attachment
  to a route table, the VPC's CIDR appears in that route table.
- **Static:** you manually add a route entry to a TGW route table. Used for
  aggregate routes or special cases.

**VPC-side route tables must also be updated:**
The TGW knows how to route between attachments. But the VPCs themselves don't
automatically know to send cross-VPC traffic to the TGW. You must add a route
in each VPC's private route table: `destination CIDR → tgw-attachment-id`.

---

## Decision framework: peering vs TGW

| Factor | VPC Peering | Transit Gateway |
|---|---|---|
| VPC count | ≤ 3 | 4+ |
| Expected growth | Stable | Growing |
| Cost concern | Free per-hour | $0.05/hr/attachment |
| Transitivity needed | No | Yes |
| Cross-account | Supported | Easier (RAM sharing) |
| On-prem connectivity | Not supported | Supported (VPN, DX) |
| Route isolation | Not supported | Supported (route tables) |

For integration platforms: use TGW. You will always need cross-account
connectivity and on-prem VPN eventually. Starting with peering and migrating
to TGW later means updating route tables across every VPC — do it once,
do it right.

---

## Best practices

- Disable default TGW route table association and propagation when creating
  the TGW. The default table connects everything to everything — control your
  topology explicitly with custom route tables.
- Use `default_route_table_association = "disable"` and
  `default_route_table_propagation = "disable"` in Terraform from day one.
- Create one TGW route table per "security domain" — not per VPC. A
  shared-services domain (reachable by all) and an app domain (isolated from
  each other but can reach shared-services) is the canonical pattern.
- Add `depends_on` in Terraform when creating routes that reference TGW
  attachments — the attachment must exist before the route can be created.
- Tag TGW attachments clearly: `Name = "app-vpc-1-attachment"`, not just the
  attachment ID.

---

## Common pitfalls

- **Assuming VPC peering is transitive.** It is explicitly not. If you try to
  route through a peer VPC (A → B → C), the packet is dropped at B. No error
  is logged — it just silently fails. Use Reachability Analyzer (Day 8) to
  confirm paths.
- **Building a VPC peering topology and then migrating to TGW later.** The
  migration involves deleting peering connections, adding TGW attachments,
  and updating every route table in every VPC. If you have 5 VPCs, that's
  10+ route table updates. Start with TGW.
- **Forgetting to update both sides of a route.** The TGW knows the route
  (via propagation), but the VPC's route table still needs to point to the
  TGW. Missing either half breaks connectivity.
- **Using the default TGW route table.** The default table auto-associates
  and auto-propagates all attachments — connecting everything to everything
  with no isolation. Create custom route tables and manage associations
  explicitly.
- **TGW attachment takes 2–5 minutes to become available.** Terraform
  operations that depend on the attachment (like adding a route) will fail
  if they run before the attachment is ready. Use `depends_on`.

---

## Exercises

Answer before starting the lab:

1. VPC-A is peered with VPC-B. VPC-B is peered with VPC-C. Can VPC-A reach
   VPC-C? What would you need to do to enable it?
2. You have 8 VPCs that need to all reach each other. How many peering
   connections would you need? How many TGW attachments?
3. You have a TGW with two route tables: `prod-rt` (associated to prod VPCs)
   and `shared-rt` (associated to shared-services VPC). Prod VPCs propagate
   into `shared-rt`. Shared-services propagates into `prod-rt`. Can prod-vpc-1
   reach prod-vpc-2? Why or why not?
4. A packet arrives at the TGW from `app-vpc` destined for `10.0.2.5`
   (in `shared-services-vpc`). What is the minimum configuration needed
   in both the TGW route table and the `app-vpc` route table for this
   packet to reach its destination?

## Lab reference

Follow Day 4 in the implementation plan:
`aws_network_components/docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`

## Journal template

```
### Day 4 — VPC Peering vs TGW
Key concept in my own words: ...
What confused me (route table propagation vs association, non-transitive): ...
Break-it exercise — missing TGW route: which AZ failed and why: ...
```
