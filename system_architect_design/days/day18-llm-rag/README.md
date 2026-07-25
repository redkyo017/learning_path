### Day 18 — LLM application architecture: RAG, embeddings, cost/latency

**Teardown target:** production RAG patterns + semantic-caching writeups
**Design brief:** a document-Q&A system over a private corpus
**ADR topic:** chunking + retrieval strategy; vector store choice; cache layer
**Lab:** minimal RAG on pgvector — ingest ~40 docs, retrieve top-k, answer; measure precision@k (k=3 vs k=5), p95 latency, $/query; add a semantic cache
**When NOT this:** RAG when fine-tuning or a simple keyword search fits — RAG adds an embedding pipeline, a vector store, and retrieval-quality risk
**Builds on:** everything (this is a distributed system with an LLM in it)  **Sets up for:** Day 19 (agents, tool use, guardrails)

---

**Beat 0 — LLM access (~5m).** Confirm you can call embeddings + an LLM. The lab
runs **fully offline by default** with a deterministic `mock` provider (no key
needed) so you can exercise the whole pipeline, precision@k, and the cache. For
real semantic quality, use **AWS Bedrock** via your existing `aws_bedrock_agent_gw`
(Titan embeddings + Claude) — the model client is **pluggable** (`MODEL_PROVIDER`
env; Bedrock is compiled in with `-tags bedrock`). Note your model + cost per 1K
tokens.

**Beat 1 — Read theory (~20m).** `content/day18.md` +
`reference/real-world-case-studies.md` → Day 18. Extract the one that matters:
retrieval quality caps answer quality; you can't tune it without precision@k.

**Beat 2 — Design core (~55m).** Run `reference/design-method.md`:
1. **Requirements** — answer questions grounded in a private corpus, with
   citations; corpus updates over time.
2. **Constraints** — context-window budget; p95 latency target; $/query budget;
   Bedrock available.
3. **Top-3 NFRs** — answer quality/grounding (precision@k), latency (p95),
   cost ($/query).
4. **Options** — RAG (pgvector) vs fine-tuning vs long-context stuffing vs
   BM25/hybrid.
5. **Tradeoff table** vs the top-3 (+ operational cost, freshness).
6. **Decision** — one sentence: why RAG-on-pgvector over the runner-up; pick a
   chunk size, k, and cache threshold.
7. **How it breaks (red-team)** — retrieval returns irrelevant chunks →
   confident wrong answers; a too-loose semantic cache; embedding/dimension
   mismatch.
Write to `design/` + one ADR to `adr/`. Suggested ADR number (global sequence —
adjust to your real count): **0019** "RAG on pgvector: chunk size, top-k, and
semantic cache".

**Beat 3 — Hands-on lab (~55m).** Do `lab/README.md`: swap Postgres to
`pgvector/pgvector:pg16`, ingest the corpus, retrieve→prompt→answer, then
**measure precision@k for k=3 vs k=5**, p95 latency, and estimated $/query.
**Break-it:** shrink chunks absurdly (or set k=1) and watch precision drop; add
the semantic cache and measure the latency/cost win on repeated queries. Record in
`lab/results.md`.

**Beat 4 — Journal (~10m).** Append to `../../journal.md`:
```
### Day 18 — LLM / RAG
Key concept in my own words: …
When would I NOT use this: … (fine-tune / BM25 / stuff-the-context)
Break-it — what I broke and how I diagnosed it: … (tiny chunks -> precision@k dropped)
Biggest surprise / open question: …
```
Then **teardown**: `cd labs && docker compose down -v` (removes the pgvector volume too).

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (RAG pipeline + cost/latency estimate)
- [ ] `diagrams/` — at least one C4/flow `.mmd` (ingest + query paths)
- [ ] `adr/NNNN-*.md` — at least one ADR (chunk size / k / cache)
- [ ] `lab/results.md` — precision@3 vs @5, p95 latency, $/query, cache win, break-it
- [ ] `journal.md` entry appended
- [ ] pgvector stack torn down (`down -v`)
