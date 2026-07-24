# Day 13 — Review (Days 8–12)

## Purpose

Today introduces no new theory. It is closed-book retrieval practice on
everything from Days 8–12: determinants and their properties, invertibility
via Gauss-Jordan and LU decomposition, eigenvalues and eigenvectors,
diagonalization and the algebraic/geometric multiplicity criterion, and
diagonalization's payoff for matrix powers and difference equations. As with
Day 7, this review sits mid-stream rather than at the end, because spaced
retrieval is what keeps Week 2's material from quietly evaporating by Week 4
— the work below is the deliberate, uncomfortable act of pulling it back out
of memory *now*, while gaps are still cheap to close.

## Instructions

Follow these steps in order, closed-book except where noted.

1. **Journal pass (~30 min).** Reread all five of your Day 8–12 journal
   entries. For every item you listed under "what confused me," re-derive it
   from scratch, closed-book, before moving on to the next one. If you can't
   re-derive something, that's exactly the kind of gap this review day exists
   to surface — note it, but keep going; you'll revisit it in the concept-gaps
   tally at the end.
2. **Full timed attempt (~150 min).** Attempt every problem in the Mixed
   review problem set below, closed-book, no notes, no solutions section, in
   one sitting timed at roughly 150 minutes total (about 8–9 minutes per
   problem on average — some will be faster, some slower). Do not look at the
   Solutions section until you've either finished or the timer runs out.
