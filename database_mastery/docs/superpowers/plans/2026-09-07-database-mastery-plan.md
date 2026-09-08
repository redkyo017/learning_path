# Database Mastery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author an 8-day, 24-hour instrument-first database mastery path covering storage, logical design, indexing, planning, concurrency, durability and distribution across PostgreSQL, MySQL and MongoDB, with diagnostic-gauntlet labs.

**Architecture:** A single Docker Compose stack (`dbmastery`) hosts PostgreSQL 16, MySQL 8.4, MongoDB 7 and a workstation container, seeded with a deterministic, power-law-skewed payments/ledger dataset. Each day pairs a content file with a lab directory; diagnostic days ship a `break.sh` that injects one pathology and a `verify.sh` that passes only when the learner both fixed it and named its cause. Days follow a six-layer model of what a database is, so no ordering is arbitrary.

**Tech Stack:** Docker Compose, PostgreSQL 16, MySQL 8.4, MongoDB 7, bash, SQL, `mongosh` JavaScript, Terraform (Day 7 only), Markdown.

**Spec:** `database_mastery/docs/superpowers/specs/2026-09-07-database-mastery-design.md` — read it before any task; every task argues from it.

## Global Constraints

Every task's requirements implicitly include this section.

### Standing rules

- **No git operations, ever.** No `git add`, `git commit`, `git push`, `git status`, `git diff`, `git log` — in any task, in any subagent dispatch. The learner handles all VCS.
- **No running infrastructure.** Do not run `docker compose up`, `docker build`, `terraform apply/plan/init`, `aws`, `atlas`, `psql`, `mysql` or `mongosh` against anything. Labs are authored here, run by the learner. Syntax checks (`bash -n`, `python3 -c`) are permitted; execution is not.
- **No real credentials.** No AWS account IDs, access keys, Atlas connection strings, or real passwords in any file. Local-stack dev passwords are the single exception and must be the literal value `dbmastery`, documented as local-only. Terraform ships `terraform.tfvars.example` with placeholders only.
- **Every exercise ships a hint and a solution sketch.** Non-negotiable, all days.
- **Every lab ships** `README.md`, `verify.sh`, `SOLUTION.md`, `teardown.md`. Diagnostic days add `break.sh`.
- **`verify.sh` never hard-codes a value that `break.sh` generated.** `break.sh` stashes the per-run answer in a file under `/tmp/` inside the relevant container; `verify.sh` reads it and compares against the learner's `/tmp/answer` without printing either value.
- **All shell scripts** start `#!/usr/bin/env bash` then `set -euo pipefail`, and are executable-intent (mode noted in the task; do not run `chmod` on files you did not create).
- **Voice:** second person, direct, no filler. Match the prose density of `linux_ops_mastery/content/day03.md`. Never write "simply", "just", "obviously".

### Stack identifiers (exact, used by every task)

| Thing | Value |
|---|---|
| Compose project name | `dbmastery` |
| Services | `pg`, `my`, `mongo`, `ws` |
| Images | `postgres:16`, `mysql:8.4`, `mongo:7`, `ws` built from `Dockerfile.ws` |
| PG database / user / password | `payments` / `dbm` / `dbmastery` |
| MySQL database / user / password | `payments` / `dbm` / `dbmastery` (root password `dbmastery`) |
| Mongo database | `payments`, replica set `rs0` (single member, required for transactions) |
| Host ports | pg `55432`, my `53306`, mongo `57017` — non-default, to avoid colliding with anything already on the learner's machine |
| PG tuning | `shared_buffers=256MB`, `work_mem=4MB`, `effective_cache_size=768MB`, `maintenance_work_mem=64MB`, `track_io_timing=on`, `shared_preload_libraries=pg_stat_statements` |
| PG durability | `wal_level=replica`, `archive_mode=on`, `archive_command` copying to `/var/lib/postgresql/archive`, `max_wal_senders=3` — Day 6's point-in-time recovery is impossible without these, and `archive_mode` needs a restart, so it must be set here rather than by a lab |
| MySQL tuning | `innodb_buffer_pool_size=256M`, `performance_schema=ON`, `slow_query_log=ON`, `long_query_time=0.5` |
| Mongo tuning | `wiredTigerCacheSizeGB=0.5`, `slowms=100`, profiler level 1 |

The three tuning rows are **deliberately below** what the learner's 24 GB host could afford. Never raise them. If a task's content mentions them, it must state why they are small: with the working set larger than the buffer pool, `EXPLAIN (ANALYZE, BUFFERS)` reports meaningful `shared read` versus `shared hit`, and sequential scans have real cost. A generous stack would cache everything and teach the opposite lesson.

### Canonical schema (exact names — every task must use these verbatim)

PostgreSQL and MySQL, database `payments`:

```
merchants(merchant_id BIGINT PK, name TEXT, country CHAR(2), risk_tier SMALLINT, created_at TIMESTAMPTZ)
customers(customer_id BIGINT PK, email TEXT, country CHAR(2), created_at TIMESTAMPTZ)
accounts(account_id BIGINT PK, owner_type TEXT, owner_id BIGINT, currency CHAR(3),
         balance_minor BIGINT, created_at TIMESTAMPTZ)
payment_methods(payment_method_id BIGINT PK, customer_id BIGINT FK, brand TEXT,
         last4 CHAR(4), exp_month SMALLINT, exp_year SMALLINT)
payments(payment_id BIGINT PK, merchant_id BIGINT FK, customer_id BIGINT FK,
         payment_method_id BIGINT FK, amount_minor BIGINT, currency CHAR(3),
         status TEXT, created_at TIMESTAMPTZ, captured_at TIMESTAMPTZ, description TEXT)
ledger_entries(entry_id BIGINT PK, payment_id BIGINT FK, account_id BIGINT FK,
         direction CHAR(1), amount_minor BIGINT, currency CHAR(3),
         posted_date DATE, created_at TIMESTAMPTZ)
refunds(refund_id BIGINT PK, payment_id BIGINT FK, amount_minor BIGINT, reason TEXT, created_at TIMESTAMPTZ)
disputes(dispute_id BIGINT PK, payment_id BIGINT FK, status TEXT, opened_at TIMESTAMPTZ, resolved_at TIMESTAMPTZ)
wide_payments(row_id BIGINT PK, plus denormalised copies of payment, merchant,
         customer and payment-method columns — Day 2's starting artifact)
```

MongoDB, database `payments`:

```
payment_events  { _id, payment_id, merchant_id, type, ts, payload: {...} }
merchant_catalog{ _id, merchant_id, name, pricing: {...}, products: [ ... ] }   // products is deliberately unbounded
```

Semantics every task must respect:

- `amount_minor` and `balance_minor` are integer minor units (cents). Never floats.
- `direction` is `'D'` (debit) or `'C'` (credit). Double entry: every `payment_id` has debit and credit lines summing to zero.
- `payments.status` ∈ `{'pending','captured','failed','refunded','disputed'}`.
- `payments.description` is long free text — this is the column that gets TOASTed in PostgreSQL. Day 1 depends on it.
- `merchants.country` and `payments.currency` are **correlated** (a GB merchant overwhelmingly bills GBP). Day 4's extended-statistics lesson depends on this correlation existing.
- Merchant activity is **power-law skewed**: the top 1% of merchants own roughly half the `payments` and `ledger_entries` rows. Every tuning lesson depends on this.
- `payment_events.ts` is monotonically increasing — Day 7's hot-shard lesson depends on it.

### Scale

`SCALE` environment variable, default `10`, meaning millions of `ledger_entries`. Derived counts at `SCALE=10`: 2 000 merchants, 500 000 customers, 5M `payments`, 10M `ledger_entries`, 2M MySQL `ledger_entries` subset, 2M `payment_events`. All generation is deterministic — `setseed(0.42)` in PostgreSQL, a fixed seed in the Mongo loader — so `verify.sh` can assert on concrete numbers.

### `labs/lib/common.sh` interface (defined in Task 3, used by every lab)

```bash
require_stack            # exits 1 with instructions if the dbmastery stack is not up
in_pg   "<sql>"          # runs SQL in the pg service as user dbm on database payments, returns tuples-only output
in_my   "<sql>"          # same for MySQL, batch mode, no column headers
in_mongo "<js>"          # same for mongosh, --quiet, database payments
answer_check "<stash_path>" "<container>"   # compares /tmp/answer against the stashed per-run value; prints
                                            # neither; returns 0 on match, 1 otherwise
say_symptom "<text>"     # prints exactly one line: "SYMPTOM: <text>"
pass "<msg>" / fail "<msg>"                 # consistent verify.sh output; fail sets the exit flag
```

---

## File Structure

```
database_mastery/
├── README.md                   Task 4   quickstart, 8-day map, the daily loop
├── STRATEGY.md                 Task 4   the law, the ordering, the 12 mistakes
├── journal.md                  Task 4   evidence-chain template
├── COVERAGE.md                 Task 14  syllabus mapping, written last
├── content/
│   ├── GLOSSARY.md             Task 5
│   ├── primers/                Task 5   3 field-reference primers
│   └── day01.md … day08.md     Tasks 6–13
└── labs/
    ├── stack/                  Task 1   compose, Dockerfile.ws, conf/
    │   └── seed/               Task 2   schema + deterministic generator + loaders
    ├── lib/common.sh           Task 3
    ├── verify-teardown.sh      Task 3
    └── day01/ … day08/         Tasks 6–13
```

**Dependency order:** Tasks 1–5 are foundation and must complete before any day task. Tasks 6–13 (the eight days) are independent of each other once the foundation exists and may be dispatched in parallel. Tasks 14–15 run last and depend on all days.

---

### Task 1: Stack scaffold

