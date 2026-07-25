# Day 20 Lab — threat-model + cost-model a prior design

This is a design lab, not a code lab. You apply two worksheets to one of your
**earlier designs** (e.g. the Day 8/11 payment-notification system).

## Steps

1. **Pick a prior design** you already sketched. Have its C4 container diagram in view.
2. **STRIDE threat model** — open `stride-worksheet.md`. It has a filled example
   followed by a blank template. For each component, enumerate Spoofing,
   Tampering, Repudiation, Info-disclosure, DoS, Elevation threats + one
   mitigation each. Write your top mitigation as ADR material.
3. **Cost model** — open `cost-model.md` (filled example + blank template).
   Using your Day-2 capacity estimate, compute monthly cost per line item and
   **$ per 1,000 requests**. Identify the top-2 cost levers.
4. **Break-it (sensitivity):** 10× the traffic assumption in the cost model and
   see which line item dominates (usually egress or LLM tokens). Record the
   before/after in `results.md`.
5. **Record** your findings and the top mitigation + top cost lever in `results.md`.

No stack to tear down. If you spun anything up to check numbers, `docker compose down -v`.
