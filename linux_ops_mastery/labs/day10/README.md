# Day 10 Lab — Fragile Argument Parser

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
