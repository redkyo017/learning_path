# Day 8 answers — all eight pathologies

`gauntlet.sh` selects five of these eight at random, so the run you did
drew a different five than the run next to you. This file covers all
eight anyway, ordered by pathology rather than by any one run, since the
selection is random and there's no meaningful "run order" to sort by.
Each entry is a compressed version of `journal.md`'s evidence-chain shape
— symptom, the first instrument to reach for, the discriminating
observation, the fix, and the proof — not the full chain. Write your own
full chain, for the five you actually drew, before reading the matching
entries here.

Every number below is a worked illustration of realistic shape, the same
convention Day 3's `SOLUTION.md` uses — not a figure your own run is
expected to reproduce exactly. The reasoning pattern is what transfers.

---

## missing_index

**Symptom:** a customer's recent-payments lookup takes several seconds
per call.

**First instrument:** `EXPLAIN (ANALYZE, BUFFERS)` on the exact query
`gauntlet.sh` wrote to `ws:/tmp/day08-missing-index.sql` — read the
instrument raw before naming what's wrong, per the daily loop's step 2.

**Discriminating observation:** the plan is a `Seq Scan` on `payments`
with a `Filter: ((customer_id = ...) AND (status = 'captured'::text))`
and a `Sort` on `created_at` afterward — two equality predicates and a
sort, no range predicate anywhere, which is the tell that this is not
last week's merchant-settlement shape from Day 3. `pg_indexes` on
`payments` shows nothing with `customer_id` as a leading column.

**Fix:** `CREATE INDEX ON payments (customer_id, status, created_at);` —
equality columns first (order between two pure-equality columns doesn't
matter for selectivity the way equality-before-range does, but leading
with the column the application always supplies, `customer_id`, keeps
the index useful for a narrower lookup too), sort column last.

**Proof:** the same `EXPLAIN (ANALYZE)` now shows an `Index Scan` (or
`Index Only Scan`) using the new index, `Index Cond` covering both
equality predicates, no `Sort` node (the index already returns rows in
`created_at` order for a fixed `customer_id`), execution time down from
several seconds to low single-digit milliseconds.

**Answer:** `index_columns=customer_id,status,created_at`

---

## stale_stats

**Symptom:** an account ledger statement that used to return in well
under a second now takes over a minute, with no schema change and no
query change.

**First instrument:** `EXPLAIN (ANALYZE, BUFFERS)` on the account ledger
report join, read bottom-up — Day 4's rule that the deepest divergent
node is the cause, not the top-level symptom.

**Discriminating observation:** the deepest node with a large
actual-versus-estimate gap is the `Index Scan` (or `Bitmap Heap Scan`) on
`ledger_entries` keyed by `account_id` — estimated a handful of rows,
actually returned tens of thousands, because a bulk `UPDATE` reassigned a
slice of `ledger_entries.account_id` onto one target account with no
`ANALYZE` afterward. `pg_attribute.attoptions` for
`ledger_entries.account_id` carries an `n_distinct=1` override — planted,
not organic — which is why `ANALYZE` alone, run by hand, would not have
fixed it: the override keeps re-corrupting every subsequent `ANALYZE`
until it's explicitly reset.

**Fix:** `ALTER TABLE ledger_entries ALTER COLUMN account_id RESET
(n_distinct); ANALYZE ledger_entries;` — never a session-level
`enable_nestloop`/`enable_hashjoin`/`enable_seqscan` toggle, which would
force a different plan without fixing the wrong estimate underneath it,
and would stop working the next time the real distribution shifts again.

**Proof:** the same `EXPLAIN (ANALYZE)` re-read shows the join's plan
shape change (typically nested loop to hash join, or vice versa,
depending on which the corrected cardinality favors) and execution time
back under a second.

