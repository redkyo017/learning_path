### Day 13 — Service communication: sync (gRPC/REST) vs async; API design & versioning

**Teardown target:** gRPC at scale (Google/CNCF) + public API versioning strategies (Stripe's date-based versions).
**Design brief:** choose comms for the Orders ↔ Inventory ↔ Payments edges.
**ADR topic:** gRPC vs REST per edge; the schema versioning/compatibility policy.
**Lab:** two Go services over gRPC; evolve the proto additively (prove back-compat); break it by renumbering a field.
**When NOT this:** gRPC across a public/browser edge (use REST/JSON there); a synchronous call on a critical path that should be async (it couples availability).
**Builds on:** Day 12 boundaries. **Sets up for:** Day 14 async events.

Theory: `content/day13.md`. Method: `reference/design-method.md`. ADR format: `reference/adr-template.md`.

**Step 0 — install `buf` and the protoc Go plugins (once):**
```bash
brew install bufbuild/buf/buf          # or: go install github.com/bufbuild/buf/cmd/buf@latest
buf --version                          # expect 1.3x+
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
# ensure $(go env GOPATH)/bin is on your PATH so buf can find the plugins
```

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day13.md` §Real-world +
`reference/real-world-case-studies.md` Day 13. Extract, in one line each: *why* is
Google's cross-service compatibility a property of field **numbers** rather than
gRPC-the-transport? *Why* did Stripe choose to carry the versioning cost
server-side? Log both takeaways in the case-studies file.

**Beat 2 — Design core (~50m).** Run `reference/design-method.md` in order on the
Orders ↔ Inventory ↔ Payments edges:
1. **Requirements** — Orders must confirm stock before accepting; must authorize
   payment; must announce that an order was placed.
2. **Constraints** — internal services (you own both ends) except Payments may be
   an external provider; independent deploy cadence.
3. **Top-3 NFRs** — pick from {latency, availability, evolvability}; justify.
4. **Options** — per edge: sync gRPC vs sync REST vs async event. Generate ≥2.
5. **Tradeoff table** — edges × {answer-needed-inline?, coupling, latency, browser-reachable?}.
6. **Decision** — assign each edge a protocol + sync/async, one-sentence why each.
7. **How it breaks** — a breaking schema change shipped without a version bump;
   a sync dependency (Inventory) slow → Orders latency; Payments provider down.
Write it to `design/` (see `design/README.md`). Write **ADR `0013`** (suggested
number — confirm the next free global number) on the per-edge protocol choice and
the compatibility policy: *additive-only, reserved numbers, no renumbering, `/vN`
package bump for true breaks.* Draw the C2 in `diagrams/` (`content/day13.md` has a
starter flowchart).

**Beat 3 — Hands-on lab (~60m).** `lab/README.md` — build two Go services talking
gRPC, evolve the proto additively and confirm nothing breaks, then **break it** by
renumbering a field and watch the value silently zero out. Record in `lab/results.md`.

**Beat 4 — Journal (~10m).** Append to `../../journal.md` using the template in
`templates/day-template.md` (key concept, when-NOT, what you broke + how you
diagnosed it, biggest surprise).

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (per-edge sync/async + protocol)
- [ ] `diagrams/` — at least one C2 `.mmd` (the three edges)
- [ ] `adr/0013-*.md` — protocol-per-edge + compatibility policy ADR
- [ ] `lab/results.md` — additive change (no break) vs renumber (silent break) + the fix
- [ ] `journal.md` entry appended

**Suggested ADR number:** `0013` (confirm the next free global number across all days).
