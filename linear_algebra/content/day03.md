# Day 3 — Linear Transformations, Matrix Representation

## Learning objectives

By the end of today you should be able to:
- State the definition of a linear transformation and verify (or refute) that
  a given map between vector spaces is linear.
- Construct the matrix of a linear transformation relative to given bases,
  and use it to compute images of arbitrary vectors.
- Prove that a linear transformation is completely determined by its action
  on a basis, in both directions (uniqueness and existence/extension).
- Prove that composing linear transformations corresponds to multiplying
  their matrices, and use this fact computationally.

## Reference material

- Primer (15 min, geometric intuition): 3Blue1Brown, *Essence of Linear
  Algebra*, Chapters 3–4 (linear transformations; matrix multiplication as
  composition) — [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab)
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §1.6–1.7 —
  [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  chapter on Linear Mappings — if you don't have a copy, the exercises below
  are self-contained and sufficient for today.

The theory below is self-contained — you do not strictly need the Treil PDF
to do today's work, but reading his §1.6–1.7 alongside this is the "theory"
layer of today's three-layer structure.

## Theory

### Definition 3.1 (Linear transformation)

Let $V, W$ be vector spaces over $\mathbb{R}$. A function $T: V \to W$ is a
**linear transformation** (or **linear map**) if for all $u, v \in V$ and all
$c \in \mathbb{R}$:

1. $T(u + v) = T(u) + T(v)$ (additivity)
2. $T(cv) = cT(v)$ (homogeneity)

Two immediate consequences: taking $c = 0$ in condition 2 gives
$T(0) = 0$ (a linear transformation always sends the zero vector to the zero
vector), and — as we prove formally below — linearity extends from pairs of
vectors to arbitrary finite linear combinations.

### Definition 3.2 (Matrix of a linear transformation relative to given bases)

Let $V$ be an $n$-dimensional vector space with **ordered basis**
$\mathcal{B} = (v_1, \dots, v_n)$, and let $W$ be an $m$-dimensional vector
space with ordered basis $\mathcal{C} = (w_1, \dots, w_m)$. Let $T: V \to W$
be linear. For each $j = 1, \dots, n$, the vector $T(v_j) \in W$ has a unique
expression in terms of $\mathcal{C}$:
$$T(v_j) = \sum_{i=1}^m a_{ij} w_i.$$
The **matrix of $T$ relative to $\mathcal{B}$ and $\mathcal{C}$**, written
$[T]_{\mathcal B}^{\mathcal C}$ (or just $A$ when the bases are clear from
context), is the $m \times n$ matrix $A = (a_{ij})$ whose $j$-th column is
the coordinate vector of $T(v_j)$ relative to $\mathcal C$.

The point of this definition is computational: if $x \in V$ has coordinate
vector $[x]_{\mathcal B} = (c_1, \dots, c_n)^T$ (i.e. $x = \sum_j c_j v_j$),
then the coordinate vector of $T(x)$ relative to $\mathcal C$ is exactly
$A[x]_{\mathcal B}$ — matrix-vector multiplication computes the image of $T$
in coordinates. We will use this repeatedly below without further comment.

### Lemma 3.1 (Linearity extends to finite linear combinations)

If $T: V \to W$ is linear, then for any finite collection of vectors
$v_1, \dots, v_k \in V$ and scalars $c_1, \dots, c_k \in \mathbb{R}$,
$$T\left(\sum_{i=1}^k c_i v_i\right) = \sum_{i=1}^k c_i T(v_i).$$

**Proof.** By induction on $k$.

*Base case ($k=1$).* $T(c_1 v_1) = c_1 T(v_1)$ is exactly homogeneity
(Definition 3.1, condition 2).

*Inductive step.* Suppose the claim holds for sums of $k - 1$ terms. Then
$$T\left(\sum_{i=1}^k c_i v_i\right)
= T\left(\sum_{i=1}^{k-1} c_i v_i \;+\; c_k v_k\right)
= T\left(\sum_{i=1}^{k-1} c_i v_i\right) + T(c_k v_k)$$
by additivity (Definition 3.1, condition 1), applied to the two vectors
$\sum_{i=1}^{k-1} c_i v_i$ and $c_k v_k$. By the inductive hypothesis, the
first term equals $\sum_{i=1}^{k-1} c_i T(v_i)$, and by homogeneity the
second term equals $c_k T(v_k)$. Hence
$$T\left(\sum_{i=1}^k c_i v_i\right) = \sum_{i=1}^{k-1} c_i T(v_i) + c_k T(v_k)
= \sum_{i=1}^k c_i T(v_i).$$
By induction, the claim holds for every $k \geq 1$. $\blacksquare$

### Theorem 3.1 (A linear transformation is determined by its action on a basis)

Let $V$ be a vector space with basis $\mathcal{B} = (v_1, \dots, v_n)$, and
let $W$ be any vector space.

**(a) Uniqueness.** If $T, S : V \to W$ are both linear and
$T(v_i) = S(v_i)$ for every $i = 1, \dots, n$, then $T(x) = S(x)$ for
*every* $x \in V$ — i.e. $T = S$.

**(b) Existence/extension.** For *any* choice of vectors
$w_1, \dots, w_n \in W$ (arbitrary — no relationship among them is assumed),
there exists a linear transformation $T: V \to W$ with $T(v_i) = w_i$ for
every $i$, and by part (a) this $T$ is unique.

**Proof of (a).** Let $x \in V$ be arbitrary. Since $\mathcal{B}$ is a basis
of $V$, $x$ has a (unique) representation $x = \sum_{i=1}^n c_i v_i$ for some
scalars $c_i \in \mathbb{R}$. Then, using Lemma 3.1 for $T$, the hypothesis
$T(v_i) = S(v_i)$, and Lemma 3.1 again for $S$:
$$T(x) = T\left(\sum_{i=1}^n c_i v_i\right) = \sum_{i=1}^n c_i T(v_i)
= \sum_{i=1}^n c_i S(v_i) = S\left(\sum_{i=1}^n c_i v_i\right) = S(x).$$
Since $x \in V$ was arbitrary, $T(x) = S(x)$ for all $x \in V$, i.e. $T = S$.

**Proof of (b).** *Construction.* Since $\mathcal{B}$ is a basis, every
$x \in V$ has a unique representation $x = \sum_{i=1}^n c_i v_i$. Define
$T: V \to W$ by
$$T(x) := \sum_{i=1}^n c_i w_i,$$
using the (unique) coefficients $c_i$ of $x$ relative to $\mathcal{B}$. This
is a well-defined function precisely because the representation of $x$ in
the basis $\mathcal{B}$ is unique — there is no ambiguity in which $c_i$ to
use.

*$T$ is linear.* Let $x = \sum_i c_i v_i$ and $y = \sum_i d_i v_i$ be the
basis representations of $x, y \in V$, and let $a \in \mathbb{R}$. Since
$\mathcal{B}$ is a basis, the representation of any vector is unique, and
$$x + y = \sum_{i=1}^n (c_i + d_i) v_i, \qquad ax = \sum_{i=1}^n (a c_i) v_i$$
are themselves the (unique) basis representations of $x+y$ and $ax$
respectively (they are linear combinations of the $v_i$, and representations
in a basis are unique, so these must be *the* representations). Hence by the
definition of $T$:
$$T(x+y) = \sum_{i=1}^n (c_i+d_i) w_i = \sum_{i=1}^n c_i w_i + \sum_{i=1}^n d_i w_i = T(x) + T(y),$$
$$T(ax) = \sum_{i=1}^n (ac_i) w_i = a\sum_{i=1}^n c_i w_i = aT(x).$$
So $T$ satisfies both conditions of Definition 3.1: $T$ is linear.

*$T$ agrees with the prescribed values.* Fix $j \in \{1, \dots, n\}$. The
basis representation of $v_j$ itself is $v_j = \sum_{i=1}^n \delta_{ij} v_i$
(coefficient $1$ on $v_j$, coefficient $0$ on every other basis vector, where
$\delta_{ij}$ is $1$ if $i=j$ and $0$ otherwise — this is the unique
representation of $v_j$ in its own basis). By the definition of $T$,
$$T(v_j) = \sum_{i=1}^n \delta_{ij} w_i = w_j,$$
as required.

*Uniqueness of this $T$* is exactly part (a): any other linear map agreeing
with $T$ on every basis vector must equal $T$ everywhere. $\blacksquare$

### Theorem 3.2 (The matrix of a composition is the product of the matrices)

Let $V, W, U$ be finite-dimensional vector spaces with fixed ordered bases
$\mathcal{B} = (v_1, \dots, v_n)$ of $V$, $\mathcal{C} = (w_1, \dots, w_m)$ of
$W$, and $\mathcal{D} = (u_1, \dots, u_p)$ of $U$. Let $T: V \to W$ be linear
with matrix $A = [T]_{\mathcal B}^{\mathcal C}$ (an $m \times n$ matrix), and
let $S: W \to U$ be linear with matrix $B = [S]_{\mathcal C}^{\mathcal D}$
(a $p \times m$ matrix). Then the composition $S \circ T : V \to U$ is
linear, and its matrix relative to $\mathcal{B}, \mathcal{D}$ is the matrix
product $BA$ (a $p \times n$ matrix):
$$[S \circ T]_{\mathcal B}^{\mathcal D} = BA.$$

**Proof.** *Step 1: $S \circ T$ is linear.* For $u, v \in V$ and $c \in \mathbb{R}$:
$$(S \circ T)(u + v) = S(T(u+v)) = S(T(u) + T(v)) = S(T(u)) + S(T(v)) = (S\circ T)(u) + (S \circ T)(v),$$
using linearity of $T$ (additivity) for the second equality and linearity of
$S$ (additivity) for the third. Similarly,
$$(S \circ T)(cv) = S(T(cv)) = S(cT(v)) = cS(T(v)) = c(S\circ T)(v),$$
using homogeneity of $T$ then homogeneity of $S$. So $S \circ T$ satisfies
both conditions of Definition 3.1: it is linear, and consequently it *does*
have a well-defined matrix relative to $\mathcal{B}, \mathcal{D}$
(Definition 3.2).

*Step 2: compute that matrix, one basis vector at a time.* Fix
$j \in \{1, \dots, n\}$. By the definition of $A$ as the matrix of $T$
relative to $\mathcal{B}, \mathcal{C}$ (Definition 3.2), the $j$-th column of
$A$ gives the coordinates of $T(v_j)$ relative to $\mathcal{C}$:
$$T(v_j) = \sum_{k=1}^m A_{kj} \, w_k.$$
Apply $S$ to both sides and use Lemma 3.1 to push $S$ through the finite sum
on the right (valid since $S$ is linear):
$$S(T(v_j)) = S\left(\sum_{k=1}^m A_{kj} w_k\right) = \sum_{k=1}^m A_{kj}\, S(w_k).$$
By the definition of $B$ as the matrix of $S$ relative to $\mathcal{C},
\mathcal{D}$, each $S(w_k)$ expands in terms of $\mathcal{D}$ as
$$S(w_k) = \sum_{i=1}^p B_{ik}\, u_i.$$
Substituting this in:
$$(S \circ T)(v_j) = S(T(v_j)) = \sum_{k=1}^m A_{kj} \left(\sum_{i=1}^p B_{ik} u_i\right)
= \sum_{i=1}^p \left(\sum_{k=1}^m B_{ik} A_{kj}\right) u_i
= \sum_{i=1}^p (BA)_{ij}\, u_i,$$
where the middle step swaps the (finite) order of summation, and the last
step recognizes $\sum_{k=1}^m B_{ik} A_{kj}$ as precisely the $(i,j)$ entry
of the matrix product $BA$ (row $i$ of $B$ dotted with column $j$ of $A$).

*Step 3: conclude.* The equation
$(S\circ T)(v_j) = \sum_{i=1}^p (BA)_{ij}\, u_i$ says exactly that the
coordinate vector of $(S\circ T)(v_j)$ relative to $\mathcal{D}$ is the
$j$-th column of $BA$. This holds for every $j = 1, \dots, n$, so by
Definition 3.2, the matrix of $S \circ T$ relative to $\mathcal{B},
\mathcal{D}$ is exactly $BA$, column by column. $\blacksquare$

## Worked example

**Claim:** Let $T: \mathbb{R}^2 \to \mathbb{R}^2$ be rotation by $90°$
counterclockwise about the origin. Relative to the standard basis
$\mathcal{E} = (e_1, e_2)$ (used for both domain and codomain), the matrix of
$T$ is $A = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$, and $T(x,y) =
(-y, x)$ for every $(x,y) \in \mathbb{R}^2$.

**Find the matrix, by finding where the basis vectors go.** $e_1 = (1,0)$
points along the positive $x$-axis; rotating it $90°$ counterclockwise
points it along the positive $y$-axis: $T(e_1) = (0, 1)$. $e_2 = (0,1)$
points along the positive $y$-axis; rotating it $90°$ counterclockwise
points it along the *negative* $x$-axis: $T(e_2) = (-1, 0)$. By
Definition 3.2, the columns of $A$ are the coordinate vectors of $T(e_1)$
and $T(e_2)$ (relative to the standard basis, coordinates are just the
components themselves):
$$A = \begin{pmatrix} T(e_1) & T(e_2) \end{pmatrix} = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}.$$

