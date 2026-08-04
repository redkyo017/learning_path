# Day 21 Primer — Singular Value Decomposition, Part 1: Existence & Geometric Meaning

## Warm-up

Before diving into today's core content, spend ten to fifteen minutes reviewing the flashcard answers for three prerequisite days.

First, Day 20 (positive semidefinite matrices): refresh on what it means for $x^TMx \ge 0$ to hold for every $x$, and why positive semidefiniteness is the right generalization of "non-negative eigenvalues" when a matrix isn't necessarily symmetric.

Second, Day 19 (the Spectral Theorem): remind yourself that every real symmetric matrix has an orthonormal eigenbasis with real eigenvalues, and crucially, that the eigenvalues can be sorted in any order we choose—in today's proof we'll sort them descending.

Third, Day 14 (inner products and norms): recall the dot product as length and angle, the axioms of an inner product, and why orthonormality means $\langle u_i, u_j \rangle = \delta_{ij}$.

Today's entire existence proof is built by stacking these three ideas: "take the Spectral Theorem, apply it to the positive semidefinite matrix $A^TA$, then transport the result through $A$ using orthonormality."
If any of those three days feels fuzzy, a fifteen-minute skim of their flashcards will make today's proof feel inevitable rather than mysterious—a natural continuation of what you've already proven, not a new and terrifying construction.

## The hook

Eigendecomposition and diagonalization work beautifully—for square, symmetric matrices.
The Spectral Theorem is magnificent: every symmetric $n \times n$ matrix has an orthonormal eigenbasis with real eigenvalues, so $A = Q\Lambda Q^T$ where $Q$ is orthogonal and $\Lambda$ is diagonal.

But real-world data never cooperates with these requirements.
A thousand users and twenty features gives a $1000 \times 20$ rectangular matrix.
A hundred images each flattened to five thousand pixels yields a $100 \times 5000$ matrix.
Rectangular matrices are everywhere.
The question becomes inescapable: is there an eigen-story for *every* real matrix, any shape, any rank?

The answer is yes, and the path is a single liberating realization.
For any rectangular matrix $A$, the product $A^TA$ is always square, always symmetric, and—here's the key—always positive semidefinite.
It's the "symmetric shadow" that every rectangular $A$ automatically casts.
Once you recognize that $A^TA$ fits the requirements for the Spectral Theorem, you can apply all that machinery.

The Spectral Theorem fires, handing you an orthonormal eigenbasis $v_1, \dots, v_n$ and ordered non-negative eigenvalues $\lambda_1 \ge \cdots \ge \lambda_n \ge 0$.
From that eigenbasis, you can reverse-engineer $A$'s structure itself using one clever trick: define $u_i = Av_i / \sqrt{\lambda_i}$ for each positive eigenvalue.

The result—the Singular Value Decomposition, or SVD—is the existence guarantee that eigendecomposition fails to provide.
Literally every real matrix, any shape, any rank, factors as $A = U\Sigma V^T$, where $U$ and $V$ are orthogonal matrices and $\Sigma$ is a rectangular diagonal stretch.
No invertibility required, no symmetry required, no rank assumption needed.

Geometrically, the picture is both beautiful and intuitive: any matrix maps the unit sphere in its input space to an ellipsoid in its output space, with semi-axes the singular values and semi-axis directions the left singular vectors $u_i$.

## The pictures

**Picture 1: The SVD geometry—unit circle to ellipse.**

Draw a 2D unit circle centered at the origin.
Then show how a $2 \times 2$ matrix $A$ stretches and rotates it into an ellipse.
On the original circle, mark two perpendicular input directions $v_1, v_2$ (the right singular vectors, pointing along the axes of the input circle).
In the output ellipse, mark two perpendicular output axes $u_1, u_2$ (the left singular vectors, pointing along the principal axes of the ellipse).
Label the semi-major and semi-minor axis lengths with $\sigma_1$ and $\sigma_2$ respectively.

Write the key insight on the diagram: $Av_i = \sigma_i u_i$—perpendicular input directions map to perpendicular output directions, each stretched by its singular value.
This asymmetry between input basis $\{v_i\}$ and output basis $\{u_i\}$ is exactly why SVD works for rectangular matrices where eigendecomposition fails.

**Picture 2: The $A = U\Sigma V^T$ factorization as rotate → stretch → rotate.**

On the left, write out the three matrices side by side with their dimensions and roles clearly labeled.
$V^T$ (size $n \times n$) rotates or reflects the input; its rows are the right singular vectors $v_i^T$, forming an orthonormal basis of the input space $\mathbb{R}^n$.

