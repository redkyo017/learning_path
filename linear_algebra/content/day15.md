# Day 15 — Orthogonal Complements, Gram-Schmidt

## Learning objectives

By the end of today you should be able to:
- Define the orthogonal complement $W^\perp$ of a subspace $W$, and an
  orthonormal set/basis, precisely.
- State and reproduce, from scratch, the complete proof that
  $V = W \oplus W^\perp$ for a finite-dimensional inner product space $V$.
- State and reproduce, from scratch, the complete proof that the
  Gram-Schmidt process turns any basis into an orthonormal basis of the same
  span, including the intermediate-span property at every step $k$.
- Run Gram-Schmidt by hand on a small basis and verify the result is
  orthonormal by direct computation.
- Find $W^\perp$ explicitly for a subspace of $\mathbb{R}^3$ and verify the
  dimension count $\dim W + \dim W^\perp = \dim V$.

## Reference material

- Primer: there is no single dedicated 3Blue1Brown video for Gram-Schmidt
  specifically. Instead, before reading the theory below, spend 10 minutes
  sketching by hand: draw two non-orthogonal vectors $v_1, v_2$ in the plane,
  then draw the projection of $v_2$ onto the line through $v_1$, and draw
  $v_2$ minus that projection. Look at the picture until it's obvious *why*
  the leftover piece is perpendicular to $v_1$ — that picture is the entire
  content of today's Theorem 15.2, and everything below is just that picture
  made algebraic and extended to more vectors.
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §5.3–5.4 —
  [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf).
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  Inner Product Spaces chapter, the problems on orthogonal complements and
  the Gram-Schmidt process — if you don't have a copy, the exercises below
  are self-contained and sufficient for today.

Notation carries over unchanged from Day 14: $\langle u, v \rangle$ for the
inner product, $\|v\| = \sqrt{\langle v, v\rangle}$ for the norm, and every
inner product below is real, symmetric ($\langle u,v\rangle = \langle
v,u\rangle$), bilinear (linear in each argument separately), and
positive-definite ($\langle v,v\rangle \ge 0$, with equality iff $v = 0$).

## Theory

Throughout, $V$ is a finite-dimensional real inner product space and $W
\subseteq V$ is a subspace.

### Definition 15.1 (Orthogonal complement)

The **orthogonal complement** of $W$ is
$$W^\perp = \{v \in V : \langle v, w\rangle = 0 \text{ for all } w \in W\}.$$

### Lemma 15.1 ($W^\perp$ is a subspace)

$W^\perp$ is a subspace of $V$.

**Proof.** *Contains 0.* $\langle 0, w\rangle = \langle 0\cdot 0, w \rangle =
0 \cdot \langle 0, w\rangle = 0$ for every $w \in W$ (using bilinearity), so
$0 \in W^\perp$.

*Closed under addition.* Let $u_1, u_2 \in W^\perp$ and $w \in W$ arbitrary.
Then $\langle u_1 + u_2, w\rangle = \langle u_1, w\rangle + \langle u_2,
w\rangle = 0 + 0 = 0$ (bilinearity, then the defining property of $u_1, u_2
\in W^\perp$). Since $w \in W$ was arbitrary, $u_1 + u_2 \in W^\perp$.

*Closed under scalar multiplication.* Let $u \in W^\perp$, $c \in
\mathbb{R}$, $w \in W$ arbitrary. Then $\langle cu, w\rangle = c\langle u,
w\rangle = c \cdot 0 = 0$. So $cu \in W^\perp$. $\blacksquare$

### Definition 15.2 (Orthonormal set, orthonormal basis)

A finite set of vectors $\{e_1, \dots, e_k\} \subseteq V$ is **orthonormal**
if $\langle e_i, e_j \rangle = \delta_{ij}$ for all $i, j$ — that is,
$\langle e_i, e_j\rangle = 0$ whenever $i \neq j$, and $\|e_i\| = 1$ for
every $i$. An orthonormal set that is also a basis of $V$ (or of a subspace
$W \subseteq V$) is called an **orthonormal basis**.

### Theorem 15.1 (Orthogonal decomposition: $V = W \oplus W^\perp$)

For a finite-dimensional inner product space $V$ and subspace $W \subseteq
V$, every $v \in V$ can be written **uniquely** as $v = w + w'$ with $w \in
W$ and $w' \in W^\perp$. (We write $V = W \oplus W^\perp$ for this.)

**Proof.**

*Existence.* If $W = \{0\}$, the claim is trivial: $v = 0 + v$, with $0 \in
W$ and $v \in W^\perp$ (since $\langle v, 0\rangle = 0$ trivially, every
vector is orthogonal to the only element of $W$). So assume $\dim W = k \ge
1$ and let $v_1, \dots, v_k$ be any basis of $W$. Apply the Gram-Schmidt
process (Theorem 15.2 below) to $v_1, \dots, v_k$ to obtain an orthonormal
basis $e_1, \dots, e_k$ of $W$ (Theorem 15.2 guarantees this is possible and
that $\operatorname{span}\{e_1,\dots,e_k\} = \operatorname{span}\{v_1,\dots,
v_k\} = W$).

