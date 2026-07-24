# Day 16 — Orthogonal Projections, Least Squares

## Learning objectives

By the end of today you should be able to:
- Define the orthogonal projection of a vector onto a subspace using an
  orthonormal basis, and compute it by hand (after Gram-Schmidt, if the
  given basis isn't already orthonormal).
- State and prove the Best Approximation Theorem: the orthogonal projection
  is the unique closest point in a subspace.
- Derive the normal equations $A^TA\hat x = A^Tb$ for the least-squares
  solution of an inconsistent system $Ax = b$, from the Best Approximation
  Theorem plus Day 6's fact that $C(A)^\perp = N(A^T)$.
- Fit a line to data by hand via least squares, and explain why "least
  squares" and "closest point in a subspace" are the same statement, not two
  different techniques.

## Reference material

- Primer (no dedicated video for this topic): before reading anything, grab
  paper and sketch a point off a line, and a point off a plane, and draw in
  the perpendicular dropped from the point to the line/plane by hand. That
  perpendicular foot *is* the orthogonal projection — today's entire theory
  section is the algebra of that one picture, generalized to $\mathbb{R}^n$
  and to subspaces you can't easily draw.
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §5.5
  (Orthogonal projection and Gram-Schmidt) — [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf).
- MIT OCW 18.06 (Strang) has two lectures directly on today's material:
  [Lecture 15: Projections onto subspaces](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/resources/lecture-15-projections-onto-subspaces/)
  and [Lecture 16: Projection matrices and least squares](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/resources/lecture-16-projection-matrices-and-least-squares/),
  both on the [18.06 Spring 2010 course page](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/).
  Watch these instead of a 3Blue1Brown clip today — they're short, worked
  examples of exactly the two theorems below, straight from the source that
  the "least squares = linear regression" application (§ Unconventional
  edge, below) is drawn from.
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  chapter on Inner Product Spaces / Orthogonality, plus the problem set
  attached to MIT 18.06 Lecture 16 above. As with prior days, the exercises
  below are self-contained if you don't have a copy.

## Theory

Throughout, $V$ is an inner product space (think $\mathbb{R}^n$ with the dot
product, as usual) and $W \subseteq V$ is a finite-dimensional subspace with
orthonormal basis $e_1, \dots, e_k$ (obtained, if necessary, by running
Gram-Schmidt on any basis of $W$ — Day 15). Recall from Day 15 that the
**orthogonal complement** of $W$ is $W^\perp = \{v \in V : \langle v, w
\rangle = 0 \text{ for all } w \in W\}$, itself a subspace, and that $v$
orthogonal to every vector of a *spanning* set for $W$ is automatically
orthogonal to every vector of $W$ (since inner products are linear in each
argument, orthogonality to $e_1,\dots,e_k$ extends to orthogonality to any
linear combination of them).

### Definition 16.1 (Orthogonal projection onto a subspace)

The **orthogonal projection** of $v \in V$ onto $W$ is
$$\operatorname{proj}_W(v) = \sum_{i=1}^k \langle v, e_i \rangle e_i.$$

This is manifestly a vector in $W$ (it's a linear combination of the
$e_i$'s). The definition looks like it depends on the choice of orthonormal
basis $e_1,\dots,e_k$; Theorem 16.1 below (specifically its uniqueness
clause) shows it does not — any orthonormal basis of $W$ produces the same
vector, because that vector is characterized by a basis-free property (being
the closest point of $W$ to $v$).

### Lemma 16.1 (Pythagorean theorem for orthogonal vectors)

If $a, b \in V$ and $\langle a, b \rangle = 0$, then
$\|a + b\|^2 = \|a\|^2 + \|b\|^2$.

**Proof.** Expand using bilinearity of the inner product:
$$\|a+b\|^2 = \langle a+b, a+b\rangle = \langle a,a\rangle + \langle a,b\rangle
+ \langle b,a\rangle + \langle b,b\rangle = \|a\|^2 + 2\langle a,b\rangle +
\|b\|^2.$$
Since $\langle a,b \rangle = 0$, this is $\|a\|^2 + \|b\|^2$. $\blacksquare$

### Lemma 16.2 (The projection residual is orthogonal to $W$)

For any $v \in V$, $v - \operatorname{proj}_W(v) \in W^\perp$.

**Proof.** It suffices to show $v - \operatorname{proj}_W(v)$ is orthogonal
to each basis vector $e_j$ ($j = 1,\dots,k$), since orthogonality to a
spanning set of $W$ gives orthogonality to all of $W$ (noted above). Compute,
using bilinearity and orthonormality of the $e_i$'s ($\langle e_i, e_j
\rangle = 1$ if $i=j$, $0$ otherwise):
$$\left\langle v - \sum_{i=1}^k \langle v,e_i\rangle e_i,\ e_j \right\rangle
= \langle v, e_j\rangle - \sum_{i=1}^k \langle v,e_i\rangle \langle e_i,e_j
\rangle = \langle v,e_j\rangle - \langle v,e_j\rangle = 0,$$
since only the $i=j$ term of the sum survives. This holds for every $j = 1,
\dots, k$, so $v - \operatorname{proj}_W(v) \in W^\perp$. $\blacksquare$

### Theorem 16.1 (Best Approximation Theorem)

For any $v \in V$, $\operatorname{proj}_W(v)$ is the unique point of $W$
closest to $v$: for every $w \in W$,
$$\|v - \operatorname{proj}_W(v)\| \le \|v - w\|,$$
with equality if and only if $w = \operatorname{proj}_W(v)$.

**Proof.** Write $p = \operatorname{proj}_W(v)$ for brevity, and for any $w
\in W$ decompose
$$v - w = (v - p) + (p - w).$$
The first term $v - p \in W^\perp$ by Lemma 16.2. The second term $p - w \in
W$, since $p \in W$ (Definition 16.1) and $w \in W$, and $W$ is a subspace
(closed under subtraction). Vectors in $W^\perp$ and $W$ are orthogonal to
each other by definition of $W^\perp$, so $\langle v-p,\ p-w\rangle = 0$.
Apply Lemma 16.1 with $a = v-p$, $b = p-w$:
$$\|v-w\|^2 = \|(v-p) + (p-w)\|^2 = \|v-p\|^2 + \|p-w\|^2.$$
Since $\|p-w\|^2 \ge 0$, this gives
$$\|v-w\|^2 \ge \|v-p\|^2,$$
and taking square roots (both sides nonnegative), $\|v-w\| \ge \|v-p\|$,
i.e. $\|v-p\| \le \|v-w\|$, proving the inequality.

*Equality case.* If $w = p$, then $\|v-w\| = \|v-p\|$ trivially, so equality
holds. Conversely, suppose $\|v-w\| = \|v-p\|$. Then $\|v-w\|^2 = \|v-p\|^2$,
and comparing with $\|v-w\|^2 = \|v-p\|^2 + \|p-w\|^2$ derived above forces
$\|p-w\|^2 = 0$, hence $p - w = 0$ (only the zero vector has zero norm, by
positive-definiteness of the inner product), i.e. $w = p$. So equality holds
if and only if $w = p = \operatorname{proj}_W(v)$. $\blacksquare$

Since $p = \operatorname{proj}_W(v)$ is shown here to be *the* unique
minimizer among all $w \in W$ — a property that doesn't reference $e_1,
\dots, e_k$ at all — this also confirms $\operatorname{proj}_W(v)$ doesn't
actually depend on which orthonormal basis of $W$ was used to compute it via
Definition 16.1: any orthonormal basis gives a formula for the *same*
uniquely-characterized vector.

### Theorem 16.2 (Normal equations for least squares)

Let $A$ be an $m \times n$ real matrix and $b \in \mathbb{R}^m$. A vector
$\hat x \in \mathbb{R}^n$ minimizes $\|Ax - b\|$ over all $x \in
\mathbb{R}^n$ if and only if $\hat x$ satisfies the **normal equations**
$$A^TA\hat x = A^Tb.$$

**Proof.** As $x$ ranges over $\mathbb{R}^n$, $Ax$ ranges exactly over
$C(A) = \{Ax : x \in \mathbb{R}^n\} \subseteq \mathbb{R}^m$ (Day 6,
Definition 6.1). So minimizing $\|Ax - b\|$ over $x \in \mathbb{R}^n$ is the
same problem as finding the point $w = Ax$ of $C(A)$ that minimizes $\|w -
b\|$ over $w \in C(A)$ — i.e. finding the closest point in the subspace
$C(A)$ to $b$.

By the Best Approximation Theorem (Theorem 16.1) applied with $W = C(A)$ and
$v = b$: the minimizing $w$ is unique and equals $\operatorname{proj}_{C(A)}(b)$,
characterized by $b - w \in C(A)^\perp$. So $\hat x$ minimizes $\|Ax-b\|$ if
and only if $A\hat x$ *is* this minimizing $w$, if and only if
$$b - A\hat x \in C(A)^\perp.$$
By Day 6 (foreshadowed in Definition 6.1 and confirmed on Day 15), $C(A)$
and $N(A^T)$ are orthogonal complements: $C(A)^\perp = N(A^T)$. So the
condition becomes
$$b - A\hat x \in N(A^T), \quad \text{i.e.} \quad A^T(b - A\hat x) = 0,$$
which rearranges to $A^Tb - A^TA\hat x = 0$, i.e.
$$A^TA\hat x = A^Tb. \qquad \blacksquare$$

**Remark.** Combining the two theorems: $A\hat x = \operatorname{proj}_{C(A)}(b)$
is always unique (Theorem 16.1's uniqueness clause, applied to $W = C(A)$),
even in cases (Exercise 9 below) where the coefficient vector $\hat x$ itself
is not. If the columns of $A$ happen to already be an orthonormal basis of
$C(A)$ (written $Q$ instead of $A$), then $Q^TQ = I$, the normal equations
collapse to $\hat x = Q^Tb$, and $Q\hat x = \sum_i \langle b, q_i\rangle q_i$
— exactly Definition 16.1 again, now written in matrix form. Day 17 picks
this observation up directly.

## Worked example

Fit a line $y = mx + b$ by least squares to the four data points $(0,1),
(1,3), (2,4), (3,8)$.

**Set up $Ax = y$.** Each data point $(x_i, y_i)$ should satisfy $mx_i + b =
y_i$; stacking all four as an (inconsistent, since 4 equations can't
generally be satisfied by 2 unknowns) linear system in the unknowns $x =
\binom{m}{b}$:
$$A = \begin{pmatrix} 0 & 1 \\ 1 & 1 \\ 2 & 1 \\ 3 & 1 \end{pmatrix}, \qquad
y = \begin{pmatrix}1\\3\\4\\8\end{pmatrix}.$$

**Form the normal equations $A^TA\,\hat x = A^Ty$.**
$$A^TA = \begin{pmatrix} 0+1+4+9 & 0+1+2+3 \\ 0+1+2+3 & 1+1+1+1 \end{pmatrix}
= \begin{pmatrix}14 & 6 \\ 6 & 4\end{pmatrix},$$
$$A^Ty = \begin{pmatrix} 0(1)+1(3)+2(4)+3(8) \\ 1+3+4+8 \end{pmatrix} =
\begin{pmatrix}35\\16\end{pmatrix}.$$
So the system for $\hat x = \binom{m}{b}$ is
$$14m + 6b = 35, \qquad 6m + 4b = 16.$$

**Solve by hand.** The second equation gives $3m + 2b = 8$, so $b =
\frac{8-3m}{2}$. Substitute into the first:
$$14m + 6\cdot\frac{8-3m}{2} = 35 \implies 14m + 3(8-3m) = 35 \implies 14m +
24 - 9m = 35 \implies 5m = 11 \implies m = \frac{11}{5} = 2.2.$$
Then $b = \frac{8 - 3(2.2)}{2} = \frac{8-6.6}{2} = \frac{1.4}{2} = 0.7$.

**So the least-squares line is $y = 2.2x + 0.7$.** As a sanity check, the
fitted values are $0.7,\ 2.9,\ 5.1,\ 7.3$ against actual $1, 3, 4, 8$; the
residuals $0.3,\ 0.1,\ -1.1,\ 0.7$ sum to exactly $0$ — not a coincidence,
since the residual $y - A\hat x$ must be orthogonal to every column of $A$
(Exercise 8), and the *second* column of $A$ here is all-ones, so
orthogonality to it means the residuals sum to zero whenever the model
includes an intercept.

## Unconventional edge

It's easy to come away from this topic having memorized "least squares
means solve $A^TA\hat x = A^Tb$" as a formula to plug $A$ and $b$ into,
without ever again thinking about *why*. That's the trap: if the normal
equations are just a recipe, you've thrown away the one fact that makes
this topic worth four hours of your life — that $\hat x$ minimizing
$\|Ax-b\|$ is nothing but a restatement of "$A\hat x$ is the closest point
in the subspace $C(A)$ to $b$," the exact same closest-point picture from
the Best Approximation Theorem, applied to a subspace you can't easily
sketch. Every time you fit a line, a plane, or a linear model with more
predictors, you are dropping a perpendicular from a data vector onto a
column space — literally the same operation as projecting a point onto a
line in $\mathbb{R}^3$, just in higher dimensions. This is exactly why
linear regression, the single most common technique in introductory machine
learning, is "just" an orthogonal projection under the hood, and it's the
whole reason this 30-day plan puts projections before any ML content:
once you see regression as projection, "why does adding a feature never
increase training error" and "why is $R^2$ related to the angle between
vectors" stop being separate facts to memorize and become consequences of
today's two theorems.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–6 are computational; 7, 8, 10 are proof-based; 9 is a
conceptual trap question.

1. Let $W = \operatorname{span}\{(1,0,0),(0,1,0)\} \subseteq \mathbb{R}^3$
   (the $xy$-plane; note this basis is already orthonormal). Compute
   $\operatorname{proj}_W(v)$ for $v = (3,-2,5)$, and compute the distance
   from $v$ to $W$.
2. Let $W = \operatorname{span}\{(3,4)\} \subseteq \mathbb{R}^2$ (a line;
   note $(3,4)$ is *not* a unit vector). Compute $\operatorname{proj}_W(v)$
   for $v = (1,7)$.
3. Let $W = \operatorname{span}\{(1,1,0),(0,1,1)\} \subseteq \mathbb{R}^3$.
   First find an orthonormal basis for $W$ by Gram-Schmidt (Day 15), then
   compute $\operatorname{proj}_W(v)$ for $v = (2,1,3)$.
4. Fit $y = mx+b$ by least squares to $(0,2), (1,2), (2,3), (3,5)$: set up
   $A$, form the normal equations, and solve for $m, b$ by hand.
5. Fit a line *through the origin*, $y = mx$ (no intercept), by least
   squares to $(1,2), (2,3), (3,7)$. (Hint: $A$ has a single column here, so
   the normal equations reduce to one equation in one unknown.)
6. Let $W = \operatorname{span}\{(1,1,1)\} \subseteq \mathbb{R}^3$. Find the
   point of $W$ closest to $v = (4,0,0)$, and compute the distance from $v$
   to $W$.
7. Prove: if $v \in W$, then $\operatorname{proj}_W(v) = v$. (Use
   Definition 16.1 and the fact that $e_1,\dots,e_k$ is a basis of $W$, so
   $v$ itself can be written as a linear combination of them.)
8. Prove, directly from the normal equations $A^TA\hat x = A^Tb$ (not by
   re-deriving from the Best Approximation Theorem), that the residual
   vector $b - A\hat x$ is orthogonal to every column of $A$.
9. **Conceptual trap.** Suppose the columns of $A$ are linearly dependent.
   Is the least-squares solution $\hat x$ to $A^TA\hat x = A^Tb$ still
   unique? Justify your answer using whether $A^TA$ is invertible (hint:
   show $N(A^TA) = N(A)$ by considering $x^TA^TAx = \|Ax\|^2$). Separately,
   is $A\hat x$ itself — the actual projection of $b$ onto $C(A)$ — unique,
   even when $\hat x$ isn't? Why doesn't this contradict your answer about
   $\hat x$?
10. Prove that $\operatorname{proj}_W$ is linear: for all $u, v \in V$ and
    scalars $a, b \in \mathbb{R}$,
    $\operatorname{proj}_W(au+bv) = a\operatorname{proj}_W(u) +
    b\operatorname{proj}_W(v)$.

## Solutions

**1.** The basis $(1,0,0), (0,1,0)$ is already orthonormal, so
$\operatorname{proj}_W(v) = \langle v,(1,0,0)\rangle(1,0,0) +
\langle v,(0,1,0)\rangle(0,1,0) = 3(1,0,0) + (-2)(0,1,0) = (3,-2,0)$.
Distance $= \|v - \operatorname{proj}_W(v)\| = \|(0,0,5)\| = 5$.

**2.** Normalize first: $e_1 = (3,4)/\|(3,4)\| = (3/5, 4/5)$ (since
$\|(3,4)\| = \sqrt{9+16}=5$). Then $\langle v, e_1\rangle = (1)(3/5) +
(7)(4/5) = 3/5 + 28/5 = 31/5$, so
$$\operatorname{proj}_W(v) = \frac{31}{5}\left(\frac35,\frac45\right) =
\left(\frac{93}{25}, \frac{124}{25}\right).$$

**3.** Gram-Schmidt on $u_1 = (1,1,0)$, $u_2 = (0,1,1)$: $e_1 = u_1/\|u_1\| =
(1,1,0)/\sqrt2$. Then $w = u_2 - \langle u_2,e_1\rangle e_1$; since
$\langle u_2, e_1\rangle = (0+1+0)/\sqrt2 = 1/\sqrt2$,
$$w = (0,1,1) - \frac{1}{\sqrt2}\cdot\frac{(1,1,0)}{\sqrt2} = (0,1,1) -
\tfrac12(1,1,0) = \left(-\tfrac12,\tfrac12,1\right),$$
with $\|w\| = \sqrt{\tfrac14+\tfrac14+1} = \sqrt{3/2} = \sqrt6/2$, so
$e_2 = w/\|w\| = (-1,1,2)/\sqrt6$.

Now project $v=(2,1,3)$: $\langle v,e_1\rangle = (2+1+0)/\sqrt2 = 3/\sqrt2$,
contributing $\frac{3}{\sqrt2}\cdot\frac{(1,1,0)}{\sqrt2} = \tfrac32(1,1,0) =
(3/2,3/2,0)$. And $\langle v,e_2\rangle = (-2+1+6)/\sqrt6 = 5/\sqrt6$,
contributing $\frac{5}{\sqrt6}\cdot\frac{(-1,1,2)}{\sqrt6} =
\tfrac56(-1,1,2) = (-5/6,5/6,5/3)$. Summing:
$$\operatorname{proj}_W(v) = \left(\frac32-\frac56,\ \frac32+\frac56,\
0+\frac53\right) = \left(\frac23, \frac73, \frac53\right).$$

**4.** $A = \begin{pmatrix}0&1\\1&1\\2&1\\3&1\end{pmatrix}$, $y =
(2,2,3,5)$. $A^TA = \begin{pmatrix}14&6\\6&4\end{pmatrix}$ (same $x$-values
as the worked example). $A^Ty = \begin{pmatrix}0(2)+1(2)+2(3)+3(5)\\
2+2+3+5\end{pmatrix} = \begin{pmatrix}23\\12\end{pmatrix}$. Normal
equations: $14m+6b=23$, $6m+4b=12 \implies 3m+2b=6 \implies
b=\frac{6-3m}{2}$. Substituting: $14m + 3(6-3m) = 23 \implies 14m+18-9m=23
\implies 5m=5 \implies m=1$, then $b = \frac{6-3}{2} = 1.5$. Fitted line:
$y = x + 1.5$. (Check: fitted values $1.5,2.5,3.5,4.5$ vs. actual
$2,2,3,5$; residuals $0.5,-0.5,-0.5,0.5$ sum to $0$ ✓.)

**5.** Here $A$ is the single column $(1,2,3)^T$, so the normal equation is
the scalar equation $(A^TA)m = A^Ty$, i.e. $\left(\sum x_i^2\right)m =
\sum x_iy_i$: $\ (1+4+9)m = 1(2)+2(3)+3(7) = 2+6+21=29 \implies 14m = 29
\implies m = \frac{29}{14}$.

**6.** Unit vector $e_1 = (1,1,1)/\sqrt3$. $\langle v,e_1\rangle =
(4+0+0)/\sqrt3 = 4/\sqrt3$, so the closest point is
$\operatorname{proj}_W(v) = \frac{4}{\sqrt3}\cdot\frac{(1,1,1)}{\sqrt3} =
\frac43(1,1,1) = \left(\frac43,\frac43,\frac43\right)$. Distance:
$$\left\|\left(4-\tfrac43,\ -\tfrac43,\ -\tfrac43\right)\right\| =
\left\|\left(\tfrac83,-\tfrac43,-\tfrac43\right)\right\| =
\sqrt{\tfrac{64}{9}+\tfrac{16}{9}+\tfrac{16}{9}} = \sqrt{\tfrac{96}{9}} =
\frac{\sqrt{96}}{3} = \frac{4\sqrt6}{3}.$$

**7.** Since $e_1,\dots,e_k$ is a basis for $W$ and $v \in W$, write $v =
\sum_{i=1}^k c_ie_i$ for some scalars $c_i$. By orthonormality, $\langle
v,e_j\rangle = \sum_{i=1}^k c_i\langle e_i,e_j\rangle = c_j$ (only the $i=j$
term survives). So
$$\operatorname{proj}_W(v) = \sum_{j=1}^k \langle v,e_j\rangle e_j =
\sum_{j=1}^k c_je_j = v.$$

**8.** From $A^TA\hat x = A^Tb$, rearrange to $A^T(A\hat x - b) = 0$, i.e.
$A^T(b - A\hat x) = 0$ (the same equation up to an overall sign). Writing
out $A^T$'s rows as the columns $a_1,\dots,a_n$ of $A$ (so row $j$ of $A^T$
is $a_j^T$), this single matrix equation says, row by row,
$$a_j^T(b - A\hat x) = 0, \quad \text{i.e.} \quad a_j \cdot (b-A\hat x) = 0,
\qquad j = 1,\dots,n.$$
So the residual $b - A\hat x$ is orthogonal to every column $a_j$ of $A$.

**9.** *Uniqueness of $\hat x$:* For any $x$, $x^TA^TAx = (Ax)^T(Ax) =
\|Ax\|^2$. So $A^TAx = 0 \implies x^TA^TAx = 0 \implies \|Ax\|^2 = 0
\implies Ax = 0$; conversely $Ax=0 \implies A^TAx = A^T0 = 0$. Hence $N(A^TA)
= N(A)$. If the columns of $A$ are linearly dependent, $N(A) \neq \{0\}$
(some nontrivial combination of columns vanishes), so $N(A^TA) \neq \{0\}$
too, meaning $A^TA$ is *not* invertible (a square matrix with nontrivial
null space isn't invertible — Day 9). Consequently, if $\hat x_0$ solves the
normal equations, so does $\hat x_0 + z$ for any $z \in N(A) = N(A^TA)$,
since $A^TA(\hat x_0+z) = A^TA\hat x_0 + A^TAz = A^Tb + 0 = A^Tb$. Since
$N(A) \neq \{0\}$ here, there are infinitely many solutions $\hat x$ — it is
**not unique**.

*Uniqueness of $A\hat x$:* Yes, $A\hat x$ is still unique, regardless. This
doesn't contradict the above because $A\hat x = \operatorname{proj}_{C(A)}(b)$
is characterized purely as "the closest point of the subspace $C(A)$ to
$b$," which the Best Approximation Theorem (Theorem 16.1) guarantees is a
*single, unique vector* no matter how many different coefficient vectors
$\hat x$ happen to produce it. Linear dependence among $A$'s columns means
several different $\hat x$'s describe the *same point* $A\hat x \in C(A)$ as
a combination of those columns — a redundancy in the representation, not in
the geometric answer.

**10.** By Definition 16.1 and bilinearity of the inner product in its
first argument:
$$\operatorname{proj}_W(au+bv) = \sum_{i=1}^k \langle au+bv, e_i\rangle e_i
= \sum_{i=1}^k \big(a\langle u,e_i\rangle + b\langle v,e_i\rangle\big) e_i$$
$$= a\sum_{i=1}^k \langle u,e_i\rangle e_i + b\sum_{i=1}^k \langle v,e_i
\rangle e_i = a\operatorname{proj}_W(u) + b\operatorname{proj}_W(v).$$

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements least squares via the normal equations and checks it
against `numpy.linalg.lstsq` on a noisy synthetic line-fitting problem — the
same computation as the Worked example and Exercises 4–5, just automated and
at a larger scale (20 points instead of 3–4). Open
`starter_code/day16_least_squares.py` — it has one function to complete,
`least_squares_normal_equations`. Fill in the `TODO`, then run the file
directly (`python starter_code/day16_least_squares.py`); it should print
that your solution matches `np.linalg.lstsq` and save a plot of the fitted
line against the noisy data.

**Hint:** the normal equations are literally $A^TA\hat x = A^Tb$ — form
`A.T @ A` and `A.T @ y`, then solve for `x`. Prefer
`np.linalg.solve(A.T @ A, A.T @ y)` over explicitly inverting with
`np.linalg.inv`; solving a linear system is both faster and numerically more
stable than computing a matrix inverse and multiplying by it, even though
both give the same answer in exact arithmetic.

If you get stuck for more than ~10 minutes, check
`solutions/day16_least_squares.py` — but only after a real attempt.

Once your implementation passes, extend it: pick a *nonlinear-looking*
feature, e.g. fit $y = a + bx + cx^2$ to some data by adding an $x^2$ column
to $A$ (this is still *linear* in the unknowns $a,b,c$, hence still ordinary
least squares — the "linear" in "linear regression" refers to linearity in
the parameters, not in $x$). Confirm your normal-equations solver still
matches `np.linalg.lstsq` on this 3-column $A$.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $\operatorname{proj}_W(v)$ | "the projection of $v$ onto $W$" | the point of the subspace $W$ closest to $v$ |
| $W^\perp$ | "$W$-perp, the orthogonal complement" | every vector perpendicular to all of $W$ |
| $v - \operatorname{proj}_W(v)$ | "the residual" | the leftover, which points straight out of $W$ |
| $\hat x$ | "x-hat, the least-squares solution" | best-fit unknowns when $Ax = b$ has no exact solution |
| $A^TA\hat x = A^Tb$ | "the normal equations" | the always-solvable system whose solution is $\hat x$ |
| $C(A)$ | "the column space of $A$" | all vectors $Ax$; the subspace we project $b$ onto |
| $\Vert v - w\Vert$ | "the distance from $v$ to $w$" | the length least squares works to minimize |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- The orthogonal projection of $v$ onto $W$ is the single point of $W$
  closest to $v$ — nothing in the subspace is nearer.
- The line from $v$ to its projection is perpendicular to the entire
  subspace $W$; that right angle is exactly what makes it the closest point.
- Least squares is not a separate technique: solving $Ax = b$ approximately
  *is* projecting $b$ onto the column space $C(A)$.
- The best fit $\hat x$ is found by the normal equations $A^TA\hat x =
  A^Tb$, which always have a solution even when $Ax = b$ has none.
- The projected point $A\hat x$ is always unique, even in cases where the
  coefficient vector $\hat x$ is not (dependent columns): geometry pins down
  the point, not the coordinates.

### Proof sketches

**Lemma 16.1 — key trick: expand the squared length and watch the cross
term die.**
Write $\|a+b\|^2$ as the inner product $\langle a+b, a+b\rangle$ and expand
into four pieces: $\|a\|^2$, $\|b\|^2$, and two copies of
$\langle a,b\rangle$. When $a \perp b$ that cross term is zero, so only
$\|a\|^2 + \|b\|^2$ survives — the Pythagorean theorem, now valid in any
inner product space. Full version: Lemma 16.1 above.

**Lemma 16.2 — key trick: only test against each basis vector; the
projection formula cancels itself.**
To show the residual $v - \operatorname{proj}_W(v)$ is perpendicular to all
of $W$, it is enough to check it against each orthonormal basis vector $e_j$,
since orthogonality to a spanning set spreads to the whole subspace. Dotting
with $e_j$, the projection sum collapses because $\langle e_i, e_j\rangle$ is
$0$ unless $i = j$, leaving $\langle v, e_j\rangle - \langle v, e_j\rangle =
0$. So the residual lands in $W^\perp$. Full version: Lemma 16.2 above.

**Theorem 16.1 — key trick: split $v - w$ into a perpendicular piece plus an
in-subspace piece, then use Pythagoras.**
For any competitor $w \in W$, write $v - w = (v - p) + (p - w)$, where $p$ is
the projection. The first piece points out of $W$ (Lemma 16.2), the second
lies inside $W$, so they are perpendicular and Lemma 16.1 gives $\|v-w\|^2 =
\|v-p\|^2 + \|p-w\|^2$. That extra $\|p-w\|^2 \ge 0$ can only push $w$
farther from $v$, and it vanishes only when $w = p$. So $p$ is the unique
closest point. Full version: Theorem 16.1 above.

**Theorem 16.2 — key trick: "closest point in the column space" plus
"residual lands in $N(A^T)$".**
As $x$ ranges over everything, $Ax$ sweeps out exactly the column space
$C(A)$, so minimizing $\|Ax - b\|$ is just finding the point of $C(A)$
closest to $b$. By the Best Approximation Theorem that point is the
projection, characterized by the residual $b - A\hat x$ being perpendicular
to $C(A)$. But "perpendicular to $C(A)$" means "inside $N(A^T)$" (Day 6),
i.e. $A^T(b - A\hat x) = 0$ — rearrange to $A^TA\hat x = A^Tb$. Full version:
Theorem 16.2 above.

### If you remember only 3 things

1. The projection is the closest point, and the residual is perpendicular to
   the subspace — one right-angle picture sits behind everything today.
2. Least squares = projection onto $C(A)$; solve the normal equations
   $A^TA\hat x = A^Tb$ (always solvable) to get the best fit $\hat x$.
3. The point $A\hat x$ is always unique; the coordinates $\hat x$ need not
   be, if $A$'s columns are linearly dependent (Exercise 9's trap).

## Journal template

```
## Day 16 — Orthogonal projections, least squares
Key theorem in my own words: ...
What confused me: ...
```
