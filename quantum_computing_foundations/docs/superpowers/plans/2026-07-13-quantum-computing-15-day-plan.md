# 15-Day Foundations of Quantum Computing — Implementation Plan

> **For the learner:** This plan is executed by you, not by an agent — each
> day's "task" is a study session (proofs, problem sets, occasional code), not
> a code change made on your behalf. Work top to bottom, one day at a time,
> and check off steps as you complete them. Do not skip ahead: the review days
> (5, 9) and the Day 15 final exam depend on the journal entries and notes
> from the days before them. Saving your work (git add/commit, or however you
> track progress) is entirely your own responsibility — nothing in this plan
> runs git on your behalf, and this directory is not currently a git
> repository.

**Goal:** Reach derivation-level mastery of the University of Sussex
"Foundations of Quantum Computing" syllabus in 15 days (4 hours/day, ~60
hours), culminating in a closed-book practice exam spanning all 7 modules.

**Architecture:** Interleaved coverage (Option B from the design spec) —
linear-algebra formalism and its quantum application are fused within the
same day wherever the dependency allows, rather than a solid block of pure
math before any quantum content. Every day still maps to exactly one official
syllabus module. Two closed-book review days (5, 9) sit at natural phase
boundaries; Day 15 is a capstone module plus a full closed-book exam.

**Tech Stack:** Pencil-and-paper proofs and problem sets as the primary
medium. Python 3 + NumPy + Matplotlib for the three flagged light-code days
(4, 11, 14) — deliberately kept to NumPy rather than a quantum SDK (e.g.
Qiskit) so there's no framework to install/learn; each code day builds the
relevant operators (state vectors, unitaries, tensor products) directly from
matrices, which doubles as a second, executable check on the same day's hand
derivations.

## Global Constraints

- 4-hour daily budget. If a step overruns, note it in the journal and move
  on — the review days exist to catch up, not the daily schedule.
- Math-first: every day's theory/proof and problem-set steps come before any
  code step. Code never substitutes for a hand derivation; it verifies one
  that was already worked out on paper.
- Code appears only on Days 4, 11, and 14 (NumPy + Matplotlib). Run
  `pip install numpy matplotlib` once, before Day 4.
- Days 5 and 9 are closed-book review days: no new primer, no new material.
  Day 15's exam is closed-book and timed (~2 hours suggested).
- No physical-qubit-hardware content anywhere in the plan — this module is
  assessed on the CS/math model (per the design spec's out-of-scope section).
- Primer references below point to the *topic* covered in each recommended
  text (Yanofsky & Mannucci's *Quantum Computing for Computer Scientists* for
  narrative/primer reading; Nielsen & Chuang's *Quantum Computation and
  Quantum Information* as the field's canonical reference; Ronald de Wolf's
  *Quantum Computing: Lecture Notes* as a free, rigorous supplement) rather
  than exact page/exercise numbers, since those drift across editions/
  revisions — locate the matching section via each text's table of contents.
  Every problem in this plan is fully self-contained (stated in full, with
  enough given data to solve and check it), so the primer reading is for
  context and alternative explanations, not a dependency for completing the
  day's problem set.
- Journal file: `quantum_computing_foundations/journal.md`, one entry
  appended per day. Written proofs/problem-set answers go in
  `quantum_computing_foundations/notes/dayNN_<topic>.md`, one file per day.

## Directory Layout

Built up incrementally across the 15 days:

```
quantum_computing_foundations/
  journal.md
  notes/
    day01_boolean_reversible.md
    day02_complexity_randomized.md
    day03_complex_vector_spaces.md
    day04_normal_matrices_bloch.md
    day05_review.md
    day06_measurement_density_matrices.md
    day07_multiqubit_entanglement.md
    day08_deutsch_jozsa.md
    day09_review.md
    day10_bernstein_vazirani_simon.md
    day11_grovers.md
    day12_grover_optimality.md
    day13_number_theory_qft.md
    day14_qpe_shors.md
    day15_beyond_and_exam.md
  code/
    day04_bloch_sphere.py
    day11_grover_simulation.py
    day14_shors_qpe_simulation.py
```

---

## Day 1: Boolean logic & reversible computation (Module 1a)

**Materials:** Yanofsky & Mannucci's chapter on Boolean circuits and
reversible gates; any standard reference on Landauer's principle.

**Builds on:** nothing (Day 1).
**Sets up:** Day 4 reuses the ancilla/garbage-bit pattern from Step 2 when
building single-qubit circuits; Day 15's BQP discussion assumes this
classical circuit vocabulary.

- [ ] **Step 1 (20 min): Primer.** Read the recommended chapter's coverage of
  Boolean gates (AND/OR/NOT/NAND) and reversible gates (a gate on $n$ bits is
  reversible iff its function $\{0,1\}^n \to \{0,1\}^n$ is a bijection). In
  `notes/day01_boolean_reversible.md`, write the definitions of CNOT$(a,b) =
  (a, a\oplus b)$ and Toffoli/CCNOT$(a,b,c) = (a, b, c \oplus (a \wedge b))$
  in your own words.

- [ ] **Step 2 (50 min): Reversibility proofs.** In your notes file, solve:
  1. Write truth tables for CNOT and Toffoli; verify each is its own inverse
     (applying it twice returns the identity on all inputs).
  2. Using only a Toffoli gate with a fresh ancilla bit fixed at $0$, show
     Toffoli$(a,b,0) = (a,b,a\wedge b)$ implements a *reversible* AND: $a,b$
     pass through unchanged and $a \wedge b$ appears on the ancilla line.
  3. Show Toffoli$(1,1,c) = (1,1,\neg c)$ — i.e. fixing both control bits to
     $1$ turns Toffoli into NOT on the third line. Conclude that "Toffoli +
     constant ancilla bits" alone realizes AND and NOT, and therefore (via De
     Morgan's laws, since OR$(a,b) = \neg(\neg a \wedge \neg b)$) realizes a
     universal classical gate set.
  4. Construct a reversible circuit (Toffoli/CNOT/NOT only) computing the
     3-bit XOR $a \oplus b \oplus c$. Track exactly which output lines are
     "garbage" (extra values you must keep, not erase, to stay reversible).

- [ ] **Step 3 (60 min): Universality & garbage bits.** Solve:
  5. Sketch a proof that any classical circuit built from AND/OR/NOT with $g$
     gates can be converted to a reversible circuit using $O(g)$ Toffoli
     gates plus $O(g)$ fresh ancilla bits: replace each AND/OR gate with its
     Toffoli/De-Morgan equivalent from Step 2.3, feeding a fresh $0$-ancilla
     each time, and keep every intermediate value as a garbage output.
  6. Build a reversible full adder: given inputs $(a, b, c_{in})$, produce
     $(\text{sum}, \text{carry})$ using Toffoli/CNOT gates. Write out the
     circuit and explicitly label which of the output lines are garbage
     versus the two you actually wanted.

- [ ] **Step 4 (30 min): Landauer's principle.** Solve:
  7. State Landauer's principle: erasing one bit of information (a
     many-to-one, logically irreversible map) dissipates at least $kT\ln 2$
     of energy. Compute this bound numerically at room temperature
     ($T=300\text{K}$, $k=1.38\times10^{-23}\text{ J/K}$).
  8. Explain, referencing Step 3's garbage-bit construction, why a
     Toffoli-based reversible circuit that *keeps* its garbage bits (rather
     than overwriting/erasing them) is not bound by Landauer's limit per
     erasure the way a NAND-based irreversible circuit is — this is the
     physical motivation for caring about reversible computing before any
     mention of quantum mechanics.

