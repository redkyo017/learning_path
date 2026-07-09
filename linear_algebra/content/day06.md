# Day 6 — The Four Fundamental Subspaces

**Today is a synthesis day, not a new-machinery day.** Every object below —
column space, row space, null space, left null space, rank — was already in
your hands by the end of Day 5. Nothing new is being defined for its own
sake; the point of today is to see that "rank" (Day 5), "kernel/image of a
linear map" (Day 4), and "row reduction" (Day 5) are four views of *one*
computation, not four separate topics to memorize separately.

## Learning objectives

By the end of today you should be able to:
- State the definitions of the column space, row space, null space, and left
  null space of a matrix $A$, and say precisely which $\mathbb{R}^k$ each one
  lives in.
- Prove the Fundamental Theorem of Linear Algebra, Part 1 (the dimension
  formulas for all four subspaces), by explicitly connecting Day 4's
  rank–nullity theorem and Day 5's row-echelon pivot count — not by treating
  it as a new fact to memorize.
- Given a matrix, find a basis for all four of its fundamental subspaces by
  row reduction, and verify the dimension count against $r$, $m$, $n$.
- Explain why row rank equals column rank, in your own words, as a
  consequence of a single row-reduction computation rather than as two
  independent facts.

## Reference material

- There is no single 3Blue1Brown video dedicated to this synthesis — instead,
  re-watch *Essence of Linear Algebra*, Chapters 6–7 (the determinant, and
  inverse matrices/column space/null space) —
  [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab).
  Watch with fresh eyes: the first time through, these were separate clips
  about separate operations; today's job is to notice they're all describing
  the same row-reduced matrix from different angles.
- MIT OCW 18.06 (Strang) has a lecture on exactly this topic. Browse the
  course page — [18.06 Linear Algebra, Spring 2010](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/)
  — and find "The Four Fundamental Subspaces" in the syllabus/video lectures
  for the lecture itself and the associated problem set; as a direct
  pointer, the same lecture is also mirrored at
  [Lecture 10: The four fundamental subspaces](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/resources/lecture-10-the-four-fundamental-subspaces/).
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson) —
  mixed problems drawn from both the Vector Spaces chapter and the Systems
  of Linear Equations chapter (this topic straddles both, which is itself
  part of the point). As with Day 1, the exercises below are self-contained
  if you don't have a copy.

## Theory

Throughout, $A$ is a fixed $m \times n$ real matrix.

### Definition 6.1 (The four fundamental subspaces)

- The **column space** of $A$ is $C(A) = \{Ax : x \in \mathbb{R}^n\} \subseteq
  \mathbb{R}^m$ — all vectors reachable as $Ax$.
- The **row space** of $A$ is $C(A^T) \subseteq \mathbb{R}^n$ — the column
  space of $A^T$, equivalently the span of the rows of $A$ (viewed as
  vectors in $\mathbb{R}^n$).
- The **null space** of $A$ is $N(A) = \{x \in \mathbb{R}^n : Ax = 0\}
  \subseteq \mathbb{R}^n$.
- The **left null space** of $A$ is $N(A^T) = \{y \in \mathbb{R}^m : A^T y =
  0\} \subseteq \mathbb{R}^m$ (equivalently, $\{y : y^T A = 0\}$ — the $y$'s
  for which $y^T$ acting on the left of $A$ gives zero, which is where the
  name comes from).

Notice the ambient spaces pair up: $C(A)$ and $N(A^T)$ both live in
$\mathbb{R}^m$; $C(A^T)$ (row space) and $N(A)$ both live in $\mathbb{R}^n$.
This pairing is not a coincidence — it is exactly what the Fundamental
Theorem below quantifies, and (foreshadowing Day 14–15) each pair will later
turn out to be *orthogonal complements* of each other, not just
same-dimensional companions.

Recall from Day 5: **rank**, written $\operatorname{rank}(A) = r$, is the
number of pivots in any row-echelon form of $A$. Recall from Day 4, the
**Rank–Nullity Theorem**: if $T : V \to W$ is a linear map and $\dim V = n$ is
finite, then
$$\dim(\ker T) + \dim(\operatorname{im} T) = n.$$

