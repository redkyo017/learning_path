# Day 8 design brief

## The brief

You're the data-layer lead for a payments platform ("Ledgerly") serving
mid-market e-commerce merchants. Product and finance have handed you
these numbers; your job is the storage design underneath them, not the
API.

- **Volume today:** 12,000,000 payments/day, fairly even across a 16-hour
  business window (roughly 210 payments/second sustained, with a
  documented 6x peak-over-average multiplier during two daily settlement
  windows).
- **Growth:** 40% year-over-year, compounding, for at least the next
  three years — finance's number, not an engineering guess, and you
  should treat it as a floor, not a ceiling.
- **Retention:** 7 years of full transaction and ledger history, a hard
  regulatory obligation in every jurisdiction Ledgerly operates in — not
  a "nice to keep," a "produce it in an audit or face a fine."
- **Latency:** p99 under 200 ms for the payment-write path (authorize +
  capture), p99 under 100 ms for the customer-facing payment-history read
  endpoint (a single customer's or merchant's own recent payments).
- **Tenancy:** Ledgerly sells to merchants directly. Today: roughly 300
  merchant tenants. Contracted growth: 3,000 by the end of year one,
  roughly 20,000 by the end of year three — the same power-law skew this
  path's own seed data uses (a small fraction of merchants will account
  for a large fraction of volume).
- **Team:** 6 backend engineers own the data layer, part-time — nobody's
  full-time job is database operations, and there is no dedicated DBA.
- **One stated future change:** finance has confirmed that within the
  next two quarters, every payment will need a `risk_score NUMERIC(5,2)
  NOT NULL DEFAULT 0` column, populated at write time by a fraud-scoring
  service that doesn't exist yet. The migration has to ship to the
  existing (by then far larger than 10 million rows) `payments` table
  with zero downtime on the write path.

## The deliverable

A one-page design — dense, not padded — covering:

1. **Engine choice**, and the reasoning that produced it, not only the
   name of the engine.
2. **Schema sketch** for the core payment/ledger path (you may extend the
   canonical schema from `global-constraints.md`, but justify any
   departure from it).
3. **Index plan** for the two latency-bound paths named above (the write
   path and the customer-facing history read), with the reasoning for
   each index's column order.
4. **Isolation strategy** — which isolation level the payment-write path
   runs under, and how the "account balance never goes negative" invariant
   is actually defended (see `global-constraints.md`'s note on
   `accounts.balance_minor` being derived, not authoritative).
5. **Capacity arithmetic** — storage and IOPS, projected across the full
   7-year retention window at the stated growth rate, and a connection
   count derived from a stated concurrency assumption, not asserted from
   nowhere.
6. **The zero-downtime migration** for the `risk_score` column, as a
   concrete, numbered sequence of phases — not "we'll use expand/contract"
   asserted without the phases spelled out.

Grade your own draft against `DESIGN-RUBRIC.md` before you read
`REFERENCE-DESIGN.md`. The reference is one defensible design, not the
answer key — reading it before grading your own draft yourself trades
away the exercise for a shortcut that doesn't teach the arithmetic habit
this brief exists to build.
