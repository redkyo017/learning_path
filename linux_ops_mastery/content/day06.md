# Day 6 — The Network, Seen From the Box

**Truth of the day:** fd table (a socket is a descriptor), plus the network
namespace
**Budget:** 3 h — 1 h read the file, derive the tool, and core concepts;
1 h the connectivity-ladder lab; 30 m strip the toolbox; 30 m exercises

## Why this matters

"The service is unreachable" is not a diagnosis, it is a symptom, and it
collapses to exactly one of five distinct causes: DNS didn't resolve, the
kernel had no route, a firewall rule dropped the packet, nothing was
listening, or the application answered and answered wrong. All five look
identical from the caller's side — a hang or a generic connection failure
— and an operator who guesses among them burns an incident restarting
things that were never broken. This day gives you the ladder: one file and
one command per rung, walked in order, so "unreachable" turns into a named
cause before anything gets touched.

## Read the file first

`/proc/net/tcp` and `/proc/net/tcp6` are decoded field by field, including
the little-endian hex address trick, in
`content/primers/proc-field-reference.md` under `## /proc/net/tcp` — the
worked example there converts `0100007F:1F90` to `127.0.0.1:8080` by
reversing the address bytes only (the port needs no byte-swap). That
primer also gives the full `st` state table and the `inode` column that
joins a socket to a process's `/proc/PID/fd`. Read it now if you haven't;
this section builds on it rather than repeating it.

`/proc/net/route` is the routing table's raw form, one line per route,
tab-separated, with `Destination` and `Gateway` written the same
little-endian hex as `/proc/net/tcp`'s addresses, and `Mask` as a hex
netmask. A default route shows `Destination 00000000`; `ip route` is
almost always the better read of this file (below), but the raw form is
what remains when `ip` itself is missing.

`/etc/resolv.conf` holds three lines that matter: `nameserver` (one or
more resolvers, tried in order), `search` (domain suffixes appended to
unqualified names), and `options ndots:N` (the threshold that decides
whether a name is tried as-is first or only after every search suffix has
failed — see the **ndots trap** below).

`/etc/nsswitch.conf`'s `hosts:` line decides where a name lookup even goes
before DNS is involved — typically `files dns`, meaning `/etc/hosts` is
consulted first. A name that resolves differently than `dig` predicts is
often not a DNS problem at all; it's an `/etc/hosts` entry shadowing it.

## Derive the tool

`/proc/net/tcp` and `/proc/net/tcp6` are the socket table exported as
text. `netstat -tn` is a formatted walk of exactly those files: one
output row per line, `local_address` split back into host and port, the
`st` field decoded (`0A` is LISTEN), and the `inode` column joined
against every PID's `/proc/PID/fd` to name the owning process — exactly
the join `content/primers/proc-field-reference.md` walks by hand.

`ss -ltnp` (`-l` listening, `-t` TCP, `-n` don't resolve names, `-p`
show the owning process) prints the same answer but does **not** read
those files. It asks the kernel the identical question over netlink
`SOCK_DIAG`, which is why it stays fast on a host with hundreds of
thousands of sockets and `netstat` does not. Two transports, one
kernel-owned truth — and the text interface is the one that is always
exported, which is why `cat /proc/net/tcp` still answers in a container
that has neither tool (`STRATEGY.md` has the full version of this
point).

`ip route` formats `/proc/net/route` (and the kernel's live routing
table, which is the same data source) as one readable line per route,
CIDR notation instead of hex, sorted so the first matching line is what
the kernel would actually pick. `ip route get <ip>` doesn't just format
the table, it **asks the kernel to run the decision** and prints the
answer — the interface, the source address it would use, and the next
hop — which is the single most useful command on this entire ladder.

## Core concepts

### Interfaces and addresses

`ip addr show` and `ip link show` read the kernel's live interface list
directly; `ifconfig` reads the same data through an older, deprecated
interface that silently drops information modern setups depend on —
most notably, `ifconfig` shows only the first address on an interface
with several, so a secondary IP added for a specific purpose can be
completely invisible to it while `ip addr` lists every one. Treat
`ifconfig` output as possibly incomplete, never as authoritative.

### The routing table as a decision procedure

