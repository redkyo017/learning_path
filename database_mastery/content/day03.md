# Day 3 — Access methods: indexes, measured

**Layer:** access method
**Budget:** 3 h — 1 h B-tree anatomy, selectivity, and composite/partial/covering indexes on PostgreSQL, with MySQL's secondary-index anatomy folded in; 30 min MongoDB's ESR rule and index intersection; 1.5 h lab: diagnose and fix an injected pathology across all three engines, then verify.

## Why this matters

Most "the database is slow" tickets resolve to one missing index or one
wrong one, and most attempted fixes make it worse: an index gets added
that the planner then declines to use, or an index gets added on the
wrong column of a composite predicate and buys nothing. The difference
between "this index helps" and "this index is dead weight the planner
correctly ignores" is entirely readable from `EXPLAIN (ANALYZE, BUFFERS)`
— not from intuition about what "should" be fast, and not from the plain
`EXPLAIN` that returns before the query has actually run. Mistake 2 in
`STRATEGY.md` is built for exactly this day: indexes added by guessing,
and never removed, because nothing in a default workflow ever asks
`pg_stat_user_indexes` whether they're used.

## Read the instrument first

Before any index exists on `payments` beyond its primary key, a
merchant's monthly settlement report — count and gross amount of
captured payments, grouped by day — reads like this:

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('day', created_at) AS settlement_day,
       count(*)                      AS payment_count,
       sum(amount_minor)             AS gross_amount_minor
FROM payments
WHERE merchant_id = 15
  AND status = 'captured'
  AND created_at >= '2024-06-01'
  AND created_at <  '2024-07-01'
GROUP BY settlement_day
ORDER BY settlement_day;

                                                        QUERY PLAN
---------------------------------------------------------------------------------------------------------------------
 GroupAggregate  (cost=161234.50..161897.34 rows=30 width=24) (actual time=4402.887..44188.312 rows=30 loops=1)
   Group Key: (date_trunc('day'::text, created_at))
   ->  Sort  (cost=161234.50..161389.75 rows=62100 width=16) (actual time=4402.801..44012.556 rows=61845 loops=1)
         Sort Key: (date_trunc('day'::text, created_at))
         Sort Method: external merge  Disk: 1584kB
         ->  Seq Scan on payments  (cost=0.00..156233.00 rows=62100 width=16) (actual time=0.045..43820.114 rows=61845 loops=1)
               Filter: ((merchant_id = 15) AND (status = 'captured') AND (created_at >= '2024-06-01'::date) AND (created_at < '2024-07-01'::date))
               Rows Removed by Filter: 4938155
 Planning Time: 0.418 ms
 Execution Time: 44201.664 ms
 Buffers: shared hit=612 read=155842
```

Nothing above names "index" yet. Read what's actually there first: a
`Seq Scan` that examined 5,000,000 rows and threw away 4,938,155 of them
one at a time (`Rows Removed by Filter`), a `Sort` that spilled to disk
because the result of that scan was too large for `work_mem=4MB`
(`Sort Method: external merge`), and `Buffers: shared read=155842` — the
number that matters. 155,842 8 KB pages is roughly 1.2 GB fetched from
outside `shared_buffers` (256 MB, well under `payments`' working set by
design — see `global-constraints.md`'s stack-tuning rationale) for a
query that returns 30 rows. `Execution Time: 44201.664 ms` is the
symptom the learner sees; `Buffers: shared read` is the reason. See
`content/primers/explain-field-reference.md#explain-buffers` and
`#explain-rows-removed-by-filter` for the fields themselves.

The MongoDB equivalent, before any supporting index exists on
`payment_events`:

```
db.payment_events.find({ merchant_id: 1950 })
                  .sort({ ts: -1 })
                  .limit(20)
                  .explain("executionStats")

{
  queryPlanner: {
    winningPlan: {
      stage: 'SORT',
      sortPattern: { ts: -1 },
      inputStage: { stage: 'COLLSCAN', filter: { merchant_id: { '$eq': 1950 } }, direction: 'forward' }
    }
  },
  executionStats: {
    nReturned: 20,
    executionTimeMillis: 812,
    totalKeysExamined: 0,
    totalDocsExamined: 2000000
  }
}
```

`totalDocsExamined: 2000000` against `nReturned: 20` is a 100,000:1
ratio — every document in the collection read and most of them thrown
away, then sorted in memory (`stage: 'SORT'` sitting on top of a
`COLLSCAN`) because nothing pre-orders the matching subset by `ts`. See
`content/primers/explain-field-reference.md#explain-mongodb-executionstats`.

