-- Day 8 — idempotent charge schema.
--
-- The UNIQUE constraint on idempotency_key is the entire correctness mechanism:
-- under N concurrent requests carrying the same key, the database guarantees
-- exactly one INSERT succeeds. Everyone else conflicts and replays the stored
-- result. The database, not the app, arbitrates the race.
--
-- Load it:
--   psql "postgres://postgres:pass@localhost:5432/app" -f schema.sql

DROP TABLE IF EXISTS charges;

CREATE TABLE charges (
    id              BIGSERIAL   PRIMARY KEY,
    idempotency_key TEXT        NOT NULL,
    amount_cents    INT         NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'succeeded',
    provider_ref    TEXT,                       -- set if a downstream provider was called
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The idempotency guard. This UNIQUE constraint is what makes the race safe.
-- BREAK-IT: drop it and run the service with IDEMPOTENT=false to get N charges:
--   ALTER TABLE charges DROP CONSTRAINT charges_idempotency_key_uniq;
-- FIX: re-add it (fails if duplicates already exist — clean the table first).
ALTER TABLE charges ADD CONSTRAINT charges_idempotency_key_uniq UNIQUE (idempotency_key);

-- Helper to check the break-it: how many charge rows exist per key?
--   SELECT idempotency_key, count(*) FROM charges GROUP BY 1 ORDER BY 2 DESC;