**Files:**
- Create: `database_mastery/labs/stack/docker-compose.yml`
- Create: `database_mastery/labs/stack/Dockerfile.ws`
- Create: `database_mastery/labs/stack/conf/postgresql.conf`
- Create: `database_mastery/labs/stack/conf/my.cnf`
- Create: `database_mastery/labs/stack/conf/mongod.conf`
- Create: `database_mastery/labs/stack/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the four service names `pg`, `my`, `mongo`, `ws`; compose project `dbmastery`; the credentials and ports in Global Constraints; a `ws` container with `psql`, `mysql`, `mongosh`, `pgbench`, `pg_repack`, `jq`, `bash`, `python3` on `PATH`; named volumes `pgdata`, `pgarchive`, `mydata`, `mongodata`; the repo mounted at `/work` inside `ws`.

- [ ] **Step 1: Write `docker-compose.yml`**

Four services. `pg` mounts `./conf/postgresql.conf` and starts with `-c config_file=/etc/postgresql/postgresql.conf`; environment `POSTGRES_DB=payments`, `POSTGRES_USER=dbm`, `POSTGRES_PASSWORD=dbmastery`; port `55432:5432`; volumes `pgdata:/var/lib/postgresql/data` and `pgarchive:/var/lib/postgresql/archive` — the second is where `archive_command` writes WAL segments, and Day 6's PITR reads them from there. `my` mounts `./conf/my.cnf` at `/etc/mysql/conf.d/my.cnf`; environment `MYSQL_ROOT_PASSWORD=dbmastery`, `MYSQL_DATABASE=payments`, `MYSQL_USER=dbm`, `MYSQL_PASSWORD=dbmastery`; port `53306:3306`; volume `mydata:/var/lib/mysql`. `mongo` runs `--replSet rs0 --config /etc/mongod.conf`; port `57017:27017`; volume `mongodata:/data/db`. `ws` builds from `Dockerfile.ws`, mounts `../..:/work`, sets `working_dir: /work`, runs `sleep infinity`, and depends on the other three.

Every service gets a healthcheck: `pg_isready -U dbm -d payments` for `pg`; `mysqladmin ping -h localhost -p$MYSQL_ROOT_PASSWORD` for `my`; `mongosh --quiet --eval 'db.adminCommand({ping:1})'` for `mongo`.

Add a comment block at the top of the file stating: the password `dbmastery` is a local-only development credential, the stack is not reachable outside the host, and the ports are non-default deliberately.

- [ ] **Step 2: Write `Dockerfile.ws`**

Base `debian:bookworm-slim`. Install, in one `apt-get` layer with `--no-install-recommends` and a cleanup of `/var/lib/apt/lists`: `postgresql-client-16`, `postgresql-16-repack` (note in a comment that `pg_repack`'s client binary comes from this package), `default-mysql-client`, `curl`, `ca-certificates`, `gnupg`, `jq`, `python3`, `bash`, `less`, `procps`. Add the MongoDB apt repository and install `mongodb-mongosh` and `mongodb-database-tools` (for `mongoimport`). Set `WORKDIR /work`.

- [ ] **Step 3: Write the three config files**

`conf/postgresql.conf` sets exactly the values in both Global Constraints tuning rows — including `wal_level=replica`, `archive_mode=on`, `archive_command='test ! -f /var/lib/postgresql/archive/%f && cp %p /var/lib/postgresql/archive/%f'` and `max_wal_senders=3` — plus `listen_addresses='*'`, `logging_collector=off`, `log_min_duration_statement=500`, `log_lock_waits=on`, `autovacuum=on`. Every non-obvious line carries a one-line comment saying what it buys the learner. The `shared_buffers=256MB` line carries the full explanation from Global Constraints.

`conf/my.cnf` sets the Global Constraints values under `[mysqld]`, plus `innodb_flush_log_at_trx_commit=1`, `innodb_print_all_deadlocks=ON`, `log_bin=binlog`, `binlog_format=ROW`.

`conf/mongod.conf` sets `storage.wiredTiger.engineConfig.cacheSizeGB: 0.5`, `operationProfiling.mode: slowOp`, `operationProfiling.slowOpThresholdMs: 100`, `replication.replSetName: rs0`, `net.bindIp: 0.0.0.0`.

- [ ] **Step 4: Write `labs/stack/README.md`**

Sections: **Prerequisites** (Docker Desktop, ~6 GB free disk, ~4 GB Docker memory); **Bring-up** (`cd database_mastery/labs/stack && docker compose -p dbmastery up -d --build`, then the one-time `rs.initiate()` for the Mongo replica set, then the seeding command from Task 2); **Your shell** (`docker compose -p dbmastery exec ws bash` — all lab work happens here); **Connecting** (the exact `psql`, `mysql`, `mongosh` invocations from inside `ws`, using service names as hosts); **Reset** (`docker compose -p dbmastery down -v` then re-seed, with the warning that `-v` destroys the seeded data and costs a re-seed); **Why the memory settings are small** (the Global Constraints explanation, in full).

- [ ] **Step 5: Verify**

Run:
```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery/labs/stack
python3 -c "import yaml,sys; d=yaml.safe_load(open('docker-compose.yml')); \
  assert set(d['services'])=={'pg','my','mongo','ws'}, d['services']; \
  print('services ok')"
grep -c 'healthcheck' docker-compose.yml
grep -n 'shared_buffers *= *256MB' conf/postgresql.conf
grep -nE "archive_mode *= *on|wal_level *= *replica" conf/postgresql.conf
grep -n 'pgarchive' docker-compose.yml
grep -rn 'AKIA\|aws_secret\|mongodb+srv://' . || echo "no credentials: ok"
```
Expected: `services ok`; healthcheck count `3`; the `shared_buffers`, `archive_mode`, `wal_level` and `pgarchive` lines all found; `no credentials: ok`. Do **not** run `docker compose up`.

---

### Task 2: Seed schema and deterministic generator

**Files:**
- Create: `database_mastery/labs/stack/seed/00-schema.sql`
- Create: `database_mastery/labs/stack/seed/10-generate.sql`
- Create: `database_mastery/labs/stack/seed/20-mysql-load.sh`
- Create: `database_mastery/labs/stack/seed/30-mongo-load.js`
- Create: `database_mastery/labs/stack/seed/seed.sh`
- Create: `database_mastery/labs/stack/seed/README.md`

**Interfaces:**
- Consumes: the service names, credentials and ports from Task 1.
- Produces: every table and collection in the Global Constraints canonical schema, populated deterministically at `SCALE` (default 10). Also produces, for later tasks: `payments.description` values long enough to TOAST (>2 KB for roughly 1 row in 20); the `merchants.country` ↔ `payments.currency` correlation; power-law merchant skew; three MySQL primary-key variant tables `pk_variant_bigint`, `pk_variant_uuid`, `pk_variant_natural` carrying identical rows under different primary keys (Day 1 depends on all four of these).

- [ ] **Step 1: Write `00-schema.sql`**

PostgreSQL DDL for every table in the canonical schema, with: explicit `PRIMARY KEY`, `FOREIGN KEY` constraints, a `CHECK` on `payments.status` against the five allowed values, a `CHECK` on `ledger_entries.direction IN ('D','C')`, and a `CHECK (balance_minor >= 0)` on `accounts` — **commented out**, with a note that Day 5 asks the learner to decide whether a row-level `CHECK` is sufficient to defend the invariant against write skew. It is not, and discovering that is the lesson.

Create `wide_payments` with no foreign keys and denormalised copies of: `payment_id`, `amount_minor`, `currency`, `status`, `created_at`, `merchant_id`, `merchant_name`, `merchant_country`, `merchant_risk_tier`, `customer_id`, `customer_email`, `customer_country`, `pm_brand`, `pm_last4`, `pm_exp_month`, `pm_exp_year`. This table is Day 2's raw material and must contain the redundancy that makes update, insert and delete anomalies reproducible.

Deliberately create **no indexes beyond primary keys**. Index creation belongs to Day 3, and to each day's `break.sh`.

- [ ] **Step 2: Write `10-generate.sql`**

Uses `\set scale :scale` (psql variable, defaulting via `\if :{?scale}`) and `SELECT setseed(0.42);` as the first statement, so runs are reproducible.

Generation, in dependency order, all via `INSERT ... SELECT FROM generate_series`:

- `merchants`: `2000 * :scale / 10` rows. `country` drawn from a weighted list so `US`, `GB`, `DE`, `FR`, `JP`, `SG`, `BR` appear at differing frequencies. `risk_tier` correlated with country.
- `customers`: `500000 * :scale / 10` rows.
- `accounts`: one per merchant, one per customer, plus one `platform` account. `balance_minor` seeded positive.
- `payment_methods`: 1–3 per customer.
- `payments`: `5000000 * :scale / 10` rows. `merchant_id` drawn from a **power-law** distribution — implement as `1 + floor(power(random(), 3) * merchant_count)` so low ids (the whales) dominate; state in a comment that the cube is what produces the roughly-1%-owns-half skew. `currency` derived from the merchant's country with a 5% deviation rate, which is what makes the correlation real but imperfect. `created_at` spread over 18 months with a business-hours weighting. `status` weighted `captured` 80%, `pending` 8%, `failed` 7%, `refunded` 4%, `disputed` 1%. `description` is short for 19 rows in 20 and a >2 KB repeated string for the twentieth — this is the TOAST material.
- `ledger_entries`: exactly two rows per payment (a `'D'` and a `'C'` summing to zero), giving `10000000 * :scale / 10`. `posted_date` derived from `created_at`.
- `refunds` and `disputes`: derived from payments whose status matches.
- `wide_payments`: `INSERT ... SELECT` joining payments to merchants, customers and payment methods, so it is genuinely redundant by construction.

End with `ANALYZE;` on every table and a `\echo` line reporting each table's row count, so the learner sees the seed succeeded.

- [ ] **Step 3: Write `20-mysql-load.sh`**

Bash. Exports the first 2M `ledger_entries` and their parent rows from PostgreSQL via `\copy ... TO PROGRAM` or `COPY ... TO STDOUT WITH CSV`, then loads them into MySQL with `LOAD DATA LOCAL INFILE`. Creates the MySQL schema first (same canonical names, InnoDB, `utf8mb4`), translating `TIMESTAMPTZ` to `DATETIME(6)` and `TEXT` to `TEXT`/`VARCHAR(255)` as appropriate — note each translation in a comment, because Day 1 asks the learner to reason about row format differences.

Then create the three PK-variant tables, each holding the same 500 000 rows copied from `payments`, differing only in primary key: `pk_variant_bigint` keyed on `BIGINT payment_id`; `pk_variant_uuid` keyed on `CHAR(36)` UUID; `pk_variant_natural` keyed on the composite `(merchant_id, created_at, payment_id)`. Give each the same two secondary indexes on `(status)` and `(created_at)`. Day 1's third deliverable measures the resulting secondary-index sizes, so all three must exist with identical row content.

- [ ] **Step 4: Write `30-mongo-load.js`**

`mongosh` script. Seeds a deterministic PRNG (implement a small LCG inline — `Math.random()` is not seedable). Inserts `2000000 * scale / 10` `payment_events` documents in batches of 10 000 with `ordered: false`, where `ts` increases monotonically across the whole run and `merchant_id` follows the same power-law skew. Inserts `merchant_catalog`, one document per merchant, where the top 20 merchants get a `products` array of 40 000+ entries — large enough that the learner can see the unbounded-array problem approaching the 16 MB limit, which Day 2 asks them to restructure. Also writes a `catalog_seed_meta` collection, one document per merchant as `{merchant_id, product_count}`, recording the product count as seeded. Day 2's `verify.sh` reads this to confirm the learner's restructuring preserved every product — without it, that check is unimplementable.

Creates **no indexes** beyond `_id`. Prints the resulting counts and `db.merchant_catalog.stats().avgObjSize`.

- [ ] **Step 5: Write `seed.sh` and `seed/README.md`**

`seed.sh` runs the four steps in order from inside `ws`, honouring `SCALE` (default 10), printing an elapsed time per stage, and refusing to run twice against a non-empty database unless `FORCE=1` is set.

`README.md` documents: what the dataset represents; the `SCALE` variable and the derived row counts at 10 and at 2; the expected runtime (~15 min at `SCALE=10`) and disk (~6 GB); the determinism guarantee and why it matters (`verify.sh` asserts on real numbers); and an explicit section titled **Why the data is skewed**, giving the Global Constraints reasoning — uniform synthetic data is the single most common reason a tuning exercise teaches nothing.

- [ ] **Step 6: Verify**

Run:
```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery/labs/stack/seed
bash -n 20-mysql-load.sh seed.sh && echo "bash syntax ok"
grep -n 'setseed(0.42)' 10-generate.sql
grep -c 'CREATE TABLE' 00-schema.sql
grep -n 'pk_variant_bigint\|pk_variant_uuid\|pk_variant_natural' 20-mysql-load.sh
grep -n 'power(random()' 10-generate.sql
grep -in 'why the data is skewed' README.md
```
Expected: `bash syntax ok`; the `setseed` line present; at least 9 `CREATE TABLE`s; all three PK variants present; the power-law expression present; the skew section present. Do not connect to any database.

---

### Task 3: Lab library and teardown verifier

**Files:**
- Create: `database_mastery/labs/lib/common.sh`
- Create: `database_mastery/labs/verify-teardown.sh`

**Interfaces:**
- Consumes: service names and credentials from Task 1.
- Produces: exactly the function signatures listed in Global Constraints — `require_stack`, `in_pg`, `in_my`, `in_mongo`, `answer_check`, `say_symptom`, `pass`, `fail` — plus the exit-flag convention: `fail` sets `FAILED=1`, and every `verify.sh` ends with `exit "${FAILED:-0}"`. Every later lab task sources this file and must use these names verbatim.

- [ ] **Step 1: Write `common.sh`**

Sourced, not executed. Begins with a comment naming its consumers ("every `labs/dayNN/verify.sh` and `break.sh`"). `require_stack` checks `docker compose -p dbmastery ps --status running` lists all four services and, if not, prints the exact bring-up command from `labs/stack/README.md` and exits 1. `in_pg` wraps `docker compose -p dbmastery exec -T pg psql -U dbm -d payments -tAX -c "$1"`. `in_my` wraps `... exec -T my mysql -u dbm -pdbmastery --batch --skip-column-names payments -e "$1"`. `in_mongo` wraps `... exec -T mongo mongosh --quiet payments --eval "$1"`.

`answer_check "<stash_path>" "<container>"` reads the stashed value and the learner's `/tmp/answer` from the named container, compares them case-insensitively after trimming whitespace, and returns 0 or 1 — **printing neither value**, so a failing run cannot leak the answer. Add a comment saying exactly that, because it is the property that keeps the labs honest.

`say_symptom` prints `SYMPTOM: $*` and nothing else. `pass` prints `ok: $*`. `fail` prints `FAIL: $*` and sets `FAILED=1`.

- [ ] **Step 2: Write `verify-teardown.sh`**

Executable. Verifies Day 7 left nothing billable. Checks, each independently and each reporting via `pass`/`fail`: no RDS instance whose identifier matches the lab prefix `dbm-lab-` (`aws rds describe-db-instances`); no manual RDS snapshot with that prefix (`aws rds describe-db-snapshots --snapshot-type manual`); no RDS subnet group or parameter group with that prefix; no Atlas cluster named `dbm-lab` (`atlas clusters list`, with a graceful message if the Atlas CLI is absent, since it is optional); and, locally, that `terraform.tfstate` in `labs/day07/terraform/` either does not exist or lists zero resources.

Each check prints the exact command the learner can run themselves to confirm. If the AWS CLI is not configured, the script says so and exits 2 rather than falsely reporting success — a teardown verifier that passes when it could not look is worse than none.

- [ ] **Step 3: Verify**

Run:
```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery/labs
bash -n lib/common.sh verify-teardown.sh && echo "syntax ok"
for f in require_stack in_pg in_my in_mongo answer_check say_symptom pass fail; do
  grep -q "^${f}()" lib/common.sh && echo "$f ok" || echo "$f MISSING"
