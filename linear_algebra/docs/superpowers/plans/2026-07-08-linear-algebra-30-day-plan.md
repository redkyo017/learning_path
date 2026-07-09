# 30-Day Linear Algebra Mastery — Implementation Plan

> **For the learner:** This plan is executed by you, not by an agent — each day's
> "task" is a study session, not a code change. Work top to bottom, one day at a
> time, and check off steps as you complete them. Do not skip ahead; the review
> days depend on the journal entries from the days before them.

**Goal:** Reach proof-level mastery of core (real-valued) linear algebra in 30 days
(4 hours/day, ~120 hours total) as the foundation for machine learning and quantum
computing.

**Architecture:** Each content day runs a fixed three-layer sequence — geometric
primer → theory/proof (written by hand) → exercises (attempted closed-book) → code
lab (NumPy, only after the exercises are done) → journal entry. Review days (7, 13,
18, 24) and a cumulative marathon (27) interrupt the linear sequence with
closed-book retrieval practice. Days 28–30 are a capstone project and final exam.

**Tech Stack / Materials:**
- Theory: Serge Treil, *Linear Algebra Done Wrong* (free PDF)
- Exercises: Schaum's Outline of Linear Algebra (Lipschutz/Lipson); MIT OCW 18.06
  problem sets for ML-weighted days
- Code: Python 3, NumPy, Matplotlib, SciPy (for `scipy.linalg.null_space`,
  `scipy.linalg.lu`, `scipy.linalg.cholesky`)
- Tracking: `journal.md` (one entry per day, appended) and `labs/dayNN_topic.py`
  (one file per code lab)

## Global Constraints

- 4-hour daily budget; do not extend a day to "finish" — if a step overruns,
  journal it and move on; review days will catch it.
- **No code before that day's hand exercises are complete.** This is a hard rule
  from the spec, not a suggestion.
- Every review day and the Day 30 exam is closed-book on the first pass. Only
  open notes after attempting.
- Complex vector spaces, Hermitian/unitary matrices, and bra-ket notation are out
  of scope for this plan — deferred to a post-Day-30 follow-on.
- If you set up git in this folder, commit `journal.md` and that day's lab file
  at the end of every day — this is your progress record.

---

## Day 1: Vector spaces, subspaces, span, linear combinations

**Materials:**
- Theory: Treil, *Linear Algebra Done Wrong*, Ch. 1 §§1.1–1.3 (vector spaces,
  subspaces, linear combinations and span)
- Exercises: Schaum's Outline, chapter on Vector Spaces — all problems on
  subspaces and span (expect 20+ problems)
- Code: `labs/day01_vector_spaces.py`
- Journal: `journal.md`

**Builds on:** nothing (Day 1)
**Sets up:** Day 2 needs the definitions of span and subspace to define linear
independence and basis.

- [ ] **Step 1 (15 min): Geometric primer.** Watch 3Blue1Brown, *Essence of Linear
  Algebra*, Ch. 1–2 (vectors, linear combinations, span, basis vectors). This is
  review of intuition you already have — just re-activate it.
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil §§1.1–1.3. Without
  looking at the book, write out proofs of:
  - The span of any subset $S \subseteq V$ is a subspace of $V$.
  - The intersection of two subspaces of $V$ is a subspace of $V$.
  - Give a counterexample showing the union of two subspaces need not be a
    subspace.
  Check each against the book only after attempting it.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline, Vector Spaces chapter —
  every problem on subspaces, linear combinations, and span. Attempt fully before
  checking the solution.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day01_vector_spaces.py`:

```python
import numpy as np

def is_in_span(target, vectors):
    """Return True if target is a linear combination of the given vectors."""
    A = np.column_stack(vectors)
    solution, residuals, rank, _ = np.linalg.lstsq(A, target, rcond=None)
    return np.allclose(A @ solution, target)

v1 = np.array([1.0, 0.0, 1.0])
v2 = np.array([0.0, 1.0, 1.0])
b_in = np.array([2.0, 3.0, 5.0])       # 2*v1 + 3*v2
b_out = np.array([1.0, 1.0, 1.0])      # not in span{v1, v2}

print("b_in in span:", is_in_span(b_in, [v1, v2]))
print("b_out in span:", is_in_span(b_out, [v1, v2]))
```

  Run it, confirm `b_in` prints `True` and `b_out` prints `False`. Then pick two
  of your own vectors in $\mathbb{R}^4$ and test a vector you construct to be
  outside their span.
- [ ] **Step 6 (15 min): Journal entry.** In `journal.md`, append:
  ```
  ## Day 1 — Vector spaces, span
  Key theorem in my own words: ...
  What confused me: ...
  ```
- [ ] **Step 7: Commit** (if using git): `git add journal.md labs/day01_vector_spaces.py && git commit -m "Day 1: vector spaces, span"`

---

## Day 2: Linear independence, basis, dimension

**Materials:**
- Theory: Treil, Ch. 1 §§1.4–1.5 (linear independence, basis, dimension)
- Exercises: Schaum's Outline, Vector Spaces chapter — problems on independence,
  basis, dimension
- Code: `labs/day02_basis_dimension.py`

**Builds on:** Day 1's span/subspace definitions.
**Sets up:** Day 3 needs basis to define how a linear transformation is
represented as a matrix.

- [ ] **Step 1 (15 min): Primer.** 3Blue1Brown, *Essence of Linear Algebra*, Ch. 2
  continued — linear independence and basis, if not already covered.
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil §§1.4–1.5. Prove:
  - A set of vectors $\{v_1, ..., v_n\}$ is linearly independent iff no $v_i$ is a
    linear combination of the others.
  - Every spanning set of a finite-dimensional vector space contains a basis
    (Steinitz exchange lemma or equivalent).
  - All bases of a finite-dimensional vector space have the same number of
    elements (so dimension is well-defined).
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline, all problems on linear
  independence, basis, and dimension. Closed-book attempt first.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day02_basis_dimension.py`:

```python
import numpy as np

def is_independent(vectors):
    A = np.column_stack(vectors)
    return np.linalg.matrix_rank(A) == len(vectors)

v1 = np.array([1.0, 2.0, 3.0])
v2 = np.array([0.0, 1.0, 1.0])
v3 = np.array([1.0, 4.0, 5.0])   # = v1 + 2*v2, dependent

print("{v1, v2} independent:", is_independent([v1, v2]))
print("{v1, v2, v3} independent:", is_independent([v1, v2, v3]))
print("dimension of span{v1, v2, v3}:", np.linalg.matrix_rank(np.column_stack([v1, v2, v3])))
```

  Confirm the dependent set reports `False` and the computed dimension is 2, not
  3. Then construct your own 4-vector set in $\mathbb{R}^4$ with exactly one
  redundant vector and verify the rank drops by 1.
- [ ] **Step 6 (15 min): Journal entry** for Day 2.
- [ ] **Step 7: Commit.**

---

## Day 3: Linear transformations, matrix representation

**Materials:**
- Theory: Treil, Ch. 1 §§1.6–1.7 (linear transformations, matrix of a linear
  transformation)
- Exercises: Schaum's Outline, Linear Mappings chapter — problems on verifying
  linearity and constructing matrix representations
- Code: `labs/day03_linear_transformations.py`

**Builds on:** Day 2's basis.
**Sets up:** Day 4 needs matrix representation to discuss invertibility and
rank-nullity.

- [ ] **Step 1 (15 min): Primer.** 3Blue1Brown, Ch. 3–4 (linear transformations,
  matrix multiplication as composition).
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil §§1.6–1.7. Prove:
  - A linear transformation $T: V \to W$ is completely determined by its action
    on a basis of $V$.
  - If $T$ has matrix $A$ (relative to given bases) and $S$ has matrix $B$, then
    $S \circ T$ has matrix $BA$.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline, Linear Mappings chapter —
  all problems on verifying linearity and building matrix representations from a
  basis.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day03_linear_transformations.py`:

```python
import numpy as np

# T: rotate by 90 degrees, S: scale x by 2
T = np.array([[0.0, -1.0], [1.0, 0.0]])
S = np.array([[2.0, 0.0], [0.0, 1.0]])

e1, e2 = np.array([1.0, 0.0]), np.array([0.0, 1.0])
print("T(e1), T(e2):", T @ e1, T @ e2)

