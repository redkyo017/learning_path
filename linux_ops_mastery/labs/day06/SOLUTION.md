# Day 6 — model diagnosis chains, all five rungs

Follows `journal.md`'s chain template, claim by claim, with one addition
this day asks for: each chain ends with the single command that would have
distinguished this fault from the other four in one step. Compare your own
chain against these — not as answers to copy, but as the shape a complete
chain takes.

## The ladder

| Rung | Question | Command | The file that proves it |
|---|---|---|---|
| 1. DNS | Does the name resolve to an address? | `getent hosts app` | `/etc/resolv.conf`, `/etc/nsswitch.conf` |
| 2. Route | Does the kernel have a path to that address? | `ip route get <addr>` | `/proc/net/route` |
| 3. Firewall | Is a rule dropping the packet on the way out? | `nft list ruleset` | `/proc/net/tcp` (peer stays `SYN_SENT`, never `ESTABLISHED`) |
| 4. Listener | Is anything actually bound to that port? | `cat /proc/net/tcp` (or `ss -ltn`) | `/proc/net/tcp`'s `local_address` |
| 5. Application | Does the app answer correctly once connected? | `curl -v http://app:8080/healthz` | the HTTP status line itself |

Walk it top to bottom. A `NO` at any rung is the diagnosis; a `YES` moves you
to the next rung down.

---

### Day 6 — fault 1: proxy cannot resolve `app`

**Symptom (verbatim, no interpretation):**
`http://localhost:8080/ through proxy returns nothing useful.`

**Resource class:** fd table (a socket is a descriptor), plus the network
namespace

**Chain of evidence:**
1. Claim: `proxy` itself is up and accepting connections — the failure is
   not "nginx is down." | Proof: `docker compose -p linuxops ps proxy` →
   state `Up`.
2. Claim: the request never gets a response from `app` — no 200, no 502,
   nothing. | Proof: `docker compose -p linuxops exec ws curl -v
   http://proxy/` hangs or errors before any HTTP status line appears.
3. Claim: `proxy`'s own name resolution for `app` is broken right now. |
   Proof: `docker compose -p linuxops exec proxy getent hosts app` fails
   (times out against an address nothing answers).
4. Claim: the resolver it's using is not Docker's own. | Proof: `docker
   compose -p linuxops exec proxy cat /etc/resolv.conf` → `nameserver
   10.255.255.1`, not `127.0.0.11`.
5. Claim: this bad resolver is genuinely the one nginx loaded, not just a
   stale file nginx never picked up. | Proof: `content/primers` has no
   file for "what resolver nginx currently has loaded" — there isn't one;
   `seed/nginx.conf`'s own comment records that `resolver` is read at
   config-load time, which is exactly why claim 3 (a live, current
   `getent` failure) is the evidence, not a reading of the config file.

**Diagnosis:**
`proxy`'s `/etc/resolv.conf` points at `10.255.255.1`, an address nothing
answers, and nginx was reloaded after the file changed, so it is genuinely
using that resolver. `app`'s name never resolves, so nginx cannot even open
a TCP connection to try — the request fails before rung 2 is ever reached.

**Fix applied:**
Rewrote `/etc/resolv.conf` back to `nameserver 127.0.0.11` (Docker's
embedded resolver) and ran `nginx -s reload` — the same two steps that
caused the fault, in reverse. The reload is not optional here either.

**Proof the fix worked (same file re-read):**
`getent hosts app` on `proxy` now returns an address promptly.
`curl -s -o /dev/null -w '%{http_code}' http://proxy/` from `ws` → `200`.

**What I would check first next time:**
Whether a "fix" actually included the reload. A resolv.conf edit that
looks applied but was never reloaded is the single most common way this
exact fault silently survives its own fix.

**Minimum distinguishing command:** `getent hosts app` on `proxy`, alone.
It fails only under fault 1 — every other fault leaves DNS intact.

---

### Day 6 — fault 2: no route to `app`'s address

**Symptom (verbatim, no interpretation):**
`http://localhost:8080/ through proxy returns nothing useful.`

**Resource class:** fd table (a socket is a descriptor), plus the network
namespace

**Chain of evidence:**
1. Claim: DNS is not the problem. | Proof: `getent hosts app` on `proxy`
   returns an address immediately, e.g. `172.20.0.5  app`.
2. Claim: the kernel has no path to that specific address. | Proof: `ip
   route get 172.20.0.5` on `proxy` → `RTNETLINK answers: Network is
   unreachable`.
3. Claim: this is not "no routes at all" — the default and connected
   routes are both still present. | Proof: `ip route show` lists a
   `default` line and the `linuxops_net` subnet as `scope link`; only one
   destination fails.
