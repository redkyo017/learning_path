# Seed dataset

This directory generates the dataset every day of this path measures
against: a synthetic payments platform, spread across PostgreSQL, a MySQL
subset, and two MongoDB collections. It is not a toy dataset generated for
looks -- its statistical shape is the material each lab tunes, breaks, and
repairs.

## What the dataset represents

A payments processor's core tables: merchants who accept payments,
customers who make them, the payment methods on file, the payments
themselves, the double-entry ledger backing them, and the refunds and
disputes that follow a fraction of them. `wide_payments` is a deliberately
denormalised copy of the same data, built for Day 2's normal-forms lab.
Two MongoDB collections cover the parts of this domain that fit an
event-log and a large-document shape better than a relational table:
`payment_events` (an append-only activity stream) and `merchant_catalog`
(one document per merchant, with an unbounded product list).

## Running it

```bash
cd labs/stack/seed
SCALE=10 bash seed.sh
```

Run this from inside the `ws` service -- it reaches PostgreSQL, MySQL and
MongoDB by their compose service names (`pg`, `my`, `mongo`), not by host
ports. `seed.sh` runs the four stages in order (`00-schema.sql`,
`10-generate.sql`, `20-mysql-load.sh`, `30-mongo-load.js`) and prints an
elapsed time for each.

`seed.sh` refuses to run against a database that already has data in it.
Set `FORCE=1` to re-seed from scratch (every stage drops its own tables
and collections before recreating them):

```bash
FORCE=1 SCALE=10 bash seed.sh
```

## SCALE

`SCALE` (default `10`) scales the PostgreSQL and MongoDB row counts. The
MySQL subset and the three PK-variant tables are a fixed absolute size
regardless of `SCALE` -- see `20-mysql-load.sh` for why.

