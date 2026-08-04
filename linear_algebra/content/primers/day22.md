# Day 22 Primer — Low-Rank Approximation and Eckart–Young

## Warm-up

Before diving into today's material, ground yourself in three prior ideas that are woven throughout.

Start by recalling the SVD decomposition from Day 21: every matrix $A$ of rank $r$ factors uniquely as $A = \sum_{i=1}^r \sigma_i u_i v_i^T$, where the singular values are sorted in descending order $\sigma_1 \ge \sigma_2 \ge \cdots \ge \sigma_r > 0$, the $u_i$ are orthonormal left singular vectors in $\mathbb{R}^m$, and the $v_i$ are orthonormal right singular vectors in $\mathbb{R}^n$.

The sum-of-rank-1-pieces form $\sum_i \sigma_i u_i v_i^T$ is the foundation for today's entire development: each term $\sigma_i u_i v_i^T$ is a low-rank "layer," and the singular value $\sigma_i$ controls the intensity of that layer.

Second, recall from Day 20 the Frobenius norm, which measures the "total size" of a matrix by $\|X\|_F = \sqrt{\sum_{i,j} X_{ij}^2}$—the root of the sum of all squared entries.

Equivalently, by applying today's Lemma 22.1, when a matrix is written as a sum of orthonormal rank-1 pieces weighted by scalars, the Frobenius norm squared becomes a pure sum of the squared weights, with no cross terms. This Pythagorean structure is the secret to quantifying truncation error cleanly.

Third, recall from Day 15 the rank–nullity theorem: if a linear map $T: \mathbb{R}^n \to \mathbb{R}^m$ has rank $k$, then $\dim(\ker T) = n - k$ exactly.

Today you will use this to count dimensions and discover forced collisions between subspaces—the key idea underlying Eckart–Young's optimality proof.

## The hook

Imagine a grayscale photograph stored as a $1000 \times 1000$ matrix of pixel intensities—one million numbers, each between 0 and 255.

Writing the image as an SVD sum gives $\sigma_1 u_1 v_1^T + \sigma_2 u_2 v_2^T + \cdots + \sigma_r u_r v_r^T$, where the terms are stacked from loudest to quietest.

Each singular value $\sigma_i$ acts as a "volume knob": turning it up amplifies the visual impact of that layer; turning it down mutes it. The first layer (largest $\sigma_1$) captures the coarse, broad structure—perhaps the main subject's outline.

Subsequent layers add texture and detail.

Now here is a radical question: what if you keep only the top 50 layers and throw away all the rest?

Each layer needs one left singular vector (1000 numbers), one right singular vector (1000 numbers), and one singular value (1 number)—so roughly 2001 numbers per layer.

Fifty layers cost about 100,000 numbers total, compared to 1,000,000 for the full image. That is 10-fold compression.

But how much visual detail did you actually lose? And could a *different* rank-50 matrix possibly reconstruct the image *better* than your truncation?

Today you answer both questions with absolute mathematical certainty, not hope or engineering intuition.

## The pictures

Visualize the SVD as a stack of semitransparent sheets, each labeled $\sigma_i u_i v_i^T$.

The first sheet (with the largest $\sigma_1$) is brightest and dominates the visual appearance—it shows the coarsest, most significant structure of the image.

Each subsequent sheet is progressively fainter (smaller singular value) and adds refinement and detail.

The pattern on sheet $i$ (the structure) is determined by the rank-1 matrix $u_i v_i^T$, and the intensity (how much that structure appears) is controlled by $\sigma_i$.

Truncation to rank $k$ means extracting the top $k$ sheets and discarding all the rest. The visual information lost on the discarded sheets is quantified perfectly by the tail singular values.

Picture an energy bar chart where each bar's height represents $\sigma_i^2$. The first $k$ bars are colored to show you are keeping them; the remaining bars are shaded gray to show they are being thrown away.

The total shaded area—$\sigma_{k+1}^2 + \sigma_{k+2}^2 + \cdots + \sigma_r^2$—is exactly the squared error $\|A - A_k\|_F^2$.

This is the key quantification: the error in Frobenius norm depends entirely on the singular values you discard, not on their specific singular vectors.

For Eckart–Young's core argument, visualize a dimension-counting collision.

Picture an abstract $(k+1)$-dimensional room spanned by the top $k+1$ right singular vectors $v_1, v_2, \ldots, v_{k+1}$.

