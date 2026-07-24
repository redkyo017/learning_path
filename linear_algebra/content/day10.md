# Day 10 — Eigenvalues and Eigenvectors

## Learning objectives

By the end of today you should be able to:
- State the definitions of eigenvalue, eigenvector, and characteristic
  polynomial, and explain how they relate.
- Prove that $\lambda$ is an eigenvalue of $A$ if and only if
  $\det(A - \lambda I) = 0$.
- Prove that eigenvectors corresponding to distinct eigenvalues are linearly
  independent.
- Find, by hand, the eigenvalues and eigenvectors of $2\times 2$ and
  $3\times 3$ matrices, including cases with a repeated eigenvalue and cases
  with complex eigenvalues.

## Reference material

- Primer (15 min, geometric intuition): 3Blue1Brown, *Essence of Linear
  Algebra*, Chapter 14 (eigenvectors and eigenvalues) —
  [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab)
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §4.1–4.2 —
  [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson), the
  Eigenvalues and Eigenvectors chapter (first half) — if you don't have a
  copy, the exercises below are self-contained and sufficient for today.

The theory below is self-contained — you do not strictly need the Treil PDF
to do today's work, but reading his §4.1–4.2 alongside this is the "theory"
layer of today's three-layer structure.

## Theory

### Definition 10.1 (Eigenvalue, eigenvector)

Let $A$ be an $n \times n$ matrix (over $\mathbb{R}$, or more generally
$\mathbb{C}$). A scalar $\lambda$ is an **eigenvalue** of $A$ if there exists
a *nonzero* vector $v$ such that
$$Av = \lambda v.$$
Any such nonzero $v$ is called an **eigenvector** of $A$ corresponding to
$\lambda$. Geometrically: $v$ is a direction that $A$ does not rotate or
otherwise redirect — $A$ only stretches, shrinks, or flips $v$ along its own
line, by the factor $\lambda$.

The requirement that $v \neq 0$ is essential: $A0 = \lambda 0$ holds
trivially for *every* $\lambda$, so if $v = 0$ were allowed, every scalar
would be an "eigenvalue" and the definition would be vacuous.

### Definition 10.2 (Characteristic polynomial)

For an $n \times n$ matrix $A$, the **characteristic polynomial** of $A$ is
$$p_A(\lambda) = \det(A - \lambda I).$$
Expanding the determinant shows $p_A$ is a polynomial in $\lambda$ of degree
exactly $n$, with leading term $(-1)^n \lambda^n$. (We will not need the
general cofactor-expansion argument for the degree today — it's visible
directly in every $2\times 2$ and $3 \times 3$ example below, and a full
induction on $n$ is a routine extension of Day 8's cofactor expansion.)

Even when $A$ has only real entries, $p_A$ is a polynomial with real
coefficients, and real polynomials do not always have real roots (think of
$\lambda^2 + 1$). So a real matrix can have genuinely complex eigenvalues —
Exercise 6 below is exactly such a case. Over $\mathbb{C}$, the Fundamental
Theorem of Algebra guarantees $p_A$ has exactly $n$ roots counted with
multiplicity, which is why eigenvalue theory is cleanest when stated over
$\mathbb{C}$ even for real matrices.

### Theorem 10.1 (Eigenvalues are exactly the roots of the characteristic polynomial)

$\lambda$ is an eigenvalue of $A$ if and only if $\det(A - \lambda I) = 0$.

**Proof.** We show a chain of equivalences.

$\lambda$ is an eigenvalue of $A$
$\iff$ there exists a nonzero $v$ with $Av = \lambda v$
$\iff$ there exists a nonzero $v$ with $Av - \lambda v = 0$
$\iff$ there exists a nonzero $v$ with $(A - \lambda I)v = 0$

(the middle step just uses $\lambda v = (\lambda I) v$ and factors $v$ out of
$Av - (\lambda I)v$, both valid by the distributive law for matrix
multiplication).

So $\lambda$ is an eigenvalue of $A$ if and only if the homogeneous linear
system $(A - \lambda I)x = 0$ has a *nontrivial* solution (a solution other
than $x = 0$).

Now, a homogeneous system $Mx = 0$ has a nontrivial solution if and only if
$M$ is **singular** (not invertible): if $M$ were invertible, we could
multiply both sides of $Mx = 0$ by $M^{-1}$ to get $x = M^{-1}0 = 0$, so the
*only* solution would be the trivial one — hence a nontrivial solution
existing rules out invertibility. Conversely, if $M$ is singular, its columns
are linearly dependent (an invertible matrix's columns are always
independent, since $Mx=0, x\ne0$ would otherwise witness a dependence), so
there exist scalars $x_1, \dots, x_n$, not all zero, with
$x_1 M_{\cdot 1} + \cdots + x_n M_{\cdot n} = 0$ — exactly the statement that
$x = (x_1, \dots, x_n) \neq 0$ satisfies $Mx = 0$.

Applying this with $M = A - \lambda I$: the system $(A-\lambda I)x = 0$ has a
nontrivial solution if and only if $A - \lambda I$ is singular.

Finally, by Day 8's theorem (a square matrix is invertible if and only if
its determinant is nonzero), $A - \lambda I$ is singular if and only if
$\det(A - \lambda I) = 0$.

