# Day 3 — L4: TCP and UDP

**Truth of the day:** the TCP header, plus the 11-state machine
**Budget:** 3 h — 1 h theory refresh, 1 h 30 m lab (guided proof, then break and
diagnose), 30 m exercises

**At a glance — how to work through this day:**
1. Read "Why this matters", then draw the header and the state machine from memory
   ("Draw it first"). Correct the drawing against the page.
2. Read "Core concepts".
3. Do the lab in `labs/day03/`: `topo.sh up`, the proof walkthrough, then `break.sh`,
   `journal.md`, `verify.sh`.
4. Read "Where AWS hides this", then do the exercises whenever you like.

## Why this matters

Someone reports: "our service gets intermittent `connection reset by peer` from a
backend behind an NLB, mostly after quiet periods." Nothing is down. The backend logs
show nothing. The first request after a pause fails, the retry works, and the pattern
disappears under load. Every word of the report is a clue, and none of them is in a
log. The clue is a RST, arriving on a connection that the client believed was open, and
the sender of the RST is not the backend.

You can only read that sentence if you know what TCP promises, which device holds the
state that makes the promise true, and what a RST and a silence each prove. This day
rebuilds that model: the header, the 11 states, the timers, and the difference between
being refused, being ignored and being reset. Then you reproduce the NLB incident in a
box with a 20 s idle timeout, so the fix comes from the capture instead of a guess.

## Draw it first

Before you read further, draw both from memory on a blank page: the TCP header with
field widths, and the state machine with its arrows. Then compare.

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-------------------------------+-------------------------------+
|        Source port (16)       |     Destination port (16)     |
+-------------------------------+-------------------------------+
|                      Sequence number (32)                     |
+---------------------------------------------------------------+
|                  Acknowledgment number (32)                   |
+-------+-------+-+-+-+-+-+-+-+-+-------------------------------+
| Data  |Rsvd   |C|E|U|A|P|R|S|F|         Window (16)           |
|offset |       |W|R|R|C|S|S|Y|I|                               |
|  (4)  |       |R|E|G|K|H|T|N|N|                               |
+-------+-------+-+-+-+-+-+-+-+-+-------------------------------+
|          Checksum (16)        |       Urgent pointer (16)     |
+-------------------------------+-------------------------------+
|              Options (0-40 bytes): MSS, SACK, wscale, TS      |
+---------------------------------------------------------------+
```

(`Rsvd` is reserved; the NS bit historically sat here, and RFC 9293 marks it reserved.)

The state machine. `->` is what you send, `<-` is what arrives.

```
                              CLOSED
         passive open: listen() |      | active open: connect(), -> SYN
                                v      v
                            LISTEN    SYN_SENT
               <- SYN, -> SYN+ACK |      | <- SYN+ACK, -> ACK
                                  v      |
                             SYN_RCVD    |
                       <- ACK    |       |
                                 v       v
                              ESTABLISHED
          active close:                      passive close:
          close(), -> FIN                    <- FIN, -> ACK
                 v                                  v
            FIN_WAIT_1                         CLOSE_WAIT
        <- ACK |     | <- FIN, -> ACK                | close(), -> FIN
               v     v  (simultaneous close)        v
        FIN_WAIT_2  CLOSING                      LAST_ACK
   <- FIN, -> ACK |     | <- ACK                      | <- ACK
                  v     v                             v
                 TIME_WAIT  -- 2 x MSL (60 s) -->  CLOSED
