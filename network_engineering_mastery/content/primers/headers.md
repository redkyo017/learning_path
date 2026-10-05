# Header primer

Bit layouts for every header the course makes you read. Rows are 32 bits wide, as in the
RFCs, except Ethernet and ARP where the natural unit is the byte. Each diagram is followed
by a "debug fields" list: field, what it tells you, and where you saw it (`dayNN`).

Read a capture from the outside in: Ethernet, then IP, then the transport header, then
the payload. Most faults show up in the first header that looks wrong.

## Ethernet II

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+---------------------------------------------------------------+
|                 destination MAC (6 bytes)                     |
+-------------------------------+-------------------------------+
|                               |  source MAC (6 bytes)         |
+-------------------------------+                               |
|                                                               |
+-------------------------------+-------------------------------+
|        EtherType (2)          |  payload (46-1500 bytes) ...  |
+-------------------------------+-------------------------------+
|                         FCS (4 bytes)                         |
+---------------------------------------------------------------+
```

Header is 14 bytes. The preamble and start delimiter come before it, and the FCS after
the payload. The NIC adds and checks both, so `tcpdump` normally never shows them. Frames
shorter than 64 bytes (header + payload + FCS) are padded.

Debug fields:

- **dst MAC** -> who the frame is for. `ff:ff:ff:ff:ff:ff` is broadcast, bit 0 of the
  first byte set means multicast. A unicast MAC the bridge has not learned is flooded.
  See `day01`.
- **src MAC** -> the sender; the bridge learns it into the forwarding database. Bit 1
  of the first byte is the locally administered (U/L) bit. See `day01`.
- **EtherType** -> what follows: `0x0800` IPv4, `0x0806` ARP, `0x86dd` IPv6, `0x8100`
  an 802.1Q tag, `0x88a8` an outer (QinQ) tag. See `day01`, `tcpdump -e`.
- **length on the wire** -> 14 + payload (+4 FCS). A 42-byte ARP frame in `tcpdump`
  is 64 on the wire after padding and FCS. See `day01` exercise 8.

## 802.1Q VLAN tag

The tag sits between the source MAC and the real EtherType. It adds 4 bytes.

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-------------------------------+-------------------------------+
|  TPID = 0x8100 (16)           | PCP(3)|D|      VID (12)       |
+-------------------------------+-------+-+---------------------+
|  inner EtherType (16) ...                                     |
+---------------------------------------------------------------+
```

Debug fields:

- **TPID** -> `0x8100` marks a tagged frame. If you see `0x8100` where you expected IP,
  the port is tagged and the capture point matters. See `day01`.
- **VID** -> the VLAN, 1-4094. The wrong VID on a trunk is the "nothing appears"
  failure. `tcpdump -e vlan` shows it as `vlan 20`. See `day01` lab step 4.
- **PCP** -> priority, 0-7. Rarely set in the lab, shown by `tcpdump -e`. See `day01`.
- **DEI** -> drop eligible. Almost always 0. See `day01`.

## ARP (IPv4 over Ethernet)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-------------------------------+-------------------------------+
|  hardware type (1 = Eth)      |  protocol type (0x0800)       |
+---------------+---------------+-------------------------------+
| hlen (6)      | plen (4)      |  operation (1 req, 2 reply)   |
+---------------+---------------+-------------------------------+
|  sender MAC (6 bytes) ...                                     |
+-------------------------------+-------------------------------+
|  ... sender MAC               |  sender IP (4 bytes) ...      |
+-------------------------------+-------------------------------+
|  ... sender IP                |  target MAC (6 bytes) ...     |
+-------------------------------+-------------------------------+
|  ... target MAC (zeros in a request)                          |
+---------------------------------------------------------------+
|  target IP (4 bytes)                                          |
+---------------------------------------------------------------+
```

The ARP payload is 28 bytes, so the frame is 14 + 28 = 42 bytes before padding.

Debug fields:

- **operation** -> 1 is `who-has`, 2 is `is-at`. A request with no reply means the
  target is absent, on another VLAN, or filtered. See `day01`.
- **sender IP = target IP** -> a gratuitous ARP. It refreshes neighbours after a
  failover. See `day01`.
- **target MAC** -> all zeros in a request; `tcpdump` hides it. See `day01`.
- **Ethernet dst** -> broadcast for requests, unicast for replies. See `day01`.

## IPv4

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-------+-------+---------------+-------------------------------+
|Version|  IHL  |  DSCP / ECN   |        Total Length           |
+-------+-------+---------------+-----+-------------------------+
|        Identification         |Flags|    Fragment Offset      |
+---------------+---------------+-----+-------------------------+
|     TTL       |   Protocol    |       Header Checksum         |
+---------------+---------------+-------------------------------+
|                       Source Address                          |
+---------------------------------------------------------------+
|                     Destination Address                       |
+---------------------------------------------------------------+
|                    Options (if IHL > 5)                       |
+---------------------------------------------------------------+
```

