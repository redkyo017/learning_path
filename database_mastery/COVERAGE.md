# Coverage — the anti-omission audit

This path is ordered by the architecture of a database — storage, logical
model, access method, planner, concurrency, durability, distribution, and
then a synthesis day — rather than by a certification syllabus. That
ordering is the whole point of the path, and it carries one real risk: it
can silently drop a topic that a syllabus-driven sweep would have caught,
because nothing forces every exam objective past the door if you're
building from first principles instead of checking boxes.

This file is that sweep, run after the fact against what the eight days
and their labs actually contain, not against what the plan said they
would contain. Four objective lists are checked below: MongoDB's C100DBA
exam, a PostgreSQL DBA competency list, MySQL 8/InnoDB's operational
surface, and classical relational theory. Every objective from every list
is either mapped to the day and section that covers it, or marked
**SKIPPED** with a stated reason. There is no third category.

Where a skip could not be justified in one honest line, it is reported as
a **GAP** in its own section at the end instead — naming the day that
should have covered it and what is actually missing. Four such gaps
turned up on the first sweep. Two of them — MongoDB backup and recovery,
and MySQL/InnoDB row formats — have since been closed by content that now
exists, and are mapped in their tables below rather than listed at the
end; two remain open. They are not smoothed into skips here; an audit
that launders gaps into skips is worse than no audit, because it stops
anyone from looking again.

## Table 1 — MongoDB C100DBA (Associate DBA) objectives