Everything below is these two facts, applied twice, plus one lemma
connecting them.

### Lemma 6.1 (Row rank equals column rank, and both equal the pivot count)

Let $U$ be any row-echelon form obtained from $A$ by elementary row
operations, with $r$ pivots. Then:

(a) $\dim(\text{row space of } A) = r$.

(b) $\dim(C(A)) = r$.

**Proof.**

*(a)* Elementary row operations (swap two rows, scale a row by a nonzero
scalar, add a multiple of one row to another) replace the set of rows with
new rows that are linear combinations of the old ones, and this process is
invertible (each operation has an inverse operation of the same type). Hence
at every step the *span* of the rows — the row space — is unchanged: the new
rows lie in the span of the old ones (so the new row space $\subseteq$ old
row space), and since the operation is invertible, the old rows lie in the
span of the new ones too (old row space $\subseteq$ new row space). By
induction over the sequence of row operations taking $A$ to $U$, row
space$(A) =$ row space$(U)$.

Now, the nonzero rows of $U$ — there are exactly $r$ of them, one per pivot
— span row space$(U)$ (the zero rows of $U$ contribute nothing to any span).
They are also linearly independent: order them by their pivot column
$j_1 < j_2 < \cdots < j_r$. In a linear combination
$c_1 (\text{row } 1) + \cdots + c_r(\text{row } r) = 0$, look at column
$j_1$: only row 1 has a nonzero entry there (rows $2, \dots, r$ have zero in
every column at or before their own pivot column, and $j_1 < j_2 \le \dots$),
so $c_1 = 0$. Repeating this argument at column $j_2$ (now that row 1's
contribution is gone) forces $c_2 = 0$, and so on inductively; all $c_i = 0$.
So the $r$ nonzero rows of $U$ are a basis for row space$(U) = $ row
space$(A)$, giving $\dim(\text{row space}(A)) = r$.

*(b)* Call the columns of $U$ at the $r$ pivot positions the *pivot columns*
of $U$, and let the *pivot columns of $A$* be the columns of $A$ at those
same $r$ positions. We show the pivot columns of $A$ are a basis for $C(A)$.

First, elementary row operations correspond to left-multiplication by an
invertible matrix $E$ (each operation is itself invertible, and a composite
of invertible maps is invertible), so $U = EA$, and consequently for any $x$,
$$Ax = 0 \iff EAx = 0 \iff Ux = 0,$$
since $E$ is invertible ($Ax = 0 \implies Ux = EAx = 0$; conversely
$Ux = 0 \implies Ax = E^{-1}Ux = 0$). So **$A$ and $U$ have the same null
space** — this single fact drives the rest of the proof.

*Independence of the pivot columns of $A$:* suppose a linear combination of
the pivot columns of $A$ vanishes; extend the coefficient vector to an
$x \in \mathbb{R}^n$ by placing these coefficients in the pivot positions and
$0$ elsewhere, so this says $Ax = 0$. Since $Ax = 0 \iff Ux = 0$, also
$Ux = 0$. Restricting $U$ to just its pivot columns and the first $r$ rows
gives an $r \times r$ upper-triangular matrix with the pivots (all nonzero)
on the diagonal, hence invertible; $Ux = 0$ restricted to those rows/columns
forces the coefficient vector to be $0$. So the pivot columns of $A$ are
linearly independent.

*Spanning:* let $j$ be any non-pivot column index. In echelon form, column
$j$ of $U$ is some linear combination of the pivot columns of $U$ to its
left — say column $j$ of $U$ equals $\sum_k \lambda_k (\text{pivot column }
k \text{ of } U)$. Build $x \in \mathbb{R}^n$ with $-1$ in position $j$,
$\lambda_k$ in each pivot position $k$, and $0$ elsewhere; by construction
$Ux = 0$. Since $Ax = 0 \iff Ux = 0$, also $Ax = 0$, which unpacks to exactly
$$\text{column } j \text{ of } A = \sum_k \lambda_k (\text{pivot column } k
\text{ of } A).$$
So every non-pivot column of $A$ is a linear combination of the pivot
columns of $A$, and the pivot columns of $A$ trivially "span themselves" —
hence the $r$ pivot columns of $A$ span $C(A)$.