Flags: bit 0 reserved, bit 1 DF (do not fragment), bit 2 MF (more fragments). With IHL 5
the header is 20 bytes. `4500 0054` at the start of a dump decodes as version 4, IHL 5,
DSCP 0, total length 0x54 = 84 (a 56-byte ping payload + 8 ICMP + 20 IP).

Debug fields:

- **TTL** -> decremented per router. 0 produces ICMP Time Exceeded; `traceroute` is
  built on it. See `day02`.
- **Protocol** -> 1 ICMP, 6 TCP, 17 UDP, 47 GRE, 50 ESP. A tunnel shows up here. See
  `day02`, `day06`.
- **Total Length** -> compare with the interface MTU. See `day02`.
- **DF** -> set means "drop and tell me, do not fragment". The PMTUD trigger and the
  black-hole ingredient. See `day02`.
- **MF and Fragment Offset** -> non-zero means the packet is a fragment; only the
  first fragment carries the L4 header, so port filters miss the rest. See `day02`.
- **Header Checksum** -> recomputed at every hop because TTL changes. Checksum errors
  on a capture of your own host are usually offload, not corruption. See `day03`.
- **Source / Destination** -> what NAT rewrites. Compare the same packet at two
  capture points. See `day04`, `day07`.

## IPv6

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-------+---------------+---------------------------------------+
|Version| Traffic Class |              Flow Label               |
+-------+---------------+-------+---------------+---------------+
|        Payload Length         |  Next Header  |   Hop Limit   |
+-------------------------------+---------------+---------------+
|                                                               |
+                    Source Address (128 bits)                  +
|                                                               |
+                                                               +
|                                                               |
+---------------------------------------------------------------+
|                                                               |
+                  Destination Address (128 bits)               +
|                                                               |
+                                                               +
|                                                               |
+---------------------------------------------------------------+
```

The header is a fixed 40 bytes. There is no checksum and no fragmentation field in it;
fragmentation, if used, is an extension header and only the source may fragment.

Debug fields:

- **Next Header** -> 6 TCP, 17 UDP, 58 ICMPv6, 44 fragment, 0 hop-by-hop. A filter
  such as `ip6[40]` reads the first byte after the fixed header, which is only the
  upper-layer header when there are no extension headers. See `day02`.
- **Hop Limit** -> the TTL equivalent. NDP packets use 255 so you can tell they never
  crossed a router. See `day02`.
- **Payload Length** -> bytes after the 40-byte header, extension headers included.
  See `day02`.
- **Addresses** -> `fe80::/10` link-local, `fd00::/8` ULA, `ff02::/16` link-scope
  multicast. See `day02`.

## ICMP (v4)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+---------------+---------------+-------------------------------+
|     Type      |     Code      |           Checksum            |
+---------------+---------------+-------------------------------+
|        Identifier (echo)      |       Sequence (echo)         |
+-------------------------------+-------------------------------+
|   data (echo) / original IP header + 8 bytes (errors)         |
+---------------------------------------------------------------+
```

For "fragmentation needed" the second word is unused (16 bits) followed by the
next-hop MTU (16 bits).

Debug fields:

- **Type/Code** -> 8/0 echo request, 0/0 echo reply, 3/3 port unreachable, 3/4
  fragmentation needed and DF set, 11/0 TTL exceeded. See `day02`, `day03`.
- **Next-hop MTU** -> in a 3/4 message; this is what PMTUD learns. See `day02`.
- **Quoted original header** -> the error carries the offending IP header plus 8
  bytes; read it to learn which flow caused the error. See `day02`, `day03`.
- **Sequence** -> gaps in echo replies mean loss. See `day02`.

