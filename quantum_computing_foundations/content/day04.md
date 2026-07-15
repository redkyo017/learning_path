# Day 4 — Normal Matrices, Spectral Theorem, Single-Qubit Unitaries & the Bloch Sphere

## Learning objectives

By the end of today you should be able to:
- State the definition of a normal matrix ($AA^\dagger = A^\dagger A$) and the
  spectral theorem for normal operators, and prove both directions of the
  theorem in the sense described below.
- Prove that every Hermitian matrix is normal and has only real eigenvalues,
  and that every unitary matrix is normal and has only modulus-$1$
  eigenvalues — connecting the latter fact to Day 3's direct proof via the
  spectral theorem itself.
- Verify, from first principles, that $X, Y, Z$ are each Hermitian and
  unitary (hence involutions), and compute each one's eigenvalues and
  eigenvectors by hand.
- Verify the spectral theorem directly for the Hadamard matrix $H$: find its
  eigenvalues and eigenvectors, and reconstruct $H = UDU^\dagger$ by explicit
  matrix multiplication.
- Derive the Bloch-sphere coordinate formulas $(x,y,z) = (\sin\theta\cos\varphi,
  \ \sin\theta\sin\varphi,\ \cos\theta)$ from a general qubit state, and use
  them to compute and predict how single-qubit gates move points on the
  sphere.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*,
  or Nielsen & Chuang, *Quantum Computation and Quantum Information* — the
  chapters covering normal matrices / the spectral theorem, the Pauli and
  Hadamard gates, and the Bloch sphere.
- The Day 4 section of the implementation plan for this course:
  `quantum_computing_foundations/docs/superpowers/plans/2026-07-13-quantum-computing-15-day-plan.md`
  (has the exact time budget and the code listing referenced in the Code lab
  section below).
- The theory below is self-contained — you do not need the book to do
  today's work, but reading the matching chapter alongside this is useful
  for a second explanation in different words.
- Builds directly on Day 3's definitions of the Hermitian adjoint
  ($A^\dagger = (\bar A)^T$) and unitary matrices ($U^\dagger U = UU^\dagger =
  I$), and on Day 3's proof that every eigenvalue of a unitary matrix has
  modulus $1$.

## Theory

### Normal matrices and the spectral theorem

A matrix $A \in \mathbb{C}^{n\times n}$ is **normal** iff it commutes with
its own adjoint: $AA^\dagger = A^\dagger A$. This single algebraic condition
turns out to be exactly the right one to guarantee the strongest possible
diagonalization result over $\mathbb{C}$:

**Spectral theorem (normal operators).** $A$ is normal if and only if $A =
UDU^\dagger$ for some unitary $U$ and diagonal $D$. Equivalently: $A$ is
normal iff it has an orthonormal basis of eigenvectors (the columns of $U$),
with the corresponding eigenvalues as the diagonal entries of $D$.

**Proof, easy direction ($A=UDU^\dagger \Rightarrow A$ normal).** Compute
both products directly, using $U^\dagger U = I$:
$$AA^\dagger = (UDU^\dagger)(UDU^\dagger)^\dagger = UDU^\dagger\,UD^\dagger U^\dagger
= UDD^\dagger U^\dagger,$$
$$A^\dagger A = (UDU^\dagger)^\dagger(UDU^\dagger) = UD^\dagger U^\dagger\,UDU^\dagger
= UD^\dagger D U^\dagger.$$
$D$ is diagonal, say with entries $d_1,\dots,d_n$; then $D^\dagger$ is
diagonal with entries $\bar d_1,\dots,\bar d_n$, and both $DD^\dagger$ and
$D^\dagger D$ are diagonal with entries $|d_i|^2$ — diagonal matrices always
commute with their own conjugates entrywise, so $DD^\dagger = D^\dagger D$.
Hence $AA^\dagger = A^\dagger A$.

**Proof, hard direction ($A$ normal $\Rightarrow A = UDU^\dagger$).** This
direction uses one standard prior fact, cited without re-proof (it's a
general linear-algebra result, not specific to quantum computing): **Schur's
theorem** — every $A\in\mathbb{C}^{n\times n}$ can be written $A = VTV^\dagger$
for some unitary $V$ and *upper triangular* $T$ (triangularize by unitary
similarity; this always exists over $\mathbb{C}$, whether or not $A$ is
normal). Given this, the argument is:

1. If $A$ is normal, so is $T$: $T^\dagger T = V^\dagger A^\dagger V\,V^\dagger AV =
   V^\dagger A^\dagger A V$ and $TT^\dagger = V^\dagger AA^\dagger V$; since
   $A^\dagger A = AA^\dagger$, these are equal, so $T^\dagger T = TT^\dagger$.
