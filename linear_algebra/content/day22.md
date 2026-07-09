# Day 22 — SVD, Part 2: Low-Rank Approximation and the Eckart–Young Theorem

## Learning objectives

By the end of today you should be able to:
- Write the SVD of a matrix in "sum of rank-1 pieces" form and define the
  rank-$k$ truncation $A_k$ obtained by keeping only the $k$ largest terms.
- Prove the error formula $\|A - A_k\|_F = \sqrt{\sigma_{k+1}^2 + \cdots +
  \sigma_r^2}$ from scratch, including the underlying fact that the
  Frobenius norm of a sum of orthonormal rank-1 pieces is the (root) sum of
  squares of their coefficients.
- State the Eckart–Young theorem precisely (optimality of $A_k$ among all
  rank-$\le k$ matrices, in Frobenius norm) and reproduce a full proof of
  the operator-norm special case, plus the proof-sketch extension to the
  full Frobenius-norm statement.
- Compute a rank-1 (or rank-$k$) truncation by hand from a matrix's SVD, and
  verify its Frobenius error against the theorem's formula.
- Explain, precisely, why SVD truncation is *provably* the best possible
  rank-$k$ approximation — not a heuristic — and why this matters for PCA,
  compression, and denoising.

## Reference material

- Primer (10 min, no video today): before reading anything, take any photo
  or grayscale image you have on hand (or imagine one) and think about what
  "the most important structure" of that image means numerically. Today's
  theorem makes precise, and *proves*, the sense in which the first few
  singular directions of the image-as-a-matrix capture exactly that
  structure — no more, no less than what's mathematically achievable in any
  rank-$k$ approximation.
- MIT OCW 18.06 (Strang), course page:
  [ocw.mit.edu/courses/18-06-linear-algebra-spring-2010](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/)
  (syllabus: [ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/pages/syllabus](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/pages/syllabus/)).
  The specific application lecture for today is **"Change of Basis; Image
  Compression"** from the companion 18.06SC (Fall 2011) OCW site —
  [direct link](https://ocw.mit.edu/courses/18-06sc-linear-algebra-fall-2011/resources/lecture-31-change-of-basis-image-compression-1/) —
  which walks through exactly the "keep the top $k$ singular values" idea
  applied to a real image, the same experiment today's code lab runs.
  Watch it after finishing the exercises.
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson), the
  problems on singular value decomposition and matrix norms — if you don't
  have a copy, the exercises below are self-contained and sufficient for
  today.

Today builds directly on Day 21 (existence of the SVD): recall that every
$A \in \mathbb{R}^{m\times n}$ of rank $r$ can be written as
$$A = \sum_{i=1}^{r} \sigma_i u_i v_i^T,$$
where $\sigma_1 \ge \sigma_2 \ge \cdots \ge \sigma_r > 0$ are the (nonzero)
singular values, $u_1,\dots,u_r \in \mathbb{R}^m$ are orthonormal (the left
singular vectors), and $v_1,\dots,v_r \in \mathbb{R}^n$ are orthonormal (the
right singular vectors). If either that construction or the orthonormality
of the $u_i$'s and $v_i$'s feels shaky, re-derive it from your Day 21 journal
before continuing — everything below is built directly on top of this sum.

## Theory

### Definition 22.1 (Rank-$k$ truncation)

Let $A \in \mathbb{R}^{m\times n}$ have rank $r$ with SVD sum $A =
\sum_{i=1}^r \sigma_i u_i v_i^T$ as above, and let $k$ be an integer with
$0 \le k \le r$. The **rank-$k$ truncation** of $A$ is
$$A_k = \sum_{i=1}^{k} \sigma_i u_i v_i^T$$
(with the convention $A_0 = 0$, the zero matrix). Note $A_r = A$ exactly,
since the sum then includes every term.

### Lemma 22.1 (Frobenius norm of an orthonormal-sum matrix)

Let $w_1,\dots,w_p \in \mathbb{R}^m$ be orthonormal, let $z_1,\dots,z_p \in
\mathbb{R}^n$ be orthonormal, and let $c_1,\dots,c_p \in \mathbb{R}$ be
scalars. Let $X = \sum_{i=1}^p c_i w_i z_i^T \in \mathbb{R}^{m\times n}$.
Then
$$\|X\|_F^2 = \sum_{i=1}^p c_i^2.$$

