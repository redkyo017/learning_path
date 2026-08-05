# Day 4 Primer — Normal matrices, spectral theorem & the Bloch sphere

## Warm-up

Day 3 built the vocabulary you will rely on throughout today. The Hermitian
adjoint $A^\dagger = (\bar A)^T$ is the core operation; a unitary matrix
satisfies $U^\dagger U = UU^\dagger = I$; and Day 3 proved directly that
every eigenvalue of a unitary matrix has modulus 1 by taking $Uv = \lambda v$,
applying $U^\dagger U = I$, and comparing norms. Keep that proof in mind —
today the same modulus-1 fact will re-emerge from a completely different
direction, as a corollary of the spectral theorem, and seeing both routes
side by side is half the lesson.

Day 3 also introduced the qubit state $|\psi\rangle = \alpha|0\rangle +
\beta|1\rangle$ with $|\alpha|^2 + |\beta|^2 = 1$. The two complex
parameters live on a 3-sphere in $\mathbb{C}^2$, but after quotienting out
the unobservable global phase one real degree of freedom drops away, leaving
a two-parameter family that turns out to be the surface of a unit sphere in
$\mathbb{R}^3$ — the Bloch sphere. Today's final section makes that
correspondence explicit and computable.

The reversible gates of Day 1 — $X$ was already there as the classical NOT
— are the direct ancestors of the single-qubit unitaries $X, Y, Z, H$ you
will study today. Day 2's Chernoff-amplification ideas live further in the
background, but there is a structural resonance: both the amplification bound
and the spectral theorem take something potentially unruly and bring it under
control by identifying the right basis to work in.

## The hook

Consider $A = \begin{pmatrix}1&1\\-1&1\end{pmatrix}$. Since $A$ is real,
$A^\dagger = A^T = \begin{pmatrix}1&-1\\1&1\end{pmatrix}$. Direct computation
gives $AA^\dagger = 2I$ and $A^\dagger A = 2I$, so $AA^\dagger = A^\dagger A$
— $A$ is normal. Yet $A \neq A^\dagger$ (not Hermitian) and $AA^\dagger = 2I
\neq I$ (not unitary). This is not a marginal case: $A$ belongs strictly to
the "normal" family and lies strictly outside both the Hermitian and unitary
families.

Because $A$ is normal, the spectral theorem guarantees a full orthonormal
eigenbasis and a decomposition $A = UDU^\dagger$. From $\mathrm{tr}(A) = 2$,
$\det(A) = 2$ the characteristic equation is $\lambda^2 - 2\lambda + 2 = 0$,
yielding $\lambda = 1 \pm i$ — complex numbers with $|1 \pm i| = \sqrt{2}$.
The worked example labelled **Claim:** in the main file carries the full
construction: eigenvectors found, orthonormality checked, and $UDU^\dagger$
verified by direct matrix multiplication.

The central point is that normality — the condition $AA^\dagger = A^\dagger A$
— is the exact algebraic hypothesis the spectral theorem requires, and
neither Hermitian nor unitary alone is sufficient or necessary. The hook
matrix is a concrete witness: the theorem works for $A$ because $A$ is
normal, full stop.

## The pictures

Three mental pictures will anchor the day's ideas before you reach the algebra.

The first is the Bloch sphere: a unit sphere in $\mathbb{R}^3$ with
$|0\rangle$ at the north pole and $|1\rangle$ at the south pole. The
equator carries equal-weight superpositions — $|{+}\rangle$ on the positive
$x$-axis, $|{-}\rangle$ on the negative $x$-axis. Two states are orthogonal
if and only if their Bloch points are antipodal. Each Pauli's eigenvectors
sit at the two ends of their named axis: $Z$'s eigenvectors at the poles,
$X$'s at the east and west equatorial points, $Y$'s at the front and back.
A single-qubit unitary acts on the sphere as a rigid rotation; the $X, Y, Z$
Paulis are each a $180°$ rotation about their own named axis.

The second picture is a nested Venn diagram. Draw a large outer circle labelled
"normal." Inside it, draw two overlapping inner circles: "Hermitian" on the
left, "unitary" on the right. The overlap region — both simultaneously —
contains $X, Y, Z$, and $H$, each of which is its own adjoint and its own
inverse. The hook matrix $A$ lives inside the outer circle but outside both
inner ones. This picture makes visible exactly what the spectral theorem says:
its hypothesis is membership in the outer circle, not either inner one.
Hermitian and unitary are the physically motivated special cases; normal is
the correct frame.

