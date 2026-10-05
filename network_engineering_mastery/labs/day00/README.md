# Day 0 lab — home, ISP, Internet

## At a glance

- **Runs in:** `netlab` (see `labs/netlab/README.md`), from `/course`.
- **Commands:** `bash labs/day00/topo.sh up`, the Prove walkthrough below,
  `bash labs/day00/break.sh`, `bash labs/day00/verify.sh`, `bash labs/day00/topo.sh down`.
- **Time:** about 1 h (35 m guided proof, 15 m break and diagnose, 10 m verify and journal).
- **Success signal:** `curl http://www.example.test:8080/` from the laptop returns 200,
  the server's log shows the client as `198.51.100.1` (not the laptop), and `verify.sh`
  prints `PASS: day 00 is healthy.` after you fix the two faults.

## Topology

```
 lap ---- hr ---------- isp ---------- transit ---------- srv
      lan0   wan0   cust0   up0     down0   srv0      eth0
 192.168.1.x  100.64.0.0/30  198.51.100.0/30    203.0.113.0/24
 (DHCP)  .1  .2   .1  .2    .1  .2          .1     .10
```

| Namespace | Plays | What it does |
|---|---|---|
| `lap` | the laptop | gets its address by DHCP, uses `192.168.1.1` for DNS |
| `hr` | the home router box | router, NAT (masquerade out `wan0`), DHCP server, DNS forwarder (one `dnsmasq`) |
| `isp` | the access ISP edge | routes to the Internet, carrier-grade NAT for `100.64.0.0/10` out `up0` |
| `transit` | the upstream provider | forwards between the ISP and the server's network; has no route to `100.64.0.0/10` or `192.168.0.0/16`, like the real Internet |
| `srv` | a web server | `python3 -m http.server 8080`, log in `/run/netlab/web.log` |

`dnsmasq` in `hr` answers DHCP on `lan0` (pool `192.168.1.100`-`150`, 12 h lease, router
and DNS option both `192.168.1.1`) and DNS on port 53 (`www.example.test` is
`203.0.113.10`). `topo.sh up` starts it, then runs `dhcpcd` in `lap` (with
`-o domain_name_servers`, so it asks for option 6) and fails loudly if no lease arrives.
The laptop's `/etc/resolv.conf` (`/etc/netns/lap/resolv.conf`) is written by `dhcpcd`
from that option: the DNS server comes from DHCP, not from configuration.

`198.51.100.0/24` and `203.0.113.0/24` are RFC 5737 documentation ranges, standing in for
public Internet space.

## Prove it on the wire

Open two or three shells in `netlab`: `docker compose -p netlab exec netlab bash`.

```bash
bash labs/day00/topo.sh up
ip netns exec lap curl -s http://www.example.test:8080/     # prints: hello from the server
```

### 1. DHCP: DORA

Release the lease and take a new one while a capture runs.

Shell 1:

```bash
ip netns exec lap tcpdump -vni eth0 'udp port 67 or udp port 68'
```

Shell 2:

```bash
ip -n lap addr flush dev eth0
rm -rf /var/lib/dhcpcd/*          # forget the stored lease so dhcpcd starts with a Discover
ip netns exec lap timeout 15 dhcpcd -4 -1 -L -B --nobackground -f /dev/null -o domain_name_servers eth0
cat /run/netlab/leases
cat /etc/netns/lap/resolv.conf
```

Four packets. Name each:

1. `0.0.0.0.68 > 255.255.255.255.67`, `BOOTP/DHCP, Request`, DHCP-Message `Discover`.
   The client has no address (source `0.0.0.0`) and does not know the server (broadcast
   destination), and the Ethernet destination is `ff:ff:ff:ff:ff:ff`.
2. `192.168.1.1.67 > 192.168.1.1xx.68` (or broadcast; your lease, for example 192.168.1.131, will differ), `BOOTP/DHCP, Reply`, `Offer`.
   The server proposes an address.
3. The client's `Request` for that address, again from `0.0.0.0` to the broadcast.
4. The server's `Reply`, DHCP-Message `ACK`.

