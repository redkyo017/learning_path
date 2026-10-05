# Day 4 lab — a firewall, a NAT and a two-AZ inspection path

## At a glance

- **Runs in:** `netlab` (see `labs/netlab/README.md`), from `/course`.
- **Commands:** `bash labs/day04/topo.sh up`, the Prove walkthrough below,
  `bash labs/day04/inspection.sh asym` and `appliance`, then `topo.sh up` again,
  `bash labs/day04/break.sh`, `bash labs/day04/verify.sh`, `bash labs/day04/topo.sh down`.
- **Time:** about 1 h 45 m (40 m guided proof, 20 m inspection emulation, 30 m break and
  diagnose, 15 m verify and journal).
- **Success signal:** `conntrack -E` shows a NAT-ed reply tuple, `inspection.sh asym`
  fails with the `fwb` invalid counter above zero, `inspection.sh appliance` returns
  HTTP 200, and `verify.sh` prints `PASS: day 04 is healthy.` after you fix both faults.

## Topology

```
              10.4.1.0/24                          10.4.2.0/24
   h1 .10 --+                                  +-- h2 .10  (http.server :8080)
            |  sw1 (bridge)        sw2 (bridge) |
   r2 .2  --+-- fw eth1 .1      fw eth2 .1 ---+-- r2 .2
                       \         /
                        fw  (forwarding, nft, conntrack)
                         | eth9 198.51.100.1/24
                         | 
                        ext eth0 198.51.100.10/24  (http.server :8080, no route to 10.4.0.0/16)
```

- h1 `10.4.1.10`, default via `10.4.1.1` (fw). h2 `10.4.2.10`, default via `10.4.2.1` (fw).
- r2 has a leg in each LAN (`10.4.1.2`, `10.4.2.2`) and forwards. In the healthy lab
  nothing uses it. Fault A makes h2 use it.
- ext is the "internet". It has no route to `10.4.0.0/16`, so a packet that arrives
  with an inside source address cannot be answered.
- `fw.nft` is the reference policy. Read it only after you have written your own.

## Prove it on the wire

### 0. Build it from nothing (15 min)

Before you read any lab script, type the smallest network that has a router and a NAT in
it, so you know what `topo.sh` automates. Inside `netlab`, from `/course`: three
namespaces, two subnets, one forwarding firewall `bfw` that masquerades.

```bash
# Namespaces, and a veth pair per link (each end is created straight into its namespace)
ip netns add bh1; ip netns add bfw; ip netns add bext
ip link add bh1-e0 netns bh1 type veth peer name bfw-in  netns bfw
ip link add bfw-out netns bfw type veth peer name bext-e0 netns bext

# Addresses
ip -n bh1  addr add 10.40.1.10/24     dev bh1-e0
ip -n bfw  addr add 10.40.1.1/24      dev bfw-in
ip -n bfw  addr add 198.51.100.1/24   dev bfw-out
ip -n bext addr add 198.51.100.10/24  dev bext-e0

# Links up, loopbacks too
for ns in bh1 bfw bext; do ip -n $ns link set lo up; done
ip -n bh1  link set bh1-e0  up
ip -n bfw  link set bfw-in  up
ip -n bfw  link set bfw-out up
ip -n bext link set bext-e0 up

# bh1 sends everything else to the firewall; the firewall forwards
ip -n bh1 route add default via 10.40.1.1
ip netns exec bfw sysctl -w net.ipv4.ip_forward=1

# Masquerade on the way out of bfw
ip netns exec bfw nft add table ip nat
ip netns exec bfw nft add chain ip nat post '{ type nat hook postrouting priority 100; }'
ip netns exec bfw nft add rule ip nat post oifname "bfw-out" masquerade
```

Prove it. Start a capture on the outside host, then ping through the firewall:

```bash
ip netns exec bext timeout 6 tcpdump -ni bext-e0 icmp &
sleep 1
ip netns exec bh1 ping -c2 198.51.100.10
wait
```

The ping succeeds, and the capture shows the echo requests from `198.51.100.1`, the
firewall's outside address, not from `10.40.1.10`. `bext` has no route to `10.40.1.0/24`
at all: the reply only finds its way home because the source was rewritten. To see it
fail, run `ip netns exec bfw nft flush chain ip nat post` and ping again.

