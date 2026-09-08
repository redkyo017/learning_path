# Database Mastery — Design Spec

**Date:** 2026-09-07
**Location:** `database_mastery/`
**Duration:** 8 days, 3 h/day (~24 h total)
**Path type:** Applied / engineering — labs are authored here, run by the learner.

---

## Purpose & Goals

The learner is a working software engineer who touches PostgreSQL, MySQL and
MongoDB every day, and who reaches into AWS RDS and MongoDB Atlas to monitor and
debug. The theory was learned properly once, years ago, and has since decayed
into habit: the right thing usually gets done, but the reasoning behind it is no
longer available on demand. That is a specific failure mode, and it does not
respond to re-reading. Habit is re-grounded by evidence the learner produces
themselves, against a live database, under conditions where a wrong belief
produces a visibly wrong number.

This path therefore does not teach database concepts and then demonstrate them.
It teaches each concept *through the instrument that measures it*, and it asks
the learner to commit to a predicted number before every measurement. The gap
between prediction and measurement is the actual curriculum — it is the only
mechanism that makes decayed knowledge visible to its owner.

Mastery here means three roles at once, which the path treats as one skill
viewed from three angles:

- **Administrator** — configure, size, back up, restore, vacuum, monitor, and
  recover a database; know what a commit guarantees and what it does not.
- **Operator** — take an unfamiliar, misbehaving production database and, using
  only its own instruments, produce a chain of evidence ending in a diagnosis,
  then a fix, then proof the fix worked.
- **System designer** — choose engines, schemas, indexes, isolation levels,
  partition and shard keys under stated constraints, and defend each choice with
  capacity arithmetic rather than preference.

The three engines are treated as three implementations of one architecture, so
the knowledge generalises past them. PostgreSQL is the teaching engine because
its introspection is the best in the field; MySQL/InnoDB appears at the specific
points where its design genuinely diverges; MongoDB carries the document and
distribution half.

---

## Success Criteria

By the end of Day 8, without notes, the learner can:

1. Read `EXPLAIN (ANALYZE, BUFFERS)` output and name the single dominant cost,
   plus the estimated-vs-actual row divergence that produced it.
2. Given a slow query, decide between index, rewrite, statistics and
   configuration as the correct intervention — and prove the choice by
   measurement rather than assertion.
3. Design a composite index for a given query set in PostgreSQL, MySQL and
   MongoDB, and defend the column order in each (equality → range → sort; ESR).
4. Derive a BCNF decomposition from a stated set of functional dependencies,
   prove it lossless, and price a deliberate denormalisation in terms of the
   enforcement it obliges.
5. Reproduce any anomaly on the ladder — dirty read, non-repeatable read,
   phantom, lost update, read skew, write skew — and state which isolation level
   in which engine prevents it, and at what cost.
6. Find the root blocker in a multi-session lock pileup in under five minutes,
   using `pg_locks` / `pg_blocking_pids()` and the InnoDB equivalents.
7. State precisely what a commit guarantees in each of the three engines, and
   execute a point-in-time restore drill that recovers known values.
8. Diagnose table and index bloat, assess transaction-ID wraparound risk, and
   choose between `VACUUM`, autovacuum retuning, `pg_repack` and `VACUUM FULL`
   with the outage cost of each.
9. Size a connection pool and set the five configuration parameters that matter,
   showing the memory arithmetic — including why `work_mem` is per-node and not
   per-query.
10. Choose a MongoDB shard key for a stated access pattern and predict its
    failure mode; explain the causes of replication lag and the read-your-writes
    hazard on a read replica.
11. Read AWS RDS Performance Insights and MongoDB Atlas Profiler output and
    translate the top wait event or slow operation into a specific fix.
12. Produce a system design for a stated workload with capacity arithmetic, an
    engine-choice justification, and a zero-downtime migration plan.

Each criterion is exercised by at least one lab deliverable and re-tested in the
Day 8 gauntlet. `COVERAGE.md` records the mapping.

---

## Constraints & Environment

**Local stack.** Docker Compose, project name `dbmastery`, four services:

