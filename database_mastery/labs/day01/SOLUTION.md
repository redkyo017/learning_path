# Day 1 — solution

Read this only after your own attempt, or after `verify.sh` has forced a
specific question you can't otherwise answer. This mirrors the chain
template in `journal.md` — the same shape every later day's `SOLUTION.md`
uses, adapted here because Day 1 measures rather than diagnoses: there is
no injected pathology, so "Fix applied" and "Proof the fix worked" are
not applicable, and say so rather than being omitted.

### Day 1 — three engines, one row, three storage decisions

**Predictions (written before running anything):**
- Ratio of `pg_total_relation_size('payments')` to summed column bytes:
  predicted 1.10 — assumed the tuple header and a little padding would
  account for most of the gap, and that the primary-key index was small
  enough not to matter much.
- Rows with an out-of-line `description`: predicted "a small number,
  maybe a few hundred" — no strong model for how "large text field" maps
  to a row count, only a guess that it would be rare.
- Fattest MySQL PK variant: predicted `pk_variant_natural`, on the theory
  that a composite three-column key is the widest of the three by
  construction, and assumed the UUID variant's single `CHAR(36)` column
  would land somewhere in between a `BIGINT` and a multi-column key.

**Symptom (verbatim, no interpretation):**
`pg_total_relation_size('payments')` reports roughly 1.85 GB. A query
summing `avg(pg_column_size(...))` across `payments`' ten columns and
multiplying by `reltuples` (≈5,000,000) reports roughly 1.23 GB of column
bytes. `information_schema.tables.INDEX_LENGTH` for the three MySQL
PK-variant tables reports three different figures, despite
`information_schema.tables.TABLE_ROWS` reporting 500,000 for all three.

**Layer:** storage

**Chain of evidence:**

1. Claim: the bloat ratio is not one thing, it is at least three things
   added together — tuple-header overhead, alignment padding, and the
   primary-key index that `pg_total_relation_size` counts but
   `pg_column_size` never sees. | Proof: `SELECT pg_total_relation_size
   ('payments'), pg_relation_size('payments'), pg_indexes_size
   ('payments');` → total ≈1.85 GB, bare heap ≈1.62 GB, indexes
   ≈0.19 GB. The heap alone already exceeds the ≈1.23 GB of raw column
   bytes by roughly 400 MB before the index is even added — that gap is
   the 23-byte tuple header (≈115 MB across 5,000,000 rows on its own)
   plus alignment padding plus per-row item-pointer overhead.
2. Claim: `payments` has exactly one column whose storage strategy can
   produce an out-of-line value in the first place, which makes
   `toast_column` unambiguous once you check the catalog rather than
   guess from the schema by eye. | Proof: `SELECT attname, attstorage
   FROM pg_attribute WHERE attrelid = 'payments'::regclass AND attnum > 0
   AND NOT attisdropped;` → every fixed-width column (`payment_id`,
   `merchant_id`, ..., `amount_minor`, `created_at`, `captured_at`)
   reports `attstorage = 'p'` (plain, never compressed or moved);
   `currency` and `status`, both short `text`/`char`, report `'x'`
   (extended: eligible, but in practice always short enough to stay
   inline); only `description` combines `'x'` storage with values long
   enough to actually cross the threshold.
3. Claim: `description` genuinely has rows stored out-of-line, not merely
   eligible in principle. | Proof: `SELECT reltoastrelid::regclass FROM
   pg_class WHERE relname = 'payments';` returns a real TOAST relation
   (not `0`), and `SELECT count(*) FROM payments WHERE pg_column_size
   (description) > 2000;` reports roughly 250,000 rows — almost exactly
   1 in 20 of the 5,000,000-row table.
4. Claim: the three MySQL PK-variant tables are not identical apart from
   their primary key — `pk_variant_uuid` also stores one column the
   other two don't, which confounds `DATA_LENGTH` as a way to compare
   them and is exactly why this measurement reads `INDEX_LENGTH`
   instead. | Proof: `SHOW CREATE TABLE pk_variant_uuid;` shows an
   eleventh column, `pk_uuid CHAR(36)`, holding the value promoted to
   primary key — `payment_id` is still present too, only no longer the
   key. `pk_variant_bigint` and `pk_variant_natural` have no such extra
   column; they repurpose columns already in the base `payments` schema
   as their key. `SELECT table_name, table_rows, data_length FROM
   information_schema.tables WHERE table_schema = 'payments' AND
   table_name LIKE 'pk_variant_%';` → all three report `table_rows =
   500000`; `pk_variant_uuid`'s `data_length` runs roughly 18 MB above
   what the same row count and remaining columns would otherwise
   predict — genuinely extra stored content (≈37 bytes × 500,000 rows),
   not an effect of primary-key width on the clustered index. `DATA_
   LENGTH` is therefore the wrong instrument for comparing these three
   tables; `INDEX_LENGTH` counts only secondary indexes and isn't
   touched by this extra column at all, which is why the size comparison
   below uses it.
