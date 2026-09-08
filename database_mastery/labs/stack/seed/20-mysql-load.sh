#!/usr/bin/env bash
set -euo pipefail

# 20-mysql-load.sh
#
# Exports a fixed absolute slice of the PostgreSQL payments dataset (the
# first 2,000,000 ledger_entries and every row those entries depend on)
# and loads it into MySQL, then builds three primary-key variant copies of
# payments for Day 1's secondary-index-size comparison. This slice is a
# fixed size regardless of SCALE, by design -- Day 1's exercises compare
# concrete byte counts, and a size that moved with SCALE would move the
# target under the learner's feet. At SCALE < 10 there may be fewer than
# 2,000,000 ledger_entries or 500,000 payments to begin with; the queries
# below use <= filters, so in that case they take everything that
# exists instead of failing.
#
# Run from inside the `ws` service, after 10-generate.sql has populated
# PostgreSQL. Reaches both databases by their compose service names.

PGHOST="${PGHOST:-pg}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-dbm}"
PGDATABASE="${PGDATABASE:-payments}"
export PGPASSWORD="${PGPASSWORD:-dbmastery}"

MYSQL_HOST="${MYSQL_HOST:-my}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-dbm}"
MYSQL_DATABASE="${MYSQL_DATABASE:-payments}"
export MYSQL_PWD="${MYSQL_PWD:-dbmastery}"

EXPORT_DIR="$(mktemp -d /tmp/dbm-mysql-export.XXXXXX)"
trap 'rm -rf "$EXPORT_DIR"' EXIT

psql_copy() {
    # $1 = query (no trailing semicolon), $2 = output CSV path.
    # COPY ... TO STDOUT streams the result through the client connection,
    # so this needs no filesystem access on the pg service itself.
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 \
        -c "COPY ($1) TO STDOUT WITH (FORMAT csv)" > "$2"
}

mysql_exec() {
    # dbm: owns the payments database's tables and data.
    mysql --local-infile=1 -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$@"
}

mysql_root_exec() {
    # root: only for the two administrative statements that dbm cannot
    # run itself -- creating the database and flipping the server-side
    # local_infile switch.
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u root "$@"
}

echo "== 1/4: administrative setup (root) =="
# CREATE DATABASE IF NOT EXISTS is normally a no-op here, since the
# mysql:8.4 image already creates MYSQL_DATABASE=payments on first start;
# it costs nothing to also run it as root so this script is self-
# sufficient against a database that was created some other way.
#
# local_infile = ON belongs in labs/stack/conf/my.cnf so the server
# starts with it enabled (see that file's comment); SET GLOBAL here is
# belt-and-braces so a learner running this against a stale image, or an
# image that didn't pick up the config change, still gets a working seed
# instead of an opaque ERROR 3948 from LOAD DATA LOCAL INFILE below.
mysql_root_exec -e "
CREATE DATABASE IF NOT EXISTS payments CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET GLOBAL local_infile = 1;
"

echo "== 2/4: create MySQL schema (dbm) =="
mysql_exec <<'SQL'
USE payments;

-- Type translation notes -- Day 1 asks the learner to reason about row
-- format differences between engines, so these choices matter:
--   TIMESTAMPTZ -> DATETIME(6)   MySQL has no timezone-aware timestamp
--                                 type with Postgres' range. DATETIME(6)
--                                 keeps microsecond precision; every value
--                                 loaded here is UTC by convention, not by
--                                 type enforcement. The export below
--                                 formats timestamps explicitly as
--                                 'YYYY-MM-DD HH24:MI:SS.US' rather than
--                                 relying on Postgres' default text
--                                 rendering, which appends a +00 offset
--                                 that MySQL 8.0.19+ only accepts in
--                                 +hh:mm form -- the bare +00 would abort
--                                 the load under strict mode.
--   TEXT, bounded in practice
--   (name, email, brand, reason,
--   status, owner_type)          -> VARCHAR(255) or VARCHAR(20). InnoDB
--                                 stores VARCHAR inline in the row (up to
--                                 the ~65,535-byte row-format budget);
--                                 TEXT/BLOB get off-page storage once a
--                                 value is large, which is unnecessary
--                                 overhead for values that are always short.
--   TEXT, unbounded
--   (payments.description)       -> stays TEXT. This is the one column
--                                 that must remain able to overflow the
--                                 row, to mirror Postgres' TOAST behaviour
--                                 for Day 1's cross-engine comparison.
--   CHAR(2)/CHAR(3)/CHAR(4),
--   SMALLINT, BIGINT, DATE        -> unchanged; both engines support them
--                                 natively with the same semantics.
--
-- No FOREIGN KEY clauses: PostgreSQL never auto-indexes a foreign key
-- column, but InnoDB does -- it silently creates a secondary index on
-- every FK column that doesn't already have a leading index, so
-- declaring the same FKs here as in 00-schema.sql would pre-empt Day 3's
-- "add the index and watch the plan change" exercise on the MySQL side
-- before the learner ever gets to it. Referential integrity for this
-- slice is enforced by the generator (10-generate.sql), not by the
-- engine.