```

Count the states: CLOSED, LISTEN, SYN_SENT, SYN_RCVD, ESTABLISHED, FIN_WAIT_1,
FIN_WAIT_2, CLOSE_WAIT, CLOSING, LAST_ACK, TIME_WAIT. That is eleven.

## Core concepts

### The header, field by field

- **Ports (16 bits each).** With the two IP addresses and the protocol they form the
  4-tuple that names a connection (the "5-tuple" counts the protocol too). The server
  port is well known. The client port is chosen by the kernel from the **ephemeral**
  range, 32768–60999 by default on Linux (`net.ipv4.ip_local_port_range`).
- **Sequence and acknowledgment numbers (32 bits each).** Sequence numbers count
  **bytes**, not segments. The ACK number is the next byte the sender of the ACK
  expects, so it is the last byte received plus one.
- **Flags.** SYN and FIN each use up one sequence number. ACK is set on everything after
  the first SYN. RST aborts. PSH asks the receiver to hand data up now. ECE and CWR
  carry congestion marks.
- **Window (16 bits).** The receiver's free buffer. It is the "flow control" field.
- **Options, set on the SYN and fixed for the connection:**
  - **MSS**: the largest payload the sender will accept. 1460 on a 1500-byte MTU
    (1500 minus 20 IP and 20 TCP).
  - **SACK permitted**: the receiver can name the exact ranges it has, so the sender
    resends only the holes.
  - **Window scale**: a left-shift applied to the 16-bit window. `wscale 7` multiplies
    it by 128. Without it the window caps at 64 KB. Both SYNs must carry the option.
  - **Timestamps (TS)**: used for RTT measurement and to reject old duplicate segments.

### Sequence and acknowledgment arithmetic

The handshake is three segments. Take a client with initial sequence number (ISN) 1000
and a server with ISN 5000:

| # | Direction | Flags | seq | ack | Payload | Why |
|---|---|---|---|---|---|---|
| 1 | C → S | SYN | 1000 | - | 0 | The SYN uses sequence number 1000 |
| 2 | S → C | SYN, ACK | 5000 | 1001 | 0 | Next byte expected from C is 1001 |
| 3 | C → S | ACK | 1001 | 5001 | 0 | Next byte expected from S is 5001 |

Now the client sends a 100-byte request. It carries seq 1001 and covers bytes
1001–1100, so the server's ACK is 1101. The server answers with 200 bytes at seq 5001,
and the client's ACK is 5201. Every ACK number is the sender's seq plus the length of
the data (plus one for SYN or FIN). Exercise 1 makes you do a six-packet version.

### States, active close and TIME_WAIT

Look at the diagram. The side that sends the first FIN is the **active closer**. It goes
FIN_WAIT_1, FIN_WAIT_2 and ends in **TIME_WAIT**. The other side goes CLOSE_WAIT,
LAST_ACK, CLOSED. Two facts to keep:

- **TIME_WAIT lives on the active closer.** It lasts 2×MSL, which is 60 s on Linux
  (a constant, not a sysctl). Who closes first is a design choice with a cost.
  A client that closes first and opens many short connections pays in ports. A
  server that closes first pays in memory for sockets in TIME_WAIT.
- **Why TIME_WAIT exists.** First, if the final ACK is lost, the peer resends its FIN
  and the closer must still be there to re-ACK it. Second, it keeps old duplicate
  segments from a dead connection out of a new one that reuses the same 4-tuple. The
  quiet period is twice the longest time (MSL) a segment can live in the network.

A pile of sockets in **CLOSE_WAIT** is a different thing: the peer closed and your
application never called `close()`. That is an application bug, not a network event.

Because the 4-tuple names a connection, a client can reach one destination only with as
many parallel-plus-recent connections as it has ephemeral ports. The default range holds
28,232 ports. Exercise 3 turns that into a rate limit.

### Refused, ignored or reset

Read the error as a wire event first (the same worked example as `STRATEGY.md`):

| What you see | What it proves |
|---|---|
| SYN, then SYN-ACK | Open. A listener exists. |
| SYN, then **RST** from the host | Closed port. The host is alive and answered. Also what a firewall `reject` does. |
| SYN, SYN, SYN with 1 s, 2 s, 4 s gaps, then nothing | **Silence**: a filter that drops, a missing route on the way out or back, a black hole, or a dead host. |
| Established data flow, then an RST from an address you did not expect | A **middlebox** (load balancer, NAT, firewall) whose state for this flow is gone. |
| Established, then nothing at all, until your own timer fires | A **half-open** connection (below) or a dropped path. |

An RST also arrives when a peer aborts (`SO_LINGER` with a zero timeout) or the
application crashes with unread data. The question to ask is which address sent it,
and whether that address is the backend. Compare the source of the RST with the server
you meant, and with the TTL on the RST.

### Retransmission and congestion

TCP sends data, starts a timer, and retransmits when the timer fires (RTO). The RTO is
derived from the measured RTT, starts at 1 s for a SYN, and **doubles on each
retransmit** (back-off): 1 s, 2 s, 4 s, and so on. This is why a dropped SYN looks like
a connect that hangs for many seconds and only then fails. A faster signal exists:
**fast retransmit**. If the receiver sees a hole, it sends a duplicate ACK for every
segment after it. Three duplicate ACKs make the sender resend the missing segment
without waiting for the RTO.

Two windows limit the sender, and the smaller one wins:

- **Flow control** protects the receiver. The receiver advertises `rwnd`, its free
  buffer (scaled by `wscale`).
- **Congestion control** protects the network. The sender keeps its own `cwnd`:
  - **Slow start**: `cwnd` starts around 10 segments and doubles each round trip until
    it reaches `ssthresh` or loses a packet.
  - **Congestion avoidance**: past `ssthresh`, `cwnd` grows by about one segment per
    round trip (CUBIC grows it along a cubic curve in time since the last loss).
  - **On loss**: three duplicate ACKs cut `cwnd` (and `ssthresh`) and the sender
    recovers. An RTO timeout drops `cwnd` back to one segment and starts slow start again.

Linux uses **CUBIC** by default. **BBR** is the other one you will meet. It does not
treat loss as the signal. It estimates the path's bandwidth and minimum RTT and paces
to that. On a lossy link BBR holds throughput that loss-based CUBIC loses.

### Idle connections, keepalive and half-open

TCP has no heartbeat. A connection with no data sends no packets, and nothing in either
endpoint notices if the other end vanished. Two consequences:

- **Half-open**: one side crashes or loses its state with no FIN or RST. The surviving
  side stays ESTABLISHED indefinitely. It learns the truth only when it next sends,
  and the peer (or a device in the middle) answers with an RST.
- **Idle timeouts**: any stateful device (a firewall, a NAT, a load balancer) keeps a
  table entry per flow with a timer. Quiet longer than the timer, and the entry is
  deleted. The next packet from either side has no flow to match.

**TCP keepalive** is a zero-length ACK probe sent after an idle period. It exists in
the kernel and is **off by default**. The application enables it with `SO_KEEPALIVE`,
and the timing (`TCP_KEEPIDLE`, `TCP_KEEPINTVL`, `TCP_KEEPCNT`) defaults to 7200 s,
75 s and 9 probes. Probes refresh the middlebox timers, and a dead peer shows up as a
failed probe sequence. **Application-level keepalive** (a ping message, an HTTP/2 PING,
a pooled connection with a maximum idle age) does the same job one layer up, and works
across proxies that terminate TCP.

### UDP

```
 0      7 8     15 16    23 24    31
