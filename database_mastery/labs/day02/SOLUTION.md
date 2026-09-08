# Day 2 solution — normal forms as anomaly prevention

Mirrors `journal.md`'s evidence-chain skeleton. Read this only after your
own attempt, or after `verify.sh` has forced the question and you are
genuinely stuck — the chain below is the destination, not a shortcut to
it.

### Day 2 — wide table hides a transitive dependency

**Predictions (written before running anything):**
- Distinct `merchant_name` spellings per `merchant_id` in the untouched
  `wide_payments`: predicted 1 for every merchant — the seed is
  deterministic and nothing has corrupted it yet.
- Size of the largest `merchant_catalog` document versus the 16 MB limit:
  predicted "large, but comfortably under" — 40,000+ products, each with
  five short fields, felt like it should land in the low single-digit
  megabytes.
- Write-time cost of adding the three foreign keys to `payments_norm.
  payments`, as a percentage of insert time: predicted "a few percent."

**Symptom (verbatim, no interpretation):**
`SELECT merchant_id, merchant_name, count(*) FROM wide_payments GROUP BY
1, 2 HAVING count(DISTINCT merchant_name) > 0 LIMIT 5;` returns rows where
the same `(merchant_id, merchant_name)` pair repeats thousands of times —
14,382 rows for one merchant alone at `SCALE=10`. Every column in
`wide_payments` is `NOT NULL`, including every merchant, customer, and
payment-method attribute, so no row can exist that describes a merchant
or customer without also describing a specific payment.

**Layer:** logical

