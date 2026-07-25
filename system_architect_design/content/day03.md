# Day 3 — Storage selection (SQL / NoSQL / NewSQL, access patterns, indexing)

> After today you can: choose a data store from the *access pattern* rather than
> fashion, reason about B-tree vs LSM-tree engines with real latency numbers, know
> when an index helps vs hurts, model the same domain both normalized-SQL and
> denormalized-KV, and say precisely when NoSQL wins and when it's a trap.

Builds on Day 2's sizing (270 TB → shard, 60k reads/s → the lookup path is hot).
Sets up Day 4, which replicates whatever you choose here.

---

## The core problem

The question is never "SQL or NoSQL?" in the abstract. It's: **given the exact
queries this system runs and their relative frequencies, which engine serves them at
the required latency and cost — and what do I give up?**

The mental model to install:

> **Model to your access pattern, not to your data's "natural" shape.** In a
> relational world you model the data and let the query planner figure out access at
> runtime. In a NoSQL world you invert it: you enumerate the queries *first*, then
> design storage so each query is a single cheap lookup. Choosing the wrong
> philosophy for your workload is the expensive mistake.

Two forces pull in opposite directions:

- **Query flexibility** (ad-hoc queries, joins, aggregations you didn't anticipate)
  — relational's strength.
- **Predictable performance at scale on *known* queries** — NoSQL's strength, bought
  by giving up the flexibility above.

If your queries are unknown/evolving → you want flexibility (SQL). If your queries
are few, known, and high-volume → you want denormalized single-purpose access (KV /
wide-column). Most real systems are a mix, and the architecture is *which store owns
which access pattern*.

---

## Key concepts

### Access-pattern-driven modeling

Before choosing a store, write the **query list** with frequencies (from Day 2):

```
shortener:
  Q1  code -> URL            ~60k/s peak   (the hot path; point lookup by PK)
  Q2  create (url,owner)     ~6k/s peak    (write)
  Q3  "my URLs" for owner    low           (list by secondary key)
  Q4  "codes created today"  rare/analytics(range scan by time)
```

The *shape* of each query — point lookup, range scan, join, aggregation — tells you
what index or storage layout you need. Q1 is a pure point lookup → any KV or a
PK-indexed SQL row nails it. Q4 is a range scan on time → needs a time index (trivial
in SQL, a design problem in a pure KV).

### The storage families

| Family | Data model | Sweet spot | Weak at | Examples |
|---|---|---|---|---|
| **Relational (SQL)** | tables + rows, schema, joins | ad-hoc queries, transactions, relational integrity | horizontal write scale (historically), rigid schema | Postgres, MySQL |
| **Key-Value** | opaque value by key | point lookups at massive scale, caching | any query that isn't "by key" | Redis, DynamoDB, Riak |
| **Document** | JSON-ish docs, some 2ary indexes | aggregate-oriented objects, flexible schema | cross-document joins, multi-doc transactions | MongoDB, DynamoDB |
| **Wide-column** | rows with dynamic columns, partition+cluster keys | huge write volume, time-series, known range queries within a partition | ad-hoc queries across partitions | Cassandra, ScyllaDB, Bigtable |
| **NewSQL / distributed SQL** | SQL + horizontal scale + strong consistency | relational semantics *at* scale | cost/complexity; latency of cross-region consistency | Spanner, CockroachDB, Yugabyte |

NewSQL is the "have your cake" option — SQL semantics with horizontal scaling — but
you pay in operational complexity and (for global strong consistency) latency. It's
the honest answer to "I need joins AND shard-scale," not a free lunch.

### B-tree vs LSM-tree — the engine underneath

This is the single most useful storage-internals distinction. It explains *why*
Postgres and Cassandra behave differently under load.

```
B-tree (Postgres, MySQL/InnoDB)          LSM-tree (Cassandra, RocksDB, Scylla)
---------------------------------        ------------------------------------
write: find leaf, update in place        write: append to in-mem memtable + WAL
       (random I/O, write-ahead log)             (sequential, fast) -> flush to
read:  traverse tree, ~O(log n) seeks            immutable SSTables; compact later
       one place to look                  read:  check memtable + several SSTables
                                                 (may touch many) -> bloom filters help
strength: fast reads, read-modify-write   strength: very high *write* throughput
weakness: random write I/O                weakness: read + space amplification,
                                                    compaction is background load
```

- **B-tree:** updates in place → reads are one lookup, but writes do random I/O.
  Great when reads dominate and you need predictable read latency.
- **LSM-tree:** all writes are sequential appends → enormous write throughput, but a
  read may check the memtable plus several on-disk SSTables (mitigated by bloom
  filters), and background **compaction** competes for I/O. Great when writes
  dominate.

Rule of thumb: **write-heavy → lean LSM; read-heavy with updates → lean B-tree.** The
shortener is read-heavy on a mostly-immutable mapping → a B-tree store (Postgres) or
a pure in-memory KV (Redis) both fit; the choice is about scale and cost, which is
today's lab.

### Indexing — when it helps, when it hurts

An index is a **second data structure** the DB maintains to make some reads fast. It
is not free:

- **Helps:** turns a full table scan (O(n)) into a lookup (O(log n)) for the indexed
  predicate. Essential for point lookups and range queries on non-PK columns.
- **Hurts:** every index must be updated on every write → **write amplification** (N
  indexes ≈ N+1 writes per row). Indexes consume storage and RAM (they compete for
  buffer cache). Over-indexing is a common cause of slow writes.
- **The rule:** index the columns your *frequent* queries filter/sort/join on;
  resist indexing everything "just in case." A composite index `(a, b)` serves
  queries on `a` and `(a,b)` but not `b` alone — column order matters.
- **Covering index:** if the index contains every column a query needs, the DB
  answers from the index alone (index-only scan) — no heap fetch.

### Single-table design (the DynamoDB idea)

In DynamoDB you model **all** entities into one table, using a composite key
(partition key `PK` + sort key `SK`) so that each of your known access patterns is a
single `Query` against one partition — **no joins, ever**. You pre-join at write time
by co-locating related items under the same `PK`. Example for orders:

```
PK              SK                 attributes
ORDER#123       META               status, total, created
ORDER#123       ITEM#001           sku, qty, price      -> "get order + its items"
ORDER#123       ITEM#002           sku, qty, price          is ONE query on PK=ORDER#123
CUSTOMER#42     ORDER#2024-01-...  orderId, total       -> "customer's orders" via
                                                            a partition/GSI
```

This is *access-pattern-driven modeling* taken to its logical end: the cost is that a
query you didn't design for is expensive or impossible, and adding one may mean a new
index (GSI) or a data migration. **You trade flexibility for guaranteed single-digit-ms
lookups at any scale.**

---

## The decision / tradeoffs — Postgres vs Redis for the lookup path (today's ADR)

The shortener's hot path is Q1 (`code → URL`, ~60k/s peak, mostly-immutable). Two
credible stores for *that specific path*:

| Criterion | Postgres (indexed) | Redis (KV, in-memory) |
|---|---|---|
| Point-lookup latency (p50/p99) | ~0.2–1 ms / a few ms (buffer-cache hit; disk on miss) | ~0.05–0.3 ms / sub-ms (RAM) |
| Read throughput (one node) | high, bounded by CPU + buffer cache | very high (100k+ ops/s) |
| Durability | strong (WAL, fsync, replication) | weaker by default (RDB/AOF; can lose recent writes) |
| Query flexibility | joins, ranges, ad-hoc, transactions | by-key only; ranges need extra structures |
| Storage cost at 270 TB | disk-priced, cheap per GB | **RAM-priced, expensive** — can't hold 270 TB |
| Operational model | mature, one system to run | another system + the DB behind it |

The honest architecture isn't "Postgres **or** Redis" — it's **Postgres as the
durable system of record + Redis as a cache-aside in front of the hot lookup** (which
is exactly Day 6). Redis alone can't be the source of truth here: 270 TB won't fit in
RAM affordably, and you want durability + Q3/Q4 flexibility. Redis-as-*cache* gives you
its sub-ms reads on the hot 20% while Postgres owns durability and the ad-hoc queries.

**Defensible ADR-0003:** *Postgres is the system of record for the mapping; Redis is a
read-through cache for the redirect path.* Runner-up "Redis as primary KV" loses on
durability and storage cost; runner-up "Postgres only" loses the sub-ms read latency
under the 60k/s peak. Today's lab measures both so the ADR cites numbers, not adjectives.

---

## When NOT this

**Don't reach for NoSQL for relational data with ad-hoc/evolving queries — you'll
rebuild joins and transactions in the application layer, badly.** NoSQL wins on
*known* access patterns at scale, not on flexibility.

- If your product's queries are still changing weekly (early product, analytics,
  internal tools), a relational store's ad-hoc query power is worth more than NoSQL's
  scale ceiling you haven't hit. Denormalizing prematurely bakes today's queries into
  storage and makes tomorrow's query a migration.
