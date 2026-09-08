# Day 8 — The gauntlet, and system design

**Layer:** all
**Budget:** 3 h — 1.5 h gauntlet, 1.5 h design

## Why this matters

The seven days behind this one each opened with a layer name in the
title. That label did real work you may not have noticed: it told you,
before you read a single line of output, which instrument to reach for
and which of the twelve mistakes in `STRATEGY.md` was probably in play.
A production incident does not open with a title. It opens with a
symptom — a slow endpoint, a stuck deploy, a support ticket — and the
first, most consequential decision is not which fix to apply but which
*layer* the symptom actually lives in, made before you've opened a
single instrument. Get that wrong and you spend the incident's first
twenty minutes running the right query against the wrong theory. This
day removes the layer label on purpose, five times over, under a loose
time budget, because that is the only way to find out whether the habit
this path spent seven days building actually transferred, or whether it
was seven separate tricks wearing seven separate name tags.

The second half asks a different but related question: can you turn the
diagnostic habit around and use it to size and shape something that
doesn't exist yet. Capacity planning done by gut feel and schema
decisions made by whichever engine's name you last saw on a job posting
both fail the same way bad diagnosis does — quietly, until the gap
between the guess and the measurement becomes somebody's incident.

## Read the instrument first

Nothing below names a layer. This is what the gauntlet hands you —
five lines, printed together, in this order, with a start timestamp
recorded and nothing else:

```
$ bash labs/day08/gauntlet.sh
Resetting Day 8 baseline (idempotent) before rolling a fresh five...
Applying 5 of 8 pathologies...

Five incidents are live. Nothing above named a layer or an engine on
purpose -- that's the whole exercise. Diagnose each from its own
instruments, write the evidence chain in journal.md before touching a
fix, and write all five key=value answers into /tmp/answer inside ws
before running verify.sh. See README.md for the exact key names.

SYMPTOM: 1) a customer's recent-payments lookup, used by the support desk dozens of times an hour, takes several seconds per call.
SYMPTOM: 2) three application connections to the payments database have been stuck for several minutes; the newest one reports waiting on a lock, and it is not the one that's been waiting longest.
SYMPTOM: 3) a support tool that searches recent event records for anything matching the word "charge" takes several seconds per search, and the search gets slower every month as the event log grows.
SYMPTOM: 4) the disputes table is small and has very little old data sitting in it, but a query that filters on its status column has gotten steadily slower for weeks.
SYMPTOM: 5) a merchant capture-summary batch job for one merchant takes about 40 seconds end to end, even though every individual query in its trace completes in under 5 milliseconds.
```

Five symptoms, three engines represented, six possible layers, and not
one word above tells you which is which. Symptom 2 *sounds* like
concurrency and is — but symptom 4 sounds like storage and is also,
technically, storage, while symptom 5 sounds like the planner and is
actually a query-shape problem no `EXPLAIN` on any single query will
ever surface (Mistake 9). Naming the layer for each of these, before
opening an instrument, is the graded skill — not a warm-up before it.

## Core concepts

**The diagnostic habit, named explicitly, one more time.** Every
pathology in the gauntlet's pool of eight is a reshaped version of a
technique from Days 3-6: a new query shape needing a composite index, a
stale-statistics flip on an unfamiliar join, a lock chain rooted in a
session that isn't the longest waiter, autovacuum starved by a
transaction rather than a disabled setting, an unanchored MongoDB
`$regex`, an InnoDB deadlock from inconsistent lock order, a bloated
index sitting on a clean table, and an N+1 visible only in aggregate.
None of the eight is a new *kind* of failure — every one of them was
fully taught by an earlier day. What's new is that you don't know which
one you're looking at until you've looked. Layer-naming happens by
elimination in practice: read `pg_stat_activity` first when a symptom
mentions "stuck" or "waiting" regardless of which table it names; read
`EXPLAIN (ANALYZE, BUFFERS)` first when it mentions "slow" and one query
you can point to; read `pg_stat_statements` first when it mentions
"slow" but every query you can point to, individually, is fast — that
last tell is the entire signature of an N+1, and it's the reason Mistake
9 gets its own row in `STRATEGY.md`'s table instead of folding into
Mistake 1.

