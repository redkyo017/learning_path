# Content Feasibility Review — Linear Algebra 30-Day Plan

**Date:** 2026-08-04
**Scope:** All 30 files in `content/day01.md`–`day30.md`, judged against the 2026-07-08 spec.
Code files and `solutions_expanded/` excluded by request.
**Review criterion:** Is each day genuinely masterable by this learner (solid HS algebra, no
formal LA course, 3B1B/Khan intuition, weak problem fluency, limited proof experience) in a
strict 4-hour block — in service of "master linear algebra as fast as humanly possible, using
top-1% strategies, avoiding the mistakes that waste 80% of beginners"?
**Method:** Five parallel deep-read reviews (days 1–7, 8–13, 14–18, 19–24, 25–30), each
applying a fixed rubric (time feasibility, mastery density, strategy fidelity, self-check
support, correctness, prerequisite chaining), plus a cross-cutting pass over the arc.

---

## Executive verdict

**The learning design is genuinely strong — the schedule is not.** Strategy fidelity is the
best part of this plan: closed-book gates before every solution, exemplary interleaved review
days (13 and 18 especially), gated code labs, trap exercises, and "Unconventional edge"
anti-recipe sections are consistently well executed. Mathematical correctness is also high:
reviewers recomputed the bulk of the ~280 exercise solutions by hand and found only a handful
of real defects (listed below).

**But as built, this is a ~135–145 hour plan labeled as 120 hours.** The 60-minute theory slot
assumes *reading* proofs, while the plan's own protocol demands *hand-writing every proof
before checking* — on proof-heavy days that takes a novice 75–145 minutes, not 60. Nine days
realistically exceed 4.5h and four exceed 5h, while days 25–29 are underloaded (2.5–3.5h). The
load curve is inverted: the hardest days have zero slack and the easiest days hoard it.

Two content defects independently threaten the plan's stated success criteria: **Day 30's
final exam** (an MIT 18.06 practice final) tests topics the plan never teaches, and **Day 23's
central PCA theorem** is proved via Lagrange multipliers — multivariable calculus this learner
does not have — while the calculus-free proof is demoted to a parenthetical.

All of this is fixable with targeted edits; no restructuring of the 30-day sequence is needed.

---

## Per-day verdicts

Estimated times are realistic totals for THIS learner honoring the write-proofs-first and
attempt-before-solutions protocols. Budget = 240 min.

