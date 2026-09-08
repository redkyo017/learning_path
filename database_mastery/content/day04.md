# Day 4 — The planner: why it chose that plan

**Layer:** planner
**Budget:** 3 h — 1 h reading plans and statistics, 1.5 h lab, 0.5 h rewrites and exercises

## Why this matters

An index that exists and is never used, a query that ran in 400 ms last
week and takes ninety seconds today with no schema change and no query
change, and a plan that is perfect against staging's tidy data and wrong
the moment it meets production's — these read like three different
failures with three different fixes. They are one failure, diagnosed by
one number: the gap between the row count the planner estimated before
running the query and the row count the query actually produced. Find
the **deepest** node in the plan where that gap opens up, because every
node above it is downstream of that one's mistake, not a separate cause
you also need to explain. Everything today builds toward reading that
number correctly, on the first pass, before reaching for a rewrite, an
index, or — the wrong move — a session-level switch that hides the
symptom instead of the cause.

## Read the instrument first

A settlement dashboard runs this once per merchant. Someone pastes the
plan into a ticket because it used to be instant:

```
GroupAggregate  (cost=612.40..612.75 rows=1 width=40)
                (actual time=812.331..812.334 rows=1 loops=1)
  Group Key: m.name
  ->  Nested Loop  (cost=8.60..611.95 rows=12 width=16)
                   (actual time=0.298..798.112 rows=1400000 loops=1)
        ->  Index Scan using merchants_pkey on merchants m
              (cost=0.29..8.31 rows=1 width=24)
              (actual time=0.019..0.021 rows=1 loops=1)
              Index Cond: (merchant_id = 4021)
        ->  Index Scan using payments_merchant_id_idx on payments p
              (cost=0.42..603.00 rows=12 width=16)
              (actual time=0.041..760.884 rows=1400000 loops=1)
              Index Cond: (merchant_id = 4021)
Planning Time: 0.298 ms
Execution Time: 813.010 ms
```

No name for what's wrong here yet — only the numbers. What every field in
that plan means — the node tree's nesting, what `cost=` and `rows=` are
before anything runs, what `actual ... rows=` and `loops=` add once it
does, what `Planning Time`/`Execution Time` measure at the bottom — is
covered once in
`primers/explain-field-reference.md#explain-plan-node-shape` and
`primers/explain-field-reference.md#explain-planning-time-vs-execution-time`;
it isn't repeated here. What matters for today: the inner `Index Scan` on
`payments` estimated `rows=12` and actually produced `rows=1400000`, at
the very leaf of the tree
(`primers/explain-field-reference.md#explain-rows-vs-actual-rows`). The
`Nested Loop` above it shows
the identical 12-versus-1,400,000 gap, because a nested loop's own row
estimate is arithmetic performed on its children's estimates — it isn't
a second, independent mistake, it's the first one propagated upward. The
`GroupAggregate` on top looks almost fine (`rows=1`, `actual rows=1`),
because grouping down to one merchant's name collapses 1.4 million rows
to one either way, regardless of which number was right underneath — the
top of this plan would tell you nothing was wrong at all. The instrument
that matters sits two levels down, at the leaf, not at the summary.

## Core concepts

**The cost model is a bet, priced before the cards are dealt.** (What
`cost=` itself represents — the `start..total` pair every node prints —
is covered in `primers/explain-field-reference.md#explain-cost`; what
follows here is what feeds that number, not what it means.)
`seq_page_cost` (default 1.0) and `random_page_cost` (default 4.0) are the
planner's guess at how expensive fetching one page is sequentially versus
at a random offset — the 4:1 ratio assumes spinning disks, which is why
`random_page_cost` is one of the few settings worth lowering on
SSD-backed storage, though this stack doesn't ask you to. The CPU costs
(`cpu_tuple_cost`, `cpu_index_tuple_cost`, `cpu_operator_cost`) price
per-row and per-operation work, orders of magnitude cheaper per unit than
either page cost. None of these numbers are measured from your hardware
by default — they're defaults dating to spinning disks, applied uniformly
to every relation, and the planner multiplies them against **row-count
estimates** it also didn't measure. A cost is a bet built entirely on
other guesses. The row-count guess is the one that breaks first and
breaks worst, because a wrong page-cost ratio degrades a plan gracefully
while a wrong row estimate can flip the plan to a different algorithm
entirely.

