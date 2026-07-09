# 30-Day Linear Algebra Mastery Plan

**Date:** 2026-07-08
**Status:** Approved design

## Purpose

Build deep, durable mastery of core (real-valued) linear algebra in 30 days, as the
foundation for two follow-on goals: machine learning and quantum computing. This is
not exam-driven — there is no external deadline — but the plan is run as an aggressive
30-day intensive at 4 hours/day (~120 hours total).

## Learner context

- Background: solid high-school algebra, no formal linear algebra course.
- Prior exposure: Khan Academy and 3Blue1Brown — good geometric intuition, but both
  are exercise-light, so no real problem-solving fluency was built.
- Proof-writing: some exposure (seen/written a few proofs), not yet fluent.
- Explicit requirement: solid theory + proof, heavy exercise practice to build real
  comprehension, *then* code — not the reverse, and not code as a substitute for
  either.
- Scope: this plan covers core real-valued linear algebra only. Complex vector
  spaces, Hermitian/unitary matrices, and bra-ket notation (needed for quantum
  computing specifically) are deliberately deferred to a short follow-on phase after
  Day 30, so the 30 days stay focused and don't lose depth to premature breadth.

## Resources & the three-layer model

Rather than following one textbook's table of contents, each topic is covered
through three fixed layers, always in this order:

1. **Theory/proof** — Serge Treil's *Linear Algebra Done Wrong* (free PDF). Chosen
   over Axler's *Linear Algebra Done Right* because it keeps determinants and
   computation integrated alongside the proofs, rather than deferring them, which
   matters for someone still building computational fluency. 3Blue1Brown videos are
   reused here as a 10–15 minute geometric primer *before* the proof reading — a
   warm-up for intuition already built, not the main event.
2. **Exercise volume** — Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
   ~600+ solved problems, as the primary drill bank. This directly addresses the
   "too few exercises" gap left by 3Blue1Brown/Khan Academy. MIT OCW 18.06 problem
   sets (free, with solutions) are folded in for the ML-critical topics (elimination,
   eigenvalues, SVD) since they're application-flavored.
3. **Code lab** — NumPy/Python, always *after* the theory and exercises for that
   topic are done. Each lab: recompute by hand what was just solved on paper, verify
   against `numpy.linalg`, then extend one step further (visualize a transformation,
   or run on a messier example than pencil-and-paper allows).

**Hard rule:** no code before the pencil-and-paper exercises for that topic are
complete. Code verifies and extends understanding; it does not build it.

## 30-day topic sequence & time allocation

Weighted so eigenvalues, orthogonality, and SVD (14 of 30 days) get the most time,
since those are what machine learning and quantum computing actually run on.
Determinants and inverses are compressed to 2 days as lower downstream leverage.
Review days are placed every 5–6 days rather than only at the end, since spaced
retrieval outperforms a single linear pass through the material.

