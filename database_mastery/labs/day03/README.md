# Day 3 lab — access methods: indexes, measured

## Goal

`break.sh` picks one of three report queries at random — a merchant
settlement summary, a disputed-payment listing, or a daily volume
rollup — and writes its text to `/tmp/day03-query.sql` inside `ws`. Each
of the three needs a genuinely different index. It also plants three
decoy indexes on `payments` (`idx_decoy_1`, `idx_decoy_2`,
`idx_decoy_3`) that look plausible but are wrong in three different
ways, and drops the supporting index out from under a MongoDB
`payment_events` query that filters on `merchant_id` and sorts by `ts`.

There are **four deliverables**, and `verify.sh` checks all four
independently:

1. Write `index_columns=<col1>,<col2>` to `/tmp/answer` inside `ws` —
   naming, in order, the columns of the index the query you were
   handed needs.
2. Build that index (or, for the disputed-payment listing, a partial
   index) so the report query in `/tmp/day03-query.sql` runs in well
   under 2 seconds via `EXPLAIN (ANALYZE)`, using an `Index Scan` or
   `Index Only Scan` — never a `Seq Scan`.
3. Drop all three decoy indexes. Recognizing that they're wrong is as
   much the point of this lab as building the right index.
4. Add the index `payment_events` needs so a query filtering on
   `merchant_id` and sorting by `ts` shows an `IXSCAN` stage with
   `totalDocsExamined / nReturned <= 2`.

Passing three of the four and skipping the fourth is not passing — do
all four before running `verify.sh`.

## Success signal

`labs/day03/verify.sh` exits `0`.

## How to run

From `database_mastery`, with the stack up
(`docker compose -p dbmastery up -d --build` in `labs/stack`):

```bash
bash labs/day03/break.sh
```

Read the printed `SYMPTOM` line, then read the query it left for you:

```bash
docker compose -p dbmastery exec ws cat /tmp/day03-query.sql
```

Read `EXPLAIN (ANALYZE, BUFFERS)` against that exact query before
touching anything else, per the daily loop's step 2. Write your
prediction and evidence chain in `journal.md` **before** building an
index — see `STRATEGY.md`, "The daily loop," steps 3 and 5.

Once you've identified the correct column order, write your answer
inside `ws`:

```bash
docker compose -p dbmastery exec ws sh -c \
  'echo "index_columns=<col1>,<col2>" > /tmp/answer'
```

replacing `<col1>,<col2>` with the actual ordered column list — no
spaces around the `=` or after the comma, lowercase.

Build the index, drop the three decoys, and add the MongoDB index, then:

```bash
bash labs/day03/verify.sh
```

If it exits non-zero, its output names exactly which of the four checks
still fails. When it exits `0`, follow `teardown.md` before starting
Day 4 — Day 3's indexes left in place change Day 4's plans.

No further hints here. `SOLUTION.md` covers all three possible report
queries in full, but reading it before you have your own evidence chain
skips the lesson the randomness of `break.sh` exists to force: you don't
get to memorize one answer for this lab, you have to actually read
`EXPLAIN` for whichever query you were handed.
