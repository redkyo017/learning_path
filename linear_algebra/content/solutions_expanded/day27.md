# Day 27 — Expanded Solutions

Companion to `content/day27.md`. The **Original** column reproduces each solution verbatim; the **Expanded** column fills in skipped steps and/or adds intuition and a plain-language recap. Only solutions that needed it are reproduced here; routine ones are listed under Coverage.

**Coverage:** expanded — 3, 4, 6, 9, 12, 13. Left as-is (already clear) — 1, 2, 5, 7, 8, 10, 11, 14, 15, 16.

---

### Exercise 3 — a linear map $T:\mathbb{R}^5 \to \mathbb{R}^3$ cannot be injective

| Original | Expanded |
|---|---|
| By rank-nullity, $\dim\ker T + \dim\operatorname{im}T = 5$. Since $\operatorname{im}T \subseteq \mathbb{R}^3$, $\dim\operatorname{im}T\le3$, so $\dim\ker T \ge 2 > 0$, meaning $\ker T \ne \{0\}$, so $T$ is not injective. | **Intuition — you can't pour 5 dimensions into 3 without collapse.** Rank-nullity ($\dim\ker T + \dim\operatorname{im}T = n$, the master counting law from today's "big ideas") is bookkeeping: the domain's 5 dimensions must be split between what $T$ crushes to zero (the kernel) and what survives as output (the image). <br> **Why the key step works.** The image lives inside $\mathbb{R}^3$, so it can carry at most $3$ of those dimensions: $\dim\operatorname{im}T\le3$. That leaves $\dim\ker T = 5-\dim\operatorname{im}T \ge 5-3 = 2$ dimensions with nowhere to go except into the kernel. A kernel of dimension $\ge 2$ certainly contains a nonzero vector, so $\ker T \ne \{0\}$. <br> **Why $\ker T \ne \{0\}$ kills injectivity.** If $v \ne 0$ lies in the kernel, then $T(v)=0=T(0)$ — two different inputs share an output. <br> **What just happened:** there are more input dimensions than output dimensions, so rank-nullity forces at least two of them to collapse to zero, and any collapse means two inputs collide. |

### Exercise 4 — rank and a null-space vector of $M=\begin{pmatrix}1&2&3\\2&4&7\\1&2&4\end{pmatrix}$

| Original | Expanded |
|---|---|
| $\operatorname{rank}(M)=2$ (its rows/columns satisfy one dependency: row 2 minus row 1 doesn't simplify cleanly, but row reduction shows only 2 pivots). A null space vector is proportional to $(-2,1,0)$ — check: $M(-2,1,0)^T = (-2+2, -4+4, -2+2)=(0,0,0)$. ✓ | **Step 1 — clear column 1 below the pivot.** With $R_1=(1,2,3)$ as pivot row: $R_2 \to R_2-2R_1=(0,0,1)$ and $R_3 \to R_3-R_1=(0,0,1)$. Matrix becomes $\begin{pmatrix}1&2&3\\0&0&1\\0&0&1\end{pmatrix}$. <br> **Step 2 — clear the duplicate.** $R_3 \to R_3-R_2=(0,0,0)$, giving row echelon form $\begin{pmatrix}1&2&3\\0&0&1\\0&0&0\end{pmatrix}$. <br> **Step 3 — count pivots.** Pivots sit in columns 1 and 3; column 2 has none. So $\operatorname{rank}(M)=2$ ("number of pivots", per today's notation decoder). <br> **Step 4 — solve $Mx=0$ from the echelon form.** Row 2 gives $x_3=0$; row 1 gives $x_1+2x_2+3x_3=0 \Rightarrow x_1=-2x_2$. Column 2 is free, so set $x_2=1$: $x=(-2,1,0)$. This matches the stated check $M(-2,1,0)^T=(0,0,0)$. <br> **What just happened:** two elimination steps reveal exactly two pivots (rank 2) and one free column, whose free variable generates the null-space direction $(-2,1,0)$. |

### Exercise 6 — if $\det(A)=0$ then $Ax=0$ has a nonzero solution

| Original | Expanded |
|---|---|
| If $\det(A)=0$, $A$ is not invertible (Day 8's theorem). If $Ax=0$ had only the solution $x=0$, $A$ would be injective as a map $\mathbb{R}^n\to\mathbb{R}^n$, hence invertible (Day 4's theorem) — contradiction. So $Ax=0$ must have a nonzero solution. | **Intuition — the argument is a proof by contradiction riding on two equivalences.** It never solves $Ax=0$ directly; instead it shows that "only $x=0$ solves it" would force $A$ to be invertible, clashing with $\det(A)=0$. <br> **Why the chain holds.** Link 1: $\det(A)=0 \Rightarrow A$ not invertible (determinant detects singularity). Link 2 (the assumed-for-contradiction part): $Ax=0$ having only $x=0$ means $\ker A=\{0\}$, i.e. $A$ is injective; and for a square map $\mathbb{R}^n\to\mathbb{R}^n$, injective $\Rightarrow$ invertible. So the two links say opposite things about invertibility — impossible. <br> **Why the square shape matters.** Injective forces invertible only because domain and codomain have equal dimension $n$ (rank-nullity again: $\dim\ker A=0 \Rightarrow \dim\operatorname{im}A=n$, so the image fills all of $\mathbb{R}^n$). The whole argument would fail for a non-square $A$. <br> **What just happened:** a singular matrix can't be injective, and "not injective" is exactly the statement that some nonzero $x$ gets sent to $0$. |