**From here on, the design half.** Everything below is arithmetic and
trade-off reasoning, not instrument-reading — a genuinely different kind
of work from the first seven days, and the reason this day's budget
splits down the middle instead of running the usual read-predict-measure
loop a sixth time.

**Capacity arithmetic, done explicitly.** "How much storage will this
need" and "how many IOPS" are questions with numeric answers, not
vibes, and the arithmetic is short enough that skipping it is a choice,
not a time-saver. The shape, worked once so the pattern transfers:

1. **Rows per day** from the stated write volume.
2. **Bytes per row**, including the columns that vary in size — this
   schema's `payments.description` TOASTs for roughly 1 row in 20 at
   over 2 KB; averaging that in, not ignoring it, is the difference
   between a believable estimate and a fictional one.
3. **Index overhead** — every secondary index adds its own per-row
   footprint, roughly proportional to its key width, paid on every
   insert, not only on read.
4. **Rows × (bytes/row + index overhead)**, projected across the
   **retention window**, not only "today's volume" — a 7-year regulatory
   retention obligation against 40% YoY growth means the bulk of the
   stored bytes, by the end of the window, come from the *later* years'
   volume, not the earlier ones; sum the growth curve across the whole
   window, don't multiply today's rate by the window length.
5. **IOPS from the access pattern**, not from the row count: a write
   path with N inserts-per-transaction and a stated peak-over-average
   multiplier gives peak write IOPS directly; a read path's IOPS depends
   on whether it's answered index-only (roughly 1 IOP/row) or requires a
   heap fetch (2+).
6. **Connections from the concurrency**, via Little's Law — concurrent
   in-flight requests ≈ request rate × average hold time — not asserted
   from a round number. The result is almost always larger than a sane
   `max_connections`, which is the argument for connection pooling
   (PgBouncer in transaction mode, or the equivalent), not a sign the
   arithmetic is wrong.

`DESIGN-BRIEF.md` and `REFERENCE-DESIGN.md` work this exact sequence
against one concrete brief — read the reference only after running the
arithmetic yourself.

**PostgreSQL is the right default. Say what actually changes that.**
An engine-choice rubric that scores every engine well on "consistency"
and "scalability" and lets the reader pick their favorite teaches
nothing — it flatters whichever engine the reader already wanted. Say
it plainly instead: for the overwhelming majority of transactional
workloads — anything with related entities, invariants that span rows,
and a need for ad hoc query flexibility as the product evolves —
PostgreSQL is the right starting point, and the interesting engineering
question is never "which database is best" in the abstract, it's "what
*specifically* about this workload would make PostgreSQL the wrong
choice." Concrete answers, not hedges:

- A write pattern that is *genuinely* schemaless and highly variable
  per record, with no cross-record invariant to enforce (a document
  store's actual strength, not "we don't want to write migrations") —
  `merchant_catalog`'s per-merchant `products` array is closer to this
  than `payments` ever will be, which is exactly why Day 2 restructures
  it in MongoDB and never proposes moving `payments` there.
- A write volume that exceeds what vertical scaling and read replicas
  can carry even with aggressive partitioning, and where the access
  pattern has an obvious, stable partition key with no cross-partition
  transactions — the actual case for horizontal sharding, not "we might
  get big someday."
- A workload that is overwhelmingly key-value lookups with no relational
  structure at all and extreme latency sensitivity at massive scale — the
  case for a dedicated key-value store as a cache or a narrow lookup
  table sitting *next to* the system of record, not replacing it.

None of these describe a typical payments platform's core ledger and
payment path. `payments`/`ledger_entries`/`accounts` have exactly the
properties — cross-row invariants, ad hoc reporting, moderate-not-extreme
scale — that argue for PostgreSQL specifically, and `REFERENCE-DESIGN.md`
says so instead of hedging.

**Read and write path design; caching, and what it costs.**
Cache-aside — check the cache, fall through to the database on a miss,
write the result back into the cache with a TTL — is the right default
specifically because it fails predictably: a cache outage degrades to
"the database handles full load," not to serving stale or wrong data
silently, and a TTL bounds the staleness window to a number you chose,
rather than to "however long until something remembers to invalidate
it." The cost is exactly that staleness window, and it is a real cost —
a customer who recently captured a payment and immediately reloads their
payment history can see the cached, pre-write version until the TTL (or
an explicit invalidation on write) catches up. Cache *before* you've
measured that the database access path is actually the bottleneck is an
anti-pattern for a specific reason: a cache in front of a query that was
never slow adds an invalidation problem and a staleness window in
exchange for nothing, and the query that actually needed the cache is
still slow, now hidden behind a cache-hit rate that looks healthy in
aggregate while the cache-miss path — the one that still matters — never
got fixed.

**Idempotency keys.** A payment API that can be retried — by a flaky
client, an ambiguous timeout, a load balancer's own retry policy — needs
a way to tell "this is the same request, sent twice" from "this is a
second, distinct charge," because the two must never produce the same
number of ledger entries. The standard mechanism: the client generates a
unique idempotency key per logical operation (not per HTTP attempt) and
sends it as a header; the server looks the key up in a dedicated table
(`idempotency_key`, `request_hash`, `response_body`, `status`,
`created_at`) inside the **same transaction** as the payment write,
before doing any work. A first sighting proceeds and stores its result
under that key; a repeat sighting returns the stored result without
re-executing anything. `request_hash` guards against the same key
being replayed against a *different* request body — a client bug, not a
legitimate retry — which should be rejected, not silently served the
old result. The key table needs its own retention/expiry (a request
retried a year later is not the same operation any reasonable system
should still be honoring) and a unique constraint on the key column,
which is what actually makes a race between two concurrent retries safe:
the loser of the `INSERT` gets a constraint violation, not a second
charge.

**The transactional outbox.** A payment write frequently needs to *also*
notify something else — a webhook, a fraud-scoring queue, an analytics
pipeline — and writing to the database and publishing to a queue are two
separate systems with no shared transaction. Doing both and hoping is a
**dual write**, and it fails exactly when it matters most: the database
commit succeeds and the queue publish fails (the event is lost), or the
publish succeeds and the database transaction then rolls back (a message
goes out for a payment that never actually happened). Neither ordering
is safe, and there is no way to make two independent systems commit
atomically without a coordinator. The outbox pattern sidesteps the
problem instead of solving it: write the event as a row in an
`outbox_events` table, in the **same transaction** as the payment write
itself — now it's one database, one transaction, genuinely atomic — and
have a separate, independent process (a polling job or a change-data-
capture stream reading the table's WAL) pick up unpublished rows and
publish them to the queue, marking them published only after the queue
acknowledges. The queue message can now arrive more than once (the
publisher might publish and then fail to mark the row published, and
retry) — which is why the consumer on the other end needs its own
idempotency handling, the same discipline as above, one layer further
out.

**Zero-downtime schema migration: expand and contract.** A single `ALTER
TABLE payments ADD COLUMN risk_score NUMERIC(5,2) NOT NULL DEFAULT 0;`
is not actually the full-table-rewrite hazard it looks like — since
PostgreSQL 11, adding a column with a non-volatile constant default is
**metadata-only**, via the same `atthasmissing`/missing-value mechanism
phase 1 below relies on for the nullable case: no rewrite, no scan, a
lock held only long enough to update the catalog. Reaching for six
phases anyway is justified by two different problems a single statement
does not solve. First, a schema change and an application deploy can
never land perfectly atomically, and a placeholder default makes
whichever one lands first silently wrong: run the single `ALTER` before
the fraud-scoring code deploys and every payment written in between gets
a permanent `risk_score` of `0` — indistinguishable from a real score,
with no error and no signal that it's wrong — while deploying the
scoring code first fails outright, referencing a column that doesn't
exist yet. A nullable column lets "not yet scored" be represented
honestly as `NULL`, distinguishable from a real score, for exactly as
long as the rollout takes. Second, once a nullable column already has
live rows sitting at `NULL`, promoting it to `NOT NULL` genuinely does
require a full-table scan to confirm none remain — unless, as phases 4
and 5 set up, an already-validated `CHECK` constraint lets PostgreSQL
12+ skip that scan when `SET NOT NULL` finally runs. (The friendlier
metadata-only case for phase 1 itself also stops applying the moment a
column's default is volatile — `now()`, a sequence, a random value —
rather than a constant; the sequence below doesn't assume the easy case
holds.) Six phases, concretely, for a ten-million-row `payments`-shaped
table adding `risk_score NUMERIC(5,2) NOT NULL DEFAULT 0`:

1. **Expand, nullable, no rewrite.** `ALTER TABLE payments ADD COLUMN
   risk_score NUMERIC(5,2);` — nullable, no default. On PostgreSQL 11+,
   adding a nullable column with no default is a metadata-only change:
   no table rewrite, a brief `ACCESS EXCLUSIVE` lock held only long
   enough to update the catalog, not proportional to the table's size.
2. **Deploy dual-write application code.** Ship the version of the
   application that writes `risk_score` on every *new* row, while still
   treating `NULL` as a valid "not yet scored" value on read. Old rows
   are untouched; the column is optional from the schema's point of
   view for exactly as long as this phase lasts.
3. **Backfill in batches.** `UPDATE payments SET risk_score = 0 WHERE
   risk_score IS NULL AND payment_id BETWEEN :lo AND :hi;`, looped over
   bounded ranges with a short pause between batches — never one
   unbounded `UPDATE` over ten million rows, which would hold row locks
   and generate WAL/replication load proportional to the whole table at
   once. Batch size and pause length are tuned against replica lag and
   lock-wait metrics observed live, not fixed in advance.
4. **Add the constraint, unvalidated.** `ALTER TABLE payments ADD
   CONSTRAINT risk_score_not_null CHECK (risk_score IS NOT NULL) NOT
   VALID;` — takes effect immediately for all *new* writes (an insert or
   update violating it fails right away) but does not scan existing
   rows, so it doesn't block on the backfill from phase 3 still running
   in a nearby transaction.
5. **Validate.** `ALTER TABLE payments VALIDATE CONSTRAINT
   risk_score_not_null;` — now that phase 3 guarantees no live `NULL`
   remains, this scans the table to confirm it, but takes only a `SHARE
   UPDATE EXCLUSIVE` lock, which coexists with ordinary reads and writes;
   it blocks only other DDL, not application traffic.
6. **Contract: promote and clean up.** `ALTER TABLE payments ALTER
   COLUMN risk_score SET NOT NULL;` — on PostgreSQL 12+, the planner can
   use the already-validated `CHECK` constraint from phase 5 to skip the
   full-table re-scan a plain `SET NOT NULL` would otherwise require,
   making this step fast regardless of table size. Drop the now-redundant
   `CHECK` constraint afterward if you want one less object to reason
   about; the column-level `NOT NULL` supersedes it.

A rollback plan whose only step is "restore from backup" is not a
rollback plan for this sequence — it throws away every write since the
backup to undo a schema change that, done as above, never needed
downtime to begin with. The actual rollback at any phase before 6 is
the mirror operation (drop the constraint, stop the backfill, revert the
application deploy); only phase 6 needs any thought at all, and even
there, dropping a `NOT NULL` is instant.

**Multi-tenancy: shared table, schema-per-tenant, database-per-tenant —
at three scales, concretely.** The three options trade isolation for
operational cost in opposite directions, and which one wins depends on
tenant count in a way that is not linear — the right answer at 100
tenants is frequently the wrong one at 10,000, not because principles
changed but because a cost that was negligible crossed a threshold.

- **At ~100 tenants:** schema-per-tenant is genuinely comfortable here —
  one PostgreSQL instance, one schema per tenant, real logical isolation
  (a tenant's own migration mistake can't corrupt another tenant's data),
  and a single tenant can be dumped, restored, or moved independently.
  Database-per-tenant is also possible but starts paying a real
  connection-pool tax even at this scale (100 separate pools, or one pool
  per tenant multiplexed, versus one pool total) for isolation benefits
  schema-per-tenant already delivers more cheaply. Shared table with a
  `tenant_id` column is the simplest of the three operationally — one
  migration path, period — at the cost of relying on application-level
  (or row-level security) scoping to prevent a cross-tenant data leak,
  which at 100 tenants is a manageable amount of code to get right and
  keep right.
- **At ~1,000 tenants:** schema-per-tenant starts to strain PostgreSQL's
  catalog — thousands of schemas, each with its own copy of every table
  and index, multiply into tens of thousands of relations that
  `pg_dump`, `autovacuum`'s per-relation bookkeeping, and every new
  connection's catalog cache warm-up all have to account for. It still
  *works*, but the operational drag is now visible, not theoretical.
  Database-per-tenant is disqualified on cost alone at this scale for
  any team without dedicated database-operations headcount — 1,000
  independent migration runs for one schema change is not a six-engineer
  team's job to babysit. Shared table with `tenant_id` becomes the
  pragmatic default here: one migration path stays true regardless of
  tenant count, a leading `tenant_id` column in every relevant composite
  index keeps per-tenant queries efficient, and row-level security
  enforces isolation at the query layer instead of the schema layer.
- **At ~10,000 tenants:** schema-per-tenant is disqualified outright —
  the catalog bloat that was merely visible at 1,000 tenants is now an
  operational hazard, and a single global schema change means tens of
  thousands of individual DDL operations. Database-per-tenant was
  already disqualified. Shared table with `tenant_id` remains the only
  workable base — but the power-law skew this path's own seed data is
  built around (a small fraction of merchants own a large fraction of
  rows) becomes the dominant tuning problem at this scale, not tenant
  count itself: a handful of the largest tenants can generate enough
  write and vacuum load to degrade the shared table for every other
  tenant sharing it. The mitigation is a hybrid, not a fourth option —
  partition the shared table by (or hash on) `tenant_id` so a runaway
  tenant's rows, bloat, and vacuum work are physically confined to its
  own partition without paying schema-per-tenant's catalog cost, and
  consider a dedicated physical shard or read replica specifically for
  the handful of largest tenants, while the long tail of small tenants
  stays on the shared, partitioned base.

## Predict before you measure

Before running `gauntlet.sh`, write down, per `STRATEGY.md`'s daily loop
step 3:

1. For each of the five `SYMPTOM` lines you're handed, your best guess
   at which of the six layers it belongs to, and the one word or phrase
   in the symptom text that drove the guess. Check your guesses only
   after you've diagnosed all five — not one at a time, which would let
   an early correct guess anchor the rest.
2. Before running the design brief's arithmetic, a rough order-of-
   magnitude guess for the total storage footprint at the end of the
   7-year retention window, and for the peak connection count. Then run
   the actual arithmetic in `REFERENCE-DESIGN.md`'s shape and compare —
   a guess that's off by an order of magnitude here is exactly the kind
   of miss `STRATEGY.md`'s step 3 exists to surface, on a design question
   instead of a measurement.

## Lab

```bash
bash labs/day08/gauntlet.sh
```

Five incidents, no layer named, a 90-minute soft target. Write the
evidence chain for each in `journal.md` before touching a fix — the
discipline from Day 1 onward, now under time pressure, which is the only
way to find out whether it survives contact with a clock instead of
merely with a quiet afternoon. See `labs/day08/README.md` for the exact
answer-key format (it depends on which five of the eight pool members you
drew) and `labs/day08/ANSWERS.md` for all eight pathologies' compressed
evidence chains, ordered by pathology since the selection is random.

```bash
bash labs/day08/verify.sh
```

scores the five you got, independently — full credit requires both the
fix and the diagnosis, for every one of the five.

Then the design half: read `labs/day08/DESIGN-BRIEF.md`, do the
arithmetic and the design work yourself, grade your own draft against
`labs/day08/DESIGN-RUBRIC.md`, and only then read
`labs/day08/REFERENCE-DESIGN.md` — explicitly one defensible design, not
the design.

## Exercises

Design-side only — the gauntlet above already supplied this day's
diagnostic practice.

1. Ledgerly (the `DESIGN-BRIEF.md` scenario) processes 12,000,000
   payments/day today, growing 40% year-over-year, with a 7-year
   retention obligation. Size the storage footprint at the end of the
   retention window and the peak write IOPS, showing your arithmetic at
   every step named in Core concepts (rows/day → bytes/row → index
   overhead → growth-projected total; access pattern → IOPS).
   **Hint:** the growth curve means most of the 7-year total comes from
   the *later* years, not the earlier ones — sum each year's volume at
   its own year's growth-adjusted rate, don't multiply today's rate by
   seven.
   **Solution sketch:** `REFERENCE-DESIGN.md`'s capacity section works
   this exact arithmetic end to end, including the assumptions it makes
   about average row width and index count — check your own assumptions
   against its stated ones before comparing final numbers, since two
   reasonable but different width assumptions produce different totals
   without either being wrong.

2. Write the six-phase expand/contract sequence for adding
   `risk_score NUMERIC(5,2) NOT NULL DEFAULT 0` to a ten-million-row
   `payments` table with live write traffic, with the exact SQL for each
   phase and the lock behavior it implies.
   **Hint:** a naive single `ALTER TABLE ... ADD COLUMN risk_score
   NUMERIC(5,2) NOT NULL DEFAULT 0;` is metadata-only on PostgreSQL 11+
   (a constant default doesn't force a rewrite) — the problem it doesn't
   solve is deployment ordering: whichever of the schema change and the
   scoring-code deploy lands first either writes a silent, permanent
   placeholder value or fails outright against a column that doesn't
   exist yet. Solve that, and solve what a bare `SET NOT NULL` costs on
   a column that already has live `NULL`s in it.
   **Solution sketch:** Core concepts' six-phase sequence above, applied
   verbatim: add nullable (phase 1), dual-write deploy (phase 2), batched
   backfill (phase 3), `CHECK ... NOT VALID` (phase 4), `VALIDATE
   CONSTRAINT` (phase 5), `SET NOT NULL` plus cleanup (phase 6).

3. Ledgerly's tenant count is contracted to hit 3,000 within a year and
   roughly 20,000 within three. Choose a multi-tenancy model for *today*
   (300 tenants) and defend it against the specific numbers in the
   brief, not against multi-tenancy in the abstract.
   **Hint:** the model that's most comfortable at today's scale is not
   necessarily the one that survives the contracted growth without a
   re-platforming project — factor in the migration *away* from your
   choice, not only its cost today.
   **Solution sketch:** shared table with `tenant_id`, chosen even at
   300 tenants (where schema-per-tenant would also be comfortable),
   specifically because the brief's own three-year trajectory ends at
   10,000+ tenants, where schema-per-tenant is disqualified outright —
   picking the model that's merely adequate today but that scales
   without a rewrite beats picking the model that's more comfortable
   today but forces a migration in two years. See Core concepts'
   three-scale breakdown for the full reasoning at each point on that
   trajectory.

4. Design the idempotency mechanism for Ledgerly's `POST /payments`
   endpoint, which must be safely retryable by a client that timed out
   without knowing whether its request succeeded.
   **Hint:** the mechanism has to handle three distinct cases correctly:
   a genuine first attempt, a retry of the exact same request, and a
   buggy client replaying the same idempotency key against a *different*
   request body — name what happens in each of the three, not only the
   happy path.
   **Solution sketch:** an `idempotency_keys` table
   (`key`, `request_hash`, `response_body`, `status`, `created_at`) with
   a `UNIQUE` constraint on `key`, checked and written inside the same
   transaction as the payment write itself. First sighting: insert the
   key, proceed, store the result. Exact retry (same key, same
   `request_hash`): return the stored result, do no work. Replayed key,
   different `request_hash`: reject with a conflict error — this is a
   client bug, not a legitimate retry, and silently honoring it would
   silently drop the second, different request the client actually
   intended to make. The `UNIQUE` constraint on `key` is what makes two
   concurrent retries of the same request race-safe: the loser of the
   `INSERT` gets a constraint violation instead of a second charge.

## Anti-patterns / common mistakes

- **Choosing an engine for a résumé line instead of an access pattern.**
  "We should use MongoDB because it scales" or "we should use Postgres
  because everyone knows SQL" are both the same mistake wearing different
  clothes: neither sentence names a property of the actual workload. The
  question that survives contact with a real incident is always "what,
  specifically, about this access pattern does this engine handle better
  than the default," and if the honest answer is "nothing in particular,"
  the engine choice was a preference, not a design decision.
- **Caching before measuring.** A cache in front of a query that was
  never measured to be slow adds an invalidation problem and a
  staleness window in exchange for nothing — and the query that actually
  needed help is still slow, now hidden behind a healthy-looking
  aggregate cache-hit rate.
- **A migration rollback plan whose only step is "restore from
  backup."** For the expand/contract sequence in Core concepts, every
  phase before the last has a cheap, targeted mirror operation; reaching
  for a full restore to undo one `ALTER TABLE` throws away every write
  since the backup was taken to fix a problem that a five-second `DROP
  CONSTRAINT` would have solved.

## Teardown

See `labs/day08/teardown.md`.