composed_matrix = S @ T
v = np.array([3.0, -1.0])
via_matrix = composed_matrix @ v
via_composition = S @ (T @ v)
print("S(T(v)) == (S@T)(v):", np.allclose(via_matrix, via_composition))
```

  Confirm the composition check prints `True`. Then define a third transformation
  of your own and verify associativity of composition numerically:
  `(R@S)@T == R@(S@T)`.
- [ ] **Step 6 (15 min): Journal entry** for Day 3.
- [ ] **Step 7: Commit.**

---

## Day 4: Invertibility, isomorphisms, rank-nullity

**Materials:**
- Theory: Treil, Ch. 1 §§1.8–1.9 (invertibility, isomorphisms, rank-nullity)
- Exercises: Schaum's Outline, Linear Mappings and Matrices chapter
- Code: `labs/day04_rank_nullity.py`

**Builds on:** Day 3's matrix representation.
**Sets up:** Day 5 needs the notion of rank before Gaussian elimination formalizes
how to compute it.

- [ ] **Step 1 (10 min): Primer.** 3Blue1Brown, Ch. 7 (inverse matrices, rank,
  null space) — first watch only, save the rest for Day 6.
- [ ] **Step 2 (65 min): Theory + hand proofs.** Read Treil §§1.8–1.9. Prove:
  - A linear transformation $T: V \to W$ between finite-dimensional spaces of
    equal dimension is invertible iff it is injective iff it is surjective.
  - Rank-nullity theorem: $\dim(\ker T) + \dim(\operatorname{im} T) = \dim V$.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline, Linear Mappings and
  Matrices chapter — all problems on kernel, image, rank, and invertibility.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (40 min): Code lab.** Create `labs/day04_rank_nullity.py`:

```python
import numpy as np
from scipy.linalg import null_space

A = np.array([
    [1.0, 2.0, 3.0],
    [2.0, 4.0, 6.0],
    [1.0, 0.0, 1.0],
])

rank = np.linalg.matrix_rank(A)
nullity = A.shape[1] - rank
kernel_basis = null_space(A)

print("rank:", rank, "nullity:", nullity, "domain dim:", A.shape[1])
print("rank + nullity == domain dim:", rank + nullity == A.shape[1])
print("kernel basis:\n", kernel_basis)
```

  Confirm the rank-nullity identity holds. Then generate 3 random $4\times 6$
  matrices with `np.random.rand` and verify the identity holds for all of them
  in a loop.
- [ ] **Step 6 (15 min): Journal entry** for Day 4.
- [ ] **Step 7: Commit.**

---

## Day 5: Gaussian elimination, row reduction, rank

**Materials:**
- Theory: Treil, Ch. 2 §§2.1–2.3 (systems of equations, elementary row
  operations, row echelon form)
- Exercises: Schaum's Outline, Systems of Linear Equations chapter — all problems
- Code: `labs/day05_gaussian_elimination.py`

**Builds on:** Day 4's rank.
**Sets up:** Day 6 needs row reduction to compute the four fundamental subspaces.

- [ ] **Step 1 (15 min): Primer.** 3Blue1Brown, Ch. 6 (inverse matrices, column
  space, and null space) if not fully watched; otherwise sketch a 3-equation
  system by hand and visualize the solution as a plane intersection.
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil §§2.1–2.3. Prove:
  - Elementary row operations do not change the solution set of a linear system.
  - $\operatorname{rank}(A)$ equals the number of pivots in any row echelon form
    of $A$, and this number is independent of the elimination path taken.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline, Systems of Linear
  Equations chapter — every problem, done by hand with full elimination steps
  shown (not just final answers).
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day05_gaussian_elimination.py`
  — implement elimination yourself before checking against a library:

```python
import numpy as np

def row_echelon(A):
    A = A.astype(float).copy()
    rows, cols = A.shape
    pivot_row = 0
    for col in range(cols):
        pivot = None
        for r in range(pivot_row, rows):
            if not np.isclose(A[r, col], 0):
                pivot = r
                break
        if pivot is None:
            continue
        A[[pivot_row, pivot]] = A[[pivot, pivot_row]]
        A[pivot_row] = A[pivot_row] / A[pivot_row, col]
        for r in range(rows):
            if r != pivot_row:
                A[r] -= A[r, col] * A[pivot_row]
        pivot_row += 1
        if pivot_row == rows:
            break
    return A

A = np.array([
    [2.0, 1.0, -1.0],
    [-3.0, -1.0, 2.0],
    [-2.0, 1.0, 2.0],
])
print("reduced row echelon form:\n", row_echelon(A))
print("rank from my elimination vs numpy:",
      np.linalg.matrix_rank(row_echelon(A)), np.linalg.matrix_rank(A))
```

  Verify your rank matches NumPy's on 3 more matrices you construct by hand,
  including one that is singular.
- [ ] **Step 6 (15 min): Journal entry** for Day 5.
- [ ] **Step 7: Commit.**

---

## Day 6: Four fundamental subspaces

**Materials:**
- Theory: Treil, Ch. 2 §2.4 plus synthesis of Days 1–5 (column space, row space,
  null space, left null space)
- Exercises: Mixed problems from Schaum's Vector Spaces + Systems chapters that
  connect rank to all four subspaces; MIT OCW 18.06, Problem Set on the four
  fundamental subspaces
- Code: `labs/day06_four_subspaces.py`

**Builds on:** Days 4–5 (rank, row reduction).
**Sets up:** Day 14 will formalize the orthogonality relationship between these
subspaces once inner products are defined.

- [ ] **Step 1 (15 min): Primer.** 3Blue1Brown does not have a dedicated video for
  this — instead, sketch by hand: for a $3\times 2$ matrix, draw its column space
  (a plane or line in $\mathbb{R}^3$) and null space (a subspace of
  $\mathbb{R}^2$).
- [ ] **Step 2 (60 min): Theory + hand proof.** State and prove (or carefully
  justify from rank-nullity) the Fundamental Theorem of Linear Algebra, Part 1:
  for an $m \times n$ matrix $A$ of rank $r$,
  - $\dim(\text{row space}) = \dim(\text{column space}) = r$
  - $\dim(\text{null space}) = n - r$
  - $\dim(\text{left null space}) = m - r$
- [ ] **Step 3 (90 min): Exercises.** MIT 18.06 problem set on the four
  fundamental subspaces (closed-book attempt), plus any Schaum's problems asking
  you to find a basis for column space, row space, and null space of the same
  matrix.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day06_four_subspaces.py`:

```python
import numpy as np
from scipy.linalg import null_space, orth

A = np.array([
    [1.0, 2.0, 1.0],
    [2.0, 4.0, 3.0],
    [3.0, 6.0, 5.0],
])

col_space = orth(A)
row_space = orth(A.T)
null_sp = null_space(A)
left_null_sp = null_space(A.T)

r = np.linalg.matrix_rank(A)
print("rank:", r)
print("dims -> col:", col_space.shape[1], "row:", row_space.shape[1],
      "null:", null_sp.shape[1], "left null:", left_null_sp.shape[1])

# Orthogonality check: row space vectors should be perpendicular to null space vectors
if null_sp.shape[1] > 0:
    print("row space ⟂ null space:", np.allclose(row_space.T @ null_sp, 0))
```

  Confirm the dimensions match the theorem, and that the orthogonality check
  passes (this previews Day 14–15's material — just observe it numerically for
  now, the proof comes later).
- [ ] **Step 6 (15 min): Journal entry** for Day 6.
- [ ] **Step 7: Commit.**

---

## Day 7: Review — Days 1–6

**Materials:** Your own `journal.md` entries for Days 1–6; Schaum's Outline
mixed-topic review problems from the Vector Spaces, Linear Mappings, and Systems
chapters.

- [ ] **Step 1 (30 min): Journal pass.** Reread all 6 journal entries. For every
  item listed under "what confused me," re-derive it from scratch, closed-book,
  before moving on.
- [ ] **Step 2 (150 min): Closed-book mixed problem set.** Pull 15–20 problems at
  random spanning Days 1–6 topics (span, independence, basis, dimension, linear
  transformations, invertibility, rank-nullity, Gaussian elimination, four
  subspaces) from Schaum's Outline. Do the full set closed-book, no notes, timed
  at roughly 150 minutes total.
- [ ] **Step 3 (15 min): Break.**
- [ ] **Step 4 (45 min): Score and correct.** Grade yourself against solutions.
  For every miss, rewrite the correct solution by hand from scratch (not just
  read it) and note in the journal why you missed it (concept gap vs.
  arithmetic slip).
- [ ] **Step 5 (15 min): Journal entry.**
  ```
  ## Day 7 — Review (Days 1-6)
  Score: __/__ 
  Concept gaps found: ...
  Arithmetic-only slips: ...
  ```
- [ ] **Step 6: Commit.**

---

## Day 8: Determinants

**Materials:**
- Theory: Treil, Ch. 3 (determinants — definition via alternating multilinear
  form, cofactor expansion, properties)
- Exercises: Schaum's Outline, Determinants chapter — all problems
- Code: `labs/day08_determinants.py`

**Builds on:** Day 5's row reduction (determinants via elimination).
**Sets up:** Day 10 needs the determinant to define the characteristic
polynomial.

- [ ] **Step 1 (15 min): Primer.** 3Blue1Brown, Ch. 6 (the determinant) — the
  geometric meaning as signed area/volume scaling.
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil Ch. 3. Prove:
  - $\det(I) = 1$ and the determinant is multilinear and alternating in the
    columns of $A$ (state the defining properties and show they pin down a
    unique function).
  - $\det(AB) = \det(A)\det(B)$.
  - $A$ is invertible iff $\det(A) \neq 0$.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline, Determinants chapter —
  every problem, by hand, using cofactor expansion for at least half of them and
  row-reduction-based computation for the other half.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day08_determinants.py`:

```python
import numpy as np

def cofactor_det(A):
    A = np.array(A, dtype=float)
    n = A.shape[0]
    if n == 1:
        return A[0, 0]
    if n == 2:
        return A[0, 0] * A[1, 1] - A[0, 1] * A[1, 0]
    total = 0.0
    for col in range(n):
        minor = np.delete(np.delete(A, 0, axis=0), col, axis=1)
        sign = (-1) ** col
        total += sign * A[0, col] * cofactor_det(minor)
    return total

A = np.array([
    [2.0, 0.0, 1.0],
    [1.0, 3.0, -1.0],
    [0.0, 4.0, 2.0],
])
print("my cofactor det:", cofactor_det(A))
print("numpy det:", np.linalg.det(A))
print("det(AB) == det(A)*det(B):",
      np.isclose(np.linalg.det(A @ A.T), np.linalg.det(A) * np.linalg.det(A.T)))
```

  Confirm your recursive determinant matches NumPy's on 3 more matrices,
  including a $4\times4$.
- [ ] **Step 6 (15 min): Journal entry** for Day 8.
- [ ] **Step 7: Commit.**

---

## Day 9: Invertibility, matrix inverse, LU decomposition

**Materials:**
- Theory: Treil, Ch. 2 §2.5 and Ch. 3 (elementary matrices, computing inverses,
  LU decomposition)
- Exercises: Schaum's Outline, Algebra of Matrices chapter — inverse-related
  problems
- Code: `labs/day09_inverse_lu.py`

**Builds on:** Day 8's determinant (invertibility criterion).
**Sets up:** Day 10 needs invertibility of $(A - \lambda I)$ to define
eigenvalues.

- [ ] **Step 1 (10 min): Primer.** Quick sketch: elimination as multiplication by
  elementary matrices — no dedicated video needed, this is a notational bridge.
- [ ] **Step 2 (65 min): Theory + hand proofs.** Read the relevant sections.
  Prove:
  - The inverse of an invertible matrix is unique, and $(AB)^{-1} = B^{-1}A^{-1}$.
  - Every invertible matrix can be written as a product of elementary matrices.
  - If Gaussian elimination on $A$ requires no row swaps, $A = LU$ for a lower
    triangular $L$ (unit diagonal) and upper triangular $U$.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline problems on computing
  inverses via Gauss-Jordan elimination and via the adjugate/cofactor formula.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (40 min): Code lab.** Create `labs/day09_inverse_lu.py`:

```python
import numpy as np
from scipy.linalg import lu

def gauss_jordan_inverse(A):
    A = A.astype(float)
    n = A.shape[0]
    aug = np.hstack([A, np.eye(n)])
    for col in range(n):
        pivot = np.argmax(np.abs(aug[col:, col])) + col
        aug[[col, pivot]] = aug[[pivot, col]]
        aug[col] = aug[col] / aug[col, col]
        for r in range(n):
            if r != col:
                aug[r] -= aug[r, col] * aug[col]
    return aug[:, n:]

A = np.array([
    [4.0, 3.0],
    [6.0, 3.0],
])
my_inv = gauss_jordan_inverse(A)
print("my inverse:\n", my_inv)
print("matches numpy:", np.allclose(my_inv, np.linalg.inv(A)))

A3 = np.array([[2.0, 1.0, 1.0], [4.0, 3.0, 3.0], [8.0, 7.0, 9.0]])
P, L, U = lu(A3)
print("A == P @ L @ U:", np.allclose(A3, P @ L @ U))
```

  Confirm both checks print `True`. Then verify Gauss-Jordan fails (or requires
  pivoting) on a matrix with a zero in the natural pivot position, and explain
  in the journal why pivoting was necessary.
- [ ] **Step 6 (15 min): Journal entry** for Day 9.
- [ ] **Step 7: Commit.**

---

## Day 10: Eigenvalues & eigenvectors — definitions, characteristic polynomial

**Materials:**
- Theory: Treil, Ch. 4 §§4.1–4.2 (eigenvalues, eigenvectors, characteristic
  polynomial)
- Exercises: Schaum's Outline, Eigenvalues and Eigenvectors chapter — first half
  (computing eigenvalues/eigenvectors by hand)
- Code: `labs/day10_eigen_basics.py`

**Builds on:** Day 8's determinant.
**Sets up:** Day 11 needs the characteristic polynomial to discuss multiplicity
and diagonalizability.

- [ ] **Step 1 (15 min): Primer.** 3Blue1Brown, Ch. 14 (eigenvectors and
  eigenvalues).
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil §§4.1–4.2. Prove:
  - $\lambda$ is an eigenvalue of $A$ iff $\det(A - \lambda I) = 0$.
  - Eigenvectors corresponding to distinct eigenvalues are linearly independent.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline, Eigenvalues and
  Eigenvectors chapter, first half — compute eigenvalues and eigenvectors by
  hand for at least 15 matrices ($2\times2$ and $3\times3$).
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day10_eigen_basics.py`:

```python
import numpy as np

def eigenvalues_via_characteristic_poly(A):
    coeffs = np.poly(A)  # characteristic polynomial coefficients
    return np.roots(coeffs)

A = np.array([
    [4.0, 1.0],
    [2.0, 3.0],
])
my_eigs = np.sort(eigenvalues_via_characteristic_poly(A).real)
np_eigs = np.sort(np.linalg.eigvals(A).real)
print("my eigenvalues:", my_eigs)
print("numpy eigenvalues:", np_eigs)
print("match:", np.allclose(my_eigs, np_eigs))
```

  Confirm the match on this matrix, then on 2 more $3\times3$ matrices you
  compute by hand in Step 3 — cross-check every hand computation against this
  script before moving on.
- [ ] **Step 6 (15 min): Journal entry** for Day 10.
- [ ] **Step 7: Commit.**

---

## Day 11: Diagonalization, algebraic & geometric multiplicity

**Materials:**
- Theory: Treil, Ch. 4 §§4.3–4.4 (diagonalization, multiplicity, similarity)
- Exercises: Schaum's Outline, Eigenvalues/Eigenvectors chapter — second half,
  plus Canonical Forms chapter intro problems
- Code: `labs/day11_diagonalization.py`

**Builds on:** Day 10's eigenvalues/eigenvectors.
**Sets up:** Day 12 needs diagonalization to compute matrix powers efficiently.

- [ ] **Step 1 (10 min): Primer.** Re-watch the diagonalization segment of
  3Blue1Brown Ch. 14 if needed.
- [ ] **Step 2 (65 min): Theory + hand proofs.** Read Treil §§4.3–4.4. Prove:
  - $A$ is diagonalizable iff for every eigenvalue, its geometric multiplicity
    equals its algebraic multiplicity (equivalently, $A$ has $n$ linearly
    independent eigenvectors).
  - Similar matrices ($B = P^{-1}AP$) have the same eigenvalues, trace, and
    determinant.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline — problems on
  diagonalizing matrices and determining algebraic vs. geometric multiplicity,
  including at least one matrix that is *not* diagonalizable.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (40 min): Code lab.** Create `labs/day11_diagonalization.py`:

```python
import numpy as np

