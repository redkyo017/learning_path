# Day 8 reference design

> **This is ONE DEFENSIBLE DESIGN for the `DESIGN-BRIEF.md` scenario, not
> THE design.** Every numbered section below states the reasoning behind
> its call, and the closing section names the specific points where a
> different call would have been equally reasonable, and what would tip
> the balance the other way. Treat disagreement with a specific numbered
> section as a sign to check your own reasoning against the brief's
> numbers, not as a sign either draft is wrong — two engineers working
> from the same brief can land on different answers here without either
> being mistaken.

Grade your own draft against `DESIGN-RUBRIC.md` before reading past this
line. What follows answers the rubric's six criteria in the same order,
plus multi-tenancy, so the two documents read side by side.

Every number below is a worked illustration built from the assumptions
stated next to it — not a figure to memorize or expect your own draft to
reproduce exactly. Change an assumption, get a different number, and
that's the arithmetic working as intended, not a sign either version is
wrong.

## 1. Engine choice

PostgreSQL. For the large majority of transactional workloads —
Ledgerly's included — PostgreSQL is the right default, and the actual
engineering question is never "which database is best," it's "what,
specifically, about this workload would make PostgreSQL the wrong
choice." Ledgerly's core payment/ledger path has exactly the properties
that argue for it rather than against it:

- **Cross-row invariants.** Double-entry bookkeeping means every payment
  writes matched debit and credit `ledger_entries` rows whose amounts
  sum to zero, and "an account's balance never goes negative" is a
  property of a *sum* over many rows, not a property any single row can
  enforce on its own. A document store's per-document validation has no
  native answer to a constraint spanning multiple documents; a
  relational engine's transactions and (with the right isolation level)
  serializability do.
- **Moderate-not-extreme scale.** The capacity arithmetic below lands at
  roughly 80 TB and tens of thousands of peak IOPS by the end of the
  7-year window — large, but well inside what a well-tuned PostgreSQL
  instance plus read replicas plus time-based partitioning handles
  without needing to become a distributed system. Horizontal sharding
  earns its complexity when vertical scaling and partitioning genuinely
  run out of room, and this brief's numbers don't cross that line.
- **Ad hoc relational reporting.** Finance and support need to query
  payments by merchant, by customer, by date range, and by combinations
  of those that don't exist yet — the flexibility a normalized relational
  schema with the right indexes gives for free, and a schema tuned around
  one document store's fixed access patterns gives up.

What would tip this the other way: a write pattern that is genuinely
schemaless per record with no cross-record invariant to defend (not the
case here — every payment participates in the ledger invariant); a write
volume that exceeds what partitioning and read replicas can carry even
with an obvious, stable partition key (this brief's ~12,000 peak writes/
sec is nowhere near that line); or an overwhelmingly key-value access
pattern with no relational structure (Ledgerly's reporting requirements
rule this out directly).

## 2. Schema sketch

Extends the canonical schema from `global-constraints.md`, changing
nothing about the double-entry `ledger_entries` structure or the
derived-not-authoritative relationship between `accounts.balance_minor`
and the ledger — both are load-bearing decisions from the brief's own
domain, not open questions this brief raises. Two additions:

```sql
ALTER TABLE payments ADD COLUMN risk_score NUMERIC(5,2);  -- see Section 6

CREATE TABLE idempotency_keys (
    key            TEXT PRIMARY KEY,
    request_hash   TEXT NOT NULL,
    response_body  JSONB,
    status         TEXT NOT NULL,       -- 'pending' | 'completed' | 'failed'
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE outbox_events (
    event_id     BIGINT PRIMARY KEY,
    payment_id   BIGINT NOT NULL REFERENCES payments(payment_id),
    event_type   TEXT NOT NULL,
    payload      JSONB NOT NULL,
    published_at TIMESTAMPTZ,           -- NULL until the publisher confirms delivery
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

`idempotency_keys` and `outbox_events` are written in the **same
transaction** as the `payments` insert, per `content/day08.md`'s Core
concepts — this is what makes the idempotency check race-safe and the
dual-write problem avoidable, not an incidental detail. No `tenant_id`
column is added to `payments` — `merchant_id` already is the tenant key
for a merchant-scoped platform, so a separate column would be redundant;
see Section 3 for how it's used in the multi-tenancy decision.

## 3. Index plan

**Write path.** The insert itself needs no new index — `payments`,
`ledger_entries`, `idempotency_keys`, and `outbox_events` are all
inserts against primary keys or a unique key, and MVCC/insert cost
doesn't depend on secondary indexes existing, though every secondary
index below does add write-time maintenance cost, which is exactly why
the read-path indexes are limited to the two paths the brief actually
latency-bounds, not one per column mentioned anywhere in the brief.

**Customer-facing history read** (`WHERE customer_id = ? AND status =
'captured' ORDER BY created_at DESC LIMIT 20`, the brief's stated p99 <
100 ms path):

```sql
CREATE INDEX idx_payments_customer_status_created
  ON payments (customer_id, status, created_at);
