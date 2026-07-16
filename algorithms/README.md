# DSA Mastery — 60 Days

A self-directed, aggressive Data Structures & Algorithms plan: full refresh of Weeks 1-7
(already covered once, in a prior repo, but never pressure-tested), then completion of the
remaining Google-focused curriculum — built around fixing one specific, diagnosed gap: solid
untimed problem-solving that falls apart under a timer or when the pattern isn't labeled.

This file is the entry point. It doesn't repeat what's already written elsewhere in more
detail — it tells you where to look and summarizes the guidelines that apply across all 60
days, so you don't have to re-derive them each morning.

## Where everything lives

| Path | What it is |
|---|---|
| `docs/superpowers/specs/2026-07-16-dsa-mastery-plan-design.md` | The design spec — diagnosis, strategy/mistakes list, daily protocol, full 60-day phase breakdown. Read this once, up front. |
| `content/why_this_works.md` | Side-by-side comparison against the old `300_bai_code_thieu_nhi` method — what changed and why, tied back to the actual diagnosis (good untimed recall, weak timed/cold recall, 5-month retention loss). |
| `content/refresh_sprint/day_1.md` … `day_10.md` | Phase 1 day index: each day's problems linked straight to the matching `content/archive/week_N/day_M_pattern.md` reference — use only if genuinely blanked, not as a pre-read. |
| `docs/superpowers/plans/2026-07-16-dsa-mastery-60-day-plan.md` | The day-by-day execution plan — what to solve each day, when to hint, when to review. This is what you follow each day. |
| `content/archive/week_1/` … `week_7/` | Historical reference from the first pass (pattern docs) — read-only, never overwritten during the Refresh Sprint. |
| `labs-go/archive/week_1/` … `week_7/` | Historical reference Go solutions from the first pass — read-only, same reason. |
| `content/curriculum_reference.md` | The original 300-problem, 16-week master list — source for curating Weeks 8-16. |
| `content/progress_history.md` | Prior progress summary (Weeks 1-6, carried over for context). |
| `content/curated_problem_list.md` | The trimmed Weeks 8-16 working set — filled in during Phase 1 wrap-up. |
| `content/week_8/_primer.md` … `week_12/_primer.md` | Short theory primers for each genuinely-new Phase 2 pattern (Math/Opt, DP Fundamentals, Advanced DP, Design & Tries, Backtracking) — read once at the start of that block's Day 1, before the timer starts. Weeks 13-16 reuse `content/archive/week_7/topology_sort_pattern.md` instead of a new primer. |
| `content/error_log.md` | The leech deck — every hint-needed/failed problem, why, and when to retry it cold. |
| `content/spaced_review_deck.md` | The spaced-repetition queue (1/3/7/21-day intervals) driving the daily 30% review block. |
| `content/weekly_challenge_log.md` | Trend log for the weekly mixed, unlabeled, timed self-challenge. |
| `labs-go/refresh_sprint/` | Phase 1 solves (Days 1-10) — new files, never overwriting the archive. |
| `labs-go/week_8/` … `week_12/`, `week_13_14/`, `week_15_16/` | Phase 2 solves (Days 11-55) — same folder names as `content/`, combined for the two blocks the curriculum groups together. |

**Start here:** `docs/superpowers/plans/2026-07-16-dsa-mastery-60-day-plan.md`, Day 1.

## Daily rhythm (every day, 3-4 hours)

Roughly 70/30 split:

1. **Acquisition (70%)** — one easy warm-up (5-10 min, no pressure), then the target problem
   under a hard 20-25 min timer, no hints, no docs.
   - **Refresh phase exception:** if a problem is genuinely blanked (not just slow), skip
     straight to a hint instead of grinding the timer — the goal is reactivation, not
     rediscovery. Still logged, still scheduled for a cold retry in 48h.
   - **Weeks 8-16:** struggle-first applies in full.
   - Clean solve -> 5-line note (pattern, insight, complexity, gotcha) -> enters
     `spaced_review_deck.md` at Interval 1. Needed a hint/solution -> logged in
     `error_log.md` as a leech, cold retry scheduled in 48h.
