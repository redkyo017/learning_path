-- Day 3 storage lab — schema for the Postgres-vs-Redis point-lookup comparison.
--   psql "postgres://postgres:pass@localhost:5432/app" -f schema.sql

DROP TABLE IF EXISTS short_urls;

CREATE TABLE short_urls (
    code       TEXT PRIMARY KEY,            -- PK => btree index => O(log n) point lookup
    url        TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

-- Secondary index on time. This is the whole break-it contrast: Postgres can answer
-- "codes created today" with an index range scan; a pure Redis KV has NO equivalent —
-- it must SCAN the entire keyspace (and doesn't even store the timestamp by default).
CREATE INDEX idx_short_urls_created_at ON short_urls (created_at);