| Day | Topic | Verdict | Est. time | Dominant issue |
|---|---|---|---|---|
| 1 | Vector spaces, span | TIGHT | ~4.2–4.5h | Ex 9 hard for a proof novice; no hints |
| 2 | Independence, basis, dimension | **OVERLOADED** | ~5–5.5h | Steinitz exchange write-out; Ex 6 is a theorem-level proof; ~1.5–2 days of material |
| 3 | Linear transformations | TIGHT | ~4.5–4.8h | Thm 3.2 index gymnastics; matrix multiplication used before ever defined |
| 4 | Invertibility, rank-nullity | TIGHT→OVER | ~4.7–5.2h | Rank-nullity write-out; Ex 6 requires calculus |
| 5 | Gaussian elimination | TIGHT→OVER | ~4.7–5h | 110–120 min exercise load; heaviest code lab of week |
| 6 | Four fundamental subspaces | TIGHT | ~4.3h | Best-calibrated content day of week 1; pivot-columns text error |
| 7 | Review 1–6 | TIGHT | ~4.25h+ | Own schedule sums to 255 min; 150-min set is really ~200 min |
| 8 | Determinants | **OVERLOADED** | ~5.5h | 8 proofs to write in a 60-min slot (~125–145 min realistic) |
| 9 | Inverse, LU | TIGHT→OVER | ~5h | LU is a second half-day; duplicates Day 8 material |
| 10 | Eigenvalues | TIGHT | ~4.7h | 120-min exercise load; complex 3×3 (Ex 6) with no hint |
| 11 | Diagonalization | **OVERLOADED** | ~5.4h | Full three-way equivalence with both hard lemmas; ~1.5–2 days of material |
| 12 | Diagonalization applications | FEASIBLE | ~3.8–4h | None — this is the calibration model for content days |
| 13 | Review 8–12 | TIGHT | ~4.3–4.5h | Slightly over; acceptable for a timed day |
| 14 | Inner products, Cauchy-Schwarz | TIGHT | ~4.25h | C-S discriminant proof not inventable; draft artifact in worked example |
| 15 | Complements, Gram-Schmidt | TIGHT→OVER | ~4.75–5h | Two long proofs incl. 3-part induction; Thm 15.1 cites Thm 15.2 "below" — breaks proof-first protocol |
| 16 | Projections, least squares | TIGHT | ~4.3h | Central theorem rests on C(A)⊥=N(Aᵀ), proven nowhere (misattributed to Day 15) |
| 17 | Orthogonal matrices, QR | TIGHT | ~4.25h | Ex 5 pinch point; minor wording issues |
| 18 | Review 14–17 | TIGHT | ~4.25h | Own schedule sums to 255 min; P6 solution uses untaught cross product |
| 19 | Spectral theorem | TIGHT→OVER | ~4.8–5.3h | Hardest induction proof of plan + 10 exercises |
| 20 | Quadratic forms, definiteness | FEASIBLE | ~4h | "Mutually exclusive" definiteness claim is false as stated |
| 21 | SVD existence | **OVERLOADED** | ~5–5.5h | Worst day of plan: 8-step existence proof + 10 exercises (5–6 proofs) + two new norms defined inside exercises |
| 22 | Eckart–Young | TIGHT | ~4–4.5h | Stage-1 proof uses dim(U+V) formula never proved in days 1–21 (verified) |
| 23 | SVD → PCA | TIGHT | ~4.5–5h | Central proof needs untaught Lagrange multipliers; Ex 8 spoils Ex 2's answer |
| 24 | Review 19–23 | TIGHT | ~4.25h | Two real errors: P9 violates Def 21.1's σ-ordering; P13 mis-cites Day 26 for a fact proved Day 23 |
| 25 | Change of basis | FEASIBLE (under) | ~3–3.5h | Underloaded; lab is a 10-min fill-in |
| 26 | Trace, det, Cholesky | FEASIBLE (under) | ~2.5–3h | Lightest day; only 5 exercises (~35–45 min vs 90); garbled Cholesky sketch |
| 27 | Cumulative marathon | TIGHT | ~4.5–4.75h | Schedule sums to ~285 min; no SVD computation problem despite "Days 1–26" title; no grading scheme |
| 28 | Capstone: PCA | FEASIBLE (under) | ~2.5h | Learner writes zero code — runs and annotates a provided script |
| 29 | Capstone: SVD + mental map | FEASIBLE | ~3.25h | Mental map (main deliverable) has no model answer — unverifiable offline |
| 30 | Final exam + gap analysis | TIGHT | ~4.75h | Exam source tests untaught topics (see P0-2) |

**Tally:** 4 overloaded, 5 borderline-overloaded, 14 tight, 7 feasible (5 of those underloaded).
Realistic total ≈ **135–145 h** vs the 120 h budget — i.e., a 33–35-day plan at 4 h/day, or
30 days at ~4.5 h/day.

---

## Findings by severity

### P0 — Breaks the plan's purpose or schedule

1. **Systematic theory-hour overrun (9 days).** The write-every-proof-first protocol costs
   75–145 min on proof-heavy days against a 60-min slot. Worst: Day 8 (8 proofs, ~125–145 min),
   Day 11 (~115 min), Day 21 (8-step SVD existence proof), Day 2 (Steinitz), Day 19 (spectral
   induction). A learner will either blow the schedule or silently downgrade to "read the
   proof" — the exact passive-learning failure the plan exists to block.
   *Fix direction:* mark 2–3 proofs per heavy day as "read-only today, re-derive on the next
   review day" (Steinitz, Thm 8.1, Lemma 11.1, Thm 19.3, Thm 21.1 are the candidates), and/or
   rebalance into the underloaded days 25–26.

2. **Day 30's final exam cannot measure success.** The primary exam is an MIT 18.06 practice
   final, which routinely includes Markov matrices, differential equations/e^At, Fourier/complex
   matrices, Jordan form — none taught here. The learner will "fail" untaught questions,
   corrupting the trace-each-miss-to-its-day gap analysis that seeds the ML/QC follow-on. The
   fallback (retake Day 27's set, whose solutions the learner hand-rewrote 3 days earlier) has
   no validity as a retrieval test. Also: the ML/QC gap analysis hands the learner the full
   concept-to-day mapping to copy rather than testing it closed-book first.
   *Fix direction:* purpose-built final drawn from the plan's own scope (or a curated 18.06
   subset restricted to covered topics), with a grading rubric.