Given an arbitrary $v \in V$, define
$$w = \sum_{i=1}^{k} \langle v, e_i\rangle e_i, \qquad w' = v - w.$$
Since $w$ is a linear combination of the basis vectors $e_1,\dots,e_k$ of
$W$, $w \in W$. We must show $w' \in W^\perp$, i.e. $\langle w', u\rangle =
0$ for **every** $u \in W$. Since $\{e_1,\dots,e_k\}$ is a basis of $W$,
every $u \in W$ is $u = \sum_j c_j e_j$ for some scalars $c_j$, so by
bilinearity it suffices to check $\langle w', e_j\rangle = 0$ for each $j =
1,\dots,k$ — then $\langle w', u\rangle = \sum_j c_j \langle w', e_j\rangle =
\sum_j c_j \cdot 0 = 0$ follows immediately.

Fix $j$. Compute, using bilinearity and $\langle e_i, e_j\rangle =
\delta_{ij}$:
$$\langle w', e_j\rangle = \Big\langle v - \sum_{i=1}^k \langle v,
e_i\rangle e_i,\ e_j\Big\rangle = \langle v, e_j\rangle - \sum_{i=1}^k
\langle v, e_i\rangle \langle e_i, e_j\rangle = \langle v, e_j\rangle -
\langle v, e_j\rangle \cdot 1 = 0,$$
since in the sum $\sum_i \langle v,e_i\rangle\langle e_i,e_j\rangle$, every
term with $i \neq j$ vanishes ($\langle e_i,e_j\rangle = 0$) and the single
surviving term at $i=j$ is $\langle v,e_j\rangle \cdot \langle e_j,e_j\rangle
= \langle v,e_j\rangle \cdot 1$. So $\langle w', e_j\rangle = 0$ for every
$j$, hence $w' \in W^\perp$ by the argument above. This proves $v = w + w'$
with $w \in W$, $w' \in W^\perp$: existence of the decomposition.

*Uniqueness.* Suppose $v = w_1 + w_1' = w_2 + w_2'$ with $w_1, w_2 \in W$
and $w_1', w_2' \in W^\perp$. Rearranging,
$$w_1 - w_2 = w_2' - w_1'.$$
The left side lies in $W$ (a subspace, closed under subtraction), and the
right side lies in $W^\perp$ (a subspace by Lemma 15.1, closed under
subtraction). Since the two sides are equal, this common vector lies in $W
\cap W^\perp$.

We claim $W \cap W^\perp = \{0\}$. Let $x \in W \cap W^\perp$. Since $x \in
W^\perp$, $x$ is orthogonal to *every* vector in $W$; since also $x \in W$,
in particular $x$ is orthogonal to itself: $\langle x, x\rangle = 0$. By
positive-definiteness of the inner product, $\langle x,x\rangle = 0
\implies x = 0$. So $W \cap W^\perp \subseteq \{0\}$, and $0$ is trivially
in both (both are subspaces), so $W \cap W^\perp = \{0\}$.

Therefore $w_1 - w_2 = w_2' - w_1' \in W \cap W^\perp = \{0\}$, forcing $w_1
- w_2 = 0$, i.e. $w_1 = w_2$. Then $w_1' = v - w_1 = v - w_2 = w_2'$ as well.
The decomposition $v = w + w'$ is unique. $\blacksquare$

### Theorem 15.2 (The Gram-Schmidt process)

Let $v_1, \dots, v_n$ be a basis of a subspace $U \subseteq V$ (or of $V$
itself). Define $u_1 = v_1$, and inductively for $k = 2, \dots, n$,
$$u_k = v_k - \sum_{i=1}^{k-1} \frac{\langle v_k, u_i\rangle}{\langle u_i,
u_i\rangle} u_i.$$
Then for every $k = 1, \dots, n$:

(a) $u_k \neq 0$;

(b) $u_1, \dots, u_k$ are pairwise orthogonal: $\langle u_i, u_j\rangle = 0$
for all $1 \le i < j \le k$;

(c) $\operatorname{span}\{u_1,\dots,u_k\} = \operatorname{span}\{v_1,\dots,
v_k\}$.

Consequently, setting $e_i = u_i / \|u_i\|$ for $i=1,\dots,n$,
$\{e_1,\dots,e_n\}$ is an orthonormal basis of $U =
\operatorname{span}\{v_1,\dots,v_n\}$.

**Proof.** We prove (a), (b), (c) together by induction on $k$.

*Base case $k=1$.* $u_1 = v_1$. Since $v_1$ is part of a basis, $v_1 \neq
0$, so $u_1 \neq 0$: (a) holds. There is nothing to check for (b) (only one
vector). For (c), $\operatorname{span}\{u_1\} = \operatorname{span}\{v_1\}$
trivially since $u_1 = v_1$.

*Inductive step.* Fix $k \ge 2$ and assume (a), (b), (c) hold for $1,\dots,
k-1$: that is, $u_1,\dots,u_{k-1}$ are all nonzero, pairwise orthogonal, and
$$U_{k-1} := \operatorname{span}\{u_1,\dots,u_{k-1}\} =
\operatorname{span}\{v_1,\dots,v_{k-1}\}.$$
We show (a), (b), (c) hold for $k$.

