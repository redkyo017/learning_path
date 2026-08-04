# Day 23 Primer — SVD to PCA: The Spectral Theorem Meets Data

## Warm-up

Before diving in, spend 5 minutes revisiting three crucial predecessors, each of which laid a brick that today's wall stands on.

**Day 16: Orthogonal projections and least squares.** Every symmetric matrix $A$ has an orthonormal eigenbasis $q_1, \ldots, q_p$ and real eigenvalues $\lambda_1 \ge \lambda_2 \ge \cdots \ge \lambda_p$, so $A = Q\Lambda Q^T$. This means any symmetric matrix is completely diagonalized by rotating to the right coordinate system (the eigenvectors). For positive semidefinite matrices (like the covariance matrix you will meet today), all eigenvalues are non-negative. This theorem is the foundation of every dimension-reduction technique.

**Day 21: The SVD—singular value decomposition.** Any real matrix $X$ factors as $X = U\Sigma V^T$ where $U$ has orthonormal columns (left singular vectors), $\Sigma$ is diagonal (singular values), and $V$ has orthonormal columns (right singular vectors). A critical identity emerges: $X^TX = V(\Sigma^T\Sigma)V^T$. This means the columns of $V$ are eigenvectors of $X^TX$, and $\sigma_i^2$ are the eigenvalues. So the SVD *is* the spectral decomposition of $X^TX$.

**Day 22: Quadratic forms and their geometry.** For a symmetric matrix $A$ and a direction $w$, the quadratic form $w^TAw$ tells you how $A$ "stretches" the space along $w$: if $w$ is an eigenvector, $w^TAw = \lambda$ (the eigenvalue), and the quadratic form measures the magnitude of stretch. Today, you will see that "how much does the data spread along direction $w$?" is answered by a specific quadratic form: $w^TCw$, where $C$ is the covariance matrix.

Today synthesizes these three. PCA is not a new algorithm—it is the Spectral Theorem applied to one specific symmetric matrix constructed from your data: the covariance matrix. The entire theory hinges on a single recognition: "the direction along which data spreads the most" is precisely "an eigenvector of the covariance matrix," and "how much the data spreads along that direction" is precisely "the corresponding eigenvalue." Every mathematical piece is already in your hands; today just shows how they snap together. The philosophical payoff is profound: after today, you will never again see "PCA" as a black-box technique to memorize from the ML toolbox. You will see it as a direct application of something you already fully own.

## The hook

Picture this: a scatter of points in two dimensions. Take the five specific centered data points from Theorem 23.1's worked example in the main file: $(2,1), (1,2), (-1,-2), (-2,-1), (0,0)$. If you plot these by hand on graph paper right now, you will immediately see a visual structure: the points are not a random blob. Instead, they cluster roughly along a diagonal line running from bottom-left to top-right at roughly $45°$. The spread is concentrated along that diagonal; perpendicular to it (the other diagonal), the points are tightly bunched. This asymmetric spread—much variation in one direction, little in the perpendicular direction—is exactly what PCA exploits and quantifies.

Now ask a concrete question: if I project these five points onto the horizontal $x$-axis (direction $w = (1,0)$), how spread out are their one-dimensional shadows? The projections land at $2, 1, -1, -2, 0$ on the $x$-axis. Computing sample variance: $(1/(n-1)) \sum (x_i - \bar x)^2 = (1/4) \cdot (4+1+1+4+0) = 2.5$. Project onto the vertical $y$-axis ($w = (0,1)$): projections at $1, 2, -2, -1, 0$, and variance is also $2.5$. But here is the critical insight: project onto the $45°$ diagonal ($w = (\tfrac{1}{\sqrt2}, \tfrac{1}{\sqrt2})$): the projections are $\tfrac{3}{\sqrt2}, \tfrac{3}{\sqrt2}, -\tfrac{3}{\sqrt2}, -\tfrac{3}{\sqrt2}, 0$. Computing the variance: $(1/4) \cdot 4 \cdot (9/2) = 4.5$. The diagonal captures nearly *twice* as much variance as either coordinate axis alone.

