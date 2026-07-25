-- Day 16 lab schema: transactional outbox + idempotent consumer + a tiny saga.
-- Apply with:  psql "postgres://postgres:pass@localhost:5432/app" -f schema.sql

-- ---- Business tables --------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
    id         BIGSERIAL PRIMARY KEY,
    product    TEXT        NOT NULL,
    qty        INT         NOT NULL,
    status     TEXT        NOT NULL DEFAULT 'PLACED',   -- PLACED|CONFIRMED|CANCELLED
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- The outbox: written in the SAME tx as the business row -----------------
CREATE TABLE IF NOT EXISTS outbox (
    id           BIGSERIAL PRIMARY KEY,
    aggregate_id BIGINT      NOT NULL,          -- e.g. order id
    event_type   TEXT        NOT NULL,          -- e.g. 'OrderPlaced'
    event_id     UUID        NOT NULL UNIQUE,    -- stable dedup key (NOT the Kafka offset)
    payload      JSONB       NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at      TIMESTAMPTZ                     -- NULL until the relay publishes it
);
CREATE INDEX IF NOT EXISTS outbox_unsent_idx ON outbox (id) WHERE sent_at IS NULL;

-- ---- Idempotent-consumer dedup ledger --------------------------------------
CREATE TABLE IF NOT EXISTS processed_events (
    event_id     UUID PRIMARY KEY,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- Saga demo tables -------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory (
    product TEXT PRIMARY KEY,
    stock   INT  NOT NULL
);
CREATE TABLE IF NOT EXISTS payments (
    id       BIGSERIAL PRIMARY KEY,
    order_id BIGINT       NOT NULL,
    amount   NUMERIC(10,2) NOT NULL,
    status   TEXT         NOT NULL DEFAULT 'RESERVED'  -- RESERVED|REFUNDED
);

-- Seed inventory: 'widget' has stock, 'gadget' is out of stock (forces compensation).
INSERT INTO inventory (product, stock) VALUES ('widget', 5), ('gadget', 0)
    ON CONFLICT (product) DO NOTHING;
