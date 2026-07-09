# Day 7 — Review (Days 1–6)

## Purpose

Today introduces no new theory. It is closed-book retrieval practice on
everything from Days 1–6: vector spaces and span, linear independence/basis/
dimension, linear transformations and matrix representation, invertibility
and rank-nullity, Gaussian elimination and rank, and the four fundamental
subspaces. Review days are placed every 5–6 days, rather than saved for the
end, because spaced retrieval outperforms a single linear pass through the
material — the forgetting curve quietly erases Week 1 material by Week 3
unless it's actively pulled back out of memory before that happens. The work
below is that retrieval: struggling to reproduce Days 1–6 from memory *now*,
while the gaps are still cheap to find and fix.

## Instructions

Follow these steps in order, closed-book except where noted.

1. **Journal pass (~30 min).** Reread all six of your Day 1–6 journal entries.
   For every item you listed under "what confused me," re-derive it from
   scratch, closed-book, before moving on to the next one. If you can't
   re-derive something, that's exactly the kind of gap this review day exists
   to surface — note it, but keep going; you'll revisit it in the concept-gaps
   tally at the end.
2. **Full timed attempt (~150 min).** Attempt every problem in the Mixed
   review problem set below, closed-book, no notes, no solutions section, in
   one sitting timed at roughly 150 minutes total (about 7–8 minutes per
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
5. **Journal entry (~15 min).** Fill in the Day 7 journal template at the
   bottom of this file and append it to your `journal.md`.

## Mixed review problem set

Problems are deliberately interleaved across topics (not grouped by day) —
mixing topics during retrieval practice is itself part of what makes it
effective. Each problem is labeled with the day/topic it targets so you can
tally your score by topic afterward.

1. **(Day 3: linear transformations)** Determine whether
   $T: \mathbb{R}^2 \to \mathbb{R}^2$, $T(x,y) = (x - 2y,\ 3x + y^2)$, is
   linear. Prove your answer.
2. **(Day 1: vector spaces/span)** Determine whether $v = (2,3,2)$ is in
   $\operatorname{span}\{(1,1,0), (0,1,1)\} \subseteq \mathbb{R}^3$. Show your
   work.
3. **(Day 5: Gaussian elimination)** Solve by elimination, showing every row
   operation:
   $$x + y + 2z = 9, \qquad 2x + 4y - 3z = 1, \qquad 3x + 6y - 5z = 0.$$
4. **(Day 2: linear independence/basis)** Determine whether
   $\{(1,0,2), (2,1,3), (0,1,-1)\}$ is linearly independent in $\mathbb{R}^3$.
   If dependent, exhibit an explicit nontrivial relation.
5. **(Day 6: four fundamental subspaces)** Let
   $A = \begin{pmatrix}1&1&2\\2&3&5\\1&2&3\end{pmatrix}$. Find a basis for
   each of the four fundamental subspaces of $A$, state their dimensions, and
   verify the Fundamental Theorem's counts against $r$, $m=3$, $n=3$.
6. **(Day 4: invertibility/rank-nullity)** Let
   $A = \begin{pmatrix}1&3\\2&6\end{pmatrix}$ as a map $\mathbb{R}^2 \to
   \mathbb{R}^2$. Find $\ker A$ and $\operatorname{im} A$, verify
   rank-nullity, and determine whether $A$ is invertible.
7. **(Day 1: vector spaces/span)** Let
   $W = \{(x,y,z) \in \mathbb{R}^3 : 2x - y + z = 0\}$. Prove or disprove that
   $W$ is a subspace of $\mathbb{R}^3$.
8. **(Day 3: linear transformations)** Determine whether
   $T: \mathbb{R}^3 \to \mathbb{R}^2$, $T(x,y,z) = (x+y+z,\ 0)$, is linear.
   Prove your answer.
9. **(Day 5: Gaussian elimination/rank)** Compute $\operatorname{rank}(M)$ by
   row reduction, where
   $M = \begin{pmatrix}1&3&2\\2&6&5\\1&3&4\end{pmatrix}$.
10. **(Day 2: linear independence/basis)** Find a basis for
    $\operatorname{span}\{(1,2,1), (2,4,2), (1,1,0)\} \subseteq \mathbb{R}^3$
    and state its dimension.
11. **(Day 6: four fundamental subspaces)** Let
    $A = \begin{pmatrix}1&0&1&3\\0&1&2&-1\end{pmatrix}$, viewed as a map
    $\mathbb{R}^4 \to \mathbb{R}^2$. Find a basis for each of the four
    fundamental subspaces. What do you notice about $N(A^T)$? Confirm it's
    consistent with $r$ and $m$.
12. **(Day 4: invertibility/rank-nullity)** Let
    $A = \begin{pmatrix}1&0&1&2\\1&1&0&1\end{pmatrix}$ as a map
    $\mathbb{R}^4 \to \mathbb{R}^2$. Find $\ker A$ and determine whether $A$
    is surjective, using rank-nullity (not a direct spanning argument).
13. **(Day 3: linear transformations)** Let $T: \mathbb{R}^2 \to \mathbb{R}^2$
    be the unique linear transformation with $T(e_1) = (2,1)$ and
    $T(e_2) = (-1,3)$. Write the matrix of $T$ relative to the standard
    basis, and use it to compute $T(3,-2)$.
14. **(Day 1: vector spaces/span)** True or False, with justification: the
    set of all singular (non-invertible) $2\times2$ matrices is a subspace of
    $M_2(\mathbb{R})$.
15. **(Day 6: four fundamental subspaces)** Suppose $A$ is a $4\times6$
    matrix with $\operatorname{rank}(A) = 3$, but you are not given $A$
    itself. State the dimension of each of the four fundamental subspaces,
    and say which of $\mathbb{R}^4$ or $\mathbb{R}^6$ each one is a subspace
    of.
16. **(Day 5: Gaussian elimination/rank)** Prove: for an $m \times n$ matrix
    $A$, the homogeneous system $Ax = 0$ has a nontrivial solution
    ($x \neq 0$) if and only if $\operatorname{rank}(A) < n$.
17. **(Day 2: linear independence/basis)** Prove: if $\{v_1, \dots, v_n\}$ is
    a basis of a vector space $V$ and $c$ is a nonzero scalar, then
    $\{cv_1, v_2, \dots, v_n\}$ is also a basis of $V$.
18. **(Day 3: linear transformations)** Let $T: \mathbb{R}^2 \to \mathbb{R}^2$
    be reflection across the $y$-axis, and let $S: \mathbb{R}^2 \to
    \mathbb{R}^2$ be the $90°$ clockwise rotation. Find the matrix of
    $S \circ T$ two ways: first by directly computing $(S \circ T)(e_1)$ and
    $(S \circ T)(e_2)$ using the geometric description of $S$ and $T$; second
    by multiplying the two standard matrices. Confirm the two answers agree.
19. **(Day 4: invertibility/rank-nullity)** Prove: if $T: V \to W$ is
    surjective and $\dim V = \dim W$ (both finite), then $T$ is automatically
    injective. Write out the rank-nullity argument explicitly.
20. **(Day 6: four fundamental subspaces)** Prove: if $A$ is an
    $m \times n$ matrix with $\operatorname{rank}(A) = m$ (full row rank),
    then $N(A^T) = \{0\}$.

## Solutions

**1.** Not linear. Check homogeneity with $x=0, y=1$: $T(0,1) = (0-2,\ 0+1) =
(-2, 1)$, so $c \cdot T(0,1) = c(-2,1)$. Now take $c = 2$: $c \cdot T(0,1) =
(-4, 2)$. But $T(c(0,1)) = T(0,2) = (0-4,\ 0+4) = (-4, 4)$. Since
$(-4,2) \neq (-4,4)$, homogeneity fails, so $T$ is not linear. (The $y^2$
term is the giveaway — a linear map can only involve degree-$1$ terms in the
input coordinates.)

**2.** Solve $a(1,1,0) + b(0,1,1) = (a,\ a+b,\ b) = (2,3,2)$. From the first
coordinate, $a = 2$. From the third coordinate, $b = 2$. Check the second
coordinate: $a + b = 4 \neq 3$ — contradiction. No solution exists, so
$v \notin \operatorname{span}\{(1,1,0),(0,1,1)\}$.

**3.** Augmented matrix:
$$\left[\begin{array}{ccc|c}1&1&2&9\\2&4&-3&1\\3&6&-5&0\end{array}\right]$$
$R_2 \to R_2 - 2R_1$: $[0,\,2,\,-7 \mid -17]$. $R_3 \to R_3 - 3R_1$:
$[0,\,3,\,-11 \mid -27]$.
$$\left[\begin{array}{ccc|c}1&1&2&9\\0&2&-7&-17\\0&3&-11&-27\end{array}\right]$$
$R_3 \to R_3 - \tfrac32 R_2$: $\left[0,\ 3-3,\ -11-\tfrac32(-7) \mid
-27-\tfrac32(-17)\right] = \left[0,\,0,\,-\tfrac12 \mid -\tfrac32\right]$.
This is row echelon form with $3$ pivots, so the system has a unique
solution. Back-substitute: $-\tfrac12 z = -\tfrac32 \implies z = 3$; from
$R_2$: $2y - 7(3) = -17 \implies 2y = 4 \implies y = 2$; from $R_1$:
$x + 2 + 2(3) = 9 \implies x = 1$. **Solution:** $(x,y,z) = (1,2,3)$. Check
against the original equations: $1+2+6=9$ ✓; $2+8-9=1$ ✓; $3+12-15=0$ ✓.

**4.** Set $a(1,0,2) + b(2,1,3) + c(0,1,-1) = (0,0,0)$. Coordinate-wise:
$a + 2b = 0$ (first), $b + c = 0$ (second), $2a + 3b - c = 0$ (third). From
the first two, $a = -2b$ and $c = -b$. Substituting into the third:
$2(-2b) + 3b - (-b) = -4b + 3b + b = 0$, which holds for *any* $b$ — so
nontrivial solutions exist. Take $b = 1$: then $a = -2$, $c = -1$. Check:
$-2(1,0,2) + 1(2,1,3) - 1(0,1,-1) = (-2+2-0,\ 0+1-1,\ -4+3+1) = (0,0,0)$ ✓.
So the set is linearly **dependent**, with relation $-2v_1 + v_2 - v_3 = 0$,
i.e. $v_2 = 2v_1 + v_3$.

**5.** Row reduce: $R_2 \to R_2 - 2R_1$ gives $(0,1,1)$; $R_3 \to R_3 - R_1$
gives $(0,1,1)$; then $R_3 \to R_3 - R_2$ gives $(0,0,0)$:
$$U = \begin{pmatrix}1&1&2\\0&1&1\\0&0&0\end{pmatrix}, \qquad r = 2
\text{ (pivots in columns 1, 2)}.$$
*Row space:* basis $\{(1,1,2),(0,1,1)\} \subseteq \mathbb{R}^3$, $\dim = 2$.
*Column space:* pivot columns of $A$ at positions 1, 2: basis
$\left\{\begin{pmatrix}1\\2\\1\end{pmatrix},
\begin{pmatrix}1\\3\\2\end{pmatrix}\right\} \subseteq \mathbb{R}^3$, $\dim=2$.
*Null space:* from $U$: row 2 gives $x_2 + x_3 = 0 \implies x_2 = -x_3$; row
1 gives $x_1 + x_2 + 2x_3 = 0 \implies x_1 = -x_2 - 2x_3 = x_3 - 2x_3 =
-x_3$. Basis $\{(-1,-1,1)\} \subseteq \mathbb{R}^3$, $\dim = 1 = n-r=3-2$.
*Left null space:* looking for a combination of the rows of $A$ that
vanishes: $(R_2 - 2R_1) - (R_3-R_1) = R_2 - R_1 - R_3 = (0,1,1)-(0,1,1) = 0$,
i.e. $-R_1 + R_2 - R_3 = 0$. Check: $-(1,1,2)+(2,3,5)-(1,2,3) = (0,0,0)$ ✓.
Basis $\{(-1,1,-1)\} \subseteq \mathbb{R}^3$, $\dim = 1 = m-r = 3-2$.
*Check:* row + null $= 2+1=3=n$ ✓; col + left-null $=2+1=3=m$ ✓.

**6.** $Ax = (x_1+3x_2,\ 2x_1+6x_2)$. $Ax=0 \iff x_1 = -3x_2$ ($x_2$ free),
so $\ker A = \operatorname{span}\{(-3,1)\}$, $\dim(\ker A) = 1$. The columns
of $A$ are $(1,2)$ and $(3,6) = 3(1,2)$, so
$\operatorname{im} A = \operatorname{span}\{(1,2)\}$, $\dim(\operatorname{im}
A) = 1$. Rank-nullity: $1 + 1 = 2 = \dim \mathbb{R}^2$ ✓. Since
$\ker A \neq \{0\}$, $A$ is not injective (Lemma 4.1); since
$\dim(\text{domain}) = \dim(\text{codomain}) = 2$, Theorem 4.2 gives
not-injective $\iff$ not-invertible. So $A$ is **not invertible**.

**7.** Yes, $W$ is a subspace. *Contains 0:* $2(0)-0+0=0$ ✓. *Closed under
addition:* if $(x_1,y_1,z_1),(x_2,y_2,z_2) \in W$, then
$2(x_1+x_2)-(y_1+y_2)+(z_1+z_2) = (2x_1-y_1+z_1)+(2x_2-y_2+z_2) = 0+0=0$, so
the sum is in $W$. *Closed under scalar multiplication:* if $(x,y,z) \in W$
and $c \in \mathbb{R}$, then $2(cx)-(cy)+(cz) = c(2x-y+z) = c\cdot0 = 0$, so
$c(x,y,z) \in W$. All three conditions hold; $W$ is the plane through the
origin with normal $(2,-1,1)$.

**8.** Linear. *Additivity:*
$$T((x_1,y_1,z_1)+(x_2,y_2,z_2)) = T(x_1{+}x_2,\,y_1{+}y_2,\,z_1{+}z_2) =
(x_1{+}x_2{+}y_1{+}y_2{+}z_1{+}z_2,\ 0)$$
$$= (x_1{+}y_1{+}z_1,\,0) + (x_2{+}y_2{+}z_2,\,0) = T(x_1,y_1,z_1) +
T(x_2,y_2,z_2).$$
*Homogeneity:* $T(c(x,y,z)) = T(cx,cy,cz) = (cx+cy+cz,\,0) = c(x+y+z,\,0) =
cT(x,y,z)$. Both conditions hold, so $T$ is linear. (Equivalently, $T$ is
given by the matrix $\begin{pmatrix}1&1&1\\0&0&0\end{pmatrix}$ acting on
$(x,y,z)^T$, and every matrix-multiplication map is automatically linear.)

**9.** $R_2 \to R_2 - 2R_1$: $[2-2,\ 6-6,\ 5-4] = [0,0,1]$. $R_3 \to R_3 -
R_1$: $[1-1,\ 3-3,\ 4-2] = [0,0,2]$.
$$\begin{pmatrix}1&3&2\\0&0&1\\0&0&2\end{pmatrix}$$
$R_3 \to R_3 - 2R_2$: $[0,0,0]$. Two nonzero rows remain (pivots in columns
1 and 3; column 2 never gets a pivot since it's already $3\times$ column 1
in the original matrix). $\operatorname{rank}(M) = 2$.

**10.** Note $(2,4,2) = 2(1,2,1)$, so the second vector is redundant and can
be dropped without changing the span (Theorem 2.1/Theorem 2.2's removal
argument):
$\operatorname{span}\{(1,2,1),(2,4,2),(1,1,0)\} =
\operatorname{span}\{(1,2,1),(1,1,0)\}$. These two are not scalar multiples:
if $(1,1,0) = t(1,2,1)$, the first coordinate forces $t=1$, but then the
second coordinate would need to be $2$, not $1$ — contradiction. So they're
independent, hence a basis for the span, and the **dimension is 2**.

**11.** $A$ is already in reduced row echelon form, with pivots in columns
1, 2; $r = 2 = m$ (full row rank — every row is a pivot row, none is zero).
*Row space:* basis $\{(1,0,1,3),(0,1,2,-1)\} \subseteq \mathbb{R}^4$, $\dim=2$.
*Column space:* pivot columns 1, 2 of $A$: basis
$\left\{\binom{1}{0},\binom{0}{1}\right\} \subseteq \mathbb{R}^2$, i.e.
$C(A) = \mathbb{R}^2$ entirely, $\dim = 2$. *Null space:* $x_1 = -x_3-3x_4$,
$x_2 = -2x_3+x_4$, with $x_3, x_4$ free. Basis
$\{(-1,-2,1,0),\ (-3,1,0,1)\} \subseteq \mathbb{R}^4$, $\dim = 2 = n-r=4-2$.
*Left null space:* since $r = m = 2$ (full row rank, no zero row survives
elimination), the Fundamental Theorem gives $\dim N(A^T) = m - r = 0$, i.e.
$N(A^T) = \{0\}$ — full row rank forces a trivial left null space (mirrors
Day 6's Exercise 4 pattern in reverse: there, full *column* rank forced a
trivial ordinary null space).

**12.** Row reduce: $R_2 \to R_2 - R_1$: $[1-1,\ 1-0,\ 0-1,\ 1-2] =
[0,1,-1,-1]$.
$$\begin{pmatrix}1&0&1&2\\0&1&-1&-1\end{pmatrix}, \qquad r=2 \text{ (pivots
in columns 1, 2)}.$$
Since $r = 2 = \dim(\text{codomain } \mathbb{R}^2)$, $\operatorname{im} A =
\mathbb{R}^2$, so $A$ is **surjective**. By rank-nullity,
$\dim(\ker A) = n - r = 4 - 2 = 2$. From the echelon form: row 2 gives
$x_2 = x_3 + x_4$; row 1 gives $x_1 = -x_3 - 2x_4$, with $x_3, x_4$ free.
Setting $x_3=1,x_4=0$: $(-1,1,1,0)$; setting $x_3=0,x_4=1$: $(-2,1,0,1)$.
Basis $\ker A = \{(-1,1,1,0),\ (-2,1,0,1)\}$. Check against the *original*
$A$: $A(-1,1,1,0) = (-1+0+1+0,\ -1+1+0+0) = (0,0)$ ✓;
$A(-2,1,0,1) = (-2+0+0+2,\ -2+1+0+1) = (0,0)$ ✓.

**13.** By Definition 3.2, the matrix of $T$ has $T(e_1), T(e_2)$ as its
columns: $A = \begin{pmatrix}2&-1\\1&3\end{pmatrix}$. Then
$$T(3,-2) = A\begin{pmatrix}3\\-2\end{pmatrix} =
\begin{pmatrix}2(3)+(-1)(-2)\\1(3)+3(-2)\end{pmatrix} =
\begin{pmatrix}6+2\\3-6\end{pmatrix} = \begin{pmatrix}8\\-3\end{pmatrix}.$$
(Check via linearity directly: $(3,-2) = 3e_1 - 2e_2$, so
$T(3,-2) = 3T(e_1) - 2T(e_2) = 3(2,1)-2(-1,3) = (6,3)-(-2,6) = (8,-3)$ ✓.)
**$T(3,-2) = (8,-3)$.**

**14.** False. The zero matrix is singular (its determinant is $0$), so the
set does contain $0$ — that alone isn't the failure. The failure is closure
under addition: let $A = \begin{pmatrix}1&0\\0&0\end{pmatrix}$ and
$B = \begin{pmatrix}0&0\\0&1\end{pmatrix}$, both singular (each has a zero
row/determinant $0$). But $A + B = \begin{pmatrix}1&0\\0&1\end{pmatrix} = I$,
which is invertible (determinant $1 \neq 0$), hence *not* singular. So
$A, B$ are in the set but $A+B$ is not — the set is not closed under
addition, hence not a subspace.

**15.** $\dim(\text{row space}) = \dim C(A) = r = 3$. Row space
$\subseteq \mathbb{R}^6$ ($n=6$), $\dim = 3$. $C(A) \subseteq \mathbb{R}^4$
($m=4$), $\dim = 3$. $\dim N(A) = n - r = 6 - 3 = 3$, and
$N(A) \subseteq \mathbb{R}^6$. $\dim N(A^T) = m - r = 4 - 3 = 1$, and
$N(A^T) \subseteq \mathbb{R}^4$.

**16.** Let $r = \operatorname{rank}(A)$, and row-reduce $A$ to an echelon
form $U$ with $r$ pivots ($r \le n$); by Theorem 5.1, $Ax=0 \iff Ux=0$, so it
suffices to analyze $Ux=0$. Among the $n$ variables, exactly $r$ are pivot
variables and $n - r$ are free variables (those in non-pivot columns).

($\Leftarrow$) Suppose $r < n$. Then $n - r \ge 1$, so at least one free
variable exists. Assign it the value $1$ (and any other free variables the
value $0$); each pivot variable is then uniquely determined by
back-substitution through the $r$ pivot equations (all of which read
"$\ldots = 0$" since the system is homogeneous). This produces a solution
$x$ whose free-variable coordinate is $1 \neq 0$, so $x \neq 0$ — a
nontrivial solution exists.

($\Rightarrow$) Suppose $r = n$ (the only remaining case, since $r \le n$
always). Then every column is a pivot column, so there are no free
variables: the $r=n$ pivot equations, read from the bottom pivot row
upward, force each variable to equal an expression in variables to its
right that are already forced to $0$ (starting from the last pivot equation,
which involves only the last variable and reads $c \cdot x_n = 0$ with
$c \neq 0$, forcing $x_n = 0$; then the second-to-last pivot equation
involves only $x_{n-1}$ and the already-zero $x_n$, forcing $x_{n-1}=0$; and
so on). Hence $x = 0$ is the *only* solution — no nontrivial solution
exists. Contrapositive: if a nontrivial solution exists, $r \neq n$, i.e.
(combined with $r \le n$) $r < n$.

Both directions give: $Ax=0$ has a nontrivial solution $\iff r < n$.
$\blacksquare$

**17.** *Spanning.* Since $c \neq 0$, $v_1 = \tfrac1c(cv_1)$, so $v_1 \in
\operatorname{span}\{cv_1, v_2, \dots, v_n\}$; combined with
$v_2, \dots, v_n$ trivially being in that span, every original basis vector
is in $\operatorname{span}\{cv_1,v_2,\dots,v_n\}$, so
$V = \operatorname{span}\{v_1,\dots,v_n\} \subseteq
\operatorname{span}\{cv_1,v_2,\dots,v_n\}$ (Day 1's monotonicity fact). The
reverse inclusion is immediate since $cv_1$ is itself a linear combination
(scalar multiple) of $v_1$, so
$\operatorname{span}\{cv_1,v_2,\dots,v_n\} \subseteq
\operatorname{span}\{v_1,\dots,v_n\} = V$. Hence
$\operatorname{span}\{cv_1,v_2,\dots,v_n\} = V$: the set spans $V$.

*Independence.* Suppose $a_1(cv_1) + a_2v_2 + \cdots + a_nv_n = 0$ for
scalars $a_i$. Rewrite as $(a_1c)v_1 + a_2v_2 + \cdots + a_nv_n = 0$. Since
$\{v_1,\dots,v_n\}$ is linearly independent, every coefficient must vanish:
$a_1 c = 0$ and $a_2 = \cdots = a_n = 0$. Since $c \neq 0$, $a_1c=0$ forces
$a_1 = 0$ as well. So the only solution is trivial:
$\{cv_1,v_2,\dots,v_n\}$ is linearly independent.

Spanning and independent: $\{cv_1,v_2,\dots,v_n\}$ is a basis of $V$.
$\blacksquare$

**18.** Reflection across the $y$-axis sends $(x,y) \mapsto (-x,y)$, so
$T(e_1)=(-1,0)$, $T(e_2)=(0,1)$, giving
$M_T = \begin{pmatrix}-1&0\\0&1\end{pmatrix}$. The $90°$ clockwise rotation
sends $(x,y) \mapsto (y,-x)$, so $S(e_1)=(0,-1)$, $S(e_2)=(1,0)$, giving
$M_S = \begin{pmatrix}0&1\\-1&0\end{pmatrix}$.

*Directly:* $(S\circ T)(e_1) = S(T(e_1)) = S(-1,0)$. Using $S(x,y)=(y,-x)$:
$S(-1,0) = (0,1)$. $(S\circ T)(e_2) = S(T(e_2)) = S(0,1) = (1,0)$. So the
matrix of $S\circ T$ (columns are these images) is
$\begin{pmatrix}0&1\\1&0\end{pmatrix}$.

*By matrix multiplication:*
$$M_S M_T = \begin{pmatrix}0&1\\-1&0\end{pmatrix}\begin{pmatrix}-1&0\\0&1\end{pmatrix}
= \begin{pmatrix}0(-1)+1(0) & 0(0)+1(1) \\ -1(-1)+0(0) & -1(0)+0(1)\end{pmatrix}
= \begin{pmatrix}0&1\\1&0\end{pmatrix}.$$
This matches the direct computation, confirming Theorem 3.2.

**19.** Suppose $T: V \to W$ is surjective, so $\operatorname{im} T = W$,
hence $\dim(\operatorname{im} T) = \dim W$. Let $n = \dim V = \dim W$. By
the rank-nullity theorem (Theorem 4.1),
$$\dim(\ker T) + \dim(\operatorname{im} T) = \dim V \implies \dim(\ker T) +
n = n \implies \dim(\ker T) = 0.$$
A subspace of dimension $0$ is exactly $\{0\}$ (only the zero vector spans a
$0$-dimensional space — any nonzero vector alone spans at least a
$1$-dimensional subspace), so $\ker T = \{0\}$. By Lemma 4.1 (injective iff
trivial kernel), $T$ is injective. $\blacksquare$

**20.** Since $\operatorname{rank}(A) = m$ equals the number of rows, the
row-reduction argument of Lemma 6.1(a) shows the $m$ rows of $A$ are
themselves already linearly independent (row-reducing an $m\times n$ matrix
to echelon form with $m$ pivots means every row becomes, and remains, a
pivot row — no row is ever reduced to all zeros). Now suppose
$y \in N(A^T)$, i.e. $A^Ty = 0$, equivalently $y^TA = 0$. Writing out
$y^TA$ as a linear combination of the rows $r_1, \dots, r_m$ of $A$:
$$y^TA = \sum_{i=1}^m y_i\, r_i = 0.$$
Since $r_1, \dots, r_m$ are linearly independent, this forces every
coefficient to vanish: $y_i = 0$ for all $i = 1, \dots, m$, i.e. $y = 0$.
Hence $N(A^T) = \{0\}$. $\blacksquare$ (Cross-check via the Fundamental
Theorem: $\dim N(A^T) = m - r = m - m = 0$, consistent.)

## Journal template

```
## Day 7 — Review (Days 1-6)
Score: __/__
Concept gaps found: ...
Arithmetic-only slips: ...
```
