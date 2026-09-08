# Day 6 teardown

Day 7 moves to distribution — RDS failover and a MongoDB Atlas hot-shard
drill — and does not touch anything this lab created. Even so, this lab
leaves real artifacts behind inside the `pg`, `ws`, and `mongo` containers
(a base backup, a scratch data directory, a synthetic table, a full
`mongodump --oplog`, and a scratch `mongod` instance) that serve no
purpose past this lab and are worth clearing so a later `break.sh`
re-run, or a fresh attempt at this lab, starts clean.

- [ ] `verify.sh` exits `0`. If it does not, finish the lab before tearing
      down — a teardown does not substitute for a passing verify.
- [ ] Confirm the scratch PITR instance is stopped (it should already be,
      from step 5 of `README.md`):
      ```bash
      docker compose -p dbmastery exec pg bash -c \
        '[ -f /tmp/day06-pitr/postmaster.pid ] && pg_ctl -D /tmp/day06-pitr stop || echo "already stopped"'
      ```
- [ ] Remove the base backup and the scratch restore directory:
      ```bash
      docker compose -p dbmastery exec pg rm -rf /tmp/day06-basebackup /tmp/day06-pitr /tmp/day06-pitr.log /tmp/day06-recovered-status.csv
      ```
- [ ] Drop the synthetic churn table — it isn't part of the canonical
      schema and nothing later depends on it:
      ```bash
      docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
        "DROP TABLE IF EXISTS idempotency_keys;"
      ```
      If you'd rather keep it around for further practice instead of
      dropping it, reset it to the default autovacuum behavior by
      removing the storage parameters this lab set, instead of dropping
      the table:
      ```bash
      docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
        "ALTER TABLE idempotency_keys RESET (autovacuum_enabled,
           autovacuum_vacuum_scale_factor, autovacuum_vacuum_threshold);"
      ```
- [ ] Confirm disk was actually reclaimed, not only marked reusable —
      compare the database size before dropping (if you kept a note of it)
      against after, or at minimum confirm the table itself is gone:
      ```bash
      docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
        "SELECT pg_size_pretty(pg_database_size('payments'));"
      docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
        "SELECT count(*) FROM information_schema.tables WHERE table_name = 'idempotency_keys';"
      ```
      The second query should return `0`.
- [ ] Confirm the `payments` fix is durable and no stray session remains
      before moving on:
      ```bash
      docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
        "SELECT status, count(*) FROM payments GROUP BY status;"
      docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
        "SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction';"
      ```
      The second query should return `0`.
- [ ] Confirm the scratch Mongo instance is stopped (it should already be,
      from step 7 of `README.md`):
      ```bash
      docker compose -p dbmastery exec mongo bash -c \
        '[ -f /tmp/day06-mongo-restore/mongod.lock ] && mongosh --quiet --port 27018 admin --eval "db.shutdownServer({force: true})" || echo "already stopped"'
      ```
- [ ] Remove the Mongo dump, the scratch restore directory, and the
      recovered-documents export:
      ```bash
      docker compose -p dbmastery exec ws rm -rf /tmp/day06-mongodump /tmp/day06-recovered-events.jsonl
      docker compose -p dbmastery exec mongo rm -rf /tmp/day06-mongo-restore /tmp/day06-mongo-restore.log
      ```
- [ ] Confirm the `payment_events` fix is durable — the damaged
      merchant/type/window is back at its pre-damage document count
      before moving on:
      ```bash
      docker compose -p dbmastery exec mongo mongosh --quiet payments --eval \
        "db.payment_events.countDocuments({merchant_id: 1, type: 'chargeback', ts: {\$gte: ISODate('2025-01-01T00:00:00.000Z'), \$lt: ISODate('2025-01-01T06:00:00.000Z')}})"
      ```
- [ ] Clear this lab's stashed files so a re-run starts clean:
      ```bash
      docker compose -p dbmastery exec pg rm -f /tmp/.day06-target
      docker compose -p dbmastery exec ws rm -f /tmp/answer
      ```
- [ ] Leave the stack running for Day 7, or bring it down with
      `docker compose -p dbmastery down` if this is the last lab of the
      session — the seeded dataset itself is untouched by this lab's
      teardown and does not need reseeding before Day 7.