## Core concepts

**B-tree anatomy.** A B-tree index is a balanced tree of fixed-size
pages: internal pages hold separator keys and pointers to child pages,
leaf pages hold the indexed key values plus a pointer back to the row
(`ctid` in PostgreSQL, the primary key value in InnoDB, the document's
`_id` — or the shard key plus `_id` on a sharded collection — in
WiredTiger). Height barely matters: a B-tree on hundreds of millions of
rows is typically 3-4 levels deep, so the difference between a
"shallow" and a "deep" index is one or two extra page reads, usually
already cached. What matters is leaf-page count — the number of pages
that must actually be visited to satisfy a scan — because every leaf
page not already in the buffer pool is a `shared read`, and that count
scales with the number of matching rows and the index's row width, not
with tree height. This is why a wide index over the same number of rows
costs more per lookup, and it is exactly the mechanism `journal.md`'s
Day 1 entry measures for InnoDB primary keys: a wider key inflates every
index whose leaf pages carry it as a pointer or a value.

**Selectivity, and when a sequential scan wins.** Selectivity is the
fraction of rows a predicate matches. `status = 'disputed'` matches
about 1% of `payments` — highly selective, a strong index candidate.
`status = 'captured'` matches about 80% — the planner will (correctly)
prefer a sequential scan over an index on `status` alone at that
selectivity, because a sequential scan reads pages once, in physical
order, while an index scan at 80% selectivity would touch nearly every
heap page anyway, in random order, plus every index leaf page on top.
An index that would force worse I/O than the scan it's meant to replace
is not a bug in the planner declining to use it — it is the planner
doing its job. `idx_decoy_1` in this lab is built on `status` for
exactly this reason: it exists, it is well-formed, and using it would be
a mistake the planner is right to avoid.

**Composite column order: equality, then range, then sort.** A
composite B-tree index's leaf pages sort by its first column, then by
its second column within each value of the first, and so on — the same
prefix structure a phone book has by last name, then first name. For a
predicate with one or more equality conditions, one range condition, and
a sort, the ordering rule that gets the most out of a single index is
equality columns first, range columns next, and sort columns last — and
when a range predicate and the sort target are the same column, as they
usually are in this dataset (`created_at >= ... AND created_at < ...
ORDER BY created_at`), that one column satisfies both slots at once.
Put the range column before the equality column and the index is still
usable, only worse: the equality condition can no longer prune the leaf
range the index scan walks, so it degrades to a `Filter` evaluated
row-by-row over a wider slice of the index. `idx_decoy_2` in this lab
is a composite index built exactly backwards — the range column first,
the equality column second — to make that degradation visible in
`EXPLAIN` rather than asserted in prose.

The **leftmost-prefix constraint** follows directly from that leaf
ordering: an index on `(a, b, c)` can serve a predicate on `a` alone, or
on `a` and `b`, but not on `b` alone or on `b` and `c` without `a` —
because without a value for `a`, the index has no way to jump to a
useful starting point in leaf-page order. `idx_decoy_3` is a
single-column index on `created_at` that happens to be a strict prefix
of `idx_decoy_2`'s `(created_at, merchant_id)` — meaning anything
`idx_decoy_3` can do, `idx_decoy_2` can already do, and `idx_decoy_3`
is pure redundant maintenance overhead sitting next to it.

**Index-only scans and the visibility map.** An index that carries every
column a query needs — a **covering index** — lets PostgreSQL answer
the query from the index leaf pages alone, skipping the heap. It can
only trust the index's own copy of a row, though, when the visibility
map says that row's heap page is all-visible to every current
transaction; a row on a recently-written, not-yet-vacuumed page forces a
`Heap Fetch` to confirm visibility even though the index had the data.
`Heap Fetches` climbing toward `actual rows` on an `Index Only Scan`
means "this table has recent writes VACUUM hasn't caught up to," not
"the index is broken" — see
`content/primers/explain-field-reference.md#explain-heap-fetches`.
**`INCLUDE`** columns extend a B-tree with payload that isn't part of
the key — not usable for searching or ordering, but present at the leaf
so a query that only filters and sorts on the key columns but also
*selects* an `INCLUDE`d column can still go index-only.

