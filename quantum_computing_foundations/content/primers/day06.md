# Day 6 — Before you read: Measurement, Born rule & density matrices

## Warm-up

This primer assumes you have read the Day 3 and Day 4 primers. Day 3 established
complex inner products, the adjoint, and bra-ket notation — every occurrence of
$\langle e_i|\psi\rangle$ today is exactly that inner product, computed as the
conjugate-transpose of $|e_i\rangle$ applied to $|\psi\rangle$. Day 4 went
further, attaching geometric meaning to single-qubit states via the Bloch sphere
and introducing the Pauli matrices $X, Y, Z$ and the Hadamard $H$. Those specific
unitaries reappear inside today's Euler decomposition and in the universal
gate-set example, so having the Day 4 Bloch-sphere picture in mind will make the
geometry of basis-rotation much more vivid. The spectral theorem from Day 4 is
also quietly present: the density matrix is Hermitian and positive semidefinite,
so it diagonalises in an orthonormal eigenbasis, and the rank-1 result is
precisely a statement about that spectrum.

Day 2 introduced randomised computation: a classical coin flip produces a
probability distribution over outcomes, and repeating the experiment amplifies
the signal about the true distribution. Today's quantum measurement shares that
skeleton — probabilities over outcomes, a physical process that selects one — but
replaces the classical coin with complex amplitudes governed by the Born rule.
The idea that probabilities must sum to one, which in Day 2 was an axiom about
the coin and needed Chernoff bounds to maintain under amplification, becomes an
automatic algebraic consequence of state normalisation here: Parseval's identity
for orthonormal bases does the work that classical probability theory had to
enforce separately.

## The hook

Consider the qubit $|\psi\rangle = \frac{3}{5}|0\rangle + \frac{4i}{5}|1\rangle$.
The amplitude on $|1\rangle$ is $\frac{4i}{5}$, a purely imaginary number. If
you computed the probability of outcome $1$ by squaring the real part of
$\frac{4i}{5}$, you would get $0$ — the real part is $0$, and that answer is
wrong. The Born rule says probability equals the modulus squared. The modulus of
$\frac{4i}{5}$ is $\left|\frac{4i}{5}\right| = \frac{4}{5}$, so the probability
is $\left|\frac{4i}{5}\right|^2 = \frac{16}{25}$. The probability of outcome $0$
is $\left|\frac{3}{5}\right|^2 = \frac{9}{25}$, and $\frac{9}{25} + \frac{16}{25}
= 1$, confirming normalisation. The imaginary coefficient $\frac{4i}{5}$ carries
exactly as much probability weight as a real coefficient of magnitude $\frac{4}{5}$
would. What the imaginary part does is hold phase information: it controls how
amplitudes from different basis directions add together — constructively or
destructively — when you rotate the measurement basis. For the Born rule in a
fixed basis, however, phase is completely invisible; only the modulus matters,
and modulus squared is always non-negative.

## The pictures

Picture the probability interpretation of amplitudes as a bar chart drawn above
the complex plane. Each amplitude $\alpha$ or $\beta$ is a point somewhere in
the plane — on the real axis, the imaginary axis, or anywhere in between. The
bar rising above each point has height $|\alpha|^2$ or $|\beta|^2$. Two
amplitudes that are related by a phase rotation, like $\frac{3}{5}$ and
$\frac{3i}{5}$, have the same bar height even though they sit at different
positions in the plane. The total bar area across all outcomes sums to one by
normalisation. Crucially, the angle of the amplitude in the complex plane — its
phase — does not appear on the bar chart at all; two amplitudes with the same
modulus but different phases are indistinguishable in single-basis measurement
statistics, yet they interfere differently when you choose a different measurement
basis, which is exactly why phase is physically real and detectable.

Picture basis-dependence as pointing a compass at different orientations relative
to the same fixed arrow. The arrow is the qubit state — a fixed direction on the
Bloch sphere. The compass tells you which direction counts as "north," that is,
which direction you are calling $|0\rangle$ for this measurement. When the compass
aligns with the $z$-axis, you are measuring in $\{|0\rangle,|1\rangle\}$; when
you rotate the compass $90°$ toward the $x$-axis, you are measuring in
$\{|+\rangle,|-\rangle\}$. The same qubit arrow subtends different angles to
north depending on how you orient the compass, so the Born-rule probabilities —
squared projections of the arrow onto north — change whenever the compass rotates.
The qubit state has not changed; only the measurement frame has.

