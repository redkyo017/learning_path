# Day 6 solution — two faults, two layers

Read this after you have written your own chain in `journal.md`. Run everything inside
`netlab`, from `/course`.

The symptom bundles an overlay fault and a naming fault. They share no cause, so you
separate them by layer.

## Fault A: the overlay MTU equals the underlay MTU (and the outer packet may not fragment)

1. Test the overlay with growing sizes and the DF bit set:

   ```bash
   ip netns exec va ping -c2 -W1 -M do -s 1000 172.16.0.2
   ip netns exec va ping -c2 -W1 -M do -s 1400 172.16.0.2
   ip netns exec va ping -c2 -W1 -M do -s 1422 172.16.0.2
   ip netns exec va ping -c2 -W1 -M do -s 1472 172.16.0.2
   ```

   1000, 1400 and 1422 pass (1422 + 28 = 1450 is exactly the healthy limit, so it cannot
   tell the two states apart). 1472, a 1500-byte inner packet, ends with
   `2 packets transmitted, 0 received, +1 errors, 100% packet loss`: a silent black hole.
   After the fix, the same ping fails at once and loudly with
   `ping: local error: message too long, mtu=1450`. Loud refusal is the healthy behaviour.
2. Read the device: `ip -d link show vxlan100` prints `mtu 1500` and `df set`, while `u0`
   is also 1500. The ping's `+1 errors` line is the kernel reporting that the
   encapsulated packet, `1500 + 50 = 1550` bytes with DF set, cannot leave through the
   1500-byte `u0` and cannot be fragmented. It never reaches `vb`. (A capture on `u0`
   shows nothing for the 1472 ping, while the 1000-byte ping shows 1078-byte frames.)
3. Compare with the healthy device: the same 1472 ping is refused locally, because the
   device MTU is 1450. A tunnel whose MTU is larger than underlay minus overhead
   accepts packets it cannot deliver.
4. The arithmetic: VXLAN adds an outer IPv4 header (20), a UDP header (8) and a VXLAN
   header (8), plus the 14-byte inner Ethernet header that now rides as payload.
   14 + 20 + 8 + 8 = 50. A 1500-byte underlay therefore carries a 1450-byte overlay.

**Mechanism used:** `df set` on the VXLAN device (recreated without `dev u0` and with `mtu 1500` before `type`, because a
device bound to a lower device refuses an MTU above lower minus 50 with `Invalid argument`). Route caches are
flushed in `va` and `vb` so no cached path MTU hides the result. If the live check shows
the kernel fragments the outer packet anyway, the fallback is an nft rule in `vb`
dropping outer fragments: `ip frag-off & 0x1fff != 0 drop`.

**Fix:**

```bash
ip -n va link set vxlan100 mtu 1450
ip -n vb link set vxlan100 mtu 1450
```

Do not raise the underlay MTU as a quick fix here: that moves the problem to every
other path the packet takes.

## Fault B: `cli` asks the public view

1. `ip netns exec cli dig app.corp.internal` answers `203.0.113.20` and the footer
   says `SERVER: 10.6.10.54`. The expected address is `10.6.10.20`.
2. Compare the two servers:

   ```bash
   ip netns exec cli dig +short @10.6.10.53 app.corp.internal    # 10.6.10.20
   ip netns exec cli dig +short @10.6.10.54 app.corp.internal    # 203.0.113.20
   ```

   Same name, two answers, both correct for their audience. That is split horizon: a
   private view for clients inside, a public view for everyone else. Nothing is wrong
   with either server.
3. `cat /etc/netns/cli/resolv.conf` shows `nameserver 10.6.10.54`. The client was
   pointed at the wrong view. `db.onprem.corp` fails too, because the public view has
   no forwarding rule.

Unbound's cache is per server, so switching the resolver gives a deterministic result:
`dnsp` never held the internal answer.

**Fix:**

```bash
printf 'nameserver 10.6.10.53\noptions ndots:1\n' > /etc/netns/cli/resolv.conf
```

After fix A alone, `verify.sh` still fails checks 1 and 4. After fix B alone, it still
fails checks 2 and 3.
