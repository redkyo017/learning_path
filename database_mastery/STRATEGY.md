# Strategy

This is the reasoning `README.md` and every `content/dayNN.md` point back
to instead of restating. Read it once before Day 1, then return to
individual sections as the days reference them.

## The law

> **No claim about a database counts until you have proved it with a query
> against that database.**

Every concept in this path arrives through the instrument that measures
it, never through a definition read first and checked later. Three worked
illustrations, because the law is easy to nod at and easy to forget under
deadline pressure:

- **MVCC.** You do not learn MVCC by reading that PostgreSQL keeps old row
  versions around. You open two `psql` sessions, read `xmin`, `xmax` and
  `ctid` directly off a row, hold a transaction open in one session, watch
  it pin the vacuum horizon, and watch bloat accumulate in
  `pg_stat_user_tables` while the other session keeps writing. The
  sentence "long transactions cause bloat" was probably already filed
  away in your head; watching the row count in `n_dead_tup` climb while a
  session you opened five minutes ago sits idle is a different kind of
  knowing, and it is the kind that survives an incident.
- **Indexes.** You do not learn indexes by reading that they speed up
  lookups. You read the `Buffers: shared hit=4 read=812` line under a
  sequential scan, add the index, re-run `EXPLAIN (ANALYZE, BUFFERS)`, and
  watch the buffer count collapse by two orders of magnitude under an
  index-only scan — then explain, from the visibility map, why it was
  index-only at all and not a second trip to the heap.
- **Normal forms.** You do not learn 3NF by memorizing that a table should
  have no transitive dependencies. You insert two rows that disagree about
  a merchant's country because the column is duplicated across every
  payment row, watch the aggregate report two different countries for one
  merchant, then decompose the table, re-run the same insert, and watch
  the database itself refuse the corruption you produced moments earlier.

Every day in this path follows that pattern: the anomaly first, produced
by your own hands, then the name for what you watched happen.

## Why this ordering

Days follow a six-layer model of what a database is, because each layer
is only explicable in terms of the one beneath it:

```
storage  →  access method  →  planner  →  concurrency  →  durability  →  distribution
```

A B-tree is a structure imposed on the heap pages Day 1 spends three hours
inside; the planner's cost model is a set of guesses about how many of
those pages an access method will touch; concurrency control is what
keeps two transactions from corrupting the pages the planner already
chose a route through; durability is the guarantee that the pages survive a
crash; distribution is what happens when one machine's pages are no
longer enough. Teaching any layer before the one it depends on produces
exactly the kind of knowledge this path is trying to repair — a name
attached to nothing, ready to decay back into habit the moment the course
ends.

Logical structure — normal forms, keys, constraints, document modelling —
sits at Day 2, between storage and access methods, and that placement is
a deliberate break from the pure layer order above it. The reason is the
law, not an exception to it: proving an anomaly requires reading the
catalog and `EXPLAIN` output to show the anomaly actually happened, so the
instruments have to exist in your hands before Day 2 asks you to use them
against a design question. Day 1 exists to supply those instruments;
everything after Day 1 assumes you have them.

## The daily loop

Seven steps, every day, in this order, without exception. The order is
load-bearing — skipping ahead to step 4 because step 3 feels like an
extra chore is the single most common way to waste this path's time, and
it is why step 3 gets the longest treatment below.

### 1. Name the layer

State, out loud or in the journal header, which of the six layers today's
material belongs to, before opening a single file or running a single
query. This is a five-second step and it is worth taking anyway: it
scopes what kind of explanation you are allowed to reach for. A slow
query on a durability day is not a planner problem no matter how much it
looks like one, and naming the layer first stops you from reaching for
yesterday's tool out of habit.

### 2. Read the instrument raw

Query `pg_class` before you open pgAdmin; read `EXPLAIN (FORMAT JSON)`
before you paste it into a plan visualizer; read `db.collection.explain()`
before Compass renders it. The raw form has every field the friendly
version summarizes or drops, and reading it first is what lets you
recognize, later, when a GUI's summary is quietly wrong or stale. A tool
you have never seen the raw output behind is a tool you cannot audit.

### 3. Predict the number before measuring it, in writing

