# Day 5 — Concurrency: Transactions, Isolation, Locks

**Layer:** concurrency
**Budget:** 3 h — 1 h isolation levels and the lock model, 2 h blocking-chain and write-skew lab

## Why this matters

Isolation levels are learned from a table in a book, and the table is
remembered as "higher is safer" — true, and useless the moment you are
staring at a specific piece of business logic and need to know which
anomaly it is actually exposed to and what the cheapest defence is. That
question has one right way to answer it: identify which two rows (or
which one row read twice) a bug can put in an impossible combination,
then pick the isolation level or lock that makes that specific
combination unreachable. Everything else — memorising the
dirty-read/non-repeatable-read/phantom table, reaching for
`SERIALIZABLE` everywhere out of caution — is a habit standing in for an
understanding that decayed.

Today's lab is the crown lab of this path for a reason: every earlier
day handed you an instrument and a single anomaly to read off it. Today
hands you two incidents that look identical from the outside — everyone
is timing out — and are caused by entirely different mechanisms, one a
lock queue and one a snapshot conflict that no lock ever fires for. Tell
them apart with the same instrument, `pg_stat_activity` and `pg_locks`,
and the ledger the way the rest of this path taught you to read a
catalog: raw, before naming the concept.

## Read the instrument first

Two `psql` sessions, side by side, against the seeded `payments`
database. Session A takes a row lock and holds it; session B asks for
the same row and waits. Before either session runs a single `EXPLAIN` or
opens a monitoring tool, this is what the catalog says happened:

```
-- session A
payments=# BEGIN;
BEGIN
payments=*# SELECT ctid, xmin, xmax FROM accounts WHERE account_id = 1;
 ctid  | xmin  | xmax
-------+-------+------
 (0,1) | 88213 |    0
(1 row)
payments=*# UPDATE accounts SET created_at = created_at WHERE account_id = 1;
UPDATE 1
-- (session A does not COMMIT yet)
```

```
-- session B, started a moment later
payments=# UPDATE accounts SET created_at = created_at WHERE account_id = 1;
-- hangs here -- no prompt returns
```

```
-- session C, a third connection, reading the catalog while B hangs
payments=# SELECT pid, state, wait_event_type, wait_event, query_start
           FROM pg_stat_activity
           WHERE datname = 'payments' AND pid <> pg_backend_pid();
  pid  |        state        | wait_event_type | wait_event    |          query_start
-------+----------------------+------------------+---------------+-------------------------------
 41207 | idle in transaction  |                  |               | 2026-09-07 10:14:02.881211+00
 41298 | active               | Lock             | transactionid | 2026-09-07 10:14:05.114032+00
(2 rows)

payments=# SELECT pg_blocking_pids(41298);
 pg_blocking_pids
-------------------
 {41207}
(1 row)
```

Nothing here needed a name yet. `xmin` on the row session A touched
changes the instant `UPDATE` runs, even before commit — that new version
is invisible to everyone else until commit, and the old version's
`xmax` gets set to session A's transaction ID, marking it superseded.
Session B's `state` is `active` while its `wait_event_type` is `Lock` —
a backend can be "running" a statement that has done nothing but sit in
a lock queue for seconds. `wait_event` is `transactionid`, specifically:
session B is blocked waiting for session A's transaction ID to finish,
because it is the only session asking for this row. A third session
issuing the same `UPDATE` while B still waits would show `tuple`
instead — PostgreSQL serializes multiple simultaneous waiters on one row
behind a heavyweight lock on the tuple itself, so the second-and-later
waiters queue on that lock, not directly on A's transaction. That
distinction — `transactionid` for the session waiting on the current
holder, `tuple` for every session queued behind an earlier waiter — is
exactly the mechanism the five-session lab below turns into "who is the
root, and who is only standing in line."

