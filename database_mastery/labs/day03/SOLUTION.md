# Day 3 solution — the 200× report and the unindexed event stream

Chains written in `journal.md`'s exact template, one per possible
`break.sh` outcome. `break.sh` picks one of the three PostgreSQL
scenarios below at random on every run — find yours by reading
`docker compose -p dbmastery exec ws cat /tmp/day03-query.sql` and
matching its table and predicates against the three headers below. The
MongoDB scenario at the end runs every time, unconditionally.

**Every buffer count, row count, and millisecond figure below is a
worked illustration of realistic shape, not a number your run is
expected to reproduce exactly.** The columns you need, the reasoning
for their order, and the two-orders-of-magnitude shape of the
before/after gap are what transfer.

---

## Scenario A — merchant settlement summary

**Predictions (written before running anything):**
- `Buffers: shared read=` before any index: predicted ~50,000 (a rough
  guess at "most of the table")
- Achievable as index-only: predicted yes, since the index would carry
  `merchant_id` and `created_at`

**Symptom (verbatim, no interpretation):**
`SYMPTOM: the report query takes over 40 seconds to run, and the
payment_events query for merchant 1950 examines roughly 50,000
documents for every one it returns.`

**Layer:** access method

**Chain of evidence:**

1. Claim: the query in `/tmp/day03-query.sql` is a merchant-scoped,
   date-bounded, status-filtered aggregate over `payments`, grouped and
   sorted by day. | Proof:
   ```
   SELECT date_trunc('day', created_at) AS settlement_day,
          count(*) AS payment_count, sum(amount_minor) AS gross_amount_minor
   FROM payments
   WHERE merchant_id = 15 AND status = 'captured'
     AND created_at >= '2024-06-01' AND created_at < '2024-07-01'
   GROUP BY settlement_day ORDER BY settlement_day;
   ```
2. Claim: no index on `payments` supports this predicate — three
   indexes exist, but none is a leftmost match for `merchant_id`. |
   Proof: `SELECT indexname, indexdef FROM pg_indexes WHERE
   tablename = 'payments';` lists `idx_decoy_1 (status)`, `idx_decoy_2
   (created_at, merchant_id)`, `idx_decoy_3 (created_at)` — none begins
   with `merchant_id`.
3. Claim: the planner falls back to a full sequential scan with an
   in-memory sort that spills to disk. | Proof: `EXPLAIN (ANALYZE,
   BUFFERS)` on the query above → `Seq Scan on payments ... Rows Removed
   by Filter: 4938155`, `Sort Method: external merge Disk: 1584kB`,
   `Buffers: shared hit=612 read=155842`, `Execution Time: 44201.664 ms`.
4. Claim: `merchant_id` is the equality predicate, `created_at` is both
   the range predicate and the sort target, and `status` is high-
   selectivity (~80% `captured`) — not worth indexing on its own. |
   Proof: `SELECT status, count(*) FROM payments GROUP BY status;`
   shows `captured` at roughly 80% of all rows — an index on `status`
   alone (`idx_decoy_1`) would be correctly ignored by the planner at
   that selectivity, which `idx_scan` on `idx_decoy_1` confirms sits at
   0 even after this query has run.

**Diagnosis:** The report needs a composite index leading with the
equality column (`merchant_id`), then the range/sort column
(`created_at`) — `status` stays out of the key, because filtering on it
alone would not narrow the scan meaningfully at 80% selectivity. The
three existing indexes are all wrong shapes: one indexes the wrong
(low-selectivity) column entirely, one has the range column ahead of
the equality column, and one is a redundant prefix of that second one.

**Fix applied:**
```sql
CREATE INDEX idx_payments_merchant_created
  ON payments (merchant_id, created_at);
DROP INDEX idx_decoy_1;
DROP INDEX idx_decoy_2;
DROP INDEX idx_decoy_3;
```
`/tmp/answer` inside `ws`: `index_columns=merchant_id,created_at`