Clean up with:

```bash
ip netns del bh1; ip netns del bfw; ip netns del bext
```

(`topo.sh up` wipes them anyway.) Now open `labs/day04/topo.sh` and compare: its `veth`,
`addr`, `route` and `forwarding` helpers are these same commands, wrapped, and `fw.nft`
holds the NAT table plus the filter you write in step 1.

### Then bring up the course topology

```bash
bash labs/day04/topo.sh up
ip netns exec h1 curl -s http://10.4.2.10:8080/          # prints: hello from the server
ip netns exec h1 curl -s http://198.51.100.10:8080/      # same, through the NAT
```

### 1. Write your own policy first

Do not open `fw.nft` yet. The spec for namespace `fw` (inside `eth1`, servers `eth2`,
outside `eth9`):

- default for forwarded traffic: drop
- return traffic of an allowed flow is allowed, and a packet that belongs to no flow
  (`invalid`) is dropped and counted
- h1's LAN (`10.4.1.0/24`) may open new connections to the servers LAN on TCP 8080 only
- h1's LAN may open new connections to the outside on any port
- everything leaving `eth9` from `10.4.1.0/24` is source-NATed to the address on `eth9`
- ping from the inside works (echo-request, plus the ICMP errors that make PMTUD work)

Write it to `/run/netlab/my.nft` (`topo.sh up` and `inspection.sh` wipe that directory, so
keep a copy elsewhere if you want it later). Start with `flush ruleset`, then
`table inet filter` and `table ip nat`. Load it, and run the checks:

```bash
ip netns exec fw nft -f /run/netlab/my.nft
bash labs/day04/verify.sh
```

Then compare with the reference. Save each ruleset in the same normalized form and diff
them:

```bash
ip netns exec fw nft list ruleset > /run/netlab/mine.txt
ip netns exec fw nft -f labs/day04/fw.nft
ip netns exec fw nft list ruleset > /run/netlab/ref.txt
diff /run/netlab/mine.txt /run/netlab/ref.txt
```

Every difference is a design choice to defend. The third command loads the
reference policy, so reload `my.nft` afterwards if you want to keep yours. Questions to
answer in `journal.md`: did you accept `established,related` before the `new` rules?
What does your policy do with an `invalid` packet, and can you see it counted?

### 2. Watch conntrack, and read the NAT-ed tuple

Shell 1:

```bash
ip netns exec fw conntrack -E -p tcp
```

Shell 2:

```bash
ip netns exec h1 curl -s -o /dev/null http://198.51.100.10:8080/
ip netns exec h1 curl -s -o /dev/null http://10.4.2.10:8080/
ip netns exec fw conntrack -L -p tcp
```

Each event is `[NEW]`, `[UPDATE]` (state changes) and `[DESTROY]`. A line has two tuples.
The first is the **original** direction. The second is what the **reply** must look
like:

```
tcp 6 ... src=10.4.1.10 dst=198.51.100.10 sport=41234 dport=8080 \
          src=198.51.100.10 dst=198.51.100.1 sport=8080 dport=41234 [ASSURED]
```

For the flow to ext, the reply tuple's destination is `198.51.100.1`, the NAT-ed
address on `eth9`. The inside address appears nowhere in the reply half. That is how
the box knows where to send the reply: it matches the reply to the entry and
un-NATs it. For the flow to h2 the two tuples mirror each other, because nothing is
rewritten. Watch the TCP state move SYN_SENT, SYN_RECV, ESTABLISHED, then TIME_WAIT
after the close, and find the timeout counting down in `conntrack -L`.

### 3. Counters

Add the word `counter` before `accept` or `drop` in each rule of `my.nft`, reload it,
send traffic (`curl` to h2 and ext, `ping -c 3` to h2, a `curl --max-time 3` to a closed port 9999
on h2) and read:

```bash
ip netns exec fw nft list ruleset
```

You see how many packets and bytes each rule matched. A rule that never counts is
either shadowed by an earlier rule or never reached. A packet that matches nothing is
dropped by the chain policy and counted nowhere, which is why an explicit final
`counter drop` helps when you debug.

### 4. The hook order, traced