$\Sigma$ (size $m \times n$) is a rectangular diagonal stretch: it stretches each coordinate independently along its axis, and even when $m \neq n$ there's no problem—extra rows are zero, extra columns are zero, one or the other depending on whether $m > n$ or $n > m$.

Finally, $U$ (size $m \times m$) rotates or reflects the output; its columns are the left singular vectors $u_i$, forming an orthonormal basis of the output space $\mathbb{R}^m$.

The power of this three-factor decomposition: because there are *two* independent orthogonal transformations instead of one, the factors can live in different spaces.
One rotation handles the $n$-dimensional input, the other handles the $m$-dimensional output, and the diagonal $\Sigma$ in between absorbs all the stretching.
This is why the SVD works for any rectangular $m \times n$ pair.
Eigendecomposition needs just one similarity rotation, so it breaks when the matrix isn't square; SVD uses two rotations, one per side, absorbing all asymmetry naturally.

**Picture 3: The factory diagram—how to build the SVD from $A^TA$.**

Draw three boxes in sequence, connected by arrows.

**First box:** "Eigendecompose $A^TA$ (symmetric positive semidefinite)."
By the Spectral Theorem, this is always possible.
Output: orthonormal vectors $v_1, \dots, v_n$ and non-negative eigenvalues $\lambda_1 \ge \lambda_2 \ge \cdots \ge \lambda_n \ge 0$, already sorted in descending order.

**Second box:** "Compute singular values and left singular vectors."
Input: the eigenvalues $\lambda_i$ and eigenvectors $v_i$ from box 1.
Action: set $\sigma_i = \sqrt{\lambda_i}$ for all $i$ (square root of a non-negative number is real).
For each index $i$ where $\sigma_i > 0$, compute $u_i = Av_i / \sigma_i$.

The inner-product trick (the heart of the proof) shows that these $u_i$ are automatically orthonormal: $\langle u_i, u_j \rangle = v_i^T A^T A v_j / (\sigma_i \sigma_j) = \lambda_j \delta_{ij} / (\sigma_i \sigma_j) = \delta_{ij}$ after algebra.
For indices where $\sigma_i = 0$, the $u_i$ can be chosen as any unit vectors orthogonal to the already-computed $u_j$'s—this freedom allows SVD to handle rank-deficient matrices.

**Third box:** "Assemble and pad."
Stack the $u_i$ into $U$ (using Gram-Schmidt to extend if needed to a full basis), stack the $v_i$ into $V$, build the rectangular diagonal $\Sigma$ with $\sigma_i$ on the main diagonal and zeros elsewhere.
Output: $A = U\Sigma V^T$, verified by checking $AV = U\Sigma$ column by column.

## Concrete-first walkthrough

**Definition 21.1: The SVD formula and its three ingredients.**

A singular value decomposition of $A \in \mathbb{R}^{m \times n}$ is a factorization $A = U\Sigma V^T$ where the three matrices satisfy three conditions.

First, $U \in \mathbb{R}^{m \times m}$ is orthogonal, meaning $U^TU = I$—in other words, its columns form an orthonormal basis of $\mathbb{R}^m$.

Second, $V \in \mathbb{R}^{n \times n}$ is orthogonal, meaning $V^TV = I$—its columns form an orthonormal basis of $\mathbb{R}^n$.

Third, $\Sigma \in \mathbb{R}^{m \times n}$ is rectangular diagonal: all off-diagonal entries are zero, and the diagonal entries are non-negative and arranged in *descending* order, $\sigma_1 \ge \sigma_2 \ge \cdots \ge \sigma_{\min(m,n)} \ge 0$.

That descending-order requirement is part of the formal definition—not a convenience, but a requirement.
Remember it carefully, because later exercises and applications will trap you if you forget to sort the singular values.

**Lemma 21.1: $A^TA$ is the symmetric positive-semidefinite engine.**

For any $A \in \mathbb{R}^{m \times n}$, the $n \times n$ matrix $A^TA$ is symmetric and positive semidefinite.

Symmetry is immediate from basic transpose arithmetic: $(A^TA)^T = A^T(A^T)^T = A^TA$ using $(XY)^T = Y^TX^T$.

The positive-semidefiniteness is the deeper fact.
Positive semidefiniteness, by definition from Day 20, means $x^T(A^TA)x \ge 0$ for every $x \in \mathbb{R}^n$.