| Objective | Day | Where it is covered |
|---|---|---|
| Philosophy and features | Day 1, Day 2 | Day 1 "Core concepts" → "WiredTiger: documents in a B-tree, compressed by default"; Day 2 "Core concepts" → "'Schemaless' describes the engine, not the application" |
| CRUD | Day 2, Day 3 | Day 2 lab deliverable 3 (restructuring `merchant_catalog` — real inserts/updates/deletes against a live collection); Day 3 "Read the instrument first" (`db.payment_events.find().sort().limit()`) |
| Indexing | Day 3 | "Core concepts" → "MongoDB: ESR, compound prefixes, index intersection, unanchored regex"; lab deliverable 4 (index on `payment_events`) |
| Aggregation | Day 4 | "Core concepts" → "MongoDB: stage order and pushdown"; exercise 6 (reordering `$match` before `$lookup`) |
| Data modelling | Day 2 | "Core concepts" → "Document modelling: embed versus reference, as four questions" and "The unbounded-array antipattern"; lab deliverable 3 (bucketing) |
| Replication | Day 7 | "Read the instrument first" (`rs.status()`); "Core concepts" → "Physical versus logical replication" (oplog) |
| Sharding | Day 7 | "Core concepts" → "MongoDB sharding, and the monotonic shard key as the worked failure"; lab deliverable `hot_shard_reason` |
| Server administration | Day 7 | "Core concepts" → "Atlas: the same reflex, different console" (Profiler, Performance Advisor, Alerts). Thin: this is the only mapping in this table that covers a managed console rather than a hands-on administration task — see the discrepancy note below. |
| Backup and recovery | Day 6 | "Core concepts" → "MongoDB backup and recovery: the oplog, `mongodump --oplog`, and its honest limits" (`local.oplog.rs` as a fixed-size collection that wraps, reading the window with `rs.printReplicationInfo()`, `mongorestore --oplogReplay` and `--oplogLimit`, and why a logical dump is not a large cluster's primary backup — filesystem snapshots and Atlas continuous backup named as the physical answer); lab deliverable 5 and `labs/day06/verify.sh` check 5 (recover the `payment_events` documents `break.sh` deletes, from the `mongodump --oplog` it takes first, graded field-for-field rather than on document count) |
| Security | — | **GAP** — see Gaps section |

## Table 2 — PostgreSQL DBA competencies

| Competency | Day | Where it is covered |
|---|---|---|
| Installation and configuration | Day 6 | Configuration only — "Core concepts" → "Checkpoints and the recovery-time trade-off", "`fsync` and `synchronous_commit`", "The five settings that matter, and `work_mem`'s own treatment". Installation itself is SKIPPED — see below. |
| Roles and security | — | **GAP** — see Gaps section |
| Backup and recovery | Day 6 | "Core concepts" → "Backup and PITR"; lab (real `pg_basebackup`, WAL archive replay to a `recovery_target_time`, `recovery_seconds`/`recovered_status` deliverables) |
| Vacuum and maintenance | Day 6 | "Core concepts" → "Autovacuum: what it does, and the outcome that looks like a bug", "Dead tuples and the visibility horizon", "Freezing and wraparound, with the arithmetic", "Bloat, measured honestly"; lab deliverable (retuned autovacuum thresholds on `idempotency_keys`) |
| Replication and high availability | Day 7 | "Core concepts" → "Physical versus logical replication", "Synchronous versus asynchronous", "Failover semantics — what is actually lost"; lab deliverable `failover_seconds` |
| Monitoring | Day 7 | "Core concepts" → "Managed reality: what the console is actually showing you" (Performance Insights, CloudWatch, Enhanced Monitoring); built on `pg_stat_activity`/`pg_stat_statements` reading practiced in Days 3–6 |
| Performance tuning | Day 3, Day 4 | Day 3 (composite/partial/covering indexes, `EXPLAIN (ANALYZE, BUFFERS)`); Day 4 "Core concepts" → row-estimate error, extended statistics, join algorithms, rewrites (sargability, keyset pagination, N+1) |
| Partitioning | Day 7 | "Core concepts" → "Partitioning" (range partitioning, pruning, partition-wise join); exercise 2 (retention-policy design) |
| Upgrades | Day 7 (partial) | "Core concepts" → "Physical versus logical replication" names logical replication's cross-major-version capability directly. The actual upgrade *procedure* (`pg_upgrade`, cutover choreography) is SKIPPED — see below. |
| Extensions | Day 3, Day 4, Day 6 | `pg_stat_statements` (Day 3 "Core concepts", Day 4 N+1 exercise); `pgstattuple` and `pg_repack` (Day 6 "Bloat, measured honestly" and the remediation table) |

## Table 3 — MySQL 8 / InnoDB operational topics

| Topic | Day | Where it is covered |
|---|---|---|
| Buffer pool | Day 3 | "Core concepts" → "B-tree anatomy" (buffer-pool hit/miss framing shared across engines); `content/GLOSSARY.md` "buffer pool" entry names `innodb_buffer_pool_size` directly |
| Redo and undo | Day 6 | "Core concepts" → "WAL, redo, undo, binlog, oplog — one idea, seen four ways" |
| Row formats | Day 1 | "Core concepts" → "InnoDB row formats: the same overflow, a different residue" (the four `ROW_FORMAT` values with `DYNAMIC` as MySQL 8.4's default; the 768-byte inline prefix ahead of a 20-byte pointer under `COMPACT`/`REDUNDANT` against the bare pointer under `DYNAMIC`/`COMPRESSED`; the roughly-half-a-16-KB-page inline ceiling set against PostgreSQL's TOAST threshold and its 18-byte pointer). Thin: explained but never measured — see the discrepancy note below. |
| Locking and deadlocks | Day 5, Day 8 | Day 5 "Core concepts" → "MySQL InnoDB" (gap locks, next-key locks) and "Deadlocks" (`SHOW ENGINE INNODB STATUS`); Day 8 gauntlet pool member `innodb_deadlock` |
| Replication and binlog | Day 6 | "Core concepts" → "WAL, redo, undo, binlog, oplog — one idea, seen four ways" (the binlog paragraph specifically) |
| `performance_schema` | Day 8 (reference) | `content/primers/catalog-field-reference.md` → `#performance_schemaevents_statements_summary_by_digest` and `#data_lock_waits`, named as MySQL's `pg_stat_statements` analog in Day 8's diagnostic toolkit. Thin: no lab exercise queries `performance_schema` directly — the InnoDB deadlock pathology is diagnosed through `SHOW ENGINE INNODB STATUS` instead. See the discrepancy note below. |
| The optimizer | Day 4 | "Core concepts" → "MySQL: `optimizer_trace`" |
| Backup | Day 6 | "Core concepts" → "Backup and PITR" names `mysqldump` as MySQL's logical-backup analog to `pg_dump`. Thin: conceptual only — no MySQL-specific backup lab exists, unlike PostgreSQL's live `pg_basebackup`/PITR exercise. See the discrepancy note below. |

## Table 4 — Relational theory

| Concept | Day | Where it is covered |
|---|---|---|
| Functional dependencies | Day 2 | "Core concepts" → "Functional dependency, stated precisely"; exercise 1 (full FD set for `wide_payments`) |
| 1NF through BCNF | Day 2 | "Core concepts" → "1NF, 2NF, 3NF, BCNF — introduced by the anomaly each one blocks, in order"; exercises 2 and 3 (highest normal form satisfied, BCNF decomposition) |
| Lossless join | Day 2 | "Core concepts" → "Lossless-join decomposition, and how to check it"; exercise 4 (row-count reconciliation against `wide_payments`) |
| Dependency preservation | Day 2 | "Core concepts" → "Dependency preservation, and the case where BCNF costs it" (the `{city, street, zip}` worked counterexample) |
| The ACID anomaly ladder | Day 5 | "Core concepts" → "ACID, stated precisely" and "The anomaly ladder"; `content/primers/isolation-anomaly-ladder.md` (`#matrix`); exercise 1 (reproducing all six anomalies live) |
| Serialisability | Day 5 | "Core concepts" → "PostgreSQL's three levels, mechanically" (SSI/predicate locking); `content/GLOSSARY.md` "SSI" entry |

## Discrepancies between the plan and the delivered content

The task brief for this audit (task 14) and the design spec both describe
this file's job identically; neither predicts specific per-topic mappings,
so there is no line-item disagreement to report against either of those
documents. Three coverage-quality discrepancies did turn up between what
a syllabus sweep would expect and what the content actually delivers,
short of being outright gaps:

- **`performance_schema` (Table 3) is documented but never exercised.**
  The primer explains `events_statements_summary_by_digest` and
  `data_lock_waits` in real depth, including the same "sort by total, not
  mean" trap `pg_stat_statements` teaches — but no lab, including Day 8's
  `innodb_deadlock` pathology, ever queries it live. The deadlock
  diagnosis instead reads `SHOW ENGINE INNODB STATUS` throughout.
- **MySQL backup (Table 3) is named, not exercised.** Day 6 pairs
  `mysqldump` with `pg_dump` as the two logical-backup examples in one
  sentence, then spends the entire lab on PostgreSQL's `pg_basebackup` and
  PITR. MySQL backup is conceptually covered by the same logical/physical
  distinction; it has no MySQL-specific lab the way PostgreSQL does.
- **InnoDB row formats (Table 3) are explained but never measured.**
  Day 1's Core Concepts section covers the four formats and the off-page
  mechanics in the same depth it gives PostgreSQL's TOAST, and Day 1's
  exercise 7 asks the learner to read a live table's format and reason
  about the alternative — but no graded lab deliverable reads a
  `ROW_FORMAT` from either engine's catalog, so the topic is exercised
  only where nothing checks the answer.
- **MongoDB "server administration" (Table 1) maps to a managed console,
  not a hands-on task.** Every other Table 1 row points at a Core
  Concepts section built around commands the learner actually runs.
  This row's best mapping — Day 7's Atlas Profiler/Performance
  Advisor/Alerts paragraph — is real content, but it is read-only
  reasoning about a console, not an administration task performed against
  the local `rs0` stack the rest of the path uses.

None of these four are severe enough to count as gaps — each has a real,
specific section backing it, only a thinner one than its neighbors in the
same table — but an audit that only reported clean mappings would be
hiding exactly the kind of degradation in coverage quality this file
exists to surface.

## SKIPPED

- **Engine installation from source.** `labs/stack/` runs `postgres:16`,
  `mysql:8.4`, and `mongo:7` as prebuilt Docker images from the first
  command any lab issues. No day ever compiles or installs an engine
  binary, because the stack is containerised by design.
- **OS-level security hardening.** Firewall rules, SSH configuration,
  patching cadence, and kernel-level controls belong to the sibling
  `linux_ops_mastery` path. This path's content starts at the database
  process, not the host it runs on.
- **MongoDB Atlas billing administration.** Day 7's Atlas usage is scoped
  entirely to the M10 cluster's technical surfaces — the Profiler,
  Performance Advisor, and Alerts — never the billing console or plan
  management, which is an account-administration skill with no database
  mechanics behind it.
- **Replica-set elections beyond failover semantics.** Day 7 covers what
  RDS Multi-AZ failover actually promotes and loses, and reads a
  three-member Atlas replica set's `rs.status()` shape directly. The
  election protocol itself — priority, terms, catchup — is never
  exercised, because this path's own local stack runs a single-member
  `rs0` that never holds an election to observe.
- **MySQL group replication.** This path's MySQL content is single-node
  InnoDB with binlog-based replication named conceptually (Day 6), never
  exercised as a running topology. Group replication — multi-primary,
  GTID-based consensus — is a separate deployment this stack never stands
  up.
- **PostgreSQL logical decoding plugins.** Day 7 covers
  `CREATE PUBLICATION`/`CREATE SUBSCRIPTION`, the SQL-level logical
  replication feature, but not the decoding-plugin architecture
  underneath it (`pgoutput`, `wal2json`, `test_decoding`) that a
  change-data-capture tool would consume directly.
- **Major-version upgrade procedures.** `pg_upgrade` and the deployment
  choreography around a live version bump are never exercised — the
  stack pins exact image versions (`postgres:16`, `mysql:8.4`, `mongo:7`)
  for the life of the path and never runs an upgrade against them.

## GAPS

Two objectives could not be honestly justified as skips. Each is a real
absence, not a naming exercise — the day named below is where the topic
belongs given the rest of that day's scope, and nothing currently there
covers it.

1. **PostgreSQL roles and security (Table 2).** No day teaches
   `CREATE ROLE`, `GRANT`/`REVOKE`, or row-level security's actual syntax.
   The only appearance of the phrase "row-level security" in the entire
   path is a single name-check inside Day 8's multi-tenancy exercise
   solution sketch ("row-level security enforces isolation at the query
   layer instead of the schema layer"), with no `CREATE POLICY` ever
   written and no lab exercising it. **Day 6** ("Durability and
   Operations," which already covers connections and pooling) is where
   this belongs — it is the day already responsible for the operational
   surface a DBA manages beyond query performance.
2. **MongoDB security (Table 1).** No content anywhere addresses
   authentication, role-based access control, or network encryption for
   MongoDB. The local stack and the Atlas cluster in Day 7 are both used
   without ever discussing how either one is actually secured. **Day 7**
   is where this belongs — it already walks the Atlas console for other
   administrative concerns (Profiler, Alerts, parameter groups) and would
   naturally extend to Atlas's built-in database-user and network-access
   configuration.

The other two gaps this sweep opened — MySQL/InnoDB row formats (Table 3)
and MongoDB backup and recovery (Table 1) — were closed after the fact and
now carry real mappings in their tables above. They are recorded here only
so the record of what was once missing is not lost. The two above are not
closed, and are not softened by those two closures.