**Proof the fix worked (same instrument re-read):** `EXPLAIN (ANALYZE,
BUFFERS)` on the identical query → `Index Scan using
idx_payments_merchant_created on payments (actual rows=61845
loops=1)`, `Index Cond: ((merchant_id = 15) AND (created_at >=
'2024-06-01'::date) AND (created_at < '2024-07-01'::date))`, `Filter:
(status = 'captured'::text)`, `Buffers: shared hit=12 read=498`,
`Execution Time: 38.216 ms` — `shared read` down from 155,842 to 498
(roughly 313×), execution time down from 44.2 s to 38 ms (roughly
1,160×).

**Prediction error and what it tells me:** predicted ~50,000 pages
before the fix; the real figure was over three times that, because the
prediction didn't account for the external-merge sort re-reading
intermediate runs from disk on top of the base scan's page count — a
`Buffers` prediction for a plan with a `Sort` node has to budget for
the sort's own I/O, not only the scan beneath it.

**What I would check first next time:** `pg_indexes` for the table
before writing any query against it — the shape of the composite
predicate (which columns are equality, which is range/sort) determines
the needed index before a single `EXPLAIN` has to be run to discover it.

---

## Scenario B — disputed-payment listing

**Predictions (written before running anything):**
- `Buffers: shared read=` before any index: predicted ~40,000
- Achievable as index-only: predicted no, because the listing also
  selects `payment_id`, `merchant_id`, and `amount_minor`, none of
  which would be in a plain `(created_at)` index

**Symptom (verbatim, no interpretation):**
`SYMPTOM: the report query takes over 40 seconds to run, and the
payment_events query for merchant 1950 examines roughly 50,000
documents for every one it returns.`

**Layer:** access method

**Chain of evidence:**

1. Claim: the query filters on the single, highly skewed predicate
   `status = 'disputed'`, sorts by `created_at` descending, and takes
   the top 50. | Proof:
   ```
   SELECT payment_id, merchant_id, amount_minor, created_at
   FROM payments WHERE status = 'disputed'
   ORDER BY created_at DESC LIMIT 50;
   ```
2. Claim: `status = 'disputed'` is a rare predicate — a strong
   candidate for a small, targeted index rather than a full-table one. |
   Proof: `SELECT count(*) FILTER (WHERE status = 'disputed'),
   count(*) FROM payments;` → roughly 1% of all rows.
3. Claim: none of the three existing indexes serves this predicate or
   this sort target as a usable prefix. | Proof: `pg_indexes` again
   shows `idx_decoy_1 (status)` — a full index over every row's
   `status`, not filtered to the rare value, and useless for the
   `ORDER BY created_at` half of the query regardless.
4. Claim: without a supporting index, the planner sequentially scans
   the whole table and sorts every row before applying the `LIMIT`. |
   Proof: `EXPLAIN (ANALYZE, BUFFERS)` → `Limit ... -> Sort ... Sort Key:
   created_at DESC ... -> Seq Scan on payments Filter: (status =
   'disputed'::text) Rows Removed by Filter: 4950000`, `Buffers: shared
   read=154980`, `Execution Time: 41732.905 ms`.

**Diagnosis:** `idx_decoy_1`'s full index on `status` is the closest-
looking decoy to a real fix here, and it is still wrong: a plain index
on a column that's 99% one non-matching value pays full maintenance
cost on every write for almost no scan benefit, and it does nothing for
the `ORDER BY`. The correct structure is a **partial** index scoped to
the 1% of rows this query actually needs, on the column the sort
depends on.

**Fix applied:**
```sql
CREATE INDEX idx_payments_disputed_created
  ON payments (created_at) WHERE status = 'disputed';
DROP INDEX idx_decoy_1;
DROP INDEX idx_decoy_2;
DROP INDEX idx_decoy_3;
```
`/tmp/answer` inside `ws`: `index_columns=created_at`

**Proof the fix worked (same instrument re-read):** `EXPLAIN (ANALYZE,
BUFFERS)` → `Limit (actual rows=50 loops=1) -> Index Scan Backward
using idx_payments_disputed_created on payments (actual rows=50
loops=1)`, no `Filter:` line at all (the partial index's own predicate
already guarantees every row it returns is disputed), `Buffers: shared
hit=3 read=9`, `Execution Time: 1.842 ms` — `shared read` down from
154,980 to 9, execution time down from 41.7 s to under 2 ms.