**Use the matrix to compute the image of an arbitrary vector.** Let
$v = (x, y)$ be arbitrary. Its coordinate vector relative to the standard
basis is just $(x,y)^T$, so
$$A\begin{pmatrix} x \\ y \end{pmatrix} = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}\begin{pmatrix} x \\ y \end{pmatrix} = \begin{pmatrix} 0\cdot x + (-1)\cdot y \\ 1 \cdot x + 0 \cdot y \end{pmatrix} = \begin{pmatrix} -y \\ x \end{pmatrix}.$$
So $T(x, y) = (-y, x)$.

**Verify geometrically.** Write $v = (x,y)$ in polar form,
$x = r\cos\theta$, $y = r\sin\theta$, where $r = \|v\|$ and $\theta$ is the
angle $v$ makes with the positive $x$-axis. Rotating $v$ by $90°$
counterclockwise, by definition, produces the vector of the same length $r$
at angle $\theta + 90°$:
$$T(v) = \big(r\cos(\theta + 90°),\; r\sin(\theta + 90°)\big).$$
Using the angle-addition identities $\cos(\theta+90°) = -\sin\theta$ and
$\sin(\theta+90°) = \cos\theta$:
$$T(v) = (-r\sin\theta,\; r\cos\theta) = (-y, x),$$
which matches the matrix computation exactly. The matrix-algebra answer and
the direct geometric rotation agree.

