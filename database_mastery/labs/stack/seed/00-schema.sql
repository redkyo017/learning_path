-- 00-schema.sql
-- Canonical PostgreSQL schema for the `payments` database (database
-- `payments`, user `dbm`). Names and columns match the Global Constraints
-- canonical schema verbatim -- every later day's labs, verify.sh scripts
-- and break.sh scripts assume these exact identifiers.
--
-- Deliberately no indexes beyond the primary keys created implicitly by
-- PRIMARY KEY constraints. Index creation belongs to Day 3, and to each
-- day's break.sh -- creating indexes here would pre-empt lessons that
-- depend on the learner adding them.
--
-- Drops are here so `seed.sh FORCE=1` can re-run this file against an
-- already-seeded database.

DROP TABLE IF EXISTS wide_payments CASCADE;
DROP TABLE IF EXISTS disputes CASCADE;
DROP TABLE IF EXISTS refunds CASCADE;
DROP TABLE IF EXISTS ledger_entries CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS merchants CASCADE;

CREATE TABLE merchants (
    merchant_id  BIGINT PRIMARY KEY,
    name         TEXT NOT NULL,
    country      CHAR(2) NOT NULL,
    risk_tier    SMALLINT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL
);

CREATE TABLE customers (
    customer_id  BIGINT PRIMARY KEY,
    email        TEXT NOT NULL,
    country      CHAR(2) NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL
);

-- accounts is polymorphic: owner_type/owner_id point at a merchant, a
-- customer, or the platform itself, so there is no single FK target and
-- none is declared for owner_id.
CREATE TABLE accounts (
    account_id     BIGINT PRIMARY KEY,
    owner_type     TEXT NOT NULL,
    owner_id       BIGINT NOT NULL,
    currency       CHAR(3) NOT NULL,
    balance_minor  BIGINT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL
    -- CHECK (balance_minor >= 0)
    -- Day 5 asks you to decide whether a row-level CHECK like this is
    -- enough to defend "an account's balance never goes negative" once
    -- concurrent transactions are in play. Before you answer, work out
    -- what balance_minor actually is with respect to ledger_entries, and
    -- what a CHECK constraint can and cannot see when it runs.
);

CREATE TABLE payment_methods (
    payment_method_id  BIGINT PRIMARY KEY,
    customer_id        BIGINT NOT NULL REFERENCES customers(customer_id),
    brand              TEXT NOT NULL,
    last4              CHAR(4) NOT NULL,
    exp_month          SMALLINT NOT NULL,
    exp_year           SMALLINT NOT NULL
);

CREATE TABLE payments (
    payment_id          BIGINT PRIMARY KEY,
    merchant_id         BIGINT NOT NULL REFERENCES merchants(merchant_id),
    customer_id         BIGINT NOT NULL REFERENCES customers(customer_id),
    payment_method_id   BIGINT NOT NULL REFERENCES payment_methods(payment_method_id),
    amount_minor        BIGINT NOT NULL,
    currency            CHAR(3) NOT NULL,
    status              TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL,
    captured_at         TIMESTAMPTZ,
    description         TEXT NOT NULL,
    CONSTRAINT payments_status_check
        CHECK (status IN ('pending', 'captured', 'failed', 'refunded', 'disputed'))
);

CREATE TABLE ledger_entries (
    entry_id      BIGINT PRIMARY KEY,
    payment_id    BIGINT NOT NULL REFERENCES payments(payment_id),
    account_id    BIGINT NOT NULL REFERENCES accounts(account_id),
    direction     CHAR(1) NOT NULL,
    amount_minor  BIGINT NOT NULL,
    currency      CHAR(3) NOT NULL,
    posted_date   DATE NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL,
    CONSTRAINT ledger_entries_direction_check
        CHECK (direction IN ('D', 'C'))
);

CREATE TABLE refunds (
    refund_id    BIGINT PRIMARY KEY,
    payment_id   BIGINT NOT NULL REFERENCES payments(payment_id),
    amount_minor BIGINT NOT NULL,
    reason       TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL
);

CREATE TABLE disputes (
    dispute_id   BIGINT PRIMARY KEY,
    payment_id   BIGINT NOT NULL REFERENCES payments(payment_id),
    status       TEXT NOT NULL,
    opened_at    TIMESTAMPTZ NOT NULL,
    resolved_at  TIMESTAMPTZ
);

-- wide_payments is Day 2's starting artifact: a fully denormalised,
-- foreign-key-free copy of a payment plus its merchant, customer and
-- payment-method attributes. The redundancy is deliberate -- it is what
-- makes update, insert and delete anomalies reproducible on demand.
CREATE TABLE wide_payments (
    row_id              BIGINT PRIMARY KEY,
    payment_id          BIGINT NOT NULL,
    amount_minor        BIGINT NOT NULL,
    currency            CHAR(3) NOT NULL,
    status              TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL,
    merchant_id         BIGINT NOT NULL,
    merchant_name       TEXT NOT NULL,
    merchant_country    CHAR(2) NOT NULL,
    merchant_risk_tier  SMALLINT NOT NULL,
    customer_id         BIGINT NOT NULL,
    customer_email      TEXT NOT NULL,
    customer_country    CHAR(2) NOT NULL,
    pm_brand            TEXT NOT NULL,
    pm_last4            CHAR(4) NOT NULL,
    pm_exp_month        SMALLINT NOT NULL,
    pm_exp_year         SMALLINT NOT NULL
);
