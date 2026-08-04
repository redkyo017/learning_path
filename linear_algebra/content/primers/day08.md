# Day 8 Primer — Determinants

## Warm-up

Before diving into determinant theory, reconnect with three foundational ideas that make today's story land hard and stick. 

On Day 6, you discovered that invertibility lives in the language of the four fundamental subspaces. A square matrix $A$ is invertible exactly when it has full rank, meaning a pivot in every row and column. When that happens, the column space fills all of $\mathbb{R}^n$, the null space shrinks to just $\{0\}$, and the row space also has dimension $n$. Invertibility is a binary thing: either you have full rank or you don't.

On Day 5, you learned the computational workhorse for measuring rank: row-reduce and count nonzero pivots. Elementary row operations preserve rank, so the rank you measure is intrinsic to the matrix. You saw that singular matrices have deficient rank, and you learned to spot them by recognizing a zero row in echelon form.

And on Day 1, you saw that every matrix defines a linear transformation. Multiplying $x$ by $A$ sends vectors in $\mathbb{R}^n$ to new locations in $\mathbb{R}^n$. The matrix is the transformation.

Today, you'll answer a geometric question about that transformation: how much does it stretch or shrink *volume*? The answer is one single number that predicts everything about invertibility *before* you row-reduce a single time. You'll see why that number (the determinant) has the formula it does, not because formulas are discovered by divine decree, but because three axioms about how volume *must* behave mathematically *force* it.

## The hook

Take the matrix $A=\begin{pmatrix}3&1\\1&2\end{pmatrix}$ and think concretely about where it sends the unit square in $\mathbb{R}^2$.

The unit square has corners at $(0,0)$, $(1,0)$, $(1,1)$, and $(0,1)$, with area $1$.

When you apply $A$ to this square, the corners move to $(0,0)$, $(3,1)$, $(4,3)$, and $(1,2)$. These four points form a slanted parallelogram—not a rectangle anymore, but a four-sided shape with parallel opposite sides.

What's its area? You can compute it using the shoelace formula or cross products, and the answer is: area $= 3 \cdot 2 - 1 \cdot 1 = 5$. That's it—one number. One number told you the volume-scaling factor of the transformation. One number predicts whether $A$ is invertible (it is, since $5 \neq 0$).

Now imagine a singular matrix like $B=\begin{pmatrix}1&2\\1&2\end{pmatrix}$, where the second row is exactly twice the first.

Apply $B$ to the same unit square. The image collapses to a one-dimensional line segment—a line through the origin in the direction $(1,2)$.

The "area" is zero. Literally no 2D volume remains. The determinant of $B$ is zero. One number captures the entire catastrophe: the square squashed flat.

This is your bridge: the determinant measures *how much volume changes under the transformation*. And—crucially—zero determinant means the transformation is not invertible. It's flattened something into a lower dimension, and you can't unflatten it.

## The pictures

**Picture 1: Volume scaling (2D case)**

Start with the unit square in the $xy$-plane, corners at $(0,0)$, $(1,0)$, $(1,1)$, $(0,1)$.

Under $A=\begin{pmatrix}3&1\\1&2\end{pmatrix}$, the corners map to $(0,0)$, $(3,1)$, $(4,3)$, $(1,2)$ respectively, forming a slanted parallelogram.

Draw this parallelogram clearly, and label its area: "$\det(A)=5$."

To the right, show the singular case: $B=\begin{pmatrix}1&2\\1&2\end{pmatrix}$ collapses the entire square to a line segment from $(0,0)$ in the direction $(1,2)$.

A one-dimensional line has no 2D area. Label: "$\det(B)=0$."

**Picture 2: Sign and orientation**

Two side-by-side $2 \times 2$ matrices visualized as row vectors.

On the left, the identity matrix with rows $(1,0)$ and $(0,1)$ forms a right-angled coordinate frame—think of the positive $x$-axis and positive $y$-axis forming a right-handed frame (like your right hand curling from $x$ to $y$).

On the right, the rows are swapped: $(0,1)$ and $(1,0)$, still perpendicular but now the axes are labeled in reverse order—this is left-handed (mirrored, like your left hand).

Label the left determinant as $+1$ and the right as $-1$.

The *sign* change tracks whether orientation flipped.

**Picture 3: Multiplicativity under composition**

A composition of two transformations shown as a sequence.

First, apply matrix $B$ to the unit cube in $\mathbb{R}^3$. It scales volume by a factor of $\det(B)$.

The resulting region (possibly skewed) has volume $|\det(B)|$ relative to the original unit cube.