### Exercise 9 — compute $E^3$ for $E=\begin{pmatrix}5&4\\1&2\end{pmatrix}$ via diagonalization

| Original | Expanded |
|---|---|
| Eigenvalues $6,1$ with eigenvectors solving $(E-6I)v=0$ and $(E-1I)v=0$ respectively: $v_1=(4,1)$, $v_2=(1,-1)$ (up to scale). Then $E^3 = PD^3P^{-1}$ with $D^3=\operatorname{diag}(216,1)$, giving $E^3=\begin{pmatrix}173&172\\43&44\end{pmatrix}$. | **Step 1 — assemble $P$ and $D$.** Put eigenvectors in columns matching eigenvalue order: $P=\begin{pmatrix}4&1\\1&-1\end{pmatrix}$, $D=\begin{pmatrix}6&0\\0&1\end{pmatrix}$, so $D^3=\begin{pmatrix}216&0\\0&1\end{pmatrix}$ (cube each diagonal entry: $6^3=216$, $1^3=1$). <br> **Step 2 — invert $P$.** $\det P = (4)(-1)-(1)(1) = -5$, so $P^{-1}=\frac{1}{-5}\begin{pmatrix}-1&-1\\-1&4\end{pmatrix}=\frac{1}{5}\begin{pmatrix}1&1\\1&-4\end{pmatrix}$. <br> **Step 3 — form $PD^3$.** $\begin{pmatrix}4&1\\1&-1\end{pmatrix}\begin{pmatrix}216&0\\0&1\end{pmatrix}=\begin{pmatrix}864&1\\216&-1\end{pmatrix}$ (each column of $P$ scaled by its eigenvalue cube). <br> **Step 4 — multiply by $P^{-1}$.** $\begin{pmatrix}864&1\\216&-1\end{pmatrix}\cdot\frac{1}{5}\begin{pmatrix}1&1\\1&-4\end{pmatrix}=\frac{1}{5}\begin{pmatrix}865&860\\215&220\end{pmatrix}=\begin{pmatrix}173&172\\43&44\end{pmatrix}$. <br> **Why this is legal:** $E=PDP^{-1}$ gives $E^3=PD^3P^{-1}$ because the inner $P^{-1}P$ pairs cancel — "diagonalize, power the diagonal, undo" from today's notation decoder. <br> **What just happened:** diagonalizing turned three matrix multiplications into cubing two numbers, then one sandwich product $PD^3P^{-1}$ rebuilds $E^3$. |

### Exercise 12 — least-squares line to $(0,1),(1,2),(2,4),(3,5)$

| Original | Expanded |
|---|---|
| Normal equations with $A=\begin{pmatrix}0&1\\1&1\\2&1\\3&1\end{pmatrix}$, $y=(1,2,4,5)$: solving gives slope $m=1.4$, intercept $b=0.9$. | **Step 1 — write the normal equations.** The best-fit $(m,b)$ solves $A^TA\begin{pmatrix}m\\b\end{pmatrix}=A^Ty$ (least-squares turns the unsolvable $Ax=y$ into a solvable square system). <br> **Step 2 — form $A^TA$.** With $x$-values $0,1,2,3$: $\sum x_i^2=0+1+4+9=14$, $\sum x_i=6$, $n=4$, so $A^TA=\begin{pmatrix}14&6\\6&4\end{pmatrix}$. <br> **Step 3 — form $A^Ty$.** $\sum x_i y_i = 0(1)+1(2)+2(4)+3(5)=25$ and $\sum y_i=1+2+4+5=12$, so $A^Ty=\begin{pmatrix}25\\12\end{pmatrix}$. <br> **Step 4 — solve the $2\times2$ system.** $\det\begin{pmatrix}14&6\\6&4\end{pmatrix}=56-36=20$. By Cramer's rule, $m=\frac{25\cdot4-6\cdot12}{20}=\frac{28}{20}=1.4$ and $b=\frac{14\cdot12-6\cdot25}{20}=\frac{18}{20}=0.9$. <br> **What just happened:** the four data points give a $2\times2$ system $A^TA\hat x=A^Ty$ whose solution is the line $y=1.4x+0.9$. |

### Exercise 13 — the product of two orthogonal matrices is orthogonal

| Original | Expanded |
|---|---|
| If $Q_1^TQ_1=I$ and $Q_2^TQ_2=I$, then $(Q_1Q_2)^T(Q_1Q_2) = Q_2^TQ_1^TQ_1Q_2 = Q_2^TIQ_2 = Q_2^TQ_2 = I$, so $Q_1Q_2$ is orthogonal. | **Intuition — orthogonal matrices are rigid motions, and composing two rigid motions is still rigid.** Each $Q_i$ preserves lengths and angles ("columns orthonormal", $Q^TQ=I$, per today's decoder); doing one then the other cannot distort anything, so the composite $Q_1Q_2$ must be orthogonal too. <br> **Why the algebra mirrors that.** The engine is the transpose-reversal rule $(Q_1Q_2)^T=Q_2^TQ_1^T$ (transpose flips the order). Then the middle collapses in two hits: the inner $Q_1^TQ_1=I$ disappears first, leaving $Q_2^TQ_2$, which is $I$ by the second hypothesis. Verifying $(Q_1Q_2)^T(Q_1Q_2)=I$ is exactly the definition of $Q_1Q_2$ being orthogonal. <br> **What just happened:** transpose-reversal lets the two orthonormality facts cancel from the inside out, confirming that chaining two length-preserving maps preserves length. |
