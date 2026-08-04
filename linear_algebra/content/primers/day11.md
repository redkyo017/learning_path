# Day 11 Primer — Diagonalization, multiplicities

## Warm-up

Before reading anything new, answer the flashcards at the end of `primers/day10.md`, `primers/day09.md`, and `primers/day04.md` for: Day 10 (eigenvalues and eigenvectors), Day 9 (inverses and change of coordinates), and Day 4 (kernels, images, rank-nullity) (~10 min). Say each answer out loud or on paper *before* flipping. This warm-up keeps the eigenvector definition sharp (today heavily leans on "what is $Av = \lambda v$?"), refreshes your memory of how matrix multiplication carries eigenvectors forward (today's Thm 11.2 reads $AP = PD$ column-by-column to extract eigenvector equations), and recalls why invertibility matters for basis construction and change of coordinates (today's diagonalization is a coordinate change to the eigenbasis, which requires $P$ invertible). You should feel solid on what an eigenvalue and eigenvector are, and comfortable with the invertible-matrix equivalences from Day 9, before diving into multiplicity and diagonalizability today.

## The hook

Compute $A^{100}$ for $A = \begin{pmatrix}4&1\\2&3\end{pmatrix}$ directly. You would have to multiply the matrix by itself 99 times — an astronomical task that scales exponentially with the exponent. Yet pause and multiply a few vectors by hand as a sanity check. Apply $A$ to $(1,1)$: you get $(4+1, 2+3) = (5,5) = 5(1,1)$. The direction never changes, only the length multiplies by 5. Try $(1,-2)$: you get $(4-2, 2-6) = (2,-4) = 2(1,-2)$ — the stretch factor is 2 here. These are special directions: eigenvectors. In the coordinate system where you see only those two magic directions, $A$ becomes the simple diagonal matrix $\begin{pmatrix}5&0\\0&2\end{pmatrix}$. Now computing $A^{100}$ means computing $\begin{pmatrix}5^{100}&0\\0&2^{100}\end{pmatrix}$, and each diagonal entry is just a number raised to a power — brutally feasible, just two scalar exponentiations instead of 99 matrix multiplications. This is the power of diagonalization: changing coordinates to turn a complicated map into a simple scaling. Today answers two critical questions: (1) when can you always switch into an all-eigenvector coordinate system, so $A = PDP^{-1}$ with $D$ diagonal? and (2) what goes wrong when you run short of eigendirections, like the shear matrix from Day 10, which had only one eigendirection but needed two to fill a basis? The answers involve two types of multiplicity for each eigenvalue, and a matching criterion.

## The pictures

**Picture 1: Change of glasses.** Imagine wearing glasses tinted in the color of eigenvectors. The pipeline is: use $P^{-1}$ to translate into eigen-language, then $D$ performs pure scaling on that clean basis, then $P$ translates back to the original language. The equation $A = PDP^{-1}$ means exactly this: the map $A$ in your original coordinate system is identical to the diagonal map $D$ when viewed through the lens of eigenvectors. The same physics, viewed through better glasses, becomes transparent.

**Picture 2: Defective shear.** The matrix $\begin{pmatrix}1&1\\0&1\end{pmatrix}$ has only one eigendirection, the line $\{t(1,0) : t \in \mathbb{R}\}$, with eigenvalue 1. You cannot build a complete grid of eigenvectors — a grid needs two independent rulers, not two parallel ones — so the shear stays un-diagonalizable. Diagonalizability requires a complete basis of eigenvectors, not just some. This matrix captures the case where the budget (algebraic multiplicity) exceeds the delivery (geometric multiplicity).

**Picture 3: Multiplicity budget bars.** Each eigenvalue gets a bar. The algebraic multiplicity $m$ is the budget ceiling — how many times that eigenvalue appears as a root of the characteristic polynomial. The geometric multiplicity $g$ is what's actually delivered — the dimension of the eigenspace. Diagonalizable means: every bar filled to ceiling, i.e., $g = m$ for every eigenvalue. The Jordan block $\begin{pmatrix}4&1\\0&4\end{pmatrix}$ has $m=2$ but $g=1$, so the bar is underfunded and the matrix stays non-diagonalizable.

## Concrete-first walkthrough

