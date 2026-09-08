# Day 5 lab — concurrency: transactions, isolation, locks

## Goal

`break.sh` leaves two independent incidents on the stack: a five-session
lock pileup on `accounts.account_id = 1`, and an already-committed
write-skew violation that has driven a different account's derived
balance negative. Diagnose the pileup to its actual root before touching
anything, then defend the invariant the pileup's cousin incident broke —
this lab's fourth deliverable is a real concurrency defence, raced 50
times against itself, not a one-off fix.

There are **four deliverables**, and all four are required:

1. `root_blocker=<pid>` written to `/tmp/answer` inside the `ws`
   container — the same place every day's answer file lives. The
   diagnosis itself happens against `pg` (that is where
   `pg_stat_activity`/`pg_locks` live), but the answer you record goes to
   `ws`, exactly like every other day.
2. The blocking chain actually resolved: no session left waiting on a
   lock, no idle-in-transaction session left older than 60 seconds.
3. The negative-balance account repaired, so no account's balance —
   computed by summing `ledger_entries`, never read from
   `accounts.balance_minor` — is negative.
4. `labs/day05/answers/withdraw.sql`: a transaction body that defends the
   invariant "this account's derived balance never goes negative" under
   real concurrency, verified by racing it 50 times with `harness.sh`.

## Deliverable 1 and 2 — the blocking chain

Read the printed `SYMPTOM` line and nothing else at first. From inside
the `pg` container (`docker compose -p dbmastery exec pg psql -U dbm -d
payments`), read `pg_stat_activity` and `pg_locks` raw, per `STRATEGY.md`
step 2, before naming anything. Five sessions are involved; only one of
them is the root. The session that has been waiting the longest is
**not** it. `pg_blocking_pids()` does not hand you the whole chain in one
call — it names whoever is immediately ahead of the session you ask
about (the lock holder, plus anyone already queued ahead of it for the
same lock). Call it again on whatever it names, and again, until it
names an empty set — that session is the root
(`content/primers/catalog-field-reference.md`,
`#pg_locks-and-pg_blocking_pids`). Write your evidence chain in
`journal.md` **before** terminating anything — `STRATEGY.md`, "The daily
loop," step 5.

Once you have the root's PID, record it where every other day's answer
lives — inside `ws`, not `pg`:

```bash
docker compose -p dbmastery exec ws sh -c 'echo "root_blocker=<the pid you found>" > /tmp/answer'
```

Then, from inside the `pg` container, terminate it:

```sql
SELECT pg_terminate_backend(<the pid you found>);
```

Re-read `pg_stat_activity` to confirm the four queued sessions have all
completed and nothing is left waiting on a lock or sitting old and idle
in transaction.

The root blocker has a bounded lifetime — 900 seconds — and self-commits
on its own if you never touch it. That bound exists so a forgotten run of
this lab cannot wedge the stack indefinitely, not as a substitute for
doing the diagnosis yourself: 900 seconds is meant to comfortably outlast
a real evidence-chain write-up, not to be raced against. `verify.sh`
checks your stated `root_blocker=` value against the session `break.sh`
actually made root, independent of whether the chain happens to have
cleared on its own by the time you run it. If you let it expire, or want
to start over, re-running `bash labs/day05/break.sh` is safe — it clears
its own previous sentinel rows and stash file before building a fresh
incident.

## Deliverable 3 — repair the negative balance

`break.sh` committed two concurrent withdrawals against one account,
each individually covered by the balance it read, together not. Find
the extra debit rows in `ledger_entries` and correct the ledger (a
compensating credit, or removing the overdraft you decide should not
have gone through — either is a legitimate repair; `verify.sh` only
checks the resulting sum, not which of the two you chose). Confirm with
the same instrument you used to find it: sum `ledger_entries` by
`account_id`, do not read `accounts.balance_minor` — it was never
touched by the race and proves nothing about what actually happened.

## Deliverable 4 — `answers/withdraw.sql`

Write a transaction body, at `labs/day05/answers/withdraw.sql`, that
withdraws from a test account without ever letting two concurrent
withdrawals overdraw it. `harness.sh` invokes it via `psql`'s `-v` flag
with four bound variables — reference them in your SQL as:

```
:account_id         the test account to withdraw from
:payment_id         a valid payment_id, to satisfy ledger_entries' FK
:withdraw_amount    the amount to withdraw, in minor units, as a
                    POSITIVE magnitude
:entry_id           the ledger_entries.entry_id THIS session should use
                    if — and only if — the withdrawal is covered
```