Now picture an $(n-k)$-dimensional room representing the null space of any rank-$k$ competitor matrix $B$—by rank–nullity, if $B$ has rank at most $k$, then $\ker B$ has dimension at least $n-k$.

Both rooms exist inside $n$-dimensional space. Since $(k+1) + (n-k) = n+1 > n$, the two rooms must overlap: they must share at least a line through the origin (a one-dimensional subspace).

That shared line contains the witness vector that Eckart–Young uses to prove $A_k$ cannot be beaten.

## Concrete-first walkthrough

**Definition 22.1:** The rank-$k$ truncation is $A_k = \sum_{i=1}^k \sigma_i u_i v_i^T$.

In plain language, you keep the $k$ loudest layers from the SVD and discard the faint ones.

Note that $A_k$ has rank exactly $k$ (if all the singular values are nonzero), and when $k = r$ (the full rank), you get $A_k = A$ exactly.

When $k = 0$, you get the zero matrix.

Memory hook: **truncation = keep the $k$ largest layers.**

**Lemma 22.1:** This is the pivot on which everything turns.

It says: whenever you write a matrix as a sum of rank-1 pieces with orthonormal left and right factors—specifically, $X = \sum_i c_i w_i z_i^T$ where $w_1, \ldots, w_p$ are orthonormal and $z_1, \ldots, z_p$ are orthonormal—the squared Frobenius norm becomes a pure sum of squared coefficients: $\|X\|_F^2 = \sum_i c_i^2$.

Critically, there are no cross terms, no interactions between different layers. This is a Pythagorean property: the "size" of the combined object is the square root of the sum of squared sizes.

Memory hook: **orthonormal-sums behave like Pythagoras—no cross terms.**

The trick in the proof is expressing $\|X\|_F^2 = \operatorname{trace}(X^T X)$, then expanding $X^T X$ as a double sum.

The orthonormality condition $w_i^T w_j = \delta_{ij}$ (Kronecker delta) kills every cross term where $i \ne j$, leaving only diagonal terms $c_i^2 z_i z_i^T$.

Each $z_i z_i^T$ contributes trace $z_i^T z_i = \|z_i\|^2 = 1$ to the total.

**Theorem 22.1:** This theorem applies Lemma 22.1 directly to the truncation error.

Observe that the remainder $A - A_k = \sum_{i=k+1}^r \sigma_i u_i v_i^T$ is exactly an orthonormal-sum: the left and right factors $u_{k+1}, \ldots, u_r$ and $v_{k+1}, \ldots, v_r$ are orthonormal subsets of the full SVD, and the coefficients are the leftover singular values.

By Lemma 22.1, $\|A - A_k\|_F^2 = \sum_{i=k+1}^r \sigma_i^2$, so taking square roots gives $\|A - A_k\|_F = \sqrt{\sigma_{k+1}^2 + \cdots + \sigma_r^2}$.

This is a complete, elementary proof—nothing is sketched or deferred.

Memory hook: **error² = the discarded tail.**

**Theorem 22.2** (Eckart–Young): This is the crown jewel.

Among *all* matrices of rank at most $k$, the truncation $A_k$ gives the smallest Frobenius-norm approximation to $A$.

This is not a heuristic or rule of thumb; it is a universal guarantee.

The main file presents this in two stages. Stage 1 (fully proved) handles the operator norm using a dimension-counting argument.

Stage 2 (sketched) upgrades to the Frobenius norm and relies on the min-max (Courant–Fischer) characterization of singular values, which is cited without re-proof.

Memory hook: **nobody beats the SVD tail.**

## Proof roadmaps

**Lemma 22.1's trick:** Express the Frobenius norm as $\|X\|_F^2 = \operatorname{trace}(X^T X)$.

Then expand the product $X^T X = (\sum_i c_i z_i w_i^T)(\sum_j c_j w_j z_j^T)$ as a double sum over all pairs $(i, j)$.

Each cross term with $i \ne j$ carries a factor $w_i^T w_j$, which is zero by orthonormality.

Only the diagonal terms $i = j$ survive, producing $\sum_i c_i^2 z_i z_i^T$.

Taking the trace of each rank-1 matrix $z_i z_i^T$ gives $z_i^T z_i = 1$ (the $z_i$ are unit vectors), so the total trace is $\sum_i c_i^2$.

