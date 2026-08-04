# Day 10 Primer — Eigenvalues and Eigenvectors

## Warm-up

Before today, you've built the precise machinery to hunt for eigenvalues. Three prior days converge now into a unified framework:

**Day 9** taught you that a homogeneous system $Mx = 0$ has a nontrivial (nonzero) solution if and only if $M$ is singular — this is your gateway theorem. Most matrices have only the trivial solution $x = 0$, meaning the system has "nothing in the kernel". But singular matrices are special: they have a nonzero vector in the null space, a direction that the matrix sends to zero. This means the matrix is defective in some way — it has a hidden direction that maps to zero.

**Day 8** showed you that singularity and determinant zero are equivalent: you can test whether a matrix is singular by computing one number (the determinant). This converts an abstract question ("is this matrix singular?") into a concrete calculation. If $\det(A) \ne 0$, then $A$ is invertible. If $\det(A) = 0$, then $A$ is singular and the system $Ax = b$ might not have a solution for arbitrary $b$.

**Day 3** established linear independence and rank: when do vectors form a dependence or independence? You learned that two vectors are dependent if one is a scalar multiple of the other, and that a set of vectors is independent if no nontrivial combination equals zero. Linear independence is the "freshness" property — the more independent vectors you have, the more information they carry. On a 2×2 matrix, two independent vectors span the entire space; on a 3×3, three independent vectors span the space.

Today chains all three together into one hunting strategy: to find eigenvalues, you'll use Day 9 to convert the existence question to singularity (does $(A - \lambda I)v = 0$ have a nonzero solution?), Day 8 to convert singularity to determinant zero (is the determinant of $A - \lambda I$ equal to zero?), and Day 3 to verify that the resulting eigenvectors are independent (can you use Theorem 10.2?). If any of those feel shaky, revisit them now. The logic flow is: definition (eigenvalue) → homogeneous system (Day 9) → singularity (Day 8) → determinant zero (Day 8) → polynomial roots (Definition 10.2) → find eigenvectors (solve $Av = \lambda v$) → independence (Theorem 10.2). Each step is a translation, not a new theorem.

## The hook

Most directions tumble when you apply a matrix $A$. Let's see this in action with a concrete example. Take $A = \begin{pmatrix}3&1\\0&2\end{pmatrix}$ and experiment with different starting vectors:

- Feed it $(1,0)$: you get $A\begin{pmatrix}1\\0\end{pmatrix} = \begin{pmatrix}3\\0\end{pmatrix}$, which is $(1,0)$ scaled by 3. Apply $A$ again: $A\begin{pmatrix}3\\0\end{pmatrix} = \begin{pmatrix}9\\0\end{pmatrix}$. The direction never changes; the stretch just compounds.
- Try $(0,1)$: you get $A\begin{pmatrix}0\\1\end{pmatrix} = \begin{pmatrix}1\\2\end{pmatrix}$. This points in a completely different direction. The $(0,1)$ direction has rotated.
- Try $(1,-1)$: you get $A\begin{pmatrix}1\\-1\end{pmatrix} = \begin{pmatrix}2\\-2\end{pmatrix} = 2\begin{pmatrix}1\\-1\end{pmatrix}$, which is $(1,-1)$ scaled by 2. Apply $A$ again: you get $(4,-4)$, scaled by 2 again.

Notice: $(1,0)$ always scales by 3; $(1,-1)$ always scales by 2; $(0,1)$ rotates every time. These two special directions stay on their lines — they never rotate under $A$. Every other arrow spirals or shears. The distinction is sharp: some directions are invariant under $A$ (up to scaling); most are not. The matrix "recognizes" $(1,0)$ and $(1,-1)$ as special; it "ignores" the fact that they have a specific direction and just stretches them. This is the heart of eigenvector theory: finding the directions that a matrix leaves alone (up to scaling).

The mystery: how do you *find* these magic directions without guessing?

