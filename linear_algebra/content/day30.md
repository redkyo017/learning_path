# Day 30 — Final Exam + Gap Analysis

## Instructions

1. **Full closed-book timed exam (180 min).** Take one complete MIT 18.06
   practice final (available via the [MIT OCW 18.06 course page](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/) —
   look for "Exams" in the course materials). Closed book, timed, no code,
   no calculator beyond basic arithmetic. If you can't access a practice
   final, use the Day 27 marathon problem set again, closed-book, as a
   substitute — the point is a full-length timed retrieval test.
2. **Break (15 min).**
3. **Score and correct (45 min).** Grade against the provided solutions.
   For every miss, write the correct solution by hand and note which day of
   this plan it traces back to.
4. **Gap analysis for the ML/QC follow-on (30 min).** Write out, for each
   downstream goal, the specific linear algebra concept from this plan that
   underlies it:

   **Machine learning:**
   - PCA is eigendecomposition of the covariance matrix (Day 23).
   - Linear regression is least squares (Day 16).
   - A neural network layer is a linear transformation plus a matrix
     representation (Day 3), composed via matrix multiplication (Day 3's
     composition theorem).
   - Data compression / low-rank approximation is truncated SVD
     (Day 21–22).
   - Regularization (ridge regression) is adding a multiple of $I$ to make
     $A^TA$ positive definite and invertible (Day 20 + Day 16).

   **Quantum computing** (where the real-valued material you just mastered
   extends into complex vector spaces — out of scope for this plan, but
   the extension points are):
   - A qubit's state space is a complex vector space with a Hermitian inner
     product — the complex analogue of Day 14's inner product space.
   - Quantum gates are unitary matrices — the complex analogue of Day 17's
     orthogonal matrices (both preserve norms; unitary preserves the
     complex inner product the way orthogonal preserves the real one).
   - Measurement and diagonalizing observables is the complex analogue of
     Day 19's spectral theorem (Hermitian matrices play the role real
     symmetric matrices played here).

   List any topic from today's exam you're still shaky on — this becomes
   the first thing to revisit before starting the ML/QC follow-on.
5. **Final journal entry.**

```
## Day 30 — Final exam + gap analysis
Score: __/__
ML concept map: ...
QC concept map: ...
Remaining gaps to close before starting ML/QC: ...
```

## What's next

This plan covered core real-valued linear algebra only, by design (see the
spec's Scope section). Before starting ML or QC material, the natural next
step is a short follow-on covering exactly the complex-vector-space
extensions named above — Hermitian/unitary matrices and bra-ket notation for
QC, and matrix calculus for ML — building directly on the real-valued
foundations from Days 1–30 rather than starting over.