- If you need multi-entity transactions and referential integrity (orders + payments +
  inventory in one commit), a single relational DB gives you ACID for free; sagas and
  app-level joins (Day 16) are the expensive alternative you take only when forced.
- **The flip:** NoSQL earns its place when (a) the access patterns are few and stable,
  (b) the scale genuinely exceeds a single relational primary (or a modest shard set),
  and (c) you can accept eventual consistency where it applies. Below that scale,
  "we might need to scale like Amazon" is cargo-culting — Postgres on one big box +
  read replicas + a cache carries most systems very far.

Symmetric caution the other way: don't force *everything* into one Postgres if one
access pattern (a firehose of append-only events, a global point-lookup at DynamoDB
scale) is a genuine mismatch. Polyglot persistence — the right store per access
pattern — is a legitimate outcome; just make each store's *ownership* explicit.

---

## Real-world

- **Uber: MySQL → Schemaless.** Uber outgrew a sharded-MySQL setup and built
  **Schemaless**, an append-only, sharded key-value store *on top of* MySQL: opaque
  cells keyed by (row key, column key, ref key), no cross-shard joins, model-to-access.
  *Lesson:* at extreme scale they gave up relational flexibility for predictable
  sharded writes and operational simplicity — and they built it on boring, trusted
  MySQL rather than a novel engine. Model to the access pattern; prefer proven storage.
