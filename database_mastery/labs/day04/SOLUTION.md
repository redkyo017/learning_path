# Day 4 — SOLUTION

Mirrors the `journal.md` chain template. Read this only after you have
written your own prediction and evidence chain — see `README.md`.

### Day 4 — a stale merchant estimate wrecks a nested loop

**Predictions (written before running anything):**
- Estimated rows at the deepest divergent node: low double digits (a
  merchant at the midpoint of the id range should look unremarkable to
  the planner).
- Actual rows at that same node: well over 100,000, given the bulk
  `UPDATE` break.sh describes reassigning a large slice of captured
  payments onto one merchant.
- Whether `ANALYZE` alone (after removing the `n_distinct` override)
  fixes everything: no — a second, independent correlation error should
  remain on any query touching `merchants.country` and
  `payments.currency` together.

**Symptom (verbatim, no interpretation):**
`SYMPTOM: the merchant capture-totals report ran in about 400 ms last
week; same schema, same query, same index -- it now takes upward of 90
seconds.`

**Layer:** planner

**Chain of evidence:**

1. Claim: the query and schema are unchanged, so the regression is in
   what the planner believes about the data, not in what the data or the
   query actually are. | Proof: `\d payments` and the query text both
   match what's in `content/day04.md`; nothing here was altered.
2. Claim: the plan's top node (`GroupAggregate`) tells you nothing is
   wrong. | Proof: `EXPLAIN (ANALYZE, BUFFERS)` on the target query shows
   `GroupAggregate (... rows=1 ...) (actual ... rows=1 ...)` — estimate
   and actual agree exactly at the root, because grouping to one
   merchant's name collapses any number of input rows down to one either
   way.
3. Claim: the divergence is two levels down, at the `Index Scan` on
   `payments`, and the `Nested Loop` above it is only inheriting that
   scan's mistake. | Proof: the `Index Scan using
   payments_merchant_id_idx on payments p` node reports `rows=` in the
   low double digits against `actual ... rows=` above 100,000; the
   `Nested Loop` immediately above it reports the identical estimate and
   the identical actual value, because a nested loop's own row estimate
   is `outer_rows × inner_rows`, and the outer side (`merchants`, keyed
   by its primary key) is exactly right at `rows=1, actual rows=1`.
4. Claim: the estimate is stale, not merely low-resolution. | Proof:
   `SELECT last_autovacuum, last_analyze, n_mod_since_analyze FROM
   pg_stat_user_tables WHERE relname = 'payments';` shows `last_autovacuum`
   null (autovacuum is disabled on this table —
   `SELECT reloptions FROM pg_class WHERE relname='payments';` confirms
   `autovacuum_enabled=false`) and `n_mod_since_analyze` in the hundreds
   of thousands — real writes have happened against this table since its
   statistics were last refreshed, and nothing has refreshed them since.
5. Claim: there is also a hand-applied override sitting on this exact
   column, independent of the staleness. | Proof: `SELECT attoptions FROM
   pg_attribute WHERE attrelid='payments'::regclass AND
   attname='merchant_id';` returns `{n_distinct=1}` — someone (here,
   `break.sh`, standing in for an earlier "fix" to a different problem)
   told the planner this column has effectively one distinct value. This
   isn't what produced today's specific divergence by itself — the stale
   MCV list already explains the gap in step 4 — but it will corrupt
   every future `ANALYZE` run's understanding of this column's
   cardinality until it's removed, which is why `verify.sh` checks for it
   independently of the timing fix.

**Diagnosis:** the target merchant was, before the bulk `UPDATE`, an
unremarkable merchant well below the top of the power-law distribution —
not common enough to earn a slot in `payments.merchant_id`'s
most-common-values list, so its row estimate came from the leftover,
spread-evenly-across-the-remaining-values bucket, on the order of a few
hundred rows. The bulk `UPDATE` reassigned a large, deterministic slice
of other merchants' captured payments onto it, multiplying its real row
count by two orders of magnitude. With autovacuum disabled and no manual
`ANALYZE`, the planner never saw that shift: it is still costing the
query against the pre-update distribution, so it commits to a nested
loop with an index scan on the inner side — the right plan for a few
hundred rows, catastrophic for the six-figure count the table actually
holds today. The `n_distinct` override sitting in `attoptions` is a
separate, compounding landmine: harmless to this particular query's
current estimate (which is coming from the stale MCV list, not the
non-MCV fallback the override would poison), but guaranteed to corrupt
the *next* `ANALYZE`'s cardinality estimate for this column if it isn't
cleared first.

**Fix applied — stage 1 (necessary, not sufficient):**
```sql
ALTER TABLE payments ALTER COLUMN merchant_id RESET (n_distinct);
ALTER TABLE payments SET (autovacuum_enabled = true);
ANALYZE payments;
```

**Proof stage 1 worked (same instrument re-read):** `EXPLAIN (ANALYZE,
BUFFERS)` on the identical target query now shows the `Index Scan` on
`payments` with `rows=` in the tens of thousands and `actual rows=`
matching it closely — the estimate has caught up with reality, the
planner is free to reconsider its plan, and the report's `Execution
Time` drops from tens of seconds back down to comfortably under a
second. **This is the intermediate improvement** — the specific incident
from the `SYMPTOM` line is resolved.

**The residual error stage 1 does not touch:** run `EXPLAIN` against a
query that filters on both `merchants.country = 'GB'` and
`payments.currency = 'GBP'` in the same join (exercise 2). Measure both
columns' marginal frequencies from `pg_stats` first — do not assume a
country's share of the `merchants` table equals its share of `payments`
volume; this schema's merchant activity is Zipf-distributed, so a
single heavy-volume merchant can move a country's real payment share far
from its merchant-count share. Multiply the two measured marginals the
way the independence assumption does, then compare that product against
the actual joint rate measured directly (or against `EXPLAIN`'s own
`rows=` and `actual rows=` on the predicate). The two will not be close:
`merchants.country` and `payments.currency` are correlated by
construction (the seed matches a payment's currency to its merchant's
country's primary currency on 95% of rows), and the independence
assumption's product comes out low by a real, substantial multiple —
`ANALYZE` cannot close this, because refreshing `payments.merchant_id`'s
own statistics does nothing for the assumption that two *different*
columns' predicates multiply cleanly. That assumption isn't a staleness
problem; it's a missing joint distribution, and `ANALYZE` alone never
builds one.

**Fix applied — stage 2 (closes the residual):**
```sql
CREATE STATISTICS payments_country_currency (ndistinct, dependencies, mcv)
  ON merchant_country, currency
  FROM wide_payments;
