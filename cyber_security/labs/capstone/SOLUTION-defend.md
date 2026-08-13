# Capstone — Full Defense Walkthrough (Day 21)

## Authorized use only

Same notice as `README.md`. Every fix below is re-verified against the exact same
attack payloads `SOLUTION-attack.md` used — nothing here is a claim without a captured
before/after.

## A note on how this was verified

Each fix was applied to an isolated copy of the affected file, rebuilt as its own
image, and swapped in for the running container (`docker run ... --network-alias
webapp/host`, attached to the same `cyberlab` / `internal` / `imds` networks this
lab's `docker-compose.yml` defines) — then the *exact* Day 20 payload was re-sent and
the *exact* real output below was captured. `docker compose config -q` also passes on
the unmodified compose file. The Dockerfile/app.py snippets below are the literal edits
applied.

---

## Fix 1 — Parameterize the injection (Finding CAP-5, SQL injection)

**Before** (`webapp/app.py`, `login()`):

```python
query = (
    f"SELECT username, role FROM users "
    f"WHERE username='{username}' AND password='{password}'"
)
row = db.execute(query).fetchone()
```

**After:**

```python
query = "SELECT username, role FROM users WHERE username=? AND password=?"
row = db.execute(query, (username, password)).fetchone()
```

**Re-attack, exact Day 20 payload:**

```sh
curl -s -c /tmp/b.txt -b /tmp/b.txt -X POST webapp:5000/login \
  --data-urlencode "username=admin' -- " --data-urlencode 'password=anything'
```

**Before:** `{"role":"admin","status":"logged in","username":"admin"}`
**After (captured):** `{"error":"invalid username or password"}`

**Why this specific fix, not just "sanitize the input":** a parameterized query sends
the SQL text and the data as two separate things to SQLite — the `'`, `--`, and every
other character in `username` are treated as *literal data to compare*, never as SQL
syntax, no matter what they contain. There is no blocklist to bypass because there is
no string-splicing step at all. **Confirmed no regression:** a normal registered
account (`normaluser` / `hunter2`) still logs in successfully against the same fixed
code — the fix removes the *vulnerability*, not the *feature*.

## Fix 2 — Fix access control (Finding CAP-1, broken access control)

**Before** (`webapp/app.py`, `diagnostics()`):

```python
if "user" not in session:
    return "login required", 401
```

**After:**

```python
if session.get("role") != "admin":
    return "admin role required", 403
```

**Re-attack, exact Day 20 payload** (as a freshly self-registered `user` account):

```sh
curl -s -b /tmp/a.txt 'webapp:5000/admin/diagnostics?host=127.0.0.1'
```

**Before:** a normal ping response, HTTP 200.
**After (captured):** `admin role required` (HTTP 403).

This one-line change closes the door Path A's *entire remaining chain* (command
injection, credential leak, pivot, host privesc) walked through — none of those later
bugs stop existing, but a plain `user` session can no longer reach the endpoint that
exposes them.

## Fix 3 — The same "parameterize/never shell out to a string" principle, applied to command injection (Finding CAP-2)

**Before** (`webapp/app.py`, `diagnostics()`):

```python
result = subprocess.getoutput(f"ping -c 1 -W 2 {host}")
```

**After:**

```python
proc = subprocess.run(
    ["ping", "-c", "1", "-W", "2", host],
    capture_output=True, text=True, timeout=5,
)
result = proc.stdout + proc.stderr
```

**Re-attack, exact Day 20 payload** (hypothetically reaching this code — Fix 2 above
already blocks non-admins from getting here at all; this fix independently blocks the
injection itself, defense-in-depth, in case anything else ever calls this function with
attacker-influenced input):

```sh
curl -s -b /tmp/a.txt -G 'webapp:5000/admin/diagnostics' \
  --data-urlencode 'host=127.0.0.1; cat /opt/webapp/.internal/ops-notes.txt'
```

