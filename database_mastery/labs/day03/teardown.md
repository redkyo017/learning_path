# Day 3 teardown

Day 4 measures the planner's statistics and cost estimates against
`payments` and `ledger_entries`. Any index left in place from this lab
— correct or decoy — changes which access paths the planner considers,
which changes the plans Day 4 asks you to read. Leaving Day 3's indexes
in place does not make Day 4 impossible, but it does make its plans
different from the ones its content and `SOLUTION.md` describe, and
comparing your output against them stops being a fair comparison.
Restore the index-free baseline before starting Day 4.

- [ ] `verify.sh` exits `0`. If it does not, finish the lab before
      tearing down — a teardown does not substitute for a passing
      verify.
- [ ] Drop whichever correct index you built this run. Only one of the
      three exists depending on which scenario `break.sh` handed you;
      running all three `DROP INDEX IF EXISTS` statements is safe
      regardless of which one that was:
      ```sql
      DROP INDEX IF EXISTS idx_payments_merchant_created;
      DROP INDEX IF EXISTS idx_payments_disputed_created;
      DROP INDEX IF EXISTS idx_ledger_direction_posted;
      ```
      Run via:
      ```bash
      docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
        "DROP INDEX IF EXISTS idx_payments_merchant_created; \
         DROP INDEX IF EXISTS idx_payments_disputed_created; \
         DROP INDEX IF EXISTS idx_ledger_direction_posted;"
      ```
- [ ] Confirm no non-primary-key index remains on `payments` or
      `ledger_entries`:
      ```bash
      docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
        "SELECT tablename, indexname FROM pg_indexes \
         WHERE tablename IN ('payments','ledger_entries') \
           AND indexname NOT LIKE '%_pkey';"
      ```
      returns no rows.
- [ ] Drop the MongoDB index added for `payment_events`. `verify.sh`
      accepts either sort direction on `ts` (both use the same `IXSCAN`),
      so drop whichever one you actually built by its key shape rather
      than assuming `-1`:
      ```bash
      docker compose -p dbmastery exec mongo mongosh --quiet payments \
        --eval 'db.payment_events.getIndexes()
          .filter(ix => ix.name !== "_id_" && "merchant_id" in ix.key && "ts" in ix.key)
          .forEach(ix => db.payment_events.dropIndex(ix.name))'
      ```
      Confirm with `db.payment_events.getIndexes()` — only `_id_`
      should remain.
- [ ] Re-run `ANALYZE` so leftover statistics from this lab's indexed
      state don't linger:
      ```bash
      docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
        "ANALYZE payments; ANALYZE ledger_entries;"
      ```
- [ ] Clear this lab's stashed files so a re-run starts clean:
      ```bash
      docker compose -p dbmastery exec pg rm -f /tmp/.day03-target
      docker compose -p dbmastery exec ws rm -f /tmp/answer /tmp/day03-query.sql
      ```
- [ ] Leave the stack running for Day 4, or bring it down with
      `docker compose -p dbmastery down` if this is the last lab of the
      session — the seeded data itself is untouched by this lab and
      does not need reseeding before Day 4.