**Definitions and slogans.**
Def 11.1 captures two different counts for each eigenvalue $\lambda_0$. The algebraic multiplicity $m$ is the exponent of $(\lambda - \lambda_0)$ in the factorization of $p_A(\lambda)$ — how many times the root repeats. The geometric multiplicity $g$ is the dimension of the eigenspace $E_{\lambda_0} = N(A - \lambda_0 I)$, the set of all eigenvectors for that eigenvalue (plus zero). These two numbers are computed via completely different methods (one via polynomial factorization, the other via row reduction and nullity), which is why they can differ and why matching them is non-trivial. Def 11.2 defines diagonalizable as the existence of matrices $P, D$ with $A = PDP^{-1}$, where $D$ is diagonal and $P$ is invertible. The key slogan: diagonalizable means "the matrix is secretly a diagonal scaling machine once you put on the right coordinate glasses."

**Similar matrices preserve the book.**
Thm 11.1 says: if $B = P^{-1}AP$, then $B$ and $A$ share the characteristic polynomial, hence the same eigenvalues with identical algebraic multiplicities, trace, and determinant. Why? Because conjugation preserves the spectrum. The determinant argument: $\det(B - \lambda I) = \det(P^{-1}(A - \lambda I)P) = \det(P^{-1}) \det(A - \lambda I) \det(P)$. The two determinants of $P$ multiply to give $\det(P^{-1}P) = \det(I) = 1$, leaving $\det(A - \lambda I) = p_A(\lambda)$. Trace uses the cyclic property: trace$(P^{-1}(AP)) =$ trace$(A(PP^{-1})) =$ trace$(A)$. *Important caveat*: similarity does *not* preserve eigenvectors — eigenvectors transform by $P^{-1}$ when you change coordinate systems (the socks-and-shoes lesson from Day 9, applied once more).

**Diagonalizable is equivalent to a full kit of eigenvectors.**
Thm 11.2 is the linchpin: $A$ is diagonalizable iff it has $n$ linearly independent eigenvectors. This is the exact condition needed to make the change-of-basis machinery work. Forward direction: if $A = PDP^{-1}$, multiply on the right by $P$ to get $AP = PD$. Read this column-by-column: the $j$-th column of $AP$ is $Ap_j$, and the $j$-th column of $PD$ is $\lambda_j p_j$ (since $D$ is diagonal). So $Ap_j = \lambda_j p_j$ for each $j$ — each column of $P$ is an eigenvector of $A$. Since $P$ is invertible (given in the diagonalization), its columns are linearly independent (by the invertible-matrix theorem from Day 9). So we have $n$ linearly independent eigenvectors of $A$. Reverse direction: given $n$ linearly independent eigenvectors $p_1, \dots, p_n$ with $Ap_j = \lambda_j p_j$, form an invertible $P$ with them as columns (invertibility is free since they're independent and span $\mathbb{R}^n$), define $D = \operatorname{diag}(\lambda_1, \dots, \lambda_n)$, and the eigenvector equations $Ap_j = \lambda_j p_j$ give $AP = PD$ as matrices. Multiply on the right by $P^{-1}$: $A = PDP^{-1}$, so $A$ is diagonalizable. The bijection is clean: diagonalizability $\iff$ enough independent eigenvectors to fill a basis.

**Multiplicities: budget and actual delivery.**
Lemma 11.1 (the hardest piece today) shows geometric $\le$ algebraic: $g \le m$ for every eigenvalue. Intuition: the budget (how many roots in the polynomial) must be at least as large as the delivery (how many eigenvectors we can produce). This inequality is *never* an equality by accident — it's a fundamental constraint of linear algebra. The construction is the key: take a basis $v_1, \dots, v_g$ of the $\lambda_0$-eigenspace (so $Av_j = \lambda_0 v_j$ for each $j \le g$, and $g = \dim(E_{\lambda_0})$ is the geometric multiplicity). Extend it to a full basis of $\mathbb{R}^n$ using the basis extension theorem (Day 2), and form $P$ with all these vectors as columns (making $P$ invertible). Consider $B = P^{-1}AP$. For $j \le g$: column $j$ of $B$ is $P^{-1}(Av_j) = P^{-1}(\lambda_0 v_j) = \lambda_0(P^{-1}v_j) = \lambda_0 e_j$, so the first $g$ columns of $B$ form the block $\lambda_0 I_g$. The remaining columns (for $j > g$) form some $(n-g) \times (n-g)$ matrix $C$. All entries below row $g$ in the first $g$ columns are zero. Thus $B$ takes the block-upper-triangular form $\begin{pmatrix}\lambda_0 I_g & *\\ 0 & C\end{pmatrix}$. For a block-upper-triangular matrix: the determinant factors as $\det(B - \lambda I) = \det((\lambda_0 - \lambda)I_g) \cdot \det(C - \lambda I_{n-g}) = (\lambda_0 - \lambda)^g \det(C - \lambda I_{n-g})$. So $(\lambda_0 - \lambda)^g$ divides $p_B(\lambda)$, meaning $\lambda_0$ appears as a root of $p_B$ at least $g$ times. By Thm 11.1, $p_B = p_A$, so the algebraic multiplicity of $\lambda_0$ in $p_A$ is at least $g$. Hence $g \le m$ always.

Lemma 11.2 and Cor 11.1 state that eigenspaces for distinct eigenvalues don't overlap (except at zero, the only vector in every subspace) and their bases concatenate into a linearly independent set. Why? Because if a sum of eigenvectors from different eigenspaces is zero, then by Lemma 11.2 (applied to eigenvectors of distinct eigenvalues) each piece must be zero individually. The largest linearly independent set of eigenvectors you can assemble has size exactly $\sum_i g_i$ (the sum of all geometric multiplicities, one per distinct eigenvalue). This is not merely an upper bound — by Cor 11.1 it's achievable by concatenating the eigenspace bases, and it's optimal (you can't exceed it). This is the ceiling for the number of independent eigenvectors available in all of $\mathbb{R}^n$.

