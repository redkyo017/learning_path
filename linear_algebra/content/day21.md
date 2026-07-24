# Day 21 — Singular Value Decomposition, Part 1: Existence & Geometric Meaning

## Learning objectives

By the end of today you should be able to:
- State the definition of the singular value decomposition (SVD) for a
  general real $m\times n$ matrix.
- Prove, completely and from the Spectral Theorem (Day 19), that every real
  matrix has an SVD — including the subtle steps (why $A^TA$ is positive
  semidefinite, why the constructed $u_i$ are orthonormal, and how to pad
  $U$ when $\operatorname{rank}(A) < m$).
- Compute an SVD by hand via $A^TA$ for small square, rank-deficient, and
  rectangular matrices.
- Prove the connection between singular values and rank, and between
  singular values and the Frobenius/operator norms of $A$.
- Explain (with proof) why $A$ maps the unit sphere in $\mathbb{R}^n$ to an
  ellipsoid in $\mathbb{R}^m$ whose semi-axis lengths are the singular
  values.

## Reference material

- Primer / exercise source: MIT OCW 18.06 (*Linear Algebra*, Strang) has a
  dedicated SVD lecture — [Lecture 29: Singular Value
  Decomposition](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/resources/lecture-29-singular-value-decomposition/).
  If that specific link ever rots, it's easy to relocate: go to the [course
  video lecture
  gallery](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/video_galleries/video-lectures/)
  or the syllabus and find the lecture titled "Singular Value Decomposition"
  (it's roughly two-thirds of the way through the semester, right after the
  symmetric-matrices/positive-definite block — the same place it sits in
  this 30-day plan).
- Background reading: Sergei Treil, *Linear Algebra Done Wrong* — [free
  PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf).
  Treil treats SVD only lightly, in the supplementary material around
  Chapter 5 (orthogonality/spectral theory); skim whatever your edition has
  there for a second exposition of today's existence proof, but don't expect
  a full treatment — today's Theory section is self-contained and is the
  primary source for today.
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson), the
  chapter on Linear Operators on Inner Product Spaces, section on Singular
  Value Decomposition — if you don't have a copy, the exercises below are
  self-contained and sufficient for today.