**Before:** ping output followed by the leaked `ops-notes.txt` contents.
**After (captured, unit-level — the whole malicious string handed to `ping` as ONE
argument):**

```
STDOUT:
STDERR: ping: 127.0.0.1; cat /opt/webapp/.internal/ops-notes.txt: Name or service not known
```

`ping` tries to resolve the *entire* string (including the `;` and everything after
it) as a single hostname and fails cleanly — there is no shell in this call chain at
all anymore, so `;` has no special meaning to anything. This is genuinely a second,
independent fix from Fix 2: Fix 2 stops *who* can reach this code; Fix 3 stops *what
that code can be tricked into doing* even if reached. Applying only one leaves the
other bug fully live.

## Fix 4 — Enforce IMDSv2 + least-privilege role (Findings CAP-6 SSRF, CAP-7 IMDSv1)

**IMDSv2, zero webapp code changes required:**

```sh
IMDS_MODE=v2 docker compose up -d --force-recreate fake-imds
```

**Re-attack, exact Day 20 payload**, with a real admin session (Fix 1/2 not yet
applied, to isolate this fix's effect specifically):

```sh
curl -s -b /tmp/b.txt -G 'webapp:5000/admin/fetch' \
  --data-urlencode 'url=http://169.254.169.254/latest/meta-data/iam/security-credentials/lab-capstone-role'
```

**Before (`IMDS_MODE=v1`):** the full fake credentials JSON.
**After (`IMDS_MODE=v2`, captured):**

```
401 Unauthorized -- a valid IMDSv2 session token is required (PUT /latest/api/token first, then send it back as X-aws-ec2-metadata-token). See content/day21-capstone-defend.md.
```

**Why this specific payload fails now, and what still could succeed:** `/admin/fetch`
performs a plain `requests.get(url)` with no attacker-controlled headers — it cannot
also perform the required `PUT /latest/api/token` step first, so this exact SSRF shape
is now insufficient. This is IMDSv2's real value: it does not make SSRF impossible, it
makes a plain GET-relay SSRF (the overwhelmingly common shape, and the only shape
`/admin/fetch` offers) insufficient to reach credentials. Residual risk, named
honestly: an SSRF bug in code that legitimately *needs* to talk to IMDS itself (and so
already performs the PUT+token dance for its own normal operation) could still be
abused to relay a "logged in" request. `/admin/fetch` here has no such legitimate need
— removing the endpoint's ability to reach `169.254.169.254` at all (an explicit
denylist, or simply not attaching this service to the `imds` network) is the deeper
fix; IMDSv2 is the AWS-wide baseline control that helps even where that deeper,
app-specific fix hasn't shipped yet.

**Least-privilege role**, for the real-AWS variant (`setup.sh --with-aws`): compare
`policies/iam-policy-before.json` (`s3:*` on `Resource: "*"`) against
`policies/iam-policy-after.json` (`s3:GetObject`/`s3:ListBucket` scoped to exactly the
one bucket `setup.sh` created). A stolen credential under the "after" policy can only
ever read that one bucket — it cannot enumerate or touch any other bucket in the
account, list IAM entities, or do anything else `s3:*`/`Resource:*` would have allowed.
This is a compensating control for the SSRF bug itself, not a fix for it — the
credential can still be stolen; least privilege bounds what stealing it is worth.

## Fix 5 — Add detection

```sh
./detection/detect.sh
```

Scans `logs/webapp/access.log` for the four signature classes: SQL-injection-shaped
`/login` bodies, command-injection-shaped `/admin/diagnostics` requests,
SSRF-to-`169.254.169.254` `/admin/fetch` requests, and non-admin sessions reaching
`/admin/*` at all. Run every payload from `SOLUTION-attack.md` once with logging
enabled, then:

```sh
./detection/detect.sh
```