2. **Spaced review (30%)** — pull whatever's due from `spaced_review_deck.md`, solve cold,
   timed, no notes. Clean -> advance interval. Shaky/failed -> reset to Interval 1, log it.

**Weekly self-challenge day** replaces that week's 7th acquisition slot: 3-4 problems, random
across every topic covered so far (old + new), unlabeled, full timer, talk-aloud, no hints, no
notes. Self-graded (pattern-ID speed, correctness, complexity, cleanliness) and logged to
`weekly_challenge_log.md` — the trend across weeks is the real signal, not any single day.

## 60-day phase map

| Phase | Days | Focus |
|---|---|---|
| 1 — Refresh Sprint | 1-10 | Cold re-solve Weeks 1-7 (hint-allowed if genuinely blanked); seeds the spaced-review deck; honest diagnostic of what's actually solid. |
| 2 — New Acquisition | 11-55 | Weeks 8-16 curated curriculum, full struggle-first protocol, weekly self-challenge each block. |
| 3 — Finale Gauntlet | 56-60 | Daily mixed, randomized, timed challenges across all 16 topic families; full error-log review and final targeted re-drills. |

Full day-by-day breakdown is in the plan doc, not repeated here.

## Unconventional strategies this plan deliberately uses

| Strategy | Why |
|---|---|
| Interleaved, unlabeled weekly challenges | Blocked practice (all-one-category) inflates confidence without testing real recognition. |
| Struggle-first, hint-after | Reading the pattern before struggling trains recognition, not retrieval. |
| Spaced re-solve (1/3/7/21-day intervals) | One-and-done knowledge decays; deliberate spaced revisit is what cements it. |
| Curated ~150-180 problems over all 300 | Fewer problems pushed to true cold mastery beats many problems solved once. |
| A running error log (the "leech deck") | Without recording *why* something failed, the same mistake repeats silently. |
| Timer on by default past the reactivation stage | Untimed-by-default practice is the single biggest cause of "fine in practice, freezes under pressure." |

## Mistakes this plan is designed to block

| Mistake | Blocked by |
|---|---|
| "I know this" from untimed recognition alone | Every post-Refresh solve is timed by default. |
| Feeling done after Week 1-7 without re-testing | The full Refresh Sprint (Phase 1) before touching new material. |
| Forgetting *why* something failed | Mandatory `error_log.md` entry on every hint/fail. |
| Practicing only in labeled categories | Weekly unlabeled, mixed self-challenge. |
| Grinding toward a problem-count vanity number | Curation pass on Weeks 8-16 against `curriculum_reference.md`. |
| Letting a leech quietly resurface for weeks | Spaced-review deck resets shaky problems to Interval 1 immediately. |

Full "why it wastes time" detail for each is in the spec, not repeated here. For a direct,
side-by-side comparison against exactly how the old repo worked, see `content/why_this_works.md`.

## Where this came from

Prior progress (Weeks 1-7, ~44 days) lived in a separate repo, `300_bai_code_thieu_nhi`,
worked through a hint-first coaching format that never got pressure-tested. That repo is left
untouched — sort it out on your own schedule. The historical Go solutions and pattern docs
worth keeping were copied into `labs-go/archive/` and `content/archive/` here; the master
300-problem curriculum (`google-coding-preps.md`) was copied in as `curriculum_reference.md`.

## A note on scope decisions

Mock-interview roleplay (an interviewer persona grading you live) was deliberately left out —
the weekly self-challenge is a solo timed exercise, self-graded. Picking the exact curated
subset for Weeks 8-16 is deferred to execution time (against `curriculum_reference.md`), not
fixed in advance. Full rationale in the spec's "Out of scope" section.
