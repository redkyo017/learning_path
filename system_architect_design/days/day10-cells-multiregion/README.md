### Day 10 — Cell-based architecture, blast radius & multi-region (AWS day)

**Teardown target:** AWS cell-based architecture + Shopify Pods + Slack's cellular migration.
**Design brief:** partition users into isolated cells; contain blast radius.
**ADR topic:** cell routing key + sizing; single-region multi-cell vs multi-region.
**Lab:** build 2 isolated cells + a thin router, kill one cell, prove containment.
**When NOT this:** a small service — the routing/ops overhead dwarfs the availability gain below a certain scale (run one well-run multi-AZ stack instead).
**Builds on:** Day 9 (breakers/bulkheads — cells are bulkheads at the stack level). **Sets up for:** Phase 3 services deployed into this topology; the capstone's region-loss red-team.

> Theory: `content/day10.md`. Lab: `lab/` (local runnable containment demo +
> optional AWS sketch). This is an **AWS day** but kept **partial/design-heavy** —
> the runnable proof of containment is local; the AWS path is an optional sketch.
> **Teardown is mandatory** (Beat 4) if you touch AWS.

---

**Beat 0 — AWS prep (~5m, only if doing the optional AWS path).**
```bash
aws --version                 # expect aws-cli/2.x
export AWS_PROFILE=sandbox
export AWS_REGION=ap-southeast-1
aws sts get-caller-identity   # confirm the sandbox account, not prod
```
If you skip the cloud path, you still do the full design + the local lab. Session
cost target if you do go to AWS: **$1–3** — and you MUST tear down.

**Beat 1 — Teardown warm-up (~20m).** Read `content/day10.md` and the Day 10
entries in `reference/real-world-case-studies.md`. Extract, in one line each:
what AWS/Shopify/Slack *isolate* with a cell, and what the *one shared component*
is in each. Log your takeaways.

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` in order on the
brief. Concretely:
1. **Requirements:** multi-tenant SaaS; pick a tenant count and per-tenant RPS
   (e.g. 2M tenants, 0.2 RPS each). Out of scope: cross-tenant queries.
2. **Constraints:** budget (per-cell fixed cost), one platform team, existing
   AWS + Go + Postgres stack.
3. **Top-3 NFRs:** availability, blast-radius/fault-isolation (reliability),
   operability. (Cost and simplicity are what you trade.)
4. **Options:** (a) single shared stack, (b) single-region multi-cell,
   (c) multi-region multi-cell. Sketch all three.
5. **Tradeoffs:** table them on the top-3 NFRs + cost + complexity (see the table
   in `content/day10.md`).
6. **Decision:** choose, one-sentence why over the runner-up.
7. **How it breaks (red-team):** the router becomes the shared fate; a tenant
   bigger than a cell; a global deploy; the control plane is itself a blast radius.
   Answer each.
Use `lab/cell-design-worksheet.md` to capture routing key, mapping mechanism, cell
sizing math, and the deploy/migration story. Write the filled design to `design/`.
Write **one ADR** to `adr/` — suggested **ADR 0010** (see `reference/adr-template.md`):
*"Route tenants to single-region cells by hashed tenant_id; defer multi-region."*
(ADR numbers are global across all days — pick the next free number if 0010 is taken.)

**Beat 3 — Hands-on lab (~55m).** `lab/README.md`. Build a **thin router + 2
isolated cells** locally (cell = an `echo` instance with its own identity), send
traffic across many tenants, then **kill cell-a** and prove cell-b's tenants are
**unaffected** (blast radius contained). Optionally reproduce it in AWS with the
ALB + 2 target-group sketch in `lab/aws/`. Record numbers in `lab/results.md`.
**Break-it is the core**: killing a cell and measuring the contained impact.

**Beat 4 — Journal + TEARDOWN (mandatory) (~10m).**
- Local: `docker compose down -v` (from `labs/`), and stop any `go run` processes.
- **AWS (if used):** run `lab/aws/teardown.sh` (or the manual commands in
  `lab/README.md`). Confirm nothing of yours remains:
  ```bash
  aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
  aws ec2 describe-instances --filters Name=tag:Project,Values=day10-cells \
    --query 'Reservations[].Instances[].State.Name'
  ```
  Both should return empty / all `terminated`. Do an AWS cost check.
- Append a `journal.md` entry (key concept, "when NOT cells", what you broke and
  how you diagnosed containment, biggest surprise).

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (+ `cell-design-worksheet.md`)
- [ ] `diagrams/` — at least one C4 diagram (`.mmd`): router + cells (C2)
- [ ] `adr/NNNN-*.md` — the routing-key / sizing / region ADR (suggested 0010)
- [ ] `lab/results.md` — before/after containment measurements
- [ ] AWS resources **torn down** and verified (if you used the cloud path)
- [ ] `journal.md` entry appended