tcpdump prints `Request` and `Reply` for the BOOTP op field, and `-v` adds
`DHCP-Message (53), length 1: Discover` (then `Offer`, `Request`, `ACK`). In the Offer and
the ACK find `Server-ID (54)` `192.168.1.1`, `Subnet-Mask (1)` `255.255.255.0`,
`Default-Gateway (3)` `192.168.1.1` (the router option), `Domain-Name-Server (6)`
`192.168.1.1` and `Lease-Time (51)` `43200` (12 h). The client's own Discover lists what it
wants in its parameter request list: `Subnet-Mask (1)`, `Default-Gateway (3)`,
`Domain-Name-Server (6)`, `BR (28)`, `Static-Route (33)`, `Lease-Time (51)`, `RN (58)`,
`RB (59)` (broadcast address, static routes, and the T1 and T2 timers). The laptop only
gets a DNS server because it asked for option 6.
`cat /run/netlab/leases` shows one line: expiry time, the laptop's MAC, the address.
`resolv.conf` now holds `nameserver 192.168.1.1`, written from option 6. Then `ip -n lap -4 addr` shows the address marked `dynamic` with a finite lifetime, and
`ip -n lap route` shows `default via 192.168.1.1 ... proto dhcp`. The router option in
the Offer became that route.

### 2. Read the routing tables

```bash
ip -n lap route
ip -n lap route get 203.0.113.10
ip -n hr  route
ip -n hr  route get 203.0.113.10
ip -n isp route
ip -n isp route get 203.0.113.10
ip -n transit route
ip -n transit route get 203.0.113.10
ip -n transit route get 100.64.0.2
```

For each, say in one sentence where that box sends the packet, and why. The laptop has a
connected route (`192.168.1.0/24 dev eth0`) and a default route via the home router. The
home router has two connected routes and a default via `100.64.0.1`. The ISP edge has a
default toward transit and a connected route to the customer. Transit has only connected
routes: for `203.0.113.10` the answer is `dev srv0`, and for `100.64.0.2` the lookup
fails with `Network is unreachable`. That last line is why fault B breaks the lab: the server answers, and the reply has no route back.

### 3. Traceroute: name the hops

```bash
ip netns exec lap traceroute -n 203.0.113.10
```

Four lines. Hop 1 is `192.168.1.1`, the home router. Hop 2 is `100.64.0.1`, the ISP
edge. Hop 3 is `198.51.100.2`, the transit provider. Hop 4 is `203.0.113.10`, the
server. The ISP edge replies from its customer-facing address, and the transit hop
replies from its ISP-facing address: each router answers from the interface the probe
entered.

### 4. The source address is rewritten twice

Four captures at once is the clearest picture. Use three shells, one per capture, and a
fourth to make requests.

```bash
ip netns exec hr      tcpdump -ni lan0  -c 3 'tcp port 8080'     # shell 1: before the home NAT
ip netns exec hr      tcpdump -ni wan0  -c 3 'tcp port 8080'     # shell 2: after the home NAT
ip netns exec transit tcpdump -ni srv0  -c 3 'tcp port 8080'     # shell 3: after the ISP NAT
ip netns exec lap curl -s -o /dev/null http://www.example.test:8080/   # shell 4
```

Read the SYN line in each: `192.168.1.1xx.<port> > 203.0.113.10.8080` on `lan0` (your lease, for example 192.168.1.131), then
`100.64.0.2.<port2> > 203.0.113.10.8080` on `wan0`, then
`198.51.100.1.<port3> > 203.0.113.10.8080` on `srv0`. The destination never changes. The
source address changes at the home router and again at the ISP, and the source port may
change too. The web server's log agrees: `tail -n 1 /run/netlab/web.log` starts with
`198.51.100.1`. Check the translation tables: `ip netns exec hr conntrack -L` and
`ip netns exec isp conntrack -L`, each with the original and the reply tuple.

### 5. The layer map

Capture one request frame with the link header:

```bash
ip netns exec hr tcpdump -nei lan0 -c 1 -vv 'tcp port 8080 and tcp[tcpflags] & tcp-syn != 0'
```

Write the headers outermost first and label each: Ethernet II (source and destination MAC,
type `0x0800`): layer 2 in OSI, the link layer in TCP/IP. IPv4 (source, destination, TTL,
protocol 6): OSI layer 3, TCP/IP internet layer. TCP (ports, flags, options): layer 4,
transport layer. Then run the same capture without `tcp-syn` on a full request and find
the HTTP text with `-A`: layers 5 to 7 in OSI are all this one application payload in
TCP/IP. Name the device that reads each header: the switch (or `hr`'s LAN side) reads
the Ethernet, the router the IP, NAT and the firewall the TCP ports.

## Break and diagnose

```bash
bash labs/day00/break.sh
```

Write the evidence chain in `journal.md` before you fix anything. Then, `SOLUTION.md`.
Run `bash labs/day00/verify.sh` after each fix: it reports every check on its own line.

## Journal

End with the sentence: "My laptop's address, as the server sees it, is ___ because ___."
Teardown: `labs/day00/teardown.md`.
