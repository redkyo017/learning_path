# Database Mastery

An 8-day, 3 h/day path for a senior engineer who touches PostgreSQL, MySQL
and MongoDB every working day, and who reaches into AWS RDS and MongoDB
Atlas to monitor and debug them. The theory underneath that daily work was
learned properly once — years ago, in a course or a book — and has since
settled into habit: the right index gets added, the right isolation level
gets chosen, the right restore drill gets skipped, and the reasoning behind
each of those calls is no longer available on demand. That gap does not
close by re-reading a chapter on MVCC or normal forms; it closes only when
a wrong belief produces a visibly wrong number and you are the one who ran
the query.

This path does not teach database concepts and then demonstrate them. It
teaches every concept through the instrument that measures it — the
catalog, `EXPLAIN (ANALYZE, BUFFERS)`, `pg_stat_user_tables`, MySQL's
`performance_schema` and `mysql.innodb_index_stats`, MongoDB's
`explain("executionStats")` — and it
requires a written, numeric prediction before every measurement. The
distance between what you predicted and what the instrument reports is the
actual curriculum: it is the only mechanism that makes decayed knowledge
visible to the person who owns it. Full reasoning for every design choice
here lives in `STRATEGY.md`; this file is the map and the mechanics.

## Prerequisites

- Docker Desktop, with roughly 6 GB free disk for the image set and the
  seeded dataset, and Docker given at least 4 GB of memory. Day 6 briefly
  needs roughly double Postgres's share of that on top — a full
  `pg_basebackup` plus a scratch restore copy, both written inside the
  `pg` container's writable layer — so provision closer to 9 GB free if
  you don't plan to reclaim disk between days.
- An AWS account and a MongoDB Atlas account, needed for **Day 7 only**.
  Expect **$2–5** in real cloud spend if you tear down the same day — see
  Cost and teardown below before you start that day.

## Bring-up

```bash
cd database_mastery/labs/stack
docker compose -p dbmastery up -d --build
```

Seeding the dataset, resetting the scale, and the fast-reset path are all
covered in `labs/stack/README.md` — read that file before your first lab
rather than guessing at flags here.

## The 8-day map

| Day | Layer | Hours | Lab incident | Content file | Lab dir |
|---|---|---|---|---|---|
| 1 | storage | 3h | Three engines, one row: TOAST out-of-line storage, InnoDB's clustered index, and which candidate primary key fattens every secondary index | `content/day01.md` | `labs/day01/` |
| 2 | logical | 3h | The wide table: reproduce all three anomaly classes in `wide_payments`, then a BCNF decomposition and an unbounded-array MongoDB fix | `content/day02.md` | `labs/day02/` |
| 3 | access method | 3h | The 200× report: `break.sh` drops the indexes that matter and plants three decoys | `content/day03.md` | `labs/day03/` |
| 4 | planner | 3h | The plan flip: corrupted statistics send a well-behaved query into a 1000× row-estimate error | `content/day04.md` | `labs/day04/` |
| 5 | concurrency | 3h | The pileup and the negative balance: a five-session blocking chain, plus a ledger already corrupted by write skew | `content/day05.md` | `labs/day05/` |
| 6 | durability | 3h | Crash and recover: a hard kill mid-write, a point-in-time restore, and an autovacuum retune proven by a before/after bloat measurement | `content/day06.md` | `labs/day06/` |
| 7 | distribution | 3h | The real thing: force an RDS Multi-AZ failover, read Performance Insights, and predict a MongoDB Atlas hot-shard failure before it happens | `content/day07.md` | `labs/day07/` |
| 8 | all | 3h | The gauntlet: five unseen pathologies across all three engines, timed, no hints, then a one-page system design | `content/day08.md` | `labs/day08/` |

## The daily loop

Seven steps, every day. The reasoning for each — why step 3 in particular
carries the whole design — is in `STRATEGY.md` under **The daily loop**.

1. Name the layer — which of the six is today's subject.
2. Read the instrument raw — the catalog view or the `EXPLAIN` JSON, never
   a GUI, first.
3. Predict the number before measuring it, in writing, in `journal.md`.
4. Measure. The gap between the prediction and reality is the lesson.
5. Write the evidence chain before touching a fix.
6. Fix, then re-read the same instrument as proof.
7. Record what you would check first next time.

## How a lab works

```bash
bash labs/dayNN/break.sh        # prints exactly one SYMPTOM line — no diagnosis
# diagnose from the database's own instruments; write the chain in
# journal.md before you touch a fix
bash labs/dayNN/verify.sh       # exits 0 only when the fix AND the diagnosis both check out
```

`verify.sh` reads `/tmp/answer` and checks it against a per-run stashed
value, so passing requires having actually found the cause, not blundering
into a fix that happens to work. `SOLUTION.md` sits in every lab
directory and holds the full chain, not merely the fix — reading it before
your own attempt, or before `verify.sh` forces the question, skips the
lesson the lab exists to teach. Days 1, 2 and 7 ship no `break.sh`: their
labs measure and build against a starting artifact seeded at bring-up
rather than diagnosing an injected pathology.

## Cost and teardown

Day 7 only. The RDS `db.t4g.micro` Multi-AZ instance and the Atlas M10
cluster run **$2–5** if torn down the same day they are created — longer
than that and the estimate no longer holds. Work through Day 7's teardown
checklist, then run:

```bash
bash labs/verify-teardown.sh
```

It fails if any billable resource or snapshot is still alive. Do not
consider Day 7 closed until it passes.