## Unconventional edge

A common trap is treating "the matrix of $T$" as though it were an
intrinsic property of $T$ itself, rather than something defined only
*relative to a chosen pair of ordered bases* (Definition 3.2). The **same**
linear transformation can have completely different-looking matrices
depending on which bases you pick for the domain and codomain — Exercise 10
below shows the *identity* transformation, whose matrix is the identity
matrix $I_2$ relative to the standard basis (Exercise 8 proves this always
holds for identity when the same basis is used on both sides), becomes the
distinctly non-diagonal matrix $\begin{pmatrix}1&1\\1&-1\end{pmatrix}$ when
you switch only the *domain's* basis while keeping the codomain's basis
standard — same function, different matrix. This is why careful notation
writes $[T]_{\mathcal B}^{\mathcal C}$ with explicit basis labels rather than
just "the matrix of $T$"; dropping the labels mentally is exactly the habit
that causes confusion later. Keep this in mind going forward — Day 25
(change of basis) is entirely devoted to the precise rule for converting a
transformation's matrix from one pair of bases to another, and today's
exercises are laying the groundwork by making you feel the basis-dependence
directly, rather than just being told about it.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–4 are linearity checks (including trick questions);
5, 6, 7, 9 are computational (matrix construction and composition);
8 and 10 are proof/justification-based.

