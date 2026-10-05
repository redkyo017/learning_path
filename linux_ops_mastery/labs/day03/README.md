# Day 3 lab — the file descriptor table

**At a glance:**
- **Run from:** repo root — `bash labs/day03/break.sh`, `bash labs/day03/verify.sh`.
- **Environment:** Docker fleet must be up (`labs/fleet/`:
  `docker compose -p linuxops up -d --build`); diagnose inside `app`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop:** two required deliverables (the `req_id` and the
  released file) — standard break → journal → fix → verify → teardown
  otherwise.

## Start here — plain steps

1. **Start the lab:** on your Mac, from `linux_ops_mastery/`, make sure the fleet (the lab's Docker containers) is up (`docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d`), then run `bash labs/day03/break.sh`. It simulates a log rotation that went wrong inside the `app` container, and prints one `SYMPTOM` line.
2. **Get a shell in the broken container:** on your Mac, in `linux_ops_mastery/`, run `docker compose -p linuxops exec app sh`. Look and fix in this shell; run `verify.sh` back on your Mac. There is no `lsof` in `app`, on purpose.
3. **Look at the symptom (in the `app` shell):** `df /var/log` says space is still used. `ls -la /var/log` shows only a small or empty file. Your job is to explain that gap, like Day 1.
4. **Know your two deliverables.** Both are required. First, the failing request's `req_id` written into `/tmp/answer` on `app`. Second, the held file released, so nothing under `/var/log` is deleted-but-still-open any more.
5. **Write your reasoning in `journal.md` before fixing anything.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file; its Day 1 example shows the style.
6. **Do both deliverables, in the `app` shell:** recover the `req_id` first and save it with `echo <id> > /tmp/answer`. Do it before you release anything, because the content may become unreadable once the file is released.
7. **Check your work:** back on your Mac in `linux_ops_mastery/` (type `exit` first if you are still inside `app`), run `bash labs/day03/verify.sh` and wait for `PASS: held file released and req_id recorded in /tmp/answer.` If it fails, it names which deliverable is missing.
8. **Strip drill and tidy up:** on your Mac, run `docker compose -p linuxops exec slim sh` and paste the snippets from "Strip the toolbox" in `content/day03.md` inside it. Then follow `labs/day03/teardown.md`. This time it tells you to restart `app`; that is fine, the lab is over.

## Goal

`app`'s `/var/log` rotated, but usage did not drop, and one request in
the rotated batch failed. Find the failing request and release the
space it is stuck behind.

There are **two deliverables**, and both are required:

1. Write the failing request's `req_id` into `/tmp/answer` on `app`.
2. Release the held file, so nothing under `/var/log` is deleted-but-open
   any more.

Recovering the `req_id` without releasing the file, or releasing the
file without recovering the `req_id`, is only half the job — `verify.sh`
checks both, independently, so guessing your way to a clean `df` will
not pass.

## Success signal

`labs/day03/verify.sh` exits `0`.

## How to run

From `linux_ops_mastery/labs/fleet`, with the fleet up
(`docker compose -p linuxops up -d --build`):

```sh
../day03/break.sh
```

Read the printed `SYMPTOM` line and nothing else. Write your diagnosis as
a chain of evidence in `journal.md` **before** attempting any fix — see
`STRATEGY.md`, "The daily loop," step 5. Everything you need is reachable
with `sh`, `grep`, `awk`, and `/proc` from inside the `app` container
(`docker compose -p linuxops exec app sh`) — no `lsof` is installed there,
by design.

Once you believe the incident is resolved:

```sh
./verify.sh
```

If it exits non-zero, re-read its output — it names exactly which of the
two deliverables is still missing — and keep going. When it exits `0`,
follow `teardown.md` before moving on to Day 4.

If you get stuck, use **Stuck? Hints** at the bottom of this file before opening `SOLUTION.md`. Reading `SOLUTION.md` before you have your own chain skips the actual lesson.

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next. Each deliverable has its own ladder.

### Deliverable 1 — recover the req_id

<details><summary>Hint 1 — where to look</summary>

The rotated log has had its name removed, but its bytes still exist and are still billed to `/var/log`. This is the same `df` versus `du` gap as Day 1. Ask: which process still has that file open? The open-file list of every process lives under `/proc`.
</details>

<details><summary>Hint 2 — what proves it</summary>

Run `ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'`. Each line is a symlink (a shortcut-style link) whose path holds the PID (process ID) and the file-descriptor number (a small number naming each open file). You can still read the content through that path: `grep 'status=500' /proc/<PID>/fd/<N>` matches exactly one line.
</details>

<details><summary>Hint 3 — almost there</summary>

A `tail -f` still holds the rotated file open, and the single failing request is still inside it as the `status=500` line. The `req_id` you need is the 8-character value right after `req_id=` on that line.
</details>

### Deliverable 2 — release the held file

<details><summary>Hint 1 — where to look</summary>

A deleted file's space comes back only when the last process holding it open lets go. So the job is not about the file at all; it is about who holds it. Use the same `/proc` open-file list.
</details>

<details><summary>Hint 2 — what proves it</summary>

The `(deleted)` line from `ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'` already names the PID. Confirm what that process is with `cat /proc/<PID>/cmdline | tr '\0' ' '`.
</details>

<details><summary>Hint 3 — almost there</summary>

The holder is a `tail -f` follower of the rotated file, left running with no reason to stop. The space returns only when that process ends and its handle closes. Finish Deliverable 1 first: the content is unreadable after that point.
</details>

Still stuck: read `SOLUTION.md`.