*Well-defined.* Since $u_i \neq 0$ for $i < k$ (induction hypothesis),
$\langle u_i, u_i\rangle = \|u_i\|^2 \neq 0$ (positive-definiteness), so
every term $\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle}u_i$ is
well-defined and so is $u_k$.

*(c) Span equality.* By construction,
$$u_k = v_k - c, \qquad \text{where } c = \sum_{i=1}^{k-1}
\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle}u_i \in U_{k-1} =
\operatorname{span}\{v_1,\dots,v_{k-1}\}.$$
So $u_k$ is $v_k$ minus a linear combination of $v_1,\dots,v_{k-1}$, hence
$u_k \in \operatorname{span}\{v_1,\dots,v_k\}$. Also $u_1,\dots,u_{k-1} \in
U_{k-1} \subseteq \operatorname{span}\{v_1,\dots,v_k\}$. So every $u_i$ for
$i \le k$ lies in $\operatorname{span}\{v_1,\dots,v_k\}$, giving
$\operatorname{span}\{u_1,\dots,u_k\} \subseteq
\operatorname{span}\{v_1,\dots,v_k\}$.

Conversely, $v_k = u_k + c$ with $c \in U_{k-1} =
\operatorname{span}\{u_1,\dots,u_{k-1}\}$, so $v_k \in
\operatorname{span}\{u_1,\dots,u_k\}$; and $v_1,\dots,v_{k-1} \in U_{k-1}
\subseteq \operatorname{span}\{u_1,\dots,u_k\}$. So every $v_i$ for $i \le
k$ lies in $\operatorname{span}\{u_1,\dots,u_k\}$, giving
$\operatorname{span}\{v_1,\dots,v_k\} \subseteq
\operatorname{span}\{u_1,\dots,u_k\}$.

Both inclusions give $\operatorname{span}\{u_1,\dots,u_k\} =
\operatorname{span}\{v_1,\dots,v_k\}$: (c) holds for $k$.

*(a) Nonzero.* Suppose, for contradiction, $u_k = 0$. Then $v_k = c \in
\operatorname{span}\{v_1,\dots,v_{k-1}\}$ (using $c \in
\operatorname{span}\{v_1,\dots,v_{k-1}\}$ shown above). But then $v_k$ is a
linear combination of $v_1,\dots,v_{k-1}$, contradicting linear independence
of $v_1,\dots,v_n$ (they form a basis). So $u_k \neq 0$: (a) holds for $k$.

*(b) Orthogonality.* Fix $j < k$. Using bilinearity,
$$\langle u_k, u_j\rangle = \Big\langle v_k - \sum_{i=1}^{k-1}
\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle}u_i,\ u_j\Big\rangle =
\langle v_k, u_j\rangle - \sum_{i=1}^{k-1} \frac{\langle v_k,u_i\rangle}
{\langle u_i,u_i\rangle}\langle u_i, u_j\rangle.$$
By the induction hypothesis, $u_1,\dots,u_{k-1}$ are pairwise orthogonal, so
$\langle u_i,u_j\rangle = 0$ for every $i < k$ with $i \neq j$; the only
surviving term in the sum is $i=j$:
$$\langle u_k, u_j\rangle = \langle v_k,u_j\rangle - \frac{\langle
v_k,u_j\rangle}{\langle u_j,u_j\rangle}\langle u_j,u_j\rangle = \langle
v_k,u_j\rangle - \langle v_k,u_j\rangle = 0.$$
So $u_k$ is orthogonal to every $u_j$ with $j < k$; combined with the
induction hypothesis that $u_1,\dots,u_{k-1}$ are pairwise orthogonal,
$u_1,\dots,u_k$ are pairwise orthogonal: (b) holds for $k$.

By induction, (a), (b), (c) hold for every $k = 1,\dots,n$; in particular at
$k=n$, $u_1,\dots,u_n$ are nonzero and pairwise orthogonal, with
$\operatorname{span}\{u_1,\dots,u_n\} = \operatorname{span}\{v_1,\dots,
v_n\} = U$.

*Orthonormal basis.* Set $e_i = u_i/\|u_i\|$ (valid since $u_i \neq 0$).
Then $\|e_i\| = 1$ for each $i$, and for $i \neq j$, $\langle e_i,e_j\rangle
= \frac{\langle u_i,u_j\rangle}{\|u_i\|\|u_j\|} = 0$ since $\langle
u_i,u_j\rangle = 0$. So $\{e_1,\dots,e_n\}$ is orthonormal. Rescaling each
$u_i$ by the positive scalar $1/\|u_i\|$ does not change the span of a
single vector, so $\operatorname{span}\{e_1,\dots,e_n\} =
\operatorname{span}\{u_1,\dots,u_n\} = U$.