1. Determine whether $T: \mathbb{R}^2 \to \mathbb{R}^2$, $T(x,y) = (2x, 3y)$,
   is linear. Prove your answer.
2. Determine whether $T: \mathbb{R}^2 \to \mathbb{R}^2$, $T(x,y) = (x+1, y)$,
   is linear. Prove your answer. (Careful — this one is a trap.)
3. Determine whether $T: \mathbb{R}^2 \to \mathbb{R}^2$, $T(x,y) = (xy, x)$,
   is linear. Prove your answer.
4. Determine whether $T: \mathbb{R}^3 \to \mathbb{R}^2$,
   $T(x,y,z) = (x - z,\ 2y + z)$, is linear. Prove your answer.
5. Let $T: \mathbb{R}^2 \to \mathbb{R}^2$ be the (unique, by Theorem 3.1)
   linear transformation with $T(e_1) = (1,2)$ and $T(e_2) = (3,-1)$. Write
   the matrix of $T$ relative to the standard basis, and use it to compute
   $T(5, -2)$.
6. Let $T: \mathbb{R}^2 \to \mathbb{R}^2$ be reflection across the $x$-axis,
   and let $S: \mathbb{R}^2 \to \mathbb{R}^2$ be the $90°$ counterclockwise
   rotation from the worked example. (a) Write the standard matrices of $T$
   and $S$. (b) Find the matrix of $S \circ T$ two ways: first by directly
   computing $(S\circ T)(e_1)$ and $(S \circ T)(e_2)$ using the geometric
   description of $S$ and $T$; second by multiplying the two matrices from
   part (a). Confirm the two answers agree.
