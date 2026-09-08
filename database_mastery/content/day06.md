# Day 6 — Durability and Operations

**Layer:** durability
**Budget:** 4.5 h total — 45 min WAL, checkpoints, and what a commit
acknowledgement actually promises; 45 min autovacuum, bloat, and MySQL's
purge equivalent; 45 min backup and recovery across all three engines —
PostgreSQL's `pg_basebackup` plus WAL archive, MongoDB's oplog and
`mongodump --oplog`, and connection accounting; 2-2.5 h lab: cause a
crash, recover from it, restore to a point in time, recover a deleted set
of MongoDB documents from an oplog-backed dump, and fix a bloat pathology
by retuning autovacuum, not by running one manual command.

**This is the path's longest day, honestly.** A hard-kill-and-watch-recovery
chain plus a base-backup restore with a `recovery_target_time` derived
from a real log line is close to 45 minutes on its own before the bloat
retune even starts waiting on autovacuum, and the MongoDB chain added on
top — a scratch `mongod`, a full-dump restore of a multi-million-document
collection, verification, export, and a surgical upsert back into the
live collection — is another 20-30 minutes for someone who has done it
before, more on a first attempt. If you're working this in evening
sessions, there is a natural place to split it: take the PostgreSQL
crash-and-PITR chain (the hard kill, reading recovery from the log, and
the point-in-time restore) in one sitting, and the MongoDB restore plus
the autovacuum bloat retune in a second. Budgeting 3 hours for a day that
actually needs 4.5 is how a learner abandons the lab halfway through —
exactly the outcome planning two sessions up front is meant to prevent.

## Why this matters

Two questions decide whether an incident is an inconvenience or a
resignation letter: what exactly did the database promise when it
acknowledged that commit, and can you actually restore. Most engineers
can answer neither with confidence. `synchronous_commit` is usually left
at whatever the framework's ORM tutorial suggested, and the backup job's
green checkmark in a dashboard is treated as proof a restore would work,
which it is not — Mistake 8 in `STRATEGY.md` names this directly: testing
the backup job's exit code, never a restore. The second question is
usually answered for the first time during the incident itself, at the
worst possible moment to be discovering that the last tested restore was
eighteen months ago, or that no one wrote down which `recovery_target_time`
corresponds to which bad deploy. Today produces both answers under
conditions you control: you will watch a real crash-recovery log, take a
real base backup, restore it to a real point in time, and prove the
restored value is correct by reading it — not by trusting the tool that
produced it.

The second half of the day is the same law applied to a slower failure.
Bloat and autovacuum starvation do not page anyone; they show up as "the
table won't stop growing" three months after someone disabled autovacuum
"temporarily" during a migration. Mistake 3 in `STRATEGY.md` — tuning
configuration knobs before fixing queries — is why this day comes after
the planner and concurrency days, not before them: you now have the
instruments (`EXPLAIN`, `pg_stat_activity`) to tell a genuine durability
problem from a query shape someone is about to blame it on.

## Read the instrument first

Kill a PostgreSQL container hard, mid-write, and bring it back. Before
anything below names "WAL" or "redo," this is what the container's own
log says on restart:

```
2026-03-14 09:12:47.331 UTC [1] LOG:  database system was interrupted; last known up at 2026-03-14 09:11:58 UTC
2026-03-14 09:12:47.402 UTC [1] LOG:  database system was not properly shut down; automatic recovery in progress
2026-03-14 09:12:47.406 UTC [1] LOG:  redo starts at 0/5C0000A0
2026-03-14 09:12:47.611 UTC [1] LOG:  invalid record length at 0/5C10F918: wanted 24, got 0
2026-03-14 09:12:47.611 UTC [1] LOG:  redo done at 0/5C10F8F0 system usage: CPU: 0.09s/0.03s [user/sys] elapsed: 0.20s
2026-03-14 09:12:47.611 UTC [1] LOG:  last completed transaction was at log time 2026-03-14 09:11:57.988 UTC
2026-03-14 09:12:47.639 UTC [1] LOG:  checkpoint starting: end-of-recovery immediate
2026-03-14 09:12:47.802 UTC [1] LOG:  checkpoint complete: wrote 341 buffers (2.1%); 0 WAL file(s) added, 0 removed, 1 recycled
2026-03-14 09:12:47.809 UTC [1] LOG:  database system is ready to accept connections
```