```

Both `customer_id` and `status` are equality predicates; `created_at`
is the sort target. Equality columns lead (Day 3's rule), sort trails —
the same reasoning `labs/day08/ANSWERS.md`'s `missing_index` entry
applies to a different table's version of this exact shape.

**Merchant-facing settlement/reporting read**, the natural second read
path a merchant-facing dashboard needs even though the brief only names
the customer-facing one explicitly:

```sql
CREATE INDEX idx_payments_merchant_status_created
  ON payments (merchant_id, status, created_at);
```

Same reasoning, same shape, `merchant_id` in the equality-leading slot
instead of `customer_id` — this is also the index multi-tenant query
scoping (below) leans on, since `merchant_id` is the tenant key.

**Multi-tenancy, at Ledgerly's actual trajectory.** Shared table with
`merchant_id` as the tenant-scoping column, chosen for *today's* ~300
tenants even though schema-per-tenant would be equally comfortable at
that scale (see Section 7) — because the brief's own three-year,
contracted trajectory (3,000 tenants by year one, ~20,000 by year three)
crosses into the range where schema-per-tenant is disqualified outright.
Applying `content/day08.md`'s three-scale breakdown to Ledgerly's actual
numbers:

- **~300 tenants (today):** either model works. Shared table is chosen
  now specifically to avoid a forced re-platform later, not because it's
  the more comfortable choice at this specific point on the curve.
- **~3,000 tenants (year one):** schema-per-tenant's catalog overhead
  (thousands of schemas × several tables and indexes each) is now a
  real, visible cost against a 6-engineer, no-dedicated-DBA team — this
  is the point at which the brief's own team-size constraint starts
  actively arguing against schema-per-tenant, not merely making it less
  elegant.
- **~20,000 tenants (year three):** schema-per-tenant and
  database-per-tenant are both disqualified. The shared table, already
  in place, needs its power-law-skew mitigation by this point: hash- or
  range-partition `payments` and `ledger_entries` on `merchant_id`, and
  budget for a dedicated read replica (or a dedicated physical partition)
  for whichever handful of merchants are, by then, the platform's own
  power-law whales.

## 4. Isolation strategy

The payment-write path's balance-affecting statements run at
**Serializable**, specifically for the transaction that inserts a
payment's debit/credit `ledger_entries` pair and checks (or relies on a
downstream check of) the resulting derived balance. `Read Committed`
(PostgreSQL's default) and `Repeatable Read` both fail to close this gap
— per `global-constraints.md`, PostgreSQL's Repeatable Read does **not**
prevent write skew, and `accounts.balance_minor` is explicitly a cache
of a sum over `ledger_entries`, never the authoritative value, so a
row-level `CHECK (balance_minor >= 0)` (the check `00-schema.sql` ships
commented out, deliberately) cannot see a concurrent transaction's
not-yet-committed ledger rows and cannot defend the invariant on its
own — the exact anomaly `content/primers/isolation-anomaly-ladder.md
#write-skew` and Day 5's own lab exist to demonstrate. Serializable
detects the conflicting read-write dependency between two concurrent
balance-affecting transactions and aborts one with a serialization
failure, which the application retries — the correct behavior for an
invariant that spans rows a single row-level constraint cannot see.

Every other path — the customer-facing history read, merchant reporting,
the idempotency-key lookup that precedes a write — runs at the default
Read Committed; applying Serializable universally would pay its
retry-under-contention cost on read-only and non-balance-affecting paths
that were never at risk of the anomaly it exists to catch.

## 5. Capacity arithmetic

Every figure below states its assumption; change an assumption and the
downstream number changes with it — that traceability is the point, not
a hedge.

**Rows per day, projected across the 7-year retention window.** Volume
today: 12,000,000 payments/day. Growth: 40% YoY, compounding. Using each
year's *start-of-year* daily rate × 365 as that year's annual volume (a
deliberate simplification — actual within-year growth would push the
true total slightly higher, not lower, so this approximation is
conservative):

