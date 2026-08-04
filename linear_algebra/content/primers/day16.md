# Primer: Day 16 — Orthogonal Projections, Least Squares

## Warm-up

Before diving into orthogonal projections and least squares, take a moment to reconnect with three prior days that laid the foundational concepts we build on today.

**Day 15** established a fundamental decomposition that underpins everything we do today: every vector in an inner product space can be split uniquely into two perpendicular pieces.
One piece lives inside a subspace $W$; the other lives in the orthogonal complement $W^\perp$.
This is not just a mathematical curiosity—it is the backbone of today's entire theory.
The orthogonal projection of a vector is precisely the $W$-part of that decomposition, and the residual is precisely the $W^\perp$-part.
When we write $V = W \oplus W^\perp$, we mean that every vector $v \in V$ can be written uniquely as $v = w + w^\perp$ where $w \in W$ and $w^\perp \in W^\perp$.
Today, we learn that $w = \operatorname{proj}_W(v)$ and $w^\perp = v - \operatorname{proj}_W(v)$.
This decomposition is not a geometric curiosity; it is the geometric fact that makes the projection unique and optimal.
No matter how you compute it, you always get the same answer.

**Day 14** built the algebraic machinery that makes this decomposition rigorous and computable.
We defined inner products formally, proved their linearity and symmetry properties, and defined orthogonality algebraically: two vectors are orthogonal when their inner product is zero, written $\langle u, v \rangle = 0$.
This perpendicularity is not just intuitive geometry—it is a precise algebraic condition that lets us check orthogonality by computation.
Two vectors can be orthogonal even in high dimensions where we cannot visualize them.
We also learned how to normalize vectors to unit length and how to apply Gram-Schmidt orthogonalization to turn any basis into an orthonormal basis.
Over the next few sections, perpendicularity becomes our main tool: instead of relying on pictures, we use inner products to detect and enforce right angles algebraically.
We will frequently appeal to the Gram-Schmidt process to build orthonormal bases whenever we need them.

Finally, **Day 9** established the fundamental spaces that will be our playgrounds today: the column space $C(A)$ (all vectors you can express as $Ax$ for some $x$), the null space $N(A)$ (all vectors annihilated by $A$, i.e., $Ax = 0$), and the null space of the transpose $N(A^T)$ (all vectors annihilated by $A^T$, or equivalently, all vectors orthogonal to every row of $A$, which is the same as being orthogonal to every column of $A$).
These spaces are finite-dimensional subspaces of Euclidean space, and we are about to project vectors onto them.
It helps to visualize what these spaces represent geometrically before we formalize the projection algebra.
The column space $C(A)$ is where your solutions and fitted values live; the orthogonal complement $C(A)^\perp$ is where your residuals live.
Today we bridge these two spaces with orthogonal projection.

## The hook

Suppose we want to fit a straight line $y = mx + b$ to three data points: $(0,1)$, $(1,3)$, $(2,4)$.
In a perfect world, each point would satisfy our model exactly.
The point $(0,1)$ would give $b = 1$.
The point $(1,3)$ would give $m + b = 3$.
The point $(2,4)$ would give $2m + b = 4$.
Stack these three equations into a system:
$$A = \begin{pmatrix} 0 & 1 \\ 1 & 1 \\ 2 & 1 \end{pmatrix}, \quad x = \begin{pmatrix} m \\ b \end{pmatrix}, \quad y = \begin{pmatrix} 1 \\ 3 \\ 4 \end{pmatrix}.$$

The system is $Ax = y$.
We have three equations in two unknowns.
Can we solve it exactly?
Let us check by backward substitution.
From the first two equations, we extract $b = 1$ and $m + 1 = 3$, giving $m = 2$ and $b = 1$.
Now plug these into the third equation: $2(2) + 1 = 5 \ne 4$.
**Contradiction. There is no exact solution.**
The system is **inconsistent** because the vector $y$ is not in the column space $C(A)$.