**Chain of evidence:**
1. Claim: `wide_payments` has exactly two candidate keys, `row_id` and
   `payment_id`, both single-column. | Proof: both are declared/verified
   unique and `NOT NULL` (`row_id` is the declared primary key;
   `SELECT count(*), count(DISTINCT payment_id) FROM wide_payments;`
   reports the same number for both), and the table is built one row per
   source `payments` row (`10-generate.sql`'s `row_number() OVER (ORDER
   BY p.payment_id)`), so no other column or combination is forced to be
   unique.
2. Claim: `merchant_id` is non-prime — it belongs to neither candidate
   key. | Proof: by inspection of the two candidate keys in step 1;
   `merchant_id` is not `row_id` and not `payment_id`.
3. Claim: `merchant_id → merchant_name, merchant_country,
   merchant_risk_tier` holds as a functional dependency. | Proof: by
   construction — `10-generate.sql` populates these three columns from a
   single `JOIN merchants m ON m.merchant_id = p.merchant_id`, so every
   row sharing a `merchant_id` necessarily shares the same
   `merchant_name`, `merchant_country`, `merchant_risk_tier` (confirmed
   empirically: `SELECT merchant_id, count(DISTINCT merchant_name) FROM
   wide_payments GROUP BY 1 HAVING count(DISTINCT merchant_name) > 1;`
   returns zero rows against the untouched table).
4. Claim: a non-prime attribute determining other non-prime attributes is
   a transitive dependency, and 3NF forbids it. | Proof: `merchant_id` is
   non-prime (step 2) and determines three other non-prime attributes
   (step 3); this is the textbook shape of a 3NF violation, and no
   composite-key partial dependency (2NF) is even possible here, since
   both candidate keys are single columns.
5. Claim: this transitive dependency is exploitable, not merely
   theoretical. | Proof: inside a rolled-back transaction, `UPDATE
   wide_payments SET merchant_name = 'MERCHANT #1, RENAMED' WHERE
   merchant_id = 1 AND row_id % 5 = 0;` followed by `SELECT merchant_id,
   count(DISTINCT merchant_name) FROM wide_payments WHERE merchant_id = 1
   GROUP BY 1;` reports `2` — one merchant, two disagreeing names, with
   no constraint in the schema that rejected the `UPDATE`.

**Diagnosis:** `wide_payments` satisfies 1NF (atomic columns) and 2NF
(trivially, since neither candidate key is composite) but violates 3NF:
`merchant_id`, a non-prime attribute, transitively determines
`merchant_name`, `merchant_country`, and `merchant_risk_tier`.
`customer_id → customer_email, customer_country` is the identical
violation on the customer side, independent of the merchant one — fixing
one does not fix the other. `violated_form=3NF`, `determinant=merchant_id`
(the answer file also accepts a set containing it, since `customer_id` is
an equally valid second determinant of the same violated form).

**Fix applied:** decomposed `wide_payments` into `payments_norm`, peeling
off each transitive dependency into its own table keyed on the
determinant, plus a payment-methods table split out on domain grounds
(see "The BCNF decomposition" below for the reasoning on that last split,
which is not forced by a functional dependency visible in `wide_payments`
itself).

**Proof the fix worked (same instrument re-read):** the disagreement
`UPDATE` from step 5 is no longer expressible without a rollback saving
you: run the equivalent update against `payments_norm.merchants` —
`UPDATE payments_norm.merchants SET merchant_name = 'x' WHERE merchant_id
= 1;` — and every payment referencing merchant 1 sees the new name on the
very next join, because there is only one row left to update. There is no
way to make two rows disagree about merchant 1's name any more, because
there is only one row that holds it.

**Prediction error and what it tells me:** the merchant-name prediction
(1 spelling per merchant, pre-corruption) was correct — but that was
never really in question; the useful prediction was implicit and wrong:
believing, going in, that "the data is consistent" and "the schema
prevents inconsistency" were the same claim. They are not. Every anomaly
in this lab was reachable with an ordinary `UPDATE` or `DELETE`, no
special privilege required, on a table that looked, at rest, completely
fine.

**What I would check first next time:** before trusting a wide,
denormalised table's consistency, check whether a duplicated fact's
determinant is a candidate key of the table it lives in — if it is not,
the table is one `UPDATE` away from disagreeing with itself, regardless
of how consistent the current data happens to look.

---

## The full functional-dependency set for `wide_payments`

Columns: `row_id, payment_id, amount_minor, currency, status, created_at,
merchant_id, merchant_name, merchant_country, merchant_risk_tier,
customer_id, customer_email, customer_country, pm_brand, pm_last4,
pm_exp_month, pm_exp_year`.

Candidate keys: `{row_id}`, `{payment_id}` (both are single columns; the
table is built one row per source payment, so `payment_id` is also
unique).

- `row_id → (every other column)` — trivial, from the primary key.
- `payment_id → (every other column)` — trivial, from the second
  candidate key.
- `merchant_id → merchant_name, merchant_country, merchant_risk_tier` —
  **non-trivial, transitive** (`merchant_id` is non-prime). This is the
  violation named in `/tmp/answer`.
- `customer_id → customer_email, customer_country` — **non-trivial,
  transitive** (`customer_id` is non-prime). The same violation,
  independent determinant.
- `pm_brand, pm_last4, pm_exp_month, pm_exp_year` have no smaller
  determinant visible among `wide_payments`'s own columns — the table
  never exposes the `payment_method_id` that determines them in the
  source schema, so from this table's attributes alone they are only
  dependent on the whole key. Splitting them out below is a domain-driven
  design decision, not a response to a provable FD violation — see the
  next section.

## The BCNF decomposition, as runnable DDL

```sql
CREATE SCHEMA payments_norm;

-- Peel off the merchant_id -> merchant_name, merchant_country,
-- merchant_risk_tier transitive dependency.
CREATE TABLE payments_norm.merchants (
    merchant_id         BIGINT PRIMARY KEY,
    merchant_name       TEXT NOT NULL,
    merchant_country    CHAR(2) NOT NULL,
    merchant_risk_tier  SMALLINT NOT NULL
);

INSERT INTO payments_norm.merchants (merchant_id, merchant_name, merchant_country, merchant_risk_tier)
SELECT DISTINCT merchant_id, merchant_name, merchant_country, merchant_risk_tier
FROM wide_payments;

-- Peel off the customer_id -> customer_email, customer_country
-- transitive dependency, the same shape as merchants above.
CREATE TABLE payments_norm.customers (
    customer_id       BIGINT PRIMARY KEY,
    customer_email    TEXT NOT NULL,
    customer_country  CHAR(2) NOT NULL
);