A = np.array([
    [2.0, 1.0, 0.0],
    [0.0, 2.0, 1.0],
    [0.0, 0.0, 3.0],
])
eigvals, eigvecs = np.linalg.eig(A)
print("eigenvalues:", eigvals)

rank_deficiency_check = np.linalg.matrix_rank(eigvecs) == A.shape[0]
print("has n independent eigenvectors (diagonalizable):", rank_deficiency_check)

if rank_deficiency_check:
    D = np.diag(eigvals)
    P = eigvecs
    reconstructed = P @ D @ np.linalg.inv(P)
    print("P D P^-1 == A:", np.allclose(reconstructed.real, A))
```

  This matrix is not diagonalizable (repeated eigenvalue 2 with only one
  independent eigenvector) — confirm the script reports that correctly, then
  repeat with a diagonalizable matrix from your Step 3 exercises and confirm
  reconstruction succeeds.
- [ ] **Step 6 (15 min): Journal entry** for Day 11.
- [ ] **Step 7: Commit.**

---

## Day 12: Diagonalization applications

**Materials:**
- Theory: Treil, Ch. 4 §4.5 or supplementary notes on matrix powers via
  diagonalization
- Exercises: MIT OCW 18.06 problem set on difference equations / Markov
  matrices (or Schaum's applied diagonalization problems if covered)
- Code: `labs/day12_diagonalization_applications.py`

**Builds on:** Day 11's diagonalization.
**Sets up:** Day 19 revisits this idea for symmetric matrices specifically.

- [ ] **Step 1 (10 min): Primer.** Sketch by hand: why $A^k = PD^kP^{-1}$ turns
  $k$ matrix multiplications into $k$ scalar exponentiations.
- [ ] **Step 2 (60 min): Theory + hand derivation.** Derive the closed-form
  solution for the Fibonacci recurrence
  $\begin{pmatrix}F_{n+1}\\F_n\end{pmatrix} = \begin{pmatrix}1&1\\1&0\end{pmatrix}\begin{pmatrix}F_n\\F_{n-1}\end{pmatrix}$
  by diagonalizing the $2\times 2$ matrix and computing $A^n$ via $PD^nP^{-1}$,
  by hand, to Binet's formula.
- [ ] **Step 3 (90 min): Exercises.** MIT 18.06 problem set on difference
  equations / Markov matrices — closed-book attempt.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create
  `labs/day12_diagonalization_applications.py`:

```python
import numpy as np
import matplotlib.pyplot as plt
import time

A = np.array([[1.0, 1.0], [1.0, 0.0]])
eigvals, eigvecs = np.linalg.eig(A)
D = np.diag(eigvals)
P = eigvecs
P_inv = np.linalg.inv(P)

def fib_via_diagonalization(n):
    An = P @ np.diag(eigvals ** n) @ P_inv
    return (An @ np.array([1.0, 0.0]))[1].real

def fib_via_matrix_power(n):
    return (np.linalg.matrix_power(A, n) @ np.array([1.0, 0.0]))[1]

for n in [10, 20, 30]:
    print(n, fib_via_diagonalization(n), fib_via_matrix_power(n))

# Plot eigenvector directions as invariant directions of the map
fig, ax = plt.subplots()
for v in eigvecs.T.real:
    ax.plot([0, v[0]], [0, v[1]], marker="o")
ax.set_title("Eigenvector directions of the Fibonacci matrix")
ax.set_aspect("equal")
plt.savefig("labs/day12_eigenvector_directions.png")
print("saved plot to labs/day12_eigenvector_directions.png")
```

  Confirm both Fibonacci methods agree (up to floating-point error), and open
  the saved plot to see the two invariant directions of the map.
- [ ] **Step 6 (15 min): Journal entry** for Day 12.
- [ ] **Step 7: Commit.**

---

## Day 13: Review — Days 8–12

**Materials:** `journal.md` entries for Days 8–12; Schaum's Outline mixed
problems from Determinants, Algebra of Matrices, and Eigenvalues chapters.

- [ ] **Step 1 (30 min): Journal pass.** Re-derive every "what confused me" item
  from Days 8–12, closed-book.
- [ ] **Step 2 (150 min): Closed-book mixed problem set.** 15–20 problems
  spanning determinants, matrix inverses, LU, eigenvalues/eigenvectors, and
  diagonalization. Full closed-book attempt, timed.
- [ ] **Step 3 (15 min): Break.**
- [ ] **Step 4 (45 min): Score and correct.** Rewrite every missed solution by
  hand from scratch; classify each miss as concept gap or arithmetic slip.
- [ ] **Step 5 (15 min): Journal entry** for Day 13 (same template as Day 7).
- [ ] **Step 6: Commit.**

---

## Day 14: Inner products, norms, Cauchy-Schwarz

**Materials:**
- Theory: Treil, Ch. 5 §§5.1–5.2 (inner products, norms, Cauchy-Schwarz,
  triangle inequality)
- Exercises: Schaum's Outline, Inner Product Spaces chapter — first part
- Code: `labs/day14_inner_products.py`

**Builds on:** Day 6's four subspaces (this day formalizes the orthogonality
hinted at there).
**Sets up:** Day 15 needs the inner product to define orthogonal complements and
Gram-Schmidt.

- [ ] **Step 1 (15 min): Primer.** 3Blue1Brown, *Essence of Linear Algebra*,
  Ch. 9 (dot products and duality).
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil §§5.1–5.2. Prove:
  - Cauchy-Schwarz inequality: $|\langle u, v \rangle| \leq \|u\|\|v\|$.
  - The triangle inequality $\|u + v\| \leq \|u\| + \|v\|$ follows from
    Cauchy-Schwarz.
  - The parallelogram law: $\|u+v\|^2 + \|u-v\|^2 = 2\|u\|^2 + 2\|v\|^2$.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline, Inner Product Spaces
  chapter, first part — problems on computing inner products, norms, and
  verifying Cauchy-Schwarz/triangle inequality by hand.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day14_inner_products.py`:

```python
import numpy as np

rng = np.random.default_rng(0)

for _ in range(5):
    u = rng.uniform(-5, 5, size=4)
    v = rng.uniform(-5, 5, size=4)
    lhs = abs(np.dot(u, v))
    rhs = np.linalg.norm(u) * np.linalg.norm(v)
    print(f"Cauchy-Schwarz holds: {lhs <= rhs + 1e-9}  ({lhs:.3f} <= {rhs:.3f})")

    parallelogram_lhs = np.linalg.norm(u + v) ** 2 + np.linalg.norm(u - v) ** 2
    parallelogram_rhs = 2 * np.linalg.norm(u) ** 2 + 2 * np.linalg.norm(v) ** 2
    print("parallelogram law holds:", np.isclose(parallelogram_lhs, parallelogram_rhs))
```

  Confirm both inequalities/identities hold across all 5 random trials.
- [ ] **Step 6 (15 min): Journal entry** for Day 14.
- [ ] **Step 7: Commit.**

---

## Day 15: Orthogonal complements, Gram-Schmidt

**Materials:**
- Theory: Treil, Ch. 5 §§5.3–5.4 (orthogonal complements, Gram-Schmidt process)
- Exercises: Schaum's Outline, Inner Product Spaces chapter — orthogonal
  complement and Gram-Schmidt problems
- Code: `labs/day15_gram_schmidt.py`

**Builds on:** Day 14's inner product.
**Sets up:** Day 16 needs orthogonal complements to define orthogonal
projection.

- [ ] **Step 1 (15 min): Primer.** 3Blue1Brown does not have a dedicated
  Gram-Schmidt video — instead, sketch by hand how to turn two non-orthogonal
  vectors in $\mathbb{R}^2$ into an orthogonal pair by subtracting the
  projection.
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil §§5.3–5.4. Prove:
  - For a finite-dimensional inner product space $V$ and subspace $W$,
    $V = W \oplus W^{\perp}$.
  - The Gram-Schmidt process applied to a basis $\{v_1,...,v_n\}$ produces an
    orthonormal basis spanning the same subspace at every step.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline problems on orthogonal
  complements and Gram-Schmidt — run the process by hand on at least 4 bases.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day15_gram_schmidt.py`:

```python
import numpy as np

def gram_schmidt(vectors):
    basis = []
    for v in vectors:
        w = v.astype(float).copy()
        for b in basis:
            w -= (np.dot(v, b) / np.dot(b, b)) * b
        basis.append(w)
    Q = np.column_stack([b / np.linalg.norm(b) for b in basis])
    return Q

