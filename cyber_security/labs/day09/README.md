# Day 9 Lab — IDOR, SSRF, and CSRF Against Juice Shop + an Internal-Only Service

## Authorized use only

This lab's `juiceshop` container is [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/),
an intentionally vulnerable training application — and `internal` is a tiny
service this lab wrote from scratch specifically to be attacked. Only ever
point the attacker toolbox at containers this learning path starts on the
`cyberlab` docker network — here or in any other day's lab — or your own AWS
sandbox account (Phase 3+). Never attempt IDOR, SSRF, or CSRF against a real
application, or against Juice Shop instances other people are running, that
you don't own or don't have explicit written authorization to test.

## What this lab is

`labs/day09/docker-compose.yml` adds **two** services, `juiceshop` and
`internal`, to (and alongside) the shared `cyberlab` network created by
[`labs/base`](../base/README.md). It does **not** redefine the `attacker`
service — that container is shared infrastructure, already running from Day
0.

**Network topology — this is the actual lab, not just plumbing:**

```
attacker --- cyberlab --- juiceshop --- day09-app --- internal (169.254.169.254)
                           (dual-homed)
```

- `attacker` is on `cyberlab` only, exactly like every earlier day.
- `juiceshop` is **dual-homed**: on `cyberlab` (so `attacker` can reach it
  directly, like any other day's `target`) AND on `day09-app` (a private
  network this lab creates, shared only with `internal`).
- `internal` is on `day09-app` **only** — there is no path from `attacker`
  to `internal` at all. `day09-app` is also declared `internal: true` in
  the compose file, so it has no route to the outside internet either.
- `internal` is pinned to the static address **`169.254.169.254`** — the
  real link-local address every major cloud provider (AWS, GCP, Azure) uses
  for their Instance Metadata Service. This is not decorative: Day 15
  attacks the real thing at this real address against a real AWS sandbox;
  today's `internal` is a safe, local stand-in for the same address and the
  same category of target. Full detail:
  [`content/day09-access-ssrf-csrf.md`](../../content/day09-access-ssrf-csrf.md).

This shape is the entire point of Section 2's SSRF step: you cannot curl
`internal` from `attacker` — try it, it will hang/refuse, there is no
network path. The only way to reach it is to make `juiceshop` (which CAN
reach it) fetch it on your behalf, which is what SSRF means.

`juiceshop` is a real, upstream, unmodified Juice Shop image
(`bkimminich/juice-shop:latest`) — its vulnerabilities are the real,
documented ones the project ships for training, not ones this lab planted.
`internal` (see [`internal/app.py`](internal/app.py)) is a small,
dependency-free Python service this lab wrote: it answers `GET /flag` with a
toy CTF flag, and also answers a fake, IMDSv1-shaped
`/latest/meta-data/iam/security-credentials/...` path with fake credentials,
mirroring the real endpoint shape Day 15 targets for real.

No ports are published to the host by the compose file itself for either
service — everything is reached container-to-container, by service name,
from the `attacker` container over `cyberlab`. (The CSRF step below needs
your own browser to see Juice Shop's UI — see "Browser-based steps.")

This lab also ships two files that are **not** staged by compose at all,
same pattern as Day 3/Day 4's loose helper files:
[`authz_ssrf_defense.py`](authz_ssrf_defense.py) (a local, no-network
before/after demo of the two code-level fixes — Defense Lab) and
[`csrf_poc.html`](csrf_poc.html) (the minimal CSRF PoC page/form). Get the
Python one into the attacker container with a plain `cp` — see Setup below.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's targets:

```sh
cd cyber_security/labs/day09
docker compose up -d --build
```

Then stage this lab's local defense-demo script into the shared loot
directory (plain `cp`, no container involved):

```sh
mkdir -p ../base/loot/day09
cp authz_ssrf_defense.py ../base/loot/day09/
```

## Running `docker compose exec` for this lab

Exactly like every earlier day: `attacker` is defined in
`labs/base/docker-compose.yml`, not in this lab's compose file. Run every
`docker compose exec attacker ...` command **from `labs/base`**, not from
`labs/day09`:

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s juiceshop:3000/rest/user/whoami"
```

## Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s juiceshop:3000/rest/user/whoami >/dev/null && echo TARGET_OK"
```

**Expected output:** `TARGET_OK`.

Confirm the SSRF topology directly (this SHOULD fail — that failure is the
point, proving `internal` is genuinely unreachable except via SSRF through
`juiceshop`):

```sh
docker compose exec attacker sh -c "curl -m 3 -s internal/flag; echo EXIT:\$?"
```

**Expected output:** a curl connection error and a non-zero `EXIT:`
code — there is no DNS entry or route for `internal` from `attacker`'s
network at all.

## Walkthrough

1. Bring up `labs/base` and `labs/day09`, and stage the defense script, as
   above.
2. From `labs/base`, work through Section 2 of
   [`content/day09-access-ssrf-csrf.md`](../../content/day09-access-ssrf-csrf.md)
   in order:
   - Step 1 — register/log in two Juice Shop accounts, find your own
     basket ID, then request a **different** basket ID and read its
     contents (IDOR / broken access control).
   - Step 2 — use Juice Shop's profile-image-by-URL feature to make
     `juiceshop` itself fetch `http://internal/flag` and
     `http://169.254.169.254/latest/meta-data/iam/security-credentials/cyberlab-day09-role`
     on your behalf, reading back a target you have no direct route to
     (SSRF).
   - Step 3 — open [`csrf_poc.html`](csrf_poc.html) and use it as a
     template for a CSRF PoC against a state-changing Juice Shop endpoint
     (CSRF) — see "Browser-based steps" below for what this needs beyond
     the attacker container.
3. Run the Verify commands above.
4. Read Section 3 (defense) and run
   `docker compose exec attacker sh -c "python3 /loot/day09/authz_ssrf_defense.py"`
   — see the BEFORE (vulnerable) output, then edit the file yourself
   (uncomment the AFTER lines the file's comments point you to) and re-run
   to see every line flip to PASS, before checking `SOLUTION.md`.

## Browser-based steps (CSRF)

The IDOR and SSRF steps above run entirely from the `attacker` container's
shell — no browser needed. The CSRF step is different by nature: CSRF
exploits a **victim's browser** silently attaching cookies to a cross-site
request, which only means something if there's an actual browser with an
actual Juice Shop session cookie in it. To see this yourself:

1. Publish `juiceshop`'s port to your host temporarily (edit
   `docker-compose.yml`'s `juiceshop` service to add
   `ports: ["3000:3000"]`, then `docker compose up -d`), or use
   `docker compose port juiceshop 3000` to find a mapped port.
2. Open Juice Shop in your own browser (`http://localhost:3000`), log in.
3. Open [`csrf_poc.html`](csrf_poc.html) in a **second tab of the same
   browser** (replace `JUICESHOP_HOST` in the file with `localhost` and the
   port first) and observe the change-password request fire automatically.
4. Log out and try logging in with the OLD password — if it now fails, and
   the NEW password (`csrf-owned123`) works, the CSRF succeeded.

Revert the port-publish change afterward if you want to go back to the
lab's default no-host-ports posture.

Full expected results, exact request/response shapes, and the honest note
on what this session did vs. didn't live-verify:
[`labs/day09/SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day09
docker compose down
```

This removes `juiceshop`, `internal`, and the `day09-app` network —
`labs/base`'s `attacker` container, the `cyberlab` network, and the staged
file under `labs/base/loot/day09/` are untouched, since they're shared
infrastructure other days depend on too. Tear down `labs/base` separately
(`cd ../base && ./down.sh`) only once you're done with the whole session.