**The diagonalizability criterion: the synthesis.**
Thm 11.3 puts it all together: assuming the characteristic polynomial $p_A(\lambda)$ splits into real linear factors (all eigenvalues are real), $A$ is diagonalizable iff geometric $=$ algebraic for *every* eigenvalue. The reasoning is elegant and uses all the pieces built so far. You need exactly $n$ linearly independent eigenvectors to fill a basis for $\mathbb{R}^n$ (so that $P$ is invertible). By Cor 11.1, the maximum independent eigenvectors available is exactly $\sum g_i$. So "$A$ has $n$ independent eigenvectors" is equivalent to "$\sum g_i \ge n$." But Cor 11.1 says the maximum is *exactly* $\sum g_i$, so you can't exceed it. Therefore "$\sum g_i \ge n$" is equivalent to "$\sum g_i = n$" (you can't have more than $n$ linearly independent vectors in $\mathbb{R}^n$ anyway, by Day 2). 

Now apply Lemma 11.1: $g_i \le m_i$ for each eigenvalue $i = 1, \dots, k$. The standing hypothesis says all roots are real, so $\sum m_i = n$ (the multiplicities sum to the degree). Consider the "gaps" or "deficits" $m_i - g_i \ge 0$ (always nonnegative by Lemma 11.1). Their sum is $\sum (m_i - g_i) = \sum m_i - \sum g_i = n - \sum g_i$. If $\sum g_i = n$ (condition for diagonalizability), the right side is zero. Since each gap is nonnegative and they sum to zero, every individual gap must be zero: $m_i - g_i = 0$ for each $i$, i.e., $g_i = m_i$ for all $i$. This is condition (3). Conversely, if condition (3) holds (all multiplicities match), then $\sum g_i = \sum m_i = n$, which is exactly condition (2). So (2) and (3) are equivalent via this gap-summing argument.

### The big trap.

The phrase "distinct eigenvalues implies diagonalizable" is a *sufficient* condition, not a *necessary* one. This catches many learners. The first, easiest corollary is usually "if $A$ has $n$ distinct eigenvalues, then $A$ is diagonalizable" — proved by noting eigenvectors for distinct eigenvalues are independent (Day 10), giving $n$ independent eigenvectors, hence diagonalizability by Thm 11.2. But sufficiency $\ne$ necessity. Three common misunderstandings:

1. **Mistaking sufficiency for necessity:** "A matrix is diagonalizable only if it has distinct eigenvalues." False. The identity $I_n$ has only one eigenvalue $\lambda = 1$ with algebraic multiplicity $m=n$ and geometric multiplicity $g=n$ (every vector is an eigenvector: $(I - 1 \cdot I)v = 0$ for all $v$). They match perfectly, so by Thm 11.3, $I_n$ is diagonalizable. No distinct eigenvalues needed. The multiplicity-matching test (Thm 11.3) is the real, general criterion; distinctness is just an easy sufficient condition.

