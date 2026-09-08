# Day 5 — solution

Read this only after your own attempt, or after `verify.sh` has forced a
specific question you can't otherwise answer. This mirrors the chain
template in `journal.md`. Day 5 carries two incidents, so it carries two
chains — the blocking-chain diagnosis first, then the write-skew
analysis, which itself has to show a wrong answer before the right ones,
because the wrong answer (a row-level `CHECK`) is the one every engineer
reaches for first.

### Day 5, incident 1 — the root blocker is not the longest-waiting session

**Predictions (written before running anything):**
- Of the four queued sessions, how many does `pg_blocking_pids()` report
  as naming the root directly: predicted "all four" — assumed a single
  contended row would report every waiter's blocker as the one session
  holding it, with no chain in between.

**Symptom (verbatim, no interpretation):** settlement writes are timing
out, and one account's derived balance has gone negative.

**Layer:** concurrency

**Chain of evidence:**

1. Claim: five sessions are touching `accounts.account_id = 1`; only one
   of them holds a lock, the rest are waiting. | Proof: `SELECT pid,
   state, wait_event_type, wait_event, xact_start FROM pg_stat_activity
   WHERE datname = 'payments' ORDER BY xact_start;` → one row with
   `state = 'idle in transaction'` and the oldest `xact_start` (call its
   pid `R`), four rows with `state = 'active'`, `wait_event_type =
   'Lock'`, younger `xact_start` values, in queued order (`S1` oldest of
   the four, `S4` youngest).
2. Claim: `S1`, the longest-waiting of the four, looks like the obvious
   target — it has been waiting longest, and it shows up first in any
   view sorted by wait time. But the longest-waiting session was the
   wrong target: `S1` is not the root blocker, it is the root blocker's
   first victim. | Proof: `SELECT pg_blocking_pids(S1);` →
   `{R}`. A single-element array is easy to misread as "this is simple,
   `S1` is blocked by `R` alone, kill `S1` and move on" — but `S1` is the
   one WAITING, not the one HOLDING; killing a waiter releases nothing
   the way killing a holder does.
3. Claim: the chain is genuinely transitive, not four independent waits
   on the same holder — but `pg_blocking_pids()` does not report that by
   naming `R` in every result; it reports it by naming a growing prefix
   of *waiters*. | Proof: `SELECT pg_blocking_pids(S2);` → `{S1}`.
   `SELECT pg_blocking_pids(S3);` → `{S1, S2}`. `SELECT
   pg_blocking_pids(S4);` → `{S1, S2, S3}` — every session ahead of it in
   the queue, but never `R`. The mechanism: `S1` is the only session
   whose `UPDATE` actually collides with `R`'s open transaction, so `S1`
   alone waits on `R`'s transaction ID (`wait_event = transactionid`).
   Once `S1` is waiting, PostgreSQL needs to keep the remaining queue
   fair without every later arrival re-checking `R` directly, so `S1`
   itself holds a heavyweight lock on the tuple (`LOCKTAG_TUPLE`) marking
   "I am next in line" — and `S2`, `S3`, `S4` each queue on *that* tuple
   lock, in the order they arrived (`wait_event = tuple`), not on `R`'s
   transaction ID at all. `pg_blocking_pids()` reports hard blockers
   (whoever holds a lock you are asking for) plus soft blockers (whoever
   is already queued ahead of you for that same lock) — one hop, not an
   arbitrary chain walk. `R` never conflicts with `S2`, `S3`, or `S4`
   directly, so it never appears in their results at all; it appears only
   in `S1`'s.
4. Claim: killing `S1` — the longest-waiting session, the one every
   dashboard highlights first — accomplishes nothing toward resolving the
   incident. | Proof: terminate `S1`'s backend, then re-read
   `pg_stat_activity` a few seconds later: `R` is still `idle in
   transaction`, still holding the row lock; `S2` has moved up to become
   the new longest waiter, now itself waiting directly on `R`'s
   transaction ID (`wait_event = transactionid`, `pg_blocking_pids(S2) =
   {R}` — `S2` only names `R` now that `S1`, the tuple-lock holder ahead
   of it, is gone). The set of sessions still blocked shrank by exactly
   one (the one killed), and the root cause — `R`'s open transaction — is
   untouched. Every remaining settlement write is exactly as stuck as
   before.
5. Claim: `R` is the actual root, and terminating it resolves everything
   downstream at once. | Proof: `SELECT pg_terminate_backend(<R's pid>);`
   then `pg_stat_activity` shows `R` gone, and within moments `S2`, `S3`,
   `S4` (whichever of the original four are still alive) each acquire the
   lock in turn, commit, and disappear from the view — the whole chain
   clears from one termination, not four.