Read it in order, before assigning names to any of it. `redo starts at
0/5C0000A0` is not "the beginning of the log" — it is the location of the
last checkpoint before the crash, which is the earliest point recovery
could possibly need to replay from; everything durable before that LSN
was already on disk when the crash happened, so replaying it again would
be wasted work, not extra safety. `invalid record length at 0/5C10F918:
wanted 24, got 0` looks like corruption on first read and is not — it is
how redo recognizes the end of the log: the last WAL record was still
being written when the process died, so the space after it is
zero-filled, and a zero-length header is the expected shape of a torn
write, not damage to react to. `redo done at 0/5C10F8F0` names the exact
LSN recovery stopped at — the true point of the crash, not the container's
kill signal. `last completed transaction was at log time 2026-03-14
09:11:57.988 UTC` is the answer to "what is the newest data I can trust,"
read directly off the log, before any query runs. `checkpoint starting:
end-of-recovery immediate` is a checkpoint forced right after replay
finishes, establishing a fresh baseline before the server accepts a single
connection — it does not wait for the normal checkpoint schedule.

Total elapsed time for this replay: 0.20 seconds. That number is a
function of how much WAL existed between the last checkpoint and the
crash — nothing else. A server that checkpoints every five minutes and
crashes four minutes and fifty seconds later replays nearly five minutes
of WAL; the same server crashing ten seconds after a checkpoint replays
almost nothing. Recovery time is a knob (`checkpoint_timeout`,
`max_wal_size`), not a fixed property of "how big the database is."

## Core concepts

**WAL, redo, undo, binlog, oplog — one idea, seen four ways.** The idea:
write the intent durably, in a compact, sequential, append-only form,
*before* the data pages it describes are modified on disk — so that if
the process dies between those two writes, recovery can replay the
intent instead of trusting half-written pages. PostgreSQL's WAL is the
purest form of this: every change is a WAL record first, the heap page
second, and crash recovery is exactly redo — replay WAL forward from the
last checkpoint. There is no separate "undo" log in PostgreSQL, because
nothing is ever applied to a page before its WAL record is durable in the
first place; an aborted transaction's changes become invisible to every
other transaction through MVCC's ordinary visibility rules, not through a
rollback step recovery has to perform. MySQL/InnoDB runs two
logs where PostgreSQL runs one: the InnoDB redo log is WAL's direct
analog, replayed forward on crash; the InnoDB undo log is genuinely
different, because InnoDB *does* modify pages before commit and needs a
way to both roll an aborted transaction back and give an older
transaction's snapshot something to read — the same undo records serve
MVCC and rollback at once. Sitting entirely apart from both is the
binlog: a logical, statement- or row-based record kept for replication
and PITR, not for InnoDB's own crash recovery, which is why binlog
position and InnoDB's crash-recovery LSN are two different coordinate
systems that happen to describe overlapping history. MongoDB's oplog
plays the binlog's role — a capped, idempotent, logical replay log
secondaries tail — while WiredTiger keeps its own physical write-ahead
log underneath for the storage engine's own crash recovery, invisible to
the replication layer entirely. Four logs, the same rule: write the
intent durably first, and know which log you're reading before you
trust its position number.

**Checkpoints and the recovery-time trade-off.** A checkpoint flushes
every dirty buffer to disk and records the LSN at which it started; that
LSN becomes recovery's starting point after a crash, because everything
before it is already durably on disk by construction. Frequent
checkpoints (`checkpoint_timeout` small, `max_wal_size` small) bound
recovery time tightly — there's never much WAL to replay — at the cost of
constant background write I/O competing with foreground traffic.
Infrequent checkpoints amortize that I/O cost over a longer window at the
cost of a longer replay after any crash. This stack leaves both at their
defaults (`checkpoint_timeout` 5 min, `max_wal_size` 1 GB); production
systems tune this pair deliberately, as a recovery-time SLA decision, not
an I/O-tuning afterthought.

**`fsync` and `synchronous_commit` — what a commit acknowledgement
promises.** `fsync=on` (the default, never disable it) is the baseline
promise: PostgreSQL does not tell the OS "trust me, it's written" — it
actually forces WAL to durable storage before treating it as flushed.
`synchronous_commit` decides *when*, relative to that flush, `COMMIT`
returns to the client, and this stack has no replica, so the levels that
matter here are:

- `on` (default) — `COMMIT` does not return until the transaction's WAL
  record has been flushed to local disk. A `COMMIT` the client received
  is durable against a hard crash to exactly the degree the storage
  underneath is honest about its own flushes.
- `local` — identical to `on` with no replica configured; the two only
  diverge once a synchronous replica exists, which this stack does not
  have (`max_wal_senders=3` here is headroom for `pg_basebackup`, not a
  standby).