The third picture is the spectral decomposition as a frame of perpendicular
axes. A normal matrix specifies a new coordinate system: its orthonormal
eigenvectors point along the axes, and the eigenvalues describe what happens
along each axis — a real positive stretch, a complex rotation, or anything
in between. In that eigen-frame the matrix is diagonal, acting on each axis
independently. The matrix $U$ in $A = UDU^\dagger$ rotates the standard frame
to the eigen-frame; $D$ applies the per-axis action; $U^\dagger$ rotates back.
Any normal matrix is geometrically nothing but a frame and a set of independent
one-dimensional actions.

## Concrete-first walkthrough

The section **Normal matrices and the spectral theorem** states the definition
— $A$ is normal iff $AA^\dagger = A^\dagger A$ — and the spectral theorem in
both directions: normal iff $A = UDU^\dagger$ for unitary $U$ and diagonal
$D$, equivalently iff $A$ has an orthonormal eigenbasis. The easy direction
(diagonalizable implies normal) comes from the fact that diagonal matrices
commute with their own conjugate transposes entry-wise: each diagonal entry
of $DD^\dagger$ and $D^\dagger D$ is the same $|d_i|^2$, so $DD^\dagger =
D^\dagger D$, and conjugating by $U$ preserves that equality.

The hard direction uses Schur's theorem as a black box: every complex matrix
can be written $A = VTV^\dagger$ for unitary $V$ and upper-triangular $T$.
If $A$ is normal, $T$ inherits normality. The key lemma then shows that a
normal upper-triangular matrix must be diagonal: comparing the $(i, i)$ entry
of $TT^\dagger$ with that of $T^\dagger T$, upper-triangularity makes one sum
run down a column and the other along a row; normality forces them equal,
which at $i = 1$ leaves the first row's off-diagonal squared-magnitude terms
on one side and nothing on the other, forcing those terms to zero; induction
clears the rest.

The section **Hermitian matrices are normal, with real eigenvalues** is
concise. Normality follows in one step: $A = A^\dagger$ gives $AA^\dagger =
A^2 = A^\dagger A$. For real eigenvalues, left-multiply $Av = \lambda v$
by $v^\dagger$ to form the scalar $v^\dagger A v = \lambda\|v\|^2$. Because
$A = A^\dagger$, taking the conjugate transpose of both sides shows the scalar
equals its own conjugate — hence real — and dividing by positive real
$\|v\|^2$ makes $\lambda$ real.

The section **Unitary matrices are normal, and the spectral theorem recovers
modulus-1 eigenvalues** handles normality in one observation: $UU^\dagger =
I = U^\dagger U$ by definition, so the two products are already equal. The
spectral-theorem route to modulus-1 eigenvalues writes $U = VDV^\dagger$,
substitutes into $U^\dagger U = I$ to obtain $V(D^\dagger D)V^\dagger = I$,
and extracts $D^\dagger D = I$, so $|\lambda_i|^2 = 1$ for every eigenvalue.
The conclusion matches Day 3's direct norm argument; the two paths are
different routes to the same destination.

The section **The Pauli matrices and the Hadamard matrix** establishes a
general observation: if a matrix is simultaneously Hermitian and unitary,
its eigenvalues must be real (Hermitian) and modulus-1 (unitary), so they
can only be $\pm 1$, and the spectral theorem immediately gives $A^2 = I$.
Verifying that each of $X$, $Y$, $Z$, and $H$ is Hermitian and unitary
therefore pins down their eigenvalue sets $\{+1, -1\}$ and confirms they are
involutions without computing a characteristic polynomial — computing actual
eigenvectors still requires solving $(A \pm I)v = 0$, but the spectrum is
known in advance.

The section **The Bloch sphere** derives the coordinate formulas starting from
$|\psi\rangle = \cos(\theta/2)|0\rangle + e^{i\varphi}\sin(\theta/2)|1\rangle$
and computing $(x, y, z) = (2\mathrm{Re}(\bar\alpha\beta),\,
2\mathrm{Im}(\bar\alpha\beta),\, |\alpha|^2 - |\beta|^2)$. The double-angle
identity $2\sin(\theta/2)\cos(\theta/2) = \sin\theta$ converts $\bar\alpha\beta$
to $\tfrac{1}{2}e^{i\varphi}\sin\theta$; separating real and imaginary parts
gives $x = \sin\theta\cos\varphi$, $y = \sin\theta\sin\varphi$; and the
half-angle identity $\cos^2(\theta/2) - \sin^2(\theta/2) = \cos\theta$ gives
$z = \cos\theta$. Together these are the spherical-to-Cartesian map, and
$x^2 + y^2 + z^2 = 1$ follows immediately.

