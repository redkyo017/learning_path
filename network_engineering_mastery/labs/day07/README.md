# Day 7 lab — one packet end to end, then the gauntlet

## At a glance

- **Runs in:** `netlab` (see `labs/netlab/README.md`), from `/course`.
- **Commands:** `bash labs/day07/topo.sh up`, the Model and Prove blocks below,
  `bash labs/day07/gauntlet.sh list | start N | check N | reset`,
  `bash labs/day07/topo.sh down`.
- **Time:** 3 h 00 m (60 min Model, 30 min Prove, 90 min Gauntlet).
- **Success signal:** your hop table matches the three captures, and
  `gauntlet.sh check N` prints `PASS: day 07 is healthy.` for all five incidents, each
  diagnosed from evidence you wrote down first.

## Topology

```
 10.70.1.0/24            10.70.255.0/30        100.64.0.0/30 (the "internet")
 task ---------- vpcr ------------------ tgw =================== onp ---- api   192.168.10.10:8080
 .10    .1 / .2   .1                .2   gre1 169.254.10.1/30   gre1 .2    |
        (resolver)                      AS 64512  GRE, MTU 1476  AS 65000  +--- odns 192.168.20.53
                                        MSS clamp                nft stateful forward policy
```

- `task` is the "ECS task". Its `/etc/netns/task/resolv.conf` points at `10.70.1.2`.
- `vpcr` is the VPC router (`10.70.1.1`) and the resolver (`10.70.1.2`, unbound with a
  `forward-zone` for `onprem.corp`).
- `tgw` is the Transit Gateway: a route table, a GRE tunnel, an MSS clamp, and FRR
  advertising `10.70.0.0/16` to `onp`.
- `onp` is the on-prem edge: FRR advertising the summary `192.168.0.0/16`
  (`aggregate-address ... summary-only`) and a stateful firewall.
- `api` serves `/` (a tiny page) and `/big.bin` (300000 bytes) on port 8080.
  `odns` answers `api.onprem.corp -> 192.168.10.10`.

```bash
bash labs/day07/topo.sh up
ip netns exec task curl -s -o /dev/null -w '%{http_code}\n' http://api.onprem.corp:8080/   # 200
```

## Model block (60 min) — fill the table before you capture anything

Using only what you know from Days 1 to 6 and the topology above, fill in the table
in `journal.md`. For each hop write the header fields that change, the fields that
stay the same, and which table decides. Then predict the three values you will compare
in the Prove block: the TTL of the packet at `task`, on the wire at `tgw wan` (inner
and outer) and at `onp lan`; the MSS in the SYN at each place; and the length of the
outer packet for a full-size segment.

| Hop | Table that decides | Fields that change (MACs, TTL, outer IPs, conntrack) | Stays the same |
|-----|--------------------|------------------------------------------------------|----------------|
| 1. `task` asks the resolver for the name | | | |
| 2. `task` ARPs for its gateway and sends | | | |
| 3. `vpcr` forwards | | | |
| 4. `tgw` looks up the route and encapsulates | | | |
| 5. the packet crosses the underlay (`tgw wan` to `onp wan`) | | | |
| 6. `onp` decapsulates and forwards | | | |
| 7. `onp` firewall | | | |
| 8. `api` accepts the connection | | | |
| 9. the reply path back to `task` | | | |

Check yourself against the appendix of `ANSWERS.md` only after the Prove block.

## Prove (30 min) — three captures at once

Start three captures in the background (each runs inside its namespace, so
`topo.sh down` stops them), generate one request, then stop them:

```bash
ip netns exec task tcpdump -ni eth0 -e -w /run/netlab/task.pcap 'tcp port 8080' &
ip netns exec tgw  tcpdump -ni wan  -e -w /run/netlab/wan.pcap  'ip proto 47'   &
ip netns exec onp  tcpdump -ni lan  -e -w /run/netlab/lan.pcap  'tcp port 8080' &
sleep 2
ip netns exec task curl -s -o /dev/null http://api.onprem.corp:8080/big.bin
sleep 1; pkill tcpdump
```

Read them with `tcpdump -nver FILE` (add `-c 6` to stay short):

```bash
tcpdump -nver /run/netlab/task.pcap -c 6
tcpdump -nver /run/netlab/wan.pcap  -c 6
tcpdump -nver /run/netlab/lan.pcap  -c 6
```

Compare, in this order:

1. **MAC addresses.** The destination MAC at `task eth0` is the MAC of `vpcr`'s `eth0`
   and the destination MAC at `onp lan` is the MAC of `api`. They share no value:
   each link rewrites both MACs.
2. **TTL.** `task` sends at 64. The inner packet on `tgw wan` has a TTL two lower
   (two routers forwarded it), and the outer GRE header has its own TTL of 64. At `onp
   lan` the packet has lost one more.
3. **Outer IPs.** The `wan` capture shows `100.64.0.1 > 100.64.0.2` with protocol GRE
   (47); the inner packet is still `10.70.1.10 > 192.168.10.10`.
4. **The MSS in the SYN.** `task eth0` shows `mss 1460`. On `wan` and `lan` the inner
   SYN shows `mss 1436`. The clamp on `tgw` changed it, in a packet that is otherwise
   the one `task` built. The SYN-ACK leaves `api` with `mss 1460` and arrives at `task`
   with `mss 1436`: the clamp works in both directions.
5. **Conntrack.** `ip netns exec onp conntrack -L` while a download runs shows one
   entry for the flow, with the original and the reply tuple. Read both tuples; they
   explain why the established rule matches the SYN-ACK.

Write one line per comparison in `journal.md`: what you predicted, what you saw.

## Gauntlet (90 min) — five incidents, 20 min each, evidence first

Each incident has a 20-minute cap, about 90 minutes in total.

```bash
bash labs/day07/gauntlet.sh list        # the five symptoms, nothing else
bash labs/day07/gauntlet.sh start 1     # rebuild, inject incident 1, print its symptom
bash labs/day07/gauntlet.sh check 1     # PASS (exit 0), FAIL (exit 1), not up (exit 2)
bash labs/day07/gauntlet.sh reset       # back to healthy
```

Do the incidents in order, 1 to 5. For each:

1. `start N`, and start a 20-minute timer.
2. Before you change anything, write in `journal.md`: the symptom, the first three
   commands you ran, and the one output line that proves the cause. Name the layer
   and the Day it belongs to.
3. Fix it, run `check N`, and note the time.
4. Only then read the matching section of `ANSWERS.md` and compare your chain.

`vty NS 'cmd' ...` comes from `. labs/lib/common.sh` and runs
`ip netns exec NS vtysh -N NS -c 'cmd' ...`.

Rules: one fault per incident, injected by a script you do not read; capture before you
guess; and no `reset` as a fix.

### Self-score

| Score | Meaning |
|-------|---------|
| 2 | Diagnosed with a written evidence line, inside 20 minutes |
| 1 | Diagnosed, but late, or the evidence line was written after the fix |
| 0 | You guessed, or you used `ANSWERS.md` before your own chain |

Ten points is the maximum. Below 7, the incidents that scored lowest tell you which
Day to reread: 1 is Days 2 and 6, 2 is Days 2 and 5, 3 is Day 5, 4 is Day 6, 5 is
Days 3 and 4.

## Cleanup

`bash labs/day07/topo.sh down`, then follow `teardown.md`.
