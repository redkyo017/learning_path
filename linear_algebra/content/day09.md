# Day 9 — Invertibility, Matrix Inverse, LU Decomposition

## Learning objectives

By the end of today you should be able to:
- Define elementary matrices and prove they implement elementary row
  operations under left multiplication.
- Prove that the inverse of an invertible matrix is unique, and that
  $(AB)^{-1} = B^{-1}A^{-1}$ for invertible $A, B$ of the same size.
- Prove that every invertible $n \times n$ matrix is a product of elementary
  matrices, and explain why this is the theoretical justification for
  Gauss-Jordan elimination as an inversion algorithm.
- Prove that elimination-without-row-swaps produces an $LU$ decomposition,
  and compute one by hand.
- Compute the inverse of a $2\times2$ or $3\times3$ matrix by hand via
  Gauss-Jordan elimination on $[A \mid I]$.

## Reference material

- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §2.5 and
  Chapter 3 — [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf).
  §2.5 covers elementary matrices and computing inverses by row reduction;
  Chapter 3 covers determinants, but the LU material in this section draws
  on the elimination-as-matrix-multiplication idea introduced there.
- There is no dedicated 3Blue1Brown video for elementary matrices or LU
  decomposition specifically — instead, re-watch *Essence of Linear
  Algebra*, Chapter 7 (inverse matrices) —
  [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab)
  — as a refresher on what invertibility *means* geometrically (an
  invertible matrix is one whose transformation can be undone, i.e. it
  doesn't collapse space to a lower dimension) before diving into today's
  proofs about *how* to compute the inverse.
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  chapter on Algebra of Matrices — if you don't have a copy, the exercises
  below are self-contained and sufficient for today.

## Theory

### Definition 9.1 (Invertible matrix, inverse)

An $n \times n$ matrix $A$ is **invertible** (or **nonsingular**) if there
exists an $n \times n$ matrix $B$ such that
$$AB = BA = I_n.$$
Any such $B$ is called **an inverse** of $A$. A matrix that is not
invertible is called **singular**.

### Definition 9.2 (Elementary matrix)

An **elementary matrix** is a matrix obtained by applying a single
elementary row operation (Definition 5.1) to the identity matrix $I_n$.
Writing $e_k$ for the row vector with a $1$ in position $k$ and $0$
elsewhere (so row $k$ of $I_n$ is $e_k$), the three types are:

1. $E_{\mathrm{swap}}(i,j)$: rows $i, j$ of $I_n$ swapped (row $i$ becomes
   $e_j$, row $j$ becomes $e_i$, all other rows unchanged).
2. $E_{\mathrm{scale}}(i,c)$, $c \neq 0$: row $i$ of $I_n$ scaled by $c$
   (row $i$ becomes $ce_i$, all other rows unchanged).
3. $E_{\mathrm{add}}(i,j,c)$, $j \neq i$: row $i$ of $I_n$ replaced by
   row $i$ plus $c$ times row $j$ (row $i$ becomes $e_i + ce_j$, all other
   rows unchanged).

### Lemma 9.1 (Elementary matrices implement row operations)

Let $E$ be the $n \times n$ elementary matrix corresponding to a given
elementary row operation, and let $M$ be any matrix with $n$ rows. Then
$EM$ equals the result of applying that same row operation to $M$.

**Proof.** By the definition of matrix multiplication, row $i$ of $EM$ is
$$\text{row}_i(EM) = \sum_{l=1}^n E_{il}\, \text{row}_l(M),$$
i.e. row $i$ of $EM$ is the linear combination of the rows of $M$ whose
coefficients are exactly the entries of row $i$ of $E$. We check each type.

*Swap $E_{\mathrm{swap}}(i,j)$.* Row $i$ of $E$ is $e_j$ (a $1$ in position
$j$, else $0$), so $\text{row}_i(EM) = \sum_l (e_j)_l \,\text{row}_l(M) =
\text{row}_j(M)$. Symmetrically $\text{row}_j(EM) = \text{row}_i(M)$. For
any other row $k \neq i,j$, row $k$ of $E$ is $e_k$, so
$\text{row}_k(EM) = \text{row}_k(M)$. So $EM$ is $M$ with rows $i,j$
swapped — exactly the row operation.

*Scale $E_{\mathrm{scale}}(i,c)$.* Row $i$ of $E$ is $ce_i$, so
$\text{row}_i(EM) = \sum_l (ce_i)_l\,\text{row}_l(M) = c\,\text{row}_i(M)$.
Every other row $k \neq i$ of $E$ is $e_k$, so $\text{row}_k(EM) =
\text{row}_k(M)$. So $EM$ is $M$ with row $i$ scaled by $c$ — exactly the
row operation.

*Add $E_{\mathrm{add}}(i,j,c)$.* Row $i$ of $E$ is $e_i + ce_j$, so
$\text{row}_i(EM) = \sum_l (e_i+ce_j)_l\,\text{row}_l(M) = \text{row}_i(M)
+ c\,\text{row}_j(M)$. Every other row $k \neq i$ of $E$ is $e_k$, so
$\text{row}_k(EM) = \text{row}_k(M)$. So $EM$ is $M$ with row $i$ replaced
by row $i$ plus $c$ times row $j$ — exactly the row operation.
$\blacksquare$

### Theorem 9.1 (Uniqueness of the inverse; inverse of a product)

(a) If $A$ is invertible, its inverse is unique. (We may therefore write
*the* inverse as $A^{-1}$.)

(b) If $A$ and $B$ are invertible $n \times n$ matrices, then $AB$ is
invertible and $(AB)^{-1} = B^{-1}A^{-1}$.

**Proof.**

*(a)* Suppose $B$ and $C$ both satisfy the defining condition for an
inverse of $A$: $AB = BA = I$ and $AC = CA = I$. Then
$$B = BI = B(AC) = (BA)C = IC = C,$$
using associativity of matrix multiplication, $AC = I$, $BA = I$, and the
identity property of $I$. So any two inverses of $A$ coincide: the inverse
is unique.

*(b)* We claim $B^{-1}A^{-1}$ satisfies the defining condition for an
inverse of $AB$. Compute, using associativity:
$$(AB)(B^{-1}A^{-1}) = A(BB^{-1})A^{-1} = A I A^{-1} = AA^{-1} = I,$$
$$(B^{-1}A^{-1})(AB) = B^{-1}(A^{-1}A)B = B^{-1} I B = B^{-1}B = I.$$
Both products equal $I$, so by Definition 9.1, $AB$ is invertible and
$B^{-1}A^{-1}$ is an inverse of $AB$. By part (a), the inverse of $AB$ is
unique, so $(AB)^{-1} = B^{-1}A^{-1}$. $\blacksquare$

**Corollary (extension to $k$ factors).** By induction on $k$ using part
(b): if $A_1, \dots, A_k$ are invertible $n \times n$ matrices, then
$A_1A_2\cdots A_k$ is invertible with
$$(A_1A_2\cdots A_k)^{-1} = A_k^{-1}\cdots A_2^{-1}A_1^{-1}.$$
*Base case* $k=1$ is trivial. *Inductive step:* if the claim holds for
$k-1$ factors, write $A_1\cdots A_k = (A_1 \cdots A_{k-1})A_k$, a product of
two invertible matrices (the first by the inductive hypothesis, the second
by assumption), so by part (b), $(A_1\cdots A_k)^{-1} = A_k^{-1}(A_1\cdots
A_{k-1})^{-1} = A_k^{-1}(A_{k-1}^{-1}\cdots A_1^{-1})$ using the inductive
hypothesis for the second factor. This is used below.

### Lemma 9.2 (Elementary matrices are invertible, with elementary inverses)

Each elementary matrix is invertible, and its inverse is again an
elementary matrix of the same type:
$$E_{\mathrm{swap}}(i,j)^{-1} = E_{\mathrm{swap}}(i,j), \qquad
E_{\mathrm{scale}}(i,c)^{-1} = E_{\mathrm{scale}}(i,1/c), \qquad
E_{\mathrm{add}}(i,j,c)^{-1} = E_{\mathrm{add}}(i,j,-c).$$

**Proof.** In each case we exhibit a two-sided inverse directly, using
Lemma 9.1 applied twice (apply operation 1 to $I$ to get $E_1$, then apply
operation 2 to $E_1$ — the result is $E_2E_1$ by Lemma 9.1).

*Swap.* Applying the swap $(i,j)$ to $I$ twice returns $I$ (swapping the
same two rows twice undoes itself), so by Lemma 9.1,
$E_{\mathrm{swap}}(i,j) \cdot E_{\mathrm{swap}}(i,j) = I$; since the two
factors are identical this single equation is both $EE=I$ and $EE=I$, i.e.
$E_{\mathrm{swap}}(i,j)$ is its own inverse.

*Scale.* Applying "scale row $i$ by $c$" to $I$ gives $E_{\mathrm{scale}}
(i,c)$; applying "scale row $i$ by $1/c$" to that result multiplies row $i$
by $c \cdot (1/c) = 1$, recovering $I$. By Lemma 9.1 this says
$E_{\mathrm{scale}}(i,1/c)\, E_{\mathrm{scale}}(i,c) = I$. Applying the two
scalings in the opposite order also recovers $I$ (scaling is commutative in
its effect on a single row), giving $E_{\mathrm{scale}}(i,c)\,
E_{\mathrm{scale}}(i,1/c) = I$ as well. So $E_{\mathrm{scale}}(i,c)$ is
invertible with inverse $E_{\mathrm{scale}}(i,1/c)$.

*Add.* Applying "row $i \mathrel{+}= c\cdot$row $j$" to $I$ gives
$E_{\mathrm{add}}(i,j,c)$, whose row $i$ is $e_i + ce_j$ and whose row $j$
is unchanged, $e_j$. Now apply "row $i \mathrel{-}= c\cdot$row $j$" to this
result: row $j$ is untouched (still $e_j$), and row $i$ becomes
$(e_i + ce_j) - ce_j = e_i$ — we recover $I$. By Lemma 9.1 this says
$E_{\mathrm{add}}(i,j,-c)\,E_{\mathrm{add}}(i,j,c) = I$. Running the same
computation in the other order (apply $-c$ first, then $c$) likewise
recovers $I$, giving $E_{\mathrm{add}}(i,j,c)\,E_{\mathrm{add}}(i,j,-c) =
I$. So $E_{\mathrm{add}}(i,j,c)$ is invertible with inverse
$E_{\mathrm{add}}(i,j,-c)$.

In every case the inverse exhibited is again an elementary matrix of the
same type. $\blacksquare$

### Theorem 9.2 (Every invertible matrix is a product of elementary matrices)

If $A$ is an invertible $n \times n$ matrix, then $A$ can be written as a
product of finitely many elementary matrices.

**Proof.** *Step 1: $A$ has $n$ pivots.* Since $A$ is invertible, Day 6
Exercise 7 gives $N(A) = \{0\}$ (an invertible matrix has trivial null
space — the direct argument there: $Ax=0 \implies x = A^{-1}(Ax) =
A^{-1}0 = 0$). By the Fundamental Theorem of Linear Algebra, Part 1 (Day 6,
Theorem 6.1), $\dim N(A) = n - r$ where $r = \operatorname{rank}(A)$. Since
$\dim N(A) = 0$, we get $r = n$: any row echelon form of $A$ has $n$
pivots. (Equivalently, once determinants are available on Day 8,
$\det A \neq 0$ gives the same conclusion — the two criteria for
invertibility agree, but we only need the rank version here, already
established.)

*Step 2: row-reducing $A$ reaches $I_n$ exactly.* Continue Gauss-Jordan
elimination on $A$ until reaching reduced row echelon form $R$. Since $A$
is $n\times n$ and has $n$ pivots (Step 1), $R$ has one pivot in each of
its $n$ rows and, since there are only $n$ columns, one pivot in each
column too. By Definition 5.2, pivot columns strictly increase as you read
down the rows of an echelon form; with exactly $n$ pivots occupying all $n$
columns across $n$ rows, the only possibility is that the pivot of row $i$
sits in column $i$ for every $i$. Reduced row echelon form additionally
requires every pivot to equal $1$ and to be the only nonzero entry in its
column (Definition 5.2); combined with "pivot of row $i$ is in column $i$,"
every off-diagonal entry of $R$ is $0$ and every diagonal entry is $1$.
Hence $R = I_n$.

*Step 3: assemble the elementary matrices.* The reduction from $A$ to
$I_n$ is a finite sequence of elementary row operations; let $E_1, \dots,
E_k$ be the corresponding elementary matrices, in the order the operations
were applied. By Lemma 9.1, applying $E_1$ then $E_2$ then $\cdots$ then
$E_k$ to $A$ corresponds to left multiplication in that order, i.e.
$$E_k E_{k-1} \cdots E_1 A = I_n.$$
By Lemma 9.2, each $E_t$ is invertible, so by the Corollary to Theorem 9.1,
the product $M = E_k \cdots E_1$ is invertible with
$$M^{-1} = E_1^{-1} E_2^{-1} \cdots E_k^{-1}.$$
From $MA = I_n$, multiply both sides on the left by $M^{-1}$:
$$A = M^{-1}(MA) = M^{-1} I_n = M^{-1} = E_1^{-1}E_2^{-1}\cdots E_k^{-1}.$$
By Lemma 9.2, each $E_t^{-1}$ is itself an elementary matrix. So $A$ is
exhibited as a product of $k$ elementary matrices. $\blacksquare$

This theorem is exactly why Gauss-Jordan elimination on $[A \mid I]$
*computes* $A^{-1}$: since $A = E_1^{-1}\cdots E_k^{-1}$, we have
$A^{-1} = E_k \cdots E_1 = E_k \cdots E_1 \cdot I$ — literally the product
of the same elementary matrices that row-reduce $A$ to $I$, applied instead
to $I$. Performing those operations on the augmented block $I$ while
performing them on $A$ (which is exactly what the augmented-matrix
algorithm does side by side) computes $A^{-1}$ automatically.

### Lemma 9.3 (Products and inverses of unit lower-triangular matrices)

Call an $n\times n$ matrix $P$ **unit lower triangular** if $P_{ij} = 0$
for all $i < j$ (lower triangular) and $P_{ii} = 1$ for all $i$ (unit
diagonal). Then:

(a) The product of two unit lower-triangular matrices is unit lower
triangular.

(b) The inverse of a unit lower-triangular matrix is unit lower triangular.

**Proof.**

*(a)* Let $P, Q$ be unit lower triangular. For $i < j$:
$$(PQ)_{ij} = \sum_{k=1}^n P_{ik}Q_{kj}.$$
A term $P_{ik}Q_{kj}$ can be nonzero only if $P_{ik} \neq 0$, which forces
$k \leq i$ (since $P$ is lower triangular, $P_{ik}=0$ for $k>i$), *and*
$Q_{kj}\neq 0$, which forces $k \geq j$ (since $Q$ is lower triangular,
$Q_{kj}=0$ for $k<j$). So a nonzero term requires $j \leq k \leq i$; but
$i<j$ makes this range empty, so every term is $0$ and $(PQ)_{ij}=0$.
Hence $PQ$ is lower triangular. For the diagonal, $(PQ)_{ii} =
\sum_k P_{ik}Q_{ki}$; by the same reasoning a nonzero term needs $k \leq i$
and $k \geq i$, i.e. $k=i$ exactly, so $(PQ)_{ii} = P_{ii}Q_{ii} = 1\cdot
1 = 1$. So $PQ$ is unit lower triangular. By induction, any finite product
of unit lower-triangular matrices is unit lower triangular.

*(b)* Let $P$ be unit lower triangular. Since every diagonal entry of $P$
is $1 \neq 0$, $P$ already has a nonzero entry in "pivot position" $(i,i)$
for each $i$ before any elimination — running Gauss-Jordan elimination on
$P$ therefore never needs a row swap or a scaling step to produce a pivot:
using only "subtract a multiple of row $j$ from row $i$ with $i>j$" steps
(each such step is left multiplication by some $E_{\mathrm{add}}(i,j,-c)$
with $i>j$, which is itself unit lower triangular, since it differs from
$I$ only in the strictly-below-diagonal position $(i,j)$), we can clear
every below-diagonal entry of $P$ column by column, left to right, reaching
exactly $I_n$ (the diagonal entries are already $1$, so no scaling step is
ever needed). Let $F_1, \dots, F_s$ be these elementary matrices, in
order, so
$$F_s F_{s-1}\cdots F_1 P = I_n.$$
Let $C = F_s\cdots F_1$. By part (a) (applied inductively to the $F_t$,
each of which is unit lower triangular by construction), $C$ is unit lower
triangular. Each $F_t$ is invertible (Lemma 9.2), so $C$ is invertible (the
Corollary to Theorem 9.1), and $CP = I_n$ together with uniqueness of
inverses (Theorem 9.1a: from $CP=I$, multiplying both sides by $C^{-1}$ on
the left gives $P = C^{-1}$, i.e. $C = P^{-1}$) gives $P^{-1} = C$. Since
$C$ is unit lower triangular, so is $P^{-1}$. $\blacksquare$

### Theorem 9.3 (LU decomposition without row swaps)

Suppose Gaussian elimination reduces an $n\times n$ matrix $A$ to upper
triangular form $U$ using only "add a multiple of one row to a row below
it" operations (no row swaps, no scaling). Then $A = LU$, where $L$ is
lower triangular with $1$'s on the diagonal.

**Proof.** Each elimination step used is of the form "row $i$
$\mathrel{+}= c \cdot$ row $j$" with $i > j$ (a lower row absorbing a
multiple of a row above it, to clear an entry below the diagonal), which is
left multiplication by $E_{\mathrm{add}}(i,j,c)$ with $i>j$. This matrix
equals $I_n$ except for the single off-diagonal entry $c$ in position
$(i,j)$ with $i > j$ — a strictly-below-diagonal position — so it is unit
lower triangular (Lemma 9.3's terminology: lower triangular with all
diagonal entries $1$, since the diagonal of $I_n$ is untouched by this
operation).

