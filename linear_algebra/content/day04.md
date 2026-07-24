# Day 4 — Invertibility, Isomorphisms, Rank-Nullity

## Learning objectives

By the end of today you should be able to:
- Define the kernel and image of a linear transformation, and compute both by
  hand for a given matrix.
- State and prove the rank-nullity theorem, and use it to relate the
  dimensions of the kernel and image without computing both from scratch.
- Prove that, between finite-dimensional spaces of equal dimension,
  injective, surjective, and invertible are all equivalent for a linear
  transformation.
- Decide, using rank-nullity alone (no explicit construction), whether an
  injective or surjective linear map between two given spaces can possibly
  exist.

## Reference material

- Primer (15 min, geometric intuition): 3Blue1Brown, *Essence of Linear
  Algebra*, Chapter 7 (inverse matrices, rank, null space) —
  [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab)
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §1.8–1.9 —
  [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  chapter on Linear Mappings and Matrices — if you don't have a copy, the
  exercises below are self-contained and sufficient for today.

The theory below is self-contained — you do not strictly need the Treil PDF to
do today's work, but reading his §1.8–1.9 alongside this is the "theory" layer
of today's three-layer structure.

## Theory

### Definition 4.1 (Kernel and image)

Let $T: V \to W$ be a linear transformation between vector spaces. The
**kernel** (or *null space*) of $T$ is
$$\ker T = \{v \in V : T(v) = 0\},$$
and the **image** (or *range*) of $T$ is
$$\operatorname{im} T = \{T(v) : v \in V\} \subseteq W.$$

Both are subspaces: $\ker T$ is a subspace of $V$, and $\operatorname{im} T$
is a subspace of $W$. (This is a one-line check via Definition 1.2 from Day 1
— $T(0) = 0$ gives $0 \in \ker T$ and $0 \in \operatorname{im} T$; linearity
of $T$ gives closure under addition and scalar multiplication in both sets.
We take this as known from Day 3 and will use it freely below.)

### Definition 4.2 (Invertible, isomorphism)

A linear transformation $T: V \to W$ is **invertible** if there exists a
linear transformation $S: W \to V$ such that $S \circ T = \operatorname{id}_V$
and $T \circ S = \operatorname{id}_W$. In this case $S$ is called the
**inverse** of $T$, written $T^{-1}$. An invertible linear transformation is
also called an **isomorphism**, and we say $V$ and $W$ are **isomorphic**.

Recall from set theory: $T$ is **injective** (one-to-one) if $T(u) = T(v)
\implies u = v$, and **surjective** (onto) if for every $w \in W$ there exists
$v \in V$ with $T(v) = w$, i.e. $\operatorname{im} T = W$. As with functions in
general, $T$ has a two-sided inverse as a *function* if and only if $T$ is
both injective and surjective (a bijection) — Lemma 4.1 below packages the
"injective" half in terms of the kernel, which is what makes this tractable
for linear maps specifically.

### Lemma 4.1 (Injective iff trivial kernel)

A linear transformation $T: V \to W$ is injective if and only if
$\ker T = \{0\}$.

**Proof.** ($\Rightarrow$) Suppose $T$ is injective. Let $v \in \ker T$, so
$T(v) = 0$. Since $T$ is linear, $T(0) = 0$ as well. So $T(v) = T(0)$, and
injectivity gives $v = 0$. Hence $\ker T \subseteq \{0\}$; combined with
$0 \in \ker T$ always, $\ker T = \{0\}$.

($\Leftarrow$) Suppose $\ker T = \{0\}$. Let $u, v \in V$ with $T(u) = T(v)$.
By linearity, $T(u - v) = T(u) - T(v) = 0$, so $u - v \in \ker T = \{0\}$,
i.e. $u - v = 0$, i.e. $u = v$. Hence $T$ is injective. $\blacksquare$

This lemma is the reason kernels matter: for linear maps, checking injectivity
— in general a "for all pairs $u,v$" statement — reduces to checking a single
condition, whether one particular set (the kernel) is trivial.

### Theorem 4.1 (Rank-nullity theorem)

Let $T: V \to W$ be a linear transformation with $V$ finite-dimensional. Then
$$\dim(\ker T) + \dim(\operatorname{im} T) = \dim V.$$

(The quantity $\dim(\operatorname{im} T)$ is called the **rank** of $T$, and
$\dim(\ker T)$ is called the **nullity** of $T$.)

**Proof.** Let $n = \dim V$, and let $k = \dim(\ker T)$ (note $k \le n$ since
$\ker T$ is a subspace of $V$). Choose a basis $\{u_1, \dots, u_k\}$ of
$\ker T$ (if $\ker T = \{0\}$, take $k=0$ and this basis is empty). By the
basis extension theorem (Day 2), extend this to a basis
$$\{u_1, \dots, u_k, v_1, \dots, v_{n-k}\}$$
of $V$. We will show that
$$\{T(v_1), \dots, T(v_{n-k})\}$$
is a basis of $\operatorname{im} T$; this immediately gives
$\dim(\operatorname{im} T) = n - k$, i.e. $k + (n-k) = n$, which is the
theorem.

*Spanning.* Let $w \in \operatorname{im} T$, so $w = T(v)$ for some $v \in V$.
Write $v$ in terms of the basis of $V$:
$$v = \sum_{i=1}^k a_i u_i + \sum_{j=1}^{n-k} b_j v_j$$
for scalars $a_i, b_j$. Applying $T$ and using linearity,
$$w = T(v) = \sum_{i=1}^k a_i T(u_i) + \sum_{j=1}^{n-k} b_j T(v_j)
= \sum_{j=1}^{n-k} b_j T(v_j),$$
since each $u_i \in \ker T$ means $T(u_i) = 0$. So $w$ is a linear combination
of $T(v_1), \dots, T(v_{n-k})$; since $w$ was an arbitrary element of
$\operatorname{im} T$, these vectors span $\operatorname{im} T$.

*Linear independence.* Suppose
$$\sum_{j=1}^{n-k} c_j T(v_j) = 0$$
for scalars $c_j$. By linearity, $T\left(\sum_{j=1}^{n-k} c_j v_j\right) = 0$,
so $\sum_{j=1}^{n-k} c_j v_j \in \ker T$. Since $\{u_1, \dots, u_k\}$ is a
basis of $\ker T$, we can write
$$\sum_{j=1}^{n-k} c_j v_j = \sum_{i=1}^k d_i u_i$$
for some scalars $d_i$, i.e.
$$\sum_{j=1}^{n-k} c_j v_j - \sum_{i=1}^k d_i u_i = 0.$$
But $\{u_1, \dots, u_k, v_1, \dots, v_{n-k}\}$ is a basis of $V$, hence
linearly independent, so *every* coefficient in this expression must vanish:
in particular $c_j = 0$ for all $j = 1, \dots, n-k$. Hence
$\{T(v_1), \dots, T(v_{n-k})\}$ is linearly independent.

Being both spanning and linearly independent, $\{T(v_1), \dots, T(v_{n-k})\}$
is a basis of $\operatorname{im} T$, so $\dim(\operatorname{im} T) = n - k$,
and therefore $\dim(\ker T) + \dim(\operatorname{im} T) = k + (n-k) =
n = \dim V$. $\blacksquare$

### Theorem 4.2 (Equivalence of invertible / injective / surjective, equal
dimension case)

