# Day 4 Lab — Brute Force a Login and Forge a JWT Against `target`

## Authorized use only

This lab's `target` container is a deliberately weak auth app running nothing but a
tiny Flask API with two planted vulnerabilities (weak login, guessable JWT secret).
Only ever point the attacker toolbox at containers this learning path starts on the
`cyberlab` docker network — here or in any other day's lab — or your own AWS sandbox
account (Phase 3+). Never brute-force, crack, or forge tokens against a system you
don't own or don't have explicit written authorization to test.

## What this lab is

`labs/day04/docker-compose.yml` adds a single `target` service to the shared
`cyberlab` network created by [`labs/base`](../base/README.md). It does **not**
redefine the `attacker` service — that container is shared infrastructure, already
running from Day 0.

`target` (see [`target/app.py`](target/app.py)) is a small Flask app with:

- **`POST /login`** — a classic HTML-form login (`admin` / `letmein`, in-memory user
  table). No rate limiting, no account lockout, no CSRF protection — accepts unlimited
  guesses from anywhere, at any speed. This is what `hydra` attacks.
- **`POST /api/token`** — given valid credentials, issues a real, standards-shaped
  compact JWT (`header.payload.signature`, HS256, base64url) whose signature is
  `HMAC-SHA256(JWT_SECRET, header + "." + payload)`. `JWT_SECRET` is a short,
  dictionary-word string (`"cyberlab"`) — guessable offline, without ever touching the
  network again once you have one valid token to test candidate secrets against.
- **`GET /api/admin`** — requires a Bearer JWT with `"role": "admin"` in its claims;
  returns a flag if so. The only account that exists (`admin`) is issued tokens with
  `"role": "user"` — reaching `/api/admin` legitimately is impossible without forging a
  new token.

No ports are published to the host — everything is reached container-to-container, by
service name (`target`), from the `attacker` container over `cyberlab`.

This lab also ships three files that are **not** staged by compose at all:
[`jwt_forge.py`](jwt_forge.py) (a dependency-free JWT decode/crack/forge script — see
its own docstring), [`passwords.txt`](passwords.txt) (a small login-brute-force
wordlist), and [`secrets.txt`](secrets.txt) (a small JWT-secret-guessing wordlist). Get
them into the attacker container with a plain `cp` — see Setup below. No extra
container is needed for that: `labs/base/loot/` is just a host directory the
already-running `attacker` container has bind-mounted at `/loot`.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's target:

```sh
cd cyber_security/labs/day04
docker compose up -d --build
```

Then stage this lab's script and wordlists into the shared loot directory (plain `cp`,
no container involved — `../base/loot/` is the same host directory already mounted at
`/loot` inside the running `attacker` container):

```sh
mkdir -p ../base/loot/day04
cp jwt_forge.py passwords.txt secrets.txt ../base/loot/day04/
```

## Running `docker compose exec` for this lab

Exactly like every earlier day: `attacker` is defined in
`labs/base/docker-compose.yml`, not in this lab's compose file. Run every
`docker compose exec attacker ...` command **from `labs/base`**, not from
`labs/day04` (running it from `labs/day04` fails with `service "attacker" is not
running`, since Compose looks for an `attacker` service inside this lab's own project,
and there isn't one):

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s target:5000/"
```

## Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "hydra -s 5000 -l admin -P /loot/day04/passwords.txt target http-post-form '/login:username=^USER^&password=^PASS^:F=Invalid username or password' -o /loot/day04/hydra_out.txt >/dev/null 2>&1; grep -qi 'login:' /loot/day04/hydra_out.txt && echo ATTACK_OK"
```

**Expected output:** `ATTACK_OK`.

**Note on hydra's exit code:** this command deliberately does **not** chain `&& echo
ATTACK_OK` directly off hydra's own exit status. Hydra (`hydra -h`, and some real
invocations) can exit non-zero by design even when it found valid credentials — gating
success on hydra's exit code is unreliable. Instead, hydra's report is written to a
file with `-o`, on its own statement (`;`, not `&&`), and the verify's pass/fail
condition comes entirely from `grep`'s exit code against that file's actual content.
Full detail and a captured example of the failure mode this avoids:
[`labs/day04/SOLUTION.md`](SOLUTION.md).

**Note on the port:** hydra's http-post-form module defaults to port 80. This target
listens on `5000` — omit `-s 5000` and every candidate fails with `[ERROR] ... cannot
connect`, which looks like a broken lab but is just the wrong port.

## Walkthrough

1. Bring up `labs/base` and `labs/day04`, and stage the loot files, as above.
2. From `labs/base`, work through Section 2 of
   [`content/day04-auth.md`](../../content/day04-auth.md) in order:
   - Step 1 — recon `target` with `curl` to see its routes.
   - Step 2 — brute force `/login` with `hydra` using `passwords.txt`, recovering
     `admin` / `letmein`.
   - Step 3 — use those credentials against `/api/token` to get a legitimate,
     `role:user` JWT; decode it with `jwt_forge.py decode` to read its claims.
   - Step 4 — crack the JWT's HMAC secret offline with `jwt_forge.py crack` against
     `secrets.txt`.
   - Step 5 — forge a new `role:admin` token with `jwt_forge.py forge` and use it
     against `/api/admin` to get the flag.
3. Run the verify command above and confirm `ATTACK_OK`.
4. Read Section 3 (defense) and try uncommenting the lockout block and hardening the
   JWT secret yourself, rebuilding, and re-running the attacks, before checking
   `SOLUTION.md`.

Full expected output for every command above, including the exact hydra
http-post-form string, the forged JWT, the cracked credentials, and both confirmed
before/after defense runs: [`labs/day04/SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day04
docker compose down
```

This removes only `target` — `labs/base`'s `attacker` container, the `cyberlab`
network, and the staged files under `labs/base/loot/day04/` are untouched, since
they're shared infrastructure other days depend on too. Tear down `labs/base`
separately (`cd ../base && ./down.sh`) only once you're done with the whole session.
