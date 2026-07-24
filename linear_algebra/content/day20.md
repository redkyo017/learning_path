# Day 20 — Quadratic Forms, Positive Definiteness

## Learning objectives

By the end of today you should be able to:
- Define the quadratic form $Q(x) = x^TAx$ associated to a symmetric matrix
  $A$, and state the definitions of positive definite, negative definite,
  positive semidefinite, negative semidefinite, and indefinite.
- Prove, from the Spectral Theorem (Day 19), that a symmetric matrix is
  positive definite if and only if all of its eigenvalues are positive —
  and state the analogous eigenvalue characterizations for the other four
  cases.
- Classify a given symmetric matrix (via its eigenvalues) as one of the five
  cases above, and avoid the "positive diagonal entries" trap.
- Explain why the sublevel sets of a positive-definite quadratic form are
  bounded ellipsoids, connecting today's eigenvalue bound back to Day 12's
  use of diagonalization to make an otherwise-opaque expression transparent.

## Reference material

- Primer (10 min, no video today): before reading anything, sketch by hand
  the level curves (the curves where the function is constant) of
  $f(x,y) = x^2+y^2$, $g(x,y) = -x^2-y^2$, and $h(x,y) = x^2-y^2$, for a few
  positive constant values. You should get concentric circles for $f$,
  concentric circles for $g$ (same shape, but $g$ is only ever $\le 0$), and
  hyperbolas for $h$. Keep these three pictures in mind — they are exactly
  the shapes of positive definite, negative definite, and indefinite
  quadratic forms in two variables, and today's theory explains precisely
  why.
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong* — the
  quadratic forms / positive-definite matrices material (look in the
  supplementary sections following the main symmetric-matrices chapter; the
  PDF's organization varies slightly by edition, so search for "positive
  definite" if the section number doesn't line up) — [free
  PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson), the
  chapter on Bilinear, Quadratic, and Hermitian Forms — restrict yourself to
  the real (quadratic form) material, not the complex/Hermitian sections,
  which are out of scope until the post-Day-30 phase. If you don't have a
  copy, the exercises below are self-contained and sufficient for today.

Today builds directly on Day 19 (symmetric matrices and the Spectral
Theorem): the entire theory below is one application of writing a symmetric
matrix as $A = Q\Lambda Q^T$ and changing coordinates by the orthogonal
matrix $Q$. If Day 19 feels shaky, a quick re-read of that theorem statement
before continuing is worth it.

## Theory

Throughout, $A$ is a fixed $n\times n$ **symmetric** real matrix
($A^T = A$), and $x$ ranges over $\mathbb{R}^n$.

### Definition 20.1 (Quadratic form)

The **quadratic form** associated to $A$ is the function
$Q : \mathbb{R}^n \to \mathbb{R}$ given by
$$Q(x) = x^TAx = \sum_{i=1}^n\sum_{j=1}^n A_{ij}x_ix_j.$$
(Symmetry of $A$ is not needed for this formula to make sense, but it is
needed for the theory below — see the Unconventional-edge-adjacent remark
after Definition 20.2 for why restricting to symmetric $A$ costs nothing.)

### Definition 20.2 (Definiteness)

$A$ (equivalently, its quadratic form $Q$) is:

- **positive definite** if $Q(x) = x^TAx > 0$ for every $x \neq 0$;
- **negative definite** if $x^TAx < 0$ for every $x \neq 0$;
- **positive semidefinite** if $x^TAx \ge 0$ for every $x$ (including
  possibly $x=0$, where it is automatically $0$);
- **negative semidefinite** if $x^TAx \le 0$ for every $x$;
- **indefinite** if neither of the semidefinite conditions holds, i.e. there
  exist $x_1, x_2 \in \mathbb{R}^n$ with $x_1^TAx_1 > 0$ and $x_2^TAx_2 < 0$.