## Derivation roadmaps

For the spectral theorem, the key trick is the "triangular-normal is diagonal"
lemma used after Schur's triangularization. Schur gives $A = VTV^\dagger$ with
$T$ upper-triangular; normality of $A$ transfers to $T$ under the unitary
conjugation. Then compare the $(i, i)$ entries of $T^\dagger T$ and $TT^\dagger$:
upper-triangularity makes one sum run down a column and the other along a row,
and normality forces them equal. At $i = 1$ the row-$i$ sum carries extra
off-diagonal squared-magnitude terms that the column-$i$ sum lacks; normality
forces those terms to zero. Induction extends the argument to every row. What
you fill in is the explicit index bookkeeping — writing out which terms appear
in the column-$i$ sum versus the row-$i$ sum and confirming the boundary terms
are exactly those forced to zero.

For the Hermitian real-eigenvalue proof, the key trick is self-adjointness of
the scalar $s = v^\dagger Av$. Because $A = A^\dagger$, computing
$s^\dagger = v^\dagger A^\dagger v = v^\dagger Av = s$ shows $s = \bar s$, so
$s$ is real. What you fill in is why "conjugate transpose of a $1\times1$
matrix" reduces to complex conjugation, and that dividing real $s$ by positive
real $\|v\|^2$ gives real $\lambda$.

For the Bloch coordinate derivation, the key trick is the double-angle identity
applied to $\bar\alpha\beta$ after substituting the spherical parameterization.
Writing $\bar\alpha\beta = \cos(\theta/2)\,e^{i\varphi}\sin(\theta/2) =
\tfrac{1}{2}e^{i\varphi}\sin\theta$ pulls the real and imaginary parts of $x$
and $y$ directly from the exponential. For $z$, the half-angle difference
$\cos^2(\theta/2) - \sin^2(\theta/2) = \cos\theta$ works directly. What you
fill in is verifying $\sin^2\theta\cos^2\varphi + \sin^2\theta\sin^2\varphi
+ \cos^2\theta = 1$, confirming the map lands on the unit sphere.

## Flashcards

Q: What is the definition of a normal matrix?
A: $A$ is normal iff $AA^\dagger = A^\dagger A$ — it commutes with its own adjoint.

Q: State the spectral theorem for normal operators.
A: $A$ is normal if and only if $A = UDU^\dagger$ for some unitary $U$ and
diagonal $D$; equivalently, $A$ has an orthonormal basis of eigenvectors.

Q: What is the key trick for proving Hermitian matrices have real eigenvalues?
A: Form $s = v^\dagger Av$; since $A = A^\dagger$, the scalar satisfies $s = \bar s$
(self-adjoint), so $s$ is real; divide by positive real $\|v\|^2$ to get real $\lambda$.

Q: What are the eigenvalues of each Pauli matrix, and why?
A: Each Pauli has eigenvalues $\pm 1$: Hermitian forces real eigenvalues;
unitary forces modulus-1 eigenvalues; a real number of modulus 1 can only be $\pm 1$.

Q: What role does $H$ play on the Bloch sphere?
A: $H$ exchanges the $Z$-basis $\{|0\rangle, |1\rangle\}$ with the $X$-basis
$\{|{+}\rangle, |{-}\rangle\}$; geometrically it is a $180°$ rotation about
the axis halfway between the $x$- and $z$-axes.

Q: Write the Bloch coordinate formula for $|\psi\rangle = \alpha|0\rangle + \beta|1\rangle$.
A: $(x, y, z) = \bigl(2\mathrm{Re}(\bar\alpha\beta),\;
2\mathrm{Im}(\bar\alpha\beta),\; |\alpha|^2 - |\beta|^2\bigr)$, equal to
$(\sin\theta\cos\varphi,\, \sin\theta\sin\varphi,\, \cos\theta)$ in spherical form.

Q: Give an example of a matrix that is normal but neither Hermitian nor unitary.
A: $A = \begin{pmatrix}1&1\\-1&1\end{pmatrix}$: satisfies $AA^\dagger = A^\dagger A = 2I$,
yet $A \neq A^\dagger$ (not Hermitian) and $2I \neq I$ (not unitary).

Q: How does the spectral theorem give a second proof that unitary eigenvalues have modulus 1?
A: Write $U = VDV^\dagger$; substituting into $U^\dagger U = I$ gives
$V(D^\dagger D)V^\dagger = I$, hence $D^\dagger D = I$, so $|\lambda_i|^2 = 1$
for every eigenvalue.