2. **Confusing algebraic with geometric multiplicity:** "If an eigenvalue has multiplicity 2, then there are 2 independent eigenvectors for it." Not necessarily. The shear matrix $\begin{pmatrix}1&1\\0&1\end{pmatrix}$ has $\lambda=1$ appearing twice in the characteristic polynomial (algebraic multiplicity $m=2$), but the eigenspace is 1-dimensional (geometric multiplicity $g=1$). The single independent eigenvector $(1,0)$ is all you get, even though the polynomial says the root appears twice. Algebraic counts roots; geometric counts independent eigenvectors — they are fundamentally different.

3. **Assuming repeated eigenvalue always blocks diagonalization:** "If an eigenvalue repeats, the matrix can't be diagonalized." Again, wrong. If the repeated eigenvalue's geometric multiplicity matches its algebraic multiplicity, diagonalization is still possible (as $I_n$ shows). The problem arises only when they mismatch. The Jordan block $\begin{pmatrix}4&1\\0&4\end{pmatrix}$ has $m=2, g=1$ (mismatch), so it's non-diagonalizable; but the $2 \times 2$ identity has $m=2, g=2$ (match), so it is diagonalizable.

### Memory hooks and key takes.

Side-by-side comparison: Example 1 vs. Example 2.

**Example 1 (non-diagonalizable):** $A = \begin{pmatrix}2&1\\0&2\end{pmatrix}$. One eigenvalue $\lambda = 2$. Characteristic polynomial $(2-\lambda)^2$ gives algebraic multiplicity $m=2$ (a double root). The eigenspace $E_2 = N(A - 2I) = N\begin{pmatrix}0&1\\0&0\end{pmatrix}$ consists of vectors $(x,y)$ with $y=0$, so it's the line through $(1,0)$, dimension $g=1$ (geometric multiplicity). Since $g=1 < m=2$, the budget exceeds the delivery: you have 2 roots but only 1 independent eigenvector. By Thm 11.3, $A$ does *not* diagonalize. You cannot make an invertible matrix $P$ with 2 independent eigenvectors from a 1-dimensional eigenspace.

**Example 2 (diagonalizable):** $B = \begin{pmatrix}4&1\\2&3\end{pmatrix}$. Characteristic polynomial $(\lambda-5)(\lambda-2)$ gives two distinct eigenvalues: $\lambda=5$ and $\lambda=2$, each with algebraic multiplicity $m_i = 1$. For each eigenvalue, the eigenspace is 1-dimensional (verify by solving $(B - \lambda_i I)v = 0$): eigenvector $(1,1)$ for $\lambda=5$, eigenvector $(1,-2)$ for $\lambda=2$, so both have $g_i = 1$. Since $g_i = m_i$ for every eigenvalue, by Thm 11.3, $B$ diagonalizes: set $P = \begin{pmatrix}1&1\\1&-2\end{pmatrix}$ (two independent eigenvectors as columns) and $D = \begin{pmatrix}5&0\\0&2\end{pmatrix}$ (eigenvalues on the diagonal), and verify $B = PDP^{-1}$.

**Central lesson:** $A$ is diagonalizable iff geometric multiplicity equals algebraic multiplicity for every eigenvalue, period. Distinctness is a red herring — a sufficient but not necessary condition. Test the match, not the distinctness.

Here are the central ideas to carry forward: 

*Def 11.1* (multiplicities) — algebraic multiplicity lives in the characteristic polynomial (how many times a root repeats as a factor); geometric multiplicity lives in the eigenspace dimension (how many independent eigenvectors we can find for that eigenvalue). They are computed via different methods and have no reason to match a priori.

*Thm 11.1* — similar matrices are the same linear map viewed through different coordinate glasses; they share the eigenvalue spectrum, traces, and determinants (but not eigenvectors themselves — eigenvectors transform by $P^{-1}$ when coordinates change).

*Thm 11.2* — diagonalizability is fundamentally a *counting* fact: you need $n$ linearly independent eigenvectors to fill a basis, which you get iff you can make an invertible matrix $P$ whose columns are eigenvectors.

