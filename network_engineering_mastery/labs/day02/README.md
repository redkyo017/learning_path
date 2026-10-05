# Day 2 lab: L3 forwarding and the MTU black hole

## At a glance

- **Where it runs:** inside the `netlab` container, from `/course`
  (`docker compose -p netlab exec netlab bash`).
- **Commands:** `bash labs/day02/topo.sh up`, the Prove section below,
  `bash labs/day02/break.sh`, `bash labs/day02/verify.sh`, `bash labs/day02/topo.sh down`.
- **Time:** about 105 minutes (45 to prove, 60 to break, diagnose and write the journal).
- **Success signal:** `verify.sh` prints `PASS: day 02 is healthy.` and exits 0, and your
  `journal.md` holds the evidence chain you wrote before fixing.

## Topology

```
 h1 eth0 ---- eth1 r1 eth2 ====== eth1 r2 eth2 ---- eth0 h2
 10.2.1.10    10.2.1.1  10.2.12.1/30  10.2.12.2  10.2.2.1    10.2.2.10
 fd00:2:1::10                                              fd00:2:2::10
                       MTU 1400 on both ends
```

h2 runs `python3 -m http.server 8080` and serves `/run/netlab/big.bin` (200 KB of random
bytes). The 1400 MTU sits on both ends of the r1–r2 link, so path MTU discovery is in play
even in the healthy state.

## Build

```bash
bash labs/day02/topo.sh up
ip -n h1 route; ip -n r1 route; ip -n r2 route
```

## Prove it

Run each capture in a second terminal (`docker compose -p netlab exec netlab bash`) before
you start the traffic.

1. **Route lookups.** The kernel answers "which route, which source, which next hop":

   ```bash
   ip -n h1 route get 10.2.2.10      # via 10.2.1.1 dev eth0 src 10.2.1.10
   ip -n h1 route get 10.2.1.1       # on-link, no via
   ip -n h1 route get 8.8.8.8        # the default route, via 10.2.1.1
   ```

   Say which entry matched before you press Enter.

2. **Traceroute, decoded.** Capture on h1 while the probes run:

   ```bash
   ip netns exec h1 tcpdump -vni eth0 'icmp or udp'          # terminal 2
   ip netns exec h1 traceroute -n 10.2.2.10                  # terminal 1
   ```

   Find the probes with `ttl 1`, `ttl 2`, `ttl 3`. Each `ttl 1`/`ttl 2` probe is answered by
   `ICMP time exceeded in-transit` from the router that decremented it to 0. The `ttl 3`
   probe reaches h2, which answers `ICMP ... udp port ... unreachable` (type 3, code 3).

3. **An IPv4 header, field by field.**

   ```bash
   ip netns exec h1 tcpdump -ni eth0 -vvx -c1 icmp           # terminal 2
   ip netns exec h1 ping -c1 10.2.2.10                       # terminal 1
   ```

   The hex starts `4500 0054`: version 4, IHL 5 (20 bytes), DSCP/ECN 0, total length 0x54 = 84.
   Then the ID, then `4000` (DF set, offset 0), then TTL `40` (64), protocol `01` (ICMP), the
   checksum, and the two addresses `0a02 010a` and `0a02 020a`. Write each field next to its
   byte offset (0, 1, 2, 4, 6, 8, 9, 10, 12, 16).

4. **The 1400 limit, exactly.** 1400 minus 20 (IPv4) minus 8 (ICMP) is 1372:

   ```bash
   ip netns exec h1 ping -M do -c1 -s 1372 10.2.2.10         # passes
   ip netns exec h1 ping -M do -c1 -s 1373 10.2.2.10         # From 10.2.1.1 ... Frag needed ... mtu = 1400
   ```

   The `From` address is r1, the router that could not forward over its 1400 link.

5. **`tracepath`.**

   ```bash
   ip netns exec h1 tracepath -n 10.2.2.10
   ```

   It starts at `1?: [LOCALHOST] pmtu 1500`, reports `pmtu 1400` on the `10.2.1.1` line, then
   shows `10.2.12.2` and `10.2.2.10 reached`, and ends with `Resume: pmtu 1400 hops 3 back 3`.

6. **IPv6 neighbour discovery.**

   ```bash
   ip -n h1 neigh flush dev eth0
   ip netns exec h1 tcpdump -ni eth0 -v 'icmp6 and (ip6[40] == 135 or ip6[40] == 136)'   # terminal 2
   ip netns exec h1 ping -6 -c1 fd00:2:1::1                                               # terminal 1
   ip -n h1 -6 neigh
   ```

   You see one Neighbor Solicitation (type 135) to the solicited-node multicast address
   `ff02::1:ff00:1` and a Neighbor Advertisement (type 136) back. `ip -n h1 -6 neigh` now
   shows `fd00:2:1::1` as REACHABLE. This is ARP, carried in ICMPv6.

7. **AWS emulation, the MTU tiers.** Make the h1–r1 link a "jumbo inside the VPC" link:

   ```bash
   ip -n h1 link set eth0 mtu 9001
   ip -n r1 link set eth1 mtu 9001
   ip netns exec h1 tracepath -n 10.2.2.10      # first line pmtu 9001; 10.2.1.1 line pmtu 1400; Resume: pmtu 1400 hops 3 back 3
   ip netns exec h1 ping -M do -c1 -s 8973 10.2.1.1   # succeeds: 8973 + 28 = 9001
   bash labs/day02/topo.sh up                   # restore the 1500/1400 topology
   ```

   Name the AWS construct in one sentence in `journal.md`: "in-VPC 9001 versus 1500 at the
   IGW is a jumbo link meeting a 1400-or-1500 link, on the wire."

## Break it

```bash
bash labs/day02/break.sh
```

Read the symptom, then write the chain of evidence in `journal.md` before you fix anything.
Two independent faults are in. Use `ip route get`, `ip neigh`, `ping -M do`, `tcpdump` on
both sides of r2, and `nft list ruleset`.

## Verify

```bash
bash labs/day02/verify.sh
```

Each check prints on its own line. Fix one fault and run it again: it must still FAIL until
both are repaired. The evidence chain and the fixes are in `SOLUTION.md`; read it only after
your own journal entry exists.

## Clean up

See `teardown.md`.
