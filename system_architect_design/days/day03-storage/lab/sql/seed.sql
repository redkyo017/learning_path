-- Seed 1,000,000 short_url rows. Codes are deterministic-but-random-looking
-- (16 hex chars from md5 of the row number => effectively collision-free for a PK).
-- created_at is spread over the last 30 days, so "created today" (last 24h) is
-- ~1/30 of the rows (~33k) — a realistic partial range scan.
--
--   psql "postgres://postgres:pass@localhost:5432/app" -f seed.sql
-- Takes a few seconds. Adjust the 1000000 below if your machine is small.

INSERT INTO short_urls (code, url, created_at)
SELECT
    substr(md5(g::text), 1, 16)                          AS code,
    'https://example.com/page/' || g                     AS url,
    now() - (random() * interval '30 days')              AS created_at
FROM generate_series(1, 1000000) AS g
ON CONFLICT (code) DO NOTHING;   -- skip the vanishingly rare hash collision

-- Sanity:
--   SELECT count(*) FROM short_urls;                       -- ~1,000,000
--   SELECT count(*) FROM short_urls WHERE created_at >= date_trunc('day', now());
ANALYZE short_urls;   -- refresh planner stats so EXPLAIN is honest