5. Claim: InnoDB copies the full primary key into every secondary index
   leaf, so a wide key is not paid once at the clustered index — it is
   paid again, per row, inside `ix_..._status` and `ix_..._created_at`
   on all three tables. | Proof: `SHOW CREATE TABLE pk_variant_uuid;`
   shows the primary key as `pk_uuid CHAR(36)`; the same two secondary
   indexes exist on all three tables by construction (identical `CREATE
   INDEX` statements in the loader), so the only variable across the
   three tables' `INDEX_LENGTH` is the byte width of whatever value gets
   silently appended to every leaf entry — the primary key, not a
   compact row pointer the way a PostgreSQL index would use.
6. Claim: the three primary keys' widths predict the ranking, and the gap
   is bigger than "a few extra bytes" because it is paid twice — once per
   secondary index, and there are two. | Proof: `pk_variant_bigint`'s key
   is an 8-byte `BIGINT`. `pk_variant_natural`'s key is `(merchant_id
   BIGINT, created_at DATETIME(6), payment_id BIGINT)` — three columns,
   roughly 24 bytes together. `pk_variant_uuid`'s key is a single
   `CHAR(36)` — 36 characters, all ASCII, so InnoDB's variable-length
   storage for a multi-byte charset column stores it as roughly 37 bytes
   (36 data bytes plus a length prefix), not the 144 bytes a naive
   `36 × 4` (utf8mb4's max bytes per character) calculation would
   suggest. `SELECT table_name, index_length FROM information_schema.
   tables WHERE table_schema = 'payments' AND table_name LIKE
   'pk_variant_%';` reports, representatively: `pk_variant_bigint` ≈
   41 MB, `pk_variant_natural` ≈ 68 MB, `pk_variant_uuid` ≈ 96 MB —
   ranked exactly by key width, and the UUID variant's roughly 2.3×
   inflation over the bigint baseline tracks its roughly 4.6×-wider key
   applied across two secondary indexes rather than one.

**Diagnosis:** `bloat_ratio` is driven by fixed per-row overhead (tuple
header, alignment padding) plus the primary-key index, all of which
`pg_total_relation_size` counts and a naive column-byte sum does not —
there is no single "the bloat," only several additive, individually
explicable costs. `toast_column` is `description`, and it is the only
column in the table whose storage class (`attstorage <> 'p'`) makes
TOAST possible in the first place — this is a catalog fact, not an
inference from column type names. `fattest_pk` is `pk_variant_uuid`: on
InnoDB, a secondary index's leaf entry is `(indexed column value, primary
key value)`, not `(indexed column value, physical row pointer)`, because
the primary key is the only address a page split inside the clustered
index cannot invalidate. Whatever the primary key is, its width is
therefore not an isolated cost paid once — it is copied into the leaf of
every secondary index the table carries, and `pk_variant_uuid`'s 36-byte
key pays that cost twice (once per secondary index) at roughly 4.6× the
width of the `BIGINT` baseline, which is what actually decides the
ranking, not "UUIDs are generally bigger."

**Fix applied:** Not applicable — Day 1 measures a live system rather
than repairing an injected pathology; there is nothing to fix here. The
corrective drill this evidence chain sets up is the one for InnoDB
primary-key selection generally: sum a candidate key's width across
every secondary index the table will carry, not the key judged in
isolation, before choosing it.

**Proof the fix worked (same instrument re-read):** Not applicable, for
the same reason.

**Prediction error and what it tells me:** The bloat-ratio prediction of
1.10 missed by roughly 0.35–0.40 against a true ratio nearer 1.45–1.50 —
the model that produced 1.10 accounted for the tuple header but forgot
the primary-key index entirely, which `pg_total_relation_size` always
includes. The TOAST-row-count prediction of "a few hundred" missed by
close to three orders of magnitude against the true ≈250,000 — there was
no real model behind that guess at all, only an intuition that "large
text field" sounds rare, which the seed's actual 1-in-20 rate falsifies
outright. The fattest-PK prediction picked `pk_variant_natural` by
reasoning about column *count* (three columns beats one) rather than
column *bytes* (24 bytes loses to 36) — a reminder that "wider key" means
bytes stored, not fields declared, and that a single `CHAR(36)` can
outweigh a three-column composite key built from narrower types.

**What I would check first next time:** For any InnoDB schema decision
involving a primary key, check `information_schema.tables.INDEX_LENGTH`
across every secondary index the table already has (or will have) before
trusting an intuition about key width — and for any PostgreSQL bloat
question, start from `pg_total_relation_size` minus `pg_relation_size`
minus `pg_indexes_size` to see how much of the gap is indexes before
reasoning about tuple headers and padding at all.