Today's central answer: turn an infinite search into a finite one. Instead of hunting through the infinite universe of possible directions ("find all vectors $v$ such that $Av = \lambda v$"), hunt through the roots of a single polynomial ("find all numbers $\lambda$ such that $\det(A - \lambda I) = 0$"). The roots of this polynomial are exactly the numbers that tame the matrix — the eigenvalues.

Why is this such a powerful idea? Because polynomials have finitely many roots (at most $n$ roots for a polynomial of degree $n$). So an $n \times n$ matrix has at most $n$ eigenvalues, and you can find all of them by solving one polynomial equation. Once you've found the eigenvalues, finding the eigenvectors is straightforward: for each eigenvalue $\lambda$, solve the homogeneous system $(A - \lambda I)v = 0$ to find the corresponding eigenvector(s). This is a systematic procedure, not a guessing game. The shift from "search through vectors" to "solve a polynomial" is not just computationally efficient — it fundamentally changes how we think about matrices. We're moving from a continuous search space (all possible vectors) to a discrete one (roots of a polynomial), which is much easier to handle algorithmically and theoretically.

## The pictures

Imagine a fan of arrows emanating from the origin in all directions — hundreds of them, pointing everywhere. When you apply $A$, most arrows rotate and skew: their heads move to new locations in new directions. The transformation scrambles the picture in all directions. But look carefully: a few arrows stay on their own lines. They only get stretched, shrunk, or flipped backward, but never rotated off their original direction. Those special arrows are the eigendirections — the matrix "recognizes" them and only changes their length.

If you stare at an eigendirection long enough under repeated multiplication by $A$, the picture becomes very simple: $A$ acts like multiplication by a single number (the eigenvalue). Pure scaling, no turning, no rotation. No mixing with other directions. This is why eigenvectors are so useful: they are the "clean" directions where the matrix's action is transparent. An eigenvector with $\lambda > 1$ stretches; $\lambda < 1$ shrinks; $\lambda < 0$ flips direction while shrinking or stretching; $\lambda = 1$ stays fixed.

Here's why this matters visually: every vector can be written as a sum of eigenvectors (if enough eigenvectors exist). On each eigenvector separately, the matrix is just a number (the eigenvalue). So in the eigenvector basis, the matrix becomes diagonal — it's just independent scaling in each direction. This is the geometric heartbeat of today: when $A$ is tamed into its eigenvector coordinate system, it becomes maximally simple. This simplification is exactly why eigenvectors are so powerful: they let you understand the matrix's behavior by looking at independent scaling directions, without worrying about rotations or mixing.

Imagine starting with a generic vector $u$ that's not an eigenvector. When you apply $A$ repeatedly, the vector $u$ gets scrambled in all directions — some components grow (those aligned with large-eigenvalue eigenvectors), some shrink (those aligned with small-eigenvalue eigenvectors). In the long run, the direction of $A^n u$ approaches the eigendirection with the largest eigenvalue. This dominance of the largest eigenvalue is the foundation of the power method, a practical algorithm for finding the largest eigenvalue of large matrices. Understanding this intuition — that repeated applications of $A$ amplify large-eigenvalue directions — is why today's material is so important.