done
grep -n 'exit 2' verify-teardown.sh
```
Expected: `syntax ok`; all eight functions `ok`; the `exit 2` unconfigured-CLI path present. Do not run either script.

---

### Task 4: Root documents

**Files:**
- Create: `database_mastery/README.md`
- Create: `database_mastery/STRATEGY.md`
- Create: `database_mastery/journal.md`

**Interfaces:**
- Consumes: the spec's strategy, curriculum and mistake table; Task 1's bring-up commands.
- Produces: the canonical wording of **the law**, **the daily loop** (7 steps) and **the 12 mistakes**, which every day file references rather than restates.

- [ ] **Step 1: Write `README.md`**

Sections, in order: a two-paragraph statement of who this is for (a senior engineer whose database theory has decayed into habit, who debugs RDS and Atlas at work) and what it does about that; **Prerequisites** (Docker Desktop, ~6 GB disk, ~4 GB Docker memory, an AWS account and an Atlas account for Day 7 only, with the $2–5 estimate stated up front); **Bring-up** (pointing at `labs/stack/README.md`, not duplicating it); **The 8-day map** as a table with columns Day, Layer, Hours, Lab incident, Content file, Lab dir — filled from the spec's curriculum; **The daily loop** (the 7 steps, one line each, pointing at `STRATEGY.md` for the reasoning); **How a lab works** (`break.sh` prints one `SYMPTOM` line; you diagnose; `verify.sh` checks both the fix and the diagnosis; `SOLUTION.md` exists but reading it early skips the lesson); **Cost and teardown** (Day 7 only, with `verify-teardown.sh`).

- [ ] **Step 2: Write `STRATEGY.md`**

Sections: **The law** (the spec's statement, verbatim, with the three worked illustrations — MVCC, indexes, normal forms); **Why this ordering** (the six-layer model, plus the explicit note that Day 2 sits between storage and access methods because instrument-first requires holding the instruments first); **The daily loop**, all seven steps with a paragraph each — step 3, *predict before you measure*, gets the longest treatment, because it is the mechanism that makes decayed knowledge visible to its owner; **The 12 mistakes that waste most of a learner's time**, reproducing the spec's table and expanding each row into a short paragraph naming why the mistake is seductive; **What this path is not** (not a certification cram, not a benchmark tutorial, not engine-agnostic hand-waving); **Approaches rejected** (failure-first inversion, pure unified-model, benchmark-driven, with the spec's reasoning).

- [ ] **Step 3: Write `journal.md`**

Opens with the rule: one entry per lab, the prediction written **before** the lab is run and the evidence chain written **before** any fix is attempted. Then the chain template:

```markdown
### Day N — <incident in five words>
**Predictions (written before running anything):**
- <quantity>: <predicted value>
**Symptom (verbatim, no interpretation):**
**Layer:** storage | logical | access method | planner | concurrency | durability | distribution
**Chain of evidence:**
1. Claim: … | Proof: `<query>` → `<the output that proves it>`
2. …
**Diagnosis:**
**Fix applied:**
**Proof the fix worked (same instrument re-read):**
**Prediction error and what it tells me:**
**What I would check first next time:**
```

Then one fully worked example entry for Day 1, so the learner sees the intended density. Every `SOLUTION.md` mirrors this skeleton exactly — say so.

- [ ] **Step 4: Verify**

Run:
```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
grep -c '^| ' README.md
grep -in 'predict before you measure' STRATEGY.md
awk '/^\| *[0-9]+ *\|/{n++} END{print "mistake rows:", n}' STRATEGY.md
grep -in 'prediction error' journal.md
grep -rniE '\b(simply|just |obviously)\b' README.md STRATEGY.md journal.md || echo "voice ok"
```
Expected: the 8-day map table present; the step-3 section found; `mistake rows: 12`; the prediction-error line present; `voice ok`.

---

### Task 5: Glossary and field-reference primers

**Files:**
- Create: `database_mastery/content/GLOSSARY.md`
- Create: `database_mastery/content/primers/explain-field-reference.md`
- Create: `database_mastery/content/primers/catalog-field-reference.md`
- Create: `database_mastery/content/primers/isolation-anomaly-ladder.md`

**Interfaces:**
- Consumes: the canonical schema and stack identifiers.
- Produces: the three primers that day files link to instead of re-explaining fields. Day files must reference them as `content/primers/<name>.md#<anchor>`; this task therefore fixes the anchor names by writing the headings.

- [ ] **Step 1: Write `explain-field-reference.md`**

Decodes every field the learner will meet, once, so no day file repeats it. PostgreSQL: the shape of a plan node; `cost=start..total` and what the two numbers mean; `rows` (estimated) versus `actual rows`; `loops` and why `actual rows` is per-loop; `Buffers: shared hit/read/dirtied/written`, `temp read/written`; `Planning Time` versus `Execution Time`; `Rows Removed by Filter`; `Heap Fetches` and its relationship to the visibility map; `Workers Planned/Launched`. MySQL: `EXPLAIN FORMAT=JSON` key fields and `optimizer_trace`. MongoDB: `explain("executionStats")` — `nReturned`, `totalKeysExamined`, `totalDocsExamined`, `executionTimeMillis`, `stage` values `COLLSCAN`/`IXSCAN`/`FETCH`/`SORT`, and `rejectedPlans`.

Include one annotated real-shaped example per engine, against the canonical schema.

- [ ] **Step 2: Write `catalog-field-reference.md`**

PostgreSQL: `pg_stat_user_tables` (`seq_scan`, `n_live_tup`, `n_dead_tup`, `last_autovacuum`, `n_mod_since_analyze`), `pg_statio_user_tables`, `pg_stat_user_indexes` (`idx_scan` — the unused-index signal), `pg_stat_activity` (`state`, `wait_event_type`, `wait_event`, `backend_xmin`, `xact_start`), `pg_locks` and `pg_blocking_pids()`, `pg_stat_statements` (`calls`, `total_exec_time`, `mean_exec_time`, `shared_blks_read`), `pg_class.relpages`/`reltuples`, `pgstattuple`. MySQL: `information_schema.tables` and `innodb_index_stats`, `performance_schema.events_statements_summary_by_digest`, `data_lock_waits`, `SHOW ENGINE INNODB STATUS` sections. MongoDB: `collStats`, `dbStats`, `$indexStats`, `currentOp`, `serverStatus.wiredTiger.cache`, the profiler collection `system.profile`.

For each: what the column actually counts, and the one wrong reading people commonly make of it.

- [ ] **Step 3: Write `isolation-anomaly-ladder.md`**

A matrix of the six anomalies — dirty read, non-repeatable read, phantom, lost update, read skew, write skew — against PostgreSQL (Read Committed, Repeatable Read, Serializable/SSI), MySQL InnoDB (Read Committed, Repeatable Read with gap and next-key locks) and MongoDB (snapshot, with and without a multi-document transaction). Each cell says *prevented* or *possible*, and every cell links to the two-session reproduction script that demonstrates it, which Day 5 supplies. Note explicitly the two facts most often got wrong: MySQL's Repeatable Read prevents phantoms in a way the standard does not require (gap locks), and PostgreSQL's Repeatable Read does **not** prevent write skew — only Serializable does.

- [ ] **Step 4: Write `GLOSSARY.md`**

Plain-English one-to-three-line definitions, alphabetical, for every term the path uses that a rusty engineer might half-remember: ACID, autovacuum, B-tree, BCNF, bloat, buffer pool, chunk, clustered index, covering index, CTE, deadlock, double entry, ESR, extended statistics, fillfactor, functional dependency, gap lock, heap, HOT update, index-only scan, isolation level, jumbo chunk, lossless join, MVCC, next-key lock, N+1, oplog, PACELC, page, partition pruning, PITR, power-law skew, quorum, read replica, replication lag, sargable, selectivity, shard key, snapshot isolation, SSI, TOAST, transaction ID wraparound, tuple header, visibility map, WAL, wide row, WiredTiger, write skew, `xmin`/`xmax`.

- [ ] **Step 5: Verify**

Run:
```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery/content
grep -c '^## \|^### ' primers/explain-field-reference.md
grep -in 'repeatable read does not prevent write skew\|only serializable' primers/isolation-anomaly-ladder.md
grep -in 'gap lock' primers/isolation-anomaly-ladder.md
for t in TOAST "write skew" "index-only scan" sargable "power-law" PACELC; do
  grep -qi "^- \*\*$t\|^\*\*$t\|^## $t" GLOSSARY.md && echo "$t ok" || echo "$t MISSING"
done
```
Expected: a substantial heading count in the EXPLAIN primer; both isolation caveats present; every sampled glossary term found.

---

### Task 6: Day 1 — Storage, and the instruments that read it

**Files:**
- Create: `database_mastery/content/day01.md`
- Create: `database_mastery/labs/day01/README.md`
- Create: `database_mastery/labs/day01/verify.sh`
- Create: `database_mastery/labs/day01/SOLUTION.md`
- Create: `database_mastery/labs/day01/teardown.md`

**Interfaces:**
- Consumes: `labs/lib/common.sh` (Task 3); the seeded schema, the TOAST-bearing `payments.description`, and the three MySQL PK-variant tables (Task 2); the primers (Task 5).
- Produces: the learner's first `/tmp/answer` format, which later days reuse — one `key=value` per line, keys lowercase, no spaces around `=`.

No `break.sh`: this lab measures rather than diagnoses. `verify.sh` computes the truth live from the catalog and compares against the learner's answers, so nothing is hard-coded.

- [ ] **Step 1: Write `content/day01.md`**

Follow the spec's day skeleton exactly. **Layer:** storage. **Budget:** 3 h — 1 h instruments, 2 h storage and lab.

*Why this matters:* every later lesson is downstream of what a page is. Index size, bloat, vacuum, planner cost and replication volume are all consequences of row layout, and an engineer who has never measured a page reasons about all five by analogy.