2. **Lemma: a normal upper-triangular matrix is diagonal.** Compare the
   $(i,i)$ diagonal entry of $T^\dagger T$ and $TT^\dagger$. Since $T$ is
   upper triangular ($T_{k\ell}=0$ for $k>\ell$),
   $$(T^\dagger T)_{ii} = \sum_k |T_{ki}|^2 = \sum_{k\le i}|T_{ki}|^2
   \quad\text{(sum down column $i$, entries at or above the diagonal)},$$
   $$(TT^\dagger)_{ii} = \sum_k |T_{ik}|^2 = \sum_{k\ge i}|T_{ik}|^2
   \quad\text{(sum along row $i$, entries at or right of the diagonal)}.$$
   For $i=1$: $(T^\dagger T)_{11} = |T_{11}|^2$, while $(TT^\dagger)_{11} =
   \sum_{k\ge1}|T_{1k}|^2 = |T_{11}|^2 + \sum_{k>1}|T_{1k}|^2$. Normality
   forces these equal, so $\sum_{k>1}|T_{1k}|^2 = 0$, i.e. every off-diagonal
   entry in row $1$ is zero. Now induct: having shown rows $1,\dots,i-1$ are
   zero off the diagonal, the same comparison at index $i$ leaves only the
   entries in row $i$, columns $>i$, on the right-hand sum, forcing them to
   $0$ too. By induction, every off-diagonal entry of $T$ vanishes: $T$ is
   diagonal.
3. So $T = D$ is diagonal, and $A = VDV^\dagger$ with $D$'s diagonal entries
   being $A$'s eigenvalues (a triangular matrix's diagonal is always its
   eigenvalues, and similarity preserves the spectrum) and $V$'s columns an
   orthonormal eigenbasis (since $AV = VD$ says column $j$ of $V$ satisfies
   $Av_j = d_j v_j$, and $V$ is unitary, so its columns are orthonormal). $\blacksquare$

Today's exercises specialize this to the concrete $2\times2$ case (Days 3–4's
running examples), where the eigen-decomposition can be written out by hand
in full.

### Hermitian matrices are normal, with real eigenvalues

A matrix $A$ is **Hermitian** iff $A = A^\dagger$.

**Normality** is then immediate: $AA^\dagger = AA = A^\dagger A$, since both
sides are just $A^2$.

**Real eigenvalues.** Let $Av = \lambda v$ for some eigenvector $v\ne0$.
Multiply on the left by $v^\dagger$ (the row vector $\bar v^T$, matching
Day 3's inner product $\langle v,w\rangle = v^\dagger w$):
$$v^\dagger A v = \lambda\, v^\dagger v.$$
The left-hand side, $v^\dagger A v$, is a $1\times1$ matrix — a scalar — so
its own conjugate transpose equals its complex conjugate: $(v^\dagger
Av)^\dagger = (v^\dagger Av)^*$. But also, expanding the conjugate transpose
directly, $(v^\dagger A v)^\dagger = v^\dagger A^\dagger v = v^\dagger A v$
using $A^\dagger = A$. Combining these two expressions for the same
quantity: $(v^\dagger Av)^* = v^\dagger Av$, i.e. $v^\dagger Av$ is real.
Since $v^\dagger v = \|v\|^2$ is a strictly positive real number ($v\ne0$),
$$\lambda = \frac{v^\dagger Av}{v^\dagger v}$$
is a real number divided by a positive real number — hence real. $\blacksquare$

### Unitary matrices are normal, and the spectral theorem recovers modulus-1 eigenvalues

A matrix $U$ is **unitary** iff $U^\dagger U = UU^\dagger = I$. Normality is
immediate from the definition itself: $UU^\dagger = I = U^\dagger U$, so both
products are literally equal (both equal $I$), which is exactly the
normality condition.

Day 3 already proved directly that every eigenvalue of a unitary matrix has
modulus $1$ (take $Uv=\lambda v$, apply $U^\dagger U = I$, and compare norms:
$\|v\|^2 = \|U v\|^2 = |\lambda|^2\|v\|^2 \Rightarrow |\lambda|=1$). The
spectral theorem gives a second route to the *same* fact, worth making
explicit because it shows the two are really one fact stated two ways: since
$U$ is normal, $U = VDV^\dagger$ for unitary $V$ and diagonal $D$ (the
eigenvalues of $U$ down the diagonal). Then
$$I = U^\dagger U = (VDV^\dagger)^\dagger(VDV^\dagger) = VD^\dagger V^\dagger V D V^\dagger
= V(D^\dagger D)V^\dagger.$$
Multiplying on the left by $V^\dagger$ and on the right by $V$ (both unitary,
hence invertible) gives $D^\dagger D = I$. Since $D$ is diagonal with entries
$\lambda_1,\dots,\lambda_n$, $D^\dagger D$ is diagonal with entries
$|\lambda_i|^2$, so $D^\dagger D = I$ says exactly $|\lambda_i|^2 = 1$ for
every $i$ — the eigenvalues of a unitary matrix lie on the unit circle. This
is the *same conclusion* as Day 3's direct proof, now obtained by unitarily
diagonalizing $U$ itself and reading the constraint off the diagonal — the
spectral theorem's diagonal entries and "$U$'s eigenvalues" are not two
different things that happen to agree, they are definitionally the same
numbers.

### The Pauli matrices and the Hadamard matrix

Define
$$X = \begin{pmatrix}0&1\\1&0\end{pmatrix},\quad
Y = \begin{pmatrix}0&-i\\i&0\end{pmatrix},\quad
Z = \begin{pmatrix}1&0\\0&-1\end{pmatrix},\quad
H = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}.$$

