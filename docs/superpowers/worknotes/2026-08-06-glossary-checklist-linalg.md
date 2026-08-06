# Glossary Term Checklist — Linear Algebra

## Terms

<!-- Days 7, 13, 18, 24, 27 reviewed: no new terms. Days 28-30 (capstone/exam) reviewed: no new terms. -->

<!-- Reappearances (kept off the empty Notes column per column rules; recorded here instead):
     Rank (row 19, Day 4, as dim(im T)) reappears Day 5 as matrix rank via pivots; shown equivalent Day 6.
     Column space (row 32, Day 6) is the matrix analogue of Image (row 18, Day 4).
     Null space (row 34, Day 6) is the matrix analogue of Kernel (row 17, Day 4).
     Elementary matrix (row 41, Day 8) is refined with named types (swap/scale/add) Day 9.
     Similar matrices (row 55, Day 11) is recapped Day 25.
     Orthogonally diagonalizable (row 78, Day 19) contrasts with plain Diagonalizable (row 54, Day 11). -->

| # | Term | Symbol | Day | Theme | Kind | In glossary? | Notes |
|---|------|--------|-----|-------|------|--------------|-------|
| 1 | Vector space | $V$ | 1 | Vector Spaces & Bases | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 2 | Subspace | $W$ | 1 | Vector Spaces & Bases | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 3 | Zero subspace (trivial subspace) | $\{0\}$ | 1 | Vector Spaces & Bases | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 4 | Linear combination |  | 1 | Vector Spaces & Bases | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 5 | Span | $\operatorname{span}(S)$ | 1 | Vector Spaces & Bases | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 6 | Linear independence |  | 2 | Vector Spaces & Bases | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 7 | Linearly dependent |  | 2 | Vector Spaces & Bases | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 8 | Basis | $B$ | 2 | Vector Spaces & Bases | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 9 | Dimension | $\dim V$ | 2 | Vector Spaces & Bases | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 10 | Steinitz Exchange Lemma |  | 2 | Vector Spaces & Bases | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 11 | Basis extension theorem |  | 2 | Vector Spaces & Bases | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 12 | Linear transformation (linear map) | $T: V \to W$ | 3 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term. RESOLVED: glossary owner's fix pass rewrote the body so each formula follows a complete English clause in its own parenthetical; re-verified with strict symbol-deletion test -- passes. |
| 13 | Matrix of a linear transformation | $[T]_{\mathcal B}^{\mathcal C}$ | 3 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 14 | Ordered basis | $\mathcal B$ | 3 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 15 | Composition of linear transformations | $S \circ T$ | 3 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 16 | Kronecker delta | $\delta_{ij}$ | 3 | Linear Maps & Invertibility | notation | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 17 | Kernel (null space of a map) | $\ker T$ | 4 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 18 | Image (range) | $\operatorname{im} T$ | 4 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 19 | Rank (of a linear map) |  | 4 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 20 | Nullity |  | 4 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 21 | Rank-Nullity theorem |  | 4 | Linear Maps & Invertibility | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 22 | Invertible transformation |  | 4 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 23 | Isomorphism |  | 4 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 24 | Injective |  | 4 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 25 | Surjective |  | 4 | Linear Maps & Invertibility | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 26 | Elementary row operation |  | 5 | Elimination & Fundamental Subspaces | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 27 | Row echelon form | REF | 5 | Elimination & Fundamental Subspaces | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 28 | Reduced row echelon form | RREF | 5 | Elimination & Fundamental Subspaces | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 29 | Pivot |  | 5 | Elimination & Fundamental Subspaces | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 30 | Augmented matrix | $[A \mid b]$ | 5 | Elimination & Fundamental Subspaces | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 31 | Rouché–Capelli theorem |  | 5 | Elimination & Fundamental Subspaces | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 32 | Column space | $C(A)$ | 6 | Elimination & Fundamental Subspaces | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 33 | Row space | $\operatorname{Row}(A)$ | 6 | Elimination & Fundamental Subspaces | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 34 | Null space (of a matrix) | $N(A)$ | 6 | Elimination & Fundamental Subspaces | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 35 | Left null space | $N(A^T)$ | 6 | Elimination & Fundamental Subspaces | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 36 | Fundamental Theorem of Linear Algebra, Part 1 |  | 6 | Elimination & Fundamental Subspaces | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 37 | Determinant | $\det(A)$ | 8 | Determinants & Factorizations | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 38 | Minor | $A_{(i,j)}$ | 8 | Determinants & Factorizations | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 39 | Cofactor | $C_{ij}$ | 8 | Determinants & Factorizations | definition | yes | Confirmed -- glossary heading begins with this exact term. RESOLVED: glossary owner's fix pass moved the formula after "multiplied by" and added a plain-English gloss (alternating sign); re-verified with strict symbol-deletion test -- passes. |
| 40 | Cofactor expansion |  | 8 | Determinants & Factorizations | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 41 | Elementary matrix |  | 8 | Determinants & Factorizations | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 42 | Triangular matrix (upper/lower) |  | 8 | Determinants & Factorizations | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 43 | Invertible matrix / inverse | $A^{-1}$ | 9 | Determinants & Factorizations | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 44 | Singular matrix |  | 9 | Determinants & Factorizations | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 45 | Gauss-Jordan elimination |  | 9 | Determinants & Factorizations | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 46 | Unit lower triangular matrix |  | 9 | Determinants & Factorizations | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 47 | LU decomposition | $A = LU$ | 9 | Determinants & Factorizations | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 48 | Eigenvalue | $\lambda$ | 10 | Eigenvalues & Diagonalization | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 49 | Eigenvector | $v$ | 10 | Eigenvalues & Diagonalization | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 50 | Characteristic polynomial | $p_A(\lambda)$ | 10 | Eigenvalues & Diagonalization | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 51 | Algebraic multiplicity | $m$ | 11 | Eigenvalues & Diagonalization | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 52 | Geometric multiplicity | $g$ | 11 | Eigenvalues & Diagonalization | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 53 | Eigenspace | $E_{\lambda_0}$ | 11 | Eigenvalues & Diagonalization | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 54 | Diagonalizable | $A = PDP^{-1}$ | 11 | Eigenvalues & Diagonalization | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 55 | Similar matrices | $B = P^{-1}AP$ | 11 | Eigenvalues & Diagonalization | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 56 | Binet's formula |  | 12 | Eigenvalues & Diagonalization | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 57 | Dominant eigenvalue | $\lambda_{\max}$ | 12 | Eigenvalues & Diagonalization | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 58 | Inner product | $\langle u,v \rangle$ | 14 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 59 | Inner product space |  | 14 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 60 | Norm | $\|v\|$ | 14 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 61 | Cauchy-Schwarz inequality |  | 14 | Inner Products & Orthogonality | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 62 | Triangle inequality |  | 14 | Inner Products & Orthogonality | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 63 | Parallelogram law |  | 14 | Inner Products & Orthogonality | named-object | yes | Confirmed -- glossary heading begins with this exact term. RESOLVED: glossary owner's fix pass states the identity fully in prose ("two vectors," "their sum," "their difference") before demoting the formula to a parenthetical; re-verified with strict symbol-deletion test -- passes. |
| 64 | Orthogonal complement | $W^\perp$ | 15 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 65 | Orthonormal set / orthonormal basis |  | 15 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 66 | Gram-Schmidt process |  | 15 | Inner Products & Orthogonality | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 67 | Orthogonal decomposition | $V = W \oplus W^\perp$ | 15 | Inner Products & Orthogonality | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 68 | Orthogonal projection | $\operatorname{proj}_W(v)$ | 16 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 69 | Best Approximation Theorem |  | 16 | Inner Products & Orthogonality | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 70 | Least squares | $\hat x$ | 16 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 71 | Normal equations | $A^TA\hat x = A^Tb$ | 16 | Inner Products & Orthogonality | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 72 | Residual | $b - A\hat x$ | 16 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 73 | Orthogonal matrix | $Q$ | 17 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 74 | QR decomposition | $A = QR$ | 17 | Inner Products & Orthogonality | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 75 | Condition number | $\kappa(A)$ | 17 | Inner Products & Orthogonality | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 76 | Symmetric matrix | $A = A^T$ | 19 | Spectral Theory & Quadratic Forms | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 77 | Spectral Theorem | $A = Q\Lambda Q^T$ | 19 | Spectral Theory & Quadratic Forms | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 78 | Orthogonally diagonalizable |  | 19 | Spectral Theory & Quadratic Forms | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 79 | Quadratic form | $Q(x) = x^TAx$ | 20 | Spectral Theory & Quadratic Forms | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 80 | Positive definite |  | 20 | Spectral Theory & Quadratic Forms | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 81 | Negative definite |  | 20 | Spectral Theory & Quadratic Forms | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 82 | Positive semidefinite |  | 20 | Spectral Theory & Quadratic Forms | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 83 | Negative semidefinite |  | 20 | Spectral Theory & Quadratic Forms | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 84 | Indefinite |  | 20 | Spectral Theory & Quadratic Forms | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 85 | Sylvester's criterion |  | 20 | Spectral Theory & Quadratic Forms | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 86 | Singular value decomposition (SVD) | $A = U\Sigma V^T$ | 21 | SVD & PCA | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 87 | Singular value | $\sigma_i$ | 21 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 88 | Left singular vector | $u_i$ | 21 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 89 | Right singular vector | $v_i$ | 21 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 90 | Rank-$k$ truncation | $A_k$ | 22 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 91 | Frobenius norm | $\|A\|_F$ | 22 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 92 | Operator norm | $\|M\|_{\text{op}}$ | 22 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 93 | Eckart–Young theorem |  | 22 | SVD & PCA | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 94 | Sample covariance matrix | $C$ | 23 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 95 | Principal component (direction) | $q_k$ | 23 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 96 | Principal component scores | $Xq_k$ | 23 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 97 | Explained variance ratio | $\text{EVR}_k$ | 23 | SVD & PCA | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 98 | Principal Component Analysis (PCA) |  | 23 | SVD & PCA | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 99 | Coordinate vector | $[v]_B$ | 25 | Change of Basis & Trace/Cholesky | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 100 | Change-of-basis matrix | $P$ | 25 | Change of Basis & Trace/Cholesky | definition | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 101 | Cholesky decomposition | $A = LL^T$ | 26 | Change of Basis & Trace/Cholesky | named-object | yes | Confirmed -- glossary heading begins with this exact term, in day-order in its theme section. |
| 102 | Trace | $\operatorname{trace}(A)$ | 26 | Change of Basis & Trace/Cholesky | named-object | yes | added in final-review fix wave — unharvested in Task 1. |
| 103 | Pythagorean theorem for orthogonal vectors |  | 16 | Inner Products & Orthogonality | named-object | yes | added in final-review fix wave — unharvested in Task 1. |

