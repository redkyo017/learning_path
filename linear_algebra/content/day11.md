# Day 11 — Diagonalization, Algebraic & Geometric Multiplicity

## Learning objectives

By the end of today you should be able to:
- State the definitions of algebraic multiplicity, geometric multiplicity,
  and "diagonalizable," and compute all three for a given matrix.
- Prove that $A$ is diagonalizable iff $A$ has $n$ linearly independent
  eigenvectors iff every eigenvalue's geometric multiplicity equals its
  algebraic multiplicity — the full three-way equivalence, not just the
  easy direction.
- Prove that similar matrices share the same characteristic polynomial
  (hence eigenvalues with multiplicity), trace, and determinant.
- Diagonalize a matrix by hand (find $P$, $D$ and verify $A = PDP^{-1}$),
  and correctly identify non-diagonalizable matrices from their
  multiplicities.

## Reference material

- Primer (continue from Day 10, 10–15 min): 3Blue1Brown, *Essence of Linear
  Algebra*, Chapter 14 ("Eigenvectors and eigenvalues"), specifically the
  second half where Grant discusses eigenbases and what it means to change
  coordinates into one — [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab).
  You already watched the eigenvalue-definition portion for Day 10; today's
  rewatch is specifically the diagonalization/eigenbasis portion.
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §4.3–4.4 —
  [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf).
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson), the
  second half of the Eigenvalues and Eigenvectors chapter, plus the
  introduction to the Canonical Forms chapter (where diagonalizability and
  the Jordan form are contrasted) — if you don't have a copy, the exercises
  below are self-contained.

The theory below is self-contained — you do not strictly need the Treil PDF
to do today's work, but reading §4.3–4.4 alongside this is the "theory"
layer of today's three-layer structure.

## Theory

