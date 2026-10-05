# Day 4 solution — two faults, two stateful-device symptoms

Read this after you have written your own chain in `journal.md`. Run everything inside
`netlab`, from `/course`.

The symptom bundles two independent faults. One breaks the return path of a stateful
firewall. The other breaks the translation that gives inside hosts an outside identity.

## Fault A: h2 returns through r2 (asymmetric routing)

1. Reproduce and see where it hangs:

   ```bash
   ip netns exec h1 ping -c 2 10.4.2.10                      # works
   ip netns exec h1 curl -sS --max-time 5 http://10.4.2.10:8080/   # hangs
   ```

2. Ask the firewall what it thinks. `ip netns exec fw conntrack -L -p tcp` shows the
   flow to `10.4.2.10:8080` stuck in `SYN_SENT` with `[UNREPLIED]`. fw saw a SYN
   and never a SYN-ACK.
3. `ip netns exec fw nft list chain inet filter forward` shows the `ct state invalid
   counter` rule with a rising packet count. h1 does receive the SYN-ACK (by another
   way, see below), answers with an ACK and sends its request. For a flow stuck in
   SYN_SENT the firewall treats both as INVALID and drops them.
4. Capture on both sides of the server LAN:

   ```bash
   ip netns exec fw tcpdump -ni eth2 tcp port 8080     # one SYN out, no SYN-ACK in; later h1's ACK and data arrive and are dropped as invalid
   ip netns exec r2 tcpdump -ni eth2 tcp port 8080     # the SYN-ACK leaves h2 toward r2 (and is retransmitted: h1's ACK never reached h2)
   ```

   The SYN goes out through fw once (h1 got the SYN-ACK, so it does not retransmit
   the SYN), and the SYN-ACK never comes back through fw, while r2 carries it. h2
   retransmits its SYN-ACK because the handshake ACK and h1's data die at fw. r2 forwards it onto the inside LAN, where h1 gets it.
5. The route explains it: `ip -n h2 route get 10.4.1.10` prints `via 10.4.2.2`, not
   `via 10.4.2.1`. The forward path and the return path are different.

**Why ping survived:** the policy accepts ICMP echo-request without looking at state
(`icmp type { echo-request, ... } accept`), so the request passes. The echo-reply
takes the same asymmetric route through r2 and reaches h1 without ever crossing fw, so
fw's missing state does not matter. TCP breaks because the firewall's rules for TCP
need a tracked flow, and the flow never completed.

**Fix:** `ip -n h2 route del 10.4.1.0/24 via 10.4.2.2`

## Fault B: fw does not translate (no NAT, no return)

1. `ip netns exec h1 curl -sS --max-time 5 http://198.51.100.10:8080/` hangs. Inside
   traffic to h2 is unaffected, so the policy and the link to ext are not the issue.
2. Capture on ext: `ip netns exec ext tcpdump -ni eth0 tcp port 8080`. SYNs arrive
   with source `10.4.1.10`, the original inside address, retransmitting.
3. ext has no route to `10.4.0.0/16` (`ip -n ext route`), so it cannot answer a
   private source address. No NAT means no return.
4. `ip netns exec fw nft list table ip nat` shows the `postrouting` chain empty. The
   masquerade rule is gone.

**Fix:** `ip netns exec fw nft -f labs/day04/fw.nft` (reloads the whole reference policy).

## Verify once per fix

```bash
bash labs/day04/verify.sh
```

| After fixing | Expected failing checks |
|---|---|
| A only | `h1 -> ext:8080 (via NAT)`, `fw masquerades outbound` |
| B only | `h1 -> h2:8080`, `h2 returns to 10.4.1.0/24 via fw` |
| A and B | none, PASS |

## Inspection emulation: expected results

- `inspection.sh asym`: curl fails, `fwb` invalid counter above zero.
- `inspection.sh appliance`: curl prints HTTP 200, `fwb` counter `0` and `fwa` `0`.