Let $T: V \to W$ be a linear transformation between finite-dimensional vector
spaces with $\dim V = \dim W$. Then the following are equivalent:
1. $T$ is invertible.
2. $T$ is injective.
3. $T$ is surjective.

**Proof.** Let $n = \dim V = \dim W$.

*(2) $\iff$ (3).* By Lemma 4.1, $T$ is injective iff $\ker T = \{0\}$ iff
$\dim(\ker T) = 0$. By rank-nullity (Theorem 4.1),
$\dim(\ker T) = n - \dim(\operatorname{im} T)$, so $\dim(\ker T) = 0$ iff
$\dim(\operatorname{im} T) = n$. But $\operatorname{im} T$ is a subspace of
$W$ with $\dim W = n$, so $\dim(\operatorname{im} T) = n$ iff
$\operatorname{im} T = W$ (a subspace of a finite-dimensional space equal in
dimension to the whole space must *be* the whole space — otherwise, extending
a basis of $\operatorname{im} T$ to a basis of $W$ would produce a basis of
$W$ with more than $n$ vectors unless no extension is needed, i.e. unless the
two already coincide), i.e. iff $T$ is surjective. Chaining these
equivalences: $T$ injective $\iff$ $\dim(\ker T) = 0 \iff \dim(\operatorname{im}
T) = n \iff T$ surjective.