Not every matrix has the same number of real eigendirections. The shear matrix $\begin{pmatrix}1&1\\0&1\end{pmatrix}$ has only *one* eigendirection: the horizontal axis. Most $2 \times 2$ matrices have two; this one has one. What happens when there's a gap between the number of independent eigenvectors you'd like and the number that actually exists? That's Day 11's cliffhanger — when a matrix doesn't have enough eigenvectors to form a complete basis. In this case, you can't fully diagonalize the matrix; you need the Jordan normal form instead (beyond today's scope).

Meanwhile, the rotation matrix $\begin{pmatrix}0&-1\\1&0\end{pmatrix}$ (which rotates every arrow by $90°$) has *zero* real eigendirections — every arrow rotates, so no arrow stays on its line. The characteristic polynomial is $(0-\lambda)(-\lambda) - (-1)(1) = \lambda^2 + 1$, which has roots $\pm i$ (complex). To find its eigendirections, you must move to the complex numbers, where complex eigenvalues hide behind rotations. This shows that even simple transformations can have no real eigenvalues — you need to expand the scalar field to $\mathbb{C}$ to fully capture a matrix's structure.

This distinction — some matrices have few eigenvectors, some have complex eigenvalues, some have both — motivates why linear algebra talks about characteristic polynomials and determinants over the complex numbers. Over $\mathbb{R}$, a matrix can have "missing" eigenvalues; over $\mathbb{C}$, the Fundamental Theorem of Algebra guarantees exactly $n$ eigenvalues (counting multiplicity) for any $n \times n$ matrix.

## Concrete-first walkthrough

**Definition 10.1** nails the core idea: an eigenvector is a nonzero vector $v$ such that $Av = \lambda v$. The scalar $\lambda$ is the eigenvalue — the stretch factor. Geometrically, when you multiply $v$ by $A$, you get the same vector $v$ back, just scaled by $\lambda$. It's as if the matrix "recognizes" this direction and only multiplies it by a number, never rotating it. This is exceptional behavior: for almost every direction, $A$ does something more complicated (rotate, shear, mix with other directions). An eigenvector is a "clean" direction; an eigenvalue quantifies how much stretching or shrinking happens on that direction.

The requirement $v \ne 0$ is crucial and non-obvious: $A0 = \lambda 0$ for every possible scalar $\lambda$. So if you allowed $v = 0$, then every scalar $\lambda$ would be an "eigenvalue", and the definition would tell you nothing. Worse, you'd have infinitely many eigenvalues for every matrix, making the whole concept useless. So we exclude the zero vector by definition — we only care about nonzero eigenvectors that truly represent a direction. This is why the $v \ne 0$ clause appears in the definition: it ensures each eigenvector represents one unique direction. Technically, the zero vector does satisfy $Av = \lambda v$ for all $\lambda$, but it's uninformative — it doesn't tell you about the matrix's structure. Restricting to nonzero vectors is a crucial design choice in the definition.

**Definition 10.2** introduces the characteristic polynomial: $p_A(\lambda) = \det(A - \lambda I)$. This polynomial in $\lambda$ has degree exactly $n$ (the size of the matrix). For a $2 \times 2$ matrix, this polynomial is quadratic; for $3 \times 3$, it's cubic; and so on. It's called the characteristic polynomial because its roots are exactly the eigenvalues. You can think of $\det(A - \lambda I)$ as a "dial" that you turn by changing $\lambda$: as you vary $\lambda$, the determinant changes continuously, and sometimes it hits exactly zero. When it hits zero, you've found an eigenvalue. This is the key insight: you're not searching for vectors; you're searching for the numbers that make a certain determinant equal zero.

The determinant $\det(A - \lambda I)$ is zero precisely when the matrix $A - \lambda I$ is singular, which means its columns (or rows) are linearly dependent. Geometrically, the matrix $A - \lambda I$ collapses the entire space down to a lower dimension. This happens at special values of $\lambda$ — exactly the eigenvalues. So the characteristic polynomial is a "reporter" that tells you, as a function of $\lambda$, when the transformation $A - \lambda I$ loses dimensionality. This is a deep idea: the eigenvalues of $A$ are the values of $\lambda$ where the transformation $A - \lambda I$ becomes singular. In a $3 \times 3$ example, if $\det(A - \lambda I) = 0$, then $A - \lambda I$ maps 3D space to a plane (or a line, or zero). The eigenvectors live in the null space of $A - \lambda I$ — they span the set of vectors that $A - \lambda I$ sends to zero.

Why does this relationship exist? Because the eigenvalue equation $Av = \lambda v$ can be rewritten as $(A - \lambda I)v = 0$. If we're looking for nonzero $v$ satisfying this, we need the null space of $A - \lambda I$ to be nontrivial. A matrix has a nontrivial null space if and only if it's singular, which happens if and only if its determinant is zero. This logical chain — eigenvalue definition → null space → singularity → determinant — is the foundation of Theorem 10.1.

**Theorem 10.1** is the game-changer: $\lambda$ is an eigenvalue of $A$ if and only if $\det(A - \lambda I) = 0$. This theorem converts the definition (which quantifies over vectors: "does there exist a nonzero $v$...?") into a polynomial-root problem (which is mechanical and computable: "are there roots of this polynomial?"). The beauty of this theorem is that it replaces an infinite search with a finite calculation. *This is the practical engine of eigenvalue computation.* You will use this theorem every time you hunt for eigenvalues: form the characteristic polynomial, find its roots, done. No guessing, no searching through vectors, no trial and error. Just polynomial root-finding, which is a well-studied problem.

Why does this work? Because an eigenvector for $\lambda$ exists if and only if $(A - \lambda I)v = 0$ has a nonzero solution. By Day 9's theorem, a homogeneous system has a nonzero solution if and only if the coefficient matrix is singular (not invertible). By Day 8's theorem, a square matrix is singular if and only if its determinant is zero. You've seen each step before; now they chain together perfectly. The proof takes these three equivalences and combines them into one clean statement. This is not new mathematics — you're just connecting ideas you already understand. What's new is the insight: eigenvalue problems are polynomial problems in disguise.

To make this concrete: suppose someone asks, "Is $\lambda = 3.7$ an eigenvalue of $A$?" By Theorem 10.1, the answer is yes if and only if $\det(A - 3.7 I) = 0$. You compute the determinant and check. No guessing, no searching through vectors. This is the computational power of Theorem 10.1.

**Theorem 10.2** says: eigenvectors for different eigenvalues are automatically linearly independent. If $\lambda_1 \ne \lambda_2 \ne \lambda_3 \ne \cdots$, and you have eigenvectors $v_1, v_2, v_3, \dots$ corresponding to these distinct eigenvalues, then the set $\{v_1, v_2, v_3, \dots\}$ is linearly independent. You don't need to check — the theorem guarantees it. This is a free lunch: once you've computed eigenvalues and verified they're all distinct, you know the eigenvectors form an independent set without any further work. This is powerful because independence is usually something you have to verify carefully; here it's automatic. For a $2 \times 2$ matrix with two distinct eigenvalues, Theorem 10.2 guarantees that the two eigenvectors are independent, which means they span the entire 2D space.

A note on edge cases: what if two eigenvalues are the same? Then Theorem 10.2 doesn't apply directly. A $3 \times 3$ matrix might have a repeated eigenvalue (say, $\lambda = 3$ appearing twice in the characteristic polynomial) and might have one or two eigenvectors for that eigenvalue. Day 11 explores this delicate situation — the gap between how many times an eigenvalue appears (algebraic multiplicity) and how many independent eigenvectors it has (geometric multiplicity). The question "does every eigenvalue have a corresponding eigenvector?" has a yes-or-no answer depending on the matrix. For now, focus on the distinct eigenvalue case, where Theorem 10.2 guarantees independence automatically. This is the "generic" situation and covers most practical applications.

**Recap: the two main theorems.** Theorem 10.1 answers: "How do I find eigenvalues?" Answer: solve $\det(A - \lambda I) = 0$ (a polynomial equation). Theorem 10.2 answers: "How do I know if my eigenvectors are independent?" Answer: if the eigenvalues are distinct, yes automatically; if not, you need to check further (Day 11). These two theorems are the foundation of today's material. Everything else is commentary or application.

## Proof roadmaps

**Theorem 10.1's proof** chains three known facts like a relay race. The structure unfolds in three stages, each pulling from a previous day:

Start with the definition: $\lambda$ is an eigenvalue means there exists a nonzero $v$ with $Av = \lambda v$. Rewrite this as $(A - \lambda I)v = 0$ (by factoring $v$ and using the fact that $\lambda v = (\lambda I)v$ by matrix algebra). Now you need $(A - \lambda I)v = 0$ to have a nonzero solution — this translates the eigenvalue problem into Day 9's language: existence of a nontrivial solution to a homogeneous system.

By Day 9's theorem (a fundamental result you proved), a homogeneous system $Mx = 0$ has a nonzero solution if and only if $M$ is singular — i.e., not invertible. If $M$ were invertible, you could multiply by $M^{-1}$ and force $x = 0$, so all solutions would be trivial. Conversely, if $M$ is singular, its columns are dependent, which means there's a nontrivial way to combine them to get zero. So the question becomes: when is $A - \lambda I$ singular? This shifts the question from vectors to matrices.

By Day 8's theorem, a square matrix is singular if and only if its determinant is zero. This is the connection between a geometric property (invertibility/singularity) and a numerical test (determinant = 0). So $A - \lambda I$ is singular exactly when $\det(A - \lambda I) = 0$. This shifts the question from matrices to numbers — determinants.

Chain all three equivalences: $\lambda$ is an eigenvalue ⟺ nonzero solution to $(A - \lambda I)v = 0$ exists ⟺ matrix $A - \lambda I$ is singular ⟺ $\det(A - \lambda I) = 0$. The infinite vector search ("does there exist a special nonzero vector?") collapses into finding roots of one polynomial ("where is $\det(A - \lambda I)$ equal to zero?"). This is the entire computational engine of eigenvalue theory. No new mathematics is invented; you're just connecting existing theorems from previous days. This is a hallmark of good mathematics: powerful conclusions follow from chaining simple facts together.

The three equivalences form a bridge: (1) the algebraic definition (what an eigenvalue is), (2) the geometric picture (null space of a singular matrix), and (3) the computational method (finding determinant zeros). Each equivalence translates the problem into a different language. Mastering these translations is more important than memorizing the final statement.

**Theorem 10.2's proof** is deeper and uses the minimal counterexample trick. The key idea: assume a smallest dependent collection of eigenvectors for distinct eigenvalues exists, and derive a contradiction by creating an even smaller dependent collection.

Assume a smallest such collection of size $k$: eigenvectors $v_1, \dots, v_k$ for distinct eigenvalues $\lambda_1, \dots, \lambda_k$, linearly dependent. Write a nontrivial dependence relation $\sum_{i=1}^k c_i v_i = 0$ with not all $c_i$ equal to zero. By minimality, all $c_i \ne 0$ (if any $c_j = 0$, dropping that term gives a smaller dependent collection).

Now perform two operations: (1) Apply $A$ to the dependence relation, using $Av_i = \lambda_i v_i$: $\sum_{i=1}^k c_i \lambda_i v_i = 0$. (2) Multiply the original relation by $\lambda_k$: $\sum_{i=1}^k c_i \lambda_k v_i = 0$. Subtract the second from the first: the $v_k$ term vanishes, leaving $\sum_{i=1}^{k-1} c_i(\lambda_i - \lambda_k) v_i = 0$, a dependence among fewer eigenvectors. But the coefficients $c_i(\lambda_i - \lambda_k)$ are all nonzero: each $c_i \ne 0$ (by assumption) and each $\lambda_i - \lambda_k \ne 0$ (because eigenvalues are distinct). This is a dependence relation among eigenvectors for distinct eigenvalues, of size $k-1 < k$. This contradicts our assumption that $k$ was minimal. Therefore, no such dependent collection exists.

The magic move here is the subtraction: by applying $A$ to one copy of the relation and multiplying another copy by a scalar, we create two relations that differ by exactly one term when subtracted. This one term (the $v_k$ term) cancels, shrinking the problem. This technique — "two versions of the same equation, subtract them strategically" — appears throughout linear algebra proofs. It's a powerful trick to keep in your toolbox.

**Example: Connecting the pieces.** Let's walk through how all the pieces fit together with a concrete $2 \times 2$ example. Take $A = \begin{pmatrix}4&1\\2&3\end{pmatrix}$. This is the exact example worked through in day10.md's worked example section.

**Step 1: Form the characteristic polynomial.** By Definition 10.2, we need $p_A(\lambda) = \det(A - \lambda I)$:
$$A - \lambda I = \begin{pmatrix}4-\lambda & 1 \\ 2 & 3-\lambda\end{pmatrix}.$$

Compute the $2 \times 2$ determinant: $(4-\lambda)(3-\lambda) - (1)(2) = 12 - 4\lambda - 3\lambda + \lambda^2 - 2 = \lambda^2 - 7\lambda + 10$. This is a quadratic polynomial in $\lambda$. Notice: the polynomial is in $\lambda$, not in the matrix entries. As $\lambda$ varies, the determinant traces out a parabola. We're hunting for the values of $\lambda$ where this parabola crosses zero.

**Step 2: Find the roots.** Factor: $\lambda^2 - 7\lambda + 10 = (\lambda - 5)(\lambda - 2) = 0$. So the eigenvalues are $\lambda_1 = 5$ and $\lambda_2 = 2$. By Theorem 10.1, these are exactly the eigenvalues of $A$ — no other values of $\lambda$ will work.

**Step 3: Find an eigenvector for $\lambda_1 = 5$.** By the definition, we need to solve $(A - 5I)v = 0$. This is a homogeneous system:
$$\begin{pmatrix}-1&1\\2&-2\end{pmatrix}\begin{pmatrix}v_1\\v_2\end{pmatrix} = \begin{pmatrix}0\\0\end{pmatrix}.$$

Row 1 gives $-v_1 + v_2 = 0$, so $v_2 = v_1$. Row 2 is $2v_1 - 2v_2 = 0$, which is just $2$ times row 1, so it's redundant. (This redundancy occurs exactly because $\det(A - 5I) = 0$, so the rows are dependent — a concrete illustration of Day 9's theorem). Taking $v_1 = 1$ gives the eigenvector $v = (1,1)$.