Let $E_1, \dots, E_k$ be the elementary matrices for the elimination steps,
in the order applied, so by Lemma 9.1,
$$E_k E_{k-1} \cdots E_1 A = U.$$
Let $M = E_k \cdots E_1$. Each $E_t$ is unit lower triangular (shown
above), so by Lemma 9.3(a) applied inductively, $M$ is unit lower
triangular. Each $E_t$ is invertible (Lemma 9.2), so $M$ is invertible (the
Corollary to Theorem 9.1). From $MA = U$, multiply both sides on the left
by $M^{-1}$:
$$A = M^{-1}U.$$
Set $L := M^{-1}$. By Lemma 9.3(b), the inverse of a unit lower-triangular
matrix is unit lower triangular, so $L$ is lower triangular with $1$'s on
the diagonal. Hence $A = LU$ with $L$ unit lower triangular and $U$ upper
triangular. $\blacksquare$

In practice you never compute $L$ by literally inverting $M$: because each
$E_t$ only ever *subtracts* a multiple of a row from a row below it, the
entries of $L$ can be read off directly as the *negatives* of the
multipliers used during elimination, placed at position $(i,j)$ for the
step that cleared entry $(i,j)$ — this shortcut is used in the worked
example of Exercise 5 below and is justified by the explicit inverse
formula for $E_{\mathrm{add}}(i,j,c)$ in Lemma 9.2.