Independent and spanning: the pivot columns of $A$ are a basis for $C(A)$,
so $\dim(C(A)) = r$. $\blacksquare$

In particular, (a) and (b) show row rank and column rank of $A$ are the
*same number* $r$ — not two facts that happen to agree, but two bases read
off the same row-reduction computation.

### Theorem 6.1 (Fundamental Theorem of Linear Algebra, Part 1)

Let $A$ be $m \times n$ with $\operatorname{rank}(A) = r$. Then:

1. $\dim(\text{row space of } A) = \dim(C(A)) = r$.
2. $\dim(N(A)) = n - r$.
3. $\dim(N(A^T)) = m - r$.

**Proof.** Statement 1 is exactly Lemma 6.1.

*Statement 2.* View $A$ as the linear map $T_A : \mathbb{R}^n \to
\mathbb{R}^m$, $T_A(x) = Ax$ (this is linear: $A(x+y) = Ax+Ay$ and
$A(cx) = cAx$ by the distributive/scalar laws of matrix multiplication).
By definition, $\ker(T_A) = \{x : Ax = 0\} = N(A)$, and
$\operatorname{im}(T_A) = \{Ax : x \in \mathbb{R}^n\} = C(A)$. Apply Day 4's
Rank–Nullity Theorem to $T_A$, whose domain $\mathbb{R}^n$ has dimension $n$:
$$\dim(N(A)) + \dim(C(A)) = n.$$
By statement 1, $\dim(C(A)) = r$, so $\dim(N(A)) = n - r$.

*Statement 3.* View $A^T$ (an $n \times m$ matrix) as the linear map
$T_{A^T} : \mathbb{R}^m \to \mathbb{R}^n$, $T_{A^T}(y) = A^T y$. By
definition, $\ker(T_{A^T}) = \{y : A^Ty = 0\} = N(A^T)$, and
$\operatorname{im}(T_{A^T}) = \{A^Ty : y \in \mathbb{R}^m\} = C(A^T) =$ row
space of $A$. Apply Day 4's Rank–Nullity Theorem to $T_{A^T}$, whose domain
$\mathbb{R}^m$ has dimension $m$:
$$\dim(N(A^T)) + \dim(C(A^T)) = m.$$
By statement 1, $\dim(C(A^T)) = \dim(\text{row space of } A) = r$, so
$\dim(N(A^T)) = m - r$. $\blacksquare$

Every clause of this proof is a fact you already had: rank-nullity is Day
4's theorem applied to the map $x \mapsto Ax$ (and, for the left null space,
to the map $y \mapsto A^Ty$), and the missing ingredient — that column rank
and row rank are the same number $r$ — is read directly off one
row-echelon computation from Day 5. There is no new machinery in this
theorem; it is Days 4 and 5 stated together.

## Worked example

Let
$$A = \begin{pmatrix}1 & 2 & 1 \\ 2 & 4 & 3 \\ 3 & 6 & 5\end{pmatrix}, \qquad
m = n = 3.$$

**Row reduce.** $R_2 \to R_2 - 2R_1$ gives $(0, 0, 1)$. $R_3 \to R_3 - 3R_1$
gives $(0, 0, 2)$. Then $R_3 \to R_3 - 2R_2$ gives $(0,0,0)$:
$$U = \begin{pmatrix}1 & 2 & 1 \\ 0 & 0 & 1 \\ 0 & 0 & 0\end{pmatrix}.$$
Pivots are in columns 1 and 2 of $U$'s row structure — precisely, row 1 pivots
in column 1, row 2 pivots in column 3. So $r = 2$.

**Row space** (basis = nonzero rows of $U$, by Lemma 6.1(a)):
$$\{(1,2,1),\ (0,0,1)\} \subseteq \mathbb{R}^3, \qquad \dim = 2 = r.$$

**Column space** (basis = pivot columns *of $A$*, at positions 1 and 3, by
Lemma 6.1(b)):
$$\left\{\begin{pmatrix}1\\2\\3\end{pmatrix},\ \begin{pmatrix}1\\3\\5\end{pmatrix}\right\}
\subseteq \mathbb{R}^3, \qquad \dim = 2 = r.$$

