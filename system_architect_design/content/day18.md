# Day 18 — LLM application architecture: RAG, embeddings, cost/latency

*After today you can: architect a document-Q&A system with retrieval, reason about retrieval quality and cost/latency as first-class NFRs, and say when RAG is the wrong tool.*

## The core problem

You have a private corpus (docs, tickets, wiki) and want an LLM to answer
questions **grounded in it**. Two things block the naive "just ask the model":

1. The model doesn't know your private data (it wasn't trained on it), and
2. You can't paste the whole corpus into every prompt — it won't fit the context
   window, and even if it did, you'd pay for those tokens on every query and add
   latency.

**Retrieval-Augmented Generation (RAG)** solves both: at query time, *retrieve*
the handful of most relevant chunks from your corpus and put **only those** in the
prompt as grounding context. The LLM answers from the retrieved context instead of
from parametric memory.

The architecture isn't "call an LLM." It's a **distributed system with an LLM in
it**: an ingestion pipeline, a vector store, a retriever, a prompt assembler, a
model client, and a cache — each with its own failure modes, latency, and cost.
And the dominant risk is not the model — it's **retrieval quality**: if retrieval
returns irrelevant chunks, the model confidently answers wrong.

Mental model: **RAG turns a knowledge problem into a search problem. Your answer
quality is capped by your retrieval quality.**

## Key concepts

### The pipeline

```mermaid
flowchart LR
  subgraph Ingest (offline, once per doc)
    D[docs] --> CH[chunk] --> EM1[embed] --> VS[(vector store<br/>pgvector)]
  end
  subgraph Query (online, per request)
    Q[question] --> EM2[embed] --> R[retrieve top-k<br/>nearest vectors]
    VS --> R
    R --> P[build prompt<br/>context + question] --> LLM --> A[grounded answer]
  end
  Q -.-> C{semantic cache} -.hit.-> A
```

### Embeddings + vector similarity

An **embedding** maps text to a fixed-length vector (e.g. Amazon Titan v2 →
1024 floats) such that semantically similar texts land near each other. "Nearest"
is measured by **cosine similarity** (angle) or its complement, cosine distance.
Retrieval = "find the k chunk-vectors nearest to the query-vector." With pgvector,
that's `ORDER BY embedding <=> $query_vec LIMIT k` (`<=>` = cosine distance).

### Chunking

You embed *chunks*, not whole documents, because (a) a query usually matches a
passage, not a whole doc, and (b) you want to fit several relevant pieces in the
prompt. Chunk size is a real tradeoff:

- **Too large** → each chunk mixes topics; the query vector matches on the wrong
  part; you waste context-window budget on irrelevant text.
- **Too small** → a chunk lacks the surrounding context needed to be useful;
  retrieval fragments an idea across many chunks.
- Typical: 200–500 tokens with ~10–20% overlap so ideas aren't cut mid-sentence.

### Top-k retrieval and the context-window budget

`k` = how many chunks you inject. Larger `k` raises **recall** (the right chunk is
more likely in the set) but also **cost** (more input tokens), **latency**, and
**noise** (irrelevant chunks can distract the model). You tune `k` empirically —
today's lab measures **precision@k** for k=3 vs k=5.

### Measuring retrieval quality: precision@k

With a labeled set of `query → expected-doc` pairs, **precision@k** (here, hit-rate
@k) = the fraction of queries whose expected doc appears in the top-k retrieved.
This is the single most important number in a RAG system, and most teams don't
measure it. You cannot tune chunk size or `k` without it.

### Grounding & hallucination

RAG reduces but does not eliminate hallucination. If retrieval misses, the model
may still answer confidently from parametric memory. Mitigations: instruct the
model to answer **only** from context and say "I don't know" otherwise; return
**citations** (which chunk each claim came from); set a retrieval **score
threshold** so a bad top-1 doesn't get injected.

### Cost & latency of model choice

Per-query cost ≈ (input tokens = prompt + retrieved chunks) × input-price +
(output tokens) × output-price, plus a small embedding cost for the query. Model
choice is a first-class lever: a cheaper/faster model (e.g. Haiku-class) for
answering can cut $/query and p95 latency by an order of magnitude versus a
frontier model, if quality holds. **Estimate cost per query before you ship** —
it's the line item that dominates at scale (see Day 20).

### Semantic caching

Exact-match caching barely helps — users phrase the same question differently.
**Semantic caching** embeds the query and, if a *previously answered* query is
within a similarity threshold, returns the cached answer — skipping retrieval and
the LLM call entirely. Huge latency/cost win for repeated intents; the risk is a
too-loose threshold serving a stale/wrong answer for a subtly different question.