| Service | Image | Role |
|---|---|---|
| `pg` | `postgres:16` | Primary teaching engine |
| `my` | `mysql:8.4` | InnoDB contrast points |
| `mongo` | `mongo:7` | Document engine, replica set of 1 (needed for transactions) |
| `ws` | built from `Dockerfile.ws` | Workstation: `psql`, `mysql`, `mongosh`, `pgbench`, `pg_repack`, `jq` |

All lab work happens from inside `ws`, so nothing depends on what is installed
on the learner's host. Verified host capacity: 24 GB RAM, 8 cores, 135 GB free —
comfortably above the stack's needs.

**Deliberate configuration.** `pg` runs with `shared_buffers=256MB`,
`work_mem=4MB`, and autovacuum left at defaults except where a lab changes it.
These are set *below* what the host could afford, deliberately: with the working
set larger than the buffer pool, `EXPLAIN (ANALYZE, BUFFERS)` reports meaningful
`shared read` versus `shared hit` counts and sequential scans have real cost. A
generously configured stack on a 24 GB machine would cache everything and teach
the opposite of the intended lesson. `my` gets a correspondingly small
`innodb_buffer_pool_size=256M`; `mongo` a 512 MB WiredTiger cache.

**Dataset — a payments / ledger platform.** Chosen over e-commerce because it is
the only candidate domain where the transaction material is load-bearing rather
than illustrative: double-entry bookkeeping supplies a real invariant to defend,
which makes write skew reproducible instead of abstract. It also supplies
natural skew, natural time-based growth, and a natural document side.

Relational core (PostgreSQL, and a subset in MySQL):

- `merchants`, `customers`, `accounts`
- `payments` — the transactional head
- `ledger_entries` — double-entry lines; the large table
- `payment_methods`, `refunds`, `disputes`
- `wide_payments` — a deliberately denormalised table, Day 2's starting artifact

Document side (MongoDB):

- `payment_events` — append-only event documents
- `merchant_catalog` — nested product/pricing documents, including one
  deliberately unbounded-array design for Day 2

**Scale.** ~10M `ledger_entries` in PostgreSQL, a 2M-row subset in MySQL, ~2M
`payment_events` documents in MongoDB. Roughly 6 GB on disk and ~15 minutes of
one-time seeding. The generator takes a `SCALE` environment variable so the
learner can regenerate smaller for a fast reset; 10M is the default because
below a few million rows the planner's choices stop being interesting.

**Skew is authored, not incidental.** Merchant activity follows a power-law
distribution — a handful of merchants own most rows — and payment timestamps
cluster into business hours. Uniformly distributed synthetic data is the single
most common reason a tuning exercise teaches nothing: it hides exactly the
correlation, selectivity-misestimation and hot-key pathologies the path is
about. Generation is deterministic (fixed RNG seed) so `verify.sh` can assert on
concrete numbers.

**Cloud.** Exactly one day (Day 7) uses real managed services: an RDS PostgreSQL
`db.t4g.micro` Multi-AZ instance and a MongoDB Atlas M10. Estimated cost **$2–5**
if torn down the same day. The RDS side ships as Terraform (`terraform.tfvars.example`,
no real values committed); Atlas is a written console walkthrough. Teardown is a
checklist plus `labs/verify-teardown.sh`, which fails if any billable resource or
snapshot survives.

**Standing rules.**

| Constraint | Rule |
|---|---|
| Git | Never commit, add or push on the learner's behalf, in any phase. |
| Credentials | No real secrets, keys, account IDs or connection strings in any file. Placeholders and `.example` files only. |
| Real infrastructure | Labs are *authored* here, never run. No `terraform apply`, no `aws` calls, no `docker compose up` during authoring. |
| Exercises | Every exercise ships a hint and a solution sketch. Non-negotiable. |
| Labs | Every lab ships `README.md`, `verify.sh`, `SOLUTION.md`, `teardown.md`. |
| Answers | `verify.sh` never hard-codes an expected value that `break.sh` generated; it reads the per-run value from a stash file and compares without printing either. |

---

## Strategy (the core design decision)

### The law