Finally, an orthonormal set is automatically linearly independent: if
$\sum_{i=1}^n c_i e_i = 0$, take the inner product of both sides with $e_j$:
$0 = \langle \sum_i c_ie_i, e_j\rangle = \sum_i c_i \langle e_i,e_j\rangle =
c_j$, for every $j$, so all $c_j = 0$. Hence $\{e_1,\dots,e_n\}$ is a
linearly independent spanning set of $U$ with $n = \dim U$ vectors, i.e. an
orthonormal basis of $U$. $\blacksquare$

## Worked example

Run Gram-Schmidt on $v_1 = (1,1,0)$, $v_2 = (1,0,1)$, $v_3 = (0,1,1)$ in
$\mathbb{R}^3$.

**Step 1.** $u_1 = v_1 = (1,1,0)$.

**Step 2.** $\langle v_2, u_1\rangle = 1\cdot1 + 0\cdot1 + 1\cdot0 = 1$,
$\langle u_1,u_1\rangle = 1+1+0 = 2$, so the coefficient is $1/2$:
$$u_2 = v_2 - \tfrac12 u_1 = (1,0,1) - (0.5,0.5,0) = (0.5,\,-0.5,\,1).$$

**Step 3.** $\langle v_3,u_1\rangle = 0\cdot1+1\cdot1+1\cdot0 = 1$, so the
first coefficient is $1/2$, giving the term $(0.5,0.5,0)$.
$\langle v_3,u_2\rangle = 0\cdot0.5+1\cdot(-0.5)+1\cdot1 = 0.5$, $\langle
u_2,u_2\rangle = 0.25+0.25+1=1.5$, so the second coefficient is $0.5/1.5 =
1/3$, giving the term $\tfrac13(0.5,-0.5,1) = (1/6,\,-1/6,\,1/3)$.
$$u_3 = v_3 - (0.5,0.5,0) - (1/6,-1/6,1/3) = (0,1,1) - (0.5,0.5,0) -
(1/6,-1/6,1/3).$$
Coordinate by coordinate: $0 - 0.5 - 1/6 = -2/3$; $1 - 0.5 + 1/6 = 2/3$;
$1 - 0 - 1/3 = 2/3$. So $u_3 = (-2/3,\, 2/3,\, 2/3)$.

**Normalize.** $\|u_1\| = \sqrt{2}$, $\|u_2\| = \sqrt{1.5} = \sqrt{6}/2$,
$\|u_3\| = \sqrt{4/9+4/9+4/9} = \sqrt{4/3} = 2/\sqrt3$.
$$e_1 = \frac{(1,1,0)}{\sqrt2}, \qquad e_2 = \frac{(1,-1,2)}{\sqrt6}, \qquad
e_3 = \frac{(-1,1,1)}{\sqrt3}.$$
(For $e_2$: $u_2 = (0.5,-0.5,1)$ scaled by $2$ is $(1,-1,2)$, and $2\|u_2\| =
2\sqrt{1.5} = \sqrt6$, so $e_2 = (1,-1,2)/\sqrt6$. Similarly for $e_3$:
$u_3 \cdot 3/2 = (-1,1,1)$ and $\|u_3\|\cdot 3/2 = \sqrt3$.)

**Verify orthonormality.** Pairwise inner products (using the un-normalized
numerator vectors — a common denominator is always positive, so it doesn't
affect whether the product is zero):
$$(1,1,0)\cdot(1,-1,2) = 1-1+0 = 0, \quad (1,1,0)\cdot(-1,1,1) = -1+1+0=0,
\quad (1,-1,2)\cdot(-1,1,1) = -1-1+2=0.$$
All three pairwise products vanish. Norms:
$$\|e_1\|^2 = \frac{1^2+1^2}{2} = 1, \quad \|e_2\|^2 =
\frac{1^2+(-1)^2+2^2}{6} = \frac{6}{6}=1, \quad \|e_3\|^2 =
\frac{(-1)^2+1^2+1^2}{3} = \frac{3}{3}=1.$$
All three norms equal 1. So $\{e_1,e_2,e_3\}$ is genuinely orthonormal, and
by Theorem 15.2, an orthonormal basis of $\mathbb{R}^3$ (it's 3 linearly
independent vectors — guaranteed by orthonormality — in a 3-dimensional
space).

## Unconventional edge

It's entirely possible to memorize $u_k = v_k - \sum_{i<k}
\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle} u_i$ as symbol
manipulation — "dot product over dot product times vector, subtract it off"
— without ever seeing *why* that particular quantity is subtracted. The
reason is that $\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle}u_i$ is
exactly the projection of $v_k$ onto the line through $u_i$: it is the
"amount of $v_k$ that already points in the $u_i$ direction," i.e. the part
of $v_k$ already *explained* by a direction you've already accounted for.
Subtracting it off, one already-explained direction at a time, is what
forces what's left ($u_k$) to be orthogonal to everything before it — not a
coincidence to verify by computation each time, but the entire point of the
subtraction. This exact move — "subtract off what's already explained by
directions you've already fixed, and see whether anything meaningful
remains in the residual" — reappears almost unchanged as the residual in
orthogonal regression (Day 16) and is the computational engine behind
deriving the QR decomposition (Day 17); if Gram-Schmidt still feels like
rote formula-following rather than "removing the already-accounted-for
part," that's worth resolving now rather than re-deriving the same
confusion twice more.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–3 are Gram-Schmidt computations; 4–5 find $W^\perp$
explicitly; 6–8 are proof-based; 9 is a conceptual "explain in your own
words" problem; 10 is a synthesis problem tying Theorem 15.1 to explicit
numbers.