Chaining all of these equivalences together:
$$\lambda \text{ is an eigenvalue of } A \iff \det(A - \lambda I) = 0. \qquad \blacksquare$$

This theorem is the entire computational engine of today: it converts the
definition of eigenvalue (which quantifies over vectors $v$, an infinite
search) into finding the roots of a single explicit polynomial in one
variable $\lambda$ (a finite, mechanical task).

### Theorem 10.2 (Eigenvectors for distinct eigenvalues are linearly independent)

Let $\lambda_1, \dots, \lambda_k$ be *distinct* eigenvalues of $A$, with
corresponding eigenvectors $v_1, \dots, v_k$ (each $v_i \neq 0$ by
definition). Then $\{v_1, \dots, v_k\}$ is linearly independent.

**Proof.** Suppose, for contradiction, that the claim is false: there exists
some collection of eigenvectors for distinct eigenvalues that is linearly
dependent. Among all such (hypothetical) counterexamples, choose one of
*smallest* size $k$: eigenvectors $v_1, \dots, v_k$ for distinct eigenvalues
$\lambda_1, \dots, \lambda_k$, linearly dependent, with no dependent
collection of eigenvectors-for-distinct-eigenvalues of size smaller than $k$.

Note $k \geq 2$: a single vector $v_1$ is "dependent" only if $v_1 = 0$, but
eigenvectors are nonzero by definition, so a size-$1$ collection is always
independent and cannot be our counterexample.

Since $v_1, \dots, v_k$ are dependent, there is a relation
$$c_1 v_1 + c_2 v_2 + \cdots + c_k v_k = 0 \tag{$*$}$$
with not all $c_i$ equal to $0$.

*Claim: every $c_i$ in $(*)$ is nonzero.* Suppose instead some $c_j = 0$.
Dropping that term from $(*)$ leaves a nontrivial relation (the remaining
coefficients are not all zero, since not all of the original $c_i$ were)
among a proper subset of $\{v_1, \dots, v_k\}$ of size $k - 1$, still
eigenvectors for distinct eigenvalues (a subset of $\lambda_1, \dots,
\lambda_k$). That would be a dependent collection of size $k - 1 < k$,
contradicting our choice of $k$ as the smallest counterexample. So no $c_j$
can be $0$: all $c_1, \dots, c_k \neq 0$.