> **No claim about a database counts until you have proved it with a query
> against that database.**

Concepts arrive through their instrument, never through a definition. The
learner does not "learn MVCC" — they open two `psql` sessions, read `xmin`,
`xmax` and `ctid`, watch a long-running transaction pin the vacuum horizon, and
watch bloat accumulate in `pg_stat_user_tables`. They do not "learn indexes" —
they read buffer counts collapse under an index-only scan. They do not "learn
normal forms" — they insert the update anomaly, watch it corrupt the data, then
normalise it away and watch the same insert fail.

### The ordering

Days follow a six-layer model of what a database *is*, because each layer is
only explicable in terms of the one beneath it:

```
storage  →  access method  →  planner  →  concurrency  →  durability  →  distribution
```

Logical structure (normal forms, keys, constraints, document modelling) is
inserted as Day 2, between storage and access methods. This is a deliberate
deviation from a pure layer ordering: instrument-first requires that the learner
hold the instruments before they can prove an anomaly, so catalog and `EXPLAIN`
literacy must come first. Day 1 exists to supply them.

### The daily loop

Seven steps, every day. Step 3 carries the design.

1. **Name the layer.** Which of the six is today's subject.
2. **Read the instrument raw** before any GUI formats it — the catalog view or
   the `EXPLAIN` JSON, never pgAdmin or Compass first.
3. **Predict the number before measuring it, in writing,** in `journal.md`.
4. **Measure.** The gap between the prediction and reality *is* the lesson.
5. **Write the evidence chain** before touching a fix.
6. **Fix, then re-read the same instrument** as proof.
7. **Record what you would check first next time.**

Step 3 is what converts "I know about indexes" into calibrated judgement. A
learner whose theory has decayed into habit cannot see the decay from the
inside; a written prediction that misses by 400× makes it visible in one move.

### Lab format: the diagnostic gauntlet

Each diagnostic lab (Days 3–6 and 8) ships a `break.sh` that injects a real
pathology into the seeded stack and prints exactly one `SYMPTOM` line — no diagnosis, no hints. The learner
diagnoses from the database's own instruments and fixes it. `verify.sh` exits 0
only when **both** deliverables pass: the pathology is genuinely resolved, and
`/tmp/answer` holds the diagnosis, proving the learner found the cause rather
than blundered into a fix. Several `verify.sh` scripts additionally reject the
common wrong fix — Day 4's, for instance, fails if `enable_nestloop` was simply
turned off.

This mirrors the learner's actual on-call work, and it is the format that made
`linux_ops_mastery` effective.

### Approaches considered and rejected

- **Failure-first inversion** — order the whole path by the twelve canonical
  production incidents and derive theory backwards. Very sticky, but coverage
  becomes lumpy: loud failures get deep treatment while schema design, normal
  forms and capacity planning barely appear. Adopted as the *lab format*, not as
  the ordering.
- **Pure unified-model spine** — teach the six layers across all three engines
  with labs as illustration. Best for articulating system design, but it is the
  most academic of the options, and academic is precisely the mode that already
  decayed on this learner once. Adopted as the *ordering*, not as the method.
- **Benchmark-driven** — measure every knob change with `pgbench` / `sysbench`.
  Rigorous, but most of the clock goes to running benchmarks rather than
  reasoning. Retained only where a benchmark is the point (Day 6 config).

---

## The mistakes that waste most of a learner's time

This becomes a full section of `STRATEGY.md`. Each entry names the mistake, why
it is seductive, the corrective drill, and the day that administers it.