+--------+--------+--------+--------+
|   Source port   |  Dest. port     |
+--------+--------+--------+--------+
|     Length      |    Checksum     |
+--------+--------+--------+--------+
```

Eight bytes, then data. No handshake, no sequence numbers, no retransmission, no
flow control, no congestion control, no connection state in the endpoints. A datagram
is delivered whole or not at all. If you send to a port with no socket, the host
returns an **ICMP port unreachable** (type 3, code 3), and that ICMP message is the
only "refusal" UDP has. A firewall that drops it makes a closed UDP port look
exactly like an open one that has nothing to say. Stateful boxes still track UDP: a
conntrack entry is created for the 5-tuple and aged by a timer (120 s is a common
default for a flow with replies), because without one the replies could not find their way back.

## Prove it on the wire

The full walkthrough is in `labs/day03/README.md`. The lab builds three namespaces:
`c1` (client), `lb` (the NLB stand-in, with a VIP `10.3.9.100` on its loopback) and
`s1` (a `python3 -m http.server` on 8080). Here is what to capture, and what each line
must prove.

1. **A full connection.** `tcpdump -ni eth0 -S tcp port 8080` in s1 while c1 runs
   `curl`. Label every packet: handshake, request, response, FIN pair. The first `F`
   marks the active closer, and `ss -tan state time-wait` shows the TIME_WAIT socket on
   that host. For this server it is s1, which closes first with HTTP/1.0.
2. **The SYN options.** The SYN line shows `mss 1460,sackOK,TS val ... ecr 0,nop,wscale 7`.
   The ACK that follows does not repeat them: options are negotiated once.
3. **Loss.** Add `tc netem loss 10%` on s1 and compare `ss -ti` on the sender before and
   after: `cwnd` drops, `ssthresh` is set, `rto` and `retrans` rise. This is slow
   start and recovery on a real socket.
4. **UDP to a closed port.** One datagram out, one ICMP `udp port 9999 unreachable` back.
5. **Port exhaustion.** Shrink the ephemeral range to ten ports and run `client.py`.
   Ten connections work, then `[Errno 99] Cannot assign requested address`.
6. **The NLB idle timeout.** The capture is the whole incident: a client holds an idle
   connection through `lb`, waits 25 s (the lab timeout is 20 s), sends again and gets
   `ConnectionResetError`. The RST in the capture has the VIP as its source, not s1.
   Repeat with `SO_KEEPALIVE` and `TCP_KEEPIDLE=10`, and no RST appears.

## Lab

See `labs/day03/`. The goal: reproduce the idle-timeout reset, then diagnose three
independent faults (a silent drop, a lossy link, a source-NAT that hides the client)
from captures, before you read `SOLUTION.md`. Success signal:
`bash labs/day03/verify.sh` exits `0` and prints `PASS: day 03 is healthy.`

## Where AWS hides this

AWS networking is TCP/IP behind an API, and Day 3's rules show up as limits on each
managed device. Each line below is "X in AWS is Y on the wire".

- **The NLB idle timeout is a conntrack timer.** An NLB keeps per-flow state with a TCP
  idle timeout of 350 seconds <!-- fact-checked 2026-10-05 --> by default. The TCP value is configurable (60 to 6000 seconds); TLS listeners are fixed at 350 seconds,
  so check the listener's attribute before you assume it <!-- fact-checked 2026-10-05 -->.
  When a flow has been quiet longer than that, the NLB drops the entry. If either side
  then sends, the NLB answers with a **TCP RST** <!-- fact-checked 2026-10-05 -->. In your incident,
  that RST arrives with the load balancer's source address, and your client sees
  `connection reset by peer` on the first request after a pause. UDP flows have a
  separate, shorter idle timer (120 seconds, fixed and not configurable) <!-- fact-checked 2026-10-05 -->.
  The lab's `lb` namespace is that device at 20 s.
- **The ALB works the other way around.** It terminates the client's TCP and opens
  its own to the target, with an idle timeout of 60 seconds <!-- fact-checked 2026-10-05 --> on each
  side. The rule that follows: the backend's keep-alive timeout must be **longer** than
  the ALB's idle timeout. If the backend closes an idle connection first, the ALB may
  reuse a connection that the backend has already torn down and returns a 502.
- **NAT Gateway is a conntrack table with port arithmetic.** A NAT Gateway supports
  55,000 simultaneous connections to each unique destination (destination IP, port and
  protocol) <!-- fact-checked 2026-10-05 -->. When it runs out of source ports for one destination,
  the `ErrorPortAllocation` metric counts it and new connections fail. The cause is
  Exercise 3's arithmetic, one level up. A NAT Gateway also ages out an idle flow after
  350 seconds <!-- fact-checked 2026-10-05 -->, and it answers a later packet on it with an RST.
  That is the same incident as the NLB's, and the same fix.
- **Client IP preservation is a question of which device terminates TCP.** An NLB
  forwards the client's packets and, for instance targets, the backend sees the real
  client address <!-- fact-checked 2026-10-05 -->. A target registered by IP (by default), or any proxy or ALB, sees the load
  balancer instead: the real address travels in `X-Forwarded-For` (HTTP) or in a
  proxy protocol v2 header <!-- fact-checked 2026-10-05 --> that NLB can prepend to the stream. Fault C in the lab is
  the loss of that information, without a header to recover it.
- **Link to the depth.** Listener rules, target group health checks, cross-zone
  behaviour and the full list of attributes belong to
  [`../../aws_computing_loadbalancing_communication_components/`](../../aws_computing_loadbalancing_communication_components/).
  The AWS hands-on for NAT Gateway and the VPC constructs is in
  [`../../aws_network_components/`](../../aws_network_components/).

**Local emulation.** The `lb` namespace is the NLB. `nf_conntrack_tcp_loose=0` plus
`nf_conntrack_tcp_timeout_established=20` give it an expiring flow table, DNAT sends
VIP:80 to `s1:8080`, and an `input` rule resets any packet that reaches the VIP
un-NATed.

## Exercises

1. **Fill the numbers.** A client with ISN 7000 and a server with ISN 9000 exchange six
   packets: (1) SYN; (2) SYN-ACK; (3) the client's ACK; (4) the client sends a
   120-byte request; (5) the server's ACK of it; (6) the server sends 300 bytes. Give
   `seq` and `ack` for each. — **Hint:** SYN and FIN each consume one number, an ACK
   number is the next byte expected. — **Solution sketch:** (1) seq 7000; (2) seq 9000,
   ack 7001; (3) seq 7001, ack 9001; (4) seq 7001, ack 9001, len 120; (5) seq 9001,
   ack 7121; (6) seq 9001, ack 7121, len 300, and the client's next ACK is 9301.
2. **Classify five captures** as refused, filtered, reset by a middlebox, slow, or healthy.
   (a) `S` at 0 s, `R.` from the target at 0.0003 s. (b) `S` at 0, 1, 3 and 7 s, never
   an answer. (c) A request that worked, 30 s of quiet, then `R` from the VIP's address
   when the client sends. (d) `S` at 0 s, `S` at 1 s, `S.` at 1.004 s. (e) `S` at 0,
   `S.` at 0.0004 s, `.` at 0.0005 s. — **Hint:** ask what arrived, from which
   address, and when. — **Solution sketch:** (a) refused; (b) filtered or black hole;
   (c) reset by middlebox, the flow was aged out; (d) slow, the first SYN or its reply was
   lost and the retry took a second; (e) healthy.
3. **Port arithmetic.** A client opens 500 short connections per second to one backend
   IP and port and closes first. TIME_WAIT is 60 s. How long until it runs out of
   ephemeral ports (default range), and what rate can it sustain? — **Hint:** ports
   in use at steady state = rate × 60 s. — **Solution sketch:** the range holds 28,232
   ports. 500 × 60 = 30,000 is more than that, so it runs out after about
   28,000 / 500 = 56 s. The sustainable rate is 28,232 / 60, about 470 per second.
4. **Keepalive settings.** A service holds long-lived connections through an NLB and
   then a NAT Gateway. Both idle at 350 s. The kernel default keepalive starts at 7200 s.
   What do you set, and where? — **Hint:** probes must beat the shortest timer with
   room for a lost probe. — **Solution sketch:** enable `SO_KEEPALIVE` in the client and
   server code, with `TCP_KEEPIDLE` around 60–120 s, `TCP_KEEPINTVL` 10–30 s and
   `TCP_KEEPCNT` 3–5. It is well under 350 s and a dead peer is found in two to four
   minutes. Without `SO_KEEPALIVE` the sysctls change nothing.
5. **Read an `ss -ti` line.** `cubic wscale:7,7 rto:208 rtt:5.1/2.3 mss:1448 cwnd:10
   ssthresh:7 bytes_retrans:4344 unacked:3 retrans:0/3`. What does it say? —
   **Hint:** `ssthresh` is only set after a loss. — **Solution sketch:** CUBIC, both
   sides scale windows by 128, a smoothed RTT of 5.1 ms (deviation 2.3), RTO 208 ms
   (the 200 ms floor plus a little), `cwnd` 10 segments of 1448 bytes. `ssthresh` 7
   and three retransmitted segments in total (4344 bytes) say a loss event happened
   earlier. No retransmission is outstanding now (`retrans:0`), and 3 segments are in flight.
6. **RTO schedule.** With `tcp_syn_retries=6`, a SYN is retransmitted with doubling
   gaps starting at 1 s. At what times are retransmissions sent, and when does
   `connect()` fail? — **Hint:** gaps 1, 2, 4, 8, 16, 32, then wait one more
   doubling. — **Solution sketch:** retransmissions at 1, 3, 7, 15, 31 and 63 s, and
   `connect()` fails at 127 s with `ETIMEDOUT` (the last wait is 64 s). Compare that
   with an RST, which fails the call in one round trip.
7. **Why 2×MSL?** Name the two jobs of TIME_WAIT and a failure that follows if you
   skip it. — **Hint:** think of the last ACK, and of a reused port. —
   **Solution sketch:** it can re-ACK a retransmitted FIN, and it keeps delayed
   segments of the old connection from being accepted by a new connection with the
   same 4-tuple. Without it a lost last ACK leaves the peer stuck in LAST_ACK, or old
   data corrupts a new stream.
8. **Half-open.** A server host loses power. The client is idle and has `SO_KEEPALIVE`
   off. What does it see, and when? — **Hint:** what packet would reveal that the
   peer is gone? — **Solution sketch:** nothing. `ss` still shows ESTABLISHED, because no
   FIN or RST was sent. It finds out only when it sends data: it retransmits until
   `tcp_retries2` (about 15 minutes) and fails. With keepalive on and tuned, the
   probes find out within `KEEPIDLE + KEEPINTVL × KEEPCNT`.
9. **UDP and closed ports.** `nc -u host 9999` prints nothing whether the port is
   open or closed. How do you tell the difference? — **Hint:** UDP has no handshake,
   so look for the one reply the stack can send. — **Solution sketch:** capture and
   look for ICMP `port unreachable`. A connected UDP socket reports it as
   `ECONNREFUSED` on the next send or receive. If a firewall drops the ICMP, the two
   cases look the same, so an application-level reply is the only reliable probe.
10. **NAT Gateway ceiling.** A fleet makes up to 200,000 concurrent connections to one
    third-party API IP and port through a single NAT Gateway. What happens, and what are
    your options? — **Hint:** the limit applies per unique destination. —
    **Solution sketch:** at 55,000 connections to that destination, new connections
    fail and `ErrorPortAllocation` rises. Options: spread the fleet over several NAT
    Gateways (at least four: 200,000 / 55,000), reuse connections through a pool,
    or reach the destination without NAT through a PrivateLink or gateway endpoint.

11. **Read a zero-window stall.** A capture of a bulk upload shows the receiver
    advertising `win 0`, then the sender emitting a 1-byte segment every few seconds
    that is answered with `win 0` again, and finally `win 65535`. Is the network
    losing packets? What is slow? — **Hint:** the sender is probing, not
    retransmitting lost data. — **Solution sketch:** no loss. `win 0` means the
    receiver's buffer is full because its application is not reading. The sender stops
    and sends persist (window) probes on a backoff timer until an ACK reopens the
    window. Look at the receiving process (a stuck consumer, a slow disk), not the
    path. A capture on the receiving host will show its socket's receive queue full.

## Anti-patterns / Common mistakes

- **Debugging without a capture (mistake 4).** Application logs and the console tell you
  what each layer says about itself. In the NLB incident the backend logs are clean
  because the backend never saw the packet. Capture at both ends: the first place the
  packet is missing is the fault domain, and an RST whose source is the VIP, not the
  backend, ends the argument.
- **Confusing a timeout with a reset (mistake 5).** A RST is a reply, so the host or a
  device speaking for it is alive and the path works. A timeout is silence. They send
  you to different places: a RST goes to a listener or a middlebox state table,
  silence goes to filters and routes. Translate the error into a wire event first.
- **Raising the timeout until it goes away.** Doubling a client timeout against a
  filtered port only makes the hang longer, and raising an idle timeout (or a retry
  count) hides a half-open connection until it breaks at a worse moment. Find which
  timer fired and which side owns it, then fix that: enable keepalive, shorten the
  client's pool idle age to be below the LB's idle timeout, or raise the right timeout
  deliberately.

## Teardown

```bash
bash labs/day03/topo.sh down
bash labs/verify-teardown.sh
```

Full checklist in `labs/day03/teardown.md`.
