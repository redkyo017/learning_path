# Day 08 Lab — Silent Pipeline Failure

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