7. Let $v_1 = (1,1)$, $v_2 = (1,-1)$. (a) Show $(v_1, v_2)$ is a basis of
   $\mathbb{R}^2$. (b) Let $T: \mathbb{R}^2 \to \mathbb{R}^2$ be the unique
   linear transformation with $T(v_1) = (2, 0)$ and $T(v_2) = (0, 3)$. Find
   the matrix of $T$ relative to the *standard* basis (for both domain and
   codomain) — i.e. find $T(e_1)$ and $T(e_2)$.
8. Prove: for any finite-dimensional vector space $V$ with basis
   $\mathcal{B} = (v_1, \dots, v_n)$, the identity transformation
   $I: V \to V$, $I(v) = v$, has matrix equal to the $n \times n$ identity
   matrix relative to $\mathcal{B}$ used as *both* the domain basis and the
   codomain basis.
9. Let $T: \mathbb{R}^3 \to \mathbb{R}^2$ have standard matrix
   $A = \begin{pmatrix} 1 & 0 & 2 \\ 3 & -1 & 0 \end{pmatrix}$, and let
   $S: \mathbb{R}^2 \to \mathbb{R}^2$ have standard matrix
   $B = \begin{pmatrix} 0 & 1 \\ 1 & 0 \end{pmatrix}$. (a) Compute the matrix
   of $S \circ T$ as the product $BA$. (b) Verify your answer by computing
   $(S \circ T)(1,0,0)$, $(S\circ T)(0,1,0)$, $(S \circ T)(0,0,1)$ directly
   from the formulas for $S$ and $T$, and checking each result matches the
   corresponding column of $BA$.