`pg_blocking_pids()` names session A's PID directly here, because there
is only one hop between B and the holder. It does not pre-walk an
arbitrary-length chain for you — it reports the session(s) immediately
ahead of the one you asked about (the lock holder, plus any other
session already queued ahead of it for the same lock), one hop at a
time. With five sessions instead of two, that matters: finding the root
means calling it again on whatever it names, and again, until it names
nothing — see `content/primers/catalog-field-reference.md`
(`#pg_stat_activity`, `#pg_locks-and-pg_blocking_pids`) for the full
field reference this section is not repeating.

## Core concepts

**ACID, stated precisely.** Atomicity: a transaction's writes are all
applied or none are, regardless of a crash or an error mid-way.
Isolation: concurrent transactions see a database state that could have
arisen from *some* serial ordering of them (or a well-defined weaker
approximation of that, depending on level). Durability: once committed,
a write survives a crash, guaranteed by the write-ahead log — Day 6's
subject. Consistency is the one everyone states loosely: it does **not**
mean "eventually consistent" or any distributed-systems sense of the
word. In ACID, consistency means the application's own invariants —
"an account's balance never goes negative," "every payment has debit and
credit lines that sum to zero" — survive every transaction that commits.
The database enforces the invariants you tell it about, with constraints
and foreign keys. It enforces nothing about the invariants you never
declared, no matter how self-evidently true they seem to you. Today's lab
lives entirely in that gap: the invariant "an account's derived balance
never goes negative" was never declared to PostgreSQL as anything a
single statement can check, because it spans every row in
`ledger_entries` for that account, not one row anywhere.

**The anomaly ladder.** `content/primers/isolation-anomaly-ladder.md`
holds the reviewed matrix (`#matrix`) and the two facts most people get
wrong (`#gap-locks-and-next-key-locks`,
`#repeatable-read-does-not-prevent-write-skew`) — read those sections
before continuing, this content does not restate them. What follows here
is the two-session script that produces each anomaly, so you have
something to run, not only a definition to recite.

*Dirty read* (`#dirty-read`) — not producible against any engine or level
in this path; shown here as the negative case:

```
-- A                              -- B
BEGIN;
UPDATE accounts SET balance_minor
  = balance_minor - 100
  WHERE account_id = 1;
                                   BEGIN;
                                   SELECT balance_minor FROM accounts
                                     WHERE account_id = 1;
                                   -- sees the value BEFORE A's update,
                                   -- on every level this path uses --
                                   -- there is no dirty read to catch here
ROLLBACK;
```

*Non-repeatable read* (`#non-repeatable-read`), PostgreSQL Read Committed:

```
-- A                              -- B
BEGIN;
SELECT balance_minor FROM accounts
  WHERE account_id = 1;  -- 5000
                                   BEGIN;
                                   UPDATE accounts SET balance_minor = 4000
                                     WHERE account_id = 1;
                                   COMMIT;
SELECT balance_minor FROM accounts
  WHERE account_id = 1;  -- 4000, same txn, different answer
COMMIT;
```

Re-run under `BEGIN ISOLATION LEVEL REPEATABLE READ;` and A's second
`SELECT` still reads `5000` — the transaction's snapshot was fixed at
its first statement, and B's committed change is invisible to it for the
rest of the transaction.

*Phantom* (`#phantom`):

```
-- A                              -- B
BEGIN;
SELECT count(*) FROM payments
  WHERE merchant_id = 2
    AND status = 'pending';  -- 3
                                   BEGIN;
                                   INSERT INTO payments (...)
                                     VALUES (..., 2, ..., 'pending', ...);
                                   COMMIT;
SELECT count(*) FROM payments
  WHERE merchant_id = 2
    AND status = 'pending';  -- 4, same txn
COMMIT;
```

Repeatable Read prevents this in both PostgreSQL and MySQL, but by
different mechanisms — MVCC snapshot invisibility in PostgreSQL, gap
locks that physically block B's `INSERT` in InnoDB. See
`#gap-locks-and-next-key-locks` for the difference and why it matters for
deadlock rates.

*Lost update* (`#lost-update`):