**Partial indexes for skewed predicates.** An index built with a `WHERE`
clause covers only the rows matching that predicate. `status =
'disputed'` at roughly 1% of `payments` is the textbook case: a partial
index `ON payments (created_at) WHERE status = 'disputed'` is a fraction
of the size of the same column indexed over the whole table, cheaper to
maintain on every write to a non-disputed row (because non-disputed
writes never touch it), and equally fast for the query it targets,
because the planner only needs to prove a partial index's predicate is
implied by the query's `WHERE` clause to use it.

**Expression indexes and sargability.** A predicate is **sargable**
("search-argument-able," see `content/GLOSSARY.md`) when an index can
evaluate it directly against stored key values. `created_at >=
'2024-06-01'` is sargable against a plain index on `created_at`;
`date(created_at) = '2024-06-01'` is not, because the planner would have
to compute `date(created_at)` for every row to compare it — a function
wrapped around the indexed column defeats the index unless an
expression index exists on `date(created_at)` specifically. The fix
is nearly always to rewrite the predicate sargable, not to build the
expression index, because a range on the untransformed column is both
cheaper to maintain and reusable by more queries.

**GIN, GiST, and BRIN.** B-tree covers equality and range on scalar,
ordered types — the large majority of this schema. GIN indexes
multi-valued data (array containment, full-text search, JSONB key
existence) where one row produces many index entries; GiST indexes
data with no single sort order (geometric containment, range-type
overlap); neither has a natural target in this canonical schema, which
carries no array or JSONB columns, so they're named here and not
exercised. BRIN is different: it stores only the min/max value per
block range rather than one entry per row, which makes it tiny and
nearly maintenance-free, and it wins specifically when a column
correlates strongly with physical row order. `ledger_entries.posted_date`
is exactly that column — rows are inserted in `payments.created_at`
order and `posted_date` is derived from it — so a BRIN index there
answers a date-range scan by eliminating whole block ranges instead of
walking a B-tree, at a small fraction of the storage cost.

**MySQL: secondary index → primary key lookup.** Every InnoDB secondary
index stores the table's primary key value as its row pointer, not a
physical offset — so a row lookup through a secondary index is really
two lookups: the secondary index's B-tree, then the clustered (primary
key) index's B-tree using the value that lookup returned. Day 1's measurement
already put a number on the consequence: a wide primary key gets copied
into every secondary index the table carries, inflating each one by the
same width difference, not once but per index. Nothing new needs
re-deriving here — every composite or partial index built today on a
MySQL table is paying that same primary-key tax underneath, silently.

**MongoDB: ESR, compound prefixes, index intersection, unanchored
regex.** The **ESR** rule — Equality, Sort, Range (see
`content/GLOSSARY.md`) — orders a compound index's fields the same way
PostgreSQL's rule orders a composite index's columns: fields tested for
equality go first, because they collapse the most of the index's key
space per query. Where the two rules diverge is what comes second:
MongoDB's ESR places *sort* fields before *range* fields, while the
PostgreSQL guidance above put *range* before *sort* — and both are the
same underlying goal reaching a different answer because they usually
collide differently. In this dataset's queries the range predicate and
the sort target are typically the same field (`created_at`, `ts`), so
the two rules never actually conflict — equality first, then one field
doing double duty as range-and-sort. When a query's sort field and range
field genuinely differ, MongoDB's own guidance is the sharper one to
follow for that engine: an equality-range-sort composite risks an
in-memory sort that ESR's equality-sort-range ordering avoids, because a
B-tree/WiredTiger index can serve a sort directly only from a fully
fixed (equality) or a single trailing range prefix, not from the
far side of one. Say it plainly: equality, range, and sort is the shape
both engines are reasoning about — they only disagree on whether range
or sort earns the second slot, and that disagreement is where reading
the actual `explain()` output, not the mnemonic, decides it.

A compound index's usable prefixes follow the same leftmost-prefix
constraint as a PostgreSQL composite index — an index on `{a: 1, b: 1,
c: 1}` serves queries on `a`, on `a` and `b`, or on all three, not on
`b` or `c` alone. **Index intersection** — MongoDB combining two
single-field indexes to answer one query — exists, but it rarely
rescues a badly-shaped index set in practice: it requires building and
merging two full result sets before applying the rest of the query, is
usually slower than one well-ordered compound index, and the planner
frequently prefers a plain collection scan over it anyway. Design the
compound index for the query; don't rely on intersection to average two
wrong indexes into one right one. Finally, **unanchored `$regex`**
(`{ name: /foo/ }`, no leading `^`) cannot use an index B-tree's sort
order at all — WiredTiger has to test every candidate string —
because the index is sorted by full string value and a pattern that
could match anywhere within the string doesn't correspond to any
contiguous range of that sort order; only a regex anchored at the start
(`/^foo/`) can be served as a prefix range scan.