**Answer key:** `divergent_node=` — the specific node name (`Index Scan
using ix_ledger_entries_account_id on ledger_entries`, or similar,
depending on your run's exact plan) is read off your own `EXPLAIN`
output, not written here, since it varies with which plan the corrected
statistics produce.

---

## lock_chain

**Symptom:** three application connections have been stuck for several
minutes; the newest one reports waiting on a lock, and it is not the one
that's waited longest.

**First instrument:** `pg_stat_activity` for `state`/`wait_event_type`,
then `pg_blocking_pids(pid)` for whichever sessions show `wait_event_type
= 'Lock'` — never kill on wait-time alone (Mistake 10 in `STRATEGY.md`).

**Discriminating observation:** three sessions are involved, not two.
Session C is blocked on session B (both hold or want a lock on the same
account row); session B is *itself* blocked on session A, trying a
*different* account row than the one B already holds. `pg_blocking_pids`
for C returns B; for B, it returns A. A is the only one of the three
holding a lock uncontested and waiting on nothing — genuinely `idle in
transaction`, not `active`. A is the root, and A is not the session that
shows the longest wait time in `pg_stat_activity` (it has no wait at
all); C is.

**Fix:** end A's transaction — `SELECT pg_terminate_backend(<A's pid>);`
if the application can't be reached to commit or roll it back cleanly.
Never kill C first; killing a downstream waiter frees nothing the root
still holds, and B becomes the new longest-waiting row instead.

**Proof:** re-read `pg_stat_activity` and `pg_locks` — A is gone, and
within seconds B and C both complete their transactions and disconnect
on their own, because the lock they were queued for is now free.

**Answer key:** `root_pid=` — A's own backend PID, read from
`pg_stat_activity` before you end its transaction.

---

## vacuum_starvation

**Symptom:** storage used by the `refunds` table keeps growing week over
week even though its row count barely changes, and the nightly
maintenance job responsible for reclaiming that space keeps reporting
success.

**First instrument:** `pg_stat_user_tables` for `refunds` —
`n_dead_tup`, `last_vacuum`, `last_autovacuum` — read together, per
`content/primers/catalog-field-reference.md#pg_stat_user_tables`'s
warning against reading `n_dead_tup` as an instantaneous verdict without
also checking whether autovacuum has actually been running.

**Discriminating observation:** `last_autovacuum` (or a manual `VACUUM
(VERBOSE)`) is recent — autovacuum is not disabled, and
`autovacuum_enabled` on `refunds` reads `true` the whole time, which
rules out Day 6's original pathology. `pg_stat_activity` shows one
session `idle in transaction` with `xact_start` far older than
`refunds`' churn, holding a `REPEATABLE READ` snapshot taken before the
churn ran. That snapshot is what pins the vacuum horizon: any dead row
version created after it started might still need to be visible to it,
so no vacuum — automatic or manual — can remove those versions until the
transaction ends.

**Fix:** end the long-running transaction —
`SELECT pg_terminate_backend(<its pid>);` if it can't be committed or
rolled back directly.