- [ ] **Step 5 (20 min): Journal entry.** Append to `journal.md`:
  ```
  ## Day 1 — Boolean logic & reversible computation
  Key idea in my own words: ...
  What confused me: ...
  ```
  Save your work however you track progress.

---

## Day 2: Computational complexity & randomized computation (Module 1b)

**Materials:** Yanofsky & Mannucci's or de Wolf's coverage of complexity
classes (P, NP, BPP) and randomized algorithms; any reference covering the
Chernoff/Hoeffding bound.

**Builds on:** nothing new (independent of Day 1's content, same module).
**Sets up:** Problem 5 below is a randomized-algorithm warm-up for the exact
promise problem Day 8 solves quantumly (Deutsch–Jozsa); Day 15 revisits BPP
directly when defining BQP.

- [ ] **Step 1 (20 min): Primer.** Read the recommended coverage of P, NP,
  and BPP. In `notes/day02_complexity_randomized.md`, write definitions: P =
  languages decidable by a deterministic poly-time algorithm; BPP =
  languages decidable by a probabilistic poly-time algorithm with two-sided
  error $\le 1/3$ on every input.

- [ ] **Step 2 (30 min): Basic containments.** Solve:
  1. Prove $P \subseteq BPP$ (a deterministic algorithm is a special case of
     a probabilistic one with error $0$).
  2. Explain why a Las Vegas algorithm (always correct, randomized *running
     time*) with expected poly time is not automatically the same as a fixed
     poly-time-bounded BPP algorithm — what happens if you truncate a Las
     Vegas algorithm at a fixed time bound and it hasn't finished?

- [ ] **Step 3 (50 min): Error amplification.** Solve:
  3. A BPP algorithm has two-sided error $\le 1/3$ (i.e. it is correct with
     probability $\ge 2/3$ on every input). Using the Chernoff/Hoeffding
     bound for a sum of $k$ independent Bernoulli-type trials each correct
     with probability $\ge 2/3$, derive that running the algorithm $k$ times
     independently and taking the majority answer is wrong with probability
     at most $e^{-ck}$ for some constant $c>0$. Work out $c$ explicitly from
     the Hoeffding inequality (the trials' mean is bounded away from $1/2$
     by a constant gap of $1/6$).
  4. Compute how large $k$ must be to drive the error probability below
     $2^{-20}$, using your bound from Step 3.3.

- [ ] **Step 4 (40 min): Randomized promise-problem warm-up.** Solve:
  5. Consider a black-box function $f:\{0,1\}^n \to \{0,1\}$ promised to be
     either the constant-$0$ function or *balanced* (exactly half of all
     $2^n$ inputs map to $1$). Design a randomized classical algorithm that
     queries $f$ at random points and decides which case holds. Show that
     after $m$ queries all returning $0$, the probability that a balanced
     $f$ would have produced this by chance is at most $2^{-m}$ — so $m=k$
     random queries give confidence $1-2^{-k}$. (Keep this result — Day 8
     solves the exact same promise problem with a single quantum query and
     zero error, and the comparison is the point.)

- [ ] **Step 5 (20 min): Well-posed speedup claims + journal.** Solve:
  6. Explain in one paragraph why the informal claim "a quantum computer
     solved X faster than a classical laptop's program" is not, by itself, a
     well-posed complexity statement, and rewrite it using P/BPP language
     (e.g. "no known/possible poly-time classical algorithm, in P or BPP,
     solves X, while a poly-size quantum circuit does" — you'll make this
     fully precise with BQP on Day 15). Append the Day 2 journal entry.

---

## Day 3: Complex vector spaces & the qubit (Module 2a)

**Materials:** Yanofsky & Mannucci's or de Wolf's coverage of complex vector
spaces, Hermitian adjoints, unitary operators, and bra-ket notation. This is
the content your linear algebra plan deliberately deferred — built from
scratch here.

**Builds on:** nothing formally required, but reuses proof habits from the
completed linear-algebra plan (inner products, adjoints), now over $\mathbb{C}$
instead of $\mathbb{R}$.
**Sets up:** Day 4 needs the Hermitian-adjoint and unitary definitions from
here to state the spectral theorem for normal operators.

- [ ] **Step 1 (25 min): Primer.** Read the recommended coverage of complex
  vector spaces and bra-ket notation. In `notes/day03_complex_vector_spaces.md`,
  write: the inner product on $\mathbb{C}^n$, $\langle v, w\rangle = \sum_i
  v_i^* w_i$; the Hermitian adjoint of a matrix $A$, $A^\dagger =
  (\bar{A})^T$; a unitary matrix $U$ satisfies $U^\dagger U = U U^\dagger =
  I$; bra-ket notation $|\psi\rangle$ (column vector), $\langle\psi| =
  |\psi\rangle^\dagger$ (its conjugate-transpose row vector).

- [ ] **Step 2 (40 min): Inner product & adjoint proofs.** Solve:
  1. Verify $\langle\cdot,\cdot\rangle$ on $\mathbb{C}^n$ satisfies conjugate
     symmetry ($\langle v,w\rangle = \langle w,v\rangle^*$), linearity in the
     second argument, and positive-definiteness ($\langle v,v\rangle \ge 0$,
     $=0$ iff $v=0$).
  2. Given $A = \begin{pmatrix}1 & i\\ 2-i & 3\end{pmatrix}$, compute
     $A^\dagger$ explicitly, then verify $(A^\dagger)^\dagger = A$.

- [ ] **Step 3 (45 min): Unitary matrices.** Solve:
  3. Prove: $U$ is unitary iff its columns form an orthonormal basis of
     $\mathbb{C}^n$ (iff $U$ preserves inner products: $\langle Uv, Uw\rangle
     = \langle v,w\rangle$ for all $v,w$).
  4. Prove that every eigenvalue of a unitary matrix has modulus $1$ (use
     $U^\dagger U = I$ and the eigenvector equation $Uv=\lambda v$, taking
     norms of both sides).

- [ ] **Step 4 (40 min): The qubit.** Define a qubit as a normalized vector
  $|\psi\rangle = \alpha|0\rangle + \beta|1\rangle \in \mathbb{C}^2$ with
  $|\alpha|^2+|\beta|^2=1$, in the standard orthonormal basis
  $\{|0\rangle,|1\rangle\}$. Solve:
  5. Given $|\psi\rangle = \frac{3}{5}|0\rangle + \frac{4i}{5}|1\rangle$,
     verify it is normalized by computing $\langle\psi|\psi\rangle$
     explicitly.
  6. Compute the outer product $|0\rangle\langle1|$ as a $2\times2$ matrix,
     then verify the completeness relation $|0\rangle\langle0| +
     |1\rangle\langle1| = I$ by direct matrix addition.

- [ ] **Step 5 (10 min): Journal entry.** Append the Day 3 entry to
  `journal.md`.

---

## Day 4: Normal matrices, spectral theorem, single-qubit unitaries, Bloch sphere (Modules 2b + 3a) — code day

**Materials:** Yanofsky & Mannucci's or Nielsen & Chuang's coverage of normal
matrices / the spectral theorem, single-qubit gates (Pauli matrices,
Hadamard), and the Bloch sphere.

**Builds on:** Day 3's Hermitian-adjoint and unitary definitions.
**Sets up:** Day 6 completes the single-qubit-gate picture (arbitrary
rotations); Day 7 tensors these single-qubit gates into multi-qubit ones.

- [ ] **Step 1 (25 min): Primer + normal-matrix definition.** Read the
  recommended coverage of normal matrices and the spectral theorem. In
  `notes/day04_normal_matrices_bloch.md`, write: $A$ is *normal* iff $AA^\dagger
  = A^\dagger A$; Hermitian ($A=A^\dagger$) and unitary matrices are both
  special cases of normal. Spectral theorem for normal operators: $A$ is
  normal iff $A = UDU^\dagger$ for some unitary $U$ and diagonal $D$ (i.e.
  $A$ is unitarily diagonalizable with an orthonormal eigenbasis).

- [ ] **Step 2 (35 min): Normality proofs.** Solve:
  1. Prove Hermitian matrices are normal, and that a Hermitian matrix's
     eigenvalues are always real (use $A=A^\dagger$ in the eigenvector
     equation and take the inner product with the eigenvector).
  2. Prove unitary matrices are normal (immediate from $U^\dagger U = UU^\dagger
     = I$), reconnecting to Day 3 Problem 4 via the spectral theorem: the
     diagonal entries of $D$ *are* $A$'s eigenvalues, so "eigenvalues have
     modulus 1" and "unitarily diagonalizable with those eigenvalues on the
     diagonal" are the same fact stated two ways.

- [ ] **Step 3 (50 min): Pauli matrices & Hadamard from first principles.**
  The Pauli matrices are $X=\begin{pmatrix}0&1\\1&0\end{pmatrix}$,
  $Y=\begin{pmatrix}0&-i\\i&0\end{pmatrix}$,
  $Z=\begin{pmatrix}1&0\\0&-1\end{pmatrix}$, and Hadamard is
  $H=\frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}$. Solve:
  3. Verify each of $X,Y,Z$ is both Hermitian and unitary (hence an
     involution: $X^2=Y^2=Z^2=I$). Find each one's eigenvalues (they must be
     $\pm1$, by Step 2.1) and eigenvectors.
  4. Verify the spectral theorem directly for $H$: find its eigenvalues and
     eigenvectors explicitly, then write $H = UDU^\dagger$ with your
     eigenvectors as the columns of $U$ and confirm by direct matrix
     multiplication that this reconstructs $H$.