Today builds directly on **Day 19** (the Spectral Theorem for real symmetric
matrices: every real symmetric matrix has an orthonormal eigenbasis with
real eigenvalues) and **Day 20** (positive semidefinite matrices: $M$ is
positive semidefinite if $x^TMx \ge 0$ for all $x$, equivalently all of
$M$'s eigenvalues are $\ge 0$). If either feels shaky, a quick skim of those
journal entries first will make today's proof click much faster — the whole
existence proof is "apply Day 19 to a specific positive semidefinite matrix
built out of $A$."

## Theory

### Definition 21.1 (Singular value decomposition)

Let $A \in \mathbb{R}^{m\times n}$ be any real matrix (square or not, any
rank). A **singular value decomposition (SVD)** of $A$ is a factorization
$$A = U\Sigma V^T$$
where:
- $U \in \mathbb{R}^{m\times m}$ is orthogonal (Definition 17.1: $U^TU = I$),
- $V \in \mathbb{R}^{n\times n}$ is orthogonal ($V^TV = I$),
- $\Sigma \in \mathbb{R}^{m\times n}$ is **diagonal** in the generalized
  rectangular sense: $\Sigma_{ij} = 0$ whenever $i \neq j$, and the diagonal
  entries $\sigma_1 \ge \sigma_2 \ge \cdots \ge \sigma_{\min(m,n)} \ge 0$ are
  arranged in decreasing order.

The numbers $\sigma_1,\dots,\sigma_{\min(m,n)}$ are the **singular values**
of $A$. The columns $u_1,\dots,u_m$ of $U$ are the **left singular vectors**;
the columns $v_1,\dots,v_n$ of $V$ are the **right singular vectors**.

Note what's *not* assumed: $A$ need not be square, symmetric, or invertible.
This is the whole point — SVD is a factorization that exists for
literally every real matrix, unlike eigendecomposition (which needs a
square matrix, and even then can fail to have real eigenvalues or a full
eigenbasis).

### Lemma 21.1 ($A^TA$ is symmetric positive semidefinite)

For any $A \in \mathbb{R}^{m\times n}$, the matrix $A^TA \in
\mathbb{R}^{n\times n}$ is symmetric and positive semidefinite.

**Proof.** *Symmetric:* $(A^TA)^T = A^T(A^T)^T = A^TA$, using
$(XY)^T = Y^TX^T$ and $(A^T)^T = A$.

*Positive semidefinite:* for any $x \in \mathbb{R}^n$,
$$x^T(A^TA)x = (Ax)^T(Ax) = \langle Ax, Ax\rangle = \|Ax\|^2 \ge 0,$$
since a squared norm is always non-negative. Since $x$ was arbitrary,
$x^T(A^TA)x \ge 0$ for all $x \in \mathbb{R}^n$, which is exactly the
definition (Day 20) of positive semidefinite. $\blacksquare$

### Theorem 21.1 (Existence of the SVD)

Every $A \in \mathbb{R}^{m\times n}$ has a singular value decomposition
$A = U\Sigma V^T$.

**Proof.**

*Step 1: eigendecompose $A^TA$.* By Lemma 21.1, $A^TA$ is symmetric, so by
the Spectral Theorem (Day 19) it has an orthonormal eigenbasis
$v_1,\dots,v_n$ of $\mathbb{R}^n$ with real eigenvalues $\lambda_1 \ge
\lambda_2 \ge \cdots \ge \lambda_n$ (we are free to sort them, since the
Spectral Theorem doesn't impose an order — we choose the descending one).

*Step 2: the eigenvalues are non-negative.* Fix $i$. Since $v_i$ is a unit
eigenvector ($\|v_i\| = 1$, $A^TAv_i = \lambda_i v_i$),
$$\lambda_i = \lambda_i\|v_i\|^2 = \lambda_i\langle v_i,v_i\rangle = \langle \lambda_i v_i, v_i\rangle = \langle A^TAv_i, v_i\rangle = v_i^T(A^TA)v_i \ge 0,$$
where the last inequality is Lemma 21.1 applied to $x = v_i$. So
$\lambda_1 \ge \cdots \ge \lambda_n \ge 0$.

*Step 3: define the singular values.* Set $\sigma_i = \sqrt{\lambda_i} \ge
0$ for $i = 1,\dots,n$. Since the $\lambda_i$ are sorted descending and all
non-negative, so are the $\sigma_i$: $\sigma_1 \ge \cdots \ge \sigma_n \ge
0$. Let
$$r = \#\{i : \sigma_i > 0\} = \#\{i : \lambda_i > 0\},$$
so that $\sigma_1 \ge \cdots \ge \sigma_r > 0 = \sigma_{r+1} = \cdots =
\sigma_n$ (the ordering guarantees all the positive ones come first).

*Step 4: define $u_1,\dots,u_r$ and show they are orthonormal.* For each $i
= 1,\dots,r$ (so $\sigma_i > 0$), define
$$u_i = \frac{Av_i}{\sigma_i} \in \mathbb{R}^m.$$
For any $i,j \in \{1,\dots,r\}$,
$$\langle u_i, u_j\rangle = \left\langle \frac{Av_i}{\sigma_i}, \frac{Av_j}{\sigma_j}\right\rangle = \frac{1}{\sigma_i\sigma_j}(Av_i)^T(Av_j) = \frac{1}{\sigma_i\sigma_j}v_i^T(A^TA)v_j = \frac{1}{\sigma_i\sigma_j}v_i^T(\lambda_j v_j) = \frac{\lambda_j}{\sigma_i\sigma_j}\langle v_i,v_j\rangle.$$
Since $v_1,\dots,v_n$ are orthonormal, $\langle v_i,v_j\rangle = \delta_{ij}$
(1 if $i=j$, 0 otherwise). If $i \neq j$, this makes the whole expression
$0$. If $i = j$, it becomes $\dfrac{\lambda_i}{\sigma_i^2}\cdot 1 =
\dfrac{\lambda_i}{\lambda_i} = 1$ (using $\sigma_i^2 = \lambda_i$). So
$$\langle u_i,u_j\rangle = \delta_{ij} \quad \text{for all } i,j \in \{1,\dots,r\},$$
i.e. $\{u_1,\dots,u_r\}$ is an orthonormal set in $\mathbb{R}^m$.

*Step 5: $r \le m$, and extending to a full orthonormal basis of
$\mathbb{R}^m$.* Orthonormal vectors are automatically linearly independent
(a standard fact: if $\sum c_iu_i = 0$, take the inner product with $u_k$ to
get $c_k = 0$ for every $k$), and $\mathbb{R}^m$ cannot contain more than
$m$ linearly independent vectors. Hence $r \le m$. If $r < m$, extend
$\{u_1,\dots,u_r\}$ to a full orthonormal basis $\{u_1,\dots,u_r,
u_{r+1},\dots,u_m\}$ of $\mathbb{R}^m$ — this is always possible: complete
$\{u_1,\dots,u_r\}$ to *any* basis of $\mathbb{R}^m$ (possible since it's
linearly independent), then run Gram-Schmidt (Day 15) on that basis; since
$u_1,\dots,u_r$ are already orthonormal, Gram-Schmidt leaves them unchanged
and only orthonormalizes the added vectors. If $r = m$, no extension is
needed. Either way we now have a full orthonormal basis $u_1,\dots,u_m$ of
$\mathbb{R}^m$.

*Step 6: assemble $U$, $\Sigma$, $V$.* Let
$$U = [\,u_1 \mid u_2 \mid \cdots \mid u_m\,] \in \mathbb{R}^{m\times m}, \qquad V = [\,v_1\mid v_2\mid\cdots\mid v_n\,] \in \mathbb{R}^{n\times n}.$$
$U$ has orthonormal columns forming a basis of $\mathbb{R}^m$, so $U$ is
orthogonal (Definition 17.1); likewise $V$ is orthogonal. Let $\Sigma \in
\mathbb{R}^{m\times n}$ have $(i,i)$ entry $\sigma_i$ for $i =
1,\dots,\min(m,n)$ and all other entries $0$.

*Step 7: verify $AV = U\Sigma$.* It suffices to check that the two sides
agree column by column, for each $k = 1,\dots,n$. Column $k$ of $AV$ is
$Av_k$ (since $V$'s $k$-th column is $v_k$). Column $k$ of $U\Sigma$ is $U$
applied to column $k$ of $\Sigma$, which is $\sigma_k e_k$ if $k \le m$ (the
scalar $\sigma_k$ times the $k$-th standard basis vector of
$\mathbb{R}^m$), or the zero vector of $\mathbb{R}^m$ if $k > m$ (only
possible when $n > m$, since $\Sigma$ has no $k$-th diagonal position past
row $m$). Two cases:

- **$k \le r$:** then $\sigma_k > 0$, so column $k$ of $U\Sigma$ is $U(\sigma_k e_k) = \sigma_k u_k$ (since $Ue_k$ is just the $k$-th column of $U$, namely $u_k$). By definition, $u_k = Av_k/\sigma_k$, so $\sigma_k u_k = Av_k$. This matches column $k$ of $AV$.
- **$k > r$:** then $\lambda_k = 0$ (by definition of $r$ and the descending order), so $\sigma_k = 0$, and
  $$\|Av_k\|^2 = (Av_k)^T(Av_k) = v_k^T(A^TA)v_k = v_k^T(\lambda_k v_k) = \lambda_k = 0,$$
  hence $Av_k = 0$ — column $k$ of $AV$ is the zero vector. On the other side, column $k$ of $U\Sigma$ is also the zero vector: if $k \le m$ it's $U(\sigma_k e_k) = U\cdot 0 = 0$ since $\sigma_k = 0$; if $k > m$ it's $U\cdot 0 = 0$ directly, as noted above. Either way, both sides are $0$ and match.

Since columns $1,\dots,n$ agree in both cases, $AV = U\Sigma$.

*Step 8: conclude.* $V$ is orthogonal, so $V^{-1} = V^T$ (Day 17, Exercise
4(b) applied here, or directly: $V^TV=I$ and $V$ square implies $V^T$ is a
two-sided inverse). Multiplying $AV = U\Sigma$ on the right by $V^T$ gives
$$AVV^T = U\Sigma V^T \implies A = U\Sigma V^T.$$
This is exactly Definition 21.1: $U, V$ orthogonal, $\Sigma$ rectangular
diagonal with non-negative descending entries. $\blacksquare$

Notice what the proof actually produced, since it matters for the worked
example and exercises below: $\Sigma$'s diagonal entries are literally
$\sigma_i = \sqrt{\lambda_i}$ for the eigenvalues $\lambda_i$ of $A^TA$;
$V$'s columns are an orthonormal eigenbasis of $A^TA$; and $U$'s columns
are $u_i = Av_i/\sigma_i$ wherever $\sigma_i > 0$, padded by *any* choice of
vectors completing an orthonormal basis of $\mathbb{R}^m$ wherever
$\sigma_i = 0$. That last clause is not a minor technicality — Exercise 3
below shows a case where this padding is genuinely a free choice, not
forced by $A$.

## Worked example

**Compute the SVD by hand of** $A = \begin{pmatrix}3 & 0\\ 4 & 5\end{pmatrix}$.

**Step 1: form $A^TA$.**
$$A^T = \begin{pmatrix}3&4\\0&5\end{pmatrix}, \qquad A^TA = \begin{pmatrix}3&4\\0&5\end{pmatrix}\begin{pmatrix}3&0\\4&5\end{pmatrix} = \begin{pmatrix}9+16 & 0+20\\ 0+20 & 0+25\end{pmatrix} = \begin{pmatrix}25&20\\20&25\end{pmatrix}.$$

**Step 2: eigenvalues/eigenvectors of $A^TA$.** This is a symmetric
$2\times2$ matrix of the form $\begin{pmatrix}a&b\\b&a\end{pmatrix}$, whose
eigenvalues are always $a+b$ and $a-b$ (check: $(1,1)$ and $(1,-1)$ are
always eigenvectors of this pattern, with eigenvalues $a+b$, $a-b$
respectively). Here $a=25,b=20$, so
$$\lambda_1 = 25+20 = 45, \qquad \lambda_2 = 25-20=5,$$
with (unit) eigenvectors
$$v_1 = \frac{1}{\sqrt2}(1,1), \qquad v_2 = \frac{1}{\sqrt2}(1,-1).$$
So
$$\sigma_1 = \sqrt{45} = 3\sqrt5, \qquad \sigma_2 = \sqrt5.$$

**Step 3: compute $U$'s columns via $u_i = Av_i/\sigma_i$.**
$$Av_1 = \begin{pmatrix}3&0\\4&5\end{pmatrix}\frac{1}{\sqrt2}\begin{pmatrix}1\\1\end{pmatrix} = \frac{1}{\sqrt2}\begin{pmatrix}3\\9\end{pmatrix}, \qquad u_1 = \frac{Av_1}{3\sqrt5} = \frac{1}{3\sqrt5\cdot\sqrt2}\begin{pmatrix}3\\9\end{pmatrix} = \frac{1}{\sqrt{10}}\begin{pmatrix}1\\3\end{pmatrix}.$$
$$Av_2 = \begin{pmatrix}3&0\\4&5\end{pmatrix}\frac{1}{\sqrt2}\begin{pmatrix}1\\-1\end{pmatrix} = \frac{1}{\sqrt2}\begin{pmatrix}3\\-1\end{pmatrix}, \qquad u_2 = \frac{Av_2}{\sqrt5} = \frac{1}{\sqrt5\cdot\sqrt2}\begin{pmatrix}3\\-1\end{pmatrix} = \frac{1}{\sqrt{10}}\begin{pmatrix}3\\-1\end{pmatrix}.$$
Quick sanity checks: $\|u_1\|^2 = \tfrac{1}{10}(1+9)=1$ ✓, $\|u_2\|^2 =
\tfrac1{10}(9+1)=1$ ✓, and $\langle u_1,u_2\rangle = \tfrac1{10}(1\cdot3 +
3\cdot(-1)) = \tfrac1{10}(3-3)=0$ ✓ — orthonormal, exactly as Theorem 21.1
guarantees.

**Assemble.**
$$U = \frac{1}{\sqrt{10}}\begin{pmatrix}1&3\\3&-1\end{pmatrix}, \qquad \Sigma = \begin{pmatrix}3\sqrt5 & 0\\0&\sqrt5\end{pmatrix}, \qquad V = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}.$$

**Verify $A = U\Sigma V^T$ numerically.** (Note $V^T = V$ here, since $V$
happens to be symmetric.) Computing $U\Sigma$ first:
$$U\Sigma = \frac{1}{\sqrt{10}}\begin{pmatrix}1\cdot3\sqrt5 & 3\cdot\sqrt5\\3\cdot3\sqrt5 & -1\cdot\sqrt5\end{pmatrix} = \frac{\sqrt5}{\sqrt{10}}\begin{pmatrix}3&3\\9&-1\end{pmatrix} = \frac1{\sqrt2}\begin{pmatrix}3&3\\9&-1\end{pmatrix}.$$
Then $(U\Sigma)V^T$:
$$\frac1{\sqrt2}\begin{pmatrix}3&3\\9&-1\end{pmatrix}\cdot\frac1{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix} = \frac12\begin{pmatrix}3+3 & 3-3\\9-1 & 9+1\end{pmatrix} = \frac12\begin{pmatrix}6&0\\8&10\end{pmatrix} = \begin{pmatrix}3&0\\4&5\end{pmatrix} = A. \checkmark$$
This was also confirmed with NumPy ($\texttt{np.linalg.svd}$ gives the same
singular values $3\sqrt5 \approx 6.708$ and $\sqrt5 \approx 2.236$, and
reconstructing $U\Sigma V^T$ from the hand-derived matrices above matches
$A$ to floating-point precision) before this file was finalized.

## Unconventional edge

The trap: treating `numpy.linalg.svd(A)` as a black box — a mysterious
"third decomposition" alongside eigendecomposition and QR, with its own
rules to memorize. But you just proved it's nothing of the sort: it is the
Spectral Theorem (Day 19), applied verbatim to the specific symmetric
positive semidefinite matrix $A^TA$ (Day 20's vocabulary), plus one
bookkeeping trick — defining $u_i = Av_i/\sigma_i$ — to turn $A^TA$'s
eigenvectors into a second orthonormal basis living in $A$'s output space
rather than its input space. The only reason SVD *feels* like new machinery
is that it needs two orthonormal bases ($U$ and $V$) instead of one,
because $A$ itself doesn't act on a single space the way a symmetric
matrix does. Once you've internalized "SVD = spectral theorem on $A^TA$,
transported through $A$," you stop needing to memorize which matrix is
which — you can always rederive $V$, $\Sigma$, and $U$ from scratch, in
that order, from $A^TA$ alone.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–4 are computational (compute an SVD by hand); 5–8 and 10
are proof-based; 9 is conceptual/geometric.

1. Compute the SVD by hand of $A = \begin{pmatrix}1&0\\0&-2\end{pmatrix}$.
   Verify $U\Sigma V^T = A$.
2. Compute the SVD by hand of $A = \begin{pmatrix}2&2\\-1&1\end{pmatrix}$.
   Verify $U\Sigma V^T = A$.
3. Compute the SVD by hand of the rank-deficient matrix
   $A = \begin{pmatrix}1&2\\2&4\end{pmatrix}$. You should find one singular
   value is $0$. What freedom do you have in choosing the second column of
   $U$, and why does it not matter for the identity $A = U\Sigma V^T$?
4. Compute the SVD by hand of the rectangular matrix
   $A = \begin{pmatrix}2&0\\0&1\\0&0\end{pmatrix}$ ($3\times2$). This
   illustrates the $m > n$ case and the basis-extension step of Theorem
   21.1's proof (Step 5) in its simplest possible form.
5. Prove that the (nonzero) singular values of $A$ and $A^T$ coincide, as
   multisets. (Hint: show that if $v \neq 0$ is an eigenvector of $A^TA$
   with eigenvalue $\lambda \neq 0$, then $Av$ is an eigenvector of $AA^T$
   with the *same* eigenvalue $\lambda$, and that $Av \neq 0$. Then argue
   the same construction works in reverse, swapping the roles of $A$ and
   $A^T$.)
6. Prove that $\operatorname{rank}(A)$ equals the number of nonzero
   singular values of $A$. (Hint: first show
   $\ker(A^TA) = \ker(A)$ — one direction is immediate from
   $Ax=0\implies A^TAx=0$; for the other, mimic the computation in Lemma
   21.1's proof to show $A^TAx = 0 \implies \|Ax\|^2 = 0$. Then use
   rank-nullity together with the fact, from the Spectral Theorem, that a
   symmetric matrix's number of zero eigenvalues equals its nullity.)
7. Prove that $\sigma_1 = \max_{\|x\|=1}\|Ax\|$ (i.e. the largest singular
   value is the *operator norm* of $A$). (Hint: expand an arbitrary unit
   vector $x$ in the orthonormal eigenbasis $v_1,\dots,v_n$ of $A^TA$ from
   Theorem 21.1, write $Ax$ in terms of the $u_i$ and $\sigma_i$, and bound
   $\|Ax\|^2$.)
8. Prove that $\|A\|_F^2 = \sum_i \sigma_i^2$, where $\|A\|_F^2 =
   \sum_{i,j}A_{ij}^2$ is the squared Frobenius norm. (Hint: $\|A\|_F^2 =
   \operatorname{trace}(A^TA)$, and the trace of a symmetric matrix equals
   the sum of its eigenvalues.)
9. Using $A = U\Sigma V^T$, explain (with justification at each step, not
   just an assertion) why $A$ maps the unit sphere
   $\{x \in \mathbb{R}^n : \|x\|=1\}$ onto an ellipsoid in $\mathbb{R}^m$
   whose semi-axis lengths are exactly the singular values $\sigma_i$, and
   whose axes point along the directions $u_i$.
10. True or False, with justification: if $A$ is symmetric **positive
    definite** (Day 20), then the singular values of $A$ equal the
    eigenvalues of $A$, and $A$ has an SVD with $U = V$. (Hint: use the
    Spectral Theorem to write $A = Q\Lambda Q^T$ and compute $A^TA$
    directly in terms of $Q$ and $\Lambda$.)

## Solutions

**1.** $A^TA = \begin{pmatrix}1&0\\0&4\end{pmatrix}$, already diagonal, so
eigenvalues/eigenvectors can be read off directly: $\lambda=4$ for $e_2 =
(0,1)$, $\lambda=1$ for $e_1=(1,0)$. Sorting descending, $v_1 = (0,1)$
($\lambda_1=4$), $v_2=(1,0)$ ($\lambda_2=1$), so $\sigma_1=2,\sigma_2=1$.
$$u_1 = \frac{Av_1}{\sigma_1} = \frac{(0,-2)}{2} = (0,-1), \qquad u_2 = \frac{Av_2}{\sigma_2} = \frac{(1,0)}{1}=(1,0).$$
$$U = \begin{pmatrix}0&1\\-1&0\end{pmatrix}, \quad \Sigma = \begin{pmatrix}2&0\\0&1\end{pmatrix}, \quad V = \begin{pmatrix}0&1\\1&0\end{pmatrix}.$$
Check ($V^T=V$ since $V$ is symmetric here): $U\Sigma = \begin{pmatrix}0&1\\-2&0\end{pmatrix}$,
$(U\Sigma)V^T = \begin{pmatrix}0&1\\-2&0\end{pmatrix}\begin{pmatrix}0&1\\1&0\end{pmatrix} = \begin{pmatrix}1&0\\0&-2\end{pmatrix} = A.$ ✓
(Confirmed numerically with NumPy.)

**2.** $A^TA = \begin{pmatrix}2&-1\\2&1\end{pmatrix}^T\cdots$ — computing
directly: $A^T=\begin{pmatrix}2&-1\\2&1\end{pmatrix}$,
$A^TA = \begin{pmatrix}2&-1\\2&1\end{pmatrix}\begin{pmatrix}2&2\\-1&1\end{pmatrix} = \begin{pmatrix}5&3\\3&5\end{pmatrix}$.
Using the $\begin{pmatrix}a&b\\b&a\end{pmatrix}$ shortcut from the worked
example ($a=5,b=3$): $\lambda_1=8,\lambda_2=2$,
$v_1=\tfrac1{\sqrt2}(1,1)$, $v_2=\tfrac1{\sqrt2}(1,-1)$, so
$\sigma_1=2\sqrt2,\sigma_2=\sqrt2$.
$$Av_1 = \tfrac1{\sqrt2}(4,0) = (2\sqrt2,0), \quad u_1 = \frac{(2\sqrt2,0)}{2\sqrt2} = (1,0).$$
$$Av_2 = \tfrac1{\sqrt2}(0,-2) = (0,-\sqrt2), \quad u_2 = \frac{(0,-\sqrt2)}{\sqrt2}=(0,-1).$$
$$U = \begin{pmatrix}1&0\\0&-1\end{pmatrix}, \quad \Sigma = \begin{pmatrix}2\sqrt2&0\\0&\sqrt2\end{pmatrix}, \quad V = \tfrac1{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}.$$
Check: $U\Sigma = \begin{pmatrix}2\sqrt2&0\\0&-\sqrt2\end{pmatrix}$,
$(U\Sigma)V^T = \tfrac1{\sqrt2}\begin{pmatrix}2\sqrt2&0\\0&-\sqrt2\end{pmatrix}\begin{pmatrix}1&1\\1&-1\end{pmatrix} = \tfrac1{\sqrt2}\begin{pmatrix}2\sqrt2&2\sqrt2\\-\sqrt2&\sqrt2\end{pmatrix} = \begin{pmatrix}2&2\\-1&1\end{pmatrix}=A.$ ✓
(Confirmed numerically with NumPy.)

**3.** $A$ is symmetric, so $A^TA = A^2 = \begin{pmatrix}1&2\\2&4\end{pmatrix}\begin{pmatrix}1&2\\2&4\end{pmatrix} = \begin{pmatrix}5&10\\10&20\end{pmatrix}$.
Trace $=25$, determinant $=5\cdot20-10\cdot10=0$, so eigenvalues solve
$\lambda^2-25\lambda=0$, giving $\lambda_1=25,\lambda_2=0$. Eigenvector for
$\lambda_1=25$: solve $(A^TA-25I)v=0 \Rightarrow -20v_1+10v_2=0 \Rightarrow
v_2=2v_1$, giving $v_1^{\text{(vec)}} = \tfrac1{\sqrt5}(1,2)$. The
orthogonal unit vector is $v_2^{\text{(vec)}} = \tfrac1{\sqrt5}(2,-1)$
(automatically the eigenvector for $\lambda_2=0$, since $A^TA$ is
symmetric and eigenvectors for distinct eigenvalues are orthogonal). So
$\sigma_1=5$, $\sigma_2=0$.
$$u_1 = \frac{Av_1}{\sigma_1} = \frac{1}{5}\cdot\frac1{\sqrt5}\begin{pmatrix}1+4\\2+8\end{pmatrix} = \frac1{5\sqrt5}(5,10) = \frac1{\sqrt5}(1,2).$$
For $\sigma_2 = 0$, the formula $u_2 = Av_2/\sigma_2$ is undefined ($0/0$)
— exactly the situation flagged after Theorem 21.1. $u_2$ must instead be
*any* unit vector orthogonal to $u_1$ in $\mathbb{R}^2$: the two choices are
$\pm\tfrac1{\sqrt5}(2,-1)$. Either works, because $A = U\Sigma V^T =
\sigma_1u_1v_1^T + \sigma_2u_2v_2^T = 5u_1v_1^T + 0\cdot u_2v_2^T =
5u_1v_1^T$ regardless of $u_2$ — the second term vanishes no matter what
$u_2$ is, since it's multiplied by $\sigma_2=0$. Concretely, with
$v_1=\tfrac1{\sqrt5}(1,2)$:
$$5u_1v_1^T = 5\cdot\frac1{\sqrt5}\binom{1}{2}\cdot\frac1{\sqrt5}(1\ \ 2) = \binom{1}{2}(1\ \ 2) = \begin{pmatrix}1&2\\2&4\end{pmatrix}=A. \checkmark$$
This is the concrete case promised in the Theory section: whenever a
singular value is $0$, the corresponding column of $U$ is unobservable from
$A$ and is a free choice in the proof's basis-extension step.

**4.** $A^T = \begin{pmatrix}2&0&0\\0&1&0\end{pmatrix}$,
$A^TA = \begin{pmatrix}4&0\\0&1\end{pmatrix}$, already diagonal:
$\lambda_1=4$ ($v_1=(1,0)$), $\lambda_2=1$ ($v_2=(0,1)$), so
$\sigma_1=2,\sigma_2=1$, both nonzero, so $r=2$.
$$u_1 = \frac{Av_1}{2} = \frac{(2,0,0)}{2}=(1,0,0), \qquad u_2 = \frac{Av_2}{1} = (0,1,0).$$
Here $r=2 < m=3$, so Step 5 of Theorem 21.1 requires extending
$\{u_1,u_2\}$ to a full orthonormal basis of $\mathbb{R}^3$: the only unit
vector orthogonal to both $(1,0,0)$ and $(0,1,0)$ (up to sign) is $u_3 =
(0,0,1)$. So
$$U = I_3, \qquad \Sigma = \begin{pmatrix}2&0\\0&1\\0&0\end{pmatrix}, \qquad V = I_2.$$
Check: $U\Sigma V^T = \Sigma = \begin{pmatrix}2&0\\0&1\\0&0\end{pmatrix} =
A$. ✓ Notice $u_3$ never appears in the product (its column of $U$ only
ever multiplies the all-zero third row of $\Sigma$), exactly as the general
proof predicts: the padding vectors exist to make $U$ a genuine orthogonal
matrix, not because $A$ "uses" them.

**5.** Let $\lambda \neq 0$ be an eigenvalue of $A^TA$ with unit eigenvector
$v$ ($A^TAv = \lambda v$). Consider $w = Av$. First, $w \neq 0$: if $w=0$
then $A^TAv = A^Tw = 0$, but $A^TAv=\lambda v\neq0$ (since $\lambda\neq0,
v\neq0$) — contradiction. Now check $w$ is an eigenvector of $AA^T$ with
the same eigenvalue:
$$AA^Tw = AA^T(Av) = A(A^TAv) = A(\lambda v) = \lambda(Av) = \lambda w.$$
So every nonzero eigenvalue of $A^TA$ is also an eigenvalue of $AA^T$
(via $v \mapsto Av$). Running the identical argument with the roles of $A$
and $A^T$ swapped (i.e. starting from an eigenvector of $AA^T=(A^T)^TA^T$
and mapping via $A^T$) shows every nonzero eigenvalue of $AA^T$ is also an
eigenvalue of $A^TA$. Moreover this correspondence is injective on
eigenspaces (orthogonal eigenvectors of $A^TA$ map to orthogonal vectors —
same computation as Theorem 21.1's Step 4 — so it preserves multiplicity).
Hence the nonzero eigenvalues of $A^TA$ and $AA^T$ coincide as multisets,
so $\sigma_i(A) = \sqrt{\lambda_i(A^TA)} = \sqrt{\lambda_i(AA^T)} =
\sigma_i(A^T)$ for the nonzero singular values.

**6.** *$\ker(A^TA) = \ker(A)$:* If $x \in \ker(A)$ (so $Ax=0$), then
$A^TAx = A^T0 = 0$, so $x \in \ker(A^TA)$. Conversely, if $x\in\ker(A^TA)$
(so $A^TAx=0$), then
$$0 = x^T(A^TAx) = (Ax)^T(Ax) = \|Ax\|^2 \implies Ax = 0,$$
so $x \in \ker(A)$. Both inclusions give $\ker(A^TA)=\ker(A)$, hence
$\dim\ker(A^TA) = \dim\ker(A) = n - \operatorname{rank}(A)$ (rank-nullity,
Day 4).

Since $A^TA$ is symmetric, the Spectral Theorem gives it an orthonormal
eigenbasis, and $\dim\ker(A^TA)$ equals exactly the number of zero
eigenvalues among $\lambda_1,\dots,\lambda_n$ (each zero eigenvalue
contributes one dimension to the eigenspace, i.e. to the kernel, and
distinct eigenspaces are independent). The number of zero $\lambda_i$'s is,
by definition, $n - r$ (recall $r$ is the count of positive $\lambda_i$'s).
So
$$n - \operatorname{rank}(A) = \dim\ker(A^TA) = n - r \implies \operatorname{rank}(A) = r,$$
i.e. $\operatorname{rank}(A)$ equals the number of nonzero singular values.

**7.** Let $x \in \mathbb{R}^n$ with $\|x\|=1$. Expand $x$ in the
orthonormal eigenbasis $v_1,\dots,v_n$ from Theorem 21.1: $x = \sum_{i=1}^n
c_iv_i$ with $\sum_i c_i^2 = \|x\|^2 = 1$ (Parseval, from orthonormality).
Then
$$Ax = \sum_{i=1}^n c_iAv_i = \sum_{i=1}^r c_i\sigma_iu_i$$
(using $Av_i=\sigma_iu_i$ for $i\le r$, and $Av_i=0$ for $i>r$, shown in
Theorem 21.1 Step 7). Since $u_1,\dots,u_r$ are orthonormal,
$$\|Ax\|^2 = \sum_{i=1}^r c_i^2\sigma_i^2 \le \sigma_1^2\sum_{i=1}^r c_i^2 \le \sigma_1^2\sum_{i=1}^n c_i^2 = \sigma_1^2,$$
using $\sigma_i \le \sigma_1$ for all $i\le r$ and $c_i^2\ge0$. So
$\|Ax\|\le\sigma_1$ for every unit $x$. Equality is achieved at $x=v_1$
(then $c_1=1$, all other $c_i=0$, so $Ax = \sigma_1u_1$ and $\|Ax\| =
\sigma_1\|u_1\|=\sigma_1$). Hence $\max_{\|x\|=1}\|Ax\| = \sigma_1$.

**8.** By definition, $\|A\|_F^2 = \sum_{i,j}A_{ij}^2$. The $(j,j)$ entry of
$A^TA$ is $\sum_i A_{ij}^2$ (dotting column $j$ of $A$ with itself), so
$$\operatorname{trace}(A^TA) = \sum_j\sum_iA_{ij}^2 = \|A\|_F^2.$$
Since $A^TA$ is symmetric, its trace equals the sum of its eigenvalues
(true for any matrix via the characteristic polynomial, and particularly
transparent here: in the eigenbasis $v_1,\dots,v_n$, $A^TA$ is similar to
$\operatorname{diag}(\lambda_1,\dots,\lambda_n)$, and trace is invariant
under similarity). So
$$\|A\|_F^2 = \operatorname{trace}(A^TA) = \sum_{i=1}^n\lambda_i = \sum_{i=1}^n\sigma_i^2.$$

**9.** Let $x\in\mathbb{R}^n$ with $\|x\|=1$, and set $y=Ax=U\Sigma V^Tx$.
Write $w = V^Tx$. Since $V^T$ is orthogonal, it preserves norms (Day 17
Corollary), so $\|w\|=\|x\|=1$; moreover, as $x$ ranges over the *entire*
unit sphere of $\mathbb{R}^n$, so does $w=V^Tx$ (because $V^T$ is a
bijection of $\mathbb{R}^n$ that preserves the sphere, with inverse $V$
also preserving the sphere). So the intermediate set $\{w : \|w\|=1\}$ is
again exactly the unit sphere, just re-labeled by $V^T$.

Next, $\Sigma$ acts on $w=(w_1,\dots,w_n)$ by $(\Sigma w)_i = \sigma_iw_i$
for $i=1,\dots,\min(m,n)$ (and drops/pads coordinates if $m\neq n$) — i.e.
it stretches (or shrinks) the $i$-th coordinate axis by the factor
$\sigma_i$ independently for each $i$. The image of the unit sphere
$\{w:\|w\|=1\}$ under an independent per-axis stretch is, by definition,
an **axis-aligned ellipsoid** with semi-axis lengths exactly the stretch
factors $\sigma_1,\dots,\sigma_{\min(m,n)}$ (in the standard coordinate
directions $e_1,\dots,e_{\min(m,n)}$ of $\mathbb{R}^m$); directions $i$
with $\sigma_i=0$ collapse that axis to a point, consistent with the
ellipsoid degenerating in exactly the directions killed by $A$
(Exercise 6: this happens along $\operatorname{rank}(A)$-many nonzero
axes and $n-\operatorname{rank}(A)$ collapsed ones).

Finally, $y = U(\Sigma w)$. Since $U$ is orthogonal, it preserves all
lengths and angles (Day 17, Theorem 17.1 and Corollary) — it is a rigid
rotation/reflection of $\mathbb{R}^m$. Applying a rigid motion to an
ellipsoid produces another ellipsoid with the *same* semi-axis lengths,
merely reoriented: the standard axis directions $e_1,\dots,e_m$ become
$u_1,\dots,u_m$. So the final image $\{Ax : \|x\|=1\}$ is an ellipsoid in
$\mathbb{R}^m$ with semi-axis lengths $\sigma_1,\dots,\sigma_{\min(m,n)}$,
oriented along the directions $u_1,\dots,u_{\min(m,n)}$ — exactly the claim.

**10.** True. Since $A$ is symmetric, the Spectral Theorem gives $A =
Q\Lambda Q^T$ with $Q$ orthogonal and $\Lambda =
\operatorname{diag}(\lambda_1,\dots,\lambda_n)$; since $A$ is additionally
positive **definite** (Day 20), all $\lambda_i > 0$ (strictly, unlike the
merely semidefinite case). Then, using $A^T=A$,
$$A^TA = A\cdot A = (Q\Lambda Q^T)(Q\Lambda Q^T) = Q\Lambda(Q^TQ)\Lambda Q^T = Q\Lambda^2Q^T$$
(using $Q^TQ=I$). This is a spectral decomposition of $A^TA$ with
eigenvalues $\lambda_i^2$ and the *same* eigenvectors (columns of $Q$) as
$A$ itself. So the singular values are $\sigma_i = \sqrt{\lambda_i^2} =
\lambda_i$ (using $\lambda_i>0$, so the positive square root recovers
$\lambda_i$ exactly, not $|\lambda_i|$ trivially but genuinely the same
positive number). Finally, $A = Q\Lambda Q^T$ is already of the form
$U\Sigma V^T$ with $U=Q$, $\Sigma=\Lambda$, $V=Q$ — a valid SVD with $U=V$.
(This also explains, in hindsight, why Exercise 3's matrix — symmetric but
only positive *semi*definite, with a zero eigenvalue — needed $A^TA=A^2$
computed from scratch rather than quoting this shortcut: the shortcut's
conclusion "$\sigma_i=\lambda_i$" still happens to hold there too since all
eigenvalues of that particular $A$ are non-negative, but the "$U=V$" part
needs $u_i=v_i$ to be forced by $A$, which fails exactly at the zero
eigenvalue, matching the free-choice freedom found in Exercise 3.)

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements the SVD-from-scratch construction of Theorem 21.1
directly: eigendecompose $A^TA$, take square roots for the singular values,
and recover $U$ via $u_i = Av_i/\sigma_i$. Open
`starter_code/day21_svd_from_scratch.py` — it has one function to complete,
`svd_from_scratch`. Fill in the `TODO` (for simplicity, assume $A$ is
square and invertible, so every $\sigma_i>0$ and no basis-extension padding
is needed), then run the file directly
(`python starter_code/day21_svd_from_scratch.py`); it should print
confirmation that your singular values match `numpy.linalg.svd`, that
$U\Sigma V^T$ reconstructs $A$, and it should save a plot showing the unit
circle mapped to an ellipse by $A$.

**Hint:** `np.linalg.eigh` returns eigenvalues in *ascending* order — you
must sort descending and reorder $V$'s columns to match before taking
square roots, or your singular values and vectors will be silently
mismatched (a nonzero eigenvalue paired with the wrong eigenvector). Once
sorted, `U = (A @ V) / singular_values` divides each column of `A @ V` by
the corresponding singular value using NumPy broadcasting (division
broadcasts the length-$n$ `singular_values` array against each row of the
$n$-column matrix `A @ V`, dividing column $i$ by `singular_values[i]`) —
this is exactly $u_i = Av_i/\sigma_i$ done for all $i$ at once.

If you get stuck for more than ~10 minutes, check
`solutions/day21_svd_from_scratch.py` — but only after a real attempt.

Once your implementation passes, extend it: look at the saved plot
(`day21_svd_circle_to_ellipse.png`) and confirm by eye that the ellipse's
long and short semi-axes have lengths matching your two singular values,
and that they point along the directions of $A$'s corresponding left
singular vectors $u_1, u_2$ (overlay them with `ax.arrow` or `ax.quiver` if
you want to check this precisely rather than by eye) — this is Exercise 9's
proof, made visible.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $A = U\Sigma V^T$ | "$A$ factors as: rotate, stretch, rotate" | the singular value decomposition |
| $U$ | "the output-side rotation" | orthogonal $m\times m$; its columns $u_i$ are the left singular vectors (directions in $A$'s output space) |
| $V^T$ | "$V$-transpose — the input-side rotation" | orthogonal; its rows are $v_i$, the right singular vectors (directions in $A$'s input space) |
| $\Sigma$ | "the diagonal stretch box" | rectangular diagonal; its entries $\sigma_i$ are the stretch factors |
| $\sigma_i$ | "sigma-$i$ — the $i$-th singular value" | how much $A$ stretches the $i$-th axis; $\sigma_i = \sqrt{\lambda_i}$ |
| $A^TA$ | "$A$-transpose-$A$" | the symmetric $n\times n$ matrix whose eigenvectors give $V$ and whose eigenvalues give the $\sigma_i^2$ |
| $\langle u,v\rangle,\ \delta_{ij}$ | "the inner product; the Kronecker delta (1 if $i=j$, else 0)" | orthonormality is exactly $\langle u_i,u_j\rangle = \delta_{ij}$ |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- Every real matrix — any shape, any rank, no invertibility needed —
  factors as $A = U\Sigma V^T$: rotate/reflect the input, stretch each axis
  by a singular value, then rotate/reflect the output.
- The singular values are the square roots of the eigenvalues of $A^TA$,
  and those eigenvalues are always $\ge 0$, so the square roots are real.
- SVD is not new machinery: it is the Spectral Theorem (Day 19) applied to
  the symmetric positive semidefinite matrix $A^TA$ (Day 20), with the
  eigenvectors carried through $A$ to build the second basis.
- Geometrically, $A$ maps the unit sphere to an ellipsoid whose semi-axis
  lengths are the singular values and whose axes point along the $u_i$.
- The count of nonzero singular values is the rank of $A$; the largest is
  $A$'s operator norm; the sum of their squares is the Frobenius norm
  squared.

### Proof sketches

**Lemma 21.1 — key trick: $x^T(A^TA)x$ is secretly a squared length.**
Symmetry is one line of transpose algebra: $(A^TA)^T = A^TA$. For
semidefiniteness, feed any $x$ in and regroup: $x^T(A^TA)x = (Ax)^T(Ax) =
\|Ax\|^2$, which can never be negative. Since that holds for every $x$,
$A^TA$ fits Day 20's definition of positive semidefinite exactly. Full
version: Lemma 21.1 above.

**Theorem 21.1 — key trick: eigendecompose $A^TA$, then push its
eigenvectors through $A$.**
Because $A^TA$ is symmetric, the Spectral Theorem hands you an orthonormal
eigenbasis $v_1,\dots,v_n$ with eigenvalues $\lambda_i \ge 0$ (nonnegative
by the Lemma); these $v_i$ are the columns of $V$, and $\sigma_i =
\sqrt{\lambda_i}$. For each positive $\sigma_i$, define $u_i = Av_i/\sigma_i$;
a short inner-product computation collapses $\langle u_i,u_j\rangle$ down to
$\delta_{ij}$, so the $u_i$ are orthonormal — pad them out to a full basis
of $\mathbb{R}^m$ with Gram-Schmidt where needed, giving $U$. Assembling
$U,\Sigma,V$ and checking $AV = U\Sigma$ one column at a time (each $Av_k$
equals $\sigma_k u_k$, or $0$ when $\sigma_k=0$), then right-multiplying by
$V^T$, yields $A = U\Sigma V^T$. Full version: Theorem 21.1 above.

### If you remember only 3 things

1. $A = U\Sigma V^T$ exists for *every* real matrix: rotate ($V^T$),
   stretch by the $\sigma_i$ ($\Sigma$), rotate ($U$).
2. Build it from $A^TA$: its eigenvectors are $V$'s columns, its
   eigenvalues' square roots are the $\sigma_i$, and $u_i = Av_i/\sigma_i$.
3. $A$ turns the unit sphere into an ellipsoid with semi-axes $\sigma_i$
   pointing along $u_i$, and the number of nonzero $\sigma_i$ is the rank.

## Journal template

```
## Day 21 — SVD, part 1: existence
Key theorem in my own words: ...
What confused me: ...
```
