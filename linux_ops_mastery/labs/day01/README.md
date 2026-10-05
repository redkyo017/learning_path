# Day 1 lab — the full `/var/log`

**At a glance:**
- **Run from:** repo root — `bash labs/day01/break.sh`, `bash labs/day01/verify.sh`.
- **Environment:** Docker fleet must be up (`labs/fleet/`:
  `docker compose -p linuxops up -d --build`); diagnose inside `app`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop:** standard break → journal → fix in place (no
  restarting `app`) → verify → teardown.

## Start here — plain steps

1. **Start the lab:** on your Mac, from `linux_ops_mastery/`, make sure the fleet (the lab's Docker containers) is up (`docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d`), then run `bash labs/day01/break.sh`. It fills up the `/var/log` disk inside the `app` container.
2. **Get a shell in the broken container:** on your Mac, in `linux_ops_mastery/`, run `docker compose -p linuxops exec app sh`. Look and fix in this shell; run `verify.sh` back on your Mac.
3. **Look at the symptom (in the `app` shell):** `df -h /var/log` says it is full. `du -sh /var/log` says almost nothing is there. Your job is to explain that gap.
4. **Write your reasoning in `journal.md` before fixing anything.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file; its Day 1 example shows the style.
5. **Fix it without restarting `app`,** then, back on your Mac in `linux_ops_mastery/`, run `bash labs/day01/verify.sh` and wait for `PASS`.
6. **Strip-the-toolbox drill:** on your Mac (type `exit` first if you are still inside `app`), run `docker compose -p linuxops exec slim sh`, then paste the 5-line snippet from "Strip the toolbox" in `content/day01.md` inside it, and watch the same evidence appear with no `lsof`.
7. **Tidy up:** on your Mac, follow `labs/day01/teardown.md`. Leave the fleet running for Day 2.

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

If you get stuck, use **Stuck? Hints** at the bottom of this file before opening `SOLUTION.md`. Read `content/day01.md` first if you're unsure where to look; read `SOLUTION.md` only after your own attempt, or after `verify.sh` has failed you at least twice.

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next.

<details><summary>Hint 1 — where to look</summary>

`df` counts space the filesystem still holds. `du` counts only files that still have a name. The missing bytes belong to a file with no name. So ask: what do processes still hold open? That is the file-descriptor (open-file handle) table.
</details>

<details><summary>Hint 2 — what proves it</summary>

Every open file of every process shows up as a symlink (a shortcut-style link) under `/proc/<PID>/fd/`, where PID means process ID. Run `ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'`. A deleted file's link target ends in `(deleted)`, and the PID is in the path.
</details>

<details><summary>Hint 3 — almost there</summary>

A background `tail -f` process still has a big log file open, even though the file's name was removed. The kernel keeps billing the space for as long as that descriptor stays open.
</details>

Still stuck: read `SOLUTION.md`.