## ICMPv6 neighbour solicitation and advertisement

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+---------------+---------------+-------------------------------+
| Type 135 (NS) | Code 0        |           Checksum            |
| or 136 (NA)   |               |                               |
+---------------+---------------+-------------------------------+
| NS: reserved (32)  /  NA: R,S,O flags + reserved (32)         |
+---------------------------------------------------------------+
|                                                               |
+                  Target Address (128 bits)                    +
|                                                               |
+                                                               +
|                                                               |
+---------------------------------------------------------------+
| Option: type 1 (source LL addr, NS) or 2 (target LL addr, NA) |
|         length 1, then 6-byte MAC                             |
+---------------------------------------------------------------+
```

Debug fields:

- **Type** -> 135 NS, 136 NA. 133 RS and 134 RA are the router pair. The lab filter is
  `icmp6 and (ip6[40] == 135 or ip6[40] == 136)`. See `day02`.
- **Target Address** -> the address whose MAC is asked for. See `day02`.
- **Link-layer address option** -> the MAC, the IPv6 equivalent of ARP's sender and
  target MAC. See `day02`.
- **IPv6 destination** -> for an NS, the solicited-node multicast `ff02::1:ffXX:XXXX`,
  built from the last 24 bits of the target. See `day02`.
- **Hop Limit 255** -> if lower, the message was routed and must be dropped. See `day02`.
- **Flags S, O** -> S set in a reply to a unicast NS, O means override the cache. See
  `day02`.

## TCP

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-------------------------------+-------------------------------+
|          Source Port          |       Destination Port        |
+-------------------------------+-------------------------------+
|                        Sequence Number                        |
+---------------------------------------------------------------+
|                    Acknowledgment Number                      |
+-------+-----+-+-+-+-+-+-+-+-+-+-------------------------------+
| Offset| Rsv |N|C|E|U|A|P|R|S|F|            Window             |
|       |     |S|W|C|R|C|S|S|Y|I|                               |
+-------+-----+-+-+-+-+-+-+-+-+-+-------------------------------+
|           Checksum            |        Urgent Pointer         |
+-------------------------------+-------------------------------+
|                    Options (if Offset > 5)                    |
+---------------------------------------------------------------+
```

The data offset is in 32-bit words: 5 is a 20-byte header. Options on a SYN usually add
MSS, SACK permitted, timestamps and window scale.

Debug fields:

- **Ports** -> the 5-tuple with the IPs and protocol. NAT and conntrack key on it.
  See `day03`, `day04`.
- **Sequence / Acknowledgment** -> `tcpdump -S` prints absolute values; the default is
  relative to the first packet seen. Use them to spot retransmissions. See `day03`.
- **Flags** -> SYN, SYN-ACK, ACK, FIN, RST. `tcp[tcpflags] & tcp-rst != 0` finds
  resets. A SYN with no SYN-ACK is a drop; a SYN answered by RST is a closed port. See
  `day03`, `day04`.
- **Window and window scale** -> flow control. A shrinking advertised window means the
  receiver is slow. See `day03`.
- **MSS option** -> on the SYN only; this is what a clamp rewrites. See `day02`, `day07`.
- **SACK permitted, timestamps** -> negotiated on the SYN, fixed for the connection.
  See `day03`.

## UDP

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-------------------------------+-------------------------------+
|          Source Port          |       Destination Port        |
+-------------------------------+-------------------------------+
|            Length             |           Checksum            |
+-------------------------------+-------------------------------+
```

Debug fields:

- **Destination port** -> 53 DNS, 4789 VXLAN, 6081 GENEVE, 500 and 4500 IKE. See
  `day03`, `day06`.
- **Length** -> 8 + payload. DNS over 512 bytes without EDNS0 sets TC. See `day06`.
- **Source port** -> a tunnel's outer source port is a hash of the inner flow, so ECMP
  can spread the tunnel. See `day06`.
- **No handshake** -> a UDP datagram to a closed port is answered by ICMP 3/3.
  See `day03`.

## GRE

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-----------------+-----+-------------------------------+
|C| |K|S|    Reserved0    | Ver |         Protocol Type         |
+-------------------------------+-------------------------------+
|      Checksum (optional)      |      Reserved1 (optional)     |
+---------------------------------------------------------------+
|                         Key (optional)                        |
+---------------------------------------------------------------+
|                   Sequence Number (optional)                  |
+---------------------------------------------------------------+
```

