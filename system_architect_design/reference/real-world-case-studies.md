# Real-World Case Studies — living library

The teardown warm-up each day targets a real system or a battle-tested practice.
Log every one here so this file becomes your personal pattern library. Add your
own one-line "lesson" after studying each — that's the part that sticks.

Format per entry: **System — what they did — the architectural lesson — link.**

## By day (seeded; fill the "my takeaway" line as you go)

### Day 1 — communicating architecture
- **C4 model (Simon Brown)** — four zoom levels for architecture diagrams.
  *Lesson:* one diagram = one level of abstraction. My takeaway: ___
- **AWS Well-Architected Framework** — 6 pillars as an NFR checklist. My takeaway: ___

### Day 2 — estimation
- **Jeff Dean, "Numbers Everyone Should Know"** — latency table that anchors all
  capacity reasoning. *Lesson:* memory ≫ SSD ≫ disk ≫ cross-continent RT. Takeaway: ___

### Day 3 — storage
- **Uber Schemaless** — built an append-only sharded datastore on top of MySQL.
  *Lesson:* model to your access pattern, not to normal forms. Takeaway: ___
- **DynamoDB single-table design** — one table, composite keys, no joins.
  *Lesson:* denormalize around known queries at scale. Takeaway: ___

### Day 4 — replication & consistency
- **Google Spanner** — TrueTime for external consistency across regions (PACELC:
  PC/EC — chooses consistency, pays latency). Takeaway: ___
- **Amazon Dynamo (2007 paper)** — eventual consistency, quorums (N/R/W).
  *Lesson:* match consistency to the business cost of staleness. Takeaway: ___

### Day 5 — partitioning
- **Discord message store** — sharded Cassandra/ScyllaDB by channel+time bucket.
  *Lesson:* choose a partition key that spreads load and matches queries. Takeaway: ___
- **Uber Ringpop** — consistent hashing + gossip for sharding stateless work. Takeaway: ___

### Day 6 — caching
- **Facebook memcached ("Scaling Memcache at Facebook")** — leases to kill
  thundering herds; regional pools. *Lesson:* invalidation is the hard part. Takeaway: ___

### Day 7 — load leveling
- **AWS "Queue-Based Load Leveling" pattern** — a queue decouples burst from
  capacity. *Lesson:* async when the caller doesn't need an immediate answer. Takeaway: ___

### Day 8 — retries & idempotency
- **Stripe idempotency keys** — client-supplied key makes POST safe to retry.
  *Lesson:* every retryable write needs an idempotency key. Takeaway: ___
- **AWS Builders' Library — "Timeouts, retries, and backoff with jitter"** —
  full jitter prevents retry storms. Takeaway: ___

### Day 9 — circuit breakers
- **Netflix Hystrix** — breakers + bulkheads + fallbacks to stop cascades.
  *Lesson:* a breaker needs a meaningful degraded mode. Takeaway: ___

### Day 10 — cells
- **AWS cell-based architecture** + **Shopify pods** + **Slack cellular migration**
  — isolate blast radius by partitioning users into independent stacks. Takeaway: ___

### Day 11 — observability
- **Google SRE — SLOs & error budgets** — reliability as a product decision, not
  "as much as possible." Takeaway: ___

### Day 12 — boundaries
- **Segment: monolith → microservices → monolith** — premature decomposition
  created a distributed monolith; they merged back. *Lesson:* boundaries first,
  network later. Takeaway: ___
- **Amazon Prime Video: re-monolith** — moved a serverless pipeline back to a
  monolith for 90% cost cut. *Lesson:* micro isn't automatically cheaper. Takeaway: ___

### Day 13 — service comms
- **gRPC at scale** — contract-first, additive-only schema evolution. Takeaway: ___
- **Stripe API versioning** — date-based versions, transformations per version. Takeaway: ___

### Day 14 — event-driven
- **Kleppmann, "Turning the Database Inside Out"** + **LinkedIn's log** — the log
  as the source of truth; derive views from it. Takeaway: ___

### Day 15 — CQRS / event sourcing
- **Event sourcing case studies** (ledgers, audit-heavy domains) — plus explicit
  "when NOT" writeups. *Lesson:* complexity tax; reserve for temporal/audit needs. Takeaway: ___

### Day 16 — sagas / outbox
- **The dual-write problem** + **transactional outbox / CDC (Debezium)** — never
  write to DB and broker in two uncoordinated steps. Takeaway: ___

### Day 17 — rollout / mesh
- **Istio** + **progressive delivery (canary/blue-green, feature flags)** —
  decouple deploy from release; automate rollback on SLO burn. Takeaway: ___

### Day 18 — LLM / RAG
- **Production RAG patterns** + **semantic caching** — retrieval quality and
  cost/latency are the real architecture problems. Takeaway: ___

### Day 19 — agents
- **Agent architectures** + **LLM-as-judge eval** — guardrails and evaluation are
  first-class, not add-ons. Takeaway: ___

### Day 20 — security & cost
- **STRIDE threat modeling** + **AWS Well-Architected security & cost pillars** —
  right-size rigor to data sensitivity and scale. Takeaway: ___

### Day 21 — capstone
- (re-skim the 2–3 most relevant to your chosen system) Takeaway: ___

## Add-your-own (as you read beyond the plan)
- …