*Lemma 11.1* — geometric $\le$ algebraic always. The hardest idea of the day, but once you see the block-triangular shape after conjugation, the multiplicity jumps out of the determinant formula. The inequality is tight: equality holds precisely when $A$ can be perfectly diagonalized for that eigenvalue.

*Thm 11.3* — the synthesis: diagonalizability is *not* about distinctness of eigenvalues, but about multiplicities matching for every eigenvalue. The identity matrix is a famous counterexample where one repeated eigenvalue fills its entire budget perfectly (all of $\mathbb{R}^n$ is the eigenspace). The Jordan block $\begin{pmatrix}\lambda&1\\0&\lambda\end{pmatrix}$ is the opposite extreme: one repeated eigenvalue with huge algebraic multiplicity but minuscule geometric multiplicity — underfunded, non-diagonalizable. Between these extremes lies everything else.

## Proof roadmaps

### Thm 11.1 (similarity preserves characteristic polynomial).

**Key trick: slide the conjugation through the determinant.** Start with $B - \lambda I = P^{-1}AP - \lambda I$. Insert $P^{-1}P = I$ so that $\lambda I = \lambda P^{-1}P = P^{-1}(\lambda I)P$ (factoring $P^{-1}$ on the left, $P$ on the right). Thus $B - \lambda I = P^{-1}AP - P^{-1}(\lambda I)P = P^{-1}(A - \lambda I)P$. Taking determinants and using multiplicativity, $\det(B - \lambda I) = \det(P^{-1})\det(A - \lambda I)\det(P)$. **Key insight:** The determinants of $P$ and $P^{-1}$ multiply to $\det(P^{-1}P) = \det(I) = 1$, so the $P$'s cancel completely, leaving $\det(B - \lambda I) = \det(A - \lambda I)$. This is why similarity preserves the entire spectrum — the conjugation is "transparent" to determinants. Thus $p_B(\lambda) = p_A(\lambda)$ as polynomials in $\lambda$. Identical polynomials means identical roots and multiplicities. For trace: use the cyclic property trace$(XY) =$ trace$(YX)$. For determinant: set $\lambda = 0$ in the polynomial identity.

### Thm 11.2 (diagonalizable iff n independent eigenvectors).

**Key trick: read the equation $AP = PD$ one column at a time to extract eigenvector equations hidden inside the matrix equation.** This is the cleanest connection between the factorization $A = PDP^{-1}$ and the existence of enough eigenvectors. **Key insight:** The column-by-column comparison reveals that each column of $P$ must satisfy the eigenvector equation $Ap_j = \lambda_j p_j$ — the matrix equation $AP = PD$ is really a stack of $n$ separate eigenvector equations bound together.

*Forward direction:* Assume $A$ is diagonalizable, i.e., $A = PDP^{-1}$ for some invertible $P$ and diagonal $D$. Multiply both sides on the right by $P$: $AP = PD$. Now fix a column index $j \in \{1, \dots, n\}$ and isolate the $j$-th column on both sides. The $j$-th column of $AP$ is $A(p_j)$ where $p_j$ is the $j$-th column of $P$. The $j$-th column of the diagonal matrix $D$ is $D e_j$ (the $j$-th standard basis vector times $D$). Since $D$ is diagonal, $D e_j = \lambda_j e_j$ where $\lambda_j$ is the $j$-th diagonal entry. So the $j$-th column of $PD$ is $P(D e_j) = P(\lambda_j e_j) = \lambda_j (P e_j) = \lambda_j p_j$ (factoring the scalar out, and noting that $P e_j$ is the $j$-th column of $P$, which is $p_j$). Equating the $j$-th columns: $A p_j = \lambda_j p_j$. So each column of $P$ is an eigenvector of $A$! Since $P$ is invertible (by assumption in the factorization), its columns are linearly independent (by the invertible-matrix theorem from Day 9). So we have $n$ linearly independent eigenvectors of $A$.