3. **Break (~15 min).**
4. **Score and correct (~45 min).** Grade your attempt against the Solutions
   section below, problem by problem. For every problem you missed or got
   only partly right, rewrite the correct solution by hand from scratch — not
   just read it — and classify the miss as either a **concept gap** (you
   didn't know or misremembered the underlying theorem/definition) or an
   **arithmetic-only slip** (you knew exactly what to do but made a
   computational error executing it). This distinction is the point of the
   exercise: concept gaps need re-study, arithmetic slips just need more
   careful hand-checking next time.
5. **Journal entry (~15 min).** Fill in the Day 13 journal template at the
   bottom of this file and append it to your `journal.md`.

## Mixed review problem set

Problems are deliberately interleaved across topics (not grouped by day) —
mixing topics during retrieval practice is itself part of what makes it
effective. Each problem is labeled with the day/topic it targets so you can
tally your score by topic afterward.

1. **(Day 10: eigenvalues)** Find the eigenvalues and eigenvectors of
   $A = \begin{pmatrix} 5 & 4 \\ 1 & 2 \end{pmatrix}$.
2. **(Day 8: determinants)** Compute
   $\det\begin{pmatrix}2&3&1\\0&1&4\\5&2&0\end{pmatrix}$ via cofactor
   expansion along row 2 (it has a zero entry — use it).
3. **(Day 12: diagonalization applications)** Using diagonalization, compute
   $A^4$ by hand for $A = \begin{pmatrix} 3 & 2 \\ 1 & 2 \end{pmatrix}$.
4. **(Day 9: invertibility/inverse)** Compute $A^{-1}$ for
   $A = \begin{pmatrix} 3 & 2 \\ 5 & 4 \end{pmatrix}$ via Gauss-Jordan
   elimination on $[A \mid I]$, showing every step.
5. **(Day 11: diagonalization)** Diagonalize
   $A = \begin{pmatrix} 2 & 3 \\ 3 & 2 \end{pmatrix}$: find $P, D$ and verify
   $A = PDP^{-1}$.
6. **(Day 8: determinants)** Compute the determinant of
   $\begin{pmatrix}1&2&0&1\\2&5&1&3\\0&1&3&2\\1&3&2&4\end{pmatrix}$ using row
   reduction to upper triangular form (tracking any scalar factors) rather
   than raw cofactor expansion.
7. **(Day 10: eigenvalues)** Find the eigenvalues and eigenvectors of
   $A = \begin{pmatrix} 1 & -2 \\ 1 & -1 \end{pmatrix}$. (Don't be alarmed if
   they're complex.)
8. **(Day 9: invertibility/inverse)** Compute $B^{-1}$ for
   $B = \begin{pmatrix}2&1&0\\1&1&1\\0&1&3\end{pmatrix}$ via Gauss-Jordan
   elimination, showing every step.
9. **(Day 12: diagonalization applications)** Solve the recurrence
   $a_{n+1} = 4a_n - 3a_{n-1}$, $a_0 = 2$, $a_1 = 5$, using diagonalization;
   find a closed-form expression for $a_n$ and verify it against $a_0, a_1$.
10. **(Day 11: diagonalization)** Let
    $A = \begin{pmatrix}2&1&0\\0&2&0\\0&0&3\end{pmatrix}$. Find the algebraic
    and geometric multiplicity of every eigenvalue. Is $A$ diagonalizable?
11. **(Day 8: determinants)** Find all real values of $k$ for which
    $\begin{pmatrix}1&k&0\\k&1&k\\0&k&1\end{pmatrix}$ is singular.
12. **(Day 10: eigenvalues)** Prove: if $\lambda$ is an eigenvalue of $A$
    with eigenvector $v$, then for any scalar $c$, $\lambda - c$ is an
    eigenvalue of $A - cI$, with the same eigenvector $v$.
13. **(Day 9: LU decomposition)** Find the $LU$ decomposition (no row swaps
    needed) of $\begin{pmatrix}1&2&1\\3&8&7\\2&7&9\end{pmatrix}$ by hand.
    Identify the multipliers that populate $L$, and verify $LU = A$.
14. **(Day 12: diagonalization applications)** Let $A$ be a diagonalizable
    $2\times2$ matrix with eigenvalues $\lambda_1 = 1$ and $\lambda_2 = c$
    where $|c| < 1$, with corresponding eigenvectors $v_1, v_2$. Suppose
    $x_0 = av_1 + bv_2$ with $a \neq 0$. Prove that
    $x_n := A^n x_0 \to av_1$ as $n \to \infty$, regardless of $b$.
15. **(Day 11: diagonalization)** Prove: if $A$ is diagonalizable and
    invertible, then $A^{-1}$ is diagonalizable; specifically, if
    $A = PDP^{-1}$, then $A^{-1} = PD^{-1}P^{-1}$.
16. **(Day 8: determinants)** Suppose $A$ is $n \times n$ and $A^3 = A$.
    Prove $\det(A) \in \{-1, 0, 1\}$.
17. **(Day 9: invertibility)** Prove: if $A$ is invertible and $AB = AC$ for
    matrices $B, C$ of the same size as $A$, then $B = C$ (the left
    cancellation law).

## Solutions

**1.** $p_A(\lambda) = (5-\lambda)(2-\lambda) - 4 = \lambda^2 - 7\lambda + 6
= (\lambda-6)(\lambda-1)$. Eigenvalues $\lambda = 6, 1$.
For $\lambda=6$: $A - 6I = \begin{pmatrix}-1&4\\1&-4\end{pmatrix}$; row 1
gives $-v_1+4v_2=0 \implies v_1=4v_2$; eigenvector $(4,1)$.
For $\lambda=1$: $A - I = \begin{pmatrix}4&4\\1&1\end{pmatrix}$; row 1 gives
$4v_1+4v_2=0 \implies v_1=-v_2$; eigenvector $(1,-1)$.
Check: $A(4,1) = (20+4,\ 4+2) = (24,6) = 6(4,1)$ ✓;
$A(1,-1) = (5-4,\ 1-2) = (1,-1) = 1\cdot(1,-1)$ ✓.

**2.** Row 2 is $(0,1,4)$.
$C_{21} = (-1)^{2+1}\det\begin{pmatrix}3&1\\2&0\end{pmatrix} =
-(0-2) = 2$, times $a_{21}=0$ contributes $0$.
$C_{22} = (-1)^{2+2}\det\begin{pmatrix}2&1\\5&0\end{pmatrix} = (0-5) = -5$,
times $a_{22}=1$ contributes $-5$.
$C_{23} = (-1)^{2+3}\det\begin{pmatrix}2&3\\5&2\end{pmatrix} =
-(4-15) = 11$, times $a_{23}=4$ contributes $44$.
$$\det = 0 + (-5) + 44 = 39.$$

**3.** $p_A(\lambda) = (3-\lambda)(2-\lambda)-2 = \lambda^2-5\lambda+4 =
(\lambda-4)(\lambda-1)$. Eigenvalues $4, 1$.
For $\lambda=4$: $A-4I=\begin{pmatrix}-1&2\\1&-2\end{pmatrix}$, row 1:
$-v_1+2v_2=0 \implies v_1=2v_2$; eigenvector $(2,1)$.
For $\lambda=1$: $A-I=\begin{pmatrix}2&2\\1&1\end{pmatrix}$, row 1:
$2v_1+2v_2=0 \implies v_1=-v_2$; eigenvector $(1,-1)$.
$$P=\begin{pmatrix}2&1\\1&-1\end{pmatrix}, \quad D=\begin{pmatrix}4&0\\0&1\end{pmatrix}.$$
$\det P = -2-1=-3$, so $P^{-1} = \tfrac{1}{-3}\begin{pmatrix}-1&-1\\-1&2\end{pmatrix}
= \begin{pmatrix}1/3&1/3\\1/3&-2/3\end{pmatrix}$.
$D^4 = \begin{pmatrix}256&0\\0&1\end{pmatrix}$, so
$PD^4 = \begin{pmatrix}512&1\\256&-1\end{pmatrix}$, and
$$A^4 = PD^4P^{-1} = \begin{pmatrix}512&1\\256&-1\end{pmatrix}\begin{pmatrix}1/3&1/3\\1/3&-2/3\end{pmatrix}
= \begin{pmatrix}171&170\\85&86\end{pmatrix}$$
(top-left: $512/3+1/3=513/3=171$; top-right: $512/3-2/3=510/3=170$;
bottom-left: $256/3-1/3=255/3=85$; bottom-right: $256/3+2/3=258/3=86$).
Verified numerically against `numpy.linalg.matrix_power(A,4)`.

**4.** $\left[\begin{array}{cc|cc}3&2&1&0\\5&4&0&1\end{array}\right]$.
$R_1 \to \tfrac13R_1$: $[1,\tfrac23\mid\tfrac13,0]$.
$R_2 \to R_2-5R_1$: $[0,\ 4-\tfrac{10}{3}\mid-\tfrac53,1] = [0,\tfrac23\mid-\tfrac53,1]$.
$$\left[\begin{array}{cc|cc}1&\tfrac23&\tfrac13&0\\0&\tfrac23&-\tfrac53&1\end{array}\right]$$
$R_2 \to \tfrac32R_2$: $[0,1\mid-\tfrac52,\tfrac32]$.
$R_1 \to R_1-\tfrac23R_2$: $[1,0\mid\tfrac13+\tfrac53,\ 0-1] = [1,0\mid2,-1]$.
$$A^{-1} = \begin{pmatrix}2&-1\\-\tfrac52&\tfrac32\end{pmatrix}.$$
Check: $AA^{-1} = \begin{pmatrix}3&2\\5&4\end{pmatrix}\begin{pmatrix}2&-1\\-2.5&1.5\end{pmatrix}
= \begin{pmatrix}6-5&-3+3\\10-10&-5+6\end{pmatrix} = \begin{pmatrix}1&0\\0&1\end{pmatrix}$ ✓
(verified numerically against `numpy.linalg.inv`).

**5.** $p_A(\lambda) = (2-\lambda)^2-9 = \lambda^2-4\lambda-5 =
(\lambda-5)(\lambda+1)$. Eigenvalues $5, -1$.
For $\lambda=5$: $A-5I=\begin{pmatrix}-3&3\\3&-3\end{pmatrix}$, row 1:
$-3v_1+3v_2=0\implies v_1=v_2$; eigenvector $(1,1)$.
For $\lambda=-1$: $A+I=\begin{pmatrix}3&3\\3&3\end{pmatrix}$, row 1:
$3v_1+3v_2=0\implies v_1=-v_2$; eigenvector $(1,-1)$.
$$P=\begin{pmatrix}1&1\\1&-1\end{pmatrix}, \quad D=\begin{pmatrix}5&0\\0&-1\end{pmatrix}.$$
$\det P=-2$, $P^{-1}=\begin{pmatrix}1/2&1/2\\1/2&-1/2\end{pmatrix}$.
$PD=\begin{pmatrix}5&-1\\5&1\end{pmatrix}$;
$$PDP^{-1} = \begin{pmatrix}5&-1\\5&1\end{pmatrix}\begin{pmatrix}1/2&1/2\\1/2&-1/2\end{pmatrix}
= \begin{pmatrix}2&3\\3&2\end{pmatrix} = A. \checkmark$$
(verified numerically).

**6.**
$$\begin{pmatrix}1&2&0&1\\2&5&1&3\\0&1&3&2\\1&3&2&4\end{pmatrix}
\xrightarrow[R_4\to R_4-R_1]{R_2\to R_2-2R_1}
\begin{pmatrix}1&2&0&1\\0&1&1&1\\0&1&3&2\\0&1&2&3\end{pmatrix}
\xrightarrow[R_4\to R_4-R_2]{R_3\to R_3-R_2}
\begin{pmatrix}1&2&0&1\\0&1&1&1\\0&0&2&1\\0&0&1&2\end{pmatrix}
\xrightarrow{R_4\to R_4-\frac12R_3}
\begin{pmatrix}1&2&0&1\\0&1&1&1\\0&0&2&1\\0&0&0&\frac32\end{pmatrix}.$$
Every operation used is type (iii) (add a multiple of one row to another),
which leaves $\det$ unchanged (Lemma 8.2(iii)). By Lemma 8.5, $\det$ of the
final triangular matrix is $1\cdot1\cdot2\cdot\tfrac32 = 3$. So the original
determinant is $3$ (verified numerically).

**7.** $p_A(\lambda) = (1-\lambda)(-1-\lambda) - (-2)(1) = (\lambda^2-1) + 2
= \lambda^2+1$. Roots $\lambda = \pm i$.
For $\lambda=i$: $A-iI = \begin{pmatrix}1-i&-2\\1&-1-i\end{pmatrix}$. Row 2
gives $v_1-(1+i)v_2=0 \implies v_1=(1+i)v_2$; taking $v_2=1$, eigenvector
$(1+i,\,1)$. (Check row 1: $(1-i)(1+i)-2(1) = (1-i^2)-2 = 2-2=0$ ✓.)
For $\lambda=-i$: by the complex-conjugate symmetry of a real matrix's
characteristic polynomial, eigenvector $(1-i,\,1)$.
(Verified numerically: `numpy.linalg.eig` gives eigenvalues $\pm i$ and an
eigenvector ratio matching $1+i$.)

**8.** $\left[\begin{array}{ccc|ccc}2&1&0&1&0&0\\1&1&1&0&1&0\\0&1&3&0&0&1\end{array}\right]$.
$R_1\to\tfrac12R_1$: $[1,\tfrac12,0\mid\tfrac12,0,0]$.
$R_2\to R_2-R_1$: $[0,\tfrac12,1\mid-\tfrac12,1,0]$.
$$\left[\begin{array}{ccc|ccc}1&\tfrac12&0&\tfrac12&0&0\\0&\tfrac12&1&-\tfrac12&1&0\\0&1&3&0&0&1\end{array}\right]$$
$R_2\to2R_2$: $[0,1,2\mid-1,2,0]$.
$R_1\to R_1-\tfrac12R_2$: $[1,0,-1\mid1,-1,0]$.
$R_3\to R_3-R_2$: $[0,0,1\mid1,-2,1]$.
$$\left[\begin{array}{ccc|ccc}1&0&-1&1&-1&0\\0&1&2&-1&2&0\\0&0&1&1&-2&1\end{array}\right]$$
$R_1\to R_1+R_3$: $[1,0,0\mid2,-3,1]$.
$R_2\to R_2-2R_3$: $[0,1,0\mid-3,6,-2]$.
$$B^{-1} = \begin{pmatrix}2&-3&1\\-3&6&-2\\1&-2&1\end{pmatrix}.$$
Check row 1 of $B$ against $B^{-1}$: $[2,1,0]\cdot(2,-3,1)^T=4-3+0=1$;
$[2,1,0]\cdot(-3,6,-2)^T=-6+6+0=0$; $[2,1,0]\cdot(1,-2,1)^T=2-2+0=0$ — row 1
of $BB^{-1}$ is $(1,0,0)$ ✓ (verified fully against `numpy.linalg.inv`).

**9.** Matrix form: $x_n = \begin{pmatrix}a_{n+1}\\a_n\end{pmatrix} = Ax_{n-1}$
with $A=\begin{pmatrix}4&-3\\1&0\end{pmatrix}$. Characteristic polynomial:
$(4-\lambda)(-\lambda)-(-3)(1) = \lambda^2-4\lambda+3=(\lambda-3)(\lambda-1)$;
eigenvalues $3, 1$.
For $\lambda=3$: $A-3I=\begin{pmatrix}1&-3\\1&-3\end{pmatrix}$, row 1:
$v_1-3v_2=0\implies v_1=3v_2$; eigenvector $(3,1)$.
For $\lambda=1$: $A-I=\begin{pmatrix}3&-3\\1&-1\end{pmatrix}$, row 1:
$v_1-v_2=0\implies v_1=v_2$; eigenvector $(1,1)$.
The general solution to the recurrence is $a_n = c_1 3^n + c_2 1^n$. Using
$a_0=2$: $c_1+c_2=2$; using $a_1=5$: $3c_1+c_2=5$. Subtracting:
$2c_1=3 \implies c_1=\tfrac32$, so $c_2=\tfrac12$.
$$a_n = \frac32\cdot3^n + \frac12 = \frac{3^{n+1}+1}{2}.$$
Check: $a_0 = \tfrac{3+1}{2}=2$ ✓; $a_1=\tfrac{9+1}{2}=5$ ✓; and
$a_2 = \tfrac{27+1}{2}=14$ matches the direct recurrence value
$4(5)-3(2)=14$ ✓ (verified for $n=0,\dots,5$ against the recurrence run
directly).

**10.** $A$ is upper triangular, so its eigenvalues are its diagonal
entries: $\lambda=2$ (appearing twice) and $\lambda=3$, i.e.
$p_A(\lambda) = (2-\lambda)^2(3-\lambda)$. So $\lambda=2$ has algebraic
multiplicity $m=2$ and $\lambda=3$ has $m=1$.
For $\lambda=2$: $A-2I=\begin{pmatrix}0&1&0\\0&0&0\\0&0&1\end{pmatrix}$. Row 1
gives $v_2=0$; row 3 gives $v_3=0$; $v_1$ free — geometric multiplicity
$g=1$. Since $g=1 < m=2$ for $\lambda=2$, Theorem 11.3 says $A$ is **not
diagonalizable** (the mismatch at even one eigenvalue is enough to rule it
out — no need to check $\lambda=3$).
(Cross-check: `numpy.linalg.eig` reports eigenvalues $[2,2,3]$, and the
rank of the eigenvector matrix it returns is $2 < 3=n$, consistent with the
total geometric multiplicity being short of $n$.)

**11.** Expand along row 1:
$$\det = 1\cdot\det\begin{pmatrix}1&k\\k&1\end{pmatrix} -
k\cdot\det\begin{pmatrix}k&k\\0&1\end{pmatrix} + 0
= (1-k^2) - k(k) = 1-2k^2.$$
By Theorem 8.2, the matrix is singular exactly when this is $0$:
$1-2k^2=0 \iff k^2=\tfrac12 \iff k = \pm\tfrac{1}{\sqrt2}$.
(Verified numerically: plugging $k=1/\sqrt2$ into the matrix gives a
determinant of $\approx 0$ up to floating-point roundoff.)

**12.** Since $v$ is an eigenvector of $A$ for $\lambda$: $Av=\lambda v$,
$v \neq 0$. Compute directly:
$$(A-cI)v = Av - cv = \lambda v - cv = (\lambda - c)v.$$
Since $v \neq 0$, this is exactly the statement that $v$ is an eigenvector
of $A - cI$ with eigenvalue $\lambda - c$. $\blacksquare$

**13.** Eliminate column 1: $R_2 \to R_2-3R_1$ gives $(0,2,4)$ (multiplier
$3$); $R_3 \to R_3-2R_1$ gives $(0,3,7)$ (multiplier $2$).
$$\begin{pmatrix}1&2&1\\0&2&4\\0&3&7\end{pmatrix}$$
Eliminate column 2: $R_3 \to R_3-\tfrac32R_2$ gives $(0,0,7-6)=(0,0,1)$
(multiplier $\tfrac32$).
$$U = \begin{pmatrix}1&2&1\\0&2&4\\0&0&1\end{pmatrix}, \qquad
L = \begin{pmatrix}1&0&0\\3&1&0\\2&\tfrac32&1\end{pmatrix}.$$
Verify $LU=A$: row 1 of $L$ times $U$ gives $(1,2,1)$ ✓. Row 2:
$3(1,2,1)+1(0,2,4) = (3,6,3)+(0,2,4)=(3,8,7)$ ✓. Row 3:
$2(1,2,1)+\tfrac32(0,2,4)+1(0,0,1) = (2,4,2)+(0,3,6)+(0,0,1)=(2,7,9)$ ✓.
So $A = LU$ (verified numerically that $LU$ reproduces $A$ exactly).

**14.** By hypothesis $Av_1 = \lambda_1v_1 = v_1$ (since $\lambda_1=1$), so
$A^nv_1 = v_1$ for every $n \ge 0$ (apply $A$ repeatedly: each application
leaves $v_1$ unchanged). Also $Av_2=\lambda_2v_2=cv_2$, so by Theorem 12.1's
argument applied to the single eigenvector $v_2$, $A^nv_2 = c^nv_2$. By
linearity of $A^n$,
$$x_n = A^nx_0 = A^n(av_1+bv_2) = aA^nv_1 + bA^nv_2 = av_1 + bc^nv_2.$$
Since $|c|<1$, $c^n \to 0$ as $n \to \infty$ (standard scalar limit), so
$bc^n \to 0$, and hence $bc^nv_2 \to 0$ (the zero vector — a fixed vector
$v_2$ scaled by a scalar going to $0$ goes to $0$). Therefore
$$x_n = av_1 + bc^nv_2 \longrightarrow av_1 + 0 = av_1,$$
regardless of the value of $b$ (as long as $a \neq 0$ keeps the limit
nonzero and meaningful). $\blacksquare$ (This makes rigorous, with an
explicit vector limit, the "long-run behavior tracks the dominant
eigenvalue" intuition from Day 12 Exercise 8.)

**15.** Since $A$ is invertible and $A=PDP^{-1}$ with $P$ invertible,
$D = P^{-1}AP$ is a product of invertible matrices, hence invertible
(Theorem 9.1(b) extended to three factors). A diagonal matrix is invertible
if and only if every diagonal entry is nonzero, so
$D^{-1} = \operatorname{diag}(1/\lambda_1, \dots, 1/\lambda_n)$ is
well-defined. Now check $PD^{-1}P^{-1}$ satisfies the defining condition for
an inverse of $A$:
$$(PDP^{-1})(PD^{-1}P^{-1}) = PD(P^{-1}P)D^{-1}P^{-1} = PD\,I\,D^{-1}P^{-1}
= P(DD^{-1})P^{-1} = PIP^{-1} = I,$$
$$(PD^{-1}P^{-1})(PDP^{-1}) = PD^{-1}(P^{-1}P)DP^{-1} = P(D^{-1}D)P^{-1}
= PIP^{-1} = I.$$
Both products equal $I$, so by Definition 9.1, $PD^{-1}P^{-1}$ is an inverse
of $A$; by uniqueness of the inverse (Theorem 9.1a), $A^{-1}=PD^{-1}P^{-1}$.
Since $P$ is invertible and $D^{-1}$ is diagonal, this exhibits $A^{-1}$ in
exactly the form Definition 11.2 requires: $A^{-1}$ is diagonalizable.
$\blacksquare$

**16.** By Theorem 8.1 (multiplicativity of $\det$),
$\det(A^3) = \det(A)\det(A)\det(A) = \det(A)^3$. Since $A^3=A$,
$\det(A^3)=\det(A)$, so
$$\det(A)^3 = \det(A) \implies \det(A)^3 - \det(A) = 0 \implies
\det(A)\big(\det(A)-1\big)\big(\det(A)+1\big) = 0$$
(factoring $x^3-x = x(x-1)(x+1)$ with $x=\det(A)$). Since $\det(A)$ is a
real number and this product of three real factors is $0$, at least one
factor must vanish: $\det(A) = 0$, $\det(A)=1$, or $\det(A)=-1$. Hence
$\det(A) \in \{-1,0,1\}$. $\blacksquare$

**17.** Since $A$ is invertible, $A^{-1}$ exists. Starting from $AB=AC$,
multiply both sides on the left by $A^{-1}$:
$$A^{-1}(AB) = A^{-1}(AC) \implies (A^{-1}A)B = (A^{-1}A)C
\implies IB = IC \implies B = C,$$
using associativity of matrix multiplication and $A^{-1}A=I$. $\blacksquare$

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $\det A$ | "the determinant of $A$" | zero $\iff$ $A$ is singular; multiplicative; product of the pivots |
| $p_A(\lambda) = \det(A - \lambda I)$ | "the characteristic polynomial" | its roots are the eigenvalues |
| $A = PDP^{-1}$ | "$A$ diagonalized" | makes powers, inverses, and recurrences easy |
| $m$ vs $g$ | "algebraic vs geometric multiplicity" | diagonalizable $\iff$ they match at every eigenvalue |
| $A = LU$ | "$A$ as lower-times-upper" | records the multipliers of Gaussian elimination |
| $[A \mid I]$ | "the augmented matrix for Gauss-Jordan" | row-reduce until the left block is $I$; the right block is then $A^{-1}$ |

Nothing new is introduced today — the table above is a recall of the symbols
from Days 8–12 that a returning learner most wants back at their fingertips.

### The big ideas (conclusions)

- A square matrix is invertible exactly when its determinant is nonzero — the
  single thread linking singularity, the eigenvalue $0$, and dependent
  columns.
- Eigenvalues are the roots of $\det(A - \lambda I) = 0$; a matrix is
  diagonalizable exactly when geometric multiplicity equals algebraic
  multiplicity at every eigenvalue.
- Diagonalization is the workhorse: $A^k = PD^kP^{-1}$ makes matrix powers,
  closed-form recurrence solutions, and long-run limits cheap.
- Gaussian elimination is the common engine underneath determinants (product
  of pivots), the inverse (Gauss-Jordan on $[A \mid I]$), and the $LU$
  factorization.

### If you remember only 3 things

1. Invertible $\iff$ $\det \neq 0$ $\iff$ $0$ is not an eigenvalue $\iff$
   columns independent — Days 8–10 keep saying the same thing four ways.
2. Diagonalizable $\iff$ $g_i = m_i$ at every eigenvalue; then $A^k =
   PD^kP^{-1}$ powers everything cheaply.
3. This is retrieval, not rereading: the miss you now label a *concept gap*
   (rather than an arithmetic slip) is exactly the one worth re-studying
   before Week 4.

## Journal template

```
## Day 13 — Review (Days 8-12)
Score: __/__
Concept gaps found: ...
Arithmetic-only slips: ...
```