Then apply matrix $A$ to that region. Every volume element gets scaled by $\det(A)$.

The total volume is now $\det(A) \cdot \det(B)$ times the original.

This is why $\det(AB)=\det(A)\det(B)$ *must* hold before any algebra—the volumes must multiply.

## Concrete-first walkthrough

Start with Definition 8.1: the determinant is defined not by a formula dropped from the sky, but by three algebraic properties that any sensible "volume" function must satisfy.

**(1) Multilinearity in each row:** The map $v \mapsto \det(r_1, \ldots, r_{i-1}, v, r_{i+1}, \ldots, r_n)$ is linear in the $i$-th row. Concretely, if you scale row $i$ by $c$, the determinant scales by $c$—volume scales linearly with one dimension. If you add a multiple of one row to another, the determinant is unchanged—shearing a box doesn't change its volume.

**(2) Alternating (degeneracy condition):** If any two rows of $A$ are equal, then $\det(A)=0$. If two rows are identical, the matrix is degenerate—it can't span the full space, so the "volume" must be zero.

**(3) Normalization:** $\det(I_n)=1$. The unit cube has volume one, so the identity should scale volume by $1$.

These three axioms, taken together, uniquely determine one function. No formula first—just properties that any volume must obey. The formula follows from the properties.

Definition 8.2 gives you the hand-computation recipe: **cofactor expansion along a row** (or column).

To compute $\det(A)$, pick row $i$. For each column $j$, form the $(i,j)$-cofactor: delete row $i$ and column $j$ to get a minor matrix $A_{(i,j)}$, multiply its determinant by $(-1)^{i+j}$ (a sign that alternates based on position), then multiply by the original entry $a_{ij}$. Sum all these terms across the row.

A remarkable fact: all $2n$ choices of row or column give the same answer. You can expand along any row or any column, and you'll get $\det(A)$.

**Lemma 8.1** is immediate and worth saying aloud: if any row is all zeros, expand along that row and every term in the expansion is zero times something, so the whole determinant is zero.

**Lemma 8.2** is the power tool—it shows exactly how the three row operations (Definition 5.1 from Day 5) affect the determinant.

**(1) Row swap** multiplies the determinant by $-1$. The volume sign flips. Orientation flips.

**(2) Scale row $i$ by $c \neq 0$** multiplies the determinant by $c$. Volume scales proportionally.

**(3) Add a multiple of row $k$ to row $i$** leaves the determinant **completely unchanged**. This is critical—say it twice: *shear does nothing*. This is why row reduction preserves whether the determinant is zero or nonzero. Shearing and scaling by nonzero are all that matter, and swaps just flip the sign.

**Definitions 8.3** introduces elementary matrices: $P_{ik}$ performs a row swap, $S_i(c)$ scales row $i$, $T_{ik}(c)$ adds a multiple of row $k$ to row $i$. These are just the identity matrix with one row operation applied—they embody the operations as matrices.

**Lemma 8.3** says that left-multiplying $B$ by an elementary matrix $E$ performs that row operation on $B$: $EB$ is $B$ with the operation done. This makes row operations composable and trackable.

**Corollary 8.1** combines this with Lemma 8.2: $\det(EB)=\det(E)\det(B)$. Since $\det(P_{ik})=-1$, $\det(S_i(c))=c$, and $\det(T_{ik}(c))=1$, each elementary matrix's determinant is exactly its volume effect.

**Lemma 8.5** is a computational shortcut that saves hours: for an upper triangular matrix $T$, $\det(T) = T_{11} \cdot T_{22} \cdots T_{nn}$—product of diagonal entries, nothing more.

The proof expands down the first column. Only the top-left entry $T_{11}$ is nonzero in that column in a triangular matrix, so only one term survives.

Then induction handles the rest recursively.

**Theorem 8.2** is the capstone: $A$ is invertible if and only if $\det(A) \neq 0$. This connects the determinant directly to Day 5's rank and Day 6's invertibility.

The proof row-reduces $A$ to echelon form $R$ (which is triangular). Since each row operation scales det by a nonzero factor (Corollary 8.1), $\det(A)$ is zero iff $\det(R)$ is zero.

By Lemma 8.5, $\det(R)$ is the diagonal product, which is nonzero iff all diagonal entries are nonzero iff $R$ has $n$ pivots iff $A$ has full rank iff $A$ is invertible.

## Proof roadmaps

**Lemma 8.2 (row swap, the hard case):** The trick, which almost no one discovers without guidance, is to build a matrix $B$ with $u+v$ in both rows $i$ and $k$ simultaneously, then expand by linearity.