- [ ] **Step 4 (30 min): Bloch sphere geometry.** Any single-qubit pure state
  can be written $|\psi\rangle = \cos(\theta/2)|0\rangle +
  e^{i\varphi}\sin(\theta/2)|1\rangle$, a point on the unit sphere with
  spherical coordinates $(\theta,\varphi)$. Solve:
  5. Compute the Bloch coordinates of $|0\rangle$, $|1\rangle$, and
     $H|0\rangle$.
  6. Predict (in words, from the matrix form of $X$) what applying $X$ does
     to a general Bloch vector — you'll verify this numerically in the code
     step below.

- [ ] **Step 5 (40 min): Code — Bloch sphere verification.** Create
  `quantum_computing_foundations/code/day04_bloch_sphere.py`:

```python
import numpy as np

def bloch_coords(psi):
    """psi: length-2 complex numpy array, normalized. Returns (x, y, z)."""
    a, b = psi
    x = 2 * np.real(np.conj(a) * b)
    y = 2 * np.imag(np.conj(a) * b)
    z = np.abs(a) ** 2 - np.abs(b) ** 2
    return (x, y, z)

X = np.array([[0, 1], [1, 0]], dtype=complex)
H = (1 / np.sqrt(2)) * np.array([[1, 1], [1, -1]], dtype=complex)

zero = np.array([1, 0], dtype=complex)
one = np.array([0, 1], dtype=complex)
plus = H @ zero

print("|0>:", bloch_coords(zero))
print("|1>:", bloch_coords(one))
print("H|0> (|+>):", bloch_coords(plus))

psi = np.array([0.6, 0.8j], dtype=complex)  # already normalized: 0.6^2+0.8^2=1
print("psi:", bloch_coords(psi))
print("X|psi>:", bloch_coords(X @ psi))
```

Run:
```bash
cd quantum_computing_foundations
python3 code/day04_bloch_sphere.py
```
Expected output: `|0>` at `(0,0,1)`, `|1>` at `(0,0,-1)`, `H|0>` at
`(1,0,0)`. For the last two lines, confirm that $X$ fixes the $x$-coordinate
and flips the sign of the $y$- and $z$-coordinates — i.e. $X$ acts as a
$180°$ rotation about the Bloch-sphere $x$-axis. Write this confirmation, and
whether it matched your Step 4.6 prediction, in your notes file.

- [ ] **Step 6 (10 min): Journal entry.** Append the Day 4 entry to
  `journal.md`.

---

## Day 5: Review — Days 1–4 (closed-book)

**Materials:** none — this is a closed-book review day, no new primer.

**Builds on:** Days 1–4 in full.
**Sets up:** Day 6 assumes every item below is solid before moving on.

- [ ] **Step 1 (90 min): Closed-book re-derivation.** Without looking at your
  notes, write full answers in `notes/day05_review.md` to:
  1. Prove Toffoli + constant ancilla bits is universal for reversible
     classical computation (Day 1, Steps 2–3).
  2. State BPP and prove that majority-vote repetition amplifies its success
     probability exponentially (Day 2, Step 3).
  3. State and prove the spectral theorem for normal operators in the
     $2\times2$ case, applied to $H$ (Day 4, Step 3.4).
  4. Derive the matrix forms of $X, Y, Z, H$ from their defining properties
     (unitary + Hermitian/involution, eigenvalues $\pm1$) without looking
     them up.
  5. State Landauer's principle and its connection to reversible gates
     (Day 1, Step 4).

- [ ] **Step 2 (60 min): Grade & correct.** Check your Step 1 answers against
  your Day 1–4 notes files. For anything wrong or incomplete, rewrite the
  correct version in `notes/day05_review.md` immediately below your original
  attempt (don't overwrite it — the gap itself is useful data for the Day 15
  gap analysis).

- [ ] **Step 3 (30 min): Journal entry.** Append to `journal.md`: which of
  the five items above was solid on the first attempt, and which needed
  correction, and why (mismatched definition, forgotten step, arithmetic
  slip, etc.).

---

## Day 6: Measurement postulate, Born rule, density matrices, completing single-qubit unitaries (Modules 2c + 3b)

**Materials:** Yanofsky & Mannucci's or Nielsen & Chuang's coverage of the
measurement postulate, density matrices, and single-qubit gate
universality/Euler decomposition.

**Builds on:** Day 4's Pauli/Hadamard matrices and Bloch sphere.
**Sets up:** Day 7 needs the measurement postulate to discuss what
"entangled" implies about measurement outcomes.

- [ ] **Step 1 (20 min): Primer.** Read the recommended coverage of the
  measurement postulate and density matrices. In
  `notes/day06_measurement_density_matrices.md`, write the Born rule for a
  projective measurement in an orthonormal basis $\{|e_i\rangle\}$: outcome
  $i$ occurs with probability $|\langle e_i|\psi\rangle|^2$, and the state
  collapses to $|e_i\rangle$.