| # | Mistake | Corrective drill | Day |
|---|---|---|---|
| 1 | Reading `EXPLAIN` without `ANALYZE, BUFFERS`, and never comparing estimated to actual rows | Every plan is read estimate-first; the divergence is named before the fix | 3, 4 |
| 2 | Adding indexes by guessing, and never removing them | Measure `pg_stat_user_indexes`; find and drop the decoys `break.sh` planted | 3 |
| 3 | Tuning configuration knobs before fixing queries | Config day comes *after* index and planner days, by design | 6 |
| 4 | Learning isolation levels from a table in a book | Every anomaly is reproduced live in two racing sessions | 5 |
| 5 | Memorising normal-form definitions instead of reproducing the anomaly | Insert the update/insert/delete anomaly, watch it corrupt, then normalise | 2 |
| 6 | Treating MongoDB as schemaless | Document modelling gets the same anomaly treatment as relational | 2, 7 |
| 7 | Benchmarking on uniformly distributed data | The seeded dataset is power-law skewed on purpose | all |
| 8 | Never running a restore drill — testing the backup, not the restore | PITR to a known pre-damage value, verified | 6 |
| 9 | Blaming the database for what is an N+1 or a missing bound | Query-shape pathologies sit alongside engine pathologies in the gauntlet | 4, 8 |
| 10 | Fixing the symptom that is loudest rather than the session that is root | Lock pileups are diagnosed to the root blocker, not the longest waiter | 5 |
| 11 | Choosing a shard key by cardinality alone | Shard-key selection drills frequency and monotonicity too, then predicts the failure | 7 |
| 12 | Trusting a dashboard over the catalog | Step 2 of the daily loop forbids the GUI first | all |

---

## Curriculum

### Day 1 — Storage, and the instruments that read it
**Layer:** storage · **Budget:** 1 h instruments, 2 h storage + lab

Concepts: the PostgreSQL heap page and tuple header (`xmin`, `xmax`, `ctid`,
alignment padding, `fillfactor`); TOAST and out-of-line storage; InnoDB's
clustered index — the table *is* the primary key's B-tree, and secondary indexes
store the PK, not a row pointer; WiredTiger documents and compression. The
catalog as ground truth: `pg_class`, `pg_attribute`, `pg_stat_user_tables`,
`pg_statio_*`, `pgstattuple`, `pg_column_size`; MySQL `information_schema` and
`performance_schema`; MongoDB `collStats`, `dbStats`, `$indexStats`.

Lab — *Three engines, one row.* Identical logical data is loaded into all three.
Deliverables: (a) explain, with catalog evidence, why the PostgreSQL table
exceeds the raw byte count of its data; (b) locate a value that has been TOASTed
and prove it lives out of line; (c) given three candidate primary keys, identify
which makes InnoDB's secondary indexes fattest, and by how much, measured not
argued.

### Day 2 — Logical structure: normal forms as anomaly prevention
**Layer:** logical · **Budget:** 1.5 h relational, 1.5 h document

Concepts: functional dependencies; 1NF → 2NF → 3NF → BCNF derived by reproducing
the anomaly each form prevents; lossless-join and dependency preservation; keys,
surrogate versus natural; constraints as the cheapest correctness mechanism
available (`CHECK`, `FOREIGN KEY`, `UNIQUE`, `EXCLUDE`), and what a foreign key
actually costs on write. Deliberate denormalisation: when it is right, and the
enforcement debt it creates (triggers, materialised views, reconciliation jobs).
Document modelling: the embed-versus-reference decision rule — cardinality,
access pattern, update frequency, the 16 MB limit — and the unbounded-array
antipattern with its bucketing remedy.

Lab — *The wide table.* Ships `wide_payments`, denormalised. Deliverables: (a)
SQL that demonstrably produces each of the three anomaly classes; (b) a BCNF
decomposition with the FD set written out; (c) a lossless-join proof by
row-count reconciliation; (d) in MongoDB, restructure the unbounded-array
`merchant_catalog` document so it cannot exceed the limit, and justify the
choice. `verify.sh` checks the constraints exist and the join-back is lossless.

### Day 3 — Access methods: indexes, measured
**Layer:** access method · **Budget:** 3 h

Concepts: B-tree anatomy, height, and why depth barely matters; selectivity and
why the planner may correctly refuse an index; composite column order (equality →
range → sort) and the leftmost-prefix rule; index-only scans and the visibility
map; partial and expression indexes; `INCLUDE` columns; when GIN, GiST and BRIN
win. MySQL: secondary index → PK lookup, and why a wide primary key poisons every
secondary index. MongoDB: the ESR rule, compound prefixes, why index intersection
is not the escape hatch it appears to be, unanchored `$regex`.
Instruments: `EXPLAIN (ANALYZE, BUFFERS)`, `pg_stat_user_indexes`,
`pg_stat_statements`; MongoDB `explain("executionStats")` and the
`keysExamined : docsExamined : nReturned` ratio.