A short general observation, worth proving once rather than three times: **if
a matrix $A$ is both Hermitian and unitary, its eigenvalues are exactly
$\pm1$, and $A^2 = I$.** Proof: Hermitian gives real eigenvalues (previous
subsection); unitary gives modulus-$1$ eigenvalues (Day 3 / previous
subsection). A real number of modulus $1$ is $\pm1$. For $A^2=I$: by the
spectral theorem $A = UDU^\dagger$ with $D=\mathrm{diag}(\pm1,\dots,\pm1)$,
so $D^2 = I$ (each diagonal entry squares to $1$), hence $A^2 = UDU^\dagger
UDU^\dagger = UD^2U^\dagger = UIU^\dagger = I$. A matrix that is its own
inverse is called an **involution**. So: to verify $X,Y,Z$ (and, separately,
$H$) are involutions with eigenvalues $\pm1$, it suffices to check
Hermitian-ness and unitarity directly from the matrix entries — the
eigenvalue and involution facts then follow automatically from the theorem
just proved, without needing to compute a characteristic polynomial first.
(You will still compute the actual eigenvectors by hand in the exercises —
the theorem above only pins down *which* eigenvalues are possible, $\{+1,-1\}$,
not which vector goes with which sign.)

### The Bloch sphere

Every normalized single-qubit state can be written, up to an unobservable
global phase, as
$$|\psi\rangle = \cos(\theta/2)|0\rangle + e^{i\varphi}\sin(\theta/2)|1\rangle,
\qquad \theta\in[0,\pi],\ \varphi\in[0,2\pi),$$
i.e. $\alpha = \cos(\theta/2)$, $\beta = e^{i\varphi}\sin(\theta/2)$ in the
usual $|\psi\rangle=\alpha|0\rangle+\beta|1\rangle$ notation. (This form
covers every normalized state up to global phase: given any $\alpha,\beta$
with $|\alpha|^2+|\beta|^2=1$, multiply by a global phase to make $\alpha$
real and non-negative, which forces $\alpha=\cos(\theta/2)$ for a unique
$\theta\in[0,\pi]$, and then $\beta$'s modulus is fixed to $\sin(\theta/2)$
with $\varphi$ its remaining phase.)

Define $(x,y,z) = \big(2\mathrm{Re}(\bar\alpha\beta),\ 2\mathrm{Im}(\bar\alpha\beta),\
|\alpha|^2-|\beta|^2\big)$ — exactly the formula the Day 4 code (below)
computes as `bloch_coords`. Substituting $\alpha=\cos(\theta/2)$,
$\beta=e^{i\varphi}\sin(\theta/2)$:
$$\bar\alpha\beta = \cos(\theta/2)\,e^{i\varphi}\sin(\theta/2)
= e^{i\varphi}\cdot\tfrac12\sin\theta = \tfrac12\sin\theta(\cos\varphi + i\sin\varphi),$$
using the double-angle identity $2\sin(\theta/2)\cos(\theta/2)=\sin\theta$. Hence
$$x = 2\mathrm{Re}(\bar\alpha\beta) = \sin\theta\cos\varphi,\qquad
y = 2\mathrm{Im}(\bar\alpha\beta) = \sin\theta\sin\varphi,$$
$$z = \cos^2(\theta/2)-\sin^2(\theta/2) = \cos\theta,$$
using $\cos^2(\theta/2)-\sin^2(\theta/2)=\cos\theta$. So $(x,y,z) =
(\sin\theta\cos\varphi,\ \sin\theta\sin\varphi,\ \cos\theta)$ — exactly the
standard spherical-to-Cartesian coordinates of a point on the *unit* sphere
in $\mathbb{R}^3$ (one checks $x^2+y^2+z^2=\sin^2\theta+\cos^2\theta=1$
directly). This is the **Bloch sphere**: every single-qubit pure state,
modulo global phase, corresponds to exactly one point on the surface of the
unit sphere, and every point on the sphere corresponds to exactly one such
state.