**Null space.** Solve $Ux = 0$: row 2 gives $x_3 = 0$; row 1 gives
$x_1 = -2x_2 - x_3 = -2x_2$; $x_2$ is free. Basis:
$$\left\{\begin{pmatrix}-2\\1\\0\end{pmatrix}\right\} \subseteq \mathbb{R}^3,
\qquad \dim = 1 = n - r = 3 - 2.$$

**Left null space.** Solve $A^Ty = 0$, equivalently find a combination of
the *rows* of $A$ that vanishes. From the row reduction, $R_2 - 2R_1$ and
$R_3 - 3R_1$ both produced $(0,0,1)$ and $(0,0,2)$ respectively (proportional
by a factor of 2), so $2(R_2 - 2R_1) - (R_3 - 3R_1) = 2R_2 - R_3 - R_1 = 0$,
i.e. $-1 \cdot R_1 + 2 \cdot R_2 - 1 \cdot R_3 = 0$. Check directly:
$$-1(1,2,1) + 2(2,4,3) - 1(3,6,5) = (-1+4-3,\ -2+8-6,\ -1+6-5) = (0,0,0). \checkmark$$
So $y = (-1, 2, -1)$ satisfies $y^TA = 0$. Basis:
$$\left\{\begin{pmatrix}-1\\2\\-1\end{pmatrix}\right\} \subseteq \mathbb{R}^3,
\qquad \dim = 1 = m - r = 3 - 2.$$

**Verify the Fundamental Theorem.** With $r = 2$, $n = 3$, $m = 3$:
row space $= C(A)$ dim $= 2 = r$ ✓; $\dim N(A) = 1 = n - r = 3-2$ ✓;
$\dim N(A^T) = 1 = m - r = 3-2$ ✓. As a bonus check on the pairing noted in
Definition 6.1: $\dim(\text{row space}) + \dim N(A) = 2 + 1 = 3 = n$, and
$\dim C(A) + \dim N(A^T) = 2 + 1 = 3 = m$ — both ambient spaces are exactly
accounted for.

## Unconventional edge

