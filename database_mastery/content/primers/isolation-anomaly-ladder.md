# Isolation anomaly ladder

Six anomalies, three engines, every combination of isolation level this
path uses. Two facts on this page are the ones most engineers get wrong,
including engineers who can recite the isolation-level table from memory —
both are called out explicitly below rather than left for you to infer
from the matrix.

**Every cell in this matrix has a live, two-session reproduction in
`labs/day05/`** — Day 5's lab supplies the concrete scripts that put two
sessions on opposite sides of each race and show you the anomaly (or its
absence) directly, rather than asking you to trust this table. Read a row
here to know what to *expect*; run the matching script in `labs/day05/` to
watch it actually happen.

## Matrix

"Prevented" means the engine/level combination stops the anomaly from
being observable at all. "Possible" means it can happen under ordinary
application code with no extra locking — not that it happens every time.

| Anomaly | PG Read Committed | PG Repeatable Read | PG Serializable | MySQL RC | MySQL RR | Mongo (no transaction) | Mongo (multi-doc transaction) |
|---|---|---|---|---|---|---|---|
| Dirty read | Prevented | Prevented | Prevented | Prevented | Prevented | Prevented | Prevented |
| Non-repeatable read | Possible | Prevented | Prevented | Possible | Prevented | Possible | Prevented |
| Phantom | Possible | Prevented | Prevented | Possible | Prevented (gap locks) | Possible | Prevented |
| Lost update | Possible | Prevented | Prevented | Possible | Possible | Possible | Prevented |
| Read skew | Possible | Prevented | Prevented | Possible | Prevented | Possible | Prevented |
| Write skew | Possible | **Possible** | Prevented | Possible | Possible | Possible | **Possible** |

Two rows do not follow the "higher level = strictly more prevented"
pattern a quick skim suggests, and both are load-bearing for this path:
**Phantom** flips to "prevented" one level earlier for MySQL than the SQL
standard requires (see **Gap locks and next-key locks** below), and
**Write skew** stays "possible" one level later than most people assume
for both PostgreSQL and MongoDB (see **Repeatable Read does not prevent
write skew** below). Lost update is also worth a second look: PostgreSQL's
Repeatable Read prevents it, MySQL's does not — see that row's own section.

## Dirty read

Reading another transaction's **uncommitted** write. None of the levels in
this path's column set allow it — PostgreSQL has no true Read Uncommitted
(it silently upgrades to Read Committed behavior), and InnoDB's Read
Committed already excludes uncommitted data. This row is here as the
baseline everyone gets right, so the ladder starts somewhere solid.

## Non-repeatable read

Re-reading the same row twice in one transaction and getting two different
committed values, because another transaction committed a change to that
row in between your two reads. PostgreSQL and MySQL both prevent this from
Repeatable Read upward, by fixing the transaction's read snapshot at (or
near) the transaction's start instead of re-establishing it on every
statement — Read Committed in both engines takes a fresh snapshot **per
statement**, which is exactly what lets this anomaly through.

## Phantom

Re-running the same range-shaped query twice in one transaction and
getting a different **set of rows**, because another transaction inserted
or deleted a row matching your predicate in between. Reproduced and
explained further in **Gap locks and next-key locks** below.

## Lost update

Two transactions each read a row, each compute a new value from what they
read, and the second one to write **silently overwrites** the first one's
change — the first transaction's update is never seen again by anyone.
PostgreSQL's Repeatable Read (and Serializable) genuinely prevents this:
when a second transaction tries to write a row that a concurrent
transaction already committed a change to, PostgreSQL raises `ERROR:
could not serialize access due to concurrent update` instead of applying
the write, forcing the caller to retry against current data. InnoDB does
not do this at either Read Committed or Repeatable Read — a blocked
`UPDATE` proceeds once the lock clears and, for a literal (non-expression)
overwrite, applies the caller's stale, precomputed value with no error at
all. At those two levels, avoiding a lost update in MySQL requires an
explicit `SELECT ... FOR UPDATE` on the read step, or a `WHERE` clause
that re-checks the originally-read value (optimistic concurrency).
InnoDB's SERIALIZABLE changes this: inside an explicit transaction it
implicitly promotes a plain `SELECT` to a locking read (`SELECT ... FOR
SHARE`), so both transactions' reads take shared locks on the row, and
those shared locks collide the moment either side issues its `UPDATE` —
InnoDB's deadlock detector then rolls one transaction back. The anomaly is still prevented at SERIALIZABLE, but through a blunter
mechanism than PostgreSQL's: a deadlock and a rollback, rather than a
targeted serialization-failure error raised specifically against the
stale writer.
MongoDB's multi-document transactions prevent it the same way PostgreSQL
does: a write conflict against a concurrently-modified document raises a
retryable `WriteConflict` error rather than applying silently.