**Proof:** re-run `VACUUM (VERBOSE) refunds;` after the pinning session
is gone and read `pg_stat_user_tables.n_dead_tup` for `refunds` again —
it drops sharply (this lab's threshold: under 1,000), because vacuum can
now reclaim everything the pin was holding back.

**Answer key:** `pinning_pid=` — the long-running session's backend PID,
read from `pg_stat_activity` (`state = 'idle in transaction'`,
`xact_start` far in the past) before you end it.

---

## mongo_regex

**Symptom:** a support tool that searches recent event records for
anything matching the word "charge" takes several seconds per search,
and the search gets slower every month as the event log grows.

**First instrument:** read the exact query the tool runs —
`gauntlet.sh` writes it verbatim to `ws:/tmp/day08-mongo-regex-query.js`
— then `(that query).explain("executionStats")`, raw, before naming the
cause, per the daily loop.

**Discriminating observation:** the file contains
`db.payment_events.find({ type: /charge/ }).limit(20)` — an **unanchored**
regex, no leading `^`. `winningPlan` is a bare `COLLSCAN`;
`totalDocsExamined` equals the full collection size regardless of
`nReturned`. `db.payment_events.getIndexes()` shows only `_id_` — but
building an index on `type` alone does **not** fix this: a B-tree/
WiredTiger index is sorted by full string value, and a pattern that can
match anywhere inside a string corresponds to no contiguous range of
that sort order (`content/primers/explain-field-reference.md`'s
ESR/regex discussion), so an unanchored regex cannot use an index scan
regardless of which index exists. `'charge'` matches only two literal
`type` values that both happen to start with the same five characters
(`'charge'` and `'chargeback'`), which is what makes an **anchored**
rewrite (`/^charge/`) both correct and the thing that actually makes an
index usable — the index and the anchoring are both required; either one
alone still collection-scans.

**Fix:** `db.payment_events.createIndex({ type: 1 })`, then edit
`day08-mongo-regex-query.js` in place to
`db.payment_events.find({ type: /^charge/ }).limit(20)` — a
prefix-anchored regex is servable as an index range scan; the unanchored
original never would have been, index or no index. (An equivalent
`$in: ['charge', 'chargeback']` rewrite is also a correct, index-friendly
fix; anchoring is the shape this pathology is built to teach, but it
isn't the only valid destination.)

**Proof:** `.explain("executionStats")` on the file's own (now edited)
query shows an `IXSCAN` on `{ type: 1 }` feeding a `FETCH`,
`totalDocsExamined` within roughly 1-2× `nReturned` instead of equal to
the full collection. `verify.sh` runs this exact file, not a hardcoded
substitute — editing the query file is not optional cleanup, it's half
the lab.

**Answer:** `regex_reason=unanchored` — naming *why* the original
pattern couldn't use an index (it wasn't anchored at the start), not
merely which field (`type`) it filtered on.

---

## innodb_deadlock

**Symptom:** a nightly settlement transfer between two accounts
intermittently aborts with a lock error under load; re-running it by
hand right afterward always succeeds.

**First instrument:** `SHOW ENGINE INNODB STATUS`'s `LATEST DETECTED
DEADLOCK` section, read immediately after the failure — InnoDB only keeps
the most recent one.

**Discriminating observation:** two transactions are each holding a row
lock on one account and waiting on a row lock the other transaction
holds on the *other* account — a classic opposite-order deadlock, visible
as two `TRANSACTION` blocks in the status output each listing the other's
held lock as what it's waiting for. `gauntlet.sh` wrote the two scripts
that produce it to `ws:/tmp/day08-transfer-a.sql` and `-b.sql`, running
against a dedicated `day08_deadlock_accounts` fixture table — not the
seeded `accounts` table — so replaying the incident doesn't leave a real
divergence between a cache and its derived balance behind (exactly the
invariant Day 5 teaches, and not one this lab should be allowed to
quietly violate). Script A updates the lower account ID first, then the
higher; script B updates the higher first, then the lower. Run
concurrently, each can grab its first row and then block waiting for the
other's — a true deadlock, not a plain lock wait, and InnoDB's deadlock
detector kills one side (the "victim") automatically, rolling its whole
transaction back.

**Fix:** rewrite both scripts (or, in a real application, both code
paths) to lock the two accounts in the same order every time — the
standard fix is a fixed, global order such as ascending account ID,
applied consistently regardless of which account is the "from" and which
is the "to" side of a given transfer.

**Proof:** replay the two edited scripts concurrently, repeatedly (this
lab replays five times) — no `Deadlock found when trying to get lock`
error in either output, on any attempt.

**Answer key:** `deadlock_accounts=` — the two account IDs involved,
ascending, comma-separated, read from the `LATEST DETECTED DEADLOCK`
section (or from the two transfer scripts `gauntlet.sh` left on `ws`) —
`1,2` for this pathology, since the fixture table's two rows are fixed.

---

## bloated_index

**Symptom:** the `disputes` table is small and has very little old data
sitting in it, but a query filtering on its `status` column has gotten
steadily slower for weeks.

**First instrument:** `pgstattuple('disputes')` for the table, then
`pgstatindex('idx_gauntlet_disputes_status')` for the index on `status` —
never assume the table's own bloat number tells you anything about an
index built on it; they're measured, and can drift, independently.

**Discriminating observation:** `pgstattuple('disputes').dead_tuple_
percent` reads low — single digits — confirming the table itself is
genuinely clean (`VACUUM` did its job on the heap). `pgstatindex
('idx_gauntlet_disputes_status').avg_leaf_density` reads well under
80%, meaning a large share of the index's leaf pages are mostly empty.
Repeated full-table `UPDATE`s cycling `status` through all three of its
valid values, over and over, forced constant delete-then-insert churn on
this index's B-tree (every value change moves a row's entry to a
different part of the key range); a plain `VACUUM` reclaims dead index
entries but doesn't compact or merge the resulting half-empty leaf pages
back together — only a rebuild does.

**Fix:** `REINDEX INDEX idx_gauntlet_disputes_status;` (or `REINDEX
INDEX CONCURRENTLY` under load, so the index stays usable mid-rebuild).
A `VACUUM FULL` on the table would also fix this — it rewrites the table
and rebuilds every index on it — but is a heavier hammer than the problem
needs when only one index is actually the issue.

**Proof:** re-read `pgstatindex('idx_gauntlet_disputes_status')` —
`avg_leaf_density` back up near what a freshly built index shows (this
lab's threshold: 80% or higher).

**Answer:** `bloated_index=idx_gauntlet_disputes_status`

---

## n_plus_one

**Symptom:** a merchant capture-summary batch job for one merchant takes
about 40 seconds end to end, even though every individual query in its
trace completes in under 5 milliseconds.

**First instrument:** `pg_stat_statements`, sorted by `total_exec_time`
descending — not the slow-query log, and not any single query's own
`EXPLAIN`, because no single query here is slow (Mistake 9 in
`STRATEGY.md`: blaming the database for what's a round-trip count
problem, not a query-cost problem).

**Discriminating observation:** the top `total_exec_time` entry has a
low `mean_exec_time` (each call genuinely fast, and `EXPLAIN` on it shows
a clean `Index Scan` using `ix_ledger_entries_payment_id` — the index
exists and is being used correctly) but a `calls` count in the hundreds,
all under one `queryid`, because the job issues one
`SELECT sum(amount_minor) FROM ledger_entries WHERE payment_id = $1`
per payment instead of one query for the whole batch. The per-call cost
never shows up as a problem in isolation; only the aggregate does.

**Fix:** replace the per-row loop with one batched query — for example
`SELECT payment_id, sum(amount_minor) FROM ledger_entries WHERE
payment_id = ANY(:ids) GROUP BY payment_id;` — one round trip regardless
of how many payment IDs the batch covers. An equivalent `IN (...)` list,
a joined `VALUES` list, or a join against a temp table populated with
the batch's IDs are equally valid; the shape of the fix matters less
than the outcome, which is what `verify.sh` actually checks.

**Proof:** `pg_stat_statements` now shows *some* query touching
`ledger_entries` and `payment_id` with a high rows-per-call ratio —
`verify.sh` picks whichever such query has the best ratio, rather than
requiring one specific syntax, and requires that ratio to be at least
20. The unfixed per-row queryid also matches the same filter, at a ratio
near 1, which is exactly why an unfixed incident fails this check rather
than passing on the strength of the wrong query happening to exist.

**Answer key:** `n1_calls=` — the `calls` value `pg_stat_statements`
showed for the offending per-row queryid when you read it, which varies
both by which merchant `gauntlet.sh` happened to pick and by how many
times you've since re-run a diagnostic query against that same shape
(`calls` for a queryid only ever increases). `verify.sh` accepts your
reading with headroom above the value stashed at apply time, rather than
requiring the two to match exactly — read the counter honestly, don't
try to reconstruct the original figure.