**Theorem 22.1's trick:** Recognize that the error $A - A_k$ is nothing but the tail of the original SVD sum—it is exactly the form Lemma 22.1 was built to handle.

**Theorem 22.2, Stage 1's trick:** Find a single witness vector that belongs to both the null space of any rank-$k$ competitor $B$ and the span of the top $k+1$ right singular vectors.

This requires the critical dimension-counting fact: **if two subspaces of $\mathbb{R}^n$ have dimensions that sum to more than $n$, they must intersect in a nontrivial subspace**.

Here is the argument in full. By the rank–nullity theorem, $\dim(\ker B) = n - \operatorname{rank}(B) \ge n - k$.

The span of $v_1, \ldots, v_{k+1}$ has dimension exactly $k+1$ (the $v_i$ are orthonormal, hence linearly independent).

Thus the dimensions sum to at least $(n-k) + (k+1) = n+1 > n$.

Suppose the two subspaces intersected only at the origin. Then a basis for $\ker B$ plus a basis for $\operatorname{span}(v_1, \ldots, v_{k+1})$ would give $\dim(\ker B) + (k+1)$ linearly independent vectors, all living in $n$-dimensional space—contradiction by the definition of dimension.

Therefore, the two subspaces *must* share at least a one-dimensional subspace (a line). Pick any nonzero vector $x$ in that intersection and normalize it to a unit vector.

This $x$ lies in $\ker B$ (so $Bx = 0$) and in $\operatorname{span}(v_1, \ldots, v_{k+1})$, so $x = \sum_{i=1}^{k+1} c_i v_i$ with $\sum c_i^2 = 1$ by Parseval.

Then $(A-B)x = Ax = \sum_{i=1}^{k+1}\sigma_i c_i u_i$ (SVD expansion), so $\|(A-B)x\|^2 = \sum_{i=1}^{k+1}\sigma_i^2 c_i^2 \ge \sigma_{k+1}^2$ (all $\sigma_i$ in the sum are at least $\sigma_{k+1}$).

Since this holds for any rank-$k$ competitor $B$, no competitor can reduce the operator norm error below $\sigma_{k+1}$, so $A_k$ is unbeatable.

Stage 2 extends this to Frobenius norm; it is a readable sketch in the main file—absorb it as motivation, not as a theorem to memorize.

## Flashcards

**Q:** What is the rank-$k$ truncation $A_k$, and what does it represent?

**A:** Keep only the $k$ largest layers from the SVD: $A_k = \sum_{i=1}^k \sigma_i u_i v_i^T$. Each term is a rank-1 matrix, so $A_k$ is a rank-$\le k$ matrix that approximates $A$.

**Q:** What is the Frobenius error formula when you truncate to rank $k$?

**A:** $\|A - A_k\|_F^2 = \sigma_{k+1}^2 + \sigma_{k+2}^2 + \cdots + \sigma_r^2$—exactly the sum of squares of all the singular values you discard.

**Q:** State the Eckart–Young theorem in one sentence.

**A:** Among all rank-$\le k$ matrices, the SVD truncation $A_k$ minimizes the Frobenius distance to $A$—provably optimal, no other choice works better.

**Q:** Why must the null space of a rank-$k$ matrix and the span of $v_1, \ldots, v_{k+1}$ intersect nontrivially?

**A:** By rank–nullity, $\dim(\ker B) \ge n-k$; the span has dimension $k+1$; the sum $(n-k) + (k+1) = n+1 > n$, so they must overlap.

**Q:** How do you prove that two subspaces with dimension-sum greater than $n$ must share a nonzero vector?

**A:** If they only intersected at the origin, their bases together would give more than $n$ independent vectors in $\mathbb{R}^n$—contradiction. So they must share at least a line.

**Q:** How many numbers must you store to represent rank-$k$ truncation $A_k$ of an $m \times n$ matrix?

**A:** Approximately $k(m + n + 1)$ numbers: $k$ left vectors ($km$), $k$ right vectors ($kn$), and $k$ singular values ($k$). Compare to $mn$ for the full matrix—huge savings when $k \ll \min(m,n)$.

**Q:** Why is SVD truncation provably optimal for low-rank approximation, not just a useful heuristic?

**A:** Eckart–Young is a universal theorem: no rank-$k$ matrix, however cleverly chosen, can achieve smaller Frobenius error—it is optimality by proof, not by luck.
