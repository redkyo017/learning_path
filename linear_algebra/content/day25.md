# Day 25 — Change of Basis, Similarity

## Learning objectives

- Compute the matrix of a linear transformation relative to a new basis.
- Prove and apply the change-of-basis formula.
- Explain why similar matrices share eigenvalues, trace, determinant, and rank.

## Reference material

- Treil, *Linear Algebra Done Wrong* (free PDF: https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf) — revisit Ch. 1 (matrix of a linear transformation) alongside Ch. 4 (similarity).
- Schaum's Outline, review-style problems on change of basis and similarity (no link).

## Theory

### Definition 25.1 (Change-of-basis matrix)

If $B = \{b_1,\dots,b_n\}$ is a basis of $V$, the **coordinate vector**
$[v]_B$ expresses $v = \sum_i c_i b_i$ as $[v]_B = (c_1,\dots,c_n)$. Given two
bases $B, B'$, the **change-of-basis matrix** $P$ from $B'$ to $B$ has as its
$k$-th column the $B$-coordinates of the $k$-th vector of $B'$; it satisfies
$[v]_B = P[v]_{B'}$ for every $v$.

### Theorem 25.1 (Change-of-basis formula)

If $T: V \to V$ has matrix $[T]_B$ relative to basis $B$, and $P$ is the
change-of-basis matrix from $B'$ to $B$, then $T$'s matrix relative to $B'$
is $[T]_{B'} = P^{-1}[T]_BP$.

**Proof.** For any $v$, $[T(v)]_B = [T]_B[v]_B$ (definition of $[T]_B$), and
$[v]_B = P[v]_{B'}$, so $[T(v)]_B = [T]_BP[v]_{B'}$. Also
$[T(v)]_B = P[T(v)]_{B'}$ (same relation applied to $T(v)$), so
$P[T(v)]_{B'} = [T]_BP[v]_{B'}$, giving
$[T(v)]_{B'} = P^{-1}[T]_BP[v]_{B'}$ for every $v$. Since this holds for
every coordinate vector $[v]_{B'}$, the matrices must agree:
$[T]_{B'} = P^{-1}[T]_BP$. $\blacksquare$

### Remark (Similar matrices — recap and one addition)

Matrices related by $B = P^{-1}AP$ are called **similar**. Day 11 proved
similar matrices share eigenvalues, trace, and determinant. One more
invariant: $\operatorname{rank}(P^{-1}AP) = \operatorname{rank}(A)$, since
left/right multiplication by invertible matrices doesn't change rank
(multiplying by an invertible matrix is a bijection on columns/rows, so it
can't change the dimension of the column space).

## Worked example

Let $T$ be reflection across the line $y=x$ in $\mathbb{R}^2$, with standard
matrix $[T]_{\text{std}} = \begin{pmatrix}0&1\\1&0\end{pmatrix}$. Using the
basis $B' = \{(1,1),(1,-1)\}$ (eigenvectors of $T$), the change-of-basis
matrix is $P = \begin{pmatrix}1&1\\1&-1\end{pmatrix}$. Then
$$[T]_{B'} = P^{-1}[T]_{\text{std}}P = \begin{pmatrix}1&0\\0&-1\end{pmatrix},$$
which is diagonal — expected, since $B'$ consists of eigenvectors with
eigenvalues $1$ and $-1$. Note $\operatorname{trace}$ and $\det$ are
preserved: both matrices have trace $0$ and determinant $-1$.

## Unconventional edge

The trap: thinking a linear transformation "has" one true matrix. It
doesn't — the matrix is always relative to a chosen basis, and the same map
can look complicated (dense, off-diagonal) in one basis and trivial
(diagonal) in another. Diagonalization (Day 11) *is* change of basis, just
specialized to the case where you pick the eigenvector basis.

## Exercises

1. Compute $[T]_{B'}$ for $T$ with standard matrix
   $\begin{pmatrix}2&0\\0&3\end{pmatrix}$ and $B'=\{(1,1),(1,-1)\}$.
2. For the $T$ and $P$ in the worked example, verify $\det([T]_{B'}) =
   \det([T]_{\text{std}})$ directly from your computed matrices.
3. Prove: if $A$ and $B$ are similar, so are $A^2$ and $B^2$.
4. True or false, with justification: if $A$ and $B$ are similar, they have
   the same eigenvectors.
5. Prove $\operatorname{rank}(P^{-1}AP) = \operatorname{rank}(A)$ directly
   (not just by citing it), using that multiplying by an invertible matrix
   doesn't change rank.
6. Find the change-of-basis matrix $P$ from $B'=\{(2,1),(1,1)\}$ to the
   standard basis of $\mathbb{R}^2$, and use it to find $[T]_{B'}$ for
   $T$ with standard matrix $\begin{pmatrix}1&1\\0&1\end{pmatrix}$.

## Solutions

**1.** $P=\begin{pmatrix}1&1\\1&-1\end{pmatrix}$, $P^{-1}=\frac12\begin{pmatrix}1&1\\1&-1\end{pmatrix}$.
$[T]_{B'}=P^{-1}\begin{pmatrix}2&0\\0&3\end{pmatrix}P = \begin{pmatrix}2.5&-0.5\\-0.5&2.5\end{pmatrix}$
(not diagonal, since $(1,1),(1,-1)$ are not eigenvectors of this $T$).

**2.** $\det([T]_{B'}) = \det\begin{pmatrix}1&0\\0&-1\end{pmatrix}=-1$.
$\det([T]_{\text{std}}) = \det\begin{pmatrix}0&1\\1&0\end{pmatrix}=0\cdot0-1\cdot1=-1$. Equal, as guaranteed.

**3.** If $B=P^{-1}AP$, then $B^2 = P^{-1}APP^{-1}AP = P^{-1}A^2P$, so $A^2$
and $B^2$ are similar via the same $P$.

**4.** False. Similar matrices share eigen*values* but generally not
eigen*vectors* — e.g. $A=\begin{pmatrix}2&0\\0&1\end{pmatrix}$ and
$B=P^{-1}AP$ for $P=\begin{pmatrix}1&1\\0&1\end{pmatrix}$ have eigenvalues
$\{2,1\}$ both, but $A$'s eigenvectors are $(1,0),(0,1)$ while $B$'s are
$P^{-1}$-images of those, generally different directions.

**5.** Left-multiplication by invertible $P^{-1}$ doesn't change the column
space's dimension (it's a bijective linear map, so it sends a basis of
$\operatorname{Col}(AP)$ to a basis of $\operatorname{Col}(P^{-1}AP)$).
Right-multiplication by invertible $P$ doesn't change rank either (it's the
same fact applied to $A^T$, since $\operatorname{rank}(AP) =
\operatorname{rank}((AP)^T)=\operatorname{rank}(P^TA^T)$, and $P^T$ is
invertible). Composing both steps, $\operatorname{rank}(P^{-1}AP) =
\operatorname{rank}(A)$.

**6.** $P = \begin{pmatrix}2&1\\1&1\end{pmatrix}$, $P^{-1} =
\begin{pmatrix}1&-1\\-1&2\end{pmatrix}$. $[T]_{B'} = P^{-1}\begin{pmatrix}1&1\\0&1\end{pmatrix}P
= \begin{pmatrix}2&1\\-1&0\end{pmatrix}$.

## Code lab

One short check today. Fill in `change_of_basis` in
`starter_code/day25_change_of_basis.py`, then run it — it verifies
Theorem 25.1 and the trace/det invariants from the worked example.

```python
import numpy as np

def change_of_basis(T_matrix, P):
    """Return P^{-1} @ T_matrix @ P."""
    # TODO: implement this
    raise NotImplementedError
```

Solution is in `solutions/day25_change_of_basis.py` — check only after
attempting.

## Journal template

```
## Day 25 — Change of basis, similarity
Key theorem in my own words: ...
What confused me: ...
```
