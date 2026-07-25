-- Day 4 schema — apply on the PRIMARY only (replica receives it via WAL).
-- The shortener's core table: short_code -> long_url.
CREATE TABLE IF NOT EXISTS links (
  short_code TEXT PRIMARY KEY,
  long_url   TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A couple of seed rows so the replica has something to stream on first sync.
INSERT INTO links (short_code, long_url) VALUES
  ('abc', 'https://example.com/one'),
  ('xyz', 'https://example.com/two')
ON CONFLICT (short_code) DO NOTHING;