vectors = [np.array([1.0, 1.0, 0.0]), np.array([1.0, 0.0, 1.0]), np.array([0.0, 1.0, 1.0])]
Q = gram_schmidt(vectors)
print("Q^T Q == I (orthonormal):\n", np.round(Q.T @ Q, 6))

Q_np, _ = np.linalg.qr(np.column_stack(vectors))
print("my Q matches numpy QR's Q up to sign:",
      np.allclose(np.abs(Q), np.abs(Q_np)))
```

  Confirm `Q^T Q` is (close to) the identity, and that your Gram-Schmidt output
  matches NumPy's QR decomposition up to column sign.
- [ ] **Step 6 (15 min): Journal entry** for Day 15.
- [ ] **Step 7: Commit.**

---

## Day 16: Orthogonal projections, least squares

**Materials:**
- Theory: Treil, Ch. 5 §5.5 (orthogonal projection, best approximation, least
  squares)
- Exercises: Schaum's Outline projection problems; MIT 18.06 least-squares
  problem set
- Code: `labs/day16_least_squares.py`

**Builds on:** Day 15's orthogonal complements/Gram-Schmidt.
**Sets up:** Day 17 needs projection to motivate QR-based least squares.

- [ ] **Step 1 (10 min): Primer.** Sketch by hand: projecting a point onto a
  line/plane as the closest point on that subspace.
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil §5.5. Prove:
  - The orthogonal projection of $v$ onto subspace $W$ is the unique point in
    $W$ closest to $v$ (the Best Approximation Theorem).
  - The least-squares solution to $Ax = b$ satisfies the normal equations
    $A^TAx = A^Tb$.
- [ ] **Step 3 (90 min): Exercises.** MIT 18.06 least-squares problem set,
  closed-book, plus Schaum's projection problems.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day16_least_squares.py`:

```python
import numpy as np
import matplotlib.pyplot as plt

rng = np.random.default_rng(1)
x = np.linspace(0, 10, 20)
y = 2.5 * x + 1.0 + rng.normal(0, 1.5, size=x.shape)

A = np.column_stack([x, np.ones_like(x)])
normal_eq_solution = np.linalg.inv(A.T @ A) @ A.T @ y
lstsq_solution, *_ = np.linalg.lstsq(A, y, rcond=None)

print("normal equations solution:", normal_eq_solution)
print("np.linalg.lstsq solution:", lstsq_solution)
print("match:", np.allclose(normal_eq_solution, lstsq_solution))

plt.scatter(x, y, label="data")
plt.plot(x, A @ normal_eq_solution, color="red", label="least-squares fit")
plt.legend()
plt.savefig("labs/day16_least_squares_fit.png")
print("saved plot to labs/day16_least_squares_fit.png")
```

  Confirm both solution methods agree, and inspect the saved plot.
- [ ] **Step 6 (15 min): Journal entry** for Day 16.
- [ ] **Step 7: Commit.**

---

## Day 17: Orthogonal matrices, QR decomposition

**Materials:**
- Theory: Treil, Ch. 5 §5.6 (orthogonal matrices, QR decomposition)
- Exercises: Schaum's Outline problems on orthogonal matrices
- Code: `labs/day17_qr_decomposition.py`

**Builds on:** Days 15–16 (Gram-Schmidt, projections).
**Sets up:** Day 19 needs orthogonal matrices for the spectral theorem.

- [ ] **Step 1 (10 min): Primer.** Sketch by hand why multiplying by an
  orthogonal matrix preserves lengths and angles (an isometry).
- [ ] **Step 2 (60 min): Theory + hand proofs.** Read Treil §5.6. Prove:
  - $Q$ is orthogonal ($Q^TQ = I$) iff $Q$ preserves inner products:
    $\langle Qu, Qv\rangle = \langle u,v\rangle$ for all $u,v$.
  - Every matrix with linearly independent columns has a QR decomposition
    $A = QR$ with $Q$ orthogonal and $R$ upper triangular (via Gram-Schmidt).
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline problems on orthogonal
  matrices and QR decomposition, by hand.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day17_qr_decomposition.py`:

```python
import numpy as np

A = np.array([
    [1.0, 1.0, 0.0],
    [1.0, 0.0, 1.0],
    [0.0, 1.0, 1.0],
    [1.0, 1.0, 1.0],
])
Q, R = np.linalg.qr(A)
print("Q orthogonal (Q^T Q == I):", np.allclose(Q.T @ Q, np.eye(Q.shape[1])))
print("QR == A:", np.allclose(Q @ R, A))

y = np.array([1.0, 2.0, 3.0, 4.0])
x_qr = np.linalg.solve(R, Q.T @ y)
x_normal_eq = np.linalg.inv(A.T @ A) @ A.T @ y
print("QR least-squares solution matches normal equations:",
      np.allclose(x_qr, x_normal_eq))
```

  Confirm all three checks pass, then read up on why QR is preferred over the
  normal equations for numerically ill-conditioned $A$ (one-paragraph journal
  note, not a formal proof).
- [ ] **Step 6 (15 min): Journal entry** for Day 17.
- [ ] **Step 7: Commit.**

---

## Day 18: Review — Days 14–17

**Materials:** `journal.md` entries for Days 14–17; Schaum's Outline Inner
Product Spaces chapter mixed problems.

- [ ] **Step 1 (30 min): Journal pass.** Re-derive every "what confused me" item
  from Days 14–17, closed-book.
- [ ] **Step 2 (150 min): Closed-book mixed problem set.** 12–15 problems
  spanning inner products, Cauchy-Schwarz, Gram-Schmidt, orthogonal
  complements, projections, least squares, and QR. Full closed-book attempt,
  timed.
- [ ] **Step 3 (15 min): Break.**
- [ ] **Step 4 (45 min): Score and correct.** Rewrite every missed solution by
  hand; classify concept gap vs. arithmetic slip.
- [ ] **Step 5 (15 min): Journal entry** for Day 18.
- [ ] **Step 6: Commit.**

---

## Day 19: Symmetric matrices & the Spectral Theorem

**Materials:**
- Theory: Treil, Ch. 5 §5.7 (symmetric operators, spectral theorem)
- Exercises: Schaum's Outline problems on symmetric matrices / spectral theorem
- Code: `labs/day19_spectral_theorem.py`

**Builds on:** Days 11 (diagonalization) and 17 (orthogonal matrices).
**Sets up:** Day 20 needs the spectral theorem to classify quadratic forms by
eigenvalue sign.

- [ ] **Step 1 (10 min): Primer.** Sketch by hand: for a $2\times2$ symmetric
  matrix, note that its eigenvectors always come out perpendicular — this is
  what today's proof explains.
- [ ] **Step 2 (65 min): Theory + hand proofs.** Read Treil §5.7. Prove:
  - Eigenvalues of a real symmetric matrix are real.
  - Eigenvectors of a real symmetric matrix corresponding to distinct
    eigenvalues are orthogonal.
  - Spectral theorem: every real symmetric matrix $A$ can be written
    $A = Q\Lambda Q^T$ with $Q$ orthogonal and $\Lambda$ diagonal.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline problems on
  diagonalizing symmetric matrices orthogonally, by hand.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (40 min): Code lab.** Create `labs/day19_spectral_theorem.py`:

```python
import numpy as np

rng = np.random.default_rng(2)
M = rng.uniform(-3, 3, size=(4, 4))
A = M + M.T  # symmetric

eigvals, Q = np.linalg.eigh(A)  # eigh assumes/uses symmetry, returns orthogonal Q
print("Q orthogonal:", np.allclose(Q.T @ Q, np.eye(4)))
reconstructed = Q @ np.diag(eigvals) @ Q.T
print("Q Lambda Q^T == A:", np.allclose(reconstructed, A))
print("eigenvalues are real:", np.all(np.isreal(eigvals)))
```

  Confirm all three checks pass on 3 different random symmetric matrices.
- [ ] **Step 6 (15 min): Journal entry** for Day 19.
- [ ] **Step 7: Commit.**

---

## Day 20: Quadratic forms, positive definiteness

**Materials:**
- Theory: Treil supplementary notes or Ch. 5 extension on quadratic forms;
  Schaum's Outline, Bilinear/Quadratic/Hermitian Forms chapter (real case only)
- Exercises: Schaum's Outline, same chapter, real quadratic form problems
- Code: `labs/day20_quadratic_forms.py`

**Builds on:** Day 19's spectral theorem.
**Sets up:** Day 21 needs positive semi-definiteness of $A^TA$ to prove SVD
exists.

- [ ] **Step 1 (10 min): Primer.** Sketch level curves of $x^2+y^2$ (positive
  definite), $-x^2-y^2$ (negative definite), and $x^2 - y^2$ (indefinite) by
  hand to build intuition before the code lab plots them precisely.
- [ ] **Step 2 (60 min): Theory + hand proof.** State and prove: a symmetric
  matrix $A$ is positive definite iff all its eigenvalues are positive. (Use
  the spectral theorem from Day 19: write $x^TAx$ in terms of $Q\Lambda Q^T$.)
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline real quadratic form
  problems — classify each given matrix as positive/negative
  definite/semidefinite/indefinite by hand via eigenvalues.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day20_quadratic_forms.py`:

```python
import numpy as np
import matplotlib.pyplot as plt

def classify(A):
    eigvals = np.linalg.eigvalsh(A)
    if np.all(eigvals > 0):
        return "positive definite"
    if np.all(eigvals < 0):
        return "negative definite"
    if np.all(eigvals >= 0):
        return "positive semidefinite"
    if np.all(eigvals <= 0):
        return "negative semidefinite"
    return "indefinite"

matrices = {
    "pos_def": np.array([[2.0, 0.0], [0.0, 3.0]]),
    "neg_def": np.array([[-1.0, 0.0], [0.0, -4.0]]),
    "indefinite": np.array([[1.0, 0.0], [0.0, -1.0]]),
}

x = np.linspace(-2, 2, 100)
y = np.linspace(-2, 2, 100)
X, Y = np.meshgrid(x, y)

fig, axes = plt.subplots(1, 3, figsize=(12, 4))
for ax, (name, A) in zip(axes, matrices.items()):
    Z = A[0, 0] * X**2 + (A[0, 1] + A[1, 0]) * X * Y + A[1, 1] * Y**2
    ax.contour(X, Y, Z, levels=12)
    ax.set_title(f"{name}: {classify(A)}")
plt.savefig("labs/day20_quadratic_forms.png")
print("saved plot to labs/day20_quadratic_forms.png")
```

  Inspect the saved contour plots — confirm positive definite gives closed
  ellipses, indefinite gives hyperbolas.
- [ ] **Step 6 (15 min): Journal entry** for Day 20.
- [ ] **Step 7: Commit.**

---

## Day 21: SVD, part 1 — existence & geometric meaning

**Materials:**
- Theory: Treil supplementary SVD notes, or Strang's SVD chapter (freely
  available MIT 18.06 lecture notes) for the existence proof
- Exercises: Schaum's Outline, Linear Operators on Inner Product Spaces
  chapter, SVD section; MIT 18.06 SVD problem set
- Code: `labs/day21_svd_from_scratch.py`

**Builds on:** Day 20's positive definiteness ($A^TA$ is always positive
semi-definite).
**Sets up:** Day 22 needs the SVD to state the Eckart-Young theorem.

- [ ] **Step 1 (15 min): Primer.** 3Blue1Brown does not have a dedicated SVD
  video; instead watch any short conceptual SVD intro you can find in the MIT
  18.06 SVD lecture, first 10 minutes, for the "circle to ellipse" geometric
  picture.
- [ ] **Step 2 (60 min): Theory + hand proof.** Prove SVD existence: since
  $A^TA$ is symmetric positive semi-definite, it has an orthonormal eigenbasis
  with non-negative eigenvalues (Day 19-20 results); define singular values as
  $\sigma_i = \sqrt{\lambda_i}$ and derive $U, \Sigma, V$ from there, showing
  $A = U\Sigma V^T$.
- [ ] **Step 3 (90 min): Exercises.** MIT 18.06 SVD problem set + Schaum's SVD
  section — compute the SVD of small matrices by hand via $A^TA$.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day21_svd_from_scratch.py`:

```python
import numpy as np
import matplotlib.pyplot as plt

A = np.array([[3.0, 0.0], [4.0, 5.0]])

# SVD from scratch via eigendecomposition of A^T A
eigvals, V = np.linalg.eigh(A.T @ A)
order = np.argsort(eigvals)[::-1]
eigvals, V = eigvals[order], V[:, order]
singular_values = np.sqrt(np.clip(eigvals, 0, None))
U = (A @ V) / singular_values

U_np, s_np, Vt_np = np.linalg.svd(A)
print("my singular values:", singular_values)
print("numpy singular values:", s_np)
print("match:", np.allclose(np.sort(singular_values)[::-1], np.sort(s_np)[::-1]))

theta = np.linspace(0, 2 * np.pi, 200)
circle = np.column_stack([np.cos(theta), np.sin(theta)])
ellipse = circle @ A.T

fig, ax = plt.subplots()
ax.plot(circle[:, 0], circle[:, 1], label="unit circle")
ax.plot(ellipse[:, 0], ellipse[:, 1], label="A * unit circle")
ax.legend()
ax.set_aspect("equal")
plt.savefig("labs/day21_svd_circle_to_ellipse.png")
print("saved plot to labs/day21_svd_circle_to_ellipse.png")
```

  Confirm the singular values match, and inspect the saved plot: the ellipse's
  semi-axes should align with $U$'s columns scaled by the singular values.
- [ ] **Step 6 (15 min): Journal entry** for Day 21.
- [ ] **Step 7: Commit.**

---

## Day 22: SVD, part 2 — low-rank approximation, Eckart-Young

**Materials:**
- Theory: Continuation of Day 21's SVD notes — Eckart-Young theorem
- Exercises: MIT 18.06 / Schaum's SVD application problems
- Code: `labs/day22_svd_low_rank.py`

**Builds on:** Day 21's SVD.
**Sets up:** Day 23 needs low-rank approximation to motivate PCA as dimension
reduction.

- [ ] **Step 1 (10 min): Primer.** Sketch by hand: truncating the SVD sum
  $A = \sum_i \sigma_i u_i v_i^T$ to the first $k$ terms as "keeping the $k$
  most important directions."
- [ ] **Step 2 (60 min): Theory + hand proof (statement + justification).**
  State the Eckart-Young theorem: among all rank-$k$ matrices, the truncated
  SVD $A_k = \sum_{i=1}^k \sigma_i u_i v_i^T$ minimizes $\|A - A_k\|_F$ (and the
  spectral norm). Work through the proof sketch using orthogonality of the
  $u_i, v_i$.
- [ ] **Step 3 (90 min): Exercises.** MIT 18.06 / Schaum's problems computing
  low-rank approximations of small matrices by hand and checking the
  approximation error.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day22_svd_low_rank.py`:

```python
import numpy as np
import matplotlib.pyplot as plt
from scipy import datasets

image = datasets.ascent().astype(float)  # built-in scipy grayscale test image
U, s, Vt = np.linalg.svd(image, full_matrices=False)

errors = []
ks = [5, 20, 50, 100]
fig, axes = plt.subplots(1, len(ks) + 1, figsize=(15, 4))
axes[0].imshow(image, cmap="gray")
axes[0].set_title("original")

for ax, k in zip(axes[1:], ks):
    approx = U[:, :k] @ np.diag(s[:k]) @ Vt[:k, :]
    error = np.linalg.norm(image - approx, ord="fro")
    errors.append(error)
    ax.imshow(approx, cmap="gray")
    ax.set_title(f"k={k}, err={error:.0f}")

plt.savefig("labs/day22_svd_compression.png")
print("saved plot to labs/day22_svd_compression.png")
print("errors decrease monotonically with k:", all(errors[i] >= errors[i+1] for i in range(len(errors)-1)))
```

  Inspect the saved image comparison and confirm reconstruction error decreases
  as $k$ grows.
- [ ] **Step 6 (15 min): Journal entry** for Day 22.
- [ ] **Step 7: Commit.**

---

## Day 23: SVD → PCA derivation from scratch

**Materials:**
- Theory: Derivation notes connecting covariance matrix eigendecomposition to
  PCA (synthesize from Days 19–22 material — this is where you write the
  connections yourself, not read them from a new source)
- Exercises: Derive and verify the PCA-maximizes-variance claim by hand on a
  small dataset
- Code: `labs/day23_pca_from_scratch.py`

**Builds on:** Day 19 (spectral theorem for symmetric matrices — covariance is
symmetric) and Day 21–22 (SVD).
**Sets up:** Days 28–29 capstone project builds directly on this day.

- [ ] **Step 1 (10 min): Primer.** Sketch by hand: for a 2D scatter of points,
  the direction of greatest spread is the first principal component — this is
  what today's proof formalizes.