```
-- A                              -- B
BEGIN;                            BEGIN;
SELECT risk_tier FROM merchants
  WHERE merchant_id = 2;  -- 1
                                   SELECT risk_tier FROM merchants
                                     WHERE merchant_id = 2;  -- 1
UPDATE merchants SET risk_tier = 2
  WHERE merchant_id = 2;
COMMIT;
                                   UPDATE merchants SET risk_tier = 3
                                     WHERE merchant_id = 2;
                                   -- Read Committed: blocks on A's row lock,
                                   -- then proceeds once A commits, silently
                                   -- overwriting risk_tier=2 with 3 -- A's
                                   -- write is gone and nobody was told
                                   COMMIT;
```

Under PostgreSQL Repeatable Read, B's `UPDATE` instead raises `ERROR:
could not serialize access due to concurrent update` once it wakes up
and finds the row changed since its snapshot — B must retry, which is
exactly the caller-side obligation the write-skew fix below also
requires. InnoDB Repeatable Read does **not** raise this error; a blocked
literal `UPDATE` applies once the lock clears, silently, per
`#lost-update` in the primer.

*Read skew* (`#read-skew`):

```
-- A (a naive transfer report)     -- B (the transfer itself)
BEGIN;
SELECT balance_minor FROM accounts
  WHERE account_id = 1;  -- sender, pre-debit: 5000
                                   BEGIN;
                                   UPDATE accounts SET balance_minor = balance_minor - 100
                                     WHERE account_id = 1;
                                   UPDATE accounts SET balance_minor = balance_minor + 100
                                     WHERE account_id = 2;
                                   COMMIT;
SELECT balance_minor FROM accounts
  WHERE account_id = 2;  -- recipient, post-credit: sees the +100
COMMIT;
-- A reported the sender at 5000 (pre-debit) and the recipient already
-- credited -- a combination that never existed as one consistent state
```

Repeatable Read and above fix this by fixing A's snapshot at the first
statement, so both reads come from the same point in time.

*Write skew* (`#write-skew`) — the anomaly this lab is built on. Two
concurrent withdrawals against the account this lab funds:

```
-- A                                    -- B
BEGIN;                                  BEGIN;
SELECT COALESCE(SUM(amount_minor), 0)
  FROM ledger_entries
  WHERE account_id = 42;   -- 5000
                                         SELECT COALESCE(SUM(amount_minor), 0)
                                           FROM ledger_entries
                                           WHERE account_id = 42;   -- 5000, same value
-- 3500 <= 5000: covered, proceed
INSERT INTO ledger_entries (..., account_id, direction, amount_minor, ...)
  VALUES (..., 42, 'D', -3500, ...);
                                         -- 3500 <= 5000: covered too, proceed
                                         INSERT INTO ledger_entries (..., account_id, direction, amount_minor, ...)
                                           VALUES (..., 42, 'D', -3500, ...);
COMMIT;
                                         COMMIT;
-- both committed. derived balance: 5000 + (-3500) + (-3500) = -2000
```

(`amount_minor` already carries the sign — credits positive, debits
negative, per `labs/stack/seed/README.md`'s "accounts/ledger invariant."
Every derived-balance query in this lab is a plain `SUM(amount_minor)`;
there is no `direction`-based `CASE` anywhere in it, because the sign is
already in the column.)

Neither `INSERT` conflicts with the other at the row level — they insert
two different, brand-new rows. No lock is ever contended, on Read
Committed **or** Repeatable Read, in PostgreSQL or InnoDB. Only
PostgreSQL Serializable (SSI) tracks the read/write dependency between
the two transactions well enough to abort one of them; see
`#repeatable-read-does-not-prevent-write-skew` for the full mechanism,
which this section is deliberately not re-deriving.

**PostgreSQL's three levels, mechanically.** Read Committed re-takes its
MVCC snapshot at the start of **every statement** — this is why a
transaction that runs the same `SELECT` twice can get two different
answers, and why an `UPDATE` that finds its target row changed since the
statement began re-reads the row's current committed value and
re-evaluates its `WHERE` clause against it, rather than erroring, once
the blocking transaction commits. Repeatable Read takes one snapshot for
the whole transaction and raises a serialization failure instead of
silently re-evaluating when a write conflict is detected. Serializable
adds predicate locking (SSI): it tracks which rows a transaction's
queries **could have** returned, not only which rows they touched, and
aborts one side of a dangerous read/write dependency cycle — sometimes a
transaction that never actually conflicted with anything gets aborted
anyway, a false positive that is the deliberate cost of catching write
skew; every caller of a `SERIALIZABLE` transaction has to be written to
retry on `SQLSTATE 40001`.