**Prediction error and what it tells me:** predicted the query would
still need a `Filter` on `status` post-fix; the partial index's
predicate made that unnecessary, because the planner only has to prove
the index's `WHERE` clause is implied by the query's, once, at plan
time — not evaluate it per row. The model I was carrying treated
partial indexes as "smaller full indexes," not as indexes that also
remove a runtime filter.

**Comparing partial to full, for scale:** this is Exercise 3, and by
the time you get to it the decoys are already gone (`verify.sh` check 3
requires it), so the full-index side of the comparison needs its own
throwaway index rather than reusing a decoy:
```sql
CREATE INDEX idx_full_created_compare ON payments (created_at);
```
`pg_relation_size('idx_full_created_compare')` reports roughly 123 MB;
`pg_relation_size('idx_payments_disputed_created')` reports roughly
1.3 MB — about 1% of the full index's size, tracking the ~1% selectivity
of `status = 'disputed'` almost exactly. Drop
`idx_full_created_compare` once you've taken the measurement — it
exists only for this comparison, and `verify.sh` does not expect it.

**What I would check first next time:** the predicate's selectivity,
before deciding between a full and a partial index — anything under a
few percent is close to always worth scoping the index to the predicate
rather than indexing the whole column.

---

## Scenario C — daily volume rollup

**Predictions (written before running anything):**
- `Buffers: shared read=` before any index: predicted ~30,000
- Achievable as index-only: predicted yes, assuming `amount_minor` were
  added via `INCLUDE`

**Symptom (verbatim, no interpretation):**
`SYMPTOM: the report query takes over 40 seconds to run, and the
payment_events query for merchant 1950 examines roughly 50,000
documents for every one it returns.`

**Layer:** access method

**Chain of evidence:**

1. Claim: this scenario's query is on `ledger_entries`, not `payments`
   — an equality filter on `direction`, a range on `posted_date`,
   grouped and sorted by `posted_date`. | Proof:
   ```
   SELECT posted_date, sum(amount_minor) AS net_volume_minor
   FROM ledger_entries
   WHERE direction = 'C'
     AND posted_date >= DATE '2024-06-01' AND posted_date < DATE '2024-07-01'
   GROUP BY posted_date ORDER BY posted_date;
   ```
2. Claim: none of the three decoys touch `ledger_entries` at all — they
   were built on `payments`, a plausible-looking distraction for a
   query that isn't on that table. | Proof: `pg_indexes WHERE tablename
   = 'ledger_entries'` returns only the primary key.
3. Claim: `direction` alone is not very selective — double-entry
   bookkeeping means exactly half of `ledger_entries` is `'C'` and half
   is `'D'`. | Proof: `SELECT direction, count(*) FROM ledger_entries
   GROUP BY direction;` → a 50/50 split. On its own, `direction` would
   be a borderline index candidate at best; combined with the
   `posted_date` range it still earns the equality-first slot, because
   pairing it with the range column lets the planner satisfy both as a
   single `Index Cond` rather than a range scan plus a row-by-row
   `Filter`.
4. Claim: without a supporting index, the full 10,000,000-row table is
   scanned. | Proof: `EXPLAIN (ANALYZE, BUFFERS)` → `Seq Scan on
   ledger_entries ... Rows Removed by Filter: 9587920`, `Buffers: shared
   hit=1240 read=92184`, `Execution Time: 41890.204 ms`.

**Diagnosis:** the correct index leads with the equality column
(`direction`) and follows with the range/sort column (`posted_date`),
the same equality-then-range-then-sort ordering as Scenario A, applied
to a different table with a genuinely different selectivity story:
`direction`'s own selectivity is weak, and the index still earns its
keep because it turns two separate predicates into one bounded
`Index Cond` instead of a range scan with a residual filter.

**Fix applied:**
```sql
CREATE INDEX idx_ledger_direction_posted
  ON ledger_entries (direction, posted_date);