Two geometric facts worth having in mind before the exercises, both
immediate from the coordinate formula above and from the definitions of
$X,Y,Z$:
- $|0\rangle$ ($\theta=0$) and $|1\rangle$ ($\theta=\pi$) sit at the north
  and south poles, i.e. the $\pm z$ axis — and they are exactly $Z$'s
  eigenvectors. More generally, each Pauli matrix's two eigenvectors sit at
  the two antipodal points of *its own* Bloch axis: $X$'s eigenvectors on
  the $\pm x$ axis, $Y$'s on the $\pm y$ axis, $Z$'s on the $\pm z$ axis —
  you will verify this by direct computation in the exercises.
- A single-qubit unitary acts on the Bloch sphere as a *rigid rotation* of
  the sphere (it must preserve $x^2+y^2+z^2=1$ and, being linear, preserve
  the geometric structure of great circles). $X$, $Y$, $Z$, each being a
  $180°$ rotation about their own axis, is the special case of a rotation
  that is also an involution.

## Worked example

The spectral theorem applies to *any* normal matrix, not only Hermitian or
unitary ones — worth seeing once on a matrix that is normal but neither, so
the generality of the theorem doesn't get lost in the specific,
physically-motivated cases (Pauli matrices, Hadamard) that the exercises
focus on.

**Claim:** $A = \begin{pmatrix}1&1\\-1&1\end{pmatrix}$ is normal, and its
spectral decomposition can be found and verified explicitly.

**Normality.** $A^\dagger = \begin{pmatrix}1&-1\\1&1\end{pmatrix}$ (real
matrix, so $A^\dagger=A^T$). Direct multiplication:
$$AA^\dagger = \begin{pmatrix}1&1\\-1&1\end{pmatrix}\begin{pmatrix}1&-1\\1&1\end{pmatrix}
= \begin{pmatrix}1\cdot1+1\cdot1 & 1\cdot(-1)+1\cdot1\\ -1\cdot1+1\cdot1 & -1\cdot(-1)+1\cdot1\end{pmatrix}
= \begin{pmatrix}2&0\\0&2\end{pmatrix},$$
$$A^\dagger A = \begin{pmatrix}1&-1\\1&1\end{pmatrix}\begin{pmatrix}1&1\\-1&1\end{pmatrix}
= \begin{pmatrix}1\cdot1+(-1)(-1) & 1\cdot1+(-1)\cdot1\\ 1\cdot1+1\cdot(-1) & 1\cdot1+1\cdot1\end{pmatrix}
= \begin{pmatrix}2&0\\0&2\end{pmatrix}.$$
Both equal $2I$, so $A$ is normal. Note directly: $A\ne A^\dagger$ ($A$ is
not Hermitian), and $AA^\dagger = 2I \ne I$ ($A$ is not unitary) — a genuine
example of the strictly larger "normal" class.

**Eigenvalues.** $\mathrm{tr}(A)=2$, $\det(A) = 1\cdot1-1\cdot(-1)=2$. The
characteristic equation $\lambda^2 - 2\lambda + 2 = 0$ gives
$\lambda = \frac{2\pm\sqrt{4-8}}{2} = 1\pm i$ — genuinely complex, off both
the real line (as expected: not Hermitian) and the unit circle (as expected:
not unitary; indeed $|1\pm i| = \sqrt2$, consistent with $AA^\dagger=2I$
rather than $I$).

**Eigenvectors.** For $\lambda=1+i$: solve $(A-\lambda I)v=0$, i.e.
$\begin{pmatrix}-i&1\\-1&-i\end{pmatrix}v=0$. Row 1 gives $-iv_1+v_2=0
\Rightarrow v_2=iv_1$; take $v_1=1$: $v=(1,i)$, normalized
$v_+=\frac{1}{\sqrt2}(1,i)$. (Row 2 gives $-v_1-iv_2 = -1-i(i) = -1+1=0$,
consistent.)

