# Day 8 lab — the gauntlet

## What this is

`gauntlet.sh` holds a pool of eight pathologies, each a reshaped version
of a technique from Days 3-6 — never a verbatim repeat of the query, the
join, the session, or the table you saw before. Every run selects **five
of the eight at random**, applies them all at once, and prints exactly
five `SYMPTOM` lines, numbered, with no layer named and no hint. The
first seven days each opened with a layer name at the top of the page;
this one does not, because production never does. Recognizing which of
the six layers a symptom belongs to, before you can even pick the right
instrument to reach for, is the actual skill this day tests — a "planner
day" habit of reaching for `EXPLAIN` first is only useful if you notice
this is a planner problem before you reach for it.

The eight pool members, so you know what you might draw (this is not a
hint about which five you got — read your own `SYMPTOM` lines for that):

1. A missing composite index on a query shape you haven't seen before.
2. A stale-statistics plan flip on a join you haven't seen before.
3. A three-session lock chain rooted in whichever session opened first —
   not whichever one `pg_stat_activity` shows as having waited longest.
4. Autovacuum starvation from a long-running transaction, with autovacuum
   itself never touched — left on the whole time.
5. A MongoDB collection scan from an unanchored `$regex`.
6. An InnoDB deadlock produced by two transfer jobs that lock the same
   two accounts in opposite order.
7. A bloated **index** — the table it belongs to vacuums clean.
8. An N+1 that is invisible query-by-query (every individual call is
   fast and properly indexed) and shows up only in `pg_stat_statements`'
   aggregates.

## Before you touch the gauntlet

Write the evidence-chain skeleton from `journal.md` into that file for
each incident **before you fix anything** — same discipline as every
earlier day, under time pressure this time. The discipline is the point;
the gauntlet is the test of whether it survives contact with a clock.
Predict the layer before you open a single instrument (`STRATEGY.md`'s
daily loop, step 1) — that five-second habit is exactly what a day with
no layer label in the title is checking for.

## How to run

From `database_mastery`, with the stack up:

```bash
bash labs/day08/gauntlet.sh
```

It prints five numbered `SYMPTOM` lines and records a start timestamp.
Ninety minutes is the target for all five, timed loosely — `verify.sh`
reports your elapsed time at the end but never fails you on it. Diagnose
each incident from its own instruments: `EXPLAIN (ANALYZE, BUFFERS)`,
`pg_stat_activity`/`pg_locks`/`pg_blocking_pids`, `pg_stat_user_tables`,
`pg_stat_statements`, `SHOW ENGINE INNODB STATUS`, `db.collection.explain
("executionStats")` — see `content/primers/catalog-field-reference.md`
and `content/primers/explain-field-reference.md` for the field-by-field
reference, and `content/day08.md` for what's new here versus Days 3-6.

## Answer format

Every earlier day stashes one key. Day 8 selects five incidents out of
eight pool members, so the key names you need depend on which five you
drew — read your own `SYMPTOM` lines and match them against the list
below, then write **only the keys for incidents you actually got** into
`/tmp/answer` inside the `ws` container, one `key=value` line per
incident, lowercase, no spaces around `=`:

| Pool member | Key | Value |
|---|---|---|
| missing_index | `index_columns` | ordered column list, comma-separated |
| stale_stats | `divergent_node` | the deepest plan node name where estimate and actual diverge |
| lock_chain | `root_pid` | the root blocker's backend PID |
| vacuum_starvation | `pinning_pid` | the long-running session's backend PID |
| mongo_regex | `regex_reason` | why the original pattern couldn't use an index — not which field it filtered on |
| innodb_deadlock | `deadlock_accounts` | the two account IDs, ascending, comma-separated |
| bloated_index | `bloated_index` | the bloated index's name |
| n_plus_one | `n1_calls` | the call count `pg_stat_statements` shows for the offending queryid |

`n1_calls` is graded with headroom, not exact equality: `pg_stat_
statements.calls` for that queryid keeps incrementing with every further
execution of the same normalized shape, including your own diagnostic
`EXPLAIN`s while investigating it — reading the counter honestly after
doing exactly that work should not cost you the incident. Answer with
whatever the counter reads when you check it; `verify.sh` accepts
anything at or above the value `gauntlet.sh` recorded, with generous
headroom above it.

`mongo_regex`'s fix lives partly in a file: `gauntlet.sh` writes the
exact offending query to `ws:/tmp/day08-mongo-regex-query.js`. Edit that
file in place — `verify.sh` runs whatever it contains, not a stand-in —
and `regex_reason` asks you to name *why* the original pattern in that
file couldn't use an index at all, regardless of which index exists,
not merely which field it filtered on.

```bash
docker compose -p dbmastery exec ws sh -c 'cat > /tmp/answer' <<'EOF'
root_pid=41298
n1_calls=317
EOF
```

(That block shows the syntax only, for a run that drew `lock_chain` and
`n_plus_one` — your own run drew a different five, and neither of those
two example values is real.)

## Scoring

```bash
bash labs/day08/verify.sh
```

It checks all five incidents **independently** — for each, both that the
pathology is genuinely resolved (the same class of assertion its origin
day used: a plan shape, a catalog counter, a replayed interleaving) and
that your stated diagnosis for that specific incident matches, and prints
a per-incident result plus a final `score: N/5` line. Anything below 5/5
leaves the script's exit code nonzero — four correct diagnoses and one
missed fix is not a pass, the same way it would not be at 2 a.m. on call.

`ANSWERS.md` covers all eight pool members, not only the five you drew,
each as a compressed evidence chain in `journal.md`'s exact shape.
Reading it before you've written your own chain for the five you got
skips the lesson the randomness of `gauntlet.sh` exists to force.

## Re-rolling

```bash
bash labs/day08/gauntlet.sh --reset
```

removes every pathology the pool can have applied — all eight, regardless
of which five your last run drew — and clears the answer stash and your
`/tmp/answer`. Run `gauntlet.sh` again (without `--reset`) afterward to
roll a fresh five. See `teardown.md` before moving on to the design half
of the day, and before tearing the stack down for good.