**MySQL InnoDB.** Read Committed behaves like PostgreSQL's: fresh
per-statement read view, no phantom protection. Repeatable Read is
InnoDB's default and goes further than the standard requires — gap and
next-key locks (`#gap-locks-and-next-key-locks`) block phantom inserts
into a locked range at the source, not merely hide them via MVCC. The
cost of that extra protection is more deadlocks: two range-based writers
can each hold a gap lock the other one needs, a situation PostgreSQL's
Repeatable Read never creates because it never takes a gap lock at all.

**MongoDB.** A single-document write is always atomic — no transaction
needed for that case. Multi-document transactions run under snapshot
isolation, the same level as PostgreSQL/InnoDB Repeatable Read, and
inherit the identical write-skew exposure: two transactions reading an
overlapping set of documents and writing to different ones both commit
cleanly, because neither's write conflicts with the other's at the
document level. A write conflict against a concurrently-modified
document raises a retryable `WriteConflict` error — the driver does not
retry this for you; the calling code must. Transactions default to a
60-second lifetime (`transactionLifetimeLimitSeconds`) after which the
server aborts them unilaterally, which makes a transaction that spans a
network round trip to an external service a reliability bug waiting to
happen, independent of anything about isolation.

**Lock modes and the lock queue.** PostgreSQL's table-level lock modes
form a hierarchy from `ACCESS SHARE` (a plain `SELECT` takes this) up to
`ACCESS EXCLUSIVE` (most forms of `ALTER TABLE`, `DROP TABLE`, `TRUNCATE`).
The queue is strictly FIFO per lock: a queued `ACCESS EXCLUSIVE` request
does not wait politely behind currently-running readers and let new
readers keep arriving — it sits in the queue, and PostgreSQL's fairness
rule then blocks every **subsequent** lock request, including plain
`SELECT`s that would otherwise be perfectly compatible with the
currently-granted locks, behind that queued exclusive request. This is
the mechanism behind "a careless `ALTER TABLE` took down the service": the
`ALTER TABLE` itself might wait harmlessly for one long-running query to
finish, but every request that arrives after it — thousands of ordinary
reads — piles up behind it too, because none of them are allowed to jump
the queue ahead of an already-waiting exclusive request.

**`SELECT ... FOR UPDATE`, `SKIP LOCKED`, and advisory locks.** `FOR
UPDATE` takes a row-level exclusive lock as part of a read, turning that
`SELECT` into a genuine write-conflict source — the fix write skew
needs. `FOR UPDATE SKIP LOCKED` is the correct job-queue dequeue
primitive: instead of blocking behind a row another worker already
claimed, it silently excludes locked rows from the result set, so N
workers can each grab a different unclaimed row from the same table with
no blocking and no risk of two workers claiming the same job.
`pg_advisory_lock`/`pg_advisory_xact_lock` take a lock on an arbitrary
integer you choose rather than on a row, useful for serializing
application-level work that has no natural row to lock against.

**Deadlocks.** Two transactions each hold a lock the other one needs, in
opposite order: A holds row 1 and wants row 2, B holds row 2 and wants
row 1. Neither can proceed and neither will spontaneously give up.
PostgreSQL's deadlock detector runs periodically (`deadlock_timeout`,
default 1 s), finds the cycle, and aborts one participant with `ERROR:
deadlock detected` in that session and a full cycle description —
process IDs, the exact lock each held and each wanted, the query text —
written to the PostgreSQL log. MySQL does the same detection and
resolution but reports it differently: query `SHOW ENGINE INNODB STATUS`
and read the `LATEST DETECTED DEADLOCK` section, which lists both
transactions, the specific lock each was holding and waiting for, and
which one InnoDB chose to roll back (by default, the one that had done
less work, measured in undo-log entries).