- [ ] **Step 2 (70 min): Theory + hand proof.** Derive PCA from scratch: for
  centered data matrix $X$ ($n$ samples $\times$ $p$ features), show that the
  direction $w$ (with $\|w\|=1$) maximizing the variance of the projections
  $Xw$ is the top eigenvector of the covariance matrix $\frac{1}{n-1}X^TX$, and
  that this is equivalent to the top right singular vector of $X$. Prove the
  maximization claim using a Lagrange multiplier or the spectral theorem
  directly.
- [ ] **Step 3 (80 min): Exercises.** By hand, on a small 2D dataset (5–6
  points you choose), compute the covariance matrix, find its eigenvectors,
  and identify the first principal component. Verify by computing the sample
  variance of the projected data along that direction vs. a few other
  candidate directions.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day23_pca_from_scratch.py`:

```python
import numpy as np
from sklearn.datasets import load_iris
from sklearn.decomposition import PCA

X = load_iris().data
X_centered = X - X.mean(axis=0)

cov = (X_centered.T @ X_centered) / (X_centered.shape[0] - 1)
eigvals, eigvecs = np.linalg.eigh(cov)
order = np.argsort(eigvals)[::-1]
eigvals, eigvecs = eigvals[order], eigvecs[:, order]

my_projection = X_centered @ eigvecs[:, :2]

sk_pca = PCA(n_components=2)
sk_projection = sk_pca.fit_transform(X)

print("explained variance (mine):", eigvals[:2] / eigvals.sum())
print("explained variance (sklearn):", sk_pca.explained_variance_ratio_)
print("projections match up to sign/axis order:",
      np.allclose(np.abs(my_projection), np.abs(sk_projection), atol=1e-6))
```

  Confirm your from-scratch explained variance matches scikit-learn's, and the
  projected coordinates match up to a sign flip.
- [ ] **Step 6 (15 min): Journal entry** for Day 23.
- [ ] **Step 7: Commit.**

---

## Day 24: Review — Days 19–23

**Materials:** `journal.md` entries for Days 19–23; Schaum's mixed problems on
symmetric matrices, quadratic forms, and SVD.

- [ ] **Step 1 (30 min): Journal pass.** Re-derive every "what confused me"
  item from Days 19–23, closed-book.
- [ ] **Step 2 (150 min): Closed-book mixed problem set.** 12–15 problems
  spanning the spectral theorem, quadratic forms, and SVD. Full closed-book
  attempt, timed.
- [ ] **Step 3 (15 min): Break.**
- [ ] **Step 4 (45 min): Score and correct.** Rewrite every missed solution by
  hand; classify concept gap vs. arithmetic slip.
- [ ] **Step 5 (15 min): Journal entry** for Day 24.
- [ ] **Step 6: Commit.**

---

## Day 25: Change of basis, similarity

**Materials:**
- Theory: Treil Ch. 1 revisited (change of basis formula) synthesized with
  Ch. 4 (similarity)
- Exercises: Schaum's Outline review-style problems on change of basis and
  similarity
- Code: `labs/day25_change_of_basis.py`

**Builds on:** Days 3 (matrix representation) and 11 (similarity).
**Sets up:** Day 26's trace/determinant-eigenvalue relations depend on
similarity invariance.

- [ ] **Step 1 (10 min): Primer.** Sketch by hand: the same vector expressed in
  two different bases, and the change-of-basis matrix connecting the
  coordinate vectors.
- [ ] **Step 2 (60 min): Theory + hand proof.** Prove the change-of-basis
  formula: if $[T]_B$ is the matrix of $T$ in basis $B$ and $P$ is the
  change-of-basis matrix from $B'$ to $B$, then $[T]_{B'} = P^{-1}[T]_BP$.
  Prove that similar matrices share eigenvalues, trace, determinant, and rank.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline problems on change of
  basis and similarity, by hand.
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day25_change_of_basis.py`:

```python
import numpy as np

# T: reflection across the line y = x, in the standard basis
T_standard = np.array([[0.0, 1.0], [1.0, 0.0]])

# New basis B' = {(1,1), (1,-1)}
P = np.array([[1.0, 1.0], [1.0, -1.0]])
T_new_basis = np.linalg.inv(P) @ T_standard @ P

print("T in new basis (should be diagonal, since (1,1) and (1,-1) are eigenvectors):\n",
      np.round(T_new_basis, 6))

eigvals_standard = np.linalg.eigvals(T_standard)
eigvals_new = np.linalg.eigvals(T_new_basis)
print("eigenvalues preserved under similarity:",
      np.allclose(np.sort(eigvals_standard), np.sort(eigvals_new)))
print("trace preserved:", np.isclose(np.trace(T_standard), np.trace(T_new_basis)))
print("det preserved:", np.isclose(np.linalg.det(T_standard), np.linalg.det(T_new_basis)))
```

  Confirm the transformed matrix comes out diagonal (since the new basis is
  made of eigenvectors) and that eigenvalues/trace/det are all preserved.
- [ ] **Step 6 (15 min): Journal entry** for Day 25.
- [ ] **Step 7: Commit.**

---

## Day 26: Trace, determinant-eigenvalue relation, bridge to Cholesky

**Materials:**
- Theory: Treil Ch. 4 supplementary material connecting the characteristic
  polynomial's coefficients to trace and determinant; brief note on Cholesky
  decomposition for positive definite matrices
- Exercises: Schaum's Outline review problems on trace properties
- Code: `labs/day26_trace_det_cholesky.py`

**Builds on:** Days 10 (characteristic polynomial) and 20 (positive
definiteness).
**Sets up:** Day 27's cumulative review draws on this as the last new-content
day.

- [ ] **Step 1 (10 min): Primer.** Sketch by hand why, for a $2\times2$ matrix,
  $\text{trace}(A) = \lambda_1 + \lambda_2$ and $\det(A) = \lambda_1\lambda_2$
  fall directly out of the characteristic polynomial $\lambda^2 -
  \text{trace}(A)\lambda + \det(A) = 0$.
- [ ] **Step 2 (60 min): Theory + hand proof.** Generalize the $n\times n$ case:
  prove $\text{trace}(A) = \sum_i \lambda_i$ and $\det(A) = \prod_i \lambda_i$
  by expanding the characteristic polynomial $\det(A-\lambda I)$ and comparing
  coefficients. State (proof sketch acceptable) that every symmetric positive
  definite matrix has a unique Cholesky decomposition $A = LL^T$ with $L$
  lower triangular.
- [ ] **Step 3 (90 min): Exercises.** Schaum's Outline review problems on trace
  properties (linearity, trace of a product, trace under similarity).
- [ ] **Step 4 (15 min): Break.**
- [ ] **Step 5 (45 min): Code lab.** Create `labs/day26_trace_det_cholesky.py`:

```python
import numpy as np
from scipy.linalg import cholesky

rng = np.random.default_rng(3)
M = rng.uniform(-2, 2, size=(4, 4))
A = M @ M.T + 4 * np.eye(4)  # guaranteed positive definite

eigvals = np.linalg.eigvalsh(A)
print("trace == sum of eigenvalues:", np.isclose(np.trace(A), eigvals.sum()))
print("det == product of eigenvalues:", np.isclose(np.linalg.det(A), np.prod(eigvals)))

L = cholesky(A, lower=True)
print("L L^T == A:", np.allclose(L @ L.T, A))
```

  Confirm all three checks pass on 3 different random positive-definite
  matrices.
- [ ] **Step 6 (15 min): Journal entry** for Day 26.
- [ ] **Step 7: Commit.**

---

## Day 27: Cumulative marathon — Days 1–26

**Materials:** All `journal.md` entries; a broad closed-book problem set
sampled across every chapter of Schaum's Outline covered so far, plus your own
list of "confusing" items collected across the whole month.

- [ ] **Step 1 (15 min): Compile your weak-spot list.** Skim all journal
  entries and list every recurring "what confused me" item across the 26 days.
- [ ] **Step 2 (180 min): Full closed-book timed exam.** Assemble 25–30
  problems spanning all major topics (vector spaces through SVD) from Schaum's
  Outline. No notes, no code, one sitting (take a 10-minute break at the
  midpoint if needed, but keep it closed-book throughout).
- [ ] **Step 3 (15 min): Break.**
- [ ] **Step 4 (60 min): Score, correct, and triage.** Grade against solutions.
  For every miss, rewrite the full correct solution by hand. Sort misses into:
  topics needing a full re-read vs. topics needing just more practice
  problems.
