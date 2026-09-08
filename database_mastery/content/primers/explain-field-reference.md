# EXPLAIN field reference

Every field a query plan can show you, decoded once. Day files link here
instead of re-deriving a field list each time they show a plan. The
numbers in every example below are authored to look realistic and are
internally consistent with each other — they are illustrations of shape,
not a run you should expect to reproduce exactly on your own machine.

## EXPLAIN: plan node shape

A PostgreSQL plan is a tree of nodes, indented to show nesting; a node's
children are the input(s) it operates on. Every node prints, at minimum,
its operation name, `cost=`, `rows=`, and `width=` (estimated average row
size in bytes) at plan time; add `ANALYZE` and it also prints `actual
time=`, `actual rows=`, and `loops=`, measured by actually running the
query:

```
Nested Loop  (cost=1.14..38.92 rows=24 width=96)
             (actual time=0.048..0.512 rows=18 loops=1)
  ->  Index Scan using payments_merchant_id_idx on payments p
        (cost=0.57..12.34 rows=12 width=48)
        (actual time=0.021..0.089 rows=9 loops=1)
        Index Cond: (merchant_id = 4021)
  ->  Index Scan using ledger_entries_payment_id_idx on ledger_entries l
        (cost=0.57..2.20 rows=2 width=48)
        (actual time=0.008..0.009 rows=2 loops=9)
        Index Cond: (payment_id = p.payment_id)
```

Read a plan from the innermost/lowest indentation outward: the deepest
node runs first, and each parent consumes its children's output. The
top-level node's `actual time` is the whole query's runtime, second
number.

## EXPLAIN: cost

`cost=start..total` is two numbers, both in arbitrary planner cost units
(not milliseconds), estimated from table/index statistics — never
measured. `start` is the estimated cost to produce the *first* row; `total`
is the estimated cost to produce *all* rows. For a plain index scan the two
are close together; for a sort or a hash build, `start` is large relative
to `total` because nothing can be returned until the whole input is
consumed and processed.

The wrong reading: comparing `cost` across two different query plans as if
it were a time you could subtract. Cost units aren't calibrated to
wall-clock time and aren't portable between servers with different
`random_page_cost`/`seq_page_cost` settings — use cost only to compare
alternatives the planner considered for *this* query, and use `actual
time` (from `ANALYZE`) for anything you want to reason about as real
duration.

## EXPLAIN: rows vs actual rows

`rows=` (no `actual`) is the planner's pre-execution estimate, derived from
table statistics (`pg_class.reltuples`, most-common-value lists,
histograms). `actual rows=` is what really came out when the query ran.
A large gap between the two — estimated 12, actual 4,800 — means the
planner's statistics are stale or the predicate involves a correlation
the planner can't see (exactly the `merchants.country`/`payments.currency`
correlation this schema is built with; see
`catalog-field-reference.md#pg_class-relpages-and-reltuples` and consider
`CREATE STATISTICS`). A plan that looks fine at the top can still hide a
bad estimate three joins deep — check every node's estimate-vs-actual gap
individually, not only the root's.

## EXPLAIN: loops

`loops=N` on an inner node means that node executed N times — once per
outer row it was invoked for, in a nested loop. `actual rows=` on that node
is the average rows returned **per loop**, not the total across all loops;
multiply `actual rows × loops` to get the node's real total row count. A
node reporting `actual rows=2 loops=9` produced 18 rows in total, not 2 —
skipping the multiplication is the single most common misreading of an
`ANALYZE` plan.

## EXPLAIN: Buffers

Add `BUFFERS` to `EXPLAIN (ANALYZE, BUFFERS)` and every node reports the
page-level I/O it did:

```
Buffers: shared hit=842 read=310 dirtied=4
```

- `shared hit` — pages found already in `shared_buffers`; no I/O below
  PostgreSQL happened for these.
- `shared read` — pages not in `shared_buffers`, fetched from the OS page
  cache or disk; PostgreSQL can't tell you which of those two, so a high
  `read` isn't automatically physical disk I/O.