- **DynamoDB single-table design (Rick Houlihan's re:Invent talks).** One table,
  composite keys, every access pattern pre-joined at write time, zero runtime joins.
  *Lesson:* denormalize *around your known queries* to buy guaranteed low-latency at
  any scale — and accept that an unplanned query is now a project. The discipline is
  enumerating access patterns *before* modeling.
- **Instagram on Postgres (early).** Ran a huge product on sharded Postgres + memcached
  for a long time. *Lesson:* "boring" relational + cache scales much further than the
  microservices-era instinct assumes; reach for NoSQL when the numbers force it (Day 2),
  not preemptively.

---

## Common mistakes / gotchas

1. **Choosing the store before listing the queries.** The access pattern *is* the
   input; picking DynamoDB or Postgres first and back-filling the model is backwards.
2. **NoSQL for its "flexibility."** NoSQL is *less* flexible for queries — its win is
   scale on *fixed* patterns. Picking it "so we can change things easily" is exactly
   wrong; schema-on-read pushes the pain to every reader.
3. **Rebuilding joins in the app.** Fan-out reads + in-memory joins across a document
   store re-implement a query planner, worse, with N+1 round trips.
4. **Over-indexing.** An index per column tanks write throughput (write amplification)
   and bloats RAM. Index for the frequent queries, not hypothetically.
5. **Ignoring the engine.** Putting a write firehose on a B-tree store and being
   surprised by random-write I/O, or expecting range scans from a pure KV. Match the
   engine (B-tree/LSM) to the read/write balance.
6. **Redis as a database of record.** Treating an in-memory cache as durable storage;
   a restart or eviction silently loses data you thought was persisted.

---

## Practice

### Exercise 1 — pick the store per access pattern

For each, name a store family and one sentence why: (a) session tokens, read on every
request, TTL'd; (b) a financial ledger requiring auditable, transactional correctness;
(c) 500k IoT sensor readings/sec, queried as "this device, last hour"; (d) a product
catalog with faceted search and filters that marketing keeps changing.

<details><summary>Hint 1</summary>
Map each to a query shape: point-lookup-by-key, multi-entity transaction, time-range
within a partition, ad-hoc/evolving filters.
</details>
<details><summary>Solution sketch</summary>

- **(a) Key-Value (Redis).** Pure point lookup by key on the hot path, TTL native,
  loss-tolerant (re-login). In-memory latency is the point.
- **(b) Relational (Postgres) — or NewSQL if it must scale horizontally.** ACID
  transactions and integrity are the top NFR; you want the DB to enforce correctness,
  not the app. (Event sourcing, Day 15, is a complementary pattern for the audit trail.)
- **(c) Wide-column (Cassandra/Scylla) or a time-series DB.** Massive write volume →
  LSM engine; partition key = device_id, clustering key = timestamp makes "device,
  last hour" one efficient range scan within a partition.
- **(d) Relational + a search index (Postgres + Elasticsearch/OpenSearch).** Evolving
  ad-hoc filters need query flexibility; faceted search wants an inverted index. Don't
  denormalize into a KV — the queries change weekly.
</details>

### Exercise 2 — B-tree or LSM?

Workload A: an append-heavy audit log, 100k writes/s, read occasionally by time range.
Workload B: a user-profile store, read 50k/s, updated 500/s, low latency required on
reads. Which storage engine suits each, and what's the failure mode of choosing wrong?

<details><summary>Hint 1</summary>
Which is write-dominated? Which is read-dominated with in-place updates?
</details>
<details><summary>Solution sketch</summary>

- **A → LSM-tree.** 100k sequential appends/s is exactly what an LSM excels at; reads
  are rare and range-shaped. Choosing a B-tree here means random-write I/O and WAL
  pressure limiting throughput far below the LSM's ceiling.
- **B → B-tree.** Read-dominated with in-place updates → predictable one-lookup reads.
  Choosing an LSM means reads may touch multiple SSTables and background compaction adds
  latency jitter (read amplification) for a workload that doesn't need the write
  throughput. Wrong engine = paying the *other* engine's tax for no benefit.
</details>

### Exercise 3 — model the feed both ways (today's design core)

Model a social feed's "load my home timeline" both as (i) normalized SQL (users,
follows, posts) and (ii) denormalized KV/wide-column. Give the read cost of each and
the write cost of each. Which wins for read-heavy at scale, and what does it give up?