3. **Day 23 proves its central theorem with math the learner doesn't have.** Theorem 23.3
   (variance maximization → top eigenvector) leads with gradients, Lagrange multipliers, and
   the Extreme Value Theorem; the clean linear-algebra-only proof (eigenbasis expansion,
   wᵀCw = Σλᵢcᵢ² ≤ λ₁) is a parenthetical. Corollary 23.3.1 and Exercise 3 also require
   calculus, as does Day 4 Ex 6 (polynomial derivatives). The learner profile guarantees HS
   algebra only.
   *Fix direction:* swap the two proofs (eigenbasis proof primary, Lagrange as optional aside);
   replace or hint-scaffold the calculus exercises.

### P1 — Correctness and chaining defects

4. **Unproven load-bearing facts** (used structurally, proven nowhere at time of use):
   - `C(A)⊥ = N(Aᵀ)` — drives Day 16's normal-equations theorem and Day 18 P15; Day 16
     attributes it to "confirmed on Day 15," but day15.md never states it.
   - Uniqueness of coordinates in a basis — Day 3's entire matrix-representation construction
     rests on it; never stated or proved in Days 1–2.
   - Matrix–vector/matrix–matrix multiplication mechanics — used from Day 3 on, never defined;
     the row-times-column rule first appears mid-proof as something to "recognize."
   - Transpose and `(AB)ᵀ = BᵀAᵀ` — used on Day 6 (definition of left null space, Ex 7) without
     definition.
   - `dim(U+V) = dim U + dim V − dim(U∩V)` — the crux of Day 22's Eckart–Young Stage-1 proof;
     verified absent from days 1–21.
   - Block-triangular determinant factorization — Day 11 Lemma 11.1 claims it was "fully
     proved on Day 8"; Day 8 proves only the entrywise-triangular case (Lemma 8.5).
   - Basis extension theorem — cited by Day 4's rank-nullity proof as "(Day 2)," but it exists
     only as Day 2 Exercise 6; a learner who failed that exercise is unknowingly missing a
     prerequisite for the plan's most important theorem.

5. **Outright text/solution errors:**
   - Day 6 worked example: "Pivots are in columns 1 and 2" — should be rows 1 and 2 / columns
     1 and 3 (subsequent computation is correct).
   - Day 20: claims the five definiteness classes are "mutually exclusive except the zero
     matrix" — false (definite ⊂ semidefinite under Definition 20.2 as written).
   - Day 24 P9: SVD solution for diag(2,3) sets Σ = diag(2,3), violating Day 21's own
     Definition 21.1 (descending σ) — teaches the learner to ignore the convention Day 21's
     lab warns about.
   - Day 24 P13: "Day 26 will prove trace = Σλ" — already proved on Day 23 Ex 5 (and Day 19
     Ex 8); the mis-citation undermines retrieval practice.
   - Day 9 "Unconventional edge": adjugate formula "coming properly on Day 8" — Day 8 is in
     the past and never covers the adjugate. (Day 9 also re-proves Day 8's elementary-matrix
     lemma nearly verbatim — likely a day-ordering swap without a consistency pass.)
   - Day 14 worked example: leftover draft artifact ("…wait, check carefully:") left in the text.
   - Day 18 P6 solution: uses the cross product, never taught anywhere in the plan.
   - Day 12 Sol 8: asserts unconditional Markov-chain convergence (needs aperiodicity — its own
     case (b) notes the oscillation possibility, then ignores it).
   - Day 26: garbled Cholesky sketch ("Gram-Schmidt applied to the rows of Q√Λᵀ"); Ex 5's flat
     "Cholesky does not apply" to a PSD matrix is imprecise (non-unique LLᵀ exists; the
     positive-diagonal/`np.linalg.cholesky` version fails).
   - Minor: Day 11 worked-example "Verify A = PDP⁻¹" labels B's verification as A; Day 3 lab
     hint "SA = S·T" should be ST; Days 4/5 disagree on a 3B1B chapter number; Day 27 P4's
     "doesn't simplify cleanly" remark is false (answer correct); Day 17 Solution 3's row/column
     opening sentence is muddled; Day 17 Thm 17.2 asserts Q,R uniqueness without proof.

