# Day 8 Lab — Injection & XSS Against DVWA

## Authorized use only

This lab's `dvwa` container is **DVWA (Damn Vulnerable Web Application)**, a
widely-used, intentionally vulnerable web app built for exactly this kind of hands-on
practice. Only ever point the attacker toolbox (`sqlmap`, `curl`, manual payloads) at
containers this learning path starts on the `cyberlab` docker network — here or in any
other day's lab — or your own AWS sandbox account (Phase 3+). Never run SQL injection,
command injection, or XSS payloads against a real website, API, or application you
don't own or don't have explicit written authorization to test.

## What this lab is

`labs/day08/docker-compose.yml` adds a single `dvwa` service to the shared `cyberlab`
network created by [`labs/base`](../base/README.md). It does **not** redefine the
`attacker` service — that container is shared infrastructure, already running from
Day 0.

`dvwa` is the [`vulnerables/web-dvwa`](https://hub.docker.com/r/vulnerables/web-dvwa)
image — a single container bundling Apache, PHP, and MySQL, listening on port 80
inside the container. It ships DVWA's standard vulnerability set at four selectable
**security levels** (`low`/`medium`/`high`/`impossible`), each backed by a genuinely
different PHP implementation of the same page. Today's Attack Lab uses:

- **SQL Injection** (`/vulnerabilities/sqli/`) — a `first_name`/`last_name` lookup by
  `id`, vulnerable to error-based probing and UNION-based dumping at `low`.
- **Command Injection** (`/vulnerabilities/exec/`) — a "ping this host" feature that
  shells out to `ping` with unsanitized input at `low`.
- **XSS (Reflected)** (`/vulnerabilities/xss_r/`) — a `name` parameter echoed straight
  into the page.
- **XSS (Stored)** (`/vulnerabilities/xss_s/`) — a guestbook whose messages are saved
  and re-rendered, unsanitized, on every future page load.

No ports are published to the host — everything is reached container-to-container, by
service name (`dvwa`), from the `attacker` container over `cyberlab`.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's target:

```sh
cd cyber_security/labs/day08
docker compose up -d
```

Give DVWA's bundled MySQL a few seconds to finish starting before the next step (its
entrypoint starts MySQL and Apache together; a setup request that arrives too early
just needs a retry).

Stage this lab's setup script into the shared loot directory (plain `cp`, no container
involved — `../base/loot/` is the same host directory already mounted at `/loot`
inside the running `attacker` container):

```sh
mkdir -p ../base/loot/day08
cp dvwa_setup.sh ../base/loot/day08/
```

## Login / setup and the security level — done entirely via `curl`, no browser needed

Every other day's lab in this path targets a container purely from inside the
`attacker` container with `curl`/tool commands — today keeps that exact pattern rather
than switching to a host browser, even though DVWA is normally driven through a
browser UI. [`dvwa_setup.sh`](dvwa_setup.sh) reproduces the same three steps a browser
walkthrough would do you'd otherwise click through by hand:

1. **`POST /setup.php`** with `create_db=Create / Reset Database` — creates DVWA's
   MySQL schema and seed data (including the `users` table Section 2's SQLi dumps).
   Idempotent — safe to re-run.
2. **`POST /login.php`** as `admin` / `password` (DVWA's fixed default account),
   first `GET`-ing the login page to extract its CSRF `user_token` field.
3. **`POST /security.php`** with `security=<level>` to select `low`, `medium`, `high`,
   or `impossible` for the session's cookie jar.

Run it from inside the attacker container (from `labs/base`, where `attacker` is
defined):

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "bash /loot/day08/dvwa_setup.sh low"
```

It prints diagnostic progress to stderr and, on success, a single line to stdout:

```
Cookie: PHPSESSID=<value>; security=low
```

Capture that into a shell variable and reuse it with every subsequent `curl`/`sqlmap`
command's `-H "Cookie: ..."` / `--cookie="..."` — every command in
[`content/day08-injection-xss.md`](../../content/day08-injection-xss.md) and
`SOLUTION.md` does exactly this:

```sh
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#"
'
```

**Re-run `dvwa_setup.sh impossible`** (instead of `low`) any time you want the Defense
Lab's re-verified security level — it's the same script, same idempotent flow, just a
different final argument.

**If login fails or the field names have drifted:** `dvwa_setup.sh` warns on stderr if
the login response doesn't look like a logged-in page, and leaves its temp HTML files
in place briefly for inspection — the script's own comments name exactly which
selectors (`username`, `password`, `user_token`, security dropdown) it assumes. DVWA's
login/setup/security-page markup has been stable across versions for years, but if
your pulled image differs, `curl`-ing each page yourself first (mirroring Day 1's
recon-before-you-attack habit) will show you the real field names to substitute.

## Running `docker compose exec` for this lab

Exactly like every earlier day: `attacker` is defined in
`labs/base/docker-compose.yml`, not in this lab's compose file. Run every
`docker compose exec attacker ...` command **from `labs/base`**, not from
`labs/day08` (running it from `labs/day08` fails with `service "attacker" is not
running`, since Compose looks for an `attacker` service inside this lab's own project,
and there isn't one):

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s dvwa/ | head -5"
```

## Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#" --cookie="$COOKIE" --batch --dbs 2>/dev/null | grep -qi "available databases" && echo ATTACK_OK
'
```

**Expected output:** `ATTACK_OK`. The exact `sqlmap` URL, cookie value from a real run,
and security level this verify command depends on are documented in
[`SOLUTION.md`](SOLUTION.md), per this lab's scope: this task's own validation is
**static only** (`docker compose config -q`) — the live attack chain above is the
documented, reproducible recipe for you to run and confirm yourself, not something
re-run and captured as part of building this lab.

## Walkthrough

1. Bring up `labs/base` and `labs/day08`, and stage `dvwa_setup.sh`, as above.
2. From `labs/base`, work through Section 2 of
   [`content/day08-injection-xss.md`](../../content/day08-injection-xss.md) in order:
   recon the SQLi point manually, find the column count and hand-craft a UNION dump,
   then automate the same finding with `sqlmap`; command injection against `/exec/`;
   reflected XSS against `/xss_r/`; stored XSS against `/xss_s/`.
3. Run the verify command above and confirm `ATTACK_OK`.
4. Read Section 3 (defense) and re-run the same attacks against `dvwa_setup.sh
   impossible` yourself, comparing the response before/after, before checking
   `SOLUTION.md`.

Full expected output for every command above, including the exact cookie value from a
real run, the raw UNION payload's response, and both DVWA `low`/`impossible` defense
comparisons: [`labs/day08/SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day08
docker compose down
```

This removes only `dvwa` — `labs/base`'s `attacker` container, the `cyberlab` network,
and the staged `dvwa_setup.sh` under `labs/base/loot/day08/` are untouched, since
they're shared infrastructure other days depend on too. Tear down `labs/base`
separately (`cd ../base && ./down.sh`) only once you're done with the whole session.

Note: DVWA's database lives inside the `dvwa` container itself (no named volume) — a
`docker compose down` here discards it, and a fresh `docker compose up -d` next time
needs `dvwa_setup.sh` re-run from scratch (its `create_db` step is idempotent, so this
is expected and safe).