Now apply $A$ to both sides of $(*)$, using linearity of matrix
multiplication and $Av_i = \lambda_i v_i$ for each $i$:
$$A(c_1 v_1 + \cdots + c_k v_k) = A0$$
$$c_1 A v_1 + \cdots + c_k A v_k = 0$$
$$c_1 \lambda_1 v_1 + c_2 \lambda_2 v_2 + \cdots + c_k \lambda_k v_k = 0. \tag{$**$}$$

Next, multiply $(*)$ through by the scalar $\lambda_k$:
$$c_1 \lambda_k v_1 + c_2 \lambda_k v_2 + \cdots + c_k \lambda_k v_k = 0.$$

Subtract this from $(**)$ term by term; the last terms cancel exactly
(both are $c_k \lambda_k v_k$), leaving
$$c_1(\lambda_1 - \lambda_k) v_1 + c_2(\lambda_2 - \lambda_k) v_2 + \cdots + c_{k-1}(\lambda_{k-1} - \lambda_k) v_{k-1} = 0. \tag{$\dagger$}$$

This is a linear relation among $v_1, \dots, v_{k-1}$ — eigenvectors for the
distinct eigenvalues $\lambda_1, \dots, \lambda_{k-1}$, a collection of size
$k - 1 < k$. By minimality of $k$, no dependent collection of eigenvectors
for distinct eigenvalues has size smaller than $k$; hence $v_1, \dots,
v_{k-1}$ must be linearly *independent*. An independent set only satisfies a
linear relation with all coefficients zero, so every coefficient in
$(\dagger)$ vanishes:
$$c_i(\lambda_i - \lambda_k) = 0, \qquad i = 1, \dots, k-1.$$
Since $\lambda_1, \dots, \lambda_k$ are distinct, $\lambda_i - \lambda_k \neq
0$ for each $i < k$, so we may divide, giving $c_i = 0$ for all $i = 1,
\dots, k - 1$.

But this contradicts the earlier claim that every $c_i$ in $(*)$ is nonzero
(in particular $c_1 = 0$, say, contradicts $c_1 \neq 0$).

This contradiction shows our assumption was false: no such dependent
collection exists. Hence eigenvectors corresponding to distinct eigenvalues
are always linearly independent. $\blacksquare$

## Worked example

**Claim:** $A = \begin{pmatrix} 4 & 1 \\ 2 & 3 \end{pmatrix}$ has eigenvalues
$\lambda = 5$ and $\lambda = 2$, with corresponding eigenvectors $(1,1)$ and
$(1,-2)$.

**Step 1: characteristic polynomial.**
$$p_A(\lambda) = \det(A - \lambda I) = \det\begin{pmatrix} 4-\lambda & 1 \\ 2 & 3-\lambda \end{pmatrix} = (4-\lambda)(3-\lambda) - (1)(2).$$
Expanding: $(4-\lambda)(3-\lambda) = 12 - 7\lambda + \lambda^2$, so
$$p_A(\lambda) = \lambda^2 - 7\lambda + 12 - 2 = \lambda^2 - 7\lambda + 10.$$

**Step 2: solve $p_A(\lambda) = 0$.** Factor: $\lambda^2 - 7\lambda + 10 =
(\lambda - 5)(\lambda - 2)$. So the eigenvalues are $\lambda_1 = 5$ and
$\lambda_2 = 2$ (by Theorem 10.1, these are exactly the eigenvalues of $A$).

**Step 3: eigenvector for $\lambda_1 = 5$.** Solve $(A - 5I)v = 0$:
$$A - 5I = \begin{pmatrix} -1 & 1 \\ 2 & -2 \end{pmatrix}.$$
Row 1 gives $-v_1 + v_2 = 0$, i.e. $v_2 = v_1$ (row 2 is $2v_1 - 2v_2 = 0$,
the same equation scaled by $-2$, so it's redundant, as it must be since we
know this system has a nontrivial solution). Taking $v_1 = 1$ gives the
eigenvector $v = (1, 1)$ (or any nonzero scalar multiple).