## Predict before you measure

Write these down before running anything, per `STRATEGY.md`'s daily
loop step 3:

1. `Buffers: shared read=` for the report query in `ws:/tmp/day03-query.sql`,
   before any correct index exists and after you build one. State a
   number for each, not only "lower."
2. Whether an index-only scan is achievable for that same query, and
   name specifically what would prevent it if it isn't (a selected or
   filtered column absent from the index's key and `INCLUDE` list, or a
   visibility map that hasn't caught up on a recently-written page).
3. The `totalDocsExamined : nReturned` ratio for the `payment_events`
   query, before and after you add the supporting index.

## Lab

`break.sh` picks one of three report queries at random — a merchant
settlement summary, a disputed-payment listing, or a daily volume
rollup — each backed by a genuinely different correct index shape, and
writes the chosen query's text to `/tmp/day03-query.sql` inside `ws`.
Read that file first; it is the query you are optimizing this run, and
which one you get is not fixed in this document because it isn't fixed
at run time.

```bash
bash labs/day03/break.sh
docker compose -p dbmastery exec ws cat /tmp/day03-query.sql
```

`break.sh` also plants three decoy indexes — `idx_decoy_1`,
`idx_decoy_2`, `idx_decoy_3` — each wrong in one of the ways named in
Core concepts above, and drops the MongoDB `payment_events` pathology
into place: a query filtering on `merchant_id` and sorting by `ts` with
no supporting index. It prints exactly one `SYMPTOM` line. Diagnose from
`EXPLAIN (ANALYZE, BUFFERS)`, `pg_stat_user_indexes` (see
`content/primers/catalog-field-reference.md#pg_stat_user_indexes`), and
`db.payment_events.find(...).explain("executionStats")` — write the
evidence chain in `journal.md` before touching a fix, per the daily
loop's step 5.

Four things have to be true for `verify.sh` to pass, and all four are
checked independently:

1. `/tmp/answer` inside `ws`, containing exactly one line,
   `index_columns=<col1>,<col2>` (lowercase, no spaces around `=` or
   after the comma), naming the columns of the index you built, in
   order, for the query `break.sh` handed you.
2. That query completes in well under 2 seconds under
   `EXPLAIN (ANALYZE)`, using an `Index Scan` or `Index Only Scan` — not
   a `Seq Scan`.
3. `idx_decoy_1`, `idx_decoy_2`, and `idx_decoy_3` are all gone —
   `pg_stat_user_indexes` returns no row matching `idx_decoy_%`.
4. The `payment_events` query for `merchant_id: 1950` shows stage
   `IXSCAN` and `totalDocsExamined / nReturned <= 2`.

`SOLUTION.md` covers all three possible report queries, since which one
you get is random — find your scenario by the columns and table your
copy of `/tmp/day03-query.sql` names, not by scenario number.

## Exercises

1. `break.sh` handed you one report query. Build the composite index it
   needs and justify the column order you chose.
   **Hint:** name which of the query's predicates is an equality test,
   which is a range test, and which column the `ORDER BY` (or implicit
   grouping order) needs — then apply equality, then range, then sort.
   **Solution sketch:** See `SOLUTION.md` for the specific scenario your
   run drew; the reasoning pattern is identical across all three:
   identify each predicate's role first, only then decide column order,
   and confirm with `EXPLAIN (ANALYZE, BUFFERS)` that the resulting scan
   is an `Index Scan` with a tight `Index Cond`, not a `Filter`.

2. Take the merchant settlement summary shape — `WHERE merchant_id = ?
   AND status = 'captured' AND created_at BETWEEN ? AND ?`, selecting
   `amount_minor` — indexed on `(merchant_id, created_at)`. Show a
   change that turns its scan index-only, and show what `EXPLAIN`
   reports before and after.
   **Hint:** the index's key columns get it to the right leaf range;
   they don't by themselves let it skip the heap for columns the query
   only reads or filters, not searches by.
   **Solution sketch:** `CREATE INDEX ... ON payments (merchant_id,
   created_at) INCLUDE (status, amount_minor);`. Before: `Index Scan`
   with a heap fetch per matching row to re-check `status` and read
   `amount_minor`. After: `Index Only Scan`, `Heap Fetches: 0` on an
   already-vacuumed table — both the equality `Filter` on `status` and
   the `SELECT`ed `amount_minor` are answerable from the index's
   `INCLUDE` payload alone.

