# Day 12 Lab — Web Consolidation Mini-CTF

## Authorized use only

This lab's `target` container is a deliberately vulnerable web app running nothing but
a tiny Flask API with two planted bugs (SQL injection auth bypass, broken access
control / IDOR), plus two static, provided log files for an offline detection
exercise. Only ever point the attacker toolbox at containers this learning path starts
on the `cyberlab` docker network — here or in any other day's lab — or your own AWS
sandbox account (Phase 3+). Never inject, enumerate, or "detect" against a system you
don't own or don't have explicit written authorization to test.

## What this lab is

`labs/day12/docker-compose.yml` adds a single `target` service to the shared
`cyberlab` network created by [`labs/base`](../base/README.md). It does **not**
redefine the `attacker` service — that container is shared infrastructure, already
running from Day 0.

`target` (see [`target/app.py`](target/app.py)) is a small Flask app chaining three
stages into one CTF:

- **Stage 1 — Foothold (injection):** `POST /login` builds its SQL query by raw string
  formatting — no parameterization at all. Two accounts exist, `alice` (role: user) and
  `admin` (role: admin), but **every real password is a random, undocumented string**
  generated fresh each time the container starts. Nobody can log in with a real
  password. The only way in is breaking the query's own syntax with a SQL injection —
  any successful login on this box is proof you did.
- **Stage 2 — Escalate (broken access control):** `GET /notes/<id>` requires a valid
  session (any of them) but never checks that the requested note's `owner_id` matches
  the session's own user — a textbook IDOR. Note `id=2` belongs to `admin` and holds
  Flag 2; it's reachable from **any** logged-in session, including `alice`'s, because
  the missing check doesn't care who's asking.
- **Stage 3 — Detect (log analysis, fully offline):** [`logs/access.log`](logs/access.log)
  and [`logs/alerts.log`](logs/alerts.log) are a **static, provided capture** — no live
  detector runs anywhere in this lab. `access.log` is a recorded trace of ordinary
  traffic plus exactly the two attacks above; `alerts.log` is a set of candidate
  automated alerts, some of which are false positives. Flag 3 is the value on the one
  true-positive alert whose claimed evidence actually correlates against `access.log`.

No ports are published to the host — everything is reached container-to-container, by
service name (`target`), from the `attacker` container over `cyberlab`. Stage 3 needs
no container at all beyond `attacker` (for `jq`/`grep`) — the log files are read
directly from the bind-mounted lab directory.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's target:

```sh
cd cyber_security/labs/day12
docker compose up -d --build
```

Then stage this lab's log files into the shared loot directory (plain `cp`, no
container involved — `../base/loot/` is the same host directory already mounted at
`/loot` inside the running `attacker` container):

```sh
mkdir -p ../base/loot/day12
cp logs/access.log logs/alerts.log ../base/loot/day12/
```

## Toolbox usage for this lab

Everything needed is already in the shared `attacker` container from
[`labs/base`](../base/README.md): `curl` for Stages 1–2 (crafting the injected
`POST /login` body and the follow-up `GET /notes/<id>` requests), and `jq`/`grep` for
Stage 3 (filtering and cross-referencing the two JSON-lines log files). No new tool is
introduced this day — this lab is a consolidation of tools already used in Days 4, 8,
and the earlier Phase 2 days, not a new-tool day.

`attacker` is defined in `labs/base/docker-compose.yml`, not in this lab's compose
file — same pattern as every earlier day. Run every `docker compose exec attacker ...`
command **from `labs/base`**, not from `labs/day12`:

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s target:5000/"
```

## Running the CTF

Work the three stages in order from [`content/day12-ctf-web.md`](../../content/day12-ctf-web.md)
Section 2 — each stage has its own hints ladder (nudge → bigger nudge → answer) in that
file. Try each stage yourself with the hints before opening `SOLUTION.md`.

1. **Stage 1 (foothold):** get a session on `target` via SQL injection against
   `POST /login` — no real password exists for either account. A successful login
   returns Flag 1 directly in the JSON response.
2. **Stage 2 (escalate):** using the session cookie from Stage 1, request
   `GET /notes/<id>` for a note you don't own. Note `id=2` (admin's) returns Flag 2 —
   this works regardless of which account Stage 1 landed you as.
3. **Stage 3 (detect):** with `access.log` and `alerts.log` staged at `/loot/day12/` in
   the attacker container, cross-reference the two files. Four of the five alerts in
   `alerts.log` are false positives for one of three distinct reasons (fabricated, with
   no matching evidence at all; real but with an exaggerated/wrong claim; or real and
   correlating but irrelevant to this incident). The one true positive that actually
   matches the Stage 2 IDOR evidence carries Flag 3.

## Verify (static validation only)

```sh
cd cyber_security/labs/day12
docker compose config -q && echo COMPOSE_OK
```

**Expected output:** `COMPOSE_OK`. This validates the compose file's syntax and that
it correctly references the external `cyberlab` network — it does **not** build or run
anything. To actually reproduce all three flags, follow the Walkthrough below (or work
the CTF unaided first) and see [`SOLUTION.md`](SOLUTION.md) for the full, staged
walkthrough including the Stage 3 detection answer.

## Walkthrough

1. Bring up `labs/base` and `labs/day12`, and stage the log files, as above.
2. From `labs/base`, work Section 2 of
   [`content/day12-ctf-web.md`](../../content/day12-ctf-web.md) in order: Stage 1
   (SQLi foothold), Stage 2 (IDOR escalation), Stage 3 (log-based detection).
3. Run the static verify command above and confirm `COMPOSE_OK`.
4. Read Section 3 (defense reflection) and name, for each flag, the one control that
   would have stopped it, before checking `SOLUTION.md`.

Full expected output for every command above, the exact injection payloads, the exact
`jq`/`grep` queries over both log files, and the reasoning for every alert (which four
are false positives and why, which one is the true positive, and its flag):
[`labs/day12/SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day12
docker compose down
```

This removes only `target` — `labs/base`'s `attacker` container, the `cyberlab`
network, and the staged files under `labs/base/loot/day12/` are untouched, since
they're shared infrastructure other days depend on too. Tear down `labs/base`
separately (`cd ../base && ./down.sh`) only once you're done with the whole session.