Picture the density matrix $\rho = |\psi\rangle\langle\psi|$ as a $2\times 2$
snapshot table. The diagonal entries $\rho_{00}$ and $\rho_{11}$ are the outcome
probabilities in the computational basis — you can read the Born-rule prediction
directly off the diagonal. The off-diagonal entries $\rho_{01}$ and $\rho_{10}$
are the coherences: they encode the phase relationship between the two amplitudes,
the same phase information invisible to the bar chart but controlling interference
in any other basis. A pure state has nonzero off-diagonal entries and rank 1:
the two rows of the table are scalar multiples of each other, reflecting that
all the probability sits in one direction. A classical mixture has zero
off-diagonal entries and rank greater than 1, because phases have been averaged
away and probability is genuinely spread across more than one independent direction.

## Concrete-first walkthrough

Begin with the Born rule in its cleanest form. The formula in
**The measurement postulate and the Born rule** is
$\Pr[\text{outcome }i] = |\langle e_i|\psi\rangle|^2$, and collapse sends the
state to $|e_i\rangle$ immediately after the measurement. For the hook state,
compute $\langle 0|\psi\rangle = \frac{3}{5}$ and $\langle 1|\psi\rangle =
\frac{4i}{5}$ by applying the inner product, square both moduli, and read off
$\frac{9}{25}$ and $\frac{16}{25}$. After working through this, locate the
sentence in **The measurement postulate and the Born rule** that extends the
postulate to any finite-dimensional space with any orthonormal basis — it appears
right after the two-step definition, and it is the direct setup for the
basis-dependence topic that follows.

Turn to **Basis-dependence of measurement statistics** and work through the
numbers before reading the commentary. Measure $|+\rangle$ in the standard
basis: both $|\langle 0|+\rangle|^2$ and $|\langle 1|+\rangle|^2$ equal
$\frac{1}{2}$. Then measure the same state in $\{|+\rangle,|-\rangle\}$:
$|\langle +|+\rangle|^2 = 1$ and $|\langle -|+\rangle|^2 = 0$. The Born rule
applied to the same state in two bases gives a uniform distribution in one case
and a deterministic outcome in the other. The state did not change; the basis
did. This is the numerical core of today's material — compute it yourself before
reading the provided solution.

With the Born rule in hand, **Density matrices: definition and basic properties**
introduces $\rho = |\psi\rangle\langle\psi|$. Build it for a concrete state:
write the column vector, write its conjugate-transpose row, form the outer
product, and check all three properties. The **Claim:** worked example does
exactly this for $|+\rangle$, including an explicit eigenvalue computation that
confirms rank 1 and positive semidefiniteness in one step. The rank-1 result
follows from the outer-product algebra, and **Density matrices as
expectation-value machines** then derives $\langle O\rangle = \mathrm{Tr}(\rho O)$
using a completeness-relation insertion. **Completing single-qubit unitaries:
Euler decomposition and $R_z$** and **Universal gate sets and the
Solovay–Kitaev theorem** close the single-qubit gate story from Day 4 by showing
that every unitary reduces to three rotations and that a small fixed gate set
suffices to approximate all of them.

Three traps to watch. First, $\left|\frac{4i}{5}\right|^2 = \frac{16}{25}$, not
$-\frac{16}{25}$: modulus squared is always non-negative, regardless of whether
the amplitude is imaginary. Second, the density matrix of a pure state is rank 1,
not full-rank: purity means all the probability sits in a single direction, and
expecting two nonzero eigenvalues is confusing pure states with mixed ones.
Third, the cyclic trace identity $\mathrm{Tr}(AB) = \mathrm{Tr}(BA)$ lets you
cycle the product inside a trace but does not imply $AB = BA$ in general; the
trace is symmetric under cyclic permutation, but the operators themselves need
not commute.

## Derivation roadmaps