**Proof.** Recall $\|X\|_F^2 = \sum_{i,j} X_{ij}^2 = \operatorname{trace}(X^TX)$
(Exercise 3 asks you to verify this identity from the definitions of
Frobenius norm, matrix transpose, and trace; we use it here as a known
fact). Compute $X^TX$:
$$X^TX = \left(\sum_{i=1}^p c_i z_i w_i^T\right)\left(\sum_{j=1}^p c_j w_j z_j^T\right) = \sum_{i=1}^p\sum_{j=1}^p c_ic_j\, z_i (w_i^Tw_j)\, z_j^T.$$
Since the $w_i$ are orthonormal, $w_i^Tw_j = \delta_{ij}$ (Kronecker delta:
$1$ if $i=j$, else $0$), so every term with $i \ne j$ vanishes, leaving
$$X^TX = \sum_{i=1}^p c_i^2\, z_iz_i^T.$$
Taking the trace and using linearity of trace,
$$\operatorname{trace}(X^TX) = \sum_{i=1}^p c_i^2\, \operatorname{trace}(z_iz_i^T) = \sum_{i=1}^p c_i^2\, z_i^Tz_i = \sum_{i=1}^p c_i^2\|z_i\|^2 = \sum_{i=1}^p c_i^2,$$
where $\operatorname{trace}(z_iz_i^T) = z_i^Tz_i$ is a standard identity
(the trace of a rank-1 matrix $zz^T$ equals $z^Tz$), and $\|z_i\|^2=1$
since the $z_i$ are orthonormal (in particular unit vectors). Combining,
$\|X\|_F^2 = \operatorname{trace}(X^TX) = \sum_{i=1}^p c_i^2$. $\blacksquare$

### Theorem 22.1 (Error formula for the rank-$k$ truncation)

With $A, r, A_k$ as in Definition 22.1 and $0 \le k \le r$,
$$\|A - A_k\|_F = \sqrt{\sigma_{k+1}^2 + \sigma_{k+2}^2 + \cdots + \sigma_r^2}$$
(interpreting the right side as $0$ when $k=r$, i.e. an empty sum).

**Proof.** By definition,
$$A - A_k = \sum_{i=1}^r \sigma_iu_iv_i^T - \sum_{i=1}^k \sigma_iu_iv_i^T = \sum_{i=k+1}^r \sigma_i u_iv_i^T.$$
This is exactly the form handled by Lemma 22.1: the vectors
$u_{k+1},\dots,u_r$ are orthonormal (they're a subset of the full orthonormal
set $u_1,\dots,u_r$ from the SVD), likewise $v_{k+1},\dots,v_r$ are
orthonormal, and the coefficients are $\sigma_{k+1},\dots,\sigma_r$. Applying
Lemma 22.1 with $p = r-k$ (reindexed to start from $1$, which changes
nothing about the sum of squares),
$$\|A-A_k\|_F^2 = \sum_{i=k+1}^r \sigma_i^2.$$
Taking square roots (both sides are non-negative) gives
$\|A-A_k\|_F = \sqrt{\sum_{i=k+1}^r \sigma_i^2}$. $\blacksquare$

This is a complete proof — nothing here is a sketch.

### Theorem 22.2 (Eckart–Young theorem)

Let $A \in \mathbb{R}^{m\times n}$ have rank $r$ and singular values
$\sigma_1 \ge \cdots \ge \sigma_r > 0$, and fix $k$ with $0 \le k < r$. Among
**all** matrices $B \in \mathbb{R}^{m\times n}$ with $\operatorname{rank}(B)
\le k$,
$$\|A - A_k\|_F = \min_{\operatorname{rank}(B) \le k} \|A - B\|_F = \sqrt{\sigma_{k+1}^2 + \cdots + \sigma_r^2},$$
i.e. the rank-$k$ truncation $A_k$ is a **minimizer**: no rank-$\le k$
matrix approximates $A$ more closely in Frobenius norm than $A_k$ does.