**Step 4: eigenvector for $\lambda_2 = 2$.** Solve $(A - 2I)v = 0$:
$$A - 2I = \begin{pmatrix} 2 & 1 \\ 2 & 1 \end{pmatrix}.$$
Row 1 gives $2v_1 + v_2 = 0$, i.e. $v_2 = -2v_1$. Taking $v_1 = 1$ gives the
eigenvector $v = (1, -2)$.

**Check:** $Av = \begin{pmatrix}4&1\\2&3\end{pmatrix}\begin{pmatrix}1\\1\end{pmatrix} = \begin{pmatrix}5\\5\end{pmatrix} = 5\begin{pmatrix}1\\1\end{pmatrix}$ ✓, and
$\begin{pmatrix}4&1\\2&3\end{pmatrix}\begin{pmatrix}1\\-2\end{pmatrix} = \begin{pmatrix}2\\-4\end{pmatrix} = 2\begin{pmatrix}1\\-2\end{pmatrix}$ ✓.
By Theorem 10.2, since $5 \neq 2$, these two eigenvectors are automatically
linearly independent — no separate check needed.

## Unconventional edge

The trap: once you've internalized "find eigenvalues = find roots of
$\det(A-\lambda I)=0$," it's easy to let the whole topic collapse into a
polynomial-algebra exercise, completely detached from what an eigenvector
*means*. But an eigenvector isn't just a vector that happens to satisfy an
equation — it's a direction that the transformation $A$ leaves alone,
stretching or flipping it but never rotating it off its own line, while
every other direction gets sheared toward the eigenvector directions. If you
lose that picture, diagonalization (Day 11) looks like an arbitrary trick for
computing $A^{100}$ instead of "describe $A$ in the one coordinate system
where it's just independent scaling"; the Spectral Theorem (Day 19) looks
like a random fact about symmetric matrices instead of "symmetric matrices
have *perpendicular* invariant directions"; and SVD (Days 21–22) looks like
machinery bolted on from nowhere instead of "find the two orthonormal bases
in which *any* linear map, not just square invertible ones, becomes pure
scaling." Keep drawing the picture — an eigenvector is an arrow $A$ doesn't
turn — every time you factor a characteristic polynomial.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–6 are computational; 7, 8, 10 are proof-based; 9 is a
trap/computation problem.

1. Find the eigenvalues and eigenvectors of
   $A = \begin{pmatrix} 3 & 1 \\ 0 & 2 \end{pmatrix}$.
2. Find the eigenvalues and eigenvectors of
   $A = \begin{pmatrix} 1 & 2 \\ 2 & 1 \end{pmatrix}$.
3. Find the eigenvalues and eigenvectors of the "Fibonacci matrix"
   $A = \begin{pmatrix} 1 & 1 \\ 1 & 0 \end{pmatrix}$. (Don't be alarmed if
   the eigenvalues are irrational — solve the characteristic polynomial with
   the quadratic formula.)
4. Find the eigenvalue(s) and all linearly independent eigenvectors of
   $A = \begin{pmatrix} 3 & 1 & 0 \\ 0 & 3 & 1 \\ 0 & 0 & 3 \end{pmatrix}$.
   (This matrix has a *repeated* root of its characteristic polynomial —
   pay attention to how many independent eigenvectors you actually find for
   it.)
5. Find the eigenvalues and eigenvectors of
   $A = \begin{pmatrix} 2 & 0 & 0 \\ 1 & 3 & 0 \\ 4 & 5 & 4 \end{pmatrix}$.
6. Find the eigenvalues and eigenvectors of
   $A = \begin{pmatrix} 0 & -1 & 0 \\ 1 & 0 & 0 \\ 0 & 0 & 1 \end{pmatrix}$
   (this is a $90°$ rotation about the $z$-axis in $\mathbb{R}^3$; expect
   complex eigenvalues for two of the three).