Verify: $A\begin{pmatrix}1\\1\end{pmatrix} = \begin{pmatrix}5\\5\end{pmatrix} = 5\begin{pmatrix}1\\1\end{pmatrix}$. ✓ The direction $(1,1)$ is scaled by exactly $5$.

**Step 4: Find an eigenvector for $\lambda_2 = 2$.** Solve $(A - 2I)v = 0$:
$$\begin{pmatrix}2&1\\2&1\end{pmatrix}\begin{pmatrix}v_1\\v_2\end{pmatrix} = \begin{pmatrix}0\\0\end{pmatrix}.$$

Row 1 gives $2v_1 + v_2 = 0$, so $v_2 = -2v_1$. Again, row 2 is redundant. Taking $v_1 = 1$ gives $v = (1,-2)$.

Verify: $A\begin{pmatrix}1\\-2\end{pmatrix} = \begin{pmatrix}2\\-4\end{pmatrix} = 2\begin{pmatrix}1\\-2\end{pmatrix}$. ✓ The direction $(1,-2)$ is scaled by exactly $2$.

**Summary and payoff:** We've found the two eigenvalues $5$ and $2$, with corresponding eigenvectors $(1,1)$ and $(1,-2)$. By Theorem 10.2, since the eigenvalues are distinct, these eigenvectors are automatically linearly independent — no additional check needed. In the new coordinate system spanned by these two eigenvectors, the matrix $A$ acts as the diagonal matrix $\begin{pmatrix}5&0\\0&2\end{pmatrix}$: it just scales independently in each eigenspace. This is the diagonalization mentioned in Day 11. The journey from "find vectors where $Av = \lambda v$" to "find roots of a polynomial" to "solve homogeneous systems" brings all the threads from Days 3, 8, and 9 together.