Lab — *The 200× report.* `break.sh` drops the indexes that matter and plants
three decoys. Deliverables: (a) name in `/tmp/answer` the one composite index and
its column order, with the reason for that order; (b) bring the query under a
stated threshold, with an index-only scan proven by buffer counts; (c) fix a
MongoDB query running a collection scan at 50 000 : 1 examined-to-returned.

### Day 4 — The planner: why it chose that plan
**Layer:** planner · **Budget:** 3 h

Concepts: the cost model and what the constants mean; statistics — `n_distinct`,
histograms, most-common-values — and where they come from; correlated columns and
extended statistics; **row-estimate error as the master diagnostic**; join
algorithms (nested loop, hash, merge) and the conditions each wants; join order
and why it is the hard part; `LATERAL`; CTE materialisation before and after
PostgreSQL 12. Query rewrites that actually move the needle: sargability, `OR` →
`UNION ALL`, keyset versus `OFFSET` pagination, the N+1. MySQL: `optimizer_trace`.
MongoDB: aggregation stage ordering, `$match` and `$project` pushdown,
`allowDiskUse`, the cost of `$lookup`.

Lab — *The plan flip.* `break.sh` corrupts statistics so a well-behaved query
flips to a catastrophic plan with a 1000× row-estimate error. Deliverables: (a)
identify the plan node where estimate and actual diverge; (b) fix by the correct
means — `ANALYZE`, or extended statistics on the correlated pair. `verify.sh`
fails if `enable_nestloop` was disabled: the hack fix is explicitly rejected.

### Day 5 — Concurrency: transactions, isolation, locks
**Layer:** concurrency · **Budget:** 3 h

Concepts: ACID stated precisely, then the anomaly ladder reproduced live in two
sessions — dirty read, non-repeatable read, phantom, lost update, read skew,
**write skew**. PostgreSQL Read Committed / Repeatable Read / Serializable (SSI
and its false positives) versus MySQL Repeatable Read with gap and next-key locks
versus MongoDB multi-document transactions on snapshot isolation. Lock modes and
the lock queue; deadlock reproduction and reading the deadlock report;
`SELECT ... FOR UPDATE`, `SKIP LOCKED` as the job-queue pattern, advisory locks.
The long-running transaction as the root of most operational evil — it pins the
vacuum horizon, grows bloat, and stalls replication.

Lab — *The pileup and the negative balance.* `break.sh` leaves a five-session
blocking chain and a ledger that already contains a balance violation introduced
by write skew. Deliverables: (a) name the root blocker — not the loudest waiter —
and resolve the chain; (b) write the corrected transaction that prevents the
write skew, which a supplied harness then attacks with two racing sessions,
asserting the invariant holds. This is the path's crown lab.

### Day 6 — Durability and operations
**Layer:** durability · **Budget:** 3 h

Concepts: WAL, redo, undo, binlog and oplog as one idea seen four ways;
checkpoints and their I/O shape; `fsync`, `synchronous_commit`, and what a commit
acknowledgement actually promises; crash recovery. Autovacuum: what it does, why
it falls behind, freezing and transaction-ID wraparound, and reading
`pg_stat_progress_vacuum`. Bloat: measuring it honestly, then choosing between
`VACUUM`, retuned autovacuum, `pg_repack` and `VACUUM FULL` by outage cost.
MySQL: the purge thread and history list length. Backup and PITR, logical versus
physical, and the principle that only a restore is a test. Connections: why they
are expensive, the memory formula, `max_connections` arithmetic, and PgBouncer
pooling modes. The five configuration parameters that matter —
`shared_buffers`, `work_mem` (per node, not per query), `effective_cache_size`,
`maintenance_work_mem`, autovacuum thresholds.