- [ ] **Step 2 (35 min): Born rule & basis-dependence.** Solve:
  1. For $|\psi\rangle = \frac{3}{5}|0\rangle + \frac{4i}{5}|1\rangle$,
     compute the measurement probabilities in the standard basis and verify
     they sum to $1$.
  2. Let $|+\rangle = \frac{1}{\sqrt2}(|0\rangle+|1\rangle)$ and $|-\rangle =
     \frac{1}{\sqrt2}(|0\rangle-|1\rangle)$. Measuring $|+\rangle$ in the
     standard basis gives a $50/50$ split. Compute $|\langle+|+\rangle|^2$
     and $|\langle-|+\rangle|^2$ to show that measuring $|+\rangle$ in the
     $\{|+\rangle,|-\rangle\}$ basis instead gives a deterministic outcome —
     the same physical state, different measurement basis, different
     outcome statistics.

- [ ] **Step 3 (45 min): Density matrices.** For a pure state, $\rho =
  |\psi\rangle\langle\psi|$. Solve:
  3. Prove $\text{Tr}(\rho)=1$, $\rho^\dagger=\rho$, and $\rho$ is positive
     semidefinite, for any normalized $|\psi\rangle$.
  4. Prove $\rho$ has eigenvalue $1$ (eigenvector $|\psi\rangle$ itself) and
     $0$ on everything orthogonal to it — i.e. $\rho$ is rank $1$. This is
     the algebraic signature of a *pure* state (contrast: a *mixed* state's
     density matrix has more than one nonzero eigenvalue).
  5. Prove $\text{Tr}(\rho O) = \langle\psi|O|\psi\rangle$ for any operator
     $O$ (the expectation value of observable $O$ in state $|\psi\rangle$),
     by direct trace computation.

- [ ] **Step 4 (40 min): Completing single-qubit unitaries.** Any single-qubit
  unitary can be written (up to an overall phase) as a product of rotations
  $R_z(\beta)R_y(\theta)R_z(\delta)$. Solve:
  6. Given $R_z(\theta) = \begin{pmatrix}e^{-i\theta/2}&0\\0&e^{i\theta/2}
     \end{pmatrix}$, verify it is unitary, and compute $R_z(\pi/2)|0\rangle$
     explicitly.
  7. State (without proving the full Solovay–Kitaev theorem) why a small
     fixed gate set such as $\{H,T\}$ can approximate any single-qubit
     unitary to arbitrary precision, and why this matters practically
     (compiling an arbitrary rotation into a small universal gate set).

- [ ] **Step 5 (10 min): Journal entry.** Append the Day 6 entry to
  `journal.md`.

---

## Day 7: Multi-qubit states, tensor products, entanglement, no-cloning (Module 3c)

**Materials:** Yanofsky & Mannucci's or Nielsen & Chuang's coverage of tensor
products, entanglement, Bell states, and the no-cloning theorem.

**Builds on:** Day 6's measurement postulate; Day 4's single-qubit gates
(embedded into the joint space via tensor product here).
**Sets up:** Day 8 needs the tensor-product formalism to state the
Deutsch–Jozsa oracle acting on two registers.

- [ ] **Step 1 (25 min): Primer + tensor product.** Read the recommended
  coverage of tensor products. In `notes/day07_multiqubit_entanglement.md`,
  write: the joint state space of two qubits is $\mathbb{C}^2\otimes\mathbb{C}^2
  \cong \mathbb{C}^4$ with basis $\{|00\rangle,|01\rangle,|10\rangle,
  |11\rangle\}$; a gate $A$ acting on qubit 1 alone and $B$ on qubit 2 alone
  embeds into the joint space as the Kronecker product $A\otimes B$.

- [ ] **Step 2 (45 min): Bell-state construction.** Solve:
  1. Compute $(H\otimes I)|00\rangle$ by tensor-expanding $H|0\rangle$ and
     $I|0\rangle$ separately, then tensoring the results. Confirm you get
     $\frac{1}{\sqrt2}(|00\rangle+|10\rangle)$.
  2. Apply CNOT (control = qubit 1, target = qubit 2) to that result.
     Confirm you get $|\Phi^+\rangle = \frac{1}{\sqrt2}(|00\rangle+
     |11\rangle)$ — the standard Bell-state preparation circuit.

- [ ] **Step 3 (45 min): Entanglement proof.** Solve:
  3. Prove $|\Phi^+\rangle$ is not separable: suppose
     $|\Phi^+\rangle = (a|0\rangle+b|1\rangle)\otimes(c|0\rangle+d|1\rangle)
     = ac|00\rangle+ad|01\rangle+bc|10\rangle+bd|11\rangle$. Matching
     coefficients to $(\frac{1}{\sqrt2},0,0,\frac{1}{\sqrt2})$ forces $ad=0$
     and $bc=0$ while $ac\ne0$ and $bd\ne0$. Show this is contradictory
     (case on $a=0$ vs. $d=0$, etc.) — hence no such $a,b,c,d$ exist.
  4. Define the reduced density matrix of qubit 1 via the partial trace,
     $\rho_1 = \text{Tr}_2(|\Phi^+\rangle\langle\Phi^+|)$. Compute it
     explicitly and show $\rho_1 = I/2$ (maximally mixed) — the signature of
     entanglement: a pure joint state whose single-qubit marginal is mixed.

- [ ] **Step 4 (35 min): No-cloning theorem.** Solve:
  5. Write the full proof: assume a unitary $U$ exists with $U(|\psi\rangle
     \otimes|0\rangle) = |\psi\rangle\otimes|\psi\rangle$ for *every*
     single-qubit $|\psi\rangle$. Apply this assumption to $|0\rangle$ and
     $|1\rangle$ individually (trivially consistent), then to $|+\rangle =
     \frac{1}{\sqrt2}(|0\rangle+|1\rangle)$ via *linearity* of $U$: compute
     $U(|+\rangle\otimes|0\rangle)$ by linearity from the $|0\rangle,
     |1\rangle$ cases, and show the result is not equal to $|+\rangle\otimes
     |+\rangle$ — contradiction. Conclude no universal cloning unitary can
     exist.
  6. Compute the Kronecker product $X\otimes Z$ explicitly as a $4\times4$
     matrix and verify it is unitary.

- [ ] **Step 5 (10 min): Journal entry.** Append the Day 7 entry to
  `journal.md`.

---

## Day 8: Quantum parallelism (correctly stated) & Deutsch–Jozsa (Module 4a)

**Materials:** Yanofsky & Mannucci's or de Wolf's coverage of the
Deutsch–Jozsa algorithm and quantum query complexity.

**Builds on:** Day 7's tensor-product/multi-qubit formalism; Day 2's
randomized classical solution to the same promise problem.
**Sets up:** Day 10 generalizes today's phase-kickback mechanism to
Bernstein–Vazirani and Simon's algorithm.

- [ ] **Step 1 (25 min): Primer + debunking quantum parallelism.** Read the
  recommended coverage of Deutsch–Jozsa. In `notes/day08_deutsch_jozsa.md`,
  write a one-paragraph correction of the common misconception that
  "quantum parallelism" means computing $f(x)$ for all $x$ simultaneously
  *and reading them all out*: by the no-cloning theorem (Day 7) and the
  measurement postulate (Day 6), a superposition $\sum_x|x\rangle|f(x)\rangle$
  gives you exactly *one* $(x,f(x))$ pair upon measurement, chosen randomly —
  the actual computational leverage comes from *interference* among the
  branches when further unitaries (Hadamards) are applied before that
  measurement.

