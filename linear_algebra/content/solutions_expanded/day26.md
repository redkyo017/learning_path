# Day 26 — Expanded Solutions

Companion to `content/day26.md`. The **Original** column reproduces each solution verbatim; the **Expanded** column fills in skipped steps and/or adds intuition and a plain-language recap. Only solutions that needed it are reproduced here; routine ones are listed under Coverage.

**Coverage:** expanded — 3. Left as-is (already clear) — 1, 2, 4, 5.

---

### Exercise 3 — Singular matrix has a zero eigenvalue

| Original | Expanded |
|---|---|
| **3.** $A$ singular means $\det(A)=0$. By Theorem 26.1, $\det(A)=\prod_i\lambda_i=0$, so at least one factor $\lambda_i=0$. | **The logic (unchanged).** $A$ singular $\Rightarrow \det(A)=0$; Theorem 26.1 says $\det(A)=\prod_i\lambda_i$, so $\prod_i\lambda_i=0$, forcing some $\lambda_i=0$. <br> **Why the last step is legal.** A product of numbers is zero only if at least one factor is zero — this is the "no zero divisors" property of $\mathbb{C}$ (a field). The eigenvalues here are complex numbers counted with algebraic multiplicity, so the product $\prod_i\lambda_i$ is an ordinary product of scalars and the rule applies directly. <br> **Intuition.** Theorem 26.1 turns a statement about the *whole* matrix ($\det A = 0$) into a statement about its *spectrum*. The determinant is the signed volume-scaling factor of $A$; singular means $A$ collapses volume to $0$, i.e. it flattens some direction completely. Since $\det$ is the product of the eigenvalues (the stretch factors along the eigen-directions in the diagonalizable picture), a collapsed matrix must have at least one direction stretched by factor $0$ — an eigenvalue $0$, with eigenvector living in the null space. <br> **What just happened:** because the determinant *is* the product of the eigenvalues, a zero determinant can only come from a zero eigenvalue. |