Lab — *Crash and recover.* Deliverables: (a) hard-kill the engine mid-write and
bring it back, explaining from the log what recovery did; (b) point-in-time
restore to just before a destructive `UPDATE`, recovering known values; (c)
retune autovacuum so a churning table stops growing, proven by a bloat
measurement taken before and after.

### Day 7 — Distribution, and the managed cloud
**Layer:** distribution · **Budget:** 1.5 h concepts, 1.5 h cloud lab

Concepts: physical versus logical replication; synchronous versus asynchronous
and what each costs; the causes of replication lag and how to measure it; the
read-your-writes hazard on a read replica; failover semantics and exactly what is
lost. Declarative partitioning and partition pruning; partition-wise joins.
MongoDB sharding: shard-key selection on cardinality, frequency and monotonicity,
chunk migration, jumbo chunks, and the hot-shard failure. CAP and PACELC stated
honestly rather than as a slogan; quorum reads and writes; MongoDB read and write
concerns and causal consistency.
Managed reality: RDS parameter groups and which settings are locked, Performance
Insights and its wait events, Enhanced Monitoring, the CloudWatch metrics that
matter, Multi-AZ failover, storage autoscaling and burst-balance exhaustion;
Atlas Profiler, Performance Advisor, and alerting.

Lab — *The real thing.* Terraform provisions an RDS `db.t4g.micro` Multi-AZ
instance; Atlas M10 is created from the console per a written walkthrough.
Deliverables: (a) force a failover and record the downtime window and what
happened to in-flight connections; (b) read Performance Insights and name the top
wait event with the fix it implies; (c) on Atlas, create a deliberately
monotonic shard key on a test collection and predict its failure mode from the
profiler. Then teardown, enforced by `labs/verify-teardown.sh`.

### Day 8 — The gauntlet, and system design
**Layer:** all · **Budget:** 1.5 h gauntlet, 1.5 h design

Gauntlet: five unseen pathologies spread across PostgreSQL, MySQL and MongoDB,
timed, no hints, diagnosed against the fixed runbook the learner has been
building in `journal.md`. `verify.sh` scores them independently.

System design: capacity arithmetic (rows, bytes, IOPS, connections, growth); an
engine-choice rubric that survives contact with a real requirement; read and
write path design; caching layers and the invalidation question; idempotency
keys; the transactional outbox; zero-downtime schema migration by expand and
contract; multi-tenancy models and their operational consequences. Output: a
one-page design for a stated workload, graded against a rubric and a reference
solution, plus the learner's own consolidated runbook.

---

## Directory Layout

```
database_mastery/
├── README.md                       # prereqs, bring-up, 8-day map, the daily loop
├── STRATEGY.md                     # the law, the ordering, the daily loop, the 12 mistakes
├── journal.md                      # one evidence chain per lab, written before the fix
├── COVERAGE.md                     # anti-omission proof: syllabus objectives → day, or SKIPPED
├── content/
│   ├── GLOSSARY.md
│   ├── day01.md … day08.md
│   └── primers/
│       ├── explain-field-reference.md     # every EXPLAIN / executionStats field, decoded once
│       ├── catalog-field-reference.md     # pg_stat_* / performance_schema / collStats columns
│       └── isolation-anomaly-ladder.md    # 6 anomalies × 3 engines × isolation levels
├── labs/
│   ├── stack/
│   │   ├── docker-compose.yml             # pg, my, mongo, ws — project name `dbmastery`
│   │   ├── Dockerfile.ws
│   │   ├── README.md                      # bring-up, seeding, reset
│   │   ├── conf/                          # postgresql.conf, my.cnf, mongod.conf overrides
│   │   └── seed/
│   │       ├── 00-schema.sql              # relational DDL incl. wide_payments
│   │       ├── 10-generate.sql            # deterministic, skewed, SCALE-aware
│   │       ├── 20-mysql-load.sh           # COPY → CSV → LOAD DATA
│   │       ├── 30-mongo-load.js           # payment_events, merchant_catalog
│   │       └── README.md
│   ├── lib/
│   │   └── common.sh                      # require_stack, in_pg, in_my, in_mongo, answer_check
│   ├── day01/ … day08/
│   │   ├── README.md                      # goal, deliverables, success signal, how to run
│   │   ├── break.sh                       # days 3–6, 8 — injects, prints one SYMPTOM
│   │   ├── verify.sh                      # exits 0 only when both deliverables pass
│   │   ├── SOLUTION.md                    # full chain, mirroring journal.md's skeleton
│   │   └── teardown.md
│   ├── day07/terraform/
│   │   ├── rds.tf, variables.tf, outputs.tf
│   │   ├── terraform.tfvars.example        # placeholders only, no real values
│   │   └── atlas-setup.md                  # console walkthrough
│   └── verify-teardown.sh                  # fails if any billable resource or snapshot survives
└── docs/superpowers/
    ├── specs/2026-09-07-database-mastery-design.md
    └── plans/2026-09-07-database-mastery-plan.md
```

