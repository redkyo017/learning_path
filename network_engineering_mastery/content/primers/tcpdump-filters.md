# tcpdump and tshark primer

Every capture command the labs use, grouped by day, then the filter language behind them.
All commands run inside the `netlab` container. Lab devices live in network namespaces,
so you capture with `ip netns exec NAME tcpdump ...`.

## Per-day recipes

These are the commands as the labs print them. The comment says what you look for.

**Day 1: frames and VLANs**

```bash
ip netns exec h1 tcpdump -eni eth0 -c 4 arp                # who-has / is-at, MACs with -e
ip netns exec h3 tcpdump -eni eth0 -c 2 arp                # run it, then ping h2: does the ARP reach this host?
ip netns exec sw tcpdump -eni br0 -c 4                     # the bridge device while h3 pings h2
ip netns exec h1 tcpdump -eni eth0 arp or icmp             # is there an ARP request for the next hop?
ip netns exec sw tcpdump -eni p2 -c 4 vlan                 # the tagged side: "vlan 20" in the line
```

**Day 2: addressing, ICMP, NDP**

```bash
ip netns exec h1 tcpdump -ni eth0 -vvx -c1 icmp            # hex of one IPv4 header: 4500 0054 ...
ip netns exec h1 tcpdump -ni eth0 -v 'icmp6 and (ip6[40] == 135 or ip6[40] == 136)'   # NS and NA
ip netns exec h1 tcpdump -vni eth0 'icmp or udp'           # traceroute: UDP probes, ICMP time exceeded
ip netns exec r2 tcpdump -ni eth2 -c8 'tcp port 8080'      # h2 side: is the SYN arriving?
ip netns exec r2 tcpdump -ni eth1 -c8 'tcp port 8080 or icmp'   # r1 side of the failing path
```

**Day 3: TCP**

```bash
ip netns exec s1 tcpdump -ni eth0 -S tcp port 8080         # handshake with absolute sequence numbers
ip netns exec s1 tcpdump -ni eth0 tcp                      # all TCP in the server namespace
ip netns exec c1 tcpdump -ni eth0 'tcp[tcpflags] & tcp-rst != 0'   # only resets
ip netns exec c1 tcpdump -ni eth0 'udp or icmp' &          # UDP and the ICMP port unreachable
```

**Day 4: firewall and NAT**

```bash
ip netns exec fw  tcpdump -ni eth2 tcp port 8080           # one SYN out, no SYN-ACK in: dropped
ip netns exec ext tcpdump -ni eth0 tcp port 8080           # the translated source arrives here
```

**Day 5: BGP**

```bash
ip netns exec r1 tcpdump -ni eth1 tcp port 179             # session establishment
ip netns exec r1 tcpdump -ni eth1 -w /tmp/bgp.pcap tcp port 179   # save OPEN, KEEPALIVE, UPDATE
tshark -r /tmp/bgp.pcap -V -Y bgp | /usr/bin/grep -E 'Type:|AS number|Hold|Identifier|AS_PATH|NEXT_HOP|NLRI|ORIGIN|MULTI|Prefix'
```

**Day 6: tunnels and DNS**

```bash
ip netns exec va tcpdump -ni u0 -w /run/netlab/vx.pcap udp port 4789   # VXLAN
tshark -r /run/netlab/vx.pcap -d udp.port==4789,vxlan -V -c 1
ip netns exec va tcpdump -ni u0 -w /run/netlab/esp.pcap esp &          # ESP
kill %1; tshark -r /run/netlab/esp.pcap -V -c 6
ip netns exec gwlb tcpdump -ni u0 -w /run/netlab/gnv.pcap udp port 6081 &   # GENEVE
kill %1; tshark -r /run/netlab/gnv.pcap -V -c 2
ip netns exec cli tcpdump -ni eth0 udp port 53             # DNS queries, count them for ndots
```

**Day 7: the three-point capture**

```bash
ip netns exec task tcpdump -ni eth0 -e -w /run/netlab/task.pcap 'tcp port 8080' &
ip netns exec tgw  tcpdump -ni wan  -e -w /run/netlab/wan.pcap  'ip proto 47'   &
ip netns exec onp  tcpdump -ni lan  -e -w /run/netlab/lan.pcap  'tcp port 8080' &
sleep 1; pkill tcpdump
tcpdump -nver /run/netlab/task.pcap -c 6
tcpdump -nver /run/netlab/wan.pcap  -c 6
tcpdump -nver /run/netlab/lan.pcap  -c 6
```

## BPF primitives

A capture filter runs in the kernel, before tcpdump sees the packet. Combine primitives
with `and`, `or`, `not` and parentheses (quote the whole filter so the shell leaves the
brackets alone).