The value of $\|A-A_k\|_F$ is Theorem 22.1, already proved completely. What
remains — and is genuinely the hard part of this theorem — is
**optimality**: showing no *other* rank-$\le k$ matrix $B$ can do strictly
better. The proof below is presented in two clearly labeled stages: a
**complete, elementary proof** of the operator-norm version of this
statement, followed by a **proof sketch** (not fully re-derived here) that
upgrades this to the full Frobenius-norm statement above.

For a matrix $M$, define its **operator norm** $\|M\|_{\text{op}} =
\max_{\|x\|=1} \|Mx\|$ (the largest amount $M$ can stretch a unit vector).
It is a standard fact — and one you can check directly from the SVD sum —
that $\|M\|_{\text{op}}$ equals $M$'s largest singular value.

**Stage 1 (complete proof): $\|A-B\|_{\text{op}} \ge \sigma_{k+1}$ for every $B$ with $\operatorname{rank}(B)\le k$.**

Let $B \in \mathbb{R}^{m\times n}$ with $\operatorname{rank}(B) \le k$. By the
rank-nullity theorem (Day 4), $\dim(\ker B) = n - \operatorname{rank}(B) \ge
n-k$. Consider the subspace $V_{k+1} = \operatorname{span}(v_1,\dots,v_{k+1})
\subseteq \mathbb{R}^n$, which has dimension $k+1$ (the $v_i$ are orthonormal,
hence linearly independent). Both $\ker B$ and $V_{k+1}$ are subspaces of
$\mathbb{R}^n$, so
$$\dim(\ker B + V_{k+1}) = \dim(\ker B) + \dim(V_{k+1}) - \dim(\ker B \cap V_{k+1}) \le n,$$
which rearranges to
$$\dim(\ker B \cap V_{k+1}) \ge \dim(\ker B) + \dim(V_{k+1}) - n \ge (n-k) + (k+1) - n = 1.$$
So $\ker B \cap V_{k+1}$ contains a nonzero vector; pick one and normalize it
to a unit vector $x$ with $\|x\|=1$, $x \in \ker B$, and $x \in V_{k+1}$.

Since $x \in V_{k+1} = \operatorname{span}(v_1,\dots,v_{k+1})$, write $x =
\sum_{i=1}^{k+1} c_i v_i$; by orthonormality of $v_1,\dots,v_{k+1}$ (Parseval),
$\sum_{i=1}^{k+1} c_i^2 = \|x\|^2 = 1$. Now compute $Ax$ using the SVD sum: for
$j > k+1$, $v_j^Tx = \sum_{i=1}^{k+1}c_i v_j^Tv_i = 0$ (orthogonality), and
for $i \le k+1$, $v_i^Tx = c_i$, so
$$Ax = \sum_{j=1}^{r}\sigma_j u_j(v_j^Tx) = \sum_{i=1}^{k+1} \sigma_i c_i u_i.$$
By orthonormality of $u_1,\dots,u_{k+1}$, $\|Ax\|^2 = \sum_{i=1}^{k+1}
\sigma_i^2 c_i^2$. Since $\sigma_1 \ge \cdots \ge \sigma_{k+1}$, every term has
$\sigma_i^2 \ge \sigma_{k+1}^2$ for $i \le k+1$, so
$$\|Ax\|^2 \ge \sigma_{k+1}^2 \sum_{i=1}^{k+1} c_i^2 = \sigma_{k+1}^2,$$
i.e. $\|Ax\| \ge \sigma_{k+1}$.

Finally, since $x \in \ker B$, $Bx = 0$, so $(A-B)x = Ax$, giving
$\|(A-B)x\| = \|Ax\| \ge \sigma_{k+1}$. Since $\|x\|=1$ and $\|A-B\|_{\text{op}}$
is the *maximum* of $\|(A-B)x\|$ over all unit vectors $x$, in particular
$$\|A-B\|_{\text{op}} \ge \|(A-B)x\| \ge \sigma_{k+1}.$$
This holds for every $B$ with $\operatorname{rank}(B)\le k$, so
$\min_{\operatorname{rank}(B)\le k}\|A-B\|_{\text{op}} \ge \sigma_{k+1} =
\|A-A_k\|_{\text{op}}$ (the last equality because $A-A_k = \sum_{i>k}\sigma_iu_iv_i^T$
has largest singular value $\sigma_{k+1}$, its first remaining term). Combined
with the trivial fact that $A_k$ itself achieves this value, $A_k$ minimizes
$\|A-B\|_{\text{op}}$ over rank-$\le k$ matrices $B$. $\blacksquare$ (operator-norm case, fully proved)

