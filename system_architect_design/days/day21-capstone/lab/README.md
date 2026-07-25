# Day 21 Lab — the capstone package

The capstone *is* the lab. You produce a complete, defended architecture for a
substantial system of your choice, integrating every prior day. These four
worksheets are your deliverable — fill them in order. Options for the system are
in `reference/interview-problems.md` (Problem 4).

## Flow (fill the worksheets in this order)

1. **`requirements.md`** — functional requirements + scale/shape. State what's out
   of scope. (Day 1 method, step 1–2.)
2. **`capacity-estimate.md`** — back-of-envelope numbers that drive decisions.
   (Day 2 skills; see `reference/estimation-cheatsheet.md`.)
3. **The design itself** goes in `../design/` + C4 diagrams in `../diagrams/` +
   3–5 ADRs in `../adr/`. Walk the full stack: storage & consistency (Days 3–5),
   caching & load-leveling (Days 6–7), resilience & cells (Days 8–10),
   comms/events/saga (Days 13–16), rollout & observability (Days 11, 17),
   security & cost (Day 20), and an AI component if relevant (Days 18–19).
4. **`red-team.md`** — the "how it breaks" pass: 10× load, region/cell loss,
   dependency outage, bad deploy, hot partition. Plus a tradeoff table for your
   single most contested decision.
5. **`mock-review.md`** — present the package to yourself as a skeptical senior
   reviewer. For each ADR answer "why not the alternative?" Log every question you
   *couldn't* answer confidently — those become new `BACKLOG.md` entries.

## Optional final rep

A fresh 45-minute timed problem you haven't seen, method in order. Grade with the
rubric in `reference/interview-problems.md`.

## Done when

You can defend every major decision, your red-team covers all five failure
scenarios, and you've captured your remaining gaps in `BACKLOG.md`. That list is
your post-21 study plan.