- `shared dirtied` — pages this node caused to become dirty (changed but
  not yet written back) — normal on writes, a signal worth noticing on a
  plain read.
- `shared written` — pages this backend itself flushed to disk (usually
  only under memory pressure forcing an early writeback).
- `temp read`/`temp written` — pages spilled to on-disk temp files because
  a sort or hash exceeded `work_mem`. This stack's `work_mem=4MB` is
  deliberately small, so expect to see `temp` appear on sorts and hash
  joins over any nontrivial slice of `payments` or `ledger_entries` —
  that's the intended lesson, not a misconfiguration to fix by raising
  `work_mem` globally.

The wrong reading: treating `shared read` as "this many disk seeks
happened." With `shared_buffers=256MB` well below the working set, a
`shared read` miss very often still resolves from the OS page cache. Pair
`BUFFERS` with `track_io_timing` (already on in this stack) and look at
`I/O Timings` for a real read-latency signal instead.

## EXPLAIN: Planning Time vs Execution Time

Two separate numbers printed once, at the very end of the plan, controlled
by the `SUMMARY` option. `SUMMARY` defaults to on when `ANALYZE` is used
and off otherwise — a plain `EXPLAIN` with no `ANALYZE` prints neither
line unless you ask for `EXPLAIN (SUMMARY)` explicitly:

```
Planning Time: 0.312 ms
Execution Time: 41.884 ms
```

`Planning Time` is the cost of choosing the plan — parsing, looking up
statistics, considering join orders. `Execution Time` is running the
chosen plan. The wrong reading: assuming planning time is negligible and
skippable to eyeball. On a query hitting a table with many partitions or a
complex partial-index set, planning time itself can be the dominant cost —
check it explicitly rather than assuming all the time is in execution.

## EXPLAIN: Rows Removed by Filter

Appears on a scan node when it has a `Filter:` condition (evaluated after
the rows are fetched) in addition to, or instead of, an `Index Cond:`
(evaluated as part of the fetch itself):

```
->  Seq Scan on payments  (actual rows=1204 loops=1)
      Filter: (status = 'disputed')
      Rows Removed by Filter: 48796
```

This counts rows the scan read and then discarded because they failed the
filter — proof the scan examined far more rows than it returned. The
wrong reading: seeing a `Filter:` line and assuming an index is already
being used to narrow the search — a `Filter` alone (no `Index Cond`) means
the condition could not be pushed into an index lookup at all; the scan
read every row the outer node handed it and checked the condition
row-by-row after the fact.

## EXPLAIN: Heap Fetches

Appears only on an `Index Only Scan`:

```
->  Index Only Scan using payments_merchant_id_idx on payments
      (actual rows=812 loops=1)
      Heap Fetches: 96
```

An index-only scan is supposed to avoid the heap entirely by answering
from the index alone — but it can only trust the index's own copy of a row
when the visibility map says the row's page is all-visible to every
current transaction. `Heap Fetches` counts how many of the returned rows
failed that check and required an extra trip to the heap to confirm
visibility. The wrong reading: treating any nonzero `Heap Fetches` as a
sign the index is broken — it means the table has recent, not-yet-vacuumed
writes on the pages those rows live on. A high count relative to `actual
rows` says "run `VACUUM`, or wait for autovacuum," not "rebuild the
index."

## EXPLAIN: Workers Planned/Launched

Appears at the top of a plan using parallel query:

```
Gather  (cost=1000.00..48291.10 rows=4200 width=64)
         (actual time=2.1..89.4 rows=4200 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  ->  Parallel Seq Scan on ledger_entries
        (actual rows=1400 loops=3)
```

`Workers Planned` is how many parallel workers the planner budgeted for
based on `max_parallel_workers_per_gather` and the estimated table size;
`Workers Launched` is how many actually started — can be lower than
planned if `max_worker_processes` is already saturated by other
concurrent queries. Note the inner node's `loops=3`: with 2 workers plus
the leader itself doing a share of the scan, `actual rows` there is again
per-worker, not the total — the same multiplication rule as `loops` above
applies here too, so `Gather`'s own `actual rows` (already the summed
total) is the number to read, not the child's.