- [ ] **Step 2 (30 min): Phase kickback.** The oracle acts as $U_f|x\rangle
  |y\rangle = |x\rangle|y\oplus f(x)\rangle$. Solve:
  1. Let $|-\rangle = \frac{1}{\sqrt2}(|0\rangle-|1\rangle)$. Show
     $U_f|x\rangle|-\rangle = (-1)^{f(x)}|x\rangle|-\rangle$ by direct
     computation, casing on $f(x)=0$ and $f(x)=1$ separately.

- [ ] **Step 3 (50 min): Deutsch–Jozsa, $n=1$ by hand.** The problem: $f:
  \{0,1\}^n\to\{0,1\}$ is promised constant or balanced; determine which
  with one oracle query. Solve:
  2. Work through the full circuit ($H$ on the input register, $|-\rangle$
     on the output register via $H$ on $|1\rangle$, apply $U_f$, apply $H$
     again to the input register, measure) step by step for $n=1$, once for
     a constant $f\equiv0$ and once for a balanced $f(x)=x$. Write out the
     exact state at every stage for both cases and confirm the final
     measurement distinguishes them with certainty.

- [ ] **Step 4 (40 min): Deutsch–Jozsa, general $n$.** Solve:
  3. Show that after the oracle and the second layer of $H^{\otimes n}$, the
     amplitude on $|0\rangle^{\otimes n}$ is $\frac{1}{2^n}\sum_x(-1)^{f(x)}$.
     Show this equals $\pm1$ if $f$ is constant (deterministic all-zero
     outcome) and exactly $0$ if $f$ is balanced (zero probability of the
     all-zero outcome) — hence one query, zero error, determines which case
     holds.
  4. Write the explicit comparison with Day 2 Problem 5: Deutsch–Jozsa needs
     exactly $1$ quantum query for a deterministic correct answer, versus
     $k$ classical randomized queries for confidence $1-2^{-k}$ (no fixed
     number of classical queries ever reaches *certainty* the way the
     quantum algorithm does).

- [ ] **Step 5 (15 min): Journal entry.** Append the Day 8 entry to
  `journal.md`.

---

## Day 9: Review — Days 6–8 (closed-book)

**Materials:** none — closed-book review day.

**Builds on:** Days 6–8.
**Sets up:** Day 10 assumes Deutsch–Jozsa's derivation is solid before
generalizing it.

- [ ] **Step 1 (75 min): Closed-book re-derivation.** Without notes, write
  full answers in `notes/day09_review.md` to:
  1. Prove $|\Phi^+\rangle$ is entangled (Day 7, Step 3.3).
  2. Compute the reduced density matrix of $|\Phi^+\rangle$'s first qubit
     and explain what it means that it's maximally mixed (Day 7, Step 3.4).
  3. Write the full no-cloning proof (Day 7, Step 4.5).
  4. Re-derive the Deutsch–Jozsa circuit and prove the general-$n$ amplitude
     formula from scratch (Day 8, Step 4.3).

- [ ] **Step 2 (45 min): Grade & correct.** Check against your Day 6–8 notes.
  Rewrite corrected versions below each attempt in `notes/day09_review.md`
  without erasing the original attempt.

- [ ] **Step 3 (30 min): Journal entry.** Append to `journal.md`: which items
  were solid, which needed correction, and why.

---

## Day 10: Bernstein–Vazirani & Simon's algorithm — unifying phase kickback (Module 4b)

**Materials:** Yanofsky & Mannucci's or de Wolf's coverage of the
Bernstein–Vazirani and Simon's algorithms.

**Builds on:** Day 8's phase-kickback identity and Deutsch–Jozsa circuit.
**Sets up:** Day 13's Quantum Fourier Transform is the general-$N$ version of
the Hadamard transform used identically in Days 8 and 10.

- [ ] **Step 1 (20 min): Primer.** Read the recommended coverage. In
  `notes/day10_bernstein_vazirani_simon.md`, write the Bernstein–Vazirani
  (BV) problem: oracle computes $f(x)=a\cdot x \bmod 2$ for a hidden $a\in
  \{0,1\}^n$; find $a$. Classically this needs $n$ queries (one bit of $a$
  at a time).

- [ ] **Step 2 (45 min): Bernstein–Vazirani derivation.** Solve:
  1. Using the identity $H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}
     \sum_y(-1)^{x\cdot y}|y\rangle$ twice (once to prepare the input
     superposition, once after the phase-kickback oracle call exactly as in
     Day 8), derive $H^{\otimes n}\sum_x(-1)^{a\cdot x}|x\rangle = |a\rangle$
     exactly — the same circuit as Deutsch–Jozsa, run on a different oracle,
     now returns $a$ with certainty in one query.
  2. Work a concrete $n=3$ example with $a=101$: trace the exact state at
     each circuit stage and confirm the final measurement gives $101$ with
     probability $1$.

- [ ] **Step 3 (50 min): Simon's algorithm.** Simon's problem: oracle $f:
  \{0,1\}^n\to\{0,1\}^n$ is promised 2-to-1 with $f(x)=f(y)$ iff $y=x\oplus
  s$ for a hidden $s\ne0$; find $s$. Solve:
  3. Explain why this promise ("2-to-1 with period $s$") is strictly
     stronger than Deutsch–Jozsa's constant/balanced promise.
  4. Sketch why, after querying the oracle into a second register and
     measuring that second register, the first register collapses to
     $\frac{1}{\sqrt2}(|x\rangle+|x\oplus s\rangle)$ for the observed
     outcome; then show that applying $H^{\otimes n}$ and computing the
     amplitude on each $y$ shows only $y$ with $y\cdot s = 0 \bmod 2$
     survive with nonzero amplitude — so a single run yields a random $y$
     satisfying that linear constraint.

- [ ] **Step 4 (30 min): Recovering $s$ via linear algebra over GF(2).**
  Solve:
  5. Choose $s = 1010$ (so $n=4$). Construct 3 concrete vectors $y_1,y_2,y_3$
     each satisfying $y_i\cdot s = 0 \bmod 2$ (pick any 3 linearly
     independent such vectors). Solve the resulting linear system mod 2 by
     Gaussian elimination (the same elimination technique from your linear
     algebra plan, now over $\mathbb{F}_2$) to recover $s$, and note that
     $n-1$ independent samples are needed in general to pin down $s$
     uniquely (up to the all-zero solution).

- [ ] **Step 5 (15 min): Unification + journal.** Solve:
  6. Write one paragraph explaining how Deutsch–Jozsa, Bernstein–Vazirani,
     and Simon's algorithm are all "the same circuit" (Hadamard — oracle
     phase-kickback — Hadamard) applied to oracles with different hidden
     structure. Append the Day 10 journal entry.

---

## Day 11: Grover's algorithm & amplitude amplification (Module 5a) — code day

**Materials:** Yanofsky & Mannucci's or Nielsen & Chuang's coverage of
Grover's algorithm and amplitude amplification.

**Builds on:** Day 4's single-qubit rotation/reflection intuition, now
applied in a 2D subspace of a much larger space.
**Sets up:** Day 12 proves this algorithm is optimal and generalizes it.

- [ ] **Step 1 (25 min): Primer + setup.** Read the recommended coverage. In
  `notes/day11_grovers.md`, write the unstructured search problem: given an
  oracle marking $M$ of $N=2^n$ items as "good," find one, using as few
  oracle queries as possible (classically, $\Theta(N/M)$ are needed in
  expectation). Define $|good\rangle$ = uniform superposition over marked
  items, $|bad\rangle$ = uniform superposition over unmarked items — these
  span a real 2D subspace containing the uniform starting state $|s\rangle =
  \cos(\theta/2)|bad\rangle+\sin(\theta/2)|good\rangle$ where
  $\sin(\theta/2)=\sqrt{M/N}$.