*Read the instrument first:* show raw `SELECT ctid, xmin, xmax, * FROM payments LIMIT 3;` output before naming a single concept, then decode each system column.

*Core concepts:* the PostgreSQL page — 8 KB, page header, item pointers, tuples growing from the end; the 23-byte tuple header and what each field is for; alignment padding and why column order changes row width; `fillfactor` and HOT updates; TOAST — the 2 KB threshold, compression then out-of-line storage, and the fact that a TOASTed value costs a second fetch. InnoDB: the table *is* the primary key's B-tree, secondary indexes store the primary key rather than a row pointer, and therefore a wide PK inflates every secondary index — the single most consequential schema decision in MySQL. WiredTiger: documents stored in a B-tree keyed by `_id`, block compression on by default, and why `collStats` `size` and `storageSize` differ.

Then the catalog as ground truth, pointing at `content/primers/catalog-field-reference.md` rather than restating it.

*Predict before you measure* (write in `journal.md` first): (1) the ratio of `pg_total_relation_size('payments')` to the summed `pg_column_size` of its columns; (2) how many of the 5M `payments` rows have an out-of-line `description`; (3) which of the three MySQL PK variants has the largest total secondary-index size, and by what factor over the smallest.

*Exercises* — six, each with hint and solution sketch: reorder a column list to reduce row width and prove the saving with `pg_column_size`; find the table with the worst `n_dead_tup` ratio; explain why `count(*)` on the heap is slow while an index-only `count(*)` may not be; compute how many `ledger_entries` rows fit in one 8 KB page and check it against `relpages`/`reltuples`; show that updating a TOASTed column rewrites more than updating an inline one; and, in MongoDB, explain the gap between `size` and `storageSize` on `payment_events`.

*Anti-patterns:* trusting a dashboard's "table size" without knowing whether it includes indexes and TOAST; assuming a UUID primary key is free; assuming MongoDB's document size equals its stored size.

- [ ] **Step 2: Write `labs/day01/README.md`**

Goal, three deliverables, success signal, how to run. The three deliverables, stated exactly:

```
1. bloat_ratio=<total relation size ÷ summed column bytes, 2 decimal places>
2. toast_column=<the column name stored out of line>
3. fattest_pk=<pk_variant_bigint | pk_variant_uuid | pk_variant_natural>
```

Written to `/tmp/answer` inside the `ws` container, one per line. State that `verify.sh` recomputes all three from the catalogs and that `bloat_ratio` is accepted within ±0.15, since the learner's summation method may differ slightly. Name the instruments that will get them there without giving the queries.

- [ ] **Step 3: Write `labs/day01/verify.sh`**

Sources `../lib/common.sh`, calls `require_stack`. Parses `/tmp/answer` from `ws` into the three keys, failing clearly if a key is missing or malformed. Then, independently:

- Computes `pg_total_relation_size('payments')` and the summed `avg(pg_column_size(col))` × `reltuples` via `in_pg`, derives the true ratio, and compares within ±0.15.
- Queries `pg_class` for the TOAST relation of `payments` and confirms the learner named `description`.
- Queries MySQL `information_schema.tables` / `innodb_index_stats` for the secondary-index sizes of the three variant tables via `in_my`, determines the true maximum, and compares.

Each check reports through `pass`/`fail`. Ends `exit "${FAILED:-0}"`. Never prints the correct value on failure — it names which deliverable is wrong and nothing more.

- [ ] **Step 4: Write `labs/day01/SOLUTION.md` and `teardown.md`**

`SOLUTION.md` mirrors the `journal.md` chain skeleton exactly: predictions, symptom, layer, numbered claim/proof chain with the actual queries and representative output, diagnosis, and the prediction-error discussion. It must explain *why* `pk_variant_uuid` wins — 36 bytes of `CHAR(36)` primary key copied into every secondary index leaf — and not merely state it.

`teardown.md`: nothing to tear down; the stack stays up for Day 2. Say so, and note that `docker compose -p dbmastery stop` is safe between sessions while `down -v` costs a re-seed.

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
bash -n labs/day01/verify.sh && echo "syntax ok"
grep -q 'lib/common.sh' labs/day01/verify.sh && echo "sources common ok"
grep -c 'Hint:' content/day01.md          # expect 6
grep -c 'Solution sketch:' content/day01.md  # expect 6
for s in "Why this matters" "Read the instrument first" "Predict before you measure" "Exercises" "Anti-patterns"; do
  grep -q "$s" content/day01.md && echo "$s ok" || echo "$s MISSING"
done
grep -q 'exit "${FAILED:-0}"' labs/day01/verify.sh && echo "exit ok"
```
Expected: syntax ok; sources common ok; both counts `6`; all five sections ok; exit ok.

---

### Task 7: Day 2 — Logical structure: normal forms as anomaly prevention

**Files:**
- Create: `database_mastery/content/day02.md`
- Create: `database_mastery/labs/day02/README.md`
- Create: `database_mastery/labs/day02/verify.sh`
- Create: `database_mastery/labs/day02/SOLUTION.md`
- Create: `database_mastery/labs/day02/teardown.md`

**Interfaces:**
- Consumes: `wide_payments` and the oversized `merchant_catalog` documents (Task 2); `common.sh` (Task 3).
- Produces: a `payments_norm` PostgreSQL schema created by the learner, which no later task depends on.

No `break.sh`: the starting artifact is `wide_payments`, created at seed time.

- [ ] **Step 1: Write `content/day02.md`**

**Layer:** logical. **Budget:** 1.5 h relational, 1.5 h document.

*Why this matters:* normal forms are usually taught as definitions to memorise and are therefore forgotten within a year. They are actually a compression of hard-won operational experience: each form names a class of update that corrupts data, and the form exists to make that update impossible.

*Read the instrument first:* `SELECT merchant_id, merchant_name, count(*) FROM wide_payments GROUP BY 1,2 HAVING count(DISTINCT merchant_name) > 0 LIMIT 5;` — show the redundancy before naming it.

*Core concepts:* functional dependency stated precisely; superkey, candidate key, prime attribute; 1NF, 2NF, 3NF, BCNF, each introduced by the anomaly it prevents — the update anomaly (a merchant renames and 3 000 rows disagree), the insertion anomaly (a merchant with no payments cannot be recorded), the deletion anomaly (the last payment's removal erases the merchant); lossless-join decomposition and how to check it; dependency preservation and the case where BCNF costs it. Constraints as the cheapest correctness mechanism available — `CHECK`, `FOREIGN KEY`, `UNIQUE`, `EXCLUDE` — and what a foreign key costs on write (an index lookup per modification, and a lock on the referenced row). Deliberate denormalisation: when it is correct, and the enforcement debt it creates.

Document modelling: the embed-versus-reference rule as four questions — cardinality, access pattern, update frequency, and the 16 MB document limit — and the unbounded-array antipattern, with bucketing and the outlier pattern as remedies. State plainly that "schemaless" describes the engine, not the application: the schema still exists, it has merely moved into the code, where nothing enforces it.

*Predict before you measure:* (1) how many distinct `merchant_name` spellings exist per `merchant_id` in `wide_payments`; (2) the size of the largest `merchant_catalog` document, and how close it is to 16 MB; (3) the write-time cost of the foreign keys you are about to add, as a percentage.

*Exercises* — six with hints and sketches: write the FD set for `wide_payments`; identify the highest normal form it satisfies and the determinant that breaks the next one; decompose to BCNF; prove losslessness by row-count reconciliation; find a legitimate denormalisation in the normalised schema and state its enforcement debt; restructure the oversized catalog document and justify bucketing over referencing.

*Anti-patterns:* normalising to BCNF reflexively without asking what queries exist; adding a foreign key without an index on the referencing column; treating MongoDB as exempt from modelling.

- [ ] **Step 2: Write `labs/day02/README.md`**

Deliverables, exactly:

```
1. A schema `payments_norm` in PostgreSQL, in BCNF, decomposed from wide_payments,
   with primary keys and foreign keys declared.
2. /tmp/answer containing:
      violated_form=<the normal form wide_payments fails>
      determinant=<the attribute set that determines the offending non-key attributes>
3. merchant_catalog restructured so no document's products array exceeds 1000 entries,
   with the total product count preserved.
```

State that the join-back reconciliation is checked automatically, so a decomposition that loses or duplicates rows will fail even if it looks tidy.

- [ ] **Step 3: Write `labs/day02/verify.sh`**

Sources `common.sh`, `require_stack`. Four independent checks:

- `payments_norm` exists and contains at least the tables needed to hold merchant, customer, payment-method and payment facts separately; asserts via `information_schema` that no table outside the merchant table carries `merchant_name`, and likewise for `customer_email` — the structural signature of the transitive dependency having been removed.
- Every table in `payments_norm` has a primary key, and the payment table has foreign keys to the others.
- Lossless join: reconstructs `wide_payments` by joining the `payments_norm` tables and asserts the reconstructed row count and the `count(DISTINCT payment_id)` both equal the originals.
- `/tmp/answer` parsed for `violated_form` (accept `3NF`, case-insensitive, trimmed) and `determinant` (accept `merchant_id`, or a set containing it).
- MongoDB: no `merchant_catalog` (or successor collection) document has a `products` array longer than 1000, **and** the summed product count across the restructured shape equals the pre-restructure total, which `verify.sh` reads from the `catalog_seed_meta` collection written at seed time by Task 2.

Report each through `pass`/`fail`; `exit "${FAILED:-0}"`.

- [ ] **Step 4: Write `SOLUTION.md` and `teardown.md`**

`SOLUTION.md`: the full FD set, the 3NF violation with `merchant_id → merchant_name, merchant_country, merchant_risk_tier` named as the transitive dependency, the BCNF decomposition as DDL, the losslessness proof, and the bucketing rewrite for the catalog with the reasoning for choosing it over referencing. Mirrors the `journal.md` skeleton.

`teardown.md`: drop `payments_norm` only if the learner wants a clean slate; the stack stays up. Note that leaving it costs nothing and is useful for revision.

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
bash -n labs/day02/verify.sh && echo "syntax ok"
grep -c 'Hint:' content/day02.md            # expect 6
grep -c 'Solution sketch:' content/day02.md # expect 6
grep -q 'payments_norm' labs/day02/verify.sh && echo "schema check ok"
grep -qi 'lossless' labs/day02/verify.sh && echo "lossless check ok"
grep -qi 'schemaless describes the engine\|schema still exists' content/day02.md && echo "mongo framing ok"
```
Expected: all five lines ok, both counts `6`.

---

### Task 8: Day 3 — Access methods: indexes, measured

**Files:**
- Create: `database_mastery/content/day03.md`
- Create: `database_mastery/labs/day03/README.md`
- Create: `database_mastery/labs/day03/break.sh`
- Create: `database_mastery/labs/day03/verify.sh`
- Create: `database_mastery/labs/day03/SOLUTION.md`
- Create: `database_mastery/labs/day03/teardown.md`

**Interfaces:**
- Consumes: the seeded, index-free schema (Task 2); `common.sh` (Task 3).
- Produces: the `break.sh` stash convention that Days 4–6 and 8 reuse — a per-run value written to `/tmp/.dayNN-target` inside the relevant container, never printed, read only by `answer_check`.

- [ ] **Step 1: Write `content/day03.md`**

**Layer:** access method. **Budget:** 3 h.

*Why this matters:* most "the database is slow" tickets are one missing or one wrong index, and most attempted fixes add an index that the planner then declines to use. The difference between the two outcomes is entirely readable from `EXPLAIN (ANALYZE, BUFFERS)`.

*Read the instrument first:* the raw plan for the report query before any index exists, with `Buffers: shared read=...` highlighted as the number that matters.