INSERT INTO payments_norm.customers (customer_id, customer_email, customer_country)
SELECT DISTINCT customer_id, customer_email, customer_country
FROM wide_payments;

-- payment_methods is not forced by a visible FD (see above) -- it is
-- forced by domain knowledge: a payment method belongs to a customer and
-- is reused across many of that customer's payments, so leaving its
-- attributes embedded in the payment-facts table reproduces the exact
-- same update-anomaly risk the moment a card's expiry changes and only
-- some of that customer's rows get touched. wide_payments never exposed
-- the real payment_method_id, so manufacture a surrogate over the
-- distinct (customer_id, brand, last4, exp_month, exp_year) combination.
CREATE TABLE payments_norm.payment_methods (
    payment_method_id  BIGINT PRIMARY KEY,
    customer_id        BIGINT NOT NULL REFERENCES payments_norm.customers(customer_id),
    brand              TEXT NOT NULL,
    last4              CHAR(4) NOT NULL,
    exp_month          SMALLINT NOT NULL,
    exp_year           SMALLINT NOT NULL,
    UNIQUE (customer_id, brand, last4, exp_month, exp_year)
);

INSERT INTO payments_norm.payment_methods (payment_method_id, customer_id, brand, last4, exp_month, exp_year)
SELECT row_number() OVER (ORDER BY customer_id, pm_brand, pm_last4, pm_exp_month, pm_exp_year),
       customer_id, pm_brand, pm_last4, pm_exp_month, pm_exp_year
FROM (
    SELECT DISTINCT customer_id, pm_brand, pm_last4, pm_exp_month, pm_exp_year
    FROM wide_payments
) d;

-- What is left after both peels is already in BCNF: its only determinants
-- are the two original candidate keys (row_id, payment_id), both
-- superkeys of what remains. payment_id is kept as the primary key here
-- since it is the identifier every other day's labs and the canonical
-- schema already use.
CREATE TABLE payments_norm.payments (
    payment_id          BIGINT PRIMARY KEY,
    merchant_id         BIGINT NOT NULL REFERENCES payments_norm.merchants(merchant_id),
    customer_id         BIGINT NOT NULL REFERENCES payments_norm.customers(customer_id),
    payment_method_id   BIGINT NOT NULL REFERENCES payments_norm.payment_methods(payment_method_id),
    amount_minor        BIGINT NOT NULL,
    currency            CHAR(3) NOT NULL,
    status              TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL
);

INSERT INTO payments_norm.payments (payment_id, merchant_id, customer_id, payment_method_id, amount_minor, currency, status, created_at)
SELECT w.payment_id, w.merchant_id, w.customer_id, pm.payment_method_id,
       w.amount_minor, w.currency, w.status, w.created_at
FROM wide_payments w
JOIN payments_norm.payment_methods pm
  ON pm.customer_id = w.customer_id
 AND pm.brand       = w.pm_brand
 AND pm.last4       = w.pm_last4
 AND pm.exp_month   = w.pm_exp_month
 AND pm.exp_year    = w.pm_exp_year;
