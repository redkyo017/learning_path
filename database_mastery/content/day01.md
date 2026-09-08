# Day 1 — Storage, and the Instruments That Read It

**Layer:** storage
**Budget:** 3 h — 1 h instruments, 2 h storage and lab

## Why this matters

Every later lesson in this path is downstream of what a page is. Index
size is a function of how many pages a B-tree needs. Bloat is dead space
inside pages that scans still have to read past. The planner's cost model
is, almost entirely, a count of pages it expects to touch. Concurrency
control decides which version of a page's contents a transaction is
allowed to see. Replication ships pages, or the log of changes to them,
across the network. An engineer who has never looked inside a page
reasons about all five of those by analogy to something else — usually
whatever mental model they built from a diagram years ago — instead of
from the structure itself. Today replaces the diagram with the structure.

The concrete version of that claim, and the day's lab: three engines
holding the same logical row make three different physical decisions
about it. PostgreSQL will silently move one of a payment's own columns
out of its row entirely, once that particular value grows past 2 KB.
InnoDB will not let you
choose a primary key without paying its width again, in full, inside
every secondary index the table carries. WiredTiger will report two
different sizes for the same collection depending on whether you ask
about the data or the bytes on disk. None of the three is a bug, and none
of the three is optional to know — they are the shape of the storage
layer in each engine, and everything you do with these databases sits on
top of that shape whether you have looked at it or not.

## Read the instrument first

Before any of that is named, read three rows the way the engine actually
stores them:

```
payments=# \x
Expanded display is on.
payments=# SELECT ctid, xmin, xmax, * FROM payments LIMIT 3;
-[ RECORD 1 ]-----+------------------------
ctid              | (0,1)
xmin              | 743
xmax              | 0
payment_id        | 1
merchant_id       | 842
customer_id       | 219481
payment_method_id | 3021
amount_minor      | 48213
currency          | USD
status            | captured
created_at        | 2024-03-11 14:22:07+00
captured_at       | 2024-03-11 15:47:12+00
description       | Order payment 1
-[ RECORD 2 ]-----+------------------------
ctid              | (0,2)
xmin              | 743
xmax              | 0
payment_id        | 2
merchant_id       | 119
customer_id       | 384022
payment_method_id | 1187
amount_minor      | 9040
currency          | GBP
status            | pending
created_at        | 2024-01-29 09:03:41+00
captured_at       |
description       | Order payment 2
-[ RECORD 3 ]-----+------------------------
...
(3 rows)
```

Three columns came back that were never in your `SELECT *` list's mental
model of "the row": `ctid`, `xmin`, `xmax`. Every PostgreSQL row carries
these whether or not a query ever asks for them.

`ctid` is a physical address: `(page number, item pointer offset)`. `(0,1)`
means "page 0, the first item pointer on it." It is not a stable identifier
— `VACUUM FULL`, `CLUSTER`, and an ordinary `UPDATE` (which writes a new
row version rather than modifying the old one in place) can all change a
row's `ctid`. It exists so an index has something concrete to point back
at, and it is the thing every plan node that says "Heap Fetch" or
"Bitmap Heap Scan" is dereferencing.

`xmin` and `xmax` are the transaction IDs that created and, if applicable,
deleted this row version — the two fields that make MVCC possible.
`xmin = 743` means transaction 743's `INSERT` produced this exact row
version. `xmax = 0` means no transaction has deleted or superseded it yet;
once one does, that transaction's ID lands in `xmax`, and the row version
stays on disk, invisible to new snapshots but not yet reclaimed, until
vacuum gets to it. All three of these fields live inside a structure you
have not seen yet: the tuple header, next.

## Core concepts

**The page.** PostgreSQL storage is one fixed unit, repeated: an 8 KB
page (`current_setting('block_size')`, not adjustable without a
recompile). Every page opens with a page header — checksum, free-space
pointers, a flags word — followed by an array of item pointers (`lp_off`,
`lp_len`, a few flag bits each) that grows forward starting right after
the header. Actual tuple data grows backward from the end of the page. The
gap in the middle is free space, and it is what a low `fillfactor` (below)
deliberately keeps around. An index pointing at a row does not store the
row's bytes — it stores a `ctid`, and the engine walks to that page,
reads the item pointer at that offset, and follows it to the tuple.