This is PCA's core insight: *there exists a single unit direction through feature space that preserves more of the data's spread than any other direction—and it is not arbitrary, but determined algebraically as the top eigenvector of the covariance matrix $C$.* The maximum variance along this direction is the top eigenvalue $\lambda_1$. Today derives exactly which direction, how much variance it captures, and why this is the complete solution to finding all principal components at once.

## The pictures

*Picture 1: The covariance ellipse with its principal axes labeled.*

A 2D scatter plot of the five centered data points from above. Overlay a tilted ellipse that roughly encloses the cloud. This is the "covariance ellipse," whose shape is determined entirely by the covariance matrix $C$.

The major (long) axis of the ellipse points northeast at $45°$—this is the direction of maximum variance, the first principal component direction $q_1$. The minor (short) axis points northwest at $-45°$ (perpendicular), representing the direction of minimum variance, $q_2$.

The key observation: the axes of the covariance ellipse *are the eigenvectors of $C$*, and the ratio of axis lengths is $\sqrt{\lambda_1/\lambda_2}$. Since $\lambda_1 = 4.5$ and $\lambda_2 = 0.5$, the ratio is $\sqrt{9} = 3$: the major axis is three times as long as the minor. This ratio encodes visually that the top eigenvalue dominates.

*Picture 2: Variance captured by three candidate directions—side-by-side comparison.*

Display the same cloud of five centered points three times, positioned side-by-side. In subplot 1, project all five points onto the horizontal $x$-axis and draw the one-dimensional shadows falling straight down. Beneath this projected view, label the variance as $2.5$.

In subplot 2, project onto the vertical $y$-axis, plot the shadows, label variance $2.5$. In subplot 3, project onto the $45°$ diagonal line, plot the shadows (now much more spread out), and label variance $4.5$.

The visual payoff is immediate and intuitive: the first two subplots show short, tight collections of shadows; the third spreads them wide. This empirical observation motivates today's theorem: among all directions, the diagonal one captures the data's structure and spread more faithfully.

*Picture 3: Explained variance decay across components—dimensionality reduction motivation.*

Fast-forward to higher dimensions. Suppose you have a real dataset with $p = 4$ features (like the Iris dataset in the code lab to come). After computing the covariance matrix $C$ and its eigendecomposition, you obtain four eigenvalues $\lambda_1 \ge \lambda_2 \ge \lambda_3 \ge \lambda_4 \ge 0$.

Draw a bar chart of these four eigenvalues. Below or beside it, plot the cumulative explained variance ratio: $\text{EVR}_{\text{cumulative}}(k) = \sum_{i=1}^k \lambda_i / (\sum_j\lambda_j)$ for $k = 1, 2, 3, 4$.

Typically, this curve drops steeply at first (the top components capture much of the story) and flattens (later components add little). Use it to answer: how many top components do I need to keep to capture $95\%$ of the total variance? If the cumulative curve reaches $0.92$ after two components but $0.97$ after three, then three components are necessary to cross the $95\%$ threshold.

## Concrete-first walkthrough

**Theorem 23.1: Centering turns variance into a quadratic form—the bridge.**

The sample variance of the one-dimensional projections $Xw$ onto a unit direction $w \in \mathbb{R}^p$ equals exactly $w^TCw$, where $C = \frac{1}{n-1}X^TX$ is the sample covariance matrix and $X \in \mathbb{R}^{n \times p}$ has centered columns (each column sums to zero).

This theorem translates a geometric question—"which direction preserves the most spread?"—into a linear-algebra question: "which direction maximizes the quadratic form $w^TCw$?"

The proof hinges on centering. Step 1: if each column of $X$ is mean-zero, then any linear combination $Xw$ is also mean-zero. Why? Because $Xw = \sum_j w_j x_{(j)}$ is a linear combination of mean-zero vectors, and a linear combination of mean-zero quantities has mean zero (by linearity of expectation).

Step 2: for any mean-zero vector $v$, the sample variance simplifies to $\frac{1}{n-1}\|v\|^2$ (no mean to subtract from entries).

Step 3: apply this to $v = Xw$, giving $\operatorname{Var}(Xw) = \frac{1}{n-1}\|Xw\|^2$.