- [ ] **Step 2 (40 min): Oracle reflection.** The oracle reflection is $O_f =
  I - 2\sum_{x\text{ good}}|x\rangle\langle x|$. Solve:
  1. Verify $O_f$ is unitary.
  2. Compute $O_f|good\rangle$ and $O_f|bad\rangle$ directly, and show $O_f$
     acts as a reflection about $|bad\rangle$ within the 2D $\{|good\rangle,
     |bad\rangle\}$ subspace.

- [ ] **Step 3 (40 min): Diffusion operator & the rotation.** The diffusion
  operator is $D = 2|s\rangle\langle s| - I$. Solve:
  3. Verify $D$ is unitary and show it reflects any vector in the 2D
     subspace about $|s\rangle$.
  4. Using the fact that the composition of two reflections at angle
     $\theta/2$ apart is a rotation by $\theta$, argue that $D\cdot O_f$,
     restricted to the 2D subspace, rotates $|s\rangle$ by angle $\theta$
     toward $|good\rangle$ on each application.

- [ ] **Step 4 (30 min): Iteration count.** Solve:
  5. For $N=16$, $M=1$, compute $\theta = 2\arcsin(1/4)$ explicitly (in
     radians), then compute the number of iterations $k$ that maximizes
     $\sin^2\!\big((2k+1)\theta/2\big)$ (the probability of measuring a good
     state after $k$ iterations). Compare this exact $k$ to the standard
     heuristic $k\approx\frac{\pi}{4}\sqrt{N/M}$.

- [ ] **Step 5 (45 min): Code — simulate a Grover instance.** Create
  `quantum_computing_foundations/code/day11_grover_simulation.py`:

```python
import numpy as np

N = 16          # 4-qubit search space
marked = 3      # the single marked index, 0-indexed

s = np.ones(N, dtype=complex) / np.sqrt(N)

def oracle(state, marked_index):
    out = state.copy()
    out[marked_index] *= -1
    return out

def diffusion(state):
    proj = np.vdot(s, state) * s  # <s|state> * s
    return 2 * proj - state

state = s.copy()
print(f"iteration 0: P(marked) = {abs(state[marked])**2:.4f}")
for k in range(1, 11):
    state = oracle(state, marked)
    state = diffusion(state)
    print(f"iteration {k}: P(marked) = {abs(state[marked])**2:.4f}")
```

Run:
```bash
cd quantum_computing_foundations
python3 code/day11_grover_simulation.py
```
Expected: the probability climbs toward $1$ over the first few iterations,
peaks near the iteration count you computed in Step 4.5, then *decreases*
again on further iterations (the well-known "overshoot" — Grover's
probability is periodic in the iteration count, not monotonically
increasing). Confirm the peak iteration in your printed output matches your
hand-computed value, and write the comparison in your notes file.

- [ ] **Step 6 (10 min): Journal entry.** Append the Day 11 entry to
  `journal.md`.

---

## Day 12: Grover's optimality (BBBV) & generalized amplitude amplification (Module 5b)

**Materials:** Nielsen & Chuang's or de Wolf's coverage of the
Bennett–Bernstein–Brassard–Vazirani (BBBV) lower bound and generalized
amplitude amplification.

**Builds on:** Day 11's rotation picture.
**Sets up:** nothing downstream directly, but the "well-posed lower bound"
habit reappears in Day 15's BQP discussion.

- [ ] **Step 1 (20 min): Primer.** Read the recommended coverage of the BBBV
  lower bound. In `notes/day12_grover_optimality.md`, state the theorem: any
  quantum algorithm making $T$ oracle queries finds a uniquely marked item
  among $N$ with probability $O(T^2/N)$ — so success probability bounded
  away from $0$ forces $T=\Omega(\sqrt N)$, meaning Grover's algorithm is
  optimal up to constant factors.

- [ ] **Step 2 (60 min): The hybrid-argument sketch.** This is a genuinely
  hard proof; the goal here is to understand its *structure*, not
  re-derive the full rigorous inequality chain (flagging explicitly: this is
  the boundary of rigor for this 15-day plan, a legitimate scope
  trade-off). Solve:
  1. Define $O_0$ = the oracle with no marked item, and $O_i$ = the oracle
     marking item $i$. Explain, in your own words, why comparing "the
     algorithm's quantum state after running against $O_0$" to "...against
     $O_i$" for every $i$, and bounding how much a *single* oracle query can
     possibly change that state (on average over $i$, since the algorithm
     doesn't know which $O_i$ it's facing), gives a way to bound how quickly
     the algorithm's output distribution can diverge from what it would
     output on $O_0$.
  2. State (without deriving) that each query changes the accumulated
     "distinguishing power" by at most $O(1/\sqrt N)$ on average, so after
     $T$ queries the total is $O(T/\sqrt N)$, and the success probability
     (which scales as the *square* of a distinguishing amplitude) is
     $O(T^2/N)$ — hence $T=\Omega(\sqrt N)$ for constant success
     probability.

- [ ] **Step 3 (50 min): Generalized amplitude amplification.** Solve:
  3. For a state-preparation unitary $A$ (replacing the uniform-superposition
     $H^{\otimes n}$) with $A|0\rangle = \sqrt p\,|good\rangle + \sqrt{1-p}\,
     |bad\rangle$ for some non-uniform "prior" $p$, derive the rotation
     angle $\theta = 2\arcsin(\sqrt p)$ by direct analogy with Day 11 Step
     4.5 (there, $p=M/N$).
  4. Given $M$ marked items among $N$ (assume $M$ is known), state the
     modified iteration count $k\approx\frac{\pi}{4}\sqrt{N/M}$, and explain
     in one sentence what changes if $M$ is *unknown* (you need either an
     estimate of $M$, e.g. via quantum counting, or a randomized/adaptive
     schedule over iteration counts) — no derivation required, this is a
     forward pointer only.

- [ ] **Step 4 (10 min): Journal entry.** Append the Day 12 entry to
  `journal.md`.

---

## Day 13: Number theory for Shor's algorithm & the Quantum Fourier Transform (Module 6a)

**Materials:** Yanofsky & Mannucci's or Nielsen & Chuang's coverage of
modular arithmetic, order-finding, continued fractions, and the Quantum
Fourier Transform.

**Builds on:** Day 10's Hadamard-transform mechanism (QFT generalizes it);
Day 2's number-theory-adjacent reasoning habits.
**Sets up:** Day 14 builds Quantum Phase Estimation directly on today's QFT,
then assembles Shor's algorithm from today's number theory.

- [ ] **Step 1 (25 min): Primer + modular arithmetic.** Read the recommended
  coverage of order-finding and Shor's reduction. In
  `notes/day13_number_theory_qft.md`, write: for $\gcd(a,N)=1$, the *order*
  of $a$ mod $N$ is the smallest $r$ with $a^r \equiv 1 \pmod N$. Euler's
  theorem: $a^{\varphi(N)}\equiv 1 \pmod N$, so $r \mid \varphi(N)$.

- [ ] **Step 2 (40 min): Order-finding examples.** Solve:
  1. Compute $\varphi(15)$, then compute the order of $2$ mod $15$ by
     listing powers of $2$ mod $15$ until you hit $1$, and verify it divides
     $\varphi(15)$.

