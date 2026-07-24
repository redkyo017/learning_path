# Day 23 — SVD to PCA: Deriving Principal Component Analysis from Scratch

This is the capstone of Week 4 (Days 19–23: Spectral Theorem, quadratic
forms, SVD, and now PCA). Nothing new is assumed beyond what Days 19 and 21
already proved — today's entire job is to show that "Principal Component
Analysis," a name that sounds like a distinct machine-learning algorithm, is
*nothing but* the Spectral Theorem applied to one specific matrix (the
covariance matrix), with the eigenvectors relabeled "principal components."
If Days 19–22 are solid, today should feel less like learning something new
and more like watching several things you already know snap together.

## Learning objectives

By the end of today you should be able to:
- Derive, from the definition of sample variance alone, why the variance of
  a 1-D projection of centered data equals $w^TCw$ for the covariance matrix
  $C$.
- Prove that the sample covariance matrix is symmetric and positive
  semidefinite.
- Prove (via a Lagrange-multiplier argument built on the Spectral Theorem,
  Day 19) that the unit vector maximizing $w^TCw$ is the top eigenvector of
  $C$, and that the maximum value achieved is the top eigenvalue.
- Explain why the eigenvectors of $C$ are exactly the right singular
  vectors of the (centered) data matrix $X$, using Day 21's SVD.
- Define the principal components of a dataset precisely, in terms of
  eigenvectors/singular vectors, rather than as a black-box procedure.
- Compute principal components by hand for small 2D datasets, and compute
  explained variance ratios to decide how many components to keep.

## Reference material