**Stage 2 (proof sketch): extending Stage 1 to the Frobenius norm.**

Stage 1 proves optimality when "distance" is measured by the operator norm.
The theorem as stated uses the *Frobenius* norm, which is a strictly stronger
claim ($\|M\|_{\text{op}} \le \|M\|_F$ always, so a Frobenius-norm bound is
harder to establish). The idea generalizes, but the last step below relies on
a fact — the min-max (Courant–Fischer) characterization of singular values —
that is stated without independent proof here; treat this stage as a sketch,
not a complete derivation.

*Generalizing Stage 1's construction.* Repeat the argument of Stage 1, but
with $V_{k+i} = \operatorname{span}(v_1,\dots,v_{k+i})$ in place of $V_{k+1}$,
for each $i = 1,\dots,r-k$. The identical dimension count gives
$$\dim(\ker B \cap V_{k+i}) \ge (n-k) + (k+i) - n = i,$$
so $\ker B \cap V_{k+i}$ contains an $i$-dimensional subspace $W_i$. Exactly
as before, every unit vector $x \in W_i$ satisfies $Bx=0$ and (by the same
computation, now with $k+i$ terms instead of $k+1$)
$$\|(A-B)x\| = \|Ax\| \ge \sigma_{k+i}.$$
So we have exhibited an $i$-dimensional subspace $W_i$ on which $A-B$ never
shrinks a unit vector below length $\sigma_{k+i}$.

*The cited fact.* The **min-max (Courant–Fischer) characterization of
singular values** states that the $i$-th singular value of any matrix $M$
satisfies
$$\sigma_i(M) = \max_{\dim(W)=i} \ \min_{x \in W, \|x\|=1} \|Mx\|$$
(the maximum ranging over all $i$-dimensional subspaces $W$). We use only the
easy consequence of this: since $\sigma_i(M)$ is defined as the *maximum*, over
**all** $i$-dimensional subspaces, of the minimum stretch on that subspace, it
is in particular at least as large as the minimum stretch on *any one*
particular $i$-dimensional subspace. Applying this to $M = A-B$ and our
specific $W_i$,
$$\sigma_i(A-B) \ge \min_{x \in W_i, \|x\|=1} \|(A-B)x\| \ge \sigma_{k+i}(A).$$
(Proving the min-max characterization itself requires relating $\sigma_i(M)$
to the $i$-th eigenvalue of the symmetric matrix $M^TM$ and invoking the
Courant–Fischer theorem for symmetric eigenvalues — a real theorem, not
proved here; this is exactly the point at which this stage is a sketch
rather than a complete proof.)

*Finishing.* Summing squares over $i=1,\dots,r-k$ (and noting all other
singular values of $A-B$, if any, only add non-negative terms),
$$\|A-B\|_F^2 = \sum_i \sigma_i(A-B)^2 \ge \sum_{i=1}^{r-k}\sigma_{k+i}(A)^2 = \sum_{j=k+1}^r \sigma_j(A)^2 = \|A-A_k\|_F^2$$
(the last equality is Theorem 22.1). Taking square roots, $\|A-B\|_F \ge
\|A-A_k\|_F$ for every rank-$\le k$ matrix $B$ — the full Eckart–Young
statement. $\blacksquare$ (sketch — relies on the cited min-max fact)

## Worked example

**Matrix:** $A = \begin{pmatrix} 1 & 0 \\ 0 & 1 \\ 1 & 1\end{pmatrix}$
(rank $r=2$).

