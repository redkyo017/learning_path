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

## Start here — plain steps

1. **Start the lab:** on your Mac, from `linux_ops_mastery/`, make sure the fleet (the lab's Docker containers) is up (`docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d`), then run `bash labs/day02/break.sh`. It starts three stray processes inside the `app` container. This lab has three separate causes, not one.
2. **Get a shell in the broken container:** on your Mac, in `linux_ops_mastery/`, run `docker compose -p linuxops exec app sh`. Look and fix in this shell; run `verify.sh` back on your Mac. Never restart `app` — that would hide all three causes.
3. **Look at the symptom (in the `app` shell):** run `for f in /proc/[0-9]*/status; do grep -H "^State:" "$f"; done` to list every process's state. `S` means sleeping (normal). Note any row that is not `S`. Then run `ps` and note every process you do not recognise.
4. **Write three separate chains in `journal.md`, one per cause, before fixing any.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file three times; its Day 1 example shows the style.
5. **Fix each one, in the `app` shell,** by sending a signal to the right process, checking the PID (process ID) before every `kill`. Never kill PID 1, and never kill the main `python /srv/app.py` service.
6. **Check your work:** back on your Mac in `linux_ops_mastery/` (type `exit` first if you are still inside `app`), run `bash labs/day02/verify.sh` and wait for `PASS: no stopped, zombie, trapped, or spawner processes remain.`
7. **Strip-the-toolbox drill:** on your Mac, run `docker compose -p linuxops exec slim sh`, then paste the snippets from "Strip the toolbox" in `content/day02.md` inside it. It reads the same process facts with no `ps` options (busybox is the tiny toolset in `slim`).
8. **Tidy up:** on your Mac, follow `labs/day02/teardown.md`. Do not run `docker compose down`. Leave the fleet running for Day 3.

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

This file stops here on purpose (apart from the opt-in hints at the bottom). `SOLUTION.md` in this directory has the
full diagnosis chain, but reading it before you've tried is reading the
answer key before the test — it will feel like understanding and won't
be. `teardown.md` is safe to read any time; it contains no diagnosis.

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next. Each cause has its own ladder, so only open the ladder for the cause you are working on.

### Cause 1 — the process that won't die

<details><summary>Hint 1 — where to look</summary>

Find the `sleep 100000` process. A plain `kill <PID>` asks it politely to stop with the TERM signal (the standard stop request), and nothing happens. So ask: what does this process do with the signals it receives? That setting is recorded in `/proc/<PID>/status` (PID means process ID).
</details>

<details><summary>Hint 2 — what proves it</summary>

Find the PID with `pgrep -f "sleep 10000[0]"` (the bracket stops `pgrep` from matching itself). Then run `grep -E "^Sig(Ign|Cgt):" /proc/<PID>/status`. `SigIgn` is a hex mask of signals the process ignores; `SigCgt` is the mask it handles itself. Signal 15, TERM, is the `4000` part of the mask. Check whether it is set in `SigIgn`.
</details>

<details><summary>Hint 3 — almost there</summary>

The shell that launched this `sleep` told itself to ignore TERM, then swapped itself for `sleep`. An ignore setting survives that swap. So `sleep`, which has no signal code of its own, silently discards every polite stop request.
</details>

### Cause 2 — the entries that keep piling up

<details><summary>Hint 1 — where to look</summary>

Look for rows with state `Z` (zombie: a process that has already exited but has not been collected). A zombie is already dead, so you cannot signal it away. Ask instead: who is supposed to collect it? That is its parent process.
</details>

<details><summary>Hint 2 — what proves it</summary>

Run `grep PPid /proc/<zombie-PID>/status` to get the parent's PID, then `cat /proc/<parent-PID>/cmdline | tr '\0' ' '` to see what the parent is. Re-run the state list from Start here twice, a few seconds apart. If the `Z` count rises, something is still creating them.
</details>

<details><summary>Hint 3 — almost there</summary>

The parent is a `python3` loop that creates a short-lived child about every two seconds and never collects the child's exit. Each uncollected exit stays as a zombie. The zombie is only the symptom; the live parent that keeps producing them is the cause.
</details>

### Cause 3 — the process that never answers

<details><summary>Hint 1 — where to look</summary>

Find the `sleep 200000` process and read its `State:` line in `/proc/<PID>/status`. It is not `S`. What does that letter mean?
</details>

<details><summary>Hint 2 — what proves it</summary>

Find the PID with `pgrep -f "sleep 20000[0]"`, then `grep State /proc/<PID>/status`. You will see `T (stopped)`. Also check `SigIgn` and `SigCgt` in the same file: TERM is not ignored here, unlike Cause 1. Send TERM and read `State` again: it is still `T`, because the process never gets to act on it.
</details>

<details><summary>Hint 3 — almost there</summary>

Something froze this process with the stop signal. A stopped process is not scheduled to run at all, so a TERM sent to it just waits, undelivered, until the process is allowed to run again.
</details>

Still stuck: read `SOLUTION.md`.