This is the step to predict before you measure — the one the whole path
is built around, and it is the one most likely to feel optional. It is
not optional.

A learner whose theory has decayed into habit cannot detect the decay by
introspection — there is no felt difference between "I know this cold"
and "I know this well enough that I have not been wrong yet." Confidence
is not calibration, and years of the right query usually working produces
exactly the kind of unearned confidence that introspection cannot see
through, because introspection is the faculty that decayed along with the
knowledge it was supposed to monitor. You cannot audit your own beliefs
about `work_mem` by thinking harder about `work_mem`.

A written prediction is the only tool that gets around this. Before you
run the query, before you look at `EXPLAIN`, before you check
`pg_stat_user_indexes`, you write down a number: how many buffers this
scan will touch, how many milliseconds the query will take, how many
megabytes that secondary index will occupy, how long the failover window
will be. Then you measure, and you compare. When the two numbers agree,
that is real evidence your mental model is accurate, and you should
trust it more, not less, than a mental model that has never once been
tested. When they disagree — and on this path, in the early days, they
disagree by orders of magnitude, not by rounding error — the size of the
miss is data about exactly where your model is wrong, in a way that no
amount of rereading the concept could have surfaced. A prediction that
misses a buffer count by 400× does not mean you are bad at this; it means
you were confidently carrying a wrong number about how a page cache
behaves, and now you know which number, and you know it because you
produced the miss yourself under conditions you cannot argue with. That
is the entire mechanism. Every other step in this loop exists to set up
this one or to act on what it reveals.

Treat every prediction as a real commitment, not a formality to clear
before the interesting part starts. Write down your reasoning in one
sentence alongside the number — "I expect an index-only scan because the
query only touches indexed columns" — so that when the measurement
disagrees, you have the belief in front of you, not only the wrong
number.

### 4. Measure

Run the query, read the instrument, record the actual value next to your
prediction. Do the comparison immediately, while the prediction is still
in your head, not at the end of the session. The gap you compute here is
the thing this path is teaching; everything from step 5 onward is what
you do in response to it.

### 5. Write the evidence chain before touching a fix

Before you change anything, write the numbered chain of claims and proofs
that gets you from the symptom to a diagnosis — the `journal.md` template
below is the exact shape. Fixing first and explaining afterward launders
a guess into something that looks like a diagnosis after the fact, and it
is indistinguishable, from the outside, from actually having understood
the problem. It is also indistinguishable from the inside, which is the
dangerous part: a fix that happens to work teaches you that the fix
works, not why the system was broken, and the next incident that looks
similar but is not will get the same fix, incorrectly, with the same
false confidence.

### 6. Fix, then re-read the same instrument as proof

Apply the fix, then go back to the exact instrument you used in step 2 —
not a different one, not a summary of it — and confirm the number moved
the way your diagnosis predicted it would. Proof and diagnosis sharing
one instrument is what closes the loop: it is what stops "the query got
faster" from being accepted as proof of "I fixed the thing I diagnosed,"
which are not the same claim.

### 7. Record what you would check first next time

One or two sentences in the journal entry, written while the incident is
still fresh: what is the fastest path to this diagnosis next time,
skipping the false leads this time cost you. This is the step that turns
eight isolated incidents into a runbook, and it is the material Day 8's
gauntlet and system-design work draws on directly.

## The 12 mistakes that waste most of a learner's time

| # | Mistake | Corrective drill | Day |
|---|---|---|---|
| 1 | Reading `EXPLAIN` without `ANALYZE, BUFFERS`, and never comparing estimated to actual rows | Every plan is read estimate-first; the divergence is named before the fix | 3, 4 |
| 2 | Adding indexes by guessing, and never removing them | Measure `pg_stat_user_indexes`; find and drop the decoys `break.sh` planted | 3 |
| 3 | Tuning configuration knobs before fixing queries | Config day comes after index and planner days, by design | 6 |
| 4 | Learning isolation levels from a table in a book | Every anomaly is reproduced live in two racing sessions | 5 |
| 5 | Memorising normal-form definitions instead of reproducing the anomaly | Insert the update/insert/delete anomaly, watch it corrupt, then normalise | 2 |
| 6 | Treating MongoDB as schemaless | Document modelling gets the same anomaly treatment as relational | 2, 7 |
| 7 | Benchmarking on uniformly distributed data | The seeded dataset is power-law skewed on purpose | all |
| 8 | Never running a restore drill — testing the backup, not the restore | PITR to a known pre-damage value, verified | 6 |
| 9 | Blaming the database for what is an N+1 or a missing bound | Query-shape pathologies sit alongside engine pathologies in the gauntlet | 4, 8 |
| 10 | Fixing the symptom that is loudest rather than the session that is root | Lock pileups are diagnosed to the root blocker, not the longest waiter | 5 |
| 11 | Choosing a shard key by cardinality alone | Shard-key selection drills frequency and monotonicity too, then predicts the failure | 7 |
| 12 | Trusting a dashboard over the catalog | Step 2 of the daily loop forbids the GUI first | all |