*Reverse direction:* Assume $A$ has $n$ linearly independent eigenvectors $p_1, \dots, p_n$ of $A$, with corresponding eigenvalues $\lambda_1, \dots, \lambda_n$ (not necessarily distinct). So $Ap_j = \lambda_j p_j$ for each $j$. Form the matrix $P = [\,p_1 \cdots p_n\,]$ (the matrix with these eigenvectors as columns) and $D = \operatorname{diag}(\lambda_1, \dots, \lambda_n)$ (the diagonal matrix with the eigenvalues on the diagonal in order). Since $p_1, \dots, p_n$ are linearly independent, they form a basis of $\mathbb{R}^n$, so $P$ is invertible (Day 9 again). Now the key observation: $Ap_j = \lambda_j p_j$ for each $j$ means that column $j$ of $AP$ equals column $j$ of $PD$ (as matrices, column by column). Since this holds for all $j$, the matrices are equal: $AP = PD$. Multiply both sides on the right by $P^{-1}$: $A = PDP^{-1}$. Hence $A$ is diagonalizable (by Def 11.2).

### Lemma 11.1 (geometric $\le$ algebraic).

**Key trick: extend eigenspace basis to full basis, conjugate to expose block-triangular structure, and read the multiplicity off the first block's size.** **Key insight:** Once you've ordered the basis so that the first $g$ vectors span the eigenspace, similarity to a block-triangular matrix forces $(\lambda_0 - \lambda)^g$ to appear as a factor of the characteristic polynomial, directly revealing the lower bound on algebraic multiplicity.

*Step 1 (construct extended basis):* Let $\lambda_0$ be any eigenvalue of $A$. Take a basis $v_1, \dots, v_g$ of the eigenspace $E_{\lambda_0}$ (so $Av_j = \lambda_0 v_j$ for each $j \le g$, and $g = \dim(E_{\lambda_0})$ is the geometric multiplicity). Extend this to a full basis $v_1, \dots, v_g, v_{g+1}, \dots, v_n$ of $\mathbb{R}^n$ using the basis extension theorem from Day 2. Form the matrix $P = [\,v_1 \cdots v_n\,]$ with all these vectors as columns; $P$ is invertible because its columns form a basis.

*Step 2 (conjugate and observe block shape):* Consider $B = P^{-1}AP$. For each $j \le g$, compute the $j$-th column of $B$. It equals the $j$-th column of $P^{-1}(AP)$, which is $P^{-1}(Av_j) = P^{-1}(\lambda_0 v_j) = \lambda_0(P^{-1}v_j)$. Since $v_j$ is the $j$-th column of $P$, we have $P^{-1}v_j = e_j$. So the $j$-th column of $B$ is $\lambda_0 e_j$. Thus the first $g$ columns of $B$ are $\lambda_0 e_1, \lambda_0 e_2, \dots, \lambda_0 e_g$, forming the block $\lambda_0 I_g$ in the upper-left corner. For $j > g$, columns of $B$ mix with the extended vectors, contributing to some $(n-g) \times (n-g)$ matrix $C$ in the bottom-right. All entries below row $g$ in columns $1$ through $g$ are zero. Thus $B$ has block-upper-triangular form $\begin{pmatrix}\lambda_0 I_g & *\\ 0 & C\end{pmatrix}$.

*Step 3 (extract multiplicity from block determinant):* For a block-upper-triangular matrix, the determinant factors as the product of the diagonal blocks' determinants (a standard fact). Compute $\det(B - \lambda I) = \det\begin{pmatrix}(\lambda_0 - \lambda)I_g & *\\ 0 & C - \lambda I_{n-g}\end{pmatrix} = \det((\lambda_0 - \lambda)I_g) \cdot \det(C - \lambda I_{n-g}) = (\lambda_0 - \lambda)^g \det(C - \lambda I_{n-g})$. (The first determinant equals $(\lambda_0 - \lambda)^g$ because it's a scalar matrix with $\lambda_0 - \lambda$ on all $g$ diagonal entries.) So $(\lambda_0 - \lambda)^g$ divides $p_B(\lambda)$, meaning $\lambda_0$ is a root with multiplicity at least $g$. By Thm 11.1, $p_B = p_A$, so $\lambda_0$ appears in $p_A$ with multiplicity $\ge g$. By definition, that multiplicity is $m$. Hence $g \le m$.

### Thm 11.3 (main diagonalizability criterion).

**Key trick: use Corollary 11.1 to count the maximum independent eigenvectors, apply Lemma 11.1 for an inequality on each eigenvalue, and add them to force equality.** **Key insight:** The nonnegative gaps $m_i - g_i$ sum to zero precisely when each individual gap is zero — this gap-summing argument transforms the condition "$\sum g_i = n$" into "$g_i = m_i$ for every $i$," revealing the deep structure of diagonalizability.