1. Run Gram-Schmidt by hand on $v_1 = (1,0,0)$, $v_2 = (1,1,0)$, $v_3 =
   (1,1,1)$ in $\mathbb{R}^3$. Show every step.
2. Run Gram-Schmidt by hand on $v_1 = (1,1,0,0)$, $v_2 = (1,0,1,0)$, $v_3 =
   (1,0,0,1)$ in $\mathbb{R}^4$. Show every step.
3. Verify orthonormality of your answer to Exercise 2 by computing all
   three pairwise inner products and all three norms explicitly.
4. Let $W = \{(x,y,z) \in \mathbb{R}^3 : x+y+z = 0\}$ (a plane through the
   origin). Find $W^\perp$ explicitly, and verify $\dim W + \dim W^\perp =
   \dim \mathbb{R}^3$.
5. Let $W = \operatorname{span}\{(1,2,2)\}$ (a line through the origin in
   $\mathbb{R}^3$). Find $W^\perp$ explicitly (give a basis), and verify
   $\dim W + \dim W^\perp = \dim \mathbb{R}^3$.
6. Prove: for a finite-dimensional subspace $W$ of a finite-dimensional
   inner product space $V$, $(W^\perp)^\perp = W$.
7. **Trap.** Is $W \cap W^\perp$ always exactly $\{0\}$, for every subspace
   $W$ of every (real, positive-definite) inner product space? Prove your
   answer using positive-definiteness of the inner product, and say in one
   sentence what property of the inner product the argument actually uses
   (would it still work for a symmetric bilinear form that is *not*
   positive-definite?).
8. Prove: any orthonormal set $\{e_1,\dots,e_k\}$ is linearly independent.
   (This fact was used inside the proof of Theorem 15.2 — prove it here on
   its own.)
9. In 2–4 sentences: why does Gram-Schmidt guarantee
   $\operatorname{span}\{u_1,\dots,u_k\} = \operatorname{span}\{v_1,\dots,
   v_k\}$ for *every* intermediate $k$, not just at the final step $k=n$?
   Why is this stronger property useful (think ahead to what a $k$-th
   column of a matrix should depend on)?
10. Let $W = \operatorname{span}\{(1,1,0), (1,0,1)\}$, and let $e_1, e_2$ be
    the first two orthonormal vectors from the Worked Example (built from
    exactly these two spanning vectors of $W$). For $v = (1,2,3)$, compute
    $w = \langle v,e_1\rangle e_1 + \langle v,e_2\rangle e_2$ and $w' = v -
    w$, then verify directly that $w' \in W^\perp$ by checking it's
    orthogonal to both $(1,1,0)$ and $(1,0,1)$.

## Solutions

**1.** $u_1 = v_1 = (1,0,0)$.
$\langle v_2,u_1\rangle = 1$, $\langle u_1,u_1\rangle=1$, coefficient $1$:
$u_2 = (1,1,0) - (1,0,0) = (0,1,0)$.
$\langle v_3,u_1\rangle=1$ (coeff 1, term $(1,0,0)$); $\langle
v_3,u_2\rangle=1$ (coeff 1, term $(0,1,0)$):
$u_3 = (1,1,1) - (1,0,0) - (0,1,0) = (0,0,1)$.
All three already have norm 1, so $e_1=(1,0,0)$, $e_2=(0,1,0)$,
$e_3=(0,0,1)$ — the standard basis.

**2.** $u_1 = v_1 = (1,1,0,0)$, $\langle u_1,u_1\rangle = 2$.
$\langle v_2,u_1\rangle = 1$, coeff $1/2$:
$u_2 = (1,0,1,0) - (0.5,0.5,0,0) = (0.5,-0.5,1,0)$, $\langle u_2,u_2\rangle
= 1.5$.
$\langle v_3,u_1\rangle = 1$, coeff $1/2$, term $(0.5,0.5,0,0)$.
$\langle v_3,u_2\rangle = 1\cdot0.5+0\cdot(-0.5)+0\cdot1+1\cdot0 = 0.5$,
coeff $0.5/1.5=1/3$, term $\tfrac13(0.5,-0.5,1,0)=(1/6,-1/6,1/3,0)$.
$$u_3 = (1,0,0,1) - (0.5,0.5,0,0) - (1/6,-1/6,1/3,0) = (1/3,\,-1/3,\,-1/3,\,1).$$
Norms: $\|u_1\|=\sqrt2$, $\|u_2\|=\sqrt{1.5}=\sqrt6/2$, $\|u_3\| =
\sqrt{1/9+1/9+1/9+1} = \sqrt{4/3} = 2/\sqrt3$. So
$$e_1 = \frac{(1,1,0,0)}{\sqrt2}, \quad e_2 = \frac{(1,-1,2,0)}{\sqrt6},
\quad e_3 = \frac{(1,-1,-1,3)}{2\sqrt3}$$
(scaling $u_2$ by 2 gives $(1,-1,2,0)$ with $2\|u_2\|=\sqrt6$; scaling $u_3$
by 3 gives $(1,-1,-1,3)$ with $3\|u_3\| = 2\sqrt3$).