## Worked example

**Compute $A^{-1}$ for $A = \begin{pmatrix}4&3\\6&3\end{pmatrix}$ by
Gauss-Jordan elimination, and verify $AA^{-1}=I$.**

Form the augmented matrix $[A \mid I]$:
$$\left[\begin{array}{cc|cc} 4 & 3 & 1 & 0 \\ 6 & 3 & 0 & 1 \end{array}\right]$$

**Step 1 — scale $R_1$ so its pivot is $1$.** $R_1 \to \tfrac14 R_1$:
$$\left[\begin{array}{cc|cc} 1 & \tfrac34 & \tfrac14 & 0 \\ 6 & 3 & 0 & 1 \end{array}\right]$$

**Step 2 — eliminate column 1 from $R_2$.** $R_2 \to R_2 - 6R_1$:
$3 - 6\cdot\tfrac34 = 3 - \tfrac{18}{4} = -\tfrac32$;
$0 - 6\cdot\tfrac14 = -\tfrac64 = -\tfrac32$; $1 - 0 = 1$.
$$\left[\begin{array}{cc|cc} 1 & \tfrac34 & \tfrac14 & 0 \\ 0 & -\tfrac32 & -\tfrac32 & 1 \end{array}\right]$$

**Step 3 — scale $R_2$ so its pivot is $1$.** $R_2 \to -\tfrac23 R_2$:
$-\tfrac32\cdot(-\tfrac23) = 1$ ✓ pivot; $-\tfrac32\cdot(-\tfrac23)=1$;
$1\cdot(-\tfrac23) = -\tfrac23$.
$$\left[\begin{array}{cc|cc} 1 & \tfrac34 & \tfrac14 & 0 \\ 0 & 1 & 1 & -\tfrac23 \end{array}\right]$$