Since $B$ has two equal rows, the alternating axiom gives $\det(B)=0$.

Now expand in row $i$ first (holding row $k$ fixed at $u+v$): two terms appear.

Expand each term in row $k$: four terms total, but two vanish immediately (equal rows again).

The survivors give $\det(A) + \det(A') = 0$. Thus $\det(A') = -\det(A)$.

The magic: you *assumed* two equal rows give zero, then forced the swap rule out of that assumption.

**Theorem 8.1 ($\det(AB)=\det(A)\det(B)$):** Split into cases.

If either factor is singular, both sides are zero (column space of $AB$ is contained in column space of $A$; row space of $AB$ is contained in row space of $B$; so $AB$ is singular too).

If $A$ is invertible, row-reduce to $I$: elementary matrices $E_1, \ldots, E_m$ satisfy $E_m \cdots E_1 A = I$, so $A = E_1^{-1} \cdots E_m^{-1}$. Each inverse is elementary.

Peel factors from the left using Corollary 8.1 repeatedly: $\det(AB)=\det(E_1)\det(E_2 \cdots E_m B)=\cdots=\det(E_1)\cdots\det(E_m)\det(B)$.

The product $\det(E_1)\cdots\det(E_m)$ is exactly $\det(A)$ by applying the same peeling to $A \cdot I$.

**Lemma 8.5 (triangular det, by induction):** Expand down column 1 of an upper triangular matrix $T$.

Every entry below $T_{11}$ is zero, so only the top-left term survives: $\det(T) = T_{11} \cdot \det(T_{(1,1)})$.

The minor $T_{(1,1)}$ (the lower-right block after deleting row 1 and column 1) is also upper triangular with diagonal $T_{22}, \ldots, T_{nn}$.

By induction, its determinant is that diagonal product. Multiply in $T_{11}$ to finish.

**Theorem 8.2 (invertible ⟺ det ≠ 0):** Row-reduce $A$ to echelon form $R$.

Row operations scale det by nonzero factors only (Corollary 8.1), so $\det(A) \neq 0 \iff \det(R) \neq 0$.

The echelon form $R$ is upper triangular. By Lemma 8.5, $\det(R)$ is the diagonal product.

This product is nonzero iff all diagonal entries are nonzero iff $R$ has $n$ pivots iff $R$ has full rank iff $A$ has full rank (rank is preserved by row operations) iff $A$ is invertible.

## Flashcards

### Flashcards

**Q:** What are the three determinant axioms, in plain language?

**A:** Linear in each row (scale row by $c$ → scale det by $c$; add one row to another → det unchanged). Zero when degenerate (two equal rows or a zero row → det is zero). Normalization ($\det(I_n)=1$).

**Q:** How do the three row operations affect the determinant?

**A:** Swap rows: multiply det by $-1$. Scale row $i$ by $c$: multiply det by $c$. Add a multiple of row $k$ to row $i$: no change (det unchanged).

**Q:** Which row operation is "free" and why does that matter?

**A:** Shear (add a multiple of one row to another) leaves det unchanged. This is why you can row-reduce to echelon form without changing whether det is zero — only swaps and scalings introduce factors.

**Q:** What is the determinant of a triangular matrix?

**A:** Product of the diagonal entries. If $T$ is upper (or lower) triangular, $\det(T) = T_{11} \cdot T_{22} \cdots T_{nn}$ by Lemma 8.5.

**Q:** What is $\det(AB)$ in terms of $\det(A)$ and $\det(B)$?

**A:** $\det(AB)=\det(A)\cdot\det(B)$ (Theorem 8.1). Volume factors multiply when you compose transformations.

**Q:** What does it mean geometrically when $\det(A)=0$?

**A:** The unit cube gets flattened to a lower-dimensional object (a line, a plane, etc.). The map loses full rank and is not invertible — no way to reverse the squashing.

**Q:** What does the sign of $\det(A)$ measure?

**A:** Orientation. If $\det(A) > 0$, the transformation preserves orientation (right-handed stays right-handed). If $\det(A) < 0$, it flips orientation (mirrors the space, reversing handedness).

**Q:** What is the fastest hand method to compute a determinant for a $3 \times 3$ or larger matrix?

**A:** Row-reduce to upper triangular form, tracking the sign of each row swap and the scalar factor of each row scaling. At the end, multiply the diagonal of the final triangular matrix and apply the correction factor from the row operations — this is faster than cofactor expansion.

