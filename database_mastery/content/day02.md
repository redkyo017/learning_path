# Day 2 — Normal Forms as Anomaly Prevention

**Layer:** logical
**Budget:** 3 h — 1.5 h relational, 1.5 h document

## Why this matters

Normal forms are usually taught as definitions to memorise, which is why
they are forgotten within a year of the course that taught them. "No
transitive dependency on the primary key" is precise, gets a check mark on
an exam, and carries no consequence anyone remembers under a real
schema-design question. That is backwards. Each normal form is a
compression of hard-won operational experience: it names one specific
class of update that corrupts data, and the form exists purely to make
that update impossible. 1NF exists because someone shipped a column that
meant two different things depending on which row you were looking at.
3NF exists because someone renamed a merchant, an `UPDATE` touched one row
out of three thousand that all claimed to describe the same merchant, and
a report picked whichever spelling happened to sort first. You are not
going to memorise that sentence and retain it. You are going to write the
`UPDATE`, watch three thousand rows disagree with each other about a fact
that has exactly one correct value, and you will not need to memorise
anything afterward — the sequence of "I did this, and the database let me
corrupt data it should have refused" is what survives.

Today's artifact, `wide_payments`, was built for exactly this. It is a
single denormalised table carrying every payment plus a full copy of that
payment's merchant, customer, and payment-method attributes, with no
foreign keys and no constraint standing between you and any of the three
classic anomalies. You will reproduce all three — update, insertion,
deletion — on purpose, then decompose the table until the database itself
refuses to let you reproduce them again. The second half of the day
repeats the same exercise against a MongoDB collection that has grown an
array past the point a document can sanely hold, which is the same
problem — an attribute crammed somewhere it does not structurally belong
— wearing a different engine's clothes.

## Read the instrument first

Before any definition, look at what `wide_payments` actually contains.
This query groups by `merchant_id` and `merchant_name` together and counts
how many rows fall into each group:

```sql
SELECT merchant_id, merchant_name, count(*)
FROM wide_payments
GROUP BY 1, 2
HAVING count(DISTINCT merchant_name) > 0
LIMIT 5;
```

```
 merchant_id | merchant_name    | count
-------------+------------------+--------
           1 | Merchant 000001  | 611000
           2 | Merchant 000002  | 306000
           3 | Merchant 000003  | 204000
           4 | Merchant 000004  | 153000
           5 | Merchant 000005  | 122000
(5 rows)
```

(The exact five rows you get will differ — there is no `ORDER BY`, so the
planner is free to return whichever groups it forms first — and the counts
above are `SCALE=10` figures specifically; at another `SCALE` the row count
per merchant changes but the roughly-1/rank shape does not. The shape is
what matters.)

The `HAVING` clause here is a decoy, and it is worth noticing why: grouping
by `(merchant_id, merchant_name)` together means every group can only ever
contain one spelling of the name, so `count(DISTINCT merchant_name)` is
always exactly `1` inside each group, and `> 0` passes for every row
without filtering anything. What the query actually demonstrates is not a
disagreement — nothing disagrees yet — it is the sheer redundancy: one
fact, "merchant 1 is named `Merchant 000001`", copied out 611,000 times,
once per row that happens to reference that merchant. That copy count
tracks `wide_payments`'s well-known power-law skew directly — merchant 1's
611,000 rows versus merchant 5's 122,000 is the same Zipf(s=1) skew
`labs/stack/seed/README.md`'s "Why the data is skewed" section derives
(`merchant_id = 1` alone draws roughly 12% of `payments` at `SCALE=10`),
showing up again here as "how many times is this one fact duplicated."

Redundancy by itself is not yet an anomaly. It is the precondition for
one: nothing in this table's structure says those 611,000 copies have to
agree, only that today, in this particular loaded instance, they happen
to. That distinction — what the schema permits versus what the current
data shows — is the entire subject of the next section.

## Core concepts

