# Day 5 — Gaussian Elimination, Row Reduction, Rank

## Learning objectives

By the end of today you should be able to:
- State the three elementary row operations and prove that applying any of
  them to the augmented matrix of a linear system leaves its solution set
  unchanged.
- Define row echelon form, pivot, and $\operatorname{rank}(A)$, and prove that
  $\operatorname{rank}(A)$ does not depend on which sequence of row
  operations was used to reach echelon form.
- Solve linear systems by hand via Gaussian elimination, including
  recognizing and correctly handling the inconsistent case (no solution) and
  the underdetermined case (infinitely many solutions).
- Compute the rank of a matrix by hand via row reduction, for both square and
  non-square matrices.

## Reference material

- Primer (15 min, geometric intuition): 3Blue1Brown, *Essence of Linear
  Algebra*, Chapter 6 (inverse matrices, column space, null space) —
  [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab).
  Watch this before the proofs below — it gives the geometric picture (a
  linear system as "which input lands on this output vector") that the
  algebraic manipulation below is secretly always about.
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §2.1–2.3 —
  [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  chapter on Systems of Linear Equations — if you don't have a copy, the
  exercises below are self-contained and sufficient for today.

The theory below is self-contained — you do not strictly need the Treil PDF
to do today's work, but reading his §2.1–2.3 alongside this is the "theory"
layer of today's three-layer structure.

## Theory

### Definition 5.1 (Elementary row operations)

Given a matrix $M$ with rows $R_1, \dots, R_m$, an **elementary row
operation** is one of the following three transformations:

1. **Row swap**: exchange the positions of two rows, $R_i \leftrightarrow
   R_j$.
2. **Scale**: replace $R_i$ by $cR_i$ for a nonzero scalar $c \neq 0$.
3. **Add a multiple of one row to another**: replace $R_i$ by $R_i + cR_j$
   for some scalar $c$ and some $j \neq i$ (the row $R_j$ itself is left
   unchanged).

These are the only moves Gaussian elimination is allowed to make. Notice
condition $c \neq 0$ in operation 2 — scaling by $0$ would destroy
information (it would erase row $i$ entirely), which is exactly why it's
excluded.

### Definition 5.2 (Row echelon form, pivot, rank)

A matrix $R$ is in **row echelon form (REF)** if:
(a) any rows consisting entirely of zeros are below all nonzero rows, and
(b) for each nonzero row, its leftmost nonzero entry — called the **pivot**
of that row — lies strictly to the right of the pivot of the row above it.

$R$ is in **reduced row echelon form (RREF)** if additionally every pivot
equals $1$ and every pivot is the *only* nonzero entry in its column. RREF is
a stronger, more processed form of REF; both share the same pivot positions
and the same number of nonzero rows, which is all that matters for the
definition below.

The **rank** of a matrix $A$, written $\operatorname{rank}(A)$, is the number
of pivots (equivalently, the number of nonzero rows) in any row echelon form
obtained from $A$ by a finite sequence of elementary row operations.

This definition is only legitimate if that count doesn't secretly depend on
*which* row operations you happened to perform — two people doing elimination
in a different order should get the same rank. That is Theorem 5.2 below.

### Theorem 5.1 (Elementary row operations preserve the solution set)

Let $Ax = b$ be a linear system with augmented matrix $[A \mid b]$, and let
$[A' \mid b']$ be the result of applying a single elementary row operation to
$[A \mid b]$. Then the system $A'x = b'$ has exactly the same solution set as
$Ax = b$.

**Proof.** Write the system's $m$ equations as $E_1, \dots, E_m$, where $E_i$
is $\sum_{k=1}^n a_{ik}x_k = b_i$. For a vector $x \in \mathbb{R}^n$ and an
equation $E$, say "$x$ satisfies $E$" if plugging $x$ into $E$ gives a true
statement, and write $\operatorname{Sol}(E) = \{x : x \text{ satisfies } E\}$.
The solution set of the whole system is
$$S = \operatorname{Sol}(E_1) \cap \operatorname{Sol}(E_2) \cap \cdots \cap
\operatorname{Sol}(E_m),$$
i.e. $x \in S$ exactly when $x$ satisfies every equation simultaneously. We
check each of the three operation types transforms the list of equations into
a new list with the same intersection $S$.

*Row swap.* Swapping rows $i, j$ just reorders the list $E_1, \dots, E_m$ as
a list — it is the same *set* of equations. Set intersection does not depend
on the order in which the sets are listed, so the intersection $S$ is
unchanged.

*Scale.* Replacing $E_i$ by $cE_i$ (with $c \neq 0$) leaves every other
equation untouched, so we only need $\operatorname{Sol}(E_i) =
\operatorname{Sol}(cE_i)$ as subsets of $\mathbb{R}^n$; then the intersection
with the other $m-1$ unchanged sets is unaffected.
($\subseteq$) If $x \in \operatorname{Sol}(E_i)$, i.e.
$\sum_k a_{ik}x_k = b_i$, multiply both sides by $c$:
$\sum_k (ca_{ik})x_k = cb_i$, i.e. $x$ satisfies $cE_i$.
($\supseteq$) If $x \in \operatorname{Sol}(cE_i)$, i.e.
$\sum_k (ca_{ik})x_k = cb_i$, divide both sides by $c$ — legal since
$c \neq 0$ — to get $\sum_k a_{ik}x_k = b_i$, i.e. $x$ satisfies $E_i$.
Hence $\operatorname{Sol}(E_i) = \operatorname{Sol}(cE_i)$, and $S$ is
unchanged.

*Add a multiple of one row to another.* Replacing $E_i$ by $E_i + cE_j$
($j \neq i$) leaves $E_j$ and every $E_k$ with $k \neq i$ unchanged. Let
$S = \bigcap_{k=1}^m \operatorname{Sol}(E_k)$ (old system) and
$S' = \operatorname{Sol}(E_i + cE_j) \cap \bigcap_{k \neq i}
\operatorname{Sol}(E_k)$ (new system; note $E_j$, since $j \neq i$, is
included among the unchanged equations in both $S$ and $S'$).
($S \subseteq S'$) Let $x \in S$. Then $x$ satisfies every $E_k$, in
particular $E_i$: $\sum_k a_{ik}x_k = b_i$, and $E_j$: $\sum_k a_{jk}x_k =
b_j$. Multiplying the second by $c$ and adding to the first:
$\sum_k (a_{ik} + ca_{jk})x_k = b_i + cb_j$, which says exactly that $x$
satisfies $E_i + cE_j$. Since $x$ also satisfies every $E_k$ with $k \neq i$
(as $x \in S$), $x \in S'$.
($S' \subseteq S$) Let $x \in S'$. Then $x$ satisfies $E_i + cE_j$:
$\sum_k (a_{ik}+ca_{jk})x_k = b_i + cb_j$, and $x$ satisfies $E_j$ (since
$j \neq i$, $E_j$ is one of the unchanged equations required by $S'$):
$\sum_k a_{jk}x_k = b_j$. Multiply the second equation by $c$ and subtract it
from the first: $\sum_k a_{ik}x_k = b_i$, i.e. $x$ satisfies $E_i$. Combined
with $x$ satisfying every other $E_k$ ($k \neq i$, given), $x$ satisfies
every original equation, so $x \in S$.
Hence $S = S'$.

In all three cases the solution set is unchanged by a single elementary row
operation. Applying a *finite sequence* of such operations changes the
solution set by the same amount at each step, i.e. not at all, by induction
on the number of operations applied. $\blacksquare$

This is the entire logical justification for Gaussian elimination: every
"legal move" is legal precisely because it doesn't change what counts as a
solution — it only changes how the same solution set is *described*.

### Theorem 5.2 (Rank is well-defined)

Let $A$ be an $m \times n$ matrix. If $R$ and $R'$ are two row echelon forms
obtained from $A$ by two (possibly different) finite sequences of elementary
row operations, then $R$ and $R'$ have the same number of nonzero rows.
Consequently $\operatorname{rank}(A)$ (Definition 5.2) is well-defined.

We prove this by connecting rank to the **row space** of $A$: for an
$m \times n$ matrix $A$ with rows $r_1, \dots, r_m \in \mathbb{R}^n$, define
$$\operatorname{Row}(A) = \operatorname{span}\{r_1, \dots, r_m\} \subseteq
\mathbb{R}^n.$$
($\operatorname{Row}(A)$ is a subspace of $\mathbb{R}^n$ by Theorem 1.1.)

**Lemma A (Elementary row operations preserve the row space).** If $A'$ is
obtained from $A$ by a single elementary row operation, then
$\operatorname{Row}(A') = \operatorname{Row}(A)$.

*Proof.* Let $A$ have rows $r_1, \dots, r_m$ and $A'$ have rows $r_1', \dots,
r_m'$.

*Swap:* $\{r_1', \dots, r_m'\}$ is the same set of vectors as $\{r_1, \dots,
r_m\}$, just listed in a different order, so their spans are identical.

*Scale ($r_i' = cr_i$, $c \neq 0$, $r_k' = r_k$ for $k \neq i$):* every row of
$A'$ is a linear combination of rows of $A$ ($r_i' = c \cdot r_i$, and
$r_k' = 1 \cdot r_k$), so each $r_k' \in \operatorname{Row}(A)$, and since
$\operatorname{Row}(A)$ is a subspace (closed under linear combinations),
$\operatorname{Row}(A') = \operatorname{span}\{r_1', \dots, r_m'\} \subseteq
\operatorname{Row}(A)$. This operation is reversible: scaling row $i$ of
$A'$ by $1/c$ recovers $A$ exactly, and the identical argument gives
$\operatorname{Row}(A) \subseteq \operatorname{Row}(A')$. Hence equality.

*Add a multiple ($r_i' = r_i + cr_j$, $j \neq i$, $r_k' = r_k$ for $k \neq
i$):* every row of $A'$ is again a linear combination of rows of $A$ ($r_i'$
explicitly so, and $r_k' = r_k$ for $k \neq i$), so
$\operatorname{Row}(A') \subseteq \operatorname{Row}(A)$ as above. This
operation is also reversible: since $r_j' = r_j$ is unchanged, replacing row
$i$ of $A'$ by $r_i' - cr_j' = (r_i + cr_j) - cr_j = r_i$ recovers $A$, and
the same containment argument in reverse gives
$\operatorname{Row}(A) \subseteq \operatorname{Row}(A')$. Hence equality.

In all three cases $\operatorname{Row}(A') = \operatorname{Row}(A)$.
$\blacksquare$ (Lemma A)

By induction on the number of operations applied, any finite sequence of
elementary row operations preserves the row space; in particular if $R$ is
any row echelon form reached from $A$, $\operatorname{Row}(R) =
\operatorname{Row}(A)$.

**Lemma B (Nonzero rows of an echelon form are a basis for its row space).**
If $R$ is in row echelon form with nonzero rows $\rho_1, \dots, \rho_r$
(top to bottom), then $\rho_1, \dots, \rho_r$ are linearly independent, and
hence $\dim(\operatorname{Row}(R)) = r$.

*Proof.* Let $c_1 < c_2 < \cdots < c_r$ be the pivot columns of $\rho_1,
\dots, \rho_r$ respectively (strictly increasing, by the definition of REF).
Suppose $\sum_{i=1}^r \lambda_i \rho_i = 0$ (the zero vector) for some
scalars $\lambda_i$. Examine the entry of this sum in column $c_1$: by
definition of pivot, row $\rho_i$ has a zero entry in every column strictly
to the left of its own pivot column $c_i$; since $c_1 < c_i$ for all $i \geq
2$, every row $\rho_2, \dots, \rho_r$ has a zero entry in column $c_1$. So the
column-$c_1$ entry of $\sum_i \lambda_i \rho_i$ reduces to just
$\lambda_1 \cdot (\rho_1)_{c_1}$. Since the sum is the zero vector, this
entry is $0$, and $(\rho_1)_{c_1} \neq 0$ (it is a pivot, nonzero by
definition), so $\lambda_1 = 0$. The equation now reads
$\sum_{i=2}^r \lambda_i \rho_i = 0$; repeating the identical argument at
column $c_2$ (only $\rho_2$ among $\rho_2, \dots, \rho_r$ can be nonzero
there) gives $\lambda_2 = 0$. Inducting down the pivot columns
$c_3, \dots, c_r$ gives $\lambda_i = 0$ for every $i$. Hence $\rho_1, \dots,
\rho_r$ are linearly independent. They also span $\operatorname{Row}(R)$
(the zero rows of $R$ contribute nothing to a span), so they are a basis of
$\operatorname{Row}(R)$, and $\dim(\operatorname{Row}(R)) = r$.
$\blacksquare$ (Lemma B)

**Proof of Theorem 5.2.** Let $R$ and $R'$ be two row echelon forms of $A$,
reached by possibly different sequences of elementary row operations, with
$r$ and $r'$ nonzero rows respectively. By Lemma A (applied repeatedly along
each sequence), $\operatorname{Row}(R) = \operatorname{Row}(A) =
\operatorname{Row}(R')$. By Lemma B, $r = \dim(\operatorname{Row}(R))$ and
$r' = \dim(\operatorname{Row}(R'))$. But $\operatorname{Row}(R)$ and
$\operatorname{Row}(R')$ are the *same* subspace of $\mathbb{R}^n$, and the
dimension of a vector space is a single well-defined number — any two bases
of the same vector space have the same size (established for general vector
spaces on Day 2). Hence $r = \dim(\operatorname{Row}(R)) =
\dim(\operatorname{Row}(R')) = r'$.

So every row echelon form of $A$, however it was reached, has the same
number of nonzero rows, namely $\dim(\operatorname{Row}(A))$. This justifies
Definition 5.2: $\operatorname{rank}(A) := \dim(\operatorname{Row}(A))$ is a
single well-defined number, computable by row-reducing $A$ by *any* legal
sequence of elementary row operations. $\blacksquare$

## Worked example

Solve, by hand, via Gaussian elimination:
$$2x + y - z = 3, \qquad -3x - y + 2z = -4, \qquad -2x + y + 2z = 2.$$

Set up the augmented matrix, rows labeled $R_1, R_2, R_3$:
$$\left[\begin{array}{ccc|c} 2 & 1 & -1 & 3 \\ -3 & -1 & 2 & -4 \\ -2 & 1 & 2 & 2 \end{array}\right]$$

**Step 1 — eliminate $x$ from $R_2$.** $R_2$'s $x$-coefficient is $-3$;
$R_1$'s is $2$. First scale $R_2$ by $2$ ($R_2 \to 2R_2$), then add $3R_1$
($R_2 \to R_2 + 3R_1$) — chosen so the $x$-coefficients cancel:
$2R_2 = [-6, -2, 4 \mid -8]$; $3R_1 = [6, 3, -3 \mid 9]$; sum $=
[0, 1, 1 \mid 1]$.
$$\left[\begin{array}{ccc|c} 2 & 1 & -1 & 3 \\ 0 & 1 & 1 & 1 \\ -2 & 1 & 2 & 2 \end{array}\right]$$

**Step 2 — eliminate $x$ from $R_3$.** $R_3$'s $x$-coefficient is $-2$,
exactly the negative of $R_1$'s, so a single operation suffices:
$R_3 \to R_3 + R_1$: $[-2+2,\ 1+1,\ 2-1 \mid 2+3] = [0, 2, 1 \mid 5]$.
$$\left[\begin{array}{ccc|c} 2 & 1 & -1 & 3 \\ 0 & 1 & 1 & 1 \\ 0 & 2 & 1 & 5 \end{array}\right]$$

**Step 3 — eliminate $y$ from $R_3$ using the new $R_2$.** $R_3 \to R_3 -
2R_2$: $[0-0,\ 2-2,\ 1-2 \mid 5-2] = [0, 0, -1 \mid 3]$.
$$\left[\begin{array}{ccc|c} 2 & 1 & -1 & 3 \\ 0 & 1 & 1 & 1 \\ 0 & 0 & -1 & 3 \end{array}\right]$$

This is row echelon form, with 3 pivots (columns 1, 2, 3), so
$\operatorname{rank}(A) = 3 = n$: the coefficient matrix is nonsingular and
the system has a unique solution. Back-substitute:

- $R_3$: $-z = 3 \implies z = -3$.
- $R_2$: $y + z = 1 \implies y = 1 - (-3) = 4$.
- $R_1$: $2x + y - z = 3 \implies 2x + 4 - (-3) = 3 \implies 2x = -4
  \implies x = -2$.

**Solution:** $(x, y, z) = (-2, 4, -3)$.

**Check** against all three *original* equations (not the row-reduced ones —
this is the actual test, since Theorem 5.1 only guarantees the row-reduced
system has the same solutions as the original, and a check confirms we
didn't make an arithmetic slip along the way):
$2(-2)+4-(-3) = -4+4+3=3$ ✓; $-3(-2)-4+2(-3)=6-4-6=-4$ ✓;
$-2(-2)+4+2(-3)=4+4-6=2$ ✓.

## Unconventional edge

The most seductive trap in Gaussian elimination is doing it as blind
arithmetic symbol-pushing: memorize "scale this row, subtract that row,"
produce the right numbers, and never once ask *why* any of it is legal. That
is calculator-brain wearing a pencil — it produces correct answers on
familiar-looking problems and falls apart the instant a system looks
slightly different (a coefficient is a fraction, a row needs a swap because
the natural pivot is zero, or the professor asks you to justify a step).
Every operation in the worked example above is legal for exactly one reason:
Theorem 5.1 guarantees that adding a multiple of one equation to another (or
scaling, or reordering) produces a new system whose solution set is
*identical* to the old one — you are never solving a "different, easier"
system, you are re-describing the same one from a different combination of
the original constraints. Internalizing that fact — not the mechanical
sequence of row moves — is what lets you handle inconsistent systems, free
variables, and rank computations as three faces of the same idea rather than
three separate memorized procedures.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1, 2, 3, 4, 5, 6, 7, 8 are computational; 9 and 10 are
proof-based.

1. Solve by elimination: $x + 2y = 5,\ 3x - y = 1$.
2. Solve by elimination, showing every row operation:
   $x+y+z=6,\ 2x-y+z=3,\ x+2y-z=2$.
3. Solve, or show there is no solution:
   $x+y-z=2,\ 2x+3y+z=5,\ 3x+4y=6$.
4. Solve, or describe the full solution set if there are infinitely many:
   $x+y+z=6,\ x+2y+2z=9,\ 2x+3y+3z=15$.
5. Compute $\operatorname{rank}(B)$ by row reduction, where
   $B = \begin{pmatrix}2&4&-2\\4&9&-3\\-2&-3&7\end{pmatrix}$.
6. Compute $\operatorname{rank}(C)$ by row reduction, where
   $C = \begin{pmatrix}1&2&1\\2&4&3\\3&6&4\end{pmatrix}$.
7. Compute $\operatorname{rank}(D)$ by row reduction, where
   $D = \begin{pmatrix}1&2&0&1\\2&4&1&3\\1&2&1&2\end{pmatrix}$.
8. Solve $x+2y+z-w=3,\ 2x+4y+3z-w=9$ for all $(x,y,z,w)$, expressing the
   solution set in terms of free parameter(s).
9. Prove: if a linear system $Ax=b$ has more unknowns than independent
   equations — precisely, if $A$ is $m \times n$ with
   $\operatorname{rank}(A) = r < n$ — then the system cannot have a unique
   solution (it has either no solution or infinitely many).
10. Prove (Rouché–Capelli): the system $Ax=b$ is consistent (has at least
    one solution) if and only if $\operatorname{rank}([A\mid b]) =
    \operatorname{rank}(A)$.

## Solutions

**1.** Augmented matrix $\begin{bmatrix}1&2&|&5\\3&-1&|&1\end{bmatrix}$.
$R_2 \to R_2 - 3R_1$: $[3-3,\ -1-6\mid 1-15] = [0,-7\mid-14]$. So $-7y=-14
\implies y=2$. Back-substitute: $x+2(2)=5 \implies x=1$. **Solution:**
$(x,y)=(1,2)$.

**2.** Augmented matrix:
$\left[\begin{array}{ccc|c}1&1&1&6\\2&-1&1&3\\1&2&-1&2\end{array}\right]$.
$R_2 \to R_2-2R_1$: $[0,-3,-1\mid-9]$. $R_3 \to R_3-R_1$: $[0,1,-2\mid-4]$.
$$\left[\begin{array}{ccc|c}1&1&1&6\\0&-3&-1&-9\\0&1&-2&-4\end{array}\right]$$
Scale $R_2 \to -\tfrac13 R_2$: $[0,1,\tfrac13\mid3]$. $R_3 \to R_3-R_2$:
$[0,0,-2-\tfrac13\mid-4-3]=[0,0,-\tfrac73\mid-7]$, so
$z = -7 / (-\tfrac73) = 3$. Back-substitute: $y+\tfrac13(3)=3\implies y=2$;
$x+2+3=6\implies x=1$. **Solution:** $(x,y,z)=(1,2,3)$.

**3.** Augmented matrix:
$\left[\begin{array}{ccc|c}1&1&-1&2\\2&3&1&5\\3&4&0&6\end{array}\right]$.
$R_2\to R_2-2R_1$: $[0,1,3\mid1]$. $R_3\to R_3-3R_1$: $[0,1,3\mid0]$.
$$\left[\begin{array}{ccc|c}1&1&-1&2\\0&1&3&1\\0&1&3&0\end{array}\right]$$
$R_3 \to R_3 - R_2$: $[0,0,0\mid-1]$. This row reads $0=-1$, a
contradiction. **No solution** — the system is inconsistent. (Note
$\operatorname{rank}(A)=2$ but $\operatorname{rank}([A\mid b])=3$; this is
exactly the Rouché–Capelli criterion from Exercise 10.)

**4.** Augmented matrix:
$\left[\begin{array}{ccc|c}1&1&1&6\\1&2&2&9\\2&3&3&15\end{array}\right]$.
$R_2\to R_2-R_1$: $[0,1,1\mid3]$. $R_3\to R_3-2R_1$: $[0,1,1\mid3]$.
$$\left[\begin{array}{ccc|c}1&1&1&6\\0&1&1&3\\0&1&1&3\end{array}\right]$$
$R_3 \to R_3-R_2$: $[0,0,0\mid0]$ — a trivial row ($0=0$), so the third
equation carried no independent information (consistent with
$R_3=R_1+R_2$ in the original system). Only $2$ independent equations
remain for $3$ unknowns, so there is (at least) $3-2=1$ free variable.
Let $z=t$ be free. From $R_2$: $y+z=3 \implies y=3-t$. From $R_1$:
$x+y+z=6 \implies x=6-(3-t)-t=3$. **Solution set:**
$(x,y,z)=(3,\,3-t,\,t)$ for $t \in \mathbb{R}$ — infinitely many solutions.

**5.** $\left[\begin{array}{ccc}2&4&-2\\4&9&-3\\-2&-3&7\end{array}\right]$.
$R_2\to R_2-2R_1$: $[0,1,1]$. $R_3\to R_3+R_1$: $[0,1,5]$.
$$\left[\begin{array}{ccc}2&4&-2\\0&1&1\\0&1&5\end{array}\right]$$
$R_3\to R_3-R_2$: $[0,0,4]$. Three nonzero rows, pivots in all three
columns. $\operatorname{rank}(B)=3$ (full rank).

**6.** $\left[\begin{array}{ccc}1&2&1\\2&4&3\\3&6&4\end{array}\right]$.
$R_2\to R_2-2R_1$: $[0,0,1]$. $R_3\to R_3-3R_1$: $[0,0,1]$.
$$\left[\begin{array}{ccc}1&2&1\\0&0&1\\0&0&1\end{array}\right]$$
$R_3\to R_3-R_2$: $[0,0,0]$. Two nonzero rows (pivots in columns 1 and 3;
column 2 never gets a pivot, since column 2 $=2\times$ column 1 in the
original matrix — no elimination step can create a pivot out of a column
that's already dependent on an earlier one). $\operatorname{rank}(C)=2$.

**7.** $\left[\begin{array}{cccc}1&2&0&1\\2&4&1&3\\1&2&1&2\end{array}\right]$.
$R_2\to R_2-2R_1$: $[0,0,1,1]$. $R_3\to R_3-R_1$: $[0,0,1,1]$.
$$\left[\begin{array}{cccc}1&2&0&1\\0&0&1&1\\0&0&1&1\end{array}\right]$$
$R_3\to R_3-R_2$: $[0,0,0,0]$. Two nonzero rows, pivots in columns 1 and 3.
$\operatorname{rank}(D)=2$.

**8.** Augmented matrix
$\left[\begin{array}{cccc|c}1&2&1&-1&3\\2&4&3&-1&9\end{array}\right]$.
$R_2\to R_2-2R_1$: $[0,0,1,1\mid3]$.
$$\left[\begin{array}{cccc|c}1&2&1&-1&3\\0&0&1&1&3\end{array}\right]$$
Pivots are in columns 1 ($x$) and 3 ($z$); columns 2 ($y$) and 4 ($w$) have
no pivot, so $y$ and $w$ are free. Let $y=s,\ w=t$. From $R_2$: $z+w=3
\implies z=3-t$. From $R_1$: $x+2y+z-w=3 \implies x = 3-2s-(3-t)+t =
-2s+2t$. **Solution set:** $(x,y,z,w) = (-2s+2t,\ s,\ 3-t,\ t)$ for
$s,t \in \mathbb{R}$ — a 2-parameter family of infinitely many solutions.

**9.** Row-reduce the augmented matrix $[A \mid b]$ to echelon form
$[A' \mid b']$; by Theorem 5.1 this system has the same solutions as the
original. Let $r = \operatorname{rank}(A)$, i.e. $A'$ has $r$ nonzero rows,
and by hypothesis $r < n$.

*Case 1: the reduced system is inconsistent*, i.e. some row of $[A' \mid
b']$ reads $0 = c$ with $c \neq 0$ (all $A$-entries zero, $b$-entry
nonzero). Then no $x$ satisfies that equation, so the system has **no
solution** — in particular not a unique one.

*Case 2: the reduced system is consistent*, i.e. no such contradictory row
exists. Among the $n$ variables, exactly $r$ correspond to pivot columns of
$A'$ ("pivot variables"); the remaining $n - r \geq 1$ variables correspond
to non-pivot columns ("free variables"), since $r < n$. Assign the free
variables any values in $\mathbb{R}$ — this is always possible since they
appear in no pivot row's leading position — and then the $r$ pivot
variables are each uniquely forced by back-substitution through the $r$
pivot equations (each pivot equation determines its pivot variable in terms
of variables to its right, which are either already-assigned free variables
or already-determined later pivot variables). This produces a valid
solution *for every choice* of the $n-r \geq 1$ free variable(s). Since
$\mathbb{R}$ has infinitely many elements and $n - r \geq 1$, there are
infinitely many distinct choices of the free variable(s), each producing a
distinct solution (different free-variable values give different vectors
$x$, since those coordinates of $x$ literally are the free variables). So
the system has **infinitely many solutions**.

In both cases the system does not have a unique solution. $\blacksquare$

**10.** ($\Leftarrow$) Suppose $\operatorname{rank}([A\mid b]) =
\operatorname{rank}(A) = r$. Row-reduce $[A \mid b]$ to echelon form
$[A' \mid b']$; then $A'$ (the first $n$ columns) is *a* row echelon form of
$A$, so by Theorem 5.2, $A'$ has exactly $r = \operatorname{rank}(A)$
nonzero rows, meaning rows $r+1, \ldots, m$ of $A'$ are entirely zero. Since
$\operatorname{rank}([A\mid b]) = r$ too, the augmented matrix $[A'\mid b']$
also has only $r$ nonzero rows — no *additional* pivot appears in the
$b'$-column. In particular, for each all-zero row of $A'$ (rows $r+1,
\ldots, m$), the corresponding entry of $b'$ must also be $0$: if some such
$b'_i \neq 0$, that row $[0,\ldots,0 \mid b'_i]$ would itself be a nonzero
row of $[A'\mid b']$ with a pivot in the augmented column, forcing
$\operatorname{rank}([A\mid b]) \geq r+1$, contradicting
$\operatorname{rank}([A\mid b])=r$. So every one of those rows reads
$0 = 0$ — no contradiction. The remaining $r$ pivot rows can always be
satisfied by back-substitution (as in Exercise 9's Case 2, assigning free
variables arbitrarily and solving pivot variables in terms of them). Hence a
solution exists: the system is **consistent**.

($\Rightarrow$) Suppose $Ax = b$ is consistent, so it has at least one
solution $\bar{x}$. Row-reduce $[A \mid b]$ to echelon form $[A' \mid b']$
using the same operations that reduce $A$ to $A'$ (a row echelon form of
$A$, with $\operatorname{rank}(A) = r$ nonzero rows by Theorem 5.2); by
Theorem 5.1, $\bar x$ is also a solution of the reduced system $A'x = b'$.
Suppose toward a contradiction that
$\operatorname{rank}([A\mid b]) > \operatorname{rank}(A) = r$: since $A'$
has only $r$ nonzero rows, this means some row $i > r$ of $[A' \mid b']$ —
which is entirely zero in its $A'$-part (rows past the $r$-th are zero in
$A'$) — is nonzero overall, i.e. has $b'_i \neq 0$. That row reads
$0 = b'_i \neq 0$, which $\bar x$ cannot satisfy — contradicting that
$\bar x$ solves the reduced system. So no such row exists, and
$\operatorname{rank}([A\mid b]) = \operatorname{rank}(A)$.

Both directions hold, proving the equivalence. $\blacksquare$

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements Gaussian elimination itself, from scratch — the
by-hand procedure you just did nine times, turned into code with no
shortcuts. Open `starter_code/day05_gaussian_elimination.py` — it has one
function to complete, `row_echelon`, which must reduce a matrix to reduced
row echelon form using only explicit loops over rows and columns (no
`np.linalg.solve`, no built-in rref routine — those are only allowed
afterward, to check your answer). Fill in the `TODO`, then run the file
directly (`python starter_code/day05_gaussian_elimination.py`); it should
print your row echelon form and confirm the rank matches
`np.linalg.matrix_rank`.

**Hint:** work one column at a time, left to right, tracking a
`pivot_row` counter starting at 0. For each column: scan rows from
`pivot_row` down for a nonzero entry (that row becomes the new pivot row —
swap it into place); if every entry in that column at or below `pivot_row`
is zero, there's no pivot in this column, so move to the next column
without advancing `pivot_row`. Otherwise, scale the pivot row so its pivot
entry is exactly $1$, then subtract the right multiple of the pivot row from
*every other row* (not just the ones below — that's what makes it *reduced*
row echelon form rather than plain echelon form) so that column becomes all
zeros elsewhere. Advance `pivot_row` by 1 and continue; stop early if
`pivot_row` reaches the number of rows.

If you get stuck for more than ~10 minutes, check
`solutions/day05_gaussian_elimination.py` — but only after a real attempt.

Once your implementation passes, extend it: run `row_echelon` on the
coefficient matrices from Exercises 5, 6, and 7 (including $C$, which is
rank-deficient — a genuinely singular case, unlike the worked example) and
confirm the ranks you got by hand match what your code and
`np.linalg.matrix_rank` report.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $R_i \leftrightarrow R_j$ | "swap rows $i$ and $j$" | the first elementary row operation |
| $R_i \to R_i + cR_j$ | "replace row $i$ by itself plus $c$ times row $j$" | the third (and most-used) row operation |
| $[A \mid b]$ | "the augmented matrix" | the coefficients $A$ with the right-hand side $b$ tacked on |
| $\operatorname{rank}(A)$ | "the rank of $A$" | the number of pivots (nonzero rows) in any echelon form |
| $\operatorname{Row}(A)$ | "the row space of $A$" | the span of $A$'s rows |
| $\operatorname{Sol}(E)$ | "the solution set of equation $E$" | all $x$ that satisfy that one equation |
| $\cap$, $\bigcap$ | "intersection (of many sets)" | the system's solution set = intersection of each equation's solutions |
| $\subseteq$, $\supseteq$ | "is contained in / contains" | the two halves of proving two sets equal |
| $\neq$ | "is not equal to" | a scale factor $c \neq 0$; pivots are nonzero |
| $\dim$ | "dimension" | rank equals the dimension of the row space |
| $\lambda_i$, $\rho_i$ | "lambda-i, rho-i — just names for scalars and rows" | coefficients and rows inside the independence argument (not eigenvalues yet) |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- The three elementary row operations never change a system's solution set —
  they only re-describe it.
- Gaussian elimination is therefore always solving the *same* system, just in
  an easier-to-read form.
- A matrix's rank — its number of pivots — is the same no matter which legal
  sequence of row operations you use.
- Rank equals the dimension of the row space, which is exactly why it cannot
  depend on the path taken to echelon form.
- Reading the echelon form tells you the outcome: a contradictory row means no
  solution; a pivotless column means a free variable and infinitely many
  solutions.

### Proof sketches

**Theorem 5.1 — key trick: view the solution set as the intersection of each
equation's solutions, and note every operation is reversible.**
Write the whole system's solution set as the intersection of the solution
sets of the individual equations. A swap just reorders that intersection.
Scaling an equation by a nonzero $c$ gives an equation with identical
solutions (divide by $c$ to undo it). Adding $c$ times one equation to
another can be undone by subtracting, so it too preserves the solutions.
Since each single move preserves the intersection, so does any finite
sequence. Full version: Theorem 5.1 above.

**Theorem 5.2 — key trick: row operations preserve the row space, and the
nonzero echelon rows are a basis of it, so their count is pinned down.**
Two supporting facts. First (Lemma A), each row operation is reversible and
only replaces rows by combinations of rows, so the row space never changes.
Second (Lemma B), in any echelon form the nonzero rows are independent — the
staircase of pivots lets you knock out one coefficient per column — so they
form a basis of the row space. Any two echelon forms of $A$ are therefore
bases of the *same* subspace, and all bases of a space have the same size
(Day 2), so their nonzero-row counts must match. Full version: Theorem 5.2
above.

### If you remember only 3 things

1. Every elementary row operation keeps the solution set identical — that
   single fact is *why* elimination is valid.
2. Rank = number of pivots = dimension of the row space, and it is
   independent of how you reduce.
3. Read the echelon form: a row saying $0 = (\text{nonzero})$ means no
   solution; a column with no pivot means a free variable and infinitely many
   solutions.

## Journal template

```
## Day 5 — Gaussian elimination, rank
Key theorem in my own words: ...
What confused me: ...
```