**3.** Using the numerator (un-normalized) vectors from Exercise 2 — a
positive common denominator never affects whether a dot product is zero:
$$(1,1,0,0)\cdot(1,-1,2,0) = 1-1+0+0=0,$$
$$(1,1,0,0)\cdot(1,-1,-1,3) = 1-1+0+0=0,$$
$$(1,-1,2,0)\cdot(1,-1,-1,3) = 1+1-2+0=0.$$
All three pairwise products vanish. Norms:
$$\|e_1\|^2 = \tfrac{1+1}{2}=1, \quad \|e_2\|^2=\tfrac{1+1+4}{6}=1, \quad
\|e_3\|^2 = \tfrac{1+1+1+9}{12}=1.$$
All three norms equal 1, confirming $\{e_1,e_2,e_3\}$ is orthonormal.

**4.** Let $n=(1,1,1)$. Every $w=(x,y,z)\in W$ satisfies $\langle w,n\rangle
= x+y+z=0$ by definition of $W$, so $n \in W^\perp$, giving
$\operatorname{span}\{n\} \subseteq W^\perp$. Now, $W$ is the kernel of the
nonzero linear functional $(x,y,z)\mapsto x+y+z$ on $\mathbb{R}^3$, whose
image is all of $\mathbb{R}$ (rank 1); by rank-nullity, $\dim W = 3-1=2$. By
Theorem 15.1, $\dim W + \dim W^\perp = \dim \mathbb{R}^3 = 3$, so $\dim
W^\perp = 3-2=1$. Since $\operatorname{span}\{n\} \subseteq W^\perp$ and
both have dimension 1, $W^\perp = \operatorname{span}\{(1,1,1)\}$. Check:
$\dim W + \dim W^\perp = 2+1=3=\dim \mathbb{R}^3$ ✓.

**5.** $v=(x,y,z) \in W^\perp \iff \langle v,(1,2,2)\rangle = 0 \iff
x+2y+2z=0$. Solving: $x=-2y-2z$ with $y,z$ free, giving basis vectors (set
$y=1,z=0$, then $y=0,z=1$): $(-2,1,0)$ and $(-2,0,1)$. So $W^\perp =
\operatorname{span}\{(-2,1,0),(-2,0,1)\}$, and these two vectors are not
scalar multiples of each other, so $\dim W^\perp = 2$. Check: $\dim W +
\dim W^\perp = 1+2=3=\dim\mathbb{R}^3$ ✓.

**6.** *($W \subseteq (W^\perp)^\perp$):* let $w \in W$. For every $u \in
W^\perp$, by definition of $W^\perp$, $\langle u, w\rangle = 0$ (since $w
\in W$), and by symmetry $\langle w, u\rangle = 0$ too. Since this holds for
every $u \in W^\perp$, $w$ satisfies the defining condition of
$(W^\perp)^\perp$, i.e. $w \in (W^\perp)^\perp$. So $W \subseteq
(W^\perp)^\perp$.

*(Dimension count):* Applying Theorem 15.1 to $W$: $\dim V = \dim W + \dim
W^\perp$. Applying Theorem 15.1 to the subspace $W^\perp$ in place of $W$:
$\dim V = \dim W^\perp + \dim (W^\perp)^\perp$. The left sides are equal, so
$\dim W + \dim W^\perp = \dim W^\perp + \dim(W^\perp)^\perp$, hence $\dim W
= \dim (W^\perp)^\perp$.

Since $W \subseteq (W^\perp)^\perp$ and these two subspaces of the
finite-dimensional space $V$ have the same (finite) dimension, they are
equal: if $W$ were a proper subset of $(W^\perp)^\perp$, any basis of $W$
could be extended to a strictly larger linearly independent set inside
$(W^\perp)^\perp$, forcing $\dim(W^\perp)^\perp > \dim W$, contradicting
what we just showed. So $W = (W^\perp)^\perp$. $\blacksquare$

