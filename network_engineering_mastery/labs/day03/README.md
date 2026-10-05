# Day 3 lab — the NLB in a box

## At a glance

- **Runs in:** `netlab` (see `labs/netlab/README.md`), from `/course`.
- **Commands:** `bash labs/day03/topo.sh up`, the Prove walkthrough below,
  `bash labs/day03/break.sh`, `bash labs/day03/verify.sh`, `bash labs/day03/topo.sh down`.
- **Time:** about 1 h 30 m (45 m guided proof, 30 m break and diagnose, 15 m verify and journal).
- **Success signal:** the idle connection through the VIP dies with
  `ConnectionResetError` after 25 s, the same one lives with keepalive on, and
  `verify.sh` prints `PASS: day 03 is healthy.` after you fix the three faults.

## Topology

```
 c1 10.3.1.10 --eth0 ===== eth1-- lb --eth2 ===== eth0-- s1 10.3.2.20
                         10.3.1.1   10.3.2.1              python3 http.server :8080
                         VIP 10.3.9.100 on lo
```

`lb` plays the NLB. The rules are in `lb.nft`. The VIP `10.3.9.100:80` is DNATed to
`s1:8080`. Conntrack in `lb` has two settings that mimic the cloud device:
`nf_conntrack_tcp_loose=0` (a mid-stream packet of an unknown flow is not adopted) and
`nf_conntrack_tcp_timeout_established=20` (a 20 s idle timeout; the real NLB uses 350 s <!-- fact-checked 2026-10-05 -->).
A packet to the VIP that is not DNATed has no flow, so the `input` chain answers it
with an RST. Nothing listens on s1:8081.

## Prove it on the wire

Open two or three shells in `netlab`: `docker compose -p netlab exec netlab bash`.

```bash
bash labs/day03/topo.sh up
ip netns exec c1 curl -s http://10.3.9.100/        # prints: hello from s1
```

### 1. One full HTTP connection

Shell 1:

```bash
ip netns exec s1 tcpdump -ni eth0 -S tcp port 8080
```

Shell 2:

```bash
ip netns exec c1 curl -s -o /dev/null http://10.3.9.100/
ip netns exec s1 ss -tan state time-wait
```

`-S` prints absolute sequence numbers. Label each line: SYN, SYN-ACK, ACK (the
handshake); the `P.` request and response data with their ACKs; the FIN/ACK pairs.
Find the first `F`. That side is the active closer, and `ss` shows the TIME_WAIT
socket on that same host. Python's `http.server` answers HTTP/1.0 and closes first, so
the TIME_WAIT is on s1.

Now read the options on the SYN line: `mss 1460` (1500 minus 40 bytes of headers),
`sackOK`, `TS val ... ecr 0`, `wscale 7`. Compare them with the SYN-ACK.

### 2. Loss, seen from the sender

Make a 2 MB payload and watch the sender (s1) through the transfer. Both runs use the
same 20 ms delay, so the only difference is the loss. (On a zero-delay veth the server
hands the whole file to the kernel and leaves ESTABLISHED before you can sample.) The
`sample` function polls every 50 ms while the s1 socket exists and prints the **last**
`ss -ti` info line it saw, which is the end-of-transfer state: the first 50 ms of any
connection still shows the initial `cwnd` of 10.

```bash
head -c 2000000 /dev/urandom > /run/netlab/big2m
sample() { local i o last=""; for i in $(seq 1 400); do
  o=$(ip netns exec s1 ss -ti state established '( sport = :8080 )' | /usr/bin/grep 'cwnd:' | tail -n 1)
  if [ -n "$o" ]; then last=$o; elif [ -n "$last" ]; then break; fi; sleep 0.05; done
  echo "${last:-(no sample)}"; }
tc -n s1 qdisc add dev eth0 root netem delay 20ms
echo "--- baseline: 20 ms delay, no loss"
ip netns exec c1 curl -s -o /dev/null --max-time 60 http://10.3.2.20:8080/big2m & sample; wait
tc -n s1 qdisc change dev eth0 root netem delay 20ms loss 10%
echo "--- 20 ms delay, 10% loss"
ip netns exec c1 curl -s -o /dev/null --max-time 60 http://10.3.2.20:8080/big2m & sample; wait
tc -n s1 qdisc del dev eth0 root
```

If you interrupt it, remove the qdisc: `tc -n s1 qdisc del dev eth0 root`. The sampler
gives up after about 20 s, and the lossy run takes about 15 s.

Expected sketch (the fields matter, the numbers vary per run):

```
--- baseline: 20 ms delay, no loss
	 cubic ... rtt:~20/... mss:1448 cwnd:large (tens to hundreds) ... bytes_sent:~2000000   (no ssthresh, no bytes_retrans)
--- 20 ms delay, 10% loss
	 cubic ... rtt:~20/... mss:1448 cwnd:small (about 2-20) ssthresh:set bytes_sent:... bytes_retrans:>0 ...
```