**Step 4 — eliminate column 2 from $R_1$.** $R_1 \to R_1 - \tfrac34 R_2$:
$\tfrac14 - \tfrac34\cdot 1 = \tfrac14-\tfrac34 = -\tfrac12$;
$0 - \tfrac34\cdot(-\tfrac23) = \tfrac12$.
$$\left[\begin{array}{cc|cc} 1 & 0 & -\tfrac12 & \tfrac12 \\ 0 & 1 & 1 & -\tfrac23 \end{array}\right]$$

The right block is now $A^{-1}$:
$$A^{-1} = \begin{pmatrix} -\tfrac12 & \tfrac12 \\ 1 & -\tfrac23 \end{pmatrix}.$$

**Verify $AA^{-1} = I$:**
$$\begin{pmatrix}4&3\\6&3\end{pmatrix}\begin{pmatrix}-\tfrac12&\tfrac12\\1&-\tfrac23\end{pmatrix}
= \begin{pmatrix}4(-\tfrac12)+3(1) & 4(\tfrac12)+3(-\tfrac23) \\ 6(-\tfrac12)+3(1) & 6(\tfrac12)+3(-\tfrac23)\end{pmatrix}
= \begin{pmatrix}-2+3 & 2-2 \\ -3+3 & 3-2\end{pmatrix}
= \begin{pmatrix}1&0\\0&1\end{pmatrix}. \checkmark$$