These five cases are mutually exclusive except for one degenerate overlap:
the zero matrix is simultaneously positive semidefinite and negative
semidefinite (Exercise 5 below), since $x^TAx = 0$ for every $x$ satisfies
both weak inequalities at once. Every other symmetric matrix falls into
exactly one of the five cases.

**Remark (why symmetric $A$ costs nothing).** For a general (possibly
non-symmetric) square matrix $M$, $x^TMx = x^T\left(\tfrac12(M+M^T)\right)x$
always — a short computation using $x^TMx = (x^TMx)^T = x^TM^Tx$ (a
$1\times1$ matrix equals its own transpose), so $x^TMx = x^TM^Tx$, hence
$x^TMx = \tfrac12(x^TMx + x^TM^Tx) = x^T\left(\tfrac12(M+M^T)\right)x$. Since
$\tfrac12(M+M^T)$ is symmetric, every quadratic form is already the
quadratic form of *some* symmetric matrix, so restricting Definition 20.1 to
symmetric $A$ loses no generality.

### Theorem 20.1 (Positive definite $\iff$ all eigenvalues positive)

$A$ is positive definite if and only if every eigenvalue of $A$ is positive.

**Proof.** Since $A$ is symmetric, the Spectral Theorem (Day 19) gives an
orthogonal matrix $Q$ and a diagonal matrix
$\Lambda = \operatorname{diag}(\lambda_1,\dots,\lambda_n)$, where
$\lambda_1,\dots,\lambda_n$ are the eigenvalues of $A$ (with multiplicity)
and the columns of $Q$ are a corresponding orthonormal eigenbasis, such that
$$A = Q\Lambda Q^T.$$

*Change of variables.* For $x \in \mathbb{R}^n$, define $y = Q^Tx$. Since
$Q$ is orthogonal it is invertible with $Q^{-1} = Q^T$ (Day 17), so
$x \mapsto y = Q^Tx$ is a bijective linear map of $\mathbb{R}^n$ onto
itself — it has an inverse, $y \mapsto x = Qy$ — and in particular
$$x \neq 0 \iff y \neq 0$$
(if $x=0$ then $y=Q^T0=0$; conversely if $y = 0$ then $x = Qy = Q0 = 0$, so
neither can be zero without the other being zero too; equivalently, a
bijective linear map sends the zero vector to the zero vector and nothing
else to it, since it has trivial kernel).

*Rewriting $Q(x)$.* Substituting $A = Q\Lambda Q^T$:
$$x^TAx = x^T\left(Q\Lambda Q^T\right)x = \left(Q^Tx\right)^T\Lambda\left(Q^Tx\right) = y^T\Lambda y,$$
using $(Q^Tx)^T = x^TQ$ and regrouping. Since $\Lambda$ is diagonal,
$$y^T\Lambda y = \sum_{i=1}^n \lambda_i y_i^2.$$
So for every $x \in \mathbb{R}^n$, with $y = Q^Tx$ as above,
$$x^TAx = \sum_{i=1}^n \lambda_i y_i^2. \tag{$\ast$}$$

Because $x \mapsto y$ is a bijection with $x \neq 0 \iff y \neq 0$, the
statement "$x^TAx > 0$ for all $x \neq 0$" is *equivalent* to the statement
"$\sum_i \lambda_i y_i^2 > 0$ for all $y \neq 0$" — every nonzero $x$
corresponds to exactly one nonzero $y$ and vice versa, and $(\ast)$ shows
the two quantities are equal at corresponding points. We now show this
reformulated statement holds if and only if every $\lambda_i > 0$.

($\Leftarrow$) Suppose $\lambda_i > 0$ for every $i = 1,\dots,n$. Let
$y \neq 0$. Then some coordinate $y_k \neq 0$, so $y_k^2 > 0$, and hence
$\lambda_k y_k^2 > 0$ (positive times positive). Every other term satisfies
$\lambda_i y_i^2 \ge 0$ (positive $\lambda_i$ times a nonnegative square).
So $\sum_i \lambda_i y_i^2$ is a sum of nonnegative terms, at least one of
which ($\lambda_k y_k^2$) is strictly positive, hence the sum itself is
strictly positive. Since $y \neq 0$ was arbitrary, $\sum_i \lambda_i y_i^2 >
0$ for all $y \neq 0$, i.e. $x^TAx > 0$ for all $x \neq 0$: $A$ is positive
definite.