*(1) $\implies$ (2) and (1) $\implies$ (3).* Suppose $T$ is invertible, with
inverse $S: W \to V$. If $T(u) = T(v)$, applying $S$ gives
$S(T(u)) = S(T(v))$, i.e. $u = v$ (since $S \circ T = \operatorname{id}_V$).
So $T$ is injective. For surjectivity, let $w \in W$; then $v := S(w) \in V$
satisfies $T(v) = T(S(w)) = w$ (since $T \circ S = \operatorname{id}_W$), so
$w \in \operatorname{im} T$. Since $w$ was arbitrary, $T$ is surjective.

*(2) and (3) $\implies$ (1).* Suppose $T$ is both injective and surjective
(by the equivalence above, either one alone forces the other, given
$\dim V = \dim W$, but we use both directly here for clarity). Then $T$ is a
bijection of sets, so it has a set-theoretic inverse function
$S: W \to V$ satisfying $S(T(v)) = v$ for all $v \in V$ and $T(S(w)) = w$ for
all $w \in W$. It remains to check $S$ is *linear*. Let $w_1, w_2 \in W$ and
$c$ a scalar; let $v_1 = S(w_1)$, $v_2 = S(w_2)$, so $T(v_1) = w_1$,
$T(v_2) = w_2$. By linearity of $T$,
$$T(v_1 + v_2) = T(v_1) + T(v_2) = w_1 + w_2, \qquad T(cv_1) = cT(v_1) = cw_1.$$
Applying $S$ to both sides of each equation and using $S(T(v)) = v$:
$$S(w_1 + w_2) = v_1 + v_2 = S(w_1) + S(w_2), \qquad S(cw_1) = cv_1 = cS(w_1).$$
So $S$ is linear, and it is a two-sided inverse of $T$ by construction. Hence
$T$ is invertible. $\blacksquare$

**Remark.** The equal-dimension hypothesis is essential — see the
Unconventional edge and Exercise 8 below for what happens without it.

## Worked example

Let $A = \begin{pmatrix}1&2\\2&4\end{pmatrix}$, viewed as the linear map
$T: \mathbb{R}^2 \to \mathbb{R}^2$, $T(x) = Ax$.

**Kernel.** Solve $Ax = 0$: $x_1 + 2x_2 = 0$ and $2x_1 + 4x_2 = 0$. The second
equation is exactly twice the first, so it gives no new information; the
system reduces to the single equation $x_1 = -2x_2$. Hence
$$\ker A = \left\{ \begin{pmatrix}-2t\\t\end{pmatrix} : t \in \mathbb{R} \right\}
= \operatorname{span}\left\{ \begin{pmatrix}-2\\1\end{pmatrix} \right\},$$
a line through the origin, so $\dim(\ker A) = 1$.