**1. Reading `EXPLAIN` without `ANALYZE, BUFFERS`, and never comparing
estimated to actual rows.** The plain form of `EXPLAIN` returns instantly
and looks complete — it has costs, it has row counts, it has node types —
so it is tempting to treat it as the whole picture and move on. It never
runs the query, which means every number on it is the planner's guess
about itself, and a guess that agrees with your intuition feels like
confirmation rather than the untested claim it is. The row-estimate
column only becomes diagnostic once you have the actual row count next to
it, and fetching that costs one keyword.

**2. Adding indexes by guessing, and never removing them.** An index
that speeds up the one query you were staring at feels like a clean win
with no visible downside, because the cost — slower writes, more WAL,
more planner choices to get wrong, more maintenance overhead — is diffuse
and shows up somewhere else, later, attributed to something else. Nothing
in a default workflow ever tells you an index has gone unused; `pg_stat_
user_indexes` has to be asked, and by default nobody asks it.

**3. Tuning configuration knobs before fixing queries.** A `postgresql.
conf` change feels like leverage — one edit, every query on the instance
potentially faster — against a query fix that only helps the one query
you rewrote. That asymmetry is real and it is also backwards: a bad
query plan wastes work no configuration setting can buy back, and a
config change tuned around a bad plan bakes the mistake into the
instance instead of removing it. Config day is scheduled after two full
days of query and planner work specifically so the knob-turning instinct
arrives last, once it has something real left to fix.

**4. Learning isolation levels from a table in a book.** The
dirty-read/non-repeatable-read/phantom table is genuinely well organized,
which makes it feel like understanding once you can recite it — but the
table describes what each anomaly looks like from outside, not the
interleaving of two sessions that produces it, and recognizing the name
of an anomaly you have never watched happen is not the same skill as
noticing you are inside one. Write skew in particular is nearly
impossible to internalize from a definition; it has to be raced.

**5. Memorising normal-form definitions instead of reproducing the
anomaly.** "No transitive dependency on the primary key" is precise and
completely unmemorable a week later, because it was never attached to a
consequence. The definitions are compact enough to seem masterable in an
afternoon, which is exactly what makes them the kind of knowledge that
decays into "I know normalization" without any of it being retrievable
under a real schema-design question.

**6. Treating MongoDB as schemaless.** "Schemaless" is the marketing
word and it describes the absence of an enforced schema at write time,
not the absence of a schema — every query still assumes a shape, and a
document store without normal-form thinking behind it accumulates the
exact same update anomalies a relational table would, only without a
constraint system available to catch them at write time. The absence of
enforcement reads as freedom right up until two documents disagree about
a fact that was denormalized into both of them.

**7. Benchmarking on uniformly distributed data.** Synthetic data
generators default to uniform distributions because they are the easiest
to write and the fastest to reason about, and a tuning exercise run
against uniform data will produce a clean, plausible-looking result — it
will not, however, be the result production gives you, because production
traffic and production entities are never uniform. This dataset is
skewed power-law on merchant activity specifically so this mistake is
structurally unavailable here: there is no uniform version of it to fall
back to.

**8. Never running a restore drill — testing the backup, not the
restore.** A backup job that completes with no error is reassuring, and
"reassuring" gets mistaken for "verified" because checking the job's exit
code is nearly free and running an actual restore is not. The exit code
proves the write succeeded; it says nothing about whether the archive is
readable, whether the WAL chain is intact, or whether anyone remembers
the recovery procedure under pressure — and all three of those routinely
fail even when every backup job for months has reported success.

