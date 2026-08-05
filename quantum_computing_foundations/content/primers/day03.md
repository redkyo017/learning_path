# Day 3 primer — Complex vector spaces & the qubit
*(Before you read day03.md)*

## Warm-up

Day 01 (primers/day01.md) showed how Boolean logic becomes reversible
computation — a warm-up for the constraint that quantum gates must be
invertible. Day 02 (primers/day02.md) introduced probabilistic amplitude
and the Chernoff/Hoeffding bound, letting you reason about randomness
without being afraid of it. Today the underlying algebra deepens: the
scalars are no longer real numbers but complex numbers, and that single
change forces every familiar tool — length, angle, adjoint, eigenvector —
to be rebuilt from the ground up.

Before you open day03.md, sit with two warm-up questions. First: how does
the dot product $v\cdot w=\sum_i v_i w_i$ define squared length in
$\mathbb{R}^n$, and what breaks if you apply the same formula in
$\mathbb{C}^n$ without modification? Second: real orthogonal matrices
satisfy $Q^TQ=I$; what is the natural complex analogue of the transpose
$Q^T$, and why must it conjugate entries as well as transpose them? The
answers to both are the pivots on which today's first two sections turn.

## The hook

Here is a matrix you will see in the Worked example under the bold label
**Claim:**

$$U = \frac{1}{\sqrt2}\begin{pmatrix}1 & i\\ i & 1\end{pmatrix}.$$

It is unitary. Its eigenvalues, found via the characteristic polynomial,
come out as $\lambda = \frac{1}{\sqrt2}(1\pm i)$ — complex numbers, not
real ones. Compute their modulus: $|1\pm i| = \sqrt{1^2+1^2} = \sqrt2$,
so $|\lambda| = \frac{1}{\sqrt2}\cdot\sqrt2 = 1$ exactly. Neither
eigenvalue is real; both sit precisely on the unit circle in the complex
plane.

This is not a coincidence unique to this matrix. Every unitary matrix,
on every one of its eigenvalues, enforces $|\lambda|=1$ — the unit circle
is exactly where quantum phases live. In quantum mechanics, applying a gate
multiplies state amplitudes by the gate's eigenvalues. If those eigenvalues
could exceed 1 in modulus, amplitudes would blow up; if they shrank below 1,
probability would drain away. Unitarity is precisely the postulate that
prevents both, by locking every eigenvalue on the circle: rotating phases,
never scaling them.

## The pictures

Picture one: draw the unit circle $|\lambda|=1$ in the complex plane, with
the real axis horizontal and the imaginary axis vertical. Mark the two
eigenvalues $\frac{1}{\sqrt2}(1+i)$ and $\frac{1}{\sqrt2}(1-i)$ as dots on
the circle. Every eigenvalue of every unitary matrix lives somewhere on this
circle — no exceptions. A real orthogonal matrix has eigenvalues only at
$\pm1$ when real eigenvalues exist at all (a $2\times2$ rotation matrix
typically has none over $\mathbb{R}$), but a complex unitary always has $n$
eigenvalues counted with multiplicity, every one of them on the full circle,
corresponding to some phase-shift $e^{i\theta}$.

Picture two: a qubit lives in $\mathbb{C}^2$, a four-dimensional real space.
Normalization cuts this to three real degrees of freedom. Draw the state
vector as an arrow, annotate its two components $\alpha$ and $\beta$, and
shade two "shadow lengths" $|\alpha|^2$ and $|\beta|^2$ below the arrow.
Those shadows are nonneg reals that sum to exactly one — they are the
measurement probabilities — because normalization is exactly the condition
$|\alpha|^2+|\beta|^2=1$ defining a unit vector in the complex sense.