**7.** Yes, always. Let $x \in W \cap W^\perp$. Since $x \in W^\perp$, $x$
is orthogonal to every vector of $W$; since also $x \in W$, in particular
$x$ is orthogonal to itself: $\langle x,x\rangle = 0$. By
positive-definiteness of the inner product ($\langle x,x\rangle = 0
\implies x=0$), $x = 0$. Since $0$ is trivially in both $W$ and $W^\perp$,
$W \cap W^\perp = \{0\}$ for every subspace $W$ — this is forced by
positive-definiteness alone, not something that needs re-checking case by
case (it's exactly the fact used to prove uniqueness in Theorem 15.1). The
argument uses *only* positive-definiteness ($\langle x,x\rangle=0 \implies
x=0$), nothing else about the specific inner product; it would **not** work
for a symmetric bilinear form that isn't positive-definite, since such a
form can have nonzero "self-orthogonal" (null) vectors with $\langle
x,x\rangle=0$ but $x \neq 0$ — this is exactly what happens with the
Minkowski form in special relativity, where light-like vectors are
self-orthogonal and nonzero.

**8.** Suppose $\{e_1,\dots,e_k\}$ is orthonormal ($\langle
e_i,e_j\rangle=\delta_{ij}$) and $c_1e_1+\cdots+c_ke_k = 0$. Fix any $j \in
\{1,\dots,k\}$ and take the inner product of both sides with $e_j$:
$$0 = \langle 0, e_j\rangle = \Big\langle \sum_{i=1}^k c_ie_i,\
e_j\Big\rangle = \sum_{i=1}^k c_i \langle e_i,e_j\rangle = c_j\langle
e_j,e_j\rangle = c_j \cdot 1 = c_j,$$
using bilinearity and that every term with $i \ne j$ vanishes while the
$i=j$ term is $c_j \cdot 1$. Since $j$ was arbitrary, $c_j = 0$ for every
$j = 1,\dots,k$: the only linear combination of $e_1,\dots,e_k$ equal to $0$
is the trivial one, so $\{e_1,\dots,e_k\}$ is linearly independent.
$\blacksquare$

**9.** Each $u_k$ is built only from $v_k$ and $u_1,\dots,u_{k-1}$ — the
formula never references $v_{k+1},\dots,v_n$. So Gram-Schmidt doesn't just
happen to produce a final orthonormal basis for the whole span; it produces
a whole nested chain of orthonormal bases, one for every intermediate
subspace $\operatorname{span}\{v_1,\dots,v_k\}$, "for free," in one pass.
This matters because it means the $k$-th orthonormal vector depends only on
the first $k$ original vectors, never on later ones — exactly the property
needed for QR decomposition (Day 17), where the $k$-th column of $Q$ must
be computable from only the first $k$ columns of the original matrix.

**10.** From the Worked Example, $e_1 = (1,1,0)/\sqrt2$, $e_2 =
(1,-1,2)/\sqrt6$ (these came from Gram-Schmidt applied to exactly $v_1,v_2$
— by Exercise 9's property, they don't depend on $v_3$, so they're valid to
reuse here unchanged).
$$\langle v,e_1\rangle = \frac{1\cdot1+2\cdot1+3\cdot0}{\sqrt2} =
\frac{3}{\sqrt2}, \qquad \langle v,e_2\rangle =
\frac{1\cdot1+2\cdot(-1)+3\cdot2}{\sqrt6} = \frac{5}{\sqrt6}.$$
$$w = \frac{3}{\sqrt2}\cdot\frac{(1,1,0)}{\sqrt2} +
\frac{5}{\sqrt6}\cdot\frac{(1,-1,2)}{\sqrt6} = \frac{3(1,1,0)}{2} +
\frac{5(1,-1,2)}{6} = (1.5,1.5,0) + (5/6,-5/6,5/3).$$
Adding coordinate-wise: $1.5+5/6 = 9/6+5/6=14/6=7/3$; $1.5-5/6 =
9/6-5/6=4/6=2/3$; $0+5/3=5/3$. So $w = (7/3,\,2/3,\,5/3)$, and
$$w' = v - w = (1-7/3,\ 2-2/3,\ 3-5/3) = (-4/3,\ 4/3,\ 4/3).$$
**Check orthogonality:** $w'\cdot(1,1,0) = -4/3+4/3+0=0$ ✓, and $w'\cdot
(1,0,1) = -4/3+0+4/3=0$ ✓. Since $w'$ is orthogonal to both spanning
vectors of $W$, it's orthogonal to every linear combination of them, i.e.
$w' \in W^\perp$ — a direct, numerical confirmation of Theorem 15.1's
decomposition $v = w+w'$ for this specific $v$ and $W$. (As a bonus check,
$w=(7/3,2/3,5/3)$ does satisfy $x=y+z$, i.e. $7/3=2/3+5/3$, confirming
$w \in W$.)

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements the Gram-Schmidt process numerically. Open
`starter_code/day15_gram_schmidt.py` — it has one function to complete,
`gram_schmidt`. Fill in the `TODO`, then run the file directly
(`python starter_code/day15_gram_schmidt.py`); it should print two lines
confirming $Q^TQ = I$ and that your $Q$ matches (up to column sign)
`numpy.linalg.qr`'s $Q$ on the same vectors — the exact vectors from
today's Worked Example.

**Hint:** build up a list `basis` of orthogonal (not yet normalized)
vectors one at a time: for each new vector $v$, subtract its projection
onto every vector already in `basis` (this is the sum in the definition of
$u_k$ in Theorem 15.2, done incrementally), then append the result. At the
end, normalize each vector in `basis` and stack as columns — this is the
direct numerical translation of the by-hand computation in the Worked
Example.

If you get stuck for more than ~10 minutes, check
`solutions/day15_gram_schmidt.py` — but only after a real attempt.