**Computing the SVD by hand.** Form $A^TA = \begin{pmatrix}1&0&1\\0&1&1\end{pmatrix}\begin{pmatrix}1&0\\0&1\\1&1\end{pmatrix} = \begin{pmatrix}2&1\\1&2\end{pmatrix}$
(this is Day 19/Day 21 territory: the right singular vectors and squared
singular values come from the eigendecomposition of $A^TA$). Its
characteristic polynomial is $(2-\lambda)^2 - 1 = \lambda^2-4\lambda+3 =
(\lambda-3)(\lambda-1)$, giving eigenvalues $\lambda_1=3, \lambda_2=1$, so
$$\sigma_1 = \sqrt3, \qquad \sigma_2 = 1.$$
For $\lambda_1=3$: $(2-3)x+y=0 \Rightarrow y=x$, unit eigenvector
$v_1 = \frac{1}{\sqrt2}(1,1)$. For $\lambda_2=1$: $(2-1)x+y=0 \Rightarrow
y=-x$, unit eigenvector $v_2 = \frac1{\sqrt2}(1,-1)$. Recover the left
singular vectors via $u_i = Av_i/\sigma_i$:
$$u_1 = \frac{1}{\sqrt3}A v_1 = \frac1{\sqrt3}\cdot\frac1{\sqrt2}(1,1,2) = \frac1{\sqrt6}(1,1,2), \qquad u_2 = \frac{1}{1}Av_2 = \frac1{\sqrt2}(1,-1,0).$$
(Direct check: $\|u_1\|^2 = (1+1+4)/6=1$, $\|u_2\|^2=(1+1)/2=1$,
$u_1^Tu_2 = (1-1+0)/\sqrt{12}=0$ — orthonormal, as required.)

**Rank-1 truncation.**
$$A_1 = \sigma_1u_1v_1^T = \sqrt3\cdot\frac1{\sqrt6}(1,1,2)\cdot\frac1{\sqrt2}(1,1)^T = \frac12\begin{pmatrix}1&1\\1&1\\2&2\end{pmatrix} = \begin{pmatrix}0.5&0.5\\0.5&0.5\\1&1\end{pmatrix}.$$
(Note $A_1$ has identical columns, so $\operatorname{rank}(A_1)=1$, as it
must.)

**Direct computation of $\|A-A_1\|_F$.**
$$A - A_1 = \begin{pmatrix}1&0\\0&1\\1&1\end{pmatrix} - \begin{pmatrix}0.5&0.5\\0.5&0.5\\1&1\end{pmatrix} = \begin{pmatrix}0.5&-0.5\\-0.5&0.5\\0&0\end{pmatrix}.$$
Summing squared entries: $0.25+0.25+0.25+0.25+0+0 = 1$, so
$\|A-A_1\|_F = \sqrt1 = 1$.

**Verifying against Theorem 22.1.** The formula predicts $\|A-A_1\|_F =
\sqrt{\sigma_2^2} = \sqrt{1^2} = 1$. This matches the direct computation
exactly. (As a bonus check of Lemma 22.1's Pythagorean structure: $\|A\|_F^2
= 1+0+0+1+1+1 = 4$, and $\sigma_1^2+\sigma_2^2 = 3+1=4$ — matches; also
$\|A_1\|_F^2 = 4\cdot0.25+2\cdot1 = 3 = \sigma_1^2$, and $3+1=4=\|A\|_F^2$,
confirming $\|A\|_F^2 = \|A_1\|_F^2+\|A-A_1\|_F^2$, used again in Exercise 2.)
These numbers were confirmed with `numpy.linalg.svd` before this file was
finalized.

## Unconventional edge

The trap: treating "throw away the small singular values" as a plausible
heuristic — something that *sounds* reasonable, like rounding or dropping
small coefficients, but that you'd only trust after checking it empirically
on your data. Eckart–Young says something much stronger: for *any* matrix
$A$ and *any* target rank $k$, the SVD truncation $A_k$ is not merely a
*good* rank-$k$ approximation, it is *provably the best possible one* in
Frobenius norm, full stop, no exceptions, no data-dependent luck involved —
every other rank-$\le k$ matrix, however cleverly chosen, is at least as far
from $A$. This is the entire theoretical justification for why PCA (Day 23),
image/data compression, and SVD-based noise reduction aren't "good enough"
engineering hacks that happen to work on typical inputs — they are, for the
specific objective of minimizing Frobenius-norm reconstruction error at a
fixed rank budget, mathematically optimal. When Day 23 derives PCA as
"project onto the top $k$ principal directions," the reason that's the
*right* choice rather than *a* choice is exactly this theorem.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1, 2, 6, 8 are computational; 3, 4, 5, 7 are proof/conceptual.

