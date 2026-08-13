# Labs Index

## Authorized use only

Every lab in this directory is a self-contained, deliberately vulnerable
environment for **authorized attack practice only**. Attack only the
containers these labs start on the `cyberlab` network, or (Phase 3+) your
own AWS sandbox account. Never target systems you don't own or don't have
explicit written authorization to test.

## Shared conventions

- **`labs/base/`** — bootstrap infrastructure. Start this first
  (`cd labs/base && ./up.sh`); it builds the shared `attacker` toolbox
  container and creates the `cyberlab` docker bridge network that every
  day-lab attaches to. See `labs/base/README.md`.
- **`labs/dayNN/`** — one directory per day, matching `content/dayNN-*.md`.
  Each day-lab directory contains:
  - `docker-compose.yml` (Docker-first days) or `setup.sh` +
    `teardown.sh` (AWS days, Phase 3) — brings up that day's target(s) on
    the `cyberlab` network (or in the learner's AWS sandbox).
  - `README.md` — authorized-use notice, setup steps, attack/defense
    walkthrough.
  - `SOLUTION.md` — full worked solution for that day's drills and lab
    verify command.
- **Network:** every Docker day-lab declares `cyberlab` as an
  `external: true` network (created by `labs/base`) rather than defining
  its own, so the attacker container can always reach that day's targets
  by service name.
- **Loot:** shared scan/capture/crack output goes under `labs/base/loot/`
  (mounted at `/loot` in the attacker container). Day-labs write into a
  day-scoped subdirectory to avoid collisions.
- **AWS labs (Phase 3, Days 13–18 + capstone):** always ship `setup.sh` +
  `teardown.sh`, stay free-tier-friendly, and the lab's README states any
  cost warning plus a teardown reminder. Never hardcode credentials — use
  a named AWS CLI profile.

## Bring-up order

1. `cd labs/base && ./up.sh` — once per machine (rebuild only if the
   toolset changes).
2. `cd labs/dayNN && docker compose up -d` (or `./setup.sh` for AWS days).
3. Work the day's content file and lab README.
4. `docker compose down -v` (or `./teardown.sh`) for that day when done.
5. `cd labs/base && ./down.sh` when you're done with the whole path (or
   leave it running between days — it's shared, lightweight infra).

## Day index

Populated as each day's lab ships (Tasks 6–27 of the implementation
plan). See `../README.md` for the full Day 0–21 content index.