Once your implementation passes, extend it: run your `gram_schmidt` on your
answer to Exercise 2 (the $\mathbb{R}^4$ basis) and confirm the columns of
$Q$ match your hand computation from Exercise 2/3 (up to sign), the same
way the file already checks the Worked Example against `numpy.linalg.qr`.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $W^\perp$ | "$W$-perp — the orthogonal complement of $W$" | every vector orthogonal to all of $W$ |
| $V = W \oplus W^\perp$ | "$V$ splits as $W$ direct-sum its complement" | every $v$ is uniquely $w + w'$ with $w \in W$, $w' \in W^\perp$ |
| $\delta_{ij}$ | "Kronecker delta: $1$ if $i=j$, else $0$" | the defining condition $\langle e_i,e_j\rangle = \delta_{ij}$ of an orthonormal set |
| $u_k = v_k - \sum_{i<k}\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle}u_i$ | "next vector minus its projections onto the earlier ones" | the Gram-Schmidt step |
| $\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle}u_i$ | "the projection of $v_k$ onto $u_i$" | the part of $v_k$ already pointing along $u_i$ |
| $e_i = u_i / \Vert u_i\Vert$ | "$u_i$ rescaled to unit length" | normalizing to turn orthogonal into orthonormal |
| $(W^\perp)^\perp$ | "the complement of the complement" | equals $W$ again |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- The orthogonal complement $W^\perp$ collects every vector perpendicular to
  all of $W$, and it is itself a subspace.
- Orthogonal decomposition: in a finite-dimensional inner product space every
  vector splits *uniquely* as a part in $W$ plus a part in $W^\perp$ ($V = W
  \oplus W^\perp$), so $\dim W + \dim W^\perp = \dim V$.
- Gram-Schmidt turns any basis into an orthonormal one spanning the same
  space, by subtracting off each new vector's projections onto the directions
  already fixed.
- Crucially, Gram-Schmidt preserves every intermediate span: the first $k$
  orthonormal vectors span the same space as the first $k$ originals — the
  property QR later leans on.

### Proof sketches

**Lemma 15.1 — key trick: orthogonality to a fixed $w$ is a linear
condition, so it survives addition and scaling.**
First, $0 \in W^\perp$ since $\langle 0, w\rangle = 0$. If $u_1, u_2$ are each
orthogonal to every $w \in W$, bilinearity gives $\langle u_1 + u_2, w\rangle
= 0 + 0 = 0$, and $\langle cu, w\rangle = c\cdot 0 = 0$. So $W^\perp$ contains
$0$ and is closed under addition and scalar multiplication — a subspace. Full
version: Lemma 15.1 above.

**Theorem 15.1 — key trick: project $v$ onto an orthonormal basis of $W$;
what is left is automatically perpendicular to $W$, and $W \cap W^\perp =
\{0\}$ forces uniqueness.**
Gram-Schmidt gives an orthonormal basis $e_1,\dots,e_k$ of $W$; set $w =
\sum_i \langle v, e_i\rangle e_i$ and $w' = v - w$. Checking $\langle w',
e_j\rangle$, orthonormality collapses the sum to one term and it cancels, so
$w' \perp$ every $e_j$, hence $w' \in W^\perp$ — that is existence. For
uniqueness, two such decompositions would differ by a vector lying in both
$W$ and $W^\perp$; such a vector is orthogonal to itself, so
positive-definiteness makes it $0$. Full version: Theorem 15.1 above.

**Theorem 15.2 — key trick: at step $k$ you subtract exactly the projections
onto $u_1,\dots,u_{k-1}$, so each inner product $\langle u_k,u_j\rangle$
cancels term-by-term to zero.**
Induct on $k$. Since $u_k$ is $v_k$ minus a combination of the earlier $u_i$
(which span $\{v_1,\dots,v_{k-1}\}$), the spans $\{u_1,\dots,u_k\}$ and
$\{v_1,\dots,v_k\}$ agree, and $u_k \neq 0$ — otherwise $v_k$ would lie in the
earlier span, breaking independence. Computing $\langle u_k, u_j\rangle$ for
$j < k$, pairwise orthogonality of the earlier $u_i$ kills every term but
$i = j$, which is $\langle v_k,u_j\rangle - \frac{\langle
v_k,u_j\rangle}{\langle u_j,u_j\rangle}\langle u_j,u_j\rangle = 0$.
Normalizing $e_i = u_i/\|u_i\|$ then yields an orthonormal basis of the same
span. Full version: Theorem 15.2 above.

### If you remember only 3 things

1. $V = W \oplus W^\perp$: every vector splits uniquely into a $W$-part and a
   perpendicular part, and $\dim W + \dim W^\perp = \dim V$.
2. Gram-Schmidt = "subtract off what the earlier directions already explain";
   the leftover $u_k$ is orthogonal to all of them, then normalize to $e_k =
   u_k/\|u_k\|$.
3. It preserves every intermediate span — the first $k$ outputs use only the
   first $k$ inputs — which is exactly why QR (Day 17) works.

## Journal template

```
## Day 15 — Orthogonal complements, Gram-Schmidt
Key theorem in my own words: ...
What confused me: ...
```