4. Claim: a more specific route is overriding the connected one for this
   single address. | Proof: `ip route show type unreachable` → `unreachable
   172.20.0.5 scope host` — a `/32` beats the broader subnet route by
   longest-prefix match, exactly the decision procedure `content/day06.md`
   describes.
5. Claim: this route, not a firewall rule, is the cause. | Proof: `nft
   list ruleset` on `proxy` shows no table at all — nothing to drop the
   packet; the kernel refuses to send it in the first place.

**Diagnosis:**
An `unreachable` route was added for `app`'s exact address. Longest-prefix
match means the kernel checks this `/32` before the broader
`linuxops_net` connected route, refuses to send anything to it, and
returns `ENETUNREACH` immediately — no SYN ever leaves the box, which is
also why this differs from fault 3 (a real SYN is sent and silently
dropped downstream).

**Fix applied:**
`ip route del unreachable 172.20.0.5` on `proxy`.

**Proof the fix worked (same file re-read):**
`ip route get 172.20.0.5` now shows a real route via the connected subnet.
`curl -s -o /dev/null -w '%{http_code}' http://proxy/` from `ws` → `200`.

**What I would check first next time:**
Whether the address changed since the route was added — `app` being
recreated (a redeploy, a crash restart) can hand it a new address, and a
stale `/32` route left behind then targets nothing real, which reads as
"fixed" by accident rather than by intent.

**Minimum distinguishing command:** `ip route get <app-ip>` on `proxy`.
`RTNETLINK answers: Network is unreachable` happens only under fault 2 —
DNS already resolved the address to get here, ruling out fault 1, and a
real route (even a bad one) exists under every other fault.

---

### Day 6 — fault 3: a firewall rule drops the connection

**Symptom (verbatim, no interpretation):**
`http://localhost:8080/ through proxy returns nothing useful.`

**Resource class:** fd table (a socket is a descriptor), plus the network
namespace

**Chain of evidence:**
1. Claim: DNS and routing are both fine. | Proof: `getent hosts app` on
   `proxy` resolves promptly, and `ip route get <app-ip>` shows a normal
   route via `linuxops_net`.
2. Claim: a connection attempt to `app:8080` never completes the
   handshake. | Proof: `curl -v http://app:8080/healthz` from `proxy` hangs
   until `proxy_connect_timeout` (2s, per `seed/nginx.conf`), with no
   response.
3. Claim: the socket is stuck in `SYN_SENT`, not `ESTABLISHED` — the
   packet left but nothing came back. | Proof: while the connection
   attempt is in flight, `cat /proc/net/tcp` on `proxy` shows a line whose
   `st` field (see `content/primers/proc-field-reference.md`, `## /proc/net/tcp`)
   is `02` (`SYN_SENT`), never advancing to `01` (`ESTABLISHED`).
4. Claim: something on `proxy` is dropping its own outbound traffic to
   that port. | Proof: `nft list ruleset` on `proxy` → a `table inet
   day06` with a `chain output` rule `tcp dport 8080 drop`.

**Diagnosis:**
An nftables rule on `proxy`'s own output hook drops every packet with
destination port 8080 before it leaves the box. The SYN is generated and
then discarded by the kernel's own netfilter hook, which is exactly why
routing (rung 2) checks out clean but the handshake still never completes
— a firewall drop and a routing failure produce the identical
`SYN_SENT`-forever symptom from a `curl -v` trace, and the file that tells
them apart is `nft list ruleset`, not `/proc/net/tcp`.

**Fix applied:**
`nft delete table inet day06` on `proxy`.

**Proof the fix worked (same file re-read):**
`nft list ruleset` on `proxy` shows no `day06` table. A fresh `curl -v
http://app:8080/healthz` from `proxy` completes the handshake and returns
`200 healthy`. `curl` through `proxy` from `ws` → `200`.

**What I would check first next time:**
Whether the rule was scoped to exactly the intended chain and port — a
rule read out of context ("there's a drop rule somewhere") is not the same
claim as "this specific rule, on this specific hook, matches this
specific traffic," and only the second one is provable from `nft list
ruleset`.

**Minimum distinguishing command:** `nft list ruleset` on `proxy`. A
matching drop rule appears only under fault 3 — DNS and routing already
checked out clean to get here.

---

### Day 6 — fault 4: `app` is bound to `127.0.0.1`

**Symptom (verbatim, no interpretation):**
`http://localhost:8080/ through proxy returns nothing useful.`

**Resource class:** fd table (a socket is a descriptor), plus the network
namespace