**The tuple header.** Every stored row version — not the table, every
individual version of every row — pays roughly 23 bytes before a single
column's value begins: `xmin`, `xmax` (8 bytes together), a command ID
field reused for `xmax`'s status once frozen, the `ctid` back-reference
used during update chains, two flag words (`infomask`/`infomask2`, which
record things like "this row has a null bitmap" or "this row's `xmax` is
a lock, not a delete"), and `t_hoff`, the offset to where user data
actually starts. A table with three narrow columns pays this 23 bytes
against a genuinely small payload — proportionally, its overhead is much
higher than a wide table's. This is why row count alone never predicts
table size; row *width*, including this fixed cost, does.

**Alignment padding, and why column order changes row width.** After the
tuple header, PostgreSQL aligns each column to its type's natural
boundary — a 4-byte `int` starts on a 4-byte boundary, an 8-byte `bigint`
or `timestamptz` on an 8-byte boundary — inserting padding bytes before a
column if the previous column left it misaligned. Declare `(flag boolean,
amount bigint)` and the single-byte `flag` forces 7 bytes of dead padding
before `amount` can start on its 8-byte boundary; declare `(amount bigint,
flag boolean)` and no padding is needed at all, because the 1-byte column
trails a properly-aligned 8-byte one instead of preceding it. Same
columns, same data, different `CREATE TABLE` order, different row width —
purely from where the padding falls. Exercise 1 below asks you to prove
this with a real reordering.

**Fillfactor and HOT updates.** `fillfactor` sets what percentage of a
page PostgreSQL fills on insert (default 100 — pack pages completely).
Setting it below 100 leaves free space on every page on purpose, so a
later `UPDATE` that doesn't touch an indexed column can write its new
version on the *same page* as the old one — a Heap-Only Tuple (HOT)
update. A HOT update needs no new index entries at all, because every
index pointing at the old `ctid` still resolves to the same page, where a
forwarding chain inside the page finds the new version. Pack pages to
100% full and every such update is forced onto a different page instead,
which does need new index entries, on every index the table carries.

**TOAST.** A row cannot span pages, so a single 8 KB page caps how large
one row's stored representation can be — the actual practical limit
PostgreSQL enforces is closer to 2 KB per attribute before it intervenes.
Crossing that threshold, for one column's value at a time, triggers TOAST
(The Oversized-Attribute Storage Technique) in order: first, try
compressing the value in place with `pglz`; if it's still too large after
compression, or doesn't compress well, move it out of the row entirely
into a companion TOAST table, leaving an 18-byte pointer behind in the
original row. A query that never touches that column reads only the
pointer's 18 bytes and pays nothing extra. A query that does touch it pays
a second page fetch, into the TOAST table, to reassemble the value — real
latency the row's own size gave no warning of, because the row you can
see with `SELECT *` no longer holds the data at all.

**InnoDB row formats: the same overflow, a different residue.** MySQL 8.4
supports four `ROW_FORMAT` values on an InnoDB table — `DYNAMIC` (the
default since 5.7), `COMPACT` (the default before that), `REDUNDANT`
(the original pre-5.0 layout, kept for compatibility), and `COMPRESSED`.
You do not have to infer which one a table is actually using from its
`CREATE TABLE` statement — `information_schema.TABLES.ROW_FORMAT` reports
it directly, keyed on `TABLE_SCHEMA` and `TABLE_NAME` (`... WHERE
TABLE_SCHEMA = 'payments' AND TABLE_NAME = 'payments'`), and `SHOW TABLE
STATUS LIKE 'payments'` reports the same figure without touching
`information_schema` at all. Both work with an ordinary user's ordinary
privileges; `information_schema.INNODB_TABLES` (a different view, despite
the similar name) requires the global `PROCESS` privilege, which this
stack's `dbm` user — granted privileges scoped to the `payments` database
only — does not have, so a query against it fails with `ERROR 1227:
Access denied` rather than returning a row.

Every one of the four formats hits the same wall TOAST exists to handle:
a page has fixed capacity, so InnoDB caps how much of a row's
variable-length data stays inline, and past that cap the value moves to
a separate overflow page with a pointer left behind in the clustered
index leaf — the identical move, made by a different engine. What
differs is what the pointer leaves behind. `COMPACT` and `REDUNDANT`
keep the first 768 bytes of the off-page value inline ahead of a
20-byte pointer to the rest; `DYNAMIC` and `COMPRESSED` keep no prefix
at all, only the 20-byte pointer. A table carrying several long `TEXT`
columns per row packs far more rows into a `DYNAMIC` page than a
`COMPACT` one, because none of those 768-byte prefixes are competing
for room in the same 16 KB.

The threshold that triggers this is InnoDB's answer to PostgreSQL's
2 KB `TOAST_TUPLE_THRESHOLD`: a page holds 16 KB by default, and InnoDB
requires at least two rows fit on every page, so a single row's inline
portion cannot exceed roughly half of it — a practical ceiling near
8 KB before variable-length columns start moving off-page. Same
problem, a threshold several times larger, and — for `COMPACT` and
`REDUNDANT` — a residue left inline that PostgreSQL's 18-byte TOAST
pointer never carries at all.

`COMPRESSED` layers zlib compression on top of the `DYNAMIC` layout,
paying CPU to compress and decompress pages on every read and every
write. It is rarely the right default — reach for it only against a
specific, measured storage constraint, not out of habit.

**InnoDB: the table is the primary key.** PostgreSQL's heap is unordered
— every index, primary key included, points into it by physical address.
InnoDB does something structurally different: it has no separate heap at
all. The table itself *is* a B-tree clustered on the primary key, with
full row data sitting in the leaf pages of that tree. There is no second
place the row lives. The consequence that matters most: a secondary
index in InnoDB cannot point at a physical row location the way a
PostgreSQL index points at a `ctid`, because a page split or a row move
inside the clustered index would silently invalidate that pointer.
Instead, every secondary index leaf stores the row's *primary key value*
as its pointer, and looks the row up by re-descending the clustered index
with that key on every secondary-index read. Whatever you choose as an
InnoDB primary key is not paid once — it is copied into every secondary
index the table has, in full, forever. That is the single most
consequential schema decision available in MySQL, and it is this day's
lab.

**WiredTiger: documents in a B-tree, compressed by default.** MongoDB's
default storage engine keeps each collection as a B-tree keyed by `_id`,
with documents as the leaf values — conceptually closer to InnoDB's
clustered layout than to PostgreSQL's heap. WiredTiger also compresses
blocks on disk by default (snappy, unless configured otherwise), which is
why `size` (the logical, uncompressed byte count of the documents) and
`storageSize` (what's actually on disk after compression) on the same
collection are two genuinely different numbers, not two names for the
same fact.

The catalog is where every one of these claims stops being an assertion
and becomes something you can check. `content/primers/catalog-field-reference.md`
covers the specific views this day's lab reads —
`#pg_class-relpages-and-reltuples`, `#pgstattuple`,
`#information_schematables-and-innodb_index_stats`, and `#collstats-and-dbstats`
— in the depth this file doesn't repeat.

## Predict before you measure

Write these in `journal.md`, with your one-sentence reasoning for each,
before you run a single query:

1. The ratio of `pg_total_relation_size('payments')` to the summed
   `pg_column_size` of its columns (across all rows, not one sampled row).
   `pg_total_relation_size` counts the main table, its TOAST table, and
   every index it carries — decide what you think is inflating that ratio
   above 1.00 before you compute it.
2. How many of the 5,000,000 `payments` rows have a value stored
   out-of-line — TOASTed into the companion table rather than kept
   inline. Nothing here tells you which column that is; identifying it
   is `toast_column`, part of what the lab asks you to measure.
3. Which of the three MySQL tables — `pk_variant_bigint`,
   `pk_variant_uuid`, `pk_variant_natural` — has the largest total
   secondary-index size, and by roughly what factor over the smallest of
   the three. All three tables load the same 500,000 payments; what
   changes between them is what serves as the primary key.

## Lab

`labs/day01/README.md` has the full instructions. In outline: the stack
is already seeded (bring it up per `labs/stack/README.md` if you haven't),
there is no `break.sh` — nothing is broken, you are measuring a live
system — and the goal is three numbers, written to `/tmp/answer` inside
the `ws` container as `key=value` lines: `bloat_ratio`, `toast_column`,
`fattest_pk`. This is the first lab in the path, and the `/tmp/answer`
format it establishes — one `key=value` per line, keys lowercase, no
spaces around `=` — is what every remaining day's lab reuses without
restating it. Get the shape right here.

`labs/day01/verify.sh` computes all three answers itself, live, from the
same catalogs this file points at — it does not have a stashed value to
check you against, because nothing here was broken on purpose. Run it
once you've written `/tmp/answer`; it tells you which of the three
deliverables is wrong, nothing more.

## Exercises

1. Reorder `wide_payments`' (or a scratch copy of it) column list so that
   fixed-width columns of the same alignment class sit together, and prove
   the row got narrower using `pg_column_size`.

   **Hint:** alignment padding happens at boundaries — a `SMALLINT` or
   `BOOLEAN` sitting right before a `BIGINT` or `TIMESTAMPTZ` forces
   padding that the same column placed after it would not.
   **Solution sketch:** `CREATE TABLE scratch AS SELECT * FROM
   wide_payments LIMIT 0;` gives you a template; drop it, redeclare it
   with all 8-byte columns first and the narrow `SMALLINT`/`CHAR(2)`/
   `CHAR(4)` columns last, reload a few thousand rows into both versions,
   and compare `SELECT avg(pg_column_size(t.*)) FROM wide_payments t;`
   against the same expression against your reordered copy. The
   reordered copy's average row size is smaller by roughly the padding
   the original ordering was wasting per row.

2. Find the table in this schema with the worst dead-tuple ratio.

   **Hint:** `pg_stat_user_tables` (`content/primers/catalog-field-reference.md#pg_stat_user_tables`)
   has both `n_live_tup` and `n_dead_tup` — the ratio, not either number
   alone, is what tells you how much of a table's storage is currently
   dead weight.
   **Solution sketch:** `SELECT relname, n_dead_tup, n_live_tup,
   round(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0), 4) AS
   dead_ratio FROM pg_stat_user_tables ORDER BY dead_ratio DESC;`. Right
   after a fresh seed, expect every ratio to be low or zero — nothing has
   churned yet — which is itself worth noticing: this instrument reports
   history, not a property of the schema.

3. Explain why `SELECT count(*) FROM payments` is slow, while
   `SELECT count(*) FROM payments WHERE <indexed column filters to
   everything>` using an index-only scan may not pay the same cost.

   **Hint:** an index entry alone cannot tell the engine whether the row
   it points at is visible to *this* transaction's snapshot —
   `content/primers/explain-field-reference.md#explain-heap-fetches` names
   the exact mechanism that lets an index-only scan sometimes skip the
   check anyway.
   **Solution sketch:** a plain heap scan must visit every page and check
   `xmin`/`xmax` on every row version against the current snapshot — there
   is no shortcut, because visibility is a per-row-version fact, not a
   per-index-entry one. An index-only scan can skip visiting the heap
   only when the visibility map marks the *page* as all-visible (every
   row on it is known good for every snapshot); when that holds, the
   index alone is enough to answer a count. `EXPLAIN (ANALYZE, BUFFERS)`
   on both shows the difference directly as a "Heap Fetches" count on the
   index-only plan — zero when the visibility map earns the shortcut,
   nonzero (and correspondingly slower) when it can't.

4. Compute how many `ledger_entries` rows should fit in one 8 KB page,
   from the table's column list alone, and check your arithmetic against
   `pg_class.relpages` and `reltuples`.

   **Hint:** sum the fixed-width columns, add the roughly-23-byte tuple
   header and a per-row item pointer (4 bytes), and divide 8192 by that —
   `content/primers/catalog-field-reference.md#pg_class-relpages-and-reltuples`
   is the instrument that checks the estimate, not the source of it.
   **Solution sketch:** `ledger_entries` is eight fixed-width columns —
   roughly 41 bytes of column data once you add them up, plus the ~23-byte
   header and ~4-byte item pointer, near 68 bytes per row — giving a
   back-of-envelope estimate in the neighborhood of 8192 / 68 ≈ 120 rows
   per page. `SELECT reltuples / relpages FROM pg_class WHERE relname =
   'ledger_entries';` reports the engine's own effective rows-per-page
   figure; expect it lower than your estimate, because it is diluted by
   `fillfactor` headroom and any partially-empty pages at the end of the
   table, not because your column-width arithmetic was wrong.

5. Show that updating a TOASTed value rewrites more than updating an
   inline one does.

   **Hint:** TOAST has no partial-update path — changing one byte of a
   large out-of-line value still means writing the whole new (possibly
   re-chunked) value into the TOAST table, while an ordinary inline
   column's update touches only the one row version.
   **Solution sketch:** using whichever column you identified as
   `toast_column`, pick one `payment_id` whose value in that column is
   short (inline) and one whose `pg_column_size(<that column>)` is large
   (out-of-line), note `pg_current_wal_lsn()` before each, run an `UPDATE
   ... SET <that column> = <that column> || ' '` on each individually,
   and read `pg_current_wal_lsn()` again. The out-of-line row's update
   advances the WAL position by many times more bytes than the inline
   row's update, because the engine wrote an entirely new TOAST value
   (and its chunk rows), not one modified attribute.

6. In MongoDB, explain the gap between `size` and `storageSize` on
   `payment_events`.

   **Hint:** `content/primers/catalog-field-reference.md#collstats-and-dbstats`
   names the mechanism; one of these two numbers reflects compression and
   one does not.
   **Solution sketch:** `db.payment_events.stats()` reports `size` (the
   logical, uncompressed size of the stored BSON documents) and
   `storageSize` (the actual on-disk footprint after WiredTiger's default
   snappy block compression). `payment_events` documents are structurally
   repetitive — same field names, similar `payload` shapes, clustered
   `type` values — exactly the redundancy a block compressor exploits, so
   expect `storageSize` noticeably below `size`, not approximately equal
   to it.

7. Read `ROW_FORMAT` for the MySQL `payments` table and reason
   conditionally about what would change if one of its variable-length
   columns carried a value long enough to cross InnoDB's off-page
   threshold, under `COMPACT` instead of the format actually in force.

   **Hint:** `ROW_FORMAT` only matters for columns whose values can
   actually get long — a fixed-width column or one whose values always
   stay short never reaches InnoDB's inline ceiling regardless of
   format. Find `payments`' variable-length columns, and reason about
   which of those, if any given row's value in it grew large enough,
   would be affected by a row format's prefix rule. You do not need to
   find a row that actually crosses the threshold to reason correctly
   about what would happen if one did.
   **Solution sketch:** `SELECT TABLE_SCHEMA, TABLE_NAME, ROW_FORMAT
   FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'payments' AND
   TABLE_NAME = 'payments';` (or `SHOW TABLE STATUS LIKE 'payments';`)
   reports `DYNAMIC`, MySQL 8.4's default — both readable without the
   global `PROCESS` privilege `information_schema.INNODB_TABLES` would
   require and this stack's `dbm` user does not have. Conditionally: if
   a variable-length column's value crossed InnoDB's inline ceiling,
   `DYNAMIC` (and `COMPRESSED`) would leave only a 20-byte pointer
   inline, while `COMPACT` (and `REDUNDANT`) would additionally keep the
   first 768 bytes of that value inline ahead of the pointer — same
   bytes on the overflow page, a wider clustered-index leaf page per
   affected row under `COMPACT`, and correspondingly fewer rows per page
   in that index. Check this table's actual values before assuming that
   difference shows up here, though: this table mirrors the same rows
   PostgreSQL's `payments` holds, and whichever column crosses
   PostgreSQL's much smaller ~2 KB `TOAST_TUPLE_THRESHOLD` (identified
   separately, as `toast_column`) tops out at roughly 3 KB — a full row
   built around it comes to only about 3.2 KB, comfortably under
   InnoDB's own inline ceiling near 8 KB (half of a 16 KB page). Nothing
   in this table's rows actually goes off-page under any `ROW_FORMAT`,
   so switching between `DYNAMIC` and `COMPACT` here changes nothing
   measurable — the reasoning above is what to carry to a table where a
   column's values are actually long enough to cross that line, not a
   difference to go hunting for in this one.

## Anti-patterns / common mistakes

- Trusting a monitoring dashboard's "table size" figure without checking
  whether it includes indexes, TOAST, and free space, or only the heap.
  `pg_total_relation_size` and a bare `pg_relation_size` answer visibly
  different questions, and a dashboard that doesn't say which one it's
  showing is not neutral — it has already picked one for you.
- Assuming a UUID primary key is a free, purely logical choice, with no
  storage consequence beyond "16 bytes instead of 8." On InnoDB, that
  width is not paid once at the clustered index; it is paid again inside
  every secondary index the table carries, and a UUID's effectively
  random insert order also defeats the sequential-append pattern a
  `BIGINT` surrogate gets for free, causing more page splits along the
  way.
- Assuming a MongoDB document's in-memory or logical size is what it
  costs on disk. `size` and `storageSize` diverge by design, and code or
  capacity planning that reads `size` alone is planning against a number
  WiredTiger never actually writes to a block device.

## Teardown

See `labs/day01/teardown.md`.
