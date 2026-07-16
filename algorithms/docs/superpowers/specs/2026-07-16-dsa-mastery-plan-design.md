# DSA Mastery Plan — Design

## Context

Prior progress lives in `300_bai_code_thieu_nhi` (a separate git repo): a 16-week, ~300-problem
Google-interview-focused curriculum (`google-coding-preps.md`), worked through a hint-first
coaching format (`day_N.go` + `day_N_pattern.md` per problem). Progress stalled at Week 7
(Graphs, day 44) — first commit 2025-11-20, last commit 2026-02-23, ~5 months idle since.

Diagnostic: the user can solve medium-difficulty problems untimed, but is shaky under a timer,
and reports having forgotten a meaningful amount of the underlying theory/pattern-recognition
skill during the stall — not just lost speed. This means the plan must both **reactivate**
dormant knowledge (hints allowed where genuinely forgotten) and **build genuine timed/cold
retrieval ability** (the actual gap that caused "solves it in practice, freezes in interview").

Goal: restart from the beginning (full refresh of Weeks 1-7) rather than resuming from Week 8,
using a redesigned method that fixes the retention/pressure gap, then continue through the
remaining curriculum. Motivation is general mastery + a discipline reset after the stall, not a
scheduled interview. Available time: 3-4 focused hours/day.

## Why the default grind wastes time (and what to do instead)

Most self-taught prep conflates *recognizing* a solution when shown it with *producing* it cold.
That gap is exactly what the diagnostic above surfaced. The specific mistakes to avoid, and the
mechanism that replaces each:

1. **Blocked practice illusion** — solving many problems of one labeled category in a row inflates
   confidence without testing recognition. Fix: interleave old and new topics, unlabeled, in
   weekly self-challenges.
2. **Passive hint-consumption** — reading the pattern before struggling trains recognition, not
   retrieval. Fix: struggle first (timer), hint only after genuinely stuck (or immediately during
   Refresh if the material is truly forgotten, not just slow — see Daily Protocol).
3. **One-and-done, no spaced revisit** — solved-once knowledge decays. Fix: a spaced-repetition
   deck (1/3/7/21-day intervals) that every solved problem enters.
4. **Volume-chasing over curation** — 300 problems solved once is weaker than ~150-180 problems
   pushed to true cold mastery. Fix: curate out near-duplicates for Weeks 8-16.
5. **No error log** — without recording *why* something failed, mistakes repeat silently. Fix: a
   single running error log (problem, date, failure type, fix insight, next review date).
6. **Skipping the clock** — untimed-by-default practice is the single biggest cause of "good in
   practice, bad under pressure." Fix: timer on by default once past pure reactivation.

## Daily protocol

Every practice day (3-4h) splits roughly 70/30.

**70% acquisition (new topics, or Refresh phase re-solves):**
- One easy warm-up (5-10 min, no time pressure) to activate context.
- Target problem: hard 20-25 min timer, no hints, no docs.
  - **Refresh-phase exception:** if a problem is genuinely blanked (not just slow), skip straight
    to a hint or the old pattern doc instead of grinding the full timer — the goal there is
    efficient reactivation, not rediscovery. It still gets logged in the error log and scheduled
    for a cold, hint-free retry in 48h to confirm it stuck.
  - **Weeks 8-16 (new material):** struggle-first applies in full — hint only after the timer
    expires and a second attempt also stalls.
- If solved cleanly: write a 5-line note max (pattern name, key insight, complexity, one gotcha).
  Add to the spaced-repetition deck at interval 1 (revisit in 3 days).
- If it needed a hint or solution: log it in the error log as a leech; schedule a cold re-attempt
  in 48h.

**30% spaced-repetition review:**
- Pull 2-4 problems due today from `spaced_review_deck.md`.
- Solve cold, timed, no notes. Comes back clean → push to the next interval. Shaky or fails →
  reset to interval 1, add an error-log entry.