7. Prove: $0$ is an eigenvalue of $A$ if and only if $A$ is singular.
8. Prove: if $A$ is a triangular matrix (upper or lower), then the
   eigenvalues of $A$ are exactly its diagonal entries. (Hint: what does
   $A - \lambda I$ look like, and what is the determinant of a triangular
   matrix?)
9. **Trap.** Do $A$ and $A^T$ always have the same eigenvalues? Do they
   always have the same eigenvectors? Justify both answers, and illustrate
   with $A = \begin{pmatrix} 3 & 1 \\ 0 & 2 \end{pmatrix}$ from Exercise 1.
10. Let $A = \begin{pmatrix} a & b \\ c & d \end{pmatrix}$ be a general
    $2\times 2$ matrix with eigenvalues $\lambda_1, \lambda_2$ (possibly
    complex, possibly equal). Prove that $\lambda_1 + \lambda_2 =
    \operatorname{trace}(A) = a + d$ and $\lambda_1 \lambda_2 = \det(A) = ad
    - bc$. (Hint: write $p_A(\lambda)$ explicitly, then compare it to
    $(\lambda - \lambda_1)(\lambda - \lambda_2)$.)

## Solutions

**1.** $p_A(\lambda) = \det\begin{pmatrix}3-\lambda & 1 \\ 0 & 2-\lambda\end{pmatrix} = (3-\lambda)(2-\lambda)$
(the matrix is upper triangular, so the determinant is just the product of
the diagonal entries — see Exercise 8). Roots: $\lambda = 3, 2$.
For $\lambda=3$: $(A-3I) = \begin{pmatrix}0&1\\0&-1\end{pmatrix}$, giving
$v_2 = 0$ and $v_1$ free, so eigenvector $(1,0)$.
For $\lambda=2$: $(A-2I) = \begin{pmatrix}1&1\\0&0\end{pmatrix}$, giving
$v_1 + v_2 = 0$, so eigenvector $(1,-1)$.

**2.** $p_A(\lambda) = (1-\lambda)^2 - 4 = \lambda^2 - 2\lambda - 3 =
(\lambda-3)(\lambda+1)$. Roots: $\lambda = 3, -1$.
For $\lambda=3$: $(A-3I) = \begin{pmatrix}-2&2\\2&-2\end{pmatrix}$, giving
$-v_1+v_2=0$, so eigenvector $(1,1)$.
For $\lambda=-1$: $(A+I) = \begin{pmatrix}2&2\\2&2\end{pmatrix}$, giving
$v_1+v_2=0$, so eigenvector $(1,-1)$.

**3.** $p_A(\lambda) = (1-\lambda)(-\lambda) - 1 = \lambda^2 - \lambda - 1$.
By the quadratic formula, $\lambda = \dfrac{1 \pm \sqrt{5}}{2}$ — the golden
ratio $\varphi = \frac{1+\sqrt5}{2}$ and its conjugate
$\psi = \frac{1-\sqrt5}{2}$.
For $\lambda = \varphi$: $(A - \varphi I)v = 0$ gives, from row 2,
$v_1 - \varphi v_2 = 0$, i.e. $v_1 = \varphi v_2$; taking $v_2 = 1$, the
eigenvector is $(\varphi, 1)$.
For $\lambda = \psi$: identically, the eigenvector is $(\psi, 1)$.
(This is why Fibonacci numbers grow like $\varphi^n$ — a preview of Day 12's
diagonalization-powered difference equations.)

**4.** $A$ is upper triangular with all diagonal entries $3$, so
$p_A(\lambda) = (3-\lambda)^3$ (Exercise 8) — a single eigenvalue $\lambda=3$
with algebraic multiplicity $3$. Solve $(A - 3I)v = 0$:
$$A - 3I = \begin{pmatrix}0&1&0\\0&0&1\\0&0&0\end{pmatrix}.$$
Row 1: $v_2 = 0$. Row 2: $v_3 = 0$. $v_1$ is free. So the eigenspace is
$\operatorname{span}\{(1,0,0)\}$ — only **one** independent eigenvector,
even though the eigenvalue $3$ is a triple root of the characteristic
polynomial. (This gap between algebraic multiplicity (3) and the number of
independent eigenvectors (1) is exactly what Day 11's diagonalization
material addresses — not every matrix has "enough" eigenvectors.)