```bash
ip netns exec fw nft add table ip tr
ip netns exec fw nft 'add chain ip tr pre { type filter hook prerouting priority -300 ; }'
ip netns exec fw nft add rule ip tr pre tcp dport 8080 meta nftrace set 1
ip netns exec fw nft monitor trace
```

In another shell: `ip netns exec h1 curl -s -o /dev/null http://198.51.100.10:8080/`.
Every packet of the flow produces a block of trace lines, one per chain it passes and
per rule it hits. Read them in order: the `tr` prerouting chain you added, then
`inet filter forward` (the rule that accepted it and the verdict), then
`ip nat postrouting` (the masquerade). That is the order in the diagram in
`content/day04.md`. Notice that the first packet traces the `new` rule, and later packets
trace the `established` rule and never reach the NAT chain: NAT runs only on the first
packet of a flow and the entry handles the rest. Remove the trace when done:

```bash
ip netns exec fw nft delete table ip tr
```

### 5. AWS emulation: two-AZ inspection

`inspection.sh` builds a second, separate topology. It begins with `topo_down`, so your
Day 4 main lab is gone afterwards. Redo it with `topo.sh up` when you need it.

```
 spa 10.41.0.10 --eth0 [ tgw ] eth1-- spb 10.42.0.10 (http.server :8080)
                        eth2 | 10.40.1.0/30      eth3 | 10.40.2.0/30
                        fwa  (AZ-a firewall)     fwb  (AZ-b firewall)
```

`tgw` stands for the Transit Gateway. `fwa` and `fwb` each run the same stateful
policy: accept established and related, drop invalid with a counter, accept new
connections from `10.0.0.0/8`. They send everything back to `tgw`. Steering is policy
routing in `tgw`: table 100 sends to `fwa`, table 200 to `fwb`, and a rule on the
transit links sends post-inspection traffic straight to the spoke.

```bash
bash labs/day04/inspection.sh up
bash labs/day04/inspection.sh asym
```

`asym`: spa's traffic goes to `fwa`, spb's traffic goes to `fwb`. The SYN from spa goes
through `fwa`. spb's SYN-ACK goes through `fwb`, which never saw the SYN, has no flow and
marks the packet INVALID. Expect:

```
curl spa -> spb:8080 : FAILED (no answer within 4 s)
fwa invalid-drop packets: 0
fwb invalid-drop packets: 5
```

The count differs between runs. The important part: `fwb` is above zero. `fwa` stays at
0, because the SYN-ACK dies at `fwb` and spa never sends an ACK. Look at the flows too: `ip netns exec fwa conntrack -L` shows `SYN_SENT` and `fwb` shows none.

```bash
bash labs/day04/inspection.sh appliance
```

`appliance`: both directions go to `fwa`. Expect `curl ... : OK (HTTP 200)` and `fwb`'s
invalid counter at `0` (the script waits 3 s and zeroes the counters, so `fwa` shows `0` too). Run the two modes alternately to convince yourself it is the
steering and not luck. The script replaces its rules each time and zeroes the counters.

Map it to AWS. A Transit Gateway delivers traffic to an inspection VPC through the
attachment's network interface **in the Availability Zone of the traffic's source**
<!-- fact-checked 2026-10-05 -->, choosing it per direction. With two AZs, a flow from AZ-a to AZ-b sends the request to
the appliance in AZ-a and the reply from AZ-b to the appliance in AZ-b. Each appliance
sees half of a flow. **Appliance mode** (`appliance_mode_support` on the inspection VPC
attachment) pins both directions of a flow to one AZ's network interface, using a flow
hash <!-- fact-checked 2026-10-05 -->. The `appliance` mode of the script has the same effect on the
wire. For the real thing, see `aws_lab/day04/` (optional, costs money).

## Break and diagnose

```bash
bash labs/day04/topo.sh up
bash labs/day04/break.sh
```

Write the evidence chain in `journal.md` before you fix anything. Then read
`SOLUTION.md`. Run `bash labs/day04/verify.sh` after each fix: it reports each check on
its own line.

## Journal

End with the sentence: "TGW appliance mode in AWS is ___ on the wire." Teardown:
`labs/day04/teardown.md`.