## Read skew

A transaction reads two related objects at two different points in time
and observes a combination that never existed as a single consistent
state — for example, reading `accounts` for two parties mid-transfer and
seeing the sender already debited but the recipient not yet credited.
Fixing the transaction's snapshot at the start (Repeatable Read and above,
in both PostgreSQL and InnoDB, and MongoDB's snapshot read concern inside
a multi-document transaction) prevents it outright, because every read in
the transaction comes from the same fixed point in time. Read Committed's
per-statement snapshot, and any sequence of ordinary un-transacted reads
in MongoDB, offers no such guarantee.

## Write skew

Two transactions each read an overlapping set of rows, each write to a
**different** row based on what they read, and both commit — yet the
combination violates an invariant that spans both rows, without either
transaction's own write ever technically breaking it in isolation. This
schema's example is two concurrent withdrawals against the same account:
each transaction reads the derived balance, confirms the withdrawal is
covered, and withdraws — from a *different* `ledger_entries` insert — and
both commit, leaving the derived balance negative even though neither
insert alone violates anything a row-level `CHECK` could see.

See **Repeatable Read does not prevent write skew** immediately below —
this is the anomaly that section is about.

## Gap locks and next-key locks

**MySQL's InnoDB Repeatable Read prevents phantom reads by a mechanism the
SQL standard does not require at that level: gap locks.** A gap lock locks
the *space between* index records rather than a record itself; paired with
a lock on the record it becomes a next-key lock. When a locking read
(`SELECT ... FOR UPDATE`/`FOR SHARE`) or a range `UPDATE`/`DELETE`
establishes these locks, a concurrent transaction's `INSERT` into that
locked gap physically blocks until the first transaction commits or rolls
back — the phantom is prevented at the source, not merely hidden by MVCC:
the row that would have caused it can't be inserted yet at all. PostgreSQL's
Repeatable Read prevents the same *plain-read* phantom, but purely through
its MVCC snapshot: a concurrent `INSERT` still succeeds immediately in
PostgreSQL — it is only invisible to a transaction that already took its
snapshot, not blocked. The
two engines reach "phantom: prevented" by genuinely different means, and
that difference is exactly why InnoDB's Repeatable Read produces more
deadlocks under range-based write contention than PostgreSQL's does — the
gap locks that block phantoms are also locks other transactions can
collide on.

## Repeatable Read does not prevent write skew

**PostgreSQL's Repeatable Read does not prevent write skew — only
Serializable does.** This is the fact this entire ladder exists to make
unmissable, and Day 5's lab is built directly on it. Repeatable Read (in
both PostgreSQL and MySQL) is snapshot isolation: it detects and blocks
conflicts when two transactions try to write the *same* row, which is
exactly what makes it sufficient to prevent lost update in PostgreSQL. But
write skew's two transactions write to **different** rows, so there is no
row-level conflict for a snapshot-isolation engine to catch — each
transaction's write is, by itself, perfectly consistent with what that
transaction read. Only PostgreSQL's Serializable (Serializable Snapshot
Isolation, SSI) tracks the read/write **dependencies** between
transactions, going beyond row-level write conflicts, and aborts one side
of a dangerous cycle with a serialization failure the caller must retry.

The same holds for MongoDB: a multi-document transaction gives you
snapshot isolation, not full serializability, so wrapping the two
withdrawals in a transaction does not by itself stop write skew — the two
transactions still read from consistent, non-conflicting snapshots and
write to different documents. And it holds for MySQL's InnoDB Repeatable
Read too: gap/next-key locks stop *phantom inserts* into a locked range,
but they do nothing for a plain `SELECT` (no `FOR UPDATE`) followed by a
write to an unrelated row — without an explicit locking read, InnoDB
Repeatable Read is exactly as exposed to write skew as PostgreSQL's is.
The fix in every engine is the same shape: make the read that establishes
the invariant a genuine write-conflict source — `SELECT ... FOR UPDATE` in
PostgreSQL and MySQL, or a read-and-write against the same document that
encodes the invariant in MongoDB — or move up to PostgreSQL Serializable
and accept the retry-loop obligation that comes with it. A row-level
`CHECK` constraint helps with none of these engines, because the invariant
being violated is derived across rows, not stored in any single one of
them.