Now the question arises: what does it mean to find the "best-fitting line" mathematically?
Intuitively, we want to be as close as possible to satisfying all three equations simultaneously, even if perfect satisfaction is impossible.
Formally, we want to minimize the total error in our fit.
Day 16 reframes this problem with geometric precision: since $y$ is not in the column space $C(A)$, we cannot make $Ax$ equal $y$ exactly, no matter what we choose for $x$.
Instead, we find the point in $C(A)$ that is **closest** to $y$.
That closest point is the **orthogonal projection** of $y$ onto $C(A)$.
Geometrically, this is obtained by dropping a perpendicular from $y$ straight down to the subspace and landing at the foot—imagine a plumb line from a point in space to the floor.
This single geometric reframing collapses the mysterious concept of "best fit" into a transparent idea: **the closest point in the subspace is the foot of the perpendicular**.
The fitted values $A\hat x$ will be as close as possible to $y$, and the residual $y - A\hat x$ will be perpendicular to every direction in $C(A)$, which translates algebraically to the normal equations $A^TA\hat x = A^Tb$.

## The pictures

**Picture 1: The residual as perpendicular drop.**
Imagine the vector $b \in \mathbb{R}^m$ floating somewhere in space, and the subspace $C(A) \subseteq \mathbb{R}^m$ as a plane (or hyperplane in higher dimensions).
The projection $p = \operatorname{proj}_{C(A)}(b)$ is the shadow of $b$ cast straight down onto that plane—think of $b$ as a light source and $C(A)$ as a floor.
The shadow $p$ is the point in $C(A)$ directly below $b$, obtained by the shortest path from $b$ to the subspace.
The error vector $e = b - p$ points straight up out of the plane—it is perpendicular to every direction inside $C(A)$.
This perpendicularity is not accidental or an artifact of one particular definition; rather, it is the defining property that makes $p$ the best approximation.
Any other point $w \in C(A)$ is farther away, and the reason is purely geometric: the path from $b$ to $w$ must take a detour compared to the perpendicular path from $b$ to $p$.
This picture is the foundational image of orthogonal projection and least squares.

**Picture 2: The right triangle for the Best Approximation Theorem.**
Draw three points: $b$, the projection $p$, and any other candidate point $w$ in $C(A)$.
Connect them to form a triangle.
The angle at $p$ is a right angle because $b - p$ (pointing out of the plane) is perpendicular to $p - w$ (pointing along the plane).
The first vector lives in $C(A)^\perp$, the second lives in $C(A)$, and orthogonal complements are, by definition, perpendicular to each other.
Apply the Pythagorean theorem (from Lemma 16.1): the hypotenuse from $b$ to $w$ is strictly longer than the leg from $b$ to $p$, unless $w$ and $p$ are the same point.
Algebraically, $\|b - w\|^2 = \|b - p\|^2 + \|p - w\|^2 > \|b - p\|^2$ whenever $w \ne p$.
This picture makes the proof of uniqueness and optimality intuitive: the right angle forces $p$ to be the unique closest point.
If you move away from $p$ even slightly (so $w \ne p$), you move farther from $b$ by the Pythagorean theorem.

**Picture 3: The normal equations' picture—make the error perpendicular to every column.**
The residual vector $b - A\hat x$ must be perpendicular to every single column of $A$, all at once.
Imagine the columns of $a_1, a_2, \ldots, a_n$ as $n$ reference directions pointing in various ways through the subspace $C(A)$.
The condition that the residual is orthogonal to each column is expressed as $n$ inner-product equations: $a_j^T(b - A\hat x) = 0$ for $j = 1, 2, \ldots, n$.
Stack all $n$ equations as a single matrix equation: $A^T(b - A\hat x) = 0$.
Rearrange to get the normal equations: $A^TA\hat x = A^Tb$.
The word "normal" here is a synonym for perpendicular—this system encodes the perpendicularity condition geometrically as a linear system algebraically.
One system, one idea: perpendicularity.

## Concrete-first walkthrough

Now let us build the theory step by step, starting with the definition and accumulating understanding through the lemmas and theorems.

**Definition 16.1** says: the orthogonal projection of $v$ onto a subspace $W$ with orthonormal basis $e_1, \ldots, e_k$ is the sum
$$\operatorname{proj}_W(v) = \sum_{i=1}^k \langle v, e_i \rangle e_i.$$