($\Rightarrow$) We prove the contrapositive: if some eigenvalue
$\lambda_k \le 0$, then $A$ is not positive definite. Take $y = e_k$ (the
$k$-th standard basis vector), which is nonzero. Then
$$\sum_{i=1}^n \lambda_i (e_k)_i^2 = \lambda_k \cdot 1^2 = \lambda_k \le 0,$$
since every other coordinate of $e_k$ is $0$. Let $x = Qe_k$, the
corresponding nonzero vector (nonzero because $e_k \neq 0$ and $x=0
\iff y=0$ as shown above; concretely $x$ is the $k$-th column of $Q$, an
eigenvector of $A$ for $\lambda_k$). By $(\ast)$, $x^TAx = \lambda_k \le 0$.
So there is a nonzero $x$ with $x^TAx \le 0$, meaning $A$ **fails** the
defining condition of positive definiteness (which requires $x^TAx>0$ for
*every* nonzero $x$). This proves the contrapositive, hence the forward
direction: if $A$ is positive definite, every eigenvalue is positive.

Both directions hold, so $A$ is positive definite if and only if every
eigenvalue of $A$ is positive. $\blacksquare$

### Corollary 20.1 (The other four cases)

The identical argument — substitute $y = Q^Tx$, use $(\ast)$, and note the
substitution is a bijection preserving "nonzero" — gives, with no new ideas
required:

- $A$ is **negative definite** $\iff$ every eigenvalue of $A$ is negative.
  (Same proof as Theorem 20.1 with every inequality reversed: if all
  $\lambda_i<0$, the same term-by-term argument makes $\sum_i\lambda_iy_i^2
  <0$ for $y\ne0$; if some $\lambda_k\ge0$, take $y=e_k$ to get a
  nonnegative value, contradicting negative definiteness.)
- $A$ is **positive semidefinite** $\iff$ every eigenvalue of $A$ is
  $\ge 0$. (If all $\lambda_i\ge0$, every term $\lambda_iy_i^2\ge0$, so the
  sum is $\ge0$ for *every* $y$, not just nonzero $y$ — matching the weak
  semidefinite condition, which is required to hold at $x=0$ too, trivially.
  Conversely if some $\lambda_k<0$, $y=e_k$ gives $\sum_i\lambda_iy_i^2 =
  \lambda_k<0$, violating $x^TAx\ge0$.)
- $A$ is **negative semidefinite** $\iff$ every eigenvalue of $A$ is
  $\le 0$. (Mirror image of the previous case.)
- $A$ is **indefinite** $\iff$ $A$ has at least one positive eigenvalue and
  at least one negative eigenvalue. (If $\lambda_j>0$ and $\lambda_k<0$ for
  some $j,k$, taking $y=e_j$ gives $x^TAx=\lambda_j>0$ and $y=e_k$ gives
  $x^TAx=\lambda_k<0$ for the corresponding $x$'s, exhibiting both signs —
  exactly Definition 20.2's indefinite condition. Conversely, if $A$ is
  none of the four definite/semidefinite cases above, its eigenvalues can
  be neither "all $\ge0$" nor "all $\le0$", so it must have both a strictly
  positive and a strictly negative eigenvalue.)

We do not re-derive each of these from scratch in full sentences — the
mechanism is identical to Theorem 20.1's proof in every case, only the sign
pattern being tracked changes.

## Worked example

**Classify $A = \begin{pmatrix}2&-1\\-1&2\end{pmatrix}$.**

