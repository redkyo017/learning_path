# Structure & Label Inventory — quantum_computing_foundations (Task 1)

Raw per-day inventory generated 2026-08-05 from `content/`. Format per day:
line count, numbered heading map (`##`/`###` with line numbers), bold named
labels (Definition/Theorem/Lemma/Claim/etc. with line numbers), exercise
count (numbered-list items — includes numbered items outside the Exercises
section on review days), and a one-line worked-example note.

Label convention across the path: labels are NAMED, not numbered — bold
`**Claim:**` / `**Claim (phase kickback):**` / `**Theorem (BBBV, 1997).**`
plus `###` topic sub-headings. Days 10 and 11 have NO bold labels — their
citable anchors are `###` section names only.

Worked-example notes:
- day01: MAJ(a,b,c) via Toffoli + constant ancillas
- day02: Hoeffding bound valid but not tight for small k
- day03: U = (1/√2)[[1,i],[i,1]] unitary, modulus-1 eigenvalues 3 ways
- day04: spectral theorem on a normal-but-neither matrix A=[[1,1],[-1,1]]
- day05: (review day — no Worked example section; model answers instead)
- day06: density matrix of |+⟩ and its Born-rule statistics
- day07: CNOT·(H⊗I) generates all four Bell states from computational basis
- day08: full state-by-state Deutsch–Jozsa trace, n=1, f≡0 vs f(x)=x
- day09: (review day — model answers instead)
- day10: Bernstein–Vazirani n=3, a=101 traced state by state
- day11: exact Grover case N=4, M=1 (θ/2=30°)
- day12: generalized amplitude amplification reduces to Day 11 formula
- day13: full classical pipeline N=15, a=7
- day14: QPE outcome x=48/64 still recovers r=4 for N=15, a=7
- day15: (exam day — final exam + model answers instead)

---

## day01.md
lines:      296
### headings
3:## Learning objectives
15:## Reference material
23:## Theory
25:### Boolean gates and reversibility
43:### CNOT and Toffoli
65:### Building AND, OR, NOT reversibly
85:### Universality and garbage bits
106:### Landauer's principle
124:## Worked example
148:## Exercises
184:## Solutions
290:## Journal template
293:## Day 1 — Boolean logic & reversible computation
### named labels
126:**Claim:** Toffoli gates and constant ancillas can compute the majority
### exercises
12

## day02.md
lines:      491
### headings
3:## Learning objectives
23:## Reference material
33:## Theory
35:### Deterministic and probabilistic decision procedures
64:### $P \subseteq BPP$
79:### Las Vegas algorithms versus BPP
124:### Error amplification: the Chernoff/Hoeffding bound
212:### A randomized classical algorithm for the Deutsch–Jozsa promise problem
243:## Common misconceptions
288:## Worked example
332:## Exercises
365:## Solutions
485:## Journal template
488:## Day 2 — Computational complexity & randomized computation
### named labels
290:**Claim:** the Hoeffding bound derived above is *valid* but, as expected of
### exercises
8

## day03.md
lines:      371
### headings
3:## Learning objectives
21:## Reference material
36:## Theory
38:### Complex vector spaces, in one paragraph
50:### The complex inner product, and why conjugation is forced
92:### The Hermitian adjoint
118:### Unitary matrices
138:### Eigenvalues of unitary matrices have modulus 1
158:### The qubit
176:### Bra-ket notation, outer products, completeness
199:## Worked example
239:## Exercises
262:## Solutions
365:## Journal template
368:## Day 3 — Complex vector spaces & the qubit
### named labels
201:**Claim:** $U = \dfrac{1}{\sqrt2}\begin{pmatrix}1 & i\\ i & 1\end{pmatrix}$
### exercises
6

## day04.md
lines:      481
### headings
3:## Learning objectives
24:## Reference material
42:## Theory
44:### Normal matrices and the spectral theorem
104:### Hermitian matrices are normal, with real eigenvalues
125:### Unitary matrices are normal, and the spectral theorem recovers modulus-1 eigenvalues
152:### The Pauli matrices and the Hadamard matrix
177:### The Bloch sphere
225:## Worked example
291:## Exercises
320:## Solutions
444:## Code lab
475:## Journal template
478:## Day 4 — Normal matrices, spectral theorem, Bloch sphere
### named labels
233:**Claim:** $A = \begin{pmatrix}1&1\\-1&1\end{pmatrix}$ is normal, and its
### exercises
10