ANALYZE wide_payments;
```

(`merchants.country` and `payments.currency` live on different tables —
`CREATE STATISTICS` cannot span the join between them. `wide_payments`
is where both columns already live on one row, from Day 2's
denormalization; that's the actual, single-table target of this fix, not
a workaround.)

**Proof stage 2 worked (same instrument re-read):**
```sql
SELECT attnames, dependencies, n_distinct
FROM pg_stats_ext
WHERE tablename = 'wide_payments';
```
reports a `dependencies` entry for the pair close to 0.95 — matching the
seeded 95% country-currency match rate directly, and unaffected by the
Zipf-skewed merchant volume that makes the raw marginals hard to predict
by hand — and `EXPLAIN` on the two-column predicate against
`wide_payments` now estimates much closer to the real joint rate you
measured directly, instead of the low independence-assumption product
from before. The exact before/after percentages are a property of this
run's seeded data, not a fixed pair of numbers to expect; the shape to
confirm is that the gap between estimate and actual closes substantially
once the dependency is recorded, not that either number hits a specific
value.

**Prediction error and what it tells me:** the prediction that `ANALYZE`
alone would be insufficient was right, but for a subtler reason than "it
doesn't fix everything" — it fixed the *entire* symptom in the ticket
(the specific merchant, the specific report, the specific 90-second
regression) and left a *completely different* class of query — one that
never appeared in the original symptom at all — still substantially
underestimated. A diagnosis that stops at "the report is fast again"
would have closed this incident and left a structurally identical one
waiting for the next merchant-currency report someone writes.

**What I would check first next time:** before declaring a row-estimate
incident closed, check whether the fixed predicate was a single column
or a correlated pair. A single-column fix that resolves the ticket's
literal symptom is not evidence that every other predicate touching the
same tables is now trustworthy — correlated pairs need their own,
separate check against `pg_stats_ext`, every time.
