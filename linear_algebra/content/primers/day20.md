# Day 20 Primer — Quadratic forms, positive definiteness

## Warm-up

Before diving into today's theory, refresh three foundational ideas that make everything click.
First, Day 19's Spectral Theorem: any symmetric matrix $A$ can be written as $A = Q\Lambda Q^T$, where $Q$ is an orthogonal matrix whose columns are orthonormal eigenvectors of $A$, and $\Lambda$ is diagonal with the eigenvalues $\lambda_1, \ldots, \lambda_n$ (possibly repeated) along the diagonal.
This decomposition always exists for symmetric matrices — one of linear algebra's most powerful guarantees.
The Spectral Theorem is the foundation for everything today.

Second, Day 17's key insight about orthogonal matrices: they are "rigid" transformations.
Multiplying by an orthogonal matrix $Q$ preserves lengths ($\|Qx\| = \|x\|$ for all $x$) and inner products ($(Qx)^T(Qy) = x^Ty$ for all $x, y$).
This rigidity means that changing coordinates by an orthogonal matrix is just a rotation or reflection — the geometry stays the same, only your viewpoint rotates.
Crucially, orthogonal matrices are invertible with inverse $Q^{-1} = Q^T$, giving bijective coordinate transformations.

Third, Day 12's central trick: transforming to the eigenvector basis makes hidden structure transparent.
When you write a matrix operation in its eigenbasis, hard questions become simple because the basis vectors are aligned with the matrix's natural axes of growth and decay.
Today you will use all three ideas together.
You apply Day 12's trick — rotate to the eigenvector basis — to classify the shape of a quadratic form: Does the surface $z = x^TAx$ form a bowl (opening upward, all eigenvalues positive), a saddle (mixed signs on eigenvalues), or a dome (opening downward, all eigenvalues negative)?
The remarkable answer is that the eigenvalue signs alone determine the entire shape.
By rotating to the eigenvector basis, you will see why this is true and how to read off the classification instantly.

## The hook

Here is a false intuition that trips every self-learner at some point.
Consider the quadratic form $q(x, y) = x^2 + 4xy + y^2$.
By superficial inspection, you see only squared terms and a positive cross-term coefficient: "Both $x^2$ and $y^2$ are positive, and $4xy$ looks positive too!"
Your intuition shouts that this must always be positive!
Surely a sum of squares times positive numbers cannot go negative?
But intuition fails catastrophically here.
Test it at a single point.
Plug in $(x, y) = (1, -1)$:
$$q(1, -1) = 1^2 + 4(1)(-1) + (-1)^2 = 1 - 4 + 1 = -2.$$
Negative!
How is this possible?
The cross term $4xy$ carries hidden structure that your eye cannot see by staring at coefficients.
When you choose a direction where $x$ and $y$ have opposite signs, the cross term becomes large and negative, overwhelming the positive squares.
The eye cannot price this cost in advance.
This is a critical lesson: the signs of matrix entries do not determine the sign behavior of the quadratic form.

Here is the machine that never falls for this trap: rewrite $q(x, y)$ as a quadratic form $q(x) = x^TAx$ with a symmetric matrix $A$.
In this case, $A = \begin{pmatrix}1&2\\2&1\end{pmatrix}$ (the diagonal entries are the coefficients of $x^2$ and $y^2$; the off-diagonal entry is half the cross-term coefficient, so $2 \times 2 \times x_1 x_2 = 4x_1 x_2$).
Now compute the eigenvalues via the characteristic polynomial: $\det(A - \lambda I) = (1-\lambda)^2 - 4 = \lambda^2 - 2\lambda - 3 = (\lambda - 3)(\lambda + 1)$, yielding eigenvalues $\lambda_1 = 3$ and $\lambda_2 = -1$.
A single fact — one eigenvalue is negative — guarantees that a downhill direction exists.
You can find a vector where the form is negative.
Try it: the eigenvector for $\lambda = -1$ has the form $\begin{pmatrix}1\\-1\end{pmatrix}$ (or any nonzero scalar multiple).
Plug it in: $1 - 4 + 1 = -2$, exactly as predicted.
The eigenvalue signs reveal whether downhill or uphill directions exist.
Today's entire theoretical edifice boils down to this: the eigenvalue signs tell you everything about the shape.

