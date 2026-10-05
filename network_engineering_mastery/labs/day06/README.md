# Day 6 lab — overlays, IPsec and names in a box

## At a glance

- **Runs in:** `netlab` (see `labs/netlab/README.md`), from `/course`.
- **Commands:** `bash labs/day06/topo.sh up`, the Prove walkthrough below,
  `bash labs/day06/geneve.sh up|down`, `bash labs/day06/break.sh`,
  `bash labs/day06/verify.sh`, `bash labs/day06/topo.sh down`.
- **Time:** about 1 h 45 m (50 m guided proof, 25 m GENEVE and resolver mapping, 30 m break,
  diagnose and verify; skip the ESP demo if short on time).
- **Success signal:** `tshark` shows VNI 100 around the inner frame, ESP shows an SPI
  and a sequence with an opaque payload, `dig` shows the TTL counting down, and
  `verify.sh` prints `PASS: day 06 is healthy.` after you fix both faults.

## Topology

```
 underlay 10.6.0.0/24                       overlay 172.16.0.0/24 (VXLAN VNI 100, UDP 4789)
 va u0 10.6.0.1 ========== u0 10.6.0.2 vb   va vxlan100 .1  <------>  vb vxlan100 .2   MTU 1450

 bridge br0 in sw, 10.6.10.0/24
   cli  .10  (resolv.conf: nameserver 10.6.10.53, ndots:1)
   dnsi .53  unbound, internal.conf  = VPC resolver + private hosted zone
   dnsp .54  unbound, public.conf    = the public view
   odns .60  unbound, onprem.conf    = on-prem DNS
   app  .20  a plain host, the address the internal view hands out
```

Resolution paths: `cli -> dnsi` answers `corp.internal` from its own zone. For
`onprem.corp`, `dnsi` forwards to `odns`. `odns` forwards `corp.internal` back to `dnsi`.

## Prove it on the wire

```bash
bash labs/day06/topo.sh up
ip netns exec va ping -c2 172.16.0.2                # across the overlay
ip netns exec cli dig +short app.corp.internal      # 10.6.10.20
```

### 1. The VXLAN frame

Shell 1:

```bash
ip netns exec va tcpdump -ni u0 -w /run/netlab/vx.pcap udp port 4789
```

Shell 2: `ip netns exec va ping -c2 -s 1000 172.16.0.2`, then stop tcpdump and decode:

```bash
tshark -r /run/netlab/vx.pcap -d udp.port==4789,vxlan -V -c 1
```

Read, top to bottom: outer Ethernet, outer IP `10.6.0.1 -> 10.6.0.2`, UDP destination
4789, `Virtual eXtensible Local Area Network` with `VXLAN Network Identifier (VNI): 100`,
then a complete inner Ethernet frame, inner IP `172.16.0.1 -> 172.16.0.2` and ICMP. The
outer IP packet is the inner IP packet plus 50 bytes: 20 + 8 + 8 of outer IP, UDP and
VXLAN, plus the inner 14-byte Ethernet header carried as payload.

### 2. ESP between va and vb

The key below is a lab placeholder. Never reuse it anywhere. Each direction needs its
own SPI: va sends with `0x1000`, vb sends with `0x1001`. Both sides hold both states.

```bash
# DEMO ONLY - obvious placeholder key material, never reuse.
K=0x$(printf 'a%.0s' {1..40})        # 20 bytes: 16-byte AES key + 4-byte GCM salt
for side in va vb; do
  ip netns exec $side ip xfrm state add src 10.6.0.1 dst 10.6.0.2 proto esp spi 0x1000 reqid 1 \
    mode transport aead 'rfc4106(gcm(aes))' $K 128
  ip netns exec $side ip xfrm state add src 10.6.0.2 dst 10.6.0.1 proto esp spi 0x1001 reqid 1 \
    mode transport aead 'rfc4106(gcm(aes))' $K 128
  ip netns exec $side ip xfrm policy add src 10.6.0.0/24 dst 10.6.0.0/24 dir out \
    tmpl proto esp mode transport reqid 1
  ip netns exec $side ip xfrm policy add src 10.6.0.0/24 dst 10.6.0.0/24 dir in \
    tmpl proto esp mode transport reqid 1
done
```

Capture and ping:

```bash
ip netns exec va tcpdump -ni u0 -w /run/netlab/esp.pcap esp &
ip netns exec va ping -c3 10.6.0.2
kill %1; tshark -r /run/netlab/esp.pcap -V -c 6
```

Look for `Encapsulating Security Payload`, `ESP SPI: 0x00001000`, a sequence number that
counts 1, 2, 3 for each SPI (six packets: three per direction), and then opaque bytes. There is no ICMP and no inner header you can
read. The policy covers the whole `10.6.0.0/24` pair, so the VXLAN overlay's UDP 4789
traffic between the VTEPs is encrypted too while it is in place. Remove everything:

```bash
for side in va vb; do ip netns exec $side ip xfrm policy flush; ip netns exec $side ip xfrm state flush; done
```

### 3. DNS without the internet