10. True or False, with justification: "The matrix of a linear
    transformation $T: V \to W$ is uniquely determined by $T$ alone,
    independent of any choice of basis." Use the identity transformation on
    $\mathbb{R}^2$, together with the basis $(v_1, v_2) = ((1,1),(1,-1))$
    from Exercise 7, to make your justification concrete.

## Solutions

**1.** Linear. *Additivity:*
$T((x_1,y_1)+(x_2,y_2)) = T(x_1+x_2, y_1+y_2) = (2(x_1+x_2), 3(y_1+y_2)) =
(2x_1,3y_1) + (2x_2,3y_2) = T(x_1,y_1) + T(x_2,y_2)$. *Homogeneity:*
$T(c(x,y)) = T(cx,cy) = (2cx,3cy) = c(2x,3y) = cT(x,y)$. Both conditions of
Definition 3.1 hold.

**2.** Not linear. Every linear transformation must send $0$ to $0$ (take
$c=0$ in the homogeneity condition: $T(0) = T(0\cdot v) = 0 \cdot T(v) = 0$).
Here $T(0,0) = (0+1, 0) = (1,0) \neq (0,0)$, so $T$ fails to be linear. (You
can also see additivity fail directly: $T(1,0) + T(1,0) = (2,0)+(2,0) =
(4,0)$, but $T((1,0)+(1,0)) = T(2,0) = (3,0) \neq (4,0)$.) This map is a
*translation*, not a linear map — translations are never linear unless the
shift is zero.

**3.** Not linear. Check homogeneity with $x=y=1$, $c=2$:
$T(c(x,y)) = T(2,2) = (2\cdot2,\, 2) = (4,2)$, but
$cT(x,y) = 2\cdot T(1,1) = 2\cdot(1,1) = (2,2)$. Since $(4,2) \neq (2,2)$,
homogeneity fails, so $T$ is not linear. (The product term $xy$ is the
giveaway — linear maps can only involve terms of degree exactly $1$ in the
input coordinates.)

**4.** Linear. *Additivity:*
$$T((x_1,y_1,z_1)+(x_2,y_2,z_2)) = T(x_1{+}x_2,\, y_1{+}y_2,\, z_1{+}z_2)
= \big((x_1{+}x_2)-(z_1{+}z_2),\ 2(y_1{+}y_2)+(z_1{+}z_2)\big)$$
$$= (x_1 - z_1,\, 2y_1+z_1) + (x_2-z_2,\, 2y_2+z_2) = T(x_1,y_1,z_1) + T(x_2,y_2,z_2).$$
*Homogeneity:* $T(c(x,y,z)) = T(cx,cy,cz) = (cx-cz,\, 2cy+cz) =
c(x-z,\, 2y+z) = cT(x,y,z)$. Both conditions hold. (Equivalently: $T$ is
given by the matrix $\begin{pmatrix}1&0&-1\\0&2&1\end{pmatrix}$ acting on
$(x,y,z)^T$, and every matrix-multiplication map is automatically linear.)

**5.** By Definition 3.2, the matrix has $T(e_1), T(e_2)$ as its columns:
$$A = \begin{pmatrix} 1 & 3 \\ 2 & -1 \end{pmatrix}.$$
To compute $T(5,-2)$, either multiply directly,
$$A\begin{pmatrix}5\\-2\end{pmatrix} = \begin{pmatrix}1\cdot5+3\cdot(-2)\\2\cdot5+(-1)\cdot(-2)\end{pmatrix} = \begin{pmatrix}-1\\12\end{pmatrix},$$
or use linearity directly via Lemma 3.1: $(5,-2) = 5e_1 - 2e_2$, so
$T(5,-2) = 5T(e_1) - 2T(e_2) = 5(1,2) - 2(3,-1) = (5,10)-(6,-2) = (-1,12)$.
Both methods agree: $T(5,-2) = (-1, 12)$.

