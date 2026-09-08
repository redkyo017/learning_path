# Catalog field reference

The system catalogs and stats views each engine exposes, decoded once. For
every field: what it actually counts, and the one wrong reading people
commonly make of it — the second half is the part worth returning to.

## pg_stat_user_tables

| Column | What it actually counts | The common wrong reading |
|---|---|---|
| `seq_scan` | Number of sequential scans **initiated** on this table since the last stats reset (server restart or `pg_stat_reset()`), not rows scanned and not scans since deploy | Reading a high `seq_scan` alone as "needs an index" — a small, fully-cached table can run thousands of cheap seq scans that beat an index scan; check it alongside `idx_scan` and table size, and remember a stats reset silently zeroes the counter |
| `n_live_tup` | An **estimate**, refreshed by `VACUUM`/`ANALYZE`/autovacuum/autoanalyze runs | Treating it as `SELECT count(*)`. Right after a bulk load with no `ANALYZE` yet, this can sit near its pre-load value while the table has millions of new rows |
| `n_dead_tup` | Estimated dead (superseded, not-yet-reclaimed) row versions accumulated since the last vacuum | Assuming any nonzero value means "bloat, fix now" — normal write churn always carries a working set of dead tuples between vacuum runs; the number to watch is the trend and whether autovacuum ever brings it back down, not the instantaneous value |
| `last_autovacuum` | Timestamp of the last time **autovacuum specifically** completed on this table | Reading a null/old value as "vacuum never ran here" — a manual `VACUUM` updates the separate `last_vacuum` column instead, so a table that's vacuumed by hand or hasn't crossed autovacuum's threshold yet can show a null `last_autovacuum` while being perfectly healthy |
| `n_mod_since_analyze` | Count of all row modifications (inserts, updates, deletes) since the last `ANALYZE`, driving autoanalyze scheduling | Confusing it with `n_dead_tup` — this counts inserts too, which create no dead tuples at all, and it resets on `ANALYZE`, not on `VACUUM` |

## pg_statio_user_tables

`heap_blks_hit`/`heap_blks_read` and `idx_blks_hit`/`idx_blks_read` count
**block accesses**, cumulative since the last stats reset. The common
wrong reading: treating `*_blks_read` as physical disk I/O. It only means
the block wasn't in `shared_buffers` — with this stack's deliberately
small `shared_buffers=256MB`, a large share of "read" blocks are still
served from the OS page cache, not disk. Pair with `track_io_timing` (on
in this stack) and `EXPLAIN (ANALYZE, BUFFERS)`'s `I/O Timings` for an
actual latency signal instead of inferring it from block counts.

## pg_stat_user_indexes

`idx_scan` counts index scans initiated using that specific index since
the last stats reset — this is the unused-index signal: an index with
`idx_scan` at or near zero over a representative traffic window (a full
day/week, not five minutes) is a drop candidate. The common wrong reading:
dropping it on that number alone. `idx_scan` stays zero for an index
backing a `UNIQUE`/`PRIMARY KEY` constraint that's enforced on write but
never used for a lookup, for an index supporting FK-driven cascade
deletes/updates that only fire occasionally, and for any index created
recently enough that it hasn't seen its typical read pattern yet — and
like every stat here, a server restart resets the counter to zero, making
a freshly-restarted server's indexes all look temporarily unused.

## pg_stat_activity

| Column | What it actually counts | The common wrong reading |
|---|---|---|
| `state` | The backend's current state: `active`, `idle`, `idle in transaction`, `idle in transaction (aborted)`, `fastpath function call`, `disabled` | Skimming past `idle in transaction` as harmless because it isn't `active` — it's an open transaction holding a snapshot and any locks it's acquired while doing nothing, the exact shape that pins the vacuum horizon (Day 6) |
| `wait_event_type` / `wait_event` | What class of thing this backend is currently blocked on (`Lock`, `LWLock`, `IO`, `Client`, `IPC`, ...) and the specific instance | Treating any non-null `wait_event` as pathology — most idle backends show `wait_event_type: Client` (waiting for the app to send the next query) at any snapshot; only `Lock` waits indicate contention worth chasing |
| `backend_xmin` | The oldest transaction ID this backend's own MVCC **snapshot** still needs to be able to see | Confusing it with the backend's own transaction ID — `backend_xmin` is about what this backend can still read, not what it has written; it's the field that determines how far the vacuum horizon can advance |
| `xact_start` | When the backend's **current transaction** began | Using it to find the slowest **query** — `query_start` is the field for that. A transaction can be `idle in transaction` for an hour with `xact_start` an hour old and `query_start` seconds old; `xact_start` answers "how long has this transaction pinned the horizon," a different question |

## pg_locks and pg_blocking_pids

