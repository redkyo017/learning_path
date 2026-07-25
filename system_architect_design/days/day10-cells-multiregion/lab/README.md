# Day 10 Lab — 2 isolated cells + a thin router; kill one; prove containment

**Goal:** build the smallest credible cell topology — a thin router in front of
**two fully independent cells** — send traffic across many tenants, then **kill
one cell** and prove the other cell's tenants are **unaffected**. That contained
failure is the whole point of cells.

This lab is deliberately **partial / design-heavy** (per the plan): the runnable
proof is **local** (fast, free, no teardown risk); an **optional AWS sketch** in
`aws/` shows the same shape with an ALB + 2 target groups if you want the cloud
rep. Do the design worksheet either way.

> Prereq: Go 1.22+. The AWS path additionally needs `aws` CLI v2 and a sandbox
> profile — and a **mandatory teardown** (see bottom).

---

## Part A — Local containment demo (do this)

A "cell" here is an `echo` instance with its own identity (in a real system it
would also have its own DB/cache/queue — the router code and the containment
logic are identical; we keep the data layer out to stay time-boxed).

### 1. Start two independent cells

```bash
# from this lab/ directory — two terminals, or background them:
( cd ../../../labs/services/echo && PORT=8081 NAME=cell-a go run . ) &
( cd ../../../labs/services/echo && PORT=8082 NAME=cell-b go run . ) &
```

Each cell is a separate process, separate port, no shared state — that is the
isolation. Verify:

```bash
curl -s localhost:8081/health   # ok  (cell-a)
curl -s localhost:8082/health   # ok  (cell-b)
```

### 2. Start the thin router

```bash
CELLS="http://localhost:8081,http://localhost:8082" PORT=8090 go run ./router
```

The router maps `tenant -> cell` with `fnv1a(tenant) % 2` and reverse-proxies.
It has **no business logic and no DB lookup** — that thinness is what stops the
shared component from becoming the shared fate. Check the mapping:

```bash
curl -si -H "X-Tenant: acme"   localhost:8090/whichcell   # X-Cell: ...:8081 or :8082
curl -si -H "X-Tenant: globex" localhost:8090/whichcell
# route a real request; note the "done by cell-a/cell-b" body:
curl -s  -H "X-Tenant: acme"   "localhost:8090/work?ms=5"
```

### 3. Measure — baseline (both cells healthy)

```bash
chmod +x loadgen.sh
./loadgen.sh http://localhost:8090 40
```

Expect ~50/50 split across cell-a and cell-b, **0 failures**. Record the split in
`results.md` (baseline row).

### 4. BREAK IT (the core) — kill one cell

Kill **cell-a** only (find its PID: `lsof -ti:8081 | xargs kill`, or Ctrl-C its
terminal). Leave cell-b and the router running. Re-run the tally:

```bash
./loadgen.sh http://localhost:8090 40
```

**What you should observe:**
- Every tenant hashed to **cell-a** now returns **503** (`X-Cell-Error: 1`) — the
  router fails them fast instead of hanging or spilling them onto cell-b.
- Every tenant hashed to **cell-b** still returns **200** at full success — its
  blast radius did not grow.
- Net impact ≈ **50%** of tenants (because N=2). In production with N=25 cells the
  same failure would hit ≈ **4%**. That ratio *is* the availability argument.

Record both rows in `results.md` and note: which tenants failed, which didn't,
and confirm cell-b's success rate and latency did **not** degrade.

### 5. (Optional) Prove the anti-pattern

Point the router's `ErrorHandler` at "reroute to the other cell on failure"
(a tempting "resilience" move) and re-run: watch the dead cell's load **spill
onto the healthy cell**, and reason about how that re-couples their fate (the
healthy cell now carries 2× load + retries → it can tip over too). Then revert.
This is why containment sometimes means *letting the contained part fail*.

Bring it down: Ctrl-C the router and `lsof -ti:8082 | xargs kill`.

---

## Part B — AWS path (optional; MANDATORY teardown if you run it)

See `aws/terraform-sketch.tf` for a minimal, clearly-TODO'd sketch:
- 1 ALB (the thin router) with **host-header / path rules** → 2 target groups.
- 2 EC2 instances (or 2 ECS services), one per target group = **cell-a**,
  **cell-b**, each running the `echo` image.
- Break-it: deregister/stop cell-a's instance → its target group goes unhealthy →
  tenants routed to cell-a get 503 from the ALB while cell-b tenants are fine.

Apply/observe/**destroy** in one sitting; cost target $1–3. Teardown is below and
in `aws/teardown.sh`.

---

## MANDATORY teardown

**Local:**
```bash
lsof -ti:8081 -ti:8082 -ti:8090 | xargs kill 2>/dev/null || true
cd ../../../labs && docker compose down -v   # if you brought up any shared services
```

**AWS (if you used Part B):**
```bash
cd aws && terraform destroy -auto-approve    # if you used the terraform sketch
# then VERIFY nothing of yours remains:
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-instances --filters Name=tag:Project,Values=day10-cells \
  --query 'Reservations[].Instances[].{id:InstanceId,state:State.Name}'
```
Both must be empty / all `terminated`. Then do an AWS **cost check** in Billing.
Leaving an ALB running is the classic day-10 mistake — it bills per hour.