## Unconventional edge

It is tempting, once you meet the adjugate/determinant formula
$A^{-1} = \frac{1}{\det A}\operatorname{adj}(A)$ (coming properly on Day
8), to treat it as "the" way to compute an inverse and Gauss-Jordan as a
lesser, more mechanical backup. This is backwards, and not just for
efficiency reasons (the adjugate formula requires $n^2$ cofactor
determinants, each itself an $(n-1)\times(n-1)$ determinant — computationally
disastrous beyond $3\times3$, while Gauss-Jordan is $O(n^3)$). The deeper
point is conceptual: Theorem 9.2 above proves that invertible matrices
*are*, by definition of the proof, products of elementary matrices
recovered by row-reducing to $I$ — Gauss-Jordan is not "a" method that
happens to also produce the inverse, it is the literal mechanism the
existence proof invokes. Understanding why Gauss-Jordan on $[A \mid I]$
works *is* understanding why an inverse exists at all and why the adjugate
formula gives the same answer; treating the adjugate formula as the
"real" definition and Gauss-Jordan as a computational shortcut gets the
logical dependency exactly backwards.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–5 and 9 are computational; 6 is a trap; 7–8 are
proof-based.

1. Compute $A^{-1}$ for $A = \begin{pmatrix}2&1\\7&4\end{pmatrix}$ via
   Gauss-Jordan elimination on $[A\mid I]$, showing every step.
2. Compute $B^{-1}$ for $B = \begin{pmatrix}1&2\\3&4\end{pmatrix}$ via
   Gauss-Jordan elimination, showing every step.
3. Compute $C^{-1}$ for
   $C = \begin{pmatrix}1&2&3\\0&1&4\\5&6&0\end{pmatrix}$ via Gauss-Jordan
   elimination, showing every step.
4. Compute $D^{-1}$ for
   $D = \begin{pmatrix}1&2&2\\1&3&3\\2&4&5\end{pmatrix}$ via Gauss-Jordan
   elimination, showing every step.
5. Find the $LU$ decomposition (no row swaps needed) of
   $A_3 = \begin{pmatrix}2&1&1\\4&3&3\\8&7&9\end{pmatrix}$ by hand. Show the
   elimination steps and identify the multipliers that populate $L$. Verify
   $LU = A_3$ by direct multiplication.
6. **Trap.** Find two invertible $n \times n$ matrices $A, B$ such that
   $A + B$ is *not* invertible. (This shows invertibility is not preserved
   by addition, unlike by multiplication in Theorem 9.1.)
7. Prove: if $A$ is invertible, then $A^T$ is invertible and
   $(A^T)^{-1} = (A^{-1})^T$.
8. Prove: if $A$ is invertible and $k$ is a positive integer, then $A^k$ is
   invertible and $(A^k)^{-1} = (A^{-1})^k$.
9. Attempt to compute $M^{-1}$ for $M = \begin{pmatrix}1&2\\2&4\end{pmatrix}$
   via Gauss-Jordan elimination. Show exactly where the process breaks
   down, and use that to conclude $M$ is singular.

## Solutions

**1.** $\left[\begin{array}{cc|cc}2&1&1&0\\7&4&0&1\end{array}\right]$.
$R_1 \to \tfrac12 R_1$: $[1,\tfrac12\mid\tfrac12,0]$.
$R_2 \to R_2-7R_1$: $[7-7,\ 4-\tfrac72\mid 0-\tfrac72,\ 1-0] =
[0,\tfrac12\mid-\tfrac72,1]$.
$$\left[\begin{array}{cc|cc}1&\tfrac12&\tfrac12&0\\0&\tfrac12&-\tfrac72&1\end{array}\right]$$
$R_2 \to 2R_2$: $[0,1\mid-7,2]$.
$R_1 \to R_1-\tfrac12R_2$: $[1,0\mid\tfrac12+\tfrac72,\ 0-1] = [1,0\mid4,-1]$.
$$A^{-1} = \begin{pmatrix}4&-1\\-7&2\end{pmatrix}.$$
Check: $AA^{-1} = \begin{pmatrix}2&1\\7&4\end{pmatrix}\begin{pmatrix}4&-1\\-7&2\end{pmatrix}
= \begin{pmatrix}8-7&-2+2\\28-28&-7+8\end{pmatrix} = \begin{pmatrix}1&0\\0&1\end{pmatrix}$ ✓.