## day05.md
lines:      369
### headings
3:## Learning objectives
26:## How to use this review
44:## Review questions
62:## Model answers
64:### 1. Toffoli + ancilla universality for reversible computation
129:### 2. BPP and Chernoff-bound error amplification
177:### 3. Spectral theorem for normal $2\times2$ operators, applied to $H$
257:### 4. Deriving $X, Y, Z, H$ from their defining properties
330:### 5. Landauer's principle and reversible gates
362:## Journal template
365:## Day 5 — Review: Days 1–4 (closed-book)
### named labels
66:**Claim.** Toffoli gates, together with constant ancilla bits (extra bits
131:**Definition.** BPP (bounded-error probabilistic polynomial time) is the
138:**Claim.** Running a BPP algorithm $k$ times independently on the same
179:**Definition.** $A$ is *normal* iff $AA^\dagger = A^\dagger A$. Hermitian
183:**Theorem ($2\times2$ case).** If $A$ is a normal $2\times2$ matrix, then
### exercises
9

## day06.md
lines:      411
### headings
3:## Learning objectives
22:## Reference material
33:## Theory
35:### The measurement postulate and the Born rule
54:### Basis-dependence of measurement statistics
68:### Density matrices: definition and basic properties
102:### Density matrices as expectation-value machines
116:### Completing single-qubit unitaries: Euler decomposition and $R_z$
137:### Universal gate sets and the Solovay–Kitaev theorem
155:## Common misconceptions
205:## Worked example
253:## Exercises
283:## Solutions
405:## Journal template
408:## Day 6 — Measurement, the Born rule & density matrices
### named labels
207:**Claim:** for $|\varphi\rangle = |+\rangle =
### exercises
9

## day07.md
lines:      476
### headings
3:## Learning objectives
18:## Reference material
28:## Theory
30:### The joint state space of two qubits
56:### Embedding single-qubit gates: the Kronecker product
98:### Separability and entanglement
131:### The partial trace and reduced density matrices
160:### The no-cloning theorem
230:## Worked example
272:## Exercises
306:## Solutions
470:## Journal template
473:## Day 7 — Multi-qubit states, entanglement & no-cloning
### named labels
162:**Claim:** there is no unitary $U$ on two qubits such that $U(|\psi\rangle
232:**Claim:** the same two-gate circuit $\text{CNOT}\cdot(H\otimes I)$ that
### exercises
7

## day08.md
lines:      488
### headings
3:## Learning objectives
19:## Reference material
32:## Theory
34:### The promise problem
49:### The oracle and phase kickback
98:### The Hadamard-transform identity
124:### The Deutsch–Jozsa circuit, general $n$
194:### Comparison with the classical randomized algorithm (Day 2)
215:## Common misconceptions
276:## Worked example
344:## Exercises
386:## Solutions
482:## Journal template
485:## Day 8 — Quantum parallelism & the Deutsch–Jozsa algorithm
### named labels
64:**Claim (phase kickback):** $U_f|x\rangle|-\rangle =
104:**Claim:** $H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_{y\in\{0,1\}^n}
### exercises
12

## day09.md
lines:      272
### headings
3:## Learning objectives
25:## How to use this review
39:## Review questions
55:## Model answers
57:### 1. $|\Phi^+\rangle$ is entangled
86:### 2. Reduced density matrix of $|\Phi^+\rangle$
130:### 3. No-cloning theorem
191:### 4. Deutsch–Jozsa: circuit and general-$n$ amplitude formula
265:## Journal template
268:## Day 9 — Review: Days 6–8 (closed-book)
### named labels
132:**Claim:** there is no unitary $U$ (on two qubits) such that
### exercises
9

## day10.md
lines:      493
### headings
3:## Learning objectives
25:## Reference material
35:## Theory
37:### Recap: the Hadamard transform and phase kickback (Day 8)
58:### The parity-orthogonality lemma
74:### Bernstein–Vazirani: statement and general derivation
124:### Simon's algorithm: statement and why the promise is stronger
161:### Simon's circuit: collapse and the linear constraint on $y$
213:### Unifying view
241:## Worked example
292:## Exercises
333:## Solutions
487:## Journal template
490:## Day 10 — Bernstein–Vazirani & Simon's algorithm
### named labels
(none)
### exercises
6

## day11.md
lines:      385
### headings
3:## Learning objectives
20:## Reference material
33:## Theory
35:### The unstructured search problem
50:### The good/bad subspace and the state $|s\rangle$
78:### The oracle reflection $O_f$
99:### The diffusion operator $D$
113:### Composing two reflections: Grover's algorithm as rotation
130:### How many iterations?
147:## Worked example
186:## Exercises
217:## Solutions
346:## Code lab
379:## Journal template
382:## Day 11 — Grover's algorithm & amplitude amplification
### named labels
(none)
### exercises
5

## day12.md
lines:      458
### headings
3:## Learning objectives
20:## Reference material
30:## Theory
32:### What's rigorous today, and what isn't
55:### Recap: the rotation picture (Day 11)
80:### The BBBV optimality theorem
108:### The hybrid-argument sketch
151:### Generalized amplitude amplification
207:### The modified iteration count
238:## Worked example
281:## Exercises
333:## Solutions
452:## Journal template
455:## Day 12 — Grover's optimality (BBBV) & generalized search
### named labels
82:**Theorem (Bennett–Bernstein–Brassard–Vazirani, 1997).** Let $N = 2^n$, and
240:**Claim:** the generalized amplitude-amplification formula reduces exactly
### exercises
9

## day13.md
lines:      387
### headings
3:## Learning objectives
21:## Reference material
31:## Theory
33:### Modular arithmetic and the order of an element
58:### Miller's reduction: from order to factor
106:### The Quantum Fourier Transform
128:### Deriving the $N=4$ matrix explicitly
145:### Reducing to the Hadamard transform on $(\mathbb{Z}_2)^n$
176:### Continued fractions
195:## Worked example
222:## Exercises
254:## Solutions
381:## Journal template
384:## Day 13 — Number theory for Shor's algorithm & the Quantum Fourier Transform
### named labels
64:**Claim.** Let $r$ be the order of $a$ mod $N$ ($\gcd(a,N)=1$), suppose $r$
### exercises
7

## day14.md
lines:      418
### headings
3:## Learning objectives
25:## Reference material
40:## Theory
42:### Setup: what Quantum Phase Estimation estimates
54:### Phase kickback, generalized from a $\pm1$ phase to an arbitrary phase
98:### From one ancilla to the full phase register: recognizing a QFT
147:### Assembling Shor's algorithm
185:### The $N=15,\ a=7$ pipeline, traced end to end
220:## Worked example
240:## Exercises
271:## Solutions
374:## Code lab
410:## Journal template
413:## Day 14 — Quantum Phase Estimation & Shor's algorithm
### named labels
222:**Claim:** for $N=15,\ a=7$, a single QPE run with outcome $x=48$ (out of
### exercises
5

## day15.md
lines:      671
### headings
3:## Learning objectives
21:## Reference material
37:## Theory
39:### BQP: bounded-error quantum polynomial time
72:### The complexity landscape: $P\subseteq BPP\subseteq BQP\subseteq PSPACE$
142:### The adiabatic model
176:### Quantum advantage / supremacy claims
215:### Two open problems
228:## Common misconceptions
256:## Final exam
299:## Model answers
301:### 1. Toffoli universality
341:### 2. BPP and Chernoff error amplification
368:### 3. Spectral theorem (2×2 case) and Pauli eigenstructure
410:### 4. Born rule in two bases; pure-state density matrix is rank 1
448:### 5. No-cloning theorem
470:### 6. Deutsch–Jozsa, general $n$
498:### 7. Bernstein–Vazirani, exact derivation
523:### 8. Grover's angle, optimal iteration count, BBBV
558:### 9. Shor's pipeline for $N=21$
595:### 10. $P\subseteq BPP\subseteq BQP\subseteq PSPACE$
618:## Gap analysis
659:## Journal template
662:## Day 15 — Beyond discrete-time quantum computing & final exam
### named labels
343:**Definition.** $BPP$ is the class of languages $L$ decidable by a
### exercises
16