Compare `cwnd`, `ssthresh`, `bytes_retrans` and `rto` between the two runs. Expect a large
`cwnd` and no retransmissions in the baseline, and a small `cwnd`, a set `ssthresh` and
a non-zero `bytes_retrans` under loss. `rtt` stays near 20 ms in both. The exact numbers
differ on each run, the direction does not.

### 3. UDP to a closed port

```bash
ip netns exec c1 tcpdump -ni eth0 'udp or icmp' &
echo hi | ip netns exec c1 nc -u -w1 10.3.2.20 9999
kill %1
```

One UDP datagram goes out. An ICMP "udp port 9999 unreachable" comes back. UDP has no
RST, so ICMP is the refusal. `nc -u` prints nothing either way, which is the point: with
UDP you only learn the port is closed because ICMP told you.

### 4. Ephemeral-port exhaustion

```bash
ip netns exec c1 sysctl -w net.ipv4.ip_local_port_range="40000 40009"
ip netns exec c1 python3 labs/day03/client.py 10.3.2.20 8080 20
ip netns exec c1 ss -tan state time-wait | head -12
ip netns exec c1 sysctl -w net.ipv4.ip_local_port_range="32768 60999"
```

Expected from `client.py`:

```
ok=10 errors=10
first error: [Errno 99] Cannot assign requested address
```

Ten ports, ten TIME_WAIT sockets on c1 (the client closes first, so it holds them), and
the eleventh connection to the same destination has no free 4-tuple. Wait 60 s and
it works again.

### 5. AWS emulation: the NLB idle timeout

`http.server` closes after every response, so the demo keeps the connection idle
another way. It sends half a request, waits, then sends the rest.

Shell 1 (c1 eth0 sees the RST that crosses the wire):

```bash
ip netns exec c1 tcpdump -ni eth0 'tcp[tcpflags] & tcp-rst != 0'
```

Shell 2, the idle client:

```bash
ip netns exec c1 python3 -c "
import socket, time
s = socket.create_connection(('10.3.9.100', 80))
s.sendall(b'GET / HTTP/1.1\r\nHost: x\r\n')
time.sleep(25)
try:
    s.sendall(b'\r\n'); print(s.recv(200).split(b'\r\n')[0])
except Exception as e:
    print(repr(e))
"
```

Shell 3, during the first 20 s and again after 25 s:

```bash
ip netns exec lb conntrack -L -p tcp 2>/dev/null
```

Expected after 25 s:

```
ConnectionResetError(104, 'Connection reset by peer')
```

and in shell 1 an RST from the VIP:

```
IP 10.3.9.100.80 > 10.3.1.10.<port>: Flags [R], seq ..., length 0
```

(The flag column reads `R` because the packet it answers carried an ACK.) Before the
timeout, `conntrack -L` shows an `ESTABLISHED` entry for `dport=80` whose timer counts
down from 20. After it, the entry is gone. The late packet is not a SYN, so conntrack
does not adopt it, the DNAT does not run, it reaches `lb` itself, and the `input` rule
answers with the RST.

Repeat with keepalive on. Probes every 5 s after 10 s of silence refresh the timer:

```bash
ip netns exec c1 python3 -c "
import socket, time
s = socket.create_connection(('10.3.9.100', 80))
s.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
s.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPIDLE, 10)
s.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPINTVL, 5)
s.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPCNT, 3)
s.sendall(b'GET / HTTP/1.1\r\nHost: x\r\n')
time.sleep(25)
try:
    s.sendall(b'\r\n'); print(s.recv(200).split(b'\r\n')[0])
except Exception as e:
    print(repr(e))
"
```

Expected: `b'HTTP/1.0 200 OK'` and no RST in shell 1. The probes show up in s1 as
zero-length ACKs. Map: NLB 350 s, NAT Gateway 350 s, here 20 s.

### 6. AWS emulation: client-IP preservation

```bash
ip netns exec lb nft add rule ip nlb postrouting ip daddr 10.3.2.20 snat to 10.3.2.1
ip netns exec c1 curl -s -o /dev/null http://10.3.9.100/
tail -n 2 /run/netlab/web.log          # the peer is now 10.3.2.1
ip netns exec lb conntrack -L -p tcp   # the reply tuple is rewritten
ip netns exec lb nft flush chain ip nlb postrouting
ip netns exec c1 curl -s -o /dev/null http://10.3.9.100/
tail -n 1 /run/netlab/web.log          # the peer is 10.3.1.10 again
```

## Break and diagnose

```bash
bash labs/day03/break.sh
```

Write the evidence chain in `journal.md` before you fix anything. Then, `SOLUTION.md`.
Run `bash labs/day03/verify.sh` after each fix: it reports every check on its own line.

## Journal

End with the sentence: "The NLB idle timeout in AWS is ___ on the wire." Teardown:
`labs/day03/teardown.md`.