`pg_locks` lists lock requests, both held and waiting, with a `granted`
boolean per row — it is a request log, not a resolved blocking graph.
`pg_blocking_pids(pid)` reports exactly **one hop**: the hard blockers
(backends holding a lock that conflicts with the one this backend is
waiting for) plus the soft blockers (backends already ahead of it in that
same wait queue, which would conflict if granted first). It does not
follow the chain past that hop and does not compute a transitive closure.
The common wrong reading: treating the array `pg_blocking_pids()` returns
as the full blocking chain, with the first PID in it assumed to be the
root. In a queue stacked behind one heavyweight lock this is wrong in a
specific, reproducible way — five sessions contending for one row can
produce `pg_blocking_pids(S1) = {R}`, `pg_blocking_pids(S2) = {S1}`,
`pg_blocking_pids(S3) = {S1, S2}`, and `pg_blocking_pids(S4) = {S1, S2,
S3}`: the actual root, `R`, appears only in `S1`'s result and never in
`S4`'s, even though `S4` is the session an on-call engineer is most likely
to be paged about. Finding the true root means calling
`pg_blocking_pids()` again on each PID it returns and walking hop by hop
until you reach a backend whose own result is empty — eyeballing the
first PID in one call's result and killing it is exactly this mistake,
whether you reconstruct chains by hand from `pg_locks` joins or read
`pg_blocking_pids()` directly.

## pg_stat_statements

| Column | What it actually counts | The common wrong reading |
|---|---|---|
| `calls` | Executions aggregated under one normalized `queryid` (literal constants stripped) | Treating a `queryid`'s `calls` as one literal query text — different parameter values (different `merchant_id`s, say) share a `queryid`; given this schema's power-law merchant skew, `calls` mixes a huge number of cheap small-merchant executions with a handful of catastrophic top-merchant ones |
| `total_exec_time` | Sum of execution time across every call under this `queryid` | Reading it as the cost of one call — it is a running sum, not a per-call figure. A high `total_exec_time` can come from one catastrophically slow call or from an enormous number of individually cheap ones; read it alongside `calls` and `mean_exec_time` to tell which, rather than treating the total by itself as a latency number |
| `mean_exec_time` | `total_exec_time / calls` | Sorting by `mean_exec_time` to prioritize optimization work — a query with a low mean but enormous call count can dominate total database load far more than a rare, individually slow query. Sort by `total_exec_time` to find where the time actually goes; use `mean_exec_time` only after you've already picked a `queryid` to investigate |
| `shared_blks_read` | Buffer misses against `shared_buffers`, summed across all calls for this `queryid` | Reading it as physical disk I/O count — same caveat as `pg_statio_user_tables` above: a shared-buffers miss frequently still resolves from the OS page cache |

## pg_class: relpages and reltuples

`relpages` and `reltuples` are statistics the planner uses for cost
estimation, refreshed only when `ANALYZE` or `VACUUM` runs — never live.
The common wrong reading: treating `reltuples` as an exact row count.
Immediately after a large bulk load with no `ANALYZE` yet run, `reltuples`
can still reflect the table's pre-load size (even near zero on a newly
created table), and every plan the optimizer produces in that window is
built on that stale number until `ANALYZE` catches up.

## pgstattuple

The `pgstattuple` extension's functions (`pgstattuple('table')`,
`pgstatindex('index')`) return **exact** counts by actually scanning the
target — live tuple count, dead tuple count, and `free_percent`. The
common wrong reading, two of them: first, running this as a routine
monitoring query — it performs a full scan under the hood, comparable in
cost to a sequential scan, so it belongs in targeted diagnosis, not a
dashboard refreshed every minute on a multi-million-row table. Second,
reading `free_percent` alone as "how bloated this table is" — some of
that free space is normal `fillfactor` headroom deliberately left for HOT
updates, not reclaimable bloat.

## information_schema.tables and innodb_index_stats

`information_schema.tables.TABLE_ROWS` for an InnoDB table is a **sampled
estimate**, taken from index dives, not a stored exact count (`DATA_LENGTH`
and `INDEX_LENGTH` are also estimates, derived from page counts). `mysql.
innodb_index_stats` holds the persistent per-index statistics (cardinality
via `stat_name LIKE 'n_diff_pfx%'`) the optimizer uses for plan costing.
The common wrong reading: assuming `TABLE_ROWS` is exact because older
MyISAM tables used to report an exact count — for InnoDB it can be off by
a large percentage right after bulk loads or heavy churn, and
`innodb_index_stats` only refreshes on `ANALYZE TABLE` or once accumulated
changes cross the persistent-stats auto-recalculation threshold (10% of
the table by default), so a burst of writes between analyses leaves the
optimizer costing plans against stale cardinalities.

## performance_schema.events_statements_summary_by_digest

