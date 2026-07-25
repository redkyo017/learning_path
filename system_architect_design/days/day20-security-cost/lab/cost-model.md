# Cost model + unit economics worksheet

Reduce the system to a **monthly total** and **$ per 1,000 requests**, name the
**top-2 levers**, then **10× the traffic** and see which line item dominates.

> Rates below are **illustrative** — replace with current AWS/Bedrock prices for your
> region before trusting a number. The method is the point, not the digits. Drive
> volume from your Day-2 capacity estimate (`reference/estimation-cheatsheet.md`).

---

## FILLED EXAMPLE — LLM support/RAG service (ties to Days 18–19)

### Assumptions (from Day-2 estimate)

- **100,000 requests/day ≈ 3,000,000/month** (avg ≈ 1.2 req/s, peak ×~5 ≈ 6 req/s).
- Each request = 1 retrieval + 1 LLM generation: **~3,000 input tokens** (context +
  prompt) + **~500 output tokens**.
- Illustrative model price: input **$3 / 1M tok**, output **$15 / 1M tok**.
  → per request tokens = 3000×$3/1e6 + 500×$15/1e6 = **$0.0090 + $0.0075 = $0.0165**.

### Monthly line items (at 3M req/mo)

| Line item | Basis | Monthly $ | % of bill | Amortizable? |
|-----------|-------|-----------|-----------|--------------|
| **LLM tokens** | $0.0165 × 3M | **49,500** | 93% | No (linear) |
| Vector store (pgvector/OpenSearch) | compute + storage | 1,200 | 2.3% | Partly (reserved) |
| Compute (API + orchestration, Fargate) | ~4 tasks avg | 1,500 | 2.8% | Yes (reserved/spot) |
| Egress + NAT | responses out + cross-AZ | 500 | 0.9% | No |
| Managed / per-request (API GW, etc.) | $3.50/M req + NAT | 200 | 0.4% | No |
| Storage (docs, logs) | GB × retention | 300 | 0.6% | Yes (tiering) |
| **Total** | | **≈ 53,200** | 100% | |

**Unit economics:** $53,200 ÷ (3,000,000 / 1,000) = **$17.73 per 1,000 requests**
(≈ $0.0177/request). If a request earns less than ~$0.02, the model is underwater
before you add margin — that's the number that decides the business, not the total.

**Top-2 levers:** (1) **LLM tokens** (93%); (2) vector store + compute (~5%).

### 10× sensitivity (30M req/mo)

| Line item | 1× ($) | 10× ($) | Notes |
|-----------|--------|---------|-------|
| LLM tokens | 49,500 | **495,000** | linear — doesn't amortize |
| Vector store | 1,200 | 7,000 | ~×6 (reserved capacity dampens) |
| Compute | 1,500 | 7,500 | ~×5 (autoscale/reserved amortize) |
| Egress + NAT | 500 | 5,000 | ~linear |
| Managed / per-req | 200 | 2,000 | linear |
| Storage | 300 | 900 | ~×3 (more logs) |
| **Total** | **53,200** | **≈ 517,400** | |
| **$/1K req** | **17.73** | **17.25** | barely moves — tokens dominate at every scale |

**What 10× reveals:** tokens go from 93% → **95.7%** of the bill and **do not
amortize**. Compute/storage per-request cost *falls* with scale (reserved/spot), so
they never become the lever. The dominant lever is unchanged and unambiguous: **cut
tokens.**

**The FinOps move:** a **semantic cache** with a 40% hit rate cuts token spend ~40%
→ saves ~$200K/month at 10×. Then: shorten retrieved context (fewer input tokens),
right-size the model (smaller model where quality allows), cap output length. Only
after tokens are addressed does touching the ~5% compute line make sense.

---

## YOUR SYSTEM — <name it>

### Assumptions (from your Day-2 estimate)

- Requests/month: __________
- Per-request resource shape (tokens / bytes / CPU): __________
- Rates used (region, date): __________

### Monthly line items

| Line item | Basis | Monthly $ | % of bill | Amortizable? |
|-----------|-------|-----------|-----------|--------------|
| Compute |  |  |  |  |
| Storage |  |  |  |  |
| Egress / data transfer |  |  |  |  |
| Managed / per-request |  |  |  |  |
| LLM tokens (if any) |  |  |  |  |
| **Total** | | | 100% | |

**Unit economics:** total ÷ (requests/1000) = **$______ per 1,000 requests**.
**Top-2 levers:** __________ , __________.

### 10× sensitivity

| Line item | 1× ($) | 10× ($) | Notes |
|-----------|--------|---------|-------|
|  |  |  |  |

**Dominant line at 10×:** __________ — **why isn't it compute?** __________
**The lever I'd pull first:** __________