1. Let $B = \operatorname{diag}(5,3,1) \in \mathbb{R}^{3\times3}$ (so its SVD
   sum uses $u_i=v_i=e_i$, $\sigma_1=5,\sigma_2=3,\sigma_3=1$). Compute $B_1$
   and $B_2$, and compute $\|B-B_1\|_F$ and $\|B-B_2\|_F$ both directly and
   via Theorem 22.1's formula.
2. Using the Worked Example's $A$ and its rank-1 truncation $A_1$, verify
   numerically that $\|A\|_F^2 = \|A_1\|_F^2 + \|A-A_1\|_F^2$, and explain in
   a sentence or two *why* this Pythagorean-style identity holds in general
   (hint: revisit how Lemma 22.1 treats $A$, $A_k$, and $A-A_k$).
3. Prove $\|X\|_F^2 = \sum_{i,j}X_{ij}^2 = \operatorname{trace}(X^TX)$
   directly from the definitions of Frobenius norm, matrix transpose, and
   trace (matrix multiplication and trace as sum of diagonal entries).
4. Fill in a step used inside Lemma 22.1's proof: let $w_1,\dots,w_p \in
   \mathbb{R}^m$ be orthonormal and $z_1,\dots,z_p \in \mathbb{R}^n$
   arbitrary, and let $X=\sum_i c_iw_iz_i^T$. Show directly, by expanding
   the product and using $w_i^Tw_j=\delta_{ij}$, that $X^TX =
   \sum_i c_i^2 z_iz_i^T$ (i.e. that all cross terms $i\ne j$ vanish).
5. Prove: if $\sigma_k > 0$, then $\operatorname{rank}(A_k) = k$ exactly
   (not just $\le k$).
6. A matrix has singular values $\sigma = (10, 8, 4, 2, 1, 0.5, 0.2)$
   (decreasing). Define its "energy" as $\sum_i \sigma_i^2$. What is the
   smallest $k$ such that $A_k$ captures at least $99\%$ of the total
   energy, i.e. $\sum_{i=1}^k \sigma_i^2 \ge 0.99\sum_i\sigma_i^2$?
7. True or False, with justification: "Since Eckart–Young shows that
   keeping the largest singular values gives the best low-rank
   approximation, it must also be true that zeroing out the numerically
   smallest *entries* of $A$ (setting small $|A_{ij}|$ to $0$) gives an
   equally good — or equally 'optimal' — approximation." Give a concrete
   example illustrating your answer.
8. What is $A_k$ when $k \ge r$ (using $r=\operatorname{rank}(A)$)? Using
   Theorem 22.1's formula, show $\|A-A_k\|_F = 0$ in this case, and confirm
   this directly with the Worked Example's $A$ at $k=2=r$.

## Solutions

**1.** $B_1 = \operatorname{diag}(5,0,0)$, $B_2=\operatorname{diag}(5,3,0)$.
Directly: $B-B_1 = \operatorname{diag}(0,3,1)$, so $\|B-B_1\|_F =
\sqrt{0+9+1}=\sqrt{10}$. $B-B_2=\operatorname{diag}(0,0,1)$, so
$\|B-B_2\|_F=\sqrt1=1$. Via the formula: $\|B-B_1\|_F =
\sqrt{\sigma_2^2+\sigma_3^2}=\sqrt{9+1}=\sqrt{10}$ ✓;
$\|B-B_2\|_F=\sqrt{\sigma_3^2}=\sqrt1=1$ ✓. Both match.