| Days | Topic |
|---|---|
| 1–2 | Vector spaces, span, linear independence, basis, dimension |
| 3–4 | Linear transformations, matrix representation, matrix multiplication as composition |
| 5 | Gaussian elimination, row reduction, rank |
| 6 | Four fundamental subspaces (column/null/row/left-null space) — unifying framework |
| **7** | **Review: Days 1–6 (mixed, timed, closed-book)** |
| 8 | Determinants (properties, cofactor expansion) |
| 9 | Invertibility, matrix inverse, intro to LU decomposition |
| 10–11 | Eigenvalues & eigenvectors (definition → characteristic polynomial → diagonalization, algebraic/geometric multiplicity) |
| 12 | Diagonalization applications (matrix powers, difference equations) + code lab |
| **13** | **Review: Days 8–12** |
| 14 | Inner products, norms, Cauchy-Schwarz, orthogonality |
| 15 | Orthogonal complements, Gram-Schmidt process |
| 16 | Orthogonal projections, least squares (→ connection to linear regression) |
| 17 | Orthogonal/orthonormal matrices, QR decomposition |
| **18** | **Review: Days 14–17** |
| 19 | Symmetric matrices & the Spectral Theorem |
| 20 | Quadratic forms, positive definite/semidefinite matrices |
| 21–22 | SVD (existence, geometric meaning, relation to eigendecomposition, low-rank approximation / Eckart-Young theorem) |
| 23 | SVD → PCA derivation from scratch |
| **24** | **Review: Days 19–23** |
| 25 | Change of basis, similarity — consolidates the whole plan into one framework |
| 26 | Trace, determinant as product of eigenvalues, brief bridge to Cholesky/LU |
| **27** | **Cumulative marathon: mixed problems from all 26 days, timed, closed-book first pass** |
| 28–29 | Capstone: implement PCA from scratch in NumPy on a real dataset, plus a second SVD application (e.g. image compression) — every step tied back to the specific theorem behind it |
| 30 | Final self-administered timed exam (Schaum's + MIT 18.06 practice exams), then gap analysis to seed the QC/ML follow-on phase |

## Daily rhythm

**Content day** (new topic), 4-hour block:

- **0:00–0:15** — Geometric primer: a relevant 3Blue1Brown clip or a quick sketch of
  your own. Intuition activation only.
- **0:15–1:15** — Theory/proof reading (Treil). Every proof is written out from the
  statement, by hand, before checking the book's version.
- **1:15–2:45** — Problem sets (Schaum's, + MIT 18.06 for ML-heavy topics). Full
  attempt before looking at any solution.
- **2:45–3:00** — Break.
- **3:00–3:45** — NumPy code lab: recompute the day's hand-solved problems, verify
  against `numpy.linalg`, then extend one step further.
- **3:45–4:00** — Journal: the day's key theorem in your own words, plus one thing
  that was confusing. This journal is exactly what review days draw from.

**Review day** (Days 7, 13, 18, 24): no new theory. Timed, closed-book mixed
problems from the prior block, then targeted re-derivation of anything flagged in
the journal. Same 4-hour block, weighted almost entirely to problem-solving.

**Day 27 / Day 30**: full closed-book timed test first, open-book review of misses
second.

## Mistakes this plan is designed to block

| Mistake | Why it wastes time | How the plan blocks it |
|---|---|---|
| Passive video-watching mistaken for understanding | Feels like learning, produces no durable skill — already experienced with 3Blue1Brown/Khan Academy | Videos capped at 15 min/day as a primer only; every session ends in self-produced proofs/problems |
| Treating linear algebra as a list of disconnected recipes | Procedural fluency (e.g. row reduction) without a model of what's happening | Day 6 (four fundamental subspaces) and Day 25 (change of basis/similarity) are explicit unifying/consolidation days |
| No spaced retrieval — one linear pass through material | The forgetting curve erases Week 1 by Week 3 unnoticed until a real test | Review days every 5–6 days, plus Day 27 cumulative marathon, all closed-book |
| Coding before understanding ("calculator-brain") | NumPy gives correct answers without building the mental model | Hard rule: no code until that topic's hand exercises are complete |
| Never testing under exam conditions | False confidence from open-book problem solving | Every review day and the Day 30 exam are closed-book and timed |
| Skipping determinants/computation as "boring, tools do it" | Weak computational fluency undermines intuition for eigenvalues, volume, invertibility | Dedicated hand-computation days for determinants/inverses before any code |
| Learning topics only algebraically or only visually | Fragile understanding — can't recognize the same idea across representations | Every content day deliberately hits geometric (primer), algebraic (proof), and computational (exercises + code) representations of the same concept |

## Success criteria

- Every proof encountered can be reproduced from the theorem statement alone,
  closed-book.
- The Day 30 timed exam (drawn from Schaum's and MIT 18.06 practice exams) is passed
  without notes.
- The capstone (Days 28–29) produces a working PCA implementation from scratch, with
  every line traceable to a specific theorem from the 30 days.
- Post-Day-30, the learner can name which specific linear algebra concept underlies
  a given ML or QC technique (e.g. "PCA is eigendecomposition of the covariance
  matrix," "a qubit's state space is a complex vector space with a Hermitian inner
  product") — verified informally by the Day 30 gap analysis, not a separate test.

## Out of scope (deferred to post-Day-30 follow-on)

- Complex vector spaces, Hermitian/unitary matrices, bra-ket notation, and other
  quantum-computing-specific extensions.
- Matrix calculus and other ML-specific extensions beyond what's needed for the PCA
  capstone.
