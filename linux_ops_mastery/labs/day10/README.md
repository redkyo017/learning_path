# Day 10 Lab — Fragile Argument Parser

**At a glance:**
- **Run from:** repo root — `bash labs/day10/break.sh`, `bash labs/day10/verify.sh`.
- **Environment:** host only — no Docker, no fleet. Everything happens
  directly on your machine under `/tmp/lab10/`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop:** standard break → journal → fix → verify → teardown.

## Start here — plain steps

1. **Start the lab (no Docker today):** everything happens on your Mac under `/tmp/lab10/`. In `linux_ops_mastery/`, run `bash labs/day10/break.sh`. It writes `/tmp/lab10/inspect.sh`, a tiny script that should be given a PID (process ID).
2. **Read the script:** on your Mac, run `cat /tmp/lab10/inspect.sh`. It uses `$1` (the first argument) without checking it.
3. **Look at the symptom:** on your Mac, run `bash /tmp/lab10/inspect.sh; echo "exit: $?"` and then `bash /tmp/lab10/inspect.sh notapid; echo "exit: $?"`. The no-argument run prints `Inspecting PID:` with an empty value, `notapid` prints `Inspecting PID: notapid`, and in both cases the exit status (0 = success) is `0`.
4. **Write your reasoning in `journal.md` before fixing anything.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file; its Day 1 example shows the style.
5. **Fix `inspect.sh` in place:** edit `/tmp/lab10/inspect.sh` in your editor. At the top, reject a missing or non-numeric argument: print a usage message to stderr (the error output stream) and exit non-zero.
6. **Check it:** on your Mac, in `linux_ops_mastery/`, run `bash labs/day10/verify.sh`. Known issue: this lab was written for Linux, so on a Mac one `verify.sh` check can fail even after a correct fix. If that happens, prove your fix by re-running the step-3 commands and showing the symptom is gone.
7. **Strip step drill:** on your Mac, check your script for bash-only syntax with `sh -n` (parse only, do not run) and convert what you find — see "Strip step" in `content/day10.md`. `diagnose.sh` there is the capstone script you write later, so practise on `inspect.sh`. (On a Mac `sh` is really bash; `dash -n` is the real POSIX check.)
8. **Tidy up:** on your Mac, follow `labs/day10/teardown.md`.

## Scenario

An ops script accepts a PID as its first argument and runs a diagnostic on
that process. When called without arguments (or with a typo), $1 is empty.
The script proceeds anyway, passing an empty string to a command that
interprets it destructively.

## Setup

    bash labs/day10/break.sh

This creates /tmp/lab10/ with inspect.sh — the broken ops script.

## The incident

Run the broken script without arguments:

    bash /tmp/lab10/inspect.sh

What happens? Now run it with a non-numeric argument:

    bash /tmp/lab10/inspect.sh notapid

Does it reject the invalid input?

## Your task

1. Diagnose the argument handling gaps.
2. Write your chain of evidence in journal.md BEFORE making any fix.
3. Fix inspect.sh to validate its argument contract at entry.
4. Run verify.sh to confirm.

## Verify

    bash labs/day10/verify.sh

## Teardown

See teardown.md.

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next.

<details><summary>Hint 1 — where to look</summary>

Look at the line `PID="$1"` in `inspect.sh`. What does `$1` hold when the caller passes nothing, or passes something that is not a number? And what does the script do next?
</details>

<details><summary>Hint 2 — what proves it</summary>

Run `bash /tmp/lab10/inspect.sh; echo "exit: $?"`. It prints `Inspecting PID:` with nothing after it, then tries to read `/proc//status`, and the exit status is 0. Run it again with `notapid` and compare.
</details>

<details><summary>Hint 3 — almost there</summary>

The script has no argument contract (a rule for what callers must pass). An unset `$1` quietly expands to an empty string, and nothing checks that the value is present or numeric, so the script carries on with a bad PID.
</details>

Still stuck: read `SOLUTION.md`.