**2.** From the Worked Example: $\|A\|_F^2=4$, $\|A_1\|_F^2=3$,
$\|A-A_1\|_F^2=1$, and indeed $3+1=4$. This holds in general because
$A = A_k + (A-A_k)$, and Lemma 22.1 shows $\|A\|_F^2 = \sum_{i=1}^r
\sigma_i^2$ (all $r$ terms), $\|A_k\|_F^2 = \sum_{i=1}^k\sigma_i^2$ (the
first $k$ terms), and $\|A-A_k\|_F^2 = \sum_{i=k+1}^r\sigma_i^2$ (the
remaining terms) — the total sum of squares simply splits into a "kept"
part and a "discarded" part, so $\|A_k\|_F^2 + \|A-A_k\|_F^2 =
\sum_{i=1}^k\sigma_i^2 + \sum_{i=k+1}^r\sigma_i^2 = \sum_{i=1}^r\sigma_i^2 =
\|A\|_F^2$ exactly, for every valid $k$.

**3.** By definition, the Frobenius norm is $\|X\|_F = \sqrt{\sum_{i,j}
X_{ij}^2}$, so $\|X\|_F^2 = \sum_{i,j}X_{ij}^2$ directly from the
definition — nothing to prove there beyond squaring. For the trace
identity: $(X^TX)_{jj} = \sum_i (X^T)_{ji}X_{ij} = \sum_i X_{ij}X_{ij} =
\sum_i X_{ij}^2$ (using $(X^T)_{ji}=X_{ij}$ and the definition of matrix
multiplication, entry $(j,j)$ of $X^TX$ is row $j$ of $X^T$ dotted with
column $j$ of $X$). Summing over the diagonal,
$$\operatorname{trace}(X^TX) = \sum_j (X^TX)_{jj} = \sum_j\sum_i X_{ij}^2 = \sum_{i,j}X_{ij}^2.$$
Combining both computations, $\|X\|_F^2 = \sum_{i,j}X_{ij}^2 =
\operatorname{trace}(X^TX)$.

**4.** $X^TX = \left(\sum_i c_iz_iw_i^T\right)\left(\sum_j c_jw_jz_j^T\right)
= \sum_{i,j} c_ic_j\, z_i(w_i^Tw_j)z_j^T$ by distributing the product over
both sums (matrix multiplication is bilinear) and regrouping the scalar
$w_i^Tw_j$ out of the product $z_iw_i^Tw_jz_j^T = z_i(w_i^Tw_j)z_j^T$ (since
$w_i^Tw_j$ is a scalar, it commutes past the vectors). Since $w_i^Tw_j =
\delta_{ij}$ by orthonormality, the term $c_ic_j\,\delta_{ij}\,z_iz_j^T$ is
$c_i^2z_iz_i^T$ when $i=j$ and $0$ when $i\ne j$. Summing over all $i,j$,
only the $i=j$ terms survive: $X^TX = \sum_i c_i^2 z_iz_i^T$.

**5.** For any $x \in \mathbb{R}^n$, $A_kx = \sum_{i=1}^k\sigma_i(v_i^Tx)u_i$,
which is a linear combination of $u_1,\dots,u_k$ alone; so the column space
(range) of $A_k$ is contained in $\operatorname{span}(u_1,\dots,u_k)$, giving
$\operatorname{rank}(A_k) \le k$. Conversely, for each $j=1,\dots,k$,
$A_kv_j = \sum_{i=1}^k \sigma_i(v_i^Tv_j)u_i = \sigma_ju_j$ (using
orthonormality $v_i^Tv_j=\delta_{ij}$). Since $\sigma_j>0$ (given, as
$j\le k$ and $\sigma_k>0$ with $\sigma_1\ge\cdots\ge\sigma_k$), this shows
$u_j = \frac{1}{\sigma_j}A_kv_j$ is itself in the column space of $A_k$, for
every $j=1,\dots,k$. So $\operatorname{span}(u_1,\dots,u_k) \subseteq$
column space of $A_k$ too. Combining both inclusions, the column space of
$A_k$ equals $\operatorname{span}(u_1,\dots,u_k)$ exactly, which has
dimension $k$ (the $u_i$ are orthonormal, hence linearly independent). So
$\operatorname{rank}(A_k)=k$ exactly.

**6.** Total energy: $10^2+8^2+4^2+2^2+1^2+0.5^2+0.2^2 = 100+64+16+4+1+0.25+0.04
= 185.29$. Cumulative sums: $k=1: 100$ ($100/185.29\approx53.97\%$); $k=2:
164$ ($\approx88.51\%$); $k=3: 180$ ($\approx97.14\%$); $k=4: 184$
($\approx99.30\%$). Since $k=3$ falls short of $99\%$ but $k=4$ exceeds it,
the smallest $k$ achieving $99\%$ energy is $\boxed{k=4}$.