The base header is 4 bytes. The K and S bits and the Key and Sequence fields are RFC 2890 extensions to the base format in RFC 2784.
Carried in IP protocol 47, so the cost is outer IPv4 (20) plus GRE (4) = 24 bytes.

Debug fields:

- **Protocol Type** -> an EtherType for the inner payload: `0x0800` IPv4. See `day06`.
- **Outer IP protocol 47** -> the underlay sees only this; no ports to filter on, hence
  `ip proto 47`. See `day06`, `day07`.
- **Key / Sequence** -> present only when the K and S flags are set. See `day06`.
- **Overhead** -> 24 bytes, so a 1500 underlay carries a 1476 inner MTU. See `day06`.

## VXLAN

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-----------------------------------------------+
|R|R|R|R|I|R|R|R|                    Reserved                   |
+-----------------------------------------------+---------------+
|         VXLAN Network Identifier (VNI)        |    Reserved   |
+-----------------------------------------------+---------------+
```

What VXLAN adds to the inner IP packet is the inner Ethernet header (14) + outer IPv4
(20) + outer UDP (8, destination 4789) + VXLAN (8) = 50 bytes over IPv4. The underlay
also has its own Ethernet header, which the underlay MTU does not count.

Debug fields:

- **I flag** -> must be 1 for a valid VNI. See `day06`.
- **VNI** -> the 24-bit segment id, like a VLAN id with 16 million values. A mismatch
  between VTEPs drops the traffic silently. See `day06`.
- **Outer UDP destination 4789** -> `tshark` needs `-d udp.port==4789,vxlan` when
  the port is not the default decode. See `day06`.
- **Inner frame** -> a full Ethernet frame, so inner MACs differ from outer MACs. See
  `day06`.
- **Overhead 50** -> an inner 1500 needs a 1550 underlay, or the inner MTU drops to
  1450. See `day06`, `day07`.

## GENEVE

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+---+-----------+-+-+-----------+-------------------------------+
|Ver|  Opt Len  |O|C|    Rsvd   |         Protocol Type         |
+-----------------------------------------------+---------------+
|        Virtual Network Identifier (VNI)       |    Reserved   |
+---------------------------------------------------------------+
|               Variable-length options (TLVs) ...              |
+---------------------------------------------------------------+
```

The base header is 8 bytes. In UDP 6081 over IPv4 with an inner Ethernet frame the
overhead is inner Ethernet 14 + outer IPv4 20 + UDP 8 + GENEVE 8 = 50 bytes, plus any
options (Opt Len counts 4-byte words).

Debug fields:

- **Opt Len** -> how many option words follow. Overhead is 50 plus 4 x Opt Len. See `day06`.
- **Protocol Type** -> `0x6558` for an Ethernet inner frame. See `day06`.
- **VNI** -> as in VXLAN. See `day06`.
- **TLV options** -> metadata carried with the packet, such as the flow information a
  Gateway Load Balancer attaches. See `day06`.
- **Outer UDP 6081** -> the filter is `udp port 6081`. See `day06`.

## ESP (IPsec)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+---------------------------------------------------------------+
|           Security Parameters Index (SPI)                     |
+---------------------------------------------------------------+
|                     Sequence Number                           |
+---------------------------------------------------------------+
|        Payload (IV + encrypted data) ...                      |
+---------------------------------------------------------------+
|     Padding | Pad Length | Next Header | ICV (auth tag)       |
+---------------------------------------------------------------+
```

IP protocol 50, or inside UDP 4500 when NAT traversal is on (8 more bytes). The payload
is encrypted, so you see only the outer headers, the SPI and the sequence number.

Debug fields:

- **SPI** -> identifies the security association (SA). Each direction has its own.
  A new SPI after a rekey is normal. See `day06`.
- **Sequence Number** -> must increase; the replay window drops old numbers. See `day06`.
- **Outer protocol** -> 50 means plain ESP, UDP 4500 means NAT-T. See `day06`.
- **Length growth** -> tunnel mode adds a new outer IP header, the ESP header, IV,
  padding, trailer and ICV; this is the Exercise 1 MTU arithmetic. See `day06`.
- **Next Header** -> encrypted, so only the endpoint sees it (4 for IP-in-IP in tunnel
  mode).
