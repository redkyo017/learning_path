# Day 2 — Networking as an Attacker

## Objectives

By the end of today you should be able to:

- Map a handful of common attacks to the OSI/TCP layer they operate at, and explain why
  that layer matters for both the attack and its defense.
- Explain the TCP three-way handshake well enough to say precisely why a SYN scan is
  "stealthier" than a full-connect scan — not just that it is.
- Run a full nmap enumeration (`-sS -sV -sC`) and read every part of its output,
  including the parts that take a while and the parts that come back unidentified.
- Capture and read raw packets with `tcpdump`/`tshark`, and connect what you see on the
  wire back to the handshake concept above.
- Explain why ARP has no authentication, and use that gap to become a real
  man-in-the-middle between two containers on an isolated segment — then read a
  cleartext credential exchange straight out of the capture.
- Apply three intro-level defenses — network segmentation, an `iptables` scan-detection
  rule, and ARP-anomaly awareness — and say honestly which of the three today's lab
  actually verifies versus which is described conceptually pending Day 11.

## 1. Concept — Layers, Handshakes, and Why ARP Is the Weak Link

### Attacks have an address: the OSI/TCP layer they live at

Day 1 treated "the network" as a black box you probe from the outside. Today opens
that box. Every attack and defense from here on operates at a specific layer, and
knowing which layer tells you what tool applies and what a fix actually changes:

| Layer | What lives here | Today's attack at this layer | Today's defense at this layer |
|---|---|---|---|
| L2 — Data Link | Ethernet frames, MAC addresses, **ARP** (mapping IP → MAC on a local segment) | **ARP spoofing** — lying about which MAC owns an IP | ARP-anomaly detection (watch for one IP claiming two MACs) |
| L3 — Network | IP addresses, routing | Traffic is routed here, but today's attacks don't forge IP itself | **Network segmentation** — controlling which L3 segments can even reach each other |
| L4 — Transport | TCP/UDP, ports, the three-way handshake | **SYN scanning** (probing the handshake itself); packet capture reads this layer directly | **Host firewall (`iptables`)** rules matching connection patterns |
| L7 — Application | HTTP, FTP, the LegacyAuth protocol today's `server` speaks | The cleartext credential exchange itself lives here — ARP spoofing (L2) is what makes it *readable* | TLS/encryption (Day 3) — not built today, but named as the actual fix |

Notice the pattern in that last row: **the attack that exposes the cleartext creds
happens two layers below the creds themselves.** ARP spoofing doesn't touch the
LegacyAuth protocol at all — it just redirects L2 delivery so an L7 conversation that
was never protected gets copied to a third party. That gap between "where the attack
happens" and "where the damage shows up" is the single most important idea in today's
lab, and it's why segmentation (an L2/L3 control) and encryption (an L7 control, coming
Day 3) are *both* necessary — one without the other still leaves a hole.

### The three-way handshake, and the SYN-scan trick