```

Every determinant left standing in this schema is a candidate key of the
table it lives in: `merchant_id` in `merchants`, `customer_id` in
`customers`, `payment_method_id` in `payment_methods` (with `(customer_id,
brand, last4, exp_month, exp_year)` as a second candidate key by
construction, enforced by the `UNIQUE` constraint), and `payment_id` in
`payments`. That is BCNF by definition — no further decomposition is
forced.

**A caveat on the manufactured key, stated honestly rather than papered
over.** The seed gives each customer one to three cards with
independently random `brand`/`last4`/`exp_month`/`exp_year`, so nothing
rules out two genuinely different cards belonging to the same customer
coincidentally sharing all four values. The `DISTINCT` step that builds
`payment_method_id` cannot tell that case apart from one real card used
twice — it collapses both into a single row before the `UNIQUE`
constraint is even created, so the constraint is satisfied by
construction, after the fact, and does nothing to catch a merge that
already happened. Nothing downstream notices either: the lossless-join
row-count check in the next section still passes, because both of the
original `wide_payments` rows still join to exactly one `payment_methods`
row regardless of whether that row represents one card or a coincidental
merge of two. This is the same point the domain-driven justification for
splitting `payment_methods` out already made, one layer deeper:
recovering a key that the source data never carried is a reconstruction,
not a measurement, and this specific reconstruction can be wrong in a way
that `wide_payments` itself has no way to reveal. In a real migration this
gets resolved by going back to the actual system of record for
`payment_method_id` rather than reconstructing one from attribute
coincidence; this lab has no such source to go back to, so the caveat
stands as a known, accepted limitation of the exercise rather than a
solved problem.

## Losslessness proof

**Algebraic argument**, applying "a split is lossless iff the intersection
of the two projections is a superkey of one of them," at each step:

1. Splitting `{merchant_id, merchant_name, merchant_country,
   merchant_risk_tier}` off of `wide_payments`: the intersection with what
   remains is `{merchant_id}`, and `merchant_id` is the sole candidate key
   of the merchants projection (by the FD in the previous section) —
   lossless.
2. Splitting `{customer_id, customer_email, customer_country}` off:
   intersection `{customer_id}`, a candidate key of the customers
   projection — lossless, by the identical argument.
3. Splitting payment-method attributes into `payment_methods`, keyed by
   construction on the surrogate `payment_method_id` with `(customer_id,
   brand, last4, exp_month, exp_year)` as a second candidate key (the
   `UNIQUE` constraint enforces this): the intersection between
   `payment_methods` and what remains is exactly that composite, which is
   a candidate key of the `payment_methods` side — lossless, even though
   this split was not forced by an FD present in the original relation.

**Empirical proof** — the same reconciliation `verify.sh` runs
automatically:

```sql
-- Original
SELECT count(*), count(DISTINCT payment_id) FROM wide_payments;

-- Reconstructed
SELECT count(*), count(DISTINCT p.payment_id)
FROM payments_norm.payments p
JOIN payments_norm.merchants m ON m.merchant_id = p.merchant_id
JOIN payments_norm.customers c ON c.customer_id = p.customer_id
JOIN payments_norm.payment_methods pm ON pm.payment_method_id = p.payment_method_id;
```

Both queries report the same two numbers: one row per original payment,
and `count(DISTINCT payment_id)` equal to `count(*)` on both sides (no
fan-out from any of the three joins, since `merchant_id`, `customer_id`,
and `payment_method_id` are each unique keys on the side they join
against).

Cardinality matching is necessary but not sufficient: a foreign key wired
to a *valid but wrong* row in the referenced table (a customer's second
card instead of the one that payment actually used, say) reproduces the
identical counts above while the reconstructed row's content is wrong.
`verify.sh` also runs the textbook lossless-join test directly —
symmetric `EXCEPT` between the reconstructed projection and
`wide_payments`, over every substantive column (everything except the
synthetic `row_id`, which `payments_norm` never needs to reproduce):

```sql
-- Rows the reconstruction has that wide_payments does not (must be empty)
SELECT p.payment_id, p.amount_minor, p.currency, p.status, p.created_at,
       p.merchant_id, m.merchant_name, m.merchant_country, m.merchant_risk_tier,
       p.customer_id, c.customer_email, c.customer_country,
       pm.brand, pm.last4, pm.exp_month, pm.exp_year
FROM payments_norm.payments p
JOIN payments_norm.merchants m ON m.merchant_id = p.merchant_id
JOIN payments_norm.customers c ON c.customer_id = p.customer_id
JOIN payments_norm.payment_methods pm ON pm.payment_method_id = p.payment_method_id
EXCEPT
SELECT payment_id, amount_minor, currency, status, created_at,
       merchant_id, merchant_name, merchant_country, merchant_risk_tier,
       customer_id, customer_email, customer_country,
       pm_brand, pm_last4, pm_exp_month, pm_exp_year
FROM wide_payments;