**6.** (a) Reflection across the $x$-axis sends $(x,y) \mapsto (x,-y)$, so
$T(e_1) = (1,0)$, $T(e_2) = (0,-1)$, giving
$M_T = \begin{pmatrix}1&0\\0&-1\end{pmatrix}$. From the worked example,
$M_S = \begin{pmatrix}0&-1\\1&0\end{pmatrix}$.

(b) *Directly:* $(S\circ T)(e_1) = S(T(e_1)) = S(1,0)$. Using $S(x,y)=(-y,x)$
(from the worked example), $S(1,0) = (0,1)$. $(S \circ T)(e_2) = S(T(e_2)) =
S(0,-1) = (1, 0)$. So the matrix of $S \circ T$ (columns are these two
images) is $\begin{pmatrix}0&1\\1&0\end{pmatrix}$.

*By matrix multiplication:*
$$M_S M_T = \begin{pmatrix}0&-1\\1&0\end{pmatrix}\begin{pmatrix}1&0\\0&-1\end{pmatrix}
= \begin{pmatrix}0\cdot1+(-1)\cdot0 & 0\cdot0+(-1)\cdot(-1)\\ 1\cdot1+0\cdot0 & 1\cdot0+0\cdot(-1)\end{pmatrix}
= \begin{pmatrix}0&1\\1&0\end{pmatrix}.$$
This matches the direct computation, confirming Theorem 3.2.

**7.** (a) $(v_1, v_2)$ is a basis of $\mathbb{R}^2$ iff they are linearly
independent (two vectors is exactly $\dim \mathbb{R}^2$). They are not
scalar multiples of each other (the determinant
$\begin{vmatrix}1&1\\1&-1\end{vmatrix} = -1 - 1 = -2 \neq 0$), so they are
linearly independent, hence a basis.

(b) Express $e_1, e_2$ in terms of $v_1, v_2$. For $e_1 = (1,0) = a v_1 + b v_2
= (a+b,\, a-b)$: $a+b=1$, $a-b=0 \Rightarrow a=b=\tfrac12$, so
$e_1 = \tfrac12 v_1 + \tfrac12 v_2$. For $e_2 = (0,1) = a v_1+bv_2$: $a+b=0$,
$a-b=1 \Rightarrow a = \tfrac12, b=-\tfrac12$, so
$e_2 = \tfrac12 v_1 - \tfrac12 v_2$. By Lemma 3.1:
$$T(e_1) = \tfrac12 T(v_1) + \tfrac12 T(v_2) = \tfrac12(2,0) + \tfrac12(0,3) = (1,\ \tfrac32),$$
$$T(e_2) = \tfrac12 T(v_1) - \tfrac12 T(v_2) = \tfrac12(2,0) - \tfrac12(0,3) = (1,\ -\tfrac32).$$
So the standard matrix of $T$ is $\begin{pmatrix}1 & 1\\ \tfrac32 & -\tfrac32\end{pmatrix}$.
(Check: this matrix times $(1,1)^T$ gives $(1+1,\ \tfrac32-\tfrac32) = (2,0) =
T(v_1)$ ✓, and times $(1,-1)^T$ gives $(1-1,\ \tfrac32+\tfrac32) = (0,3) =
T(v_2)$ ✓.)

**8.** Let $\mathcal{B} = (v_1, \dots, v_n)$ be a basis of $V$, used as both
the domain and codomain basis for $I: V \to V$. By Definition 3.2, the
$j$-th column of the matrix of $I$ relative to $\mathcal{B}$ (on both sides)
is the coordinate vector of $I(v_j)$ relative to $\mathcal{B}$. But
$I(v_j) = v_j$ by definition of the identity map, and the coordinate vector
of $v_j$ relative to the basis $\mathcal{B} = (v_1,\dots,v_n)$ is
$(0,\dots,0,1,0,\dots,0)^T$ with the $1$ in position $j$ — this is because
$v_j = \sum_{i=1}^n \delta_{ij} v_i$ is (trivially) a linear combination of
the basis vectors, and by uniqueness of basis representations, this must be
*the* representation. So the $j$-th column of the matrix is the $j$-th
standard basis vector of $\mathbb{R}^n$, for every $j = 1,\dots,n$. A matrix
whose $j$-th column is the $j$-th standard basis vector for every $j$ is, by
definition, the $n\times n$ identity matrix $I_n$. $\blacksquare$