For Born-rule normalisation — showing that $\sum_i |\langle e_i|\psi\rangle|^2
= 1$ automatically — the key trick is $\sum_i |\langle e_i|\psi\rangle|^2 =
\|\psi\|^2$ by the Parseval-type identity for orthonormal bases. Fill in the
completeness relation $\sum_i |e_i\rangle\langle e_i| = I$ and the normalisation
$\langle\psi|\psi\rangle = 1$ to close the two-line argument. Notice that the
same reasoning works in any finite-dimensional space, which is why the postulate
can be stated once for all dimensions without a separate normalisation check.

For the rank-1 purity result, the key trick is $\rho^2 =
|\psi\rangle\langle\psi|\psi\rangle\langle\psi| = |\psi\rangle\langle\psi| = \rho$,
using $\langle\psi|\psi\rangle = 1$. Every eigenvalue $\lambda$ then satisfies
$\lambda^2 = \lambda$, so $\lambda \in \{0,1\}$. Fill in why $\mathrm{Tr}(\rho)
= \sum_i \lambda_i = 1$ forces exactly one eigenvalue equal to $1$ and all
others to $0$, completing the rank-1 conclusion.

For the expectation-value identity $\mathrm{Tr}(\rho O) = \langle\psi|O|\psi\rangle$,
the key trick is inserting $I = \sum_i |e_i\rangle\langle e_i|$ into
$\langle\psi|O|\psi\rangle$ and noticing that the result reassembles the outer
product $|\psi\rangle\langle\psi|$ inside the trace. Fill in the scalar-reordering
step — $\langle e_i|\psi\rangle$ and $\langle\psi|O|e_i\rangle$ are both scalars
and so commute — and the trace definition to complete the identification.

## Flashcards

Q: State the Born rule. What is the probability of outcome $i$ when measuring $|\psi\rangle$ in orthonormal basis $\{|e_i\rangle\}$?
A: $\Pr[\text{outcome }i] = |\langle e_i|\psi\rangle|^2$. The state collapses to $|e_i\rangle$ immediately after the measurement.

Q: For $|\psi\rangle = \frac{3}{5}|0\rangle + \frac{4i}{5}|1\rangle$, what are the Born-rule probabilities of outcomes $0$ and $1$?
A: $\left|\frac{3}{5}\right|^2 = \frac{9}{25}$ and $\left|\frac{4i}{5}\right|^2 = \frac{16}{25}$, summing to $1$. Modulus squared, not real-part squared.

Q: What does basis-dependence of measurement mean? Give a concrete example.
A: The same state gives different outcome distributions in different bases. $|+\rangle$ gives 50/50 in $\{|0\rangle,|1\rangle\}$ but probability $1$ for outcome "$+$" in $\{|+\rangle,|-\rangle\}$.

Q: What are the three algebraic properties every density matrix of a pure state satisfies?
A: $\mathrm{Tr}(\rho)=1$ (unit trace), $\rho^\dagger = \rho$ (Hermitian), and $\langle\varphi|\rho|\varphi\rangle \geq 0$ for all $|\varphi\rangle$ (positive semidefinite).

Q: What is the rank of the density matrix of a pure state, and which identity forces it?
A: Rank 1. The idempotent $\rho^2 = \rho$ forces all eigenvalues into $\{0,1\}$; then $\mathrm{Tr}(\rho)=1$ forces exactly one eigenvalue equal to $1$.

Q: State the expectation-value formula using the density matrix.
A: $\langle O\rangle = \mathrm{Tr}(\rho O)$ for any operator $O$. For pure states it equals $\langle\psi|O|\psi\rangle$; for mixed states it still holds without modification.

Q: What does the Solovay–Kitaev theorem guarantee, and what is the gate-sequence length?
A: Any single-qubit $U$ can be approximated to within $\varepsilon$ (operator norm) using $O(\log^c(1/\varepsilon))$ gates from a finite universal set such as $\{H,T\}$ — polylogarithmic in $1/\varepsilon$.

Q: The Born rule holds in any finite-dimensional space. What does this mean beyond the qubit case?
A: Measuring in any orthonormal basis $\{|e_i\rangle\}$ of an $n$-dimensional space yields outcome $i$ with probability $|\langle e_i|\psi\rangle|^2$ and collapses the state to $|e_i\rangle$, for any $n$.