Observe that without the systematic approach (Theorem 10.1), you would never find these eigenvectors: you'd have to guess. But with the systematic approach, you formalize the search as a polynomial root-finding problem, which is teachable and computable. This is the power of good mathematical organization: it takes a seemingly impossible search ("find all special vectors") and turns it into a concrete algorithm ("find polynomial roots, then solve linear systems").

**Why this matters.** Once you have the eigenvectors and eigenvalues, you've completely decoded what the matrix does. In the eigenvector basis, $A$ is diagonal — maximally simple. You can compute $A^{100}$ by just raising the diagonal entries to the 100th power. You can solve difference equations and differential equations. You can understand the long-term behavior of repeated applications of $A$. The eigenvectors are the "directions of stability" in dynamical systems. On a larger scale, eigenvalues and eigenvectors are the foundation for spectral theory, which says that symmetric matrices (and more generally, certain classes of matrices) can be completely understood through their eigenvalues and eigenvectors.

The hunt for eigenvalues also illustrates a powerful theme in linear algebra: converting a search over vectors (infinite) into a search over scalars (finite). This is not just a computational shortcut — it's a conceptual shift that reveals the hidden structure in matrices. Whenever you see a matrix, you should be thinking: what are its eigenvalues? What are its eigendirections? These questions pin down everything that matters about how the matrix transforms space. A matrix with eigenvalues 0.5, 0.5, and 2 tells you that two directions shrink by half while one direction stretches by 2 — the long-term behavior of $A^n$ for large $n$ is dominated by that factor-2 direction.