## The pictures

Imagine three archetypal surfaces floating above the $(x, y)$-plane.
Picture the first: a smooth bowl (paraboloid opening upward), like $z = x^2 + y^2$ with eigenvalues $\lambda_1 = 1, \lambda_2 = 1$ (both positive).
If you slice this surface horizontally with planes $z = c$ for positive constants $c$, you get concentric circles (or ellipses when the eigenvalues differ in magnitude).
The form is always nonnegative, and strictly positive everywhere except at the origin.
This is the positive definite case — the defining property of a bowl-shaped surface.
The larger the absolute eigenvalue, the steeper the curvature in that direction.

Picture the second: a saddle surface, like $z = x^2 - y^2$ with eigenvalues $\lambda_1 = 1, \lambda_2 = -1$ (mixed signs).
If you slice it horizontally, you get hyperbolas that never close — they open to infinity in certain directions.
The form takes positive values in some directions (along the $x$-axis, where the $x^2$ term dominates) and negative values in others (along the $y$-axis, where the $-y^2$ term dominates).
This is the indefinite case — a surface that rises in one direction and falls in another, like an actual saddle or mountain pass.
If you rode a horse across it, you'd climb in one direction and descend in the perpendicular direction.

Picture the third: a smooth dome (paraboloid opening downward), like $z = -x^2 - y^2$ with eigenvalues $\lambda_1 = -1, \lambda_2 = -1$ (both negative).
If you slice it horizontally for negative constants $z = c < 0$, you again get concentric ellipses, but now you are slicing below the apex.
The form is always nonpositive, and strictly negative everywhere except at the origin.
This is the negative definite case — geometrically the inverse of the bowl.
You stand on top of the dome looking down.

Why do these three archetypal shapes exhaust all possibilities?
The Spectral Theorem (Day 19, Thm 19.1) tells you why: rotate to the eigenvector basis using the substitution $y = Q^Tx$, where $Q$ contains the eigenvectors as columns.
In that new coordinate system, the quadratic form becomes $\sum_i \lambda_i y_i^2$ — purely a weighted sum of squares, with no cross terms to confuse you.
In this form, the shape is self-evident.
Each positive eigenvalue $\lambda_i$ contributes a $+\lambda_i y_i^2$ term that bends the surface upward along the $i$-th eigenvector axis.
Each negative eigenvalue contributes a downward bend.
Mixed signs create the saddle.
The Spectral Theorem guarantees that every symmetric matrix's quadratic form looks exactly like one of these three pictures once you view it through the eigenvector coordinate system.

## Concrete-first walkthrough

Start with Definition 20.1 from the main text: the quadratic form associated to an $n \times n$ symmetric matrix $A$ is the function $Q(x) = x^TAx$ for vectors $x \in \mathbb{R}^n$.
Expanding the sum, $x^TAx = \sum_{i=1}^n \sum_{j=1}^n A_{ij} x_i x_j$, a weighted sum of products of coordinates.
Geometrically, think of this as the "energy" or "score" that matrix $A$ assigns to each direction $x$.
The value $Q(x)$ tells you how "favorably" the matrix $A$ views the direction $x$.
A larger positive value rewards that direction strongly; a negative value penalizes it.

Why insist on symmetric $A$?
Because for any square matrix $M$, the equation $x^TMx = x^T\left(\frac{1}{2}(M + M^T)\right)x$ always holds (a short check using transpose rules on a scalar), so every quadratic form is equivalent to the quadratic form of some symmetric matrix.
You lose no generality by restricting to symmetric $A$ — you gain clarity and the power of the Spectral Theorem (Day 19, Thm 19.1), which applies only to symmetric matrices.
In particular, only symmetric matrices admit the diagonal form $A = Q\Lambda Q^T$ with orthogonal $Q$.

