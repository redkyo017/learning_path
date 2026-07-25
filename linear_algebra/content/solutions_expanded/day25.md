# Day 25 — Expanded Solutions

Companion to `content/day25.md`. The **Original** column reproduces each solution verbatim; the **Expanded** column fills in skipped steps and/or adds intuition and a plain-language recap. Only solutions that needed it are reproduced here; routine ones are listed under Coverage.

**Coverage:** expanded — 1, 3, 4, 5, 6. Left as-is (already clear) — 2.

---

### Exercise 1 — Compute $[T]_{B'}$ for $T=\begin{pmatrix}2&0\\0&3\end{pmatrix}$, $B'=\{(1,1),(1,-1)\}$

| Original | Expanded |
|---|---|
| $P=\begin{pmatrix}1&1\\1&-1\end{pmatrix}$, $P^{-1}=\frac12\begin{pmatrix}1&1\\1&-1\end{pmatrix}$. $[T]_{B'}=P^{-1}\begin{pmatrix}2&0\\0&3\end{pmatrix}P = \begin{pmatrix}2.5&-0.5\\-0.5&2.5\end{pmatrix}$ (not diagonal, since $(1,1),(1,-1)$ are not eigenvectors of this $T$). | **Step 1 — build $P$ (Def 25.1).** Its columns are the $B'$-vectors in standard coordinates: $P=\begin{pmatrix}1&1\\1&-1\end{pmatrix}$. <br> **Step 2 — invert $P$.** $\det P = (1)(-1)-(1)(1) = -2$, so $P^{-1}=\frac{1}{-2}\begin{pmatrix}-1&-1\\-1&1\end{pmatrix}=\frac12\begin{pmatrix}1&1\\1&-1\end{pmatrix}$. <br> **Step 3 — apply Theorem 25.1, right factor first.** $AP = \begin{pmatrix}2&0\\0&3\end{pmatrix}\begin{pmatrix}1&1\\1&-1\end{pmatrix} = \begin{pmatrix}2&2\\3&-3\end{pmatrix}$. <br> **Step 4 — left-multiply by $P^{-1}$.** $P^{-1}(AP)=\frac12\begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}2&2\\3&-3\end{pmatrix}=\frac12\begin{pmatrix}5&-1\\-1&5\end{pmatrix}=\begin{pmatrix}2.5&-0.5\\-0.5&2.5\end{pmatrix}$. <br> **What just happened:** we translated $T$ into the $B'$ basis by the triple product $P^{-1}[T]_BP$, and because $(1,1),(1,-1)$ are not eigenvectors of this $T$ the result is symmetric-but-not-diagonal. |

### Exercise 3 — If $A,B$ are similar, so are $A^2,B^2$

| Original | Expanded |
|---|---|
| If $B=P^{-1}AP$, then $B^2 = P^{-1}APP^{-1}AP = P^{-1}A^2P$, so $A^2$ and $B^2$ are similar via the same $P$. | **The idea:** "similar" means same map, two coordinate systems; squaring the map is basis-independent, so the two coordinate versions stay linked by the *same* $P$. <br> **Why the middle collapses:** $B^2=(P^{-1}AP)(P^{-1}AP)$; the adjacent factors $P\,P^{-1}=I$ cancel, leaving $P^{-1}A(PP^{-1})AP=P^{-1}A\,I\,AP=P^{-1}A^2P$. That cancellation is the whole trick — it is why powers of similar matrices are again similar (by induction, $A^k$ and $B^k$ for every $k$). <br> **What just happened:** conjugation by $P$ passes straight through multiplication because the inner $PP^{-1}$ telescopes, so squaring in one basis matches squaring in the other. |

### Exercise 4 — T/F: similar matrices have the same eigenvectors

| Original | Expanded |
|---|---|
| False. Similar matrices share eigen*values* but generally not eigen*vectors* — e.g. $A=\begin{pmatrix}2&0\\0&1\end{pmatrix}$ and $B=P^{-1}AP$ for $P=\begin{pmatrix}1&1\\0&1\end{pmatrix}$ have eigenvalues $\{2,1\}$ both, but $A$'s eigenvectors are $(1,0),(0,1)$ while $B$'s are $P^{-1}$-images of those, generally different directions. | **The intuition:** $A$ and $B$ are the *same* linear map seen through two different coordinate systems. What is intrinsic to the map — the eigenvalues (the stretch factors) — is shared; what is a name for a *direction* — the eigenvector's coordinate list — gets relabeled when you switch bases. <br> **Why the directions move:** if $Av=\lambda v$, then $B(P^{-1}v)=P^{-1}AP\,P^{-1}v=P^{-1}Av=\lambda\,(P^{-1}v)$, so $B$'s eigenvector is $P^{-1}v$ with the *same* $\lambda$. Same eigenvalue, generally a different vector — equal only when $P^{-1}$ happens to fix that direction. <br> **What just happened:** similarity preserves the "how much" (eigenvalues) but rewrites the "which direction" (eigenvectors) through $P^{-1}$, so the claim is false. |

