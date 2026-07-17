# Day 6 — Hybrid Connectivity

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain the components of a Site-to-Site VPN connection (CGW, VGW/TGW,
  tunnels, PSK, BGP)
- State why two VPN tunnels are required for HA and what happens when one fails
- Explain why BGP is preferred over static routes for VPN
- Describe the three types of Direct Connect virtual interfaces (private,
  public, transit) and when each is used
- Trace a DNS query from an AWS EC2 to an on-prem hostname via Resolver
  outbound endpoint

---

## Site-to-Site VPN

A Site-to-Site VPN connects your on-premises network to AWS over the public
internet using IPSec tunnels. "Site-to-Site" because you are connecting two
networks (sites), not a single user device.

**Components:**

**Customer Gateway (CGW):**
The CGW is an AWS resource that represents your on-prem VPN device. It
stores the IP address and BGP ASN of your physical (or virtual) VPN router.
The CGW is just a configuration record — it has no AWS infrastructure.

**VPN connection:**
The logical connection between the CGW and an AWS VPN endpoint. Each VPN
connection has exactly two IPSec tunnels, each terminating on a different
AWS endpoint in a different Availability Zone. Both tunnels are active
simultaneously in active/active mode.

**TGW VPN attachment (preferred) vs Virtual Private Gateway:**
- **Virtual Private Gateway (VGW):** attaches to a single VPC. Simpler but
  only serves one VPC. If you have multiple VPCs behind the VPN, traffic
  must be routed through the single VPC with the VGW.
- **TGW VPN attachment:** attaches the VPN to the Transit Gateway. Any VPC
  attached to the TGW can reach the on-prem network (if the TGW route tables
  allow it). This is the correct choice for integration platforms with multiple VPCs.

---

## IPSec tunnels

IPSec is the encryption protocol used for VPN tunnels. Each AWS VPN
connection creates two tunnels:
- **Tunnel 1** and **Tunnel 2** each have a unique AWS endpoint IP, a pre-shared
  key (PSK), and BGP peering configuration
- Both tunnels should be in active/active mode (both carrying traffic)
- Each tunnel terminates on a different AWS infrastructure component in a
  different AZ — AWS may bring down one tunnel for maintenance, so both must
  be configured and monitored

The "inside CIDR" (`169.254.10.0/30`) is a link-local address used for the
BGP peering session between the tunnel endpoints. It is not your VPC CIDR
— it's just the peering address for the BGP session running over the tunnel.

**Why two tunnels are mandatory:**
AWS performs maintenance on VPN endpoint infrastructure periodically. When
this happens, one tunnel goes down. If you only configured tunnel 1, your
VPN goes down during maintenance windows, often at night without warning.
With both tunnels configured, traffic fails over automatically to the
remaining tunnel. Always configure both.

---

## BGP vs static routes

BGP (Border Gateway Protocol) is a dynamic routing protocol. When using BGP
on the VPN:
- Your on-prem router advertises its network prefixes to AWS via BGP over
  the IPSec tunnel
- AWS advertises your VPC CIDRs to your on-prem router
- If a tunnel fails, BGP withdraws the routes learned through it and
  re-advertises them through the remaining tunnel — automatic failover

With static routes:
- You manually configure which CIDRs to send over the VPN on both sides
- If a tunnel fails, the static route still points to the failed tunnel until
  someone manually removes it and adds a route via the working tunnel
- This means a maintenance event (30–60 minutes) can cause an outage unless
  someone is watching

BGP is supported by all enterprise VPN devices. Use it. The only reason to
use static routes is if your on-prem device is too old to support BGP.

**ASN assignment:**
- AWS side: 64512 by default (the TGW ASN)
- On-prem side: any private ASN (64512–65534, or 4200000000–4294967294 for
  32-bit ASNs). In this lab we use `65000` for the simulated on-prem.
- The two sides must use different ASNs.

---

## Direct Connect

Direct Connect (DX) is a dedicated physical connection from your data centre
to an AWS Direct Connect Location (a co-location facility where AWS maintains
PoPs). Unlike VPN (which runs over the public internet), DX uses a private
circuit with predictable latency and up to 100 Gbps bandwidth.

DX is not lab-able without real hardware or a carrier circuit, but understand
the concepts for when your team discusses it:

**Virtual Interfaces (VIFs):**
A DX connection is divided into virtual interfaces by VLAN tagging:
- **Private VIF:** connects to a Virtual Private Gateway in one VPC. Enables
  private IP connectivity to one VPC.
- **Transit VIF:** connects to a Transit Gateway. Enables private IP
  connectivity to multiple VPCs. Use this for integration platforms.
- **Public VIF:** enables access to AWS public services (S3, DynamoDB,
  public endpoints) via the DX connection, using public IPs. Not for VPC
  private connectivity.