6. **Proof-first protocol breaks structurally in two places:**
   - Every day prints each proof immediately below its statement with no in-file "attempt
     before reading" gate — the protocol lives only in the plan doc, so the file layout
     invites the passive reading the plan forbids.
   - Day 15: Theorem 15.1's proof invokes Theorem 15.2 ("below") — a learner honoring
     write-before-read cannot do it in the printed order.

### P2 — Requirement and self-check gaps

7. **Hints are missing on ~70% of exercises** (your standing requirement: every exercise ships
   with hints + solutions). Days 1–7: zero hints on any paper exercise (code labs have them).
   Solutions themselves are universally complete — the gap is only the intermediate nudge, so
   a stuck offline learner's only move is reading the full answer. Worst stranding candidates:
   Day 10 Ex 6 (complex 3×3), Day 15 Ex 6, Day 14 Ex 8, Day 22 (1 hint in 8 exercises).

8. **Exam days lack grading artifacts.** Days 27 and 30 have "Score: __/__" with no point
   scheme or partial-credit rubric, so concept-gap vs arithmetic-slip triage (the plan's own
   mechanic) has no systematic basis. Day 29's mental map — the capstone's main synthesis
   deliverable — has no model answer or checklist, making it unverifiable offline.

9. **Capstone passivity (Days 28–29).** The learner writes zero code: both days run and
   annotate provided scripts. The from-scratch PCA build actually happens on Day 23. The
   theorem-annotation and closed-book re-derivation steps partially deliver the capstone's
   intent, but "implement PCA from scratch, every line traceable to a theorem" is not literally
   what these days do — and they are the plan's most underloaded days.

10. **Review-day schedules all overrun on paper.** Days 7, 18, 24, 27, 30 each sum to 255–285
    min against the 240-min block before any slippage; Day 7's 150-min problem set is
    realistically ~200 min for this learner, which silently overflows the score-and-correct
    phase.

11. **Day 27 coverage gaps:** no direct SVD computation problem, and Days 3, 25–26 material is
    absent despite the "Days 1–26" title.

---

## What is working well (keep as-is)

- **Review-day machinery is top-1% in substance, not just name:** timed closed-book interleaved
  sets, per-topic tallies, rewrite-missed-solutions-by-hand, concept-gap vs arithmetic-slip
  classification. Days 13 and 18 are exemplary; Day 12 is the calibration model for content days.
- **Mathematical accuracy is high:** reviewers hand-verified the large majority of ~280
  solutions; everything not listed in P1 checked out, including all of days 25–30's arithmetic.
- **Anti-mistake design mostly lands:** videos capped as primers, labs gated behind paper work,
  unifying days (6, 25) explicit, trap exercises pre-labeled, "Unconventional edge" sections
  genuinely target misconceptions.
- **Chaining discipline is unusually good** — most claims carry day-citations; the defects in
  P1 stand out precisely because the rest is clean.

---

## Recommended fix order (no changes made — your call)

1. **P0-1 load rebalance** — add "read-only proof" markers on the 5 hardest proofs + shift
   exercise load from Days 8/11/21 toward Days 25/26; this alone brings every day under ~4.5h.
2. **P0-2 purpose-built Day 30 final** with rubric (biggest single-file fix, protects the
   plan's success criteria).
3. **P0-3 Day 23 proof swap** (eigenbasis proof primary) + fix Day 4 Ex 6 calculus dependency.
4. **P1-4 patch the seven unproven facts** — most need only a short lemma or an honest
   "taken as given" label; C(A)⊥=N(Aᵀ) deserves a real proof on Day 15 (it is also the FTLA
   payoff the plan foreshadows on Day 6).
5. **P1-5 mechanical errata pass** (one-line fixes, ~15 items listed above).
6. **P2-7 hints pass** — add one nudge-level hint per solution-bearing exercise, prioritizing
   the proof exercises.
7. **P2-8/9 capstone + rubric upgrades** — make Days 28–29 re-implementation days (blank-file
   rebuild of Day 23's PCA on the new dataset would fit the freed capacity) and add point
   schemes to Days 27/30, a model answer to Day 29's map.