**5.** $A$ is lower triangular, so by Exercise 8 the eigenvalues are the
diagonal entries: $\lambda = 2, 3, 4$.
For $\lambda=2$: $A - 2I = \begin{pmatrix}0&0&0\\1&1&0\\4&5&2\end{pmatrix}$.
Row 2: $v_1 + v_2 = 0 \Rightarrow v_2 = -v_1$. Row 3: $4v_1+5v_2+2v_3=0
\Rightarrow 4v_1 - 5v_1 + 2v_3 = 0 \Rightarrow v_3 = v_1/2$. Taking $v_1=2$:
eigenvector $(2,-2,1)$.
For $\lambda=3$: $A - 3I = \begin{pmatrix}-1&0&0\\1&0&0\\4&5&1\end{pmatrix}$.
Row 1: $v_1 = 0$. Row 3 (with $v_1=0$): $5v_2 + v_3 = 0 \Rightarrow v_3 =
-5v_2$. Taking $v_2=1$: eigenvector $(0,1,-5)$.
For $\lambda=4$: $A - 4I = \begin{pmatrix}-2&0&0\\1&-1&0\\4&5&0\end{pmatrix}$.
Row 1: $v_1=0$. Row 2: $v_1 - v_2 = 0 \Rightarrow v_2 = 0$. $v_3$ free.
Eigenvector $(0,0,1)$.

**6.** $p_A(\lambda) = \det\begin{pmatrix}-\lambda&-1&0\\1&-\lambda&0\\0&0&1-\lambda\end{pmatrix}$.
Expand along the third column: $(1-\lambda)\det\begin{pmatrix}-\lambda&-1\\1&-\lambda\end{pmatrix}
= (1-\lambda)(\lambda^2+1)$. Roots: $\lambda = 1, i, -i$.
For $\lambda=1$: $A - I = \begin{pmatrix}-1&-1&0\\1&-1&0\\0&0&0\end{pmatrix}$.
Row 1: $-v_1-v_2=0 \Rightarrow v_2=-v_1$. Row 2: $v_1-v_2=0 \Rightarrow
v_2=v_1$. Together, $v_1 = -v_1 \Rightarrow v_1=0=v_2$; $v_3$ free.
Eigenvector $(0,0,1)$ — the $z$-axis, which a rotation about the $z$-axis
indeed leaves fixed.
For $\lambda=i$: $A - iI = \begin{pmatrix}-i&-1&0\\1&-i&0\\0&0&1-i\end{pmatrix}$.
Row 3: $(1-i)v_3=0 \Rightarrow v_3=0$. Row 1: $-iv_1-v_2=0 \Rightarrow
v_2=-iv_1$. Taking $v_1=1$: eigenvector $(1,-i,0)$.
For $\lambda=-i$: by symmetry (complex conjugate of the previous case),
eigenvector $(1,i,0)$.