| Year | Daily rate (× 1.4^k) | Annual payments |
|---|---|---|
| 1 | 12.0M | ≈ 4.38B |
| 2 | 16.8M | ≈ 6.13B |
| 3 | 23.5M | ≈ 8.58B |
| 4 | 32.9M | ≈ 12.02B |
| 5 | 46.1M | ≈ 16.83B |
| 6 | 64.5M | ≈ 23.56B |
| 7 | 90.4M | ≈ 32.98B |

**Total ≈ 105 billion `payments` rows** accumulated over the 7-year
window — roughly 24× today's single-year volume, not 7×, because most of
the total comes from the later, larger years. Multiplying today's daily
rate by 7 × 365 (ignoring growth) would understate this by roughly an
order of magnitude, exactly the failure mode `DESIGN-RUBRIC.md` names.
Double-entry bookkeeping means **≈ 210 billion `ledger_entries` rows**
(exactly 2 per payment) over the same window.

**Bytes per row.** `payments`: fixed-width columns (five `BIGINT`
foreign/primary keys, `amount_minor`, `currency`, `status`, two
timestamps) plus row overhead ≈ 135 bytes; `description` averages ≈ 40
bytes inline for the ~95% of rows that stay short and ≈ 2,200 bytes for
the ~5% that TOAST (`global-constraints.md`'s stated ~1-in-20 rate),
blending to ≈ 148 bytes/row across the whole table. **≈ 283 bytes/row**
raw, before indexes. `ledger_entries`: no large text column, fixed-width
columns plus row overhead ≈ **90 bytes/row** raw.

**Index overhead.** `payments` carries 3 secondary indexes in this
design (customer-scoped, merchant-scoped, plus the primary key itself is
not "overhead" in this sense) at roughly 35 bytes/entry each (a 2-3
column `BIGINT`/`TIMESTAMPTZ` composite key plus its heap pointer) ≈
105 bytes/row. `ledger_entries` carries 2 secondary indexes (account-
scoped, payment-scoped) at the same per-entry estimate ≈ 70 bytes/row.

**Total, projected:**

- `payments`: 105B rows × (283 + 105) ≈ 105B × 388 bytes ≈ **41 TB**
- `ledger_entries`: 210B rows × (90 + 70) ≈ 210B × 160 bytes ≈ **34 TB**
- Everything else (`merchants`, `customers`, `accounts`,
  `payment_methods`, `refunds`, `disputes`, `idempotency_keys`,
  `outbox_events`) is small by comparison at this scale — budget a few
  more TB for headroom.

**≈ 75-80 TB total by the end of the retention window** — large enough
that time-based partitioning (Section 7) and a tiered storage strategy
(recent partitions on fast storage, older partitions on cheaper storage
once regulatory access patterns allow it) are worth planning for now,
even though nothing here demands sharding across multiple database
instances.

**IOPS from the access pattern.** Peak write rate: 210 payments/sec
sustained × the brief's stated 6x peak multiplier = 1,260 payments/sec
peak. Each payment write touches 6 rows in this design (1 `payments`
insert, 2 `ledger_entries` inserts, 1 `accounts` balance-cache update, 1
`idempotency_keys` insert, 1 `outbox_events` insert) → 7,560 row-writes/
sec at peak; budgeting roughly 1.5× for WAL and index-maintenance
overhead per write gives **≈ 12,000 write IOPS at peak**. Assuming a 5:1
read:write ratio (typical of a payments product's dashboards, receipts,
and reconciliation traffic layered on top of the write path) gives 6,300
reads/sec at peak. The customer-history index answers most of these
tightly, but not every read is a warm-cache index-only hit — assume an
average of 2.5 page reads per query, a stated blend covering both the
common in-cache case (close to 1 page) and the heavier cold-cache/ad hoc
reporting case (5+ pages), not a derivation from first principles: 6,300
× 2.5 ≈ **16,000 read IOPS at peak**. **Target: provision for at least
30,000 combined IOPS at peak** (12,000 write + 16,000 read, rounded up
for headroom), and validate the 2.5-page-per-query assumption against
real traffic once live rather than treating it as a final ceiling.

**Connections, via Little's Law.** Concurrent in-flight requests ≈
request rate × average hold time. Peak combined request rate (writes +
reads): 1,260 + 6,300 = 7,560 requests/sec. Assuming ≈ 15 ms average
hold time per request against a well-indexed OLTP path: 7,560 × 0.015 ≈
**114 concurrent connections needed at peak**; doubling for burst
headroom gives **≈ 230**. This exceeds what a single PostgreSQL instance
should serve as direct backend connections at reasonable memory cost —
the argument for **PgBouncer in transaction-pooling mode** in front of
the database, letting application-tier pools (which can be far larger,
spread across many app instances) multiplex down to a bounded number of
actual PostgreSQL backends.

## 6. The zero-downtime migration

Adding `risk_score NUMERIC(5,2) NOT NULL DEFAULT 0` to `payments` (by
the time this ships, far larger than the ten-million-row figure the
exercise in `content/day08.md` sizes the pattern against, but the
six-phase sequence doesn't change shape with table size):

1. **Expand, nullable, no rewrite.**
   `ALTER TABLE payments ADD COLUMN risk_score NUMERIC(5,2);` —
   metadata-only on PostgreSQL 11+, no table rewrite, lock held only long
   enough to update the catalog.
2. **Deploy dual-write application code.** Ship the version that writes
   `risk_score` on every new row (using a placeholder value until the
   fraud-scoring service exists, then the real score once it does),
   while every read path still treats `NULL` as a valid "not yet scored"
   value.
3. **Backfill in bounded batches.** `UPDATE payments SET risk_score = 0
   WHERE risk_score IS NULL AND payment_id BETWEEN :lo AND :hi;`, looped
   over bounded ranges with a pause between batches, tuned against
   observed replica lag and lock-wait metrics — never one unbounded
   `UPDATE` across the whole table.
4. **Add the constraint, unvalidated.**
   `ALTER TABLE payments ADD CONSTRAINT risk_score_not_null CHECK
   (risk_score IS NOT NULL) NOT VALID;` — enforced on every new write
   immediately, no table scan yet, so it doesn't block on phase 3 still
   running.
5. **Validate.**
   `ALTER TABLE payments VALIDATE CONSTRAINT risk_score_not_null;` —
   scans the table to confirm no live `NULL` remains, under a `SHARE
   UPDATE EXCLUSIVE` lock that coexists with ordinary reads and writes.
6. **Contract: promote and clean up.**
   `ALTER TABLE payments ALTER COLUMN risk_score SET NOT NULL;` — on
   PostgreSQL 12+, the already-validated `CHECK` lets this skip the
   full-table re-scan a plain `SET NOT NULL` would otherwise require.
   Drop the now-redundant `CHECK` constraint afterward.

Rollback before phase 6 is the mirror of whichever phase is live (stop
the backfill, drop the unvalidated constraint, revert the application
deploy); phase 6 itself is cheap to reverse too — dropping a `NOT NULL`
is instant. None of this needs "restore from backup" at any point, which
`content/day08.md`'s Anti-patterns section names directly as throwing
away every write since the backup to undo a change that never needed
downtime.

## 7. Where a different choice would have been equally reasonable

**Isolation strategy (Section 4).** Serializable on the balance-affecting
path, chosen here, is not the only defensible answer. Explicit
pessimistic locking — `SELECT ... FOR UPDATE` on the specific account
rows a transfer touches, under plain Read Committed — is equally
reasonable, and cheaper under contention, since it never pays
Serializable's retry-on-conflict cost. What tips it: if profiling under
real load shows Serializable's abort-and-retry rate on this path is
low (contention on any single account is rare outside the power-law
whales), Serializable's simplicity wins; if the retry rate turns out
to be a real throughput cost — plausible specifically for the small
number of highest-volume merchant accounts — targeted `FOR UPDATE`
locking on only those hot rows is the better trade.

**Multi-tenancy model (Section 3).** Shared table with `merchant_id`,
chosen here for *today's* 300 tenants specifically because of the
brief's stated three-year trajectory, is not the only defensible choice
for today. Schema-per-tenant is equally reasonable at 300 tenants on its
own terms — stronger per-tenant isolation, easier single-tenant
dump/restore/migration-off. What tips it: this design bets that the
brief's "contracted growth" language means the 3,000/20,000-tenant
numbers are real commitments, not aspirational sales targets; if that
growth were materially less certain, optimizing for today's actual scale
with schema-per-tenant and accepting the risk of a future re-platform
would be the more defensible bet instead.

**Partitioning timeline (Sections 3, 5).** This design assumes `payments`
and `ledger_entries` get time-based (and later `merchant_id`-based)
partitioning applied proactively, ahead of any single relation becoming
operationally unwieldy. Deferring partitioning — launching unpartitioned
and retrofitting it once a specific, measured threshold is crossed — is
equally reasonable, and saves the 6-engineer team real effort now that
could go toward the fraud-scoring migration and multi-tenancy work
instead. What tips it: if the team has never operated a partitioned
PostgreSQL table before, proactive partitioning trades a real, immediate
learning cost for avoiding a harder retrofit later under load; if the
team already has that operational experience, deferring is the lower-
effort path and the retrofit, done before the ~80 TB figure gets much
closer, is not especially risky.
