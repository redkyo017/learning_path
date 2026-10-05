# Day 5 solution — a wrong ASN and a static route

Read this after you have written your own chain in `journal.md`. Run everything inside
`netlab`, from `/course`.

The symptom has two parts: traffic is on the VPN path, and shutting the VPN path did
not move it. The first sentence says r1 prefers r2. The second says there is no usable
alternative. Two faults explain both, and each leaves its own evidence.

## Fault A: r1 expects the wrong ASN from r3

1. `ip netns exec r1 vtysh -N r1 -c 'show bgp summary'` lists r2 as `Established` with a
   prefix count, and r3 (`10.5.13.2`) in `Active` or `Connect` with no prefixes. A
   session that retries and never completes means TCP or OPEN is failing.
2. Rule out the transport first: the next step's `show bgp neighbor` output and a capture
   of `tcp port 179` show TCP connecting and an OPEN being exchanged, so the failure is
   in the OPEN, not in reachability.
3. `ip netns exec r1 vtysh -N r1 -c 'show bgp neighbor 10.5.13.2'` reports
   `Last reset ... ` and a last error of `Bad Peer AS` (an OPEN or NOTIFICATION error,
   subcode 2). In a capture of `tcp port 179` on r1's eth1 you see r1 send an OPEN, then a
   NOTIFICATION, then the TCP close, repeating every few seconds. r3's OPEN says
   `My AS: 65003`, and the config says `remote-as 65099`.
4. `show running-config` in r1's vtysh shows `neighbor 10.5.13.2 remote-as 65099`.

**Fix:** `ip netns exec r1 vtysh -N r1 -c 'configure terminal' -c 'router bgp 65001' -c 'neighbor 10.5.13.2 remote-as 65003'`
and then run `ip netns exec r1 vtysh -N r1 -c 'clear bgp 10.5.13.2'`. The clear matters: after
a failed OPEN, BGP waits for its ConnectRetry timer before dialing again (120 s by
default; the lab configs set `timers connect 5`, but the retry timer may already be
running). Wait up to 40 s for `Established`.

## Fault B: a static route outranks BGP

1. `ip -n r1 route show 10.50.100.0/24` prints
   `10.50.100.0/24 via 10.5.12.2 proto static metric 10`. A BGP-learned route would say
   `proto bgp metric 20`. This one was added by hand.
2. `ip netns exec r1 vtysh -N r1 -c 'show ip route 10.50.100.0/24'` shows zebra holding
   the route as a kernel or static route (code `K` or `S`) with a lower administrative
   distance than eBGP (20). zebra installs the lowest-distance route, so the BGP path
   stays in the BGP table, unused for forwarding. The kernel agrees on its own terms:
   metric 10 beats metric 20.
3. Even with fault A fixed, `show bgp ipv4 unicast 10.50.100.0/24` marks r3's path as
   best, but `ip -n r1 route get 10.50.100.1` still says `via 10.5.12.2`. The BGP table
   and the forwarding table disagree. That disagreement is the evidence: BGP made a
   decision and something with a lower distance overrode it.

**Fix:** `ip -n r1 route del 10.50.100.0/24 proto static`

## Partial fixes

- Fix A only: once the session is up, BGP prefers r3, but the static route (metric 10)
  still beats the BGP route (kernel metric 20). Checks "best path via r3" and
  "no static route" fail.
- Fix B only: the static route is gone, but r3 stays down, so the only BGP path is via
  r2. The r1<->r3 check and the best-path check fail.

After both fixes, `bash labs/day05/verify.sh` prints `PASS: day 05 is healthy.`

## Takeaway

BGP chooses among BGP paths. Administrative distance chooses among sources of routes
(connected, static, BGP, OSPF) before BGP's best-path list is even consulted for
forwarding. A forgotten static route from an old migration is the classic way for a
backup link to carry production traffic.
