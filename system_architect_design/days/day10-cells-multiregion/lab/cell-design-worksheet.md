# Cell design worksheet (Day 10)

Fill this during Beat 2. It forces the decisions the ADR then records. Copy the
filled version into `../design/`.

## 1. Routing key
- Partition key: __________ (tenant_id? account_id? user_id?)
- Why this key gives blast radius a *business* meaning (one ____ = one cell): ____
- Do any requests need data from *another* tenant's cell? (If yes, cells may be
  the wrong pattern — note the cross-cell calls.) ____

## 2. Mapping mechanism
- [ ] deterministic hash `cell = hash(key) % N`
- [ ] assignment table (tenant → cell), authoritative in control plane
- [ ] consistent-hash ring (grow cells without a global reshuffle)
- [ ] shuffle sharding (k of N) — justify if chosen: ____
- Hot-path lookup source (must NOT be a per-request DB call): ____
- How a tenant is **migrated** to another cell: ____

## 3. Cell sizing (show the math)
- Total tenants: __________   Per-tenant RPS: __________   Total RPS: __________
- Tested cell ceiling — tenants/cell: ______  RPS/cell: ______ (whichever binds)
- N cells = ceil(total / binding ceiling) = __________  (+ headroom → ____)
- Blast radius per cell failure = 1/N = ______ %
- Largest single tenant fits in one cell with headroom? (yes/no): ____

## 4. The thin router (the shared fate)
- What the router runs on: ______ (DNS / ALB rules / Lambda@Edge / small proxy)
- What it does NOT do (no business logic, no per-request DB): confirm ____
- How it is made not-a-SPOF (stateless, replicated, cached mapping): ____
- Deploy cadence of the router vs the cells (router rarely): ____

## 5. Deploy & control-plane story
- Deploys are cell-by-cell (a cell = a canary)? (yes/no): ____
- Can the **data plane keep serving while the control plane is down** (static
  stability)? How: ____
- Operational lever: "drain cell X" — how is it done: ____

## 6. Region decision
- Single-region multi-cell, or multi-region? __________
- The ONE requirement that justifies multi-region here (region-loss survival /
  data residency) — or "none, deferred": ____

## 7. Red-team (answer each)
- Router becomes the shared fate → mitigation: ____
- A tenant bigger than a cell → mitigation: ____
- Global/bad deploy → blast radius + containment: ____
- Control plane outage → what still works: ____