**Image.** $\operatorname{im} A$ is spanned by the columns of $A$:
$\operatorname{span}\left\{ \binom{1}{2}, \binom{2}{4} \right\}$. But
$\binom{2}{4} = 2\binom{1}{2}$, so the second column is redundant, and
$$\operatorname{im} A = \operatorname{span}\left\{ \binom{1}{2} \right\},$$
also a line through the origin, so $\dim(\operatorname{im} A) = 1$.

**Rank-nullity check.** $\dim(\ker A) + \dim(\operatorname{im} A) = 1 + 1 = 2
= \dim \mathbb{R}^2$ ✓, as Theorem 4.1 guarantees.

**Invertibility.** $\ker A \neq \{0\}$ (it contains, e.g., $\binom{-2}{1}
\neq 0$), so by Lemma 4.1, $A$ is not injective. Since $\dim(\text{domain}) =
\dim(\text{codomain}) = 2$, Theorem 4.2 tells us not-injective $\implies$
not-invertible directly — no need to separately check surjectivity or try to
construct an inverse. (Consistent with the classical fact: $A$ is singular
because $\det A = 1\cdot4 - 2\cdot2 = 0$; today's route to the same
conclusion goes through the kernel instead of the determinant.)

## Unconventional edge

It's tempting to treat "find the kernel" and "find the image" as two
unrelated homework tasks, each with its own memorized row-reduction recipe —
and then, out of habit, to compute both from scratch every time. But
rank-nullity says they are mechanically linked: once you know $\dim V$ and
*either* $\dim(\ker T)$ or $\dim(\operatorname{im} T)$, the other is
determined for free by subtraction. In the worked example above, once you
know $\dim(\ker A) = 1$ and $\dim \mathbb{R}^2 = 2$, you already know
$\dim(\operatorname{im} A) = 1$ *before* touching the columns of $A$ — computing
the image from scratch afterward is a good check, not a necessity. The
deeper trap this guards against (echoing the plan's "disconnected recipes"
mistake) is memorizing rank-nullity as a fact to cite rather than internalizing
it as a structural constraint: dimension count is conserved, splitting
between "collapsed to zero" ($\ker T$) and "what survives the map"
($\operatorname{im} T$), and every invertibility question on this page is
secretly a question about how that one number ($\dim V$) is partitioned.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–6 are computational; 7–10 are proof/justification-based.

1. Let $A = \begin{pmatrix}1&0\\0&0\end{pmatrix}$ as a map $\mathbb{R}^2 \to
   \mathbb{R}^2$. Find $\ker A$ and $\operatorname{im} A$ explicitly, and
   verify rank-nullity numerically.
2. Let $A = \begin{pmatrix}1&2&3\\2&4&6\end{pmatrix}$ as a map $\mathbb{R}^3
   \to \mathbb{R}^2$. Find $\ker A$, $\operatorname{im} A$, the rank, and the
   nullity.
3. Let $A = \begin{pmatrix}1&0\\0&1\\1&1\end{pmatrix}$ as a map $\mathbb{R}^2
   \to \mathbb{R}^3$. Find $\ker A$ and $\operatorname{im} A$. Is $A$
   injective? Is it surjective?
4. Let $A = \begin{pmatrix}1&1&0\\0&1&1\\1&2&1\end{pmatrix}$ as a map
   $\mathbb{R}^3 \to \mathbb{R}^3$. Find the rank of $A$ by finding
   $\dim(\ker A)$ first (look for a nontrivial relation among the columns),
   then invoke rank-nullity to get the rank without separately row-reducing
   for the image. Is $A$ invertible?
5. Let $A = \begin{pmatrix}2&0&0\\0&3&0\\0&0&0\end{pmatrix}$ as a map
   $\mathbb{R}^3 \to \mathbb{R}^3$. Find $\ker A$ and $\operatorname{im} A$,
   and state the rank and nullity.
