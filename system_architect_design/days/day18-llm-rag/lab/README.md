# Day 18 lab — minimal RAG on pgvector: precision@k, latency, $/query, cache

**Goal:** ingest ~40 docs into pgvector, retrieve top-k → prompt → answer, then
**measure precision@k (k=3 vs k=5)**, p95 latency, and estimated $/query. Add a
semantic cache and measure the win. **Break-it:** shrink chunks / drop k and watch
precision fall.

Runs **fully offline** with the default `mock` provider (no API key). Swap in
**AWS Bedrock** (`-tags bedrock`) for real semantic quality.

## 0. Bring up pgvector + schema

The shared Postgres image doesn't have `vector`; the override swaps it for
`pgvector/pgvector:pg16`.

```bash
# from the repo root
cd labs
docker compose -f docker-compose.yml \
  -f ../days/day18-llm-rag/lab/docker-compose.override.yml \
  up -d postgres
docker compose ps           # postgres (pgvector image) healthy

# apply schema (runs CREATE EXTENSION vector)
psql "postgres://postgres:pass@localhost:5432/app" \
  -f ../days/day18-llm-rag/lab/schema.sql

cd ../days/day18-llm-rag/lab
go mod tidy                 # resolves pgx, writes go.sum (mock path: no AWS deps)
```

## 1. Build: ingest + ask (mock provider, offline)

```bash
go run . ingest
#  -> ingested 40 docs -> ~40 chunks (chunk_max_chars=400, provider=mock ...)
go run . status

go run . ask "What is the API rate limit per minute?"
#  prints an answer, the retrieved sources (doc_id + cosine distance),
#  latency, approx token counts, and est_cost ($0 for mock)
```

## 2. Measure: precision@k, latency, $/query

```bash
go run . eval
#  precision@3 = ...   precision@5 = ...
#  latency cold p50/p95, warm p50/p95, cache_hits, avg $/query
```

Record precision@3 vs precision@5. With good chunking they should both be high;
precision@5 ≥ precision@3 always (a larger set can only include more gold docs).

## 3. Break-it: shrink chunks / drop k, watch precision drop

```bash
# absurdly tiny chunks fragment each doc -> the matching idea is split up
CHUNK_MAX_CHARS=20 go run . ingest
go run . eval          # precision typically drops vs the 400-char baseline

# or keep good chunks but fetch only k=1 (no room for the gold doc to appear lower)
CHUNK_MAX_CHARS=400 go run . ingest
TOP_K=1 go run . eval  # precision@k reported for k in {3,5}; but ask uses k=1
go run . ask "How often are database backups taken?"   # with TOP_K=1, one chunk only
```

**Observe:** retrieval quality — not the model — sets the ceiling on answers. This
is why you build the labeled eval set *first* and tune chunk size / k against it.
Re-ingest at `CHUNK_MAX_CHARS=400` before moving on.

## 4. Semantic cache win

The `eval` command already primes and re-runs the cache (warm p95, cache_hits).
See it directly:

```bash
go run . resetcache
go run . ask "How do I reset my password if I forgot it?"      # cold: retrieves + LLM
go run . ask "How can I reset my password? I forgot it"        # near-duplicate intent
#  -> [semantic cache HIT]  (much lower latency, $0 marginal cost)

# tighten/loosen the threshold to feel the risk:
CACHE_THRESHOLD=0.5 go run . ask "How do I cancel my subscription?"
#  a loose threshold can HIT the password answer for a DIFFERENT question — that's
#  the semantic-cache footgun. Tune it down.
```

## 5. (Optional) Real Bedrock quality

```bash
go get github.com/aws/aws-sdk-go-v2/config \
       github.com/aws/aws-sdk-go-v2/service/bedrockruntime \
       github.com/aws/aws-sdk-go-v2/aws
export AWS_PROFILE=... AWS_REGION=ap-southeast-1
MODEL_PROVIDER=bedrock go run -tags bedrock . ingest
MODEL_PROVIDER=bedrock go run -tags bedrock . eval
# Compare $/query with BEDROCK_CHAT_MODEL=anthropic.claude-opus-4-8 vs
# BEDROCK_CHAT_MODEL=anthropic.claude-haiku-4-5 — model choice is a cost lever.
```

## 6. Teardown (mandatory)

```bash
cd ../../../labs && docker compose down -v      # removes the pgvector volume too
```

## What to record in `results.md`
- precision@3 vs precision@5 at the baseline chunk size.
- precision after the tiny-chunk / k=1 break-it (should drop).
- cold vs warm p95 latency, cache hit count, avg $/query.
- the loose-threshold cache footgun you observed.

> **TODO for you (the one insight to implement):** add a **retrieval score
> threshold** — if the best chunk's cosine distance exceeds a cutoff, answer "I
> don't have that information" instead of injecting a bad chunk. Wire it into
> `answerQuery` and add a test query with no good match to prove it abstains.
> Everything else runs as-is.