## The decision / tradeoffs

**RAG vs. alternatives:**

| Approach | Good when | Cost / risk |
|---|---|---|
| **RAG** | Large/changing private corpus; need grounding + citations; facts update often | Embedding pipeline + vector store + retrieval-quality risk |
| **Fine-tuning** | Fixed style/format/behavior; knowledge is stable; latency-sensitive | Retrain to update facts; no citations; can still hallucinate |
| **Long-context stuffing** | Corpus is small enough to fit the window | Pay for all tokens every query; slow; doesn't scale |
| **Keyword search** (BM25) | Queries are exact-term / code / IDs | Misses paraphrase/semantics |
| **Hybrid (BM25 + vector)** | You need both exact terms and semantics | More moving parts |

**Chunk size & k:** driven by precision@k on *your* data, not folklore. Measure.

**Vector store:** pgvector (reuse your Postgres, transactional, good to millions of
vectors) vs. dedicated (Pinecone/Weaviate/Qdrant — better at billions + advanced
filtering). Start with pgvector until scale forces otherwise.

## When NOT this

- **Don't use RAG when fine-tuning or plain search fits.** If you need consistent
  *format/behavior* (always output this JSON, always this tone) rather than fresh
  *facts*, fine-tuning or a good system prompt is simpler — RAG adds an embedding
  pipeline, a vector store, and retrieval-quality risk for nothing. If queries are
  exact-term lookups (error codes, SKUs), keyword/BM25 search beats vector search
  and is cheaper. Alternative wins when: the corpus is stable (fine-tune), tiny
  (stuff the context), or lexical (BM25).