## Symbols

| Symbol | Read as | First day | Meaning sketch |
|--------|---------|-----------|----------------|
| $V$, $W$ | "a vector space $V$; a subspace/subset $W$" | 1 | generic vector-space and subspace labels |
| $\in$ | "is an element of" | 1 | membership |
| $\notin$ | "is not an element of" | 1 | non-membership |
| $\subseteq$ | "is a subset of" | 1 | containment |
| $\mathbb{R}$, $\mathbb{R}^n$ | "the real numbers; real $n$-tuples" | 1 | scalars, and the ambient running-example space |
| $0$ | "the zero vector" | 1 | additive identity; must lie in every subspace |
| $\emptyset$ | "the empty set" | 1 | the set with no elements |
| $\{x : \text{condition}\}$ | "the set of all $x$ such that..." | 1 | set-builder notation |
| $\operatorname{span}(S)$ | "the span of $S$" | 1 | all finite linear combinations of vectors in $S$ |
| $\cap$ | "intersection" | 1 | vectors lying in both sets |
| $\cup$ | "union" | 1 | vectors lying in either set |
| $\implies$ | "implies" | 1 | logical consequence |
| $\sum$ | "summation" | 1 | a finite sum written compactly |
| $\blacksquare$ | "end of proof" | 1 | marks the end of a proof |
| $\iff$ | "if and only if" | 2 | logical equivalence |
| $\Rightarrow$ / $\Leftarrow$ | "the forward / backward half of an iff proof" | 2 | one-directional implication |
| $\setminus$ | "set minus" | 2 | remove these elements |
| $\neq$ | "is not equal to" | 2 | inequality of values |
| $\dim V$ | "the dimension of $V$" | 2 | number of vectors in any basis of $V$ |
| $\|S\|$ | "the size of $S$" | 2 | number of elements in a finite set |
| $\le$ | "is less than or equal to" | 2 | ordering of numbers |
| $T: V \to W$ | "$T$, a map from $V$ into $W$" | 3 | a function between vector spaces |
| $\mapsto$ | "maps to" | 3 | describes what a function does to an input |
| $S \circ T$ | "$S$ after $T$" | 3 | composition — do $T$ first, then $S$ |
| $[T]_{\mathcal B}^{\mathcal C}$ | "matrix of $T$, input basis $\mathcal B$, output basis $\mathcal C$" | 3 | basis-dependent matrix representation |
| $\mathcal B, \mathcal C, \mathcal D$ | "ordered bases" | 3 | fixed lists of basis vectors, coordinate systems |
| $[x]_{\mathcal B}$ | "coordinates of $x$ in basis $\mathcal B$" | 3 | the column of numbers a matrix representation multiplies |
| $a_{ij}$ | "the entry in row $i$, column $j$" | 3 | matrix entry notation |
| $I$ | "the identity matrix" | 3 | leaves every vector unchanged; $1$'s on the diagonal, $0$'s elsewhere |
| $\delta_{ij}$ | "the Kronecker delta" | 3 | $1$ if $i=j$, else $0$ |
| $\ker T$ | "the kernel of $T$" | 4 | all inputs $T$ sends to $0$ |
| $\operatorname{im} T$ | "the image of $T$" | 4 | all outputs $T$ can produce |
| $\{0\}$ | "the zero subspace — only the zero vector" | 4 | a trivial kernel means $T$ is injective |
| $\operatorname{id}_V$ | "the identity map on $V$" | 4 | leaves every vector unchanged |
| $T^{-1}$ | "$T$ inverse" | 4 | the linear map that reverses $T$ |
| $R_i \leftrightarrow R_j$ | "swap rows $i$ and $j$" | 5 | the first elementary row operation |
| $R_i \to R_i + cR_j$ | "replace row $i$ by itself plus $c$ times row $j$" | 5 | the third (most-used) row operation |
| $[A \mid b]$ | "the augmented matrix" | 5 | the coefficients $A$ with right-hand side $b$ attached |
| $\operatorname{rank}(A)$ | "the rank of $A$" | 5 | number of pivots in any echelon form of $A$ |
| $\operatorname{Row}(A)$ | "the row space of $A$" | 5 | the span of $A$'s rows |
| $\supseteq$ | "contains" | 5 | reverse containment, used in set-equality proofs |
| $A^T$ | "$A$ transpose" | 6 | flip rows and columns: row $i$ of $A^T$ is column $i$ of $A$ |
| $C(A)$ | "the column space of $A$" | 6 | everything reachable as $Ax$ |
| $C(A^T)$ | "the row space of $A$, as a column space" | 6 | span of $A$'s rows, second notation |
| $N(A)$ | "the null space of $A$" | 6 | all $x$ with $Ax = 0$ |
| $N(A^T)$ | "the left null space of $A$" | 6 | all $y$ with $y^TA = 0$ |
| $\det(A)$ | "the determinant of $A$" | 8 | a signed volume-scaling factor |
| $M_n(\mathbb{R})$ | "the $n\times n$ real matrices" | 8 | the inputs the determinant eats |
| $A_{(i,j)}$ | "the $(i,j)$ minor of $A$" | 8 | $A$ with row $i$ and column $j$ deleted |
| $C_{ij}$ | "the $(i,j)$ cofactor" | 8 | signed minor used in cofactor expansion |
| $A^{-1}$ | "$A$ inverse" | 9 | the unique matrix that undoes $A$ |
| $[A \mid I]$ | "$A$ augmented with the identity" | 9 | Gauss-Jordan turns this into $[I \mid A^{-1}]$ |
| $A = LU$ | "$A$ factors as lower times upper" | 9 | elimination-without-swaps splits $A$ this way |
| $L$ | "the lower-triangular factor" | 9 | records the elimination multipliers |
| $\lambda$ | "lambda — the stretch factor" | 10 | how much $A$ scales an eigenvector |
| $\det(A - \lambda I)$ | "the determinant test for $\lambda$" | 10 | zero exactly when $\lambda$ is an eigenvalue |
| $p_A(\lambda)$ | "the characteristic polynomial of $A$" | 10 | its roots are the eigenvalues |
| $m$ | "the algebraic multiplicity" | 11 | how many times an eigenvalue repeats as a root of $p_A(\lambda)$ |
| $g$ | "the geometric multiplicity" | 11 | how many independent eigenvectors that eigenvalue actually has |
| $A = PDP^{-1}$ | "$A$ rebuilt from its eigenvectors and eigenvalues" | 11 | $P$'s columns are eigenvectors, $D$'s diagonal their eigenvalues |
| $B = P^{-1}AP$ | "$B$ is $A$ rewritten in new coordinates" | 11 | similarity — conjugating by $P$ |
| $D = \operatorname{diag}(\lambda_1,\dots,\lambda_n)$ | "the diagonal matrix of eigenvalues" | 11 | the simple shape $A$ takes once diagonalized |
| $E_{\lambda_0}$ | "the eigenspace of $\lambda_0$" | 11 | every eigenvector for $\lambda_0$, together with $0$ |
| $\operatorname{trace}(A)$ | "the trace — sum of the diagonal entries" | 11 | unchanged by similarity; equals the sum of eigenvalues |
| $A^k = PD^kP^{-1}$ | "the $k$-th power, computed the cheap way" | 12 | diagonalize once, then only $D^k$ changes with $k$ |
| $D^k$ | "the diagonal raised entrywise to the $k$-th power" | 12 | the only real work left in computing $A^k$ |
| $x_n = Ax_{n-1}$ | "one step of a recurrence is one matrix multiply" | 12 | stacking consecutive terms turns a recurrence into this |
| $\varphi, \psi$ | "phi and psi — the roots $\tfrac{1\pm\sqrt5}{2}$" | 12 | eigenvalues of the Fibonacci matrix; $\varphi$ is the golden ratio |
| $F_n$ | "the $n$-th Fibonacci number" | 12 | its closed form is Binet's formula |
| $\lambda_{\max}$ | "the dominant (largest-magnitude) eigenvalue" | 12 | its size alone decides growth, decay, or steady state |
| $\langle u, v \rangle$ | "the inner product of $u$ and $v$" | 14 | a generalized dot product |
| $\|v\|$ | "the norm (length) of $v$" | 14 | $\sqrt{\langle v,v\rangle}$ |
| $\cos\theta = \langle u,v\rangle/(\|u\|\|v\|)$ | "the cosine of the angle between $u$ and $v$" | 14 | lands in $[-1,1]$ thanks to Cauchy-Schwarz |
| $\langle \cdot,\cdot\rangle_w$ | "a weighted inner product" | 14 | a different but still valid inner product |
| $\|x\|_1$ | "the $\ell_1$ (taxicab) norm" | 14 | a genuine norm not induced by any inner product |
| $W^\perp$ | "$W$-perp — the orthogonal complement of $W$" | 15 | every vector orthogonal to all of $W$ |
| $V = W \oplus W^\perp$ | "$V$ splits as $W$ direct-sum its complement" | 15 | every $v$ is uniquely $w + w'$ with $w \in W$, $w' \in W^\perp$ |
| $u_k = v_k - \sum_{i<k}\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle}u_i$ | "next vector minus its projections onto the earlier ones" | 15 | the Gram-Schmidt step |
| $e_i = u_i/\|u_i\|$ | "$u_i$ rescaled to unit length" | 15 | normalizing to turn orthogonal into orthonormal |
| $(W^\perp)^\perp$ | "the complement of the complement" | 15 | equals $W$ again |
| $\operatorname{proj}_W(v)$ | "the projection of $v$ onto $W$" | 16 | the point of subspace $W$ closest to $v$ |
| $\hat x$ | "x-hat, the least-squares solution" | 16 | best-fit unknowns when $Ax=b$ has no exact solution |
| $A^TA\hat x = A^Tb$ | "the normal equations" | 16 | the always-solvable system whose solution is $\hat x$ |
| $Q^TQ = I$ | "$Q$ is orthogonal" | 17 | orthonormal columns; equivalently $Q^{-1}=Q^T$ |
| $A = QR$ | "$A$ factored as $Q$ times $R$" | 17 | orthonormal columns times upper triangular |
| $\kappa(A)$ | "the condition number of $A$" | 17 | error-amplification factor; $\kappa(A^TA)=\kappa(A)^2$ |
| $A = A^T$ | "$A$ equals its transpose" | 19 | the definition of a symmetric matrix |
| $A = Q\Lambda Q^T$ | "$A$ as $Q$, Lambda, $Q$-transpose" | 19 | the spectral decomposition |
| $\Lambda$ | "capital lambda — the diagonal of eigenvalues" | 19 | eigenvalues of $A$ down the diagonal |
| $v^*$ | "v-star, the conjugate transpose" | 19 | transpose $v$, then conjugate every entry |
| $\bar\lambda$ | "lambda-bar, the complex conjugate" | 19 | equals $\lambda$ exactly when $\lambda$ is real |
| $Q(x) = x^TAx$ | "the quadratic form of $A$" | 20 | a pure quadratic function of $x$ built from symmetric $A$ |
| $y = Q^Tx$ | "the rotated coordinates" | 20 | orthogonal change of variables that diagonalizes the form |
| $\lambda_{\min}$ | "the smallest eigenvalue" | 20 | controls the bound $Q(x) \ge \lambda_{\min}\|x\|^2$ |
| $A = U\Sigma V^T$ | "$A$ factors as: rotate, stretch, rotate" | 21 | the singular value decomposition |
| $U$ | "the output-side rotation" | 21 | orthogonal; columns are the left singular vectors |
| $V^T$ | "the input-side rotation" | 21 | orthogonal; rows are the right singular vectors |
| $\Sigma$ | "the diagonal stretch box" | 21 | its entries $\sigma_i$ are the stretch factors |
| $\sigma_i$ | "sigma-$i$, the $i$-th singular value" | 21 | how much $A$ stretches the $i$-th axis; $\sigma_i=\sqrt{\lambda_i(A^TA)}$ |
| $A^TA$ | "$A$-transpose-$A$" | 21 | the symmetric PSD matrix whose eigen-data builds $V,\Sigma$ |
| $\sum_i \sigma_i u_i v_i^T$ | "$A$ as a sum of rank-1 pieces" | 22 | the SVD rewritten as a weighted sum, heaviest piece first |
| $u_i v_i^T$ | "an outer product" | 22 | a rank-1 matrix; the $i$-th building block of $A$ |
| $A_k$ | "$A$-sub-$k$, the rank-$k$ truncation" | 22 | keep only the top $k$ pieces, drop the rest |
| $\|X\|_F$ | "the Frobenius norm of $X$" | 22 | root of the sum of all squared entries |
| $\|M\|_{\text{op}}$ | "the operator norm of $M$" | 22 | the most $M$ can stretch a unit vector |
| $X$ | "the centered data matrix" | 23 | samples (rows) by features (columns), each column mean $0$ |
| $q_k$ | "the $k$-th principal component direction" | 23 | the line the data is projected onto |
| $Xq_k$ | "the projections onto $q_k$" | 23 | the shadows of the samples on the line through $q_k$ |
| $C = \frac{1}{n-1}X^TX$ | "the sample covariance matrix" | 23 | $p\times p$; entry $(i,j)$ is the covariance of features $i,j$ |
| $\text{EVR}_k$ | "the explained variance ratio" | 23 | fraction of total variance captured by component $k$ |
| $[v]_B$ | "the coordinates of $v$ in basis $B$" | 25 | the weights that rebuild $v$ from $B$'s vectors |
| $P$ | "the change-of-basis matrix" | 25 | its columns are $B'$'s vectors written in $B$-coordinates |
| $[T]_B$ | "the matrix of $T$ in basis $B$" | 25 | how $T$ acts once everything is written in $B$-coordinates |
| $\sum_i \lambda_i$, $\prod_i \lambda_i$ | "the sum / product of the eigenvalues" | 26 | equal the trace and the determinant, respectively |
| $A = LL^T$ | "$A$ splits into lower-triangular times its own transpose" | 26 | the Cholesky factorization |