For $\lambda=1-i$: $\begin{pmatrix}i&1\\-1&i\end{pmatrix}v=0$. Row 1 gives
$iv_1+v_2=0\Rightarrow v_2=-iv_1$; $v=(1,-i)$, normalized
$v_-=\frac{1}{\sqrt2}(1,-i)$.

**Orthonormality check** (the spectral theorem's promise): $\langle
v_+,v_-\rangle = \tfrac12(\overline{1}\cdot1 + \overline{i}\cdot(-i)) =
\tfrac12(1 + (-i)(-i)) = \tfrac12(1+i^2) = \tfrac12(1-1) = 0$ — orthogonal, as
guaranteed.

**Reconstruction.** Let $U = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\i&-i\end{pmatrix}$
(columns $v_+,v_-$), $D=\begin{pmatrix}1+i&0\\0&1-i\end{pmatrix}$,
$U^\dagger = \frac{1}{\sqrt2}\begin{pmatrix}1&-i\\1&i\end{pmatrix}$. First
$UD = \frac{1}{\sqrt2}\begin{pmatrix}1+i & 1-i\\ -1+i & -1-i\end{pmatrix}$
(multiply each column of $U$ by its eigenvalue). Then
$$(UD)U^\dagger = \tfrac12\begin{pmatrix}1+i&1-i\\-1+i&-1-i\end{pmatrix}
\begin{pmatrix}1&-i\\1&i\end{pmatrix}.$$
Entry $(1,1)$: $\tfrac12\big[(1+i)+(1-i)\big] = \tfrac12(2) = 1$.
Entry $(1,2)$: $\tfrac12\big[(1+i)(-i)+(1-i)(i)\big]
= \tfrac12\big[(1-i)+(1+i)\big] = \tfrac12(2) = 1$
(using $(1+i)(-i)=-i-i^2=1-i$ and $(1-i)(i)=i-i^2=1+i$).
Entry $(2,1)$: $\tfrac12\big[(-1+i)+(-1-i)\big] = \tfrac12(-2) = -1$.
Entry $(2,2)$: $\tfrac12\big[(-1+i)(-i)+(-1-i)(i)\big]
=\tfrac12\big[(1+i)+(1-i)\big] = 1$
(using $(-1+i)(-i)=i-i^2\cdot... $ — expand directly: $(-1+i)(-i)=i-i\cdot i\cdot(-1)$; more carefully $(-1+i)(-i) = (-1)(-i)+i(-i) = i - i^2 = i+1$, and $(-1-i)(i) = -i-i^2 = -i+1 = 1-i$, summing to $2$, giving entry $1$).

So $UDU^\dagger = \begin{pmatrix}1&1\\-1&1\end{pmatrix} = A$ exactly,
recovered by direct matrix multiplication — the spectral theorem's claim
verified concretely on a matrix that is normal without being Hermitian or
unitary.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Prove that every Hermitian matrix is normal, and that every Hermitian
   matrix's eigenvalues are real.
2. Prove that every unitary matrix is normal. Then, using the spectral
   theorem (not Day 3's direct norm argument), show that every eigenvalue of
   a unitary matrix has modulus $1$.
3. Verify directly from the matrix entries that $X$, $Y$, and $Z$ are each
   Hermitian and unitary (hence involutions with eigenvalues $\pm1$, by the
   theorem in the Theory section). Then find each one's eigenvalues *and*
   eigenvectors explicitly (six eigenvectors total, two per matrix).
4. Verify the spectral theorem directly for $H = \frac{1}{\sqrt2}
   \begin{pmatrix}1&1\\1&-1\end{pmatrix}$: find its eigenvalues and
   eigenvectors, then set $U$'s columns to your eigenvectors and $D$ to the
   corresponding eigenvalues, and confirm by direct matrix multiplication
   that $UDU^\dagger = H$.
5. Compute the Bloch coordinates $(x,y,z)$ of $|0\rangle$, $|1\rangle$, and
   $H|0\rangle$.
6. From the matrix form of $X$ alone (no code yet), predict in words what
   applying $X$ does to a general point $(x,y,z)$ on the Bloch sphere.
7. Prove your Exercise 6 prediction algebraically: for a general normalized
   $|\psi\rangle=\alpha|0\rangle+\beta|1\rangle$ with Bloch coordinates
   $(x,y,z)$, compute the Bloch coordinates of $X|\psi\rangle$ in terms of
   $(x,y,z)$ and show the relationship holds for *every* $\alpha,\beta$, not
   just the specific example the Code lab below will run.

## Solutions

**1.** Let $A=A^\dagger$. Normal: $AA^\dagger = AA = A^\dagger A$ (both sides
are $A^2$), so the normality condition holds trivially. Real eigenvalues:
for $Av=\lambda v$, $v\ne0$, left-multiply by $v^\dagger$ to get $v^\dagger
Av = \lambda v^\dagger v$. The scalar $v^\dagger Av$ satisfies $(v^\dagger
Av)^\dagger = v^\dagger A^\dagger v = v^\dagger Av$ (using $A^\dagger=A$),
and for a scalar, "conjugate transpose" is just complex conjugation, so
$v^\dagger Av$ is real. Since $v^\dagger v = \|v\|^2>0$ is real and positive,
$\lambda = (v^\dagger Av)/(v^\dagger v)$ is real (real over positive real).

**2.** Let $U^\dagger U = UU^\dagger = I$. Normal: both products equal $I$,
hence equal each other — the normality condition holds by definition of
unitary. Modulus-1 eigenvalues via the spectral theorem: since $U$ is
normal, $U=VDV^\dagger$ for unitary $V$, diagonal $D=\mathrm{diag}(\lambda_1,
\dots,\lambda_n)$. Then $I = U^\dagger U = VD^\dagger V^\dagger VDV^\dagger =
V(D^\dagger D)V^\dagger$; multiplying by $V^\dagger$ on the left and $V$ on
the right gives $D^\dagger D = I$, i.e. $|\lambda_i|^2=1$ for every $i$ —
every eigenvalue of $U$ has modulus $1$.

**3.** 

*$X=\begin{pmatrix}0&1\\1&0\end{pmatrix}$*: real and symmetric, so
$X^\dagger = X$ — Hermitian. $X^\dagger X = X^2 = \begin{pmatrix}0&1\\1&0
\end{pmatrix}\begin{pmatrix}0&1\\1&0\end{pmatrix} = \begin{pmatrix}1&0\\0&1
\end{pmatrix}=I$ — unitary, and $X^2=I$ confirms the involution directly.
Eigenvalues: $\mathrm{tr}(X)=0$, $\det(X)=-1$, so $\lambda^2-1=0 \Rightarrow
\lambda=\pm1$ (consistent with the general theorem). For $\lambda=1$:
$(X-I)v=0 \Rightarrow \begin{pmatrix}-1&1\\1&-1\end{pmatrix}v=0 \Rightarrow
v_1=v_2$, giving $|+\rangle=\frac{1}{\sqrt2}(1,1)$. For $\lambda=-1$:
$v_1=-v_2$, giving $|-\rangle=\frac{1}{\sqrt2}(1,-1)$.

*$Y=\begin{pmatrix}0&-i\\i&0\end{pmatrix}$*: $\bar Y = \begin{pmatrix}0&i\\-i&0
\end{pmatrix}$, so $Y^\dagger = (\bar Y)^T = \begin{pmatrix}0&-i\\i&0
\end{pmatrix} = Y$ — Hermitian. $Y^2 = \begin{pmatrix}0&-i\\i&0\end{pmatrix}
\begin{pmatrix}0&-i\\i&0\end{pmatrix}$; entry $(1,1) = 0\cdot0+(-i)(i) = -i^2=1$,
entry $(1,2)=0$, entry $(2,1)=0$, entry $(2,2)=i(-i)+0 = -i^2=1$, so $Y^2=I$ —
unitary and involution confirmed directly. Eigenvalues $\pm1$ again by
$\mathrm{tr}(Y)=0,\det(Y)=-(-i)(i)=-1$. For $\lambda=1$:
$\begin{pmatrix}-1&-i\\i&-1\end{pmatrix}v=0 \Rightarrow -v_1-iv_2=0
\Rightarrow v_1=-iv_2$; taking $v_2=1,v_1=-i$ and normalizing gives, up to
overall phase, $|i{+}\rangle=\frac{1}{\sqrt2}(1,i)$ — check directly:
$Y\cdot\frac{1}{\sqrt2}(1,i)^T = \frac{1}{\sqrt2}(-i\cdot i,\ i\cdot1)^T =
\frac{1}{\sqrt2}(1,i)^T$, confirming eigenvalue $+1$. For $\lambda=-1$, the
orthogonal vector $|i{-}\rangle=\frac{1}{\sqrt2}(1,-i)$: $Y\cdot
\frac{1}{\sqrt2}(1,-i)^T = \frac{1}{\sqrt2}(-i(-i),\ i\cdot1)^T =
\frac{1}{\sqrt2}(-1,i)^T = -\frac{1}{\sqrt2}(1,-i)^T$, confirming eigenvalue
$-1$.

*$Z=\begin{pmatrix}1&0\\0&-1\end{pmatrix}$*: real diagonal, so trivially
$Z^\dagger=Z$ (Hermitian) and $Z^2 = \begin{pmatrix}1&0\\0&1\end{pmatrix}=I$
(unitary, involution). Being diagonal, its eigenvectors are simply the
standard basis vectors: $Z|0\rangle = |0\rangle$ (eigenvalue $+1$),
$Z|1\rangle=-|1\rangle$ (eigenvalue $-1$).

**4.** $H$ is real and symmetric ($H^\dagger=H$, Hermitian) and $H^2 =
\tfrac12\begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}1&1\\1&-1
\end{pmatrix} = \tfrac12\begin{pmatrix}2&0\\0&2\end{pmatrix}=I$ (unitary,
involution), so eigenvalues are $\pm1$ ($\mathrm{tr}(H)=0$, $\det(H)=-1$
confirm $\lambda^2-1=0$). Write $\theta=\pi/8$. Claim: $|h_+\rangle =
(\cos\theta,\sin\theta)$ has eigenvalue $+1$ and $|h_-\rangle =
(-\sin\theta,\cos\theta)$ has eigenvalue $-1$. Check $H|h_+\rangle$: first
component $\tfrac{1}{\sqrt2}(\cos\theta+\sin\theta) = \cos(\theta-\pi/4)
= \cos(\pi/8-\pi/4)=\cos(\pi/8)$ (using $\cos\theta+\sin\theta=\sqrt2
\cos(\theta-\pi/4)$), matching $\cos\theta$. Second component
$\tfrac{1}{\sqrt2}(\cos\theta-\sin\theta) = \cos(\theta+\pi/4) =
\cos(3\pi/8) = \sin(\pi/8)$ (using $\cos\theta-\sin\theta=\sqrt2
\cos(\theta+\pi/4)$, and $\cos(3\pi/8)=\sin(\pi/8)$ since they're
complementary angles), matching $\sin\theta$. So $H|h_+\rangle=|h_+\rangle$
exactly, confirming eigenvalue $+1$. An identical calculation confirms
$H|h_-\rangle=-|h_-\rangle$. Orthogonality is immediate:
$\langle h_+,h_-\rangle = -\cos\theta\sin\theta+\sin\theta\cos\theta=0$.

Reconstruction: let $U=\begin{pmatrix}\cos\theta&-\sin\theta\\
\sin\theta&\cos\theta\end{pmatrix}$ (columns $h_+,h_-$; a real rotation
matrix, so $U^\dagger=U^T=\begin{pmatrix}\cos\theta&\sin\theta\\
-\sin\theta&\cos\theta\end{pmatrix}$), $D=\begin{pmatrix}1&0\\0&-1
\end{pmatrix}$. Then $UD = \begin{pmatrix}\cos\theta&\sin\theta\\
\sin\theta&-\cos\theta\end{pmatrix}$ (flip the sign of column 2). Multiplying
$(UD)U^\dagger$ entrywise:
$$(1,1):\ \cos^2\theta-\sin^2\theta = \cos2\theta,\qquad
(1,2):\ \cos\theta\sin\theta+\sin\theta\cos\theta = \sin2\theta,$$
$$(2,1):\ \sin\theta\cos\theta+\sin\theta\cos\theta = \sin2\theta,\qquad
(2,2):\ \sin^2\theta-\cos^2\theta = -\cos2\theta.$$
With $\theta=\pi/8$, $2\theta=\pi/4$, so $\cos2\theta=\sin2\theta=
\frac{1}{\sqrt2}$, giving $UDU^\dagger = \begin{pmatrix}1/\sqrt2&1/\sqrt2\\
1/\sqrt2&-1/\sqrt2\end{pmatrix} = H$ — reconstructed exactly by direct matrix
multiplication.

**5.** Using $x=2\mathrm{Re}(\bar\alpha\beta)$, $y=2\mathrm{Im}(\bar\alpha\beta)$,
$z=|\alpha|^2-|\beta|^2$:
- $|0\rangle$: $\alpha=1,\beta=0 \Rightarrow \bar\alpha\beta=0$, so $(x,y,z)=(0,0,1)$.
- $|1\rangle$: $\alpha=0,\beta=1 \Rightarrow \bar\alpha\beta=0$, so $(x,y,z)=(0,0,-1)$.
- $H|0\rangle = |+\rangle = \frac{1}{\sqrt2}(1,1)$: $\alpha=\beta=1/\sqrt2$,
  $\bar\alpha\beta = 1/2$ (real), so $x=2(1/2)=1$, $y=0$,
  $z=\tfrac12-\tfrac12=0$; $(x,y,z)=(1,0,0)$.

$|0\rangle,|1\rangle$ land at the north/south poles, as expected since they
are $Z$'s eigenvectors; $H|0\rangle$ lands on the $+x$ axis, as expected
since $|+\rangle=\frac{1}{\sqrt2}(1,1)$ is exactly $X$'s $\lambda=+1$
eigenvector from Exercise 3.

**6.** $X$ swaps the two basis amplitudes: $X(\alpha,\beta)=(\beta,\alpha)$.
Geometrically, since $X$'s own eigenvectors sit on the $\pm x$ axis (Exercise
3/5), and $X$ is a $180°$-rotation-type involution (Theory section), the
prediction is: $X$ acts as a $180°$ rotation of the Bloch sphere about the
$x$-axis — it should leave the $x$-coordinate fixed and flip the sign of
both the $y$- and $z$-coordinates.

