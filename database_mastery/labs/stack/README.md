# dbmastery lab stack

Four containers — `pg` (PostgreSQL 16), `my` (MySQL 8.4), `mongo` (MongoDB 7,
single-member replica set `rs0`), and `ws` (a Debian workbench with the
`psql`, `mysql`, `mongosh`, `pgbench`, `pg_repack`, `jq`, `python3` clients on
`PATH`) — running under the compose project name `dbmastery`. All eight days
of this course run their commands against this stack.

## Prerequisites

- Docker Desktop (or an equivalent Docker Engine + Compose v2 install).
- About 6 GB of free disk for images and the seeded volumes.
- Docker configured with at least 4 GB of memory available to containers.

## Bring-up

```bash
cd database_mastery/labs/stack
docker compose -p dbmastery up -d --build
```

Wait for all three database services to report healthy:

```bash
docker compose -p dbmastery ps
```

MongoDB needs its replica set initiated once, the first time the stack is
brought up on fresh volumes:

```bash
docker compose -p dbmastery exec mongo mongosh --quiet --eval 'rs.initiate()'
```

Then load the dataset. The seed loader itself (schema + deterministic
generator + per-engine loaders) is described in
`labs/stack/seed/README.md` — run the seeding command documented there
before starting Day 1.

## Your shell

All lab work — every day's `README.md`, `verify.sh`, and exercises — runs
from inside the `ws` container, not from your host shell:

```bash
docker compose -p dbmastery exec ws bash
```

Your repository is mounted at `/work` inside `ws` (that is also its
`WORKDIR`), so paths inside `ws` match paths in your checkout.

## Connecting

From inside `ws`, reach Postgres and Mongo directly by service name as the
host:

```bash
# PostgreSQL
PGPASSWORD=dbmastery psql -h pg -U dbm -d payments

# MongoDB
mongosh --host mongo payments
```

For MySQL, exec straight into the `my` container and use its own bundled
client instead of connecting from `ws` over the network. `ws`'s MySQL
client package (`default-mysql-client`, which resolves to `mariadb-client`
on Debian bookworm) is not a guaranteed-clean match for MySQL 8.4's default
`caching_sha2_password` authentication — exec'ing into `my` sidesteps that
cross-vendor client/auth question entirely, and is also how
`labs/lib/common.sh`'s `in_my` helper connects for every lab's automated
commands:

```bash
docker compose -p dbmastery exec my mysql -u dbm -pdbmastery payments
```

(`dbmastery` is the local-only development password for this stack — see
the comment block at the top of `docker-compose.yml`.)

## Reset

To wipe the stack back to empty and start over:

```bash
docker compose -p dbmastery down -v
```

**Warning:** the `-v` flag deletes the named volumes (`pgdata`, `pgarchive`,
`mydata`, `mongodata`) along with them — this destroys the seeded dataset.
After a `-v` reset you must bring the stack back up, re-run `rs.initiate()`,
and re-run the Task 2 seed loader before any lab will work again. If you
want only to restart the containers without losing data, omit `-v` (plain
`docker compose -p dbmastery down` followed by `up -d`, or
`docker compose -p dbmastery restart`).

## Why the memory settings are small

`shared_buffers=256MB` (Postgres), `innodb_buffer_pool_size=256M` (MySQL),
and the 0.5 GB WiredTiger cache (Mongo) are **deliberately** far below what
your host's ~24 GB of RAM could support. This is not an oversight and you
should not raise these values.

The dataset in this course is sized so its working set is larger than these
buffer pools. That gap is what makes the tuning lessons real: with the
working set larger than the buffer pool, `EXPLAIN (ANALYZE, BUFFERS)`
reports a meaningful mix of `shared hit` (block found already in the pool)
versus `shared read` (block fetched from the OS/disk), and sequential scans
carry real, visible cost. The same logic holds for MySQL's buffer-pool hit
ratio and Mongo's WiredTiger cache eviction pressure. A generously
configured stack would cache the entire working set in memory, every query
would hit, and every buffer-accounting and I/O-cost lesson in this course
would end up teaching the opposite of what happens on a real,
memory-constrained production system.
