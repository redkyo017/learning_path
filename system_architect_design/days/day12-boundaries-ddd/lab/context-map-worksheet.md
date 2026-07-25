# Context-map worksheet (Day 12)

Fill this during Beat 2 for the e-commerce domain (Catalog, Cart, Orders,
Payments, Inventory, Shipping). Copy the filled version into `../design/`.

## 1. Bounded contexts & aggregate roots
| Context | Aggregate root | Key invariant the root enforces | Owning team (Conway) |
|---------|----------------|---------------------------------|----------------------|
| Catalog | Product |  |  |
| Cart | Cart |  |  |
| Orders | Order |  |  |
| Payments | Payment |  |  |
| Inventory | StockItem |  |  |
| Shipping | Shipment |  |  |

Ubiquitous-language check: does "Order" mean the same thing in Sales vs
Fulfillment vs Billing? If not, note the different models: __________

## 2. Context map — relationships & integration style
For each edge, mark the relationship (Partnership / Customer-Supplier / Conformist
/ Anti-Corruption Layer / Shared Kernel / Open-Host-Published-Language) and
**sync vs async**.

| Edge | Relationship | Sync / Async | Why |
|------|--------------|--------------|-----|
| Cart → Catalog (price/availability) |  |  |  |
| Orders → Inventory (reserve/decrement) |  |  |  |
| Orders → Payments |  |  |  |
| Orders → Shipping |  |  |  |
| Payments → external provider |  | (ACL?) |  |

## 3. The chatty-boundary red-team
- Highest-frequency SYNC edge (the chatty one): __________
- Estimated cross-boundary calls per user action: __________ (N+1 risk?)
- Mitigation (keep in-process / batch / cache / event-fed read model): ________

## 4. Aggregate / transaction check
- Any operation that must atomically change TWO aggregates? __________
- If yes: merge them, or use an event + eventual consistency (Day 16)? ________
- Confirm no proposed service boundary splits a single aggregate: ____

## 5. Decision — modular monolith vs microservices
- Team count now: ______   Domain stability: ______ (churning / stable)
- Decision: __________  One-sentence why over the runner-up: __________
- If monolith: which module would you extract FIRST, and what condition triggers
  it (independent scaling / deploy cadence / new owning team)? __________
