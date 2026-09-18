# Day 1 lab — the full `/var/log`

**At a glance:**
- **Run from:** repo root — `bash labs/day01/break.sh`, `bash labs/day01/verify.sh`.
- **Environment:** Docker fleet must be up (`labs/fleet/`:
  `docker compose -p linuxops up -d --build`); diagnose inside `app`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop:** standard break → journal → fix in place (no
  restarting `app`) → verify → teardown.

**Goal:** return `/var/log` on `app` to under 20% used, without restarting
the container.

**Success signal:** `bash labs/day01/verify.sh` exits 0 and prints `PASS`.

**Run:**

```bash
bash labs/day01/break.sh
# write your chain of evidence in journal.md BEFORE touching a fix -- see
# STRATEGY.md, "The daily loop," step 5
bash labs/day01/verify.sh
```

**Constraint — do not restart `app`.** `docker compose restart app` (or
any `stop`/`up` cycle on it) throws away exactly the evidence this lab is
testing: the process holding the deleted file exits with the container,
the tmpfs is recreated empty, and `verify.sh` will pass — but you will
have "fixed" the symptom without ever having proven what caused it.
Diagnose and repair the running container in place.

No further hints here on purpose. Read `content/day01.md` first if you're
stuck on where to look; read `SOLUTION.md` only after your own attempt, or
after `verify.sh` has failed you at least twice.