Throughout, $A$ is a fixed $n \times n$ real matrix. Recall from Day 10: a
scalar $\lambda$ is an **eigenvalue** of $A$ if $Av = \lambda v$ for some
nonzero $v \in \mathbb{R}^n$ (an **eigenvector**); equivalently, $\lambda$ is
a root of the **characteristic polynomial**
$p_A(\lambda) = \det(A - \lambda I)$, a degree-$n$ polynomial. Recall also
Day 10's theorem that eigenvectors corresponding to *distinct* eigenvalues
are linearly independent — that fact does essentially all the work below.
We also write $N(A - \lambda I)$ for the null space of $A - \lambda I$
(same notation as Day 6's null space $N(\cdot)$), since that is exactly the
set of eigenvectors for $\lambda$ together with $0$.

### Definition 11.1 (Algebraic and geometric multiplicity)

Let $\lambda_0$ be an eigenvalue of $A$.

- The **algebraic multiplicity** of $\lambda_0$ is the multiplicity of
  $\lambda_0$ as a root of $p_A(\lambda)$: the largest integer $m$ such that
  $(\lambda - \lambda_0)^m$ divides $p_A(\lambda)$.
- The **eigenspace** of $\lambda_0$ is
  $E_{\lambda_0} = N(A - \lambda_0 I) = \{v \in \mathbb{R}^n : Av = \lambda_0
  v\}$ — a subspace of $\mathbb{R}^n$ (it's a null space, hence a subspace
  by Day 4). The **geometric multiplicity** of $\lambda_0$ is
  $g = \dim(E_{\lambda_0})$.

### Definition 11.2 (Diagonalizable, similar)

$A$ is **diagonalizable** (over $\mathbb{R}$) if there exists an invertible
matrix $P$ and a diagonal matrix $D$, both real, with $A = PDP^{-1}$.
Two $n \times n$ matrices $A, B$ are **similar** if $B = P^{-1}AP$ for some
invertible $P$. (So "diagonalizable" means exactly "similar to a diagonal
matrix.")

### Theorem 11.1 (Similar matrices share characteristic polynomial, eigenvalues, trace, determinant)

If $B = P^{-1}AP$ for some invertible $P$, then:
1. $p_B(\lambda) = p_A(\lambda)$ for all $\lambda$ (hence $A$ and $B$ have
   the same eigenvalues, with the same algebraic multiplicities).
2. $\det(B) = \det(A)$.
3. $\operatorname{trace}(B) = \operatorname{trace}(A)$.

**Proof.**

*(1)* For any $\lambda$,
$$B - \lambda I = P^{-1}AP - \lambda I = P^{-1}AP - \lambda P^{-1}P
= P^{-1}(AP - \lambda P) = P^{-1}(A - \lambda I)P,$$
using $P^{-1}P = I$ and factoring $P$ out on the right. Taking determinants
and using multiplicativity of $\det$ (that $\det(XY) = \det(X)\det(Y)$ for
square matrices of the same size, from Day 8):
$$p_B(\lambda) = \det(B - \lambda I) = \det(P^{-1})\det(A - \lambda I)\det(P)
= \det(A-\lambda I)\left(\det(P^{-1})\det(P)\right).$$
Since $P^{-1}P = I$, $\det(P^{-1})\det(P) = \det(P^{-1}P) = \det(I) = 1$
(again by multiplicativity). So $p_B(\lambda) = \det(A-\lambda I) =
p_A(\lambda)$ for every $\lambda$: $A$ and $B$ have the identical
characteristic polynomial as functions of $\lambda$, hence the same roots
with the same multiplicities, i.e. the same eigenvalues and the same
algebraic multiplicity for each.

*(2)* Setting $\lambda = 0$ in the identity $p_B(\lambda) = p_A(\lambda)$
gives $\det(B) = \det(B - 0\cdot I) = \det(A - 0 \cdot I) = \det(A)$.
(Alternatively, directly: $\det(B) = \det(P^{-1}AP) = \det(P^{-1})\det(A)\det(P)
= \det(A)$ by the same multiplicativity argument as above, without
mentioning $\lambda$ at all.)

*(3)* We first establish the **cyclic property of trace**: for any matrices
$X$ ($n\times m$) and $Y$ ($m \times n$), so that both $XY$ ($n\times n$)
and $YX$ ($m \times m$) are defined and square,
$$\operatorname{trace}(XY) = \operatorname{trace}(YX).$$
Indeed, $\operatorname{trace}(XY) = \sum_{i=1}^n (XY)_{ii} = \sum_{i=1}^n
\sum_{k=1}^m X_{ik}Y_{ki}$. Swapping the (finite) order of summation,
this equals $\sum_{k=1}^m \sum_{i=1}^n Y_{ki}X_{ik} = \sum_{k=1}^m (YX)_{kk}
= \operatorname{trace}(YX)$.

Now apply this with $X = P^{-1}$ and $Y = AP$ (both $n \times n$ here, but
the argument only needed compatible shapes):
$$\operatorname{trace}(B) = \operatorname{trace}(P^{-1}(AP))
= \operatorname{trace}((AP)P^{-1}) = \operatorname{trace}(A(PP^{-1}))
= \operatorname{trace}(AI) = \operatorname{trace}(A),$$
where the middle equality is the cyclic property just proved (with
$X = P^{-1}$, $Y = AP$), and the next step regrouped $(AP)P^{-1} =
A(PP^{-1})$ by associativity of matrix multiplication. $\blacksquare$

### Theorem 11.2 (Diagonalizable iff $n$ independent eigenvectors)

$A$ (an $n\times n$ matrix) is diagonalizable if and only if $A$ has $n$
linearly independent eigenvectors.

**Proof.**

($\Rightarrow$) Suppose $A = PDP^{-1}$ with $P$ invertible and
$D = \operatorname{diag}(\lambda_1, \dots, \lambda_n)$. Write $p_1, \dots,
p_n$ for the columns of $P$, i.e. $p_j = Pe_j$ where $e_j$ is the $j$-th
standard basis vector. From $A = PDP^{-1}$ we get $AP = PD$ (multiply both
sides on the right by $P$). Compare column $j$ of both sides:
$$\text{column } j \text{ of } AP = A(Pe_j) = Ap_j,$$
$$\text{column } j \text{ of } PD = P(De_j) = P(\lambda_j e_j) = \lambda_j
(Pe_j) = \lambda_j p_j.$$
So $Ap_j = \lambda_j p_j$ for every $j = 1, \dots, n$. Since $P$ is
invertible, its columns $p_1, \dots, p_n$ are nonzero (an invertible
matrix cannot have a zero column — that column would be a nontrivial
element of the null space) and linearly independent (the columns of an
invertible matrix form a basis of $\mathbb{R}^n$, by the invertible-matrix
characterizations from Day 9). So each $p_j$ is a genuine eigenvector, and
we have exhibited $n$ linearly independent eigenvectors of $A$.

($\Leftarrow$) Suppose $A$ has $n$ linearly independent eigenvectors
$p_1, \dots, p_n$, with $Ap_j = \lambda_j p_j$ for scalars $\lambda_j$ (not
necessarily distinct). Let $P = [\,p_1 \ \cdots \ p_n\,]$, the matrix with
these vectors as columns. Since $p_1, \dots, p_n$ are linearly independent,
$P$ is invertible (Day 9: $n$ linearly independent vectors in
$\mathbb{R}^n$ form a basis, and the matrix with a basis as columns is
invertible). Let $D = \operatorname{diag}(\lambda_1, \dots, \lambda_n)$.
Exactly as in the forward direction, column $j$ of $AP$ is $Ap_j = \lambda_j
p_j$ and column $j$ of $PD$ is $\lambda_j p_j$ — these agree for every $j$,
so $AP = PD$ as matrices. Multiplying both sides on the right by $P^{-1}$
gives $A = PDP^{-1}$, so $A$ is diagonalizable. $\blacksquare$

### Lemma 11.1 (Geometric multiplicity $\le$ algebraic multiplicity)

For any eigenvalue $\lambda_0$ of $A$, if $g$ is its geometric multiplicity
and $m$ is its algebraic multiplicity, then $g \le m$.

**Proof (sketch, using Theorem 11.1).** Let $v_1, \dots, v_g$ be a basis of
the eigenspace $E_{\lambda_0}$ (so $Av_i = \lambda_0 v_i$ for each $i$).
By the basis extension theorem (Day 2), extend this to a full basis
$v_1, \dots, v_g, v_{g+1}, \dots, v_n$ of $\mathbb{R}^n$, and let
$P = [\,v_1\ \cdots\ v_n\,]$, which is invertible since its columns are a
basis. Consider $B = P^{-1}AP$, similar to $A$. For $j \le g$: column $j$ of
$AP$ is $Av_j = \lambda_0 v_j$, so column $j$ of $B = P^{-1}AP$ is
$P^{-1}(\lambda_0 v_j) = \lambda_0 (P^{-1}v_j) = \lambda_0 e_j$ (since $v_j$
is the $j$-th column of $P$, $P^{-1}v_j = e_j$). So $B$'s first $g$ columns
are $\lambda_0 e_1, \dots, \lambda_0 e_g$, which forces the block form
$$B = \begin{pmatrix} \lambda_0 I_g & * \\ 0 & C \end{pmatrix}$$
for some $g \times (n-g)$ block $*$ and some $(n-g)\times(n-g)$ block $C$
(the bottom-left block is $0$ because the first $g$ columns are zero below
row $g$). For a block *upper triangular* matrix, $\det$ factors as the
product of the diagonal blocks' determinants (a standard fact from Day 8,
provable by cofactor-expanding down the first $g$ columns and observing
every nonzero term picks its row/column indices entirely from the top-left
block for those columns). Applying this to $B - \lambda I$, which has the
same block shape with $\lambda_0 I_g$ replaced by $(\lambda_0-\lambda)I_g$
on the diagonal block:
$$p_B(\lambda) = \det(B - \lambda I) = \det\big((\lambda_0-\lambda)I_g\big)
\cdot \det(C - \lambda I_{n-g}) = (\lambda_0 - \lambda)^g \det(C - \lambda
I_{n-g}).$$
So $(\lambda - \lambda_0)^g$ (up to sign) divides $p_B(\lambda)$, i.e.
$\lambda_0$'s multiplicity as a root of $p_B$ is at least $g$. By Theorem
11.1, $p_B = p_A$ (since $B$ is similar to $A$), so $\lambda_0$'s
multiplicity as a root of $p_A$ — which is $m$, by Definition 11.1 — is
also at least $g$. Hence $g \le m$. $\blacksquare$

(The two ingredients cited without re-proof — basis extension, and the
block-triangular determinant formula — are themselves fully proved results
from Day 2 and Day 8 respectively; nothing here is asserted without proof
*somewhere* in the course, this lemma just doesn't re-derive them inline.)

### Lemma 11.2 (Eigenspaces for distinct eigenvalues form a direct sum)

Let $\lambda_1, \dots, \lambda_k$ be the *distinct* eigenvalues of $A$. If
$v_1 + v_2 + \cdots + v_k = 0$ with each $v_i \in E_{\lambda_i}$, then every
$v_i = 0$.

**Proof.** Suppose not. Discard the $v_i$ that are already $0$ and relabel
so that $v_1, \dots, v_j$ (some $1 \le j \le k$) are exactly the nonzero
ones among a hypothetical counterexample, with $v_1 + \cdots + v_j = 0$
(the discarded zero terms don't affect the sum). Each $v_i$ ($i \le j$) is
a *nonzero* vector in $E_{\lambda_i}$, i.e. a genuine eigenvector for
$\lambda_i$. But $\lambda_1, \dots, \lambda_j$ are distinct (they're a
subset of the distinct list $\lambda_1,\dots,\lambda_k$), so by Day 10's
theorem, eigenvectors $v_1, \dots, v_j$ for distinct eigenvalues are
linearly independent. Linear independence means the *only* way
$c_1v_1 + \cdots + c_jv_j = 0$ is $c_1 = \cdots = c_j = 0$ — but we have
$1\cdot v_1 + \cdots + 1 \cdot v_j = 0$ with all coefficients $1 \ne 0$,
a contradiction (this requires $j \ge 1$, i.e. that there was at least one
nonzero term — exactly the assumption that we have a counterexample). So no
such nonzero $v_i$ can exist: every $v_i = 0$. $\blacksquare$

### Corollary 11.1 (Maximum independent eigenvectors $= \sum$ geometric multiplicities)

Let $\lambda_1, \dots, \lambda_k$ be the distinct eigenvalues of $A$, with
geometric multiplicities $g_1, \dots, g_k$. Then the largest possible size
of a linearly independent set of eigenvectors of $A$ is exactly
$g_1 + g_2 + \cdots + g_k$.

**Proof.** *Upper bound.* Let $S$ be any linearly independent set of
eigenvectors of $A$. Every eigenvector of $A$ lies in exactly one $E_{\lambda_i}$
(the one for its own eigenvalue), so $S$ partitions as $S = S_1 \cup \cdots
\cup S_k$ with $S_i = S \cap E_{\lambda_i}$. Each $S_i$ is a subset of the
linearly independent set $S$, hence itself linearly independent, hence
$|S_i| \le \dim(E_{\lambda_i}) = g_i$ (a linearly independent subset of a
$g_i$-dimensional space has at most $g_i$ elements — Day 2). So
$|S| = \sum_i |S_i| \le \sum_i g_i$.

*This bound is achieved.* For each $i$, let $B_i$ be a basis of
$E_{\lambda_i}$ (so $|B_i| = g_i$), and let $S = B_1 \cup \cdots \cup B_k$,
$|S| = \sum_i g_i$ (these sets are disjoint since the eigenspaces intersect
only in $0$, which isn't in any basis). We claim $S$ is linearly
independent. Suppose a linear combination of $S$ vanishes; group the terms
by which $B_i$ they came from: $\sum_i w_i = 0$ where $w_i$ is the
(sub)combination of vectors from $B_i$, so $w_i \in E_{\lambda_i}$. By Lemma
11.2, every $w_i = 0$. But $B_i$ is linearly independent (it's a basis), so
$w_i = 0$ forces every coefficient used to build $w_i$ to be $0$. This holds
for every $i$, so *all* coefficients in the original combination are $0$:
$S$ is linearly independent, achieving size $\sum_i g_i$. $\blacksquare$

### Remark (Real vs. complex eigenvalues — a standing hypothesis)

This course covers only real vector spaces (complex vector spaces are
deferred to the post-Day-30 phase). A real $n\times n$ matrix's
characteristic polynomial has real coefficients but need not have all real
roots — e.g. a $90°$ rotation matrix has no real eigenvalues at all. If
$p_A(\lambda)$ does not split into $n$ real linear factors (i.e. the real
eigenvalues' algebraic multiplicities sum to less than $n$), then $A$
**cannot** be diagonalized over $\mathbb{R}$, full stop, regardless of any
multiplicity condition on the real eigenvalues it does have — there simply
cannot be $n$ real eigenvectors when not even $n$ real eigenvalues exist to
own them. Theorem 11.3 below is therefore stated under the standing
hypothesis that $p_A(\lambda)$ splits into real linear factors; every
matrix in this course's exercises satisfies this hypothesis by
construction. Watch for this becoming a genuine (not just hypothetical)
concern once complex eigenvalues are treated properly post-Day-30.

### Theorem 11.3 (Main diagonalizability criterion)

Suppose $p_A(\lambda)$ splits into real linear factors,
$$p_A(\lambda) = \pm(\lambda - \lambda_1)^{m_1}(\lambda-\lambda_2)^{m_2}
\cdots (\lambda - \lambda_k)^{m_k}, \qquad m_1 + m_2 + \cdots + m_k = n,$$
with $\lambda_1, \dots, \lambda_k$ the distinct (real) eigenvalues of $A$
and $m_i$ the algebraic multiplicity of $\lambda_i$. Let $g_i$ denote the
geometric multiplicity of $\lambda_i$. Then the following are equivalent:

1. $A$ is diagonalizable.
2. $A$ has $n$ linearly independent eigenvectors.
3. $g_i = m_i$ for every $i = 1, \dots, k$.

**Proof.** (1) $\iff$ (2) is exactly Theorem 11.2.

(2) $\iff$ (3): By Corollary 11.1, the maximum possible size of a linearly
independent set of eigenvectors of $A$ is $\sum_i g_i$. So "$A$ has $n$
linearly independent eigenvectors" is equivalent to "the maximum, $\sum_i
g_i$, is at least $n$" — but since the maximum is *exactly* $\sum_i g_i$
(not merely an upper bound — Corollary 11.1 shows it's achieved), this is
equivalent to $\sum_i g_i = n$ exactly (it can't exceed $n$ either, since
$n$ linearly independent vectors is already the most $\mathbb{R}^n$ can
hold — Day 2). So condition (2) is equivalent to
$$\sum_{i=1}^k g_i = n.$$
Now, by Lemma 11.1, $g_i \le m_i$ for every $i$, so $m_i - g_i \ge 0$ for
every $i$. Summing over $i$ and using $\sum_i m_i = n$ (our standing
hypothesis):
$$\sum_{i=1}^k (m_i - g_i) = n - \sum_{i=1}^k g_i.$$
The left side is a sum of $k$ nonnegative terms. If $\sum_i g_i = n$, the
right side is $0$, forcing *every* term $m_i - g_i$ on the left (each
$\ge 0$) to individually be $0$ — a sum of nonnegative numbers is zero only
if each summand is zero. So $g_i = m_i$ for every $i$, which is (3).
Conversely, if $g_i = m_i$ for every $i$, then $\sum_i g_i = \sum_i m_i = n$,
which is (2)'s equivalent condition. So (2) $\iff$ (3). $\blacksquare$

## Worked example

**Claim:** $A = \begin{pmatrix}2&1\\0&2\end{pmatrix}$ is **not**
diagonalizable, while $B = \begin{pmatrix}4&1\\2&3\end{pmatrix}$ **is**
diagonalizable, with explicit $P, D$.

**$A$:** $p_A(\lambda) = \det\begin{pmatrix}2-\lambda & 1\\0&2-\lambda\end{pmatrix}
= (2-\lambda)^2$ (upper triangular, so the determinant is the product of
the diagonal entries). The only root is $\lambda = 2$, with algebraic
multiplicity $m = 2$. For the eigenspace, solve $(A - 2I)v = 0$:
$$A - 2I = \begin{pmatrix}0&1\\0&0\end{pmatrix}, \qquad
\begin{pmatrix}0&1\\0&0\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix} =
\begin{pmatrix}y\\0\end{pmatrix} = \begin{pmatrix}0\\0\end{pmatrix}
\implies y = 0,\ x \text{ free}.$$
So $E_2 = \operatorname{span}\{(1,0)\}$, geometric multiplicity $g = 1$.
Since $g = 1 < 2 = m$, Theorem 11.3 says $A$ is **not diagonalizable** —
there is only 1 independent eigenvector available, but 2 are needed.

**$B$:** $p_B(\lambda) = \det\begin{pmatrix}4-\lambda&1\\2&3-\lambda\end{pmatrix}
= (4-\lambda)(3-\lambda) - 2 = \lambda^2 - 7\lambda + 10 = (\lambda-5)(\lambda-2)$.
Two distinct eigenvalues, $\lambda = 5$ and $\lambda = 2$, each with
algebraic (and, as we'll check, geometric) multiplicity $1$.

*Eigenvector for $\lambda=5$:* $B - 5I = \begin{pmatrix}-1&1\\2&-2\end{pmatrix}$;
row 1 gives $-x + y = 0 \implies y = x$. Eigenvector $(1,1)$.

*Eigenvector for $\lambda=2$:* $B - 2I = \begin{pmatrix}2&1\\2&1\end{pmatrix}$;
row 1 gives $2x + y = 0 \implies y = -2x$. Eigenvector $(1,-2)$.

Both eigenspaces are 1-dimensional (a single nonzero row after elimination,
one free variable), so $g=m=1$ for both eigenvalues — diagonalizable by
Theorem 11.3. Take
$$P = \begin{pmatrix}1&1\\1&-2\end{pmatrix}, \qquad
D = \begin{pmatrix}5&0\\0&2\end{pmatrix}.$$
**Verify $A = PDP^{-1}$:** $\det(P) = 1(-2) - 1(1) = -3$, so
$P^{-1} = \frac{1}{-3}\begin{pmatrix}-2&-1\\-1&1\end{pmatrix} =
\begin{pmatrix}2/3&1/3\\1/3&-1/3\end{pmatrix}$. Then
$$PD = \begin{pmatrix}1&1\\1&-2\end{pmatrix}\begin{pmatrix}5&0\\0&2\end{pmatrix}
= \begin{pmatrix}5&2\\5&-4\end{pmatrix},$$
$$PDP^{-1} = \begin{pmatrix}5&2\\5&-4\end{pmatrix}
\begin{pmatrix}2/3&1/3\\1/3&-1/3\end{pmatrix} =
\begin{pmatrix}\frac{10+2}{3}&\frac{5-2}{3}\\[2pt]\frac{10-4}{3}&\frac{5+4}{3}\end{pmatrix}
= \begin{pmatrix}4&1\\2&3\end{pmatrix} = B. \checkmark$$

## Unconventional edge

A common trap for self-learners: concluding that diagonalizability
*requires* distinct eigenvalues, because "distinct eigenvalues $\implies$
diagonalizable" is the first, easy corollary usually taught (it's Exercise
8 below). That statement gives a *sufficient* condition, not a *necessary*
one — Theorem 11.3's actual criterion is about multiplicities matching, not
about distinctness. The cleanest counterexample is the identity matrix
$I_n$: its only eigenvalue is $\lambda=1$ with algebraic multiplicity $n$
(as repeated as multiplicities get), yet $N(I - 1\cdot I) = N(0) =
\mathbb{R}^n$ has dimension $n$, so the geometric multiplicity is also $n$
— they match, so $I_n$ is diagonalizable (trivially: $I_n = I_n I_n
I_n^{-1}$, already diagonal). If you catch yourself checking "are the
eigenvalues distinct?" as your diagonalizability test instead of "does
geometric multiplicity equal algebraic multiplicity for each eigenvalue?",
that's the sufficient-condition trap — go back to Theorem 11.3.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–3 ask you to diagonalize a matrix fully (find $P, D$,
verify $A=PDP^{-1}$); 4–7 ask only for algebraic/geometric multiplicities
and a diagonalizability verdict (including non-diagonalizable cases); 8 is
a proof problem; 9 is a true/false trap about similar matrices; 10 is a
proof problem previewing Day 12.

1. Diagonalize $A_1 = \begin{pmatrix}1&2\\2&1\end{pmatrix}$: find $P, D$ and
   verify $A_1 = PDP^{-1}$.
2. Diagonalize $A_2 = \begin{pmatrix}0&1\\-2&3\end{pmatrix}$: find $P, D$
   and verify $A_2 = PDP^{-1}$.
3. Diagonalize $A_3 = \begin{pmatrix}1&1&0\\0&2&0\\0&0&3\end{pmatrix}$: find
   $P, D$ and verify $A_3 = PDP^{-1}$.
4. Let $A_4 = \begin{pmatrix}3&1\\0&3\end{pmatrix}$. Find the algebraic and
   geometric multiplicity of every eigenvalue. Is $A_4$ diagonalizable?
5. Let $A_5 = \begin{pmatrix}4&1&0\\0&4&1\\0&0&4\end{pmatrix}$. Find the
   algebraic and geometric multiplicity of every eigenvalue. Is $A_5$
   diagonalizable?
6. Let $A_6 = \begin{pmatrix}4&0&0\\0&4&0\\1&0&4\end{pmatrix}$. Find the
   algebraic and geometric multiplicity of every eigenvalue. Is $A_6$
   diagonalizable?
7. Let $A_7 = 5I_3$ (the $3\times3$ scalar matrix with $5$'s on the
   diagonal). Find the algebraic and geometric multiplicity of its
   eigenvalue. Is $A_7$ diagonalizable?
8. Prove: if an $n\times n$ matrix $A$ has $n$ *distinct* eigenvalues, then
   $A$ is automatically diagonalizable. (Use Day 10's theorem that
   eigenvectors for distinct eigenvalues are linearly independent, together
   with Theorem 11.2 above.)
9. True or False, with justification: if $A$ and $B$ are similar matrices,
   then they have the same eigen*vectors* (not just the same eigenvalues).
   If false, give a concrete $2\times2$ counterexample.
10. Prove: if $A$ is diagonalizable, $A = PDP^{-1}$, then for every integer
    $k \ge 0$, $A^k = PD^kP^{-1}$ (where $D^k$ is just each diagonal entry
    raised to the $k$-th power). Use induction on $k$.

## Solutions

**1.** $p_{A_1}(\lambda) = (1-\lambda)^2 - 4 = \lambda^2 - 2\lambda - 3 =
(\lambda-3)(\lambda+1)$; eigenvalues $3, -1$.
For $\lambda=3$: $A_1 - 3I = \begin{pmatrix}-2&2\\2&-2\end{pmatrix}$, row 1
gives $-2x+2y=0 \implies y=x$; eigenvector $(1,1)$.
For $\lambda=-1$: $A_1+I = \begin{pmatrix}2&2\\2&2\end{pmatrix}$, row 1
gives $2x+2y=0\implies y=-x$; eigenvector $(1,-1)$.
$$P = \begin{pmatrix}1&1\\1&-1\end{pmatrix}, \quad D=\begin{pmatrix}3&0\\0&-1\end{pmatrix}.$$
$\det(P) = -1-1=-2$, $P^{-1} = \frac{1}{-2}\begin{pmatrix}-1&-1\\-1&1\end{pmatrix}
= \begin{pmatrix}1/2&1/2\\1/2&-1/2\end{pmatrix}$.
$PD = \begin{pmatrix}3&-1\\3&1\end{pmatrix}$;
$PDP^{-1} = \begin{pmatrix}3&-1\\3&1\end{pmatrix}\begin{pmatrix}1/2&1/2\\1/2&-1/2\end{pmatrix}
= \begin{pmatrix}\frac{3-1}{2}&\frac{3+1}{2}\\\frac{3+1}{2}&\frac{3-1}{2}\end{pmatrix}
= \begin{pmatrix}1&2\\2&1\end{pmatrix} = A_1$. $\checkmark$

**2.** $p_{A_2}(\lambda) = -\lambda(3-\lambda) - (1)(-2) = \lambda^2-3\lambda+2
= (\lambda-1)(\lambda-2)$; eigenvalues $1, 2$.
For $\lambda=1$: $A_2-I=\begin{pmatrix}-1&1\\-2&2\end{pmatrix}$, row 1:
$-x+y=0\implies y=x$; eigenvector $(1,1)$.
For $\lambda=2$: $A_2-2I=\begin{pmatrix}-2&1\\-2&1\end{pmatrix}$, row 1:
$-2x+y=0\implies y=2x$; eigenvector $(1,2)$.
$$P=\begin{pmatrix}1&1\\1&2\end{pmatrix}, \quad D=\begin{pmatrix}1&0\\0&2\end{pmatrix}.$$
$\det(P)=2-1=1$, $P^{-1}=\begin{pmatrix}2&-1\\-1&1\end{pmatrix}$.
$PD=\begin{pmatrix}1&2\\1&4\end{pmatrix}$;
$PDP^{-1}=\begin{pmatrix}1&2\\1&4\end{pmatrix}\begin{pmatrix}2&-1\\-1&1\end{pmatrix}
=\begin{pmatrix}2-2&-1+2\\2-4&-1+4\end{pmatrix}=\begin{pmatrix}0&1\\-2&3\end{pmatrix}=A_2$. $\checkmark$

**3.** $A_3$ is upper triangular, so $p_{A_3}(\lambda)=(1-\lambda)(2-\lambda)(3-\lambda)$;
eigenvalues $1,2,3$ (distinct, each algebraic multiplicity 1).
For $\lambda=1$: $A_3-I=\begin{pmatrix}0&1&0\\0&1&0\\0&0&2\end{pmatrix}$:
row 1 gives $y=0$; row 3 gives $2z=0\implies z=0$; $x$ free. Eigenvector
$(1,0,0)$.
For $\lambda=2$: $A_3-2I=\begin{pmatrix}-1&1&0\\0&0&0\\0&0&1\end{pmatrix}$:
row 3 gives $z=0$; row 1 gives $-x+y=0\implies y=x$; $x$ free. Eigenvector
$(1,1,0)$.
For $\lambda=3$: $A_3-3I=\begin{pmatrix}-2&1&0\\0&-1&0\\0&0&0\end{pmatrix}$:
row 2 gives $y=0$; row 1 gives $-2x+y=0\implies x=0$; $z$ free. Eigenvector
$(0,0,1)$.
$$P=\begin{pmatrix}1&1&0\\0&1&0\\0&0&1\end{pmatrix}, \quad
D=\begin{pmatrix}1&0&0\\0&2&0\\0&0&3\end{pmatrix}.$$
$P^{-1}=\begin{pmatrix}1&-1&0\\0&1&0\\0&0&1\end{pmatrix}$ (check:
$P P^{-1}$ gives $I$ directly by matrix multiplication).
$PD=\begin{pmatrix}1&2&0\\0&2&0\\0&0&3\end{pmatrix}$;
$PDP^{-1}=\begin{pmatrix}1&2&0\\0&2&0\\0&0&3\end{pmatrix}
\begin{pmatrix}1&-1&0\\0&1&0\\0&0&1\end{pmatrix}
=\begin{pmatrix}1&-1+2&0\\0&2&0\\0&0&3\end{pmatrix}
=\begin{pmatrix}1&1&0\\0&2&0\\0&0&3\end{pmatrix}=A_3$. $\checkmark$

**4.** $A_4$ upper triangular, $p_{A_4}(\lambda) = (3-\lambda)^2$; single
eigenvalue $\lambda=3$, algebraic multiplicity $m=2$. $A_4-3I=
\begin{pmatrix}0&1\\0&0\end{pmatrix}$: row 1 gives $y=0$, $x$ free — 1
free variable, geometric multiplicity $g=1$. Since $g=1 < m=2$, $A_4$ is
**not diagonalizable**.

**5.** $A_5$ upper triangular, $p_{A_5}(\lambda)=(4-\lambda)^3$; single
eigenvalue $\lambda=4$, algebraic multiplicity $m=3$. $A_5-4I =
\begin{pmatrix}0&1&0\\0&0&1\\0&0&0\end{pmatrix}$: row 1 gives $y=0$; row 2
gives $z=0$; $x$ free — $g=1$. Since $g=1<m=3$, $A_5$ is **not
diagonalizable** (a "Jordan block" — the maximally non-diagonalizable
case).

**6.** $A_6$ lower triangular, $p_{A_6}(\lambda)=(4-\lambda)^3$; single
eigenvalue $\lambda=4$, algebraic multiplicity $m=3$. $A_6-4I=
\begin{pmatrix}0&0&0\\0&0&0\\1&0&0\end{pmatrix}$: row 3 gives $x=0$; rows 1,2
are trivially satisfied; $y,z$ free — $g=2$. Since $g=2<m=3$, $A_6$ is
**not diagonalizable** (a partial defect: 2 independent eigenvectors exist,
just not the 3 needed).

**7.** $A_7=5I_3$: $p_{A_7}(\lambda)=(5-\lambda)^3$; single eigenvalue
$\lambda=5$, algebraic multiplicity $m=3$. $A_7-5I=0$ (the zero matrix), so
every vector in $\mathbb{R}^3$ solves $(A_7-5I)v=0$: $E_5=\mathbb{R}^3$,
geometric multiplicity $g=3$. Since $g=3=m$, $A_7$ **is diagonalizable**
(trivially — it's already diagonal, $P=I_3$, $D=A_7$). This is the "Day 11
edge case" pattern: repeated eigenvalue, but still diagonalizable, because
multiplicities match despite the lack of distinctness.

**8.** Suppose $A$ has $n$ distinct eigenvalues $\lambda_1,\dots,\lambda_n$.
Each $\lambda_i$ is a root of $p_A$, so $N(A-\lambda_iI) \ne \{0\}$: pick a
nonzero eigenvector $v_i \in N(A-\lambda_iI)$ for each $i$. By Day 10's
theorem, eigenvectors corresponding to distinct eigenvalues are linearly
independent, and $\lambda_1,\dots,\lambda_n$ are (by hypothesis) distinct,
so $v_1,\dots,v_n$ are linearly independent. That's $n$ linearly
independent vectors in $\mathbb{R}^n$ — i.e. $n$ linearly independent
eigenvectors of $A$. By Theorem 11.2, $A$ is diagonalizable. $\blacksquare$

**9.** **False.** Let $A=\begin{pmatrix}1&0\\0&2\end{pmatrix}$ (eigenvector
$(0,1)$ for $\lambda=2$) and $P=\begin{pmatrix}1&1\\0&1\end{pmatrix}$
(invertible, $\det P=1$, $P^{-1}=\begin{pmatrix}1&-1\\0&1\end{pmatrix}$).
Compute $B=P^{-1}AP$: $AP=\begin{pmatrix}1&1\\0&2\end{pmatrix}$, so
$B=P^{-1}(AP)=\begin{pmatrix}1&-1\\0&1\end{pmatrix}\begin{pmatrix}1&1\\0&2\end{pmatrix}
=\begin{pmatrix}1&1-2\\0&2\end{pmatrix}=\begin{pmatrix}1&-1\\0&2\end{pmatrix}$.
By Theorem 11.1, $A$ and $B$ are similar, so they share eigenvalues $1,2$
(check: $\operatorname{trace}(B)=3=\operatorname{trace}(A)$,
$\det(B)=2=\det(A)$ $\checkmark$). Eigenvector of $B$ for $\lambda=2$: solve
$(B-2I)v=0$, $B-2I=\begin{pmatrix}-1&-1\\0&0\end{pmatrix}$, row 1:
$-x-y=0\implies y=-x$; eigenvector $(1,-1)$. This is **not** a scalar
multiple of $A$'s eigenvector $(0,1)$ for the same eigenvalue $2$ — so $A$
and $B$ are similar, share the eigenvalue $2$, but have genuinely different
eigenvectors for it. Similarity preserves eigen*values*, not eigen*vectors*
(the eigenvector of $B$ is $P^{-1}$ applied to the eigenvector of $A$, as
you can check: $P^{-1}(0,1) = (0\cdot1+(-1)\cdot1,\ 1) = (-1,1)$, parallel
to $(1,-1)$ — similar matrices' eigenvectors are related by $P^{-1}$, not
identical).

**10.** *Base case* $k=0$: $A^0 = I$ and $PD^0P^{-1} = PIP^{-1}=PP^{-1}=I$
(since $D^0$ is the identity — every diagonal entry raised to the $0$-th
power is $1$). So the claim holds for $k=0$.
*Inductive step:* suppose $A^k = PD^kP^{-1}$ for some $k\ge 0$. Then
$$A^{k+1} = A^k \cdot A = \left(PD^kP^{-1}\right)\left(PDP^{-1}\right)
= PD^k\left(P^{-1}P\right)DP^{-1} = PD^k(I)DP^{-1} = P\left(D^kD\right)P^{-1}
= PD^{k+1}P^{-1},$$
using $D^kD = D^{k+1}$ (diagonal matrices multiply entrywise, so powers of
the same diagonal matrix add exponents, exactly like scalars). By
induction, $A^k = PD^kP^{-1}$ for every integer $k \ge 0$. $\blacksquare$

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements a numerical diagonalizability test and
reconstruction. Open `starter_code/day11_diagonalization.py` — it has one
function to complete, `diagonalize_and_reconstruct`. Fill in the `TODO`,
then run the file directly
(`python starter_code/day11_diagonalization.py`); it should print both
success messages with no errors.

**Hint:** use `np.linalg.eig(A)` to get eigenvalues and eigenvectors (the
eigenvectors come back as the *columns* of a matrix — exactly the $P$ from
Theorem 11.2's proof). Then check
`np.linalg.matrix_rank(eigenvectors) == A.shape[0]` — this is the
numerical analogue of "are these $n$ eigenvectors linearly independent,"
i.e. exactly condition (2) of Theorem 11.3. If the rank is full, build
$D = \operatorname{diag}(\text{eigenvalues})$ and reconstruct
$P D P^{-1}$; if not, $A$ isn't diagonalizable and there's nothing sound to
reconstruct.

Once your implementation passes, extend it: run it on the Jordan block from
Exercise 5, $\begin{pmatrix}4&1&0\\0&4&1\\0&0&4\end{pmatrix}$, and confirm
your function correctly reports `is_diagonalizable == False` — a good
sanity check that the code and your by-hand multiplicity analysis agree.
Also try `np.linalg.matrix_rank` on the eigenvector matrix `np.linalg.eig`
returns for the worked-example matrix $B=\begin{pmatrix}4&1\\2&3\end{pmatrix}$
above, and confirm the $P, D$ NumPy finds match yours up to column
reordering and scaling (eigenvectors are only unique up to a nonzero
scalar multiple).

If you get stuck for more than ~10 minutes, check
`solutions/day11_diagonalization.py` — but only after a real attempt.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $A = PDP^{-1}$ | "$A$ rebuilt from its eigenvectors and eigenvalues" | $P$'s columns are eigenvectors, $D$'s diagonal their eigenvalues |
| $B = P^{-1}AP$ | "$B$ is $A$ rewritten in new coordinates ($A,B$ are *similar*)" | conjugating by $P$; keeps char. polynomial, det, trace |
| $D = \operatorname{diag}(\lambda_1,\dots,\lambda_n)$ | "the diagonal matrix of eigenvalues" | the simple shape $A$ takes once diagonalized |
| $E_{\lambda_0} = N(A-\lambda_0 I)$ | "the eigenspace of $\lambda_0$" | every eigenvector for $\lambda_0$, together with $0$ |
| $m$ (algebraic mult.) | "how many times $\lambda_0$ is a root of $p_A$" | the exponent of $(\lambda-\lambda_0)$ in the char. polynomial |
| $g$ (geometric mult.) | "how many independent eigenvectors $\lambda_0$ has" | $\dim E_{\lambda_0}$; always $\le m$ |
| $\operatorname{trace}(A)$ | "the sum of the diagonal entries" | unchanged by similarity; equals the sum of eigenvalues |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- Diagonalizing $A$ means finding a full set of eigenvectors: $A = PDP^{-1}$,
  where $P$'s columns are eigenvectors and $D$ lists the matching
  eigenvalues.
- An $n \times n$ matrix is diagonalizable exactly when it has $n$ linearly
  independent eigenvectors — no fewer will do.
- For every eigenvalue, its geometric multiplicity (number of independent
  eigenvectors) is at most its algebraic multiplicity (root order), and
  diagonalizability is precisely the case where the two are equal for *every*
  eigenvalue.
- Similar matrices $B = P^{-1}AP$ are one map seen in two coordinate systems,
  so they share characteristic polynomial, eigenvalues with multiplicity,
  determinant, and trace — but generally not eigenvectors.
- Distinct eigenvalues are sufficient but not necessary for
  diagonalizability: a repeated eigenvalue may still be fine (the identity
  $I_n$) or may fail (a Jordan block).

### Proof sketches

**Theorem 11.1 — key trick: conjugating by $P$ slides straight through
$\det$, and $\det(P^{-1})\det(P) = 1$ erases $P$ entirely.**
Insert $\lambda P^{-1}P$ to rewrite $B - \lambda I = P^{-1}(A - \lambda I)P$.
Determinant is multiplicative, so $p_B(\lambda) = \det(P^{-1})\,p_A(\lambda)\,
\det(P)$, and the two $P$-factors multiply to $\det(I) = 1$, leaving
$p_B = p_A$ — identical polynomials, hence identical eigenvalues and
multiplicities. Setting $\lambda = 0$ in that identity gives $\det B = \det
A$. Trace needs one extra fact, $\operatorname{trace}(XY) =
\operatorname{trace}(YX)$ (swap the order of a finite double sum), which lets
you cycle $\operatorname{trace}(P^{-1}(AP)) = \operatorname{trace}((AP)P^{-1})
= \operatorname{trace}(A)$. Full version: Theorem 11.1 above.

**Theorem 11.2 — key trick: $A = PDP^{-1}$ is the same equation as $AP = PD$,
which read one column at a time says "column $j$ of $P$ is an eigenvector."**
Multiply $A = PDP^{-1}$ on the right by $P$ to get $AP = PD$. Column $j$ of
$AP$ is $Ap_j$; column $j$ of $PD$ is $\lambda_j p_j$; so $Ap_j = \lambda_j
p_j$. An invertible $P$ has nonzero, independent columns — exactly $n$
independent eigenvectors. Run the same reading backwards: $n$ independent
eigenvectors let you build an invertible $P$ and diagonal $D$ with $AP = PD$,
i.e. $A = PDP^{-1}$. Full version: Theorem 11.2 above.

**Lemma 11.1 — key trick: put a basis of the eigenspace first among $P$'s
columns; the similar matrix $P^{-1}AP$ then opens with a $\lambda_0 I_g$
block.**
Take a basis $v_1,\dots,v_g$ of $E_{\lambda_0}$ and extend it to a basis of
the whole space; these columns form an invertible $P$. Because $Av_j =
\lambda_0 v_j$ for the first $g$ columns, $B = P^{-1}AP$ is block-upper-
triangular with $\lambda_0 I_g$ in the top-left corner. Its characteristic
polynomial therefore carries a factor $(\lambda_0 - \lambda)^g$, so $\lambda_0$
is a root of $p_B$ at least $g$ times. Since $B$ is similar to $A$, $p_B =
p_A$ (Theorem 11.1), so the algebraic multiplicity $m$ is at least $g$. Full
version: Lemma 11.1 above.

**Lemma 11.2 — key trick: if a sum of one-vector-per-eigenspace is zero, the
surviving nonzero pieces would be dependent eigenvectors for distinct
eigenvalues — which Day 10 forbids.**
Suppose $v_1 + \cdots + v_k = 0$ with each $v_i \in E_{\lambda_i}$, and throw
away every $v_i$ that is already $0$. If any survive, they are genuine
eigenvectors for distinct eigenvalues, so by Day 10's theorem they are
linearly independent — yet here they sum to $0$ with every coefficient equal
to $1$, a contradiction. So none survive: every $v_i = 0$. Full version:
Lemma 11.2 above.

**Corollary 11.1 — key trick: sort any independent set of eigenvectors into
its eigenspaces for the ceiling, then pool eigenspace bases to hit it.**
Upper bound: every eigenvector lives in exactly one $E_{\lambda_i}$, so an
independent set $S$ splits into the pieces $S_i = S \cap E_{\lambda_i}$; each
$S_i$ is independent inside a $g_i$-dimensional space, hence has at most
$g_i$ vectors, so $|S| \le \sum_i g_i$. Achievability: take a basis $B_i$ of
each $E_{\lambda_i}$ and pool them into $S = B_1 \cup \cdots \cup B_k$ of
size $\sum_i g_i$. If a combination of $S$ vanishes, grouping its terms by
eigenspace gives $\sum_i w_i = 0$ with $w_i \in E_{\lambda_i}$, so Lemma 11.2
forces each $w_i = 0$, and each $B_i$ being a basis forces its coefficients
to $0$ — the pooled set is independent and reaches the ceiling. Hence the
largest independent set of eigenvectors has exactly $\sum_i g_i$ vectors.
Full version: Corollary 11.1 above.

**Theorem 11.3 — key trick: the most independent eigenvectors you can gather
is $\sum g_i$, so needing $n$ of them forces $\sum g_i = n$; with $g_i \le
m_i$ and $\sum m_i = n$, every gap $m_i - g_i$ must be zero.**
Statement (1) $\iff$ (2) is just Theorem 11.2. For (2) $\iff$ (3): Corollary
11.1 says the most independent eigenvectors you can gather is exactly
$\sum g_i$, so "$A$ has $n$ independent eigenvectors" means exactly
$\sum g_i = n$. Since each $g_i \le
m_i$ (Lemma 11.1) and the $m_i$ sum to $n$, the nonnegative gaps $m_i - g_i$
sum to $n - \sum g_i$; that total is zero precisely when each $g_i = m_i$.
Full version: Theorem 11.3 above.

### If you remember only 3 things

1. $A = PDP^{-1}$: columns of $P$ are eigenvectors, the diagonal of $D$ their
   eigenvalues — and this exists iff $A$ has $n$ independent eigenvectors.
2. Diagonalizable $\iff$ geometric multiplicity $=$ algebraic multiplicity
   for every eigenvalue (and always $g \le m$).
3. Trap: distinct eigenvalues *guarantee* diagonalizability but are only a
   sufficient condition — test the multiplicity match, not distinctness.

## Journal template

```
## Day 11 — Diagonalization
Key theorem in my own words: ...
What confused me: ...
```