**2.** $\left[\begin{array}{cc|cc}1&2&1&0\\3&4&0&1\end{array}\right]$.
$R_2 \to R_2-3R_1$: $[0,4-6\mid0-3,1] = [0,-2\mid-3,1]$.
$$\left[\begin{array}{cc|cc}1&2&1&0\\0&-2&-3&1\end{array}\right]$$
$R_2 \to -\tfrac12R_2$: $[0,1\mid\tfrac32,-\tfrac12]$.
$R_1 \to R_1-2R_2$: $[1,0\mid1-3,0+1] = [1,0\mid-2,1]$.
$$B^{-1} = \begin{pmatrix}-2&1\\\tfrac32&-\tfrac12\end{pmatrix}.$$
Check: $BB^{-1} = \begin{pmatrix}1&2\\3&4\end{pmatrix}\begin{pmatrix}-2&1\\\tfrac32&-\tfrac12\end{pmatrix}
= \begin{pmatrix}-2+3&1-1\\-6+6&3-2\end{pmatrix} = \begin{pmatrix}1&0\\0&1\end{pmatrix}$ ✓.

**3.**
$\left[\begin{array}{ccc|ccc}1&2&3&1&0&0\\0&1&4&0&1&0\\5&6&0&0&0&1\end{array}\right]$.
$R_3 \to R_3-5R_1$: $[0,6-10,0-15\mid0-5,0,1] = [0,-4,-15\mid-5,0,1]$.
$$\left[\begin{array}{ccc|ccc}1&2&3&1&0&0\\0&1&4&0&1&0\\0&-4&-15&-5&0&1\end{array}\right]$$
$R_3 \to R_3+4R_2$: $[0,0,-15+16\mid-5,4,1] = [0,0,1\mid-5,4,1]$.
$$\left[\begin{array}{ccc|ccc}1&2&3&1&0&0\\0&1&4&0&1&0\\0&0&1&-5&4&1\end{array}\right]$$
$R_2 \to R_2-4R_3$: $[0,1,0\mid0+20,1-16,0-4] = [0,1,0\mid20,-15,-4]$.
$R_1 \to R_1-3R_3$: $[1,2,0\mid1+15,0-12,0-3] = [1,2,0\mid16,-12,-3]$.
$$\left[\begin{array}{ccc|ccc}1&2&0&16&-12&-3\\0&1&0&20&-15&-4\\0&0&1&-5&4&1\end{array}\right]$$
$R_1 \to R_1-2R_2$: $[1,0,0\mid16-40,-12+30,-3+8] = [1,0,0\mid-24,18,5]$.
$$C^{-1} = \begin{pmatrix}-24&18&5\\20&-15&-4\\-5&4&1\end{pmatrix}.$$
Spot-check row 1 of $C$ against $C^{-1}$: $[1,2,3]\cdot[-24,20,-5]^T =
-24+40-15=1$; $[1,2,3]\cdot[18,-15,4]^T=18-30+12=0$;
$[1,2,3]\cdot[5,-4,1]^T=5-8+3=0$ — first row of $CC^{-1}$ is $(1,0,0)$ ✓
(the remaining rows check out the same way).

**4.**
$\left[\begin{array}{ccc|ccc}1&2&2&1&0&0\\1&3&3&0&1&0\\2&4&5&0&0&1\end{array}\right]$.
$R_2 \to R_2-R_1$: $[0,1,1\mid-1,1,0]$. $R_3 \to R_3-2R_1$:
$[0,0,1\mid-2,0,1]$.
$$\left[\begin{array}{ccc|ccc}1&2&2&1&0&0\\0&1&1&-1&1&0\\0&0&1&-2&0&1\end{array}\right]$$
$R_2 \to R_2-R_3$: $[0,1,0\mid-1+2,1,-1] = [0,1,0\mid1,1,-1]$.
$R_1 \to R_1-2R_3$: $[1,2,0\mid1+4,0,-2] = [1,2,0\mid5,0,-2]$.
$$\left[\begin{array}{ccc|ccc}1&2&0&5&0&-2\\0&1&0&1&1&-1\\0&0&1&-2&0&1\end{array}\right]$$
$R_1 \to R_1-2R_2$: $[1,0,0\mid5-2,0-2,-2+2] = [1,0,0\mid3,-2,0]$.
$$D^{-1} = \begin{pmatrix}3&-2&0\\1&1&-1\\-2&0&1\end{pmatrix}.$$
Check row 1 of $D$, $[1,2,2]$, against columns of $D^{-1}$: with column 1
$=(3,1,-2)$: $3+2-4=1$; column 2 $=(-2,1,0)$: $-2+2+0=0$; column 3
$=(0,-1,1)$: $0-2+2=0$ — first row of $DD^{-1}$ is $(1,0,0)$ ✓.

**5.** Eliminate column 1: $R_2 \to R_2 - 2R_1$ gives $(0,1,1)$ (multiplier
$2$); $R_3 \to R_3-4R_1$ gives $(0,3,5)$ (multiplier $4$).
$$\begin{pmatrix}2&1&1\\0&1&1\\0&3&5\end{pmatrix}$$
Eliminate column 2: $R_3 \to R_3-3R_2$ gives $(0,0,2)$ (multiplier $3$).
$$U = \begin{pmatrix}2&1&1\\0&1&1\\0&0&2\end{pmatrix}$$
The multipliers used were $2$ (row 2 from row 1), $4$ (row 3 from row 1),
and $3$ (row 3 from row 2); placing them at their $(i,j)$ positions:
$$L = \begin{pmatrix}1&0&0\\2&1&0\\4&3&1\end{pmatrix}.$$
Verify $LU = A_3$: row 1 of $L$ times $U$ gives $(2,1,1)$ ✓ (row 1 of
$A_3$). Row 2: $2(2,1,1)+1(0,1,1) = (4,2,2)+(0,1,1)=(4,3,3)$ ✓ (row 2 of
$A_3$). Row 3: $4(2,1,1)+3(0,1,1)+1(0,0,2) = (8,4,4)+(0,3,3)+(0,0,2) =
(8,7,9)$ ✓ (row 3 of $A_3$). So $A_3 = LU$.

