# Day 2 lab — normal forms as anomaly prevention

## Goal

`wide_payments` is a fully denormalised copy of every payment plus its
merchant, customer, and payment-method attributes, seeded once at
bring-up. There is no `break.sh` today — nothing was injected into it.
Your job is to decompose it into a normalised PostgreSQL schema, diagnose
which normal form it violates and why, and separately fix a MongoDB
collection that has grown an array past what a single document should
carry.

There are **three deliverables**, and all three are required:

```
1. A schema `payments_norm` in PostgreSQL, in BCNF, decomposed from wide_payments,
   with primary keys and foreign keys declared.
2. /tmp/answer containing:
      violated_form=<the normal form wide_payments fails>
      determinant=<the attribute set that determines the offending non-key attributes>
3. merchant_catalog restructured so no document's products array exceeds 1000 entries,
   with the total product count preserved.
```

`labs/day02/verify.sh` reconstructs `wide_payments` by joining the tables
you build in `payments_norm` and checks the reconstruction against the
original two ways: row count and `count(DISTINCT payment_id)` have to
match exactly, and every column's *value* has to match too, row for row,
in both directions. This check is automatic and it is not fooled by a
tidy-looking decomposition: if your join loses rows, duplicates them,
drops an entity `wide_payments` referenced, or wires a foreign key to a
real row that is nonetheless the wrong one, the reconciliation fails even
though every table you wrote has a primary key and every join looks
correct at a glance.

## Deliverable 1 — `payments_norm`

Create a PostgreSQL schema named `payments_norm` containing exactly these
four tables, with these exact table and column names and primary/foreign
keys — `verify.sh` checks the decomposition structurally and content-wise,
by name, not by guessing at your schema:

- `payments_norm.merchants` — one row per merchant, `merchant_id` primary
  key, carrying the merchant's `merchant_name`, `merchant_country`, and
  `merchant_risk_tier` — none of the three duplicated into any other
  table.
- `payments_norm.customers` — one row per customer, `customer_id` primary
  key, carrying the customer's `customer_email` and `customer_country` —
  neither duplicated into any other table.
- `payments_norm.payment_methods` — one row per distinct payment method,
  with its own primary key `payment_method_id` (`wide_payments` never
  exposed the original one, so you will need to manufacture a surrogate —
  see `content/day02.md`'s exercise 3 if you get stuck), a `customer_id`
  foreign key to `customers`, and the card attributes named `brand`,
  `last4`, `exp_month`, `exp_year`. This table has to be genuinely
  deduplicated — one row per distinct card, not one row per payment that
  happened to use it — and it needs a `UNIQUE (customer_id, brand, last4,
  exp_month, exp_year)` constraint declared, so a later write cannot
  reintroduce a duplicate row for a card already on file.
- `payments_norm.payments` — one row per payment, `payment_id` primary
  key, `merchant_id`/`customer_id`/`payment_method_id` foreign keys to the
  three tables above, and the payment's own facts named `amount_minor`,
  `currency`, `status`, `created_at`.

Every table needs a declared `PRIMARY KEY`. `payments_norm.payments` needs
all three `FOREIGN KEY`s. Get every table and column name exactly right —
`verify.sh` checks the decomposition structurally, by name, not by
guessing at your schema. It checks all five of the duplicated columns
above individually, one table at a time, not only a single representative
column per table; it checks that `merchants`, `customers`, and
`payment_methods` each hold a genuinely deduplicated row count — moving
only `merchant_name` out while leaving `merchant_country` and
`merchant_risk_tier` behind, or building `payment_methods` with one row
per payment instead of one row per card, both fail even though the more
visibly wrong column is gone in each case; it checks that the `UNIQUE`
constraint above is actually declared, not merely true by construction of
however you loaded the data; and it checks the reconstructed join against
`wide_payments` on *content*, not only row counts — every column's value
has to match, not merely the number of rows and the number of distinct
`payment_id`s. A foreign key that points at a real but wrong row (the
right customer's second card instead of the one that payment actually
used, say) passes a row-count check and fails this one.

## Deliverable 2 — `/tmp/answer`

Inside `ws`, write to `/tmp/answer`:

```
violated_form=<...>
determinant=<...>
```

`violated_form` is the single highest normal form `wide_payments`
satisfies plus one — i.e., the first one it fails, checked in order.
`determinant` is the non-key attribute set responsible: the thing on the
left-hand side of the functional dependency that breaks that form. Work
this out from `content/day02.md`'s Core concepts section and your own FD
analysis (exercise 1 and 2 there walk through exactly this) — it is not
handed to you here, and reading it off a failing `verify.sh` run is not
available either: the two values it expects were never printed by this
lab in the first place, only compared against.

## Deliverable 3 — restructure `merchant_catalog`

The top 20 merchants in `merchant_catalog` carry `products` arrays of
40,000+ entries — several megabytes per document, and closing in on the
16 MB BSON document limit. Restructure the collection so **no document's
`products` array exceeds 1,000 entries**, while preserving every product.

Do the restructuring in place, under the same collection name,
`merchant_catalog` — add whatever field you need (a `bucket_seq` alongside
`merchant_id` is the natural choice) to distinguish one merchant's
multiple bucket documents from each other. If you genuinely prefer a
different collection name, name it `merchant_catalog_buckets` exactly;
`verify.sh` checks whichever of the two names actually holds data.

`verify.sh` confirms preservation against `catalog_seed_meta`, a
collection written once at seed time holding exactly one `{merchant_id,
product_count}` document per merchant — the ground truth for how many
products each merchant started with, independent of anything you do to
`merchant_catalog` itself.

## Success signal

`labs/day02/verify.sh` exits `0`.

## How to run

With the stack up (`docker compose -p dbmastery up -d --build`, seeded
per `labs/stack/seed/README.md`), work from inside `ws`:

```sh
docker compose -p dbmastery exec ws bash
```

Before writing a single line of DDL, predict the numbers in
`content/day02.md`'s "Predict before you measure" section and record them
in `journal.md`, per `STRATEGY.md`'s daily loop — then reproduce the
three anomalies `content/day02.md`'s Lab section walks through, inside a
transaction you roll back, so `wide_payments` is untouched for the
decomposition that follows. Write your evidence chain — what `wide_
payments` lets you get away with, and why — before you build
`payments_norm`, not after.

Once you believe all three deliverables are in place:

```sh
./verify.sh
```

If it exits non-zero, re-read its output — it reports each of the four
independent checks separately, so it tells you exactly which deliverable
is still wrong rather than leaving you to guess. When it exits `0`,
follow `teardown.md` before moving on to Day 3.

No further hints here. `SOLUTION.md` has the full FD set, the
decomposition DDL, the losslessness proof, and the catalog restructuring
code if you get stuck — reading it before you have your own diagnosis
skips the lesson the lab exists to teach.