**7.** False. Entrywise thresholding operates on individual coordinates of
$A$ in the standard basis and has no relationship to $A$'s singular
directions — it neither reliably reduces rank nor, when it does change
rank, does so in the Frobenius-optimal way that Eckart–Young guarantees for
SVD truncation. Concrete example: let $A = \begin{pmatrix}1&0.01\\0.01&1
\end{pmatrix}$. The entries $0.01$ are numerically small, so entrywise
thresholding (zeroing anything below, say, $0.05$) produces $I_2$ —
which still has rank $2$ (full rank!), not a lower-rank matrix at all,
even though $0.01$ "looks small." The notion of "small" that matters for
approximation is smallness of a *singular value* (a direction in which $A$
barely stretches space), not smallness of an individual matrix *entry* —
these are generally unrelated, and only the SVD-based notion has an
optimality guarantee behind it (Theorem 22.2).

**8.** When $k \ge r$, $A_k = \sum_{i=1}^{\min(k,r)}\sigma_iu_iv_i^T =
\sum_{i=1}^r\sigma_iu_iv_i^T = A$ (there are no singular values with index
between $r+1$ and $k$ to add — the SVD sum only ever has $r$ nonzero terms).
So $A - A_k = 0$. Theorem 22.1's formula agrees: $\|A-A_k\|_F =
\sqrt{\sum_{i=k+1}^r\sigma_i^2}$ is an empty sum (since $k+1 > r$), which is
$0$ by convention, giving $\|A-A_k\|_F=0$. Concretely, for the Worked
Example's $A$ (with $r=2$) at $k=2$: $A_2 = \sigma_1u_1v_1^T+\sigma_2u_2v_2^T
= A$ exactly (this is just the full SVD sum reconstructing $A$, as in Day
21), so $A-A_2$ is the zero matrix and $\|A-A_2\|_F=0$, matching
$\sqrt{\text{(empty sum)}}=0$.

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab applies rank-$k$ truncation to a real grayscale image and
verifies the Eckart–Young error formula numerically at several values of
$k$. Open `starter_code/day22_svd_low_rank.py` — it has one function to
complete, `truncated_svd_approx`. Fill in the `TODO`, then run the file
directly (`python starter_code/day22_svd_low_rank.py`); it should print
`All checks passed!` along with the Frobenius error at each truncation rank,
and save a side-by-side comparison image to
`starter_code/day22_svd_compression.png`.

**Hint:** with `U, s, Vt = np.linalg.svd(image, full_matrices=False)`, the
rank-$k$ truncation is $A_k = U[:, :k] \,@\, \operatorname{diag}(s[:k])
\,@\, Vt[:k, :]$ — exactly Definition 22.1's sum, just written as a matrix
product instead of a sum of outer products (they're the same object: column
$i$ of $U[:,:k]$ times row $i$ of $\operatorname{diag}(s[:k])@Vt[:k,:]$
reconstructs $\sigma_iu_iv_i^T$). The file already asserts that the
computed Frobenius error matches `np.sqrt(np.sum(s[k:] ** 2))` — that
assertion *is* Theorem 22.1, checked numerically at $k=5,20,50,100$ on a
$512\times512$ image.

If you get stuck for more than ~10 minutes, check
`solutions/day22_svd_low_rank.py` — but only after a real attempt.

Once your implementation passes, extend it: compute and plot the "energy
captured," $\sum_{i\le k}\sigma_i^2 / \sum_i \sigma_i^2$, as a function of
$k$ for this image (reusing Exercise 6's idea, now on real singular values
instead of a hypothetical sequence), and find the smallest $k$ that captures
99% of the image's energy. Compare that $k$ to $512$ (the image's full
rank) to see just how much compression Eckart–Young-optimal truncation
buys you here.

## Journal template

```
## Day 22 — SVD, part 2: low-rank approximation
Key theorem in my own words: ...
What confused me: ...
```