**Practical patterns.** As you compute eigenvalues, you'll notice some recurring patterns. Triangular matrices (upper or lower) always have eigenvalues on the diagonal — no computation needed; just read them off. For instance, $\begin{pmatrix}3&*\\0&2\end{pmatrix}$ has eigenvalues 3 and 2 automatically. Symmetric matrices (where $A = A^T$) always have real eigenvalues and orthogonal eigenvectors (Spectral Theorem, Day 19) — a powerful guarantee. Singular matrices (det = 0) always have $\lambda = 0$ as an eigenvalue (Exercise 7 in day10.md), because $\det(A - 0 \cdot I) = \det(A) = 0$. These patterns are not accidents; they're theorems. When you see a matrix with special structure, pause and ask: what does this structure tell me about eigenvalues?

**A reminder on practice.** When solving for eigenvectors, you'll solve homogeneous systems $(A - \lambda I)v = 0$ by row reduction. These systems always have nontrivial solutions (by construction, since $\det(A - \lambda I) = 0$), so you'll never hit a contradiction like "0 = 1". You'll typically find the free variables and express the solution space as a span of one or more vectors. For a $2 \times 2$ matrix, each eigenvalue usually gives one independent eigenvector (unless the eigenvalue is repeated, which is Day 11's scenario where you might get fewer or even just one eigenvector). For a $3 \times 3$ matrix, each eigenvalue can give one, two, or even three independent eigenvectors, depending on how "degenerate" it is. Always verify your answer by checking that $Av = \lambda v$ for your computed eigenvector $v$. This catch-all verification works because if it fails, you made a computational error.

