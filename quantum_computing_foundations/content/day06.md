# Day 6 — Measurement, the Born Rule & Density Matrices

## Learning objectives

By the end of today you should be able to:
- State the Born rule for a projective measurement in an orthonormal basis
  and use it to compute measurement probabilities for a given qubit state.
- Show, with a concrete example, that measurement outcome statistics depend
  on the *basis* in which you measure, not just on the state itself.
- Define the density matrix $\rho = |\psi\rangle\langle\psi|$ of a pure
  state and prove its three defining algebraic properties: trace $1$,
  Hermiticity, and positive semidefiniteness.
- Prove that a pure state's density matrix is rank $1$, and explain why this
  is the algebraic signature distinguishing pure from mixed states.
- Compute expectation values of an observable via $\text{Tr}(\rho O)$ and
  show this agrees with the direct bra-ket computation $\langle\psi|O|\psi\rangle$.
- Verify that $R_z(\theta)$ is unitary and use it as a concrete instance of
  the general single-qubit rotation decomposition.
- State (without proving) why a small fixed gate set such as $\{H, T\}$
  suffices to approximate any single-qubit unitary to arbitrary precision.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*,
  the chapter covering the measurement postulate and density matrices; or
  Nielsen & Chuang, *Quantum Computation and Quantum Information*, the
  sections on projective measurement, the density-matrix formalism, and
  single-qubit gate universality / the Euler-angle (Z-Y-Z) decomposition.
- The theory below is self-contained — you do not need the book to do
  today's work, but reading the matching chapter alongside this is useful
  for a second explanation in different words.

## Theory

### The measurement postulate and the Born rule

Given a qubit in state $|\psi\rangle = \alpha|0\rangle + \beta|1\rangle$
(normalized: $|\alpha|^2 + |\beta|^2 = 1$), a **projective measurement** in
an orthonormal basis $\{|e_i\rangle\}$ is a physical process with two parts:

1. **Probabilities (the Born rule):** outcome $i$ is observed with
   probability $p_i = |\langle e_i|\psi\rangle|^2$.
2. **Collapse:** conditioned on observing outcome $i$, the state
   immediately after measurement is $|e_i\rangle$ — all information about
   the pre-measurement amplitudes on the other basis vectors is gone.

Because $\{|e_i\rangle\}$ is an orthonormal basis, $|\psi\rangle =
\sum_i \langle e_i|\psi\rangle\, |e_i\rangle$, and normalization of
$|\psi\rangle$ forces $\sum_i p_i = \sum_i |\langle e_i|\psi\rangle|^2 = 1$
automatically — the Born rule always produces a valid probability
distribution over the basis, for *any* choice of orthonormal basis. This
last clause is the crux of the next subsection.

### Basis-dependence of measurement statistics

The Born rule is stated relative to a basis, and the same physical state
gives *different* outcome statistics in different bases. This is not a
minor technicality — it is one of the sharpest ways quantum measurement
differs from classical randomness, and today's Exercise 2 makes it
completely explicit with numbers: measuring $|+\rangle =
\frac{1}{\sqrt2}(|0\rangle + |1\rangle)$ in the standard basis
$\{|0\rangle,|1\rangle\}$ gives a $50/50$ split, while measuring the
*exact same state* in the basis $\{|+\rangle,|-\rangle\}$
(with $|-\rangle = \frac{1}{\sqrt2}(|0\rangle-|1\rangle)$) gives a
deterministic outcome. Nothing about the state changed between these two
descriptions — only the choice of measurement basis did.

### Density matrices: definition and basic properties

For a pure state $|\psi\rangle$, the **density matrix** is the outer
product $\rho = |\psi\rangle\langle\psi|$, an $n\times n$ matrix (for an
$n$-dimensional state space; $n=2$ for a single qubit). It packages the
same physical information as $|\psi\rangle$ but is invariant under the
overall-phase ambiguity of state vectors: $|\psi\rangle$ and
$e^{i\gamma}|\psi\rangle$ give the identical $\rho$, since
$(e^{i\gamma}|\psi\rangle)(e^{i\gamma}|\psi\rangle)^\dagger =
e^{i\gamma}e^{-i\gamma}|\psi\rangle\langle\psi| = \rho$. Every density
matrix built this way from a normalized $|\psi\rangle$ satisfies three
properties, proved in full in today's Solutions:

- $\text{Tr}(\rho) = 1$ (total probability is conserved),
- $\rho^\dagger = \rho$ (Hermitian — $\rho$ represents something physical,
  and its eigenvalues, which will turn out to be measurement
  probabilities in an appropriate basis, must be real),
- $\rho \ge 0$, meaning $\langle\varphi|\rho|\varphi\rangle \ge 0$ for
  *every* vector $|\varphi\rangle$ (positive semidefinite — the quantity
  it produces, an outcome probability, can never be negative).

A pure-state $\rho$ has a further, sharper property: it is **rank $1$**,
with eigenvalue $1$ on $|\psi\rangle$ itself and eigenvalue $0$ on every
vector orthogonal to $|\psi\rangle$. This is the precise algebraic
signature of purity. A general (*mixed*) state's density matrix — not
covered in depth today, but worth naming for contrast — is any matrix
satisfying the same three bulleted properties above, and can have more
than one nonzero eigenvalue; it describes classical uncertainty *over*
quantum states (e.g. "$|\psi_1\rangle$ with probability $q_1$, or
$|\psi_2\rangle$ with probability $q_2$"), layered on top of the quantum
description, rather than being another pure state. A pure state's
$\rho$ never mixes two possibilities in this sense — its rank-$1$-ness is
exactly the algebraic statement of that fact.

### Density matrices as expectation-value machines

The density matrix isn't just a repackaging of $|\psi\rangle$ — it is the
natural object for computing expectation values. For any observable
(Hermitian operator) $O$, $\text{Tr}(\rho O) = \langle\psi|O|\psi\rangle$,
the expectation value of $O$ in state $|\psi\rangle$, proved directly from
the trace's cyclic/completeness properties in today's Solutions. This
identity is what makes density matrices indispensable once mixed states
enter the picture (from Day 7 onward, e.g. the reduced state of one half
of an entangled pair): the *same* formula $\text{Tr}(\rho O)$ computes
expectation values whether $\rho$ is pure or mixed, whereas the bra-ket
form $\langle\psi|O|\psi\rangle$ only makes sense for a pure state with a
definite state vector.

### Completing single-qubit unitaries: Euler decomposition and $R_z$

Day 4 built $X, Y, Z, H$ from first principles. Those are specific,
named unitaries; the general statement is that **every** single-qubit
unitary $U$ can be written, up to an overall (physically unobservable)
phase, as a product of three rotations:
$$U = e^{i\alpha}\, R_z(\beta)\, R_y(\theta)\, R_z(\delta)$$
for real angles $\alpha,\beta,\theta,\delta$, where
$$R_z(\theta) = \begin{pmatrix} e^{-i\theta/2} & 0 \\ 0 & e^{i\theta/2}
\end{pmatrix}, \qquad R_y(\theta) = \begin{pmatrix}
\cos(\theta/2) & -\sin(\theta/2) \\ \sin(\theta/2) & \cos(\theta/2)
\end{pmatrix}$$
are rotations by angle $\theta$ about the Bloch-sphere $z$- and $y$-axes
respectively (consistent with Day 4's Bloch-sphere picture: $R_z(\theta)$
fixes the $z$-coordinate of a Bloch vector and rotates the $x$-$y$ plane by
$\theta$, and similarly for $R_y$ in the $z$-$x$ plane). This is the
"Z-Y-Z Euler decomposition" of $SU(2)$/$U(2)$, and it is the sense in which
Day 4's specific gates and today's general rotations *complete* the
single-qubit picture: any unitary evolution a single qubit can undergo is
one of these three-rotation products.

### Universal gate sets and the Solovay–Kitaev theorem

A real quantum computer does not implement arbitrary real-valued angles
$\beta,\theta,\delta$ as native operations — it implements a small, fixed
set of gates (e.g. $H$ and $T = \text{diag}(1, e^{i\pi/4})$) and must
*compile* any desired unitary into a finite sequence of them. The
**Solovay–Kitaev theorem** guarantees this is always possible to arbitrary
accuracy: for any single-qubit unitary $U$ and any $\varepsilon > 0$, there
is a sequence of gates from $\{H,T\}$ of length $O(\log^c(1/\varepsilon))$
(for a small constant $c$) whose product is within distance $\varepsilon$
of $U$ (in operator norm). We state this today as a fact, without proving
it — the proof is a substantial independent result — because its
*consequence* is what matters practically: a compiler never needs a
gate set matching every possible rotation angle; a small universal set
plus enough compiled gates gets arbitrarily close to any single-qubit
unitary, and (with an analogous statement for entangling gates) to any
multi-qubit unitary at all.

## Common misconceptions

**"Superposition just means the qubit has an unknown, definite value, and
measurement reveals which one it secretly was all along."** This is the
single most common wrong mental model of superposition, and it is wrong in
a way that today's own results directly refute — not just as a matter of
philosophical interpretation, but as a matter of the mathematics giving
different, checkable predictions.

If $|\psi\rangle = \alpha|0\rangle + \beta|1\rangle$ merely encoded
classical uncertainty — "it's secretly $|0\rangle$ with probability
$|\alpha|^2$ or secretly $|1\rangle$ with probability $|\beta|^2$, we just
don't know which yet" — then the *amplitudes* $\alpha,\beta$ would be
doing no work beyond their squared magnitudes: only $|\alpha|^2$ and
$|\beta|^2$ would ever matter, exactly as only the probabilities (not
some finer-grained phase) matter for a classical unknown coin. But
amplitudes are complex numbers, not just probabilities in disguise, and
their phases are physically real and detectable. $|+\rangle =
\frac{1}{\sqrt2}(|0\rangle+|1\rangle)$ and $|-\rangle =
\frac{1}{\sqrt2}(|0\rangle-|1\rangle)$ assign the *same* squared magnitudes
($\frac12,\frac12$) to $|0\rangle$ and $|1\rangle$ — a classical
"unknown-value" model would say these are the same 50/50 coin, with
nothing to distinguish them. Yet they are provably different physical
states: Exercise 2 computes $|\langle+|+\rangle|^2 = 1$ and
$|\langle-|+\rangle|^2 = 0$, so measuring $|+\rangle$ in the
$\{|+\rangle,|-\rangle\}$ basis gives a *deterministic* outcome, while a
genuinely classical 50/50-in-the-standard-basis coin, reinterpreted in any
other basis, would still show some residual randomness rather than
snapping to certainty. The relative *sign* between $\alpha$ and $\beta$ —
information a bare probability distribution cannot even represent — is
exactly what flips the standard basis's "maximally random" outcome into
the $\{|+\rangle,|-\rangle\}$ basis's "perfectly certain" outcome.

The mechanism behind this is **interference**: complex amplitudes can
partially or fully cancel when combined, in a way that plain
non-negative probabilities structurally cannot (probabilities only add).
Rewriting $|0\rangle$ and $|1\rangle$ in terms of $|+\rangle, |-\rangle$
and substituting into $|\psi\rangle=\alpha|0\rangle+\beta|1\rangle$ shows
the amplitude on $|+\rangle$ is $\frac{1}{\sqrt2}(\alpha+\beta)$ and on
$|-\rangle$ is $\frac{1}{\sqrt2}(\alpha-\beta)$: whenever $\alpha=\beta$
(as for $|\psi\rangle=|+\rangle$ itself) the $|-\rangle$ amplitude cancels
to exactly zero. There is no classical "unknown coin" picture that
produces exact cancellation like this — a genuine unknown-value model has
no notion of two possibilities cancelling each other out, only of one
possibility or the other being true. The correct statement is: a
superposition is a single physical state whose measurement statistics are
basis-dependent and governed by complex amplitudes capable of
interference; it is not a compact way of saying "one of these classical
values, we just haven't looked yet."

## Worked example

**Claim:** for $|\varphi\rangle = |+\rangle =
\frac{1}{\sqrt2}(|0\rangle+|1\rangle)$, the density matrix
$\rho = |\varphi\rangle\langle\varphi|$ satisfies all of today's structural
properties, and $\text{Tr}(\rho Z)$ correctly reproduces
$\langle\varphi|Z|\varphi\rangle$ for the Pauli observable $Z$.

**Building $\rho$.** In the standard basis, $|\varphi\rangle =
\frac{1}{\sqrt2}\binom{1}{1}$, so $\langle\varphi| =
\frac{1}{\sqrt2}(1,1)$, and
$$\rho = |\varphi\rangle\langle\varphi| = \frac12
\begin{pmatrix}1\\1\end{pmatrix}\begin{pmatrix}1&1\end{pmatrix}
= \frac12\begin{pmatrix}1&1\\1&1\end{pmatrix}.$$

**Trace $1$.** $\text{Tr}(\rho) = \frac12 + \frac12 = 1$. Matches
$\langle\varphi|\varphi\rangle = 1$ (already known: $|+\rangle$ is
normalized).

**Hermitian.** $\rho$ is real and symmetric here, so trivially
$\rho^\dagger = \rho^T = \rho$.

**Positive semidefinite.** Eigenvalues of $\frac12\begin{pmatrix}1&1\\1&1
\end{pmatrix}$: characteristic polynomial $(\frac12-\lambda)^2 -
\frac14 = 0 \Rightarrow \lambda(\lambda - 1) = 0 \Rightarrow \lambda \in
\{0,1\}$ — both $\ge 0$, confirming positive semidefiniteness, and both
consistent with the general rank-$1$ claim ahead of solving it in full
generality in Exercise 4 below: eigenvalue $1$ (on $|\varphi\rangle$
itself) and eigenvalue $0$ (on the orthogonal state, which here is
$|-\rangle$ — check directly: $\rho|-\rangle = \frac12
\begin{pmatrix}1&1\\1&1\end{pmatrix}\frac{1}{\sqrt2}\binom{1}{-1} =
\frac{1}{2\sqrt2}\binom{1-1}{1-1} = \binom00$).

**Expectation value via the trace formula.** $Z =
\begin{pmatrix}1&0\\0&-1\end{pmatrix}$, so
$$\rho Z = \frac12\begin{pmatrix}1&1\\1&1\end{pmatrix}
\begin{pmatrix}1&0\\0&-1\end{pmatrix} =
\frac12\begin{pmatrix}1&-1\\1&-1\end{pmatrix}, \qquad
\text{Tr}(\rho Z) = \frac12(1) + \frac12(-1) = 0.$$
Directly: $\langle\varphi|Z|\varphi\rangle = \frac12(1,1)
\begin{pmatrix}1&0\\0&-1\end{pmatrix}\binom{1}{1} = \frac12(1,1)\binom{1}{-1}
= \frac12(1-1) = 0$. The two computations agree, as the general identity
$\text{Tr}(\rho O)=\langle\psi|O|\psi\rangle$ (proved for arbitrary
$|\psi\rangle$ and $O$ in Exercise 5's solution) guarantees they always
will; this also matches the physical picture from Day 4 — $|+\rangle$
sits on the Bloch sphere's equator, where the $Z$-axis component (and
hence $\langle Z\rangle$) is exactly $0$.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. For $|\psi\rangle = \frac{3}{5}|0\rangle + \frac{4i}{5}|1\rangle$,
   compute the Born-rule measurement probabilities in the standard basis
   $\{|0\rangle,|1\rangle\}$, and verify they sum to $1$.
2. Let $|+\rangle = \frac{1}{\sqrt2}(|0\rangle+|1\rangle)$ and
   $|-\rangle = \frac{1}{\sqrt2}(|0\rangle-|1\rangle)$. Compute
   $|\langle+|+\rangle|^2$ and $|\langle-|+\rangle|^2$, and explain why
   this shows measuring $|+\rangle$ in the $\{|+\rangle,|-\rangle\}$ basis
   gives a deterministic outcome, in contrast to the $50/50$ split
   obtained measuring the same state in the standard basis.
3. For a normalized $|\psi\rangle$ and $\rho = |\psi\rangle\langle\psi|$,
   prove $\text{Tr}(\rho) = 1$, $\rho^\dagger = \rho$, and $\rho \ge 0$
   (positive semidefinite).
4. Prove $\rho = |\psi\rangle\langle\psi|$ has eigenvalue $1$ with
   eigenvector $|\psi\rangle$, and eigenvalue $0$ on every vector
   orthogonal to $|\psi\rangle$ — i.e. $\rho$ is rank $1$.
5. Prove $\text{Tr}(\rho O) = \langle\psi|O|\psi\rangle$ for any operator
   $O$, by direct trace computation using an orthonormal basis and the
   completeness relation.
6. Given $R_z(\theta) = \begin{pmatrix}e^{-i\theta/2}&0\\0&e^{i\theta/2}
   \end{pmatrix}$, verify $R_z(\theta)$ is unitary for every real $\theta$,
   and compute $R_z(\pi/2)|0\rangle$ explicitly.
7. State (without proving the full Solovay–Kitaev theorem) why a small
   fixed gate set such as $\{H,T\}$ can approximate any single-qubit
   unitary to arbitrary precision, and why this matters practically.

## Solutions

**1.** $|\langle 0|\psi\rangle|^2 = \left|\frac35\right|^2 = \frac{9}{25}$,
and $|\langle 1|\psi\rangle|^2 = \left|\frac{4i}{5}\right|^2 =
\frac{16}{25}$ (using $|4i|^2 = 4^2\cdot|i|^2 = 16$). Sum:
$\frac{9}{25}+\frac{16}{25} = \frac{25}{25} = 1$, as required — this is
exactly the same normalization check performed on this state back in Day
3, now stated in Born-rule language: the two squared amplitudes *are* the
two measurement probabilities.

**2.** $\langle+|+\rangle = 1$ since $|+\rangle$ is normalized, so
$|\langle+|+\rangle|^2 = 1$. For $\langle-|+\rangle$:
$$\langle-|+\rangle = \frac{1}{\sqrt2}(\langle0|-\langle1|)\cdot
\frac{1}{\sqrt2}(|0\rangle+|1\rangle) = \frac12\big(\langle0|0\rangle +
\langle0|1\rangle - \langle1|0\rangle - \langle1|1\rangle\big) =
\frac12(1+0-0-1) = 0,$$
using orthonormality of $\{|0\rangle,|1\rangle\}$. So
$|\langle-|+\rangle|^2 = 0$. By the Born rule applied to the orthonormal
basis $\{|+\rangle,|-\rangle\}$, measuring $|+\rangle$ in that basis gives
outcome "$+$" with probability $|\langle+|+\rangle|^2=1$ and outcome
"$-$" with probability $|\langle-|+\rangle|^2=0$ — a deterministic result.
This is the *same* state $|+\rangle$ that gives probabilities
$|\langle0|+\rangle|^2 = |\langle1|+\rangle|^2 = \frac12$ (a $50/50$
split) in the standard basis. Nothing about $|+\rangle$ changed between
the two calculations — only the basis relative to which the Born rule was
applied — which is the concrete demonstration that measurement statistics
are a property of *state and basis together*, not of the state alone.

**3.** *Trace.* Writing $|\psi\rangle$ as a column vector and
$\langle\psi|$ as its conjugate-transpose row vector, $\rho=|\psi\rangle
\langle\psi|$ is the outer product, and by the cyclic property of the
trace, $\text{Tr}(|\psi\rangle\langle\psi|) =
\text{Tr}(\langle\psi|\,|\psi\rangle) = \langle\psi|\psi\rangle = 1$,
using normalization of $|\psi\rangle$.

*Hermiticity.* $\rho^\dagger = (|\psi\rangle\langle\psi|)^\dagger =
\langle\psi|^\dagger\,|\psi\rangle^\dagger$ (reversing order under the
adjoint, $(AB)^\dagger=B^\dagger A^\dagger$). Since $\langle\psi|^\dagger =
|\psi\rangle$ and $|\psi\rangle^\dagger = \langle\psi|$, this is
$|\psi\rangle\langle\psi| = \rho$.

*Positive semidefiniteness.* For any vector $|\varphi\rangle$,
$$\langle\varphi|\rho|\varphi\rangle = \langle\varphi|\psi\rangle
\langle\psi|\varphi\rangle = \langle\varphi|\psi\rangle
\big(\langle\varphi|\psi\rangle\big)^* = \big|\langle\varphi|\psi\rangle
\big|^2 \ge 0,$$
using $\langle\psi|\varphi\rangle = \langle\varphi|\psi\rangle^*$
(conjugate symmetry of the inner product). Since this holds for every
$|\varphi\rangle$, $\rho \ge 0$.

**4.** $\rho|\psi\rangle = |\psi\rangle\langle\psi|\psi\rangle =
|\psi\rangle\cdot 1 = |\psi\rangle$, using normalization — so $|\psi\rangle$
is an eigenvector of $\rho$ with eigenvalue $1$. Now let $|\varphi\rangle$
be any vector with $\langle\psi|\varphi\rangle = 0$ (orthogonal to
$|\psi\rangle$): $\rho|\varphi\rangle = |\psi\rangle\langle\psi|\varphi
\rangle = |\psi\rangle\cdot 0 = 0$ — eigenvalue $0$. Since
$\{|\psi\rangle\}$ together with its orthogonal complement (dimension
$n-1$ in an $n$-dimensional space) spans the entire space, $\rho$'s full
eigenvalue spectrum is exactly $\{1$ (multiplicity $1$, eigenvector
$|\psi\rangle$)$, 0$ (multiplicity $n-1$, every vector orthogonal to
$|\psi\rangle$)$\}$. A matrix with only one nonzero eigenvalue, of
multiplicity $1$, has rank $1$ — the algebraic signature of a pure state.
(Contrast: a mixed state's density matrix has two or more nonzero
eigenvalues, reflecting genuine classical uncertainty over more than one
quantum possibility, rather than a single definite $|\psi\rangle$.)

**5.** Let $\{|e_i\rangle\}$ be any orthonormal basis, so $\sum_i
|e_i\rangle\langle e_i| = I$ (completeness relation). Then
$$\text{Tr}(\rho O) = \sum_i \langle e_i|\,\rho O\,|e_i\rangle =
\sum_i \langle e_i|\psi\rangle\langle\psi|O|e_i\rangle.$$
Each term is a scalar, so it may be reordered:
$$= \sum_i \langle\psi|O|e_i\rangle\langle e_i|\psi\rangle =
\langle\psi|O\left(\sum_i |e_i\rangle\langle e_i|\right)|\psi\rangle =
\langle\psi|O\,I\,|\psi\rangle = \langle\psi|O|\psi\rangle,$$
using the completeness relation in the middle step. This holds for *any*
operator $O$ and any orthonormal basis used to evaluate the trace (the
trace itself is basis-independent, so the choice of $\{|e_i\rangle\}$ was
only a computational device).

**6.** $R_z(\theta)$ is diagonal, so its adjoint is just the entrywise
complex conjugate:
$$R_z(\theta)^\dagger = \begin{pmatrix}e^{i\theta/2}&0\\0&e^{-i\theta/2}
\end{pmatrix}.$$
Then
$$R_z(\theta)^\dagger R_z(\theta) = \begin{pmatrix}e^{i\theta/2}e^{-i\theta/2}
&0\\0&e^{-i\theta/2}e^{i\theta/2}\end{pmatrix} =
\begin{pmatrix}1&0\\0&1\end{pmatrix} = I,$$
and identically $R_z(\theta)R_z(\theta)^\dagger = I$ (diagonal matrices
commute with their own adjoints), so $R_z(\theta)$ is unitary for every
real $\theta$.

For $R_z(\pi/2)$: $\theta/2 = \pi/4$, so $R_z(\pi/2) =
\begin{pmatrix}e^{-i\pi/4}&0\\0&e^{i\pi/4}\end{pmatrix}$. Applied to
$|0\rangle = \binom{1}{0}$:
$$R_z(\pi/2)|0\rangle = e^{-i\pi/4}\binom{1}{0} = e^{-i\pi/4}|0\rangle =
\left(\cos\frac\pi4 - i\sin\frac\pi4\right)|0\rangle =
\frac{\sqrt2}{2}(1-i)\,|0\rangle.$$
This is $|0\rangle$ multiplied by an overall phase $e^{-i\pi/4}$ — a
physically unobservable change (any measurement's Born-rule probabilities
depend only on $|\langle e_i|\psi\rangle|^2$, and an overall phase factors
out of every such squared amplitude unchanged). This illustrates why the
Euler decomposition in the Theory section is only claimed "up to an
overall phase" — $R_z$ acting on a basis state it fixes up to phase is the
simplest possible instance of that caveat.

**7.** The Solovay–Kitaev theorem states that for any single-qubit
unitary $U$ and any desired accuracy $\varepsilon>0$, there exists a
finite word in a fixed universal generating set (such as $\{H,T\}$) whose
product approximates $U$ to within $\varepsilon$ in operator norm, using a
gate sequence of length only *polylogarithmic* in $1/\varepsilon$ (i.e.
$O(\log^c(1/\varepsilon))$ gates, not the exponentially worse naive bound).
Practically, this matters because real hardware exposes only a small,
fixed set of native gates — it cannot implement an arbitrary real-valued
rotation angle directly. Without a theorem like this, "compile an
arbitrary single-qubit unitary $R_z(\beta)R_y(\theta)R_z(\delta)$ (today's
Euler decomposition) into hardware gates" would be an open question of
uncertain cost; Solovay–Kitaev guarantees the compilation is always
possible, and cheaply (only polylogarithmically many gates) in the
desired precision — which is why $\{H,T\}$ (or any other small universal
set) is a genuinely sufficient target for a quantum compiler, not merely
a convenient theoretical idealization.

## Journal template

```
## Day 6 — Measurement, the Born rule & density matrices
Key idea in my own words: ...
What confused me: ...
```
