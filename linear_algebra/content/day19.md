# Day 19 — Symmetric Matrices & the Spectral Theorem

## Learning objectives

By the end of today you should be able to:
- Prove that every eigenvalue of a real symmetric matrix is real.
- Prove that eigenvectors of a real symmetric matrix corresponding to
  distinct eigenvalues are orthogonal.
- State and prove the Spectral Theorem: every real symmetric $n\times n$
  matrix $A$ factors as $A = Q\Lambda Q^T$ with $Q$ orthogonal and $\Lambda$
  real diagonal.
- Compute a full spectral decomposition by hand for $2\times2$ and $3\times3$
  symmetric matrices, including the repeated-eigenvalue case.
- Explain precisely what is new here relative to Day 11's diagonalization
  (an *orthogonal* $Q$, not just any invertible $P$) and why that matters
  computationally.

## Reference material

- Primer (10 min, no video today): sketch by hand. Take
  $A = \begin{pmatrix}2&1\\1&2\end{pmatrix}$ (today's worked example), plot
  its two eigenvectors as arrows from the origin, and check with a
  protractor (or just eyeballing perpendicularity) that they meet at
  $90°$. Repeat with any other symmetric $2\times2$ matrix of your choosing.
  This is the geometric fact — eigenvectors of a symmetric matrix are always
  perpendicular — that today's proofs make precise and general.
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §5.7
  (symmetric matrices and the spectral theorem) — [free
  PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson), the
  problems on symmetric matrices and the spectral theorem — if you don't
  have a copy, the exercises below are self-contained and sufficient for
  today.

Today combines Day 11 (diagonalization, algebraic/geometric multiplicity)
with Day 17 (orthogonal matrices, $Q^TQ=I$). If either feels shaky, a
5-minute skim of those journal entries before starting is worth it — the
whole point of today is that these two ideas fuse into one theorem for the
special case of symmetric matrices.

## Theory

Throughout, $A$ is a fixed real $n \times n$ matrix, and $\langle x,y\rangle
= x^Ty$ is the standard inner product on $\mathbb{R}^n$ (Day 14 notation).

### Definition 19.1 (Symmetric matrix)

$A$ is **symmetric** if $A = A^T$, i.e. $A_{ij} = A_{ji}$ for all $i,j$.

### Theorem 19.1 (Eigenvalues of a real symmetric matrix are real)

If $A$ is a real symmetric matrix, every eigenvalue of $A$ is real.

**Proof.** A priori an eigenvalue $\lambda$ of $A$ could be complex, with a
corresponding (possibly complex) eigenvector $v \in \mathbb{C}^n$, $v \neq
0$, satisfying $Av = \lambda v$. Write $\bar v$ for the entrywise complex
conjugate of $v$ and $\bar\lambda$ for the conjugate of $\lambda$. Take the
conjugate transpose (denoted $*$: transpose, then conjugate every entry) of
both sides of $Av = \lambda v$:
$$(Av)^* = (\lambda v)^* \implies v^*A^* = \bar\lambda v^*.$$
Since $A$ has real entries, $A^* = \overline{A^T} = \overline{A} = A$ (real
entries are their own conjugates), and since $A$ is symmetric, $A^T = A$ as
well — either way $A^* = A$. So the equation becomes
$$v^*A = \bar\lambda v^*. \tag{1}$$
Multiply both sides of (1) on the right by $v$:
$$v^*Av = \bar\lambda v^*v. \tag{2}$$
On the other hand, multiply both sides of $Av = \lambda v$ on the left by
$v^*$:
$$v^*Av = \lambda v^*v. \tag{3}$$
The left sides of (2) and (3) are identical, so their right sides are equal:
$$\bar\lambda v^*v = \lambda v^*v.$$
Now, $v^*v = \bar v^Tv = \sum_{i=1}^n \bar v_i v_i = \sum_{i=1}^n |v_i|^2 =
\|v\|^2$, a strictly positive real number since $v \neq 0$. So we may divide
both sides by $v^*v \neq 0$, giving
$$\bar\lambda = \lambda.$$
A complex number equal to its own conjugate is real (writing $\lambda = a +
bi$, $\bar\lambda = a - bi$, so $\bar\lambda = \lambda \implies b = 0$).
Hence $\lambda \in \mathbb{R}$. $\blacksquare$

### Theorem 19.2 (Eigenvectors for distinct eigenvalues are orthogonal)

Let $A$ be a real symmetric matrix, and let $Av_1 = \lambda_1 v_1$,
$Av_2 = \lambda_2 v_2$ with $v_1, v_2 \neq 0$ and $\lambda_1 \neq \lambda_2$.
Then $\langle v_1, v_2 \rangle = 0$.

**Proof.** By Theorem 19.1, $\lambda_1, \lambda_2 \in \mathbb{R}$, and since
$A$ is real symmetric, $v_1, v_2$ may be taken real too (a real eigenvalue
of a real matrix always has a real eigenvector — solve $(A-\lambda I)v=0$
by real row reduction). Compute $\langle Av_1, v_2\rangle$ two ways.

First, directly using $Av_1 = \lambda_1 v_1$:
$$\langle Av_1, v_2 \rangle = \langle \lambda_1 v_1, v_2\rangle = \lambda_1
\langle v_1, v_2\rangle.$$

Second, moving $A$ across the inner product using symmetry: for any $x,y \in
\mathbb{R}^n$, $\langle Ax, y\rangle = (Ax)^Ty = x^TA^Ty = x^T(A^Ty) =
\langle x, A^Ty\rangle$, and since $A^T = A$, this is $\langle x, Ay
\rangle$. Applying this with $x = v_1$, $y = v_2$:
$$\langle Av_1, v_2\rangle = \langle v_1, Av_2\rangle = \langle v_1,
\lambda_2 v_2\rangle = \lambda_2 \langle v_1, v_2\rangle.$$

Both expressions equal $\langle Av_1, v_2\rangle$, so
$$\lambda_1 \langle v_1, v_2\rangle = \lambda_2 \langle v_1, v_2\rangle
\implies (\lambda_1 - \lambda_2)\langle v_1, v_2\rangle = 0.$$
Since $\lambda_1 \neq \lambda_2$ by hypothesis, $\lambda_1 - \lambda_2 \neq
0$, forcing $\langle v_1, v_2\rangle = 0$. $\blacksquare$

### Theorem 19.3 (The Spectral Theorem)

Every real symmetric $n\times n$ matrix $A$ can be written
$$A = Q\Lambda Q^T$$
for some orthogonal $Q \in \mathbb{R}^{n\times n}$ (Day 17: $Q^TQ = I$) and
some real diagonal $\Lambda$.

**Proof.** By strong induction on $n$.

*Base case $n=1$.* $A = (a)$ is already diagonal. Take $Q = (1)$ (trivially
orthogonal, since $Q^TQ = (1) = I_1$) and $\Lambda = (a)$. Then $Q\Lambda
Q^T = (a) = A$.

*Inductive step.* Fix $n > 1$ and assume the theorem holds for every real
symmetric $(n-1)\times(n-1)$ matrix. Let $A$ be real symmetric $n\times n$.

*Step 1: get one real unit eigenvector.* The characteristic polynomial
$p_A(\lambda) = \det(A - \lambda I)$ has real coefficients and degree $n$,
so by the Fundamental Theorem of Algebra it has $n$ roots counted with
multiplicity in $\mathbb{C}$. By Theorem 19.1, every root of $p_A$ — i.e.
every eigenvalue of $A$, since $A$ is symmetric — is in fact real. So $A$
has at least one real eigenvalue $\lambda_1$, with a real eigenvector (as
noted in Theorem 19.2's proof); normalize it to $v_1$ with $\|v_1\| = 1$, so
$Av_1 = \lambda_1 v_1$.

*Step 2: extend to an orthonormal basis.* By the basis extension theorem
(Day 2) together with Gram-Schmidt (Day 15), extend $\{v_1\}$ to an
orthonormal basis $\{v_1, v_2, \dots, v_n\}$ of $\mathbb{R}^n$. Let
$V = [\,v_1 \mid v_2 \mid \cdots \mid v_n\,]$; since its columns are
orthonormal, $V$ is an orthogonal matrix ($V^TV = I$, hence also $V^{-1} =
V^T$).

*Step 3: change coordinates and peel off the first row/column.* Let
$B = V^TAV$. Since $V^{-1} = V^T$, $B$ is similar to $A$ (Day 11 notation),
and $B$ is symmetric: $B^T = (V^TAV)^T = V^TA^TV = V^TAV = B$, using $A^T=A$.
Compute the first column of $B$: writing $e_1$ for the first standard basis
vector,
$$Be_1 = V^TAVe_1 = V^TAv_1 = V^T(\lambda_1v_1) = \lambda_1(V^Tv_1) =
\lambda_1 e_1,$$
where $V^Tv_1 = e_1$ because $V^Tv_1$ is the vector of inner products of
$v_1$ with each column of $V$ (i.e. $(V^Tv_1)_i = \langle v_i, v_1\rangle$),
which is $1$ for $i=1$ and $0$ otherwise by orthonormality. So the first
column of $B$ is $(\lambda_1, 0, \dots, 0)^T$. Since $B$ is symmetric, its
first *row* is the transpose of its first *column*, i.e. also
$(\lambda_1, 0, \dots, 0)$. Hence $B$ has the block form
$$B = \begin{pmatrix} \lambda_1 & 0 \\ 0 & C \end{pmatrix}$$
for some $(n-1)\times(n-1)$ block $C$, and $C$ is symmetric ($C^T = C$
follows directly from $B^T = B$ restricted to that block).

*Step 4: apply the inductive hypothesis to $C$.* By the inductive
hypothesis, $C = Q'\Lambda'Q'^T$ for some orthogonal $(n-1)\times(n-1)$
matrix $Q'$ and real diagonal $(n-1)\times(n-1)$ matrix $\Lambda'$. Define
the $n\times n$ block-diagonal matrix
$$Q'' = \begin{pmatrix} 1 & 0 \\ 0 & Q' \end{pmatrix}.$$
$Q''$ is orthogonal: $Q''^TQ'' = \begin{pmatrix}1&0\\0&Q'^TQ'\end{pmatrix} =
\begin{pmatrix}1&0\\0&I_{n-1}\end{pmatrix} = I_n$, using $Q'^TQ'=I_{n-1}$.
And
$$Q''\Lambda Q''^T = \begin{pmatrix}1&0\\0&Q'\end{pmatrix}
\begin{pmatrix}\lambda_1&0\\0&\Lambda'\end{pmatrix}
\begin{pmatrix}1&0\\0&Q'^T\end{pmatrix} =
\begin{pmatrix}\lambda_1&0\\0&Q'\Lambda'Q'^T\end{pmatrix} =
\begin{pmatrix}\lambda_1&0\\0&C\end{pmatrix} = B,$$
where $\Lambda = \begin{pmatrix}\lambda_1&0\\0&\Lambda'\end{pmatrix}$ is
diagonal (its diagonal entries are $\lambda_1$ followed by the diagonal
entries of $\Lambda'$).

*Step 5: unwind back to $A$.* From $B = V^TAV$ we get $A = VBV^T$ (multiply
on the left by $V$ and right by $V^T$, using $V^{-1}=V^T$). Substituting
$B = Q''\Lambda Q''^T$:
$$A = V\left(Q''\Lambda Q''^T\right)V^T = (VQ'')\,\Lambda\,(VQ'')^T,$$
using $(VQ'')^T = Q''^TV^T$ regrouped as $((VQ'')\Lambda)(Q''^TV^T)$ —
associativity lets us write this as $(VQ'')\Lambda(VQ'')^T$. Let $Q = VQ''$.
Since $V$ and $Q''$ are both orthogonal, so is their product (Day 17,
Exercise 4(a): $(VQ'')^T(VQ'') = Q''^TV^TVQ'' = Q''^TIQ'' = Q''^TQ'' = I$).
So $A = Q\Lambda Q^T$ with $Q$ orthogonal and $\Lambda$ real diagonal,
completing the inductive step.

By induction, the theorem holds for all $n \ge 1$. $\blacksquare$

### Remark (What the induction bought us for repeated eigenvalues)

Theorem 19.2 alone only orthogonalizes eigenvectors belonging to *different*
eigenvalues; it says nothing about two independent eigenvectors sharing the
*same* eigenvalue (e.g. a $2$-dimensional eigenspace). One might worry those
could fail to be orthogonalizable, or worse, that there might not even be
enough of them (recall from Day 11 that geometric multiplicity can fall
*short* of algebraic multiplicity for a general matrix, blocking
diagonalization entirely). The induction above sidesteps both worries
without ever needing to compare multiplicities directly: at each step it
only ever asks for *one* eigenvector (Step 1) and hands the rest of the
matrix to a strictly smaller symmetric problem, recursively. Because the
argument never assumes distinct eigenvalues, it automatically handles
repeated eigenvalues correctly — the diagonal of $\Lambda$ simply lists an
eigenvalue as many times as it recurs through the recursion, and the
corresponding columns of $Q$, built independently at different recursion
depths, still end up mutually orthonormal by construction (each is an
eigenvector living inside a subspace orthogonal to all previously chosen
columns). This is *the* precise sense in which "geometric multiplicity
always equals algebraic multiplicity for a symmetric matrix," a fact stated
without proof in some treatments — here it falls out as a side effect of
the induction rather than needing to be established separately.

## Worked example

**Find the spectral decomposition $A = Q\Lambda Q^T$ of**
$$A = \begin{pmatrix} 2 & 1 \\ 1 & 2 \end{pmatrix}.$$

**Eigenvalues.** $p_A(\lambda) = (2-\lambda)^2 - 1 = 0 \implies 2 - \lambda =
\pm1 \implies \lambda = 3 \text{ or } \lambda = 1$. Both real, as guaranteed
by Theorem 19.1 (and $A$ is symmetric, so no surprise there).

**Eigenvector for $\lambda=3$.** $A - 3I = \begin{pmatrix}-1&1\\1&-1\end{pmatrix}$:
row 1 gives $-x+y=0 \implies y=x$. Raw eigenvector $(1,1)$, normalized
$$q_1 = \left(\tfrac1{\sqrt2}, \tfrac1{\sqrt2}\right), \qquad \|q_1\|=1.$$

**Eigenvector for $\lambda=1$.** $A - I = \begin{pmatrix}1&1\\1&1\end{pmatrix}$:
row 1 gives $x+y=0 \implies y=-x$. Raw eigenvector $(1,-1)$, normalized
$$q_2 = \left(\tfrac1{\sqrt2}, -\tfrac1{\sqrt2}\right), \qquad \|q_2\|=1.$$

**Check orthogonality (should be automatic by Theorem 19.2, since
$\lambda_1=3 \neq 1=\lambda_2$):** $\langle q_1, q_2\rangle =
\tfrac1{\sqrt2}\cdot\tfrac1{\sqrt2} + \tfrac1{\sqrt2}\cdot\left(-\tfrac1{\sqrt2}\right)
= \tfrac12 - \tfrac12 = 0$. $\checkmark$ No Gram-Schmidt step was needed here
because the eigenvalues are distinct — Theorem 19.2 already guarantees
orthogonality for free.

**Assemble.**
$$Q = \begin{pmatrix} \tfrac1{\sqrt2} & \tfrac1{\sqrt2} \\[2pt]
\tfrac1{\sqrt2} & -\tfrac1{\sqrt2} \end{pmatrix}, \qquad
\Lambda = \begin{pmatrix}3&0\\0&1\end{pmatrix}.$$

**Verify $Q^TQ=I$:** columns are unit vectors (each has squared norm
$\tfrac12+\tfrac12=1$) and their inner product is $0$ (just checked), so
$Q^TQ=I$: $Q$ is orthogonal.

**Verify $Q\Lambda Q^T = A$.** Using $Q\Lambda Q^T = \sum_i \lambda_i q_iq_i^T$:
$$q_1q_1^T = \begin{pmatrix}1/2&1/2\\1/2&1/2\end{pmatrix}, \qquad
q_2q_2^T = \begin{pmatrix}1/2&-1/2\\-1/2&1/2\end{pmatrix}.$$
$$Q\Lambda Q^T = 3\begin{pmatrix}1/2&1/2\\1/2&1/2\end{pmatrix} +
1\begin{pmatrix}1/2&-1/2\\-1/2&1/2\end{pmatrix} =
\begin{pmatrix}3/2+1/2 & 3/2-1/2\\3/2-1/2&3/2+1/2\end{pmatrix} =
\begin{pmatrix}2&1\\1&2\end{pmatrix} = A. \checkmark$$
(Confirmed numerically with `numpy.linalg.eigh` before this file was
finalized.)

## Unconventional edge

The trap: seeing $A = Q\Lambda Q^T$ and filing it away as "diagonalization,
just with different letters" — after all, Day 11's $A = PDP^{-1}$ already
diagonalizes any matrix with enough independent eigenvectors, and this
looks like the exact same shape. That reaction misses the entire point of
today. The genuinely new content is not *that* $A$ diagonalizes — it's that
for a symmetric $A$, the change-of-basis matrix can always be chosen
**orthogonal**, so $Q^{-1} = Q^T$ comes for free with zero computation,
versus computing a general $P^{-1}$ by Gaussian elimination or cofactors.
That single upgrade — inversion becomes transposition — is not a minor
convenience: it's the exact fact that makes covariance-matrix
eigendecomposition numerically cheap and stable enough to run inside PCA
(Day 23) and countless other ML algorithms on matrices with thousands of
rows, where computing a general inverse would be both slower and far more
sensitive to rounding error (recall Day 17's point about $\kappa(A^TA) =
\kappa(A)^2$ — the same numerical-stability theme resurfaces here in a
different guise). If you catch yourself thinking "spectral theorem = just
diagonalization," stop and ask specifically what changed about $Q$ — that's
the whole lesson.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–3 ask for a full spectral decomposition; 4, 8, 9, 10 are
proof/conceptual; 5 is a trap question; 6–7 use the spectral decomposition
to compute matrix powers/inverses without ever inverting a general matrix.

1. Find the spectral decomposition $A_1 = Q\Lambda Q^T$ of
   $A_1 = \begin{pmatrix}1&2\\2&1\end{pmatrix}$. Verify $Q^TQ=I$ and
   $Q\Lambda Q^T = A_1$.
2. Find the spectral decomposition of
   $A_2 = \begin{pmatrix}4&2\\2&1\end{pmatrix}$ (one of its eigenvalues is
   $0$ — keep this matrix in mind for Exercise 4). Verify $Q^TQ=I$ and
   $Q\Lambda Q^T=A_2$.
3. Find the spectral decomposition of
   $A_3 = \begin{pmatrix}2&1&1\\1&2&1\\1&1&2\end{pmatrix}$. (Its eigenvalues
   are $4$, with a $1$-dimensional eigenspace, and $1$, with a
   $2$-dimensional eigenspace — you will need to produce an *orthonormal*
   basis of that $2$-dimensional eigenspace yourself, e.g. via
   Gram-Schmidt.) Verify $Q^TQ=I$ and $Q\Lambda Q^T = A_3$.
4. Prove: for a real symmetric matrix $A$, $\operatorname{rank}(A)$ equals
   the number of nonzero eigenvalues of $A$, counted with (algebraic)
   multiplicity. (Hint: use the Spectral Theorem and the fact that
   multiplying by an invertible matrix — in particular an orthogonal one —
   does not change rank.) Then use this to state $\operatorname{rank}(A_2)$
   from Exercise 2 without any further computation.
5. **Trap.** True or False: every diagonalizable matrix is *orthogonally*
   diagonalizable (i.e. $A = PDP^{-1}$ with $P$ orthogonal). If false, give
   a concrete $2\times2$ counterexample: a diagonalizable, non-symmetric
   matrix, and show explicitly that its eigenvectors are not orthogonal.
6. Let $A_1$ be the matrix from Exercise 1. Using its spectral
   decomposition, compute $A_1^{10}$ without computing $10$ successive
   matrix multiplications (i.e. use $A_1^{10} = Q\Lambda^{10}Q^T$).
7. Using the same $A_1$ and its spectral decomposition, compute $A_1^{-1}$
   as $Q\Lambda^{-1}Q^T$ (no cofactor expansion or row reduction). Check
   your answer by verifying $A_1A_1^{-1} = I$ directly.
8. Prove, using the Spectral Theorem and Day 11's cyclic-trace argument,
   that $\operatorname{trace}(A) = \lambda_1 + \lambda_2 + \cdots +
   \lambda_n$ (the sum of the eigenvalues, with multiplicity) for any real
   symmetric $A$.
9. Conceptual (no computation): explain, citing the Remark after Theorem
   19.3, why a symmetric matrix can never exhibit the kind of "defective"
   behavior seen in Day 11's Jordan-block examples (geometric multiplicity
   strictly less than algebraic multiplicity). Contrast this explicitly
   with $A_5 = \begin{pmatrix}4&1&0\\0&4&1\\0&0&4\end{pmatrix}$ from Day 11,
   Exercise 5 — why doesn't the argument here apply to $A_5$?
10. **Bonus.** Suppose $A$ is both symmetric *and* orthogonal (i.e. $A^T=A$
    and $A^TA=I$ simultaneously). Prove that every eigenvalue of $A$ is
    either $1$ or $-1$.

## Solutions

**1.** $p_{A_1}(\lambda) = (1-\lambda)^2-4=0 \implies 1-\lambda=\pm2
\implies \lambda=-1 \text{ or } 3$.
For $\lambda=3$: $A_1-3I=\begin{pmatrix}-2&2\\2&-2\end{pmatrix}$, row 1:
$-2x+2y=0\implies y=x$; eigenvector $(1,1)$, normalized $q_1 =
\left(\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right)$.
For $\lambda=-1$: $A_1+I=\begin{pmatrix}2&2\\2&2\end{pmatrix}$, row 1:
$2x+2y=0\implies y=-x$; eigenvector $(1,-1)$, normalized $q_2 =
\left(\tfrac1{\sqrt2},-\tfrac1{\sqrt2}\right)$.
$$Q=\begin{pmatrix}\tfrac1{\sqrt2}&\tfrac1{\sqrt2}\\\tfrac1{\sqrt2}&-\tfrac1{\sqrt2}\end{pmatrix},
\qquad \Lambda=\begin{pmatrix}3&0\\0&-1\end{pmatrix}.$$
$Q^TQ$: columns are unit vectors ($\tfrac12+\tfrac12=1$ each) with inner
product $\tfrac12-\tfrac12=0$, so $Q^TQ=I$. $\checkmark$
$Q\Lambda Q^T = 3q_1q_1^T + (-1)q_2q_2^T = 3\begin{pmatrix}1/2&1/2\\1/2&1/2\end{pmatrix}
- \begin{pmatrix}1/2&-1/2\\-1/2&1/2\end{pmatrix} =
\begin{pmatrix}3/2-1/2&3/2+1/2\\3/2+1/2&3/2-1/2\end{pmatrix} =
\begin{pmatrix}1&2\\2&1\end{pmatrix}=A_1$. $\checkmark$

**2.** $p_{A_2}(\lambda)=(4-\lambda)(1-\lambda)-4=\lambda^2-5\lambda =
\lambda(\lambda-5)$; eigenvalues $0, 5$.
For $\lambda=5$: $A_2-5I=\begin{pmatrix}-1&2\\2&-4\end{pmatrix}$, row 1:
$-x+2y=0\implies x=2y$; eigenvector $(2,1)$, $\|(2,1)\|=\sqrt5$, normalized
$q_1 = \left(\tfrac2{\sqrt5},\tfrac1{\sqrt5}\right)$.
For $\lambda=0$: $A_2v=0$, row 1: $4x+2y=0\implies y=-2x$; eigenvector
$(1,-2)$, $\|(1,-2)\|=\sqrt5$, normalized $q_2 =
\left(\tfrac1{\sqrt5},-\tfrac2{\sqrt5}\right)$.
Check orthogonality: $\langle(2,1),(1,-2)\rangle = 2-2=0$. $\checkmark$
(guaranteed anyway by Theorem 19.2, since $5 \neq 0$).
$$Q=\begin{pmatrix}\tfrac2{\sqrt5}&\tfrac1{\sqrt5}\\\tfrac1{\sqrt5}&-\tfrac2{\sqrt5}\end{pmatrix},
\qquad \Lambda=\begin{pmatrix}5&0\\0&0\end{pmatrix}.$$
$Q^TQ$: each column has squared norm $\tfrac45+\tfrac15=1$; inner product
$\tfrac2{\sqrt5}\cdot\tfrac1{\sqrt5}+\tfrac1{\sqrt5}\cdot\left(-\tfrac2{\sqrt5}\right)
=\tfrac25-\tfrac25=0$, so $Q^TQ=I$. $\checkmark$
$Q\Lambda Q^T = 5q_1q_1^T + 0\cdot q_2q_2^T = 5\begin{pmatrix}4/5&2/5\\2/5&1/5\end{pmatrix}
= \begin{pmatrix}4&2\\2&1\end{pmatrix}=A_2$. $\checkmark$

**3.** Write $A_3 = I + J$ where $J$ is the all-ones $3\times3$ matrix. $J$
has rank $1$, eigenvalue $3$ for the eigenvector $(1,1,1)$ (since $J(1,1,1)
=(3,3,3)$), and eigenvalue $0$ for the plane $x+y+z=0$ orthogonal to
$(1,1,1)$ (any vector in that plane is annihilated by $J$, since each row
of $J$ is $(1,1,1)$ and $\langle(1,1,1),v\rangle=0$ for $v$ in that plane).
So $A_3=I+J$ has eigenvalue $1+3=4$ for $(1,1,1)$, and eigenvalue $1+0=1$
(now with algebraic multiplicity $2$, since $0$ had multiplicity $2$ for
$J$) for the plane $x+y+z=0$.
Normalized eigenvector for $\lambda=4$: $q_1=\left(\tfrac1{\sqrt3},
\tfrac1{\sqrt3},\tfrac1{\sqrt3}\right)$.
For $\lambda=1$, the eigenspace is the plane $\{(x,y,z):x+y+z=0\}$, a
$2$-dimensional space (algebraic multiplicity $2$ — matching, as guaranteed
by the Spectral Theorem for symmetric matrices). Pick two vectors spanning
it, e.g. $(1,-1,0)$ and $(1,1,-2)$ (both satisfy $x+y+z=0$), and check they
are already orthogonal: $\langle(1,-1,0),(1,1,-2)\rangle = 1-1+0=0$
$\checkmark$ (if they weren't, Gram-Schmidt would be needed here — this is
exactly the step that's automatic for distinct eigenvalues but requires
manual orthogonalization *within* a repeated eigenspace). Normalize:
$$q_2 = \left(\tfrac1{\sqrt2},-\tfrac1{\sqrt2},0\right), \qquad
q_3 = \left(\tfrac1{\sqrt6},\tfrac1{\sqrt6},-\tfrac2{\sqrt6}\right).$$
$$Q = \begin{pmatrix}\tfrac1{\sqrt3}&\tfrac1{\sqrt2}&\tfrac1{\sqrt6}\\[2pt]
\tfrac1{\sqrt3}&-\tfrac1{\sqrt2}&\tfrac1{\sqrt6}\\[2pt]
\tfrac1{\sqrt3}&0&-\tfrac2{\sqrt6}\end{pmatrix}, \qquad
\Lambda = \begin{pmatrix}4&0&0\\0&1&0\\0&0&1\end{pmatrix}.$$
$Q^TQ=I$ by construction (all three columns are unit vectors, pairwise
orthogonal: $q_1\perp q_2$ and $q_1\perp q_3$ by Theorem 19.2 since they
belong to different eigenvalues, and $q_2\perp q_3$ was checked by hand
above). $Q\Lambda Q^T = A_3$ was confirmed numerically with
`numpy.linalg.eigh` before this file was finalized (by-hand verification of
a $3\times3$ triple matrix product is left as an optional check — the
structural argument via $I+J$ above is the more illuminating verification).

**4.** By the Spectral Theorem, $A = Q\Lambda Q^T$ with $Q$ orthogonal
(hence invertible, $Q^{-1}=Q^T$ by Day 17) and $\Lambda$ diagonal.
Multiplying a matrix on the left or right by an invertible matrix does not
change its rank: if $M$ is invertible, $\operatorname{rank}(MB) =
\operatorname{rank}(B)$ (left-multiplying by $M$ is a bijection on
$\mathbb{R}^n$, so it maps the column space of $B$ bijectively onto the
column space of $MB$, preserving dimension) and likewise
$\operatorname{rank}(BM)=\operatorname{rank}(B)$ (apply the previous fact to
transposes: $\operatorname{rank}(BM)=\operatorname{rank}((BM)^T) =
\operatorname{rank}(M^TB^T) = \operatorname{rank}(B^T) =
\operatorname{rank}(B)$, using $M^T$ invertible whenever $M$ is). Applying
this twice,
$$\operatorname{rank}(A) = \operatorname{rank}(Q\Lambda Q^T) =
\operatorname{rank}(\Lambda Q^T) = \operatorname{rank}(\Lambda).$$
For a diagonal matrix $\Lambda = \operatorname{diag}(\lambda_1,\dots,
\lambda_n)$, the columns are $\lambda_ie_i$; a column is zero exactly when
$\lambda_i=0$, and the nonzero columns (one per nonzero $\lambda_i$) are
automatically linearly independent (distinct standard basis directions), so
$\operatorname{rank}(\Lambda)$ = the number of nonzero $\lambda_i$, i.e. the
number of nonzero eigenvalues of $A$ counted with multiplicity. Combining,
$\operatorname{rank}(A)$ equals the number of nonzero eigenvalues of $A$
(with multiplicity). $\blacksquare$
Applying this to $A_2$ from Exercise 2, whose eigenvalues are $5, 0$: exactly
one nonzero eigenvalue, so $\operatorname{rank}(A_2)=1$ — consistent with
$A_2=\begin{pmatrix}4&2\\2&1\end{pmatrix}$ having row 2 equal to $\tfrac12$
times row 1.

**5.** **False.** Take $B=\begin{pmatrix}4&1\\2&3\end{pmatrix}$ from Day 11's
worked example: $p_B(\lambda)=(\lambda-5)(\lambda-2)$, eigenvector $(1,1)$
for $\lambda=5$ and $(1,-2)$ for $\lambda=2$, so $B$ is diagonalizable
($B=PDP^{-1}$ with $P=\begin{pmatrix}1&1\\1&-2\end{pmatrix}$,
$D=\operatorname{diag}(5,2)$, verified in Day 11). But $\langle(1,1),(1,-2)
\rangle = 1-2=-1\neq0$: the eigenvectors are **not orthogonal**, so $P$
cannot be replaced by an orthogonal matrix to diagonalize $B$. This is not
a coincidence: if $B$ were orthogonally diagonalizable, $B=Q\Lambda Q^T$
for orthogonal $Q$, then $B^T=(Q\Lambda Q^T)^T=Q\Lambda^T Q^T=Q\Lambda Q^T=B$
would force $B$ to be symmetric — but $B^T=\begin{pmatrix}4&2\\1&3\end{pmatrix}
\neq B$, so $B$ is not symmetric, and hence (by this same argument, applied
in general) $B$ can *never* be orthogonally diagonalized, regardless of
which $Q$ is tried. Orthogonal diagonalizability is equivalent to symmetry,
not to diagonalizability alone.

**6.** From Exercise 1, $A_1 = Q\Lambda Q^T$ with $Q=\begin{pmatrix}
\tfrac1{\sqrt2}&\tfrac1{\sqrt2}\\\tfrac1{\sqrt2}&-\tfrac1{\sqrt2}\end{pmatrix}$,
$\Lambda=\operatorname{diag}(3,-1)$. Since $Q^{-1}=Q^T$,
$$A_1^{10} = (Q\Lambda Q^T)^{10} = Q\Lambda^{10}Q^T$$
(each interior $Q^TQ=I$ collapses telescopically, exactly as in Day 11
Exercise 10 but with $Q^{-1}$ replaced by the free transpose $Q^T$).
$\Lambda^{10}=\operatorname{diag}(3^{10},(-1)^{10})=\operatorname{diag}
(59049,1)$. Using $A_1^{10}=59049\,q_1q_1^T + 1\cdot q_2q_2^T$:
$$A_1^{10} = 59049\begin{pmatrix}1/2&1/2\\1/2&1/2\end{pmatrix} +
\begin{pmatrix}1/2&-1/2\\-1/2&1/2\end{pmatrix} =
\begin{pmatrix}29525&29524\\29524&29525\end{pmatrix}.$$
(Confirmed with `numpy.linalg.matrix_power(A1, 10)`.)

**7.** $A_1^{-1} = Q\Lambda^{-1}Q^T$ (same telescoping argument as Exercise
6, with exponent $-1$ instead of $10$), $\Lambda^{-1} =
\operatorname{diag}\left(\tfrac13,-1\right)$.
$$A_1^{-1} = \tfrac13\begin{pmatrix}1/2&1/2\\1/2&1/2\end{pmatrix} -
\begin{pmatrix}1/2&-1/2\\-1/2&1/2\end{pmatrix} =
\begin{pmatrix}1/6-1/2 & 1/6+1/2\\1/6+1/2&1/6-1/2\end{pmatrix} =
\begin{pmatrix}-1/3&2/3\\2/3&-1/3\end{pmatrix}.$$
Check: $A_1A_1^{-1} = \begin{pmatrix}1&2\\2&1\end{pmatrix}
\begin{pmatrix}-1/3&2/3\\2/3&-1/3\end{pmatrix} =
\begin{pmatrix}-1/3+4/3&2/3-2/3\\-2/3+2/3&4/3-1/3\end{pmatrix} =
\begin{pmatrix}1&0\\0&1\end{pmatrix}=I$. $\checkmark$

**8.** By the Spectral Theorem, $A=Q\Lambda Q^T$ with $\Lambda =
\operatorname{diag}(\lambda_1,\dots,\lambda_n)$. Using Day 11's cyclic
property of trace, $\operatorname{trace}(XY)=\operatorname{trace}(YX)$, with
$X=Q$ and $Y=\Lambda Q^T$:
$$\operatorname{trace}(A) = \operatorname{trace}(Q(\Lambda Q^T)) =
\operatorname{trace}((\Lambda Q^T)Q) = \operatorname{trace}(\Lambda(Q^TQ))
= \operatorname{trace}(\Lambda I) = \operatorname{trace}(\Lambda),$$
using $Q^TQ=I$ (orthogonality of $Q$) and associativity to regroup
$(\Lambda Q^T)Q = \Lambda(Q^TQ)$. Finally
$\operatorname{trace}(\Lambda)=\sum_{i=1}^n\lambda_i$ directly from the
definition of trace applied to a diagonal matrix. So
$\operatorname{trace}(A) = \lambda_1+\cdots+\lambda_n$. $\blacksquare$

**9.** The Remark after Theorem 19.3 shows the induction proof never
compares geometric and algebraic multiplicity at all — at each recursive
step it extracts exactly one eigenvector and orthogonally deflates the
problem by one dimension, and this always succeeds (Step 1 always finds a
real eigenvalue, by Theorem 19.1 plus the Fundamental Theorem of Algebra).
Running the recursion to completion for an $n\times n$ symmetric matrix
always produces a full set of $n$ mutually orthonormal eigenvectors, so for
symmetric matrices geometric multiplicity is *automatically* forced to
equal algebraic multiplicity for every eigenvalue — there's no matrix for
which it could fail. Day 11's $A_5=\begin{pmatrix}4&1&0\\0&4&1\\0&0&4
\end{pmatrix}$ is **not symmetric** ($A_5^T=\begin{pmatrix}4&0&0\\1&4&0\\
0&1&4\end{pmatrix}\neq A_5$), so none of today's theorems apply to it — the
Spectral Theorem's guarantee is specifically a consequence of symmetry
(via Theorem 19.1's realness and the induction's repeated use of it), and
$A_5$ is exactly the kind of matrix (a Jordan block) where that guarantee
fails to hold precisely because the hypothesis $A=A^T$ fails.

**10.** Since $A$ is orthogonal, $A^TA=I$, i.e. $A^{-1}=A^T$. Since $A$ is
also symmetric, $A^T=A$. Combining, $A^{-1}=A$, i.e. $A\cdot A = A A^{-1} =
I$, so $A^2=I$. Let $\lambda$ be any eigenvalue of $A$ with eigenvector
$v\neq0$: $Av=\lambda v$. By Theorem 19.1, $\lambda$ is real (or directly:
$A$ symmetric $\Rightarrow$ real eigenvalues). Apply $A$ again:
$A^2v = A(\lambda v) = \lambda(Av) = \lambda^2v$. But $A^2=I$, so $A^2v=v$.
Hence $\lambda^2v = v$, and since $v\neq0$, $\lambda^2=1$, giving
$\lambda=\pm1$. $\blacksquare$

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements a numerical spectral decomposition and reconstruction
check. Open `starter_code/day19_spectral_theorem.py` — it has one function
to complete, `spectral_decompose_and_check`. Fill in the `TODO`, then run
the file directly (`python starter_code/day19_spectral_theorem.py`); it
should print a success message with no errors.

**Hint:** use `eigvals, Q = np.linalg.eigh(A)` — **not** `np.linalg.eig`.
`eigh` is specifically for symmetric (or, in the complex case, Hermitian)
matrices: it exploits symmetry to guarantee real eigenvalues and a genuinely
orthogonal `Q` (`np.linalg.eig` on a symmetric matrix will often *also*
return the right answer up to floating point, but makes no such guarantee
and does noticeably more work internally, since it handles the fully
general, possibly-complex-eigenvalue case). Build
`reconstructed = Q @ np.diag(eigvals) @ Q.T` and compare to `A`.

Once your implementation passes, extend it: construct a symmetric matrix
with a genuinely repeated eigenvalue (e.g. `A3` from Exercise 3,
$\begin{pmatrix}2&1&1\\1&2&1\\1&1&2\end{pmatrix}$, whose eigenvalue $1$ has
multiplicity $2$) and run it through your function. Confirm `Q` still comes
back orthogonal and the reconstruction still matches `A`, even though the
two columns of `Q` spanning the repeated eigenspace are *not* the same
vectors you chose by hand in Exercise 3 (`eigh` picks some orthonormal basis
of that eigenspace, not necessarily yours — eigenvectors within a repeated
eigenspace are only unique up to choice of orthonormal basis, unlike the
single-eigenvector-per-eigenvalue case). This is the numerical confirmation
of today's Remark: the repeated-eigenvalue case works out fine, it's just
not unique.

If you get stuck for more than ~10 minutes, check
`solutions/day19_spectral_theorem.py` — but only after a real attempt.

## Journal template

```
## Day 19 — Symmetric matrices, Spectral Theorem
Key theorem in my own words: ...
What confused me: ...
```