3. Build a partial index for the disputed-payment listing
   (`WHERE status = 'disputed' ORDER BY created_at DESC LIMIT 50`) and
   measure the size difference against a full index on the same column.
   **Hint:** build both indexes yourself so the comparison is
   self-contained — do this before you've dropped `verify.sh`'s decoys,
   or after, it doesn't matter, since neither comparison index is one
   of the three graded decoys.
   **Solution sketch:** `CREATE INDEX idx_disputed_created ON payments
   (created_at) WHERE status = 'disputed';` and, as a throwaway
   comparison only, `CREATE INDEX idx_full_created_compare ON payments
   (created_at);`. Compare `pg_relation_size('idx_full_created_compare')`
   against `pg_relation_size('idx_disputed_created')` — the partial
   index, over roughly 1% of the table's rows, comes in at roughly 1%
   of the full index's size (real numbers land close to that ratio but
   rarely land on it exactly; the point is confirming the order of
   magnitude, not matching a specific figure). Drop
   `idx_full_created_compare` once you've taken the measurement; it has
   no other purpose and `verify.sh` does not expect it to exist.

4. Find every index in `payments` with `idx_scan = 0` after you've run
   the report query at least once.
   **Hint:** `pg_stat_user_indexes` carries the counter; a fresh index
   used by nothing still reads zero no matter how correct its shape
   looks on paper.
   **Solution sketch:** `SELECT indexrelname, idx_scan FROM
   pg_stat_user_indexes WHERE relname = 'payments' ORDER BY idx_scan;`
   — the three decoys sit at 0 because nothing ever queries by their
   exact leading column in a way that matches their shape; the index
   you built for the report query should show `idx_scan >= 1` once
   you've actually run that query through `EXPLAIN (ANALYZE)`.

5. Construct a predicate on `payments.created_at` that defeats a plain
   index on that column, then rewrite it to be sargable.
   **Hint:** wrap the column in a function on the left side of the
   comparison and watch the index stop being usable for that predicate.
   **Solution sketch:** `WHERE date(created_at) = '2024-06-15'` forces a
   function evaluation per row and shows up as a `Filter`, not an
   `Index Cond`, against a plain `(created_at)` index. Rewritten
   sargable: `WHERE created_at >= '2024-06-15' AND created_at <
   '2024-06-16'` — same result set, and now the index scan uses an
   `Index Cond` bounding both ends of the range directly.

6. A MongoDB application issues two query shapes against
   `payment_events`: `{ merchant_id: X }` sorted by `ts`, and
   `{ type: Y, ts: { $gte: ... } }` with no sort. Choose between one
   compound index and two single-field indexes, and justify it.
   **Hint:** a compound index only helps a query shape that uses its
   leftmost-prefix columns; a query shape that doesn't touch that prefix
   gets no benefit from it at all, and index intersection is not a
   reliable substitute.
   **Solution sketch:** the two shapes share no common leading field
   (`merchant_id` versus `type`), so one compound index cannot serve
   both as a prefix — build `{ merchant_id: 1, ts: -1 }` for the first
   shape (equality then sort, ESR-ordered) and `{ type: 1, ts: 1 }` for
   the second (equality then range, same field also serving as an
   implicit ascending scan order), rather than reaching for a single
   four-field compound index that would only ever serve one shape as a
   true prefix and add unindexed dead weight to every write for the
   other.

## Anti-patterns / common mistakes

- **An index per column in the `WHERE` clause.** Four single-column
  indexes do not combine the way one well-ordered composite does; the
  planner can intersect them, but a composite index built for the
  actual predicate shape is smaller, faster to maintain, and usually
  faster to scan than any index-intersection plan over several narrower
  ones.
- **Assuming the planner must use an index that exists.** An index is a
  data structure the planner is free to ignore whenever its cost model
  says a sequential scan (or a different index) wins — `idx_decoy_1` on
  low-selectivity `status` demonstrates exactly this. An unused index
  costs write overhead and storage with nothing to show for it; find it
  with `pg_stat_user_indexes`, not by reading the schema and assuming.
- **Measuring with `EXPLAIN` alone rather than `EXPLAIN (ANALYZE,
  BUFFERS)`.** The plain form reports the planner's estimates and
  returns before the query has actually run — it cannot tell you what
  really happened, only what was guessed beforehand. Mistake 1 in
  `STRATEGY.md`.

## Teardown

See `labs/day03/teardown.md`.