What does this formula mean geometrically and algebraically?
Each inner product $\langle v, e_i \rangle$ measures the component of $v$ in the direction of $e_i$; we scale $e_i$ by that component and add up all the scaled pieces.
The result is a linear combination of the basis vectors, hence automatically lives in $W$.
Memory hook: *the projection is the shadow, built from the orthonormal basis of the floor*.
At first, this formula looks as if it depends on which orthonormal basis we choose for $W$.
But Theorem 16.1 will prove that the projection is unique—any orthonormal basis of $W$ produces the same vector because the projection is characterized by a basis-free geometric property: being the closest point in $W$ to $v$.
This is the first key insight: the formula depends on the basis, but the answer does not.

**Lemma 16.1** restates the Pythagorean theorem in any inner product space: if $a \perp b$ (i.e., $\langle a, b \rangle = 0$), then $\|a + b\|^2 = \|a\|^2 + \|b\|^2$.
This is a purely algebraic consequence of expanding $\|a+b\|^2 = \langle a+b, a+b \rangle$ using bilinearity: we get $\|a\|^2 + 2\langle a, b \rangle + \|b\|^2$, and the cross term $2\langle a, b \rangle$ vanishes when $a \perp b$.
Memory hook: *perpendicular components add in squares*.
We will use this lemma repeatedly throughout today to relate distances to orthogonality and to convert geometric intuition into algebraic statements.
It is the glue connecting geometry and algebra.

**Lemma 16.2** says the residual $v - \operatorname{proj}_W(v)$ is orthogonal to the entire subspace $W$.
The proof checks orthogonality against each basis vector $e_j$ separately and uses the orthonormality to collapse the sum—when you dot the residual with $e_j$, most terms vanish by orthonormality, leaving $\langle v, e_j \rangle - \langle v, e_j \rangle = 0$.
Memory hook: *the leftover points straight out of the floor*.
This lemma is crucial because it characterizes the projection by a basis-free property: once you impose the requirement that the residual lands in $W^\perp$, there is exactly one point in $W$ that satisfies it.
This is what makes the projection unique despite the definition looking basis-dependent.

**Theorem 16.1** (Best Approximation Theorem) states that the projection is not just any point in $W$—it is the closest.
For any $w \in W$, we have $\|v - \operatorname{proj}_W(v)\| \le \|v - w\|$, with equality if and only if $w = \operatorname{proj}_W(v)$.
The proof works by decomposing $v - w = (v - p) + (p - w)$ where $p$ is the projection, then noting that the first piece is in $W^\perp$ (by Lemma 16.2) and the second is in $W$ (since both $p$ and $w$ are in $W$, so their difference is too).
Because the two pieces are orthogonal, we apply Lemma 16.1 to get $\|v-w\|^2 = \|v-p\|^2 + \|p-w\|^2 \ge \|v-p\|^2$.
The nonnegative term $\|p-w\|^2$ vanishes only when $w = p$, giving both the inequality and uniqueness for free.
Memory hook (slogan): ***the shadow beats every other candidate***.
This theorem is the geometric heart of the day: it explains why the projection formula (Definition 16.1) gives a unique vector independent of the choice of orthonormal basis.

**Theorem 16.2** (Normal equations) says: to minimize $\|Ax - b\|$ over all $x \in \mathbb{R}^n$, we solve $A^TA\hat x = A^Tb$.
Why does this work?
As $x$ ranges over $\mathbb{R}^n$, the vector $Ax$ ranges over exactly $C(A)$.
So minimizing $\|Ax - b\|$ is equivalent to finding the point of $C(A)$ closest to $b$.
By Theorem 16.1, that point is the projection $\operatorname{proj}_{C(A)}(b)$, uniquely characterized by the residual $b - A\hat x$ being perpendicular to all of $C(A)$.