**Functional dependency, stated precisely.** `X → Y` ("X determines Y")
holds on a relation if, for any two rows that agree on every attribute in
`X`, they are also guaranteed to agree on every attribute in `Y`. Read
that as a constraint on every possible instance of the table, not a fact
about the rows currently loaded — a functional dependency is a claim
about what the schema *permits*, and it can be true of the design while
looking false, or looking true by accident, of whatever data happens to
be sitting in the table right now. `wide_payments` currently has zero
merchants with disagreeing names (the query above confirmed the shape of
that), and that consistency is not evidence the design is sound — nothing
in `wide_payments`'s structure stands between the current data and the
very next `UPDATE` that introduces the disagreement. A functional
dependency you cannot violate by writing to the table is worth nothing;
one you can violate freely is a bug waiting on a deploy, whether or not
it has fired yet.

**Superkey, candidate key, prime attribute.** A superkey is any attribute
set that functionally determines every attribute of the relation — it
identifies a row, possibly with wasted columns in it. A candidate key is
a *minimal* superkey: remove any one attribute from it and it stops being
a superkey. `wide_payments` has two candidate keys, `{row_id}` and
`{payment_id}` — both are single-column, both unique, and both determine
every other column, because the table is built one row per source
payment. A prime attribute is any attribute that belongs to *some*
candidate key; every other attribute — `merchant_id`, `merchant_name`,
`customer_email`, all of it — is non-prime. Which attributes are prime
versus non-prime is what every definition below turns on — each of the
next four normal forms treats a dependency differently depending on
whether prime or non-prime attributes sit on either side of it.

**1NF, 2NF, 3NF, BCNF — introduced by the anomaly each one blocks, in
order.**

- *1NF: no repeating groups, atomic values per column.* The anomaly this
  blocks is ambiguity about what a row even means — a column holding a
  comma-joined list of products, say, makes "how many products does this
  row represent" an unanswerable question without parsing the string
  first. `wide_payments` satisfies 1NF; every column holds one atomic
  value. Nothing to fix here, but it is worth checking explicitly rather
  than assuming it, because the MongoDB half of today is a direct
  descendant of a 1NF violation: an array field is exactly a repeating
  group, legal in a document store, and it inherits the same "which one
  of these do I mean" ambiguity the moment a query needs to reason about
  it individually.
- *2NF: no non-prime attribute depends on only part of a composite
  candidate key.* The anomaly this blocks is the **update anomaly** in
  its classic textbook form — a fact stored once per line item when it
  should be stored once per order, say, corrupted the moment one line
  item's copy gets updated and the others do not. 2NF only has teeth when
  a candidate key is composite. `wide_payments`'s candidate keys are both
  single columns (`row_id`, `payment_id`), so there is no proper subset of
  either key to depend on partially — 2NF is satisfied trivially, by
  construction, not by design effort. Do not skip stating this: a learner
  who reflexively checks 2NF against a single-column key and finds nothing
  to fix can wrongly conclude the table is well-designed. It is not — the
  next form is where the actual damage is.
- *3NF: no non-prime attribute depends on another non-prime attribute
  (a transitive dependency).* The anomaly this blocks is the same update
  anomaly, one level removed: instead of a fact depending on part of the
  key, it depends on a *non-key* attribute that itself depends on the
  key. Take a worked example that is deliberately not this lab's schema:
  an `orders` table with columns `order_id, warehouse_id,
  warehouse_city`, keyed on `order_id` alone. If `warehouse_id →
  warehouse_city` holds — every order shipped from warehouse 7 lists the
  same city, because a warehouse has exactly one city — then
  `warehouse_city` is transitively dependent on `order_id`, routed through
  the non-prime attribute `warehouse_id`, which is what makes this a
  transitive dependency rather than a second candidate key in disguise
  (`warehouse_id` is not part of `orders`'s key; it only happens to
  determine another non-key attribute). The anomaly is identical in shape
  to the one from "Why this matters": relocate warehouse 7, run an
  `UPDATE` that touches most but not all of its orders, and the table now
  disagrees with itself about where warehouse 7 is. The fix is the same
  shape every time — pull `{warehouse_id, warehouse_city}` into its own
  table keyed on `warehouse_id`, and reference it from `orders` instead of
  copying the city into every order row. Exercises 1 and 2 ask you to find
  where `wide_payments` has this exact shape, and name the transitive
  dependency responsible.