**The long-running transaction is the root of most operational evil.**
This is the fact Day 6 depends on, established here: any transaction —
active or idle in transaction — pins `pg_stat_activity.backend_xmin` at
whatever value it was when the transaction started. `backend_xmin` is
the oldest row version this backend's snapshot might still need to read,
and `VACUUM` cannot remove a dead row version older than the oldest
`backend_xmin` across every connection, no matter how long ago it was
superseded. A transaction opened five minutes ago and forgotten — the
canonical `idle in transaction` state — holds that horizon in place for
five minutes and counting: dead tuples pile up, `n_dead_tup` climbs,
autovacuum runs and reclaims nothing for the tables that transaction's
snapshot still needs, and on a replica, a long-running query with
`hot_standby_feedback` enabled propagates the same horizon back to the
primary, stalling vacuum there too. None of this requires the
transaction to be doing anything — `idle in transaction` with zero
queries running for an hour is worse for the system than an actively
running query of the same age, because nothing about it looks alarming
in a dashboard that only surfaces `active` sessions.

## Predict before you measure

Write these down, with one sentence of reasoning each, before running
`break.sh`:

1. In the write-skew race `break.sh` runs, which of the two concurrent
   withdrawal sessions will succeed?
2. Does PostgreSQL Repeatable Read prevent the write skew `break.sh`
   commits? (Answer from the primer's `#repeatable-read-does-not-prevent-write-skew`
   section before you run anything — this is a prediction about a fact,
   not a guess about a race.)
3. Of the four sessions queued behind the root blocker, how many does
   `pg_blocking_pids()` report as waiting on the root blocker **directly**
   (as their only blocker), versus **transitively** (blocked by the
   session ahead of them in the queue, which is itself blocked by the
   root)?

## Lab

`labs/day05/break.sh` builds two independent incidents against the
seeded stack: a five-session lock pileup on one `accounts` row, and an
already-committed write-skew violation on a different account. Read
`labs/day05/README.md` for the exact deliverables and run order. Before
touching either incident, write your predictions above into
`journal.md`, then work the daily loop's evidence-chain step
(`STRATEGY.md`, "The daily loop," step 5) for the blocking chain: find
the actual root with `pg_locks`/`pg_blocking_pids()`, not by killing
whichever session has been waiting longest. Only after you have a chain
of evidence should you terminate anything.

The write-skew half of the lab has already happened by the time
`break.sh` returns — there is no live race to watch, only a committed
negative balance to explain and fix, and a defence to write
(`labs/day05/answers/withdraw.sql`) that `labs/day05/harness.sh` races
50 times to confirm it actually holds.

## Exercises

1. Reproduce each of the six anomalies above against this stack (dirty
   read, non-repeatable read, phantom, lost update, read skew, write
   skew) and record which isolation level first stops each one.
   **Hint:** run every anomaly's two-session script three times: once at
   Read Committed, once at Repeatable Read, once at Serializable, and
   note the first level where the "surprising" second read or the second
   commit no longer happens.
   **Solution sketch:** dirty read is stopped at every level in this path
   (no engine here offers true Read Uncommitted); non-repeatable read,
   phantom, lost update and read skew are all stopped starting at
   Repeatable Read in PostgreSQL; write skew is the one anomaly that
   survives Repeatable Read and requires Serializable — the entire point
   of `#repeatable-read-does-not-prevent-write-skew`.

2. Write a job-queue dequeue that two workers can run concurrently
   without ever claiming the same row.
   **Hint:** blocking on a claimed row is the wrong primitive here — a
   worker should skip a claimed row instantly and move to the next
   available one, not queue up behind it.
   **Solution sketch:** `UPDATE jobs SET status = 'claimed', worker_id =
   :worker_id WHERE job_id = (SELECT job_id FROM jobs WHERE status =
   'pending' ORDER BY job_id FOR UPDATE SKIP LOCKED LIMIT 1) RETURNING
   job_id;` — the subquery's `FOR UPDATE SKIP LOCKED` excludes any row
   another worker's transaction already has locked, so two workers
   running this concurrently claim two different rows with no blocking.