- `off` — `COMMIT` returns as soon as the WAL record is written into the
  in-memory WAL buffer, without waiting for a flush. The background WAL
  writer flushes it within `wal_writer_delay` (default 200 ms) or at the
  next checkpoint, whichever comes first. A plain process crash — the
  `postgres` backend dying while the OS keeps running — does **not**
  lose this data: the OS page cache still holds the unflushed write, and
  the ordinary crash-recovery replay above reads it back. What actually
  loses it is a **power loss or OS-level crash in the window before that
  flush completes**: the client already received `COMMIT`, already acted
  on it — charged a card, released a shipment, cleared a hold — and on
  restart that transaction is gone entirely. Nothing in the log tells the
  database a transaction is missing, because from WAL's own point of view
  no incomplete record was ever left behind; it was never written at all.
  The gap is invisible to every instrument except the client's own
  record of having been told "success."

**`innodb_flush_log_at_trx_commit` and `sync_binlog` — the same trade-off,
InnoDB's knobs.** `innodb_flush_log_at_trx_commit` controls what a MySQL
`COMMIT` promises, the same question `synchronous_commit` answers on
Postgres: `1` (the default, and this stack's setting — read it back
yourself with `SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';`
against the running `my` container rather than trusting this paragraph)
writes the redo log record to the OS and `fsync`s it before `COMMIT`
returns, surviving both an ordinary `mysqld` crash and a power loss. `2`
writes to the OS at commit but only `fsync`s once a second, so an
ordinary process crash still loses nothing (the OS page cache holds the
write), but a power loss or OS crash inside that up-to-one-second window
loses whatever committed in it. `0` skips the OS write at commit
entirely, deferring both the write and the flush to roughly once a
second, so an ordinary `mysqld` process crash — not only a power loss —
can lose up to a second of already-acknowledged commits. `sync_binlog`
is the parallel knob for the binlog: `1` (its default, unset here because
`my.cnf` never overrides it, so it is already in effect) `fsync`s the
binlog on every commit, keeping it crash-consistent with the redo log;
any higher value `fsync`s every N commits instead, opening a window
where the two logs can disagree about the last committed transaction
after a crash.

**MongoDB's `w` and `j` are two independent write-concern axes.** `w`
(covered above only in its quorum sense) says how many replica set
members must acknowledge a write before it returns; `j` says whether the
acknowledging member had already synced that write to its own on-disk
journal, and the two compose independently. `{w: 1}` with `j` unset
acknowledges as soon as the primary applies the write in memory, so a
primary crash before its next journal flush can lose an already-
acknowledged write with no other member ever having seen it. `{w: 1, j:
true}` waits for that same primary's journal `fsync` first, so a lone
primary crash cannot lose it, but losing the primary's disk while a
majority of replicas are down still can. `{w: "majority"}`, this path's
quorum answer, tolerates losing the primary's disk entirely because
another member already holds the data, but only adds journal durability
on top of that if journaling is enabled on the members being counted —
check a member's actual journal activity against the live stack rather
than assuming a default: `db.serverStatus().dur` reports live
journal-flush statistics on any member with journaling active.

**Crash recovery, read from the log.** Everything in "Read the instrument
first" above is this section, now named: `redo starts at` is the
checkpoint LSN, `redo done at` is the crash LSN, and the elapsed time
between them is bounded by the checkpoint interval you chose, not by
total database size.

**Autovacuum: what it does, and the outcome that looks like a bug.**
Autovacuum reclaims dead tuple slots for reuse *within that table*, runs
autoanalyze to refresh planner statistics, and advances the freeze
horizon to hold off transaction ID wraparound. "The table is still
growing after I deleted everything" is the expected result of exactly
this design, not a malfunction: `DELETE` marks rows dead, it does not
shrink the file, and plain `VACUUM`/autovacuum makes that dead space
reusable by future writes *to the same table* — it does not return pages
to the OS, and it does nothing for any other table. Only `VACUUM FULL`,
`pg_repack`, or `CLUSTER` actually rewrite the table into a smaller file.

**Dead tuples and the visibility horizon.** A row version can only be
removed once no active transaction's snapshot could still legitimately
need it — the oldest such snapshot is the horizon, and it is pinned by
transaction age, not by activity. `pg_stat_activity.state = 'idle in
transaction'` (see
`content/primers/catalog-field-reference.md#pg_stat_activity`) is the
exact shape that pins it: a session doing nothing still holds a snapshot
open, and every dead tuple newer than that snapshot's start sits
un-vacuumable regardless of thresholds. This is Day 5's finding, restated
at full force here: **no amount of autovacuum retuning helps until the
long-running transaction ends.** A more aggressive `autovacuum_vacuum_scale_factor`
makes autovacuum run *more often*; it cannot make autovacuum remove rows
a still-open snapshot might still read. Tuning around a stuck session
instead of ending it is solving the wrong layer's problem with this
layer's knobs.