This schema signs `amount_minor` itself — credits positive, debits
negative (`labs/stack/seed/README.md`, "The accounts/ledger invariant";
`content/GLOSSARY.md`) — so an account's true balance is a plain `SUM
(amount_minor)`, never a `direction`-based `CASE`. `:withdraw_amount` is
handed to you as a positive number; your debit row's `amount_minor` must
be `-:withdraw_amount`, not `:withdraw_amount`. Get the sign backwards
and you have written a credit that happens to carry a debit's
`direction`, which inflates the balance instead of reducing it — the
harness will not catch that mistake for you, since a balance that only
ever grows can never go negative no matter how broken your defence is.

Your script must, in one transaction: determine the account's TRUE
balance (`SELECT COALESCE(SUM(amount_minor), 0) FROM ledger_entries
WHERE account_id = :account_id`), and if `:withdraw_amount` is covered,
`INSERT` exactly one debit row — `amount_minor = -:withdraw_amount`,
`direction = 'D'` — using `:entry_id`, then commit. If it is not covered
— including because a concurrent session already spent the funds — abort
cleanly, by whatever means your chosen technique uses (an explicit
`ROLLBACK`, a raised exception, or a `SERIALIZABLE` transaction's own
serialization failure). `harness.sh` accepts any technique that holds the
invariant; it never inspects how your script arrived at its result, only
whether the result is correct.

`content/day05.md`'s exercise 5 walks through why a `CHECK
(balance_minor >= 0)` cannot be that technique, and `SOLUTION.md` has two
worked defences (`SELECT ... FOR UPDATE`, and `SERIALIZABLE` with a
retry loop) if you want to compare approaches after your own attempt
passes.

## Success signal

`labs/day05/verify.sh` exits `0`.

## How to run

From the repository root, with the stack up and seeded:

```bash
bash labs/day05/break.sh
```

Read the `SYMPTOM` line, then work the blocking chain and the
negative-balance repair as described above. Write
`labs/day05/answers/withdraw.sql` (deliverable 4) whenever you like
relative to the first three — nothing about it depends on the injected
incidents still being present.

You can race your own draft directly, without going through
`verify.sh`, at any point:

```bash
bash labs/day05/harness.sh labs/day05/answers/withdraw.sql
```

**Expect a few minutes, not a hang.** `00-schema.sql` creates no index on
`ledger_entries` beyond its primary key, and each round would otherwise
do three full passes of that table (the fixture reset, both sessions'
own balance reads, the post-round check) — so `harness.sh` builds a
plain, temporary index on `ledger_entries(account_id)` before its first
round and drops it again when it finishes (including on an interrupted
run), turning all three into fast lookups instead. What is left is
mostly the rendezvous barrier itself: 3 seconds per round × 50 rounds is
2.5 minutes on its own, plus ordinary `docker compose exec` overhead for
the handful of round-trips each round makes. The round count is 50
because that is what this lab specifies, not a default left unexamined —
reducing it would weaken the one property (`harness.sh` never accepting
a run with zero evidence of contention) that this lab's crown-lab status
rests on, so it stays at 50.

On failure it prints the exact round that broke — which session
committed, which didn't, and the derived balance after that round — so
you do not have to guess which of the 50 rounds is the interesting one.
It also refuses to print `PASS` at all if none of the 50 rounds shows any
evidence the two sessions actually contended with each other (a retried
serialization failure/deadlock, or the two sessions' measured wall-clock
intervals actually overlapping) — a defence that "passes" only because
the two sessions never actually overlapped has proven nothing, and this
harness says so instead of reporting success.

Once all four deliverables are in place:

```bash
bash labs/day05/verify.sh
```

Check 4 runs `harness.sh` itself, so `verify.sh` takes the same few
minutes described above once it reaches that check — this is expected.

If it exits non-zero, it names exactly which of the four checks is still
failing. When it exits `0`, follow `teardown.md` before moving on to
Day 6 — Day 6 assumes no leftover idle-in-transaction session from this
lab is still pinning the vacuum horizon.

No further hints here. `SOLUTION.md` has the full chain of evidence —
root-blocker diagnosis, the failed `CHECK` approach and why it fails,
and two correct defences with their trade-off — if you get stuck, but
reading it before your own attempt skips the lesson this lab exists to
teach.