| Table / collection            | Formula                     | SCALE=10   | SCALE=2   |
|--------------------------------|------------------------------|-----------:|----------:|
| `merchants`                   | `2000 * SCALE / 10`          | 2,000      | 400       |
| `customers`                   | `500000 * SCALE / 10`        | 500,000    | 100,000   |
| `payments`                    | `5000000 * SCALE / 10`       | 5,000,000  | 1,000,000 |
| `ledger_entries`               | `10000000 * SCALE / 10`      | 10,000,000 | 2,000,000 |
| MySQL `ledger_entries` subset  | fixed                        | 2,000,000  | 2,000,000 (all of them, at this SCALE) |
| MySQL PK-variant tables (each) | fixed                        | 500,000    | 500,000 (half of MySQL's 1,000,000-row `payments` table, at this SCALE) |
| Mongo `payment_events`         | `2000000 * SCALE / 10`       | 2,000,000  | 400,000   |

`refunds`, `disputes` and `wide_payments` are derived from `payments` and
have no independent formula: `refunds` is roughly 4% of `payments`,
`disputes` roughly 1%, and `wide_payments` is one row per payment.

Expected runtime at `SCALE=10`: about 15 minutes end to end, dominated by
the PostgreSQL generation and the MySQL/MongoDB loads. Expected disk
usage: about 6 GB across all three databases.

## Determinism

`10-generate.sql` calls `SELECT setseed(0.42);` as its first statement and
disables parallel query for the session, and `30-mongo-load.js` uses a
hand-written seeded linear congruential generator instead of
`Math.random()`, which cannot be seeded at all. Two runs at the same
`SCALE` produce identical data, down to the row.

This matters beyond reproducibility for its own sake: every day's
`verify.sh` asserts against concrete numbers -- row counts, specific
merchant ids, specific correlation strengths -- rather than against
"looks about right." A generator that drifted between runs would make
those assertions unwritable, or worse, silently wrong.

## The accounts/ledger invariant

`accounts.balance_minor` is a cache of the sum of an account's
`ledger_entries.amount_minor` (credits positive, debits negative). At
seed time, every account -- including the platform account, which never
receives any ledger legs -- is reconciled to an exact, fixed relationship
with its ledger sum:

```
balance_minor - (SUM of that account's ledger_entries.amount_minor) = 100000000000
```

`100000000000` (1e11 minor units) is a fixed, documented opening-balance
constant, not a computed one: it is comfortably above any single
account's total possible debits at any supported `SCALE`, while leaving
vast `BIGINT` headroom below the ~9.2e18 limit. `10-generate.sql` prints
it via `\echo` during the seed run so it is visible, not only documented
here.

This is the invariant Day 5's `verify.sh` depends on: the cache starts
*exactly* consistent with the ledger for every account, so any divergence
the learner observes after running their own concurrent transactions is
attributable to those transactions, not to how the data was seeded.

## Why the data is skewed

Uniform synthetic data is the single most common reason a database tuning
exercise teaches nothing: if every merchant gets the same number of
payments, every value is equally likely, and every row is the same size,
then there is nothing for an index, a statistics collector, or a sharding
key to get right or wrong. This dataset is built to avoid that, in four
specific ways that later days depend on:

- **`payments.description` TOASTs for about 1 row in 20.** Most
  descriptions are a short sentence; roughly 5% are built from 96
  concatenated MD5 hashes (3,072 bytes of high-entropy text, a real margin
  over PostgreSQL's ~2,032-byte `TOAST_TUPLE_THRESHOLD`), which is large
  enough, and resistant enough to PostgreSQL's TOAST compressor, to force
  those rows' description values out of the main table into TOAST
  storage. Day 1 asks the learner to find that column and count the rows
  that used it.
- **`merchants.country` and `payments.currency` are correlated, not
  independent, and not perfectly correlated either.** A payment's
  currency matches its merchant's country's primary currency 95% of the
  time, and is a genuinely different currency the other 5%. The
  PostgreSQL query planner assumes columns are independent unless told
  otherwise; this dataset makes that assumption visibly wrong without
  making it *so* wrong that any estimate at all would reveal the problem.
  Day 4's extended-statistics fix depends on the correlation being real,
  strong, and imperfect all at once.
- **Merchant activity is power-law skewed.** `payments.merchant_id` is
  drawn from a Zipf(s=1) distribution over merchant rank (merchant_id
  itself is the rank): `weight(rank) = 1/rank`, normalised by the
  harmonic number `H_N`. Both PostgreSQL (`10-generate.sql`'s
  `merchant_cdf` scratch table) and the Mongo loader
  (`30-mongo-load.js`'s `buildMerchantCdf`) implement the same
  distribution via inverse-CDF lookup, so the skew is consistent across
  both databases. At `SCALE=10` (`merchant_count = 2000`): `H_20`
  (the top 1% of merchants, by id) is approximately 3.598, and `H_2000`
  is approximately 8.178 (`H_n ≈ ln(n) + γ`), so the top 1% of merchants
  receive roughly `3.598 / 8.178 ≈ 44%` of `payments` (and, downstream,
  `ledger_entries`) rows, and merchant_id = 1 alone receives roughly
  `1 / 8.178 ≈ 12%`. An earlier draft of this generator used
  `1 + floor(power(random(), 3) * merchant_count)`, which is a
  materially weaker skew than intended -- that cube gives the top 1%
  only `0.01^(1/3) ≈ 21.5%` of rows, not the roughly-half this dataset is
  supposed to model. Reaching 50% by raising the exponent instead
  (`power(random(), 6.64)`) was considered and rejected: it would put
  roughly 32% of all payments on merchant_id = 1 alone, and since
  `merchants.country` is drawn once per merchant, that single country's
  currency would then dominate the `payments.currency` marginal enough to
  damage the correlation property Day 4 depends on. 44% with a healthy
  (not overwhelming) head is the right trade. Every tuning lesson in this
  path -- indexing, partitioning, caching, sharding -- assumes that some
  keys are hot and most are not; uniform access patterns would make all
  of those lessons look unnecessary. **The 44% / 12% figures are
  SCALE=10-specific.** Smaller N concentrates the head less, because
  there is less tail for it to dominate: at `SCALE=2`
  (`merchant_count = 400`, top 1% = 4 merchants), `H_4 / H_400 ≈
  2.083 / 6.569 ≈ 31.7%` for the top 1%, and the head merchant's share
  rises to `1 / H_400 ≈ 15.2%`. Any check that asserts ~44% specifically
  must run at SCALE=10.
- **`payment_events.ts` is monotonically increasing across the entire
  load**, not only within a batch, and its step size is scaled so the
  event stream spans the same ~548-day window as `payments.created_at`
  regardless of `SCALE`. Day 7's hot-shard lesson is that a monotonically
  increasing shard key concentrates writes on whichever shard owns the
  current high end of the range; that lesson does not exist if timestamps
  can move backward, arrive out of order, or cluster into a much shorter
  window than the rest of the dataset. Note that `payment_events` is
  deliberately **not** referentially tied to `payments`: its
  `merchant_id` and `payment_id` fields are drawn independently, so a
  given event document will often name a merchant that does not actually
  own that `payment_id` in PostgreSQL. No lab should join
  `payment_events` to `payments` expecting those fields to agree -- this
  collection models an activity stream, not a normalized ledger.
