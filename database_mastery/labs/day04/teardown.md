# Day 4 teardown

Run these against the `pg` service (`docker compose -p dbmastery exec pg
psql -U dbm -d payments`) before moving on to Day 5, so Day 5 starts from
a clean statistics baseline rather than one still carrying Day 4's
deliberately shifted distribution.

```sql
-- Re-enable autovacuum on payments -- break.sh turned it off, and leaving
-- it off would let Day 5's own writes accumulate unvacuumed indefinitely.
ALTER TABLE payments SET (autovacuum_enabled = true);

-- Confirm the n_distinct override is actually gone (a no-op if you
-- already cleared it as part of the fix, safe to run either way).
ALTER TABLE payments ALTER COLUMN merchant_id RESET (n_distinct);

-- Restore the rows break.sh's bulk UPDATE reassigned, using the side
-- table it saved them to before touching anything. This is not optional
-- cleanup: the UPDATE moved a large, disproportionate slice of captured
-- payments onto one previously-unremarkable merchant, and that merchant
-- now sits far higher in the power-law skew than the seed ever put it.
-- Skipping this step leaves that distortion in place for every day after
-- this one -- Days 5-8 assume the seeded power-law skew is the real one,
-- not one this lab silently altered.
UPDATE payments p
SET merchant_id = o.merchant_id
FROM day04_original_merchants o
WHERE p.payment_id = o.payment_id;

DROP TABLE IF EXISTS day04_original_merchants;

-- Optional: drop the extended statistics object created during the lab.
-- Keep it if you'd rather carry the corrected correlation estimate
-- forward -- it costs nothing at query time it wasn't already costing,
-- and nothing downstream depends on it being absent. Use whatever name
-- you actually created it under; the one used in SOLUTION.md is shown
-- here.
DROP STATISTICS IF EXISTS payments_country_currency;

-- Refresh statistics on both tables the lab touched, so the next day
-- starts from an honest baseline instead of whatever ANALYZE happened to
-- run mid-lab.
ANALYZE payments;
ANALYZE wide_payments;
```

Leave `payments_merchant_id_idx` in place — Day 5 does not depend on the
index baseline being empty the way Day 4 did against Day 3's teardown,
and dropping it here buys nothing.