- **Don't add a semantic cache with a loose threshold on high-stakes answers.** A
  0.90-similarity "hit" can serve the answer to a *different* question (e.g.
  "cancel my order" vs "can I cancel my order?" vs "how do I cancel a
  subscription?"). For anything where a wrong-but-confident answer is costly, keep
  the threshold tight or skip the cache.
- **Don't reach for a dedicated vector DB before pgvector is saturated.** At tens
  of thousands to low millions of vectors, `pgvector` on the Postgres you already
  run is simpler, transactional, and cheaper. The dedicated store earns its
  operational cost only at much larger scale or with heavy metadata filtering.

## Real-world

- **Production RAG patterns.** The recurring lesson from teams shipping RAG:
  **retrieval quality is the architecture problem**, not the model. Invest in
  chunking, an eval set (precision@k), reranking, and citations before swapping
  models.
- **Semantic caching writeups.** Caching by *meaning* (embed the query, match on
  similarity) cuts cost and p95 dramatically for repeated intents — with a
  threshold you must tune to avoid serving the wrong answer.
- **pgvector.** A Postgres extension that adds a `vector` column type + ANN indexes
  (IVFFlat, HNSW). *Lesson:* you often don't need a new datastore — extend the one
  you have until scale says otherwise.
- **AWS Bedrock (Titan Embeddings v2 + Claude).** Managed embeddings + a
  managed LLM behind one API; the learner's `aws_bedrock_agent_gw` already fronts
  this. *Lesson:* keep the model client **pluggable** so you can swap providers /
  models to tune cost, latency, and quality without touching the pipeline.

(Log takeaways in `reference/real-world-case-studies.md` → Day 18.)

## Common mistakes / gotchas

1. **No eval set.** Shipping RAG without a labeled `query→expected` set means you
   are tuning chunk size and `k` by vibes. Build 8–50 labeled pairs first.
2. **Chunking on fixed byte counts, mid-sentence.** Splits ideas and tanks recall.
   Chunk on sentence/paragraph boundaries with overlap.
3. **Embedding query and docs with different models/dimensions.** The vectors must
   live in the same space — same model, same normalization, same dimension. A
   `vector(1024)` column can't hold a 1536-dim vector.
4. **Injecting a bad top-1 with no threshold.** If the nearest chunk is still far,
   you inject noise and the model hallucinates on it. Gate on the similarity score.
5. **Ignoring cost until the bill arrives.** LLM tokens dominate at scale.
   Estimate $/query (input+output+embedding) and pick the model deliberately.
6. **Semantic cache threshold too loose.** Serves the answer to a *similar-looking
   but different* question. Tune on real query pairs; log cache hits to audit.
7. **Prompt injection via retrieved content.** A doc in your corpus contains
   "ignore previous instructions…". Retrieved text is untrusted input — this
   becomes a real problem for agents (Day 19).

## Practice

**1. Chunk size / k are killing quality — how do you know, and what do you turn?**

<details><summary>Hint 1</summary>
What number tells you whether retrieval is finding the right chunk?
</details>
<details><summary>Hint 2</summary>
Two independent knobs affect that number: how you split, and how many you fetch.
</details>
<details><summary>Solution sketch</summary>
Measure **precision@k** on a labeled set. If precision@5 is high but precision@3
is low, the right chunk is being retrieved but ranked 4th–5th → try a smaller
chunk size (tighter topical match) or a reranker, or raise k (paying more tokens).
If precision is low even at k=5, the right chunk isn't in the set at all → the
chunking is wrong (too large/mixed, or too small/fragmented) or the embedding
model is a poor fit. You *cannot* diagnose this without the eval set — that's the
whole point of building it first.
</details>

**2. Estimate $/query and decide the model.**
Prompt = 1500 input tokens (system + 5 chunks + question), 300 output tokens.
Compare a frontier model at ~$5/$25 per 1M vs a fast model at ~$1/$5 per 1M.

<details><summary>Hint</summary>
cost = in_tokens × in_price + out_tokens × out_price (+ small embedding cost).
</details>
<details><summary>Solution sketch</summary>
Frontier: 1500/1e6×$5 + 300/1e6×$25 = $0.0075 + $0.0075 = **$0.015/query**.
Fast: 1500/1e6×$1 + 300/1e6×$5 = $0.0015 + $0.0015 = **$0.003/query** (~5× cheaper,
and lower latency). Decision: if the fast model's precision@k answers are
acceptable on your eval set, use it — RAG offloads the "knowing facts" job to
retrieval, so the answering model often doesn't need to be the biggest one. Ship
the frontier model only for the queries where eval shows the fast model fails.
</details>

**3. Where does a semantic cache help, and where does it bite?**

<details><summary>Solution sketch</summary>
Helps: high-volume, repeated *intents* phrased differently ("reset password" /
"how do I reset my password" / "forgot password") — one cached answer serves all,
skipping retrieval + LLM (big p95 + $ win). Bites: a threshold loose enough to
match paraphrases can also match a *different* question ("cancel order" vs "cancel
subscription"), serving the wrong answer with full confidence; and it serves stale
answers if the underlying corpus changed. Mitigate: tune the threshold on labeled
query pairs, scope/expire cache entries when docs change, and never cache
high-stakes or personalized answers loosely.
</details>

**4. Retrieval returns irrelevant chunks → confident wrong answers. Red-team it.**

<details><summary>Solution sketch</summary>
Failure: query has no good match in the corpus, but top-k still returns the
*least-bad* chunks (there's always a nearest neighbor), the model treats them as
authoritative, and answers wrong with confidence. Defenses: (a) a **similarity
threshold** — if the best score is below it, don't inject and answer "I don't have
that information"; (b) instruct the model to ground strictly in context and abstain
otherwise; (c) return **citations** so a human can verify; (d) a reranker to
improve top-k ordering; (e) monitor a "no good context" rate as an SLI. The bug is
that vector search *always* returns something — you must decide when "something"
isn't good enough.
</details>

## Go deeper (offline-friendly)

- **Alex Xu, *Machine Learning System Design Interview*** — retrieval / embedding /
  vector-search chapters; and Xu's system-design newsletter RAG writeups.
- **DDIA Ch. 3 "Storage and Retrieval"** for index intuition (why ANN indexes like
  IVFFlat/HNSW trade recall for speed), and Ch. 11 for the pipeline mindset.
- **pgvector README / docs** — the `vector` type, `<=>`/`<->`/`<#>` operators,
  IVFFlat vs HNSW index tuning (`lists`, `probes`, `m`, `ef_search`).
- **AWS documentation — "Amazon Titan Text Embeddings V2"** (dimensions,
  normalization) and **"Anthropic Claude on Amazon Bedrock"** (the Messages-format
  InvokeModel body, model IDs).
- **Anthropic — "Contextual Retrieval"** and general RAG guidance (chunking,
  reranking, evaluation).
- **AWS Builders' Library** / re:Invent talks on production RAG (retrieval quality,
  guardrails, cost).

## Check yourself

- Why is your answer quality capped by retrieval quality?
- What is precision@k and why can't you tune chunk size / k without it?
- Chunk too large vs too small — what fails in each direction?
- When would you NOT use RAG (name the alternative and its winning condition)?
- How do you estimate $/query, and why is model choice a first-class decision?
- Where does a semantic cache help, and what's the threshold risk?
- What must be identical between how you embed docs and how you embed queries?
