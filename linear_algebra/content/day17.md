# Day 17 — Orthogonal Matrices, QR Decomposition

## Learning objectives

By the end of today you should be able to:
- State the definition of an orthogonal matrix and prove it is equivalent to
  having orthonormal columns.
- Prove that a matrix is orthogonal if and only if it preserves inner
  products (and hence lengths and angles).
- Prove that every matrix with linearly independent columns admits a QR
  decomposition, and explain exactly how $R$'s entries come from
  Gram-Schmidt.
- Compute a QR decomposition by hand for a small matrix via Gram-Schmidt.
- Solve a least-squares problem via $R\hat x = Q^Tb$ instead of the normal
  equations, and explain why this is numerically preferable.

## Reference material

- Primer (10 min, no video today): before reading anything, sketch by hand
  why multiplying a vector by an orthogonal matrix cannot change its length
  or the angle it makes with another vector. Draw two vectors $u, v \in
  \mathbb{R}^2$ at some angle, then draw a rotation of both by the same
  angle $\theta$ — convince yourself geometrically that lengths and the
  angle between them are unchanged. This is the intuition Theorem 17.1
  below makes precise and general (any orthogonal $Q$, not just rotations,
  in any dimension).
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §5.6
  (orthogonal matrices and QR decomposition) — [free
  PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  chapter on orthogonality, the problems on orthogonal matrices — if you
  don't have a copy, the exercises below are self-contained and sufficient
  for today.

Today builds directly on Day 15 (Gram-Schmidt, orthonormal sets) and Day 16
(orthogonal projection, least squares). If either feels shaky, a 5-minute
skim of those journal entries before starting is worth it — QR decomposition
is nothing more than Gram-Schmidt with its bookkeeping made explicit, and
today's least-squares exercise revisits Day 16's normal-equations problem
from a different, more numerically honest angle.

## Theory

### Definition 17.1 (Orthogonal matrix)

A square matrix $Q \in \mathbb{R}^{n\times n}$ is **orthogonal** if
$$Q^TQ = I.$$

**Equivalence with orthonormal columns.** Write $Q = [q_1 \mid q_2 \mid
\cdots \mid q_n]$ in terms of its columns. The $(i,j)$ entry of $Q^TQ$ is
$q_i^Tq_j = \langle q_i, q_j\rangle$ (the standard inner product on
$\mathbb{R}^n$, $\langle x,y\rangle = x^Ty$). So
$$Q^TQ = I \iff \langle q_i, q_j \rangle = \delta_{ij} \text{ for all } i,j,$$
where $\delta_{ij}$ is $1$ if $i=j$ and $0$ otherwise. The right-hand
condition says exactly that $\{q_1,\dots,q_n\}$ is an **orthonormal set**
(pairwise orthogonal, each of unit norm). So "orthogonal matrix" and "square
matrix with orthonormal columns" are the same thing, by definition of matrix
multiplication — no further proof needed, but it's worth seeing explicitly
since the exercises use both phrasings interchangeably.

### Theorem 17.1 (Orthogonal $\iff$ preserves inner products)

Let $Q \in \mathbb{R}^{n \times n}$. Then $Q$ is orthogonal (i.e. $Q^TQ=I$)
if and only if
$$\langle Qu, Qv \rangle = \langle u, v \rangle \quad \text{for all } u, v \in \mathbb{R}^n.$$

**Proof.**

($\Rightarrow$) Suppose $Q^TQ = I$. For any $u, v \in \mathbb{R}^n$,
$$\langle Qu, Qv \rangle = (Qu)^T(Qv) = u^TQ^TQv = u^T(Q^TQ)v = u^TIv = u^Tv = \langle u, v\rangle.$$
Since $u, v$ were arbitrary, this holds for all $u, v \in \mathbb{R}^n$.

($\Leftarrow$) Suppose $\langle Qu, Qv\rangle = \langle u,v\rangle$ for all
$u, v \in \mathbb{R}^n$. Expanding the left side as above,
$$u^TQ^TQv = u^Tv \quad \text{for all } u,v \in \mathbb{R}^n,$$
i.e. $u^T(Q^TQ - I)v = 0$ for all $u, v$. Let $M = Q^TQ - I$; we must show
$M = 0$. Test this identity on the standard basis vectors: for any $i, j \in
\{1,\dots,n\}$, take $u = e_i$ and $v = e_j$. Then $e_i^TMe_j = M_{ij}$ (the
$(i,j)$ entry of $M$), so the identity gives $M_{ij} = 0$. Since $i, j$ were
arbitrary, every entry of $M$ is $0$, i.e. $M = 0$, i.e. $Q^TQ = I$.

Both directions hold, so the two conditions are equivalent. $\blacksquare$

**Corollary (norm preservation).** Taking $u = v$ in Theorem 17.1,
$$\langle Qv, Qv \rangle = \langle v, v \rangle \implies \|Qv\|^2 = \|v\|^2 \implies \|Qv\| = \|v\|$$
for all $v \in \mathbb{R}^n$ (norms are non-negative, so the square roots
agree too). So orthogonal matrices preserve length. Combined with the full
theorem, they also preserve angles: since $\cos\theta =
\dfrac{\langle u,v\rangle}{\|u\|\|v\|}$, and both the numerator and both
norms in the denominator are unchanged by $Q$, the angle between $Qu$ and
$Qv$ equals the angle between $u$ and $v$. This is exactly the sketch from
today's primer, now proved for every orthogonal $Q$ in every dimension, not
just 2D rotations.

### Theorem 17.2 (Existence of the QR decomposition)

Let $A \in \mathbb{R}^{m \times n}$ ($m \ge n$) have linearly independent
columns $a_1, \dots, a_n$. Then there exist $Q \in \mathbb{R}^{m\times n}$
with orthonormal columns and an upper triangular $R \in \mathbb{R}^{n\times
n}$ with strictly positive diagonal entries such that
$$A = QR.$$

**Proof.** Apply the Gram-Schmidt process (Day 15) to $a_1, \dots, a_n$ to
produce an orthonormal set $q_1, \dots, q_n$. Recall the key property of
Gram-Schmidt proved on Day 15: at every stage $k = 1, \dots, n$,
$$\operatorname{span}\{q_1, \dots, q_k\} = \operatorname{span}\{a_1, \dots, a_k\}.$$

*Building $R$.* Fix $k$. Since $a_k \in \operatorname{span}\{a_1,\dots,a_k\}
= \operatorname{span}\{q_1,\dots,q_k\}$, there exist scalars $r_{1k},
r_{2k}, \dots, r_{kk}$ such that
$$a_k = \sum_{i=1}^{k} r_{ik}\, q_i. \tag{$\ast$}$$
Crucially, only $q_1, \dots, q_k$ appear on the right — not $q_{k+1}, \dots,
q_n$ — because the span at stage $k$ only reaches $a_1,\dots,a_k$. Define
the $n \times n$ matrix $R$ by these coefficients, setting $r_{ik} = 0$
whenever $i > k$. By construction $R$ is upper triangular. Let $Q = [q_1
\mid \cdots \mid q_n] \in \mathbb{R}^{m\times n}$.

*Checking $A = QR$.* The $k$-th column of $QR$ is $Q$ applied to the $k$-th
column of $R$, i.e. $\sum_{i=1}^n r_{ik} q_i = \sum_{i=1}^k r_{ik}q_i$ (the
terms with $i > k$ vanish since $r_{ik}=0$ there), which by $(\ast)$ equals
$a_k$, the $k$-th column of $A$. Since this holds for every $k = 1,\dots,n$,
the matrices $QR$ and $A$ agree in every column, so $A = QR$.

*$Q$ has orthonormal columns* by construction (Gram-Schmidt's output is
always orthonormal — that's Day 15's theorem).

*Diagonal entries of $R$ are positive.* Take the inner product of both
sides of $(\ast)$ with $q_k$, using orthonormality ($\langle q_i,
q_k\rangle = \delta_{ik}$):
$$\langle a_k, q_k \rangle = \sum_{i=1}^k r_{ik}\langle q_i, q_k\rangle = r_{kk}.$$
So $r_{kk} = \langle a_k, q_k\rangle$. Now recall exactly how Gram-Schmidt
builds $q_k$: it first forms
$$v_k = a_k - \sum_{i=1}^{k-1} \langle a_k, q_i\rangle q_i$$
(the component of $a_k$ orthogonal to $q_1,\dots,q_{k-1}$), then normalizes.
Normalizing $v_k$ to unit length has **two possible sign choices**, $q_k =
\pm v_k/\|v_k\|$; both give a unit vector orthogonal to $q_1,\dots,q_{k-1}$,
so both are valid outputs of "an orthonormal set with the right span at
every stage." The standard Gram-Schmidt convention picks the $+$ sign,
$q_k = v_k/\|v_k\|$. With this choice,
$$r_{kk} = \langle a_k, q_k\rangle = \left\langle v_k + \sum_{i<k}\langle a_k,q_i\rangle q_i,\ q_k\right\rangle = \langle v_k, q_k\rangle$$
(the sum drops out since $q_k \perp q_i$ for $i < k$) $= \left\langle v_k,
\dfrac{v_k}{\|v_k\|}\right\rangle = \dfrac{\|v_k\|^2}{\|v_k\|} = \|v_k\| >
0$, where $v_k \neq 0$ because $a_k \notin
\operatorname{span}\{a_1,\dots,a_{k-1}\} = \operatorname{span}\{q_1,\dots,q_{k-1}\}$
(the columns of $A$ are linearly independent). Had we instead picked the
$-$ sign at step $k$, we'd get $r_{kk} = -\|v_k\| < 0$ and $QR$ would still
equal $A$ (flip the sign of column $k$ of $Q$ and row $k$ of $R$
simultaneously — the product is unchanged) — so the positive-diagonal
convention is exactly what pins down a *unique* $Q, R$ pair, not an
incidental detail. Choosing the $+$ sign at every step $k=1,\dots,n$
therefore produces $R$ with all diagonal entries strictly positive.
$\blacksquare$

## Worked example

**Compute the QR decomposition of**
$$A = \begin{pmatrix} 1 & 0 \\ 1 & 1 \\ 0 & 1 \end{pmatrix}, \qquad a_1 = (1,1,0), \quad a_2 = (0,1,1).$$

This is the same pair of vectors Gram-Schmidt was run on in Day 15 — here we
package the result as $A = QR$.

**Step 1 ($k=1$).** $v_1 = a_1 = (1,1,0)$. $\|v_1\| = \sqrt{1^2+1^2+0^2} =
\sqrt2$. So
$$q_1 = \frac{v_1}{\|v_1\|} = \left(\tfrac{1}{\sqrt2}, \tfrac{1}{\sqrt2}, 0\right), \qquad r_{11} = \|v_1\| = \sqrt2.$$

**Step 2 ($k=2$).** First subtract off the component of $a_2$ along $q_1$:
$$r_{12} = \langle a_2, q_1\rangle = 0\cdot\tfrac{1}{\sqrt2} + 1\cdot\tfrac{1}{\sqrt2} + 1\cdot 0 = \tfrac{1}{\sqrt2}.$$
$$v_2 = a_2 - r_{12}\,q_1 = (0,1,1) - \tfrac{1}{\sqrt2}\left(\tfrac{1}{\sqrt2},\tfrac{1}{\sqrt2},0\right) = (0,1,1) - \left(\tfrac12,\tfrac12,0\right) = \left(-\tfrac12,\tfrac12,1\right).$$
$$\|v_2\| = \sqrt{\left(-\tfrac12\right)^2 + \left(\tfrac12\right)^2 + 1^2} = \sqrt{\tfrac14+\tfrac14+1} = \sqrt{\tfrac32} = \frac{\sqrt6}{2}.$$
$$q_2 = \frac{v_2}{\|v_2\|} = \left(-\tfrac1{\sqrt6}, \tfrac1{\sqrt6}, \tfrac2{\sqrt6}\right), \qquad r_{22} = \|v_2\| = \frac{\sqrt6}{2}.$$

**Assemble $Q$ and $R$.**
$$Q = \begin{pmatrix} \tfrac1{\sqrt2} & -\tfrac1{\sqrt6} \\[4pt] \tfrac1{\sqrt2} & \tfrac1{\sqrt6} \\[4pt] 0 & \tfrac2{\sqrt6} \end{pmatrix}, \qquad R = \begin{pmatrix} \sqrt2 & \tfrac1{\sqrt2} \\[4pt] 0 & \tfrac{\sqrt6}{2} \end{pmatrix}.$$

Note $r_{11}, r_{22} > 0$ as guaranteed by Theorem 17.2, and $R$ is upper
triangular.

**Verify $QR = A$.**

Column 1 of $QR$: $r_{11}q_1 = \sqrt2\left(\tfrac1{\sqrt2},\tfrac1{\sqrt2},0\right) = (1,1,0) = a_1$. ✓

Column 2 of $QR$: $r_{12}q_1 + r_{22}q_2 = \tfrac1{\sqrt2}\left(\tfrac1{\sqrt2},\tfrac1{\sqrt2},0\right) + \tfrac{\sqrt6}{2}\left(-\tfrac1{\sqrt6},\tfrac1{\sqrt6},\tfrac2{\sqrt6}\right)$
$= \left(\tfrac12,\tfrac12,0\right) + \left(-\tfrac12,\tfrac12,1\right) = (0,1,1) = a_2$. ✓

Both columns match, so $QR = A$, and one can also check directly that
$Q^TQ = I$ (its columns are unit vectors, and $\langle q_1,q_2\rangle =
-\tfrac1{2\sqrt3}+\tfrac1{2\sqrt3}+0 = 0$). This was confirmed numerically
with `numpy.linalg.qr` before this file was finalized.

## Unconventional edge

The trap: memorizing "QR decomposition" as one more named factorization to
look up, alongside LU and eigendecomposition, without noticing it *is*
Gram-Schmidt — nothing new is computed. Every $r_{ik}$ in $R$ is a
projection coefficient you already computed while orthogonalizing $a_k$
against $q_1,\dots,q_{k-1}$ (Day 15); $R$ is simply that bookkeeping written
down as a matrix instead of thrown away after use. If you ever forget the
formula for an entry of $R$, rederive it by asking "what coefficient did
Gram-Schmidt use here?" rather than hunting for a formula to memorize.
Separately: for least-squares, solving the normal equations $A^TA\hat x =
A^Tb$ looks like the natural approach, but computing $A^TA$ numerically
squares $A$'s condition number ($\kappa(A^TA) = \kappa(A)^2$), which
amplifies rounding error badly when $A$ is even mildly ill-conditioned. QR
avoids this entirely — solving $R\hat x = Q^Tb$ never forms $A^TA$, so the
numerical error stays proportional to $\kappa(A)$, not $\kappa(A)^2$. This
is why production numerical libraries (including `numpy.linalg.lstsq`)
default to QR- or SVD-based solvers rather than the normal equations.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1, 2, 3, 5, 8, 9 are computational; 4, 6, 7 are proof-based.

1. Compute the QR decomposition by hand (via Gram-Schmidt) of
   $A = \begin{pmatrix} 1 & 2 \\ 1 & 0\end{pmatrix}$. Verify $QR = A$.
2. Compute the QR decomposition by hand of
   $A = \begin{pmatrix} 1 & 0 \\ 0 & 1 \\ 1 & 1\end{pmatrix}$. Verify $QR=A$.
3. Verify that
   $Q = \dfrac13\begin{pmatrix} 2 & -2 & 1 \\ 1 & 2 & 2 \\ 2 & 1 & -2\end{pmatrix}$
   is orthogonal by computing $Q^TQ$ directly.
4. Prove both of the following:
   (a) If $Q_1, Q_2 \in \mathbb{R}^{n\times n}$ are both orthogonal, then
   $Q_1Q_2$ is orthogonal.
   (b) If $Q$ is orthogonal, then $Q$ is invertible and $Q^{-1} = Q^T$.
5. Let $A = \begin{pmatrix} 1&0\\1&1\\1&2\\1&3\end{pmatrix}$ and $b =
   (1,2,2,3)$ (the same regression setup as Day 16: fitting $y = c_0 + c_1x$
   to the four points $(0,1),(1,2),(2,2),(3,3)$). Compute the QR
   decomposition of $A$ by hand, then solve $R\hat x = Q^Tb$ by
   back-substitution. Separately solve the normal equations $A^TA\hat x =
   A^Tb$ directly. Confirm the two solutions agree.
6. Prove: if $Q$ is orthogonal, then $\det(Q) = \pm 1$. (Hint: start from
   $\det(Q^TQ) = \det(I)$, and use $\det(Q^T) = \det(Q)$ and the
   multiplicativity of $\det$.)
7. Using Theorem 17.1, explain in a few sentences why an orthogonal matrix
   cannot only preserve lengths of individual vectors but must also
   preserve the angle between any two vectors. (You already sketched the
   2D rotation case in today's primer — give the general argument here.)
8. True or False, with justification: if $Q \in \mathbb{R}^{m\times n}$
   with $m > n$ has orthonormal columns (so $Q^TQ = I_n$), then $QQ^T =
   I_m$ as well. (Use the $Q$ from Exercise 2 as a concrete test case if
   you're unsure.)
9. Let $Q_\theta = \begin{pmatrix}\cos\theta & -\sin\theta \\ \sin\theta &
   \cos\theta\end{pmatrix}$ be the standard 2D rotation matrix. Compute
   $Q_\theta^TQ_\theta$ symbolically and show it equals $I$ for every
   $\theta$, using the identity $\cos^2\theta + \sin^2\theta = 1$.

## Solutions

**1.** Columns $a_1 = (1,1)$, $a_2 = (2,0)$.

$v_1 = a_1 = (1,1)$, $\|v_1\| = \sqrt2$, so $q_1 = \left(\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right)$, $r_{11}=\sqrt2$.

$r_{12} = \langle a_2,q_1\rangle = 2\cdot\tfrac1{\sqrt2} + 0 = \sqrt2$.
$v_2 = a_2 - r_{12}q_1 = (2,0) - \sqrt2\left(\tfrac1{\sqrt2},\tfrac1{\sqrt2}\right) = (2,0)-(1,1) = (1,-1)$.
$\|v_2\| = \sqrt2$, so $q_2 = \left(\tfrac1{\sqrt2},-\tfrac1{\sqrt2}\right)$, $r_{22}=\sqrt2$.

$$Q = \begin{pmatrix}\tfrac1{\sqrt2} & \tfrac1{\sqrt2} \\ \tfrac1{\sqrt2} & -\tfrac1{\sqrt2}\end{pmatrix}, \quad R = \begin{pmatrix}\sqrt2 & \sqrt2 \\ 0 & \sqrt2\end{pmatrix}.$$

Check: column 1 of $QR$ is $\sqrt2\,q_1 = (1,1) = a_1$ ✓. Column 2 is
$\sqrt2\,q_1 + \sqrt2\,q_2 = (1,1)+(1,-1) = (2,0) = a_2$ ✓.

**2.** Columns $a_1=(1,0,1)$, $a_2=(0,1,1)$.

$v_1=a_1$, $\|v_1\|=\sqrt2$, $q_1 = \left(\tfrac1{\sqrt2},0,\tfrac1{\sqrt2}\right)$, $r_{11}=\sqrt2$.

$r_{12} = \langle a_2,q_1\rangle = 0+0+1\cdot\tfrac1{\sqrt2} = \tfrac1{\sqrt2}$.
$v_2 = (0,1,1) - \tfrac1{\sqrt2}\left(\tfrac1{\sqrt2},0,\tfrac1{\sqrt2}\right) = (0,1,1)-\left(\tfrac12,0,\tfrac12\right) = \left(-\tfrac12,1,\tfrac12\right)$.
$\|v_2\| = \sqrt{\tfrac14+1+\tfrac14} = \sqrt{\tfrac32} = \tfrac{\sqrt6}{2}$.
$q_2 = \left(-\tfrac1{\sqrt6},\tfrac2{\sqrt6},\tfrac1{\sqrt6}\right)$, $r_{22} = \tfrac{\sqrt6}{2}$.

$$Q = \begin{pmatrix}\tfrac1{\sqrt2} & -\tfrac1{\sqrt6} \\ 0 & \tfrac2{\sqrt6} \\ \tfrac1{\sqrt2} & \tfrac1{\sqrt6}\end{pmatrix}, \quad R = \begin{pmatrix}\sqrt2 & \tfrac1{\sqrt2} \\ 0 & \tfrac{\sqrt6}{2}\end{pmatrix}.$$

Check: column 1 of $QR$ is $\sqrt2\,q_1 = (1,0,1)=a_1$ ✓. Column 2 is
$\tfrac1{\sqrt2}q_1 + \tfrac{\sqrt6}2 q_2 = \left(\tfrac12,0,\tfrac12\right) + \left(-\tfrac12,1,\tfrac12\right) = (0,1,1)=a_2$ ✓.

**3.** Denote the rows of the un-scaled integer matrix as $u_1=(2,-2,1)$,
$u_2=(1,2,2)$, $u_3=(2,1,-2)$ — these are also the columns of $Q^T$ (up to
the $\tfrac13$ scaling), and computing $Q^TQ$ means dotting columns of $Q$,
which are $\tfrac13 u_1, \tfrac13 u_2, \tfrac13 u_3$ read off from the
matrix as given (its columns are $(2,1,2)/3,(-2,2,1)/3,(1,2,-2)/3$).
Concretely, column $j$ dotted with column $k$:
$$\langle \text{col}_1,\text{col}_1\rangle = \tfrac19(2^2+1^2+2^2) = \tfrac99 = 1,$$
$$\langle \text{col}_2,\text{col}_2\rangle = \tfrac19((-2)^2+2^2+1^2)=\tfrac99=1, \qquad \langle \text{col}_3,\text{col}_3\rangle = \tfrac19(1^2+2^2+(-2)^2)=\tfrac99=1,$$
$$\langle \text{col}_1,\text{col}_2\rangle = \tfrac19(2\cdot(-2)+1\cdot2+2\cdot1) = \tfrac19(-4+2+2)=0,$$
$$\langle \text{col}_1,\text{col}_3\rangle = \tfrac19(2\cdot1+1\cdot2+2\cdot(-2)) = \tfrac19(2+2-4)=0,$$
$$\langle \text{col}_2,\text{col}_3\rangle = \tfrac19((-2)\cdot1+2\cdot2+1\cdot(-2)) = \tfrac19(-2+4-2)=0.$$
So $Q^TQ = I_3$: $Q$ is orthogonal. (Confirmed numerically with NumPy.)

**4.** (a) Since $Q_1, Q_2$ are orthogonal, $Q_1^TQ_1 = I$ and $Q_2^TQ_2 =
I$. Then
$$(Q_1Q_2)^T(Q_1Q_2) = Q_2^TQ_1^TQ_1Q_2 = Q_2^T(Q_1^TQ_1)Q_2 = Q_2^TIQ_2 = Q_2^TQ_2 = I,$$
so $Q_1Q_2$ is orthogonal.

(b) $Q^TQ = I$ means, by definition of matrix inverse, that $Q^T$ is a
left inverse of $Q$. For square matrices, a one-sided inverse is a
two-sided inverse (a standard fact: if $BA=I$ for square $A,B$ then also
$AB=I$, since $BA=I$ forces $A$ injective hence invertible, and then $B =
BAA^{-1}=A^{-1}$). So $Q^TQ=I$ implies $Q$ is invertible with $Q^{-1}=Q^T$.

**5.** Columns of $A$: $a_1=(1,1,1,1)$, $a_2=(0,1,2,3)$.

$v_1=a_1$, $\|v_1\|=2$, $q_1 = \left(\tfrac12,\tfrac12,\tfrac12,\tfrac12\right)$, $r_{11}=2$.

$r_{12}=\langle a_2,q_1\rangle = \tfrac12(0+1+2+3)=3$.
$v_2 = (0,1,2,3) - 3\left(\tfrac12,\tfrac12,\tfrac12,\tfrac12\right) = (0,1,2,3)-\left(\tfrac32,\tfrac32,\tfrac32,\tfrac32\right) = \left(-\tfrac32,-\tfrac12,\tfrac12,\tfrac32\right)$.
$\|v_2\| = \sqrt{\tfrac94+\tfrac14+\tfrac14+\tfrac94} = \sqrt5$, so
$q_2 = \tfrac1{\sqrt5}\left(-\tfrac32,-\tfrac12,\tfrac12,\tfrac32\right)$, $r_{22}=\sqrt5$.

$$R = \begin{pmatrix}2 & 3 \\ 0 & \sqrt5\end{pmatrix}.$$

$Q^Tb$ with $b=(1,2,2,3)$:
$$\langle b,q_1\rangle = \tfrac12(1+2+2+3)=4, \qquad \langle b,q_2\rangle = \tfrac1{\sqrt5}\left(-\tfrac32\cdot1 -\tfrac12\cdot2+\tfrac12\cdot2+\tfrac32\cdot3\right) = \tfrac1{\sqrt5}(-1.5-1+1+4.5)=\tfrac3{\sqrt5}.$$

Back-substitution on $R\hat x = Q^Tb = \left(4, \tfrac3{\sqrt5}\right)$:
row 2: $\sqrt5\, c_1 = \tfrac3{\sqrt5} \implies c_1 = \tfrac35 = 0.6$.
row 1: $2c_0 + 3c_1 = 4 \implies 2c_0 = 4 - 1.8 = 2.2 \implies c_0 = 1.1$.

Normal equations: $A^TA = \begin{pmatrix}4&6\\6&14\end{pmatrix}$, $A^Tb =
(8,15)$. Solving $4c_0+6c_1=8$, $6c_0+14c_1=15$ gives (eliminating $c_0$:
multiply the first equation by $1.5$ to get $6c_0+9c_1=12$, subtract from
the second: $5c_1=3 \implies c_1=0.6$; then $c_0 = (8-6(0.6))/4 = 4.4/4 =
1.1$). Both methods give $\hat x = (c_0,c_1) = (1.1, 0.6)$ — confirmed
numerically with NumPy.

**6.** Since $Q$ is orthogonal, $Q^TQ=I$, so $\det(Q^TQ) = \det(I) = 1$. By
multiplicativity of determinant, $\det(Q^TQ) = \det(Q^T)\det(Q)$, and since
$\det(Q^T)=\det(Q)$ for any square matrix, this is $\det(Q)^2$. So
$\det(Q)^2 = 1$, giving $\det(Q) = \pm1$.

**7.** By Theorem 17.1, $\langle Qu,Qv\rangle = \langle u,v\rangle$ for all
$u,v$, and by the Corollary, $\|Qu\|=\|u\|$, $\|Qv\|=\|v\|$. The angle
$\theta$ between two nonzero vectors $x,y$ is defined by $\cos\theta =
\dfrac{\langle x,y\rangle}{\|x\|\|y\|}$. Substituting $x=Qu,y=Qv$:
$$\cos(\text{angle between } Qu,Qv) = \frac{\langle Qu,Qv\rangle}{\|Qu\|\|Qv\|} = \frac{\langle u,v\rangle}{\|u\|\|v\|} = \cos(\text{angle between }u,v).$$
Since both angles lie in $[0,\pi]$ where cosine is injective, the angles
themselves are equal. So $Q$ preserves not just individual lengths but the
angle between every pair of vectors — lengths are just the special case
$u=v$ (angle $0$).

**8.** False in general. Using $Q$ from Exercise 2:
$$QQ^T = \begin{pmatrix}\tfrac1{\sqrt2} & -\tfrac1{\sqrt6} \\ 0 & \tfrac2{\sqrt6} \\ \tfrac1{\sqrt2} & \tfrac1{\sqrt6}\end{pmatrix}\begin{pmatrix}\tfrac1{\sqrt2} & 0 & \tfrac1{\sqrt2} \\ -\tfrac1{\sqrt6} & \tfrac2{\sqrt6} & \tfrac1{\sqrt6}\end{pmatrix}$$
has $(1,1)$ entry $\tfrac12+\tfrac16 = \tfrac23 \ne 1$, so $QQ^T \ne I_3$.
The reason: $Q^TQ=I_n$ says the $n$ columns of $Q$ (living in
$\mathbb{R}^m$) are orthonormal, which pins down an $n\times n$ product;
but $QQ^T$ is $m\times m$, and when $m>n$ the columns of $Q$ span only an
$n$-dimensional subspace of $\mathbb{R}^m$, not all of it, so $QQ^T$ is
actually the (rank-$n$) orthogonal projection onto that subspace, not the
identity. Only when $m=n$ (so $Q$ is square) does $Q^TQ=I$ force $QQ^T=I$
too (that's Exercise 4(b): $Q^{-1}=Q^T$ on both sides).

**9.**
$$Q_\theta^TQ_\theta = \begin{pmatrix}\cos\theta & \sin\theta \\ -\sin\theta & \cos\theta\end{pmatrix}\begin{pmatrix}\cos\theta & -\sin\theta \\ \sin\theta & \cos\theta\end{pmatrix} = \begin{pmatrix}\cos^2\theta+\sin^2\theta & -\cos\theta\sin\theta+\sin\theta\cos\theta \\ -\sin\theta\cos\theta+\cos\theta\sin\theta & \sin^2\theta+\cos^2\theta\end{pmatrix}.$$
The off-diagonal entries are $0$ (they cancel term-by-term), and both
diagonal entries equal $\cos^2\theta+\sin^2\theta = 1$ by the Pythagorean
identity. So $Q_\theta^TQ_\theta = I$ for every $\theta$ — every 2D
rotation matrix is orthogonal, matching today's primer sketch.

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements least-squares via QR instead of the normal
equations. Open `starter_code/day17_qr_decomposition.py` — it has one
function to complete, `solve_least_squares_via_qr`. Fill in the `TODO`,
then run the file directly
(`python starter_code/day17_qr_decomposition.py`); it should print
confirmation that $Q$ is orthogonal, $QR=A$, and that your QR-based
solution matches the normal-equations solution.

**Hint:** get `Q, R = np.linalg.qr(A)`, then solve the triangular system
$R\hat x = Q^Tb$ with `np.linalg.solve(R, Q.T @ y)` (or write your own
back-substitution loop over `R`'s rows from bottom to top, mirroring
Exercise 5's by-hand computation).

If you get stuck for more than ~10 minutes, check
`solutions/day17_qr_decomposition.py` — but only after a real attempt.

Once your implementation passes, extend it: use `np.linalg.cond` to compare
$\kappa(A)$ against $\kappa(A^TA)$ for the `A` in the starter file, and then
again for a deliberately near-degenerate matrix of your own construction
(e.g. two nearly-parallel columns). Confirm numerically that
$\kappa(A^TA) \approx \kappa(A)^2$, which is the concrete evidence behind
today's "Unconventional edge" claim that normal equations amplify
ill-conditioning while QR does not.

## Journal template

```
## Day 17 — Orthogonal matrices, QR decomposition
Key theorem in my own words: ...
What confused me: ...
```