- *BCNF: every determinant is a candidate key, full stop — no exception
  for prime attributes on the right-hand side.* BCNF is strictly stronger
  than 3NF; 3NF carves out an exception (a dependency is allowed to
  violate the "determinant must be a candidate key" rule if everything it
  determines is itself prime), and that exception is rare enough in
  practice that fixing the 3NF violations above also lands you in BCNF
  here, with no separate step required. The general case where the two
  diverge is covered under dependency preservation below.

**The other two anomaly classes**, both consequences of a transitive
dependency of this shape, not separate FDs of their own:

- **Insertion anomaly.** You cannot record a merchant in `wide_payments`
  without a payment attached: every column that belongs to the payment
  itself, not to the merchant, is `NOT NULL`, so a merchant who has signed
  up but has not yet taken a payment does not fit in this table at all —
  short of inventing a fake payment row to hang the merchant's details on,
  which corrupts the payments data to close a gap in the merchant data.
- **Deletion anomaly.** Delete the one row referencing a low-volume
  merchant's only payment, and every fact that belongs to the merchant
  rather than to the payment disappears with it, even though nothing
  about the merchant itself was meant to be deleted. The merchant's
  existence is accidentally coupled to the existence of at least one
  payment. (The identical anomaly exists on the customer side, for the
  identical reason — a customer's own facts are coupled to at least one
  payment existing, too.)

**Lossless-join decomposition, and how to check it.** Splitting `R` into
`R1` and `R2` is lossless if joining `R1` and `R2` back together on their
shared attributes reproduces `R` exactly — no rows gained, none lost. The
theorem that lets you check this without materialising the join every
time: the split is lossless if and only if `R1 ∩ R2` is a superkey of
`R1` or of `R2`. Applied to the `orders`/warehouse example above: pull
`{warehouse_id, warehouse_city}` off of `orders`, and the intersection
with what remains is `{warehouse_id}` — the sole candidate key of that
projected warehouse table, so the split is lossless by the theorem. You
still confirm it empirically afterward, on every decomposition you ship
(that is what the lab's row-count reconciliation against `wide_payments`
is), because the theorem tells you a decomposition is *structurally*
sound, not that you implemented it without a typo — a join condition
that accidentally matches on the wrong column can still fan out or drop
rows even when the theorem says the split you intended was safe.

**Dependency preservation, and the case where BCNF costs it.** A
decomposition preserves dependencies if every FD from the original
relation can still be *checked* using only the decomposed tables, without
a join. This is usually free — peeling a transitive dependency's
determinant and its dependents into their own table, the way the
warehouse example above did, preserves the FD automatically, because both
halves of it land in the same new table together and its own primary key
enforces the rest. It is not always free. The canonical case where BCNF
and dependency preservation genuinely conflict: a relation `(city,
street, zip)` with `{city, street} → zip` (an address has one ZIP code)
and `zip → city` (a ZIP code lies in exactly one city). `zip → city`
violates BCNF, since `zip` alone is not a candidate key of the whole
relation — decomposing to fix it forces `(zip, city)` and `(zip,
street)`, and now the very reasonable rule "a given city/street
combination has exactly one ZIP" can only be checked by joining the two
tables back together. BCNF is not free by construction; it is free *when
the schema happens to cooperate*, and part of the job is knowing which
case you are in before you decompose.

**Constraints are the cheapest correctness mechanism you have**, in
order of what they enforce: `UNIQUE` enforces "no two rows share this
value," `CHECK` enforces an arbitrary row-local boolean, `FOREIGN KEY`
enforces "this value exists in that other table," and `EXCLUDE`
generalises `UNIQUE` to non-equality operators — the standard use is
preventing overlapping ranges (`EXCLUDE USING gist (room_id WITH =,
during WITH &&)` stops two bookings for the same room from overlapping in
time, something no combination of `UNIQUE` columns can express because
"overlaps" is not equality). None of these are free at write time. A
`FOREIGN KEY` costs an index lookup against the referenced table on every
insert or update of the referencing column — which is exactly why the
referenced side must already have a unique index (its primary key
usually supplies it) — and it takes a share lock on the referenced row
for the duration of the write, specifically to stop a concurrent
transaction from deleting the parent out from under it. That lock is a
detail Day 5 depends on; file it away now.