DROP INDEX idx_decoy_1;
DROP INDEX idx_decoy_2;
DROP INDEX idx_decoy_3;
```
`/tmp/answer` inside `ws`: `index_columns=direction,posted_date`

**Proof the fix worked (same instrument re-read):** `EXPLAIN (ANALYZE,
BUFFERS)` → `Index Scan using idx_ledger_direction_posted on
ledger_entries (actual rows=412080 loops=1)`, `Index Cond: ((direction =
'C'::bpchar) AND (posted_date >= '2024-06-01'::date) AND (posted_date <
'2024-07-01'::date))`, `Buffers: shared hit=8 read=612`, `Execution
Time: 54.318 ms` — `shared read` down from 92,184 to 612 (roughly 150×),
execution time down from 41.9 s to 54 ms.

**Prediction error and what it tells me:** predicted index-only would
need `amount_minor` in `INCLUDE`; that's still true for the `sum()`, but
I underestimated how much a 50%-selective equality column would still
contribute paired with a range — the model I was carrying treated
"selectivity" as a property of one column in isolation, when what
actually determines the scan's cost is the combined selectivity of the
whole `Index Cond`, not any single column's selectivity read alone.

**What I would check first next time:** for a two-predicate composite
where one predicate looks weak on its own (50/50, here), compute the
*combined* selectivity of both predicates together before ruling the
weak one out of the key — it is usually still worth the equality-first
slot as long as the pair together is meaningfully selective.

---

## MongoDB — payment_events, every run

**Predictions (written before running anything):**
- `totalDocsExamined : nReturned` before any index: predicted ~10,000:1
- Same ratio after the correct index: predicted 1:1

**Symptom (verbatim, no interpretation):** part of the same
`SYMPTOM` line above: "the payment_events query for merchant 1950
examines roughly 50,000 documents for every one it returns."

**Layer:** access method

**Chain of evidence:**

1. Claim: the query filters on `merchant_id` (equality) and sorts on
   `ts` (descending), taking the top 20. | Proof:
   ```js
   db.payment_events.find({ merchant_id: 1950 })
                     .sort({ ts: -1 }).limit(20)
   ```
2. Claim: no index on `payment_events` supports `merchant_id` as a
   leading field. | Proof: `db.payment_events.getIndexes()` returns
   only the default `_id_` index.
3. Claim: without a supporting index, the whole collection is scanned
   and the matches sorted in memory. | Proof:
   `.explain("executionStats")` → `winningPlan: { stage: 'SORT', ...
   inputStage: { stage: 'COLLSCAN', filter: { merchant_id: { '$eq':
   1950 } } } }`, `executionStats: { nReturned: 20, totalDocsExamined:
   2000000, totalKeysExamined: 0 }` — a 100,000:1 examined-to-returned
   ratio, because merchant 1950 sits far from the power-law-favored low
   end of the merchant-id range and has comparatively few events, while
   the scan still reads every one of the collection's 2,000,000
   documents to find them.

**Diagnosis:** the ESR rule calls for `merchant_id` (equality) first,
`ts` (the sort target, no separate range predicate here) second — a
compound index `{ merchant_id: 1, ts: -1 }`.

**Fix applied:**
```js
db.payment_events.createIndex({ merchant_id: 1, ts: -1 })
```

**Proof the fix worked (same instrument re-read):**
`.explain("executionStats")` on the identical query →
`winningPlan: { stage: 'IXSCAN', keyPattern: { merchant_id: 1, ts: -1 } }`,
no `SORT` stage above it (the index already returns rows in the needed
order), `executionStats: { nReturned: 20, totalDocsExamined: 20,
totalKeysExamined: 20 }` — a 1:1 ratio, matching the prediction exactly.

**Prediction error and what it tells me:** the before-fix ratio (100,000:1)
came in an order of magnitude worse than predicted (10,000:1) — the
prediction assumed an even, roughly-uniform miss rate across merchants;
the actual figure is that much worse specifically because merchant 1950
is a cold, low-activity merchant under the power-law skew, so its true
share of the collection is far below the naive "collection size ÷
merchant count" estimate a uniform-data mental model would produce.

**What I would check first next time:** for any `find + sort` on an
unindexed field in this dataset, check whether the equality field is
skewed before predicting the miss ratio — the power-law skew means the
same query shape produces wildly different `totalDocsExamined` figures
depending on whether the equality value lands on a whale or a cold
merchant.