**Freezing and wraparound, with the arithmetic.** PostgreSQL transaction
IDs are a 32-bit counter (`content/GLOSSARY.md`, "transaction ID
wraparound"); autovacuum freezes old tuples well before the counter could
wrap, forcing a mandatory anti-wraparound autovacuum once a table's age
crosses `autovacuum_freeze_max_age` (default 200,000,000 transactions) —
this triggers regardless of dead-tuple thresholds, because it is a
correctness deadline, not a housekeeping preference. Put a number on how
close a busy system gets: at a sustained 5,000 transactions/second — a
plausible peak for a busy payments platform, not this course's seeded
dataset — a table would cross that default's headroom in
200,000,000 ÷ 5,000 = 40,000 seconds, **roughly 11.1 hours**. That is not
a comfortable safety margin; it is the kind of number that turns into an
actual outage window at a shop running hot, and it is why wraparound gets
treated as an operational deadline with a clock on it, not a theoretical
edge case reserved for exam questions.

**`pg_stat_progress_vacuum`, read mid-run.** While a vacuum (manual or
autovacuum) is in flight, this view reports `phase`, `heap_blks_total`,
`heap_blks_scanned`, and `heap_blks_vacuumed` for the table being
processed — a rough completion percentage you can compute yourself
(`heap_blks_scanned::float / heap_blks_total`), which is exactly the
number you need mid-incident to decide whether to let a long vacuum
finish or intervene.

**Bloat, measured honestly.** `pgstattuple('tablename')` (see
`content/primers/catalog-field-reference.md#pgstattuple`) scans the
table and returns exact `dead_tuple_count`/`dead_tuple_percent` —
expensive (a scan, not a monitoring query), but honest. The common
estimate — comparing `pg_stat_user_tables.n_dead_tup` against
`n_live_tup`, or `pg_class.reltuples`/`relpages` (see
`content/primers/catalog-field-reference.md#pg_class-relpages-and-reltuples`)
against a guessed average row width — is only as fresh as the last
vacuum/analyze, and diverges hardest exactly when it matters most: right
after a burst of churn nothing has vacuumed yet.

Once bloat is measured, the remediation choice is a lock-level and
outage-cost decision, not a "which tool sounds most thorough" one:

| Remediation | Lock held | Outage cost |
|---|---|---|
| Plain `VACUUM` | Brief locks per page, table stays readable and writable throughout | None — safe on a live table, does not shrink the file |
| Retuned autovacuum thresholds | Same as plain `VACUUM`, run automatically and more often | None — the preventive fix, not a one-time cure |
| `pg_repack` | Brief `ACCESS EXCLUSIVE` only for the final table swap; the rewrite itself runs concurrently against a shadow table, replaying concurrent writes via a trigger | Seconds, not the rewrite's full duration |
| `VACUUM FULL` | `ACCESS EXCLUSIVE` for the **entire** rewrite | The whole table is unavailable for the rewrite's full duration — real outage on anything live |

**Known issue: `pg_repack` version mismatch.** This stack's `pg_repack`
client (on `ws`) and its server-side extension (on `pg`, installed by
`labs/stack/Dockerfile.pg`) come from separate Debian packages baked into
separate images, and neither Dockerfile pins an exact package version.
Rebuild only one image later — say, `ws` picks up a newer
`postgresql-16-repack` package on a subsequent `docker compose build`
while `pg` does not — and `pg_repack` refuses to run with something like:

```
ERROR: program version does not match library version
   program: 1.5.1
   library: 1.5.0
```

This is not a bug to route around: `pg_repack`'s safety depends on the
trigger it installs matching, exactly, the server-side C/SQL logic that
replays concurrent writes during the rebuild, and it refuses to proceed
rather than risk silently dropping a write made mid-repack. The fix is to
rebuild both images together from the same package set (`docker compose
-p dbmastery build --no-cache pg ws`) so client and extension line up
again — or, for real durability, pin the exact package version in both
Dockerfiles so this can't drift apart unnoticed a second time.

**MySQL: the purge thread and History List Length.** InnoDB's undo log
entries pile up the same way PostgreSQL's dead tuples do, and for the
same root cause: a long-running transaction's read view holds the purge
point back, so InnoDB's background purge thread cannot reclaim undo
records newer than it. `SHOW ENGINE INNODB STATUS` (see
`content/primers/catalog-field-reference.md#show-engine-innodb-status`)
surfaces this as **History List Length** — the same story wearing
different clothes, and the same fix: end the long-running transaction.
`OPTIMIZE TABLE` (InnoDB's rough equivalent of `VACUUM FULL`, and equally
locking) does not touch the actual cause.

**Backup and PITR.** Logical backups (`pg_dump`, `mysqldump`) capture a
consistent snapshot as statements or a portable data format — flexible,
selective, slow to restore at scale. Physical backups (`pg_basebackup`,
filesystem snapshots) copy the actual data files — fast to restore,
tied to the exact engine version and architecture that produced them.
`pg_basebackup` plus a continuous WAL archive is what makes **point-in-time
recovery** possible: restore the base backup, replay archived WAL up to a
chosen `recovery_target_time`, and you have the database as of any
instant covered by that WAL, not only the instant the backup itself was
taken. None of this is real until it has produced a known, checked value
from an actual restore — a backup job with a green exit code and zero
restore drills is Mistake 8, an assumption wearing a checkmark.

**MongoDB backup and recovery: the oplog, `mongodump --oplog`, and its
honest limits.** The oplog earned its place in "one idea, seen four ways"
above as MongoDB's redo log, but it has a property none of WAL, the
InnoDB redo log, or the binlog share: it is a **fixed-size, capped
collection** (`local.oplog.rs`) that **wraps** — once full, the oldest
entries are overwritten unconditionally to make room for new ones,
whether or not anything has consumed them yet. WAL is bounded only by
disk and archiving policy; the oplog cannot grow past its configured size
no matter what — a secondary that falls behind further than the oplog's
own window cannot resync by replaying it and needs a full resync instead.
This is the single most important operational difference from WAL, with
no PostgreSQL or MySQL equivalent: **your recovery window is bounded by
write volume, not by disk headroom**, and it shrinks as write traffic
rises, with no error at all until the moment something needs an entry
that has already rolled off. This stack's
`mongod.conf` never sets `replication.oplogSizeMB`, so MongoDB auto-sizes
the oplog from available disk space, with a documented floor around
990 MB — the number that matters for any node is whatever it reports
back live, not the sizing formula.

`rs.printReplicationInfo()` reports exactly that number: how much
wall-clock time currently separates the oldest and newest entries the
oplog holds, the entire resync/recovery window available right now, at
today's write rate — or read the same thing directly off `local.oplog.rs`
by comparing the `ts` field of its first and last documents in natural
(insertion) order. That span is a live number, not a config value; it
shrinks whenever write volume rises and never grows back on its own.
Know it for your production cluster before an incident asks you what it
was.

`mongodump --oplog` is not a snapshot the way `pg_basebackup` is. It
writes each collection's documents as of whenever that collection's own
dump completes — not the same instant across collections, since
`mongodump` processes them one at a time — and separately tails
`local.oplog.rs` for the dump's whole duration, writing every operation
observed into `oplog.bson` at the top of the output directory. On its
own, a multi-collection dump is internally inconsistent by however long
it took to run; `mongorestore --oplogReplay` re-applies `oplog.bson`
after loading the dumped collections, carrying every collection forward
to the single instant the dump finished — a guarantee manufactured after
the fact, not captured atomically the way a filesystem snapshot is.
`--oplog` requires a real replica set member with a real oplog to tail
(this stack's single-member `rs0` qualifies), and it dumps the whole
deployment, never a single `--db` or `--collection` — the consistency
guarantee only means anything across everything backed up together, not
one database in isolation.

The more interesting fact than "the dump includes several databases" is
what it never includes: `mongodump` excludes the `local` database
unconditionally, in every mode, `--oplog` or not — a dump directory never
contains a `local/` folder at all. `--oplog`'s tailed entries do not go
into a `local` copy either; they are *extracted* out of
`local.oplog.rs`'s change stream into the standalone `oplog.bson` file at
the top of the dump, which is a different shape entirely — a flat replay
log, not a collection of documents restorable on its own. A dump taken
with `--oplog` against this stack's deployment produces exactly `admin`,
`config`, `payments`, and `oplog.bson` — never a `local` directory, and
seeing only three database directories plus that one file is the dump
working correctly, not a sign that something failed to copy.

Oplog replay only rolls **forward**. `mongorestore --oplogReplay` applies
recorded operations in the order they happened — it has no mechanism for
undoing one. If a deletion happens *after* the dump that `oplog.bson`
belongs to, nothing in that oplog can reverse it, because the delete was
never observed by the tailer in the first place; replaying that oplog
faithfully reproduces a state that still includes the delete, not one
that predates it. Recovering documents deleted after a dump completed has
to come from the dumped collection data itself — the `.bson` file
holding whatever was still live when `mongodump` reached that collection
— not from the oplog, which in that scenario contributes nothing to the
recovery at all.

`--oplogLimit <seconds>:<ordinal>` caps how far into `oplog.bson`
`mongorestore --oplogReplay` replays, a genuine point-in-time choice, but
one bounded by how long that single `mongodump --oplog` run lasted —
seconds to minutes, not the hours or days a continuously archived WAL
stream covers. It is **exclusive**: an oplog entry timestamped at or after
the given `<seconds>:<ordinal>` is not applied, only entries strictly
before it are. That gap is the honest limit: `mongodump` is a **logical**
dump — it reads documents out through the query layer and reinserts them
on restore — slow at real cluster scale, with a PITR window only as wide
as the one dump that produced it, and it is not the primary backup
strategy past a modest dataset. A filesystem-level snapshot (LVM, EBS, or
the equivalent under WiredTiger's data files, taken with `db.fsyncLock()`
held across every member, or a storage layer guaranteeing
crash-consistent volume snapshots) restores by copying files back at disk
speed regardless of data volume — the physical-backup answer, the same
trade-off `pg_basebackup` makes against `pg_dump`. Atlas's continuous
backup goes further, archiving the oplog on an ongoing basis the way WAL
archiving does, for genuinely open-ended PITR. `mongodump --oplog` is the
right tool for today's lab and for moving a modest dataset between
environments; it is the wrong tool to bet a production cluster's recovery
on.

**Connections.** A PostgreSQL connection is a forked OS process, not a
lightweight thread — several megabytes of backend memory plus catalog
caches, before it runs a single query. `max_connections` is therefore a
hard ceiling on concurrent processes, and it interacts multiplicatively
with `work_mem`, which gets its own treatment below because the
interaction is the part that actually causes incidents. PgBouncer sits in
front of Postgres to decouple "clients connected" from "server processes
in use," at a cost that depends on the pooling mode:

- **Session pooling** — one server connection held for the client's
  entire session. Every session feature works (`SET`, prepared
  statements, session-scoped advisory locks, `LISTEN`/`NOTIFY`) because
  nothing is shared underneath, but it barely reduces server connections
  when clients hold idle sessions open.
- **Transaction pooling** — the server connection returns to the pool the
  moment a transaction ends, the mode that actually multiplexes many
  clients onto few server connections. The cost: anything scoped to a
  session rather than a transaction breaks silently across statement
  boundaries — session-level `SET`, `PREPARE`d statements reused across
  transactions, advisory locks meant to outlive one transaction.
- **Statement pooling** — the connection returns after every single
  statement. The cost is explicit and total: no multi-statement
  transactions at all, effectively autocommit-only.

This stack runs no PgBouncer instance — sizing a pool here is a written
exercise (below), not something you'll run against these containers.

**The five settings that matter, and `work_mem`'s own treatment.**
`shared_buffers`, `effective_cache_size`, `maintenance_work_mem`,
`max_connections`, and `work_mem` are the five knobs that between them
decide this stack's whole memory story — and `work_mem` is the one that
actually causes incidents, because engineers price it as a per-query or
per-connection budget and it is neither. **`work_mem` is a ceiling per
sort or hash node, not per query** — a single plan can contain several
such nodes at once (a hash join here, a sort there, a second hash join
feeding the first), each independently allowed to consume up to
`work_mem` before spilling to disk. A plan with eight such nodes, running
concurrently across twelve open connections, can commit
8 × 12 × `work_mem` — **ninety-six times** the single `work_mem` figure
the engineer thought they'd configured, not twelve times, which is the
number you get by treating `work_mem` as a per-connection limit instead
of a per-node one. At this stack's actual `work_mem=4MB`, that scenario
commits 96 × 4 MB = 384 MB no one budgeted for — on a host running
several such stacks at once, or under real production concurrency, this
is exactly how a "small" setting produces an out-of-memory kill nobody
predicted from reading the config file alone.

## Predict before you measure

Write these down before running anything, per `STRATEGY.md`'s daily loop
step 3:

1. How long crash recovery will take, in seconds, after you hard-kill the
   `pg` container — state a number, and the one-sentence reasoning behind
   it (how much WAL you expect to have accumulated since the last
   checkpoint).
2. The bloat ratio (`pgstattuple`'s `dead_tuple_percent`) of the churn
   table `break.sh` leaves you, before you touch `VACUUM`.
3. The value of the damaged row's `status` column at the recovery target
   you choose — before you restore anything and look.

## Lab

`break.sh` sets up four things in one run: a fresh `pg_basebackup` (with
a live check that WAL archiving is actually running, since PITR is
impossible otherwise), a wrongly-scoped bulk `UPDATE` against `payments`,
a bloat pathology on a table it creates for the purpose, and a fresh
`mongodump --oplog` followed by the deletion of a bounded set of
`payment_events` documents. Bring the stack up, then:

```bash
bash labs/day06/break.sh
```

It prints the target row you'll verify your restore against (not its
correct value — that stays hidden until you've actually restored it) and
one `SYMPTOM` line. Read `docker compose -p dbmastery logs pg --tail 50`
next: `log_min_duration_statement=500` means the damaging bulk `UPDATE`
is slow enough to appear there, timestamped — that log line is how you
find your `recovery_target_time`, not a value handed to you.

**The crash is yours to cause.** `README.md` has the exact command; doing
it by hand — watching the container actually die and actually come back —
is the point, not a formality on the way to the interesting part.

From there: read the crash-recovery log against "Read the instrument
first" above, take the base backup `break.sh` already produced and
restore it into a scratch data directory on a second port inside the `pg`
container, set `recovery_target_time` to a moment before the damaging
`UPDATE`, confirm the pre-damage value directly against the paused,
recovered instance, then repair the live table using that recovered
instance as your source of truth — not by promoting it into production,
which would be a full-database outage over a single wrongly-scoped
column update. Separately: measure the churn table's bloat with
`pgstattuple`, then fix it by retuning autovacuum, not by running one
manual `VACUUM` and moving on. Separately again: recover the deleted
`payment_events` documents from the `mongodump --oplog` backup `break.sh`
already took — restore it into a scratch, standalone `mongod` on a second
port inside the `mongo` container, replay its oplog, confirm the
documents read back correctly there, then backfill only those documents
into the live collection — the same restore-to-scratch-then-backfill
pattern as the PostgreSQL PITR above, not a wholesale collection replace.
Full commands are in `README.md`; `SOLUTION.md` has the complete worked
chain if you get stuck.

Five things have to be true for `verify.sh` to pass, checked
independently:

1. `/tmp/answer` inside `ws` contains `recovery_seconds=`,
   `bloat_ratio_before=` (both parseable numbers in plausible ranges),
   and `recovered_status=` — the last one compared against the stash
   `break.sh` left inside `pg`.
2. The damaged row's `status` and `amount_minor` match their stashed
   pre-damage values.
3. The churn table's `pgstattuple` dead-tuple percentage is back under a
   stated threshold, **and** `pg_class.reloptions` shows autovacuum
   enabled again with non-default thresholds — a plain `VACUUM` that
   never touches the table's autovacuum settings does not pass this.
4. No `idle in transaction` session older than 60 seconds survives —
   exactly the pattern that would silently defeat the vacuum fix.
5. The deleted `payment_events` documents are back in the live Mongo
   collection with every field — `payment_id`, `merchant_id`, `type`,
   `ts`, `payload.amount_minor`, `payload.channel` — matching the stash
   `break.sh` left, not only the same document count.

## Exercises

1. Compute the memory ceiling this stack's `max_connections` and
   `work_mem` actually imply, assuming a plan with up to six
   sort-or-hash nodes can run concurrently on any one connection.
   **Hint:** the naive figure — `max_connections × work_mem` — treats
   `work_mem` as a per-connection budget; multiply in the node count
   before you trust any ceiling you compute.
   **Solution sketch:** `max_connections` is left unset in this stack's
   `postgresql.conf`, so it takes PostgreSQL's built-in default of 100;
   `work_mem=4MB`. Naive ceiling:
   100 × 4 MB = 400 MB. Real ceiling at up to six concurrent nodes per
   connection: 100 × 6 × 4 MB = **2,400 MB** — six times the naive
   figure, entirely from `work_mem` being a per-node, not per-connection,
   limit.

2. Find the oldest open transaction on `payments` and compute the
   wraparound headroom remaining.
   **Hint:** `pg_stat_activity.xact_start` finds the oldest transaction;
   `age(datfrozenxid)` from `pg_database` gives the table's current
   distance into the wraparound counter.
   **Solution sketch:** `SELECT pid, now() - xact_start AS age, query
   FROM pg_stat_activity WHERE xact_start IS NOT NULL ORDER BY xact_start
   LIMIT 1;` finds the oldest transaction. `SELECT datname, age(datfrozenxid)
   FROM pg_database WHERE datname = 'payments';` gives the current age;
   headroom is `autovacuum_freeze_max_age` (200,000,000 by default) minus
   that age. A healthy, regularly-vacuumed database on this dataset sits
   at an age of a few thousand — headroom in the hundreds of millions,
   nowhere near the deadline.

3. Measure `idempotency_keys`' bloat with `pgstattuple` and compare it
   against the common estimate query.
   **Hint:** the estimate query reads `pg_stat_user_tables.n_dead_tup`
   and `n_live_tup`; `pgstattuple` actually scans the table. Run both and
   look at how far apart they land, not only which one is bigger.
   **Solution sketch:** `SELECT * FROM pgstattuple('idempotency_keys');`
   reports an exact `dead_tuple_percent`. `SELECT round(100.0 * n_dead_tup
   / NULLIF(n_live_tup + n_dead_tup, 0), 1) FROM pg_stat_user_tables WHERE
   relname = 'idempotency_keys';` reports the cheap estimate. With
   autovacuum disabled the whole time `break.sh` was churning this table,
   `n_dead_tup` was never given a chance to go stale relative to reality
   in this specific case — but the two numbers diverge sharply on any
   table where autovacuum *did* run since the last `ANALYZE`, because
   `n_dead_tup` only reflects what the last vacuum/analyze pass saw, not
   the current instant.

4. A 40%-bloated table in production cannot take a lock longer than a few
   milliseconds. Choose the correct remediation and justify it against
   the lock-level table above.
   **Hint:** rule out anything holding `ACCESS EXCLUSIVE` for the
   rewrite's full duration before you pick between what's left.
   **Solution sketch:** `pg_repack`. It builds a shadow copy of the table
   concurrently, replaying writes made during the rebuild via a trigger,
   and only takes `ACCESS EXCLUSIVE` for the final, near-instant table
   swap. `VACUUM FULL` is ruled out specifically because it holds that
   same lock for the entire rewrite, not only for the swap — on a table
   this bloated, that is minutes of full unavailability, not milliseconds.

5. Size a PgBouncer pool, in transaction pooling mode, for an application
   that runs 500 instances, each holding up to 20 idle HTTP-driven
   connections, but never more than roughly 40 database transactions
   in flight across the whole fleet at any instant.
   **Hint:** transaction pooling multiplexes server connections across
   transactions, not across clients — size the pool to the concurrent
   transaction count, not the client count.
   **Solution sketch:** a `pool_size` around 40-50 (some headroom over
   the stated peak) is enough — the 500 × 20 = 10,000 client-side
   connections never need 10,000 (or even 500) server-side processes,
   because transaction pooling hands a server connection back to the pool
   the instant each transaction commits, regardless of how many idle
   client connections are waiting.

6. Explain precisely what is lost when `synchronous_commit=off`, and
   under what specific failure it is lost.
   **Hint:** distinguish a plain process crash from a power loss or OS
   crash — they are not the same failure for this setting.
   **Solution sketch:** nothing is lost on an ordinary process crash,
   because the unflushed WAL record still sits in the OS page cache and
   ordinary crash recovery replays it. What's lost is any transaction
   whose `COMMIT` returned to the client but whose WAL record had not yet
   been flushed (within `wal_writer_delay`, up to 200 ms by default) when
   a power loss or OS-level crash occurs — the client already acted on a
   success it received in good faith, and that transaction is gone on
   restart with no trace in the log that it ever existed.

7. Explain why `mongodump --oplog` cannot be scoped with `--db` or
   `--collection`, and what a backup job that only cares about `payments`
   in a multi-database deployment has to do instead.
   **Hint:** the flag's consistency guarantee only makes sense across
   everything captured in the same oplog window — think about what
   "internally consistent as of one instant" would even mean for a dump
   of only part of a deployment.
   **Solution sketch:** `--oplog` tails `local.oplog.rs` for the whole
   duration of the dump and replays it on restore to carry every dumped
   collection forward to the same instant; that guarantee is
   deployment-wide, not per-database, which is why MongoDB refuses
   `--oplog` together with `--db`/`--collection`. A backup job that only
   needs `payments` still has to run a full, unscoped `mongodump --oplog`
   (or move to filesystem or Atlas snapshots) and restore only the
   databases it cares about — there is no way to keep the oplog
   consistency guarantee while filtering the dump itself.

## Anti-patterns / common mistakes

- **Testing backups by checking the backup job's exit code.** A
  `pg_basebackup` or `pg_dump` that exits 0 proves the *write* succeeded;
  it proves nothing about whether the resulting files can actually be
  restored into a working, correct database. Mistake 8 in
  `STRATEGY.md` — the only test that counts is a restore that produces a
  known value you can check.
- **Raising `max_connections` to solve a pooling problem.** Every extra
  connection is another OS process and several more megabytes, before it
  runs a single query — and it multiplies the `work_mem` exposure
  computed above. The actual fix for "we're running out of connections"
  is almost always transaction-mode pooling, which reduces server-side
  connections without discarding client concurrency, not a bigger ceiling
  on how many processes Postgres is allowed to fork.
- **Running `VACUUM FULL` on a live table because it sounds thorough.**
  It holds `ACCESS EXCLUSIVE` for the entire rewrite, not a brief moment —
  a genuine outage on that table for as long as the rewrite takes.
  Plain `VACUUM`, a retuned autovacuum, or `pg_repack` reclaim the same
  space (or close to it) without ever taking that lock.

## Teardown

See `labs/day06/teardown.md`.