**Example pitfall.** A common mistake is to forget to subtract $\lambda I$ and just row-reduce $A$ to find the null space. Don't do that — you must solve $(A - \lambda I)v = 0$, not $Av = 0$. The zero eigenvalue ($\lambda = 0$) is the only case where these are the same. Similarly, don't confuse eigenvectors with null-space vectors: eigenvectors are null-space vectors of $A - \lambda I$, not of $A$. The subtraction of $\lambda I$ is not optional; it's essential.

**A final note: scaling.** When you find an eigenvector $v$ for an eigenvalue $\lambda$, any nonzero scalar multiple $cv$ is also an eigenvector for the same $\lambda$ (verify: $A(cv) = c(Av) = c(\lambda v) = \lambda(cv)$). So eigenvectors are defined only up to scaling. We typically choose the "simplest" representative: maybe integer entries, or a unit vector. In a homework or exam, any nonzero scalar multiple is correct. What matters is the direction, not the magnitude.

**Bridge to tomorrow (Day 11).** Today you learned to find eigenvalues and eigenvectors. Tomorrow you'll learn to use them: the big payoff is diagonalization, where you can rewrite $A = PDP^{-1}$, with $P$ a matrix of eigenvectors and $D$ a diagonal matrix of eigenvalues. This diagonal form makes computing $A^n$ and solving systems involving $A$ much easier. For now, make sure you can systematically find eigenvalues (via the characteristic polynomial) and eigenvectors (via homogeneous systems). The rest builds on this foundation.