6. Let $T: P_2 \to P_1$ (polynomials of degree $\le 2$ to polynomials of
   degree $\le 1$) be given by $T(p) = p'$ (the derivative). Find $\ker T$,
   $\operatorname{im} T$, the rank, and the nullity. (Recall $\dim P_2 = 3$,
   $\dim P_1 = 2$.)
7. Prove: if $T: V \to W$ is injective and $\dim V = \dim W$ (both finite),
   then $T$ is automatically surjective. Use the rank-nullity theorem
   directly in your proof (you may cite Theorem 4.2, but write out the
   rank-nullity argument explicitly rather than just citing the theorem
   number).
8. True or False, with justification using rank-nullity: there exists an
   injective linear map $T: \mathbb{R}^3 \to \mathbb{R}^2$.
9. True or False, with justification using rank-nullity: there exists a
   surjective linear map $T: \mathbb{R}^2 \to \mathbb{R}^3$.
10. Prove: if $T: U \to V$ and $S: V \to W$ are both invertible linear
    transformations, then $S \circ T: U \to W$ is invertible, with
    $(S \circ T)^{-1} = T^{-1} \circ S^{-1}$.

## Solutions

**1.** $Ax = \binom{x_1}{0}$, so $Ax = 0 \iff x_1 = 0$ ($x_2$ free). Hence
$\ker A = \operatorname{span}\{(0,1)\}$, $\dim(\ker A) = 1$. The columns of
$A$ are $(1,0)$ and $(0,0)$; the image is spanned by the nonzero one:
$\operatorname{im} A = \operatorname{span}\{(1,0)\}$, $\dim(\operatorname{im}
A) = 1$. Check: $1 + 1 = 2 = \dim \mathbb{R}^2$ ✓.

**2.** $Ax = 0$ gives $x_1 + 2x_2 + 3x_3 = 0$ (the second row is twice the
first, redundant). This is one equation in three unknowns, so the solution
set is 2-dimensional: parametrize by $x_2 = s, x_3 = t$, $x_1 = -2s-3t$, so
$\ker A = \operatorname{span}\{(-2,1,0), (-3,0,1)\}$, $\dim(\ker A) = 2$. By
rank-nullity, $\dim(\operatorname{im} A) = \dim\mathbb{R}^3 - \dim(\ker A) =
3 - 2 = 1$; indeed the columns $(1,2),(2,4),(3,6)$ are all multiples of
$(1,2)$, so $\operatorname{im} A = \operatorname{span}\{(1,2)\}$, confirming
rank $=1$, nullity $=2$.

**3.** $Ax = (x_1, x_2, x_1+x_2)$. This is $0$ only when $x_1 = x_2 = 0$, so
$\ker A = \{0\}$; by Lemma 4.1, $A$ is injective. $\operatorname{im} A =
\operatorname{span}\{(1,0,1),(0,1,1)\}$, a 2-dimensional plane in
$\mathbb{R}^3$ (the two spanning vectors are not scalar multiples of each
other, so they're independent). Since $\operatorname{im} A \neq \mathbb{R}^3$
(e.g. $(0,0,1) \notin \operatorname{im} A$: it would need $x_1=0,x_2=0$, but
then the third coordinate is $0 \neq 1$), $A$ is not surjective. (Consistent
with rank-nullity: $\dim(\ker A) + \dim(\operatorname{im} A) = 0 + 2 = 2 =
\dim \mathbb{R}^2$ — the domain, not the codomain, since rank-nullity always
sums to $\dim V$, the *domain* dimension.)

**4.** Look for a relation $c_1(1,0,1) + c_2(1,1,2) + c_3(0,1,1) = 0$ among
the columns: this gives $c_1+c_2=0$, $c_2+c_3=0$, $c_1+2c_2+c_3=0$. From the
first two, $c_1=-c_2$, $c_3=-c_2$; substituting into the third:
$-c_2+2c_2-c_2 = 0$, which holds for *any* $c_2$ — so nontrivial solutions
exist, e.g. $c_2=1, c_1=-1,c_3=-1$: check $-1\cdot(1,0,1)+1\cdot(1,1,2)-1\cdot
(0,1,1) = (-1+1-0,\,0+1-1,\,-1+2-1)=(0,0,0)$ ✓. So the column
$(-1,1,-1)\in\ker A$ is nonzero, hence $\dim(\ker A) \ge 1$. Since the first
two columns $(1,0,1),(1,1,2)$ are not multiples of each other, they're
independent, so $\dim(\ker A)$ can't be $2$ or $3$ (that would force the
image to have dimension $\le 1$, but we already have 2 independent columns in
the image) — so $\dim(\ker A) = 1$ exactly. By rank-nullity,
$\dim(\operatorname{im} A) = 3 - 1 = 2$. Since $\dim(\operatorname{im} A) = 2
\neq 3 = \dim\mathbb{R}^3$, $A$ is not surjective, and by Theorem 4.2 (equal
domain/codomain dimension), not surjective $\iff$ not invertible. So $A$ is
not invertible.

