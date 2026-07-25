# Backlog — future topics (extend past Day 21)

Pull from here when you finish the core 21 days or want to insert a topic. To add
a day: `cp templates/day-template.md days/dayNN-<slug>/README.md`, write
`content/dayNN.md`, reuse `labs/`, then tick it off here.

Priority: **P1** = highest leverage next, **P3** = niche/when-needed.

## Data & scale (deeper)
- [ ] **P1 — Stream processing deep-dive** (windowing, watermarks, exactly-once
  in Kafka Streams / Flink). Lab: tumbling+sliding windows over the Day-14 event stream.
- [ ] **P2 — Analytics / lakehouse** (OLTP vs OLAP, columnar stores, CDC → warehouse,
  medallion architecture). Lab: CDC from Postgres → DuckDB/parquet.
- [ ] **P2 — Time-series & metrics stores at scale** (downsampling, retention tiers).
- [ ] **P3 — Search architecture** (inverted index, Elasticsearch/OpenSearch, relevance).

## Real-time & edge
- [ ] **P1 — Real-time / WebSockets / SSE** (connection state, fan-out, presence).
  Lab: a presence service with Redis pub/sub.
- [ ] **P2 — CDN & geo-distribution** (edge caching, anycast, geo-routing, PoPs).
- [ ] **P3 — Push notifications at scale** (device registry, fan-out, dedup).

## Resilience & operations (deeper)
- [ ] **P1 — Chaos engineering** (hypothesis-driven fault injection, game days).
  Lab: extend Toxiproxy into a scripted chaos suite over the Day-9/11 stack.
- [ ] **P2 — Rate limiting & quotas at scale** (distributed token bucket, sliding log).
- [ ] **P2 — Multi-region active-active** (conflict resolution, CRDTs, global routing).
- [ ] **P3 — Disaster recovery** (RPO/RTO, backup/restore drills, failover runbooks).

## Modern patterns (deeper)
- [ ] **P1 — GraphQL & federation** (schema stitching, N+1, persisted queries).
- [ ] **P2 — Backend-for-frontend (BFF) & API gateway patterns.**
- [ ] **P2 — Feature flags & experimentation platform** (targeting, rollout, kill switches).
- [ ] **P3 — Workflow/orchestration engines** (Temporal, Step Functions).

## AI/LLM (deeper)
- [ ] **P1 — LLM evaluation deep-dive** (golden sets, LLM-as-judge calibration,
  regression suites, offline vs online eval).
- [ ] **P2 — Fine-tuning vs RAG vs prompt engineering** (decision framework, cost).
- [ ] **P2 — Advanced RAG** (hybrid search, re-ranking, query rewriting, graph RAG).
- [ ] **P3 — LLM serving & inference infra** (batching, KV-cache, quantization, GPU cost).

## Platform & org
- [ ] **P1 — Platform engineering / Internal Developer Platform** (golden paths,
  self-service, paved roads).
- [ ] **P2 — Multi-tenancy patterns** (silo vs pool vs bridge, noisy neighbor).
- [ ] **P3 — Data governance & privacy-by-design** (PII handling, GDPR, data contracts).

## Interview practice (extra reps)
- [ ] **P1 — Extra problem sets** (see `reference/interview-problems.md` for the
  bank with hints + solution sketches; do 1–2 timed per week to stay sharp).