**Step 1: eigenvalues via the characteristic polynomial.**
$$p_A(\lambda) = \det(A-\lambda I) = \det\begin{pmatrix}2-\lambda&-1\\-1&2-\lambda\end{pmatrix} = (2-\lambda)^2 - 1.$$
Expand: $(2-\lambda)^2 - 1 = \lambda^2 - 4\lambda + 4 - 1 = \lambda^2-4\lambda+3
= (\lambda-1)(\lambda-3)$. So the eigenvalues are $\lambda=1$ and
$\lambda=3$.

**Step 2: apply Theorem 20.1.** Both eigenvalues are positive ($1>0$,
$3>0$), so by Theorem 20.1, $A$ is **positive definite**.

**Step 3: double-check directly on specific vectors.** Writing out
$Q(x) = x^TAx$ for $x=(x_1,x_2)$ explicitly,
$$Q(x) = 2x_1^2 - 2x_1x_2 + 2x_2^2$$
(the off-diagonal entry $-1$ contributes $2 \cdot (-1) \cdot x_1x_2$, and
the diagonal entries contribute $2x_1^2$ and $2x_2^2$). Check a few nonzero
$x$:
- $x=(1,0)$: $Q(x) = 2(1)^2 - 0 + 0 = 2 > 0$. ✓
- $x=(1,1)$: $Q(x) = 2(1) - 2(1)(1) + 2(1) = 2-2+2 = 2 > 0$. ✓
- $x=(1,-1)$: $Q(x) = 2(1) - 2(1)(-1) + 2(1) = 2+2+2 = 6 > 0$. ✓

All three checks give a strictly positive value, consistent with (though of
course not a proof of) positive definiteness — Theorem 20.1's eigenvalue
test is what actually guarantees positivity for *every* nonzero $x$, not
just these three samples. (Confirmed numerically with
`np.linalg.eigvalsh`, which returns `[1.0, 3.0]`.)

## Unconventional edge

A common self-learner trap: "eyeballing" a symmetric matrix's diagonal
entries and assuming positive diagonal entries mean positive definite. This
is false, and it's false in exactly the way that costs the most confidence
when discovered later — a matrix can have all-positive diagonal entries
and still be indefinite. Concretely, $A = \begin{pmatrix}1&3\\3&1\end{pmatrix}$
has diagonal entries $1, 1$ (both positive), but its characteristic
polynomial is $(1-\lambda)^2 - 9 = \lambda^2-2\lambda-8 = (\lambda-4)(\lambda+2)$,
giving eigenvalues $4$ and $-2$ — one positive, one negative, so by
Corollary 20.1 this matrix is **indefinite**, not positive definite. The
large off-diagonal entry ($3$) is what breaks it: definiteness is a
statement about the matrix as a whole, not about its diagonal in isolation.
The reliable test is always Theorem 20.1 — compute the eigenvalues (or, as
an alternative you may encounter in Schaum's or elsewhere, check the signs
of the leading principal minors, Sylvester's criterion, which we state here
without proof: $A$ is positive definite iff every leading principal minor
is positive) — never diagonal entries alone.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–6 and 8 are computational (classify by eigenvalues);
7 and 9 are proof-based; 10 connects back to Day 12.

1. Classify $A_1 = \begin{pmatrix}3&0\\0&5\end{pmatrix}$.
2. Classify $A_2 = \begin{pmatrix}-2&0\\0&-7\end{pmatrix}$.
3. Classify $A_3 = \begin{pmatrix}1&2\\2&1\end{pmatrix}$.
4. Classify $A_4 = \begin{pmatrix}4&2\\2&1\end{pmatrix}$.
5. Classify $A_5 = \begin{pmatrix}0&0\\0&0\end{pmatrix}$ (the zero matrix).
   What is special about this case relative to Definition 20.2's five
   categories?