Every route lookup is a search for the **longest matching prefix**
first, and only a tie in prefix length is broken by **metric** (lower
wins). A `/32` route to one exact address always beats a `/16` covering
that same address, no matter which was added first or which has the
better metric — this is why a single narrow route can override a whole
subnet's worth of broader ones, deliberately or by accident. `ip route
get <ip>` is how you stop inferring this from the table and start asking
the kernel directly: it returns the interface, source address, and next
hop the kernel would actually use for that destination, right now.

### DNS resolution order, and the `ndots` trap

A name lookup walks `/etc/nsswitch.conf`'s `hosts:` order (commonly
`files dns`), and once it reaches DNS, `/etc/resolv.conf`'s `ndots`
option decides the search strategy. **`ndots:N` means: if the name has
fewer than `N` dots in it, try it as a relative name — append each
`search` suffix in order and query that — before ever trying the name
exactly as typed.** A bare service name like `db` has zero dots, so under
`ndots:5` (a common orchestrator default) it is treated as relative no
matter how many dots the eventual real name has. With a four-entry
`search` list — a realistic shape for a clustered environment —
resolving `db` costs up to **five** sequential DNS round trips before an
answer comes back:

```
db.ns.svc.cluster.local.   (search entry 1 — NXDOMAIN)
db.svc.cluster.local.      (search entry 2 — NXDOMAIN)
db.cluster.local.          (search entry 3 — NXDOMAIN)
db.ec2.internal.           (search entry 4 — NXDOMAIN)
db.                        (absolute — finally answers)
```

Every failed attempt is a real round trip to a real resolver, with a real
timeout if that resolver is slow rather than fast-failing — this is why a
single `db` lookup can silently cost 5x the latency of the same lookup
written as `db.` (a trailing dot forces an absolute, non-search lookup,
skipping straight to line 5) or of a name with five or more dots already
in it (which never triggers the search behavior at all). Read
`/etc/resolv.conf`'s `options ndots:N` and `search` lines before assuming
a "slow DNS" complaint is the resolver's fault rather than the query
count.

### Listening on `127.0.0.1` versus `0.0.0.0`

A socket bound to `127.0.0.1` accepts connections only from processes
sharing that same network namespace — its own loopback, nothing else,
ever. A socket bound to `0.0.0.0` accepts connections arriving on any of
the namespace's interfaces, loopback included. These are not "mostly the
same with an edge case": a service correctly running and correctly
healthy on `127.0.0.1` is, from every other network namespace, exactly as
unreachable as a service that was never started, and a firewall drop and
a `127.0.0.1` bind produce an identical externally-observed symptom.
`/proc/net/tcp`'s `local_address` field is where this is provable —
`00000000` accepts from anywhere, `0100007F` accepts from nowhere but
itself.

### TCP states, the handshake, and port exhaustion

The three-way handshake (`SYN` → `SYN-ACK` → `ACK`) leaves a client
socket in `SYN_SENT` until the second packet arrives; a socket stuck
there and never advancing to `ESTABLISHED` means either nothing answered
(no route, or a silent firewall drop) or a `RST` came back instead (a
connection actively refused — nothing listening on that address).
`TIME_WAIT` is the state a closing socket holds for roughly twice the
maximum segment lifetime specifically so a delayed duplicate packet from
the old connection cannot be mistaken for part of a new one reusing the
same four-tuple; under sustained high connection churn from one client
identity, the pool of ephemeral source ports can be exhausted by sockets
sitting in `TIME_WAIT`, and new outbound connections start failing with
no route or firewall problem anywhere. `ss -tan state time-wait | wc -l`
(or the busybox-safe count in **Strip the toolbox**, below) is the file
that proves it.

### `curl -v` as a protocol trace

`curl -v` prints its work in the order it happens, and each line names
the layer that either worked or didn't: `* Trying <ip>` is after DNS
already resolved (a hang before this line is a DNS problem); `* Connected
to <host> (<ip>) port <port>` is the TCP handshake completing (a hang or
refusal before this line is routing, firewall, or listener); `* SSL
connection using...` is the TLS handshake for HTTPS; `> GET / HTTP/1.1`
is the request `curl` sent; `< HTTP/1.1 200 OK` is the first line of the
actual response. Reading which line was the last one printed before a
hang or an error tells you which rung failed without needing anything
else.

### `openssl s_client` for certificate and SNI problems

`openssl s_client -connect host:443 -servername host` opens exactly the
TLS connection a browser or a load balancer health check would, and
prints the full certificate chain the server actually presented — the
common name, the SAN list, the issuer, and the validity window — plus the
negotiated protocol version and cipher. `-servername` sends SNI, the
hostname the client is asking for during the handshake itself; omitting
it is the single most common reason `openssl s_client` sees a different
(often self-signed, default, or wrong-domain) certificate than a real
client does on a server hosting more than one TLS domain.

### MTU and the black-hole symptom

When a path's actual MTU is smaller than what either endpoint believes,
small packets (a DNS query, a TLS handshake's early messages) go through
fine while larger ones (a big HTTP response body, a bulk file transfer)
simply vanish — a router along the path needs to fragment or send back
"packet too big" via ICMP, and if that ICMP message itself is filtered
somewhere, both endpoints wait forever with no error at all. "Small
requests work, large ones hang" with no firewall rule visible on either
end is the specific, memorable shape of this failure; `ping -M do -s
<size> <host>` (Do-not-fragment set, testing successively smaller sizes)
finds the actual usable MTU on the path.

### Reading `nftables`/`iptables` rules

The operator skill that matters here is reading, not writing: `nft list
ruleset` (or `iptables -L -n -v` on the legacy tool) prints every table,
chain, and rule currently loaded, in evaluation order — the first
matching rule in a chain wins, and a chain's own default policy (`ACCEPT`
or `DROP`) is what applies if nothing matches at all. A single `drop`
rule sitting on an `output` hook filtering by destination port is
completely invisible to `ip route`, to DNS, and to the application — the
only file that shows it is the ruleset itself.

### `tcpdump` — the two or three invocations that matter

`tcpdump -i any -n host <ip> and port <port>` captures exactly one
conversation, with `-n` skipping DNS lookups on captured addresses so the
capture doesn't itself generate the traffic you're trying to isolate.
Adding `-c 20` bounds it to 20 packets so it doesn't run forever
unattended. Seeing a `SYN` leave and no `SYN-ACK` ever return, from
`proxy`'s own interface, is the packet-level confirmation of a routing or
firewall problem; seeing the `SYN-ACK` come back but the connection still
fail at the application layer rules both of those out entirely.

## Lab

See `labs/day06/`. The goal: given the five-container fleet with exactly
one of DNS, route, firewall, listener, or application broken, name the
rung and fix only that rung. Success signal: `bash labs/day06/verify.sh`
exits `0`. Run `break.sh 1` first (then `2` through `5` in order, then
`random` for re-practice), and write the chain in `journal.md` **before**
touching a fix.

## Strip the toolbox

In `slim` — busybox `sh`, busybox `awk`, no `ss`, no `netstat` — find what
`app` is listening on using only `cat` and the hex decode from
`content/primers/proc-field-reference.md`:

```sh
awk '$4 == "0A" {print $2}' /proc/net/tcp
```

`$4` is the `st` field; `0A` is `LISTEN`. The result, e.g. `00000000:1F90`,
is `local_address:port` in hex — split on `:`, reverse the address bytes
per the primer's worked example (`0100007F` → `127.0.0.1`; `00000000` →
`0.0.0.0`), and convert the port from hex the same way the primer does
(`1F90` → `8080`, no byte-swap needed). This is the entire mechanism
behind `ss -ltn`'s listening-socket rows, run by hand with nothing but a
text file and busybox `awk`.

## Exercises

1. Decode this `/proc/net/tcp` line to `ip:port state`: local_address
   `0A00000A:0050`, st `0A`. **Hint:** reverse the address's hex byte
   pairs, not the port's; `0050` needs no byte-swap.
   **Solution sketch:** `0A00000A` reversed byte-pairs is `0A 00 00 0A` →
   `10.0.0.10`; `0050` = 80. `st 0A` is LISTEN. Result: `10.0.0.10:80
   LISTEN`.

2. A service answers `curl localhost` correctly from inside its own
   container but is unreachable from `proxy`. **Hint:** "its own
   container" and "from `proxy`" are two different network namespaces —
   check what the service is actually bound to.
   **Solution sketch:** the service is bound to `127.0.0.1`, which only
   accepts connections from within its own namespace's loopback;
   `/proc/net/tcp`'s `local_address` shows `0100007F`, not `00000000`, on
   its listening line. Nothing outside that one namespace can ever reach
   it, no matter how healthy it is internally.

3. Given `options ndots:5` and a four-entry `search` list, compute how
   many DNS queries resolving the bare name `db` generates in the worst
   case. **Hint:** `db` has zero dots, and zero is less than five.
   **Solution sketch:** zero dots is below the `ndots:5` threshold, so
   the resolver tries each of the 4 `search` suffixes in order first,
   then the name as an absolute lookup — 4 + 1 = **5** queries before an
   answer, assuming the first four all return NXDOMAIN.

4. `ip route get 10.0.5.20` prints `10.0.5.20 via 10.0.0.1 dev eth1 src
   10.0.0.7`. Name the interface and the source address the kernel chose.
   **Hint:** `dev` and `src` are two different fields answering two
   different questions.
   **Solution sketch:** interface `eth1`; the kernel would source the
   connection from `10.0.0.7` — the address bound to `eth1` that's in the
   same subnet as the next hop `10.0.0.1`.

5. Distinguish a DNS failure from a routing failure from a firewall drop,
   using exactly one command each. **Hint:** one of the three commands
   asks the kernel to decide something out loud, rather than just
   reading a file.
   **Solution sketch:** DNS — `getent hosts <name>` fails or times out.
   Routing — `ip route get <ip>` returns "Network is unreachable" (or a
   route to the wrong place). Firewall — `nft list ruleset` shows a
   `drop` rule matching the traffic, with the route itself intact.

6. A request hangs after the TCP handshake completes but before the
   first byte of the response arrives. Explain what this usually means.
   **Hint:** `curl -v`'s last printed line before the hang tells you
   which side is still working.
   **Solution sketch:** the connection itself is fine (DNS, route,
   firewall, and listener all checked out); the application accepted the
   connection but has not sent a response — it's blocked doing
   something (a slow downstream call, a lock, a deadlock) rather than
   refusing or erroring outright. This is rung 5's territory, not rungs
   1 through 4's.

## Anti-patterns / Common mistakes

- **Mistake 2** (trusting the summary tool): `ping` succeeding proves
  only that ICMP round-trips between two hosts — nothing about whether
  the target port has a listener, whether a firewall rule targets TCP
  specifically while leaving ICMP alone, or whether the application
  behind that port is healthy. "I pinged it and it's up" answers a
  narrower question than the one being asked, and answering the wrong
  question with confidence is worse than admitting the real one is still
  open.
- **Mistake 1** (memorising flags instead of the model): collecting
  `tcpdump` flags without the ladder that tells you *when* to reach for
  a packet capture at all is a stack of tools with no order of
  operations — `tcpdump` is rung 2/3's tool for confirming what the
  kernel already told you via `ip route get` and `nft list ruleset`; run
  first, not run instead of those two reads, it mostly reproduces
  information already sitting in a file.

## Where this shows up in AWS

ECS tasks in `awsvpc` mode each get their own elastic network interface
and, because of that, **their own network namespace and their own
`127.0.0.1`** — a sidecar container in the same task does not share the
application container's loopback the way containers on a single Docker
host with `network_mode: bridge` might lead you to expect. An assumption
carried over from a shared-host mental model ("localhost always reaches
my sidecar") silently breaks the moment a workload moves to `awsvpc`,
and it breaks exactly the way fault 4 does in this lab: correctly running,
completely unreachable.

Security groups producing a silent drop look, from the caller's side,
identical to a routing problem — no RST, no ICMP, just a hang until
timeout — because a security group's default behavior for non-matching
traffic is exactly that: silent. `ip route get` will show a perfectly
correct route on both ends; the only place the drop is visible at all is
the security group configuration itself, which is this environment's
equivalent of `nft list ruleset` and lives entirely outside the box.

The `ndots:5` cost is not theoretical inside a cluster: ECS tasks and EKS
pods commonly inherit a resolver configuration with `ndots:5` and a
multi-entry `search` list, so every bare-name lookup for another
in-cluster service pays the same up-to-five-query cost worked out above
— real, measurable added latency and DNS resolver load on every cold
lookup, invisible unless someone reads `/etc/resolv.conf` on the task.

NLB health checks failing against a target that is, by every application
log, perfectly healthy is fault 4's exact shape: the app bound to
`127.0.0.1` instead of `0.0.0.0` answers itself fine and refuses
everyone else, including the load balancer's health checker, which lives
outside the task's network namespace no matter how "local" the
infrastructure diagram makes it look.

## Teardown

Full checklist: `labs/day06/teardown.md`. In short: run `verify.sh` to
confirm no fault remains active, confirm `/etc/resolv.conf`, the routing
table, `nft list ruleset`, and `app`'s listener are all back to their
default fleet state, and leave the fleet running for Day 7.