*Core concepts:* B-tree anatomy — leaf and internal pages, height, and why height barely matters while leaf-page count matters a great deal; selectivity, and the legitimate case where a sequential scan beats an index; composite column order under the equality → range → sort rule, and the leftmost-prefix constraint that follows; index-only scans and their dependence on the visibility map, which is why `Heap Fetches` can quietly destroy one; `INCLUDE` columns; partial indexes for skewed predicates — directly applicable here, since `status='disputed'` is 1% of rows; expression indexes and why a function on the left of a predicate defeats a plain index; when GIN, GiST and BRIN win, with BRIN as the natural fit for `posted_date` on an append-ordered table.

MySQL: secondary index → primary key lookup, and the consequence that a wide primary key inflates every secondary index — connect back to Day 1's measurement rather than re-deriving it. MongoDB: the ESR rule, compound prefixes, why index intersection rarely rescues a bad index set, and unanchored `$regex`.

*Predict before you measure:* (1) the `shared read` count for the report query before and after the right index; (2) whether an index-only scan is achievable for it, and what would prevent it; (3) the `totalDocsExamined : nReturned` ratio for the MongoDB query before and after.

*Exercises* — six with hints and sketches: build the composite index for a stated query and justify the order; demonstrate a case where adding a column to `INCLUDE` turns a scan index-only; build a partial index for the disputed-payments query and measure the size difference; find every index with `idx_scan = 0`; construct a predicate that defeats an existing index and then rewrite it to be sargable; and choose between compound and multiple single-field indexes for a MongoDB query set.

*Anti-patterns:* creating an index per column in a `WHERE` clause; assuming the planner must use an index that exists; measuring with `EXPLAIN` alone rather than `EXPLAIN (ANALYZE, BUFFERS)`.

- [ ] **Step 2: Write `labs/day03/break.sh`**

Sources `common.sh`, `require_stack`. Picks one of three seeded report queries at random (a merchant settlement summary, a disputed-payment listing, a daily volume rollup), each of which has a different correct composite index. Writes the correct ordered column list for the chosen query to `/tmp/.day03-target` inside `pg`, and the query text itself to `/tmp/day03-query.sql` inside `ws` so the learner knows what to optimise.

Creates three decoy indexes with deliberately plausible but wrong shapes — a single-column index on the low-selectivity `status`, a composite with the range column first, and a redundant index that is a prefix of another — named `idx_decoy_1`, `idx_decoy_2`, `idx_decoy_3`. Drops any correct index if present. Runs `ANALYZE`. Creates the MongoDB pathology: a query on `payment_events` filtering on `merchant_id` and sorting by `ts` with no supporting index.

Prints exactly one line via `say_symptom`: the settlement report takes over 40 seconds and the events query examines 50 000 documents for every one returned.

- [ ] **Step 3: Write `labs/day03/verify.sh`**

Four independent checks:

- `answer_check /tmp/.day03-target pg` — the learner's `/tmp/answer` line `index_columns=` must match the stashed ordered column list, compared after normalising whitespace and case. Neither value printed.
- The chosen report query now completes under the stated threshold, measured by `EXPLAIN (ANALYZE)` execution time via `in_pg`, and its plan contains `Index Only Scan` or `Index Scan` — not `Seq Scan`.
- All three decoy indexes are gone: `pg_stat_user_indexes` returns no row for `idx_decoy_%`.
- The MongoDB query's `explain("executionStats")` shows stage `IXSCAN` and `totalDocsExamined / nReturned <= 2`.

- [ ] **Step 4: Write `SOLUTION.md` and `teardown.md`**

`SOLUTION.md` covers all three possible target queries, since `break.sh` chooses randomly — each with its correct index, the column-order reasoning, and the before/after buffer counts. Mirrors the `journal.md` skeleton.

`teardown.md`: drop the created indexes to restore a clean baseline for Day 4, with the exact `DROP INDEX` statements; note that leaving them changes Day 4's plans and should be avoided.

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
bash -n labs/day03/break.sh labs/day03/verify.sh && echo "syntax ok"
grep -q 'say_symptom' labs/day03/break.sh && echo "symptom ok"
test "$(grep -c 'say_symptom\|echo ' labs/day03/break.sh)" -ge 1 && echo "output ok"
grep -q 'answer_check' labs/day03/verify.sh && echo "answer_check ok"
grep -c 'idx_decoy' labs/day03/break.sh   # expect >= 3
grep -c 'Hint:' content/day03.md          # expect 6
grep -qi 'equality.*range.*sort' content/day03.md && echo "ESR rule ok"
```
Expected: every line ok; decoy count at least 3; hint count 6.

---

### Task 9: Day 4 — The planner: why it chose that plan

**Files:**
- Create: `database_mastery/content/day04.md`
- Create: `database_mastery/labs/day04/README.md`
- Create: `database_mastery/labs/day04/break.sh`
- Create: `database_mastery/labs/day04/verify.sh`
- Create: `database_mastery/labs/day04/SOLUTION.md`
- Create: `database_mastery/labs/day04/teardown.md`

**Interfaces:**
- Consumes: the `merchants.country` ↔ `payments.currency` correlation (Task 2); `common.sh`; the stash convention from Task 8.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write `content/day04.md`**

**Layer:** planner. **Budget:** 3 h.

*Why this matters:* an index that exists and is not used, a query that was fast last week and is catastrophic today, a plan that is perfect in staging and wrong in production — all three are the same phenomenon, and all three are diagnosed by one number: the divergence between estimated and actual rows.

*Read the instrument first:* a plan where `rows=12` sits above `actual rows=1_400_000`, shown before the concept is named.

*Core concepts:* the cost model and what `seq_page_cost`, `random_page_cost` and the CPU costs actually represent; where statistics come from and what `default_statistics_target` buys; `n_distinct`, histograms and most-common-value lists, read directly from `pg_stats`; the independence assumption and why correlated columns break it — with the seeded country/currency correlation as the worked case; extended statistics (`CREATE STATISTICS ... (ndistinct, dependencies, mcv)`) as the correct remedy. **Row-estimate error as the master diagnostic**: find the deepest node where estimate and actual diverge, because everything above it is a consequence, not a cause. Join algorithms — nested loop, hash, merge — and the conditions each wants; join order and why it is the genuinely hard part; `LATERAL`; CTE materialisation before and after PostgreSQL 12.

Rewrites that move the needle: sargability, `OR` → `UNION ALL`, keyset versus `OFFSET` pagination with the arithmetic showing why `OFFSET 100000` costs what it does, and the N+1 seen from the database side in `pg_stat_statements`. MySQL: `optimizer_trace` and reading its cost sections. MongoDB: aggregation stage ordering, `$match` and `$project` pushdown, `allowDiskUse`, and why `$lookup` is not a join.

*Predict before you measure:* (1) the estimated and actual row counts at the deepest divergent node; (2) whether `ANALYZE` alone will fix it; (3) the estimate after creating extended statistics.

*Exercises* — six with hints and sketches: read `pg_stats` for `payments.currency` and predict the planner's estimate for a given predicate; construct a two-column predicate where the independence assumption fails and quantify the error; fix it with extended statistics and re-measure; rewrite an `OFFSET 100000` pagination query as keyset and compare buffers; find the N+1 in `pg_stat_statements` by `calls` against `mean_exec_time`; and reorder an aggregation pipeline so `$match` precedes `$lookup`, measuring the difference.

*Anti-patterns:* disabling a plan node type to force a plan; raising `default_statistics_target` globally instead of fixing the correlated pair; reading the top of the plan rather than the deepest divergence.

- [ ] **Step 2: Write `labs/day04/break.sh`**

Sources `common.sh`, `require_stack`. Applies a statistics pathology: sets a false `n_distinct` override on `payments.merchant_id` via `ALTER TABLE ... ALTER COLUMN ... SET (n_distinct = 1)`, disables autovacuum on `payments`, then performs a bulk update that shifts the distribution without a follow-up `ANALYZE`. Stashes in `/tmp/.day04-target` inside `pg` the name of the plan node type at which estimate and actual diverge for the target query, as produced by a reference run. Prints one `say_symptom` line: a report that ran in 400 ms now takes over 90 seconds, with no schema or query change.

Include a comment block stating that `break.sh` deliberately does **not** disable `enable_nestloop`, and that `verify.sh` fails if the learner does.

- [ ] **Step 3: Write `labs/day04/verify.sh`**

Five independent checks:

- `answer_check /tmp/.day04-target pg` against the learner's `divergent_node=` line.
- The target query completes under the stated threshold.
- **The hack fix is rejected:** `SELECT setting FROM pg_settings WHERE name IN ('enable_nestloop','enable_hashjoin','enable_seqscan')` must all be `on`, and `pg_db_role_setting` must contain no override for them. Fail with a message naming this explicitly — forcing a plan hides the cause and does not survive the next data shift.
- The false `n_distinct` override is gone: `pg_attribute.attoptions` for `payments.merchant_id` is null or contains no `n_distinct`.
- An extended statistics object exists covering the correlated pair, confirmed via `pg_statistic_ext`, and `pg_stats_ext` shows it has been analysed.

- [ ] **Step 4: Write `SOLUTION.md` and `teardown.md`**

`SOLUTION.md`: the full chain — reading the plan bottom-up, locating the deepest divergence, checking `pg_stats` against reality, discovering the `n_distinct` override in `attoptions`, removing it, running `ANALYZE`, and then finding the residual correlation error that only extended statistics fixes. Show both the intermediate improvement and the final one, so the learner sees that `ANALYZE` alone is necessary but not sufficient. Mirrors the `journal.md` skeleton.

`teardown.md`: re-enable autovacuum on `payments`, drop the extended statistics object if desired, re-run `ANALYZE`. Exact statements.

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
bash -n labs/day04/break.sh labs/day04/verify.sh && echo "syntax ok"
grep -q 'enable_nestloop' labs/day04/verify.sh && echo "hack-fix rejection ok"
grep -q 'pg_statistic_ext' labs/day04/verify.sh && echo "extended stats check ok"
grep -q 'n_distinct' labs/day04/break.sh && echo "pathology ok"
grep -c 'Hint:' content/day04.md          # expect 6
grep -qi 'deepest node where estimate and actual diverge\|deepest divergence' content/day04.md && echo "master diagnostic ok"
```
Expected: every line ok; hint count 6.

---

### Task 10: Day 5 — Concurrency: transactions, isolation, locks

**Files:**
- Create: `database_mastery/content/day05.md`
- Create: `database_mastery/labs/day05/README.md`
- Create: `database_mastery/labs/day05/break.sh`
- Create: `database_mastery/labs/day05/harness.sh`
- Create: `database_mastery/labs/day05/verify.sh`
- Create: `database_mastery/labs/day05/SOLUTION.md`
- Create: `database_mastery/labs/day05/teardown.md`

**Interfaces:**
- Consumes: `accounts`, `ledger_entries` and the commented-out `CHECK` from Task 2; `common.sh`; the stash convention from Task 8.
- Produces: `harness.sh`, a two-session race runner that Day 8's gauntlet reuses.

**Framing that every file in this task must respect:** the invariant under defence is *derived*, not stored. An account's balance is the sum of its `ledger_entries` credits minus debits; `accounts.balance_minor` is a cached copy. A row-level `CHECK (balance_minor >= 0)` therefore cannot defend it — the two concurrent withdrawals each read a sum that is still valid, each writes rows the other cannot see, and the constraint is never violated by either statement in isolation. That is write skew, and discovering that the obvious constraint does not help is the point of the day.

- [ ] **Step 1: Write `content/day05.md`**

**Layer:** concurrency. **Budget:** 3 h.

*Why this matters:* isolation levels are learned from a table in a book, and the table is remembered as "higher is safer" — which is true and useless. What an engineer needs is the ability to look at a piece of business logic and say which anomaly it is exposed to, and what the cheapest defence is.

*Read the instrument first:* two `psql` sessions side by side, showing `xmin`, `xmax` and `pg_stat_activity.wait_event` as a lock is taken and waited on.

