-- Day 6 seed — 1000 short codes + one designated 'hot' key.
-- The app seeds this itself with `go run . -seed 1000`; this file is here if you
-- prefer to seed manually via psql.
CREATE TABLE IF NOT EXISTS links (
  short_code TEXT PRIMARY KEY,
  long_url   TEXT NOT NULL
);

INSERT INTO links
  SELECT 'code-' || g, 'https://x/' || g
  FROM generate_series(0, 999) g
ON CONFLICT (short_code) DO NOTHING;

INSERT INTO links VALUES ('hot', 'https://x/hot')
ON CONFLICT (short_code) DO NOTHING;