The key move: rewrite the left side using associativity: $x^T(A^TA)x = (Ax)^T(Ax) = \langle Ax, Ax \rangle = \|Ax\|^2$, where the last step uses the definition of the Euclidean norm.

But a squared norm is always non-negative, $\|Ax\|^2 \ge 0$, with equality only when $Ax = 0$.
So for every $x$, we have $x^T(A^TA)x \ge 0$, which is exactly positive semidefiniteness.

Internalize this fact: $A^TA$ is where $A$'s semidefiniteness "lives," invisible but omnipresent in every matrix.

**Theorem 21.1: The existence proof and its central slogan.**

The statement is clean: *every real matrix $A \in \mathbb{R}^{m \times n}$ has a singular value decomposition*.

The slogan that packages the entire proof: "eigenvectors of $A^TA$ in, normalized images out."

The proof follows this ladder. Step one: Because $A^TA$ is symmetric (by Lemma 21.1), the Spectral Theorem applies directly.
You get an orthonormal eigenbasis $v_1, \dots, v_n$ of $\mathbb{R}^n$ and real eigenvalues $\lambda_1 \ge \lambda_2 \ge \cdots \ge \lambda_n$.

But are these eigenvalues non-negative? Yes, by positive semidefiniteness (also Lemma 21.1 applied to each $v_i$): for each $i$, we have $\lambda_i = \|v_i\|^2 \lambda_i = \langle v_i, \lambda_i v_i \rangle = \langle v_i, A^TAv_i \rangle = v_i^T(A^TA)v_i \ge 0$.
So $\lambda_1 \ge \lambda_2 \ge \cdots \ge \lambda_n \ge 0$.

Step two: Define the singular values: $\sigma_i = \sqrt{\lambda_i}$ for $i = 1, \dots, n$.
Since the $\lambda_i$ are non-negative and sorted descending, so are the $\sigma_i$: $\sigma_1 \ge \sigma_2 \ge \cdots \ge \sigma_n \ge 0$.

Let $r$ be the count of positive (nonzero) singular values. Then $\sigma_1 \ge \sigma_2 \ge \cdots \ge \sigma_r > 0$ and $\sigma_{r+1} = \cdots = \sigma_n = 0$.

Step three: For each $i = 1, \dots, r$ (indices with $\sigma_i > 0$), define $u_i = Av_i / \sigma_i \in \mathbb{R}^m$.
Now comes the critical computation, the "middle rung" that makes the whole edifice stand.

For any $i, j \in \{1, \dots, r\}$, compute the inner product: $\langle u_i, u_j \rangle = \langle Av_i / \sigma_i, Av_j / \sigma_j \rangle = (1 / (\sigma_i \sigma_j)) (Av_i)^T(Av_j) = (1 / (\sigma_i \sigma_j)) v_i^T(A^TA)v_j$.

Use the eigenvector condition: $A^TAv_j = \lambda_j v_j$.
So the inner product becomes $(1 / (\sigma_i \sigma_j)) v_i^T(\lambda_j v_j) = (\lambda_j / (\sigma_i \sigma_j)) \langle v_i, v_j \rangle$.

By orthonormality of the $v_i$, we have $\langle v_i, v_j \rangle = \delta_{ij}$ (one if $i = j$, zero otherwise).
If $i \ne j$, the whole expression is zero.
If $i = j$, it becomes $\lambda_i / (\sigma_i^2) = \lambda_i / \lambda_i = 1$ (using $\sigma_i^2 = \lambda_i$).

Therefore, $\langle u_i, u_j \rangle = \delta_{ij}$, so the set $\{u_1, \dots, u_r\}$ is orthonormal.

## Proof roadmaps

**Theorem 21.1: The hardest construction—treat the ladder as the assignment.**

This proof requires holding eight separate ideas in mind simultaneously and weaving them together.
You need the Spectral Theorem (Day 19), positive semidefiniteness (Day 20), the definition of eigenvectors and the sorting of eigenvalues, the definition of the singular values as square roots, the orthonormality computation (which is the heart of the proof), basis extension via Gram-Schmidt (Day 15), rank and nullity facts (Days 4–6), and careful column-by-column verification.

**First stage: Spectral Theorem on $A^TA$.**

Because $A^TA$ is symmetric positive semidefinite (Lemma 21.1), the Spectral Theorem applies.
You get an orthonormal eigenbasis $v_1, \dots, v_n$ of $\mathbb{R}^n$ with real eigenvalues $\lambda_1 \ge \lambda_2 \ge \cdots \ge \lambda_n \ge 0$ (the non-negativity follows from positive semidefiniteness).
Define $\sigma_i = \sqrt{\lambda_i}$ and let $r$ be the count of positive singular values.
This first stage is straightforward: you've applied the Spectral Theorem many times by Day 21, just to the specific matrix $A^TA$.

