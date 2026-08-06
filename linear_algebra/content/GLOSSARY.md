# Glossary — Linear Algebra

*Lookup for catch-up: scan for the term you forgot — this is not meant to be read in order. Full treatments live in the day files named in each section header.*

→ [Jump index](#jump-index)

## Notation at a glance

| Symbol | Read as | Meaning |
|--------|---------|---------|
| $V$, $W$ | "a vector space $V$; a subspace/subset $W$" | generic vector-space and subspace labels |
| $\in$ | "is an element of" | membership |
| $\notin$ | "is not an element of" | non-membership |
| $\subseteq$ | "is a subset of" | containment |
| $\mathbb{R}$, $\mathbb{R}^n$ | "the real numbers; real $n$-tuples" | scalars, and the ambient running-example space |
| $0$ | "the zero vector" | additive identity; must lie in every subspace |
| $\emptyset$ | "the empty set" | the set with no elements |
| $\{x : \text{condition}\}$ | "the set of all $x$ such that..." | set-builder notation |
| $\operatorname{span}(S)$ | "the span of $S$" | all finite linear combinations of vectors in $S$ |
| $\cap$ | "intersection" | vectors lying in both sets |
| $\cup$ | "union" | vectors lying in either set |
| $\implies$ | "implies" | logical consequence |
| $\sum$ | "summation" | a finite sum written compactly |
| $\blacksquare$ | "end of proof" | marks the end of a proof |
| $\iff$ | "if and only if" | logical equivalence |
| $\Rightarrow$ / $\Leftarrow$ | "the forward / backward half of an iff proof" | one-directional implication |
| $\setminus$ | "set minus" | remove these elements |
| $\neq$ | "is not equal to" | inequality of values |
| $\dim V$ | "the dimension of $V$" | number of vectors in any basis of $V$ |
| $\lvert S\rvert$ | "the size of $S$" | number of elements in a finite set |
| $\le$ | "is less than or equal to" | ordering of numbers |
| $T: V \to W$ | "$T$, a map from $V$ into $W$" | a function between vector spaces |
| $\mapsto$ | "maps to" | describes what a function does to an input |
| $S \circ T$ | "$S$ after $T$" | composition — do $T$ first, then $S$ |
| $[T]_{\mathcal B}^{\mathcal C}$ | "matrix of $T$, input basis $\mathcal B$, output basis $\mathcal C$" | basis-dependent matrix representation |
| $\mathcal B, \mathcal C, \mathcal D$ | "ordered bases" | fixed lists of basis vectors, coordinate systems |
| $[x]_{\mathcal B}$ | "coordinates of $x$ in basis $\mathcal B$" | the column of numbers a matrix representation multiplies |
| $a_{ij}$ | "the entry in row $i$, column $j$" | matrix entry notation |
| $I$ | "the identity matrix" | leaves every vector unchanged; $1$'s on the diagonal, $0$'s elsewhere |
| $\delta_{ij}$ | "the Kronecker delta" | $1$ if $i=j$, else $0$ |
| $\ker T$ | "the kernel of $T$" | all inputs $T$ sends to $0$ |
| $\operatorname{im} T$ | "the image of $T$" | all outputs $T$ can produce |
| $\{0\}$ | "the zero subspace — only the zero vector" | a trivial kernel means $T$ is injective |
| $\operatorname{id}_V$ | "the identity map on $V$" | leaves every vector unchanged |
| $T^{-1}$ | "$T$ inverse" | the linear map that reverses $T$ |
| $R_i \leftrightarrow R_j$ | "swap rows $i$ and $j$" | the first elementary row operation |
| $R_i \to R_i + cR_j$ | "replace row $i$ by itself plus $c$ times row $j$" | the third (most-used) row operation |
| $[A \mid b]$ | "the augmented matrix" | the coefficients $A$ with right-hand side $b$ attached |
| $\operatorname{rank}(A)$ | "the rank of $A$" | number of pivots in any echelon form of $A$ |
| $\operatorname{Row}(A)$ | "the row space of $A$" | the span of $A$'s rows |
| $\supseteq$ | "contains" | reverse containment, used in set-equality proofs |
| $A^T$ | "$A$ transpose" | flip rows and columns: row $i$ of $A^T$ is column $i$ of $A$ |
| $C(A)$ | "the column space of $A$" | everything reachable as $Ax$ |
| $C(A^T)$ | "the row space of $A$, as a column space" | span of $A$'s rows, second notation |
| $N(A)$ | "the null space of $A$" | all $x$ with $Ax = 0$ |
| $N(A^T)$ | "the left null space of $A$" | all $y$ with $y^TA = 0$ |
| $\det(A)$ | "the determinant of $A$" | a signed volume-scaling factor |
| $M_n(\mathbb{R})$ | "the $n\times n$ real matrices" | the inputs the determinant eats |
| $A_{(i,j)}$ | "the $(i,j)$ minor of $A$" | $A$ with row $i$ and column $j$ deleted |
| $C_{ij}$ | "the $(i,j)$ cofactor" | signed minor used in cofactor expansion |
| $A^{-1}$ | "$A$ inverse" | the unique matrix that undoes $A$ |
| $[A \mid I]$ | "$A$ augmented with the identity" | Gauss-Jordan turns this into $[I \mid A^{-1}]$ |
| $A = LU$ | "$A$ factors as lower times upper" | elimination-without-swaps splits $A$ this way |
| $L$ | "the lower-triangular factor" | records the elimination multipliers |
| $\lambda$ | "lambda — the stretch factor" | how much $A$ scales an eigenvector |
| $\det(A - \lambda I)$ | "the determinant test for $\lambda$" | zero exactly when $\lambda$ is an eigenvalue |
| $p_A(\lambda)$ | "the characteristic polynomial of $A$" | its roots are the eigenvalues |
| $m$ | "the algebraic multiplicity" | how many times an eigenvalue repeats as a root of $p_A(\lambda)$ |
| $g$ | "the geometric multiplicity" | how many independent eigenvectors that eigenvalue actually has |
| $A = PDP^{-1}$ | "$A$ rebuilt from its eigenvectors and eigenvalues" | $P$'s columns are eigenvectors, $D$'s diagonal their eigenvalues |
| $B = P^{-1}AP$ | "$B$ is $A$ rewritten in new coordinates" | similarity — conjugating by $P$ |
| $D = \operatorname{diag}(\lambda_1,\dots,\lambda_n)$ | "the diagonal matrix of eigenvalues" | the simple shape $A$ takes once diagonalized |
| $E_{\lambda_0}$ | "the eigenspace of $\lambda_0$" | every eigenvector for $\lambda_0$, together with $0$ |
| $\operatorname{trace}(A)$ | "the trace — sum of the diagonal entries" | unchanged by similarity; equals the sum of eigenvalues |
| $A^k = PD^kP^{-1}$ | "the $k$-th power, computed the cheap way" | diagonalize once, then only $D^k$ changes with $k$ |
| $D^k$ | "the diagonal raised entrywise to the $k$-th power" | the only real work left in computing $A^k$ |
| $x_n = Ax_{n-1}$ | "one step of a recurrence is one matrix multiply" | stacking consecutive terms turns a recurrence into this |
| $\varphi, \psi$ | "phi and psi — the roots $\tfrac{1\pm\sqrt5}{2}$" | eigenvalues of the Fibonacci matrix; $\varphi$ is the golden ratio |
| $F_n$ | "the $n$-th Fibonacci number" | its closed form is Binet's formula |
| $\lambda_{\max}$ | "the dominant (largest-magnitude) eigenvalue" | its size alone decides growth, decay, or steady state |
| $\langle u, v \rangle$ | "the inner product of $u$ and $v$" | a generalized dot product |
| $\Vert v\Vert$ | "the norm (length) of $v$" | $\sqrt{\langle v,v\rangle}$ |
| $\cos\theta = \langle u,v\rangle/(\Vert u\Vert\Vert v\Vert)$ | "the cosine of the angle between $u$ and $v$" | lands in $[-1,1]$ thanks to Cauchy-Schwarz |
| $\langle \cdot,\cdot\rangle_w$ | "a weighted inner product" | a different but still valid inner product |
| $\Vert x\Vert_1$ | "the $\ell_1$ (taxicab) norm" | a genuine norm not induced by any inner product |
| $W^\perp$ | "$W$-perp — the orthogonal complement of $W$" | every vector orthogonal to all of $W$ |
| $V = W \oplus W^\perp$ | "$V$ splits as $W$ direct-sum its complement" | every $v$ is uniquely $w + w'$ with $w \in W$, $w' \in W^\perp$ |
| $u_k = v_k - \sum_{i<k}\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle}u_i$ | "next vector minus its projections onto the earlier ones" | the Gram-Schmidt step |
| $e_i = u_i/\Vert u_i\Vert$ | "$u_i$ rescaled to unit length" | normalizing to turn orthogonal into orthonormal |
| $(W^\perp)^\perp$ | "the complement of the complement" | equals $W$ again |
| $\operatorname{proj}_W(v)$ | "the projection of $v$ onto $W$" | the point of subspace $W$ closest to $v$ |
| $\hat x$ | "x-hat, the least-squares solution" | best-fit unknowns when $Ax=b$ has no exact solution |
| $A^TA\hat x = A^Tb$ | "the normal equations" | the always-solvable system whose solution is $\hat x$ |
| $Q^TQ = I$ | "$Q$ is orthogonal" | orthonormal columns; equivalently $Q^{-1}=Q^T$ |
| $A = QR$ | "$A$ factored as $Q$ times $R$" | orthonormal columns times upper triangular |
| $\kappa(A)$ | "the condition number of $A$" | error-amplification factor; $\kappa(A^TA)=\kappa(A)^2$ |
| $A = A^T$ | "$A$ equals its transpose" | the definition of a symmetric matrix |
| $A = Q\Lambda Q^T$ | "$A$ as $Q$, Lambda, $Q$-transpose" | the spectral decomposition |
| $\Lambda$ | "capital lambda — the diagonal of eigenvalues" | eigenvalues of $A$ down the diagonal |
| $v^*$ | "v-star, the conjugate transpose" | transpose $v$, then conjugate every entry |
| $\bar\lambda$ | "lambda-bar, the complex conjugate" | equals $\lambda$ exactly when $\lambda$ is real |
| $Q(x) = x^TAx$ | "the quadratic form of $A$" | a pure quadratic function of $x$ built from symmetric $A$ |
| $y = Q^Tx$ | "the rotated coordinates" | orthogonal change of variables that diagonalizes the form |
| $\lambda_{\min}$ | "the smallest eigenvalue" | controls the bound $Q(x) \ge \lambda_{\min}\Vert x\Vert^2$ |
| $A = U\Sigma V^T$ | "$A$ factors as: rotate, stretch, rotate" | the singular value decomposition |
| $U$ | "the output-side rotation" | orthogonal; columns are the left singular vectors |
| $V^T$ | "the input-side rotation" | orthogonal; rows are the right singular vectors |
| $\Sigma$ | "the diagonal stretch box" | its entries $\sigma_i$ are the stretch factors |
| $\sigma_i$ | "sigma-$i$, the $i$-th singular value" | how much $A$ stretches the $i$-th axis; $\sigma_i=\sqrt{\lambda_i(A^TA)}$ |
| $A^TA$ | "$A$-transpose-$A$" | the symmetric PSD matrix whose eigen-data builds $V,\Sigma$ |
| $\sum_i \sigma_i u_i v_i^T$ | "$A$ as a sum of rank-1 pieces" | the SVD rewritten as a weighted sum, heaviest piece first |
| $u_i v_i^T$ | "an outer product" | a rank-1 matrix; the $i$-th building block of $A$ |
| $A_k$ | "$A$-sub-$k$, the rank-$k$ truncation" | keep only the top $k$ pieces, drop the rest |
| $\Vert X\Vert_F$ | "the Frobenius norm of $X$" | root of the sum of all squared entries |
| $\Vert M\Vert_{\text{op}}$ | "the operator norm of $M$" | the most $M$ can stretch a unit vector |
| $X$ | "the centered data matrix" | samples (rows) by features (columns), each column mean $0$ |
| $q_k$ | "the $k$-th principal component direction" | the line the data is projected onto |
| $Xq_k$ | "the projections onto $q_k$" | the shadows of the samples on the line through $q_k$ |
| $C = \frac{1}{n-1}X^TX$ | "the sample covariance matrix" | $p\times p$; entry $(i,j)$ is the covariance of features $i,j$ |
| $\text{EVR}_k$ | "the explained variance ratio" | fraction of total variance captured by component $k$ |
| $[v]_B$ | "the coordinates of $v$ in basis $B$" | the weights that rebuild $v$ from $B$'s vectors |
| $P$ | "the change-of-basis matrix" | its columns are $B'$'s vectors written in $B$-coordinates |
| $[T]_B$ | "the matrix of $T$ in basis $B$" | how $T$ acts once everything is written in $B$-coordinates |
| $\sum_i \lambda_i$, $\prod_i \lambda_i$ | "the sum / product of the eigenvalues" | equal the trace and the determinant, respectively |
| $A = LL^T$ | "$A$ splits into lower-triangular times its own transpose" | the Cholesky factorization |