**9.** (a)
$$BA = \begin{pmatrix}0&1\\1&0\end{pmatrix}\begin{pmatrix}1&0&2\\3&-1&0\end{pmatrix}
= \begin{pmatrix}0\cdot1+1\cdot3 & 0\cdot0+1\cdot(-1) & 0\cdot2+1\cdot0\\ 1\cdot1+0\cdot3 & 1\cdot0+0\cdot(-1) & 1\cdot2+0\cdot0\end{pmatrix}
= \begin{pmatrix}3&-1&0\\1&0&2\end{pmatrix}.$$

(b) With $A$ as given, $T(x,y,z) = (x+2z,\ 3x-y)$; with $B$ as given,
$S(a,b) = (b,a)$ (it swaps coordinates). So
$$(S\circ T)(x,y,z) = S(x+2z,\ 3x-y) = (3x-y,\ x+2z).$$
Evaluating on the standard basis of $\mathbb{R}^3$:
$(S\circ T)(1,0,0) = (3, 1)$, $(S\circ T)(0,1,0) = (-1, 0)$,
$(S\circ T)(0,0,1) = (0, 2)$. These are exactly the three columns of $BA$
found in part (a): $(3,1)$, $(-1,0)$, $(0,2)$. Confirmed.

**10.** False. The matrix of $T$ depends on the *choice of bases* used for
$V$ and $W$ (Definition 3.2) — $T$ itself (the function) is basis-independent,
but its matrix representation is not. Concretely: the identity map
$I: \mathbb{R}^2 \to \mathbb{R}^2$ relative to the standard basis (both
sides) has matrix $I_2 = \begin{pmatrix}1&0\\0&1\end{pmatrix}$ (Exercise 8).
But if we keep the codomain basis standard while switching the *domain*
basis to $(v_1,v_2) = ((1,1),(1,-1))$ from Exercise 7, the matrix columns
become the coordinates of $I(v_1) = v_1 = (1,1)$ and $I(v_2) = v_2 = (1,-1)$
relative to the *standard* basis — i.e. just their components — giving
$\begin{pmatrix}1&1\\1&-1\end{pmatrix} \neq I_2$. Same function $I$, two
different matrices, because two different bases were used. This is the
"Unconventional edge" trap above.

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements a numerical check that composing two linear
transformations agrees with multiplying their matrices — the computational
analogue of Theorem 3.2 and of what you verified by hand in Exercises 6 and
9. Open `starter_code/day03_linear_transformations.py` — it has one function
to complete, `matches_composition`. Fill in the `TODO`, then run the file
directly (`python starter_code/day03_linear_transformations.py`); it should
print `All checks passed!`.

**Hint:** applying $T$ then $S$ to a vector $v$ means computing
$S(T(v)) = S \,(T v)$, i.e. `S @ (T @ v)`. Applying the single matrix product
$SA = S \cdot T$ (Theorem 3.2) means computing `(S @ T) @ v`. Compare the two
with `np.allclose` — matrix multiplication is associative, so the grouping
of the parentheses shouldn't matter mathematically, but it's worth seeing
NumPy confirm it numerically.

If you get stuck for more than ~10 minutes, check
`solutions/day03_linear_transformations.py` — but only after a real attempt.

Once your implementation passes, extend it: pick a third transformation $R$
of your own (any $2\times2$ matrix), and confirm numerically that
$(R S) T = R (S T)$ as matrices — i.e. that composition of linear
transformations is associative, which follows immediately from Theorem 3.2
applied twice plus the associativity of matrix multiplication.

## Journal template

```
## Day 3 — Linear transformations, matrix representation
Key theorem in my own words: ...
What confused me: ...
```