**Diagnosis:** The root blocker is the session with no entry in its own
`pg_blocking_pids()` result — the one nothing else is waiting for it to
release turns out, on inspection, to be exactly the one everyone else is
transitively waiting on. The longest-waiting session is reliably the
*first* victim in the queue, not the cause; sorting by wait time finds
victims, walking `pg_blocking_pids()` finds causes, and those are not the
same sort order.

**Fix applied:** `SELECT pg_terminate_backend(<R's pid>);`, where `R` is
the pid recovered in step 1/5 above, run against `pg`; the diagnosis
itself is recorded to `/tmp/answer` inside `ws` (the same container every
day's answer file lives in) as `root_blocker=<pid>`.

**Proof the fix worked (same instrument re-read):** `SELECT count(*)
FROM pg_stat_activity WHERE wait_event_type = 'Lock' AND state =
'active';` → `0`. `SELECT count(*) FROM pg_stat_activity WHERE state =
'idle in transaction' AND now() - xact_start > interval '60 seconds';`
→ `0`.

**Prediction error and what it tells me:** predicted all four sessions
would show a single-element `pg_blocking_pids()` result naming `R`
directly; three of the four actually named a growing prefix of every
session ahead of them in the queue. The model that produced the wrong
prediction treated "waiting for the same row" as a single shared queue
position rather than an ordered line — a genuinely transitive structure,
not a fan-out from one holder to N waiters.

**What I would check first next time:** `pg_blocking_pids()` on the
session with the OLDEST `xact_start`/`query_start` among the *waiters*,
not the session with the oldest timestamp overall (that one might be the
root, sitting outside the waiter set entirely) — and specifically look
for which session's own `pg_blocking_pids()` result is empty, since that
absence, not any wait-time ranking, is what actually identifies the root.

### Day 5, incident 2 — write skew survives a constraint that looks sufficient

**Predictions (written before running anything):**
- Whether `CHECK (balance_minor >= 0)`, if it were live, would have
  prevented the negative balance: predicted yes — assumed any write that
  would leave a negative balance would fail a check against that exact
  column.

**Symptom (verbatim, no interpretation):** one account's derived balance
— summed from `ledger_entries` — is negative, despite every individual
`ledger_entries` row being a normal, valid debit.

**Layer:** concurrency

**Chain of evidence:**

1. Claim: `accounts.balance_minor` is a cache, not the account's real
   balance. | Proof: `00-schema.sql` defines `accounts.balance_minor` as
   a plain `BIGINT` column with no trigger and no generated-column
   definition tying it to `ledger_entries`; the account's true balance is
   `SELECT COALESCE(SUM(amount_minor), 0) FROM ledger_entries WHERE
   account_id = ...`, over a different table entirely. `amount_minor`
   already carries its own sign here — credits positive, debits negative,
   per `labs/stack/seed/README.md`'s "accounts/ledger invariant" — so this
   is a plain sum, never a `direction`-based `CASE`.
2. **The wrong answer, tried first:** claim: uncommenting `CHECK
   (balance_minor >= 0)` on `accounts` would have stopped this. | Proof
   it does not: the race that produced the negative balance never issued
   a single `UPDATE` or `INSERT` against the `accounts` table at all —
   `break.sh`'s two withdrawal sessions each `INSERT`ed one new row into
   `ledger_entries`. A `CHECK` constraint evaluates against the row being
   written, in the table it is declared on. There is no row written to
   `accounts` for it to fire against, so this constraint — live or
   commented out — is a complete non-participant in this incident. Even
   granting a hypothetical trigger that recomputed and wrote
   `balance_minor` after every `ledger_entries` insert, each individual
   `UPDATE accounts SET balance_minor = ...` from that trigger would
   still evaluate the `CHECK` against a single point-in-time recomputation
   made *after* that specific withdrawal alone — precisely the same blind
   spot: each session's own view is internally consistent, and the
   violation exists only in the combination the constraint never sees
   both halves of at once.
3. Claim: the actual mechanism is a missing write conflict, not a missing
   constraint. | Proof: two sessions both ran `SELECT SUM(amount_minor)
   FROM ledger_entries WHERE account_id = 2` before either committed,
   both got the same pre-race value, and both then `INSERT`ed into
   *different* rows of `ledger_entries` — no lock either session took
   ever collided with the other's, on Read Committed or on Repeatable
   Read (verify this yourself: re-run the same two-session race under
   `BEGIN ISOLATION LEVEL REPEATABLE READ` and the second commit still
   succeeds — see
   `content/primers/isolation-anomaly-ladder.md#repeatable-read-does-not-prevent-write-skew`).
4. Claim: `SELECT ... FOR UPDATE` against a row in `accounts` fixes it,
   by manufacturing the write conflict that was missing. | Proof (sketch
   for `answers/withdraw.sql`):
   ```sql
   BEGIN;
   SELECT account_id FROM accounts WHERE account_id = :account_id FOR UPDATE;
   -- second concurrent session now blocks HERE until this commits
   -- (accounts.balance_minor's own value is irrelevant; the row is a lock target)
   -- now derive the TRUE balance:
   SELECT COALESCE(SUM(amount_minor), 0)
     FROM ledger_entries WHERE account_id = :account_id;
   -- if covered:
   INSERT INTO ledger_entries (entry_id, payment_id, account_id, direction, amount_minor, currency, posted_date, created_at)
     VALUES (:entry_id, :payment_id, :account_id, 'D', -:withdraw_amount, 'USD', current_date, now());
   COMMIT;
   -- if not covered: ROLLBACK;
   ```
   (`amount_minor` is `-:withdraw_amount`, not `:withdraw_amount` — the
   schema signs debits negative, and `:withdraw_amount` is handed to this
   script as a positive magnitude.)
   The second session's `FOR UPDATE` blocks until the first commits, then
   re-reads `ledger_entries` fresh — the invariant is defended because the
   two transactions can no longer both believe they are reading the same
   pre-race state.
5. Claim: `SERIALIZABLE` with a retry loop fixes it by a different
   mechanism — detecting the dangerous dependency after the fact instead
   of serializing access up front. | Proof (sketch): both sessions run
   `BEGIN ISOLATION LEVEL SERIALIZABLE;` then the same read-then-insert
   logic with no `FOR UPDATE` at all; PostgreSQL's SSI tracks that both
   transactions read a value that the other one's write invalidates, and
   aborts one of them at commit time with `SQLSTATE 40001`. Retrying that
   is the CALLER's obligation, in the ordinary sense of "caller" — the
   application code that opened the transaction in the first place, not
   a test harness. `harness.sh` happens to implement a bounded retry
   wrapper of its own, generically, around whatever transaction body it
   is given, which is a convenience for grading a submitted `withdraw.sql`
   file in isolation, not a substitute for this obligation: a real
   `withdraw.sql` shipped into an application with a bare `SERIALIZABLE`
   body and no retry logic of its own is only being carried by the
   harness here — in production, an uncaught `40001` is indistinguishable,
   from the caller's perspective, from the withdrawal having failed, and
   nothing upstream of the harness would ever retry it for you.

**Diagnosis:** the negative balance is write skew: two transactions each
read an overlapping input (`ledger_entries` summed for one account), each
write to a *different*, non-conflicting row, and both commit — the
combination violates an invariant that spans both rows without either
write breaking anything a row-level constraint could see. A `CHECK` on
`accounts.balance_minor` cannot help regardless of whether it is live,
because the writes that caused the violation never touched `accounts` in
the first place.

**Fix applied:** a compensating credit entry restoring the account's
derived balance to non-negative (or removal of the second, uncovered
debit — either is a legitimate repair for the already-committed damage);
separately, `answers/withdraw.sql` written with the `FOR UPDATE`
technique above as the going-forward defence.

**Proof the fix worked (same instrument re-read):** `SELECT
COALESCE(SUM(amount_minor), 0) FROM ledger_entries WHERE account_id =
2;` → `>= 0`. `bash labs/day05/harness.sh labs/day05/answers/withdraw.sql`
→ `PASS: 50/50 rounds held all three invariants (exactly one session
committed, balance never negative), and at least one round showed real
evidence the two sessions contended.` (the harness's own guarantee is
"at least one round," not "every round" — quoted here exactly as it
prints, not as a stronger claim than the instrument actually makes).

**Prediction error and what it tells me:** the `CHECK`-would-have-worked
prediction was wrong not by degree but in kind — it assumed the
constraint's declared table and the invariant's actual scope were the
same thing, when the entire premise of this lab is that they are not.
That is a category error, not a missed edge case, and it is exactly the
error a `CHECK (balance_minor >= 0)` sitting right there in the schema,
syntactically valid and ready to uncomment, is designed to invite.

**What I would check first next time:** before trusting any row-level
constraint to defend a business invariant, name every table and every row
the invariant actually depends on, and check whether the constraint's own
declared table is a strict superset of that set. If it is not — if the
invariant reads from a table the constraint never sees — the constraint
is decorative for this specific failure mode, regardless of how correct
it looks sitting in the schema.

**Trade-off between the two correct defences:** `FOR UPDATE` costs
nothing extra when contention is rare (readers of unrelated accounts
never block), is simple to reason about locally, and degrades to ordinary
lock-wait latency under contention rather than aborting anything — but it
requires knowing, in advance, which row to lock, and it does not
generalize past account-level defences: a broader invariant spanning
rows with no natural single lock target has no `FOR UPDATE` equivalent.
`SERIALIZABLE` generalizes to any read/write dependency the planner can
express, at the cost of every transaction on that connection paying SSI's
predicate-lock bookkeeping and, more importantly, obliging every caller
to implement a bounded, backed-off retry loop — a `SERIALIZABLE`
transaction with no retry loop around it is not a partial defence, it is
a withdrawal that now silently fails under load it used to succeed under.