Here is the **prerequisite patch**—critical for making the next step transparent.
Why is $C(A)^\perp = N(A^T)$?
In three lines: A vector $y$ is perpendicular to every column of $A$ if and only if $\langle a_j, y \rangle = 0$ for all columns $a_j$.
But $\langle a_j, y \rangle = a_j^T y$ is exactly the $j$-th entry of the vector $A^T y$.
So "$\langle a_j, y \rangle = 0$ for all $j$" means $A^T y = 0$, i.e., $y \in N(A^T)$.
This is the Fundamental Theorem of Linear Algebra's right angle connection at work, promised on Day 6 and delivered here.
With this fact in hand, the condition $b - A\hat x \in C(A)^\perp$ becomes $A^T(b - A\hat x) = 0$, which rearranges to $A^TA\hat x = A^Tb$.
Memory hook (slogan): ***make the error invisible to every column***.
This is where the normal equations come from, and it is the precise algebraic translation of the geometric condition.

## Proof roadmaps

**Theorem 16.1 — Best Approximation Theorem.**
The proof's core trick is *insert-and-Pythagoras*.
For any competitor $w \in W$, we insert the projection and decompose $v - w = (v - p) + (p - w)$ where $p = \operatorname{proj}_W(v)$.
By Lemma 16.2, the first piece $v - p$ lies in $W^\perp$; the second piece $p - w$ lies in $W$ (since $p$ and $w$ are both in $W$, and $W$ is closed under subtraction).
These two pieces are orthogonal to each other by the definition of orthogonal complement.
We then apply Lemma 16.1: $\|v - w\|^2 = \|v - p\|^2 + \|p - w\|^2 \ge \|v - p\|^2$.
The nonnegative term $\|p - w\|^2$ vanishes only when $w = p$, giving both the inequality and the uniqueness clause in one stroke.
No separate uniqueness argument is needed; it falls out of the Pythagorean theorem.

**Theorem 16.2 — Normal equations.**
The proof's core trick is *translate geometric condition into matrix language*.
First, by applying Theorem 16.1 with $W = C(A)$, minimizing $\|Ax - b\|$ over all $x$ is equivalent to finding $A\hat x = \operatorname{proj}_{C(A)}(b)$.
Second, by Lemmas 16.2 and the prerequisite patch on $C(A)^\perp = N(A^T)$, the residual must satisfy $A^T(b - A\hat x) = 0$.
Third, rearrange this matrix equation to $A^TA\hat x = A^Tb$.
Bonus insight: when $A$ has independent columns (full column rank), the matrix $A^TA$ is invertible.
Proof of invertibility: if $A^TAx = 0$, then $0 = x^TA^TAx = (Ax)^T(Ax) = \|Ax\|^2$, so $Ax = 0$.
But if $A$ has full column rank, its null space is trivial, so $x = 0$.
Thus $N(A^TA) = \{0\}$, making $A^TA$ injective, and since it is square, it is invertible.
This guarantees a unique solution $\hat x = (A^TA)^{-1}A^Tb$.

## Flashcards

### Flashcards

**Q:** Least squares in one geometric sentence?

**A:** Project $b$ onto the column space $C(A)$—the closest achievable point is the foot of the perpendicular from $b$ to the subspace.

**Q:** The normal equations?

**A:** $A^TA\hat x = A^Tb$.

**Q:** Why "normal"?

**A:** Normal means perpendicular—the normal equations encode that the residual is perpendicular to every column of $A$.

**Q:** State $C(A)^\perp = N(A^T)$ in words and explain why in one line.

**A:** What's perpendicular to everything $A$ produces is exactly what $A^T$ kills; $\langle a_j, y \rangle = 0$ for all columns $a_j \iff A^Ty = 0$.

**Q:** Best Approximation Theorem proof trick?

**A:** Insert the projection into the distance formula: $v - w = (v - p) + (p - w)$, apply Pythagoras to orthogonal pieces, and drop a nonnegative term.

**Q:** When is $A^TA$ invertible?

**A:** If and only if $A$'s columns are independent; from $A^TAx = 0$ follows $\|Ax\|^2 = 0$, hence $x \in N(A) = \{0\}$, so $A^TA$ is injective, thus invertible.

**Q:** What everyday method is this whole day?

**A:** Linear regression—fitting a model by minimizing squared errors, which is orthogonal projection onto the column space of the data matrix.
