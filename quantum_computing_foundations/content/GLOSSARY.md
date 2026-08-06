# Glossary — Quantum Computing Foundations

*Lookup for catch-up: scan for the term you forgot — this is not meant to be read in order. Full treatments live in the day files named in each section header.*

→ [Jump index](#jump-index)

## Notation at a glance

| Symbol | Read as | Meaning |
|--------|---------|---------|
| $\lvert\psi\rangle$ | "ket psi" | a normalized column vector representing a quantum state |
| $\langle\psi\rvert$ | "bra psi" | the conjugate-transpose (row-vector) dual of a ket |
| $\langle\phi\rvert\psi\rangle$ | "bra-ket" | the inner product of two states — a single complex number |
| $\lvert\phi\rangle\langle\psi\rvert$ | "ket-bra" | the outer product of two states — a rank-1 matrix (operator) |
| $A^\dagger$ | "A dagger" | the Hermitian adjoint (conjugate transpose) of matrix $A$ |
| $\mathbb{C}^n$ | "C to the n" | the space of $n$-dimensional vectors of complex numbers |
| $\lvert0\rangle,\lvert1\rangle$ | "ket zero / ket one" | the two standard basis states of a single qubit |
| $\alpha, \beta$ | "alpha, beta" | the two complex amplitudes of a qubit state $\alpha\lvert0\rangle+\beta\lvert1\rangle$ |
| $I$ | "identity" | the "do nothing" operator or gate |
| $\oplus$ | "XOR" | bitwise exclusive-or (addition mod 2) |
| CNOT | "controlled-NOT" | the two-bit gate that flips a target bit exactly when the control bit is 1 |
| Toffoli / CCNOT | "Toffoli" | the three-bit gate that flips a target bit exactly when both control bits are 1 |
| $X$ | "Pauli X" | the bit-flip gate |
| $Y$ | "Pauli Y" | the bit-and-phase-flip gate |
| $Z$ | "Pauli Z" | the phase-flip gate |
| $H$ | "Hadamard" | the gate that turns a definite 0 or 1 into an equal superposition |
| $e^{i\gamma}$ | "e to the i gamma" | a global phase factor — an overall multiplier on a state with no physical effect |
| $\rho$ | "rho" | a density matrix (a state that may be pure or a statistical mixture) |
| $\text{Tr}$ | "trace" | the trace of a matrix — the sum of its diagonal entries |
| $\lvert+\rangle,\lvert-\rangle$ | "ket plus / ket minus" | the two Hadamard-basis states — equal mixes of $\lvert0\rangle$ and $\lvert1\rangle$ that differ only in a sign |
| $R_z(\theta), R_y(\theta)$ | "R sub z/y of theta" | single-qubit rotation gates about the Bloch sphere's z- or y-axis |
| $T$ | "T gate" | a small fixed-phase gate used, together with $H$, to approximate any other single-qubit gate |
| $\otimes$ | "tensor" | the operation combining two separate quantum systems into one joint system |
| $\lvert\Phi^+\rangle$ | "ket Phi plus" | one of the four Bell states — a maximally entangled two-qubit state |
| $\text{Tr}_2$ | "partial trace over subsystem 2" | the operation that averages away one subsystem to leave the other's reduced state |
| $\rho_1$ | "rho sub 1" | the reduced density matrix of subsystem 1, left after tracing out subsystem 2 |
| $U_f$ | "U sub f" | the oracle unitary that implements a hidden function $f$ |
| $x\cdot y$ | "x dot y" | the mod-2 inner (dot) product of two bit strings |
| $s$ | "s" | Simon's algorithm's hidden string, describing which inputs pair up |
| $a$ | "a" | Bernstein–Vazirani's hidden string, defining the oracle's linear function |
| $\mathbb{F}_2$ | "F-2" | the number system with just two elements, 0 and 1, under mod-2 arithmetic |
| $O_f$ | "O sub f" | the oracle (phase) reflection operator used in Grover's algorithm |
| $D$ | "D" | the diffusion operator used in Grover's algorithm |
| $\lvert s\rangle$ | "ket s" | the starting uniform superposition over all items, the axis the diffusion operator reflects about |
| $\theta$ | "theta" | the rotation angle used in Grover's algorithm and amplitude amplification |
| $\lvert good\rangle,\lvert bad\rangle$ | "ket good / ket bad" | the two basis directions spanning Grover's 2D search subspace |
| $P_{good}$ | "P sub good" | the projector onto the marked (good) items' subspace |
| $r$ | "r" | the multiplicative order — the smallest exponent with $a^r\equiv1\pmod N$ |
| $\equiv \pmod N$ | "is congruent to ... modulo N" | two numbers leave the same remainder after dividing by $N$ |
| $\varphi(N)$ | "Euler phi of N" | Euler's totient function — how many numbers up to $N$ share no factor with $N$ |
| $\gcd$ | "G-C-D" | greatest common divisor |
| $\mathbb{Z}_N^*$ | "Z-N-star" | the group of numbers mod $N$ that share no factor with $N$ |
| $\omega$ | "omega" | a primitive $N$-th root of unity, used to define the Quantum Fourier Transform |
| QFT | "Q-F-T" | the Quantum Fourier Transform operator |
| $p_n/q_n$ | "p sub n over q sub n" | a continued-fraction convergent — the best simple-fraction approximation at step $n$ |
| $\varphi$ | "phi" | the eigenphase that Quantum Phase Estimation estimates |
| $U_a$ | "U sub a" | the modular multiplication unitary that multiplies a register by $a$, wrapping mod $N$ |
| $O(\cdot)/\Omega(\cdot)$ | "big-O / big-Omega" | asymptotic upper / lower bounds on how fast a quantity grows |
| P, BPP, BQP, NP, PSPACE | "the complexity classes" | named sets of problems solvable under different resource budgets (deterministic, randomized, quantum, verifiable, polynomial-space) |

## Jump index

[Reversible & Classical Computation (Days 1–2)](#reversible--classical-computation-days-12) · [Complex Vector Spaces & Qubits (Days 3–4)](#complex-vector-spaces--qubits-days-34) · [Measurement & Density Matrices (Day 6)](#measurement--density-matrices-day-6) · [Entanglement & Multi-Qubit Systems (Day 7)](#entanglement--multi-qubit-systems-day-7) · [Quantum Query Algorithms (Days 8–10)](#quantum-query-algorithms-days-810) · [Grover's Algorithm & Search (Days 11–12)](#grovers-algorithm--search-days-1112) · [Shor's Algorithm & Number Theory (Days 13–14)](#shors-algorithm--number-theory-days-1314) · [Quantum Complexity Theory (Day 15)](#quantum-complexity-theory-day-15)

## Reversible & Classical Computation (Days 1–2)

**Boolean gate ($f:\{0,1\}^n\to\{0,1\}^m$)** — a rule that turns some number of input bits into output bits, like AND, OR, or NOT.

**Reversible gate (bijective)** — a gate whose function is a bijection: every possible output comes from exactly one input, so you can always work backward and recover what went in.

**CNOT gate** — a two-bit gate where the first bit (the control) passes through unchanged and the second bit (the target) flips exactly when the control is 1.

**Toffoli gate (CCNOT)** — a three-bit gate where two control bits pass through unchanged and the target bit flips exactly when both controls are 1.

**Ancilla bit** — an extra bit added to a circuit, started at a known fixed value (0 or 1), that gives a reversible gate somewhere to write a result.

**Garbage bit** — a leftover bit produced while making a circuit reversible that isn't the answer you wanted, but must be kept (not erased) so the whole circuit stays bijective.

**Landauer's principle ($kT\ln2$)** — a physical law: erasing information always costs at least a fixed minimum amount of energy, released as heat; reversible circuits, which never erase anything, sidestep this cost.

**P (complexity class)** — the set of yes/no problems an ordinary (non-random) computer can solve in a reasonable amount of time.

**BPP** — the set of yes/no problems a computer allowed to flip coins can solve quickly, getting the right answer at least two-thirds of the time on every input.

**Probabilistic algorithm** — an algorithm that uses randomness (coin flips) as part of how it decides its answer.

**Las Vegas algorithm (contrast with BPP algorithm)** — a randomized algorithm that is never wrong; what varies from run to run is its running time, not its correctness — the opposite trade-off from a BPP algorithm, which has a fixed running time but can occasionally be wrong.

**Markov's inequality** — a general rule: any nonnegative quantity is unlikely to be many times bigger than its own average value.

**Chernoff/Hoeffding bound ($e^{-ck}$)** — a mathematical bound showing that repeating an algorithm and taking the majority answer drives the chance of being wrong down exponentially fast as you add more repetitions.

**Error amplification (majority-vote repetition)** — running a bounded-error algorithm many times independently and taking the most common answer, to push the chance of a wrong final answer down toward zero.

**Promise problem (e.g. constant-vs-balanced)** — a problem where you're told in advance that the input is guaranteed to fall into one of a small number of special cases, and you just have to determine which.

## Complex Vector Spaces & Qubits (Days 3–4)

**Complex inner product ($\langle v,w\rangle=v^\dagger w$)** — a way of measuring how much two vectors of complex numbers overlap, defined so that a vector's overlap with itself always comes out as a nonnegative real number.

**Hermitian adjoint (dagger) ($A^\dagger$)** — the complex-number counterpart of a matrix transpose: flip rows and columns, then take the complex conjugate of every entry.

**Hermitian matrix ($A=A^\dagger$)** — a matrix that equals its own Hermitian adjoint; these always have real eigenvalues and represent physically measurable quantities.

**Unitary matrix ($U^\dagger U=I$)** — a matrix that preserves lengths and angles under the complex inner product; every quantum gate and every step of quantum evolution is unitary.

> **Unitary vs Hermitian**
>
> | | Unitary ($U^\dagger U=I$) | Hermitian ($A=A^\dagger$) |
> |---|---|---|
> | It is… | a reversible evolution step (a gate) | an observable — a measurable physical quantity |
> | Shows… | eigenvalues of size exactly 1 (on the unit circle) | eigenvalues that are always real numbers |
> | Math object | preserves lengths/angles under the inner product | equals its own Hermitian adjoint |
>
> A single matrix can be one, both (the Pauli matrices are), or neither.

**Qubit ($\alpha|0\rangle+\beta|1\rangle$)** — the quantum version of a bit: a vector of two complex numbers whose squared sizes add up to 1, instead of a fixed 0 or 1.

**Bra ($\langle\psi|$)** — the row-vector, conjugated partner of a ket; placing a bra next to a ket computes an inner product.

**Ket ($|\psi\rangle$)** — the standard way to write a quantum state, as a column vector.

> **Bra vs Ket**
>
> | | Ket ($\lvert\psi\rangle$) | Bra ($\langle\psi\rvert$) |
> |---|---|---|
> | It is… | a state | its dual |
> | Math object | column vector | row vector (conjugate transpose) |
> | Combine as… | $\langle\phi\rvert\psi\rangle$ = inner product | $\lvert\psi\rangle\langle\phi\rvert$ = outer product |

**Outer product ($|\phi\rangle\langle\psi|$)** — the matrix you get from multiplying a ket by a bra rather than a bra by a ket; used to build projectors and density matrices.

**Completeness relation ($\sum_i|i\rangle\langle i|=I$)** — the fact that adding up the projectors onto every direction of an orthonormal basis gives back the identity — nothing is lost by describing a state in any complete basis.

**Normal matrix ($AA^\dagger=A^\dagger A$)** — a matrix that commutes with its own Hermitian adjoint; this is exactly the condition guaranteeing it can be perfectly diagonalized using an orthonormal set of eigenvectors.

**Spectral theorem (normal operators) ($A=UDU^\dagger$)** — the result that a matrix has an orthonormal basis of eigenvectors, with eigenvalues on the diagonal, exactly when it is normal.

**Schur's theorem ($A=VTV^\dagger$)** — a general fact from linear algebra, not specific to quantum computing: every matrix can be turned into an upper-triangular matrix by an orthonormal change of basis; used as a stepping stone to prove the spectral theorem. (This $T$ is that triangular matrix — an unrelated, unfortunate reuse of the same letter as the T gate above.)

**Pauli matrices ($X,Y,Z$)** — three specific matrices that flip a qubit's value, flip its value and phase, or flip only its phase.

**Hadamard matrix ($H$)** — the gate that turns a definite 0 or 1 qubit into an equal superposition of both.

**Involution ($A^2=I$)** — a matrix or gate that is its own inverse: applying it twice does nothing.

**Bloch sphere ($(x,y,z)$)** — a way of picturing any single-qubit state as one point on the surface of an ordinary sphere in 3D space, ignoring the physically meaningless overall phase.

**Global phase (physically unobservable) ($e^{i\gamma}$)** — an overall factor multiplying an entire quantum state that has no effect on any measurement outcome, and so carries no physical meaning.

> **Global Phase vs Relative Phase**
>
> | | Global phase ($e^{i\gamma}$) | Relative phase |
> |---|---|---|
> | It is… | one factor multiplying an entire state | a phase difference between two amplitudes within one state |
> | Shows… | nothing — no measurement can detect it | up in interference patterns — it's physically real |
> | Example | $e^{i\gamma}\lvert\psi\rangle$ and $\lvert\psi\rangle$ are the same physical state | the sign telling $\lvert+\rangle$ apart from $\lvert-\rangle$ |

## Measurement & Density Matrices (Day 6)

**Projective measurement** — the physical process of observing a quantum system in a chosen basis: it produces one random outcome and changes the state to match what was observed.

> **Gate vs Measurement**
>
> | | Gate | Measurement |
> |---|---|---|
> | It is… | a deterministic, reversible step | a probabilistic, irreversible step |
> | Math object | a unitary matrix | a probabilistic collapse governed by the Born rule |
> | Shows… | the same output every time, for the same input | a random outcome, different across repeated runs on identical states |
>
> Conflating these two is the single most common source of confusion about what "quantum parallelism" actually gives you.

**Born rule ($p_i=|\langle e_i|\psi\rangle|^2$)** — the rule that the probability of getting a particular measurement outcome equals the squared size of the corresponding amplitude.

> **Amplitude vs Probability**
>
> | | Amplitude | Probability |
> |---|---|---|
> | It is… | a complex number describing a state's weight on a basis direction | a nonnegative real number describing the chance of an outcome |
> | Compute it by… | reading off a state's coefficient, e.g. $\alpha,\beta$ | squaring an amplitude's size (the Born rule): $p=\lvert\alpha\rvert^2$ |
> | Shows… | interference — amplitudes can add or cancel | no interference — probabilities only ever add |

**Collapse (measurement)** — what happens to a quantum state right after measurement: it snaps to whichever basis state matched the outcome you saw, and all other information in the original state is gone.

**Density matrix ($\rho=|\psi\rangle\langle\psi|$)** — a matrix representing a quantum state that works for both a definite state and a statistical mixture of states, unlike a single ket.

**Pure state (density matrix rank 1)** — a quantum state that is one definite ket, not a statistical mixture; its density matrix has exactly one nonzero eigenvalue.

**Mixed state (density matrix has two or more nonzero eigenvalues)** — classical uncertainty layered on top of quantum states — e.g. "this state with some probability, or that state otherwise" — rather than a single definite quantum state.

> **Pure State vs Mixed State**
>
> | | Pure state | Mixed state |
> |---|---|---|
> | It is… | one definite quantum state | classical uncertainty over several quantum states |
> | Math object | density matrix of rank 1 | density matrix with two or more nonzero eigenvalues |
> | Compute it by… | $\rho=\lvert\psi\rangle\langle\psi\rvert$ for a single ket | a weighted sum of several such $\rho$'s |

**Expectation value ($\text{Tr}(\rho O)$)** — the average result you'd get from measuring some quantity many times on identically prepared copies of a state, computed directly from the density matrix.

**Euler (Z-Y-Z) decomposition ($U=e^{i\alpha}R_zR_yR_z$)** — the fact that every single-qubit gate can be built as three rotations in a row, around the Bloch sphere's z-, y-, and z-axes.

**Solovay–Kitaev theorem** — a guarantee that any single-qubit gate can be approximated as closely as you like using only a short sequence of gates from a small, fixed, universal set.

**Superposition (not a classical unknown-value)** — a state that is a genuine combination of several possibilities at once, not just a value you don't happen to know yet; measuring in a different basis reveals the difference.

**Interference (amplitude cancellation)** — the effect where the amplitudes of different computational paths can add together or cancel each other out, changing the resulting probabilities.

## Entanglement & Multi-Qubit Systems (Day 7)

**Tensor product ($\otimes$)** — the operation that combines two separate quantum systems, like two qubits, into one joint system.

**Kronecker product (matrix form of the tensor product) ($A\otimes B$)** — the matrix recipe for combining two gates that each act on their own qubit into one bigger gate acting on the joint system.

**Separable state (product state)** — a multi-qubit state that can be split into one qubit's state combined with another's, meaning the qubits behave completely independently of each other.

**Entangled state (not separable)** — a multi-qubit state that cannot be split into separate single-qubit states; the qubits are correlated in a way no classical description captures.

> **Separable vs Entangled**
>
> | | Separable (product) state | Entangled state |
> |---|---|---|
> | It is… | two or more qubits behaving independently | qubits correlated in a way no separate description captures |
> | Math object | factors as $\lvert\chi\rangle\otimes\lvert\varphi\rangle$ | does not factor into any single-qubit states |
> | Shows… | a pure reduced density matrix on each subsystem | a mixed reduced density matrix on a subsystem, even though the whole state is pure |

> **Superposition vs Entanglement**
>
> | | Superposition | Entanglement |
> |---|---|---|
> | It is… | a property of one system's own state vector | a property of how two or more subsystems' states are correlated |
> | Lives in… | a single qubit (or any single system) | the joint state of two or more qubits together |
> | Note | a superposition can exist with zero entanglement | entanglement always requires at least two subsystems and cannot exist for a single one |

**Bell state (one of four maximally entangled states) ($|\Phi^+\rangle$)** — one of four specific two-qubit states that are as entangled as two qubits can possibly be.

**Partial trace ($\text{Tr}_2$)** — the operation for working out "just this one qubit's state" from a larger multi-qubit system, by averaging away the other qubits.

**Reduced density matrix ($\rho_1$)** — the density matrix you get for one part of a multi-qubit system after taking the partial trace over the rest; it can be mixed even when the whole system is pure — the signature of entanglement.

**No-cloning theorem** — the proven fact that no quantum process can make a perfect copy of an arbitrary, unknown quantum state.

## Quantum Query Algorithms (Days 8–10)

**Quantum parallelism** — the idea that a quantum computer holds a superposition over many inputs at once; by itself this doesn't give you the answer for every input simultaneously — the real power comes from how the branches later interfere.

**Oracle (phase oracle) ($U_f$)** — a black-box unitary that lets a hidden function be used inside a quantum circuit without ever exposing its internals directly.

**Phase kickback ($(-1)^{f(x)}$)** — a trick where querying an oracle leaves the answer register completely unchanged and instead "kicks" the function's value back as a phase multiplying the input register.

**Deutsch–Jozsa algorithm** — a quantum algorithm that decides, with a single query and zero chance of error, whether a hidden function is constant or balanced.

**Parity-orthogonality lemma ($\sum_x(-1)^{x\cdot z}$)** — a counting fact: a certain sum of plus-and-minus-one terms is huge when a hidden string is all-zero and exactly zero otherwise — the engine behind why several quantum algorithms' answers concentrate on a single outcome.

**Bernstein–Vazirani algorithm** — a quantum algorithm that recovers an entire hidden bit-string in a single query, where a classical computer needs one query per bit.

**Simon's algorithm** — a quantum algorithm that finds a hidden string describing how a function's inputs pair up, using exponentially fewer queries than any possible classical algorithm.

**Value oracle (contrast with phase oracle) ($U_f|x\rangle|0\rangle=|x\rangle|f(x)\rangle$)** — an oracle that writes the function's actual output into a separate register, rather than hiding it as a phase.

## Grover's Algorithm & Search (Days 11–12)

**Unstructured search problem** — the task of finding a marked item among many, with no shortcut like sorting or hashing to exploit — the oracle is the only source of information.

**Marked / unmarked item** — in a search problem, a "marked" (good) item is one you're looking for; an "unmarked" (bad) item is one you're not.

**Oracle reflection ($O_f$)** — the operation in Grover's algorithm that flips the sign of every marked item's amplitude and leaves everything else alone.

**Diffusion operator ($D$)** — the operation in Grover's algorithm that reflects the current state back about the starting (uniform superposition) direction.

> **Oracle Reflection vs Diffusion Operator**
>
> | | Oracle reflection ($O_f$) | Diffusion operator ($D$) |
> |---|---|---|
> | It is… | a reflection about the $\lvert bad\rangle$ axis | a reflection about the starting state $\lvert s\rangle$ |
> | Depends on… | which items are marked (the oracle) | the state-preparation step, not the oracle |
> | Compute it by… | $O_f=I-2\sum_{x\text{ good}}\lvert x\rangle\langle x\rvert$ | $D=2\lvert s\rangle\langle s\rvert-I$ |

**Amplitude amplification** — the general technique, of which Grover's algorithm is the standard example, of repeatedly rotating a quantum state so the chance of measuring a desired outcome grows.

**Grover's algorithm** — a quantum algorithm for unstructured search that finds a marked item using far fewer oracle queries than any classical approach needs.

**BBBV theorem (Grover optimality) ($T=\Omega(\sqrt N)$)** — a proof that no quantum algorithm of any design can solve unstructured search faster than Grover's algorithm already does, up to constant factors.

**Hybrid argument (sketch-level proof technique)** — a style of proof, used to establish the BBBV theorem, that compares an algorithm's behavior across many slightly different oracles to show it can't have learned much after only a few queries.

**Generalized amplitude amplification (generalizes Grover's algorithm) ($\theta=2\arcsin\sqrt p$)** — the extension of Grover's rotation trick to any starting state and any "prior probability" of success, not just the uniform superposition.

## Shor's Algorithm & Number Theory (Days 13–14)

**Multiplicative order ($r$)** — for a chosen number and a chosen modulus, the smallest number of times you have to multiply that number by itself before landing back on 1 under that modulus.

**Euler's totient function ($\varphi(N)$)** — the count of numbers up to a given number that share no common factor with it.

> **Multiplicative Order vs Euler's Totient**
>
> | | Multiplicative order ($r$) | Euler's totient ($\varphi(N)$) |
> |---|---|---|
> | It is… | the smallest exponent with $a^r\equiv1\pmod N$, for one chosen $a$ | the size of the whole group of numbers coprime to $N$ |
> | Compute it by… | trying powers of $a$ until you hit 1 | counting integers up to $N$ sharing no factor with $N$ |
> | Note | depends on which $a$ you picked | fixed once $N$ is fixed; guarantees only that $r\mid\varphi(N)$, not $r=\varphi(N)$ |

**Euler's theorem ($a^{\varphi(N)}\equiv1$)** — a rule guaranteeing that raising any valid number to the power of Euler's totient function always lands back on 1, when you work modulo that same number.

**Lagrange's theorem (element order divides group order)** — a general algebra fact: the multiplicative order of any single element always evenly divides the size of the whole group it belongs to.

**Miller's reduction ($\gcd(a^{r/2}-1,N)$)** — the trick that turns "I know the multiplicative order of the chosen base" directly into "I've found a genuine factor of the number being factored," via one greatest-common-divisor calculation.

**Euclidean algorithm** — the classic, fast method for computing the greatest common divisor of two numbers by repeated division and remainder-taking.

**Quantum Fourier Transform (QFT)** — a unitary operation that rewrites a quantum state in terms of its underlying periodic structure — the quantum version of an ordinary Fourier transform.

**Continued fraction expansion (recovers $k/r$ from a noisy phase estimate) ($p_n/q_n$)** — a method for turning an imprecise decimal estimate of a fraction into the exact, simplest fraction it was probably approximating.

**Quantum Phase Estimation (QPE)** — a quantum algorithm that, given a way to apply a unitary, estimates the hidden phase (eigenvalue) of one of its eigenvectors.

**Modular multiplication unitary ($U_a$)** — the specific unitary used in Shor's algorithm that multiplies a register's value by a fixed number, wrapping around under a fixed modulus.

**Shor's algorithm** — a quantum algorithm that factors large numbers efficiently by turning factoring into an order-finding problem and solving that with quantum phase estimation.

## Quantum Complexity Theory (Day 15)

**BQP** — the set of yes/no problems a quantum computer can solve quickly, getting the right answer at least two-thirds of the time on every input — the quantum analogue of BPP.

> **BPP vs BQP**
>
> | | BPP | BQP |
> |---|---|---|
> | It is… | bounded-error classical randomized computation | bounded-error quantum computation |
> | Compute it by… | coin flips and classical logic | superposition, interference, and measurement |
> | Note | $BPP\subseteq BQP$ is proven; whether it's a strict subset is open | conjectured to be strictly larger (Shor's algorithm is the headline candidate witness) |

**PSPACE** — the set of problems solvable using only a reasonable (polynomial) amount of memory, no matter how much time it takes.

**NP** — the set of yes/no problems where, if the answer is yes, there's a short proof of that fact that can be checked quickly, even if finding the proof might be hard.

**NP-complete (SAT is the canonical example)** — a problem in NP that every other NP problem can be efficiently rephrased as; Boolean satisfiability (SAT) is the standard example.

**Adiabatic theorem** — a physics result: if a system's underlying "energy landscape" changes slowly enough, the system stays in its lowest-energy state throughout, ending in the lowest-energy state of the final landscape.

**Adiabatic quantum computation (polynomially equivalent to the circuit model)** — a way of computing by slowly deforming a physical system so its final lowest-energy state encodes the answer, instead of running a sequence of discrete gates; provably no more or less powerful than the standard gate-based model.

**Quantum advantage / supremacy (empirical claim, not proof that $BQP\ne BPP$)** — the claim that a specific quantum device solved a specific task faster than any known classical computer can — a statement about today's best-known algorithms and hardware, not a mathematical proof that quantum computers are fundamentally more powerful.

**Cook–Levin theorem** — the theorem proving that Boolean satisfiability (SAT) is NP-complete, making it the canonical hardest problem in NP.
