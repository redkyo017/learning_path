# BGP best-path primer

Two ordered lists decide which route carries your traffic: FRR's BGP best-path selection
(the router you run in the Day 5 lab) and AWS's route preference in a VPC or Transit
Gateway route table. The first rule that separates two candidates wins, and the
rest are never looked at. This primer puts them side by side, adds the administrative
distance table, and walks six decisions.

## The two orders

Step 0 comes before any BGP attribute. The forwarding table does longest-prefix match
first, so a /25 beats a /24 whatever their attributes say. Both lists below start there.

| # | FRR best path (compare in this order) | AWS route preference (route tables) |
|---|---|---|
| 0 | Longest prefix (forwarding table) | Longest prefix <!-- fact-checked 2026-10-05 --> |
| 1 | **Weight**, highest. Local to the router, never sent to a peer. FRR gives locally originated routes weight 32768 | Local route (the VPC's own CIDR) always wins <!-- fact-checked 2026-10-05 --> |
| 2 | **LOCAL_PREF**, highest. Travels only inside one AS, default 100 | Static route over a propagated route (VPC and TGW tables) <!-- fact-checked 2026-10-05 --> |
| 3 | **Locally originated** (network, redistribute, aggregate) over learned | Among propagated routes, ranked by source: Direct Connect over Site-to-Site VPN (a static VPN route ranks between them on a VGW) <!-- fact-checked 2026-10-05 --> |
| 4 | **AS_PATH length**, shortest | For VPN, AS-path length (prepending works, but is discouraged if the CGW supports asymmetric routing) <!-- fact-checked 2026-10-05 --> |
| 5 | **ORIGIN**, IGP < EGP < incomplete | (not a rule you control) |
| 6 | **MED**, lowest. Only between paths from the same neighbouring AS, unless `bgp always-compare-med` | MED, only between paths from the same neighbouring ASN, after equal AS-path length <!-- fact-checked 2026-10-05 --> |
| 7 | **eBGP over iBGP** | (not exposed) |
| 8 | **Lowest IGP metric** to the next hop | (not exposed) |
| 9 | **Multipath check**: if `maximum-paths` is set, paths tied so far are all installed (ECMP) | (not exposed) |
| 10 | **Oldest path** (eBGP paths only). `bgp bestpath compare-routerid` removes this step, so router-id decides | (not exposed) |
| 11 | **Lowest router-id** | (not exposed) |
| 12 | **Shortest cluster-list** (route-reflector hops) | (not exposed) |
| 13 | **Lowest peer address** | (not exposed) |

Read the AWS column as the shape of the order, not a spec. AWS's documented ordering
differs between a VPC route table, a Transit Gateway route table and the Direct Connect
gateway, and AWS changes it. A tunnel's health takes precedence over all route attributes. Check the current AWS documentation for the table you use. Day 5 has the detail.

For Direct Connect, AWS also reads local-preference communities on the prefixes you
advertise: 7224:7100 (low), 7224:7200 (medium), 7224:7300 (high) <!-- fact-checked 2026-10-05 -->.
That is how you pick among your own DX links. Between DX and VPN, AWS's own preference
(row 3) already ranks DX first.

## What FRR prints

`show bgp ipv4 unicast PREFIX` marks the winner with a suffix on `best`. These are the
suffixes seen in the labs, and the rule each one reports:

| FRR line | Meaning |
|---|---|
| `best (Local Pref)` | decided by LOCAL_PREF |
| `best (AS Path)` | decided by AS_PATH length |
| `best (MED)` | decided by MED (needed `bgp always-compare-med` between two neighbouring ASes) |
| `best (Router ID)` | decided by lowest router-id, with `bgp bestpath compare-routerid` |
| `best (Older Path)` | everything tied, the path that has been up longest stays |

If the suffix names a rule lower than the one you meant to use, a rule above it did not
separate the candidates. `Older Path` is the warning sign: nothing in the policy chose
the winner, and a reboot can change it.

## Administrative distance

Before any protocol compares metrics, the router compares trust in the source.

| Source | AD |
|---|---|
| Connected | 0 |
| Static | 1 |
| eBGP | 20 |
| OSPF | 110 |
| IS-IS | 115 |
| RIP | 120 |
| iBGP | 200 |

The lowest AD is installed. A route that loses the AD comparison stays in its protocol's
own table and is not used. A floating static route has a deliberately high AD (for
example 250), so it is installed only when the dynamic route disappears.

On Linux there is a second layer. Zebra installs routes into the kernel, and the kernel
itself compares only prefix length and then metric. A hand-typed `ip route` with metric 10
beat the FRR route installed with metric 20 in the Day 5 lab, even though neither
mentioned AD. When a route "should" win and does not, compare `ip route` with
`show ip route`.

## Rule 0 first: prefix length

Best-path selection compares paths for one prefix. Different prefixes never meet in it.
Suppose r1 holds 10.50.100.0/24 from r3 with perfect attributes and 10.50.100.128/25 from
r2 with local-pref 50 and a long AS-path. Traffic for 10.50.100.200 follows the /25 through
r2, because the forwarding table does longest-prefix match before BGP attributes count.
This is why a more-specific hijack works, and why a /25 advertised over a VPN overrides a
prepended /24 over DX.

## Six worked decisions

The first four use the Day 5 topology: r1 learns r4's 10.50.100.0/24 (AS 64512) through
r2 (AS 65002) and through r3 (AS 65003, the "DX path").

**1. Everything ties: oldest path, then router-id.** No policy. Both paths have AS_PATH
length 2 (`65002 64512` and `65003 64512`), the same origin, no MED, and the same
local-pref and weight. Nothing is locally originated. Both are eBGP and the IGP metric
is the same. The path that arrived first stays: `best (Older Path)`. Resetting the winning
session hands the win to the other path, which is why this default is unstable. With
`bgp bestpath compare-routerid` the lowest router-id decides instead: `best (Router ID)`.
Write a policy so a person chooses, not the order of arrival.

**2. Local-pref beats everything below it.** Apply `FROM-R3` inbound on r1: it sets
local-pref 200 on r3's routes, and r2's keep 100. Local-pref is rule 2, so r3 wins before
AS-path is compared: `best (Local Pref)`. Use local-pref to choose your exit.

**3. Shorter AS-path decides when local-pref ties.** Remove `FROM-R3`, then prepend
64512 twice on r4's advertisement toward r3 (`PREPEND`). The r3 path becomes
`65003 64512 64512 64512`, length 4, against r2's length 2. r2 wins:
`best (AS Path)`. Prepending is the knob for the inbound direction, because it changes
what others see.

**4. MED chooses between links to the same neighbour.** r4 advertises one prefix on two
sessions with MED 50 and MED 10. Local-pref, AS-path and origin tie, and both paths come from
the same neighbouring AS, so MED compares and MED 10 wins: `best (MED)`. In the lab the
two paths came from two different neighbour ASes, and the rule is skipped between
different ASes unless `bgp always-compare-med` is set, which the lab needed. MED is non-transitive: the receiving AS does not pass it on, and
it may ignore it.

**5. A static route beats BGP, however good the BGP path.** The router has a static route
for the prefix (AD 1) and an eBGP route (AD 20). The static is installed. BGP may still
list its path as `best`, but it is not the route in use. Do not debug BGP attributes here:
check `show ip route PREFIX` for a static and compare with `ip route`. Remove the static,
or raise its distance so it floats. If the competing route is a kernel route, metric
decides: 10 beats 20, as in the lab.

**6. AWS: DX against VPN for the same prefix.** A VPC route table has 10.50.100.0/24
propagated from a Direct Connect gateway and from a Site-to-Site VPN <!-- fact-checked 2026-10-05 -->.
Same prefix, both propagated, so the source ranking decides: DX is installed, with no
AS-path comparison. To shift traffic to the VPN you need a more specific prefix over the
VPN, a static route, or to withdraw the DX route. Prepending longer on the VPN does the
opposite of what you want here. In the other direction (on-prem to AWS) your own router
chooses: raise local-pref on the DX-learned routes, as in decision 2.