3. Produce a deadlock deliberately and read the report.
   **Hint:** you need two transactions that lock two rows in opposite
   order — session A row 1 then row 2, session B row 2 then row 1 — with
   a pause between each session's two statements so both can acquire
   their first lock before either asks for the second.
   **Solution sketch:** in PostgreSQL, one session gets `ERROR: deadlock
   detected`, and the server log shows both process IDs, the exact locks
   each held and each wanted, and the two queries; in MySQL, run `SHOW
   ENGINE INNODB STATUS` immediately after and read `LATEST DETECTED
   DEADLOCK`, which names both transactions and states which one InnoDB
   chose to roll back.

4. Find the longest-running transaction on the stack and state what it
   is costing.
   **Hint:** the transaction's age is not its query's age — one field on
   `pg_stat_activity` answers "how long has this held the vacuum
   horizon," and it is not `query_start`.
   **Solution sketch:** `SELECT pid, state, now() - xact_start AS
   txn_age, backend_xmin FROM pg_stat_activity WHERE xact_start IS NOT
   NULL ORDER BY xact_start LIMIT 5;` — the oldest `backend_xmin` across
   every row here is the earliest dead-tuple age `VACUUM` is currently
   blocked from reclaiming anywhere in the database, regardless of which
   table that transaction is even touching.

5. Explain why `SELECT ... FOR UPDATE` fixes the write skew in this
   lab's account while a `CHECK (balance_minor >= 0)` does not.
   **Hint:** ask what each mechanism actually reads before it decides
   whether to allow a write — a row-level `CHECK` fires against the row
   being written, not against a sum over a different table.
   **Solution sketch:** `FOR UPDATE` forces the second withdrawal to
   block until the first commits, then re-derive the balance from
   `ledger_entries` against post-commit reality — it manufactures the
   write conflict the invariant needs. A `CHECK` on `accounts.balance_minor`
   can only ever see the single row being written to `accounts`, and
   neither withdrawal writes to `accounts` at all — each inserts a new,
   independent `ledger_entries` row, so the constraint that would need to
   fire never gets a chance to evaluate the account's true, summed
   state; see the SOLUTION.md for the full evidence chain, including why
   this holds even though the `CHECK` line is available and commented
   into `00-schema.sql` on purpose.

6. Implement the same withdrawal defence in MongoDB with a
   multi-document transaction and a retry loop.
   **Hint:** a `WriteConflict` is retryable by definition — the driver
   raises it, it does not resolve it, and the 60-second default
   transaction lifetime bounds how many retries you get to attempt.
   **Solution sketch:** run the balance check and the debit insert inside
   `session.withTransaction(...)`, catch a `WriteConflict` (or any error
   carrying the `TransientTransactionError` label), and retry the whole
   callback with a capped attempt count and a small backoff — never an
   unbounded `while (true)`, since the transaction's own 60-second budget
   is already an implicit cap you should not exceed with your own retry
   delay stacked on top of it.

## Anti-patterns / common mistakes

- Raising the isolation level globally (`ALTER DATABASE ... SET default_
  transaction_isolation = 'serializable'`) instead of defending the one
  invariant that actually needs it — every transaction on the instance
  now pays SSI's predicate-lock overhead and retry obligation, including
  the vast majority that were never at risk of write skew in the first
  place.
- Killing the longest-waiting session instead of the root blocker. It is
  the session every monitoring view surfaces first, and it is usually a
  victim; killing it frees nothing the root blocker still holds, and the
  next-longest waiter moves to the top of the list in its place.
- A retry loop with no backoff and no attempt cap around a `SERIALIZABLE`
  transaction or a MongoDB `WriteConflict` — under real contention this
  turns a transient conflict into a tight, connection-exhausting spin
  that can look, from the outside, like the database itself has stopped
  responding.

## Teardown

See `labs/day05/teardown.md`.
