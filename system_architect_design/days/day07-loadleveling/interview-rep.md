# Day 7 — Phase 1 interview rep (45 min, timed)

**Problem:** *Design a URL shortener with a per-client rate limiter.*
Full statement, graduated hints, and a solution sketch are in
**`reference/interview-problems.md` → Problem 1**.

## How to run this rep

1. **Set a 45-minute timer.** No peeking at the solution until it rings (or you're
   genuinely stuck — then take *one* hint at a time, not the solution).
2. Work on a whiteboard or in `design/interview-rep-work.md`. Run
   `reference/design-method.md` **in order** — the discipline is what's being
   graded, not the answer.
3. Produce, at minimum:
   - **Requirements + scale numbers** (creates/day, read:write ratio, peak QPS).
   - **Top-3 NFRs** with targets (e.g. redirect p99 < 50ms, availability 99.95%).
   - **≥2 options** for ID generation (counter/base62 vs hash vs key-gen service)
     compared in a table.
   - A **capacity estimate** that drives a decision (storage over 5y → shard? cache
     working set? rate-limiter store sizing?).
   - A **C2 container diagram** (Mermaid — see `reference/c4-guide.md`).
   - The **rate limiter** design (token bucket per API key, where state lives,
     atomicity, 429 + Retry-After) — this is the Day 7 hook.
   - A **red-team pass** (hot code, counter service down, cache stampede, 10×).

## Self-grade (/10) — from `reference/interview-problems.md`

- Requirements + scale numbers stated (2)
- Named top-3 NFRs and designed to them (2)
- ≥2 options compared, not one (1)
- A capacity estimate that drove a decision (1)
- Data model + storage choice justified (1)
- Failure modes / red-team pass (2)
- One clear "why this over the alternative" per key decision (1)

**Then** open Problem 1's `<details>` solution sketch and compare. Grade yourself
on *whether you ran the method and defended tradeoffs*, not on matching word for
word. Log anything you couldn't answer confidently into `../../BACKLOG.md`.

Save your attempt + score in `design/interview-rep-work.md`.