It is entirely possible to memorize "rank = number of pivots," "null space =
solutions to $Ax=0$," and "column space = span of the columns" as three
unrelated vocabulary words attached to three unrelated procedures, and this
is precisely the "disconnected recipes" failure mode this plan is designed
to block (see the design spec's mistakes table). The tell is if you can
compute all four subspaces correctly but can't say, without hesitation, why
the same number $r$ shows up in three of the four dimension formulas. Today's
proof exists to force the connection: one row reduction produces the pivots;
those pivots simultaneously hand you a basis for the row space (Lemma
6.1a), a basis for the column space (Lemma 6.1b), and — via a single prior
theorem, rank-nullity, applied twice — the dimensions of both null spaces.
If you ever find yourself re-deriving rank-nullity from scratch for a
null-space dimension question instead of reaching for the theorem you
proved on Day 4, that's a signal you're still treating these as separate
recipes rather than one computation viewed four ways.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–4 are computational (find all four subspaces by hand);
5–6 are pure dimension-counting (no row reduction needed); 7 is proof-based;
8 is a "explain in your own words" conceptual problem; 9 is a synthesis
problem tying the dimension formulas back to the worked example.

1. Let $A = \begin{pmatrix}1 & 2 & 3 \\ 2 & 4 & 6\end{pmatrix}$. Find a basis
   for each of the four fundamental subspaces, state their dimensions, and
   verify the Fundamental Theorem's counts against $r$, $m = 2$, $n = 3$.
2. Let $A = \begin{pmatrix}1 & 0 \\ 0 & 1 \\ 1 & 1\end{pmatrix}$. Find a basis
   for each of the four fundamental subspaces. What do you notice about
   $N(A)$? Confirm it's consistent with $r$ and $n$.
3. Let $A = \begin{pmatrix}1 & 2 & -1 \\ 2 & 4 & 1 \\ 1 & 2 & 2\end{pmatrix}$.
   Find a basis for each of the four fundamental subspaces and verify the
   Fundamental Theorem's counts.
4. Let $A = \begin{pmatrix}1 & 0 & 2 & 1 \\ 0 & 1 & 1 & -1\end{pmatrix}$.
   Find a basis for each of the four fundamental subspaces. What do you
   notice about $N(A^T)$? Confirm it's consistent with $r$ and $m$.
5. Suppose $A$ is a $5 \times 7$ matrix with $\operatorname{rank}(A) = 4$,
   but you are not given $A$ itself. State the dimension of each of the four
   fundamental subspaces, and say which of $\mathbb{R}^5$ or $\mathbb{R}^7$
   each one is a subspace of.
6. Suppose $B$ is a $6 \times 4$ matrix with $\operatorname{rank}(B) = 4$
   (the maximum possible, since rank $\le \min(m,n)$). What is $N(B)$
   exactly? What is $\dim N(B^T)$?
7. Prove: if $A$ is a square $n \times n$ invertible matrix, then
   $N(A) = \{0\}$ and $N(A^T) = \{0\}$.
8. In your own words (2–4 sentences, no new computation), explain why
   $\operatorname{rank}(A) = \operatorname{rank}(A^T)$ for every matrix $A$.
9. Using only $r = 2$, $n = 3$, $m = 3$ from the worked example above (do
   *not* redo the row reduction), predict $\dim N(A)$ and $\dim N(A^T)$ from
   the Fundamental Theorem alone. Confirm your prediction matches the
   explicit bases found in the worked example.

## Solutions

**1.** $R_2 \to R_2 - 2R_1$ gives $(0,0,0)$, so $U = \begin{pmatrix}1&2&3\\0&0&0\end{pmatrix}$,
$r = 1$.
- Row space: basis $\{(1,2,3)\} \subseteq \mathbb{R}^3$, $\dim = 1$.
- Column space: pivot column 1 of $A$: basis $\left\{\binom{1}{2}\right\}
  \subseteq \mathbb{R}^2$, $\dim = 1$.
- Null space: $x_1 + 2x_2 + 3x_3 = 0 \implies x_1 = -2x_2 - 3x_3$, $x_2, x_3$
  free. Basis $\left\{\begin{pmatrix}-2\\1\\0\end{pmatrix},
  \begin{pmatrix}-3\\0\\1\end{pmatrix}\right\} \subseteq \mathbb{R}^3$,
  $\dim = 2$.
- Left null space: $y_1 (1,2,3) + y_2(2,4,6) = (y_1+2y_2)(1,2,3) = 0
  \implies y_1 = -2y_2$. Basis $\left\{\binom{-2}{1}\right\} \subseteq
  \mathbb{R}^2$, $\dim = 1$.
- Check: $r=1$; $\dim N(A) = n-r = 3-1=2$ ✓; $\dim N(A^T) = m-r=2-1=1$ ✓;
  row+null $=1+2=3=n$ ✓; col+left-null $=1+1=2=m$ ✓.

**2.** $R_3 \to R_3 - R_1$ gives $(0,1)$; then $R_3 \to R_3 - R_2$ gives
$(0,0)$. $U = \begin{pmatrix}1&0\\0&1\\0&0\end{pmatrix}$, $r = 2$ (both
columns are pivot columns).
- Row space: basis $\{(1,0),(0,1)\} \subseteq \mathbb{R}^2$ (i.e. row space
  is all of $\mathbb{R}^2$), $\dim = 2$.
- Column space: both columns of $A$ are pivot columns: basis
  $\left\{\begin{pmatrix}1\\0\\1\end{pmatrix},
  \begin{pmatrix}0\\1\\1\end{pmatrix}\right\} \subseteq \mathbb{R}^3$,
  $\dim = 2$.
- Null space: with both columns pivots, $Ux=0$ forces $x_1=x_2=0$, so
  $N(A) = \{0\}$. This matches $\dim N(A) = n - r = 2 - 2 = 0$: since $A$
  has full *column* rank, its null space is trivial.
- Left null space: $A^Ty=0$: $y_1+y_3=0$, $y_2+y_3=0 \implies y_1=y_2=-y_3$.
  Basis $\left\{\begin{pmatrix}-1\\-1\\1\end{pmatrix}\right\} \subseteq
  \mathbb{R}^3$, $\dim = 1 = m-r=3-2$.
- Check: row+null$=2+0=2=n$ ✓; col+left-null$=2+1=3=m$ ✓.

**3.** $R_2 \to R_2-2R_1$ gives $(0,0,3)$; $R_3 \to R_3-R_1$ gives $(0,0,3)$;
then $R_3 \to R_3-R_2$ gives $(0,0,0)$. $U = \begin{pmatrix}1&2&-1\\0&0&3\\0&0&0\end{pmatrix}$,
pivots in columns 1 and 3, $r=2$.
- Row space: basis $\{(1,2,-1),(0,0,1)\}$ (scaling row 2), $\dim=2$.
- Column space: pivot columns 1, 3 of $A$: basis
  $\left\{\begin{pmatrix}1\\2\\1\end{pmatrix},
  \begin{pmatrix}-1\\1\\2\end{pmatrix}\right\}$, $\dim=2$.
- Null space: from $U$: $3x_3=0 \implies x_3=0$; $x_1+2x_2-x_3=0 \implies
  x_1=-2x_2$; $x_2$ free. Basis $\left\{\begin{pmatrix}-2\\1\\0\end{pmatrix}\right\}$,
  $\dim=1=n-r=3-2$.
- Left null space: looking for a combination of rows of $A$ that vanishes.
  $(R_2-2R_1) - (R_3-R_1) = R_2 - R_3 - R_1 = 0$, i.e.
  $-1\cdot(\text{row }1) + 1\cdot(\text{row }2) - 1\cdot(\text{row }3) = 0$.
  Check: $-(1,2,-1)+(2,4,1)-(1,2,2) = (0,0,0)$ ✓. Basis
  $\left\{\begin{pmatrix}-1\\1\\-1\end{pmatrix}\right\}$, $\dim=1=m-r=3-2$.
- Check: row+null$=2+1=3=n$ ✓; col+left-null$=2+1=3=m$ ✓.

**4.** $A$ is already in reduced echelon form with pivots in columns 1, 2;
$r=2$.
- Row space: basis $\{(1,0,2,1),(0,1,1,-1)\} \subseteq \mathbb{R}^4$,
  $\dim=2$.
- Column space: pivot columns 1, 2 of $A$: basis $\left\{\binom{1}{0},
  \binom{0}{1}\right\} \subseteq \mathbb{R}^2$ — i.e. $C(A) = \mathbb{R}^2$
  entirely, $\dim = 2$.
- Null space: $x_1 = -2x_3-x_4$, $x_2=-x_3+x_4$, $x_3,x_4$ free. Basis
  $\left\{\begin{pmatrix}-2\\-1\\1\\0\end{pmatrix},
  \begin{pmatrix}-1\\1\\0\\1\end{pmatrix}\right\} \subseteq \mathbb{R}^4$,
  $\dim=2=n-r=4-2$.
- Left null space: $r = m = 2$ (full *row* rank — the two rows are already
  independent pivot rows with nothing left over), so by the Fundamental
  Theorem $\dim N(A^T) = m-r = 2-2=0$, i.e. $N(A^T)=\{0\}$. This is the
  mirror image of Exercise 2: full row rank forces a trivial left null
  space, just as full column rank forced a trivial (ordinary) null space.
- Check: row+null$=2+2=4=n$ ✓; col+left-null$=2+0=2=m$ ✓.

**5.** $\dim(\text{row space}) = \dim C(A) = r = 4$. Row space $\subseteq
\mathbb{R}^7$ ($n=7$), dim 4. $C(A) \subseteq \mathbb{R}^5$ ($m=5$), dim 4.
$\dim N(A) = n - r = 7 - 4 = 3$, and $N(A) \subseteq \mathbb{R}^7$.
$\dim N(A^T) = m - r = 5 - 4 = 1$, and $N(A^T) \subseteq \mathbb{R}^5$.

**6.** $\operatorname{rank}(B) = 4 = n$ (the number of columns), so
$\dim N(B) = n - r = 4 - 4 = 0$, i.e. $N(B) = \{0\}$ exactly (full column
rank). $\dim N(B^T) = m - r = 6 - 4 = 2$.

**7.** *Direct argument.* Suppose $Ax = 0$. Since $A$ is invertible, multiply
both sides on the left by $A^{-1}$: $A^{-1}(Ax) = A^{-1}0 \implies
(A^{-1}A)x = 0 \implies Ix = 0 \implies x = 0$. So $N(A) = \{0\}$.

For $A^T$: since $A$ is invertible, $A^{-1}$ exists with $AA^{-1} = A^{-1}A
= I$. Transposing, $(AA^{-1})^T = (A^{-1})^T A^T = I^T = I$ and similarly
$A^T(A^{-1})^T = I$, so $A^T$ is invertible with $(A^T)^{-1} = (A^{-1})^T$.
Applying the same argument as above with $A^T$ in place of $A$: $A^Ty = 0
\implies y = (A^T)^{-1}(A^Ty) = (A^T)^{-1}0 = 0$. So $N(A^T) = \{0\}$.

*Cross-check via the Fundamental Theorem.* An invertible $n\times n$ matrix
has $\operatorname{rank}(A) = n$ (its columns must span $\mathbb{R}^n$,
since $A$ is onto — for every $b$, $Ax=b$ has the solution $x=A^{-1}b$ — so
$C(A) = \mathbb{R}^n$ forces $r=n$). With $m=n=r$: $\dim N(A) = n-r=0$ and
$\dim N(A^T)=m-r=0$, agreeing with the direct argument.

**8.** Row reducing $A$ to echelon form $U$ makes both the row rank and
column rank of $A$ visible at once: the number of pivots $r$ simultaneously
(i) counts the nonzero (independent, spanning) rows of $U$, which is
$\dim(\text{row space})$, and (ii) marks $r$ columns of the *original* $A$
that are independent and span $C(A)$, because every other column of $A$
is forced — by the very same row operations, which preserve $Ax=0 \iff
Ux=0$ — to be that same combination of pivot columns as it is in $U$. Since
both quantities come out of the identical set of pivots from one
computation, they can't help but be equal: $\operatorname{rank}(A) =
\operatorname{rank}(A^T)$ is not a coincidence to verify separately, it's a
restatement of what the pivots already told you.

**9.** With $r=2$, $n=3$: $\dim N(A) = n-r = 3-2=1$. With $r=2$, $m=3$:
$\dim N(A^T) = m-r=3-2=1$. Both predictions match the worked example, where
$N(A) = \operatorname{span}\{(-2,1,0)\}$ (dimension 1) and
$N(A^T) = \operatorname{span}\{(-1,2,-1)\}$ (dimension 1).

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab computes all four fundamental subspaces numerically and checks
the dimension formulas from Theorem 6.1 automatically, rather than doing it
by hand as above. Open `starter_code/day06_four_subspaces.py` — it has one
function to complete, `fundamental_subspaces`. Fill in the `TODO`, then run
the file directly (`python starter_code/day06_four_subspaces.py`); it should
print `All dimension checks passed!` followed by the rank.

**Hint:** `scipy.linalg.orth(A)` returns an orthonormal basis for the column
space of `A` as the columns of a matrix (so `orth(A.T)` gives a basis for
the row space, since the row space of `A` is the column space of `A.T`).
`scipy.linalg.null_space(A)` returns a basis for the null space of `A` as
the columns of a matrix (so `null_space(A.T)` gives a basis for the left
null space). This is the direct numerical analogue of what you did by hand:
`orth`/`null_space` under the hood do something equivalent to the
row-reduction-plus-pivot-tracking from the Theory section, just via a more
numerically stable algorithm (SVD) that you'll meet properly around Day 21.

Once your implementation passes, do the extension at the bottom of the
file: run it on a random $4\times3$ matrix and a random $3\times4$ matrix,
and confirm the dimension counts still satisfy the Fundamental Theorem in
each case. (Random matrices are generically full rank, so pick the shapes
so that $r = \min(m,n)$ is the expected outcome, and check that one of the
null spaces you'd expect to be trivial actually comes out empty—width-0.)

If you get stuck for more than ~10 minutes, check
`solutions/day06_four_subspaces.py` — but only after a real attempt.

## Journal template

```
## Day 6 — Four fundamental subspaces
Key theorem in my own words: ...
What confused me: ...
```
