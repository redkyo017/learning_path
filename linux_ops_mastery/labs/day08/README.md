# Day 08 Lab — Silent Pipeline Failure

**At a glance:**
- **Run from:** repo root — `bash labs/day08/break.sh`, `bash labs/day08/verify.sh`.
- **Environment:** host only — no Docker, no fleet. Everything happens
  directly on your machine under `/tmp/lab08/`. (Days 1-7 needed the
  Docker fleet; Days 8-10 don't.)
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop:** standard break → journal → fix → verify → teardown.

## Start here — plain steps

1. **Start the lab (no Docker today):** everything happens on your Mac under `/tmp/lab08/`. In `linux_ops_mastery/`, run `bash labs/day08/break.sh`. It builds a small backup job: a `data/` folder, one file nobody is allowed to read, and a script `backup.sh`.
2. **Look at what it made:** on your Mac, run `ls -l /tmp/lab08/ /tmp/lab08/data`. `secret.txt` shows `----------` (mode 000: no one may read it). `cat /tmp/lab08/backup.sh` — the whole job is one `find ... | tar ...` line (a pipeline: `|` hands one command's output to the next).
3. **Run the broken script and look at the symptom:** on your Mac, run `bash /tmp/lab08/backup.sh; echo "exit: $?"`. It says "Backup complete" and the exit status (the number a program returns, 0 = success) is `0`. Then list the archive with `tar -tzf /tmp/lab08/backup/archive.tar.gz` and compare it with `ls /tmp/lab08/data`.
4. **Write your reasoning in `journal.md` before fixing anything.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file; its Day 1 example shows the style. Use `echo $?` and `PIPESTATUS` (bash's per-stage exit numbers; run `bash` first, zsh spells it differently).
5. **Fix `backup.sh` in place:** edit `/tmp/lab08/backup.sh` in your editor so that the script fails loudly (non-zero exit and a visible error) when a stage of the pipeline fails.
6. **Check it:** on your Mac, in `linux_ops_mastery/`, run `bash labs/day08/verify.sh`. Known issue: this lab was written for Linux, so on a Mac one `verify.sh` check can fail even after a correct fix. If that happens, prove your fix by re-running the step-3 commands and showing the symptom is gone.
7. **Strip step drill:** on your Mac, repeat the diagnosis in plain `sh` (no `PIPESTATUS` there — see "Strip step" in `content/day08.md`). On a Mac `sh` is really bash, so for a true POSIX shell type `dash` instead.
8. **Tidy up:** on your Mac, follow `labs/day08/teardown.md`.

## Scenario

A backup script wraps `find` and `tar` in a pipeline. `find` hits a
permission-denied path, exits 1, but `tar` succeeds on the partial input.
The pipeline exits 0. The script prints "Backup complete." The backup is
missing files.

## Setup

    bash labs/day08/break.sh

This creates /tmp/lab08/ with:
- /tmp/lab08/data/readable.txt — a normal file
- /tmp/lab08/data/secret.txt  — mode 000, unreadable
- /tmp/lab08/backup.sh        — the broken backup script

## The incident

Run the broken script:

    bash /tmp/lab08/backup.sh

It reports success. Inspect the archive. What is missing?

## Your task

1. Diagnose the failure using `echo $?`, `PIPESTATUS`, and `set -o pipefail`.
2. Write your chain of evidence in journal.md BEFORE making any fix.
3. Fix backup.sh so it fails loudly instead of silently.
4. Run verify.sh to confirm.

## Verify

    bash labs/day08/verify.sh

## Teardown

See teardown.md.

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next.

<details><summary>Hint 1 — where to look</summary>

Look at the one pipeline line in `backup.sh`. A pipeline is several commands joined by `|`, and the shell reports only one exit status for the whole thing. Which stage's status does it report by default?
</details>

<details><summary>Hint 2 — what proves it</summary>

In `bash`, run `find /tmp/lab08/data -type f 2>/dev/null | tar -czf /dev/null -T -` and then `echo "${PIPESTATUS[@]}"`. You get one number per stage, `find` first and `tar` second. Compare them with the single number `echo $?` gives you. On a Mac, `find` may not fail on this file at all; the behaviour this lab describes is Linux's.
</details>

<details><summary>Hint 3 — almost there</summary>

The pipeline's exit status is just the last stage's (`tar`'s), so a failure in `find` is thrown away. On top of that, `2>/dev/null` hides the error message, so nothing tells you anything went wrong.
</details>

Still stuck: read `SOLUTION.md`.
