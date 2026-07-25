# Day 1 — How architects reason (method, NFRs, C4, ADRs)

**Teardown target:** a real system *you already operate at work* (plus C4 / arc42 /
AWS Well-Architected as the practice references).
**Design brief:** reverse-engineer that known system with the design method, as if
designing it fresh.
**ADR topic:** a real past decision in it — re-justify it with the method.
**Lab:** produce a C4 (L1 context + L2 containers) diagram + your first ADR (0001).
**When NOT this:** when a whiteboard sketch suffices (throwaway spikes / two-way-door
details) — C4/ADR overhead is for decisions others must understand or that are
expensive to reverse.
**Builds on:** nothing (this is Phase 0). **Sets up for:** the method + artifacts you
use *every* later day.

Theory: `content/day01.md`. Method: `reference/design-method.md`. NFRs:
`reference/nfr-checklist.md`. C4: `reference/c4-guide.md`. ADR: `reference/adr-template.md`.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day01.md` (core problem → the
method → NFRs → C4 → ADRs → "decision vs detail"). Skim the practice references above.
Extract the one question that reframes today: **what makes something an architecture
*decision* (one-way door) versus a *detail* (two-way door)?** Log a one-line takeaway
for the two Day-1 case-study entries (C4 model; AWS Well-Architected) in
`reference/real-world-case-studies.md`.

**Beat 2 — Design core (~60–75m).** Pick a real system you've built or operate. Run
`reference/design-method.md` in order, *as if designing it fresh* → write to
`design/reverse-engineer.md`:
1. **Requirements** — functional (verbs) + scale/shape (users, RPS, data size, read:write).
2. **Constraints** — budget, team, latency SLA, compliance, existing stack.
3. **Top-3 NFRs** — the three "-ilities" it lives or dies by, each with a *number*
   (e.g. "availability 99.95%", "p99 < 100ms"). Name the one you deliberately don't
   optimize.
4. **Options** — the ≥2 genuinely different designs that existed at decision time.
5. **Tradeoff table** — options × top-3 NFRs (+ cost + complexity), concrete numbers.
6. **Decision** — the one you shipped, with the one-sentence "why over the runner-up."
7. **How it breaks** — self-red-team: list **5** failure modes (load spike, dependency
   down, partition, bad deploy, hot key/data loss) and what actually happens for each.

**Beat 3 — Hands-on lab (~30m).** See `lab/README.md`. Draw C1 + C2 in Mermaid
(starter skeletons in `lab/`) → `diagrams/context.mmd`, `diagrams/containers.mmd`.
Write **ADR 0001** for one real decision in that system → `adr/0001-<title>.md` using
`reference/adr-template.md`, with a populated "Alternatives considered" section.
Verify both diagrams render.

**Beat 4 — Journal (~10m).** Append to `../../journal.md`:
```
### Day 1 — How architects reason
Key concept in my own words: …
When would I NOT use C4/ADR: …  (and what flips it back on)
Break-it — the failure mode I found reverse-engineering my own system: …
Biggest surprise / open question: …
```

---

**Suggested ADR number:** `0001` (numbers are global and monotonic across all days;
you write the ADR — the stub in `adr/` names what's expected).

**Outputs checklist:**
- [ ] `design/reverse-engineer.md` — the filled 7-step method + 5 failure modes
- [ ] `diagrams/context.mmd` (C1) and `diagrams/containers.mmd` (C2), both rendering
- [ ] `adr/0001-*.md` — one ADR with a real "Alternatives considered" section
- [ ] `lab/results.md` — the "decision vs detail" list + render check + reflections
- [ ] `../../journal.md` entry appended
- [ ] case-study takeaways logged in `reference/real-world-case-studies.md`