*(1) $\iff$ (2):* This is exactly Thm 11.2 — diagonalizability (existence of $A = PDP^{-1}$) is equivalent to the existence of $n$ linearly independent eigenvectors (the columns of $P$).

*(2) $\iff$ (3):* By Corollary 11.1, the maximum size of a linearly independent set of eigenvectors of $A$ is exactly $\sum_i g_i$ (the sum of the geometric multiplicities). The condition "$A$ has $n$ linearly independent eigenvectors" therefore means "the maximum $\sum g_i$ is at least $n$." But Corollary 11.1 says the maximum is *exactly* $\sum g_i$ — it's achievable by concatenating eigenspace bases — so "$\sum g_i \ge n$" is equivalent to "$\sum g_i = n$" (you cannot exceed $n$ linearly independent vectors in $\mathbb{R}^n$ anyway by Day 2).

Now apply Lemma 11.1: $g_i \le m_i$ for each eigenvalue $i = 1, \dots, k$. The standing hypothesis says $\sum_i m_i = n$ (all eigenvalues are real). Consider the nonnegative "gaps" $m_i - g_i$. Their sum is $\sum (m_i - g_i) = n - \sum g_i$. If $\sum g_i = n$, the right side is zero. Since every gap is nonnegative and they sum to zero, each $m_i - g_i = 0$ individually: $g_i = m_i$ for each $i$. This is condition (3). Converse: if (3) holds ($g_i = m_i$ for all $i$), then $\sum g_i = \sum m_i = n$, which is condition (2).

### Recap: The three-way equivalence.

Today's main finding is Thm 11.3, which packs enormous power into three equivalent statements. Under the standing hypothesis that all eigenvalues are real, the following are equivalent:

(1) $A$ is diagonalizable (i.e., $A = PDP^{-1}$ for some invertible $P$ and diagonal $D$).

(2) $A$ has $n$ linearly independent eigenvectors.

(3) For every eigenvalue of $A$, geometric multiplicity $=$ algebraic multiplicity.

These three conditions are completely equivalent. If you can verify any one of them, the other two follow for free. In practice, (3) is often the easiest to check by hand: for each eigenvalue, compute its algebraic multiplicity (from the characteristic polynomial) and its geometric multiplicity (from the dimension of the null space of $A - \lambda I$), and compare. If they all match, you're done — diagonalization exists. If any mismatch exists, diagonalization is impossible. This is much simpler than explicitly constructing $P$ and $D$ (which is (1)) or verifying $n$ eigenvectors are independent (which is (2)).

## Flashcards

### Flashcards

**Q:** In the factorization $A = PDP^{-1}$, what are $P$ and $D$ exactly?

**A:** $P$'s columns are $n$ linearly independent eigenvectors; $D$ is diagonal with the matching eigenvalues in the same order.

**Q:** Similar matrices share what properties?

**A:** Characteristic polynomial (hence eigenvalues and algebraic multiplicities), trace, and determinant — but NOT eigenvectors.

**Q:** Geometric multiplicity vs algebraic multiplicity: inequality and slogan?

**A:** $g \le m$; the slogan is "delivery never exceeds budget."

**Q:** Full diagonalizability criterion for a real matrix with all real eigenvalues?

**A:** $A$ is diagonalizable iff geometric multiplicity equals algebraic multiplicity for every eigenvalue.

**Q:** Is "n distinct eigenvalues" necessary for diagonalizability?

**A:** No — it is sufficient but not necessary. The identity matrix has one repeated eigenvalue but is fully diagonalizable.

**Q:** What is the classic non-diagonalizable example?

**A:** The shear $\begin{pmatrix}1&1\\0&1\end{pmatrix}$: $\lambda = 1$ with algebraic multiplicity 2 but geometric multiplicity 1.

**Q:** Why compute $A^{100}$ via $PDP^{-1}$ instead of multiplying 99 times?

**A:** Because $A^k = PD^kP^{-1}$ makes $D^k$ trivial (diagonal entries raised to the $k$-th power), and the inner $P^{-1}P$ pairs telescope away.

**Q:** First move in proving geometric $\le$ algebraic (Lemma 11.1)?

**A:** Take a basis of the eigenspace, extend to a full basis, conjugate to expose the block-triangular shape, and read off the multiplicity from the first block's size.