- Primer (10–15 min, no video for the derivation itself): before reading
  anything, sketch by hand a scatter of 8–10 points on paper with visible
  directional spread (e.g. a rough diagonal cloud, not a circular blob).
  Draw, by eye, the single direction along which the points are most spread
  out, and a second direction, perpendicular to the first, along which
  they're most tightly clustered. That pair of directions — one of maximum
  spread, one of minimum spread, at right angles to each other — is exactly
  what today's theorem proves must exist and pins down algebraically as
  eigenvectors of the covariance matrix. There is no dedicated video for
  this specific derivation, but 3Blue1Brown's channel
  ([youtube.com/@3blue1brown](https://www.youtube.com/@3blue1brown)) has
  general content on PCA/covariance if you want an optional second visual
  pass after today's proof, not before.
- Primary theory: none dedicated — today is a synthesis day. The "theory
  text" for today is your own Day 19 (Spectral Theorem) and Day 21 (SVD)
  material; a 5-minute skim of those two journal entries before starting is
  worth it, since every step below cites one of them directly.
- Application-flavored background (optional): the MIT OCW 18.06 course page
  — [ocw.mit.edu/courses/18-06-linear-algebra-spring-2010](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/)
  — has later lectures that touch on PCA-adjacent material (covariance,
  variance maximization) if you want a second exposition of the same ideas
  from a different instructor; not required to complete today's work, which
  is self-contained below.

## Theory

### Setup

Let $X \in \mathbb{R}^{n \times p}$ be a data matrix: $n$ samples (rows), $p$
features (columns), with each **column already centered** — i.e. each
column of $X$ has mean $0$. (If you started from raw data $\tilde X$, you
get here by $X = \tilde X - \mathbf{1}\bar x^T$, subtracting each column's
mean from itself; Exercise 4 below examines what breaks if you skip this
step.)

For a unit vector $w \in \mathbb{R}^p$ ($\|w\| = 1$), think of $w$ as a
*direction* in feature space. The **projections of the data onto direction
$w$** are the $n$ numbers $Xw \in \mathbb{R}^n$ — the $i$-th entry, $(Xw)_i =
x_i^Tw$ (where $x_i^T$ is the $i$-th row of $X$), is the signed length of
sample $i$'s shadow on the line through the origin spanned by $w$.

### Theorem 23.1 (Variance of a projection)

Let $X \in \mathbb{R}^{n\times p}$ have centered columns, and let $w \in
\mathbb{R}^p$ be a unit vector. Then the sample variance of the projections
$Xw$ is
$$\operatorname{Var}(Xw) = w^TCw, \qquad \text{where } C := \frac{1}{n-1}X^TX.$$

**Proof.** *Step 1: $Xw$ is itself mean-zero.* Write $X = [x_{(1)} \mid
\cdots \mid x_{(p)}]$ in terms of its columns (each $x_{(j)} \in
\mathbb{R}^n$, mean $0$ by assumption). Then
$$Xw = \sum_{j=1}^p w_j\, x_{(j)},$$
a linear combination of mean-zero vectors. The sample mean is a linear
functional (mean of $\sum_j w_j x_{(j)}$ is $\sum_j w_j \cdot \text{mean}(x_{(j)}) = \sum_j w_j \cdot 0 = 0$), so $Xw$ is mean-zero too. (Equivalently:
letting $\mathbf 1 \in \mathbb{R}^n$ be the all-ones vector, each column
summing to zero means $\mathbf 1^TX = 0^T$, so $\mathbf 1^T(Xw) =
(\mathbf 1^TX)w = 0$.)

*Step 2: the variance formula for a mean-zero vector.* For any mean-zero
vector $v \in \mathbb{R}^n$ (sample mean $\bar v = 0$), the sample variance
is by definition
$$\operatorname{Var}(v) = \frac{1}{n-1}\sum_{i=1}^n (v_i - \bar v)^2 = \frac{1}{n-1}\sum_{i=1}^n v_i^2 = \frac{1}{n-1}\|v\|^2.$$

*Step 3: substitute $v = Xw$.* By Step 1, $Xw$ is mean-zero, so Step 2
applies with $v = Xw$:
$$\operatorname{Var}(Xw) = \frac{1}{n-1}\|Xw\|^2.$$
Expand the squared norm as an inner product and use $(AB)^T = B^TA^T$:
$$\|Xw\|^2 = (Xw)^T(Xw) = w^TX^TXw.$$
Combining,
$$\operatorname{Var}(Xw) = w^T\left(\frac{1}{n-1}X^TX\right)w = w^TCw. \qquad \blacksquare$$

### Definition 23.1 (Sample covariance matrix)

For centered $X \in \mathbb{R}^{n\times p}$, the matrix
$$C = \frac{1}{n-1}X^TX \in \mathbb{R}^{p\times p}$$
is the **sample covariance matrix** of the data. Its $(i,j)$ entry is
$C_{ij} = \frac{1}{n-1}\sum_{k=1}^n X_{ki}X_{kj}$, which (since both columns
are centered) is exactly the sample covariance between feature $i$ and
feature $j$; in particular $C_{ii} = \operatorname{Var}(x_{(i)})$, the
variance of feature $i$ alone.

### Theorem 23.2 ($C$ is symmetric positive semidefinite)

$C = \frac{1}{n-1}X^TX$ is symmetric, and $w^TCw \ge 0$ for **every** $w \in
\mathbb{R}^p$ (not just unit vectors).

**Proof.** *Symmetric.* $C^T = \left(\frac{1}{n-1}X^TX\right)^T =
\frac{1}{n-1}(X^TX)^T = \frac{1}{n-1}X^T(X^T)^T = \frac{1}{n-1}X^TX = C$,
using $(AB)^T = B^TA^T$ and $(X^T)^T = X$.

*Positive semidefinite.* Nothing in the algebra of Theorem 23.1's proof
actually used $\|w\|=1$ — the identity $w^TCw = \frac{1}{n-1}\|Xw\|^2$ holds
for *any* $w \in \mathbb{R}^p$ (the unit-length assumption was only needed to
*interpret* $Xw$ as "the projection onto a direction"; the algebra itself is
scale-free). Since $\|Xw\|^2 \ge 0$ always (a sum of squares) and
$\frac{1}{n-1} > 0$ (assuming $n \ge 2$), we get $w^TCw = \frac{1}{n-1}
\|Xw\|^2 \ge 0$ for every $w \in \mathbb{R}^p$. This is exactly the
definition of positive semidefinite. $\blacksquare$

Symmetric + PSD is exactly the hypothesis the Spectral Theorem (Day 19)
needs: $C$ has an orthonormal eigenbasis $q_1, \dots, q_p$ with **real,
non-negative** eigenvalues $\lambda_1 \ge \lambda_2 \ge \cdots \ge \lambda_p
\ge 0$ (non-negativity follows because if $Cq_i = \lambda_i q_i$ with $q_i$
a unit eigenvector, then $\lambda_i = q_i^TCq_i \ge 0$ by the PSD property
just proved).

### Theorem 23.3 (The variance-maximizing direction is the top eigenvector)

Let $C \in \mathbb{R}^{p\times p}$ be symmetric with eigenvalues $\lambda_1
\ge \lambda_2 \ge \cdots \ge \lambda_p$ and a corresponding orthonormal
eigenbasis $q_1, \dots, q_p$ (Spectral Theorem, Day 19). Then:
$$\max_{\|w\|=1} w^TCw = \lambda_1,$$
and the maximum is attained at $w = q_1$ (any unit eigenvector for
$\lambda_1$).

**Proof.**

*Step 1 (a maximizer exists).* The unit sphere $S^{p-1} = \{w \in
\mathbb{R}^p : \|w\| = 1\}$ is closed and bounded in $\mathbb{R}^p$, hence
compact. The function $f(w) = w^TCw$ is a polynomial in the entries of $w$,
hence continuous. By the Extreme Value Theorem, $f$ attains a maximum at
some $w^* \in S^{p-1}$.

*Step 2 (necessary condition at the maximizer — Lagrange multipliers).*
Maximize $f(w) = w^TCw$ subject to $g(w) = \|w\|^2 - 1 = 0$. Form the
Lagrangian $L(w,\mu) = w^TCw - \mu(\|w\|^2 - 1)$. Since $\nabla g(w) = 2w
\ne 0$ everywhere on $S^{p-1}$, the constraint qualification holds
everywhere, so at the maximizer $w^*$ there exists a scalar $\mu$ with
$\nabla_w L(w^*,\mu) = 0$.

Compute the two gradients. Writing $w^TCw = \sum_{i,j} C_{ij}w_iw_j$, the
partial derivative with respect to $w_k$ is
$$\frac{\partial}{\partial w_k}\sum_{i,j}C_{ij}w_iw_j = \sum_j C_{kj}w_j + \sum_i C_{ik}w_i = (Cw)_k + (C^Tw)_k = 2(Cw)_k,$$
using $C^T = C$ (Theorem 23.2) in the last step. So $\nabla_w(w^TCw) =
2Cw$. Also $\nabla_w\|w\|^2 = 2w$. So the stationarity condition is
$$2Cw^* - 2\mu w^* = 0 \iff Cw^* = \mu w^*.$$
This says $w^*$ is a unit eigenvector of $C$, with eigenvalue $\mu$.

*Step 3 (the value of $f$ at any unit eigenvector is its eigenvalue).* If
$Cw = \lambda w$ with $\|w\| = 1$, then
$$f(w) = w^TCw = w^T(\lambda w) = \lambda(w^Tw) = \lambda\|w\|^2 = \lambda.$$
In particular, applying this to $w^*$ from Step 2: $f(w^*) = \mu$.

*Step 4 (the maximizer's eigenvalue must be $\lambda_1$).* By the Spectral
Theorem, $C$'s full list of eigenvalues (with the orthonormal eigenbasis
$q_1,\dots,q_p$) includes $\mu$ as one of $\lambda_1,\dots,\lambda_p$ (say
$\mu = \lambda_i$ for some $i$). Each $q_j$ ($j = 1,\dots,p$) is itself a
unit vector satisfying the constraint, so by Step 3, $f(q_j) = \lambda_j$
for every $j$. Since $w^*$ is a **global** maximizer over the entire sphere
(Step 1), in particular $f(w^*) \ge f(q_j)$ for every $j$, i.e.
$$\lambda_i \ge \lambda_j \quad \text{for every } j = 1,\dots,p.$$
Since $\lambda_i$ is itself one of $\lambda_1,\dots,\lambda_p$ and is
$\ge$ all of them, and $\lambda_1$ is by definition the largest, $\lambda_i
= \lambda_1$. Hence $f(w^*) = \mu = \lambda_i = \lambda_1$.

Conversely, $q_1$ is a specific unit vector satisfying the constraint, and
$f(q_1) = \lambda_1$ by Step 3 — so $\lambda_1$ is actually achieved, not
just an upper bound. Combining: $\max_{\|w\|=1} w^TCw = \lambda_1$, attained
at $w = q_1$. $\blacksquare$

*(An equally valid closed-form proof: writing $w$ in the eigenbasis as $w =
\sum_i c_iq_i$ with $\sum_ic_i^2 = \|w\|^2 = 1$, one gets $w^TCw =
\sum_i\lambda_ic_i^2 \le \lambda_1\sum_ic_i^2 = \lambda_1$ directly, with
equality iff all the "weight" $c_i$ sits on eigenvalue-$\lambda_1$
directions — this avoids calculus entirely and is worth rederiving yourself
as a check on the Lagrange argument above.)*

### Corollary 23.3.1 (Subsequent principal components)

For $k = 2, \dots, p$, the maximum of $w^TCw$ over unit vectors $w$
orthogonal to $q_1, \dots, q_{k-1}$ is $\lambda_k$, attained at $w = q_k$.

**Proof (sketch, mirroring Theorem 23.3).** Maximize $f(w) = w^TCw$ subject
to $\|w\|^2 = 1$ and the $k-1$ extra constraints $w^Tq_i = 0$ for $i =
1,\dots,k-1$. The Lagrangian gains one multiplier per extra constraint:
$$L = w^TCw - \mu(\|w\|^2-1) - \sum_{i=1}^{k-1}\nu_i(w^Tq_i).$$
Setting $\nabla_wL = 0$: $2Cw - 2\mu w - \sum_i \nu_iq_i = 0$, i.e.
$$Cw = \mu w + \tfrac12\sum_{i=1}^{k-1}\nu_iq_i. \tag{$\dagger$}$$
Dot both sides of $(\dagger)$ with $q_j$ for some fixed $j < k$. On the
right, $q_j^Tw = 0$ (constraint) and $q_j^Tq_i = \delta_{ij}$
(orthonormality), so the right side collapses to $\tfrac12\nu_j$. On the
left, $q_j^TCw = (Cq_j)^Tw = \lambda_jq_j^Tw = \lambda_j\cdot 0 = 0$ (using
$C$ symmetric, $Cq_j = \lambda_jq_j$, and $w \perp q_j$ again). So
$0 = \tfrac12\nu_j$ for every $j < k$, i.e. all $\nu_j = 0$. Substituting
back into $(\dagger)$: $Cw = \mu w$ — the maximizer is, again, a unit
eigenvector of $C$, now additionally constrained to lie orthogonal to
$q_1,\dots,q_{k-1}$.

By the Spectral Theorem's single orthonormal eigenbasis $q_1,\dots,q_p$,
the eigenvectors orthogonal to $q_1,\dots,q_{k-1}$ are exactly (linear
combinations of) $q_k,\dots,q_p$, with eigenvalues $\lambda_k,\dots,
\lambda_p$. Repeating the "global max beats every candidate" argument from
Step 4 of Theorem 23.3, restricted to this smaller candidate set, gives
maximum value $\max(\lambda_k,\dots,\lambda_p) = \lambda_k$ (using the
ordering $\lambda_k \ge \cdots \ge \lambda_p$), attained at $w = q_k$.
$\blacksquare$

This is why "just find the eigenvectors of $C$, sorted by eigenvalue" gives
*all* the principal components at once, with no separate re-optimization
needed at each step — the orthogonality that Corollary 23.3.1 requires by
hand is already guaranteed for free by the Spectral Theorem's orthonormal
eigenbasis (Day 19).

### Remark 23.1 (Connection to the SVD — Day 21)

Day 21 proved that if $X = U\Sigma V^T$ is the SVD of $X$ (with singular
values $\sigma_1 \ge \sigma_2 \ge \cdots \ge 0$ on $\Sigma$'s diagonal and
$V$ orthogonal), then
$$X^TX = V\Sigma^TU^TU\Sigma V^T = V(\Sigma^T\Sigma)V^T,$$
using $U^TU = I$. Since $\Sigma^T\Sigma$ is diagonal with entries
$\sigma_i^2$, this is *exactly* a spectral decomposition of $X^TX$: its
eigenvectors are the columns of $V$ — the **right singular vectors** of
$X$ — with eigenvalues $\sigma_i^2$. (This is the identity Day 21 used to
*prove* the SVD exists in the first place, run here in the other
direction.)

Since $C = \frac{1}{n-1}X^TX$ is just $X^TX$ scaled by the positive
constant $\frac{1}{n-1}$, scaling a matrix by a positive scalar leaves its
eigenvectors unchanged and scales its eigenvalues by the same constant: if
$X^TXv = \sigma^2v$ then $Cv = \frac{\sigma^2}{n-1}v$. So **$C$ and $X^TX$
share exactly the same eigenvectors**, meaning the top eigenvector of $C$
(Theorem 23.3's $q_1$) is identically the top right singular vector $v_1$
of $X$, with $\lambda_1 = \sigma_1^2/(n-1)$.

### Definition 23.2 (Principal components, explained variance ratio)

The **$k$-th principal component direction** of centered data $X$ is $q_k$
— equivalently $v_k$, the $k$-th right singular vector of $X$ — the unit
vector maximizing the variance of the projection $Xw$ among directions
orthogonal to all previous principal component directions (Theorem 23.3 for
$k=1$, Corollary 23.3.1 for $k \ge 2$). The **$k$-th principal component
scores** are the projections $Xq_k \in \mathbb{R}^n$ (one score per sample).
The **explained variance ratio** of the $k$-th component is
$$\text{EVR}_k = \frac{\lambda_k}{\sum_{j=1}^p \lambda_j},$$
the fraction of the data's total variance ($\sum_j\lambda_j$, see Exercise 5)
captured by that single direction. Keeping the top $m$ components and
discarding the rest is the dimensionality-reduction step of PCA; how large
$m$ needs to be is governed by how quickly $\sum_{k=1}^m \text{EVR}_k$
approaches $1$ (Exercise 6).

## Worked example

**Claim.** For the 5 points $(12,21), (11,22), (9,18), (8,19), (10,20)$ in
$\mathbb{R}^2$, the first principal component direction is $w_1 =
\left(\tfrac{1}{\sqrt2},\tfrac{1}{\sqrt2}\right)$, and this direction gives
strictly more variance than either coordinate axis alone.

**Step 1: center.** Mean $= \left(\frac{12+11+9+8+10}{5},
\frac{21+22+18+19+20}{5}\right) = (10, 20)$. Subtracting:
$$X = \begin{pmatrix} 2 & 1 \\ 1 & 2 \\ -1 & -2 \\ -2 & -1 \\ 0 & 0 \end{pmatrix}.$$
(Check: each column sums to $0$ — required for Theorem 23.1 to apply.)

**Step 2: covariance matrix.** $n = 5$, so $n - 1 = 4$.
$$X^TX = \begin{pmatrix} 2^2+1^2+(-1)^2+(-2)^2+0^2 & 2(1)+1(2)+(-1)(-2)+(-2)(-1)+0 \\ \cdot & 1^2+2^2+(-2)^2+(-1)^2+0^2\end{pmatrix} = \begin{pmatrix} 10 & 8 \\ 8 & 10\end{pmatrix}.$$
$$C = \frac14\begin{pmatrix}10&8\\8&10\end{pmatrix} = \begin{pmatrix}2.5 & 2\\2 & 2.5\end{pmatrix}.$$

**Step 3: eigenvalues.** $\det(C-\lambda I) = (2.5-\lambda)^2 - 2^2 = 0
\implies 2.5-\lambda = \pm2 \implies \lambda = 0.5 \text{ or } 4.5.$ So
$\lambda_1 = 4.5$, $\lambda_2 = 0.5$.

**Step 4: eigenvectors.** For $\lambda_1 = 4.5$: $C - 4.5I =
\begin{pmatrix}-2&2\\2&-2\end{pmatrix}$, giving $-2v_1+2v_2=0 \implies v_1 =
v_2$. Normalizing: $q_1 = \left(\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right)$. For
$\lambda_2=0.5$: $C-0.5I = \begin{pmatrix}2&2\\2&2\end{pmatrix}$, giving
$v_1+v_2=0 \implies v_1=-v_2$. Normalizing: $q_2 =
\left(\tfrac1{\sqrt2},-\tfrac1{\sqrt2}\right)$. (Check orthogonality:
$q_1\cdot q_2 = \tfrac12 - \tfrac12 = 0$ ✓, as guaranteed by the Spectral
Theorem.)

**Step 5: verify by directly computing variance along three candidate
directions.**

*Along $q_1 = \left(\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right)$ (the claimed
PC1):* projections $Xq_1$ are $\tfrac{1}{\sqrt2}(2+1), \tfrac1{\sqrt2}(1+2),
\tfrac1{\sqrt2}(-1-2), \tfrac1{\sqrt2}(-2-1), \tfrac1{\sqrt2}(0) =
\tfrac{3}{\sqrt2},\tfrac3{\sqrt2},-\tfrac3{\sqrt2},-\tfrac3{\sqrt2},0$. Sum of
squares: $4 \cdot \tfrac{9}{2} = 18$. Variance $= 18/4 = 4.5 = \lambda_1$ ✓
(matches Theorem 23.1 exactly).

*Along $q_2 = \left(\tfrac1{\sqrt2},-\tfrac1{\sqrt2}\right)$ (the claimed
PC2):* projections are $\tfrac1{\sqrt2}, -\tfrac1{\sqrt2},\tfrac1{\sqrt2},
-\tfrac1{\sqrt2}, 0$. Sum of squares $= 4\cdot\tfrac12=2$. Variance $=
2/4=0.5=\lambda_2$ ✓.

*Along the $x$-axis, $u=(1,0)$ (a third, non-eigenvector candidate):*
projections are just the first coordinates $2,1,-1,-2,0$. Sum of squares
$=4+1+1+4=10$. Variance $=10/4=2.5$. Indeed $C_{11}=2.5$ matches directly
(projecting onto a coordinate axis just recovers that feature's own
variance), and $0.5 \le 2.5 \le 4.5$: the $x$-axis gives *more* variance
than PC2 but strictly *less* than PC1 — confirming Theorem 23.3's claim
that no direction beats the top eigenvector.

## Unconventional edge

The trap: learning "PCA" as a black-box `sklearn.decomposition.PCA`
`.fit().transform()` call — a named tool in the ML toolbox, memorized
alongside "logistic regression" and "k-means," with its own API to look up
whenever needed. This treats it as an isolated technique with its own
theory. It has no separate theory: Theorem 23.3 above *is* PCA's entire
mathematical content, and it is nothing more than the Spectral Theorem
(Day 19) pointed at one specific symmetric PSD matrix, the covariance
matrix. Once this clicks, "how many components explain 95% of the
variance" stops being a magic hyperparameter and becomes a statement about
eigenvalue decay you could compute with a pencil (Exercise 6); "PCA assumes
linear structure" stops being a vague caveat and becomes the precise fact
that it can only ever find eigenvectors of a matrix, not some more general
notion of pattern. This is the whole point of the 30-day plan: every
"advanced" technique you'll meet after Day 30 is a named application of a
theorem you already fully own, not a new thing to memorize from scratch.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1, 2, 6, 8 are computational; 3, 5 are proof-based; 4, 7 are
conceptual.

1. For the 5 points $(12,19), (11,18), (9,22), (8,21), (10,20)$: center the
   data, compute the covariance matrix $C$ by hand, find its eigenvalues
   and eigenvectors, and identify the first principal component direction.
   Verify by computing the variance of the projections along your claimed
   PC1 and PC2 directions directly (as in the Worked example's Step 5).
2. For the 5 points $(8,12), (6,10), (4,8), (2,10), (5,10)$: do the same —
   center, compute $C$, find eigenvalues/eigenvectors, identify PC1, and
   verify the variance along PC1 exceeds the variance along both coordinate
   axes.
3. Let $C = \begin{pmatrix}2.5 & 2\\2&2.5\end{pmatrix}$ (the covariance
   matrix from the Worked example). Parametrize unit vectors as $w(\theta) =
   (\cos\theta, \sin\theta)$ and write $h(\theta) = w(\theta)^TCw(\theta)$
   as an explicit function of $\theta$. Use calculus ($h'(\theta) = 0$) to
   find the maximizing $\theta$ (restricting to $\theta \in [0,\pi)$, since
   $w(\theta)$ and $w(\theta+\pi)$ give the same line), and confirm both the
   maximizing direction and the maximum value match the eigenvector/
   eigenvalue found in the Worked example.
4. **Conceptual.** Suppose you forgot to center $X$ (its columns have
   nonzero mean). Which specific step of Theorem 23.1's proof breaks, and
   why? Concretely: if $X$'s columns are *not* mean-zero, is $\frac{1}{n-1}
   \|Xw\|^2$ still equal to $\operatorname{Var}(Xw)$? What would maximizing
   $w^T\left(\frac{1}{n-1}X^TX\right)w$ actually be maximizing instead, in
   that case (hint: relate $\frac1{n-1}\|v\|^2$ to $\operatorname{Var}(v)$
   for a vector $v$ with nonzero mean $\bar v$, using $\operatorname{Var}(v)
   = \frac{1}{n-1}\sum_i(v_i-\bar v)^2$)?
5. **Proof.** Show that $\operatorname{trace}(C) = \sum_{i=1}^p
   \operatorname{Var}(x_{(i)})$ (the sum of each individual feature's
   variance) **and** $\operatorname{trace}(C) = \sum_{i=1}^p\lambda_i$ (the
   sum of $C$'s eigenvalues). (Hint for the second part: use $C = Q\Lambda
   Q^T$ from the Spectral Theorem, and the cyclic property of trace,
   $\operatorname{trace}(ABC) = \operatorname{trace}(BCA)$.) Conclude that
   "total variance," $\sum_i\lambda_i$, can be computed two totally
   different ways — summing the diagonal of $C$ directly, or summing its
   eigenvalues — and both must agree.
6. Suppose a dataset with $p=4$ features has covariance-matrix eigenvalues
   $\lambda = (8, 5, 2, 1)$. Compute the explained variance ratio of each
   principal component, and determine the minimum number of components
   needed to explain at least $90\%$ of the total variance.
7. **Trap.** A dataset has two features: feature 1 measured in millimeters
   (values roughly $\pm 10$) and feature 2 measured in kilometers (values
   roughly $\pm 0.1$), with the four centered points $(10, 0.1), (-10,
   0.1), (10, -0.1), (-10,-0.1)$. Compute $C$ and its eigenvalues/
   eigenvectors, and note which feature "wins" as PC1. Now suppose you
   converted feature 1 to kilometers too (dividing by $1{,}000{,}000$):
   would PC1 still point the same way? What does this tell you about
   applying PCA directly to raw covariance matrices when features are on
   very different scales, and what is the standard fix (hint: look up "the
   correlation matrix is the covariance matrix of standardized data")?
8. Using $C = \begin{pmatrix}5&2\\2&2\end{pmatrix}$ from Exercise 2 (which
   has eigenvalues $\lambda_1=6$, $\lambda_2=1$), compute $w^TCw$ for the
   three unit vectors $w_a = (1,0)$, $w_b = (0,1)$, $w_c =
   \left(\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right)$. Confirm all three values
   lie in $[\lambda_2, \lambda_1] = [1,6]$, consistent with Theorem 23.3
   (no direction beats $\lambda_1$) and its mirror-image fact that no
   direction does worse than $\lambda_2$ (which you are not asked to prove,
   but should notice is the same argument applied to the *minimum* instead
   of the maximum).

## Solutions

**1.** Mean $= (10, 20)$. Centered data:
$$X = \begin{pmatrix}2&-1\\1&-2\\-1&2\\-2&1\\0&0\end{pmatrix}.$$
$X^TX$: $(1,1)$ entry $=4+1+1+4+0=10$; $(2,2)$ entry $=1+4+4+1+0=10$;
$(1,2)$ entry $=2(-1)+1(-2)+(-1)(2)+(-2)(1)+0 = -2-2-2-2=-8$. So
$$C = \frac14\begin{pmatrix}10&-8\\-8&10\end{pmatrix} = \begin{pmatrix}2.5&-2\\-2&2.5\end{pmatrix}.$$
Eigenvalues: $(2.5-\lambda)^2 - 4 = 0 \implies \lambda = 0.5$ or $4.5$.
For $\lambda_1=4.5$: $C-4.5I=\begin{pmatrix}-2&-2\\-2&-2\end{pmatrix}
\implies v_1=-v_2$, so $q_1 = \left(\tfrac1{\sqrt2},-\tfrac1{\sqrt2}\right)$
(PC1). For $\lambda_2=0.5$: $C-0.5I=\begin{pmatrix}2&-2\\-2&2\end{pmatrix}
\implies v_1=v_2$, so $q_2=\left(\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right)$.
Verify: projections onto $q_1$: $\tfrac1{\sqrt2}(2-(-1))=\tfrac3{\sqrt2}$,
$\tfrac1{\sqrt2}(1-(-2))=\tfrac3{\sqrt2}$, $\tfrac1{\sqrt2}(-1-2)=-\tfrac3{\sqrt2}$,
$\tfrac1{\sqrt2}(-2-1)=-\tfrac3{\sqrt2}$, $0$. Sum of squares
$=4(4.5)=18$, variance $=18/4=4.5=\lambda_1$ ✓. Projections onto $q_2$:
$\tfrac1{\sqrt2}(2-1)=\tfrac1{\sqrt2}$, $\tfrac1{\sqrt2}(1-2)=-\tfrac1{\sqrt2}$,
$\tfrac1{\sqrt2}(-1+2)=\tfrac1{\sqrt2}$, $\tfrac1{\sqrt2}(-2+1)=-\tfrac1{\sqrt2}$,
$0$. Sum of squares $=4(0.5)=2$, variance $=2/4=0.5=\lambda_2$ ✓. (This
dataset is the Worked example's data reflected across the $x$-axis, so PC1
is the mirror image, $(1,-1)/\sqrt2$ instead of $(1,1)/\sqrt2$, with the
same eigenvalues.)

**2.** Mean $= (5, 10)$. Centered data:
$$X = \begin{pmatrix}3&2\\1&0\\-1&-2\\-3&0\\0&0\end{pmatrix}.$$
$X^TX$: $(1,1)$ entry $=9+1+1+9+0=20$; $(2,2)$ entry $=4+0+4+0+0=8$;
$(1,2)$ entry $=3(2)+1(0)+(-1)(-2)+(-3)(0)+0=6+0+2+0=8$. So
$$C=\frac14\begin{pmatrix}20&8\\8&8\end{pmatrix} = \begin{pmatrix}5&2\\2&2\end{pmatrix}.$$
Eigenvalues: $\operatorname{trace}=7$, $\det = 10-4=6$; $\lambda^2-7\lambda+6=0
\implies (\lambda-6)(\lambda-1)=0 \implies \lambda=6,1$. For $\lambda_1=6$:
$C-6I=\begin{pmatrix}-1&2\\2&-4\end{pmatrix}\implies -v_1+2v_2=0\implies
v_1=2v_2$, giving (unnormalized) $(2,1)$, so $q_1 =
\left(\tfrac2{\sqrt5},\tfrac1{\sqrt5}\right)$ (PC1). For $\lambda_2=1$:
$C-I=\begin{pmatrix}4&2\\2&1\end{pmatrix}\implies 4v_1+2v_2=0\implies
v_2=-2v_1$, giving $(1,-2)$, so $q_2=\left(\tfrac1{\sqrt5},-\tfrac2{\sqrt5}\right)$.
Check orthogonality: $q_1\cdot q_2 = \tfrac25-\tfrac25=0$ ✓. Variance along
PC1 (by Theorem 23.1, should equal $\lambda_1=6$): projections
$\tfrac1{\sqrt5}(2(3)+1(2))=\tfrac8{\sqrt5}$, $\tfrac1{\sqrt5}(2(1)+0)=\tfrac2{\sqrt5}$,
$\tfrac1{\sqrt5}(2(-1)-2)=-\tfrac4{\sqrt5}$, $\tfrac1{\sqrt5}(2(-3)+0)=-\tfrac6{\sqrt5}$,
$0$. Sum of squares $=\tfrac1{5}(64+4+16+36)=\tfrac{120}{5}=24$, variance
$=24/4=6=\lambda_1$ ✓. Along the $x$-axis $(1,0)$: projections are
$3,1,-1,-3,0$, sum of squares $9+1+1+9=20$, variance $=20/4=5$. Along the
$y$-axis $(0,1)$: projections $2,0,-2,0,0$, sum of squares $4+0+4+0=8$,
variance $=8/4=2$. Both $5$ and $2$ are $\le \lambda_1=6$, confirming PC1
beats both coordinate axes.

**3.** $h(\theta) = w(\theta)^TCw(\theta) = 2.5\cos^2\theta + 2(2)\cos\theta\sin\theta + 2.5\sin^2\theta$
(the cross term appears twice, from $C_{12}$ and $C_{21}$, each contributing
$2\cos\theta\sin\theta$ times $C_{12}=2$). Using $\cos^2\theta+\sin^2\theta=1$:
$$h(\theta) = 2.5 + 4\cos\theta\sin\theta = 2.5 + 2\sin(2\theta),$$
using the double-angle identity $\sin(2\theta) = 2\sin\theta\cos\theta$.
Differentiate: $h'(\theta) = 4\cos(2\theta)$. Setting $h'(\theta)=0$ on
$[0,\pi)$: $\cos(2\theta)=0 \implies 2\theta = \tfrac\pi2 \text{ or }
\tfrac{3\pi}2 \implies \theta = \tfrac\pi4 \text{ or } \tfrac{3\pi}4$.
Evaluate $h$ at both: $h(\pi/4) = 2.5+2\sin(\pi/2) = 2.5+2=4.5$;
$h(3\pi/4) = 2.5+2\sin(3\pi/2) = 2.5-2=0.5$. So the maximum is $4.5$ at
$\theta=\pi/4$ ($45°$), where $w(\pi/4) = (\cos45°,\sin45°) =
\left(\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right)$ — exactly $q_1$ and
$\lambda_1$ from the Worked example, and $\theta=3\pi/4$ gives the minimum
$0.5=\lambda_2$ at $w=\left(-\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right)$, the
same line as $q_2$.

**4.** The break is in Step 1 of Theorem 23.1's proof: if $X$'s columns are
not mean-zero, then $Xw = \sum_j w_jx_{(j)}$ is a linear combination of
vectors that are *not* individually mean-zero, so $Xw$ itself generally has
nonzero mean $\overline{Xw} = \sum_jw_j\bar x_{(j)} \ne 0$. Step 2's formula
$\operatorname{Var}(v) = \frac1{n-1}\|v\|^2$ specifically used $\bar v = 0$
to drop the $(v_i-\bar v)$ down to $v_i$; for $\bar v \ne 0$ the correct
formula is $\operatorname{Var}(v) = \frac1{n-1}\sum_i(v_i-\bar v)^2 =
\frac1{n-1}\left(\sum_iv_i^2 - n\bar v^2\right) = \frac1{n-1}\|v\|^2 -
\frac{n}{n-1}\bar v^2$ (expanding the square and using $\sum_i(v_i-\bar v)^2
= \sum_iv_i^2 - 2\bar v\sum_iv_i + n\bar v^2 = \sum_iv_i^2 - n\bar v^2$,
since $\sum_iv_i = n\bar v$). So without centering, $\frac1{n-1}\|Xw\|^2 =
\operatorname{Var}(Xw) + \frac{n}{n-1}\overline{Xw}^2 \ne \operatorname{Var}(Xw)$
in general — it's variance *plus* a penalty-free bonus term that grows with
how far the projected mean is from $0$. Maximizing $w^TCw$ on uncentered
data would therefore actually be maximizing "mean-square distance from the
origin along direction $w$," which is dominated by wherever the data's
centroid happens to sit relative to the origin — a direction that can be
completely unrelated to how the data is actually spread out. Centering
first removes this origin-dependent artifact so that what's maximized is
genuine spread, not an accident of where the coordinate origin was placed.

**5.** *First equality.* By definition, $C_{ii} = \frac1{n-1}\sum_{k=1}^n
X_{ki}^2$ (the diagonal entries of $\frac1{n-1}X^TX$ are dot products of a
column with itself). Since column $i$, $x_{(i)}$, is centered (mean $0$),
Step 2 of Theorem 23.1's proof gives $\operatorname{Var}(x_{(i)}) =
\frac1{n-1}\|x_{(i)}\|^2 = \frac1{n-1}\sum_kX_{ki}^2 = C_{ii}$. Summing over
$i$: $\operatorname{trace}(C) = \sum_iC_{ii} = \sum_i\operatorname{Var}(x_{(i)})$.

*Second equality.* By the Spectral Theorem, $C = Q\Lambda Q^T$ with $Q$
orthogonal ($Q^TQ=QQ^T=I$) and $\Lambda = \operatorname{diag}(\lambda_1,
\dots,\lambda_p)$. Using the cyclic property of trace,
$\operatorname{trace}(ABC)=\operatorname{trace}(BCA)$:
$$\operatorname{trace}(C) = \operatorname{trace}(Q\Lambda Q^T) = \operatorname{trace}(\Lambda Q^TQ) = \operatorname{trace}(\Lambda I) = \operatorname{trace}(\Lambda) = \sum_{i=1}^p\lambda_i.$$
Combining both equalities: $\sum_i\operatorname{Var}(x_{(i)}) =
\operatorname{trace}(C) = \sum_i\lambda_i$. So "total variance" can be read
directly off the raw data (sum the per-feature variances, no
eigendecomposition needed) or off the eigenvalues (sum $C$'s eigenvalues) —
both routes must agree, and this is exactly the denominator
$\sum_j\lambda_j$ used in the explained variance ratio (Definition 23.2).

**6.** Total variance $= 8+5+2+1=16$. $\text{EVR}_1 = 8/16=0.50$,
$\text{EVR}_2=5/16=0.3125$, $\text{EVR}_3=2/16=0.125$,
$\text{EVR}_4=1/16=0.0625$. Cumulative: after PC1, $50\%$; after PC1+PC2,
$50\%+31.25\%=81.25\%$; after PC1+PC2+PC3, $81.25\%+12.5\%=93.75\% \ge
90\%$. So the minimum number of components needed to reach $90\%$ explained
variance is $\boxed{3}$ (2 components only reach $81.25\%$, not enough).

**7.** Mean is already $(0,0)$. $X^TX$: $(1,1)$ entry $=10^2\cdot4=400$;
$(2,2)$ entry $=0.1^2\cdot4=0.04$; $(1,2)$ entry $=10(0.1)+(-10)(0.1)+10(-0.1)+(-10)(-0.1)=1-1-1+1=0$.
So $$C=\frac14\begin{pmatrix}400&0\\0&0.04\end{pmatrix}=\begin{pmatrix}100&0\\0&0.01\end{pmatrix}.$$
Since $C$ is already diagonal, its eigenvalues are its diagonal entries,
$\lambda_1=100$ (eigenvector $(1,0)$, feature 1's axis) and $\lambda_2=0.01$
(eigenvector $(0,1)$, feature 2's axis) — PC1 is feature 1 (millimeters),
overwhelmingly, purely because millimeter-scale numbers happen to be
numerically larger than the kilometer-scale numbers, with **zero** actual
correlation between the features driving this (the off-diagonal entry is
exactly $0$). If feature 1 were instead expressed in kilometers too
(dividing every value by $1{,}000{,}000$), the new $(1,1)$ entry of $C$
would shrink to $100/10^{12}=10^{-10} \ll 0.01$, and PC1 would instead point
along the *old* feature 2's axis — the identity of "PC1" flips entirely
based on an arbitrary choice of measurement units, even though nothing
about the actual data changed. This shows PCA run on the raw covariance
matrix is not unit-invariant, and is exactly why practitioners standardize
each feature to unit variance first (subtract the mean *and* divide by the
standard deviation) before running PCA whenever features are on
incomparable scales; doing so replaces $C$ with the **correlation matrix**
(the covariance matrix of the standardized features, which by construction
has $1$'s on the diagonal), so no single feature can dominate PC1 merely by
virtue of its units.

**8.** $w_a=(1,0)$: $w_a^TCw_a = C_{11} = 5$. $w_b=(0,1)$: $w_b^TCw_b =
C_{22}=2$. $w_c=\left(\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right)$:
$w_c^TCw_c = \tfrac12(5) + 2\left(\tfrac1{\sqrt2}\right)\left(\tfrac1{\sqrt2}\right)(2) + \tfrac12(2) = \tfrac12(5+2+2\cdot2) $; more carefully, expanding
$w^TCw = C_{11}w_1^2 + 2C_{12}w_1w_2 + C_{22}w_2^2$ with $w_1=w_2=\tfrac1{\sqrt2}$:
$= 5\left(\tfrac12\right) + 2(2)\left(\tfrac12\right) + 2\left(\tfrac12\right) = 2.5+2+1=5.5$.
All three values, $5, 2, 5.5$, lie in $[\lambda_2,\lambda_1]=[1,6]$ — none
exceeds $6$ (Theorem 23.3: nothing beats the top eigenvalue) and none falls
below $1$ (the mirror-image fact that nothing does worse than the smallest
eigenvalue, provable by the same eigenbasis-expansion argument
$w^TCw=\sum_i\lambda_ic_i^2 \ge \lambda_p\sum_ic_i^2=\lambda_p$ noted in
Theorem 23.3's closed-form alternative proof).

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements PCA completely from scratch — no `sklearn.decomposition.PCA`
internals, just the eigendecomposition you've been doing by hand all day,
run on a real dataset (`sklearn`'s classic Iris dataset, 150 samples, 4
features) and checked against `sklearn`'s own implementation. Open
`starter_code/day23_pca_from_scratch.py` — it has one function to complete,
`pca_from_scratch`.

**Hint:** the four steps are exactly Definition 23.1 through Definition
23.2, mechanized: (1) center $X$ by subtracting `X.mean(axis=0)`; (2) form
$C$ as `(X_centered.T @ X_centered) / (n - 1)`; (3) eigendecompose with
`np.linalg.eigh` (use `eigh`, not `eig` — it's specifically for symmetric
matrices, exploits Theorem 23.2, and guarantees real eigenvalues/orthonormal
eigenvectors, but returns them in *ascending* order, so you must reverse the
order yourself to match $\lambda_1 \ge \lambda_2 \ge \cdots$); (4) take the
top `n_components` eigenvectors as columns and project the centered data
onto them.

Fill in the `TODO`, then run the file directly
(`python3 starter_code/day23_pca_from_scratch.py`); it should print
confirmation that your explained variance ratios and (up to sign)
projections match `sklearn.decomposition.PCA` exactly.

**Why "up to sign"?** Just like Day 17's QR decomposition had a sign
ambiguity in each $q_k$, an eigenvector $v$ of $C$ and $-v$ are both valid
unit eigenvectors for the same eigenvalue (both satisfy $Cv=\lambda v$) — so
different implementations (yours vs. `sklearn`'s, which uses SVD internally
per Remark 23.1) may legitimately flip the sign of a given principal
component. This is a sign convention, not a bug; it never affects any
downstream computation that only cares about variance (which depends on
$w$ only through $w^Tw$-type quantities, unaffected by $w \to -w$).

If you get stuck for more than ~10 minutes, check
`solutions/day23_pca_from_scratch.py` — but only after a real attempt.

Once your implementation passes, extend it: plot the cumulative explained
variance ratio (`np.cumsum` of your `explained_variance_ratio_` array,
computed with `n_components=4` — all of them, for Iris) against the number
of components kept, and read off, just as in Exercise 6, the smallest
number of components needed to explain at least $95\%$ of Iris's total
variance.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $X$ | "the centered data matrix" | $n$ samples (rows) $\times$ $p$ features (columns), each column shifted to mean $0$ |
| $w$ | "a unit direction in feature space" | the line we project the data onto |
| $Xw$ | "the projections onto $w$" | the $n$ shadows of the samples on the line through $w$ |
| $C = \frac{1}{n-1}X^TX$ | "the sample covariance matrix" | $p\times p$; entry $(i,j)$ is the covariance of features $i$ and $j$ |
| $w^TCw$ | "$w$-transpose-$C$-$w$" | the variance of the data measured along direction $w$ |
| $\lambda_i,\ q_i$ | "the eigenvalues and eigenvectors of $C$" | $q_i$ is the $i$-th principal direction; $\lambda_i$ is the variance along it |
| $\text{EVR}_k$ | "the explained variance ratio" | $\lambda_k/\sum_j\lambda_j$, the fraction of total variance captured by component $k$ |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- Measuring how spread the centered data is along a unit direction $w$ gives
  exactly $w^TCw$, where $C$ is the covariance matrix — variance becomes a
  quadratic form.
- $C$ is symmetric and positive semidefinite, so the Spectral Theorem
  (Day 19) hands it an orthonormal eigenbasis with real, non-negative
  eigenvalues.
- The direction of maximum variance is the top eigenvector $q_1$ of $C$, and
  the variance it achieves is the top eigenvalue $\lambda_1$; each next
  principal direction is the next eigenvector.
- Because $C = \frac{1}{n-1}X^TX$, its eigenvectors are exactly the right
  singular vectors of $X$ — so running PCA is running the SVD of the data.
- PCA has no separate theory: it is the Spectral Theorem aimed at the
  covariance matrix, with "principal components" just its eigenvectors
  sorted by eigenvalue.

### Proof sketches

**Theorem 23.1 — key trick: centering turns variance into a plain squared
length.**
Each column of $X$ has mean $0$, so any combination $Xw$ of those columns is
mean-zero too. For a mean-zero vector, variance is just
$\frac{1}{n-1}\|Xw\|^2$ — no mean to subtract. Expand that squared norm as
$w^TX^TXw$, pull out the $\frac{1}{n-1}$, and it is precisely $w^TCw$. Full
version: Theorem 23.1 above.

**Theorem 23.2 — key trick: the same identity, with the unit-length
assumption dropped.**
Symmetry is one line of transpose algebra on $\frac{1}{n-1}X^TX$. For
semidefiniteness, notice the variance identity $w^TCw = \frac{1}{n-1}\|Xw\|^2$
never actually used $\|w\|=1$ — the algebra is scale-free. Since a squared
norm is $\ge 0$ and $\frac{1}{n-1}>0$, $w^TCw \ge 0$ for every $w$. Full
version: Theorem 23.2 above.

**Theorem 23.3 — key trick: Lagrange multipliers turn "maximize $w^TCw$ on
the sphere" into the eigenvector equation $Cw=\mu w$.**
The unit sphere is compact and $w^TCw$ is continuous, so a maximizer exists.
Setting the Lagrangian's gradient to zero gives $Cw^* = \mu w^*$ (the
gradient of $w^TCw$ is $2Cw$ because $C$ is symmetric), so the maximizer is
a unit eigenvector, and its objective value equals its own eigenvalue. Since
it out-scores every basis eigenvector $q_j$ — each worth $\lambda_j$ — its
eigenvalue must be the largest, $\lambda_1$, achieved at $q_1$. Full
version: Theorem 23.3 above.

**Corollary 23.3.1 — key trick: add orthogonality constraints and the extra
multipliers all vanish.**
To find the next component, maximize $w^TCw$ over directions orthogonal to
$q_1,\dots,q_{k-1}$. The Lagrangian picks up one multiplier $\nu_j$ per new
constraint, but dotting the stationarity equation with $q_j$ kills each one
(because $Cq_j=\lambda_jq_j$ and $w\perp q_j$), collapsing back to
$Cw=\mu w$. The eligible eigenvectors are now $q_k,\dots,q_p$, so the winner
is $q_k$ with value $\lambda_k$ — which is why sorting $C$'s single
eigenbasis by eigenvalue hands you every principal component at once. Full
version: Corollary 23.3.1 above.

### If you remember only 3 things

1. The variance of the data along a direction $w$ is $w^TCw$, with $C$ the
   covariance matrix — and centering the data is exactly what makes this
   identity hold.
2. The maximum-variance direction is the top eigenvector of $C$ and the
   maximum variance is the top eigenvalue; the principal components are
   $C$'s eigenvectors sorted by eigenvalue.
3. PCA *is* the Spectral Theorem applied to the covariance matrix
   (equivalently the SVD of $X$) — a relabeling of things you already know,
   not a new algorithm.

## Journal template

```
## Day 23 — SVD to PCA
Key theorem in my own words: ...
What confused me: ...
```
