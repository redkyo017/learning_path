# Day 7 answers — the gauntlet

Read an incident's section only after you have written your own evidence chain in
`journal.md`. Run everything inside `netlab`, from `/course`. For each incident:
the symptom, the first three commands a strong engineer runs, the evidence line that
proves the cause, the fix, and the AWS equivalent. Where a command prints something
that depends on your run, this file describes the fields to read instead of quoting
numbers.

Source the helpers first: `. labs/lib/common.sh`. That gives you `vty NS 'cmd' ...`, which
is `ip netns exec NS vtysh -N NS -c 'cmd' ...`.

The healthy path, for reference: `task` (10.70.1.10) asks the resolver at 10.70.1.2 in
`vpcr`; `vpcr` forwards `onprem.corp` to `odns`; the TCP flow goes `task -> vpcr -> tgw
-> gre1 -> onp -> api`.

## Incident 1 — "Health check OK, large responses hang"

**First three commands**

```bash
ip netns exec task curl -s -o /dev/null -w '%{http_code} %{size_download}\n' --max-time 5 http://api.onprem.corp:8080/
ip netns exec task curl -s -o /dev/null -w '%{http_code} %{size_download}\n' --max-time 5 http://api.onprem.corp:8080/big.bin
ip netns exec task ping -c2 -W2 -M do -s 1472 192.168.10.10
```

The small page returns `200`. The big file stops at a partial `size_download` and
curl ends on its timeout. The third command is the DF ping at the 1500-byte boundary:
healthy, `ping` reports that the packet needs fragmentation and names the next-hop MTU
(1476); here it prints nothing back at all.

**Evidence line.** Capture on `onp` `lan` while the download runs:
`ip netns exec onp tcpdump -ni lan 'tcp port 8080'`. After the handshake you see `api`
sending data segments of about 1448 bytes (a 1500-byte packet with the timestamp
option) with the same sequence number again and again, and no ACK advancing. The
3-way handshake and the small page worked, so the path exists; only full-size packets
die. Then read the three facts:

```bash
ip -n tgw link show gre1 | head -1          # mtu 1476
ip -n onp link show gre1 | head -1          # mtu 1500: it disagrees with its peer
ip netns exec tgw nft list ruleset          # no maxseg rule; an output rule drops ICMP type 3 code 4
ip netns exec onp nft list ruleset          # the same output rule on the far side
```

Three things are wrong together, and each one alone is survivable. With the clamp,
no host builds a packet larger than the tunnel. With correct MTUs, `onp` would say
"too big" and the sender would adapt. With ICMP intact, path MTU discovery would repair
a missing clamp. Removing all three leaves a black hole: the 1500-byte packet plus 24
bytes of GRE and outer IP cannot cross a 1500-byte link with DF set, and the error that
would explain it is dropped.

**Fix**

```bash
ip -n onp link set gre1 mtu 1476
ip netns exec tgw nft -f labs/day07/clamp.nft           # the MSS clamp comes back
for ns in tgw onp; do ip netns exec $ns nft delete table inet o2; done   # let ICMP type 3 code 4 out
for ns in task vpcr tgw onp api; do ip -n $ns route flush cache; done
```

Flushing the route caches matters: `api` may have cached a bad path MTU, and the
cached value would hide whether the fix worked.

**AWS equivalent.** A Site-to-Site VPN is an IPsec (or GRE-over-IPsec) tunnel with an
MTU below 1500, and the customer gateway must clamp MSS and must not filter ICMP
"fragmentation needed". The symptom is the same: health checks and small API calls pass,
large transfers stall.

## Incident 2 — "Name resolves, connect times out"

**First three commands**

```bash
ip netns exec task dig +short api.onprem.corp          # an address: DNS is fine
ip netns exec task traceroute -n -m 8 192.168.10.10
ip -n tgw route get 192.168.10.10
```

**Evidence line.** `traceroute` prints `1  10.70.1.1`, `2  10.70.255.2`, `3  10.70.1.1`,
`4  10.70.255.2`, and so on, alternating hop after hop, and never an address in
`169.254.10.0/30` or `192.168.x.x` (`vpcr` answers from its primary address on `eth0`). The packet is going around in a circle between `tgw` and `vpcr`. `ip
route get` on `tgw` names `via 10.70.255.1 dev eth0`, back towards the VPC, where
the BGP route says `gre1`:

```bash
ip -n tgw route show 192.168.0.0/16 192.168.10.0/24
```

A `/24` beats the BGP `/16` by longest prefix, regardless of metric or protocol. Each
lap costs two TTL decrements, so the packet dies at `tgw` after about 31 laps and
`task` gets a time-exceeded (curl reports a timeout, not a refusal).

**Fix**

```bash
ip -n tgw route del 192.168.10.0/24 via 10.70.255.1
```

**AWS equivalent.** A Transit Gateway static route (or a VPC route-table entry) that is
more specific than the propagated on-prem prefix and points back at the VPC
attachment. Longest prefix wins, and a static route beats a propagated one for the same
prefix <!-- fact-checked 2026-10-05 -->.

## Incident 3 — "Everything on-prem unreachable since the change window"

**First three commands**

```bash
ip netns exec task ping -c2 -W1 192.168.10.10          # bypass DNS to split the layers
ip -n tgw route show 192.168.0.0/16
vty tgw 'show bgp ipv4 unicast'
```

**Evidence line.** The ping fails fast with a destination-unreachable that names the
`tgw` side (10.70.255.2), not with silence, so something knows it has no route. The kernel
table on `tgw` has no `192.168.0.0/16`, and the BGP table lacks it too, while the
session is still `Established`. Move to the far end:

```bash
vty onp 'show bgp neighbors 169.254.10.1 advertised-routes'    # lists no prefixes
vty onp 'show running-config'                                  # neighbor ... route-map OUT out
```

The session is up and the peer is silent, which points at an outbound filter on `onp`.
Name resolution fails as well here, because the resolver cannot reach `odns`: that is
why you split the layers with the ping before the DNS test.

**Fix**

```bash
vty onp 'configure terminal' 'router bgp 65000' 'address-family ipv4 unicast' \
  'no neighbor 169.254.10.1 route-map OUT out' 'exit-address-family' 'exit' \
  'no route-map OUT' 'end' 'clear bgp * soft out'
```

Wait a few seconds for the route to appear on `tgw`, then retry.

**AWS equivalent.** The on-prem router stopped advertising a prefix over the VPN's
BGP session (a new outbound filter, a prefix-list typo), so the Transit Gateway's
propagated routes for that prefix disappear. The VPN tunnel is still `UP` <!-- fact-checked 2026-10-05 --> in the
console, and the failure is in the route table, not the tunnel.

## Incident 4 — "curl: Could not resolve host api.onprem.corp"

**First three commands**

```bash
ip netns exec task cat /etc/resolv.conf                 # nameserver 10.70.1.2
ip netns exec task dig @10.70.1.2 api.onprem.corp       # status SERVFAIL, no answer
ip netns exec task dig @192.168.20.53 api.onprem.corp  # the on-prem server answers
```

**Evidence line.** The resolver the client really uses fails, and the authoritative
on-prem server answers the same question correctly when asked directly. The path to
`odns` is fine (the third command crossed the tunnel and the firewall), and
`ping 192.168.10.10` works. The fault is inside the resolver:
`cat /run/netlab/vpcr-dns.conf` has a `server:` block and no `forward-zone` for
`onprem.corp`, so the resolver tries the public hierarchy, which this lab has no route to.

**Fix**

```bash
cp labs/day07/dns/vpcr.conf /run/netlab/vpcr-dns.conf
kill $(ip netns pids vpcr)
ip netns exec vpcr setsid unbound -d -c /run/netlab/vpcr-dns.conf >/run/netlab/vpcr-dns.log 2>&1 &
sleep 1
ip netns exec task dig +short api.onprem.corp
```

**AWS equivalent.** A Route 53 Resolver outbound endpoint exists, but the forwarding
rule for the on-prem domain is missing, or it is not associated with this VPC. VPC
clients ask the VPC resolver, the resolver has no rule, and the name fails to resolve.
Connectivity tests by IP address still pass.

## Incident 5 — "SYN reaches on-prem, nothing comes back"

**First three commands**

```bash
ip netns exec task curl -sv --max-time 4 http://api.onprem.corp:8080/ -o /dev/null
ip netns exec api ss -tn state syn-recv
ip netns exec onp nft -a list chain inet filter forward
```

**Evidence line.** The name resolves and `curl` sits in the connect phase until it times
out (silence, not a refusal). `ss` on `api` shows the half-open connection in `syn-recv`:
the SYN got all the way to the server, and the server answered. Capturing on `onp` `lan`
and on `gre1` shows the SYN-ACK leave `api` and never appear on `gre1`, so it died in
`onp`. The forward chain has the rule that admits new connections to port 8080 and no
`ct state established,related accept`, and the final `counter drop` rule's packet count
rises with every SYN-ACK retransmission. `ping` still works because ICMP has stateless
accept rules, which is the contrast that locates the missing piece: the policy keeps
state for TCP, and the rule that uses the state is gone.

**Fix**

```bash
ip netns exec onp nft insert rule inet filter forward ct state established,related accept
```

**AWS equivalent.** A return path blocked by something that is not stateful for it:
an on-prem firewall that tracks no state for the flow, or a network ACL whose outbound
rules lack the ephemeral return range (1024-65535 is the usual range to allow <!-- fact-checked 2026-10-05 -->).
Security groups are stateful and would not cause this.

## Appendix — the filled hop table

| Hop | Table that decides | Changes | Does not change |
|-----|--------------------|---------|-----------------|
| `task` asks the resolver | `/etc/resolv.conf`, then the neighbour table (same subnet, so no router) | dst MAC = `vpcr` eth0; DNS source port | src/dst IP |
| `task` sends to the app | route table: default via 10.70.1.1; ARP for the gateway | dst MAC = `vpcr` eth0 | dst IP 192.168.10.10 |
| `vpcr` | longest prefix: `192.168.0.0/16 via 10.70.255.2` | MACs rewritten, TTL 64 -> 63 | IPs, ports |
| `tgw` | route lookup picks `gre1` (BGP-learned `192.168.0.0/16`); the clamp rewrites the MSS in a SYN | TTL 63 -> 62; then GRE adds an outer IP (100.64.0.1 -> 100.64.0.2, TTL 64) | inner IPs, ports |
| `tgw` wan -> `onp` wan | route to 100.64.0.2 | outer MACs | the inner packet, unseen by the underlay |
| `onp` decap | route for `192.168.10.10` on `lan` | outer header removed, TTL 62 -> 61, MACs | inner IPs |
| `onp` firewall | `forward` chain; conntrack entry created for the SYN | conntrack gains one entry in state NEW | packet bytes |
| `api` | socket table: listener on 8080 | SYN-ACK is the reply; conntrack on `onp` goes to ESTABLISHED | |
| return path | `api` default via `onp`; `onp` uses the BGP route `10.70.0.0/16 via 169.254.10.1`; `tgw` has `10.70.1.0/24 via 10.70.255.1` | same rewrites in the other direction | |