**5.** $Ax = (2x_1, 3x_2, 0)$. This is $0$ iff $x_1=x_2=0$ ($x_3$ free), so
$\ker A = \operatorname{span}\{(0,0,1)\}$, nullity $1$. The image is
$\{(2x_1,3x_2,0): x_1,x_2\in\mathbb R\} = \operatorname{span}\{(1,0,0),
(0,1,0)\}$, rank $2$. Check: $1+2=3=\dim\mathbb{R}^3$ ✓.

**6.** For $p(x) = a+bx+cx^2 \in P_2$, $T(p) = p' = b + 2cx$. $T(p) = 0
\iff b=0, c=0$ ($a$ free), so $\ker T = \{a : a \in \mathbb{R}\}$ (the
constant polynomials), $\dim(\ker T) = 1$. Every element of $P_1$, say
$\beta+\gamma x$, is hit by $p(x) = \beta x + \frac{\gamma}{2}x^2$ (plus any
constant), so $T$ is surjective and $\operatorname{im} T = P_1$,
$\dim(\operatorname{im} T) = 2$. Check: $1 + 2 = 3 = \dim P_2$ ✓ (rank-nullity
uses $\dim V = \dim P_2$, the domain, even though the codomain $P_1$ has
different dimension — this is exactly the unequal-dimension case where
Theorem 4.2 does *not* apply, since $\dim P_2 \ne \dim P_1$; $T$ can be, and
is, surjective without being injective).

**7.** Suppose $T: V\to W$ is injective and $\dim V = \dim W =: n$ (both
finite). By Lemma 4.1, injectivity gives $\ker T = \{0\}$, so
$\dim(\ker T) = 0$. By the rank-nullity theorem (Theorem 4.1),
$$\dim(\ker T) + \dim(\operatorname{im} T) = \dim V \implies 0 +
\dim(\operatorname{im} T) = n \implies \dim(\operatorname{im} T) = n.$$
Now $\operatorname{im} T$ is a subspace of $W$ with $\dim(\operatorname{im}
T) = n = \dim W$. A subspace of a finite-dimensional space with dimension
equal to the whole space must equal the whole space: extend a basis of
$\operatorname{im} T$ ($n$ vectors) to a basis of $W$; but $\dim W = n$
already, so the extension adds zero vectors, meaning the original basis of
$\operatorname{im} T$ was already a basis of $W$, i.e.
$\operatorname{im} T = W$. Hence $T$ is surjective. $\blacksquare$

**8.** False. If $T: \mathbb{R}^3 \to \mathbb{R}^2$ were injective, Lemma 4.1
gives $\dim(\ker T) = 0$, so rank-nullity forces $\dim(\operatorname{im} T) =
\dim\mathbb{R}^3 - 0 = 3$. But $\operatorname{im} T$ is a subspace of
$\mathbb{R}^2$, which has dimension only $2$, and no subspace can have larger
dimension than its ambient space — contradiction. So no such injective map
exists. (Intuitively: you cannot inject a "bigger" space into a "smaller"
one linearly, since $3$ dimensions of input can't avoid collapsing onto only
$2$ dimensions of output — some nonzero vector must land in the kernel.)