**7.** Let $|\psi\rangle=\alpha|0\rangle+\beta|1\rangle$ with Bloch
coordinates $x=2\mathrm{Re}(\bar\alpha\beta)$, $y=2\mathrm{Im}(\bar\alpha\beta)$,
$z=|\alpha|^2-|\beta|^2$. Then $X|\psi\rangle = \beta|0\rangle+\alpha|1\rangle$,
i.e. $\alpha'=\beta,\ \beta'=\alpha$. Its coordinates:
$$x' = 2\mathrm{Re}(\bar\alpha'\beta') = 2\mathrm{Re}(\bar\beta\alpha).$$
Since $\bar\beta\alpha = \overline{\bar\alpha\beta}$ (conjugating a product
of a conjugate and a non-conjugate factor swaps which factor is conjugated),
and $\mathrm{Re}(\bar w) = \mathrm{Re}(w)$ for any complex $w$,
$$x' = 2\mathrm{Re}\big(\overline{\bar\alpha\beta}\big) = 2\mathrm{Re}(\bar\alpha\beta) = x.$$
Similarly $y' = 2\mathrm{Im}(\bar\beta\alpha) = 2\mathrm{Im}(\overline{\bar\alpha\beta})
= -2\mathrm{Im}(\bar\alpha\beta) = -y$, using $\mathrm{Im}(\bar w)=-\mathrm{Im}(w)$.
And $z' = |\beta|^2-|\alpha|^2 = -(|\alpha|^2-|\beta|^2) = -z$. So for *every*
normalized $\alpha,\beta$: $X$ maps $(x,y,z)\mapsto(x,-y,-z)$ — proving the
Exercise 6 prediction algebraically, not just for one numerical example.