6. Classify $A_6 = \begin{pmatrix}2&1&0\\1&2&0\\0&0&-3\end{pmatrix}$. (Hint:
   this matrix is block diagonal — a $2\times2$ block and a $1\times1$
   block — so you can find the eigenvalues of each block separately,
   exactly as in Day 11's block-triangular determinant argument.)
7. Prove: if $A$ is positive definite, then $A$ is invertible and $A^{-1}$
   is also positive definite. (Hint: first show $0$ is not an eigenvalue of
   $A$, hence $A$ is invertible; then show that if $v$ is an eigenvector of
   $A$ for eigenvalue $\lambda \neq 0$, $v$ is also an eigenvector of
   $A^{-1}$ for eigenvalue $1/\lambda$; then apply Theorem 20.1 to $A^{-1}$,
   noting $A^{-1}$ is symmetric since $A$ is.)
8. **Trap.** Classify $A_8 = \begin{pmatrix}1&5\\5&1\end{pmatrix}$. Note its
   diagonal entries before you compute anything, then compute the
   eigenvalues and compare.
9. Prove: if $A$ is positive definite, then every diagonal entry $A_{ii}$ is
   strictly positive. (Hint: apply the definition directly with
   $x = e_i$, the $i$-th standard basis vector — don't use eigenvalues for
   this one.) Then explain, in one sentence, why Exercise 8 does not
   contradict this fact.
10. Let $A$ be positive definite with smallest eigenvalue $\lambda_{\min}
    > 0$, and let $Q(x) = x^TAx$. Fix $c > 0$ and consider the sublevel set
    $S_c = \{x \in \mathbb{R}^n : Q(x) \le c\}$. Using the bound
    $Q(x) \ge \lambda_{\min}\|x\|^2$ (derive this bound first, from
    equation $(\ast)$ in Theorem 20.1's proof), argue that $S_c$ is
    bounded — contained in a ball of some explicit radius around the
    origin. (You may additionally note, without a full proof, why $S_c$ is
    in fact an ellipsoid rather than some other bounded shape.)

## Solutions

**1.** $A_1$ is diagonal, so its eigenvalues are exactly its diagonal
entries: $3$ and $5$, both positive. By Theorem 20.1, $A_1$ is **positive
definite**.

**2.** Diagonal, eigenvalues $-2$ and $-7$, both negative. By Corollary
20.1, $A_2$ is **negative definite**.

**3.** $p_{A_3}(\lambda) = (1-\lambda)^2 - 4 = \lambda^2-2\lambda-3 =
(\lambda-3)(\lambda+1)$; eigenvalues $3, -1$. One positive, one negative, so
by Corollary 20.1, $A_3$ is **indefinite**. (Confirmed numerically:
`np.linalg.eigvalsh` gives `[-1., 3.]`.)

**4.** $p_{A_4}(\lambda) = (4-\lambda)(1-\lambda) - 4 = \lambda^2-5\lambda+4-4
= \lambda^2-5\lambda = \lambda(\lambda-5)$; eigenvalues $0, 5$. Both are
$\ge 0$ (one is exactly $0$), so by Corollary 20.1, $A_4$ is **positive
semidefinite** (not positive definite, since an eigenvalue is $0$, not
strictly positive). (Confirmed numerically: `[0., 5.]`.)

**5.** $A_5 = 0$ has eigenvalues $0, 0$ — both $\ge 0$ and both $\le 0$
simultaneously. By Corollary 20.1, $A_5$ is **both positive semidefinite
and negative semidefinite** — the one degenerate case flagged after
Definition 20.2, since $Q(x) = x^T0x = 0$ for every $x$, which trivially
satisfies $\ge 0$ and $\le 0$ at once. It is not indefinite (indefinite
requires some strictly positive *and* some strictly negative value, and
here every value is exactly $0$).

**6.** $A_6$ has the block form $\begin{pmatrix}B & 0\\0&-3\end{pmatrix}$
with $B = \begin{pmatrix}2&1\\1&2\end{pmatrix}$. Since $A_6-\lambda I$ has
the same block-diagonal shape, $\det(A_6-\lambda I) = \det(B-\lambda I)
\cdot \det(-3-\lambda)$ (block-diagonal determinants factor — Day 11).
$\det(B-\lambda I) = (2-\lambda)^2-1 = \lambda^2-4\lambda+3=(\lambda-1)(\lambda-3)$,
giving eigenvalues $1, 3$ from the block; the remaining eigenvalue is $-3$
directly (the $1\times1$ block). So $A_6$'s eigenvalues are $1, 3, -3$: a
mix of positive and negative, so by Corollary 20.1, $A_6$ is **indefinite**.
(Confirmed numerically: `np.linalg.eigvalsh` gives `[-3., 1., 3.]`.)

**7.** *Invertibility.* Since $A$ is positive definite, Theorem 20.1 says
every eigenvalue of $A$ is (strictly) positive, so in particular $0$ is not
an eigenvalue of $A$. By the eigenvalue/null-space correspondence (Day
10/11: $0$ is an eigenvalue of $A$ iff $Av=0$ for some $v \neq 0$, i.e. iff
$A$ has nontrivial null space), $A$ having no eigenvalue equal to $0$ means
$N(A) = \{0\}$, i.e. $A$ is invertible.

*Eigenvalues of $A^{-1}$.* Let $\lambda$ be any eigenvalue of $A$ (so
$\lambda > 0$, hence $\lambda \neq 0$) with eigenvector $v \neq 0$:
$Av = \lambda v$. Multiply both sides on the left by $A^{-1}$:
$v = A^{-1}(\lambda v) = \lambda A^{-1}v$. Since $\lambda \neq 0$, divide
both sides by $\lambda$: $A^{-1}v = \tfrac{1}{\lambda}v$. So $v$ is also an
eigenvector of $A^{-1}$, with eigenvalue $1/\lambda$. Running this over
every eigenvalue $\lambda_1,\dots,\lambda_n$ of $A$ (all positive) shows
every eigenvalue of $A^{-1}$ is of the form $1/\lambda_i$ for some positive
$\lambda_i$, hence itself positive.

*Conclusion.* $A^{-1}$ is symmetric: $(A^{-1})^T = (A^T)^{-1} = A^{-1}$
(using $A^T=A$). Since $A^{-1}$ is symmetric with every eigenvalue positive,
Theorem 20.1 (applied to $A^{-1}$ in place of $A$) says $A^{-1}$ is positive
definite. $\blacksquare$

**8.** Diagonal entries are $1, 1$ — both positive, tempting a "positive
definite" guess by eyeballing. But $p_{A_8}(\lambda) = (1-\lambda)^2-25 =
\lambda^2-2\lambda-24=(\lambda-6)(\lambda+4)$; eigenvalues $6, -4$. Mixed
sign, so by Corollary 20.1, $A_8$ is **indefinite** — exactly the
"Unconventional edge" trap, with a different matrix than the one worked out
there. (Confirmed numerically: `[-4., 6.]`.)

**9.** Let $A$ be positive definite and fix any index $i \in \{1,\dots,n\}$.
Take $x = e_i$, the $i$-th standard basis vector, which is nonzero. Then
$$x^TAx = e_i^TAe_i = A_{ii}$$
(this is a standard fact about how $e_i^TMe_i$ picks out the $(i,i)$ entry
of any matrix $M$: $Me_i$ is the $i$-th column of $M$, and $e_i^T$ dotted
with that column picks out its $i$-th entry, which is $M_{ii}$). Since $A$
is positive definite and $e_i \neq 0$, $x^TAx > 0$, i.e. $A_{ii} > 0$. Since
$i$ was arbitrary, every diagonal entry of $A$ is strictly positive.

This does **not** contradict Exercise 8: positive diagonal entries are a
*necessary* condition for positive definiteness (this exercise), not a
*sufficient* one (Exercise 8 and the Unconventional edge section) — $A_8$
satisfies the necessary condition (both diagonal entries positive) while
still failing to be positive definite, because the off-diagonal entry is
too large relative to the diagonal.

**10.** *Deriving the bound.* From equation $(\ast)$ in Theorem 20.1's
proof, with $y = Q^Tx$, $Q(x) = x^TAx = \sum_i \lambda_i y_i^2$ where
$\lambda_1,\dots,\lambda_n$ are the eigenvalues of $A$. Since every
$\lambda_i \ge \lambda_{\min}$ (by definition of $\lambda_{\min}$ as the
smallest eigenvalue) and every $y_i^2 \ge 0$,
$$Q(x) = \sum_{i=1}^n \lambda_i y_i^2 \ge \sum_{i=1}^n \lambda_{\min} y_i^2 = \lambda_{\min}\sum_{i=1}^n y_i^2 = \lambda_{\min}\|y\|^2.$$
Since $Q$ is orthogonal, it preserves norms (Day 17's corollary), so
$\|y\| = \|Q^Tx\| = \|x\|$ ($Q^T$ is itself orthogonal, by Exercise 4(b) of
Day 17 applied to $Q^T$, or directly since $(Q^T)^TQ^T = QQ^T=I$ when $Q$ is
square orthogonal). So $Q(x) \ge \lambda_{\min}\|x\|^2$ for every $x$.

*Boundedness.* Let $x \in S_c$, i.e. $Q(x) \le c$. Combining with the bound
just derived,
$$\lambda_{\min}\|x\|^2 \le Q(x) \le c \implies \|x\|^2 \le \frac{c}{\lambda_{\min}} \implies \|x\| \le \sqrt{\frac{c}{\lambda_{\min}}}$$
(dividing by $\lambda_{\min}>0$ preserves the inequality direction, and
$\lambda_{\min}>0$ since $A$ is positive definite). So every $x \in S_c$
lies within distance $\sqrt{c/\lambda_{\min}}$ of the origin: $S_c$ is
contained in a ball of that radius, hence bounded.

*Why an ellipsoid (brief).* In the rotated coordinates $y=Q^Tx$, the
condition $Q(x)\le c$ reads $\sum_i \lambda_iy_i^2 \le c$, i.e.
$\sum_i y_i^2/(c/\lambda_i) \le 1$ — precisely the interior of a standard
axis-aligned ellipsoid with semi-axis lengths $\sqrt{c/\lambda_i}$. Since
$x = Qy$ is just an orthogonal change of coordinates (a rotation/reflection,
which distorts no shape, only reorients it), $S_c$ in the original
$x$-coordinates is that same ellipsoid, rotated by $Q$ — so $S_c$ is a
(possibly rotated) bounded ellipsoid, not merely some unspecified bounded
region. This is the same "diagonalize, then read off the answer in the
eigenbasis, then rotate back" pattern Day 12 used to make matrix powers and
difference equations tractable — here it makes the geometry of a quadratic
form tractable instead.

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements a numerical definiteness classifier and visualizes
it. Open `starter_code/day20_quadratic_forms.py` — it has one function to
complete, `classify`. Fill in the `TODO`, then run the file directly
(`python3 starter_code/day20_quadratic_forms.py`); it should print
`All classification checks passed!` and then `saved plot`.

**Hint:** use `np.linalg.eigvalsh(A)` (the symmetric-matrix eigenvalue
solver — faster and numerically more reliable than `np.linalg.eig` when you
know the matrix is symmetric, and it always returns real eigenvalues in
ascending order) to get the eigenvalues, then check their signs with
`np.all(eigvals > 0)`, `np.all(eigvals < 0)`, etc. — exactly the
case-by-case logic of Theorem 20.1 and Corollary 20.1, translated directly
into code.

If you get stuck for more than ~10 minutes, check
`solutions/day20_quadratic_forms.py` — but only after a real attempt.

Once your implementation passes, extend it: run your `classify` function on
every matrix from today's Exercises (1–6, 8) and confirm it agrees with
your by-hand answers, including the degenerate zero-matrix case from
Exercise 5 (check what your function reports for it, and compare against
your Exercise 5 answer). Then look at the saved contour plot: confirm the
positive-definite matrix's level curves are closed loops (ellipses, matching
today's primer sketch), the negative-definite matrix's level curves are
also closed loops but for negative level values, and the indefinite
matrix's level curves are hyperbolas that never close up — the exact
pictures from today's primer, now generated from real eigenvalue
computations instead of hand sketches.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $Q(x) = x^TAx$ | "the quadratic form of $A$" | a pure quadratic function of $x$ built from symmetric $A$ |
| $x^TAx > 0$ | "the form is positive for every nonzero $x$" | the definition of positive definite |
| definite / semidefinite / indefinite | "the sign behavior of the form" | always $>0$; always $\ge 0$; or mixed signs |
| $\lambda_i$ | "the eigenvalues of $A$" | their signs decide the definiteness class |
| $y = Q^Tx$ | "the rotated coordinates" | orthogonal change of variables that diagonalizes the form; here $Q$ is Day 19's orthogonal eigenvector matrix, not the quadratic form $Q(x)$ |
| $\sum_i \lambda_i y_i^2$ | "the form in rotated coordinates" | a plain weighted sum of squares |
| $\lambda_{\min}$ | "the smallest eigenvalue" | controls the bound $Q(x) \ge \lambda_{\min}\Vert x\Vert^2$ |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- A quadratic form $Q(x) = x^TAx$ (with $A$ symmetric) is positive definite
  exactly when every eigenvalue of $A$ is positive.
- The other four classes read off the same list of signs: negative definite
  (all $< 0$), positive/negative semidefinite (all $\ge 0$ / all $\le 0$),
  and indefinite (both a positive and a negative eigenvalue present).
- The whole classification comes from one move: rotate by $Q$ so the form
  becomes a weighted sum of squares $\sum_i \lambda_i y_i^2$, whose sign is
  then obvious.
- Positive diagonal entries do **not** imply positive definite — a large
  off-diagonal entry can hide a negative eigenvalue.
- For a positive-definite form the sublevel sets are bounded ellipsoids,
  with size controlled by the smallest eigenvalue $\lambda_{\min}$.

### Proof sketches

**Theorem 20.1 — key trick: rotate coordinates by $Q$ so the form becomes
$\sum_i \lambda_i y_i^2$, where the signs are laid bare.**
Spectral-decompose $A = Q\Lambda Q^T$ and substitute $y = Q^Tx$. Since $Q$ is
a bijection sending only the origin to the origin, "$x \neq 0$" and "$y \neq
0$" match up, and the form turns into $\sum_i \lambda_i y_i^2$. If every
$\lambda_i > 0$, any nonzero $y$ makes this a sum of nonnegative terms with
at least one strictly positive, so the form is $> 0$. If some $\lambda_k \le
0$, plug in $y = e_k$ (i.e. $x$ = that eigenvector) to get value $\lambda_k
\le 0$, breaking positive definiteness. Full version: Theorem 20.1 above.

**Corollary 20.1 — key trick: same rotation, just track a different sign
pattern.**
Once the form is written as $\sum_i \lambda_i y_i^2$, every definiteness
class is simply a statement about the signs of the $\lambda_i$: all negative
gives negative definite, all $\ge 0$ gives positive semidefinite, all $\le
0$ gives negative semidefinite, and having both a positive and a negative
eigenvalue gives indefinite (test $y = e_j$ and $y = e_k$ to exhibit each
sign). No new argument is needed — only the bookkeeping of signs changes.
Full version: Corollary 20.1 above.

### If you remember only 3 things

1. Definiteness = the signs of the eigenvalues: all positive $\Rightarrow$
   positive definite, mixed signs $\Rightarrow$ indefinite, and so on.
2. The one move behind all of it is rotating to $\sum_i \lambda_i y_i^2$ via
   the Spectral Theorem, where every sign is visible at a glance.
3. Trap: positive diagonal entries do **not** guarantee positive definite —
   always check the eigenvalues, never the diagonal alone.

## Journal template

```
## Day 20 — Quadratic forms, positive definiteness
Key theorem in my own words: ...
What confused me: ...
```