| Primitive | Matches | Example |
|---|---|---|
| `host A` | source or destination is A. `src host` / `dst host` narrow it | `host 10.1.0.2` |
| `net N/len` | source or destination inside the prefix | `net 10.6.0.0/16` |
| `port P` | TCP or UDP port P on either side. `tcp port`, `udp port`, `portrange` | `tcp port 8080` |
| `tcp[tcpflags]` | the TCP flag byte; test with the named masks | `'tcp[tcpflags] & tcp-rst != 0'` |
| `icmp[icmptype]` | the ICMP type byte | `'icmp[icmptype] == icmp-echo'` |
| `vlan` | frames with an 802.1Q tag. `vlan 20` matches one VID | `vlan 20` |
| `udp port 4789` | VXLAN (6081 for GENEVE) | `udp port 4789` |
| `esp` | IPsec ESP (IP protocol 50) | `esp` |
| `ip proto 47` | GRE. The underlay has no ports for it | `ip proto 47` |
| `arp` | ARP frames | `arp` |
| `icmp6` | ICMPv6. Offsets such as `ip6[40]` read the first byte after the IPv6 header | `icmp6` |

Flag masks: `tcp-syn`, `tcp-ack`, `tcp-fin`, `tcp-rst`, `tcp-push`. A new connection attempt
is `'tcp[tcpflags] & (tcp-syn|tcp-ack) == tcp-syn'`, a SYN without an ACK.

Three traps:

- `vlan` shifts the offsets of the filter that follows it, and a capture on an access
  port or a Linux bridge may show frames already untagged. See Day 1.
- `tcp port N` does not match later IP fragments, since only the first fragment has the
  TCP header (Day 2).
- IPv6 extension headers move the L4 header, so `ip6[40]` is only the next header when
  there are none.

## Output and capture options

| Option | Effect |
|---|---|
| `-i IF` | interface. `-i any` mixes all interfaces and fakes the link header |
| `-n` | no name or port resolution: addresses stay numbers, and no DNS queries pollute the trace |
| `-e` | print the link header: MACs, EtherType, VLAN tag, frame length |
| `-v`, `-vv`, `-vvv` | more IP detail: TTL, id, flags, checksums, total length |
| `-S` | absolute TCP sequence numbers instead of relative |
| `-x`, `-xx`, `-X` | hex dump of the packet (`-xx` includes the link header, `-X` adds ASCII) |
| `-c N` | stop after N packets |
| `-w FILE` | write raw packets to a pcap, without decoding |
| `-r FILE` | read a pcap, and apply decode options and a filter to it |
| `-s 0` | capture whole packets (the default is already 262144 bytes on modern builds) |

Build habits, not memorized commands: use `-n` always, `-e` when the question is L2, `-S`
when comparing with another capture, `-w` when you need `tshark` later.

## tshark display filters

BPF filters at capture time; display filters select after decoding, with a different
syntax. Use `-f` for a capture filter and `-Y` for a display filter.

| BPF | tshark display filter |
|---|---|
| `host 10.1.0.2` | `ip.addr == 10.1.0.2` |
| `tcp port 8080` | `tcp.port == 8080` |
| `udp port 53` | `udp.port == 53` or `dns` |
| `tcp[tcpflags] & tcp-rst != 0` | `tcp.flags.reset == 1` |
| SYN without ACK | `tcp.flags.syn == 1 && tcp.flags.ack == 0` |
| `icmp[icmptype] == icmp-echo` | `icmp.type == 8` |
| `arp` | `arp` or `arp.opcode == 1` |
| `vlan 20` | `vlan.id == 20` |
| `udp port 4789` | `vxlan` (add `-d udp.port==4789,vxlan` for other ports) |
| `udp port 6081` | `geneve` |
| `esp` | `esp` (SPI: `esp.spi`) |
| `ip proto 47` | `gre` |
| `tcp port 179` | `bgp` (or `bgp.type == 2` for UPDATE) |
| ICMPv6 NS / NA | `icmpv6.type == 135 \|\| icmpv6.type == 136` |

Useful flags: `-V` for the full decode, `-c N` for a limit, `-T fields -e ip.src -e ip.dst`
for a table, and `-d` to decode a non-standard port.

## Reading a three-point capture

Day 7 captures one flow at the source (`task`), in the middle (`wan`) and at the
destination (`lan`). Reading one flow across three files is a method:

1. **Pick one packet and follow it.** Use the first SYN. Note source and destination IP,
   ports, TTL and IP id at the first point.
2. **Compare the same packet at the next point.** The id and the ports stay unless NAT
   rewrote them, TTL drops by one per router, MACs change at every L3 hop, and a tunnel
   hides the inner packet in a new outer header.
3. **Find where it stops.** The last point that has the packet is before the fault, and
   the first that lacks it is after. If a SYN appears at `task` and `wan` but not at
   `lan`, the loss is between them.
4. **Check the reverse path separately.** The SYN-ACK is a different packet with its
   own path. It can die on a different box, such as a stateful firewall that never saw the SYN.
5. **Look at sizes.** A packet that gets bigger by 24 (GRE) or 50 (VXLAN, GENEVE) bytes at the
   tunnel is expected. A data packet that vanishes at that point while small ones pass
   is the MTU black hole from Day 2 and Day 6.
6. **Write down what each point proves.** Silence at a point means "not seen here",
   never "not sent". Check the filter and the interface first.

Compare timestamps across the files only as relative values: the namespaces share one
kernel clock here, but a real capture from three hosts does not.