## EXPLAIN: PostgreSQL worked example

Annotated, against the canonical schema — a merchant's recent disputed
payments joined to their ledger lines:

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.payment_id, p.amount_minor, l.direction, l.amount_minor
FROM payments p
JOIN ledger_entries l USING (payment_id)
WHERE p.merchant_id = 4021 AND p.status = 'disputed';
```

```
Nested Loop  (cost=4.60..156.22 rows=6 width=40)
             (actual time=0.061..0.410 rows=4 loops=1)
  Buffers: shared hit=38 read=6
  ->  Index Scan using payments_merchant_id_idx on payments p
        (cost=0.57..44.11 rows=3 width=24)
        (actual time=0.032..0.198 rows=2 loops=1)
        Index Cond: (merchant_id = 4021)
        Filter: (status = 'disputed')
        Rows Removed by Filter: 71
        Buffers: shared hit=14 read=3
  ->  Index Scan using ledger_entries_payment_id_idx on ledger_entries l
        (cost=0.57..37.24 rows=2 width=24)
        (actual time=0.009..0.010 rows=2 loops=2)
        Index Cond: (payment_id = p.payment_id)
        Buffers: shared hit=24 read=3
Planning Time: 0.284 ms
Execution Time: 0.487 ms
```

Reading it top to bottom: the outer `Index Scan` used the merchant-id
index but had to `Filter` on `status` afterward (no index on `status`
here), discarding 71 non-disputed rows it had to fetch anyway — a
candidate for a partial or composite index if this query runs often. The
inner scan ran twice (`loops=2`, matching the outer's 2 actual rows) and
its `actual rows=2` is per loop, so it returned 4 ledger lines in total,
matching the top node's `actual rows=4`.

## EXPLAIN: MySQL FORMAT=JSON

`EXPLAIN FORMAT=JSON SELECT ...` returns nested `query_block` objects. The
fields worth knowing, per table accessed:

| Field | Meaning |
|---|---|
| `table.table_name` | Table (or derived table) this step accesses |
| `access_type` | `const`/`eq_ref`/`ref`/`range`/`index`/`ALL` — `ALL` is a full table scan |
| `possible_keys` | Indexes MySQL considered for this access |
| `key` | Index actually chosen (`null` means none was used) |
| `used_key_parts` | Which columns of a composite index were actually applied |
| `rows_examined_per_scan` | Estimated rows read per invocation of this step |
| `rows_produced_per_join` | Estimated rows this step contributes after filtering |
| `filtered` | Estimated **percentage** of `rows_examined_per_scan` surviving non-indexed conditions |
| `cost_info.read_cost` / `eval_cost` | Estimated cost to read rows / evaluate conditions on them |
| `used_columns` | Columns actually needed — tells you whether a covering index is possible |

The wrong reading: treating `filtered` as a row count. It is a percentage
(0–100) of `rows_examined_per_scan` — a step examining 50,000 rows with
`"filtered": "2.00"` still produces roughly 1,000 rows, not 2.

## EXPLAIN: optimizer_trace

`SET optimizer_trace='enabled=on'; SELECT ...; SELECT * FROM
information_schema.optimizer_trace \G` — this is the tool for "why didn't
MySQL use the index I expected," one level deeper than `EXPLAIN`.
`EXPLAIN` shows only the plan MySQL chose; `optimizer_trace` shows the
`considered_execution_plans` array — every access path the optimizer
priced out and rejected, with the cost it computed for each, inside a
`join_optimization` section. Read the rejected plans' costs against the
winning plan's cost to see exactly which estimate (usually `rows_estimate`
on the rejected index path) tipped the decision. Remember to `SET
optimizer_trace='enabled=off'` afterward — it adds overhead to every
subsequent statement on the session while left on.

## EXPLAIN: MySQL worked example

```
EXPLAIN FORMAT=JSON
SELECT payment_id, amount_minor
FROM payments
WHERE merchant_id = 4021 AND status = 'disputed';
```

```json
{
  "query_block": {
    "select_id": 1,
    "cost_info": { "query_cost": "18.45" },
    "table": {
      "table_name": "payments",
      "access_type": "ref",
      "possible_keys": ["idx_merchant_id"],
      "key": "idx_merchant_id",
      "used_key_parts": ["merchant_id"],
      "rows_examined_per_scan": 73,
      "rows_produced_per_join": 3,
      "filtered": "4.00",
      "cost_info": { "read_cost": "16.99", "eval_cost": "1.46" },
      "used_columns": ["payment_id", "merchant_id", "status", "amount_minor"]
    }
  }
}
```

`key: idx_merchant_id` confirms the merchant-id index was used;
`used_key_parts` shows only `merchant_id` was applied by the index — the
`status = 'disputed'` half of the `WHERE` clause is evaluated as a
non-indexed filter over the 73 rows the index handed back, which is why
`filtered` is a low 4% and `rows_produced_per_join` (3) is far below
`rows_examined_per_scan` (73).

## EXPLAIN: MongoDB executionStats

`db.collection.find({...}).explain("executionStats")` on
`payment_events`/`merchant_catalog`. The fields worth knowing live under
`executionStats`, with one exception noted below:

| Field | Meaning |
|---|---|
| `nReturned` | Documents actually returned to the caller |
| `totalKeysExamined` | Index entries examined across the whole plan |
| `totalDocsExamined` | Documents fetched from the collection itself |
| `executionTimeMillis` | Wall-clock time for the query as measured by this explain run |
| `executionStages.stage` | The stage tree — see below |

`rejectedPlans` is a sibling of `winningPlan`, both nested under
`queryPlanner` rather than `executionStats` — the other candidate plans
the query planner priced out and did not choose, kept separate from the
stats of the plan that actually ran.

Stage values that matter: `COLLSCAN` (full collection scan, no index used),
`IXSCAN` (walking an index), `FETCH` (given index entries, going to fetch
the actual document), `SORT` (an in-memory sort, meaning no index supplied
the order — expensive and spillable past 100MB without `allowDiskUse`).

The wrong reading: comparing `nReturned` to `totalDocsExamined` and calling
them close enough. An `IXSCAN` feeding a `FETCH` can have
`totalKeysExamined` far above `totalDocsExamined` (a compound index
examined many entries before the equality/range predicates narrowed
things — normal), but a **`COLLSCAN`** with no `limit()` (or one paired
with a blocking `SORT`, which must still consume the whole input) has
`totalDocsExamined` equal to the full collection size regardless of
`nReturned` — a `COLLSCAN` with a `limit()` and no sort can stop early
and examine far fewer. Where it does scan the whole collection, the ratio
`nReturned / totalDocsExamined` close to zero under `COLLSCAN` is the
unused-index signal to act on, the same shape as `pg_stat_user_indexes`'
`idx_scan`.

## EXPLAIN: MongoDB worked example

```js
db.payment_events.find(
  { merchant_id: 4021, type: "capture" }
).explain("executionStats")
```

```json
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": {
        "stage": "IXSCAN",
        "indexName": "merchant_id_1_ts_1",
        "keyPattern": { "merchant_id": 1, "ts": 1 }
      }
    },
    "rejectedPlans": []
  },
  "executionStats": {
    "nReturned": 214,
    "totalKeysExamined": 340,
    "totalDocsExamined": 340,
    "executionTimeMillis": 3
  }
}
```

`rejectedPlans` is empty because only one index matched the query shape —
if a second index on `type` alone existed, the planner would have priced
both and this array would show the loser with its own `totalKeysExamined`.
`totalKeysExamined` (340) exceeds `nReturned` (214): the index scan on
`merchant_id_1_ts_1` narrowed by `merchant_id` but still walked entries for
every `ts` value before the `type` filter (not part of the index key)
dropped the rest — a candidate to add `type` into the compound index,
following ESR (see `GLOSSARY.md`).