### Exercise 5 — Prove $\operatorname{rank}(P^{-1}AP)=\operatorname{rank}(A)$ directly

| Original | Expanded |
|---|---|
| Left-multiplication by invertible $P^{-1}$ doesn't change the column space's dimension (it's a bijective linear map, so it sends a basis of $\operatorname{Col}(AP)$ to a basis of $\operatorname{Col}(P^{-1}AP)$). Right-multiplication by invertible $P$ doesn't change rank either (it's the same fact applied to $A^T$, since $\operatorname{rank}(AP) = \operatorname{rank}((AP)^T)=\operatorname{rank}(P^TA^T)$, and $P^T$ is invertible). Composing both steps, $\operatorname{rank}(P^{-1}AP) = \operatorname{rank}(A)$. | **The strategy:** rank = dimension of the column space, and an invertible matrix is a bijection, so it can neither collapse independent columns nor invent new ones — dimension is untouched. The proof does this once on the left and once on the right. <br> **Left step, unpacked:** $P^{-1}$ is invertible, hence injective as a map; applied to a basis of $\operatorname{Col}(AP)$ it yields an independent, spanning set for $\operatorname{Col}(P^{-1}AP)$, so $\operatorname{rank}(P^{-1}AP)=\operatorname{rank}(AP)$. <br> **Right step, unpacked:** columns are awkward here, so transpose: $\operatorname{rank}(AP)=\operatorname{rank}((AP)^T)=\operatorname{rank}(P^TA^T)$, and $P^T$ is invertible, so the left-step fact gives $\operatorname{rank}(P^TA^T)=\operatorname{rank}(A^T)=\operatorname{rank}(A)$. <br> **What just happened:** sandwiching $A$ between invertible matrices only relabels the column and row spaces without shrinking either, so rank is a similarity invariant. |

### Exercise 6 — $P$ from $B'=\{(2,1),(1,1)\}$ and $[T]_{B'}$ for $T=\begin{pmatrix}1&1\\0&1\end{pmatrix}$

| Original | Expanded |
|---|---|
| $P = \begin{pmatrix}2&1\\1&1\end{pmatrix}$, $P^{-1} = \begin{pmatrix}1&-1\\-1&2\end{pmatrix}$. $[T]_{B'} = P^{-1}\begin{pmatrix}1&1\\0&1\end{pmatrix}P = \begin{pmatrix}2&1\\-1&0\end{pmatrix}$. | **Step 1 — build $P$ (Def 25.1).** Columns are the $B'$-vectors in standard coordinates: $P=\begin{pmatrix}2&1\\1&1\end{pmatrix}$. <br> **Step 2 — invert $P$.** $\det P=(2)(1)-(1)(1)=1$, so $P^{-1}=\frac11\begin{pmatrix}1&-1\\-1&2\end{pmatrix}=\begin{pmatrix}1&-1\\-1&2\end{pmatrix}$. <br> **Step 3 — Theorem 25.1, right factor first.** $AP=\begin{pmatrix}1&1\\0&1\end{pmatrix}\begin{pmatrix}2&1\\1&1\end{pmatrix}=\begin{pmatrix}3&2\\1&1\end{pmatrix}$. <br> **Step 4 — left-multiply by $P^{-1}$.** $P^{-1}(AP)=\begin{pmatrix}1&-1\\-1&2\end{pmatrix}\begin{pmatrix}3&2\\1&1\end{pmatrix}=\begin{pmatrix}2&1\\-1&0\end{pmatrix}$. <br> **Check (invariants):** $\operatorname{trace}=2$ and $\det=1$ match $[T]_{\text{std}}$'s trace $2$ and det $1$, as similarity guarantees. <br> **What just happened:** the triple product $P^{-1}[T]_BP$ re-expresses the same shear $T$ in the skewed basis $B'$, preserving trace and determinant. |