Ask each server only what it holds, with recursion off (`RD=0` means "answer from what
you hold, do not go and ask"):

```bash
ip netns exec cli dig +norecurse @10.6.10.53 app.corp.internal     # NOERROR 10.6.10.20 (its zone)
ip netns exec cli dig +norecurse @10.6.10.54 app.corp.internal     # NOERROR 203.0.113.20 (its zone)
ip netns exec cli dig +norecurse @10.6.10.53 db.onprem.corp        # REFUSED: would have to forward
ip netns exec cli dig +norecurse @10.6.10.54 db.onprem.corp        # NXDOMAIN: its empty onprem.corp zone
ip netns exec cli dig +norecurse @10.6.10.60 app.corp.internal     # REFUSED: would have to forward
ip netns exec cli dig +norecurse @10.6.10.60 db.onprem.corp        # NOERROR 192.168.20.5 (its zone)
ip netns exec cli dig            @10.6.10.53 db.onprem.corp        # NOERROR 192.168.20.5 (forwarded)
```

The first two are split horizon: one name, two answers, chosen by which server you
asked. The REFUSED lines are the lesson. `dnsi` knows the way to `db.onprem.corp` (a
`forward-zone`) but does not hold the data, so with recursion off it declines. With
recursion on, the last line shows it asking `odns`. A real `dig +trace` would walk
root, TLD and authoritative the same way, one non-recursive question at a time; this lab
has no root, so you do the walk by choosing the server yourself.

**TTL countdown.** `odns` forwards `corp.internal` to `dnsi` and caches what comes back.
Ask it three times, several seconds apart:

```bash
for i in 1 2 3; do ip netns exec cli dig +noall +answer @10.6.10.60 app.corp.internal; sleep 5; done
```

The first answer may already show less than 60: `topo.sh` primed `odns` with this name
when it polled. Later answers count down (for example 55, 50). When the TTL
reaches 0 the next query fetches a fresh copy. (Entries that unbound serves from its
own local-zone data, as `dnsi` does, are not cached and always show 60.)

**NXDOMAIN and negative caching.** Ask `odns` for a name that does not exist:

```bash
ip netns exec cli dig +noall +comments +authority @10.6.10.60 nope.corp.internal
```

The status is `NXDOMAIN` and the authority section carries the zone's SOA, which the lab
configs define with TTL 60 and minimum 30. The negative TTL is the smaller of the two,
30 seconds: a resolver may remember the absence that long. Repeat after a few seconds
and watch the SOA TTL in the cached reply fall.

**`ndots` and `search`.** `dig` can emulate the resolver library's behaviour. Capture
in a second shell: `ip netns exec cli tcpdump -ni eth0 udp port 53`. Then:

```bash
ip netns exec cli dig +search +domain=corp.internal +ndots=5 +showsearch +noall +comments app
ip netns exec cli dig +search +domain=corp.internal +ndots=1 +showsearch +noall +comments app.corp.internal
```

Name `app` has fewer than 5 dots, so the library tries the search suffix first. It
finds `app.corp.internal`. A name like `app.example.com` with `ndots=5` also gets
`app.example.com.corp.internal` tried first and fails before the real name is asked.
Now try a name with dots, which `ndots=5` still treats as relative:

```bash
ip netns exec cli dig +search +domain=corp.internal +ndots=5 +showsearch +time=1 +tries=1 +noall +comments app.example.com
```

`+showsearch` prints `app.example.com.corp.internal` first (NXDOMAIN), and only then
`app.example.com`. That one fails here because the lab has no route to a root server,
which is fine: you are counting queries. Count the queries in tcpdump for each form.

## The resolver mapping (Route 53 Resolver in a box)

```bash
ip netns exec cli dig db.onprem.corp                         # cli -> .53 -> .60
ip netns exec cli dig +noall +answer @10.6.10.60 app.corp.internal    # on-prem -> inbound
```

| AWS | In this lab |
|---|---|
| VPC +2 resolver | `dnsi` (10.6.10.53) |
| Private hosted zone | `local-zone: "corp.internal." static` + `local-data` in `dnsi` |
| Outbound endpoint + forwarding rule | `forward-zone: "onprem.corp."` in `dnsi`, pointing at `odns` |
| Inbound endpoint | the address `10.6.10.53` that `odns` forwards `corp.internal` to |
| On-prem DNS server | `odns` (10.6.10.60) |
| Public view of the same name | `dnsp` (10.6.10.54) |

## GWLB on the wire (`geneve.sh`)

`geneve.sh` calls `topo_down` first, so it replaces the Day 6 topology. Bring the main
topology back with `topo.sh up` afterwards.

```bash
bash labs/day06/geneve.sh up         # builds the lab and prints a ping that works
ip netns exec gwlb tcpdump -ni u0 -w /run/netlab/gnv.pcap udp port 6081 &
ip netns exec src ping -c3 10.62.0.10
kill %1; tshark -r /run/netlab/gnv.pcap -V -c 2
bash labs/day06/geneve.sh down
```

The capture shows outer IP `10.60.0.1 <-> 10.60.0.2`, UDP destination 6081, Geneve with
VNI 1, and an inner packet `10.61.0.10 -> 10.62.0.10` that is **unchanged**: same
source, same destination, same payload. The packet appears twice per direction, once
going to the appliance and once coming back. A real GWLB keeps the original addresses,
adds GENEVE, and pins a flow to one appliance by its 5-tuple. Here `gwlb` uses policy
routing (`ip rule iif s0 lookup 100`) to send everything from `src` or `dst` into
`gnv0`, and `appl` hairpins it back with a route for `10.0.0.0/8` via `gnv0`.

## Break it, diagnose it, fix it

```bash
bash labs/day06/topo.sh up
bash labs/day06/break.sh
bash labs/day06/verify.sh          # exit 1
```

Write the evidence chain in `journal.md` before you open `SOLUTION.md`. Run
`bash labs/day06/verify.sh` after each fix; it reports each check on its own line.