**6.** $A = I$, $B = -I$ (both invertible: $I \cdot I = I$ and
$(-I)(-I) = I$). $A + B = I + (-I) = 0$, the zero matrix, which is not
invertible (for any $C$, $0 \cdot C = 0 \neq I$). So invertibility of $A$
and $B$ individually says nothing about invertibility of $A+B$ — unlike
products of invertibles (always invertible, Theorem 9.1b), sums of
invertibles can be singular.

**7.** Since $A$ is invertible, $A^{-1}$ exists with $AA^{-1} = A^{-1}A =
I$. Transpose both equations, using $(XY)^T = Y^TX^T$ and $I^T = I$:
$$(AA^{-1})^T = (A^{-1})^TA^T = I, \qquad (A^{-1}A)^T = A^T(A^{-1})^T = I.$$
So $(A^{-1})^TA^T = A^T(A^{-1})^T = I$, which is exactly the defining
condition (Definition 9.1) for $A^T$ to be invertible with inverse
$(A^{-1})^T$. By uniqueness of the inverse (Theorem 9.1a),
$(A^T)^{-1} = (A^{-1})^T$. $\blacksquare$

**8.** Induction on $k$. *Base case* $k=1$: $A^1 = A$ is invertible with
$(A^1)^{-1} = A^{-1} = (A^{-1})^1$, given. *Inductive step:* suppose $A^{k}$
is invertible with $(A^k)^{-1} = (A^{-1})^k$. Then $A^{k+1} = A^k \cdot A$
is a product of two invertible matrices ($A^k$ by the inductive hypothesis,
$A$ by assumption), so by Theorem 9.1(b), $A^{k+1}$ is invertible with
$$(A^{k+1})^{-1} = (A^k A)^{-1} = A^{-1}(A^k)^{-1} = A^{-1}(A^{-1})^k =
(A^{-1})^{k+1}.$$
By induction, the claim holds for every positive integer $k$. $\blacksquare$

**9.** $\left[\begin{array}{cc|cc}1&2&1&0\\2&4&0&1\end{array}\right]$.
$R_2 \to R_2-2R_1$: $[2-2,4-4\mid0-2,1-0] = [0,0\mid-2,1]$.
$$\left[\begin{array}{cc|cc}1&2&1&0\\0&0&-2&1\end{array}\right]$$
Row 2 is now entirely zero in the left ($A$-side) block — there is no
possible pivot in column 2 (every entry at or below row 2, column 2, is
$0$), and no row swap can fix this since row 1 is already used as the
pivot row for column 1. The elimination cannot produce two pivots, so it
cannot reach $I$ on the left block: the Gauss-Jordan algorithm fails to
invert $M$. This matches $\operatorname{rank}(M) = 1 < 2 = n$ (row 2 is a
multiple of row 1, $(2,4) = 2\cdot(1,2)$), so by Theorem 9.2's Step 1
(applied in reverse — an invertible matrix must have $n$ pivots), $M$ is
**singular**.

## Code lab

**Rule:** don't open this section until you've finished the exercises
above on paper.

