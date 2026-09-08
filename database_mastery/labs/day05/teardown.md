# Day 5 teardown

Three things to confirm before moving on to Day 6, which assumes no
leftover long-running transaction from this lab is still pinning the
vacuum horizon.

## 1. Terminate any surviving background session

`break.sh`'s root blocker and its four queued sessions are bounded (the
root self-commits after 900 seconds even if untouched), but if you are
tearing down shortly after running the lab, one or more may still be
alive. From inside the `pg` container:

```sql
SELECT pid, state, now() - xact_start AS age
FROM pg_stat_activity
WHERE datname = 'payments' AND pid <> pg_backend_pid()
ORDER BY xact_start;
```

Terminate anything still there with the exact query this lab's diagnosis
already used:

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'payments'
  AND state = 'idle in transaction'
  AND now() - xact_start > interval '60 seconds';
```

This targets `state = 'idle in transaction'` only, which is the root
blocker's own state — it will not directly match any of the four queued
sessions, since they show `state = 'active'` (blocked on a lock, not idle
in transaction). That is not a gap: those four are waiting on the root's
row lock, not holding one of their own, so terminating the root releases
the lock they are queued for and each of them completes and exits on its
own within moments. If any of the four is somehow still present after
terminating the root, terminate it directly by `pid` from the first
query's output.

Re-run the first query and confirm it now returns no rows beyond your
own session.

## 2. Restore the test account's balance

`break.sh` committed two extra debit rows against merchant account 2
(`entry_id` 9000000000001 and 9000000000002). Remove them, restoring the
account to the balance it had before this lab ran:

```sql
DELETE FROM ledger_entries WHERE entry_id IN (9000000000001, 9000000000002);
```

`harness.sh` also leaves its own synthetic fixture behind — always, not
only when it fails, since `verify.sh` runs it as part of check 4 on every
successful pass too. It shares no data with anything else in the seeded
dataset, so clean it up unconditionally:

```sql
DELETE FROM ledger_entries WHERE account_id = 999999999;
DELETE FROM payments WHERE payment_id = 999999999;
DELETE FROM accounts WHERE account_id = 999999999;
```

`harness.sh` also builds a temporary index,
`day05_harness_ledger_account_idx`, on `ledger_entries(account_id)`
before its first round, and drops it itself via a `trap` when it exits —
normal completion or a failure both trigger it. As a belt-and-braces
check (a `kill -9` from outside the script bypasses any trap), confirm
it is actually gone:

```sql
DROP INDEX IF EXISTS day05_harness_ledger_account_idx;
```

Confirm the repair (`amount_minor` already carries its own sign — credits
positive, debits negative — so this is a plain sum, never a
`direction`-based `CASE`):

```sql
SELECT COALESCE(SUM(amount_minor), 0)
FROM ledger_entries WHERE account_id = 2;
```

## 3. Confirm no idle-in-transaction session remains

```sql
SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction';
```

This should return `0` (aside from any transaction you are actively
running to check it, which will not show this state). If it does not,
repeat step 1 — Day 6's point-in-time recovery lab and its bloat
measurements assume the vacuum horizon is not still pinned by anything
left over from today.

Leave the stack running between sessions:

```bash
docker compose -p dbmastery stop
```

Do **not** run `docker compose -p dbmastery down -v` — that discards the
seeded dataset, and every day from here on depends on it.