**9.** False. By rank-nullity, for *any* linear $T:\mathbb{R}^2\to
\mathbb{R}^3$, $\dim(\operatorname{im} T) = \dim\mathbb{R}^2 - \dim(\ker T) =
2 - \dim(\ker T) \le 2 < 3 = \dim\mathbb{R}^3$. So $\operatorname{im} T$
can never be all of $\mathbb{R}^3$ — it is at most a 2-dimensional subspace
(e.g. the naive attempt $T(x_1,x_2) = (x_1,x_2,0)$ has image
$\operatorname{span}\{(1,0,0),(0,1,0)\}$, missing every point with nonzero
third coordinate). No surjective linear map $\mathbb{R}^2\to\mathbb{R}^3$
exists — the same "can't grow dimension" obstruction as Exercise 8,
mirrored on the image side. This is the trap the exercise is testing: the
naive instinct is "sure, just map onto a subspace and call it surjective,"
but surjective means hitting *all* of $\mathbb{R}^3$, and rank-nullity caps
the image dimension at $2$.

**10.** Since $T$ is invertible, $T^{-1}: V \to U$ exists with $T^{-1}\circ T
= \operatorname{id}_U$, $T\circ T^{-1} = \operatorname{id}_V$; similarly
$S^{-1}: W\to V$ satisfies $S^{-1}\circ S=\operatorname{id}_V$, $S\circ
S^{-1} = \operatorname{id}_W$. Both $T^{-1}$ and $S^{-1}$ are linear (by
definition of invertible linear transformation), and a composition of linear
maps is linear, so $T^{-1}\circ S^{-1}: W \to U$ is linear. Check it's a
two-sided inverse of $S\circ T: U \to W$:
$$(T^{-1}\circ S^{-1})\circ(S\circ T) = T^{-1}\circ(S^{-1}\circ S)\circ T =
T^{-1}\circ \operatorname{id}_V\circ T = T^{-1}\circ T = \operatorname{id}_U,$$
$$(S\circ T)\circ(T^{-1}\circ S^{-1}) = S\circ(T\circ T^{-1})\circ S^{-1} =
S\circ \operatorname{id}_V\circ S^{-1} = S\circ S^{-1} = \operatorname{id}_W.$$
So $S\circ T$ is invertible with $(S\circ T)^{-1} = T^{-1}\circ S^{-1}$.
$\blacksquare$

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements a numerical rank-nullity check. Open
`starter_code/day04_rank_nullity.py` — it has one function to complete,
`rank_nullity_holds`. Fill in the `TODO`, then run the file directly
(`python starter_code/day04_rank_nullity.py`); it should print
`All checks passed!`.

**Hint:** `np.linalg.matrix_rank(A)` gives $\dim(\operatorname{im} A)$
directly (numerically, via the SVD under the hood — more on SVD in Weeks
3–4). `scipy.linalg.null_space(A)` returns an orthonormal basis for
$\ker A$ as the columns of a matrix, so `.shape[1]` gives $\dim(\ker A)$.
The function should just check that these two numbers sum to
`A.shape[1]` (the number of columns of $A$, i.e. $\dim$ of the domain
$\mathbb{R}^{\text{ncols}}$) — this is Theorem 4.1, verified numerically
rather than symbolically.

If you get stuck for more than ~10 minutes, check
`solutions/day04_rank_nullity.py` — but only after a real attempt.