Picture three: imagine a bra $\langle\phi|$ as a socket and a ket
$|\psi\rangle$ as a plug. Snap bra onto ket — $\langle\phi|\psi\rangle$ —
and you get a scalar, a single complex number, the inner product. Reverse
the order — $|\psi\rangle\langle\phi|$ — and you get an $n\times n$ matrix,
a machine that acts on other vectors. Same two objects, reversed assembly
order, completely different output type. This asymmetry is the backbone of
outer-product notation and will reappear every time you write a spectral
decomposition $\sum_i\lambda_i|e_i\rangle\langle e_i|$ from Day 4 onward.

## Concrete-first walkthrough

Open **### The complex inner product, and why conjugation is forced**. The
critical failure is concrete: if you define squared length as $\sum_i v_i^2$,
take $v=(i,0)$ and compute $i^2=-1$, a negative number — the formula cannot
serve as a notion of length. The fix is to conjugate one factor:
$\langle v,v\rangle=\sum_i v_i^*v_i=\sum_i|v_i|^2\ge0$ always, because
$|v_i|^2$ is a nonneg real by definition of modulus. That one change
propagates: conjugate symmetry $\langle v,w\rangle=\langle w,v\rangle^*$
replaces plain symmetry, and conjugate-linearity in the first argument
replaces ordinary linearity there. Everything in day03.md flows from that
single structural decision.

Turn to **### The Hermitian adjoint**. The adjoint $A^\dagger$ is the
conjugate-transpose: transpose $A$, then conjugate every entry. It satisfies
$\langle Av,w\rangle=\langle v,A^\dagger w\rangle$ for all $v,w$ — the same
defining property that characterized the real transpose in your linear
algebra plan, now with the complex inner product in place of the real one.
One clean consequence: $(A^\dagger)^\dagger=A$, because transposing and
conjugating twice each return every entry to its starting value and position.

In **### Unitary matrices** you find three equivalent characterizations:
$U^\dagger U=I$; columns of $U$ form an orthonormal basis of $\mathbb{C}^n$;
and $\langle Uv,Uw\rangle=\langle v,w\rangle$ for all $v,w$. These are three
languages for one idea. The physical consequence is immediate: quantum gates
are unitary, so they preserve inner products, hence preserve normalization
$\langle\psi|\psi\rangle=1$, meaning total probability is conserved by every
quantum operation not by special arrangement but by mathematical necessity.

The section **### Eigenvalues of unitary matrices have modulus 1** delivers
the theorem the hook pointed to. The proof is three lines; read it with care
and trace exactly where conjugate-linearity and positive-definiteness each
contribute one indispensable step.

Reach **### The qubit** and verify the secondary example before reading it:
$|\psi\rangle=\frac{3}{5}|0\rangle+\frac{4i}{5}|1\rangle$ gives
$\langle\psi|\psi\rangle=\frac{9}{25}+\frac{16}{25}=1$, because
$|4i/5|^2=(4/5)^2|i|^2=16/25$ and $|i|=1$. Notice the trap: $|4i/5|^2$
is not $(4i/5)^2=-16/25$; modulus squares are always nonneg, plain squares
of complex numbers are not. A normalized vector in $\mathbb{C}^2$ has three
real degrees of freedom beyond the normalization constraint. Day 4 will show
that one of those three — global phase — is physically irrelevant, leaving
exactly two, which the Bloch sphere parametrizes as polar and azimuthal angles.

Close with **### Bra-ket notation, outer products, completeness**. The outer
product $|\psi\rangle\langle\phi|$ is an $n\times n$ matrix. The completeness
relation $\sum_i|e_i\rangle\langle e_i|=I$ says that summing the rank-1
projectors over all directions of an orthonormal basis returns the identity
— an algebraic fact you will invoke constantly from Day 6 onward, where
$|i\rangle\langle i|$ becomes the projector associated with measurement
outcome $i$.

## Derivation roadmaps

Three proofs in day03.md are load-bearing. For each, a key trick is named
below; fill in the algebra yourself before reading the Solutions section.