**9. Blaming the database for what is an N+1 or a missing bound.** A
slow endpoint with a database on the other end invites database-shaped
explanations first, because that is where the slow query log points and
because "the database is slow" is a smaller admission than "the
application issued eight hundred round trips." The engine will
faithfully execute each of those round trips fast and still produce an
endpoint that times out, and no index or config change fixes a query
count problem.

**10. Fixing the symptom that is loudest rather than the session that is
root.** In a blocking chain, the session that has been waiting longest is
the one that shows up first in every monitoring view, and killing it
feels like decisive action — but it is usually a victim, not a cause,
and killing it only promotes the next-longest waiter to the top of the
list while the actual root blocker keeps holding its lock. The root is
found by walking the wait graph, not by sorting on wait time.

**11. Choosing a shard key by cardinality alone.** High cardinality is
the one property every shard-key tutorial leads with, because it is easy
to state and easy to check with a single `distinct` count — and it is a
necessary property, not a sufficient one. A monotonically increasing
high-cardinality key routes every new write to the same shard regardless
of how many distinct values exist in total, which is a frequency and
monotonicity failure that a cardinality check alone will never surface.

**12. Trusting a dashboard over the catalog.** A dashboard is faster to
read, prettier, and usually right, which is precisely what makes it
dangerous the one time it is stale, misconfigured, or built on a metric
that means something subtly different from what its label claims. The
catalog underneath is always current and always exactly what the engine
believes, and step 2 of the daily loop exists to build the reflex of
checking it first, before the GUI has a chance to become the thing you
trust by default.

## What this path is not

- **Not a certification cram.** No section here is organized around an
  exam's objective list, and no lab exists because a syllabus item needed
  covering. `COVERAGE.md` maps this path's architecture-first ordering
  onto the relevant certification and competency objectives afterward, as
  an audit, not as the spine.
- **Not a benchmark tutorial.** `pgbench` and `sysbench` appear exactly
  once, on Day 6, where the point of the day is measuring a configuration
  change's effect under load. Most of this path's clock goes to reasoning
  about a single query or a single incident, not to running throughput
  numbers.
- **Not engine-agnostic hand-waving.** PostgreSQL, MySQL and MongoDB are
  treated as three implementations of one architecture, and the path says
  so explicitly wherever a lesson genuinely transfers — but a
  page that describes "how relational databases work" in the abstract,
  illustrated with whichever engine happens to be handy, teaches nothing
  that survives contact with InnoDB's clustered index or WiredTiger's
  document model actually diverging from that abstraction. Every
  divergence is named as a divergence, not smoothed over.

## Approaches rejected

**Failure-first inversion.** Order the whole path by the twelve canonical
production incidents and derive theory backwards from each one. This is
the stickiest possible format for the incidents it covers, and it is
adopted here as the *lab format* — every diagnostic day is exactly this.
Adopted as the path's overall ordering, though, it produces lumpy
coverage: loud, memorable failures get deep treatment while schema
design, normal forms and capacity planning barely appear, because they do
not fail loudly enough to generate an incident of their own.

**Pure unified-model spine.** Teach the six layers straight through, all
three engines side by side at every layer, with labs used purely as
illustration of material already presented. This is the strongest
framing for articulating system design and for seeing the three engines
as one architecture — and it is also the most academic of the options
considered, and academic is precisely the mode that already produced the
decay this path is repairing. Adopted as the *ordering* — the six layers,
in dependency order — but not as the method: every layer still arrives
through an instrument and an anomaly first, never through exposition
alone.

**Benchmark-driven.** Measure the effect of every knob change and every
schema decision with `pgbench` or `sysbench`, on the theory that a real
throughput number beats an argued one every time. It is rigorous, and it
is also slow: most of the available time goes to running and waiting on
benchmarks rather than reasoning about what the plan or the lock graph or
the catalog is telling you, which is the actual skill under
construction. Retained only where a benchmark is the point — Day 6's
configuration work — and rejected as the default evidentiary standard
everywhere else, where a single well-chosen measurement makes the same
case in a tenth of the time.