## Confusable pairs

- kernel / image — both describe a linear map's behavior; input set that collapses to zero vs. output set actually reached
- span / basis — span is any generating set (possibly redundant); a basis is a minimal, linearly independent generating set
- rank / nullity — rank is the dimension of what survives (the image); nullity is the dimension of what collapses (the kernel); they always sum to the domain's dimension
- eigenvalue / eigenvector — the eigenvalue is the scalar stretch factor; the eigenvector is the nonzero direction that scales without rotating
- row space / column space — row space is the span of the rows (lives in $\mathbb{R}^n$); column space is the span of the columns (lives in $\mathbb{R}^m$)
- injective / surjective — injective means no two inputs collide (trivial kernel); surjective means every output is hit (image fills the codomain)
- orthogonal complement / orthogonal projection — the complement $W^\perp$ is a whole subspace of vectors perpendicular to $W$; the projection $\operatorname{proj}_W(v)$ is a single vector, the closest point of $W$ to $v$
- symmetric matrix / orthogonal matrix — symmetric means $A=A^T$ (a condition on one matrix's own transpose); orthogonal means $Q^TQ=I$ (a condition tying a matrix to its inverse) — easy to conflate since both drive the Spectral Theorem
- diagonalizable / orthogonally diagonalizable — diagonalizable only requires $n$ independent eigenvectors ($A=PDP^{-1}$, any invertible $P$); orthogonally diagonalizable requires those eigenvectors to be orthonormal ($A=Q\Lambda Q^T$), which holds automatically only for symmetric matrices
- positive definite / positive semidefinite — definite requires $x^TAx>0$ for every nonzero $x$ (all eigenvalues strictly positive); semidefinite only requires $\ge 0$ (eigenvalues can include zero)
- LU decomposition / QR decomposition — LU factors $A$ into lower- and upper-triangular pieces from plain Gaussian elimination; QR factors $A$ into an orthogonal piece and an upper-triangular piece from Gram-Schmidt
- SVD / Spectral Theorem (eigendecomposition) — the Spectral Theorem diagonalizes only symmetric matrices with one orthogonal matrix ($A=Q\Lambda Q^T$); the SVD factors *any* real matrix using two orthogonal matrices ($A=U\Sigma V^T$)
