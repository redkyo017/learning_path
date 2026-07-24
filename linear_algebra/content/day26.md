# Day 26 — Trace, Determinant-Eigenvalue Relation, Bridge to Cholesky

## Learning objectives

- Prove trace and determinant are the sum and product of eigenvalues.
- State the Cholesky decomposition and know when it applies.

## Reference material

- Treil, *Linear Algebra Done Wrong* (https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf), Ch. 4, for characteristic-polynomial coefficient facts.
- Schaum's Outline, review problems on trace properties (no link).

## Theory

### Theorem 26.1 (Trace and determinant via eigenvalues)

For an $n\times n$ matrix $A$ with eigenvalues $\lambda_1,\dots,\lambda_n$
(counted with algebraic multiplicity, possibly complex),
$$\operatorname{trace}(A) = \sum_{i=1}^n \lambda_i, \qquad \det(A) = \prod_{i=1}^n \lambda_i.$$

**Proof.** The characteristic polynomial factors over $\mathbb{C}$ as
$$p(\lambda) = \det(A-\lambda I) = (-1)^n\prod_{i=1}^n(\lambda-\lambda_i) = (-1)^n\left(\lambda^n - \Big(\sum_i\lambda_i\Big)\lambda^{n-1} + \cdots + (-1)^n\prod_i\lambda_i\right).$$
Separately, expanding $\det(A-\lambda I)$ directly via the Leibniz/cofactor
definition of the determinant, the coefficient of $\lambda^{n-1}$ comes only
from the product of diagonal entries $\prod_i(A_{ii}-\lambda)$ (every
off-diagonal term in the full determinant expansion contributes degree
$\le n-2$ in $\lambda$, since it omits at least two diagonal factors),
giving coefficient $(-1)^{n-1}\sum_iA_{ii} = (-1)^{n-1}\operatorname{trace}(A)$.
Matching coefficients of $\lambda^{n-1}$ between the two expressions for
$p(\lambda)$ gives $(-1)^{n-1}\operatorname{trace}(A) = (-1)^n\cdot(-1)\sum_i\lambda_i = (-1)^{n-1}\sum_i\lambda_i$,
so $\operatorname{trace}(A)=\sum_i\lambda_i$. Setting $\lambda=0$ in both
expressions gives $\det(A) = p(0)\cdot(-1)^0= (-1)^n\prod_i(-\lambda_i) = \prod_i\lambda_i$
(tracking signs: $p(0)=\det(A)$ directly from the definition, and
$p(0)=(-1)^n\prod_i(0-\lambda_i)=(-1)^n(-1)^n\prod_i\lambda_i=\prod_i\lambda_i$). $\blacksquare$

### Remark (Cholesky decomposition)

Every symmetric positive definite matrix $A$ has a unique decomposition
$A = LL^T$ with $L$ lower triangular and positive diagonal entries. Sketch:
by the spectral theorem $A=Q\Lambda Q^T$ with all $\lambda_i>0$ (Day 20), so
$A = (Q\sqrt\Lambda)(Q\sqrt\Lambda)^T$ already gives *a* square root
factorization; Gram-Schmidt applied to the rows of $Q\sqrt\Lambda^T$ (or
equivalently, Gaussian elimination without pivoting on $A$) converts this
into the triangular form $L$. We won't reprove uniqueness here — the point
is to recognize Cholesky as "$A$'s own square root," a fact used constantly
in statistics (sampling from a multivariate Gaussian with covariance $A$)
and numerical optimization.

## Worked example

For $A = \begin{pmatrix}4&2\\2&3\end{pmatrix}$: eigenvalues solve
$(4-\lambda)(3-\lambda)-4=0 \Rightarrow \lambda^2-7\lambda+8=0 \Rightarrow
\lambda = \frac{7\pm\sqrt{17}}{2}$. Check: $\lambda_1+\lambda_2 = 7 =
\operatorname{trace}(A) = 4+3$. $\lambda_1\lambda_2 = 8 = \det(A) =
4\cdot3-2\cdot2=8$. Both match.

## Unconventional edge

The trap: computing trace and determinant as two unrelated arithmetic facts
about a matrix's entries, rather than seeing them as two coefficients of the
*same* characteristic polynomial — the same object you've been computing
since Day 10. Once you see trace and determinant as "sum of roots" and
"product of roots" of one polynomial, you get both almost for free whenever
you already know the eigenvalues, and you get a fast consistency check
whenever you compute eigenvalues by hand (their sum and product must match
the trace and determinant you can read directly off $A$).

## Exercises

1. Verify Theorem 26.1 for $A=\begin{pmatrix}1&2\\3&4\end{pmatrix}$: compute
   eigenvalues, then check their sum/product against trace/det.
2. For a $3\times3$ matrix with eigenvalues $2, -1, 3$, what are
   $\operatorname{trace}(A)$ and $\det(A)$?
