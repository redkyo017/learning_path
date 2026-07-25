# Day 18 lab results

Date: ____  Provider: mock / bedrock (____)  Chat model (if Bedrock): ____

## Retrieval quality (precision@k)

| chunk_max_chars | top-k for ask | precision@3 | precision@5 |
|----------------:|--------------:|------------:|------------:|
| 400 (baseline)  | 5             |             |             |
| 20 (tiny)       | 5             |             |             |
| 400             | 1             |             |             |

What did tiny chunks do to precision, and why? ____

## Latency + cost

| run | p50 | p95 | cache hits | avg $/query |
|-----|----:|----:|-----------:|------------:|
| cold (cache empty) |  |  | 0 |  |
| warm (cache primed) |  |  |  | ~0 marginal |

(If Bedrock) $/query with opus-4-8 vs haiku-4-5: ____ vs ____

## Semantic cache

- Cold ask latency: ____   Warm (near-duplicate) latency: ____
- Loose-threshold footgun: at CACHE_THRESHOLD=____ , the query "____" wrongly HIT
  the cached answer for "____". Threshold I'd actually ship: ____

## Design linkage
- Chunk size / k I'd choose for this corpus, and the precision@k that justifies it: ____
- When I would NOT use RAG here (alternative + condition): ____

## Break-it summary
- What I broke: ____
- How I diagnosed it (which metric moved): ____
- The fix / mitigation (score threshold, chunk tuning, reranker): ____
