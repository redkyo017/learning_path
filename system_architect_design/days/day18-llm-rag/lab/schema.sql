-- Day 18 lab schema — requires the pgvector extension (use the
-- pgvector/pgvector:pg16 image; see docker-compose.override.yml).
-- Apply with:
--   psql "postgres://postgres:pass@localhost:5432/app" -f schema.sql

CREATE EXTENSION IF NOT EXISTS vector;

-- Corpus chunks + their embeddings. The dimension (1024) is FIXED and must match
-- the model's output (Titan v2 default, and the mock provider's dim). Query and
-- chunk embeddings must live in the same space.
CREATE TABLE IF NOT EXISTS chunks (
    id          BIGSERIAL PRIMARY KEY,
    doc_id      TEXT   NOT NULL,
    chunk_index INT    NOT NULL,
    content     TEXT   NOT NULL,
    embedding   vector(1024) NOT NULL
);

-- Semantic cache: previously-answered queries + their embeddings. A new query is
-- a cache HIT if the nearest entry is within CACHE_THRESHOLD cosine distance.
CREATE TABLE IF NOT EXISTS query_cache (
    id         BIGSERIAL PRIMARY KEY,
    query      TEXT   NOT NULL,
    embedding  vector(1024) NOT NULL,
    answer     TEXT   NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- With only ~40 docs, exact (brute-force) cosine search is instant, so no ANN
-- index is required. At scale you would add one, e.g.:
--   CREATE INDEX ON chunks USING hnsw (embedding vector_cosine_ops);
-- and tune ef_search / m (HNSW) or lists / probes (IVFFlat). That trades a little
-- recall for a lot of speed — the classic ANN tradeoff.
