# Day 09 Lab — Trap Scope and Stale Temp Directory

**At a glance:**
- **Run from:** repo root — `bash labs/day09/break.sh`, `bash labs/day09/verify.sh`.
- **Environment:** host only — no Docker, no fleet. Everything happens
  directly on your machine under `/tmp/lab09/`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop:** standard break → journal → fix → verify → teardown.

## Start here — plain steps

1. **Start the lab (no Docker today):** everything happens on your Mac under `/tmp/lab09/`. In `linux_ops_mastery/`, run `bash labs/day09/break.sh`. It writes a deploy script, `/tmp/lab09/deploy.sh`.
2. **Read the script:** on your Mac, run `cat /tmp/lab09/deploy.sh`. It makes a temp folder, sets a cleanup trap (a command that runs when the script exits or is interrupted), then loops over servers after a `|`.
3. **Cause the incident and look at the symptom:** use a normal Terminal window on your Mac. Run `bash /tmp/lab09/deploy.sh &` (the `&` runs it in the background), wait until you see a few `Deploying to server-N...` lines, then run `kill -INT $!` (this sends the same interrupt signal as Ctrl-C). Straight away run `ls -d /tmp/lab09/work.*`: the temp folder is still there, and the server lines keep coming. Wait for `Deployment complete` before moving on.
4. **Write your reasoning in `journal.md` before fixing anything.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file; its Day 1 example shows the style. Compare process IDs (PIDs, each process's number) with `echo $$` inside and outside the loop.
5. **Fix `deploy.sh` in place:** edit `/tmp/lab09/deploy.sh` in your editor so the cleanup always runs when the script is interrupted.
6. **Check it:** on your Mac, in `linux_ops_mastery/`, run `bash labs/day09/verify.sh`. Known issue: this lab was written for Linux, so on a Mac one `verify.sh` check can fail even after a correct fix. If that happens, prove your fix by re-running the step-3 commands and showing the symptom is gone.
7. **Strip step drill:** on your Mac, redo the loop for plain `sh` — see "Strip step" in `content/day09.md`. `<(...)` does not exist there. (On a Mac `sh` is really bash; type `dash` for a real POSIX shell.)
8. **Tidy up:** on your Mac, follow `labs/day09/teardown.md`.

## Scenario

A deployment script creates a temp directory, registers a cleanup trap, then
processes a list of servers via a pipeline loop. Hitting Ctrl-C partway through
leaves the temp directory behind. The second run fails because the directory
already exists.

## Setup

    bash labs/day09/break.sh

This creates /tmp/lab09/ with deploy.sh — the broken deployment script.

## The incident

Run the broken script, then interrupt it:

    bash /tmp/lab09/deploy.sh &
    sleep 1
    kill -INT $!

Check whether the temp directory was cleaned up. Then run it again — what
happens?

## Your task

1. Diagnose why the trap does not fire on Ctrl-C inside the pipeline loop.
2. Write your chain of evidence in journal.md BEFORE making any fix.
3. Fix deploy.sh so the cleanup trap reliably fires on interrupt.
4. Run verify.sh to confirm.

## Verify

    bash labs/day09/verify.sh

## Teardown

See teardown.md.

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next.

<details><summary>Hint 1 — where to look</summary>

Look at the `seq 1 20 | while read ...` line in `deploy.sh`. A pipe (`|`) starts each side as its own process. So which shell is the `while` loop actually running in?
</details>

<details><summary>Hint 2 — what proves it</summary>

Compare process IDs. Run `echo "parent PID: $$"`, then run `seq 1 3 | while read -r n; do echo "loop PID: $$"; break; done`. If the two numbers differ, the loop is running in a child process.
</details>

<details><summary>Hint 3 — almost there</summary>

The loop is the right-hand side of a pipeline, so it runs in a subshell (a child copy of the shell). The interrupt and the parent's trap do not line up with that child, so the cleanup does not fire when you expect it to.
</details>

Still stuck: read `SOLUTION.md`.