Step 4: expand $\|Xw\|^2 = w^TX^TXw$ using the inner-product definition, then factor out $\frac{1}{n-1}$ to get $w^TCw$.

This translation—from "how spread out are the projections?" to "evaluate this quadratic form"—is the entire conceptual bridge connecting geometry to linear algebra.

**Definition 23.1: The covariance matrix—data's spread encoded as a matrix.**

The sample covariance matrix $C = \frac{1}{n-1}X^TX \in \mathbb{R}^{p \times p}$ is a $p \times p$ symmetric matrix that encodes all pairwise second-order correlations in the data.

Entry $(i,j)$ is the sample covariance between features $i$ and $j$; diagonal entry $C_{ii}$ is the variance of feature $i$ alone.

The factor $\frac{1}{n-1}$ (Bessel's correction) is a statistics convention ensuring unbiased estimation; for our linear-algebra purposes, it is just a positive constant that scales all eigenvalues uniformly without changing the eigenvectors.

The covariance matrix is the "spread machine": feed it a direction $w$, and out comes $w^TCw$, a measure of spread along that direction.

**Theorem 23.2: $C$ is symmetric and positive semidefinite—the Spectral Theorem's setup.**

Symmetry is one line: $(X^TX)^T = X^T(X^T)^T = X^TX$.

Positive semidefiniteness (the statement $w^TCw \ge 0$ for every $w \in \mathbb{R}^p$) follows immediately from the identity $w^TCw = \frac{1}{n-1}\|Xw\|^2 \ge 0$ (a squared norm is always non-negative, and $\frac{1}{n-1} > 0$).

These two properties are precisely the hypotheses the Spectral Theorem (Day 19) requires. Therefore, $C$ has an orthonormal eigenbasis $q_1, \ldots, q_p$ with real, non-negative eigenvalues $\lambda_1 \ge \lambda_2 \ge \cdots \ge \lambda_p \ge 0$.

The non-negativity of eigenvalues follows from: if $Cq_i = \lambda_i q_i$ with $\|q_i\| = 1$, then $\lambda_i = q_i^TCq_i \ge 0$ (by positive semidefiniteness).

**Theorem 23.3: The maximum-variance direction is the top eigenvector—PCA's beating heart.**

Among all unit vectors $w \in \mathbb{R}^p$, the maximum value of the quadratic form $w^TCw$ is the largest eigenvalue $\lambda_1$, and this maximum is attained uniquely (up to sign) at the top eigenvector $q_1$.

This is the central theorem of PCA. It says: searching for "the direction of maximum spread in the data" is equivalent to finding the top eigenvector of $C$.

Corollary 23.3.1 extends: the second principal component direction is the second eigenvector $q_2$, maximizing variance among all unit directions orthogonal to $q_1$; the third is $q_3$, and so on.

The profound consequence: because the Spectral Theorem hands you all $p$ eigenvectors at once in a single orthonormal basis, already sorted by eigenvalue size, you solve PCA in a single step. Eigendecompose $C$ once. All principal components are immediately available—no re-optimization needed at each step.

**Definition 23.2: Explained variance ratio—the interpretability metric.**

Component $k$ explains the fraction $\text{EVR}_k = \lambda_k / \sum_j\lambda_j$ of the total variance.

This ratio answers: "Of all the spread in my data, what fraction does this component's direction capture?"

Practitioners use it for dimensionality reduction: keep the top $m$ components such that $\sum_{k=1}^m \text{EVR}_k \ge \tau$ for some threshold like $\tau = 0.95$ or $0.99$.

In the worked example, $\lambda_1 = 4.5, \lambda_2 = 0.5$, total $= 5$. Thus $\text{EVR}_1 = 90\%$ and $\text{EVR}_2 = 10\%$—the first component dominates.

This is why PCA is powerful for dimensionality reduction: often, a small number of top components capture $95\%$ or more of the total variance, so you can work with a much lower-dimensional dataset without losing essential structure.

**Remark 23.1: Connection to SVD—PCA is reading SVD through the eigenvalue lens.**

From Day 21, if $X = U\Sigma V^T$ is the SVD of the centered data matrix, then $X^TX = V(\Sigma^T\Sigma)V^T$ (using $U^TU = I$).

The matrix $\Sigma^T\Sigma$ is diagonal with entries $\sigma_1^2, \ldots, \sigma_r^2, 0, \ldots, 0$ (where $r \le \min(n,p)$ is the rank). Therefore, the columns of $V$ are the eigenvectors of $X^TX$, and $\sigma_i^2$ are the corresponding eigenvalues.

Since $C = \frac{1}{n-1}X^TX$, the eigenvectors of $C$ are the columns of $V$ (unchanged by positive scaling), and the eigenvalues are $\lambda_i = \frac{\sigma_i^2}{n-1}$.

So running PCA via eigendecomposition of $C$ is algebraically identical to computing the SVD of $X$ and reading off its right singular vectors as the principal components. In practice, PCA implementations often use SVD internally because it is numerically more stable than direct eigendecomposition.

## Proof roadmaps

**Theorem 23.1—Key trick: Factor the direction $w$ out of the squared projections.** 

Write the variance of $v = Xw$ as $\operatorname{Var}(v) = \frac{1}{n-1}\sum_i v_i^2 = \frac{1}{n-1}\sum_i (x_i^Tw)^2$ (where $x_i^T$ is row $i$ of $X$). Expand $(x_i^Tw)^2 = w^Tx_ix_i^Tw$. 

Rewrite the sum as $\frac{1}{n-1}\sum_i w^Tx_ix_i^Tw$. Factor $w$ and $w^T$ outside: $w^T\left(\frac{1}{n-1}\sum_i x_ix_i^T\right)w$. 

Recognize that $\sum_i x_ix_i^T = X^TX$ (the outer-product sum equals the Gram matrix), so the whole thing is $w^T\left(\frac{1}{n-1}X^TX\right)w = w^TCw$. 

The magic: by recognizing the sum as a matrix product, you trade a summation for a quadratic form, enabling the rest of the theory.

**Theorem 23.2—Key tricks: Symmetry in one line; PSD from dropping the unit-length assumption.** 

For symmetry, just apply transpose rules: $C^T = \left(\frac{1}{n-1}X^TX\right)^T = \frac{1}{n-1}(X^TX)^T = \frac{1}{n-1}X^T(X^T)^T = \frac{1}{n-1}X^TX = C$.

For positive semidefiniteness, notice that in Theorem 23.1's proof, the identity $w^TCw = \frac{1}{n-1}\|Xw\|^2$ never actually used the assumption $\|w\|=1$. It holds for any $w$ by pure algebra.

So for any $w$: $w^TCw = \frac{1}{n-1}\|Xw\|^2 \ge 0$ (squared norms are non-negative, and $\frac{1}{n-1} > 0$). This is exactly the definition of positive semidefiniteness.

**Theorem 23.3—CRITICAL: Learn the eigenbasis proof, not the calculus proof. The main file's Lagrange-multiplier derivation is optional reading.**

The main Theorem 23.3 in `content/day23.md` uses Lagrange multipliers and multivariable calculus (computing partial derivatives, gradient vectors), which requires prerequisites outside this course. Instead, master this calculus-free proof using only the Spectral Theorem and algebra.

**Step 1:** Expand the unit vector $w$ in $C$'s orthonormal eigenbasis (Spectral Theorem, Day 19): $w = \sum_{i=1}^p c_iq_i$, where $\sum_i c_i^2 = 1$ (the constraint $\|w\|^2 = 1$, by orthonormality).

**Step 2:** Compute $w^TCw = \left(\sum_i c_iq_i\right)^T C\left(\sum_j c_jq_j\right) = \sum_i\sum_j c_ic_jq_i^TCq_j$. Using $Cq_j = \lambda_jq_j$ and $q_i^Tq_j = \delta_{ij}$ (orthonormality), this simplifies to $\sum_i c_i^2\lambda_i$.

**Step 3:** Recognize $\sum_i \lambda_ic_i^2$ as a weighted average of the eigenvalues, with weights $c_i^2 \ge 0$ summing to $1$.

**Step 4:** A weighted average cannot exceed its maximum ingredient: $\sum_i\lambda_ic_i^2 \le \lambda_1 \cdot \max_i c_i^2 \le \lambda_1 \cdot 1 = \lambda_1$. Equality holds if and only if all weight is on the $\lambda_1$ term—that is, $c_i = 0$ for $i > 1$, so $w = \pm q_1$. This one-liner proof also yields Corollary 23.3.1 automatically.

**Corollary 23.3.1—Key trick: Orthogonality constraints vanish automatically in the eigenbasis.**

To find component $k$, maximize $w^TCw$ over unit vectors orthogonal to $q_1, \ldots, q_{k-1}$. The standard approach adds $k-1$ Lagrange multipliers for orthogonality constraints and differentiates. In the eigenbasis approach, orthogonality is automatic.

If $w \perp q_1, \ldots, q_{k-1}$, then in the expansion $w = \sum c_iq_i$, the first $k-1$ coefficients must be zero: $w^Tq_j = c_j = 0$ for $j < k$.

Therefore, $w^TCw = \sum_i c_i^2\lambda_i$ collapses to $\sum_{i=k}^p c_i^2\lambda_i \le \lambda_k\sum_{i=k}^p c_i^2 = \lambda_k$ (using $\lambda_k \ge \lambda_{k+1} \ge \cdots$). The maximizer is $w = q_k$.

This is why sorting $C$'s eigenvectors by eigenvalue size produces all principal components at once.

## Flashcards

### Flashcards

**Q:** What single matrix encodes "how much does the data spread along any direction $w$"?

**A:** The sample covariance matrix $C = \frac{1}{n-1}X^TX$ (where $X$ is centered data). Theorem 23.1 proves: variance along a unit direction $w$ is exactly $w^TCw$, translating a geometric question into a quadratic form.

**Q:** What is PCA's core result, stated in one sentence?

**A:** Among all unit directions $w$, the maximum variance is the top eigenvalue $\lambda_1$ of $C$, achieved at $w = q_1$ (the top eigenvector). This eigenvector is the first principal component.

**Q:** What is the calculus-free proof of Theorem 23.3?

**A:** Expand $w = \sum c_iq_i$ in $C$'s eigenbasis; then $w^TCw = \sum \lambda_ic_i^2$ is a weighted average of eigenvalues. Since weights sum to $1$, the average is bounded by $\lambda_1$, with equality when $w = q_1$.

**Q:** How is the second principal component $q_2$ determined mathematically?

**A:** It maximizes $w^TCw$ among all unit vectors orthogonal to $q_1$. Corollary 23.3.1 proves this maximum is $\lambda_2$, attained at $w = q_2$—the runner-up eigenvector.

**Q:** Why must you center the data matrix $X$ before running PCA?

**A:** Centering ensures $Xw$ is mean-zero, so $\operatorname{Var}(Xw) = \frac{1}{n-1}\|Xw\|^2 = w^TCw$ (Theorem 23.1). Without centering, the data's mean distance from the origin masquerades as spread, corrupting the analysis.

**Q:** What does the explained variance ratio $\text{EVR}_k$ tell you, and how do you use it in practice?

**A:** $\text{EVR}_k = \lambda_k / \sum_j\lambda_j$ (Definition 23.2) is the fraction of total variance that component $k$ captures. Keep the top $m$ components such that $\sum_{k=1}^m \text{EVR}_k \ge 0.95$ for dimensionality reduction decisions.

**Q:** How does PCA relate concretely to the SVD of $X$ from Day 21?

**A:** The right singular vectors in $X = U\Sigma V^T$ are exactly the eigenvectors of $X^TX$, hence of $C$. Remark 23.1 shows: $\lambda_k = \sigma_k^2/(n-1)$. PCA is the SVD read through the eigenvalue lens.

**Q:** What assumption about prerequisites does the Lagrange-multiplier proof of Theorem 23.3 require?

**A:** It requires multivariable calculus (partial derivatives, Hessian matrices) outside this course's scope. Instead, learn the eigenbasis proof: expand $w$ in $C$'s basis, note $w^TCw = \sum \lambda_ic_i^2$ is a weighted average, bound by $\lambda_1$.
