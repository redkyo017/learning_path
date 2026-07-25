# ADR Template

Architecture Decision Records capture **why** a decision was made, so future-you
(and your team) don't relitigate it or reverse it blindly. One decision per ADR.
Number them globally and monotonically: `0001`, `0002`, … across all days.

Filename: `days/dayNN-*/adr/NNNN-short-title.md`

---

```markdown
# ADR NNNN: <short imperative title, e.g. "Read from replicas for redirects">

- **Date:** YYYY-MM-DD
- **Status:** proposed | accepted | superseded by ADR-XXXX | deprecated
- **Deciders:** <you / the team>

## Context

What forces are at play? The functional requirement, the constraints, and —
critically — the **top-3 NFRs** this decision serves. State the problem
neutrally, before any solution. Include the numbers from your estimate if
relevant.

## Decision

What we chose, stated in one clear sentence, then the specifics. Use active
voice: "We will …".

## Alternatives considered

The other options from step 4 of the method. For each: a one-line description
and **why it lost** against the top-3 NFRs. An ADR with no rejected alternatives
is a red flag — it means you evaluated a single option.

- **Option B — <name>:** … Rejected because …
- **Option C — <name>:** … Rejected because …

## Consequences

- **Positive:** what gets better.
- **Negative:** what gets worse or riskier (there is always a cost).
- **What we now live with:** the new constraint this decision imposes on future
  work (e.g. "reads may be stale up to the replication lag").

## How it breaks (optional but encouraged)

The failure mode this decision introduces or fails to address, and the trigger
that would make us revisit it.
```

---

## What makes an ADR good

1. It records a **decision that was expensive to make or reverse** — not a detail.
2. The "Alternatives considered" section is real, not decoration.
3. Someone who wasn't in the room can understand *why* from it alone.
4. It's immutable: to change a decision, write a new ADR that supersedes it,
   and set the old one's status to `superseded by ADR-XXXX`.

## The one-sentence test

If you can't finish this sentence, you're not ready to write the ADR:
> "We chose X over Y because, for our top NFR of ___, X gives us ___ while Y
> would have cost us ___."