Today's lab implements the Gauss-Jordan inversion algorithm you just did by
hand five times, plus a sanity check of $LU$ decomposition using SciPy.
Open `starter_code/day09_inverse_lu.py` — it has one function to complete,
`gauss_jordan_inverse`. Fill in the `TODO`, then run the file directly
(`python starter_code/day09_inverse_lu.py`); all assertions should pass
silently and it should print the computed inverse plus a confirmation that
$A = PLU$ (SciPy's convention: $P$ permutes the rows of $LU$ back into
$A$'s original order, equivalently $P^TA = LU$ since $P$ is orthogonal).

**Hint:** build the augmented $n \times 2n$ matrix $[A \mid I]$, then for
each column: find a pivot (partial pivoting via `np.argmax` of absolute
value is fine, and is what real numerical code does — it avoids dividing
by a small number), swap it into position, scale that row so the pivot is
exactly $1$, then eliminate that column in **every other row** (not just
the rows below — that's what makes this Gauss-*Jordan* rather than plain
Gaussian elimination, and it's what leaves $I$ on the left when you finish,
handing you $A^{-1}$ on the right). Do not call `np.linalg.inv` inside the
function itself — only afterward, to check your answer.

If you get stuck for more than ~10 minutes, check
`solutions/day09_inverse_lu.py` — but only after a real attempt.

Once your implementation passes, extend it: run `gauss_jordan_inverse` on
the $3\times3$ matrices $C$ and $D$ from Exercises 3 and 4, and confirm the
results match what you computed by hand. Then pass a singular matrix (e.g.
Exercise 9's $M$) to your function and observe what happens — a division
by (near-)zero pivot — and add a check that raises a clear error if the
chosen pivot's absolute value is below some small tolerance (e.g. `1e-10`)
instead of silently producing garbage or `inf`/`nan`.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $A^{-1}$ | "$A$ inverse" | the unique matrix that undoes $A$: $AA^{-1}=A^{-1}A=I$ |
| $E_{\mathrm{swap}},\ E_{\mathrm{scale}},\ E_{\mathrm{add}}$ | "the elementary matrices" | $I$ with one row operation applied |
| $[A \mid I]$ | "$A$ augmented with the identity" | the block Gauss-Jordan turns into $[I \mid A^{-1}]$ |
| $A = LU$ | "$A$ factors as lower times upper" | elimination-without-swaps splits $A$ this way |
| $L$ | "unit lower triangular factor" | records the elimination multipliers, $1$'s on the diagonal |
| $U$ | "upper triangular factor" | the echelon form elimination leaves behind |
| $\operatorname{rank}(A) = n$ | "full rank — $n$ pivots" | the invertibility test used here |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- Multiplying by an elementary matrix on the left performs one row operation,
  so row reduction is the same thing as multiplying by a chain of these
  matrices.
- The inverse of a matrix is unique, and a product inverts in reverse order:
  $(AB)^{-1} = B^{-1}A^{-1}$.
- Every invertible matrix is a product of elementary matrices — which is
  exactly why running Gauss-Jordan on $[A \mid I]$ hands you $A^{-1}$.
- Elimination with no row swaps and no scaling factors $A$ into $LU$: a unit
  lower-triangular $L$ times an upper-triangular $U$.
- The entries of $L$ are just the elimination multipliers (negated), so you
  read $L$ straight off the elimination rather than inverting anything.

### Proof sketches

**Lemma 9.1 — key trick: each row of $EM$ is a recipe read off a row of
$E$.**
Row $i$ of the product $EM$ is the combination of $M$'s rows weighted by row
$i$ of $E$. Since $E$ is the identity with one row operation applied, its
rows are exactly the basis rows that reproduce that operation — pulling out
row $j$ for a swap, scaling a row, or adding one row to another. Checking the
three types confirms $EM$ is $M$ with the operation applied. Full version:
Lemma 9.1 above.

**Theorem 9.1 — key trick: sandwich one inverse between the other two
factors, and cancel a product from the inside out.**
If $B$ and $C$ are both inverses of $A$, then $B = B(AC) = (BA)C = C$ by
associativity, so the inverse is unique. For a product, test $B^{-1}A^{-1}$:
multiplying it against $AB$ on either side lets the inner pair cancel to $I$,
then the outer pair cancels too. So $B^{-1}A^{-1}$ satisfies the definition,
and uniqueness makes it *the* inverse $(AB)^{-1}$. Full version: Theorem 9.1
above.

**Lemma 9.2 — key trick: every row operation is undone by an operation of the
same kind.**
A swap undoes itself when repeated; scaling by $c$ is undone by scaling by
$1/c$; adding $c$ times a row is undone by adding $-c$ times it. Each of
these undo-operations is itself an elementary matrix, and Lemma 9.1 shows
their product with the original gives $I$ both ways. So every elementary
matrix is invertible with an elementary inverse of the same type. Full
version: Lemma 9.2 above.

**Theorem 9.2 — key trick: row-reduce all the way to $I$, then read the
recipe backward.**
An invertible matrix has trivial null space, so by Day 6's dimension formula
it has $n$ pivots, and its reduced echelon form can only be $I$. So some
chain of elementary matrices $E_k \cdots E_1$ times $A$ equals $I$. Inverting
that chain — each factor's inverse is again elementary (Lemma 9.2) — expresses
$A$ itself as a product of elementary matrices. This is the exact mechanism
that makes Gauss-Jordan on $[A \mid I]$ compute $A^{-1}$. Full version:
Theorem 9.2 above.

**Lemma 9.3 — key trick: an index chase shows the triangular, unit-diagonal
shape survives both multiplication and inversion.**
For a product $PQ$ with $i < j$, a nonzero term would need an index $k$ with
both $k \le i$ and $k \ge j$, which is impossible, so $PQ$ stays lower
triangular; the diagonal terms collapse to $1 \cdot 1 = 1$. For the inverse,
a unit lower-triangular matrix already has $1$'s on its diagonal, so you can
clear everything below the diagonal using only add-a-lower-row steps — each
itself unit lower triangular — reaching $I$. Their product is that shape and
equals the inverse. Full version: Lemma 9.3 above.

**Theorem 9.3 — key trick: no-swap elimination is multiplication by unit
lower-triangular matrices, and that shape is closed under inverting.**
Each "add a multiple of an upper row to a lower row" step is an elementary
matrix that is unit lower triangular. Their product $M$ satisfies $MA = U$
and, by Lemma 9.3(a), is itself unit lower triangular and invertible. So
$A = M^{-1}U$, and by Lemma 9.3(b) the factor $L = M^{-1}$ is again unit
lower triangular — giving $A = LU$. Full version: Theorem 9.3 above.

### If you remember only 3 things

1. Left-multiplying by an elementary matrix does one row operation, so every
   invertible matrix is a product of them — that's why Gauss-Jordan on
   $[A \mid I]$ produces $A^{-1}$.
2. Inverses are unique and reverse under products: $(AB)^{-1} =
   B^{-1}A^{-1}$.
3. Swap-free elimination factors $A = LU$, and $L$'s entries are just the
   negated multipliers you already used — no extra computation.

## Journal template

```
## Day 9 — Invertibility, inverse, LU
Key theorem in my own words: ...
What confused me: ...
```
