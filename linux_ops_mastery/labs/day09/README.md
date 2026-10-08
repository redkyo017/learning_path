# Day 09 Lab — Trap Scope and Leaked Work Directories

**At a glance:**
- **Run from:** repo root — `bash labs/day09/break.sh`, `bash labs/day09/verify.sh`.
- **Environment:** host only — no Docker, no fleet. Everything happens
  directly on your machine under `/tmp/lab09/`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop:** standard break → journal → fix → verify → teardown.

## Start here — plain steps

1. **Start the lab (no Docker today):** everything happens on your Mac under `/tmp/lab09/`. In `linux_ops_mastery/`, run `bash labs/day09/break.sh`. It writes a deploy script, `/tmp/lab09/deploy.sh`.
2. **Read the script:** run `cat /tmp/lab09/deploy.sh`. It sets a cleanup trap (a command that runs when the script exits or is interrupted), then loops over eight servers after a `|`, creating its work folder lazily inside the loop.
3. **See the leak:** run `/bin/bash /tmp/lab09/deploy.sh` three times. Each run ends with `cleanup: nothing to remove`. Then run `ls -d /tmp/lab09/work.*`: one folder per run is left behind, and the count grows each time.
4. **See the false success:** run the script once more and press Ctrl-C around `server-3`. It prints `cleanup: nothing to remove` and then `Deployment complete` anyway, then cleans up (finds nothing) a second time.
5. **Prove the subshell:** in `/tmp/lab09/deploy.sh`, add `echo "in loop: $WORKDIR"` inside the loop (after the `if` block) and `echo "after loop: $WORKDIR"` right after `done`. Run it: the first line shows a folder, the second is empty.
6. **Write your reasoning in `journal.md` before fixing anything.** Edit it in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file; its Day 1 example shows the style.
7. **Fix `deploy.sh` in place:** edit `/tmp/lab09/deploy.sh` so the work folder is not set in a subshell and an interrupt ends the script with cleanup. Remove the two debug `echo` lines if you like.
8. **Check it:** in `linux_ops_mastery/`, run `bash labs/day09/verify.sh`. All three checks should pass (it works on both macOS and Linux).
9. **Strip step drill:** redo the fix for plain `sh` — see "Strip step" in `content/day09.md`. `<(...)` does not exist there. (On a Mac `sh` is really bash; type `dash` for a real POSIX shell.)
10. **Tidy up:** follow `labs/day09/teardown.md`.

## Scenario

A CI runner's `/tmp` fills up with `work.*` directories. The deployment script
that stages files there registers a cleanup trap, yet every run leaves a
directory behind and the cleanup says "nothing to remove". On Ctrl-C the
script even prints "Deployment complete".

## Setup

    bash labs/day09/break.sh

This creates /tmp/lab09/ with deploy.sh — the broken deployment script.

## The incident

Run the broken script a few times and count the leftovers:

    bash /tmp/lab09/deploy.sh
    bash /tmp/lab09/deploy.sh
    ls -d /tmp/lab09/work.*

Then run it again and press Ctrl-C at `server-3` or so. Read the output
closely: what does it claim?

(Do not test with `bash deploy.sh &` then `kill -INT $!`: a background job
started by a non-interactive shell starts with SIGINT ignored, so that does
nothing. Use Ctrl-C in the foreground, or `kill -TERM`.)

## Your task

1. Diagnose why the cleanup finds nothing to remove, and why the script
   carries on after a signal.
2. Write your chain of evidence in journal.md BEFORE making any fix.
3. Fix deploy.sh so no `work.*` is left after a normal run, SIGTERM, or Ctrl-C,
   and an interrupted run does not claim success.
4. Run verify.sh to confirm.

## Verify

    bash labs/day09/verify.sh

## Teardown

See teardown.md.

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next.

<details><summary>Hint 1 — where to look</summary>

Look at the `printf ... | while read ...` line in `deploy.sh`, and at where `WORKDIR` is assigned. A pipe (`|`) starts each side as its own process. So which shell is the `while` loop actually running in, and which shell's `WORKDIR` does `cleanup` read?
</details>

<details><summary>Hint 2 — what proves it</summary>

Put `echo "in loop: $WORKDIR"` inside the loop and `echo "after loop: $WORKDIR"` after `done`. If the first has a value and the second is empty, the assignment happened in a child process.
</details>

<details><summary>Hint 3 — almost there</summary>

Two fixes are needed. Feed the loop with `done < <(printf ...)` (or create `WORKDIR` before the loop) so the assignment happens in the parent. And a trap handler that returns lets the script carry on: make the `INT` handler `exit 130` and the `TERM` handler `exit 143`, and keep cleanup on `EXIT`.
</details>

Still stuck: read `SOLUTION.md`.