- [ ] **Step 3 (45 min): Miller's reduction (factoring from order-finding).**
  Solve:
  2. Prove: if $r$ is the order of $a$ mod $N=pq$, $r$ is even, and
     $a^{r/2}\not\equiv-1\pmod N$, then $\gcd(a^{r/2}-1,\,N)$ is a nontrivial
     factor of $N$. (Sketch: $a^r\equiv1 \Rightarrow (a^{r/2}-1)(a^{r/2}+1)
     \equiv0\pmod N$; since $N\nmid(a^{r/2}-1)$ — as $r$ is the *smallest*
     such exponent, so $a^{r/2}\ne1$ — and $N\nmid(a^{r/2}+1)$ by
     assumption, $N$ must be split between the two factors, so their gcd
     with $N$ is nontrivial.)
  3. Work a full numeric example: $N=15$, $a=7$. Compute the order $r$ of
     $7$ mod $15$ by brute force, verify $r$ is even, compute
     $\gcd(7^{r/2}-1, 15)$, and confirm it is a nontrivial factor of $15$.
     (Keep your value of $r$ — Day 14 reuses this exact example.)

- [ ] **Step 4 (45 min): Quantum Fourier Transform.** $\text{QFT}|x\rangle =
  \frac{1}{\sqrt N}\sum_y e^{2\pi i xy/N}|y\rangle$ on an $N=2^n$-dimensional
  space. Solve:
  4. Derive the $n=2$ ($N=4$) QFT matrix explicitly: write out the
     $4\times4$ matrix with entries $\omega^{xy}/2$ where $\omega=e^{i\pi/2}
     =i$, and verify it is unitary by checking its columns are orthonormal.
  5. Show that QFT restricted to the special case where every coordinate is
     mod-2 (i.e. the group $(\mathbb{Z}_2)^n$ rather than $\mathbb{Z}_{2^n}$)
     reduces to exactly $H^{\otimes n}$ — the same transform used in Days 8
     and 10 is the $\mathbb{Z}_2^n$ special case of the QFT you're
     generalizing to today.

- [ ] **Step 5 (25 min): Continued fractions.** Solve:
  6. You're told a phase estimate of $0.6247$ and that the true denominator
     $r \le 10$. Run the continued-fraction expansion of $0.6247$ by hand
     (repeatedly take the integer part, then the reciprocal of the
     remainder) until you recover a fraction with denominator $\le10$.
     Confirm it recovers $5/8$ — i.e. the algorithm is robust to the kind of
     small numerical error a real phase-estimation measurement would
     produce.

- [ ] **Step 6 (10 min): Journal entry.** Append the Day 13 entry to
  `journal.md`.

---

## Day 14: Quantum Phase Estimation & Shor's algorithm assembly (Module 6b) — code day, heaviest day

**Materials:** Nielsen & Chuang's or Yanofsky & Mannucci's coverage of
Quantum Phase Estimation (QPE) and the full Shor's algorithm.