## Code lab

Today is one of the plan's three flagged code days (Days 4, 11, 14). The
code is already written for you — it is a *verification* of the hand
derivations above, not a new implementation exercise. See
`quantum_computing_foundations/code/day04_bloch_sphere.py`, and Step 5 of the
Day 4 section in
`quantum_computing_foundations/docs/superpowers/plans/2026-07-13-quantum-computing-15-day-plan.md`
for the exact listing.

The script implements `bloch_coords(psi)` exactly as derived in the Theory
section's Bloch-sphere subsection ($x=2\mathrm{Re}(\bar\alpha\beta)$,
$y=2\mathrm{Im}(\bar\alpha\beta)$, $z=|\alpha|^2-|\beta|^2$), then prints the
Bloch coordinates of $|0\rangle$, $|1\rangle$, $H|0\rangle$, a general state
$|\psi\rangle=(0.6,\,0.8i)$, and $X|\psi\rangle$.

Run it:
```bash
cd quantum_computing_foundations
python3 code/day04_bloch_sphere.py
```

Expected output, per the plan: `|0>` at `(0,0,1)`, `|1>` at `(0,0,-1)`,
`H|0>` at `(1,0,0)` — matching your Exercise 5 by-hand computation exactly.
For the last two printed lines ($\psi$ and $X|\psi\rangle$), confirm that
$X$ leaves the printed $x$-coordinate unchanged and flips the sign of both
the $y$- and $z$-coordinates — the numerical instance of the general
Exercise 7 proof, and the direct check of your Exercise 6 prediction. Write
this confirmation, and whether it matched your Step 4.6/Exercise 6
prediction, in `notes/day04_normal_matrices_bloch.md`.

## Journal template

```
## Day 4 — Normal matrices, spectral theorem, Bloch sphere
Key idea in my own words: ...
What confused me: ...
```
