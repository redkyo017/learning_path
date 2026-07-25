# Day 20 — Cross-cutting dimensions: security, cost/FinOps, platform thinking

**Teardown target:** STRIDE threat modeling + AWS Well-Architected security & cost pillars.
**Design brief:** threat-model AND cost-model one of your earlier designs.
**ADR topic:** the top security mitigation + the biggest cost lever.
**Lab:** produce a STRIDE threat table + a monthly cost model for a prior design.
**When NOT this:** gold-plating security/cost on a prototype — right-size the rigor
to the data sensitivity and the scale.
**Builds on:** all prior designs (Day 2 estimation feeds the cost model).
**Sets up for:** Day 21 capstone integrates these axes.

Theory: read **`content/day20.md`** first. Lab worksheets: **`lab/`**. This is a
design-heavy day — the "lab" is worksheets, not code.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day20.md` and the Day 20 entry in
`reference/real-world-case-studies.md`. Study STRIDE + the AWS Well-Architected
Security and Cost Optimization pillars, and the Capital One breach as a worked STRIDE
example (SSRF → over-privileged IAM role → S3 read). Log the takeaway: *which single
control would have shrunk the blast radius most?* (least privilege).

**Beat 2 — Design core: threat model (~60m).** Pick a prior design — the
payment/notification system (Problem 2) is the richest. Run
`reference/design-method.md` framing, then build a **STRIDE table**: per component and
per trust-boundary crossing, enumerate a Spoofing / Tampering / Repudiation /
Info-disclosure / DoS / Elevation threat **and a mitigation each**. Fill
`lab/stride-worksheet.md` (a filled example is included — replace it with YOUR
design). Write **one ADR** on the **top security mitigation** (the one that most
reduces blast radius). Red-team: the mitigation you're most likely to get wrong (hint:
over-broad IAM, or trusting the network perimeter).

**Beat 3 — Lab: cost model + unit economics (~45m).** Using your **Day-2 capacity
estimate**, build a markdown cost model in `lab/cost-model.md` (filled example
included): compute, storage, egress, managed/per-request services, LLM tokens (if
applicable) → **monthly total** and **$ per 1,000 requests**. Identify the **top-2
cost levers**. **Break-it:** 10× the traffic assumption and watch which line item
dominates (usually egress or LLM tokens) — that's your real lever. Record findings in
`lab/results.md`. (No docker to tear down; if you spun anything up, tear it down.)

Write the ADR to `adr/` using `reference/adr-template.md`.
**Suggested ADR number:** the next free number in your global sequence (≈ `0020` if
~one per day; ADR numbers are global across all days). This ADR can carry *two*
decisions or you can split it: the top security mitigation, and the biggest cost lever.

**Beat 4 — Journal (~10m).** Append to `../../journal.md`:
```
### Day 20 — security, cost/FinOps, platform thinking
Key concept in my own words: …
When would I NOT do full STRIDE / buy reserved capacity: …
Break-it — what dominated the bill at 10×, and why not compute: …
Top security mitigation + biggest cost lever I chose: …
Biggest surprise / open question: …
```

---

**Outputs checklist:**
- [ ] `design/` — the STRIDE framing + which prior design you chose and why
- [ ] `diagrams/` — a data-flow diagram with **trust boundaries** marked (`.mmd`)
- [ ] `adr/NNNN-*.md` — top security mitigation + biggest cost lever
- [ ] `lab/stride-worksheet.md` — filled STRIDE table for your design
- [ ] `lab/cost-model.md` — monthly model + $/1K requests + 10× sensitivity
- [ ] `lab/results.md` — top mitigation, dominant cost lever, what 10× revealed
- [ ] `journal.md` entry appended
