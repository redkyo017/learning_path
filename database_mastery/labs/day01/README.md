# Day 1 lab — storage, and the instruments that read it

## Goal

Measure three real properties of the seeded dataset, straight from each
engine's own catalog — nothing here is broken, and there is no
`break.sh`. This lab establishes the answer format every remaining day's
lab reuses, so get its shape exactly right even though the content is
specific to today.

There are **three deliverables**, written to `/tmp/answer` inside the
`ws` container, one `key=value` line per deliverable, keys lowercase, no
spaces around `=`:

```
bloat_ratio=<total relation size ÷ summed column bytes, 2 decimal places>
toast_column=<the column name stored out of line>
fattest_pk=<pk_variant_bigint | pk_variant_uuid | pk_variant_natural>
```

- `bloat_ratio` is `pg_total_relation_size('payments')` divided by the
  summed, per-row average `pg_column_size` of `payments`' own columns.
  `verify.sh` recomputes this itself and accepts your answer within
  **±0.15** of its own figure — your summation method (which columns you
  add up, in what order, whether you average per-column or per-row first)
  can legitimately land on a slightly different number without being
  wrong, and this tolerance is sized for that, not for a guess.
- `toast_column` is the name of the one `payments` column whose values
  PostgreSQL is moving out of the main table under TOAST.
- `fattest_pk` names whichever of the three MySQL PK-variant tables,
  each loading the same 500,000 payments, carries the largest total
  secondary-index size. Measure `INDEX_LENGTH` specifically, not
  `DATA_LENGTH` — one of the three tables also stores one additional
  column the other two don't (the value that serves as its primary key),
  which inflates its `DATA_LENGTH` for a reason that has nothing to do
  with the secondary-index mechanism this lab is measuring.

## Instruments, not queries

This README does not hand you the queries; Day 1's content
(`content/day01.md`) and the catalog primer
(`content/primers/catalog-field-reference.md`) name the instruments and
leave the exact query to you:

- `pg_total_relation_size(...)` and `pg_column_size(...)` for the ratio.
- The catalog that records each PostgreSQL column's storage strategy
  narrows the field but doesn't finish the job: several `payments`
  columns are *eligible* for TOAST (any variable-length type defaults to
  `extended` storage), while the deliverable asks which one is
  *actually* stored out of line — a property of the values a given load
  produced, not of the column's declared type. Confirming that requires
  measuring real value sizes (`pg_column_size` again, per candidate
  column) rather than stopping at eligibility.
- `information_schema.tables` (`#information_schematables-and-innodb_index_stats`
  in the catalog primer) for each MySQL table's secondary-index footprint,
  for `fattest_pk`.

## Success signal

`labs/day01/verify.sh` exits `0`.

## How to run

From the repository root, with the stack up and seeded
(`labs/stack/README.md` and `labs/stack/seed/README.md` if you haven't
done this yet):

```bash
docker compose -p dbmastery exec ws bash
```

Work the three measurements from inside `ws`, against `pg` and `my` by
their service names (see `labs/stack/README.md`, "Connecting"). Write
your predictions to `journal.md` **before** you run a single query — see
`STRATEGY.md`, "The daily loop," step 3 — then measure, then write
`/tmp/answer` inside `ws`:

```sh
ws$ cat > /tmp/answer <<'EOF'
bloat_ratio=1.00
toast_column=amount_minor
fattest_pk=pk_variant_bigint
EOF
```

(That block shows the syntax only — none of those three values is
actually correct for this dataset. Compute your own from the catalogs.)

Then, from the repository root, not inside `ws`:

```bash
bash labs/day01/verify.sh
```

If it exits non-zero, it names exactly which of the three deliverables is
wrong and nothing else — it never prints the value it computed, on
success or failure. Re-measure that one instrument and try again.
`SOLUTION.md` has the full chain of evidence if you get stuck, but
reading it before your own attempt skips the lesson.