**Expected:** all four `---` sections print at least one matching line, ending in
`DETECT_OK`. This is intentionally simple, signature-based detection (grep patterns,
not a real correlation engine) — see Drill 3 below for its blind spots.

---

## Re-running the full Day 20 chain against the fully hardened environment

With all four code/config fixes applied (Fixes 1–4) and IMDS_MODE=v2:

- **Path A:** register succeeds (unchanged — that's a feature, not a bug); `GET
  /admin/diagnostics` returns `403 admin role required` for the low-priv session before
  the command-injection payload is ever evaluated. Path A is blocked at Fix 2, and
  independently would also be blocked at Fix 3 if anything else ever reached that code.
- **Path B:** `POST /login` with the injection payload returns `{"error":"invalid
  username or password"}` — no admin session is ever obtained, so `/admin/fetch` is
  never even reachable. Path B is blocked at Fix 1, and independently would also be
  blocked at Fix 4 (IMDSv2) if an admin session were obtained by some other means.

Both independent sub-chains fail at their first stage; both also have a second,
independent layer of defense further down the chain — genuine defense-in-depth, not a
single choke point.

## Teardown

```sh
cd cyber_security/labs/capstone
./teardown.sh                                          # Docker
./teardown.sh --with-aws --bucket <name-from-setup>     # if you ran --with-aws
```

## Drills — with solutions

### Drill 1 — Map each Day 20 stage to the control that stops it

**Hint:** go stage by stage through `SOLUTION-attack.md`'s summary table and name the
one Fix (1–5 above) that closes it.

**Solution sketch:**

| Day 20 stage | Control |
|---|---|
| 2a — broken access control | Fix 2 (role check on `/admin/diagnostics`) |
| 2b — command injection | Fix 3 (argument-list `subprocess.run`) |
| leaked credential | not re-demonstrated live here — the real fix is rotating the credential and never placing one in a web root at all (Day 10's future secrets-sprawl lesson); Fixes 2 and 3 already block the path that would have discovered it |
| 3 — lateral movement / privesc | Fix — remove the `sudoers.d` rule on `host` entirely (captured above: `sudo: a password is required`) |
| 2c — SQL injection | Fix 1 (parameterized query) |
| 4 — SSRF / IMDSv1 | Fix 4 (IMDSv2) |

### Drill 2 — Prove one control works (before/after)

**Hint:** pick the one you're least sure about and re-run its exact `curl` from
`SOLUTION-attack.md` against both the vulnerable and hardened builds — don't just read
this file's captured output, reproduce it.

**Solution sketch:** the fullest before/after in this file is Fix 1 (SQL injection):
before, `admin' -- ` logs in as `admin` with zero password knowledge; after, the
identical payload returns `{"error":"invalid username or password"}`, while a normal
account (`normaluser`/`hunter2`) still logs in successfully on the same fixed code —
proving the fix removed the *vulnerability* specifically, not the *login feature*
generally.

### Drill 3 — What detection fires for the residual risk

**Hint:** Fix 4's own writeup above names a residual risk explicitly — ask what
`detect.sh` would or wouldn't catch if that specific residual risk were exploited
instead of the exact Day 20 payload.

**Solution sketch:** `detect.sh`'s `[SSRF]` rule greps for the literal string
`169.254.169.254` in `/admin/fetch` requests — it would catch an attacker probing IMDS
directly, exactly as Day 20 did. It would **not** catch a more patient attacker who
targets a *different* internal-only address `/admin/fetch` can also reach (any other
service on the `imds` or wider network SSRF could reach, if one existed) — the
detection rule is scoped to the one signature this lab's specific attack used, not to
"SSRF in general." This is Section 1's fidelity-vs-noise tradeoff made concrete: a
tighter, more specific rule has fewer false positives but more blind spots; a broader
rule (e.g. "any `/admin/fetch` request to a non-public IP range") would catch more
variants at the cost of needing a real IP-range check instead of a literal string
match — exactly the kind of rule Day 11's future content builds out properly.