Aggregates statements by a normalized `DIGEST` (literals replaced with
`?`) — MySQL's equivalent of `pg_stat_statements`' `queryid`. Key columns:
`COUNT_STAR` (calls), `SUM_TIMER_WAIT`/`AVG_TIMER_WAIT` (total/mean
latency), `SUM_ROWS_EXAMINED`, `SUM_ROWS_SENT`, `DIGEST_TEXT` (the
normalized statement text). The common wrong reading, two of them: sorting
by `AVG_TIMER_WAIT` instead of `SUM_TIMER_WAIT` to decide what to optimize
first, same trap as `pg_stat_statements`' `mean_exec_time`; and filtering
`DIGEST_TEXT LIKE '%4021%'` expecting to find a specific merchant's
queries — literal values are replaced with `?` in the digest text, so a
specific parameter value never appears there at all.

## data_lock_waits

`performance_schema.data_lock_waits` (and the friendlier
`sys.innodb_lock_waits` view built on it) shows one row per blocking
relationship: a `REQUESTING_ENGINE_TRANSACTION_ID` waiting on a
`BLOCKING_ENGINE_TRANSACTION_ID`. The common wrong reading: reading a
single row's blocker as the root cause. This table gives you one hop of
the graph per row — exactly like raw `pg_locks`, a blocking chain here can
be transitive, and finding the true root means walking blocker-of-blocker
across rows, not trusting whichever row surfaces first.

## SHOW ENGINE INNODB STATUS

Free-text, sectioned output; the two sections worth reading routinely are
`TRANSACTIONS` (lists every active transaction, its lock waits, and its
undo log entries) and the summary line reporting **History List Length**
near the top of the transaction/purge information. The common wrong
reading: skimming past History List Length as a purge-subsystem internal.
It counts undo log entries not yet purged — the direct InnoDB analog of
PostgreSQL's `n_dead_tup`/vacuum-horizon story — and it climbs for exactly
the same reason: a long-running transaction holds back the purge point.
The fix is ending that transaction, not `OPTIMIZE TABLE`; purge catches up
on its own once the oldest open transaction moves.

## collStats and dbStats

`db.collection.stats()` reports `size` (uncompressed logical data size),
`storageSize` (actual on-disk size after WiredTiger's default snappy
compression), `count`, `avgObjSize`, `nindexes`, `totalIndexSize`.
`db.stats()` rolls the same shape up to database level and adds
`fsUsedSize`/`fsTotalSize` (filesystem-level, from the volume mongod
runs on). The common wrong reading: comparing `size` against what `df`
reports on disk — `storageSize` is the number that corresponds to actual
disk footprint; `size` describes the data before compression and will
look considerably larger. A second wrong reading at the `dbStats` level:
assuming the database's `dataSize`/`storageSize` accounts for all disk
usage of the deployment — the oplog lives in the separate `local`
database and isn't counted here at all.

## $indexStats

The `$indexStats` aggregation stage returns per-index access counters,
including `accesses.ops` — a count of operations that have used that
index since the counter was last reset. The common wrong reading:
declaring an index unused from a single low `accesses.ops` reading without
checking two things — the counter resets on every `mongod` restart (same
caveat as PostgreSQL's `idx_scan`), and `$indexStats` reports counts local
to the node it's run on; a workload reading from secondaries via a
`secondaryPreferred` read preference can drive heavy use of an index that
looks unused when checked only on the primary.

## currentOp

`db.currentOp()` lists in-progress operations, with `secs_running`,
`waitingForLock`, `lsid`, and — for a multi-document transaction — a
`transaction` sub-document including `parameters.txnNumber` and how long
the transaction has been open. The common wrong reading: treating every
entry as an active, running query. Idle sessions holding an open cursor
and idle-but-uncommitted multi-document transactions (candidates for the
default 60-second transaction lifetime limit) also show up here with a
`secs_running` value, and internal system operations (an index build, the
TTL monitor) appear alongside user queries and shouldn't be judged by the
same "is this stuck" standard.

## serverStatus.wiredtiger.cache

Nested under `serverStatus().wiredTiger.cache`: `bytes currently in the
cache`, `maximum bytes configured` (matches this stack's
`wiredTigerCacheSizeGB=0.5`), `tracked dirty bytes in the cache`, `pages
evicted by application threads`, `unmodified pages evicted`. The common
wrong reading: treating "bytes currently in the cache" sitting near
"maximum bytes configured" as itself a problem. WiredTiger is designed to
run its cache nearly full at all times — that's not pressure. The actual
pressure signal is a rising `pages evicted by application threads`: it
means eviction work that should happen in the background on dedicated
threads is instead being pushed onto the foreground threads serving reads
and writes, which is what actually stalls user operations.

## system.profile

The profiler's output collection, populated once `db.setProfilingLevel(1,
{ slowms: 100 })` (this stack's default) is set, per database. Key fields:
`millis` (operation duration), `planSummary` (`COLLSCAN`/`IXSCAN{...}`),
`docsExamined`, `keysExamined`, `ts`. The common wrong reading: treating
`system.profile` as a complete log of everything slow that ever happened.
It's a **capped collection** — once it hits its configured size, oldest
entries silently roll off with no warning — and profiling level is set
per database and per node; a level-1 profiler enabled only on the primary
misses slow reads served from a secondary under a non-primary read
preference.
