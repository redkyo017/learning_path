# Why This Plan Is Different From `300_bai_code_thieu_nhi`

You asked for this comparison explicitly, so here it is in full — not as a verdict on the old
repo (it got you real pattern recognition across 7 topic families), but as an explicit account
of *which specific failure modes* this plan was redesigned to close, and why.

## Start from the actual diagnosis, not a vague "this is better"

Two concrete facts triggered this redesign, not a general feeling that grinding harder is
good:

1. **The old repo stalled for ~5 months** (last commit 2026-02-23, picked back up 2026-07-16)
   after 44 days of real work across 7 pattern families.
2. **When you came back, you reported two things, not one:** you could still solve mediums
   *untimed*, but were "shaky under time pressure," AND you'd genuinely forgotten enough theory
   that some problems needed a hint just to get started again — not just a speed problem, a
   retention problem.

Both facts point at the same root cause: **the old method built recognition, not durable,
pressure-tested retrieval.** Recognizing a pattern when you have unlimited time and no stakes
is a much weaker skill than producing it cold, under a clock, when you don't know which
category it belongs to — which is exactly what an interview (or 5 months later) demands.
Every change below traces back to closing that specific gap, not to some generic "more
efficient" story.

## Side-by-side

| Old method (`300_bai_code_thieu_nhi`) | This plan (`algorithms/`) | Why the change |
|---|---|---|
| Hint-first coaching, live, every session | Hint ladders + pattern content pre-written once per problem, reusable without a coach in the loop | You can now run most days solo and only need a human for genuinely hard sticking points — the old model made every day depend on a live coaching session. |
| Strict linear progression, one topic block at a time (blocked practice) | Weekly self-challenge: unlabeled, mixed problems across *everything* covered so far | Blocked practice inflates confidence because you already know the category walking in. That's precisely why "I solved this in Week 3" didn't survive to "I can solve this cold in Week 30" — you were never tested without the label. |
| Untimed by default | Hard 20-25 min timer on every problem past the reactivation stage | This is the single most direct fix for "shaky under time pressure" — the old method never once put a clock on you, so there was no way to discover the pressure gap before it mattered. |
| Solved once, never revisited (except as prose summaries) | Explicit spaced-repetition deck (1/3/7/21-day intervals); every solved problem gets pulled back cold | This is *why* so much was forgotten during the 5-month gap — nothing in the old system ever forced a return visit. Spaced retrieval is what converts "solved once" into "actually retained." |
| No error tracking — mistakes were invisible after the fact | A running `error_log.md`: every hint/fail, why, and a scheduled cold retry | Without a record of *why* something failed, the same gap can resurface silently for weeks. The log makes forgetting visible and actionable instead of just re-discovered by accident. |
| Essay-length `day_N_pattern.md` write-ups after every solve | 5-line note after solving (pattern/insight/complexity/gotcha); the deeper hint/pattern reference is written once, upfront, per problem | Writing a full essay after every problem is real time cost that doesn't buy proportional retention benefit. Separating "quick personal note" from "reusable reference material" gets you both speed and depth. |
| Resume progress picked up wherever the day-count left off (Week 8) | Full Refresh Sprint (Phase 1) before touching new material | "44 days completed" was being used as a proxy for "44 days of material retained" — after a 5-month gap, that proxy had clearly broken. Phase 1 replaces the assumption with an actual, honest diagnostic. |
| Chase the full 300-problem list as the finish line | Curated ~150-180 problems (drop near-duplicates), pushed to true cold mastery | A problem solved once and never revisited is a weaker unit of progress than a smaller set solved, then re-solved cold multiple times. Volume was the wrong success metric. |
| "Done" = reached the end of the checklist | "Done" = the error log is empty (or every remaining entry is genuinely understood) | A checklist can be completed by problems that were never truly retained (see: the 5-month gap). An error log that's actually empty is a claim about retention, not about coverage. |

## The one-sentence version

The old method optimized for **problems seen**; this one optimizes for **problems you can
still produce, cold, under pressure, without knowing the category** — because that's the
actual thing that decayed over 5 months and the actual thing an interview tests.

## What was kept, deliberately

Not everything changed. The hint-escalation *style* (conceptual → technique → structure →
implementation) carries over directly from the old coaching format — it worked, so this plan
just made it self-serve instead of requiring a live session every time. The Go-first
implementation choice, the LeetCode-link-per-problem habit, and the per-topic pattern-doc idea
are also kept, not reinvented — see `docs/superpowers/specs/2026-07-16-dsa-mastery-plan-design.md`
for the full rationale behind every design decision, including what was deliberately left out
of scope.
