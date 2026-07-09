# Day 27 — Cumulative Marathon (Days 1–26)

## Purpose

One full closed-book timed exam spanning the entire month so far. This is
the highest-value single day for finding out what actually stuck versus
what only felt understood while the book was open.

## Instructions

1. Compile your weak-spot list (15 min): skim every journal entry from Days
   1–26 and list recurring "what confused me" items.
2. Full closed-book timed exam (180 min): all 16 problems below, one
   sitting, no notes, no code. Take a 10-minute break at the midpoint if
   needed, but stay closed-book throughout.
3. Break (15 min).
4. Score, correct, and triage (60 min): grade against the Solutions section;
   rewrite every missed solution by hand; sort misses into "needs a full
   re-read" vs. "needs more practice problems only."
5. Journal entry, using the template below.

## Problem set

1. (Day 1) Is $(2,5,3)$ in $\operatorname{span}\{(1,2,0),(0,1,1)\}$?
2. (Day 2) Are $(1,2,3), (2,4,7), (1,2,4)$ linearly independent?
3. (Day 4) Prove: a linear map $T:\mathbb{R}^5 \to \mathbb{R}^3$ cannot be
   injective.
4. (Day 5–6) For $M = \begin{pmatrix}1&2&3\\2&4&7\\1&2&4\end{pmatrix}$, find
   $\operatorname{rank}(M)$ and one nonzero vector in its null space.
5. (Day 8) Compute $\det\begin{pmatrix}2&1&0\\1&3&1\\0&1&2\end{pmatrix}$.
6. (Day 9) Prove: if $\det(A) = 0$, then $Ax=0$ has a nonzero solution.
7. (Day 10) Find the eigenvalues of $E = \begin{pmatrix}5&4\\1&2\end{pmatrix}$.
8. (Day 11) Is $F = \begin{pmatrix}3&1\\0&3\end{pmatrix}$ diagonalizable?
9. (Day 12) Using $E$ from problem 7, compute $E^3$ via diagonalization.
10. (Day 14) Verify Cauchy-Schwarz for $u=(1,2), v=(2,1)$.
11. (Day 15) Run one step of Gram-Schmidt: given $v_1=(1,0,1)$,
    $v_2=(1,1,0)$, find $u_2$ (the orthogonal-but-not-yet-normalized second
    vector).
12. (Day 16) Fit a least-squares line to $(0,1),(1,2),(2,4),(3,5)$.
13. (Day 17) Prove: the product of two orthogonal matrices is orthogonal.
14. (Day 19) Find the spectral decomposition's eigenvalues for
    $S=\begin{pmatrix}4&1\\1&4\end{pmatrix}$.
15. (Day 20) Classify $\begin{pmatrix}1&2\\2&1\end{pmatrix}$
    (positive/negative definite, semidefinite, or indefinite).
16. (Day 21–23) For a covariance matrix with eigenvalues $9$ and $1$, what
    fraction of variance does the first principal component explain?

## Solutions

**1.** Solve $a(1,2,0)+b(0,1,1)=(a,2a+b,b)=(2,5,3)$: from coords 1 and 3,
$a=2, b=3$; check coord 2: $2a+b=7 \ne 5$ — contradiction. **Not in the
span.**

**2.** Stack as columns and check rank: the matrix has rank $2 < 3$, so
**dependent**. (Concretely: $(1,2,4) = -1\cdot(1,2,3)+1\cdot(2,4,7)$ — check:
$-(1,2,3)+(2,4,7)=(1,2,4)$. ✓.)

**3.** By rank-nullity, $\dim\ker T + \dim\operatorname{im}T = 5$. Since
$\operatorname{im}T \subseteq \mathbb{R}^3$, $\dim\operatorname{im}T\le3$,
so $\dim\ker T \ge 2 > 0$, meaning $\ker T \ne \{0\}$, so $T$ is not
injective.

**4.** $\operatorname{rank}(M)=2$ (its rows/columns satisfy one dependency:
row 2 minus row 1 doesn't simplify cleanly, but row reduction shows only 2
pivots). A null space vector is proportional to $(-2,1,0)$ — check:
$M(-2,1,0)^T = (-2+2, -4+4, -2+2)=(0,0,0)$. ✓

**5.** Cofactor expansion along row 1: $2(3\cdot2-1\cdot1) -
1(1\cdot2-1\cdot0) + 0 = 2(5)-1(2) = 10-2=8$.

**6.** If $\det(A)=0$, $A$ is not invertible (Day 8's theorem). If $Ax=0$
had only the solution $x=0$, $A$ would be injective as a map
$\mathbb{R}^n\to\mathbb{R}^n$, hence invertible (Day 4's theorem) —
contradiction. So $Ax=0$ must have a nonzero solution.

**7.** $\det(E-\lambda I)=(5-\lambda)(2-\lambda)-4=\lambda^2-7\lambda+6=0
\Rightarrow \lambda=6,1$.

**8.** Eigenvalue $3$ has algebraic multiplicity $2$ (repeated root).
Geometric multiplicity: $\ker(F-3I)=\ker\begin{pmatrix}0&1\\0&0\end{pmatrix}$
is 1-dimensional (spanned by $(1,0)$). Since $1 < 2$, **not
diagonalizable**.

**9.** Eigenvalues $6,1$ with eigenvectors solving $(E-6I)v=0$ and
$(E-1I)v=0$ respectively: $v_1=(4,1)$, $v_2=(1,-1)$ (up to scale). Then
$E^3 = PD^3P^{-1}$ with $D^3=\operatorname{diag}(216,1)$, giving
$E^3=\begin{pmatrix}173&172\\43&44\end{pmatrix}$.

**10.** $|\langle u,v\rangle| = |2+2| = 4$. $\|u\|\|v\| = \sqrt5\cdot\sqrt5=5$.
$4 \le 5$ ✓.

**11.** $u_2 = v_2 - \frac{\langle v_2,u_1\rangle}{\langle u_1,u_1\rangle}u_1
= (1,1,0) - \frac{1}{2}(1,0,1) = (0.5, 1, -0.5)$. Check orthogonality:
$\langle u_1,u_2\rangle = 0.5+0-0.5=0$ ✓.

**12.** Normal equations with $A=\begin{pmatrix}0&1\\1&1\\2&1\\3&1\end{pmatrix}$,
$y=(1,2,4,5)$: solving gives slope $m=1.4$, intercept $b=0.9$.

**13.** If $Q_1^TQ_1=I$ and $Q_2^TQ_2=I$, then
$(Q_1Q_2)^T(Q_1Q_2) = Q_2^TQ_1^TQ_1Q_2 = Q_2^TIQ_2 = Q_2^TQ_2 = I$, so
$Q_1Q_2$ is orthogonal.

**14.** $\det(S-\lambda I)=(4-\lambda)^2-1=0 \Rightarrow \lambda=3,5$.

**15.** Eigenvalues: $(1-\lambda)^2-4=0 \Rightarrow \lambda=3,-1$. One
positive, one negative — **indefinite**.

**16.** $\frac{9}{9+1} = 0.9$, i.e. 90%.

## Journal template

```
## Day 27 — Cumulative marathon
Score: __/__
Topics needing a full re-read before Day 28: ...
Topics needing more practice only: ...
```