<details><summary>Hint 1</summary>
Normalized read = a join across follows × posts at query time. Denormalized = a
precomputed per-user feed list you append to on every post (fan-out on write).
</details>
<details><summary>Hint 2</summary>
Push the cost to the cheaper side. Reads happen far more than posts — so pay at write
time if you can.
</details>
<details><summary>Solution sketch</summary>

- **(i) Normalized SQL:** `SELECT ... FROM posts JOIN follows ON ... WHERE follower=me
  ORDER BY created DESC LIMIT 50`. **Read:** a join + sort over potentially thousands of
  followees per request — expensive, tail-latency-prone at scale. **Write:** trivial —
  one row insert per post. Flexible (any query), but reads don't scale for hot users.
- **(ii) Denormalized KV (fan-out on write):** each user has a precomputed feed list
  (Redis list / wide-column partition keyed by user). **Read:** one lookup of the
  user's feed list — O(1), fast, cache-friendly. **Write:** a post fans out to every
  follower's list (N writes) — expensive for high-follower users.
- **Read-heavy at scale → (ii) wins**, because you pay the cost at write time (rarer)
  to make the frequent read O(1). What it gives up: write amplification, storage
  duplication, and it **breaks for celebrities** (one post = millions of writes) → the
  hybrid push/pull answer (interview Problem 3 / Day 17). Red-team prompt: which query
  can the denormalized model *not* serve cheaply? (e.g. "everyone who liked posts
  containing X" — no index for it; the KV model can't do ad-hoc.)
</details>

### Exercise 4 — the query your model can't serve

You chose DynamoDB single-table design for orders, optimized for "get order + items"
and "customer's orders." Product now wants "all orders in the last hour across all
customers, by status" for an ops dashboard. Why is this hard, and what are your
options?

<details><summary>Hint 1</summary>
That query scans *across* partitions on attributes that aren't your keys. Single-table
design optimized for per-partition access, not cross-partition scans.
</details>
<details><summary>Solution sketch</summary>
It's hard because there's no partition/key that groups "recent orders across all
customers by status" — answering it means a full table scan (slow, expensive) or a
new access path you didn't design for. **Options:** (1) add a **Global Secondary Index**
keyed on e.g. `status` + `created` (costs write throughput + storage, and you must know
the pattern in advance); (2) **stream to a query-friendly store** — DynamoDB Streams →
a relational/OLAP store or a search index that *does* support ad-hoc scans (CQRS-style,
Day 15); (3) accept it as an offline analytics job, not a live query. The lesson: the
denormalized model made the *known* queries cheap and this *unknown* one expensive —
exactly the tradeoff you signed up for. This is why you enumerate access patterns first,
and why polyglot (a second store for analytics) is often the right answer.
</details>

---

## Go deeper (offline-friendly)

- **DDIA (Kleppmann), Ch. 2 "Data Models and Query Languages"** (relational vs document
  vs graph) and **Ch. 3 "Storage and Retrieval"** (B-trees vs LSM-trees, indexes,
  column stores) — this is *the* reference for today; read Ch. 3 twice.
- **Alex Xu, *System Design Interview* Vol. 1** — the "Design a URL shortener" and
  storage-choice sections; Vol. 2 for the feed data-model treatment.
- **Uber Engineering blog — "Designing Schemaless, Uber Engineering's Scalable
  Datastore"** (multi-part) — the MySQL→Schemaless evolution and *why*.
- **Rick Houlihan, AWS re:Invent — "Advanced Design Patterns for DynamoDB"
  (DAT403/DAT401)** — single-table design and access-pattern-first modeling.
- **Amazon DynamoDB paper (2022 USENIX ATC, "Amazon DynamoDB: A Scalable, Predictably
  Performant, and Fully Managed NoSQL Database Service")** — how predictable
  performance is engineered.
- **The original Google Bigtable (2006) and Amazon Dynamo (2007) papers** — the
  ancestors of wide-column and KV thinking.

---

## Check yourself

- Can you state the difference between B-tree and LSM engines and which read/write
  balance each suits — with rough latency numbers?
- Can you explain why an index speeds reads but slows writes, and what write
  amplification is?
- Can you model one domain both normalized-SQL and denormalized-KV, and give the read
  and write cost of each?
- When does NoSQL win, and when is it a trap? State the flip condition precisely.
- For the shortener lookup path, why is "Postgres + Redis cache" more defensible than
  either store alone?
- Which query can your chosen model *not* serve cheaply — and what would you do about it?