**Summary: the three steps.** (1) Form $p_A(\lambda) = \det(A - \lambda I)$ (the characteristic polynomial). (2) Solve $p_A(\lambda) = 0$ to find the eigenvalues. (3) For each eigenvalue $\lambda_i$, solve $(A - \lambda_i I)v = 0$ to find the eigenvectors. This three-step procedure is the core algorithm of eigenvalue computation. Practice it until it's automatic.

**Why today matters.** Eigenvalues and eigenvectors are not just abstract concepts — they appear everywhere in practice. In physics, they describe vibrational modes and energy levels. In computer science, they power PageRank (Google's search algorithm) and machine learning (principal component analysis). In dynamical systems, they determine long-term stability. Understanding eigenvalues is understanding what a matrix really does under repeated applications. That's why Days 10–11 are considered the heart of linear algebra: you're learning to read the true nature of matrices.

**FAQ.** Q: "Do all matrices have eigenvalues?" A: Over $\mathbb{C}$ (complex numbers), yes — the Fundamental Theorem of Algebra guarantees $n$ eigenvalues (counting multiplicity) for an $n \times n$ matrix. Over $\mathbb{R}$ (real numbers), no — a real matrix can have complex eigenvalues that don't appear in real pairs. Q: "How many eigenvectors does each eigenvalue have?" A: Infinitely many, since scalar multiples of an eigenvector are also eigenvectors. But the geometric multiplicity (dimension of the eigenspace) is finite, and equals 1 or more (unless the eigenvalue is repeated, which is a subtlety in Day 11). Q: "Can an eigenvalue be zero?" A: Yes. $\lambda = 0$ is an eigenvalue if and only if $A$ is singular, i.e., $\det(A) = 0$ (Exercise 7).

## Flashcards

### Flashcards

**Q:** Define an eigenpair (eigenvalue and eigenvector) precisely.

**A:** $Av = \lambda v$ with $v \ne 0$. The scalar $\lambda$ is the eigenvalue; the vector $v$ is the eigenvector.

**Q:** Why is the requirement $v \ne 0$ essential?

**A:** Because $A0 = \lambda 0$ holds for every scalar $\lambda$. Zero tells you nothing about which direction $A$ leaves alone.

**Q:** State the three-link chain that converts "does a special vector exist?" into "is one number zero?"

**A:** Nonzero solution to $(A - \lambda I)v = 0$ ⟺ nonzero kernel (Day 9) ⟺ singular matrix (Day 4) ⟺ determinant zero (Day 8).

**Q:** What does "eigen" mean, and why is this memory hook useful?

**A:** "Eigen" is German for "own." Eigenvectors are the matrix's own directions — the ones it leaves alone (just scaling them).

**Q:** Can a real matrix have no real eigenvalues? Give an example.

**A:** Yes. A rotation matrix (e.g., $90°$ rotation) has no real eigendirections — every arrow turns. Its eigenvalues are complex.

**Q:** If two eigenvalues are different, what can you say about their eigenvectors?

**A:** They are automatically linearly independent (Theorem 10.2). No additional check needed.

**Q:** Sketch the subtraction trick in Theorem 10.2's proof.

**A:** Apply $A$ to the dependence relation, multiply the same relation by $\lambda_k$, then subtract. One term cancels, creating a shorter dependence that contradicts minimality.

**Q:** Where do the eigenvalues of a triangular matrix sit?

**A:** On the diagonal. The characteristic polynomial is $\det(A - \lambda I) = \prod (a_{ii} - \lambda)$, so the eigenvalues are the diagonal entries.

---

**You've now learned to systematically find eigenvalues and eigenvectors.** These are the "hidden directions" that reveal a matrix's true nature. In Day 11, you'll learn to use them for diagonalization — rewriting a matrix in a simpler form that makes computation and understanding much easier. The journey from Definition 10.1 (what is an eigenvector?) to Theorem 10.1 (how to find eigenvalues?) to the three-step algorithm (the computational procedure) is complete. Practice these steps on the exercises until they become automatic. You now have one of linear algebra's most powerful tools in your toolbox.