**Deliberate denormalisation is sometimes correct — and it always creates
enforcement debt.** `accounts.balance_minor` in this course's own schema
is the working example: an account's true balance is derived by summing
`ledger_entries` (credits minus debits), and `balance_minor` is a cached
copy of that sum, kept only because recomputing it from scratch on every
read would be wasteful. That is a legitimate denormalisation — reporting
and dashboards read `balance_minor` constantly and can tolerate the
staleness window. The debt is that nothing keeps it honest: a row-level
`CHECK (balance_minor >= 0)` cannot see `ledger_entries` at all, so it
cannot defend the invariant "balance never goes negative," and the schema
in this course ships that `CHECK` commented out for exactly this reason.
Real enforcement here needs either a trigger that recomputes the balance
transactionally on every posting, or an application invariant enforced at
the write path with the same rigor a constraint would carry — and Day 5
is where you find out which of those choices actually holds under
concurrent writers and which only looks like it does.

**Document modelling: embed versus reference, as four questions.**
MongoDB does not remove the need for this reasoning — it removes the
mechanism, `FOREIGN KEY` and `JOIN`, that used to make the reasoning
visible in the DDL. The decision is the same one relational modelling
always required, asked explicitly:

1. **Cardinality.** A handful of related items (an address, a shipping
   preference) embed cheaply. Thousands to unbounded (this merchant's
   entire product catalog) do not.
2. **Access pattern.** If every read of the parent needs the children too,
   embedding turns that into one document fetch instead of a fetch plus a
   lookup. If children are usually read independently of their parent,
   embedding forces you to either overfetch or reach inside an array with
   every query.
3. **Update frequency.** An embedded subdocument that changes often forces
   MongoDB to rewrite the whole parent document (or at least relocate it,
   if the update grows the document past its allocated space) on every
   change to a value that logically has nothing to do with the rest of
   the parent.
4. **The 16 MB document limit.** A hard ceiling, not a soft warning. It
   does not care how well-reasoned your cardinality and access-pattern
   answers were — an array with no upper bound will eventually reach it
   regardless.

**The unbounded-array antipattern**, and the two remedies. An array field
with no enforced maximum — `merchant_catalog.products`, in this
database's seed — grows without limit as the business it models grows,
and every one of the top merchants' catalogs is now tens of thousands of
entries deep, several megabytes per document and closing on the 16 MB
ceiling. Two remedies, not interchangeable:

- **Bucketing.** Split the array across multiple documents of bounded
  size (a `bucket_seq` field alongside `merchant_id` — a document holds
  at most, say, 1,000 products, and a merchant with more products gets
  more bucket documents instead). The collection stays flat, a query for
  "one merchant's products" is still a single-collection, indexed query,
  and no document can ever cross the size ceiling regardless of how large
  the merchant's true catalog grows.
- **The outlier pattern.** Embed by default, because most documents in
  the collection are small enough that embedding is already the right
  answer — and reference (or bucket) only the rare document that
  would otherwise blow past a size budget, flagging it so the application
  knows to fetch the overflow separately. This trades a small amount of
  branching logic in the application for not paying the referencing
  overhead on every document when only a few outliers need it.

Bucketing is today's lab, because the pathology here — power-law-skewed
merchant activity producing a small number of genuinely enormous
documents among many small ones — is precisely the shape the outlier
pattern is designed for, and choosing between the two remedies for that
exact shape is one of today's exercises.