TCP opens a connection with three packets: **SYN** (client: "I'd like to connect"),
**SYN-ACK** (server: "OK, and I'd like to connect back"), **ACK** (client: "confirmed,
we're open"). A normal client — `curl`, a browser, `victim.py` in today's lab — sends
all three and then talks over the now-open connection.

nmap's default scan (`-sS`, a **SYN scan**) never sends that third ACK. It sends the
SYN, reads whether a SYN-ACK comes back (port open) or a RST comes back (port closed),
and then — because the OS-level TCP stack never completed the handshake — the
connection **never gets fully established**. This matters for two separate reasons:

- **Speed:** nmap doesn't have to wait for an application on the far end to accept and
  process a connection; the kernel-level SYN-ACK/RST reply is enough information.
- **Stealth relative to a connect scan:** a **connect scan** (`-sT`, what nmap falls
  back to without raw-socket privileges) completes the full handshake using the normal
  OS socket API, which means the *target application* sees a completed connection and
  may log it (an FTP daemon logging a connection attempt, a web server logging a
  request). A SYN scan's half-open connection often never reaches the application layer
  at all — only lower-level packet inspection (a firewall, an IDS, `tcpdump` on the
  target itself) sees it. Neither is invisible to a system that's actually watching the
  wire — that's Day 11's job — but a SYN scan is quieter against the more common case
  of an application that only logs completed sessions.

Today's attack lab captures exactly this exchange with `tcpdump` so you see the
SYN → SYN-ACK → RST pattern as real bytes, not just prose.

### ARP: the protocol with no ID check

**ARP** (Address Resolution Protocol) answers one question on a local network segment:
"who has this IP address?" — by broadcasting a request and trusting whatever reply
comes back, unconditionally. There is no signature, no certificate, no shared secret.
Any host on the segment can reply "I have that IP" for an address it doesn't own, and
every other host will simply believe it and start sending that IP's traffic to the
liar's MAC address instead. That's **ARP spoofing** (also called ARP poisoning).

Do it twice — tell the victim "I am the server" and tell the server "I am the victim" —
and you've inserted yourself in the middle of their conversation without either side's
TCP stack ever objecting: TCP doesn't know delivery got rerouted a layer below it. This
is a **MITM** (man-in-the-middle) position: traffic that used to flow victim ↔ server
directly now flows victim ↔ *you* ↔ server, and you can read (or, if you also forward
packets between the two connections, silently relay) every byte, including the
completely unencrypted username/password today's `victim` container sends every five
seconds. **Packet capture** — recording raw frames off the wire with `tcpdump` or
`tshark` — is how you actually *read* what a MITM position exposes; the ARP spoof gets
you the vantage point, capture is what turns that vantage point into visible
credentials.

### Segmentation: the defense that was already running

`GLOSSARY.md`'s **trust boundary** concept (Day 0) shows up today as **network
segmentation** — deliberately splitting a network into zones so that compromising one
zone doesn't automatically grant reach into another. Today's lab is *built* around this
idea before you even touch the defense section: `victim` and `server`'s cleartext
exchange happens entirely on an isolated segment (`day02-mitm`) that the attacker
container is **not** on by default. Reaching that segment at all — via
`docker network connect`, a deliberate, visible step documented in the lab README — is
itself a small model of what a real attacker has to do to get from "I can scan this
network" to "I'm on the same broadcast domain as this sensitive traffic." Segmentation
doesn't stop ARP spoofing once you're on the segment; it stops you *getting onto* the
segment in the first place, which is why it's listed first among today's defenses even
though the lab doesn't ask you to build it — you're shown it by contrast, the way Day
1 showed attack-surface reduction by first harvesting what an unreduced surface leaks.

### Detection is a spectrum, and today only touches the start of it

An **IDS** (Intrusion Detection System) watches traffic or logs and raises an alert on
suspicious patterns — either by matching known bad **signatures** (a specific scan
tool's packet shape) or by flagging statistical **anomalies** (a host suddenly claiming
an IP it's never claimed before). Today's defense lab writes one `iptables` rule that
detects/rate-limits a scan pattern and describes, conceptually, one ARP-anomaly check
and one Suricata-style signature rule — genuinely useful first exposure, but
intentionally not a running Suricata engine or a tuned detection pipeline. That's Day
11's job (`content/day11-detection.md`), which is why `ROADMAP.md` marks today's
contribution to blue-team/IDS coverage **Partial**, not **Covered** — be honest with
yourself about that boundary rather than assuming today's single rule is a real SOC
capability.

## 2. Attack Lab — Enumerate, Capture, and MITM the `server`/`victim` Pair

**Authorized use only:** everything below targets only the `server` and `victim`
containers this lab starts on `cyberlab` and the lab-private `day02-mitm` segment.
Never point any of this at a network you don't own or don't have explicit written
authorization to test — ARP spoofing in particular is disruptive to real networks and
is illegal to run against anything you don't have permission to test.

### What you're attacking

`labs/day02/` adds two containers (full detail:
[`labs/day02/README.md`](../labs/day02/README.md)):

- **`server`** — runs a tiny, deliberately plaintext "LegacyAuth" service on port 2121
  (banner → `USER` → `331` → `PASS` → `230`, the same shape as real FTP's control
  channel). `server` sits on **both** `cyberlab` (so the attacker can enumerate it
  directly, like every other day's target) and `day02-mitm`.
- **`victim`** — logs into `server`'s LegacyAuth service on a loop, every five seconds,
  sending a real username and password in cleartext each time. `victim` exists **only**
  on `day02-mitm`, a bridge network private to this lab — the attacker container is not
  on it by default.

Bring both up (after `labs/base/up.sh` if you haven't already):

```sh
cd cyber_security/labs/day02
docker compose up -d --build
```

### Step 1 — Full nmap enumeration

```sh
docker compose exec attacker sh -c "nmap -sS server"
docker compose exec attacker sh -c "nmap -sS -sV -sC server"
```

Run these from `labs/base` (or anywhere `docker compose exec attacker ...` resolves the
shared container — see the lab README's note on this).

**What you should see:** the first command is fast and shows port 2121 open,
guessed as an unrelated service (`ccproxy-ftp`) purely from the port number — the same
"wrong guess, still useful raw data" pattern Day 1 covered. The second command
**takes noticeably longer (over two minutes is normal)** — `-sV`'s version-detection
probes send many different protocol-specific strings at the unidentified service, and
`server`'s simple two-line handshake doesn't respond usefully to almost any of them, so
each probe waits out its own timeout before nmap moves to the next. This is exactly
the "unidentified is not the same as safe, and now it's also not the same as fast"
lesson from Day 1, taken one step further: an oddball service costs an attacker real
time to fingerprint, which is itself a (mild, incidental) defense. The output includes
a `fingerprint-strings` block showing the raw banner text nmap captured across several
different probes — direct confirmation that the data was always there, same as Day 1.

### Step 2 — Capture the scan itself

Packet capture reads traffic at the wire level, independent of whatever any tool
*reports* about it — worth doing once so the handshake concept in Section 1 stops being
prose and becomes bytes you've looked at yourself:

```sh
docker compose exec -d attacker sh -c "tcpdump -i eth0 -w /loot/day02-scan.pcap 'tcp port 2121'"
docker compose exec attacker sh -c "nmap -sS server"
docker compose exec attacker sh -c "tshark -r /loot/day02-scan.pcap -T fields -e ip.src -e ip.dst -e tcp.flags -e tcp.srcport -e tcp.dstport"
```

(`-d` runs the `tcpdump` command detached so it keeps capturing while the next command
runs; stop it afterward with the process-management approach in
[`labs/day02/SOLUTION.md`](../labs/day02/SOLUTION.md) if you don't want it to keep
running.)

**What you should see:** three packets, textbook SYN-scan shape — a `SYN` (flags
`0x0002`) from the attacker, a `SYN-ACK` (`0x0012`) back from `server` confirming the
port is open, and then a `RST` (`0x0004`) from the attacker instead of the `ACK` a real
client would send. That `RST` in place of `ACK` **is** the half-open scan from Section
1, visible as an actual packet rather than a claim about one.

### Step 3 — Join the isolated segment

`server` and `victim`'s cleartext exchange lives on `day02-mitm`, which the attacker
container is not part of yet. Join it deliberately:

```sh
docker network connect cyberlab-day02-mitm cyberlab-attacker
docker compose exec attacker sh -c "ip -brief addr"
```

**What you should see:** a new `eth1` interface inside the attacker container with an
address on the `172.20.0.0/16` range (the exact address will vary by run) — you're now
on the same L2 segment as `victim` and `server`'s conversation, but you haven't done
anything to intercept it yet. Find both containers' addresses *on this segment*
specifically (not `cyberlab`'s):

```sh
docker inspect cyberlab-day02-server --format '{{(index .NetworkSettings.Networks "cyberlab-day02-mitm").IPAddress}}'
docker inspect cyberlab-day02-victim --format '{{(index .NetworkSettings.Networks "cyberlab-day02-mitm").IPAddress}}'
```

### Step 4 — ARP-spoof and sniff the cleartext exchange

The attacker toolbox doesn't ship `arpspoof` by default (it's not in the shared
`labs/base` tool list — installing it there would affect every other day's lab). Install
it just for this session instead, exactly the way a real engagement adds a tool it
didn't anticipate needing:

```sh
docker compose exec attacker sh -c "apt-get update -qq && apt-get install -y --no-install-recommends dsniff"
```

Start a capture, then poison both directions of the ARP cache — telling `victim` that
*you* are `server`, and telling `server` that *you* are `victim` — using the addresses
from Step 3:

```sh
docker compose exec -d attacker sh -c "tcpdump -i eth1 -w /loot/day02-mitm.pcap 'tcp port 2121'"
docker compose exec -d attacker sh -c "arpspoof -i eth1 -t <victim-ip> <server-ip>"
docker compose exec -d attacker sh -c "arpspoof -i eth1 -t <server-ip> <victim-ip>"
```

Wait at least one full `victim` login cycle (5+ seconds), then read the capture:

```sh
docker compose exec attacker sh -c "tshark -r /loot/day02-mitm.pcap -q -z follow,tcp,ascii,0"
```

**What you should see:** `arpspoof` printing a continuous stream of forged ARP replies
(each side now believes the attacker's MAC owns the other's IP), and the `tshark`
follow-stream output showing the **entire LegacyAuth exchange in plaintext**, including
a `PASS` line with the actual password `victim` sent. Full confirmed output, and how to
stop the capture/spoofing cleanly afterward, are in
[`labs/day02/SOLUTION.md`](../labs/day02/SOLUTION.md) — this is the moment today's
concept section (ARP has no ID check → MITM → cleartext is readable) becomes something
you did, not something you read about.

### Verify

```sh
docker compose exec attacker sh -c "nmap -sS server > /loot/day02.txt && grep -q open /loot/day02.txt && echo ATTACK_OK"
```

Expected: `ATTACK_OK`. Full walkthrough with real captured output (enumeration, scan
packet capture, and the full ARP-spoof MITM session) is in
[`labs/day02/SOLUTION.md`](../labs/day02/SOLUTION.md).

## 3. Defense Lab — Segment, Rate-Limit, and Watch for ARP Anomalies

Three intro-level defenses, honestly scoped: one is already built into the lab
architecture (you're asked to *recognize* it), one you apply and re-verify yourself,
and one is described conceptually with a pointer to where it becomes real (Day 11).

### Defense 1 — Segmentation (already running; recognize why)

Look back at Section 2 Step 3: the attacker container had to *explicitly join*
`day02-mitm` before any ARP spoofing was possible. That's segmentation working exactly
as intended — the isolated network is the actual control, and "the attacker wasn't on
the segment" is the reason Steps 1–2 (enumeration) could happen without exposing the
cleartext exchange at all. In a real network, the equivalent is VLANs or subnets that
keep a payments-processing segment, say, off the same broadcast domain as general
office Wi-Fi: an attacker who compromises a laptop on the office segment still can't
ARP-spoof anything on the payments segment without a *further*, separate compromise to
get there. Nothing to build here — the exercise is noticing that Section 2 would have
been a non-event on `day02-mitm` if the attacker had never run `docker network
connect`, and that this is precisely the property segmentation is for.

### Defense 2 — An `iptables` scan-detection/rate-limit rule

A **host firewall** rule can flag (or drop) the specific pattern a port scan produces:
many new connection attempts, from one source, in a short window — very different from
normal traffic. Apply this on `server` (rebuild required, since `server`'s image needs
`iptables` added and the rule applied at container start):

```sh
# inside server's entrypoint, before starting the LegacyAuth service:
iptables -A INPUT -p tcp --dport 2121 -m conntrack --ctstate NEW \
  -m recent --name day02scan --set
iptables -A INPUT -p tcp --dport 2121 -m conntrack --ctstate NEW \
  -m recent --name day02scan --update --seconds 10 --hitcount 5 \
  -j LOG --log-prefix "day02-scan-detect: "
```

The `recent` module tracks recent connection attempts per source IP; the second rule
matches when the *same* source has hit this list 5+ times within 10 seconds and logs
it (swap `-j LOG` for `-j DROP` to actively block rather than just detect — detection
first is usually the right default so you can confirm the rule fires before it starts
silently dropping legitimate traffic too).

**Re-verify:** re-run `nmap -sS server` a few times in quick succession from the
attacker and check `server`'s kernel log for the `day02-scan-detect:` line. Full applied
diff and confirmed log output: [`labs/day02/SOLUTION.md`](../labs/day02/SOLUTION.md).

### Defense 3 — ARP-anomaly awareness, and where full IDS coverage actually lands

Two things worth naming precisely, even without standing up tooling for them today:

- **ARP-anomaly detection**, in its simplest form, is watching for one IP address
  claiming two different MAC addresses in a short window — exactly the signal
  Section 2 Step 4 generated (both `victim` and `server` saw ARP replies claiming the
  attacker's MAC for an IP that wasn't previously that MAC). A tool like `arpwatch`
  does this continuously and alerts on changes; you can approximate a single manual
  check with `arp -a` (or `ip neigh`) run from `victim` or `server` before and after
  Step 4 and diffing the MAC column for the other party's IP.
- A real **IDS** (e.g., Suricata) would encode this same idea — and the SYN-scan
  pattern from Step 2 — as standing rules that fire automatically and continuously,
  correlated with logging and alerting, not something you run by hand once per lab.
  A conceptual sketch of what such a rule looks like: a Suricata rule matching "more
  than N SYN packets to distinct ports from one source within T seconds" for scan
  detection, and a rule matching "gratuitous ARP reply changing a known IP→MAC binding"
  for spoofing detection. **Today does not stand up Suricata** — that's Day 11
  (`content/day11-detection.md`), which is exactly why `ROADMAP.md` marks this node
  **Partial** today and **Covered** only once Day 11 ships. Naming the gap accurately
  is more useful than pretending one `iptables` log line is a SOC.

### The pattern to internalize

Every defense today operates at a **different layer than the attack it counters**, on
purpose: segmentation stops the L2 ARP spoof by controlling reachability before any
packet is sent; the `iptables` rule reads L4 connection metadata to catch an L3/L4-level
scan pattern; ARP-anomaly awareness watches the same L2 layer the attack itself abused.
None of them touch the L7 cleartext protocol at all — that gap is deliberate, and it's
the reason Day 3's actual fix for "credentials sent in the clear" is encryption, not
anything covered today. Layered defense means covering the layer the attack used *and*
still fixing the layer that made the damage possible once intercepted.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Interpret a pcap snippet

You capture the following (`tshark`-style summary, timestamps in seconds, `S`=SYN,
`A`=ACK, `SA`=SYN-ACK, `R`=RST):

```
0.001  10.0.0.5:51000 -> 10.0.0.10:22   [S]
0.002  10.0.0.10:22 -> 10.0.0.5:51000   [SA]
0.002  10.0.0.5:51000 -> 10.0.0.10:22   [R]
0.003  10.0.0.5:51001 -> 10.0.0.10:80   [S]
0.004  10.0.0.10:80 -> 10.0.0.5:51001   [SA]
0.004  10.0.0.5:51001 -> 10.0.0.10:80   [A]
0.004  10.0.0.5:51001 -> 10.0.0.10:80   [GET / HTTP/1.1 ...]
```

What happened, what kind of scan/traffic is each numbered block, and what does the
*difference* between the two blocks tell you about what's running on 10.0.0.10?

**Hint:** look at what packet ends each block — a `RST` where an `ACK` "should" be
means something specific from Section 1.

**Solution sketch:**

- **Port 22 (lines 1–3):** SYN → SYN-ACK → **RST**. This is a SYN scan against port
  22 — the handshake was never completed (no `ACK`), which is nmap's `-sS` behavior:
  it only needed the SYN-ACK to know the port is open, then tore the half-open
  connection down with a RST instead of finishing it. SSH itself never saw a completed
  session, so this wouldn't appear in `sshd`'s own connection log.
- **Port 80 (lines 4–7):** SYN → SYN-ACK → **ACK** → an actual `GET` request. This is
  a completed connection carrying real HTTP traffic (a connect scan, or simply a normal
  HTTP client) — the handshake finished and an application-layer request followed.
- **The difference tells you:** whatever tool generated lines 1–3 was specifically
  probing to see if port 22 was open without fully connecting (typical enumeration
  behavior), while lines 4–7 show genuine interaction with the web server on port 80 —
  two different activities in the same capture, and the packet-ending pattern is the
  only thing that distinguishes "just checking if this is open" from "actually talking
  to what's there."

### Drill 2 — Write an iptables rule to drop a scan pattern

Using the `recent` module pattern from Section 3's Defense 2, write an `iptables` rule
set that **drops** (not just logs) any source IP that makes 10 or more new connection
attempts to port 443 within a 5-second window.

**Hint:** you need the same two-rule shape (a `--set` rule, then a `--update` rule
checking the threshold) — the only things that change from the Section 3 example are
the port, the threshold, the window, and the final `-j` target.

**Solution sketch:**

```sh
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW \
  -m recent --name https_scan --set
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW \
  -m recent --name https_scan --update --seconds 5 --hitcount 10 \
  -j DROP
```

The first rule adds every new connection attempt's source IP to a tracked list named
`https_scan` with a timestamp. The second rule checks that same list: if this source
IP has 10+ entries within the last 5 seconds, `--update` refreshes its timestamp *and*
the rule matches, sending the packet to `DROP` instead of letting it reach port 443.
Genuine clients making the occasional new HTTPS connection stay well under 10 attempts
in 5 seconds and are unaffected; anything scanning through many ports/attempts quickly
trips the threshold. (As in Section 3: test with `-j LOG` first before switching to
`-j DROP`, so you can confirm the threshold doesn't also catch legitimate bursty
traffic like a page loading many assets at once.)

### Drill 3 — Why ARP spoofing works, and one detection method

In one or two sentences each: (a) explain *why* ARP spoofing works at a protocol level
— what specific property ARP lacks that lets it happen — and (b) name one concrete way
to detect it happening on a network.

**Hint:** for (a), don't just say "ARP is insecure" — name the specific missing
mechanism, the same way Section 1 named it. For (b), you already ran the exact
before/after check that would catch this, earlier today.

**Solution sketch:**

- **(a) Why it works:** ARP replies carry no authentication — any host can broadcast
  "I own IP X" and every other host on the segment accepts it unconditionally, with no
  signature or shared secret to check the claim against. There's no step in the
  protocol where a receiver can verify the reply actually came from whoever legitimately
  holds that IP.
- **(b) Detection:** watch for **ARP anomalies** — a given IP address suddenly
  resolving to a *different* MAC address than it did a moment ago, with no legitimate
  reason (like the interface's NIC actually changing). Tools like `arpwatch` do this
  continuously and alert on change; you can approximate it manually with `arp -a` (or
  `ip neigh`) diffed before/after — literally the same check Section 3's Defense 3
  described, and the same signal that would have appeared on `victim` and `server`
  during Section 2 Step 4's live spoofing.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** the `server`/`victim` pair — name specifically what you
  enumerated (the unidentified port, guessed wrong by nmap) versus what you actually
  MITM'd and read (the cleartext username/password), since those were two different
  vantage points requiring two different actions (staying on `cyberlab` vs. joining
  `day02-mitm`).
- **How:** walk through the four steps in order — enumeration, packet capture of the
  scan itself, joining the segment, ARP spoofing — and say which single step made the
  biggest "click" for you connecting concept to reality.
- **What defended it:** of today's three defenses (segmentation, the `iptables` rule,
  ARP-anomaly awareness), which is honestly a *real* control today versus which is
  closer to "named but not yet built" (and say why that distinction matters rather than
  treating all three as equally finished)?
- **What confused me:** anything about *why* the SYN scan's RST-instead-of-ACK matters,
  or about why ARP spoofing (an L2 attack) can expose an L7 cleartext protocol that
  ARP itself has nothing to do with, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (SYN scan, ARP spoofing, MITM,
  packet capture, segmentation) to re-explain from memory before Day 3, without looking
  back at this file.
