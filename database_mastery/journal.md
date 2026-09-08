# Journal — evidence chains

One entry per lab. The prediction is written **before the lab is run**,
and the evidence chain is written **before any fix is attempted** — see
`STRATEGY.md`, The daily loop, steps 3 and 5. Copy the chain template
below for each new incident. Every `SOLUTION.md` under `labs/dayNN/`
mirrors this exact skeleton, so a diagnosis you write here should read
the same as the one you'd find there if you gave up and looked.

## Chain template

```markdown
### Day N — <incident in five words>
**Predictions (written before running anything):**
- <quantity>: <predicted value>
**Symptom (verbatim, no interpretation):**
**Layer:** storage | logical | access method | planner | concurrency | durability | distribution
**Chain of evidence:**
1. Claim: … | Proof: `<query>` → `<the output that proves it>`
2. …
**Diagnosis:**
**Fix applied:**
**Proof the fix worked (same instrument re-read):**
**Prediction error and what it tells me:**
**What I would check first next time:**
```

## Day 1 — example entry

### Day 1 — wide natural key fattens every secondary index

**Predictions (written before running anything):**
- Combined `INDEX_LENGTH` across both secondary indexes on
  `pk_variant_bigint`, in MB: predicted 40
- Same, for `pk_variant_natural`, in MB: predicted 45 — assumed the
  difference would be marginal since the natural key only adds two
  columns beyond the surrogate's one.

**Symptom (verbatim, no interpretation):**
Two 500,000-row MySQL tables, `pk_variant_bigint` and
`pk_variant_natural`, carry the same `payment_id <= 500000` slice of
`payments` and the same two secondary indexes (`..._status`,
`..._created_at`), differing only in primary key. `SELECT table_name,
index_length FROM information_schema.tables WHERE table_schema =
'payments' AND table_name IN ('pk_variant_bigint', 'pk_variant_natural');`
reports `pk_variant_bigint` at roughly 41 MB and `pk_variant_natural` at
roughly 68 MB.

**Layer:** storage

**Chain of evidence:**
1. Claim: both tables hold identical logical data, so the size gap isn't
   a row-count artifact. | Proof: `SELECT table_name, table_rows FROM
   information_schema.tables WHERE table_schema = 'payments' AND
   table_name IN ('pk_variant_bigint', 'pk_variant_natural');` → both
   report `table_rows = 500000`.
2. Claim: InnoDB secondary indexes store the primary key's value as their
   row pointer, not a physical offset, so the key's width is repeated in
   every secondary index the table carries, not paid once. | Proof:
   `SHOW CREATE TABLE pk_variant_bigint;` and `SHOW CREATE TABLE
   pk_variant_natural;` show byte-for-byte identical `CREATE INDEX`
   statements (one index on `status`, one on `created_at`) apart from the
   table name — the only thing that can differ between the two tables'
   leaf entries is whatever gets silently appended to each one: the
   primary key.
3. Claim: the natural key is roughly three times the surrogate's width,
   which the prediction above treated as marginal. | Proof:
   `pk_variant_bigint`'s key is a single 8-byte `BIGINT` (`payment_id`);
   `SHOW CREATE TABLE pk_variant_natural;` shows `PRIMARY KEY
   (merchant_id, created_at, payment_id)` — three columns, roughly 24
   bytes together, not the near-parity the prediction assumed.
4. Claim: the measured gap (68 / 41 ≈ 1.66×) is smaller than the raw 3×
   key-width ratio because every leaf entry also carries the indexed
   column's own bytes (`status` or `created_at`), which are identical
   between the two tables and dilute the ratio — the key-width difference
   does not translate one-for-one into total index size. | Proof: solving
   `(x + 24) / (x + 8) ≈ 1.66` for the shared per-entry payload `x` gives
   `x ≈ 16` bytes, the right order of magnitude for a short `status`
   value or an 8-byte `created_at` value plus per-entry overhead — small
   next to the 16-byte gap between the two keys, but not negligible
   enough to make the ratio track key width alone.

**Diagnosis:** The natural composite key is copied into both of the
table's secondary indexes as InnoDB's row pointer, so its 16 extra bytes
per row (24 versus 8) are paid twice, not once — the direct cause of the
gap. The gap is smaller than a naive 3× extrapolation because each leaf
entry also carries the indexed column's own bytes, a fixed cost the two
tables share, which dilutes the ratio below the raw key-width ratio.

**Fix applied:** Kept `pk_variant_bigint`'s `BIGINT` surrogate as
`payments`' actual primary key, and would carry `(merchant_id,
created_at)` as a plain secondary index rather than fold either column
into the primary key, if a query needed to range-scan by merchant and
date.

**Proof the fix worked (same instrument re-read):** `SELECT table_name,
index_length FROM information_schema.tables WHERE table_schema =
'payments' AND table_name = 'pk_variant_bigint';` reports roughly 41 MB
across both secondary indexes — already measured above as the low-cost
variant, and nothing further to change.

**Prediction error and what it tells me:** I predicted a 5 MB gap between
the two options (40 vs. 45); the measured gap was roughly 27 MB, more
than 5× the predicted difference. The model I was actually carrying
treated the natural key's two extra columns as "a little wider," not as
fully-priced width appended to two independent secondary indexes at
once.

**What I would check first next time:** Before accepting any primary key
candidate on an InnoDB table, sum its width across every secondary index
the table will carry — not the key judged on its own — because that
sum, not the key's standalone size, is what the storage cost actually
is.
