# Day 21 — Capstone: full architecture package + mock review

**Teardown target:** re-skim the 2–3 case studies most relevant to your chosen system.
**Design brief:** a substantial system of your choice — e.g. a multi-tenant,
event-driven, globally-distributed ride-hailing platform; a real-time collaborative
editor; or an LLM-powered support platform.
**ADR topic:** 3–5 ADRs for the highest-stakes decisions.
**Lab:** assemble and defend the complete package in a mock architecture review.
**When NOT this:** n/a — this is the integration exercise.
**Builds on:** everything (Days 1–20). **Sets up for:** ongoing practice via `BACKLOG.md`.

Theory: read **`content/day21.md`** first (depth-over-breadth, the integration
checklist, the five red-team dimensions, the mock-review ritual, self-grading).
**System menu:** **Problem 4** in `reference/interview-problems.md`. Worksheet
templates you fill: **`lab/`** (`requirements.md`, `capacity-estimate.md`,
`red-team.md`, `mock-review.md`).

This is a longer day (~3 hrs). It runs the whole method once, end to end, on a system
you haven't designed before.

---

**Step 1 — Choose the system + write requirements (~10m).**
Pick one from **Problem 4** in `reference/interview-problems.md` (global ride-hailing;
real-time collaborative editor; LLM-powered support platform). Fill
**`lab/requirements.md`**: functional use cases (as verbs), scale/shape numbers, and
what's **explicitly out of scope**. Copy the finished version into
`design/requirements.md`.

**Step 2 — Full design pass, the method end to end (~75m).** Use the integration
checklist in `content/day21.md` to decide, per concern, *deep or one line*:
- **Capacity estimate** (Day 2) → fill **`lab/capacity-estimate.md`**; every number
  ends in "→ therefore X".
- **C4 diagrams** C1–C3 (`reference/c4-guide.md`) → `diagrams/*.mmd`.
- **Data model + storage** (Days 3–5) with the **consistency** decisions (Day 4).
- **Resilience:** timeouts / idempotency / breakers / cells (Days 8–10).
- **Communication + events + a saga where justified** (Days 13–16).
- **Rollout + observability** (Days 11, 17).
- **Security + cost model** (Day 20).
- **AI component** if relevant (Days 18–19).
- **3–5 ADRs** for the biggest decisions → `adr/NNNN-*.md` (`reference/adr-template.md`).
  **Go deep on the 2–3 risk-carrying subsystems; sketch the rest.**

**Step 3 — Self-red-team + tradeoff table (~45m).** Fill **`lab/red-team.md`**: the
"how it breaks" section across all five dimensions — 10× load, a region/cell loss, a
dependency outage, a bad deploy, a hot partition (plus data loss / duplicate
delivery). Build a **tradeoff table for your single most contested decision**. Copy
into `design/red-team.md`.

**Step 4 — Mock architecture review (~30m).** Present the package to yourself as a
skeptical senior reviewer. For **each ADR**, answer *"why not the alternative?"* in
one sentence. Log every question you **couldn't** answer confidently as a new
`BACKLOG.md` entry. Write the review summary in **`lab/mock-review.md`** (copy to
`days/day21-capstone/mock-review.md` if you keep it at the day root too).

**Step 5 — (optional, timed) Final interview rep (~45m).** One hard open-ended problem
you haven't seen, 45 minutes, method in order. Grade with the rubric in
`reference/interview-problems.md`.

**Step 6 — Journal, the meta-entry (~10m).** Append to `../../journal.md`:
```
### Day 21 — capstone
System I designed: …
The 2–3 subsystems I went deep on, and why: …
Where it breaks (the scariest of the five dimensions): …
An ADR alternative I could defend in one sentence: …
What changed in how I reason about systems over 21 days: …
Top-3 remaining gaps (→ BACKLOG.md): …
```

---

**Outputs checklist:**
- [ ] `design/requirements.md` — functional + scale + out-of-scope
- [ ] `lab/capacity-estimate.md` — numbers that drove decisions
- [ ] `diagrams/` — C1–C3 C4 diagrams (`.mmd`)
- [ ] `adr/NNNN-*.md` — 3–5 ADRs, each with a rejected alternative
       (suggested numbers: the next free block in your global sequence, e.g. `0021`–`0025`)
- [ ] `design/red-team.md` — five failure dimensions + a tradeoff table
- [ ] `mock-review.md` — the review summary; unanswered questions logged to `BACKLOG.md`
- [ ] `journal.md` meta-entry appended
- [ ] `BACKLOG.md` updated with your top-3 remaining gaps