3. Prove: if $A$ is singular, at least one eigenvalue of $A$ is $0$ (use
   Theorem 26.1's determinant formula).
4. True or false: if $\operatorname{trace}(A)=0$, then $A$ has a zero
   eigenvalue. Justify (consider a rotation matrix).
5. Is $A=\begin{pmatrix}4&2\\2&1\end{pmatrix}$ positive definite? If so, find
   its Cholesky factor $L$ by hand (solve $LL^T=A$ for a lower-triangular
   $L$ directly, entry by entry).

## Solutions

**1.** $\det(A-\lambda I)=(1-\lambda)(4-\lambda)-6 = \lambda^2-5\lambda-2=0
\Rightarrow \lambda=\frac{5\pm\sqrt{33}}2$. Sum $=5=\operatorname{trace}(A)=1+4$.
Product $=\frac{25-33}{4}=-2=\det(A)=1\cdot4-2\cdot3=-2$. Both match.

**2.** $\operatorname{trace}(A)=2+(-1)+3=4$. $\det(A)=2\cdot(-1)\cdot3=-6$.

**3.** $A$ singular means $\det(A)=0$. By Theorem 26.1, $\det(A)=\prod_i\lambda_i=0$,
so at least one factor $\lambda_i=0$.

**4.** False. A 2D rotation by 90°, $\begin{pmatrix}0&-1\\1&0\end{pmatrix}$,
has trace $0$ but eigenvalues $\pm i$ (complex, neither is $0$). Trace $0$
only forces the eigenvalues to *sum* to zero, not that any individual one is
zero.

**5.** Eigenvalues: $(4-\lambda)(1-\lambda)-4=\lambda^2-5\lambda=0
\Rightarrow \lambda=0,5$. One eigenvalue is $0$, so $A$ is positive
*semi*definite, not positive definite — Cholesky (which needs strict
positive definiteness) does not apply here. (This is a deliberate trap:
always check definiteness before attempting Cholesky.)

## Code lab

One short check: verify trace/det against eigenvalues, and run Cholesky on
a matrix that actually qualifies. Fill in `solutions/day26_trace_det_cholesky.py`'s
starter counterpart.

```python
import numpy as np

def trace_det_match_eigenvalues(A):
    """Return True if trace(A) == sum(eigenvalues) and det(A) == prod(eigenvalues)."""
    # TODO: implement this
    raise NotImplementedError
```

Solution is in `solutions/day26_trace_det_cholesky.py` — check only after
attempting.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $\operatorname{trace}(A)$ | "the trace — sum of the diagonal entries" | today it also equals the sum of the eigenvalues |
| $\sum_i \lambda_i$, $\prod_i \lambda_i$ | "add up / multiply together all the eigenvalues" | the two things trace and determinant secretly are |
| $p(\lambda) = \det(A - \lambda I)$ | "the characteristic polynomial" | the one object whose coefficients hide both trace and determinant |
| $A = LL^T$ | "$A$ splits into a lower-triangular $L$ times its own transpose" | the Cholesky factorization |
| $L$ | "the Cholesky factor" | a lower-triangular square root of $A$ |
| positive definite | "$x^T A x > 0$ for every nonzero $x$" | the condition a matrix must meet before Cholesky applies |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- The trace is the sum of the eigenvalues and the determinant is their
  product — both are just coefficients of the one characteristic
  polynomial you have been computing since Day 10.
- That hands you a free consistency check: eigenvalues you found by hand
  must sum to the trace and multiply to the determinant, or you slipped.
- Every symmetric positive definite matrix has a unique Cholesky
  factorization $A = LL^T$ with $L$ lower triangular and positive
  diagonal — a triangular "square root" of $A$.
- Cholesky needs *strict* positive definiteness; a single zero eigenvalue
  (only semidefinite) breaks it, so always check definiteness first.
- Cholesky is really the spectral theorem's square root $Q\sqrt\Lambda$
  (Day 20) repackaged into triangular form.

### Proof sketches

**Theorem 26.1 — key trick: read trace and determinant off the two ends
of the characteristic polynomial.**
Factor the characteristic polynomial as $(-1)^n\prod_i(\lambda -
\lambda_i)$; its coefficients are then built entirely from the
eigenvalues — the $\lambda^{n-1}$ coefficient is, up to sign, their sum
and the constant term is their product. Now expand that *same*
determinant straight from the matrix: only the product of diagonal
entries can reach degree $n-1$, so that coefficient is the sum of the
diagonal entries, the trace. Match the two expressions coefficient by
coefficient to get the sum, and set $\lambda = 0$ to read off $\det(A) =
p(0) = \prod_i\lambda_i$ for the product. Full version: Theorem 26.1
above.

### If you remember only 3 things

1. Trace = sum of eigenvalues, determinant = product of eigenvalues —
   two coefficients of the same characteristic polynomial.
2. Use it as a sanity check: hand-computed eigenvalues must add up to the
   trace and multiply to the determinant.
3. Cholesky $A = LL^T$ exists only for symmetric positive definite $A$; a
   zero eigenvalue (merely semidefinite) kills it, so check definiteness
   before you factor.

## Journal template

```
## Day 26 — Trace, determinant, Cholesky bridge
Key theorem in my own words: ...
What confused me: ...
```
