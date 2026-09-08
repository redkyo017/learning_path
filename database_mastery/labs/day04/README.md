# Day 4 lab — the planner: why it chose that plan

## Goal

A merchant capture-totals report used to run in about 400 ms. It now
takes upward of ninety seconds, with no schema change and no query
change. There are **two deliverables**, and both are required:

1. Find the deepest plan node where the estimate and the actual row
   count diverge, and write it into `/tmp/answer` on `ws` as
   `divergent_node=<node type>` (for example `divergent_node=Index
   Scan`).
2. Fix it — in two stages, both required:
   - Remove the false `n_distinct` override on `payments.merchant_id`
     and run `ANALYZE`.
   - Create extended statistics on the correlated `merchant_country` /
     `currency` pair on `wide_payments`, and confirm they've actually
     been analysed, not only created.

Finding the right node without fixing it, or fixing it without ever
identifying which node was actually wrong, is only half the job.
`verify.sh` checks both, independently.

## Success signal

`labs/day04/verify.sh` exits `0`.

## How to run

From `database_mastery/labs/day04`, with the stack up (see
`labs/stack/README.md`):

```sh
./break.sh
```

Read the `SYMPTOM` line and nothing else. Write your prediction and your
evidence chain in `journal.md` **before** attempting any fix — see
`STRATEGY.md`, "The daily loop," steps 3 and 5.

### Step 1 — find the divergence

Run `EXPLAIN (ANALYZE, BUFFERS)` yourself against the merchant
capture-totals report — do not open a GUI plan visualizer first (daily
loop, step 2). The query:

```sql
SELECT m.name, count(*) AS n_captured, sum(p.amount_minor) AS total_minor
FROM merchants m
JOIN payments p ON p.merchant_id = m.merchant_id
WHERE p.merchant_id = :target
  AND p.status = 'captured'
GROUP BY m.name;
```

`:target` is not hidden — it is the merchant sitting at the midpoint of
the `merchant_id` range:

```sql
SELECT merchant_id FROM merchants
ORDER BY merchant_id
OFFSET (SELECT count(*)/2 FROM merchants)
LIMIT 1;
```

Read the plan bottom-up. Every node prints an estimate (`rows=`) and, with
`ANALYZE`, a measured value (`actual ... rows=`) — find the deepest one
where the two disagree by orders of magnitude, not the first one you
notice at the top. Write the node type to `/tmp/answer` on `ws`:

```
divergent_node=<node type>
```

### Step 2 — fix it, in order

`n_distinct` is a per-column *option*, visible in `pg_attribute.attoptions`
and readable through `\d+ payments` in `psql` — check there before
assuming the divergence is purely a stale-statistics story. Removing the
override and re-running `ANALYZE` closes most of the gap on this
specific query. It does not close the second, unrelated gap this day
also asks you to find and fix: the independence-assumption error on the
seeded `merchants.country` / `payments.currency` correlation, which
`CREATE STATISTICS` can only address on a single table — see
`content/day04.md`'s Core Concepts for why, and why `wide_payments` is
where that fix actually lives.

Once you believe both stages are done:

```sh
./verify.sh
```

If it exits non-zero, re-read its output — it names exactly which of the
five checks failed — and keep going. It will fail, on purpose and by
name, if it finds `enable_nestloop`, `enable_hashjoin` or
`enable_seqscan` disabled anywhere: forcing a plan node off is not a
valid fix for this lab, because it hides the row-estimate error instead
of correcting it, and it stops working the next time the data shifts.

When `verify.sh` exits `0`, follow `teardown.md` before moving on to
Day 5.

No further hints here. `SOLUTION.md` has the full chain if you get
stuck, but reading it before you have your own evidence chain skips the
actual lesson.
