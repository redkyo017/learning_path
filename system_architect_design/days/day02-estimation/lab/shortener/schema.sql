-- Day 2 shortener schema. The service auto-creates this on startup (mustMigrate),
-- so you normally don't need to run it by hand. Kept here so the data model is
-- explicit and reviewable (and so you can pre-create/inspect it via psql).
--
-- psql "postgres://postgres:pass@localhost:5432/app" -f schema.sql

CREATE TABLE IF NOT EXISTS short_urls (
    code       TEXT PRIMARY KEY,           -- the short code; PK => a btree index (point lookup)
    url        TEXT NOT NULL,              -- the original long URL
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Inspect after a load test:
--   SELECT count(*) FROM short_urls;
--   SELECT * FROM short_urls ORDER BY created_at DESC LIMIT 5;