**Hosted vs dedicated:**
- **Dedicated connection:** a full circuit you order directly from AWS
  (1 Gbps or 10 Gbps or 100 Gbps)
- **Hosted connection:** a sub-circuit provided by an AWS DX Partner (can be
  50 Mbps to 10 Gbps). Useful when you need smaller increments or a carrier
  already has a DX presence

**When to use DX vs VPN:**
- DX for: consistent low latency, high bandwidth (hundreds of Gbps), compliance
  requirements that prohibit internet traversal
- VPN for: smaller bandwidth needs, cost sensitivity, faster time-to-connect
  (DX provisioning takes weeks; VPN is minutes)
- Both together: DX for primary path, VPN as backup ("VPN over DX" pattern)

---

## Hybrid DNS with Resolver

With the VPN tunnel up and the Resolver outbound endpoint/rule built on Day 3,
hybrid DNS now works end-to-end:

```
EC2 in shared-services-vpc
  → queries "corp-erp.corp.internal"
  → VPC resolver sees Resolver rule for "corp.internal"
  → forwards query to outbound endpoint ENI IPs
  → outbound endpoint forwards to 192.168.1.2 (on-prem DNS)
    [travels over VPN tunnel]
  → on-prem DNS responds with the corp-erp IP
  → response returns through tunnel to the EC2
```

And in the other direction, on-prem systems reach AWS names via the inbound
endpoint (configured on Day 3), forwarding queries to the inbound endpoint
IPs over the VPN.

---

## strongSwan (lab VPN simulation)

Since we don't have physical hardware, we simulate an on-prem VPN device
using strongSwan — an open-source IPSec implementation — running on an EC2
in a separate "onprem-sim" VPC.

Key config files:
- `/etc/strongswan/ipsec.conf`: tunnel definition (IKE/IPSec parameters,
  remote endpoint IPs, local/remote subnets)
- `/etc/strongswan/ipsec.secrets`: pre-shared keys (`%any %any : PSK "key"`)
- Start tunnels: `sudo systemctl start strongswan` or `sudo ipsec up tunnel1`
- Check status: `sudo ipsec status`

The AWS-generated VPN config download (available after creating the VPN
connection) includes a strongSwan-specific template with all values filled in.
Download it in the Console and adapt it for the lab.

---

## Best practices

- Always configure both VPN tunnels. Never use a single-tunnel configuration
  in any non-test environment.
- Use BGP (dynamic routing) unless your VPN device literally cannot support it.
- Attach VPN to TGW (not VGW) for any multi-VPC or multi-account setup.
- Monitor VPN tunnel state with CloudWatch metrics: `TunnelState` (0=down,
  1=up). Alert at 0. Alert at 1 if BOTH tunnels should be up.
- For Direct Connect planning: use a Transit VIF to TGW for all new
  deployments — Private VIF to VGW limits you to one VPC.

---

## Common pitfalls

- **Configuring only one tunnel.** AWS maintenance brings it down without
  notice. Configure both — even if it takes an extra 20 minutes.
- **Using static routes on the VPN.** A tunnel failure leaves the static route
  pointing at a dead endpoint until manually fixed. BGP makes failover automatic.
- **Forgetting to disable source/destination check on the strongSwan EC2.**
  EC2 instances drop packets that aren't addressed to them by default. The
  VPN EC2 needs to forward packets on behalf of the whole `192.168.0.0/16`
  range — disable source/destination check.
- **Missing the on-prem-side route.** After the VPN is up, you must add a
  route in the `onprem-sim-vpc` route table pointing `10.0.0.0/8` to the
  strongSwan EC2's ENI. Without it, responses from on-prem can't reach AWS.
- **Tunnel IPs not matching between both sides.** The inside IPv4 CIDR
  (`169.254.10.0/30`) must match on both the AWS VPN connection config and
  the strongSwan config. A mismatch causes the tunnel to stay down.

---

## Exercises

Answer before starting the lab:

1. AWS performs maintenance on one VPN tunnel endpoint. Tunnel 1 goes down.
   Your strongSwan instance has both tunnels configured with BGP. What
   happens to traffic, and how quickly does it recover?
2. You're using static routes on a VPN connection. The same tunnel goes down.
   What happens to traffic? What manual action is required to restore it?
3. You have 5 VPCs and need them all to reach an on-prem data centre via VPN.
   Should you use a VGW or a TGW attachment? Why?
4. A `dig corp-erp.corp.internal` from an EC2 in `shared-services-vpc` times
   out. The VPN tunnels are both UP. What are the three most likely causes?

## Lab reference

Follow Day 6 in the implementation plan:
`aws_network_components/docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`

## Journal template

```
### Day 6 — Hybrid Connectivity
Key concept in my own words: ...
What confused me (tunnel inside CIDR, BGP ASN, source/dest check): ...
Break-it exercise — single tunnel failure: what failover looked like: ...
```
