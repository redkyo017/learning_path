# Day 8 design rubric

Grade your own draft against this before reading `REFERENCE-DESIGN.md`.
Each criterion names what a strong answer actually contains, and the
specific failure mode a weak answer falls into — not a vague "needs more
detail," which is not gradeable against your own draft.

## 1. Engine choice

**Strong:** names PostgreSQL, and defends it by naming the *specific*
properties of Ledgerly's workload that argue for it — cross-row
invariants (the double-entry ledger), a moderate-not-extreme scale, and
a need for ad hoc relational reporting — not by asserting "it's the
industry standard" or listing generic strengths. Also names what would
have to be true of the workload for a different choice to be right, even
though this brief doesn't have those properties.

**Weak failure mode:** an engine-choice rubric that scores every engine
well on "consistency," "scalability," and "flexibility" with no
connection to this brief's actual numbers — a comparison table that
would print the same for any brief, which means it didn't actually
engage with this one.

## 2. Schema sketch

**Strong:** starts from the canonical schema in `global-constraints.md`
and extends it only where the brief's new requirement (the `risk_score`
column, a `tenant_id`/merchant scoping decision) demands it, with each
departure justified against a specific stated requirement.

**Weak failure mode:** redesigning the schema from scratch, discarding
the double-entry `ledger_entries` structure or the derived-not-
authoritative relationship between `accounts.balance_minor` and the
ledger, without noticing those were load-bearing decisions from the
brief's own domain, not arbitrary starting points open for a rewrite.

## 3. Index plan

**Strong:** one index per named latency-bound path (the write path, the
customer-facing history read), with the column order justified by
which predicates are equality, which are range, and which are sort —
the same reasoning Day 3 teaches, applied here to a schema you designed
rather than one you were handed. Names what the index costs on the write
path, not only what it buys on the read path.

**Weak failure mode:** an index per column named anywhere in the brief,
with no column-order reasoning and no acknowledgment that indexes are
not free on the write path this brief explicitly latency-bounds too.

## 4. Isolation strategy

**Strong:** names a specific isolation level for the payment-write path
and explains, specifically, how the "balance never goes negative"
invariant is defended given that `accounts.balance_minor` is a cache,
not the source of truth (`global-constraints.md`) — a row-level `CHECK`
on that column cannot see the other rows a concurrent transaction is
writing, which is exactly the write-skew shape Day 5's isolation-anomaly
work covers. A strong answer either names Serializable for the
balance-affecting path specifically, or names the equivalent explicit
locking strategy, and says why Repeatable Read alone does not close the
gap.

**Weak failure mode:** naming an isolation level with no connection to
the specific invariant it needs to defend — "we'll use Serializable
everywhere for safety" without noting the throughput cost that
implies, or "Read Committed is the default, so that" with no
acknowledgment that Read Committed doesn't prevent the anomaly this
brief's own ledger discipline depends on preventing.

## 5. Capacity arithmetic

**Strong:** follows the exact sequence in `content/day08.md`'s Core
concepts — rows/day, bytes/row (including an honest accounting for
`description`'s TOAST-eligible size on the fraction of rows it applies
to), index overhead, growth-projected total across the *whole* retention
window (summed year by year, not multiplied by a flat rate), IOPS from
the access pattern, and connections from Little's Law. Every number
traces back to an assumption the writer stated, so a reader can
disagree with one assumption and recompute rather than having to reject
the whole estimate.

**Weak failure mode:** a single unsupported number ("we'll need about 50
TB") with no visible arithmetic behind it, or an arithmetic chain that
multiplies today's daily volume by the retention window in days without
accounting for growth — understating a 40%-YoY, 7-year total by roughly
an order of magnitude, since most of the accumulated volume comes from
the later, larger years, not the earlier ones.

## 6. The zero-downtime migration

**Strong:** a numbered, concrete sequence — add nullable, deploy
dual-write code, backfill in bounded batches, add an unvalidated `CHECK`,
validate it, then promote to `NOT NULL` and clean up — with the specific
SQL and the specific lock behavior named at each phase, not merely
"we'll do expand and contract." Names what rollback looks like at each
phase before the last, and that the last phase is cheap to reverse too
(dropping a `NOT NULL` is instant).

**Weak failure mode:** "we'll add the column during a maintenance
window" (the brief requires zero downtime on the write path — a
maintenance window is exactly the thing being avoided), or a rollback
plan whose only step is "restore from backup," which the Anti-patterns
section of `content/day08.md` names directly as throwing away every
write since the backup to undo one `ALTER TABLE`.

## Multi-tenancy (folded into the schema/index sections, graded here)

**Strong:** picks a model for *today's* 300 tenants while explicitly
weighing the brief's own three-year trajectory to 10,000+ — noting that
schema-per-tenant, comfortable today, is disqualified at the scale the
brief's own numbers are heading toward, and choosing accordingly rather
than optimizing only for the number on the page today.

**Weak failure mode:** picking a multi-tenancy model by evaluating only
today's tenant count, with no mention of the brief's own stated growth
trajectory — technically defensible at 300 tenants and silently wrong by
year two.