*Core concepts:* ACID stated precisely, with the observation that "consistency" in ACID means the application's invariants, not the distributed-systems sense. The anomaly ladder — dirty read, non-repeatable read, phantom, lost update, read skew, write skew — each with the two-session script that produces it, cross-referenced to `content/primers/isolation-anomaly-ladder.md`. PostgreSQL Read Committed (statement-level snapshots and the surprising re-read of updated rows), Repeatable Read (transaction-level snapshot, serialisation failures on write conflict), Serializable (SSI, predicate locks, and the false positives that oblige a retry loop). MySQL InnoDB Repeatable Read with gap and next-key locks, which prevents phantoms further than the standard requires, and the deadlock consequences of that. MongoDB multi-document transactions on snapshot isolation, with their 60-second default limit and the write-conflict retry obligation.

Lock modes and the lock queue, including the fact that a queued `ACCESS EXCLUSIVE` request blocks every reader behind it — the reason a careless `ALTER TABLE` takes down a service. Deadlock reproduction and reading the report from both PostgreSQL's log and `SHOW ENGINE INNODB STATUS`. `SELECT ... FOR UPDATE`, `SKIP LOCKED` as the correct job-queue primitive, and advisory locks. The long-running transaction as the root of most operational evil: it pins `backend_xmin`, blocks vacuum, grows bloat, and stalls replication — establish this here, because Day 6 depends on it.

*Predict before you measure:* (1) which session in the supplied race will win, and why; (2) whether Repeatable Read prevents the write skew (it does not); (3) how many of the five blocked sessions are waiting on the root blocker directly versus transitively.

*Exercises* — six with hints and sketches: reproduce each of the six anomalies and record which isolation level stopped each; write a job-queue dequeue that two workers can run safely; produce a deadlock deliberately and read the report; find the longest-running transaction and state what it is costing; explain why `SELECT FOR UPDATE` fixes the write skew while a `CHECK` does not; and implement the same defence in MongoDB with a transaction and a retry loop.

*Anti-patterns:* raising the isolation level globally instead of defending the specific invariant; killing the longest-waiting session instead of the root blocker; retry loops without backoff or a cap.

- [ ] **Step 2: Write `labs/day05/break.sh`**

Sources `common.sh`, `require_stack`. Creates a five-session blocking chain: one root session takes a row lock and then idles in transaction; four further sessions queue behind it, arranged so that the longest-waiting session is *not* the root blocker — the chain must be transitive, so that killing the loudest waiter accomplishes nothing. Background sessions run via `docker compose exec -d` with a bounded lifetime so a forgotten lab cannot wedge the stack indefinitely.

Stashes the root blocker's backend PID in `/tmp/.day05-target` inside `pg`. Then introduces a write-skew violation: runs two concurrent withdrawals against one account under Read Committed such that the summed ledger goes negative, leaving at least one account whose derived balance is below zero.

Prints one `say_symptom` line: settlement writes are timing out, and one account's derived balance has gone negative.

- [ ] **Step 3: Write `labs/day05/harness.sh`**

Takes a path to the learner's transaction body (`labs/day05/answers/withdraw.sql`), runs it in two concurrent sessions 50 times against an account funded for exactly one withdrawal, and asserts two properties: the derived balance never goes negative, and not both sessions succeed on the same round. Accepts any correct defence — `SELECT ... FOR UPDATE`, `SERIALIZABLE` with a retry loop, or a materialised constraint — because the harness tests the invariant, not the technique. Reports per-round outcomes on failure so the learner can see which round broke.

- [ ] **Step 4: Write `labs/day05/verify.sh`**

Four independent checks:

- `answer_check /tmp/.day05-target pg` against the learner's `root_blocker=` line.
- The chain is resolved: no session in `pg_stat_activity` has `wait_event_type='Lock'` with `state='active'`, and no transaction older than 60 seconds remains idle-in-transaction.
- No account's derived balance — computed from `ledger_entries`, not read from `accounts.balance_minor` — is negative.
- `harness.sh` passes against `answers/withdraw.sql`, which must exist.

- [ ] **Step 5: Write `SOLUTION.md` and `teardown.md`**

`SOLUTION.md`: the chain from symptom to root blocker via `pg_locks` and `pg_blocking_pids()`, showing explicitly why the longest-waiting session was the wrong target; then the write-skew analysis, with the failed `CHECK` approach shown first and its failure explained, then two correct defences (`FOR UPDATE` and `SERIALIZABLE` with retry) with the trade-off between them. Mirrors the `journal.md` skeleton.

`teardown.md`: terminate any surviving background sessions with the exact `pg_terminate_backend` query, restore the test account's balance, and confirm no idle-in-transaction sessions remain.

- [ ] **Step 6: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
bash -n labs/day05/break.sh labs/day05/harness.sh labs/day05/verify.sh && echo "syntax ok"
grep -q 'pg_blocking_pids' labs/day05/SOLUTION.md && echo "root-blocker method ok"
grep -qi 'derived balance\|sum(' labs/day05/verify.sh && echo "derived invariant ok"
grep -qi 'longest-waiting session was the wrong target\|not the root blocker' labs/day05/SOLUTION.md && echo "framing ok"
grep -c 'Hint:' content/day05.md          # expect 6
grep -qi 'repeatable read' content/day05.md && echo "isolation coverage ok"
```
Expected: every line ok; hint count 6.

---

### Task 11: Day 6 — Durability and operations

**Files:**
- Create: `database_mastery/content/day06.md`
- Create: `database_mastery/labs/day06/README.md`
- Create: `database_mastery/labs/day06/break.sh`
- Create: `database_mastery/labs/day06/verify.sh`
- Create: `database_mastery/labs/day06/SOLUTION.md`
- Create: `database_mastery/labs/day06/teardown.md`

**Interfaces:**
- Consumes: `common.sh`; the stash convention from Task 8; and specifically the WAL-archiving settings and the `pgarchive` volume established in Task 1 — `wal_level=replica`, `archive_mode=on`, `archive_command` writing to `/var/lib/postgresql/archive`. Point-in-time recovery is impossible without them, so if they are absent, stop and fix Task 1 rather than working around it.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write `content/day06.md`**

**Layer:** durability. **Budget:** 3 h.

*Why this matters:* two questions decide whether an incident is an inconvenience or a resignation letter — what exactly did the database promise when it acknowledged that commit, and can you actually restore. Most engineers can answer neither with confidence, and the second one is usually answered for the first time during the incident.

*Read the instrument first:* the PostgreSQL log lines emitted during crash recovery, shown raw, before the concepts are named.

*Core concepts:* WAL, redo, undo, binlog and oplog presented as one idea seen four ways — write the intent durably before the data, so recovery can replay it. Checkpoints, their I/O shape, and the trade-off between checkpoint frequency and recovery time. `fsync`, `synchronous_commit`, and precisely what a commit acknowledgement promises under each setting — including the case where `synchronous_commit=off` returns success for a transaction that a power loss will discard. Crash recovery, read from the log.

Autovacuum: what it does, why "the table is still growing after I deleted everything" is the expected outcome and not a bug, dead tuples and the visibility horizon, freezing and transaction-ID wraparound with the arithmetic of how close a busy database gets, and reading `pg_stat_progress_vacuum` during a run. Bloat: measuring it honestly with `pgstattuple` rather than guessing from a formula, then choosing among plain `VACUUM`, retuned autovacuum thresholds, `pg_repack` and `VACUUM FULL` — each with its lock level and outage cost stated. Connect explicitly to Day 5: a long-running transaction pins the horizon and no amount of vacuum tuning will help until it ends. MySQL: the purge thread, history list length, and the same failure wearing different clothes.

Backup and PITR: logical versus physical, `pg_basebackup` plus WAL archive, `recovery_target_time`, and the principle that a backup is untested until a restore has produced known values. Connections: why a PostgreSQL connection costs a process and several megabytes, the `max_connections` arithmetic against `work_mem` and `shared_buffers`, and PgBouncer's session, transaction and statement pooling modes with the feature each one costs you. The five settings that matter, with `work_mem` given its own treatment because it is per sort or hash node, not per query — a plan with eight such nodes across twelve connections can commit ninety-six times what the engineer thought they configured.

*Predict before you measure:* (1) how long crash recovery will take after the kill; (2) the bloat ratio of the churn table before you vacuum it; (3) the value of the damaged column at your chosen recovery target.

*Exercises* — six with hints and sketches: compute the memory ceiling implied by the current `max_connections` and `work_mem`; find the oldest transaction and the wraparound headroom; measure bloat with `pgstattuple` and compare against the common estimate query; choose the correct remediation for a 40%-bloated table that cannot take a lock; size a PgBouncer pool for a stated workload; and explain what is lost when `synchronous_commit=off`.

*Anti-patterns:* testing backups by checking the backup job's exit code; raising `max_connections` to solve a pooling problem; running `VACUUM FULL` on a live table because it sounds thorough.

- [ ] **Step 2: Write `labs/day06/break.sh`**

Sources `common.sh`, `require_stack`. Three-part setup:

1. Takes a `pg_basebackup` into a lab directory and confirms WAL archiving is active, so PITR is possible. Records the pre-damage value of a specific `payments` row's `amount_minor` and `status` and the timestamp immediately before the damage, stashing both in `/tmp/.day06-target` inside `pg`.
2. Performs the damage: a bulk `UPDATE payments SET status='failed'` against a large, wrongly-chosen predicate, committed. This is the change the learner must recover from.
3. Creates the bloat pathology: disables autovacuum on a churn table and runs repeated update cycles until it is substantially bloated.

Prints one `say_symptom` line: a bulk status update ran against the wrong predicate twelve minutes ago, and separately a table is growing without bound.

The crash is left to the learner — `README.md` instructs them to hard-kill the container themselves, since doing it by hand is part of the lesson.

- [ ] **Step 3: Write `labs/day06/verify.sh`**

Four independent checks:

- The learner's `/tmp/answer` contains `recovery_seconds=` and `bloat_ratio_before=`, both parseable numbers in plausible ranges, plus `recovered_status=`, which `answer_check` compares against the stashed pre-damage value.
- The damaged rows are restored: the specific row's `status` and `amount_minor` match the stashed pre-damage values, verified through `in_pg`.
- The churn table's bloat is reduced: `pgstattuple` reports a dead-tuple percentage below a stated threshold, and autovacuum is enabled on it again with non-default thresholds, confirmed via `pg_class.reloptions` — so retuning, not a one-off manual vacuum, is what passes.
- No idle-in-transaction session older than 60 seconds survives, since one would silently defeat the vacuum fix.

- [ ] **Step 4: Write `SOLUTION.md` and `teardown.md`**

`SOLUTION.md`: the crash-recovery log read line by line; then the PITR chain — locating the damage window, restoring the base backup to a scratch directory, setting `recovery_target_time`, starting recovery, confirming the values, and promoting; then the bloat chain — measuring with `pgstattuple`, ruling out `VACUUM FULL` on lock grounds, retuning `autovacuum_vacuum_scale_factor` for a large table and explaining why the default scale factor is wrong at ten million rows. Mirrors the `journal.md` skeleton.

`teardown.md`: remove the base backup directory and any scratch data directory, re-enable default autovacuum settings if desired, confirm disk reclaimed. Exact commands.

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
bash -n labs/day06/break.sh labs/day06/verify.sh && echo "syntax ok"
grep -q 'pg_basebackup' labs/day06/break.sh && echo "basebackup ok"
grep -q 'recovery_target_time' labs/day06/SOLUTION.md && echo "PITR ok"
grep -q 'reloptions\|autovacuum_vacuum_scale_factor' labs/day06/verify.sh && echo "retune check ok"
grep -qi 'per sort or hash node\|not per query' content/day06.md && echo "work_mem framing ok"
grep -c 'Hint:' content/day06.md          # expect 6
```
Expected: every line ok; hint count 6.

---

### Task 12: Day 7 — Distribution, and the managed cloud

