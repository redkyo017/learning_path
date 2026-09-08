# Glossary

Plain-English definitions for terms used across this path without re-explaining
them inline. Alphabetical; each entry is one to three sentences. When a term
has its own primer section with more detail, the entry says so.

- **ACID**: Atomicity (a transaction's writes all happen or none do),
  Consistency (the database moves from one application-valid state to
  another — not the C in CAP, a different word wearing the same letter),
  Isolation (concurrent transactions don't see each other's uncommitted
  effects, to a degree set by the isolation level), Durability (a committed
  write survives a crash). See `primers/isolation-anomaly-ladder.md` for how
  Isolation actually fails.

- **autovacuum**: PostgreSQL's background process that reclaims space from
  dead tuples and advances the freeze horizon to prevent transaction ID
  wraparound. It runs per-table once configured thresholds of dead/modified
  rows are crossed, not on a fixed schedule.

- **B-tree**: The default index structure in PostgreSQL, MySQL/InnoDB, and
  MongoDB (WiredTiger). Balanced, sorted, supports equality, range, and
  ordered-scan lookups in roughly logarithmic time; the structure almost
  every other index concept in this path (covering, clustered, gap locks) is
  built on top of.

- **BCNF**: Boyce-Codd Normal Form — a stricter version of third normal
  form. Every determinant (a column or set of columns that functionally
  determines another column) must be a candidate key. Tables that satisfy
  3NF but not BCNF still have a narrow class of update anomalies.

- **bloat**: Space consumed by dead tuples or rows that vacuuming (Postgres)
  or purging (MySQL) hasn't reclaimed yet, or that can no longer be
  reclaimed in place. Bloat lowers the effective density of data per page,
  so scans read more pages to find the same live rows.

- **buffer pool**: The in-memory cache of on-disk pages — `shared_buffers`
  in PostgreSQL, `innodb_buffer_pool_size` in MySQL, the WiredTiger cache in
  MongoDB. A page found here is a "hit"; a page not found here costs a
  read from the OS cache or disk.

- **chunk**: In a sharded MongoDB collection, a contiguous range of shard-key
  values that the balancer moves as one unit between shards. See
  **jumbo chunk** for what happens when a chunk can't be split.

- **clustered index**: An index whose leaf pages *are* the table's row
  storage, so rows physically sort by the index key. InnoDB tables are
  always clustered on the primary key; PostgreSQL has no clustered index by
  default (`CLUSTER` is a one-time, non-maintained reordering).

- **covering index**: An index that contains every column a query needs, so
  the engine never has to visit the base table/heap to answer it. Enables
  an index-only scan in PostgreSQL or a "using index" access in MySQL.

- **CTE**: Common Table Expression, a `WITH name AS (...)` block. In
  PostgreSQL 12+ a non-recursive CTE can be inlined into the surrounding
  query by the planner (it is not automatically an optimization fence);
  `WITH RECURSIVE` is the mechanism behind hierarchy and graph-walk queries.

- **deadlock**: Two or more transactions each hold a lock the other needs,
  so neither can proceed. Both PostgreSQL and InnoDB detect the cycle and
  kill one transaction (the "victim") to break it; the survivor proceeds.

- **double entry**: This path's ledger discipline — every `payment_id`
  posts matching debit and credit `ledger_entries` rows whose
  `amount_minor` sums to zero. `accounts.balance_minor` is a cached,
  derivable projection of this ledger, never the source of truth.

- **ESR**: Equality, Sort, Range — the rule of thumb for ordering fields in
  a MongoDB compound index. Equality-tested fields go first, then fields
  used to sort, then fields used in a range test; getting the order wrong
  forces an in-memory sort or an oversized index scan even though a
  matching-looking index exists.

- **extended statistics**: PostgreSQL's `CREATE STATISTICS`, which records
  cross-column dependence (`ndistinct`, `dependencies`, or an MCV list on a
  combination of columns) that the default per-column statistics can't
  express. Needed when two columns are correlated — this schema's
  `merchants.country` and `payments.currency` are the working example.

- **fillfactor**: The percentage of a page PostgreSQL fills on insert,
  leaving the remainder free for same-page updates. A lower fillfactor
  trades some storage for more HOT updates and less index churn on tables
  that are updated in place after insert.

- **functional dependency**: `X → Y` — knowing the value of `X` determines
  the value of `Y`. The building block of normal-form reasoning: a table
  violates 3NF/BCNF when a functional dependency exists that isn't rooted
  in a candidate key.

- **gap lock**: An InnoDB lock on the *space between* index records (not on
  a row itself), used at Repeatable Read to stop another transaction from
  inserting into that gap. Combined with a lock on the record itself it
  becomes a **next-key lock**; this pairing is why InnoDB's Repeatable Read
  blocks phantoms that the SQL standard does not require it to block.

- **heap**: PostgreSQL's term for a table's actual row storage, as opposed
  to its indexes. Unlike InnoDB, a PostgreSQL heap is not ordered by any
  index — every index stores a separate pointer (`ctid`) back into it.

- **HOT update**: Heap-Only Tuple update — a PostgreSQL update whose new row
  version lands on the same page as the old one and touches no indexed
  column, so no index entries need to change. Cheaper than an ordinary
  update and a major reason fillfactor is tuned below 100.

- **index-only scan**: A PostgreSQL scan that answers a query entirely from
  a covering index, skipping the heap — except where the visibility map
  says a page might have invisible-to-this-snapshot rows, in which case it
  still visits the heap (a "heap fetch"). See
  `primers/explain-field-reference.md#explain-heap-fetches`.

- **isolation level**: The contract a database offers for what one
  transaction can observe of another's concurrent, uncommitted or
  concurrently-committing work. Ordered loosely by strictness: Read
  Uncommitted, Read Committed, Repeatable Read, Serializable — but
  "stricter" doesn't mean "prevents more of what you'd guess"; see
  `primers/isolation-anomaly-ladder.md`.

- **jumbo chunk**: A MongoDB chunk that has grown past the configurable
  split size but can't be split further, because every document in it
  shares the same shard-key value. The balancer can't move it in pieces,
  so it sits on one shard indefinitely — a direct symptom of a low-
  cardinality or power-law-skewed shard key.

- **lossless join**: A decomposition of a table into smaller tables is
  lossless if joining them back (on the right key) reproduces exactly the
  original rows — no spurious rows appear. The property normalization is
  supposed to preserve; a lossy decomposition is a normalization bug.

- **MVCC**: Multi-Version Concurrency Control — readers see a consistent
  snapshot of the data without blocking writers, because the engine keeps
  multiple versions of a row and hands each transaction the version valid
  for its snapshot. PostgreSQL (`xmin`/`xmax`), InnoDB (undo log), and
  WiredTiger all implement this idea differently.

- **N+1**: A query pattern that runs one query to fetch a list, then one
  more query per row to fetch each row's related data, instead of one join
  or one batched `IN (...)` lookup. Looks fine at 10 rows; at 10,000 it's
  10,001 round trips.

- **next-key lock**: A row lock plus the gap lock immediately before it,
  InnoDB's default locking strategy for index records at Repeatable Read.
  See **gap lock**.

- **oplog**: MongoDB's replication log — a capped collection
  (`local.oplog.rs`) of every write, replayed by secondaries to stay in
  sync. Its retention window is measured in time, not only size, which
  bounds how far behind a secondary can fall before it needs a full resync.

- **PACELC**: An extension of CAP: if there's a **P**artition, trade
  **A**vailability against **C**onsistency (CAP's actual content) — but
  **E**lse (no partition), trade **L**atency against **C**onsistency
  anyway, because synchronous replication costs latency even when the
  network is healthy. The clause CAP leaves out and PACELC exists to say.

- **page**: The fixed-size unit of on-disk storage and I/O — 8 KB in
  PostgreSQL, 16 KB in InnoDB by default, WiredTiger pages are
  variable-size internally but still the unit the buffer/cache manages.
  Every read/write cost estimate ultimately counts pages, not rows.

- **partition pruning**: The planner eliminating whole partitions from a
  query plan based on the `WHERE` clause matching (or failing to match) the
  partition key, before ever touching those partitions' data. Requires the
  predicate to actually constrain the partition key — a predicate on a
  different column prunes nothing.

- **PITR**: Point-In-Time Recovery — restoring a base backup and replaying
  WAL (PostgreSQL) up to a chosen timestamp or LSN, rather than only to the
  moment the backup was taken. Requires continuous WAL archiving to already
  be running before the incident, not started after.

- **power-law skew**: A distribution where a small fraction of keys account
  for a disproportionate share of activity — in this schema, the top 1% of
  merchants own roughly 44% of `payments` and `ledger_entries` at
  `SCALE=10` (see `labs/stack/seed/README.md`'s "Why the data is skewed").
  Breaks any tuning assumption built on "activity is roughly even across
  rows."

- **quorum**: The minimum number of nodes that must acknowledge a write (or
  participate in a read) for the operation to count as durable/consistent
  under the replica set's configured concern — MongoDB's `w: majority`
  is a quorum write concern, not a guarantee every replica has the data yet.

- **read replica**: A database instance that receives a continuous stream
  of changes from a primary and serves read traffic, but does not accept
  writes. Introduces **replication lag** as a new variable in every
  read-your-own-write question.

- **replication lag**: The delay between a write committing on the primary
  and that write becoming visible on a replica. Measured in time, not
  bytes or transaction count, because what matters is how stale a read
  from that replica can be right now.

- **sargable**: "Search-ARGument-ABLE" — a predicate an index can be used
  to evaluate directly, without the engine first computing a function of
  the column for every row. `created_at > '2026-01-01'` is sargable;
  `date(created_at) > '2026-01-01'` usually is not, unless an index exists
  on that expression.

- **selectivity**: The fraction of a table's rows a predicate is expected
  to match. Low selectivity (few rows match) favors an index scan; high
  selectivity (most rows match) favors a sequential/full scan, because
  reading the whole table beats a page-per-matching-row index round trip.

- **shard key**: The field (or compound field set) MongoDB uses to
  partition a collection's documents across shards. Chosen once,
  expensive to change, and the single decision that determines whether
  write load spreads evenly or piles onto one shard (see **jumbo chunk**).

- **snapshot isolation**: A consistency model where a transaction sees the
  database exactly as it was at the transaction's start (or first
  statement), unaffected by concurrent commits. PostgreSQL Repeatable Read,
  InnoDB Repeatable Read, and MongoDB's default multi-document transaction
  read concern are all snapshot-isolation variants — and snapshot
  isolation, by itself, does **not** prevent write skew.

- **SSI**: Serializable Snapshot Isolation — PostgreSQL's implementation of
  `SERIALIZABLE`. Built on top of snapshot isolation plus predicate locks
  that detect dangerous read/write dependency cycles; a transaction caught
  in one aborts with a serialization failure rather than being blocked, so
  callers must be prepared to retry.

- **TOAST**: The Oversized-Attribute Storage Technique — PostgreSQL's
  mechanism for storing values too large for a page out-of-line in a
  separate TOAST table, optionally compressed. `payments.description` is
  the column in this schema that TOASTs.

- **transaction ID wraparound**: PostgreSQL transaction IDs are a 32-bit
  counter; without freezing, old row versions would become invisible (or
  worse, appear to come from the future) once the counter wraps. Autovacuum
  freezes old tuples well before that point — this is why freezing exists,
  not an optional cleanup step.

- **tuple header**: The fixed ~23-byte overhead PostgreSQL stores before
  every row's actual data — `xmin`, `xmax`, a command ID, and flag bits.
  Present on every row regardless of the row's own size, which is why
  narrow tables have proportionally larger overhead than wide ones.

- **visibility map**: A PostgreSQL per-table bitmap tracking which heap
  pages contain only rows visible to every current and future transaction.
  Index-only scans consult it to decide whether a heap fetch is needed;
  autovacuum uses it to skip pages with nothing to clean.

- **WAL**: Write-Ahead Log — PostgreSQL writes every change to this log
  before applying it to data pages, so crash recovery replays the log
  instead of trusting partially-written pages. The basis for streaming
  replication and PITR.

- **wide row**: A row (or, in MongoDB, a document) that is unusually large
  relative to its table's/collection's typical row, often from an
  unbounded array or many nullable columns. Wide rows spill onto extra
  pages, degrade per-page row density, and in MongoDB can push a document
  past reasonable size long before the hard 16 MB document limit.

- **WiredTiger**: MongoDB's default storage engine since 3.2 — document-
  level locking, MVCC snapshots, on-disk compression, and its own page
  cache (`serverStatus.wiredTiger.cache`) separate from the OS page cache.

- **write skew**: Two transactions each read an overlapping set of rows,
  each writes to a *different* row based on what they read, and both
  commit — yet the combination violates an invariant that spanned both
  rows, which neither transaction's individual write ever technically
  broke. Repeatable Read/snapshot isolation does **not** prevent this;
  only Serializable does. See `primers/isolation-anomaly-ladder.md#write-skew`.

- **`xmin`/`xmax`**: Hidden columns in every PostgreSQL row's tuple header —
  `xmin` is the ID of the transaction that inserted this row version,
  `xmax` the ID of the transaction that deleted or updated it (0 if still
  current). MVCC visibility is computed by comparing these against a
  snapshot, not by any lock.
