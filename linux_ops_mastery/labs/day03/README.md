# Day 3 lab — the file descriptor table

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

No further hints here. `SOLUTION.md` has the full chain if you get stuck,
but reading it before you have your own chain skips the actual lesson.