Days 1 and 2 ship no `break.sh`: their labs measure and build rather than
diagnose, and their starting artifacts (the TOAST-bearing table, the candidate
primary keys, `wide_payments`) are created at seed time. Day 7 ships Terraform
and the Atlas walkthrough in place of `break.sh`. Individual day directories may
carry one or two extra lab-specific files beyond the four standard ones — Day 5's
concurrency harness is the notable case.

---

## Content Day Skeleton

Every `content/dayNN.md` follows this structure:

```markdown
# Day N — <Title>

**Layer:** <storage | logical | access method | planner | concurrency | durability | distribution>
**Budget:** 3 h — <split>

## Why this matters
<One short paragraph, concrete, naming the specific failure this day prevents.>

## Read the instrument first
<The raw catalog view / EXPLAIN output / log line, shown before any tool that
formats it. Annotated field by field, or pointed at the relevant primer.>

## Core concepts
<Body. PostgreSQL first; MySQL and MongoDB introduced at the points where they
genuinely diverge, not for symmetry.>

## Predict before you measure
<2–3 quantities the learner writes a prediction for in journal.md before running
the lab. These are the day's calibration checks.>

## Lab
See `labs/dayNN/`. The goal: <one line>. Success signal: `verify.sh` exits 0.

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. …

## Anti-patterns / common mistakes
<2–3 bullets, each tied to an entry in STRATEGY.md's mistake table.>

## Teardown
<Checklist. For Day 7, leaves zero billable resources.>
```

---

## COVERAGE.md mapping

The path is ordered by architecture rather than by a certification syllabus,
which risks silently dropping a topic a systematic sweep would have caught.
`COVERAGE.md` is the proof that nothing was missed by accident. Every objective
from each source below is either mapped to the day that covers it, or marked
**SKIPPED** with a stated reason. There is no third category.

- MongoDB **C100DBA** (Associate DBA) exam objectives.
- A PostgreSQL DBA competency sweep: installation and configuration, security and
  roles, backup and recovery, vacuum and maintenance, replication and HA,
  monitoring, performance tuning, upgrades.
- MySQL 8 InnoDB operational topics: buffer pool, redo and undo, locking, replication,
  binlog, `performance_schema`.
- Classical relational theory: functional dependencies, 1NF–BCNF, lossless join,
  dependency preservation, the ACID anomaly ladder.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Seeding 10M rows is slow or heavy on the learner's machine | `SCALE` env var; measured target ~15 min and ~6 GB against a verified 24 GB / 135 GB host |
| A lab passes by luck rather than diagnosis | Two independent deliverables per `verify.sh`; per-run generated answers; explicit rejection of known hack fixes |
| Day 7 leaves billable AWS or Atlas resources running | Teardown checklist plus `verify-teardown.sh`; `db.t4g.micro` and M10 chosen as the cheapest tiers that still demonstrate failover and profiling |
| Three engines dilute depth | PostgreSQL is primary throughout; MySQL and MongoDB appear only where they genuinely diverge, never for symmetry |
| Content drifts from the instrument-first law into exposition | The day skeleton mandates "Read the instrument first" before "Core concepts", and "Predict before you measure" before the lab |
| Architecture-first ordering silently drops a topic | `COVERAGE.md`, with no third category between mapped and SKIPPED |
