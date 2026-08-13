# Capstone Lab — Attack, Then Harden, a Small Company

## Authorized use only

Every attack in this lab targets containers this lab starts, on `cyberlab` plus two
lab-private networks (`internal`, `imds`) — never a real host, and never a real AWS
account other than your own sandbox if you opt into `setup.sh --with-aws`. All
credentials in this lab (the SQL-injectable login, the leaked ops password, the fake
AWS keys) are synthetic and planted on purpose for this exercise; none of them are real
secrets.

## What this lab is

A small simulated company: **Northwind Ops Portal** (`webapp`), a Flask app with two
independent bug pairs (see `webapp/app.py`'s module docstring), fronting an internal
Linux host (`host`) it was never supposed to expose, plus a simulated AWS side
(`fake-imds`, `fake-s3`) standing in for real EC2 instance metadata and a real S3
bucket. Day 20 (`content/day20-capstone-attack.md`) attacks it end-to-end; Day 21
(`content/day21-capstone-defend.md`) hardens, detects, and re-verifies every stage
against the exact same attack.

### Architecture map

```
                 cyberlab (shared, external)
   attacker ───────────────┬───────────────── fake-s3 (:8080)
                            │                  "the S3 API" -- reachable
                            │                  directly, like real S3
                            ▼
                         webapp (:5000)
                    "Northwind Ops Portal"
                       /            \
                      /              \
        internal (lab-private)      imds (lab-private)
        [attacker has NO route]     [attacker has NO route]
                    │                          │
                    ▼                          ▼
                  host (ssh)              fake-imds (169.254.169.254)
        "the box nobody meant           "the metadata service" --
         to expose"                      only webapp can reach this
```

- `attacker` (from `labs/base`) can reach `webapp` and `fake-s3` directly. It can
  reach neither `host` nor `fake-imds` directly — those are only reachable by riding a
  shell already established on `webapp` (a genuine pivot) or by tricking `webapp`
  into fetching a URL on your behalf (SSRF).
- `host` sits on `internal` only — no route out, no route in except through `webapp`.
- `fake-imds` sits on `imds` only, at the real, literal link-local address
  `169.254.169.254` — real EC2 instance metadata lives at that exact address too, and
  is *only* reachable from code running on the instance itself. This lab reproduces
  that access boundary exactly.
- `fake-s3` sits on `cyberlab`, reachable directly, exactly like real S3 is reachable
  from anywhere once you hold valid credentials — no further pivot needed once you have
  them.

### The two independent sub-chains

This environment has **two separate ways in**, and that's deliberate (see
`content/day20-capstone-attack.md`'s Concept section for why):

- **Path A** — register a normal account (open to anyone) → `/admin/diagnostics` is
  missing its role check (broken access control) → that same endpoint has an
  independent OS command-injection bug → foothold shell on `webapp` → a leaked
  credential in a leftover ops-notes file → lateral movement / pivot to `host` over
  SSH → a passwordless-sudo misconfig on `host` → root.
- **Path B** — SQL injection on `/login` bypasses authentication entirely and lands an
  `admin` session → `/admin/fetch`'s role check is correct, but the endpoint itself is
  a raw SSRF → fetch `http://169.254.169.254/...` → steal fake IAM role credentials →
  use those credentials directly against `fake-s3` (no further pivot needed) → a
  confidential object.

Neither path depends on the other. Day 21's hardening has to fix **both** independently
— fixing only one leaves the whole other path open, which is itself the lab's main
defense-in-depth lesson.

## Prerequisites

- The shared toolbox up (`cd ../base && ./up.sh`) — `attacker` and the `cyberlab`
  network must exist before this lab's `docker compose up` will succeed.
- Optional, for the real-AWS variant only: an AWS sandbox account, the AWS CLI, and a
  named profile (`aws configure --profile cyberlab-sandbox`). Never hardcode
  credentials into any script here.

## Setup

```sh
cd cyber_security/labs/base && ./up.sh   # once, if not already running
cd ../capstone
./setup.sh                                # Docker only -- free, no AWS calls at all
```

This builds and starts `webapp`, `host`, `fake-imds`, and `fake-s3`, and creates
`logs/webapp/` for the access log Day 21's detection drill reads.

**Dry validation, no docker/aws calls at all:**

```sh
docker compose config -q && ./setup.sh --check
```

**Optional real-AWS variant** (see `content/day20-capstone-attack.md`'s "Real AWS
mode" note and `setup.sh`'s own comments for exactly what this buys you): `./setup.sh
--with-aws` provisions a real, least-privilege-scoped-*after* IAM role, instance
profile, and S3 bucket in your sandbox account. Attaching that instance profile to a
real EC2 instance running this compose file's `webapp`+`host`+`fake-s3` (skip
`fake-imds`) turns Stage 4 into a genuine SSRF-to-real-IMDS credential theft, with zero
code changes. This step is optional and off by default; the default Docker-only path
already exercises the full chain safely and for free.

## Working the lab

1. Read `content/day20-capstone-attack.md` and attack the environment yourself —
   the content file gives you objectives and a hints ladder per stage, not a worked
   walkthrough. Fill in `report-template.md` Sections 1–6 as you go.
2. Only after a genuine attempt, check `SOLUTION-attack.md` for the full chain.
3. Read `content/day21-capstone-defend.md`, apply each control, and re-run Day 20's
   exact attack against the hardened environment to prove it now fails or is detected.
   Check `SOLUTION-defend.md` after your own attempt.
4. Finish `report-template.md` Sections 7–10.

## IMDSv2 before/after (Day 21)

`fake-imds`'s behavior is controlled entirely by one env var, with no webapp code
changes required to see the difference:

```sh
# Day 20 baseline (vulnerable):
docker compose up -d fake-imds                      # IMDS_MODE defaults to v1

# Day 21 hardening -- flip the exact same attack payload from Day 20 to fail:
IMDS_MODE=v2 docker compose up -d --force-recreate fake-imds
```

## Detection

```sh
cd cyber_security/labs/capstone
./detection/detect.sh
```

Scans `logs/webapp/access.log` for SQL-injection, command-injection, SSRF-to-metadata,
and broken-access-control signatures. See `content/day21-capstone-defend.md` for the
detection drill this backs.

## Teardown

```sh
./teardown.sh                                        # Docker only
./teardown.sh --with-aws --bucket <name-from-setup>   # also delete AWS resources
docker compose config -q && ./teardown.sh --check     # dry validation, no calls at all
```

Run the Docker teardown every time you're done for the session. If you used
`--with-aws`, run the AWS teardown too — the bucket name was printed by `setup.sh` when
it ran (or set `CAPSTONE_BUCKET_NAME` yourself before running either script).

## Files

- `docker-compose.yml` — `webapp`, `host`, `fake-imds`, `fake-s3` and the three
  networks (`cyberlab` external, `internal`, `imds`).
- `webapp/`, `host/`, `fake-imds/`, `fake-s3/` — each container's Dockerfile + app code.
- `setup.sh` / `teardown.sh` — Docker bring-up/teardown (default) plus the optional
  `--with-aws` real-resource path.
- `policies/` — the IAM trust policy and the before/after S3 policy documents used by
  the real-AWS variant and referenced in Day 21's least-privilege fix.
- `detection/detect.sh` — the log-based detection pass (Day 21, fix #5).
- `report-template.md` — the attack-and-defense writeup template (the deliverable).
- `SOLUTION-attack.md` — full worked attack chain (both paths).
- `SOLUTION-defend.md` — full worked defense: one control per finding, re-verified.