Once your implementation passes, extend it: generate 3 random $4\times 6$
matrices with `np.random.default_rng()` and confirm `rank_nullity_holds`
returns `True` for all of them (it always should — rank-nullity is an
identity, not a special case that only holds for hand-picked matrices).

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $\ker T$ | "the kernel of $T$" | all inputs that $T$ sends to $0$ |
| $\operatorname{im} T$ | "the image of $T$" | all outputs $T$ can actually produce |
| $\{v \in V : T(v)=0\}$ | "the set of $v$ in $V$ such that $T(v)=0$" | the set-builder definition of the kernel |
| $\{0\}$ | "the zero subspace — only the zero vector" | a trivial kernel; means $T$ is injective |
| $\dim(\ker T)$ | "the nullity — dimension of the kernel" | how many independent directions collapse to $0$ |
| $\dim(\operatorname{im} T)$ | "the rank — dimension of the image" | how many independent directions survive |
| $\operatorname{id}_V$ | "the identity map on $V$" | leaves every vector unchanged; what $T^{-1}\circ T$ equals |
| $T^{-1}$ | "$T$ inverse" | the linear map that reverses $T$ |
| $S \circ T$ | "$S$ after $T$" | composition (from Day 3) |
| $\iff$ | "if and only if" | injective $\iff$ trivial kernel |
| $\implies$ | "implies" | $T(u)=T(v) \implies u=v$ (injectivity) |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- The kernel collects everything a map crushes to zero; the image collects
  everything the map can reach.
- A linear map is injective exactly when its kernel is trivial — just the
  zero vector.
- Rank-nullity: the input dimension always splits cleanly into "dimension
  collapsed" (nullity) plus "dimension surviving" (rank).
- Between spaces of equal finite dimension, injective, surjective, and
  invertible are all the very same condition.
- You cannot linearly inject a bigger space into a smaller one, nor surject a
  smaller one onto a bigger one — rank-nullity forbids both.

### Proof sketches

**Lemma 4.1 — key trick: injectivity applied to $T(v)=T(0)$, and linearity
turning $T(u)=T(v)$ into $T(u-v)=0$.**
If $T$ is injective and $T(v)=0=T(0)$, then $v=0$, so the kernel is just
$\{0\}$. Conversely, if the kernel is trivial and $T(u)=T(v)$, linearity
gives $T(u-v)=0$, so $u-v$ lies in the kernel, hence equals $0$, hence
$u=v$. Full version: Lemma 4.1 above.

**Theorem 4.1 — key trick: start from a basis of the kernel, extend it to a
basis of the whole space, and watch what $T$ does to the new vectors.**
Pick a basis of the kernel and extend it to a basis of $V$. The kernel
vectors all map to zero, so only the images of the *added* vectors can span
the image — and they do. Those images are also independent: any relation
among them pulls back to a combination landing in the kernel, which the full
basis's independence forces to be trivial. So they form a basis of the image,
giving rank $=$ $\dim V$ minus nullity. Full version: Theorem 4.1 above.

**Theorem 4.2 — key trick: rank-nullity ties injective and surjective
together, and an inverse map delivers both at once.**
By Lemma 4.1, injective means zero nullity, which by rank-nullity means full
rank, which — since the dimensions are equal — means the image fills the
codomain, i.e. surjective; and every step reverses, so injective and
surjective are equivalent here. An inverse map forces both injectivity and
surjectivity directly; conversely, a bijection's set-theoretic inverse turns
out to be linear, so it is a genuine inverse. Full version: Theorem 4.2
above.

### If you remember only 3 things

1. Injective $\iff$ $\ker T = \{0\}$ — check one set, not all pairs of
   inputs.
2. Rank-nullity: $\dim(\ker T) + \dim(\operatorname{im} T) = \dim V$. Know
   either piece plus the domain, and the other comes for free.
3. Equal finite dimensions: injective, surjective, invertible collapse into
   one property — and you can never grow or shrink dimension linearly (no
   injection into a smaller space, no surjection onto a bigger one).

## Journal template

```
## Day 4 — Invertibility, rank-nullity
Key theorem in my own words: ...
What confused me: ...
```