## Jump index

[Vector Spaces & Bases (Days 1–2)](#vector-spaces--bases-days-12) · [Linear Maps & Invertibility (Days 3–4)](#linear-maps--invertibility-days-34) · [Elimination & Fundamental Subspaces (Days 5–6)](#elimination--fundamental-subspaces-days-56) · [Determinants & Factorizations (Days 8–9)](#determinants--factorizations-days-89) · [Eigenvalues & Diagonalization (Days 10–12)](#eigenvalues--diagonalization-days-1012) · [Inner Products & Orthogonality (Days 14–17)](#inner-products--orthogonality-days-1417) · [Spectral Theory & Quadratic Forms (Days 19–20)](#spectral-theory--quadratic-forms-days-1920) · [SVD & PCA (Days 21–23)](#svd--pca-days-2123) · [Change of Basis & Trace/Cholesky (Days 25–26)](#change-of-basis--tracecholesky-days-2526)

## Vector Spaces & Bases (Days 1–2)

**Vector space ($V$)** — A set of objects (vectors) that you can add together and scale by real numbers, where those two operations obey the usual arithmetic rules (associativity, commutativity, distributivity, an additive identity, and additive inverses). The running example is $\mathbb{R}^n$, but the definition also covers spaces of matrices, polynomials, and functions.

**Subspace ($W$)** — A subset of a vector space that is itself a vector space: it contains the zero vector and is closed under addition and scalar multiplication. Checking just those two closure properties (plus zero) is enough — the other vector-space rules come along for free.

**Zero subspace (trivial subspace) ($\{0\}$)** — The subspace containing only the zero vector. It's the smallest possible subspace of any vector space, and every subspace must contain it.

**Linear combination** — Any sum of vectors, each first scaled by a number and then added up, as in $a_1v_1 + a_2v_2 + \cdots + a_kv_k$. It's the basic building block every other definition in this theme builds on.

**Span ($\operatorname{span}(S)$)** — The set of every linear combination you can build from a set of vectors $S$. The span of any set is always a subspace — the smallest one containing every vector in $S$.

**Linear independence** — A set of vectors is independent if the only way to combine them into the zero vector is to use all-zero weights. Equivalently, no vector in the set can be written as a combination of the others.

**Linearly dependent** — The opposite of independent: some nonzero combination of the vectors adds up to zero, which means at least one vector in the set is redundant — it can be rebuilt from the others.

**Basis ($B$)** — A set of vectors that spans a space and is linearly independent. It's the smallest possible spanning set and the largest possible independent set at once — every vector in the space is a combination of basis vectors in exactly one way.

> **Span vs Basis**
>
> | | Span | Basis |
> |---|---|---|
> | It is… | any generating set, possibly with redundant vectors | a minimal generating set with no redundancy |
> | Shows… | that a space is reachable by combinations | a genuine coordinate system for the space |
> | Compute it by… | listing/collecting vectors, no independence check | checking spanning *and* linear independence |

**Dimension ($\dim V$)** — The number of vectors in any basis of a space. Every basis of the same space has the same size, so this count is a single well-defined number, not a choice-dependent one.

**Steinitz Exchange Lemma** — A spanning set can never be smaller than an independent set living in the same space; formally, if one set spans and another (in the same space) is independent, the independent one has no more vectors than the spanning one. This one fact is what makes "dimension" well-defined at all.

**Basis extension theorem** — Any independent set of vectors can be grown, by adding more vectors from the space, into a full basis of that space. It's the mirror image of trimming a spanning set down to a basis.

## Linear Maps & Invertibility (Days 3–4)

**Linear transformation (linear map) ($T: V \to W$)** — A function between vector spaces that respects addition and scaling: applying it to a sum gives the sum of the outputs ($T(u+v) = T(u)+T(v)$), and applying it to a scaled vector gives that same scaling applied to the output ($T(cv) = cT(v)$). It automatically sends the zero vector to zero and sends every linear combination to that same combination of the outputs.

**Matrix of a linear transformation ($[T]_{\mathcal B}^{\mathcal C}$)** — Once you fix an ordered basis for the input space and one for the output space, a linear map is captured completely by one matrix: its $j$-th column is where the map sends the $j$-th input-basis vector, written in output-basis coordinates. The same map gets a different matrix if you change either basis.

**Ordered basis ($\mathcal B$)** — A basis where the order of the vectors matters, because that order fixes which coordinate slot each basis vector corresponds to. Ordered bases are what let "the matrix of a map" and "the coordinates of a vector" be well-defined lists of numbers rather than unordered sets.

**Composition of linear transformations ($S \circ T$)** — Doing one linear map after another: first apply $T$, then apply $S$ to the result. Composing two linear maps is itself linear, and its matrix is exactly the product of the two maps' matrices, in the same order.

**Kronecker delta ($\delta_{ij}$)** — A shorthand that equals $1$ when its two subscripts match and $0$ otherwise. It's the notation used to say "this is exactly the identity matrix's entries" or "these vectors are orthonormal" without writing out cases.

**Kernel (null space of a map) ($\ker T$)** — Every input a linear map sends to the zero vector. It's always a subspace of the domain, and it measures exactly how much information the map destroys.

**Image (range) ($\operatorname{im} T$)** — Every output a linear map can actually produce. It's always a subspace of the codomain, and it measures exactly what the map can reach.

> **Kernel vs Image**
>
> | | Kernel | Image |
> |---|---|---|
> | It is… | the input set that collapses to zero | the output set actually reached |
> | Lives in… | the domain | the codomain |
> | Shows… | what a map destroys (injectivity fails when this grows) | what a map can produce (surjectivity holds when this fills the codomain) |
> | Matrix view | the null space of the matrix | the column space of the matrix |

**Rank (of a linear map)** — The dimension of a map's image: how many independent directions survive the map. For a matrix, this reappears as the rank found by row reduction — the number of pivots — the same number viewed a second way.

**Nullity** — The dimension of a map's kernel: how many independent directions collapse to zero. Rank and nullity always add up to the dimension of the domain — know one and the input dimension, and the other comes for free.

> **Rank vs Nullity**
>
> | | Rank | Nullity |
> |---|---|---|
> | It is… | the dimension of what survives | the dimension of what collapses |
> | Lives in… | a measurement of the image, inside the codomain | a measurement of the kernel, inside the domain |
> | Compute it by… | number of pivots in echelon form | domain dimension minus rank |

**Rank-Nullity theorem** — For a linear map out of a finite-dimensional space, the dimension of the kernel plus the dimension of the image always equals the dimension of the domain. This is the single fact that ties injectivity, surjectivity, and dimension counting together.

**Invertible transformation** — A linear map that has a two-sided inverse: another linear map that undoes it completely in both directions. Between spaces of equal finite dimension, being invertible is the same thing as being injective, and the same thing as being surjective.

**Isomorphism** — Another name for an invertible linear transformation. Two spaces connected by an isomorphism are called isomorphic, meaning they're really "the same" vector space wearing different labels.

**Injective** — A map where no two different inputs ever produce the same output. For a linear map, this happens exactly when the kernel is trivial (only the zero vector maps to zero) — one condition to check instead of comparing every pair of inputs.

**Surjective** — A map whose image is the entire codomain: every possible output actually gets hit by some input.

> **Injective vs Surjective**
>
> | | Injective | Surjective |
> |---|---|---|
> | It is… | no collisions between inputs | every output gets hit |
> | Shows… | the kernel is trivial | the image fills the codomain |
> | Matrix view | full column rank (no free variables) | full row rank (image is everything) |

## Elimination & Fundamental Subspaces (Days 5–6)

**Elementary row operation** — One of three moves allowed during row reduction: swap two rows, scale a row by a nonzero number, or add a multiple of one row to another. Every one of these moves leaves the solution set of a linear system exactly unchanged — they only re-describe it.

**Row echelon form (REF)** — A matrix shape reached by row reduction where every nonzero row's leading (leftmost nonzero) entry sits strictly to the right of the leading entry in the row above it, and all-zero rows sit at the bottom.

**Reduced row echelon form (RREF)** — Row echelon form taken one step further: every leading entry (pivot) equals $1$ and is the only nonzero number in its column. It's the most "cleaned up" version of a matrix reachable by row operations.

**Pivot** — The first (leftmost) nonzero entry in a nonzero row of an echelon-form matrix. The number of pivots is exactly the rank of the matrix, no matter which legal sequence of row operations produced them.

**Augmented matrix ($[A \mid b]$)** — The coefficient matrix of a linear system with the right-hand-side vector stuck on as an extra column. Row-reducing this single object is how you solve a linear system by hand.

**Rouché–Capelli theorem** — A linear system has at least one solution exactly when adding the right-hand-side column to the coefficient matrix doesn't create a new pivot — that is, when the rank of the augmented matrix equals the rank of the coefficient matrix alone.

**Column space ($C(A)$)** — Every vector reachable as $Ax$ for some input $x$: the span of $A$'s columns. It's the matrix version of a linear map's image, and it lives in the space with as many entries as $A$ has rows.

**Row space ($\operatorname{Row}(A)$)** — The span of $A$'s rows, viewed as vectors. Row reduction never changes the row space, and its dimension equals the rank — the same number that shows up as the column space's dimension, because both come from the same pivots.

> **Row space vs Column space**
>
> | | Row space | Column space |
> |---|---|---|
> | It is… | the span of $A$'s rows | the span of $A$'s columns |
> | Lives in… | $\mathbb{R}^n$ (as many entries as a row) | $\mathbb{R}^m$ (as many entries as a column) |
> | Compute it by… | reading the nonzero rows of an echelon form | reading the pivot columns of the *original* matrix |

**Null space (of a matrix) ($N(A)$)** — Every input $x$ with $Ax = 0$: the matrix version of a linear map's kernel. Its dimension is the number of columns minus the rank.

**Left null space ($N(A^T)$)** — Every vector $y$ with $y^TA = 0$ (equivalently, the null space of $A^T$). Its dimension is the number of rows minus the rank.

**Fundamental Theorem of Linear Algebra, Part 1** — The dimension formulas tying together all four subspaces of a matrix: row space and column space both have dimension equal to the rank; the null space has dimension "columns minus rank"; the left null space has dimension "rows minus rank." It's not new machinery — it's the rank-nullity theorem applied twice, using one row reduction's pivot count.

## Determinants & Factorizations (Days 8–9)

**Determinant ($\det(A)$)** — A single number that measures how much a square matrix scales signed volume: its absolute value is the scaling factor for area/volume, and its sign records whether the matrix flips orientation. A matrix is invertible exactly when its determinant is nonzero.

**Minor ($A_{(i,j)}$)** — The smaller matrix left over after deleting row $i$ and column $j$ from $A$. Minors are the building blocks of cofactor expansion.

**Cofactor ($C_{ij}$)** — A minor's determinant with a sign attached — specifically, the minor's determinant multiplied by $(-1)^{i+j}$, which alternates between $+1$ and $-1$ depending on the row and column deleted. Cofactors are the weighted pieces summed up in cofactor expansion.

**Cofactor expansion** — A recipe for computing a determinant by picking one row (or column), multiplying each entry by its cofactor, and adding up the results. It reduces one big determinant to several smaller ones.

**Elementary matrix** — The identity matrix with a single elementary row operation baked in — a row swap, a row scaled by a number, or a multiple of one row added to another (these three named types are the ones later shown to have their own tidy inverses). Multiplying by one on the left performs that row operation, and every invertible matrix is a product of these — which is exactly why running row reduction on a matrix augmented with the identity computes its inverse.

**Triangular matrix (upper/lower)** — A square matrix that is entirely zero on one side of the diagonal (above it, for lower triangular; below it, for upper triangular). Its determinant and its eigenvalues are both just the product, or the list, of the diagonal entries.

**Invertible matrix / inverse ($A^{-1}$)** — A square matrix $A$ is invertible if some matrix $A^{-1}$ undoes it completely in both directions. That inverse, when it exists, is always unique, and $A$ is invertible exactly when its determinant is nonzero (equivalently, when it has full rank).

**Singular matrix** — A square matrix with no inverse; equivalently, one whose determinant is zero, or whose rank falls short of full.

**Gauss-Jordan elimination** — Row reduction pushed all the way to reduced row echelon form on both sides of a matrix augmented with the identity, so that once the left side becomes the identity, the right side has become the original matrix's inverse.

**Unit lower triangular matrix** — A lower triangular matrix whose diagonal entries are all exactly $1$. This shape is closed under multiplication and inversion, which is exactly why the lower-triangular factor in an $LU$ decomposition always has this form.

**LU decomposition ($A = LU$)** — Splitting a matrix into a unit-lower-triangular factor $L$ and an upper-triangular factor $U$, produced by row-reducing without swaps or scaling. $L$'s entries are just the (negated) multipliers used during elimination — no extra work to find them.

## Eigenvalues & Diagonalization (Days 10–12)

**Eigenvalue ($\lambda$)** — A scalar stretch factor: a number such that some nonzero vector gets scaled (not rotated) by exactly that factor when a matrix acts on it. Eigenvalues are exactly the roots of the characteristic polynomial.

**Eigenvector ($v$)** — A nonzero direction that a matrix only stretches, shrinks, or flips along its own line — never rotates off that line. Eigenvectors belonging to different eigenvalues are automatically linearly independent.

> **Eigenvalue vs Eigenvector**
>
> | | Eigenvalue | Eigenvector |
> |---|---|---|
> | It is… | a scalar (the stretch factor) | a nonzero direction (what gets scaled) |
> | Lives in… | the real (or complex) numbers, on its own | the vector space $A$ acts on — a direction inside the domain |
> | Compute it by… | solving $\det(A-\lambda I)=0$ | solving $(A-\lambda I)v=0$, once $\lambda$ is known |

**Characteristic polynomial ($p_A(\lambda)$)** — The polynomial $\det(A-\lambda I)$, in the variable $\lambda$. Its roots are exactly the eigenvalues of $A$, which turns "find the special vectors" into "find the roots of one polynomial."

**Algebraic multiplicity ($m$)** — How many times an eigenvalue repeats as a root of the characteristic polynomial. A "double root" has algebraic multiplicity $2$, and so on.

**Geometric multiplicity ($g$)** — How many independent eigenvectors an eigenvalue actually has: the dimension of its eigenspace. Geometric multiplicity is never larger than algebraic multiplicity, and a matrix is diagonalizable exactly when the two match for every eigenvalue.

**Eigenspace ($E_{\lambda_0}$)** — All the eigenvectors for one particular eigenvalue, together with the zero vector. It's a genuine subspace, and its dimension is that eigenvalue's geometric multiplicity.

**Diagonalizable ($A = PDP^{-1}$)** — A matrix that can be rebuilt from a full set of eigenvectors: $P$'s columns are independent eigenvectors, and $D$'s diagonal lists the matching eigenvalues. This happens exactly when geometric multiplicity equals algebraic multiplicity for every eigenvalue — distinct eigenvalues are a convenient sufficient condition, but not a necessary one.

**Similar matrices ($B = P^{-1}AP$)** — Two matrices that represent the exact same linear map, just written in different bases. Similar matrices always share the same characteristic polynomial (hence eigenvalues with multiplicity), determinant, and trace — but generally not the same eigenvectors.

**Binet's formula** — The closed-form expression for the $n$-th Fibonacci number, derived by diagonalizing the $2\times2$ matrix that turns the Fibonacci recurrence into repeated matrix multiplication.

**Dominant eigenvalue ($\lambda_{\max}$)** — The eigenvalue with the largest absolute value. Its size alone decides whether repeatedly applying a matrix makes vectors grow without bound, shrink to zero, or settle into a steady state — which is exactly why Markov chains converge to a stationary distribution.

## Inner Products & Orthogonality (Days 14–17)

**Inner product ($\langle u,v \rangle$)** — A generalized dot product: any pairing of two vectors that is symmetric, linear in each argument, and always non-negative when paired with itself (zero only for the zero vector). It's what lets you define length and angle in any vector space, not just $\mathbb{R}^n$.

**Inner product space** — A vector space equipped with an inner product. $\mathbb{R}^n$ with the ordinary dot product is the standard example, but the same three axioms work for spaces of functions too.

**Norm ($\Vert v\Vert$)** — The length of a vector, defined as the square root of its inner product with itself. It's well-defined precisely because an inner product is never negative when paired with itself.

**Cauchy-Schwarz inequality** — The inner product of two vectors is never bigger, in absolute value, than the product of their lengths. This is exactly what keeps the ratio used to define the angle between vectors from ever escaping $[-1,1]$, so "angle" makes sense in any dimension.

**Triangle inequality** — The length of a sum is never more than the sum of the lengths. It follows directly from Cauchy-Schwarz.

**Parallelogram law** — An exact identity that every length coming from an inner product must satisfy: for any two vectors, the squared lengths of their sum and their difference always add up to twice the sum of their own squared lengths ($\Vert u+v\Vert^2 + \Vert u-v\Vert^2 = 2\Vert u\Vert^2 + 2\Vert v\Vert^2$). A norm that fails this identity for even one pair of vectors (like the taxicab norm) can never have come from any inner product.

**Pythagorean theorem for orthogonal vectors** — When two vectors are perpendicular, the squared length of their sum equals the sum of their squared lengths. It's the familiar right-triangle fact from the plane, now proved for any inner product space, and it's the key step behind why an orthogonal projection is always the closest point of a subspace.

**Orthogonal complement ($W^\perp$)** — Every vector perpendicular to an entire subspace $W$. It's itself a subspace, and every vector in the whole space splits uniquely into a piece inside $W$ plus a piece inside $W^\perp$.

**Orthonormal set / orthonormal basis** — A set of vectors that are pairwise perpendicular and each exactly length $1$. An orthonormal set that also happens to be a basis is the friendliest kind of coordinate system a subspace can have.

**Gram-Schmidt process** — A step-by-step recipe that turns any basis into an orthonormal basis of the same span: at each step, subtract off the new vector's projections onto the directions already fixed, then normalize what's left. It preserves every intermediate span along the way, not just the final one.

**Orthogonal decomposition ($V = W \oplus W^\perp$)** — The fact that every vector in a finite-dimensional inner product space splits, in exactly one way, into a part lying in a subspace $W$ plus a part perpendicular to all of $W$.

**Orthogonal projection ($\operatorname{proj}_W(v)$)** — The single point of a subspace $W$ closest to a given vector $v$. The line from $v$ to its projection is always perpendicular to $W$ — that right angle is exactly what makes it the nearest point.

> **Orthogonal complement vs Orthogonal projection**
>
> | | Orthogonal complement | Orthogonal projection |
> |---|---|---|
> | It is… | a whole subspace of perpendicular vectors | a single vector — the closest point of $W$ |
> | Lives in… | the ambient space, as $W^\perp$ | the subspace $W$ itself |
> | Shows… | everything orthogonal to $W$ | the best approximation to $v$ inside $W$ |

**Best Approximation Theorem** — The projection of a vector onto a subspace is the unique closest point of that subspace to it — no other point in the subspace is nearer.

**Least squares ($\hat x$)** — The best-fit set of unknowns when a linear system has no exact solution. Solving least squares is exactly the same thing as projecting the target vector onto the column space of the coefficient matrix — not a separate technique.

**Normal equations ($A^TA\hat x = A^Tb$)** — The always-solvable system whose solution is the least-squares answer. It comes directly from requiring the leftover error to be perpendicular to every column of $A$.

**Residual ($b - A\hat x$)** — What's left over after using the best-fit answer: the gap between the actual data and the model's prediction. It's always perpendicular to the column space being fit into.

**Orthogonal matrix ($Q$)** — A square matrix whose columns are orthonormal, equivalently one satisfying $Q^TQ=I$. Orthogonal matrices preserve every length and angle — they are rotations and reflections, nothing else — and their inverse is just their transpose.

**QR decomposition ($A = QR$)** — Splitting a matrix into an orthonormal-columns factor $Q$ and an upper-triangular factor $R$. It's Gram-Schmidt written down as a matrix product: $R$'s entries are exactly the projection coefficients Gram-Schmidt already computes.

> **LU decomposition vs QR decomposition**
>
> | | LU decomposition | QR decomposition |
> |---|---|---|
> | It is… | lower-triangular times upper-triangular | orthonormal-columns times upper-triangular |
> | Compute it by… | plain Gaussian elimination (no swaps) | Gram-Schmidt on the columns |
> | Shows… | how elimination factors a square matrix | a numerically safer route to least squares |

**Condition number ($\kappa(A)$)** — A single number measuring how much a matrix can amplify error: how much worse a small input error can become after the matrix acts on it. Solving least squares through the normal equations squares this number, which is why QR-based solving is numerically preferred.

## Spectral Theory & Quadratic Forms (Days 19–20)

**Symmetric matrix ($A = A^T$)** — A matrix that equals its own transpose. Every eigenvalue of a real symmetric matrix is real, and eigenvectors for different eigenvalues are automatically perpendicular, not merely independent.

> **Symmetric matrix vs Orthogonal matrix**
>
> | | Symmetric matrix | Orthogonal matrix |
> |---|---|---|
> | It is… | a condition on one matrix's own transpose ($A=A^T$) | a condition tying a matrix to its inverse ($Q^TQ=I$) |
> | Shows… | real eigenvalues, perpendicular eigenvectors | preserves every length and angle |
> | Compute it by… | check the matrix equals its transpose | check the inverse equals the transpose |

**Spectral Theorem ($A = Q\Lambda Q^T$)** — Every real symmetric matrix factors into an orthogonal matrix of eigenvectors and a diagonal matrix of (real) eigenvalues. The upgrade over ordinary diagonalization is that the change-of-basis matrix can always be chosen orthogonal, so inverting it is as easy as transposing it.

**Orthogonally diagonalizable** — A matrix that can be diagonalized using an *orthogonal* change-of-basis matrix. A real matrix has this property exactly when it is symmetric — nothing else qualifies.

> **Diagonalizable vs Orthogonally diagonalizable**
>
> | | Diagonalizable | Orthogonally diagonalizable |
> |---|---|---|
> | It is… | $A=PDP^{-1}$ for *any* invertible $P$ | $A=Q\Lambda Q^T$ for an *orthogonal* $Q$ |
> | Shows… | independent eigenvectors exist | orthonormal eigenvectors exist |
> | Holds automatically for… | matrices whose multiplicities match | symmetric matrices only |

**Quadratic form ($Q(x) = x^TAx$)** — A purely quadratic function of $x$ built from a symmetric matrix $A$. Rotating coordinates by $A$'s eigenvectors turns it into a plain weighted sum of squares, which is why its sign behavior is decided entirely by the signs of $A$'s eigenvalues.

**Positive definite** — A quadratic form that is strictly positive for every nonzero input; equivalently, a symmetric matrix all of whose eigenvalues are positive.

**Negative definite** — A quadratic form that is strictly negative for every nonzero input; equivalently, a symmetric matrix all of whose eigenvalues are negative.

**Positive semidefinite** — A quadratic form that is never negative, though it may be zero for some nonzero input; equivalently, a symmetric matrix all of whose eigenvalues are $\ge 0$.

> **Positive definite vs Positive semidefinite**
>
> | | Positive definite | Positive semidefinite |
> |---|---|---|
> | It is… | strictly positive for every nonzero input | never negative for any input |
> | Eigenvalues are… | all strictly positive | all $\ge 0$ (zero allowed) |
> | Watch out… | positive diagonal entries alone do **not** guarantee this | includes the all-zero matrix as an edge case |

**Negative semidefinite** — A quadratic form that is never positive; equivalently, a symmetric matrix all of whose eigenvalues are $\le 0$.

**Indefinite** — A quadratic form that takes both positive and negative values on different inputs; equivalently, a symmetric matrix with at least one positive and at least one negative eigenvalue.

**Sylvester's criterion** — A shortcut test for positive definiteness that doesn't require finding eigenvalues: a symmetric matrix is positive definite exactly when every one of its leading principal minors (the determinants of its top-left $k\times k$ blocks) is positive.

## SVD & PCA (Days 21–23)

**Singular value decomposition (SVD) ($A = U\Sigma V^T$)** — A factorization that exists for *every* real matrix, of any shape or rank: rotate the input, stretch each axis independently, then rotate the output. It is nothing but the Spectral Theorem applied to the symmetric matrix $A^TA$, with the eigenvectors carried through $A$ to build a second orthonormal basis.

> **SVD vs Spectral Theorem (eigendecomposition)**
>
> | | Spectral Theorem | SVD |
> |---|---|---|
> | It is… | $A=Q\Lambda Q^T$, one orthogonal matrix | $A=U\Sigma V^T$, two orthogonal matrices |
> | Applies to… | symmetric matrices only | *any* real matrix, any shape |
> | Shows… | eigenvalues and eigenvectors | singular values and two singular-vector bases |

**Singular value ($\sigma_i$)** — A non-negative number describing how much a matrix stretches one particular axis; the square root of an eigenvalue of $A^TA$. The largest singular value is exactly the matrix's operator norm, and the count of nonzero singular values equals the matrix's rank.

**Left singular vector ($u_i$)** — A direction in a matrix's output space, one of the columns of the orthogonal matrix $U$ in the SVD. It's the axis that a matched input direction stretches onto.

**Right singular vector ($v_i$)** — A direction in a matrix's input space, one of the columns of the orthogonal matrix $V$ in the SVD; equivalently, an eigenvector of $A^TA$. It's an axis of the unit sphere that gets stretched by the matching singular value.

**Rank-$k$ truncation ($A_k$)** — The matrix built by keeping only the $k$ largest pieces of the SVD sum and dropping the rest. By the Eckart–Young theorem, this is provably the *best possible* rank-$k$ approximation of the original matrix, not merely a reasonable one.

**Frobenius norm ($\Vert A\Vert_F$)** — A matrix's overall "size," computed as the square root of the sum of every entry squared. It equals the square root of the sum of the squares of all the singular values.

**Operator norm ($\Vert M\Vert_{\text{op}}$)** — The most a matrix can stretch any unit vector. It equals the matrix's largest singular value.

**Eckart–Young theorem** — The proof that the SVD's rank-$k$ truncation is the closest possible rank-$k$ (or lower) matrix to the original, measured in Frobenius norm — no other choice of a rank-limited matrix can do better. This is the mathematical justification behind PCA and data/image compression.

**Sample covariance matrix ($C$)** — For centered data (each feature's mean already subtracted off), the matrix whose $(i,j)$ entry is the covariance between features $i$ and $j$. It is always symmetric and positive semidefinite.

**Principal component (direction) ($q_k$)** — The $k$-th eigenvector of the covariance matrix, sorted by eigenvalue — equivalently the $k$-th right singular vector of the centered data. It's the direction of maximum remaining variance once every earlier principal direction has been accounted for.

**Principal component scores ($Xq_k$)** — The data projected onto one principal component direction: one number per sample, describing how far along that direction each sample sits.

**Explained variance ratio ($\text{EVR}_k$)** — The fraction of a dataset's total variance captured by a single principal component: that component's eigenvalue divided by the sum of all the eigenvalues. Adding up these ratios for the top few components tells you how much structure you keep if you discard the rest.

**Principal Component Analysis (PCA)** — Finding a dataset's directions of maximum variance, in order, by eigendecomposing its covariance matrix. It has no separate theory of its own — it is exactly the Spectral Theorem pointed at one specific matrix, with "principal components" just a name for its sorted eigenvectors.

## Change of Basis & Trace/Cholesky (Days 25–26)

**Coordinate vector ($[v]_B$)** — The list of weights that rebuilds a vector $v$ from the vectors of a chosen basis $B$. The same vector gets a different coordinate list under a different basis.

**Change-of-basis matrix ($P$)** — The matrix that converts coordinates from one basis to another: its columns are the new basis's vectors, written in the old basis's coordinates. Conjugating a linear map's matrix by this matrix re-expresses that same map in the new basis — this is exactly what "similar matrices" means.

**Trace ($\operatorname{trace}(A)$)** — The sum of a square matrix's diagonal entries. It equals the sum of the matrix's eigenvalues, counted with multiplicity, and it never changes when the matrix is rewritten in a different basis (similarity) — a free consistency check whenever eigenvalues are computed by hand.

**Cholesky decomposition ($A = LL^T$)** — For a symmetric *positive definite* matrix, a unique factorization into a lower-triangular matrix $L$ (with positive diagonal entries) times its own transpose — a triangular "square root" of $A$. It fails the moment $A$ is only positive semidefinite (has a zero eigenvalue), so definiteness always has to be checked first.
