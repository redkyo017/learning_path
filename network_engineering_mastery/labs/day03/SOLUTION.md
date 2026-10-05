# Day 3 solution — three faults, three kinds of evidence

Read this after you have written your own chain in `journal.md`. Run everything inside
`netlab`, from `/course`.

The symptom bundles three independent faults. Each one leaves a different mark in a
capture, so you separate them by what the packets do, not by guessing.

## Fault A: s1 drops its service port (filtered, not refused)

1. Aim at the backend directly, bypassing the load balancer:

   ```bash
   ip netns exec c1 curl -sS --max-time 5 http://10.3.2.20:8081/
   ip netns exec c1 curl -sS --max-time 5 http://10.3.2.20:8080/
   ```

   Port 8081 fails with `Connection refused` without any retry, after one round trip (netem makes that round trip slow while fault B is active). Port 8080 runs out the 5 s.
2. Capture in s1 while you repeat both: `ip netns exec s1 tcpdump -ni eth0 tcp`.
   - 8081: `Flags [S]` in, `Flags [R.]` out. A RST is an answer. The host is alive, the
     path works, and nothing listens on 8081. Nothing is wrong with 8081.
   - 8080: `Flags [S]` arrives three or four times, gaps of about 1 s, 2 s, 4 s, and
     nothing is sent back. The SYN reaches s1 and s1 stays silent. Silence at a live
     host means a filter.
3. Prove the filter: `ip netns exec s1 nft list ruleset` shows
   `table inet lab` with `tcp dport 8080 drop`.

**Fix:** `ip netns exec s1 nft delete table inet lab`

## Fault B: netem on the client link (slow, not broken)

1. `ip netns exec c1 ping -c 10 10.3.1.1` shows RTT near 200 ms and some missing
   replies (loss 30% on the way out only).
2. Fix A first, because A still drops 8080. Then, while a transfer runs, `ip netns exec c1 ss -ti dst 10.3.2.20` shows `rto` raised
   and `retrans` counting up. TCP is doing its job, and the link is the problem.
3. `tc -n c1 qdisc show dev eth0` prints `qdisc netem ... delay 200ms loss 30%`.
   On a real network you often cannot run `tc` on the client, so you infer the loss from
   retransmissions and late data in the capture.

**Fix:** `tc -n c1 qdisc del dev eth0 root`

## Fault C: the load balancer rewrites the source (client IP lost)

1. The app team reports `10.3.2.1` as the peer. Confirm on the backend: the access
   log, `tail /run/netlab/web.log`, and `ip netns exec s1 ss -tn`, show the peer as
   `10.3.2.1` where there used to be `10.3.1.10`.
2. `ip netns exec lb conntrack -L` shows the entry with the reply tuple rewritten:
   the reply side now says `src=10.3.2.20 dst=10.3.2.1`, not `dst=10.3.1.10`.
3. `ip netns exec lb nft list table ip nlb` prints the rule
   `ip daddr 10.3.2.20 snat to 10.3.2.1` in `postrouting`.

Why this matters: an **NLB** forwards the client's packets and, for instance targets,
keeps the client source address <!-- fact-checked 2026-10-05 -->, so the backend sees the real client. An **ALB** (or any
proxy) terminates the client connection and opens a new one from its own address. The
backend sees the proxy, and the client address survives only in a header
(`X-Forwarded-For` for HTTP) or in a prefix on the stream (proxy protocol v2 <!-- fact-checked 2026-10-05 -->, which an
NLB can add for backends that cannot see the source otherwise). Fault C turned the lab
NLB into an ALB-style hop without adding any header, so the information is lost.

**Fix:** `ip netns exec lb nft flush chain ip nlb postrouting`

## Verify once per fix

```bash
bash labs/day03/verify.sh
```

Apply the three fixes one at a time and run verify after each:

| After fixing | Expected failing checks |
|---|---|
| A only | `no netem`, `10 sequential requests` (maybe), `real client IP` |
| A and B | `real client IP` |
| A, B and C | none, PASS |

The `10 sequential requests` line while B is still active depends on the loss
pattern. It fails most runs, and a pass there proves nothing, so read the netem line.
