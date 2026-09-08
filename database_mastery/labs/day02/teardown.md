# Day 2 teardown

Nothing here is required before moving on to Day 3, and the stack stays
up — Day 2 has no `break.sh` to reverse and nothing it built is in Day 3's
way.

## `payments_norm`

`payments_norm` is a schema you built alongside the canonical `payments`
tables; no later day reads from it. You can leave it in place indefinitely
at no cost — it is a handful of tables sized to the same `SCALE` as
everything else, and having it sit there is genuinely useful for
revision: come back to it after Day 5's concurrency work and re-run the
lossless-join reconciliation query by hand, or after Day 6 and check
whether your `payments_norm.payments` foreign keys behave the way you
expect under a restore.

If you want a clean slate anyway:

```sql
DROP SCHEMA payments_norm CASCADE;
```

## `merchant_catalog`

Leave the restructured, bucketed `merchant_catalog` as it is. No later
day depends on its original oversized shape, and nothing reverts it
automatically — if you want the original single-document-per-merchant
seed data back for any reason, re-run the Task 2 seed loader's MongoDB
stage (`labs/stack/seed/README.md`), which rebuilds `merchant_catalog`,
`payment_events`, and `catalog_seed_meta` from scratch, deterministically,
at whatever `SCALE` you set.

## The stack

Do not tear down `pg`, `my`, `mongo`, or `ws`. Every later day in this
path assumes the same running stack and the same seeded dataset Day 1
and Day 2 both used.
