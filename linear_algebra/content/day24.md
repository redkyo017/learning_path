# Day 24 — Review (Days 19–23)

## Purpose

Closed-book retrieval practice on symmetric matrices, the spectral theorem,
quadratic forms, SVD, and PCA. No new theory today — spaced review beats a
single linear pass, per the plan's design rationale.

## Instructions

1. Journal pass (30 min): reread your Day 19–23 journal entries; re-derive
   anything flagged "confusing," closed-book.
2. Full closed-book timed set (150 min): attempt every problem below with no
   notes.
3. Break (15 min).
4. Score and correct (45 min): grade against the Solutions section; rewrite
   every missed solution by hand; classify each miss as a concept gap or an
   arithmetic slip.
5. Journal entry (15 min), using the template below.

## Mixed review problem set

1. (Day 19) Find the spectral decomposition $A = Q\Lambda Q^T$ of
   $A = \begin{pmatrix}3&1\\1&3\end{pmatrix}$.
2. (Day 19) Prove that a symmetric matrix with all eigenvalues equal to $c$
   must be $cI$.
3. (Day 19) True or false: if $A$ is symmetric and $A^2 = A$, then every
   eigenvalue of $A$ is $0$ or $1$. Justify.
4. (Day 20) Classify $\begin{pmatrix}5&2\\2&2\end{pmatrix}$ as positive
   definite, negative definite, indefinite, or semidefinite.
5. (Day 20) Prove: if $A$ is positive definite, then every diagonal entry of
   $A$ is positive. (Hint: evaluate $x^TAx$ at $x = e_i$.)
6. (Day 20) Give a $2\times 2$ symmetric matrix with a negative entry that is
   nonetheless positive definite.
7. (Day 21) Compute the singular values of $A = \begin{pmatrix}0&2\\0&0\end{pmatrix}$
   by hand.
8. (Day 21) Prove that the singular values of an orthogonal matrix $Q$ are
   all equal to $1$.
9. (Day 21) For $A = \begin{pmatrix}2&0\\0&3\end{pmatrix}$, write down $U,
   \Sigma, V$ directly (no computation needed — explain why).
10. (Day 22) For a matrix with singular values $\sigma_1=5,\sigma_2=3,\sigma_3=1$,
    compute $\|A - A_1\|_F$ and $\|A-A_2\|_F$.
11. (Day 22) True or false: the rank-$k$ truncation $A_k$ is the unique
    rank-$k$ matrix minimizing $\|A-B\|_F$. Justify (consider repeated
    singular values).
12. (Day 23) For centered data with covariance matrix
    $C = \begin{pmatrix}4&0\\0&1\end{pmatrix}$, what is the first principal
    component direction, and what fraction of the total variance does it
    explain?
13. (Day 23) Prove that the sum of all eigenvalues of the covariance matrix
    $C$ equals the total variance $\sum_j \operatorname{Var}(X_j)$ (the sum
    of the per-feature variances). (Hint: trace.)
14. (Day 23) Why must data be centered (mean-subtracted) before computing
    principal components?

## Solutions

**1.** Characteristic polynomial: $(3-\lambda)^2 - 1 = 0 \Rightarrow
\lambda = 4, 2$. For $\lambda=4$: $(A-4I)v=0 \Rightarrow
\begin{pmatrix}-1&1\\1&-1\end{pmatrix}v=0 \Rightarrow v=(1,1)$, normalized
$\frac{1}{\sqrt2}(1,1)$. For $\lambda=2$: $v=(1,-1)$, normalized
$\frac1{\sqrt2}(1,-1)$. So $Q = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}$,
$\Lambda=\operatorname{diag}(4,2)$.

**2.** By the spectral theorem $A = Q\Lambda Q^T$ with $\Lambda = cI$ (all
eigenvalues $c$), so $A = Q(cI)Q^T = c(QQ^T) = cI$ since $Q$ is orthogonal.

**3.** True. If $Av=\lambda v$ ($v\ne0$) and $A^2=A$, then
$\lambda^2 v = A^2v = Av = \lambda v$, so $\lambda^2=\lambda$, i.e.
$\lambda(\lambda-1)=0$, so $\lambda \in \{0,1\}$.

**4.** Eigenvalues: $(5-\lambda)(2-\lambda)-4=0 \Rightarrow
\lambda^2-7\lambda+6=0 \Rightarrow \lambda=6,1$. Both positive, so positive
definite.

**5.** $x^TAx > 0$ for all $x\ne0$. Take $x=e_i$ (the $i$-th standard basis
vector, which is nonzero): $e_i^TAe_i = A_{ii} > 0$.

**6.** $\begin{pmatrix}2&-1\\-1&2\end{pmatrix}$: eigenvalues $1, 3$, both
positive, so positive definite, despite the negative off-diagonal entry.

**7.** $A^TA = \begin{pmatrix}0&0\\0&4\end{pmatrix}$, eigenvalues $0,4$, so
singular values $\sigma_1=2,\sigma_2=0$.

**8.** $Q^TQ=I$ means $A^TA=I$ for $A=Q$, so every eigenvalue of $A^TA$ is
$1$, hence every singular value $\sigma_i=\sqrt1=1$.

**9.** $A$ is already diagonal with positive entries, so $A=U\Sigma V^T$
with $U=V=I$ and $\Sigma=A$ directly — a diagonal matrix with non-negative
entries already satisfies the definition of an SVD of itself.

**10.** $\|A-A_1\|_F=\sqrt{\sigma_2^2+\sigma_3^2}=\sqrt{9+1}=\sqrt{10}$.
$\|A-A_2\|_F=\sqrt{\sigma_3^2}=1$.

**11.** False in general — if there's a tie among singular values at the
truncation boundary (e.g. $\sigma_k=\sigma_{k+1}$), multiple rank-$k$
matrices achieve the same minimal error, since the choice of which
singular vectors to include among the tied ones is not unique.

**12.** $C$ is already diagonal, so its eigenvectors are the standard basis
vectors with eigenvalues $4$ and $1$. The first PC is $(1,0)$ (the larger
eigenvalue). Fraction of variance explained: $4/(4+1) = 0.8$.

**13.** $\operatorname{trace}(C) = \sum_i \lambda_i$ (Day 26 will prove this
in general; you may cite it here). But also, by definition,
$C_{jj} = \operatorname{Var}(X_j)$ (the diagonal entries of a covariance
matrix are the individual feature variances), so
$\operatorname{trace}(C) = \sum_j C_{jj} = \sum_j \operatorname{Var}(X_j)$.
Combining, $\sum_i\lambda_i = \sum_j\operatorname{Var}(X_j)$ — PCA
redistributes the same total variance across orthogonal directions.

**14.** The variance derivation (Day 23, Theorem 23.1) relies on $Xw$ being
mean-zero so that $\operatorname{Var}(Xw) = \frac1{n-1}\|Xw\|^2$. If $X$
isn't centered, $\frac1{n-1}\|Xw\|^2$ conflates variance with the squared
mean (it computes $E[(Xw)^2]$, not $\operatorname{Var}(Xw)=E[(Xw)^2]-E[Xw]^2$),
so the eigenvectors of $X^TX$ would no longer correspond to directions of
maximum *variance* — they'd be contaminated by the offset of the data
cloud from the origin.

## Journal template

```
## Day 24 — Review (Days 19-23)
Score: __/__
Concept gaps found: ...
Arithmetic-only slips: ...
```