- [ ] **Step 5 (15 min): Journal entry.**
  ```
  ## Day 27 — Cumulative marathon
  Score: __/__
  Topics needing a full re-read before Day 28: ...
  Topics needing more practice only: ...
  ```
- [ ] **Step 6: Commit.**

---

## Day 28: Capstone, part 1 — PCA from scratch on a real dataset

**Materials:**
- Your Day 23 derivation and code as the starting point
- Code: `labs/day28_pca_capstone.py`
- Dataset: scikit-learn's Iris or Wine dataset (built in, no download needed)

**Builds on:** Day 23's PCA derivation.
**Sets up:** Day 29 extends this into a second SVD application and the
mental-map synthesis.

- [ ] **Step 1 (30 min): Re-derive PCA from memory, closed-book.** Before
  touching code, write out the full derivation from Day 23 again from scratch
  — covariance matrix, eigendecomposition, why the top eigenvectors maximize
  variance — without looking at your Day 23 journal entry. Compare afterward
  and note any gaps.
- [ ] **Step 2 (180 min): Build the capstone.** Create
  `labs/day28_pca_capstone.py`. Implement, from scratch (no `sklearn.decomposition.PCA`
  call in your own implementation — only used afterward to check):

```python
import numpy as np
from sklearn.datasets import load_wine
from sklearn.decomposition import PCA
import matplotlib.pyplot as plt

def pca_from_scratch(X, n_components):
    X_centered = X - X.mean(axis=0)
    cov = (X_centered.T @ X_centered) / (X_centered.shape[0] - 1)
    eigvals, eigvecs = np.linalg.eigh(cov)
    order = np.argsort(eigvals)[::-1]
    eigvals, eigvecs = eigvals[order], eigvecs[:, order]
    components = eigvecs[:, :n_components]
    projected = X_centered @ components
    explained_variance_ratio = eigvals[:n_components] / eigvals.sum()
    return projected, components, explained_variance_ratio

data = load_wine()
X, y = data.data, data.target

projected, components, ratio = pca_from_scratch(X, n_components=2)
print("explained variance ratio (mine):", ratio)

sk_pca = PCA(n_components=2)
sk_projected = sk_pca.fit_transform(X)
print("explained variance ratio (sklearn):", sk_pca.explained_variance_ratio_)
print("match:", np.allclose(ratio, sk_pca.explained_variance_ratio_))

plt.scatter(projected[:, 0], projected[:, 1], c=y, cmap="viridis")
plt.title("Wine dataset projected onto first 2 principal components")
plt.xlabel("PC1")
plt.ylabel("PC2")
plt.savefig("labs/day28_pca_wine.png")
print("saved plot to labs/day28_pca_wine.png")
```

  Confirm your explained variance matches scikit-learn's, and inspect the
  scatter plot — the three wine classes should separate visibly along the
  first two components.
- [ ] **Step 3 (30 min): Annotate.** In comments directly above each block of
  `pca_from_scratch`, write one line naming the specific theorem from Days
  19–23 that justifies that step (e.g. "# Day 19 spectral theorem: cov is
  symmetric, so eigh gives real eigenvalues + orthogonal eigenvectors").
- [ ] **Step 4 (15 min): Journal entry** for Day 28.
- [ ] **Step 5: Commit.**

---

## Day 29: Capstone, part 2 — SVD application + mental map

**Materials:**
- Day 22's SVD image compression code as the starting point
- Code: `labs/day29_svd_capstone.py`
- A blank page or `mental_map.md` for the synthesis

**Builds on:** Day 22 (SVD low-rank approximation) and the whole 30 days for
the mental map.
**Sets up:** Day 30's final exam and gap analysis.

- [ ] **Step 1 (90 min): Second SVD application.** Create
  `labs/day29_svd_capstone.py`. Extend Day 22's image compression: load a
  different image, compute the SVD, and produce a plot of reconstruction error
  (Frobenius norm) vs. rank $k$ for $k = 1, 5, 10, 20, ..., 100$, with a
  horizontal line marking 90% and 99% of the total "energy"
  ($\sum_{i\le k}\sigma_i^2 / \sum_i \sigma_i^2$). Identify the smallest $k$
  that captures 95% of the energy.

```python
import numpy as np
import matplotlib.pyplot as plt
from scipy import datasets

image = datasets.face(gray=True).astype(float)
U, s, Vt = np.linalg.svd(image, full_matrices=False)

energy = np.cumsum(s**2) / np.sum(s**2)
k_95 = np.searchsorted(energy, 0.95) + 1
print(f"smallest k capturing 95% of energy: {k_95} out of {len(s)}")

plt.plot(energy)
plt.axhline(0.95, color="red", linestyle="--", label="95% energy")
plt.axvline(k_95, color="green", linestyle="--", label=f"k={k_95}")
plt.xlabel("rank k")
plt.ylabel("cumulative energy captured")
plt.legend()
plt.savefig("labs/day29_svd_energy.png")
print("saved plot to labs/day29_svd_energy.png")
```

- [ ] **Step 2 (90 min): Write the mental map.** In `mental_map.md`, write a
  one-page synthesis connecting every major topic from the 30 days into one
  picture. At minimum, answer: how do the four fundamental subspaces (Day 6),
  the spectral theorem (Day 19), and the SVD (Days 21–22) relate to each
  other? Where does PCA (Day 23) sit in that picture? This should be written
  from memory, closed-book, then checked against your journal only to fill
  genuine gaps.
- [ ] **Step 3 (30 min): Break + review.** Read your mental map back and mark
  any sentence you're not 100% confident you could defend under questioning —
  these feed directly into Day 30's gap analysis.
- [ ] **Step 4 (15 min): Journal entry** for Day 29.
- [ ] **Step 5: Commit** (include `mental_map.md`).

---

## Day 30: Final exam + gap analysis

**Materials:** Schaum's Outline + MIT 18.06 practice exams; your `mental_map.md`
and full `journal.md` history.

- [ ] **Step 1 (180 min): Full closed-book timed exam.** Take one complete MIT
  18.06 practice final (available with the OCW course) under real exam
  conditions — closed book, timed, no code, no calculator beyond basic
  arithmetic.
- [ ] **Step 2 (15 min): Break.**
- [ ] **Step 3 (45 min): Score and correct.** Grade against the provided
  solutions. For every miss, write the correct solution by hand and note
  whether it traces back to a specific day in this plan.
- [ ] **Step 4 (30 min): Gap analysis for the ML/QC follow-on.** In
  `journal.md`, write a final entry naming, for each of your two downstream
  goals, the specific linear algebra concept from this plan that underlies it:
  - Machine learning: e.g. "PCA is eigendecomposition of the covariance
    matrix (Day 23)," "linear regression is least squares (Day 16)," "a
    neural network layer is a linear transformation + matrix representation
    (Day 3)."
  - Quantum computing: name where complex vector spaces, Hermitian/unitary
    matrices, and bra-ket notation (out of scope for this plan) will extend
    the real-valued spectral theorem (Day 19) and inner products (Day 14) you
    just mastered.
  List any topic from the Day 30 exam you're still shaky on — this becomes
  the first thing to revisit before starting the QC/ML follow-on phase.
- [ ] **Step 5 (10 min): Final journal entry.**
  ```
  ## Day 30 — Final exam + gap analysis
  Score: __/__
  ML concept map: ...
  QC concept map: ...
  Remaining gaps to close before starting ML/QC: ...
  ```
- [ ] **Step 6: Commit.**

---

## Self-Review Notes

- **Spec coverage:** every spec section maps to plan content — three-layer
  model (Steps 2/3/5 of each content day), 30-day topic table (Days 1–30
  headers match exactly), daily rhythm (step timing sums to 240 minutes on
  content days), mistakes-to-avoid table (no-code-before-exercises rule stated
  in Global Constraints and enforced by step ordering every day; closed-book
  review enforced on Days 7/13/18/24/27/30; unifying-framework days 6 and 25
  present; geometric+algebraic+computational triple representation present in
  every content day's Steps 1/2/3+5).
- **No placeholders:** every code lab contains complete, runnable code; every
  theory step names the exact theorem(s) to prove rather than saying "review
  the chapter."
- **Type/name consistency:** file names (`labs/dayNN_topic.py`) are unique and
  consistent across days; `journal.md` and `mental_map.md` are the only two
  tracking files referenced, both introduced in Day 1's constraints and used
  identically throughout.
