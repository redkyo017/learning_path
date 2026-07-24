# Day 8 — Determinants

## Learning objectives

By the end of today you should be able to:
- State the three properties that uniquely characterize the determinant and
  the cofactor expansion formula, and compute determinants by hand via
  cofactor expansion for $2\times2$, $3\times3$, and $4\times4$ matrices.
- Prove $\det(AB) = \det(A)\det(B)$ for all $n\times n$ matrices $A, B$.
- Prove that $A$ is invertible if and only if $\det(A) \neq 0$, connecting
  the determinant to Day 5's row-reduction/rank framework.
- Compute a determinant more efficiently via row reduction than via raw
  cofactor expansion, correctly tracking how each elementary row operation
  scales the determinant.
- Recognize the determinant as a signed volume-scaling factor rather than
  merely a computational recipe.

## Reference material

- Primer (15 min, geometric intuition): 3Blue1Brown, *Essence of Linear
  Algebra*, Chapter 6 (the determinant) —
  [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab).
  Watch this before the proofs below — the whole point of today's theory is
  that the formulas are a computation *of* something (signed area/volume
  scaling), not an end in themselves.
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, Chapter 3
  — [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  chapter on Determinants — if you don't have a copy, the exercises below
  are self-contained and sufficient for today.

The theory below is self-contained — you do not strictly need the Treil PDF
to do today's work, but reading his Chapter 3 alongside this is the "theory"
layer of today's three-layer structure.

## Theory

### Definition 8.1 (The determinant, axiomatically)

The **determinant** is the function $\det: M_n(\mathbb{R}) \to \mathbb{R}$,
uniquely determined by the following three properties of the $n$ columns
$a_1, \dots, a_n$ of a matrix $A$:

(a) **Multilinearity in the columns.** For each fixed column index $j$,
    holding every other column fixed, the map
    $v \mapsto \det(a_1, \dots, a_{j-1}, v, a_{j+1}, \dots, a_n)$ is linear:
    $$\det(\dots, u+w, \dots) = \det(\dots, u, \dots) + \det(\dots, w, \dots),
    \qquad \det(\dots, cu, \dots) = c\det(\dots, u, \dots).$$
(b) **Alternating.** If two columns of $A$ are equal, $\det(A) = 0$.
(c) **Normalization.** $\det(I_n) = 1$.

*On existence and uniqueness.* That some function satisfies (a)–(c) is
exhibited constructively by the cofactor expansion formula below (Definition
8.2). That it is the *only* such function is a genuine theorem, proved in
Treil §3.1 via the explicit Leibniz permutation formula
$\det(A) = \sum_{\sigma \in S_n} \operatorname{sgn}(\sigma)
\prod_{i=1}^n a_{i,\sigma(i)}$ — we take this uniqueness as given rather than
reproduce it, and simply identify $\det$ with cofactor expansion from here
on.

*Rows vs. columns.* It is also a standard fact — a consequence of
$\det(A^T) = \det(A)$, which you will prove by induction in Exercise 7 below
— that properties (a)–(c) hold identically with "row" substituted for
"column" throughout. We use this row version freely starting in Lemma 8.2,
since elementary *row* operations are what Gaussian elimination (Day 5) and
today's proofs are built on.

### Definition 8.2 (Minor, cofactor, cofactor expansion)

For an $n\times n$ matrix $A$ and indices $i, j \in \{1, \dots, n\}$, let
$A_{(i,j)}$ denote the $(n-1)\times(n-1)$ **minor matrix** obtained by
deleting row $i$ and column $j$ from $A$. The $(i,j)$ **cofactor** of $A$ is
$$C_{ij} = (-1)^{i+j}\det(A_{(i,j)}).$$
For any fixed row $i$, the **cofactor expansion along row $i$** is
$$\det(A) = \sum_{j=1}^n a_{ij}C_{ij} = \sum_{j=1}^n (-1)^{i+j}a_{ij}
\det(A_{(i,j)}),$$
and for any fixed column $j$, the **cofactor expansion down column $j$** is
$\det(A) = \sum_{i=1}^n a_{ij}C_{ij}$. The base case is $1\times1$:
$\det([a]) = a$.

It is a standard fact (proved in Treil §3.1 and in Schaum's, via the Leibniz
formula cited above) that all $2n$ of these expansions — one per row, one
per column — always agree with each other and with $\det(A)$; we use this
freely below without reproducing that argument, and use the row-1 expansion
as the default recipe for hand computation.

### Lemma 8.1 (A zero row forces determinant zero)

If $A$ is $n \times n$ and some row $p$ of $A$ is entirely zero, then
$\det(A) = 0$.

**Proof.** Expand along row $p$ (Definition 8.2):
$\det(A) = \sum_{j=1}^n (-1)^{p+j} \cdot 0 \cdot \det(A_{(p,j)}) = 0$.
$\blacksquare$

### Definition 8.3 (Elementary matrices)

Let $I = I_n$. For row indices $i \neq k$ and scalar $c \neq 0$, define:
- $P_{ik}$: $I$ with rows $i$ and $k$ swapped.
- $S_i(c)$: $I$ with row $i$ replaced by $c$ times row $i$.
- $T_{ik}(c)$: $I$ with row $i$ replaced by (row $i$) $+ c\cdot$(row $k$),
  for any scalar $c$ (including $0$, trivially).

These are the **elementary matrices**; each is $I$ with exactly one of the
three elementary row operations from Day 5 (Definition 5.1) applied to it.

### Lemma 8.2 (Effect of elementary row operations on the determinant)

Let $A$ be $n \times n$ with rows $r_1, \dots, r_n$.

(i) If $A'$ is $A$ with rows $i, k$ swapped ($i \neq k$), then
$\det(A') = -\det(A)$.

(ii) If $A'$ is $A$ with row $i$ replaced by $cr_i$ ($c \neq 0$, other rows
unchanged), then $\det(A') = c\det(A)$.

(iii) If $A'$ is $A$ with row $i$ replaced by $r_i + cr_k$ ($k \neq i$,
other rows unchanged), then $\det(A') = \det(A)$.

**Proof.**

*(ii)* This is exactly the row version of multilinearity, property (a): the
map $v \mapsto \det(r_1,\dots,v,\dots,r_n)$ (row $i$ varying, rest fixed) is
linear, so replacing row $i$ by $c \cdot r_i$ scales the output by $c$:
$\det(A') = c\det(A)$.

*(i)* Let $u = r_i$, $v = r_k$. Consider the matrix $B$ equal to $A$ except
that *both* row $i$ and row $k$ are replaced by $u + v$. Since two of $B$'s
rows are equal, property (b) (row version) gives $\det(B) = 0$. Expand
$\det(B)$ using multilinearity in row $i$ first (row $k$ held fixed at
$u+v$):
$$0 = \det(B) = \det(\dots, u, \dots, u+v, \dots) +
\det(\dots, v, \dots, u+v, \dots),$$
(all other rows of $A$, unchanged, are suppressed from the notation). Now
expand each term using multilinearity in row $k$:
$$\det(\dots, u, \dots, u+v, \dots) = \det(\dots,u,\dots,u,\dots) +
\det(\dots,u,\dots,v,\dots) = 0 + \det(\dots,u,\dots,v,\dots),$$
$$\det(\dots, v, \dots, u+v, \dots) = \det(\dots,v,\dots,u,\dots) +
\det(\dots,v,\dots,v,\dots) = \det(\dots,v,\dots,u,\dots) + 0,$$
where the two zero terms vanish by property (b) (rows $i,k$ both equal $u$,
respectively both equal $v$). Note $\det(\dots,u,\dots,v,\dots)$ (row $i=u$,
row $k=v$) is exactly $\det(A)$, and $\det(\dots,v,\dots,u,\dots)$ (row
$i=v$, row $k=u$) is exactly $\det(A')$. Substituting back:
$$0 = \det(A) + \det(A'),$$
so $\det(A') = -\det(A)$.

*(iii)* Let $A'$ be $A$ with row $i$ replaced by $r_i + cr_k$. By
multilinearity in row $i$:
$$\det(A') = \det(\dots, r_i + cr_k, \dots, r_k, \dots) =
\det(\dots, r_i, \dots, r_k, \dots) + c\det(\dots, r_k, \dots, r_k, \dots).$$
The first term is $\det(A)$. The second matrix has row $i$ *and* row $k$
both equal to $r_k$ (row $i$ was replaced by $r_k$, row $k$ was left as
$r_k$), so by property (b) its determinant is $0$. Hence
$\det(A') = \det(A) + c\cdot 0 = \det(A)$. $\blacksquare$

### Lemma 8.3 (Left-multiplying by an elementary matrix performs the row operation)

Let $E$ be one of $P_{ik}$, $S_i(c)$, $T_{ik}(c)$, and let $B$ be any
$n \times n$ matrix. Then $EB$ equals $B$ with the corresponding elementary
row operation applied.

**Proof.** For any matrices $E, B$, row $m$ of the product $EB$ is
$\sum_{l=1}^n E_{ml}\cdot(\text{row } l \text{ of } B)$ — a linear
combination of the rows of $B$ with coefficients read off row $m$ of $E$.

- $E = P_{ik}$: row $i$ of $E$ is the standard basis row $e_k$ and row $k$
  of $E$ is $e_i$; every other row $m$ of $E$ is $e_m$. So row $i$ of $EB$
  is row $k$ of $B$, row $k$ of $EB$ is row $i$ of $B$, and every other row
  of $EB$ equals the corresponding row of $B$ — exactly rows $i,k$ of $B$
  swapped.
- $E = S_i(c)$: row $i$ of $E$ is $ce_i$, every other row $m$ is $e_m$. So
  row $i$ of $EB$ is $c\cdot(\text{row } i \text{ of } B)$, and every other
  row of $EB$ equals the corresponding row of $B$ — exactly row $i$ of $B$
  scaled by $c$.
- $E = T_{ik}(c)$: row $i$ of $E$ is $e_i + ce_k$, every other row $m$ is
  $e_m$. So row $i$ of $EB$ is (row $i$ of $B$) $+ c\cdot$(row $k$ of $B$),
  and every other row of $EB$ equals the corresponding row of $B$ — exactly
  row $i$ of $B$ plus $c$ times row $k$ of $B$, added to $B$.

In all three cases $EB$ is $B$ with the stated row operation applied.
$\blacksquare$

### Corollary 8.1 ($\det(EB) = \det(E)\det(B)$ for elementary $E$)

For $E$ one of $P_{ik}, S_i(c), T_{ik}(c)$ and any $n\times n$ matrix $B$,
$\det(EB) = \det(E)\det(B)$.

**Proof.** Taking $B = I$ in Lemma 8.3, $E = E \cdot I$ is $I$ with the row
operation applied; combined with Lemma 8.2 applied to $A = I$
($\det(I) = 1$), we get $\det(P_{ik}) = -1$, $\det(S_i(c)) = c$,
$\det(T_{ik}(c)) = 1$. By Lemma 8.3, $EB$ is $B$ with the same row operation
applied, so by Lemma 8.2 applied to $A = B$:
$$\det(EB) = \begin{cases} -\det(B) = \det(P_{ik})\det(B) & E = P_{ik} \\
c\det(B) = \det(S_i(c))\det(B) & E = S_i(c) \\
\det(B) = \det(T_{ik}(c))\det(B) & E = T_{ik}(c). \end{cases}$$
In every case $\det(EB) = \det(E)\det(B)$. $\blacksquare$

By induction, applying this repeatedly, if $R = E_m E_{m-1}\cdots E_1 A$ for
elementary matrices $E_1, \dots, E_m$, then
$\det(R) = \det(E_m)\det(E_{m-1})\cdots\det(E_1)\det(A)$, and every
$\det(E_i)$ above is nonzero ($-1$, or $c \neq 0$, or $1$). This one fact —
row-reducing changes $\det$ only by a running nonzero factor — powers both
theorems below.

### Lemma 8.4 (A singular matrix has determinant zero)

If $A$ is $n \times n$ and singular (not invertible, equivalently
$\operatorname{rank}(A) < n$ — established via the four fundamental
subspaces, Day 6), then $\det(A) = 0$.

**Proof.** Row-reduce $A$ to echelon form $R$ via elementary row operations
$E_1, \dots, E_m$, so $R = E_m \cdots E_1 A$. By the remark after Corollary
8.1, $\det(R) = \det(E_m)\cdots\det(E_1)\det(A)$ where every $\det(E_i)$ is
nonzero; dividing both sides by this nonzero product shows
$\det(A) = 0 \iff \det(R) = 0$. By Theorem 5.2 (Day 5), row operations
preserve rank, so $\operatorname{rank}(R) = \operatorname{rank}(A) < n$.
Since $R$ is $n \times n$ echelon form with fewer than $n$ pivots, at least
one of its $n$ rows has no pivot, i.e. is entirely zero. By Lemma 8.1,
$\det(R) = 0$. Hence $\det(A) = 0$. $\blacksquare$

### Theorem 8.1 ($\det(AB) = \det(A)\det(B)$ for all $n\times n$ $A, B$)

**Proof.** We split into cases based on whether $A$ is invertible.

**Case 1: $A$ or $B$ is singular.** Suppose $A$ is singular. The column
space of $AB$ is contained in the column space of $A$: every vector in
$\operatorname{Col}(AB)$ has the form $(AB)x = A(Bx)$ for some $x$, which is
$A$ applied to the vector $Bx$, hence lies in $\operatorname{Col}(A)$.
A subspace contained in another has dimension at most as large, so
$\operatorname{rank}(AB) = \dim\operatorname{Col}(AB) \le
\dim\operatorname{Col}(A) = \operatorname{rank}(A) < n$. So $AB$ is also
singular, and by Lemma 8.4, $\det(A) = 0$ and $\det(AB) = 0$; hence
$\det(AB) = 0 = 0 \cdot \det(B) = \det(A)\det(B)$.

Suppose instead $B$ is singular (and $A$ may or may not be). Every row of
$AB$ is a linear combination of the rows of $B$: row $i$ of $AB$ equals
$\sum_k A_{ik}\cdot(\text{row } k \text{ of } B)$, so it lies in
$\operatorname{Row}(B)$. Hence $\operatorname{Row}(AB) \subseteq
\operatorname{Row}(B)$, giving $\operatorname{rank}(AB) =
\dim\operatorname{Row}(AB) \le \dim\operatorname{Row}(B) =
\operatorname{rank}(B) < n$ (using $\operatorname{rank} =
\dim\operatorname{Row}$ from Day 5). So $AB$ is singular, and by Lemma 8.4,
$\det(B) = 0 = \det(AB)$, so again $\det(AB) = 0 = \det(A)\cdot 0 =
\det(A)\det(B)$.

**Case 2: $A$ is invertible.** Row-reduce $A$: since
$\operatorname{rank}(A) = n$ (full rank, as $A$ is invertible), the reduced
row echelon form of the square matrix $A$ has a pivot — necessarily equal to
$1$, and the only nonzero entry in its column — in every one of the $n$
rows and $n$ columns, which forces the RREF to be exactly $I$. So there are
elementary matrices $F_1, \dots, F_m$ with $F_m \cdots F_1 A = I$, i.e.
$A = F_1^{-1} F_2^{-1} \cdots F_m^{-1}$. Each elementary matrix's inverse is
again elementary of the same kind ($P_{ik}^{-1} = P_{ik}$, $S_i(c)^{-1} =
S_i(1/c)$, $T_{ik}(c)^{-1} = T_{ik}(-c)$ — each checked directly by matrix
multiplication), so $A = E_1 E_2 \cdots E_m$ for elementary matrices $E_i$.

Now apply Corollary 8.1 repeatedly (peeling off one elementary factor at a
time from the left):
$$\det(AB) = \det(E_1 E_2 \cdots E_m B) = \det(E_1)\det(E_2\cdots E_m B) =
\det(E_1)\det(E_2)\det(E_3 \cdots E_m B) = \cdots =
\det(E_1)\det(E_2)\cdots\det(E_m)\det(B).$$
The identical telescoping argument, applied to $A = E_1 E_2 \cdots E_m \cdot
I$ (i.e. taking "$B$" to be $I$), gives
$\det(A) = \det(E_1)\det(E_2)\cdots\det(E_m)\det(I) =
\det(E_1)\cdots\det(E_m)$ (using $\det(I)=1$). Substituting into the
displayed equation:
$$\det(AB) = \det(E_1)\cdots\det(E_m)\det(B) = \det(A)\det(B).$$

Cases 1 and 2 are exhaustive ($A$ is either singular or invertible), so
$\det(AB) = \det(A)\det(B)$ holds for all $n\times n$ $A, B$. $\blacksquare$

### Lemma 8.5 (Determinant of a triangular matrix)

If $T$ is $n \times n$ **upper triangular** ($T_{ij} = 0$ whenever $j < i$),
then $\det(T) = T_{11}T_{22}\cdots T_{nn}$ (the product of the diagonal
entries).

**Proof.** Induction on $n$. *Base case* $n=1$: $\det([T_{11}]) = T_{11}$,
the empty product convention needing no work here.

*Inductive step.* Assume the claim for $(n-1)\times(n-1)$ upper triangular
matrices. Let $T$ be $n\times n$ upper triangular, and expand $\det(T)$
down column $1$ (Definition 8.2):
$$\det(T) = \sum_{i=1}^n (-1)^{i+1}T_{i1}\det(T_{(i,1)}).$$
Since $T$ is upper triangular, $T_{i1} = 0$ for every $i > 1$ (column index
$1 < i$), so every term with $i > 1$ vanishes, leaving only the $i=1$ term:
$$\det(T) = (-1)^{1+1}T_{11}\det(T_{(1,1)}) = T_{11}\det(T_{(1,1)}).$$
The minor $T_{(1,1)}$ (delete row $1$, column $1$) is the lower-right
$(n-1)\times(n-1)$ block of $T$; it inherits the zero-below-diagonal
property (its $(i',j')$ entry is $T_{i'+1,j'+1}$, which is $0$ whenever
$j' < i'$ since that means $j'+1 < i'+1$ in $T$), with diagonal entries
$T_{22}, \dots, T_{nn}$. By the inductive hypothesis,
$\det(T_{(1,1)}) = T_{22}T_{33}\cdots T_{nn}$. Hence
$\det(T) = T_{11}\cdot T_{22}\cdots T_{nn}$. $\blacksquare$

### Theorem 8.2 ($A$ is invertible if and only if $\det(A) \neq 0$)

**Proof.** Row-reduce $A$ (any $n\times n$ matrix) to row echelon form $R$
via elementary row operations $E_1, \dots, E_m$, so $R = E_m\cdots E_1 A$.
As in Lemma 8.4, $\det(R) = \det(E_m)\cdots\det(E_1)\det(A)$ with every
$\det(E_i)$ nonzero, so
$$\det(A) \neq 0 \iff \det(R) \neq 0. \tag{$\ast$}$$

$R$, being in echelon form, is upper triangular: the pivot of row $i$ (if it
exists) lies in a column $\geq i$, because the pivot columns of rows
$1, \dots, i$ are $i$ distinct, strictly increasing indices starting at
$1$ or later, so the $i$-th one is at least $i$; hence every entry of row
$i$ in a column $j < i$ lies strictly left of row $i$'s own pivot (or the
row is entirely zero), and is therefore $0$ either way. So Lemma 8.5
applies:
$$\det(R) = R_{11}R_{22}\cdots R_{nn}.$$
This product is nonzero if and only if every diagonal entry $R_{ii}$ is
nonzero. If $\operatorname{rank}(R) = n$, all $n$ rows have a pivot, and $n$
strictly increasing pivot columns chosen from $\{1,\dots,n\}$ across $n$
rows forces pivot column $i$ to equal $i$ exactly for every $i$ — so
$R_{ii}$ *is* the pivot of row $i$, nonzero, for every $i$, making the
product nonzero. Conversely if $\operatorname{rank}(R) = r < n$, rows
$r+1, \dots, n$ of $R$ are entirely zero (echelon form places all zero rows
at the bottom), so in particular $R_{nn} = 0$, making the product zero. So:
$$\det(R) \neq 0 \iff \operatorname{rank}(R) = n. \tag{$\ast\ast$}$$

Finally, row operations preserve rank (Theorem 5.2, Day 5), so
$\operatorname{rank}(R) = \operatorname{rank}(A)$, and a square matrix has
full rank $n$ if and only if it is invertible (established via the four
fundamental subspaces, Day 6). Chaining this with $(\ast)$ and
$(\ast\ast)$:
$$\det(A) \neq 0 \iff \det(R) \neq 0 \iff \operatorname{rank}(R) = n \iff
\operatorname{rank}(A) = n \iff A \text{ is invertible.}$$
$\blacksquare$

## Worked example

Compute $\det(M)$ for $M = \begin{pmatrix}2&0&1\\1&3&-1\\0&4&2\end{pmatrix}$,
two ways.

**Method 1: cofactor expansion along row 1.**
$$\det(M) = 2\cdot C_{11} + 0\cdot C_{12} + 1\cdot C_{13}.$$
- $C_{11} = (-1)^{1+1}\det\begin{pmatrix}3&-1\\4&2\end{pmatrix} =
  (3\cdot2 - (-1)\cdot4) = 6+4 = 10.$
- The $C_{12}$ term is multiplied by $a_{12}=0$, so it contributes $0$
  regardless of its value — no need to compute it.
- $C_{13} = (-1)^{1+3}\det\begin{pmatrix}1&3\\0&4\end{pmatrix} =
  (1\cdot4 - 3\cdot0) = 4.$

$$\det(M) = 2(10) + 0 + 1(4) = 20 + 4 = 24.$$

**Method 2: row reduction, tracking the scalar factor.**
$$\begin{pmatrix}2&0&1\\1&3&-1\\0&4&2\end{pmatrix}
\xrightarrow{R_2 \to R_2 - \frac12 R_1}
\begin{pmatrix}2&0&1\\0&3&-1.5\\0&4&2\end{pmatrix}
\xrightarrow{R_3 \to R_3 - \frac43 R_2}
\begin{pmatrix}2&0&1\\0&3&-1.5\\0&0&4\end{pmatrix}.$$
Both operations are of type (iii) in Lemma 8.2 ("add a multiple of one row
to another"), and Lemma 8.2(iii) says this type leaves $\det$ *unchanged*
(scalar factor $1$ each time). So $\det(M)$ equals the determinant of the
final upper triangular matrix, which by Lemma 8.5 is the product of its
diagonal entries: $2 \cdot 3 \cdot 4 = 24$.

Both methods agree: $\det(M) = 24$.

## Unconventional edge

The most seductive trap with determinants is treating them as "just a
number you crank out via a formula" — memorize the $2\times2$ shortcut, or
the cofactor cross-multiply pattern for $3\times3$, get the right number,
move on. That framing makes the sign of the answer feel arbitrary, which is
exactly backwards: the determinant is a **signed volume-scaling factor** —
$|\det(A)|$ is the factor by which $A$ scales area (in $\mathbb{R}^2$) or
volume (in $\mathbb{R}^n$), and the *sign* records whether $A$ preserves or
flips orientation. That is precisely why Lemma 8.2(i) says a row (or column)
swap flips the sign of $\det$: swapping two vectors in a parallelepiped's
spanning set is a mirror-flip of orientation, and the algebra is just
tracking that geometric fact. If you only ever compute determinants as
arithmetic and never watch 3Blue1Brown's determinant chapter (today's
primer) with the geometric picture switched on, "why does a row swap flip
the sign" and "why is $\det(A) = 0$ exactly when $A$ squashes space into a
lower dimension" stay memorized facts instead of things you can *see* —
and that gap resurfaces painfully at eigenvalues (Days 10–11), where the
determinant's role as "is this transformation invertible" is used
constantly and needs to be intuitive, not looked up.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–6, 8, 9 are computational; 7 and 10 are proof-based.

1. Compute $\det\begin{pmatrix}7&2\\3&5\end{pmatrix}$.
2. Compute $\det\begin{pmatrix}3&0&2\\1&4&-1\\2&5&1\end{pmatrix}$ via
   cofactor expansion along row 1 (it has a zero entry — use it).
3. Compute $\det\begin{pmatrix}2&0&1\\3&4&-2\\1&0&5\end{pmatrix}$ via
   cofactor expansion down column 2 (it has two zero entries — use them).
4. Compute $\det\begin{pmatrix}2&1&0&3\\0&4&0&1\\1&2&5&0\\3&0&0&2\end{pmatrix}$
   via cofactor expansion (find the row or column with the most zeros
   first).
5. Compute $\det\begin{pmatrix}1&1&1&1\\2&3&1&4\\1&2&2&3\\3&1&2&1\end{pmatrix}$
   using row reduction to upper triangular form (tracking any scalar
   factors) rather than raw cofactor expansion.
6. Find all real values of $k$ for which
   $\begin{pmatrix}k&1&0\\1&k&1\\0&1&k\end{pmatrix}$ is singular.
7. Prove $\det(A^T) = \det(A)$ for every $n\times n$ matrix $A$, using the
   cofactor expansion formula and induction on $n$. (Hint: expansion of $A$
   along row $1$ should match expansion of $A^T$ down column $1$.)
8. Let $A$ be $n\times n$ and $c \in \mathbb{R}$ a scalar. What is
   $\det(cA)$ in terms of $c$, $n$, and $\det(A)$? (Many learners guess
   $c\det(A)$ — check your answer against a $2\times2$ example before
   trusting it.)
9. Let $A, B$ be $3\times 3$ matrices with $\det(A) = 3$ and
   $\det(B) = -2$. Compute (a) $\det(AB)$, (b) $\det(A^3)$, (c)
   $\det(A^{-1})$ (you may assume $A$ is invertible), (d) $\det(B^TA)$.
10. Suppose $A$ is $n\times n$ and $A^2 = 0$ (the zero matrix). Prove
    $\det(A) = 0$.

## Solutions

**1.** $\det\begin{pmatrix}7&2\\3&5\end{pmatrix} = 7\cdot5 - 2\cdot3 = 35-6
= 29$.

**2.** Row 1 is $(3,0,2)$.
$$\det = 3\det\begin{pmatrix}4&-1\\5&1\end{pmatrix} - 0 +
2\det\begin{pmatrix}1&4\\2&5\end{pmatrix}
= 3(4\cdot1-(-1)\cdot5) + 2(1\cdot5-4\cdot2) = 3(9) + 2(-3) = 27-6=21.$$

**3.** Column 2 is $(0,4,0)^T$; only the middle entry is nonzero, so only
one term survives:
$$\det = (-1)^{2+2}\cdot4\cdot\det\begin{pmatrix}2&1\\1&5\end{pmatrix} =
4(2\cdot5-1\cdot1) = 4(9) = 36.$$

**4.** Column 3 is $(0,0,5,0)^T$ — only row 3 is nonzero, the best choice:
$$\det = (-1)^{3+3}\cdot5\cdot
\det\begin{pmatrix}2&1&3\\0&4&1\\3&0&2\end{pmatrix}.$$
Expand the $3\times3$ minor along row 1:
$2(4\cdot2-1\cdot0) - 1(0\cdot2-1\cdot3) + 3(0\cdot0-4\cdot3)
= 2(8) - 1(-3) + 3(-12) = 16+3-36 = -17$. So $\det = 5(-17) = -85$.

**5.**
$$\begin{pmatrix}1&1&1&1\\2&3&1&4\\1&2&2&3\\3&1&2&1\end{pmatrix}
\xrightarrow[R_4\to R_4-3R_1]{R_2\to R_2-2R_1,\ R_3\to R_3-R_1}
\begin{pmatrix}1&1&1&1\\0&1&-1&2\\0&1&1&2\\0&-2&-1&-2\end{pmatrix}
\xrightarrow[R_4\to R_4+2R_2]{R_3\to R_3-R_2}
\begin{pmatrix}1&1&1&1\\0&1&-1&2\\0&0&2&0\\0&0&-3&2\end{pmatrix}
\xrightarrow{R_4\to R_4+\frac32R_3}
\begin{pmatrix}1&1&1&1\\0&1&-1&2\\0&0&2&0\\0&0&0&2\end{pmatrix}.$$
Every operation used is type (iii) (add a multiple of one row to another),
which by Lemma 8.2(iii) leaves $\det$ unchanged. By Lemma 8.5, $\det$ of
the final triangular matrix is $1\cdot1\cdot2\cdot2 = 4$. So the original
determinant is $4$.

**6.** Expand along row 1:
$$\det = k\det\begin{pmatrix}k&1\\1&k\end{pmatrix} -
1\det\begin{pmatrix}1&1\\0&k\end{pmatrix} + 0
= k(k^2-1) - 1(k) = k^3 - 2k = k(k^2-2).$$
By Theorem 8.2 the matrix is singular exactly when this is $0$:
$k(k^2-2)=0 \iff k = 0 \text{ or } k = \pm\sqrt2$.

**7.** By induction on $n$. *Base case* $n=1$: $A^T = A$ trivially for a
$1\times1$ matrix, so $\det(A^T)=\det(A)$.

*Inductive step.* Assume $\det(B^T) = \det(B)$ for all $(n-1)\times(n-1)$
matrices $B$. Let $A$ be $n\times n$. Expand $\det(A)$ along row $1$:
$$\det(A) = \sum_{j=1}^n (-1)^{1+j}a_{1j}\det(A_{(1,j)}).$$
Now consider $A^T$. Column $1$ of $A^T$ equals row $1$ of $A$, i.e. entry
$i$ of column $1$ of $A^T$ is $(A^T)_{i1} = a_{1i}$. Expand $\det(A^T)$
down column $1$:
$$\det(A^T) = \sum_{i=1}^n (-1)^{i+1}(A^T)_{i1}\det\big((A^T)_{(i,1)}\big)
= \sum_{i=1}^n (-1)^{i+1}a_{1i}\det\big((A^T)_{(i,1)}\big).$$
The minor $(A^T)_{(i,1)}$ (delete row $i$, column $1$ from $A^T$) is the
transpose of the minor $A_{(1,i)}$ (delete row $1$, column $i$ from $A$):
deleting row $i$/column $1$ of $A^T$ and then transposing back is the same
set of entries as deleting row $1$/column $i$ of $A$, just transposed,
since transposing swaps the roles of "row $1$" and "column $1$" and of
"column $i$" and "row $i$". Both are $(n-1)\times(n-1)$, so by the
inductive hypothesis $\det\big((A^T)_{(i,1)}\big) =
\det\big((A_{(1,i)})^T\big) = \det(A_{(1,i)})$. Substituting (and
relabeling the summation index $i$ as $j$):
$$\det(A^T) = \sum_{j=1}^n (-1)^{j+1}a_{1j}\det(A_{(1,j)}) = \det(A),$$
matching the row-$1$ expansion of $\det(A)$ term for term (since
$(-1)^{j+1}=(-1)^{1+j}$). $\blacksquare$

**8.** $\det(cA) = c^n\det(A)$, *not* $c\det(A)$. Reasoning: $cA$ is $A$
with *every one* of its $n$ columns (or rows) scaled by $c$. By
multilinearity (property (a)), scaling one column by $c$ multiplies $\det$
by $c$; scaling all $n$ columns by $c$, one at a time, multiplies $\det$ by
$c$ a total of $n$ times, i.e. by $c^n$. Sanity check with $n=2$,
$A=\begin{pmatrix}1&0\\0&1\end{pmatrix}$, $c=2$: $\det(A)=1$,
$2A=\begin{pmatrix}2&0\\0&2\end{pmatrix}$, $\det(2A)=4=2^2\cdot1$ — matches
$c^n\det(A)$, not $c\det(A)=2$.

**9.** (a) $\det(AB)=\det(A)\det(B) = 3\cdot(-2) = -6$ (Theorem 8.1).
(b) $\det(A^3) = \det(A)^3 = 3^3 = 27$ (Theorem 8.1 applied twice:
$\det(A^3)=\det(A\cdot A\cdot A)=\det(A)\det(A)\det(A)$).
(c) From $AA^{-1}=I$: $\det(A)\det(A^{-1}) = \det(AA^{-1}) = \det(I) = 1$
(Theorem 8.1), so $\det(A^{-1}) = 1/\det(A) = 1/3$.
(d) $\det(B^TA) = \det(B^T)\det(A) = \det(B)\det(A)$ (using
$\det(B^T)=\det(B)$ from Exercise 7) $= (-2)(3) = -6$.

**10.** By Theorem 8.1, $\det(A)^2 = \det(A)\det(A) = \det(A\cdot A) =
\det(A^2) = \det(0_{n\times n})$. The zero matrix has every row equal to
the zero vector, so by Lemma 8.1, $\det(0_{n\times n}) = 0$. Hence
$\det(A)^2 = 0$. Since $\det(A)$ is a real number and the only real number
whose square is $0$ is $0$ itself, $\det(A) = 0$. $\blacksquare$

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements the determinant itself, from scratch, via recursive
cofactor expansion — the exact procedure you just did by hand in Exercises
1–4, turned into code. Open `starter_code/day08_determinants.py` — it has
one function to complete, `cofactor_det`. Fill in the `TODO`, then run the
file directly (`python starter_code/day08_determinants.py`); it should
print that your cofactor determinant matches `numpy.linalg.det` on the
worked-example matrix.

**Hint:** this is a direct translation of Definition 8.2 into code.
Base cases: a $1\times1$ matrix's determinant is its single entry; a
$2\times2$ matrix's determinant is $ad-bc$ (you could also let the $1\times1$
case handle everything recursively, but $2\times2$ as an explicit base case
keeps the recursion shallow and easy to debug). Recursive case: for each
column `col`, build the minor by deleting row `0` and column `col`
(`np.delete` twice, once per axis), multiply by `A[0, col]` and the sign
`(-1)**col`, and sum over all columns — this is cofactor expansion along
row $0$ (row 1 in 1-indexed math notation).

If you get stuck for more than ~10 minutes, check
`solutions/day08_determinants.py` — but only after a real attempt.

Once your implementation passes, extend it as the file's `__main__` block
prompts: construct a $4\times4$ matrix of your own, confirm your
`cofactor_det` still matches `numpy.linalg.det` on it, and then verify
numerically that $\det(AA^T) = \det(A)\det(A^T)$ — a direct check of both
Theorem 8.1 (multiplicativity) and Exercise 7 ($\det(A^T)=\det(A)$) on the
same matrix.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $\det(A)$ | "the determinant of $A$" | one number that measures signed volume scaling |
| $M_n(\mathbb{R})$ | "the $n \times n$ real matrices" | the inputs the determinant eats |
| $A_{(i,j)}$ | "the $(i,j)$ minor of $A$" | $A$ with row $i$ and column $j$ deleted |
| $C_{ij} = (-1)^{i+j}\det(A_{(i,j)})$ | "the $(i,j)$ cofactor" | signed minor used in the expansion |
| $P_{ik},\ S_i(c),\ T_{ik}(c)$ | "swap / scale / add-multiple matrices" | $I$ with one row operation baked in |
| $\det(AB)$ | "determinant of the product" | equals $\det(A)\det(B)$ — the day's headline |
| $\operatorname{rank}(A)$ | "the rank — pivot count" | full rank $n$ is the invertibility test |
| $\iff$ | "is exactly the same statement as" | how the invertibility chain links up |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- The determinant is a signed volume-scaling factor, not just a formula:
  $|\det(A)|$ is how much $A$ stretches volume, and the sign says whether it
  flips orientation.
- The three elementary row operations change the determinant in fixed ways:
  a swap negates it, scaling a row by $c$ multiplies it by $c$, and adding a
  multiple of one row to another leaves it unchanged.
- The determinant is multiplicative: $\det(AB) = \det(A)\det(B)$ for every
  pair of $n \times n$ matrices.
- A square matrix is invertible exactly when its determinant is nonzero,
  tying the determinant directly to Day 5's rank and Day 6's subspaces.
- For a triangular matrix the determinant is just the product of the diagonal
  entries — which is why row-reducing to triangular form is the fast way to
  compute one.

### Proof sketches

**Lemma 8.1 — key trick: expand along the row that's all zeros.**
Cofactor expansion along the zero row multiplies each cofactor by that row's
entries, and those entries are all $0$. So every term in the sum is zero and
the whole determinant is zero. Full version: Lemma 8.1 above.

**Lemma 8.2 — key trick: multilinearity plus "equal rows give zero" handle
all three operations.**
Scaling a row by $c$ is just linearity in that row, so the determinant
scales by $c$. For a swap, put $u+v$ in both the $i$ and $k$ rows: the matrix
now has two equal rows so its determinant is zero, and expanding by
linearity leaves $\det(A) + \det(A') = 0$, giving the sign flip. For adding
$c$ times row $k$ to row $i$, linearity splits the result into $\det(A)$ plus
$c$ times a determinant with two equal rows, and that second piece is zero.
Full version: Lemma 8.2 above.

**Lemma 8.3 — key trick: each row of $EB$ is a recipe read off a row of
$E$.**
Row $m$ of any product $EB$ is the combination of $B$'s rows weighted by row
$m$ of $E$. Each elementary matrix is the identity with one row operation
applied, so its rows are exactly the basis rows needed to reproduce that same
operation on $B$ — swapping, scaling, or adding. Reading the three cases off
directly shows $EB$ is $B$ with the operation applied. Full version: Lemma
8.3 above.

**Corollary 8.1 — key trick: $\det E$ is the very factor that row operation
introduces.**
Because $E$ is the identity with one operation applied, Lemma 8.2 gives its
determinant outright: $-1$ for a swap, $c$ for a scaling, $1$ for an
add-multiple. Lemma 8.3 says $EB$ is $B$ with that same operation, and Lemma
8.2 again says the operation multiplies $\det(B)$ by that same factor. So
$\det(EB) = \det(E)\det(B)$. Full version: Corollary 8.1 above.

**Lemma 8.4 — key trick: row-reduce, then find the guaranteed zero row.**
Row reduction only multiplies the determinant by nonzero factors, so $A$ and
its echelon form $R$ are zero or nonzero together. Since $A$ is singular its
rank is below $n$, so $R$ has fewer than $n$ pivots and at least one all-zero
row. By Lemma 8.1 that forces $\det(R) = 0$, hence $\det(A) = 0$. Full
version: Lemma 8.4 above.

**Theorem 8.1 — key trick: split on invertibility; when $A$ is invertible,
break it into elementary pieces and telescope.**
If either factor is singular, then $AB$ is singular too (its column or row
space can't exceed the singular factor's), so both sides are zero by Lemma
8.4. If $A$ is invertible it row-reduces to $I$, so $A$ is a product of
elementary matrices. Peeling those factors off one at a time with Corollary
8.1 turns $\det(AB)$ into $\det(E_1)\cdots\det(E_m)\det(B)$, and the same
peeling on $A$ alone shows that leading product is exactly $\det(A)$. Full
version: Theorem 8.1 above.

**Lemma 8.5 — key trick: expand down the first column, where only the corner
survives.**
Expanding down column $1$ of an upper triangular matrix, every entry below
the top is zero, so only the top-left term $T_{11}$ contributes. Its minor is
again upper triangular with diagonal $T_{22}, \dots, T_{nn}$, so induction
gives its determinant as that product. Multiplying back in $T_{11}$ yields
the full diagonal product. Full version: Lemma 8.5 above.

**Theorem 8.2 — key trick: reduce to triangular form and read invertibility
off the diagonal.**
Row reduction changes the determinant only by nonzero factors, so $\det(A)$
is nonzero exactly when $\det(R)$ is, for the echelon form $R$. Being echelon
makes $R$ upper triangular, so by Lemma 8.5 its determinant is the product of
its diagonal entries, which is nonzero exactly when every diagonal entry is a
pivot — that is, when $R$ has full rank $n$. Full rank is preserved by row
operations and means invertibility, so chaining the equivalences gives
$\det(A) \neq 0 \iff A$ invertible. Full version: Theorem 8.2 above.

### If you remember only 3 things

1. $\det(AB) = \det(A)\det(B)$: the determinant turns matrix products into
   plain number products.
2. $\det(A) \neq 0$ is exactly the test for $A$ being invertible (equivalently
   full rank).
3. A row swap flips the sign of the determinant, and scaling the whole matrix
   gives $\det(cA) = c^n\det(A)$, not $c\det(A)$ — the volume picture is why.

## Journal template

```
## Day 8 — Determinants
Key theorem in my own words: ...
What confused me: ...
```