**Second stage: The middle rung—the computation to internalize.**

This is where the proof's magic happens.
For $i, j \le r$ (the indices with $\sigma_i > 0$), compute $\langle u_i, u_j \rangle$ where $u_i = Av_i / \sigma_i$.
Write it as $\langle Av_i, Av_j \rangle / (\sigma_i \sigma_j)$.
Use transpose properties to get $(Av_i)^T(Av_j) / (\sigma_i \sigma_j) = v_i^T A^T A v_j / (\sigma_i \sigma_j)$.

Apply the eigenvector condition $A^T A v_j = \lambda_j v_j$: the numerator becomes $v_i^T(\lambda_j v_j) = \lambda_j v_i^T v_j$.
By orthonormality of the $v_i$, $v_i^T v_j = \delta_{ij}$.
So the whole inner product is $\lambda_j \delta_{ij} / (\sigma_i \sigma_j)$.

When $i = j$, this is $\lambda_i / (\sigma_i^2) = \lambda_i / \lambda_i = 1$.
When $i \ne j$, it's $0$.
Therefore, $\langle u_i, u_j \rangle = \delta_{ij}$—orthonormality is built in.
This computation is the proof's heart; practice it until it flows automatically.

**Third stage: Sketch and assembly.**

For $i > r$, the singular value $\sigma_i = 0$, so $Av_i = 0$ (because $A^TAv_i = \lambda_i v_i = 0$).
The corresponding $u_i$ can be any unit vector orthogonal to the already-chosen $u_1, \dots, u_{r-1}$—this is where Gram-Schmidt (Day 15) enters, extending the orthonormal set to a full basis of $\mathbb{R}^m$.

Assemble the matrices $U$, $V$, and $\Sigma$, then check $AV = U\Sigma$ one column at a time: each $k$-th column of $AV$ is $Av_k$, which equals $\sigma_k u_k$ (if $k \le r$, by the definition of $u_k$) or $0$ (if $k > r$, by the fact that $Av_k = 0$).
Both sides match at every column.
Finally, multiply $AV = U\Sigma$ on the right by $V^T$ (where $V^T = V^{-1}$ since $V$ is orthogonal) to get $A = U\Sigma V^T$.

## Flashcards

### Flashcards

**Q:** State the SVD equation and name the three ingredients.

**A:** $A = U\Sigma V^T$. $U$ is orthogonal ($m \times m$, columns are left singular vectors), $\Sigma$ is rectangular diagonal ($m \times n$, entries non-negative and descending), $V$ is orthogonal ($n \times n$, columns are right singular vectors).

**Q:** How are the singular values obtained from $A^TA$?

**A:** The singular values are $\sigma_i = \sqrt{\lambda_i}$, where $\lambda_i$ are the eigenvalues of the symmetric matrix $A^TA$, sorted in descending order.

**Q:** Why is $A^TA$ always positive semidefinite?

**A:** For any $x$, we have $x^T A^T A x = (Ax)^T(Ax) = \|Ax\|^2 \ge 0$, which is the defining condition for positive semidefiniteness.

**Q:** How are the left singular vectors $u_i$ built and why are they orthonormal?

**A:** For nonzero $\sigma_i$, define $u_i = Av_i / \sigma_i$. They are orthonormal because $\langle u_i, u_j \rangle = v_i^T A^T A v_j / (\sigma_i \sigma_j) = \lambda_j \delta_{ij} / (\sigma_i \sigma_j) = \delta_{ij}$ after simplification using the eigenvector condition and orthonormality of $v_i$.

**Q:** Describe the geometric picture of the SVD in one sentence.

**A:** Every matrix maps the unit sphere in $\mathbb{R}^n$ to an ellipsoid in $\mathbb{R}^m$, with semi-axis lengths equal to the singular values and semi-axis directions pointing along the left singular vectors $u_i$.

**Q:** How does the rank of $A$ relate to its SVD?

**A:** The rank of $A$ equals the number of nonzero singular values; this is because the dimension of the image of $A$ is determined by how many singular values are positive.

**Q:** Why does the SVD exist for every real matrix when eigendecomposition does not?

**A:** SVD uses two independent orthonormal bases (one for input, one for output) instead of one, allowing it to work on rectangular and non-diagonalizable matrices. The two bases absorb all asymmetry naturally where one basis cannot.
