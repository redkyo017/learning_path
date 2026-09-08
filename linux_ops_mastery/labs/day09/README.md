# Day 09 Lab — Trap Scope and Stale Temp Directory

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