**Chain of evidence:**
1. Claim: DNS, routing, and the firewall are all fine. | Proof: `getent
   hosts app`, `ip route get <app-ip>`, and `nft list ruleset` on `proxy`
   all check out clean.
2. Claim: the connection to `app:8080` is refused immediately, not
   timed out. | Proof: `curl -v http://app:8080/healthz` from `proxy` →
   `Connection refused` in well under a second — a refused connection
   means a SYN reached the box and got a RST back, unlike faults 2 and 3.
3. Claim: nothing is listening on `app`'s real address, only on loopback.
   | Proof: on `app`, `cat /proc/net/tcp` (no `ss`, no `netstat` on
   Alpine) shows a line with `local_address` `0100007F:1F90` and `st`
   `0A` (LISTEN) — decoding per `content/primers/proc-field-reference.md`'s
   worked example, `0100007F` reverses to `127.0.0.1`, not `0.0.0.0`
   (`00000000`).
4. Claim: this is the process's own bind address, not a stale socket. |
   Proof: `docker compose -p linuxops exec app env | grep BIND_ADDR` →
   `BIND_ADDR=127.0.0.1`.

**Diagnosis:**
`app` is listening only on `127.0.0.1:8080` — reachable from inside its
own network namespace, invisible from every other container, including
`proxy`, which sits in a different namespace entirely. The TCP stack
correctly refuses the connection (nothing is bound on the address `proxy`
actually reaches), which is why this fault presents as an instant refusal
rather than the silent hang of faults 2 and 3.

**Fix applied:**
Recreated `app` with `BIND_ADDR=0.0.0.0` (the compose file's own default —
`docker compose -p linuxops up -d --force-recreate app`).

**Proof the fix worked (same file re-read):**
`cat /proc/net/tcp` on `app` now shows `local_address` `00000000:1F90`.
`curl` through `proxy` from `ws` → `200`.

**What I would check first next time:**
What actually set `BIND_ADDR` to `127.0.0.1` — an environment default
changed in a task definition or a compose override survives a restart and
will reproduce this on every redeploy, not just this once.

**Minimum distinguishing command:** `cat /proc/net/tcp` on `app`, decoding
`local_address` for the `:1F90` line. `0100007F:1F90` happens only under
fault 4 — every other fault leaves the listener itself alone.

---

### Day 6 — fault 5: `app` answers, but wrongly

**Symptom (verbatim, no interpretation):**
`http://localhost:8080/ through proxy returns nothing useful.`

**Resource class:** fd table (a socket is a descriptor), plus the network
namespace

**Chain of evidence:**
1. Claim: DNS, routing, the firewall, and the listener are all fine. |
   Proof: `getent hosts app` resolves, `ip route get <app-ip>` shows a
   normal route, `nft list ruleset` is clean, and `cat /proc/net/tcp` on
   `app` shows `local_address` `00000000:1F90`, `st` `0A`.
2. Claim: a TCP connection to `app:8080` succeeds. | Proof: `curl -v
   http://app:8080/healthz` from `proxy` shows `Connected to app
   (172.20.0.5) port 8080` in the trace — the handshake completed.
3. Claim: the application itself returns an error status, not a
   transport-layer failure. | Proof: the same `curl -v` shows `< HTTP/1.1
   502` in the response headers, not a connection error.
4. Claim: the failure is sticky — persistent, not a one-off. | Proof: a
   second `curl` a few seconds later still returns `502`.

**Diagnosis:**
`app` armed sticky failure mode via `GET /fail?code=502&sticky=1`, which
poisons `/` and `/healthz` — exactly the two paths a proxy and a health
check use — until explicitly cleared. Every layer below the application
(DNS, route, firewall, listener) is healthy; the TCP handshake completes
and a real HTTP response comes back, just the wrong one.

**Fix applied:**
`curl 'http://app:8080/fail?code=200'` from `proxy` or `ws` — any
`code=200` clears sticky mode regardless of the `sticky` parameter, per
`app.py`'s own contract.

**Proof the fix worked (same file re-read):**
`curl -v http://app:8080/healthz` now shows `< HTTP/1.1 200` and body
`healthy`. `curl` through `proxy` from `ws` → `200`.

**What I would check first next time:**
Whether `/fail` was armed deliberately (a chaos test, another lab) or by
a bug in something that calls it — the sticky flag persists until
cleared, so a forgotten arm from an earlier session reads identically to
a fresh incident.

**Minimum distinguishing command:** `curl -v http://app:8080/healthz`. A
completed handshake with a non-200 status happens only under fault 5 —
every other fault fails before a real HTTP status line ever comes back.