**"Schemaless" describes the engine, not the application.** MongoDB
enforces no shape on a document at write time by default, and that fact
gets shortened, colloquially, to "MongoDB is schemaless" — which is a
claim about the write path, not about whether a schema exists. It does:
the schema still exists, every single time application code does
`doc.pricing.model` or aggregates on `products.price_minor`, because that
code is asserting a shape it needs the document to have. What changed is
not whether a schema exists — it is *where* it lives and *what enforces
it*. In PostgreSQL the schema lives in `information_schema` and a `NOT
NULL` violation is rejected before the row ever lands. In MongoDB, absent
`$jsonSchema` validation, the schema lives in the application code, and
nothing rejects a document that violates it — a typo'd field name, a
string where every other document has a number, an array where every
other document has a scalar, all land silently, and the first evidence
you get is a query or an aggregation stage that quietly returns wrong or
missing results for that one document. Treating a document store as
exempt from the anomaly analysis above because "it's schemaless" is
Mistake 6 on `STRATEGY.md`'s list for exactly this reason.

## Predict before you measure

Write down a number and one sentence of reasoning for each, before you
run anything:

1. **How many distinct `merchant_name` spellings exist per `merchant_id`
   in `wide_payments`, right now, before you touch anything.** (`SELECT
   merchant_id, count(DISTINCT merchant_name) FROM wide_payments GROUP BY
   1 HAVING count(DISTINCT merchant_name) > 1;` — the corrected version of
   this morning's instrument, grouping by `merchant_id` alone.) If your
   prediction was anything other than "zero rows returned," reconsider
   what a functional dependency claims versus what today's loaded data
   happens to show.
2. **The size of the largest `merchant_catalog` document, and how close
   it sits to the 16 MB limit.** Measure with `Object.bsonsize(db.
   merchant_catalog.findOne({merchant_id: 1}))` inside `mongosh` — do not
   guess from `products.length` alone, since BSON overhead per field name,
   repeated once per array element, is exactly what a naive "it's N small
   objects, multiply and done" estimate misses.
3. **The write-time cost of the foreign keys you are about to add to
   `payments_norm.payments`, as a percentage of insert time.** Bulk-load
   a batch of synthetic rows into a copy of the table with the FKs in
   place, `\timing` on; drop the FKs, reload the same batch, compare. A
   single-digit percentage is the usual outcome for a well-indexed
   referenced table — the cost is not the lookup itself, it is what
   happens when the referenced table's index is missing or the referenced
   row is under contention, which is not this lab's scenario but is
   worth remembering before you dismiss FKs as expensive by default.

## Lab

Work inside `ws`, against the `pg` and `mongo` services. There is no
`break.sh` today — `wide_payments` and the oversized `merchant_catalog`
documents were built once, at seed time, and are waiting for you exactly
as loaded.

**Reproduce the three anomalies on purpose, in a transaction you roll
back**, so `wide_payments` is untouched for the decomposition that
follows:

```sql
BEGIN;
UPDATE wide_payments SET merchant_name = 'MERCHANT #1, RENAMED'
  WHERE merchant_id = 1 AND row_id % 5 = 0;   -- touch a fifth of merchant 1's rows
SELECT merchant_id, count(DISTINCT merchant_name)
FROM wide_payments WHERE merchant_id = 1 GROUP BY 1;
ROLLBACK;
```

Then the deletion anomaly, on a merchant with exactly one payment:

```sql
BEGIN;
SELECT merchant_id, count(*) FROM wide_payments GROUP BY 1 HAVING count(*) = 1 LIMIT 1;
-- take the merchant_id printed above and delete its one row
DELETE FROM wide_payments WHERE merchant_id = <that merchant_id>;
SELECT * FROM wide_payments WHERE merchant_id = <that merchant_id>;
-- zero rows: everything this table ever knew about that merchant left
-- with the one payment that was carrying it
ROLLBACK;
```

The insertion anomaly needs no query at all — try to write down, on
paper, the `INSERT` you would need to record a new merchant with zero
payments in `wide_payments`, and notice which `NOT NULL` columns you
cannot supply a real value for.

**Then build `payments_norm`** and restructure `merchant_catalog`,
against the exact deliverables in `labs/day02/README.md`. That file
specifies the schema, the two `/tmp/answer` keys, and the catalog
restructuring target precisely — read it before you start, and read it
again after `labs/day02/verify.sh` tells you something is wrong, because
it names exactly which of the independent checks failed rather than
leaving you to guess.

Success signal: `labs/day02/verify.sh` exits `0`.

## Exercises

1. Write the full functional-dependency set for `wide_payments` —
   every `X → Y` you can justify from the columns and the join that built
   the table.
   **Hint:** start from the two candidate keys (every attribute is
   trivially dependent on either), then ask, for every remaining
   non-prime attribute, whether some *other* non-prime attribute already
   determines it before falling back to "only the whole key determines
   this."
   **Solution sketch:** `row_id → (everything)` and `payment_id →
   (everything)` are the two trivial FDs from the candidate keys.
   Non-trivially: `merchant_id → merchant_name, merchant_country,
   merchant_risk_tier` and `customer_id → customer_email,
   customer_country`. The four payment-method columns (`pm_brand,
   pm_last4, pm_exp_month, pm_exp_year`) have no smaller determinant
   visible among `wide_payments`'s own columns — the table never exposes
   a `payment_method_id` to depend on — so, strictly from this table's
   attributes, they are only dependent on the whole key. That gap matters
   for exercise 3.

2. Identify the highest normal form `wide_payments` satisfies, and the
   determinant whose dependency breaks the next one.
   **Hint:** check the forms in order and stop at the first one that
   fails — do not skip 2NF, but do notice why it cannot fail here.
   **Solution sketch:** 1NF holds (every column atomic) and 2NF holds
   trivially (both candidate keys are single columns, so there is no
   proper subset of a key to depend on partially). 3NF fails:
   `merchant_id` is non-prime and determines `merchant_name,
   merchant_country, merchant_risk_tier` — a transitive dependency,
   since `merchant_id` itself only exists in the table because
   `payment_id`/`row_id` determines it, not the other way around.
   `wide_payments` therefore satisfies 2NF and violates 3NF; `merchant_id`
   is the determinant (`customer_id` breaks it identically and
   independently — fixing one does not fix the other).

3. Decompose `wide_payments` to BCNF.
   **Hint:** peel off one transitive dependency at a time — project the
   determinant and its dependents into a new table, keyed on the
   determinant, and remove the dependents (but not the determinant) from
   what remains. Then look again at what is left over for a case exercise
   1 flagged as *not* forced by a visible FD.
   **Solution sketch:** peel `{merchant_id, merchant_name,
   merchant_country, merchant_risk_tier}` off into a merchants table keyed
   on `merchant_id`; peel `{customer_id, customer_email,
   customer_country}` off into a customers table keyed on `customer_id`.
   What remains — `payment_id, merchant_id, customer_id, amount_minor,
   currency, status, created_at, pm_brand, pm_last4, pm_exp_month,
   pm_exp_year` — has no non-superkey determinant left among its visible
   columns, so it is already technically in BCNF. Split the payment-method
   columns out anyway, on domain grounds rather than a provable FD: a
   payment method belongs to a customer and gets reused across many of
   that customer's payments, so leaving its four columns embedded in the
   payment-facts table reproduces the identical update-anomaly risk the
   moment a card's expiry changes and only some of that customer's
   payment rows get touched. Manufacture a surrogate
   `payment_method_id` with `row_number() OVER (ORDER BY customer_id,
   pm_brand, pm_last4, pm_exp_month, pm_exp_year)` applied to the
   `DISTINCT` combination of those five columns, and add a `UNIQUE
   (customer_id, brand, last4, exp_month, exp_year)` constraint on the new
   table so no later write can reintroduce a duplicate row for a card
   already on file. Be honest about what this construction cannot do,
   though: two genuinely different cards belonging to the same customer
   that happen to share brand, last four digits, and expiry are
   indistinguishable from one card in `wide_payments`'s own columns, and
   the `DISTINCT` step above silently merges them into a single
   `payment_method_id` before the `UNIQUE` constraint ever gets a chance
   to object — it is satisfied by construction, after the merge, and
   cannot detect a merge that already happened. Nothing in the lossless-
   join row-count check catches this either, since both of the original
   rows still join to exactly one `payment_methods` row either way. This
   is the same lesson as the split itself, one layer deeper: recovering a
   key that the source data never carried is a reconstruction, not a
   measurement, and a reconstruction can be wrong in a way the data used
   to build it cannot reveal. Full DDL is in `labs/day02/SOLUTION.md`.

4. Prove your decomposition is lossless by row-count reconciliation.
   **Hint:** the intersection-is-a-superkey theorem tells you the
   decomposition is structurally sound; it does not catch a typo'd join
   condition. Reconstruct and count.
   **Solution sketch:** join the decomposed tables back on their keys and
   compare `count(*)` and `count(DISTINCT payment_id)` against the same
   two numbers computed directly on `wide_payments`. Both must match
   exactly — a mismatched `count(*)` with a matching `count(DISTINCT
   payment_id)` means a join fanned out (a "unique" key on one side was
   not actually unique); a mismatched `count(DISTINCT payment_id)` means
   rows were dropped, most likely by an `INNER JOIN` against a table that
   is missing an entity `wide_payments` referenced.

5. Find a legitimate denormalisation already present in this database's
   normalised schema, and state its enforcement debt.
   **Hint:** it does not have to be inside `payments_norm` — look at what
   the top-level `accounts` table caches versus what it derives.
   **Solution sketch:** `accounts.balance_minor` is a cached, denormalised
   projection of summing `ledger_entries.amount_minor` by direction. It is
   legitimate because recomputing that sum on every balance read would be
   wasteful for a value read far more often than the ledger changes. Its
   enforcement debt: nothing keeps the cache honest under concurrent
   posting — a row-level `CHECK` cannot see `ledger_entries` at all, so
   the invariant "balance never goes negative" has no constraint defending
   it, only application discipline (or a trigger) that Day 5 tests directly
   against write skew.

6. Restructure `merchant_catalog` so no document's `products` array
   exceeds 1,000 entries, and justify choosing bucketing over fully
   referencing (a separate `products` collection, one document per
   product, joined by `merchant_id`).
   **Hint:** think about what a query for "page 3 of this merchant's
   catalog" costs under each shape — write-time cost is not the only cost
   that matters here.
   **Solution sketch:** referencing turns one 45,000-product document into
   45,000 one-product documents, each paying MongoDB's fixed per-document
   overhead (its own `_id`, its own place in the collection's index, its
   own WiredTiger page bookkeeping) on data that used to amortise that
   overhead across one document. Reading "this merchant's catalog" changes
   from one document fetch into a scan or index range read across tens of
   thousands of documents. Bucketing keeps the same access pattern — fetch
   this merchant's products — as a small, bounded number of larger
   documents (at most 1,000 products each) instead of an unbounded number
   of one-product documents, which is the better trade whenever the read
   pattern is "give me a page of this merchant's catalog" rather than
   "give me this one product by its own identity." Full restructuring code
   is in `labs/day02/SOLUTION.md`.

## Anti-patterns / common mistakes

- **Normalising to BCNF reflexively, without asking what queries the
  schema needs to serve.** BCNF is a correctness property against
  update anomalies, not a performance target, and a schema decomposed
  past the point any query pattern needs turns every read into a chain of
  joins that a single deliberate denormalisation (with its enforcement
  debt paid consciously, as in exercise 5) would have avoided.
- **Adding a foreign key without an index on the referencing column.**
  PostgreSQL creates the required unique index on the *referenced* side
  automatically (usually its primary key) but never indexes the
  referencing column for you — leaving `payments.merchant_id` unindexed
  means every delete or update on `merchants` triggers a sequential scan
  of `payments` to check for orphaned children, on top of the lock cost
  already described in Core concepts.
- **Treating MongoDB as exempt from this entire chapter.** Document
  modelling gets the identical anomaly treatment relational modelling
  does — cardinality, access pattern, and update frequency are the same
  three questions asked of embedding that they are of a foreign key, and
  the unbounded array in `merchant_catalog` is the same category of
  mistake as `wide_payments`'s transitive dependency: a fact placed
  somewhere the design does not actually support it growing.

## Teardown

See `labs/day02/teardown.md`.