**Files:**
- Create: `database_mastery/content/day07.md`
- Create: `database_mastery/labs/day07/README.md`
- Create: `database_mastery/labs/day07/verify.sh`
- Create: `database_mastery/labs/day07/SOLUTION.md`
- Create: `database_mastery/labs/day07/teardown.md`
- Create: `database_mastery/labs/day07/atlas-setup.md`
- Create: `database_mastery/labs/day07/terraform/rds.tf`
- Create: `database_mastery/labs/day07/terraform/variables.tf`
- Create: `database_mastery/labs/day07/terraform/outputs.tf`
- Create: `database_mastery/labs/day07/terraform/terraform.tfvars.example`

**Interfaces:**
- Consumes: `common.sh`; `labs/verify-teardown.sh` (Task 3), which this day's `teardown.md` invokes and whose resource prefix `dbm-lab-` this task's Terraform must use for every named resource.
- Produces: nothing later tasks depend on.

No `break.sh`: the pathologies here are provoked by the learner against real managed services.

**Honest limitation to state in `README.md`:** unlike Days 1–6, `verify.sh` cannot recompute the truth, because the truth lives in someone else's account and varies by region and instance class. It therefore checks that each answer is present, well-formed and within a plausible range, that the named wait event is a real Performance Insights event name, and that teardown left nothing running. Say this plainly rather than implying a rigour the check does not have.

- [ ] **Step 1: Write `content/day07.md`**

**Layer:** distribution. **Budget:** 1.5 h concepts, 1.5 h cloud lab.

*Why this matters:* this is the day that maps directly onto the learner's job. Every RDS and Atlas console screen they already look at is a rendering of one of these concepts, and the console's vocabulary is only legible if the underlying mechanism is.

*Read the instrument first:* raw `pg_stat_replication` output from a primary, and the `rs.status()` document from a MongoDB replica set, before either is explained.

*Core concepts:* physical versus logical replication and what each can and cannot do; synchronous versus asynchronous and the latency each buys or costs; the real causes of replication lag — a long transaction on the primary, a conflicting query on the replica, single-threaded apply, network — and how to measure it in each engine rather than guess. The read-your-writes hazard: an application that writes to the primary and immediately reads from a replica is not eventually consistent, it is intermittently wrong, and the fix is a routing decision rather than a database setting. Failover semantics and exactly what is lost: in-flight transactions, the connection pool's cached endpoints, and any unreplicated WAL under asynchronous replication.

Partitioning: declarative range partitioning on `payments.created_at`, partition pruning shown in a plan, partition-wise joins, and the maintenance obligation partitions create. MongoDB sharding: shard-key selection on cardinality, frequency and monotonicity — with the seeded monotonic `payment_events.ts` as the worked failure, since a monotonic key sends every insert to one chunk and one shard; chunk migration, jumbo chunks, and why an apparently high-cardinality key can still be catastrophic. CAP and PACELC stated as engineering trade-offs rather than slogans; quorum reads and writes; MongoDB read and write concerns, and causal consistency as the tool that actually fixes read-your-writes.

Managed reality: RDS parameter groups and which parameters are locked, Performance Insights and its wait-event vocabulary, Enhanced Monitoring versus CloudWatch and what each can see, the metrics that matter (`DBLoad`, `FreeableMemory`, `ReadIOPS`, `BurstBalance`, `ReplicaLag`), storage autoscaling and burst-balance exhaustion as a slow-motion outage. Atlas: Profiler, Performance Advisor, and alert configuration.

*Predict before you measure:* (1) the Multi-AZ failover duration in seconds; (2) what happens to an open connection and an in-flight transaction during it; (3) the top wait event under a `pgbench` load on `db.t4g.micro`.

*Exercises* — six with hints and sketches: compute replication lag from `pg_stat_replication` byte positions rather than the time column; design a partition scheme for `payments` with a stated retention policy; pick a shard key for `payment_events` that avoids the hot shard and defend it; explain what `readConcern: "majority"` costs; identify which of five RDS parameters are modifiable and which are locked; and interpret a burst-balance graph heading to zero.

*Anti-patterns:* choosing a shard key by cardinality alone; treating a read replica as a consistent read source; sizing an instance from CPU alone while ignoring `BurstBalance` and IOPS.

- [ ] **Step 2: Write the Terraform**

`rds.tf`: a `db.t4g.micro` PostgreSQL 16 instance, `multi_az = true`, `identifier = "dbm-lab-pg"`, `allocated_storage = 20`, `storage_type = "gp3"`, `performance_insights_enabled = true`, `performance_insights_retention_period = 7`, `backup_retention_period = 1`, `skip_final_snapshot = true`, `deletion_protection = false`, `publicly_accessible` driven by a variable and defaulting to `false`, plus a security group restricted to a variable-supplied CIDR and a parameter group named `dbm-lab-pg16` that sets `log_min_duration_statement` and `shared_preload_libraries = pg_stat_statements`.

Every resource name carries the `dbm-lab-` prefix, because `labs/verify-teardown.sh` matches on it.

`variables.tf`: `region`, `db_password`, `my_ip_cidr`, `publicly_accessible`, each with a description and no default for the secret. `outputs.tf`: endpoint and port, with `db_password` never output. `terraform.tfvars.example`: placeholder values only — `region = "eu-west-1"`, `db_password = "CHANGE_ME_use_a_password_manager"`, `my_ip_cidr = "203.0.113.4/32"` — with a header comment saying to copy it to `terraform.tfvars`, which is git-ignored, and never to commit real values.

Add a cost comment at the top of `rds.tf` stating the expected charge and that `skip_final_snapshot = true` is set deliberately so teardown leaves no billable snapshot.

- [ ] **Step 3: Write `atlas-setup.md`**

A console walkthrough: create an M10 cluster named `dbm-lab` in a named region; create a database user and add the learner's IP to the access list; load a subset of `payment_events` with `mongoimport` from the `ws` container, giving the exact command with the connection string as a placeholder; enable the Profiler; create the deliberately monotonic index and shard key for the hot-shard demonstration; where to find Performance Advisor. Every step names what to look at, not merely what to click. State the cost and that the cluster must be terminated the same day.

- [ ] **Step 4: Write `labs/day07/README.md`, `verify.sh`, `SOLUTION.md`, `teardown.md`**

`README.md`: the three deliverables — `failover_seconds=`, `top_wait_event=`, `hot_shard_reason=` — written to `/tmp/answer`; the cost warning up front; the honest limitation of `verify.sh` stated in full; and the instruction to run teardown the same day.

`verify.sh`: checks `failover_seconds` parses as a number between 20 and 600; `top_wait_event` matches a real Performance Insights event name from a list the script carries (`CPU`, `IO:DataFileRead`, `Lock:transactionid`, `LWLock:BufferMapping`, `Client:ClientRead`, and the other common ones); `hot_shard_reason` mentions monotonicity; then invokes `../verify-teardown.sh` and propagates its exit status, so a passing Day 7 also proves nothing is still billing.

`SOLUTION.md`: what a Multi-AZ failover actually does (DNS record swap to the standby, typically 60–120 s), what happened to the open connection and why the pool must be configured to recognise it, how to read the Performance Insights top-SQL and wait-event panels, and why a monotonic shard key produces a single hot chunk regardless of the key's cardinality. Mirrors the `journal.md` skeleton.

`teardown.md`: `terraform destroy`, terminate the Atlas cluster, delete the Atlas project if it was created for this, then run `labs/verify-teardown.sh` and require a clean pass. State that this is the only day with a financial consequence for skipping teardown.

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery/labs/day07
bash -n verify.sh && echo "syntax ok"
grep -rn 'AKIA\|aws_access_key\|mongodb+srv://[^<]*[a-z0-9]@' . || echo "no credentials: ok"
grep -c 'dbm-lab' terraform/rds.tf        # expect >= 3
grep -q 'skip_final_snapshot *= *true' terraform/rds.tf && echo "no billable snapshot ok"
grep -q 'CHANGE_ME' terraform/terraform.tfvars.example && echo "placeholder ok"
grep -q 'verify-teardown.sh' verify.sh && echo "teardown gating ok"
grep -qi 'cannot recompute the truth\|plausible range' README.md && echo "honest limitation ok"
```
Expected: every line ok. Do not run `terraform init`, `plan`, `apply`, or any `aws` command.

---

### Task 13: Day 8 — The gauntlet, and system design

**Files:**
- Create: `database_mastery/content/day08.md`
- Create: `database_mastery/labs/day08/README.md`
- Create: `database_mastery/labs/day08/gauntlet.sh`
- Create: `database_mastery/labs/day08/verify.sh`
- Create: `database_mastery/labs/day08/ANSWERS.md`
- Create: `database_mastery/labs/day08/teardown.md`
- Create: `database_mastery/labs/day08/DESIGN-BRIEF.md`
- Create: `database_mastery/labs/day08/DESIGN-RUBRIC.md`
- Create: `database_mastery/labs/day08/REFERENCE-DESIGN.md`

**Interfaces:**
- Consumes: `common.sh`; the pathology techniques from Days 3–6. (It does **not** use `labs/day05/harness.sh` — none of the eight pathologies is a concurrency race, and Day 5's own lab already tests that skill under the harness.)
- Produces: the learner's consolidated runbook, which is theirs, not a checked artifact.

`ANSWERS.md` replaces `SOLUTION.md` here, because there are five independent incidents rather than one chain.

- [ ] **Step 1: Write `content/day08.md`**

**Layer:** all. **Budget:** 1.5 h gauntlet, 1.5 h design.

*Why this matters:* the seven preceding days each announced their layer in advance. Production does not. The gauntlet removes that scaffolding, which is the only way to find out whether the diagnostic habit transferred or whether the layer label was doing the work.

*Core concepts (design half):* capacity arithmetic done explicitly — rows per day, bytes per row, index overhead, IOPS from the access pattern, connections from the concurrency, and growth projected over the retention window. An engine-choice rubric built from the access pattern rather than from preference, with the honest observation that PostgreSQL is the right default for most workloads and that the interesting question is what specifically makes a given workload an exception. Read and write path design; caching layers and the invalidation question, including why cache-aside with a TTL is usually right and what it costs in staleness; idempotency keys for a payments API; the transactional outbox and why dual writes to a database and a queue cannot be made atomic without one. Zero-downtime schema migration by expand and contract, given as a concrete six-phase sequence for adding a `NOT NULL` column with a default to a ten-million-row table. Multi-tenancy: shared table with a tenant column, schema per tenant, database per tenant — with the operational consequence of each stated at the hundred-, thousand- and ten-thousand-tenant scales.

*Exercises* — four with hints and sketches, all design-side, since the gauntlet supplies the diagnostic practice: size the storage and IOPS for a stated payment volume; write the six-phase expand/contract sequence for the `NOT NULL` column; choose a multi-tenancy model for a stated tenant profile and defend it; and design the idempotency mechanism for a retryable payment endpoint.

*Anti-patterns:* choosing an engine for a résumé rather than an access pattern; caching before measuring; a migration plan whose rollback step is "restore from backup".

- [ ] **Step 2: Write `labs/day08/gauntlet.sh`**

Sources `common.sh`, `require_stack`. Holds a pool of eight pathologies drawn from the earlier days but reshaped so none is a verbatim repeat — a missing composite index on a new query shape, a stale-statistics plan flip on a different join, a lock chain rooted in a different session, an autovacuum starvation caused by a long transaction rather than by disabled autovacuum, a MongoDB collection scan from an unanchored `$regex`, an InnoDB deadlock from an inconsistent update order, a bloated index rather than a bloated table, and an N+1 visible only in `pg_stat_statements`.

Selects five at random, applies them, and stashes for each the identifying value the learner must produce, in `/tmp/.day08-targets` inside the relevant container, as `key=value` lines. Prints exactly five `say_symptom` lines, one per incident, numbered, with no layer named and no hint. Records a start timestamp for the timed run.

Includes a `--reset` flag that removes every pathology it can have applied, so a learner can re-run the gauntlet cleanly.

- [ ] **Step 3: Write `labs/day08/verify.sh`**

Scores the five incidents independently. For each: the pathology is genuinely resolved, checked by the same class of assertion its origin day used, **and** the learner's `/tmp/answer` line for that incident matches the stash via `answer_check`. Prints a per-incident result and a final score line of the form `score: N/5`. Any unresolved incident calls `fail`, so anything below 5/5 leaves `FAILED=1`; the script ends with the standard `exit "${FAILED:-0}"` like every other day, which keeps Task 15's mechanical exit-convention check valid. Partial credit is reported but does not pass — an on-call engineer does not get partial credit. Also reports the elapsed time against the 90-minute target without failing on it.

- [ ] **Step 4: Write `ANSWERS.md`, `DESIGN-BRIEF.md`, `DESIGN-RUBRIC.md`, `REFERENCE-DESIGN.md`, `README.md`, `teardown.md`**

`ANSWERS.md`: all eight pathologies, each as a compressed evidence chain in the `journal.md` shape — symptom, the first instrument to reach for, the discriminating observation, the fix, and the proof. Ordered by pathology, not by the run, since the selection is random.

`DESIGN-BRIEF.md`: a single realistic brief — a payments platform at a stated volume, growth rate, latency requirement, retention obligation and team size — with the deliverable being a one-page design covering engine choice, schema sketch, index plan, isolation strategy, capacity arithmetic, and a zero-downtime migration for one stated future change.

`DESIGN-RUBRIC.md`: what a strong answer contains, criterion by criterion, each with the failure mode of a weak answer — so the learner can grade themselves honestly.

`REFERENCE-DESIGN.md`: a worked answer to the brief, explicitly labelled as one defensible design rather than the design, naming the two or three decisions where a different choice would have been equally reasonable and what would tip it.

`README.md`: how to run the timed gauntlet, the answer-file format, the scoring rule, and the instruction to write the evidence chains in `journal.md` before fixing anything — the discipline is the point, and the gauntlet is the test of whether it survived contact with time pressure.

`teardown.md`: `gauntlet.sh --reset`, then the stack teardown options, then a final reminder to run `labs/verify-teardown.sh` if Day 7 was done recently.

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery/labs/day08
bash -n gauntlet.sh verify.sh && echo "syntax ok"
grep -c 'say_symptom' gauntlet.sh          # expect >= 5
grep -q -- '--reset' gauntlet.sh && echo "reset flag ok"
grep -q 'score: ' verify.sh && echo "scoring ok"
grep -q 'answer_check' verify.sh && echo "answer_check ok"
grep -ci '^## ' ANSWERS.md                 # expect >= 8, one per pathology
grep -qi 'one defensible design' REFERENCE-DESIGN.md && echo "framing ok"
grep -c 'Hint:' ../../content/day08.md     # expect 4
```
Expected: every line ok; symptom count at least 5; ANSWERS sections at least 8; hint count 4.

