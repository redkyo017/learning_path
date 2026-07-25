### Day N — <topic>

**Teardown target:** <real system / practice to study>
**Design brief:** <the system or subsystem to design today>
**ADR topic:** <the key decision to defend>
**Lab:** <the one concept to build / measure / break>
**When NOT this:** <the alternative + the condition under which it wins>
**Builds on:** <prior day(s)>  **Sets up for:** <later day(s)>

---

**Beat 1 — Teardown warm-up (~20m).** Read the day's case study (see
`content/dayNN.md` and `reference/real-world-case-studies.md`). Extract: what did
they choose, and *why*? Log your takeaway.

**Beat 2 — Design core (~60–75m).** Run `reference/design-method.md` in order:
1. Requirements  2. Constraints  3. Top-3 NFRs  4. ≥2 options  5. Tradeoff table
6. Decision (+ one-sentence why)  7. How it breaks (self-red-team).
Write the design to `design/`, and one ADR to `adr/` using `reference/adr-template.md`.

**Beat 3 — Hands-on lab (~40–60m).** Build → measure → **break**. Put code/config
and a `results.md` in `lab/`. The break-it step is mandatory.

**Beat 4 — Journal (~10m).** Append to `../../journal.md`:
```
### Day N — <topic>
Key concept in my own words: …
When would I NOT use this: …
Break-it — what I broke and how I diagnosed it: …
Biggest surprise / open question: …
```

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design
- [ ] `diagrams/` — at least one C4 diagram (`.mmd`)
- [ ] `adr/NNNN-*.md` — at least one ADR
- [ ] `lab/results.md` — measurements + what broke + the fix
- [ ] `journal.md` entry appended