**Builds on:** Day 13's QFT and number theory in full; Day 8/10's
phase-kickback identity, generalized here.
**Sets up:** nothing downstream — this is the syllabus's heaviest single
day. If it overruns, continue into Day 15's morning before starting Module 7
(per the design spec's flagged buffer note).

- [ ] **Step 1 (20 min): Primer.** Read the recommended coverage of QPE. In
  `notes/day14_qpe_shors.md`, write the setup: given a unitary $U$ with
  eigenvector $|u\rangle$ and eigenvalue $e^{2\pi i\varphi}$, and $t$ ancilla
  qubits prepared in $|0\rangle^{\otimes t}$, QPE estimates $\varphi$ to $t$
  bits of precision using controlled-$U^{2^j}$ gates followed by an inverse
  QFT on the ancilla register.

- [ ] **Step 2 (45 min): QPE derivation.** Solve:
  1. Show that applying controlled-$U^{2^j}$ to $\frac{1}{\sqrt2}(|0\rangle+
     |1\rangle)$ (control) $\otimes|u\rangle$ (target) gives
     $\frac{1}{\sqrt2}(|0\rangle+e^{2\pi i\varphi 2^j}|1\rangle)\otimes
     |u\rangle$ — this is exactly Day 8 Step 2's phase-kickback identity,
     generalized from a $\pm1$ phase to an arbitrary phase $e^{2\pi i
     \varphi2^j}$.
  2. Show that after doing this for ancilla qubits $j=0,\dots,t-1$, the
     ancilla register (with the target register left in $|u\rangle$,
     unentangled) is in the state $\frac{1}{\sqrt{2^t}}\sum_x
     e^{2\pi i\varphi x}|x\rangle$ — recognize this as exactly the QFT of a
     state peaked at "$\varphi$," so applying the *inverse* QFT recovers
     (an estimate of) $\varphi$.

- [ ] **Step 3 (40 min): Assembling Shor's algorithm.** Solve:
  3. Using your Day 13 Step 3.3 result ($N=15$, $a=7$, order $r$ found by
     brute force), explain how QPE would be used in the real algorithm: run
     QPE on the modular-exponentiation unitary $U_a|y\rangle = |ay \bmod
     N\rangle$, whose eigenvalues encode $r$; QPE returns a phase estimate
     $\varphi\approx k/r$ for a random $k$; apply Day 13 Step 5's
     continued-fraction algorithm to $\varphi$ to recover $r$; apply Day 13
     Step 3.2's (Miller's) reduction to $r$ to recover a factor of $N$.
  4. Trace every step of this $N=15,a=7$ pipeline back to its originating
     derivation (QPE mechanism → today's Steps 1–2; continued fractions →
     Day 13 Step 5; Miller's reduction → Day 13 Step 3.2) — write this
     trace explicitly in your notes file. (This is the plan's "full
     traceability" success criterion, made concrete.)

- [ ] **Step 4 (55 min): Code — exact QPE + order-finding simulation.**
  Build the entire pipeline for $N=15$, $a=7$ as exact matrices (small
  enough to brute-force; no physical noise). Create
  `quantum_computing_foundations/code/day14_shors_qpe_simulation.py`:

```python
import numpy as np

N = 15
a = 7

# Work register: represent |y> for y in 0..N-1 as a length-N basis vector
# (this sidesteps needing ceil(log2(N)) qubits explicitly, since we only
# need the *permutation matrix* U_a|y> = |a*y mod N>, restricted to y
# coprime to N in practice, but defined on all of 0..N-1 here for simplicity).
def mod_mult_unitary(a, N):
    U = np.zeros((N, N))
    for y in range(N):
        U[(a * y) % N, y] = 1
    return U

U = mod_mult_unitary(a, N)

# Find the order r of a mod N classically, to build controlled-U^(2^j) exactly
# and to check the QPE output against (Day 13 Step 3.3's brute-force result).
r = 1
val = a % N
while val != 1:
    val = (val * a) % N
    r += 1
print(f"order of {a} mod {N}: r = {r}")

t = 6  # phase register precision (bits)
phase_dim = 2 ** t

# Build the full QPE state exactly: start in |1> on the work register
# (an eigenvector-supporting state; U_a's eigenvectors are combinations of
# {a^k mod N}, and starting from |1> after the full circuit yields a
# uniform mixture over k = 0..r-1's eigenphases, which is what a real
# circuit produces too when no single eigenvector is prepared).
work_dim = N
state = np.zeros(phase_dim * work_dim, dtype=complex)
work_start = 1  # |1> on the work register
for x in range(phase_dim):
    state[x * work_dim + work_start] = 1.0
state /= np.sqrt(phase_dim)

# Apply controlled-U^(2^j): for phase-register basis state |x>, apply U^x
# to the work register (this is exactly controlled-U^(2^j) for all j at once,
# since x's binary expansion picks out exactly which powers of 2 apply).
U_powers = {}
def U_power(k):
    if k not in U_powers:
        U_powers[k] = np.linalg.matrix_power(U, k)
    return U_powers[k]

new_state = np.zeros_like(state)
for x in range(phase_dim):
    Ux = U_power(x)
    block = state[x * work_dim:(x + 1) * work_dim]
    new_state[x * work_dim:(x + 1) * work_dim] = Ux @ block
state = new_state

# Inverse QFT on the phase register (work register is a spectator here).
def inverse_qft_matrix(dim):
    omega = np.exp(-2j * np.pi / dim)
    return np.array([[omega ** (x * y) for y in range(dim)] for x in range(dim)]) / np.sqrt(dim)

IQFT = inverse_qft_matrix(phase_dim)
state_reshaped = state.reshape(phase_dim, work_dim)
state_reshaped = IQFT @ state_reshaped
state = state_reshaped.reshape(-1)

# Measure the phase register: sum probability over the work register.
probs = np.sum(np.abs(state.reshape(phase_dim, work_dim)) ** 2, axis=1)
print("Top phase-register outcomes (x, probability, x/2^t):")
top = np.argsort(probs)[::-1][:8]
for x in sorted(top):
    print(f"  x={x:3d}  P={probs[x]:.4f}  x/2^t={x/phase_dim:.4f}  (expect near k/{r} for integer k)")
```

Run:
```bash
cd quantum_computing_foundations
python3 code/day14_shors_qpe_simulation.py
```
Expected: the printed order matches your Day 13 Step 3.3 hand computation,
and the high-probability phase-register outcomes cluster at $x/2^t$ values
close to $0/4, 1/4, 2/4, 3/4$ (i.e. multiples of $1/r = 1/4$) — the exact
numerical confirmation of the entire week's most complex derivation chain.
In your notes file, pick one high-probability outcome, run it through the
continued-fraction algorithm (Day 13 Step 5) to recover $r$, and confirm you
get $r=4$.

- [ ] **Step 5 (10 min): Journal entry.** Append the Day 14 entry to
  `journal.md`, noting whether this day overran its 4-hour budget and, if
  so, how much of Day 15's morning you needed to borrow.

---

## Day 15: Beyond discrete-time quantum computation + final exam (Module 7 + capstone)

**Materials:** Nielsen & Chuang's or de Wolf's coverage of BQP, the
adiabatic model, and quantum advantage claims.

**Builds on:** Day 2's BPP definition and error amplification; the full
15-day sequence for the final exam.
**Sets up:** nothing — this is the plan's terminal day.

- [ ] **Step 1 (35 min): BQP and the complexity landscape.** In
  `notes/day15_beyond_and_exam.md`, write: BQP (bounded-error quantum
  polynomial time) is the class of decision problems solvable by a
  poly-size quantum circuit family with two-sided error $\le1/3$,
  amplifiable exponentially by repeated trials + majority vote — the exact
  same Chernoff-bound argument from Day 2, now applied to quantum
  measurement outcomes instead of classical coin flips. Solve:
  1. Explain why $P\subseteq BPP\subseteq BQP$ (a classical circuit is a
     restricted case of a quantum one) and why $BQP\subseteq PSPACE$ (a
     quantum circuit's amplitudes can be computed exactly, in exponential
     time but only polynomial *space*, by direct simulation).
  2. State that whether $BQP\subseteq NP$ or $NP\subseteq BQP$ is a genuinely
     open problem — this is the "beyond provable" boundary the module title
     points at: some of the most basic relationships between these classes
     are not yet proven either way.

- [ ] **Step 2 (30 min): Adiabatic / continuous-time quantum computation.**
  Solve:
  3. State the adiabatic theorem informally: evolving a time-dependent
     Hamiltonian $H(t)$ slowly enough (relative to its instantaneous
     spectral gap) from an easy-to-prepare ground state keeps the system in
     its instantaneous ground state throughout, ending in the ground state
     of the final, problem-encoding Hamiltonian.
  4. State (without proof) that adiabatic quantum computation is known to be
     polynomially equivalent to the discrete gate-circuit model — so "beyond
     discrete-time" is a different *model*, not a more powerful one; any
     speedup available adiabatically is available (up to polynomial
     overhead) in the circuit model too.

- [ ] **Step 3 (25 min): Quantum advantage claims.** Solve:
  5. Explain what a random-circuit-sampling "quantum supremacy/advantage"
     claim actually asserts (a specific sampling task appears hard for
     specific classical hardware/algorithms) versus what it does *not*
     assert (that $BQP\supsetneq BPP$ has been proven — that remains open).
     Connect this explicitly back to Day 2 Step 5's discussion of what makes
     a speedup claim well-posed.

- [ ] **Step 4 (5 min): Open problems.** In one sentence each, state two open
  problems: (a) is $BQP=BPP$? (b) is integer factoring actually outside
  BPP, or might a not-yet-discovered classical algorithm match Shor's
  performance?

- [ ] **Step 5 (120 min, timed, closed-book): Final exam.** Set a timer for
  2 hours. Without any notes, solve all of the following in
  `notes/day15_beyond_and_exam.md`:
  1. Prove Toffoli + constant ancilla bits is universal for reversible
     computation (Day 1).
  2. State BPP and prove error amplification via the Chernoff bound
     (Day 2).
  3. State and prove the spectral theorem for normal operators in the
     $2\times2$ case, and derive the Pauli matrices' eigenvalues/eigenvectors
     from their defining properties (Days 3–4).
  4. Compute the Born-rule measurement probabilities for a given state in
     two different bases, and prove that a pure state's density matrix is
     rank 1 (Day 6).
  5. Prove the no-cloning theorem (Day 7).
  6. Derive the Deutsch–Jozsa amplitude formula for general $n$ and prove it
     distinguishes constant from balanced functions with certainty
     (Day 8).
  7. Derive the exact Bernstein–Vazirani result $H^{\otimes n}\sum_x
     (-1)^{a\cdot x}|x\rangle = |a\rangle$ (Day 10).
  8. Derive Grover's rotation angle $\theta$ and the optimal iteration count
     formula, and state the BBBV lower bound (Days 11–12).
  9. For $N=21$ (a new example, not $N=15$): choose a valid $a$ coprime to
     $21$, find its order $r$ by hand, and — assuming a QPE run returned a
     phase estimate near $k/r$ for some $k$ — walk through the full Shor's
     pipeline (continued fractions, Miller's reduction) to a nontrivial
     factor of $21$ (Days 13–14).
  10. State the containments $P\subseteq BPP\subseteq BQP\subseteq PSPACE$
      and explain which are proven and which (if any) are open in the other
      direction (Day 15).

- [ ] **Step 6 (40 min): Gap analysis.** Grade your Step 5 answers against
  the corresponding day's notes file. For every problem that was wrong,
  incomplete, or took noticeably longer than it should have, write down
  which day it traces back to, then re-derive that day's core result from
  scratch, closed-book, right now — before considering the plan complete.
  Append a final entry to `journal.md` summarizing which modules are solid
  and which need continued practice as the module's actual lectures/coursework
  proceed.