---

### Task 14: COVERAGE.md — the anti-omission proof

**Files:**
- Create: `database_mastery/COVERAGE.md`

**Interfaces:**
- Consumes: all eight content files and all eight lab directories. Run this task only after Tasks 6–13 are complete, because it audits what they actually contain rather than what they were supposed to contain.
- Produces: the audit that justifies ordering the path by architecture rather than by syllabus.

- [ ] **Step 1: Read every content file and lab README**

Read `content/day01.md` … `content/day08.md` and each `labs/dayNN/README.md`. Build the mapping from what is actually written, not from this plan. Where the plan and the delivered content disagree, the content is the truth and the discrepancy is worth noting in the audit.

- [ ] **Step 2: Write the four coverage tables**

Open with the same framing the spec gives: this path is ordered by the architecture of a database rather than by a certification syllabus, which risks silently dropping something a systematic sweep would catch; this file is the proof that nothing was missed by accident. Every objective is either mapped to a day or marked **SKIPPED** with a reason. There is no third category.

Table 1 — **MongoDB C100DBA objectives**: philosophy and features, CRUD, indexing, aggregation, data modelling, replication, sharding, server administration, backup and recovery, security. Each row: objective, day, where it is covered.

Table 2 — **PostgreSQL DBA competencies**: installation and configuration, roles and security, backup and recovery, vacuum and maintenance, replication and high availability, monitoring, performance tuning, partitioning, upgrades, extensions.

Table 3 — **MySQL 8 / InnoDB operational topics**: buffer pool, redo and undo, row formats, locking and deadlocks, replication and binlog, `performance_schema`, the optimizer, backup.

Table 4 — **Relational theory**: functional dependencies, 1NF through BCNF, lossless join, dependency preservation, the ACID anomaly ladder, serialisability.

- [ ] **Step 3: Write the SKIPPED section with reasons**

Every objective not mapped gets an entry here with a one-line reason. Expected skips, each of which must be justified rather than merely listed: engine installation from source (the stack is containerised); OS-level security hardening (covered by `linux_ops_mastery`); MongoDB Atlas billing administration; replica-set elections beyond failover semantics; MySQL group replication; PostgreSQL logical decoding plugins; upgrade procedures across major versions. If a skip cannot be justified in one line, it is a gap — add it to the relevant day instead of skipping it, and say so in this task's report.

- [ ] **Step 4: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
grep -c 'SKIPPED' COVERAGE.md
awk '/^\|/{n++} END{print "table rows:", n}' COVERAGE.md
grep -qi 'there is no third category' COVERAGE.md && echo "framing ok"
for d in 1 2 3 4 5 6 7 8; do
  grep -q "day0$d\|Day $d" COVERAGE.md && echo "day $d referenced" || echo "day $d MISSING"
done
```
Expected: a non-zero SKIPPED count with reasons; a substantial table-row count; framing ok; all eight days referenced.

---

### Task 15: Final consistency sweep

**Files:**
- Modify: any file found defective by the checks below.

**Interfaces:**
- Consumes: everything. Run last.
- Produces: a written report of what was found and fixed.

This task fixes what it finds. It does not re-author; if a check reveals a missing file or an absent section, create or repair the minimum needed and report it.

- [ ] **Step 1: Structural completeness**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
for d in 01 02 03 04 05 06 07 08; do
  for f in README.md verify.sh SOLUTION.md teardown.md; do
    test -f "labs/day$d/$f" || echo "MISSING labs/day$d/$f"
  done
  test -f "content/day$d.md" || echo "MISSING content/day$d.md"
done
# day08 uses ANSWERS.md instead of SOLUTION.md; day07 has no break.sh; days 01-02 have no break.sh
for d in 03 04 05 06; do test -f "labs/day$d/break.sh" || echo "MISSING labs/day$d/break.sh"; done
test -f labs/day08/ANSWERS.md || echo "MISSING labs/day08/ANSWERS.md"
```
Expected: no `MISSING` lines. Day 8's `SOLUTION.md` absence is expected and is satisfied by `ANSWERS.md` — adjust the loop rather than creating a redundant file.

- [ ] **Step 2: Exercise contract**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery/content
for f in day0*.md; do
  h=$(grep -c 'Hint:' "$f"); s=$(grep -c 'Solution sketch:' "$f")
  echo "$f hints=$h sketches=$s"; test "$h" -eq "$s" || echo "  MISMATCH in $f"
  test "$h" -ge 4 || echo "  TOO FEW exercises in $f"
done
```
Expected: every file balanced, every file with at least four exercises. Any mismatch is a hard failure — the hint-and-sketch rule is non-negotiable.

- [ ] **Step 3: Secret and credential scan**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
grep -rnE 'AKIA[0-9A-Z]{16}|aws_secret_access_key|mongodb\+srv://[^< ]*:[^< ]*@|-----BEGIN' . \
  && echo "SECRETS FOUND — fix before finishing" || echo "no secrets: ok"
grep -rn 'dbmastery' --include='*.tf' --include='*.example' . && echo "check: local password must not appear in cloud files" || echo "cloud files clean: ok"
```
Expected: `no secrets: ok` and `cloud files clean: ok`. The literal `dbmastery` is permitted only in the local stack's compose file, configs, `common.sh` and lab scripts — never in Terraform or `.example` files.

- [ ] **Step 4: Shell and interface consistency**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery/labs
bash -n lib/common.sh verify-teardown.sh day0*/*.sh && echo "all shell syntax ok"
for f in day0*/verify.sh; do
  grep -q 'lib/common.sh' "$f" || echo "$f does not source common.sh"
  grep -q 'exit "${FAILED:-0}"' "$f" || echo "$f missing standard exit"
done
# every function called from a lab must exist in common.sh
grep -rhoE '\b(require_stack|in_pg|in_my|in_mongo|answer_check|say_symptom|pass|fail)\b' day0*/*.sh \
  | sort -u | while read -r fn; do
      grep -q "^${fn}()" lib/common.sh || echo "UNDEFINED FUNCTION: $fn"
    done
```
Expected: all shell syntax ok; no unsourced or non-standard-exit files; no undefined functions.

- [ ] **Step 5: Cross-reference integrity**

```bash
cd /Users/hunghd/git_clone/learning_path/database_mastery
# every relative markdown link resolves
grep -rhoE '\]\(([a-zA-Z0-9_./-]+\.md)(#[a-zA-Z0-9_-]+)?\)' content labs *.md \
  | sed -E 's/^\]\(//; s/\)$//; s/#.*$//' | sort -u | while read -r p; do
      found=0
      for base in . content labs content/primers; do
        test -f "$base/$p" && found=1
      done
      test "$found" -eq 1 || echo "BROKEN LINK: $p"
    done
grep -rn 'primers/' content/day0*.md | head -20   # primers should be referenced, not restated
```
Expected: no `BROKEN LINK` lines; primer references present in the day files that need them.

- [ ] **Step 6: Report**

Write a short report naming: every defect found, what was changed to fix it, and any discrepancy between this plan and the delivered content that was resolved in the content's favour. Do not commit it — hand it to the learner.

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: Purpose and Goals → Task 4 (`README.md`, `STRATEGY.md`); Success Criteria → Tasks 6–13 lab deliverables, audited in Task 14; Constraints and Environment → Tasks 1–2; Strategy → Task 4; the mistakes table → Task 4; Curriculum Days 1–8 → Tasks 6–13; Directory Layout → the File Structure map and every task's Files block; Content Day Skeleton → enforced by the section-presence check in every day task's verify step; COVERAGE.md mapping → Task 14; Risks → mitigated in Tasks 2 (`SCALE`), 3 (`answer_check` non-printing), 12 (teardown gating) and 15 (final sweep).

**Placeholder scan.** No task contains "TBD", "implement later", "add error handling", or "similar to Task N". Every verification step carries runnable commands with stated expected output.

**Type consistency.** The function names in Task 3's `common.sh` (`require_stack`, `in_pg`, `in_my`, `in_mongo`, `answer_check`, `say_symptom`, `pass`, `fail`) are used verbatim in Tasks 6–13 and re-checked mechanically in Task 15 Step 4. Table and column names come from the Global Constraints canonical schema and are used unchanged throughout. The stash path convention `/tmp/.dayNN-target` is introduced in Task 8 and reused in Tasks 9–11 and 13. The `/tmp/answer` `key=value` format is fixed in Task 6 and reused everywhere.

**Two gaps found during review and closed:** Task 11's point-in-time recovery requires WAL archiving, which was not in Task 1's original configuration list — Task 1 Step 3 and the compose file now include `wal_level`, `archive_mode`, `archive_command` and the `pgarchive` volume, and Task 11's Interfaces block states the dependency explicitly. Task 13's `SOLUTION.md` would have been redundant against `ANSWERS.md`, so Task 15's structural check excludes it deliberately rather than reporting a false missing file.

---

## Execution Handoff

Fifteen tasks. Tasks 1–5 are foundation and strictly precede the rest; Tasks 6–13 are mutually independent and suit parallel dispatch; Tasks 14–15 run last and depend on everything.

No task commits anything. No task runs the stack, Terraform, or a cloud CLI.