Next, Definition 20.2 divides all symmetric matrices into five exhaustive classes (mutually exclusive except the zero matrix).
A matrix $A$ is positive definite if $x^TAx > 0$ for all nonzero $x$ — the form is always strictly positive, the signature of a bowl.
It is negative definite if $x^TAx < 0$ for all nonzero $x$ — always strictly negative, a dome.
It is positive semidefinite if $x^TAx \geq 0$ for all $x$ (weak inequality, allowing zero even at nonzero vectors) — think of a flat-bottomed valley where the form can touch zero along a whole line or plane.
It is negative semidefinite if $x^TAx \leq 0$ for all $x$.
Finally, $A$ is indefinite if both positive and negative values occur — the saddle.
A subtle but crucial point: positive definite is a strict special case of positive semidefinite (all eigenvalues positive is a special case of all eigenvalues nonnegative).
Always report the strongest label that applies — if a matrix is positive definite, call it that, not merely semidefinite.

Theorem 20.1 and Corollary 20.1 are the heart of today.
Theorem 20.1 (Def 20.1, Thm 20.1) states: $A$ is positive definite if and only if every eigenvalue of $A$ is strictly positive.
Corollary 20.1 generalizes to all five cases: all eigenvalues $\geq 0$ $\Rightarrow$ positive semidefinite; all eigenvalues $< 0$ $\Rightarrow$ negative definite; all eigenvalues $\leq 0$ $\Rightarrow$ negative semidefinite; both positive and negative eigenvalues present $\Rightarrow$ indefinite.
The practical payoff is stark: to classify a symmetric matrix, compute its eigenvalues and check their signs.
Diagonal entries and off-diagonal entries, taken alone or together, tell you nothing reliable.
The Unconventional edge trap from the main text exemplifies this: $A = \begin{pmatrix}1&3\\3&1\end{pmatrix}$ has positive diagonal entries (both 1's), yet its characteristic polynomial is $(1-\lambda)^2 - 9 = \lambda^2 - 2\lambda - 8 = (\lambda-4)(\lambda+2)$, giving eigenvalues 4 and $-2$.
Mixed signs mean indefinite — not positive definite, despite all positive diagonal entries.
This is why diligent learners compute eigenvalues: the diagonal alone lies.

## Proof roadmaps

The proof of Theorem 20.1 hinges entirely on one move: rotate to the eigenvector basis and read off the definiteness class.
Here is the roadmap.
By the Spectral Theorem (Day 19, Thm 19.1), decompose $A = Q\Lambda Q^T$, where $Q$ is orthogonal (its columns are orthonormal eigenvectors of $A$) and $\Lambda = \operatorname{diag}(\lambda_1, \ldots, \lambda_n)$ has eigenvalues on the diagonal.
Introduce a new coordinate vector $y = Q^Tx$.
Since $Q$ is square and orthogonal, the map $x \mapsto y$ is invertible with inverse $y \mapsto x = Qy$.
The crucial observation: $Q$ has trivial kernel (any orthogonal matrix is invertible), so $x \neq 0 \iff y \neq 0$ (Day 17, Cor 17.1).
This nonzero preservation is essential.
Substitute into the quadratic form: $$x^TAx = x^T(Q\Lambda Q^T)x = (Q^Tx)^T \Lambda (Q^Tx) = y^T\Lambda y = \sum_{i=1}^n \lambda_i y_i^2.$$
The quadratic form in the eigenvector basis is now a pure weighted sum of squares — no cross terms, complete transparency.
Every term is a perfect square weighted by an eigenvalue.

If every eigenvalue $\lambda_i > 0$, then for any nonzero $y$, at least one coordinate $y_k$ is nonzero.
This gives $\lambda_k y_k^2 > 0$ (positive $\lambda_k$ times positive $y_k^2$).
All other terms satisfy $\lambda_i y_i^2 \geq 0$ (positive $\lambda_i$ times nonnegative square).
The entire sum is strictly positive.
Since the map $x \mapsto y$ preserves nonzero status ($x \neq 0 \iff y \neq 0$), every nonzero $x$ yields $x^TAx > 0$, so $A$ is positive definite by Definition 20.2.
For the converse, if some eigenvalue $\lambda_k \leq 0$, take $y = e_k$ (the $k$-th standard basis vector in $y$-space), which corresponds to $x = Qe_k$ in $x$-space (a nonzero eigenvector of $A$ for eigenvalue $\lambda_k$).
Then $x^TAx = \sum_i \lambda_i (e_k)_i^2 = \lambda_k \leq 0$, violating the positive definite requirement.
This completes the proof, showing that $A$ is positive definite if and only if all eigenvalues are strictly positive.

Corollary 20.1 applies the identical coordinate rotation $y = Q^Tx$ to derive the other four cases.
For negative definite, reverse every inequality: all $\lambda_i < 0$ makes every term negative (when $y \neq 0$), so the sum is negative.
For positive semidefinite, all $\lambda_i \geq 0$ makes every term nonnegative for any $y$ (even $y=0$), so $x^TAx \geq 0$ always.
For negative semidefinite, mirror this: all $\lambda_i \leq 0$.
For indefinite, you need both signs present: if $\lambda_j > 0$ and $\lambda_k < 0$, plug in $y = e_j$ to get a positive value and $y = e_k$ to get a negative value, exhibiting the required mixed signs concretely.
The beauty of this proof is that it reduces all five cases to the same rotating-and-reading-off technique.

## Flashcards

### Flashcards

**Q:** Informally, what does the quadratic form $Q(x) = x^TAx$ measure?

**A:** The "energy" or "score" that matrix $A$ assigns to a direction $x$ — a single scalar output that captures how much weight or favorability $A$ gives to that direction.

**Q:** State the eigenvalue condition for each of the five definiteness classes.

**A:** Positive definite: all $\lambda_i > 0$. Positive semidefinite: all $\lambda_i \geq 0$. Negative definite: all $\lambda_i < 0$. Negative semidefinite: all $\lambda_i \leq 0$. Indefinite: at least one $\lambda_i > 0$ and at least one $\lambda_i < 0$.

**Q:** Why can't you judge definiteness by inspecting the matrix's diagonal and off-diagonal entries?

**A:** The off-diagonal entries (cross terms) hide downhill directions. For example, $x^2 + 4xy + y^2$ has all positive-looking coefficients but $q(1,-1) = -2 < 0$ because the cross term flips the sign.

**Q:** What is the core proof technique that makes Theorem 20.1 (positive definite $\iff$ all $\lambda_i > 0$) work?

**A:** Rotate to the eigenvector basis: $y = Q^Tx$ converts $x^TAx$ into $\sum \lambda_i y_i^2$. The shape is now visible. With all $\lambda_i > 0$, every nonzero $y$ makes the sum strictly positive. Any $\lambda_k \leq 0$ lets you choose $y = e_k$ to make the form non-positive.

**Q:** How do you construct a concrete counterexample showing a matrix is not positive definite?

**A:** Find an eigenvalue $\lambda_k \leq 0$ via the characteristic polynomial. Then plug in the corresponding eigenvector $q_k$: you get $q_k^TAq_k = \lambda_k \leq 0$, proving a nonzero vector produces a non-positive form value.

**Q:** Is every positive definite matrix also positive semidefinite?

**A:** Yes — positive definite (all $\lambda_i > 0$) is the strict case; positive semidefinite (all $\lambda_i \geq 0$) is the weak case. Always report the strongest label that accurately describes a given matrix.
