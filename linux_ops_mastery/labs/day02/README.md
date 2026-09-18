# Day 2 lab — the process table and the syscall boundary

**At a glance:**
- **Run from:** repo root — `bash labs/day02/break.sh`, `bash labs/day02/verify.sh`.
- **Environment:** Docker fleet must be up (`labs/fleet/`:
  `docker compose -p linuxops up -d --build`); diagnose inside `ws` and `app`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop:** three independent causes, each needs its own chain
  entry before you fix any of them — then break → journal → fix → verify →
  teardown.

## Goal

`app` has three processes that will not go away. Name the cause of each
one — separately, in `journal.md`, before you touch anything — and then
repair `app` back to a clean process table. Read `content/day02.md`
first if you have not; this lab assumes the process-state model and the
signal table from that page.

**Constraint: do not restart `app`.** No `docker compose restart app`,
no `up --force-recreate app`, no killing PID 1 or python itself. `app`
now carries `restart: unless-stopped`, so if PID 1 exits — which it
does the moment python exits, since `sh -c "python /srv/app.py; exit
$?"` runs `exit $?` right after — Docker brings the container straight
back with a brand-new process table, silently "solving" all three
causes by accident. Every one of the three is fixable by signalling a
specific `sleep` PID, never python or PID 1; if a command you are about
to run targets python's PID instead of one of the stray `sleep`s, stop
and re-check which process you actually found.

## Success signal

```bash
cd linux_ops_mastery/labs/day02
./verify.sh
```

`PASS: no stopped, zombie, or trapped processes remain.` and exit 0.

## How to run

```bash
cd linux_ops_mastery/labs/day02
./break.sh
```

Read the symptom it prints, then start investigating from inside `ws`:

```bash
docker compose -p linuxops exec ws bash
docker compose -p linuxops exec app sh
```

`/proc` is your evidence. Three distinct processes are involved — do not
assume they share one cause just because they share one symptom
("won't exit"). Write your chain in `journal.md` for each cause before
you send a single signal.

## No spoilers

This file stops here on purpose. `SOLUTION.md` in this directory has the
full diagnosis chain, but reading it before you've tried is reading the
answer key before the test — it will feel like understanding and won't
be. `teardown.md` is safe to read any time; it contains no diagnosis.