-- Rows wide_payments has that the reconstruction does not (must also be empty)
-- (the same two SELECTs, EXCEPT in the other direction)
```

`EXCEPT` computes a distinct-set difference, so cardinality (row count,
fan-out) and content (per-column value equality) are genuinely
independent failure modes here — this query catches the second even when
the row-count check above reports a clean match. At `SCALE=10`
(5,000,000 payments) this forces a real hash or sort over the full
16-column projection on each side, twice, under this stack's deliberately
small `work_mem`; expect it to spill to disk and take real wall-clock
time rather than complete instantly. That cost is the price of a genuine
lossless-join proof rather than a proxy for one, and it is why `verify.sh`
keeps the cheap cardinality check as a fast first failure signal and only
pays for the full `EXCEPT` afterward.

## Dependency preservation

Both extracted FDs (`merchant_id → …`, `customer_id → …`) are fully
preserved: each determinant and its dependents live together in one
table, so both can still be checked without a join — a `merchants` row's
own primary key uniqueness is the entire enforcement mechanism. This
schema does not hit the classic case where BCNF costs dependency
preservation (the `{city, street} → zip`, `zip → city` example in
`content/day02.md`'s Core concepts) — that case only arises when two
overlapping FDs share a non-key attribute on both sides in a way that no
single table can hold together, which does not happen here.

## The catalog restructuring — bucketing over referencing

`merchant_catalog`'s `products` array is the same category of problem as
`wide_payments`: a fact (the full product list) stored somewhere it has
outgrown, with no ceiling forcing the point. Restructure by bucketing —
splitting each merchant's products into multiple documents of at most
1,000 entries each — rather than by fully referencing each product as its
own document:

```js
// mongosh, against the payments database
const BUCKET_SIZE = 1000;

db.merchant_catalog.find().forEach(function (doc) {
    const products = doc.products || [];
    for (let i = 0, seq = 0; i < products.length; i += BUCKET_SIZE, seq++) {
        db.merchant_catalog_buckets.insertOne({
            merchant_id: doc.merchant_id,
            bucket_seq: seq,
            product_count: Math.min(BUCKET_SIZE, products.length - i),
            products: products.slice(i, i + BUCKET_SIZE)
        });
    }
});

db.merchant_catalog_buckets.createIndex({ merchant_id: 1, bucket_seq: 1 }, { unique: true });

// Replace the original collection with the bucketed shape, in place,
// under the same name -- drop the oversized originals only after the
// bucketed copy is confirmed complete.
db.merchant_catalog.drop();
db.merchant_catalog_buckets.renameCollection('merchant_catalog');
```

**Why bucketing, not referencing.** A fully referenced design puts one
product per document in its own `products` collection, joined to
`merchant_catalog` by `merchant_id`. That turns one merchant's 45,000-
product catalog into 45,000 documents, each paying MongoDB's fixed
per-document overhead — its own `_id`, its own entry in every index on
the collection, its own place in WiredTiger's page layout — on data that
used to amortise that overhead across a single document. It also changes
the access pattern: "give me this merchant's catalog," previously one
document fetch, becomes a scan or an index range read across tens of
thousands of documents, most of them likely still landing on the same few
WiredTiger pages regardless of the extra bookkeeping now required to get
there. Bucketing keeps the read shape close to the original — a small,
bounded number of larger documents, each comfortably under the 1,000-
entry cap — because the access pattern here is "give me a page of this
merchant's catalog," not "give me this one product by its own identity."
Referencing is the right call when products need independent identity
(their own updates, their own queries by SKU across merchants); bucketing
is the right call when the array's only sin is size and the read pattern
never needed per-product independence in the first place, which is
exactly this dataset's shape.

**Product-count preservation**, checked the same way `verify.sh` checks
it:

```js
db.merchant_catalog.aggregate([
    { $group: { _id: "$merchant_id", total: { $sum: { $size: "$products" } } } }
]);
// compare each merchant_id's total against catalog_seed_meta.product_count
```

Every merchant's summed product count across its bucket documents must
equal the `product_count` `catalog_seed_meta` recorded for that merchant
at seed time — the ground truth the restructuring is not allowed to
disturb.