**Modulus-1 eigenvalues** (section **### Eigenvalues of unitary matrices
have modulus 1**). Key trick: unitaries preserve inner products, so
$\langle Uv,Uv\rangle=\langle v,v\rangle$; apply this with $Uv=\lambda v$,
pull $\lambda$ out of the first argument (conjugate-linearity gives
$\lambda^*$) and out of the second (linearity gives $\lambda$), leaving
$|\lambda|^2\langle v,v\rangle=\langle v,v\rangle$. What to fill in: the
positive-definiteness argument that justifies dividing both sides by
$\langle v,v\rangle>0$.

**Conjugation is forced** (section **### The complex inner product, and why
conjugation is forced**). Key trick: demand $\langle v,v\rangle\ge0$ for
all complex $v$; the naive formula $\sum v_i^2$ fails on $v=(i,0)$ by
giving $-1$; conjugating one factor forces $v_i^*v_i=|v_i|^2$, a nonneg
real. What to fill in: why $|v_i|^2\ge0$ follows from the definition of
the complex modulus as a squared distance in $\mathbb{R}^2$.

**Three unitary equivalences** (section **### Unitary matrices**). Key
trick: the $(i,j)$ entry of $U^\dagger U$ equals $\langle c_i,c_j\rangle$,
where $c_i$ is the $i$-th column of $U$, so $U^\dagger U=I$ is precisely
columns orthonormal. For the preservation direction, insert $U^\dagger U=I$
into $\langle Uv,Uw\rangle=v^\dagger U^\dagger Uw$. What to fill in: the
converse from preservation back to $U^\dagger U=I$, by testing the identity
on pairs of standard basis vectors.

## Flashcards

Q: State the conjugate-symmetry axiom for the complex inner product.
A: $\langle v,w\rangle=\langle w,v\rangle^*$. Over $\mathbb{R}$ this reduces to plain symmetry because conjugation is the identity on real numbers.

Q: Why must the complex inner product conjugate one argument?
A: Without conjugation, $\sum v_i^2$ can be negative (e.g. $v=(i,0)$ gives $-1$). Conjugating gives $\sum|v_i|^2\ge0$, making length well-defined.

Q: Define the Hermitian adjoint $A^\dagger$ of a matrix $A$.
A: $A^\dagger=\overline{A}^T$: transpose then conjugate every entry. It is the unique matrix satisfying $\langle Av,w\rangle=\langle v,A^\dagger w\rangle$ for all $v,w$.

Q: State three equivalent characterizations of a unitary matrix.
A: (1) $U^\dagger U=I$; (2) columns of $U$ form an orthonormal basis of $\mathbb{C}^n$; (3) $\langle Uv,Uw\rangle=\langle v,w\rangle$ for all $v,w$.

Q: Why do all eigenvalues of a unitary matrix have modulus 1?
A: If $Uv=\lambda v$, then $\langle v,v\rangle=\langle Uv,Uv\rangle=|\lambda|^2\langle v,v\rangle$; since $\langle v,v\rangle>0$, dividing gives $|\lambda|=1$.

Q: Write the qubit normalization condition and interpret each term.
A: $|\alpha|^2+|\beta|^2=1$. Each term is the probability of the corresponding measurement outcome; they must sum to one because total probability is one.

Q: How many real degrees of freedom does a normalized qubit have, and what reduces this to two?
A: Three (four real params minus one normalization constraint). Day 4 shows global phase is physically irrelevant, removing one more, leaving the two the Bloch sphere parametrizes.

Q: State the completeness relation for an orthonormal basis $\{|e_i\rangle\}$ of $\mathbb{C}^n$.
A: $\sum_i|e_i\rangle\langle e_i|=I$. Each outer product is the rank-1 projector onto $|e_i\rangle$; summing over a complete orthonormal basis returns the identity.

Q: What distinguishes the inner product $\langle\phi|\psi\rangle$ from the outer product $|\psi\rangle\langle\phi|$?
A: The inner product is a scalar (a complex number); the outer product is an $n\times n$ matrix acting as a linear operator. Same objects, reversed assembly order, different type.