DROP TABLE IF EXISTS ledger_entries;
DROP TABLE IF EXISTS pk_variant_natural;
DROP TABLE IF EXISTS pk_variant_uuid;
DROP TABLE IF EXISTS pk_variant_bigint;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS payment_methods;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS merchants;

CREATE TABLE merchants (
    merchant_id BIGINT PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    country     CHAR(2) NOT NULL,
    risk_tier   SMALLINT NOT NULL,
    created_at  DATETIME(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE customers (
    customer_id BIGINT PRIMARY KEY,
    email       VARCHAR(255) NOT NULL,
    country     CHAR(2) NOT NULL,
    created_at  DATETIME(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE accounts (
    account_id     BIGINT PRIMARY KEY,
    owner_type     VARCHAR(20) NOT NULL,
    owner_id       BIGINT NOT NULL,
    currency       CHAR(3) NOT NULL,
    balance_minor  BIGINT NOT NULL,
    created_at     DATETIME(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payment_methods (
    payment_method_id BIGINT PRIMARY KEY,
    customer_id       BIGINT NOT NULL,
    brand             VARCHAR(255) NOT NULL,
    last4             CHAR(4) NOT NULL,
    exp_month         SMALLINT NOT NULL,
    exp_year          SMALLINT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payments (
    payment_id         BIGINT PRIMARY KEY,
    merchant_id        BIGINT NOT NULL,
    customer_id        BIGINT NOT NULL,
    payment_method_id  BIGINT NOT NULL,
    amount_minor       BIGINT NOT NULL,
    currency           CHAR(3) NOT NULL,
    status             VARCHAR(20) NOT NULL,
    created_at         DATETIME(6) NOT NULL,
    captured_at        DATETIME(6) NULL,
    description        TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ledger_entries (
    entry_id      BIGINT PRIMARY KEY,
    payment_id    BIGINT NOT NULL,
    account_id    BIGINT NOT NULL,
    direction     CHAR(1) NOT NULL,
    amount_minor  BIGINT NOT NULL,
    currency      CHAR(3) NOT NULL,
    posted_date   DATE NOT NULL,
    created_at    DATETIME(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQL

echo "== 3/4: export slice from PostgreSQL and load into MySQL =="
# merchants/customers/accounts/payment_methods are exported in full: they
# are small relative to payments/ledger_entries, and exporting them whole
# is simpler and safer than computing exactly which rows the 2,000,000
# ledger_entries slice references.
#
# Every TIMESTAMPTZ column is rendered explicitly via to_char(... AT TIME
# ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') rather than a bare ::text cast:
# Postgres' default text output appends a UTC offset ("+00"), which
# MySQL 8.0.19+ only parses in +hh:mm form, and under MySQL 8.4's default
# STRICT_TRANS_TABLES that mismatch aborts the LOAD DATA instead of only
# warning. Formatting explicitly sidesteps session DateStyle entirely.
#
# COALESCE(...,'\N') turns SQL NULL into the literal two characters \N,
# which MySQL's LOAD DATA INFILE recognises as NULL by default. Postgres'
# CSV COPY format represents NULL as an empty field instead, which LOAD
# DATA would otherwise read as an empty string, not NULL.
psql_copy "SELECT merchant_id, name, country, risk_tier, to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') FROM merchants ORDER BY merchant_id" \
    "$EXPORT_DIR/merchants.csv"
psql_copy "SELECT customer_id, email, country, to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') FROM customers ORDER BY customer_id" \
    "$EXPORT_DIR/customers.csv"
psql_copy "SELECT account_id, owner_type, owner_id, currency, balance_minor, to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') FROM accounts ORDER BY account_id" \
    "$EXPORT_DIR/accounts.csv"
psql_copy "SELECT payment_method_id, customer_id, brand, last4, exp_month, exp_year FROM payment_methods ORDER BY payment_method_id" \
    "$EXPORT_DIR/payment_methods.csv"

# ledger_entries are generated as payment_id*2-1 (D) / payment_id*2 (C),
# so entry_id <= 2,000,000 is exactly the first 1,000,000 payments' worth
# of entries -- filtering payments the same way keeps the two exports
# referentially consistent without an extra round trip to find the
# matching payment_id range.
psql_copy "SELECT payment_id, merchant_id, customer_id, payment_method_id, amount_minor, currency, status, to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US'), COALESCE(to_char(captured_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US'), '\\N'), description FROM payments WHERE payment_id <= 1000000 ORDER BY payment_id" \
    "$EXPORT_DIR/payments.csv"
psql_copy "SELECT entry_id, payment_id, account_id, direction, amount_minor, currency, posted_date, to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') FROM ledger_entries WHERE entry_id <= 2000000 ORDER BY entry_id" \
    "$EXPORT_DIR/ledger_entries.csv"

mysql_exec "$MYSQL_DATABASE" -e "
LOAD DATA LOCAL INFILE '$EXPORT_DIR/merchants.csv' INTO TABLE merchants
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\n'
(merchant_id, name, country, risk_tier, created_at);
"
mysql_exec "$MYSQL_DATABASE" -e "
LOAD DATA LOCAL INFILE '$EXPORT_DIR/customers.csv' INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\n'
(customer_id, email, country, created_at);
"
mysql_exec "$MYSQL_DATABASE" -e "
LOAD DATA LOCAL INFILE '$EXPORT_DIR/accounts.csv' INTO TABLE accounts
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\n'
(account_id, owner_type, owner_id, currency, balance_minor, created_at);
"
mysql_exec "$MYSQL_DATABASE" -e "
LOAD DATA LOCAL INFILE '$EXPORT_DIR/payment_methods.csv' INTO TABLE payment_methods
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\n'
(payment_method_id, customer_id, brand, last4, exp_month, exp_year);
"
mysql_exec "$MYSQL_DATABASE" -e "
LOAD DATA LOCAL INFILE '$EXPORT_DIR/payments.csv' INTO TABLE payments
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\n'
(payment_id, merchant_id, customer_id, payment_method_id, amount_minor, currency, status, created_at, captured_at, description);
"
mysql_exec "$MYSQL_DATABASE" -e "
LOAD DATA LOCAL INFILE '$EXPORT_DIR/ledger_entries.csv' INTO TABLE ledger_entries
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\n'
(entry_id, payment_id, account_id, direction, amount_minor, currency, posted_date, created_at);
"

echo "== 4/4: build PK-variant tables (Day 1) =="
# Three copies of the same 500,000 payments rows, differing only in
# primary key, each carrying identical secondary indexes on (status) and
# (created_at). Day 1 measures how those secondary indexes differ in size
# purely as a function of the primary key's width and type -- InnoDB
# stores the primary key value inside every secondary index entry.
mysql_exec "$MYSQL_DATABASE" <<'SQL'
DROP TABLE IF EXISTS pk_variant_natural;
DROP TABLE IF EXISTS pk_variant_uuid;
DROP TABLE IF EXISTS pk_variant_bigint;

CREATE TABLE pk_variant_bigint (
    payment_id         BIGINT PRIMARY KEY,
    merchant_id        BIGINT NOT NULL,
    customer_id        BIGINT NOT NULL,
    payment_method_id  BIGINT NOT NULL,
    amount_minor       BIGINT NOT NULL,
    currency           CHAR(3) NOT NULL,
    status             VARCHAR(20) NOT NULL,
    created_at         DATETIME(6) NOT NULL,
    captured_at        DATETIME(6) NULL,
    description        TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO pk_variant_bigint
SELECT payment_id, merchant_id, customer_id, payment_method_id, amount_minor,
       currency, status, created_at, captured_at, description
FROM payments
WHERE payment_id <= 500000;

CREATE INDEX ix_pk_variant_bigint_status ON pk_variant_bigint (status);
CREATE INDEX ix_pk_variant_bigint_created_at ON pk_variant_bigint (created_at);

-- pk_uuid is a deterministic, UUID-shaped string derived from payment_id
-- (not MySQL's UUID(), which is not seedable) so repeated seed runs at
-- the same SCALE load byte-identical data.
CREATE TABLE pk_variant_uuid (
    pk_uuid            CHAR(36) PRIMARY KEY,
    payment_id         BIGINT NOT NULL,
    merchant_id        BIGINT NOT NULL,
    customer_id        BIGINT NOT NULL,
    payment_method_id  BIGINT NOT NULL,
    amount_minor       BIGINT NOT NULL,
    currency           CHAR(3) NOT NULL,
    status             VARCHAR(20) NOT NULL,
    created_at         DATETIME(6) NOT NULL,
    captured_at        DATETIME(6) NULL,
    description        TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO pk_variant_uuid
SELECT CONCAT(
           LPAD(HEX(payment_id), 8, '0'), '-0000-4000-8000-',
           LPAD(HEX(payment_id), 12, '0')
       ),
       payment_id, merchant_id, customer_id, payment_method_id, amount_minor,
       currency, status, created_at, captured_at, description
FROM payments
WHERE payment_id <= 500000;

CREATE INDEX ix_pk_variant_uuid_status ON pk_variant_uuid (status);
CREATE INDEX ix_pk_variant_uuid_created_at ON pk_variant_uuid (created_at);

CREATE TABLE pk_variant_natural (
    merchant_id        BIGINT NOT NULL,
    created_at         DATETIME(6) NOT NULL,
    payment_id         BIGINT NOT NULL,
    customer_id        BIGINT NOT NULL,
    payment_method_id  BIGINT NOT NULL,
    amount_minor       BIGINT NOT NULL,
    currency           CHAR(3) NOT NULL,
    status             VARCHAR(20) NOT NULL,
    captured_at        DATETIME(6) NULL,
    description        TEXT NOT NULL,
    PRIMARY KEY (merchant_id, created_at, payment_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO pk_variant_natural
SELECT merchant_id, created_at, payment_id, customer_id, payment_method_id,
       amount_minor, currency, status, captured_at, description
FROM payments
WHERE payment_id <= 500000;

CREATE INDEX ix_pk_variant_natural_status ON pk_variant_natural (status);
CREATE INDEX ix_pk_variant_natural_created_at ON pk_variant_natural (created_at);
SQL

echo "MySQL load complete."