**Weekly self-challenge day** (replaces that week's 7th acquisition slot):
- 3-4 problems pulled at random across *all* topics covered so far (old + new), unlabeled.
- Full pressure: hard timer per problem, talk out loud, no hints, no notes. This is a personal
  challenge/gauntlet, not an interviewer roleplay — self-graded against a simple rubric (pattern-ID
  speed, correctness, complexity, code cleanliness).
- Log the result as a trend line in `weekly_challenge_log.md` — the trend across weeks is the real
  signal of progress, not any single day's pass/fail.

## 60-day phase breakdown

**Phase 1 — Refresh Sprint (Days 1-10).** Re-solve Weeks 1-7 (~44 problems) cold-first,
hint-allowed-if-blanked. Seeds the spaced-repetition deck and produces an honest diagnostic of
which of the 7 pattern families are solid vs. rusty.
- Days 1-2: Hash Map / Stack / Two Pointers / Sliding Window (Week 1)
- Day 3: Hash Tables / Sets / Design basics (Week 2)
- Day 4: Linked Lists (Week 3)
- Day 5: Stacks / Queues / Monotonic structures (Week 4)
- Days 6-7: Trees + BST (Weeks 5-6)
- Days 8-9: Graphs (Week 7)
- Day 10: Catch-up + first weekly self-challenge (mixed, all 7 weeks) + error-log review

**Phase 2 — New Acquisition (Days 11-55, ~45 days).** 70/30 hybrid protocol, curated problem sets
(near-duplicates dropped from the original 300), one self-challenge day per week block.
- Days 11-16: Math & Optimization (Week 8)
- Days 17-23: DP Fundamentals (Week 9)
- Days 24-30: Advanced DP (Week 10)
- Days 31-37: System Design & Advanced Data Structures (Week 11)
- Days 38-44: Backtracking & Advanced Algorithms (Week 12)
- Days 45-51: Google's Most Frequent Problems (curated from Weeks 13-14)
- Days 52-55: System Design + Advanced tier (curated from Weeks 15-16)
- Each block's self-challenge day draws from everything covered to date, not just that block.

**Phase 3 — Finale Gauntlet (Days 56-60).** Daily mixed, randomized, timed challenges spanning all
16 topic families, unlabeled, full pressure. Close by reviewing the entire error log end-to-end —
anything still recurring gets one last targeted re-drill.

## Repo structure

Centralized into this repo under `algorithms/`, matching the existing per-topic convention used by
`kafka_practice` and `aws_bedrock_agent_gw` (`README.md` + `content/` + `labs-go/` +
`docs/superpowers/`).

**One-time migration from `300_bai_code_thieu_nhi`** (Day 0 setup, before Phase 1 starts):
- `week_1/` … `week_7/` Go solutions → `algorithms/labs-go/archive/week_1/` … `week_7/` (read-only
  historical reference; Phase 1 refresh solves live in new files and never overwrite these)
- Their `day_N_pattern.md` + topic docs (`sliding_window.md`, `two_pointer.md`, etc.) →
  `algorithms/content/archive/week_1/` … `week_7/`
- `google-coding-preps.md` → `algorithms/content/curriculum_reference.md` (source for curating
  Weeks 8-16)
- `weeks_compact.md` → `algorithms/content/progress_history.md` (reference only)
- Not copied: `claude-project-introduction.md` (superseded by this design), `main.go` (scratch
  runner), `.DS_Store`
- `300_bai_code_thieu_nhi` itself is left untouched — sorted out later on its own schedule

**New work going forward:**
- `algorithms/labs-go/refresh_sprint/day_1.go` … `day_10.go` (Phase 1), with its own fresh `go.mod`
- `algorithms/labs-go/week_8/` … `week_16/` (Phase 2, continuing the original week numbering)
- `algorithms/content/refresh_sprint/day_N_notes.md`, `algorithms/content/week_8/` … (5-line notes)
- Trackers: `algorithms/content/error_log.md`, `spaced_review_deck.md`, `weekly_challenge_log.md`,
  `curated_problem_list.md`
- This spec: `algorithms/docs/superpowers/specs/2026-07-16-dsa-mastery-plan-design.md`

## Out of scope

- Mock-interview roleplay (interviewer persona, live grading) — explicitly not wanted; the weekly
  self-challenge is a solo timed exercise, self-graded.
- Sorting out or deleting `300_bai_code_thieu_nhi` — deferred to the user.
- Picking the exact curated problem subset for Weeks 8-16 — happens during execution (curation
  against `curriculum_reference.md`), not fixed in this spec.