**Where the row-count guess comes from.** `ANALYZE` samples a table (the
sample size controlled by `default_statistics_target`, default 100 — the
number of histogram buckets and most-common-value slots per column, not
a percentage or row count) and writes the result to `pg_stats`:
`n_distinct` (an estimate of distinct values, negative when it's stored
as a fraction of row count instead of an absolute number), a
most-common-values list (`most_common_vals` / `most_common_freqs`) for
the values that show up often enough to name individually, and a
histogram (`histogram_bounds`) for everything else. `EXPLAIN`'s `rows=`
comes from combining these: a value in the MCV list gets its exact
recorded frequency; a value that never made the cut gets the leftover
probability mass spread evenly across the remaining estimated distinct
values. Read `pg_stats` directly before trusting any row estimate that
matters:

```sql
SELECT attname, n_distinct, most_common_vals, most_common_freqs
FROM pg_stats
WHERE tablename = 'payments' AND attname = 'merchant_id';
```

Raising `default_statistics_target` gets you a bigger sample and a longer
MCV list — more resolution on a single column's own distribution. It
does nothing for the next problem, which is not about resolution at all.

**The independence assumption, and where it actually fails.** A
multi-column `WHERE` clause is priced, by default, by multiplying each
column's selectivity together — `P(a) × P(b)` — which is only correct
when `a` and `b` are statistically independent. `merchants.country` and
`payments.currency` are not: the generator matches a payment's currency
to its billing merchant's country's primary currency on exactly 95% of
rows, deviating to a genuinely different currency — never a coincidental
match — on the other 5% (`labs/stack/seed/10-generate.sql`). That
conditional match rate is a fixed property of the generator, true of
every payment regardless of which merchant wrote it.