**7.** ($\Rightarrow$) If $0$ is an eigenvalue of $A$, then by Theorem 10.1,
$\det(A - 0\cdot I) = \det(A) = 0$, so $A$ is singular (by Day 8's theorem).
($\Leftarrow$) If $A$ is singular, $\det(A) = 0$, i.e. $\det(A - 0\cdot I) =
0$; by Theorem 10.1 (applied with $\lambda = 0$), $0$ is an eigenvalue of
$A$. Both directions hold, so $0$ is an eigenvalue of $A$ if and only if $A$
is singular.

**8.** Say $A$ is upper triangular (lower triangular is identical by
symmetry) with diagonal entries $a_{11}, \dots, a_{nn}$. Then $A - \lambda I$
is also upper triangular, with diagonal entries $a_{11}-\lambda, \dots,
a_{nn}-\lambda$ (subtracting $\lambda$ only changes the diagonal). The
determinant of a triangular matrix is the product of its diagonal entries
(Day 8), so
$$p_A(\lambda) = \det(A-\lambda I) = (a_{11}-\lambda)(a_{22}-\lambda)\cdots(a_{nn}-\lambda).$$
By Theorem 10.1, the eigenvalues of $A$ are exactly the roots of $p_A$, and
the roots of this product are precisely $\lambda = a_{11}, \dots, a_{nn}$ —
the diagonal entries of $A$.

**9.** Yes, $A$ and $A^T$ always have the same eigenvalues, but their
eigenvectors are generally *different*. For the eigenvalue claim:
$$p_{A^T}(\lambda) = \det(A^T - \lambda I) = \det\big((A-\lambda I)^T\big) = \det(A - \lambda I) = p_A(\lambda),$$
using the fact that $\lambda I$ is symmetric (so $(A - \lambda I)^T = A^T -
\lambda I$) and that a matrix and its transpose have the same determinant
(Day 8). Since $A$ and $A^T$ have the *identical* characteristic polynomial,
they have exactly the same roots, hence the same eigenvalues, by Theorem
10.1.
For the concrete illustration, $A = \begin{pmatrix}3&1\\0&2\end{pmatrix}$ has
eigenvalues $3, 2$ with eigenvectors $(1,0)$ and $(1,-1)$ (Exercise 1).
$A^T = \begin{pmatrix}3&0\\1&2\end{pmatrix}$: for $\lambda=3$,
$A^T - 3I = \begin{pmatrix}0&0\\1&-1\end{pmatrix}$ gives $v_1 = v_2$, so
eigenvector $(1,1)$ — *not* a multiple of $A$'s eigenvector $(1,0)$ for the
same eigenvalue. For $\lambda=2$, $A^T-2I = \begin{pmatrix}1&0\\1&0\end{pmatrix}$
gives $v_1 = 0$, so eigenvector $(0,1)$ — again different from $A$'s
$(1,-1)$. So the trap is real: matching eigenvalues do **not** imply
matching eigenvectors, because the proof above only ever compares
*determinants* (which pin down $\lambda$), never the actual null spaces of
$A - \lambda I$ versus $A^T - \lambda I$ (which pin down the eigenvectors,
and depend on the specific rows/columns of $A$ versus $A^T$, generally
different).

**10.** $p_A(\lambda) = \det\begin{pmatrix}a-\lambda & b \\ c & d-\lambda\end{pmatrix}
= (a-\lambda)(d-\lambda) - bc = \lambda^2 - (a+d)\lambda + (ad - bc) =
\lambda^2 - \operatorname{trace}(A)\,\lambda + \det(A)$.
By Theorem 10.1, $\lambda_1, \lambda_2$ are exactly the roots of $p_A$, so
$p_A(\lambda) = (\lambda - \lambda_1)(\lambda - \lambda_2) = \lambda^2 -
(\lambda_1+\lambda_2)\lambda + \lambda_1\lambda_2$. Comparing coefficients of
these two expressions for the same polynomial $p_A(\lambda)$: the
coefficient of $\lambda^1$ gives $-(\lambda_1+\lambda_2) =
-\operatorname{trace}(A)$, i.e. $\lambda_1+\lambda_2 = \operatorname{trace}(A)$;
the constant term gives $\lambda_1\lambda_2 = \det(A)$.

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab automates the "form the characteristic polynomial, then find its
roots" procedure you just did by hand. Open
`starter_code/day10_eigen_basics.py` — it has one function to complete,
`eigenvalues_via_characteristic_poly`.

**Hint:** `np.poly(A)` returns the coefficients of $A$'s characteristic
polynomial directly (highest degree first), and `np.roots(coeffs)` finds the
roots of a polynomial given its coefficients — chaining the two reproduces
exactly the "Step 1 / Step 2" of today's Worked example, just automated.

Fill in the `TODO`, then run the file directly
(`python starter_code/day10_eigen_basics.py`); it should print your
eigenvalues and confirm they match `numpy.linalg.eigvals`.

If you get stuck for more than ~10 minutes, check
`solutions/day10_eigen_basics.py` — but only after a real attempt.

Once your implementation passes, extend it: run it on the two 3x3 matrices
from Exercises 5 and 6 (the second has complex eigenvalues — `np.roots` will
happily return complex numbers, and `np.linalg.eigvals` will too) and
confirm your hand-computed eigenvalues from the Solutions section match.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $\lambda$ | "lambda — the stretch factor" | how much $A$ scales an eigenvector |
| $Av = \lambda v$ | "$A$ acting on $v$ is just $v$ scaled by $\lambda$" | the defining equation of an eigenpair |
| $\det(A - \lambda I)$ | "the determinant test for $\lambda$" | equals zero exactly when $\lambda$ is an eigenvalue |
| $p_A(\lambda)$ | "the characteristic polynomial of $A$" | its roots are the eigenvalues |
| $\iff$ | "is exactly the same statement as" | eigenvalue $\iff$ determinant test gives zero |
| $(*)$, $(**)$, $(\dagger)$ | "nicknames for equations, to refer back to them" | labels used inside the independence proof |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- An eigenvector is a direction the matrix does not turn: $A$ only
  stretches, shrinks, or flips it, by the factor $\lambda$.
- You never find eigenvalues by searching vectors: $\lambda$ is an
  eigenvalue exactly when $\det(A - \lambda I) = 0$.
- The characteristic polynomial of an $n \times n$ matrix has degree $n$,
  so there are at most $n$ eigenvalues (exactly $n$ over the complex
  numbers, counting repeats).
- A perfectly real matrix can have complex eigenvalues — rotations are the
  classic example.
- Eigenvectors belonging to different eigenvalues are automatically
  linearly independent — no extra check ever needed.

### Proof sketches

**Theorem 10.1 — key trick: turn "does a special vector exist?" into "is
one number zero?".**
Saying $\lambda$ is an eigenvalue means $(A - \lambda I)v = 0$ has a
nonzero solution. A homogeneous system has a nonzero solution exactly when
its matrix is singular — otherwise you could multiply by the inverse and
force $v = 0$. And singular means determinant zero (Day 8). Chain the three
equivalences and the infinite vector search collapses into finding roots of
one polynomial. Full version: Theorem 10.1 above.

**Theorem 10.2 — key trick: apply $A$, multiply by $\lambda_k$, subtract —
the last vector cancels.**
Assume the smallest possible dependent set of eigenvectors for distinct
eigenvalues. Feed the dependence relation through $A$ (each $v_i$ picks up
its own $\lambda_i$), separately multiply the same relation by
$\lambda_k$, and subtract: the last vector drops out, leaving a dependence
among fewer eigenvectors. That contradicts "smallest", because the
distinct-eigenvalue differences $\lambda_i - \lambda_k$ are nonzero and
can't rescue the coefficients. So no dependent set exists at all. Full
version: Theorem 10.2 above.

### If you remember only 3 things

1. $Av = \lambda v$ with $v \neq 0$: the matrix doesn't turn $v$, it only
   scales it by $\lambda$.
2. Eigenvalues are the roots of $\det(A - \lambda I) = 0$ — a polynomial
   problem, not a vector search.
3. Distinct eigenvalues give automatically independent eigenvectors, but a
   repeated eigenvalue may not have enough eigenvectors (Exercise 4's trap).

## Journal template

```
## Day 10 — Eigenvalues and eigenvectors
Key theorem in my own words: ...
What confused me: ...
```