What is **not** fixed, and not something you can read off the
`merchants` table alone, is how much of the actual *payment volume* a
given country carries. Merchant activity in this schema is drawn from a
Zipf distribution (`labs/stack/seed/10-generate.sql`'s `merchant_cdf`),
assigned independently of country — a small number of merchants can
carry a large share of all payments, and which country those particular
merchants happen to belong to is not something the merchant table's own
country breakdown tells you. "Country X is N% of merchants" and
"country X is N% of payment volume" are not the same claim in a
Zipf-skewed schema, and treating them as interchangeable is exactly the
kind of shortcut that produces a false sense of having quantified
something — a single heavy-volume merchant can move a country's real
payment share well past its merchant-count share.

Measure both marginals for real instead of assuming them:
`pg_stats.most_common_freqs` for `merchants.country`, and the equivalent
for `payments.currency`. Multiply the two the way the independence
assumption does, then measure the actual joint rate directly (a plain
`count(*) FILTER (...)` against the join, or `EXPLAIN`'s own `rows=`
versus `actual rows=` on the predicate) and compare. Because the columns
are genuinely correlated — the 95% match rate above — the independence
product will land well below the measured joint rate. Exactly how far
below is a property of *this run's* seeded data, not a number this page
can hand you; computing it from your own `pg_stats` is exercise 2 below,
and it's a better exercise for it — deriving the marginals yourself is
the actual skill this section exists to teach. What doesn't change
regardless of the exact multiple: a bigger `ANALYZE` sample buys more
resolution on each column's own marginal distribution, and does nothing
to teach the planner that the two columns move together.

**Extended statistics are the remedy — for one table.**
`CREATE STATISTICS name (ndistinct, dependencies, mcv) ON col_a, col_b
FROM some_table;` teaches the planner the actual joint behavior of two or
more columns: `ndistinct` corrects combined-cardinality estimates,
`dependencies` records how strongly one column's value predicts another's
(the functional-dependency degree, 0 to 1), and `mcv` stores an explicit
most-common-**combinations** list instead of assuming independence for
the tail. The constraint worth stating plainly, because it is easy to
miss and expensive to discover by trial and error: extended statistics
are scoped to **one table**. `merchants.country` and `payments.currency`
live on different tables — there is no `CREATE STATISTICS` that spans a
join. The seeded correlation is real and it does bias the join's
row estimate, but the direct remedy only exists where both columns
already live in one row. That's exactly what `wide_payments` — Day 2's
denormalized artifact — is for: it carries `merchant_country` and
`currency` on the same table, and `CREATE STATISTICS ... ON
(merchant_country, currency) FROM wide_payments` closes the estimate gap
there. A report that needs this fixed at the join has one honest choice:
point it at the denormalized copy instead, and accept that this is a
schema decision with its own cost (the redundancy Day 2 spent three hours
on), not a free statistics tweak.

**Row-estimate error is the master diagnostic, read from the bottom up.**
Every technique above exists to answer one question: at which node does
`rows=` (estimate) stop matching `actual rows=` (measured)? Read a plan
leaf-first. The deepest node with a real divergence is the one to
explain; every ancestor's divergence is arithmetic inherited from that
node, and explaining the ancestor instead only restates the symptom one
level higher. "The join estimate was wrong" is not a diagnosis if a scan
three levels down was already wrong before the join ever combined
anything.

**Join algorithms want different things.** Nested loop wins when the
outer side is small and the inner side has a supporting index — cost
scales with `outer_rows × inner_lookup_cost`, so a bad `outer_rows`
estimate is exactly what makes a nested loop plan catastrophic instead of
merely suboptimal: PostgreSQL commits to running the inner index scan
once per outer row, and if the actual outer row count is 100,000× the
estimate, that commitment gets executed 100,000× more than planned. Hash
join wants no useful index and enough `work_mem` to hold the smaller side
as an in-memory hash table — this stack's `work_mem=4MB` means it spills
to `temp` files past that, visible under `EXPLAIN (BUFFERS)` as `temp
read`/`temp written` (every `Buffers:` field is decoded in
`primers/explain-field-reference.md#explain-buffers`), which is a signal
to shrink the working set or accept the spill, not to raise `work_mem`
globally (Mistake #3). Merge
join wants both sides already sorted (or cheaply sortable) on the join
key and wins on large, roughly-equal-sized inputs where a hash table
would be expensive to build. **Join order is the genuinely hard part**:
for `N` tables there are `N!` orderings before symmetry reductions, the
planner switches from exhaustive search to the Genetic Query Optimizer
past `geqo_threshold` (default 12 tables), and a wrong row estimate two
joins deep silently steers this search toward an order that looks cheap
on paper and isn't.

**`LATERAL`** lets a subquery on the right side of a join reference
columns from rows on the left — the SQL-standard way to write "for each
merchant, that merchant's three most recent payments," which no ordinary
join can express because ordinary joins can't parameterize a subquery per
outer row. Executed, it behaves like the inner side of a nested loop:
same per-outer-row cost profile, same sensitivity to a bad outer-row
estimate.

**CTE materialization changed in PostgreSQL 12.** Before 12, every `WITH`
clause was an optimization fence: materialized in full, in isolation,
before the outer query touched it, with no predicate push-down across the
boundary. From 12 on, a CTE referenced exactly once is inlined and
optimized as part of the surrounding query by default — `MATERIALIZED`
forces the old fencing behavior back on when you genuinely want an
isolated, single-evaluation snapshot (a CTE with side effects, or one
you deliberately don't want the planner re-costing per reference).

**Rewrites that move the needle, before reaching for a bigger machine:**

- **Sargability.** `WHERE created_at::date = '2024-06-01'` cannot use a
  plain index on `created_at` — the cast wraps the column, so the
  planner can't derive a usable range from it. `WHERE created_at >=
  '2024-06-01' AND created_at < '2024-06-02'` is sargable: same result,
  usable as an index range condition. Any expression on the indexed side
  of a predicate needs a matching expression index (Day 3) or a rewrite
  like this one — there's no third option.
- **`OR` → `UNION ALL`.** `WHERE merchant_id = 4021 OR customer_id =
  9981` frequently can't use either column's index cleanly — the planner
  either falls back to a bitmap OR of two scans (fine, when it happens)
  or a sequential scan (when the estimate says the OR clause isn't
  selective enough to bother). `SELECT ... WHERE merchant_id = 4021 UNION
  ALL SELECT ... WHERE customer_id = 9981` (deduplicated with `UNION` if
  the two sides can overlap) gives the planner two separate, independently
  indexable queries instead of one it has to reason about jointly.
- **Keyset versus `OFFSET` pagination — the arithmetic.** `SELECT * FROM
  payments ORDER BY payment_id LIMIT 20 OFFSET 100000` cannot return page
  5,001 without the executor first producing and discarding pages 1
  through 5,000: PostgreSQL has no way to seek an index to "the 100,000th
  row" without walking it, so it fetches 100,020 index entries in order
  and, for each one not covered by an index-only scan, a heap page to go
  with it, throwing away the first 100,000. At roughly 50 rows per 8&nbsp;KB
  heap page for a `payments`-shaped row, that's on the order of 2,000
  buffer touches spent purely on rows the query already knows it will
  discard — and every subsequent page pays a strictly larger version of
  the same cost, because the discard count grows with the offset.
  Keyset pagination — `WHERE payment_id > :last_seen_id ORDER BY
  payment_id LIMIT 20`, carrying the last row's key forward instead of a
  position — touches only a B-tree descent (`O(log n)`, a handful of
  buffers) plus the 20 rows actually returned, **regardless of how deep
  into the result set you are.** `OFFSET`'s cost is linear in the offset;
  keyset's is flat.
- **The N+1, seen from the database side.** No single slow query shows up
  in a log — the tell lives in `pg_stat_statements`: a `queryid` with
  `calls` in the hundreds or thousands and a `mean_exec_time` under a
  millisecond is individually invisible and collectively the whole
  request's latency budget, one row fetched per iteration of a loop that
  should have been one join. Sort `pg_stat_statements` by
  `total_exec_time`, not `mean_exec_time` (Mistake in
  `catalog-field-reference.md#pg_stat_statements`), to find it.
- **MySQL: `optimizer_trace`.** Where PostgreSQL's `EXPLAIN` shows only
  the winning plan, MySQL's `optimizer_trace` shows every access path the
  optimizer priced and rejected, under `join_optimization` →
  `considered_execution_plans`, each with its own `rows_estimate` and
  cost. Read the rejected paths' costs against the winner's — usually the
  rejected index path's `rows_estimate` is the number that tipped the
  decision away from it. `SET optimizer_trace='enabled=on'`, run the
  query, `SELECT * FROM information_schema.optimizer_trace \G`, and turn
  it back off — it adds overhead to every statement while left on.
- **MongoDB: stage order and pushdown.** An aggregation pipeline runs its
  stages in the order they're written, and the query planner will push a
  `$match` or `$project` earlier when doing so provably doesn't change
  the result — but it will not reorder across a `$lookup`, `$unwind`, or
  `$group`. Writing `$match` after a `$lookup` means the join executes
  against the full collection before anything gets filtered; writing it
  first (or as early as the logic allows) filters before the expensive
  stage runs. **`$lookup` is not a join** in the relational sense — it is
  a per-document, per-batch subquery against the foreign collection, with
  none of a hash- or merge-join's whole-collection algorithms available,
  so an unindexed `$lookup` degrades the way an unindexed nested loop
  does: badly, and linearly in the size of the side being probed. A sort
  or grouping stage that can't be satisfied by an index spills to disk
  and fails outright past 100&nbsp;MB unless `allowDiskUse: true` is set —
  which trades a hard failure for a slow one, not a fix for the missing
  index.

## Predict before you measure

Write these down before running anything:

1. The estimated and actual row counts at the deepest divergent node for
   the merchant capture-totals query below.
2. Whether removing the `n_distinct` override and running `ANALYZE`
   alone will fix that divergence.
3. Your own measured marginals for `merchants.country = 'GB'` and
   `payments.currency = 'GBP'` from `pg_stats`, the row count the
   independence assumption predicts from multiplying them, and the row
   count extended statistics on `wide_payments` actually produces once
   they exist — three numbers you derive from your own seeded data, none
   of them assumed in advance.

## Lab

```sh
cd database_mastery/labs/day04
./break.sh
```

Read the `SYMPTOM` line and nothing else yet. `break.sh` sets a false
`n_distinct` override on `payments.merchant_id`, turns off autovacuum on
`payments`, then runs a bulk `UPDATE` that shifts a large slice of
captured payments onto one specific merchant — with no `ANALYZE`
afterward. Nothing about the schema or the query text changes.

Run `EXPLAIN (ANALYZE, BUFFERS)` on the merchant capture-totals report
yourself before doing anything else — step 2 of the daily loop. Find the
**deepest** node where `rows=` and `actual rows=` diverge; write it to
`/tmp/answer` on `ws` as `divergent_node=<node type>` (for example
`divergent_node=Index Scan`). Then work the fix in two stages, because
one stage is not enough:

1. Discover the `n_distinct` override in `pg_attribute.attoptions` for
   `payments.merchant_id`, remove it (`RESET (n_distinct)`), and run
   `ANALYZE payments;`. Re-read the same `EXPLAIN` you started with —
   proof and diagnosis share one instrument (daily loop, step 6).
2. Separately, work the `merchants.country`/`payments.currency`
   arithmetic above against `wide_payments`, create the extended
   statistics object on the pair, `ANALYZE wide_payments;`, and confirm
   in `pg_stats_ext` that it carries a real `n_distinct`/`dependencies`
   payload, not only an entry in `pg_statistic_ext`.

Full instructions: `labs/day04/README.md`. Verify with
`labs/day04/verify.sh`; it fails loudly, and by name, if you reach for
`enable_nestloop`/`enable_hashjoin`/`enable_seqscan` instead.

## Exercises

**1. Predict a selectivity from `pg_stats`.**
Read `most_common_vals`/`most_common_freqs` for `payments.currency`
directly, and predict the planner's `rows=` estimate for `WHERE currency
= 'JPY'` before running `EXPLAIN`.

**Hint:** a value present in the MCV list uses its recorded frequency
directly; multiply by `pg_class.reltuples` for `payments`, not by
`count(*)`.

**Solution sketch:** `SELECT unnest(most_common_vals::text[]),
unnest(most_common_freqs) FROM pg_stats WHERE tablename='payments' AND
attname='currency';` gives JPY's frequency directly — read it, don't
predict it from Japan's share of the `merchants` table. This schema's
merchant activity is Zipf-skewed, so a currency's share of *payments* is
not the same claim as its billing country's share of *merchants* (see
Core Concepts). Multiply the read frequency by `payments`' `reltuples`
from `pg_class` to get the predicted row count, then compare against
`EXPLAIN`'s `rows=` for the same predicate — they should match closely,
since a single-column MCV lookup is exactly what `pg_stats` is built to
answer well.

**2. Construct a two-column predicate that breaks independence, and
quantify the error.**
Using `merchants.country = 'GB' AND payments.currency = 'GBP'` in a join,
measure both marginals from your own seeded data, compute what
independence predicts for the join from them, and compare that against
the real joint rate and against `EXPLAIN`'s `rows=`/`actual rows=`.

**Hint:** read `P(country='GB')` from `pg_stats` for `merchants.country`
and `P(currency='GBP')` from `pg_stats` for `payments.currency` — do not
turn a merchant-level share into a payment-level share by assuming
activity is spread evenly across merchants. It isn't (see Core
Concepts); measure the payment-level marginal directly instead of
deriving it from the merchant table.

**Solution sketch:** multiply your two measured marginals to get the
independence-assumption estimate of the join's selectivity, then measure
the real joint rate directly (`count(*) FILTER (...) / count(*)` against
the join, or read `actual rows=` off `EXPLAIN ANALYZE` and divide by the
join's total row count). The independence assumption should come out low
by a large multiple — the mechanism is that `payments.currency` mostly
follows its merchant's `country` (the seeded 95% match), which
multiplying two independent marginals cannot capture no matter how
accurate each marginal is on its own. The exact multiple is a property
of your own seeded data — specifically, how much of the Zipf-skewed
payment volume happens to land on GB merchants — and computing it
yourself is the point of this exercise, not a figure to look up.

**3. Fix it with extended statistics and re-measure.**
Create `CREATE STATISTICS payments_country_currency (ndistinct,
dependencies, mcv) ON merchant_country, currency FROM wide_payments;`,
`ANALYZE wide_payments;`, and re-run a query against `wide_payments` with
the same two-column predicate.

**Hint:** query `pg_stats_ext` for the new statistics object's
`dependencies` column — it should land close to 0.95, the exact
country-currency match rate the generator applies to every payment row
regardless of which merchant wrote it. Unlike the marginal frequencies in
exercise 2, this figure isn't affected by the Zipf-skewed merchant
volume — it's a per-row conditional, not a population share.

**Solution sketch:** before the statistics object exists, `EXPLAIN` on
`wide_payments WHERE merchant_country='GB' AND currency='GBP'` shows the
same independence-assumption underestimate you measured in exercise 2.
After `CREATE STATISTICS` and `ANALYZE`, the estimate should move
substantially closer to the real joint rate you measured directly — the
planner is now combining a recorded dependency degree with the
individual marginals instead of assuming they multiply cleanly. The
exact before/after numbers are yours to produce from your own data; the
shape to confirm is that the gap closes by a large amount, not that
either number hits a specific percentage.

**4. Rewrite `OFFSET 100000` as keyset, and compare buffers.**
Run `EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM payments ORDER BY
payment_id LIMIT 20 OFFSET 100000;`, then the keyset equivalent seeded
with the 100,000th `payment_id`, and compare total buffer counts.

**Hint:** the `OFFSET` version's buffer count should scale roughly
linearly with the offset value; the keyset version's should not scale
with it at all.

**Solution sketch:** the `OFFSET` plan shows a single `Limit` atop an
`Index Scan` (or `Index Only Scan`) whose `actual rows=100020` — it
produced and discarded 100,000 rows to return 20 — with a buffer count in
the low thousands. The keyset plan's `Index Scan` shows `actual rows=20`
and a buffer count in the single digits to low tens: a B-tree descent
plus 20 leaf/heap pages, independent of how deep into the table
`:last_seen_id` sits.

**5. Find the N+1 in `pg_stat_statements`.**
Sort `pg_stat_statements` by `total_exec_time` and look for a `queryid`
with a high `calls` count and a low `mean_exec_time` that, together,
dominate the total.

**Hint:** `SELECT query, calls, mean_exec_time, total_exec_time FROM
pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;` — the N+1 is
never the top row by `mean_exec_time` alone.

**Solution sketch:** a query shaped like `SELECT * FROM payment_methods
WHERE customer_id = $1` with `calls` in the thousands and
`mean_exec_time` under a millisecond, whose `total_exec_time` still ranks
near the top of the list, is a loop-per-row fetch that should have been
one join against `payment_methods` keyed on a batch of `customer_id`
values instead of one call per customer.

**6. Reorder a MongoDB pipeline so `$match` precedes `$lookup`.**
Take an aggregation on `payment_events` that joins to `merchant_catalog`
via `$lookup` and filters on `merchant_id` afterward; move the `$match`
before the `$lookup` and compare `executionStats`.

**Hint:** `explain("executionStats")` on an aggregation reports
`nReturned` and timing per stage — compare the `$lookup` stage's own
document-examined count before and after the reorder.

**Solution sketch:** with `$match` after `$lookup`, the join stage runs
against every document in `payment_events`, and `$lookup`'s internal
subquery executes once per input document regardless of whether that
document will survive the later filter. With `$match` first, `$lookup`
only ever runs against the documents that already passed the filter —
the join's own work shrinks by whatever fraction the filter removes, with
no change to what the pipeline returns.

## Anti-patterns / common mistakes

- **Disabling a plan node type to force a plan.** `SET enable_nestloop =
  off;` (or `enable_hashjoin`, or `enable_seqscan`) makes today's query
  fast and hides the row-estimate error that caused the bad choice in the
  first place. The next data shift produces a new bad estimate, and this
  switch either does nothing for it or actively prevents the plan that
  would have handled it correctly. `verify.sh` for this lab fails if it
  finds any of these three off, anywhere.
- **Raising `default_statistics_target` globally instead of fixing the
  correlated pair.** More histogram buckets and a longer MCV list improve
  a single column's own resolution; they do not teach the planner that
  two columns move together. The independence-assumption error from a
  correlated predicate persists at any statistics target until extended
  statistics — or a rewrite that avoids the correlated join — actually
  addresses it.
- **Reading the top of the plan instead of the deepest divergence.** A
  `GroupAggregate` or `Limit` at the root can look accurate — matching
  cardinality at the top tells you nothing about a mis-estimated scan
  three joins beneath it. Read bottom-up, every time.

## Teardown

`labs/day04/teardown.md`.
