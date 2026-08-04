# Day 19 Primer — Symmetric Matrices & the Spectral Theorem

## Warm-up

Before diving into today's theory, spend about ten minutes reconnecting with three prior topics by working through flashcards from Days 17, 16, and 11. Say your answers aloud or write them down *before* checking.

**Why these three days?** Each provides a critical piece that fuses into today's theorem.

**Day 17 — Orthogonal matrices:** You discovered that matrices $Q$ with orthonormal columns satisfy $Q^TQ = I$, so the inverse is just the transpose: $Q^{-1} = Q^T$. These rigid transformations preserve everything geometric — inner products, lengths, angles, volumes. Applied to a line, they rotate it; applied to an ellipse, they rotate and reflect it, but never distort it. They're bulletproof numerically: the condition number is always 1, making them immune to rounding error. When you change coordinates via an orthogonal matrix, you're rotating your viewpoint, not warping the space. This is why orthogonal matrices are the "perfect glasses" — they let you see the same space from a different angle without distorting anything.

**Day 16 — Orthogonal projections and least squares:** You learned that the closest point in a subspace $W$ to a given vector $b$ is found by dropping a perpendicular from $b$ onto $W$. This perpendicularity is the defining condition — the residual $e = b - \text{projection}$ must be orthogonal to every vector in $W$. That single geometric principle led to the normal equations $A^TA\hat{x} = A^Tb$. You also glimpsed the structure of orthogonal complements: the subspace $C(A)^\perp$ (all vectors perpendicular to the column space of $A$) is exactly $N(A^T)$ (the null space of the transpose). Perpendicularity is a powerful organizing principle.

**Day 11 — Diagonalization and the multiplicity problem:** You learned that some matrices diagonalize ($A = PDP^{-1}$) and some do not. The gap: algebraic multiplicity (how many times an eigenvalue appears as a root of the characteristic polynomial) can exceed geometric multiplicity (the actual dimension of the eigenspace). The shear matrix $\begin{pmatrix}1&1\\0&1\end{pmatrix}$ epitomizes the disease: $\lambda=1$ appears twice (algebraic multiplicity = 2), but there is only one eigenvector direction (geometric multiplicity = 1). The matrix is *defective* and cannot be diagonalized. This was a heartbreak: a simple, ordinary-looking matrix broken by internal mismatch.

Now: hold these three threads. Today braids them into one beautiful theorem that solves the defectiveness problem *for all matrices with a special structure*.

## The hook

For generic real matrices, eigenvalues can be complex. Worse, the defectiveness trap means diagonalization fails entirely. Day 11 left open wounds.

Enter **symmetric matrices**, where $A = A^T$. The matrix mirrors across its main diagonal: $(i,j)$ entry equals $(j,i)$ entry. They are everywhere in applied mathematics. Covariance matrices in statistics are symmetric. Hessians (second-derivative matrices) of smooth functions are symmetric. Gram matrices of the form $B^TB$ are always symmetric. Laplacians in physics are symmetric. Normal equations from least squares yield symmetric systems.

The miracle: **symmetry heals both diseases — real eigenvalues and complete eigenvector bases**.

Let's verify with the worked example from day19.md. Take $A = \begin{pmatrix}2&1\\1&2\end{pmatrix}$. First, check it's symmetric: transpose is $\begin{pmatrix}2&1\\1&2\end{pmatrix}$ = $A$. ✓

Find eigenvalues. The characteristic polynomial is $\det(A - \lambda I) = \det\begin{pmatrix}2-\lambda & 1\\1 & 2-\lambda\end{pmatrix} = (2-\lambda)^2 - 1 = \lambda^2 - 4\lambda + 3 = 0$. So $(\lambda-3)(\lambda-1)=0$, giving $\lambda \in \{3, 1\}$. **Both real.** No phantom complex numbers.

Find eigenvectors. For $\lambda=3$: solve $(A - 3I)v = 0 \Rightarrow \begin{pmatrix}-1 & 1\\1 & -1\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix} = 0 \Rightarrow x = y$. Eigenvector direction: $(1,1)$. Normalize: $q_1 = \frac{1}{\sqrt{2}}\begin{pmatrix}1\\1\end{pmatrix}$. For $\lambda=1$: solve $(A-I)v=0 \Rightarrow \begin{pmatrix}1&1\\1&1\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}=0 \Rightarrow x+y=0 \Rightarrow y=-x$. Eigenvector direction: $(1,-1)$. Normalize: $q_2 = \frac{1}{\sqrt{2}}\begin{pmatrix}1\\-1\end{pmatrix}$.

Compute their inner product: $\langle q_1, q_2\rangle = \frac{1}{2}(1 \cdot 1 + 1 \cdot (-1)) = \frac{1}{2}(1-1) = 0$. **Perpendicular!** This is not a lucky fluke. Theorem 19.2 from day19.md guarantees it always happens for symmetric matrices with distinct eigenvalues.

Assemble the decomposition: $Q = \begin{pmatrix}q_1 & q_2\end{pmatrix} = \frac{1}{\sqrt{2}}\begin{pmatrix}1&1\\1&-1\end{pmatrix}$, $\Lambda = \begin{pmatrix}3&0\\0&1\end{pmatrix}$. Verify: $Q$ is orthogonal (columns are orthonormal), and $Q\Lambda Q^T = A$ (you can check by multiplication, or see day19.md's verification). This is the spectral decomposition: $A = Q\Lambda Q^T$.

## The pictures

**Picture 1: The ellipse with perpendicular axes.**

A symmetric $2\times2$ matrix stretches the unit circle into an ellipse. Where do the ellipse's principal axes point? Along the eigenvectors. For our $A = \begin{pmatrix}2&1\\1&2\end{pmatrix}$, the major axis points in direction $q_1 = (1,1)$ (the eigenvector for $\lambda=3$), and the minor axis points in $q_2 = (1,-1)$ (the eigenvector for $\lambda=1$). How long are the axes? The major axis has semi-length $\sqrt{3}$ (the square root of the larger eigenvalue, in a certain normalization); the minor axis has semi-length $1$.

Why does this matter? Picture yourself standing at the origin, looking at the ellipse. Its shape is intrinsic — it doesn't depend on which coordinate system you choose. But when you find the eigenvectors, you're discovering the *natural* coordinate system for this ellipse — the axes along which it's *already aligned*. Once you rotate to the eigen-coordinate system, the ellipse stops being tilted and sits cleanly on the axes. This is the geometric meaning of the spectral theorem: it finds the coordinate system in which the symmetric matrix looks simplest (diagonal). You start with a tilted ellipse and a tilted matrix $A$. After the spectral decomposition, the same ellipse sits on axis-aligned axes in the rotated view, and the matrix becomes the clean, simple diagonal $\Lambda$.

By today's theorem, these axes are **always perpendicular**. You don't have to check; symmetry guarantees it. In $\mathbb{R}^n$, a symmetric $n \times n$ matrix maps the unit sphere to an ellipsoid whose $n$ principal axes align with the $n$ eigenvectors and whose $n$ semi-axis lengths are the $n$ eigenvalues (in absolute value). This geometric picture is the face of the Spectral Theorem.

**Picture 2: Rigid decomposition versus general diagonalization.**

Day 11 gave $A = PDP^{-1}$ where $P$ is any invertible matrix and $D$ is diagonal. The change-of-basis matrix $P$ could be arbitrary — its columns could be nearly parallel (ill-conditioned), or twisted in ugly ways. Computing $P^{-1}$ costs $O(n^3)$ arithmetic by Gaussian elimination, and the result is numerically fragile.

Day 19 upgrades: $A = Q\Lambda Q^T$ where $Q$ is orthogonal. The interpretation: apply $Q^T$ (rotate rigidly to the eigen-axes), apply $\Lambda$ (scale purely along those axes, no shear), apply $Q$ (rotate back). The entire transformation is composed of **rigid rotations and pure scalings** — no distortion. Computing $Q^{-1}$ costs one transpose (essentially free, no arithmetic, $O(n^2)$ memory), and the result is numerically bulletproof (condition number 1 for $Q$).

Why should you care? When you use spectral decomposition in practice — say, computing a covariance matrix's eigendecomposition for PCA, or iterating on an eigenvalue solver — the orthogonal $Q$ means all your subsequent computations stay rock-solid numerically. If you had used a general invertible $P$ instead, rounding errors would accumulate and corrupt the answer. This is why spectral methods dominate whenever symmetric matrices appear: fast, stable, bulletproof.

**Picture 3: Symmetry cures defectiveness.**

Left panel: the defective shear $\begin{pmatrix}1&1\\0&1\end{pmatrix}$. Its only eigenvalue is $\lambda=1$, with algebraic multiplicity 2 (the characteristic polynomial is $(\lambda-1)^2$), yet the eigenspace has dimension 1 (only the direction $(1,0)$). There is a **multiplicity mismatch**: geometric $<$ algebraic. Diagonalization fails. Jordan blocks emerge. Defective means broken.

Is this matrix symmetric? Transpose is $\begin{pmatrix}1&0\\1&1\end{pmatrix}$, which is not equal to the original. No. It's not symmetric.

Right panel: **any symmetric matrix**. Theorem 19.3's construction (peel one eigenpair recursively, always finding one eigenvector per step) guarantees exactly $n$ mutually orthogonal eigenvectors. No gap between geometric and algebraic multiplicity. The geometric multiplicity automatically equals the algebraic multiplicity. Defectiveness is impossible. Symmetry is the cure. The inductive proof doesn't rely on counting multiplicities — it just extracts one eigenvector at a time, and that mechanical process always succeeds. No matrix can hide a defect if it's symmetric.

## Concrete-first walkthrough

**Definition 19.1** (Symmetric matrix): $A$ is symmetric if $A = A^T$, i.e., $A_{ij} = A_{ji}$ for all $i,j$. The entries mirror across the main diagonal. The deeper algebraic fact is **self-adjointness**: for any vectors $v, w$, $\langle Av, w\rangle = \langle v, Aw\rangle$ (you can slide $A$ across the inner product). This is remarkable — general matrices don't have this property. Only symmetric (and more generally, self-adjoint) matrices do. This sliding operation is *the single algebraic move* powering all three theorems today.

**Memory hook:** "Sliding symmetry — move $A$ across the inner product."

**Connection to the worked example:** Our matrix $A = \begin{pmatrix}2&1\\1&2\end{pmatrix}$ is symmetric because $(1,2)$ entry equals $(2,1)$ entry, both are 1. So we can slide: $\langle A v_1, v_2 \rangle = \langle v_1, A v_2 \rangle$. Watch this move: it's the secret weapon in all three proofs. Every time you feel stuck in a proof below, this sliding trick is what saves you.

---

---

**Theorem 19.1** (Eigenvalues of a real symmetric matrix are real): Every eigenvalue $\lambda$ of a real symmetric matrix $A$ is real, not complex.

Why believe it? Suppose $Av = \lambda v$ for some possibly-complex eigenpair $(\lambda, v)$. The proof uses a clever trick: compute the same quantity $v^*Av$ (using conjugate transpose) two different ways and equate them. *Method 1:* directly from the eigenvalue equation, $v^*Av = \lambda(v^*v)$. *Method 2:* using self-adjointness (conjugate the equation to get $v^*A = \bar\lambda v^*$, multiply by $v$ on the right), $v^*Av = \bar\lambda(v^*v)$. *Equate:* $\lambda(v^*v) = \bar\lambda(v^*v)$. Since $v^*v = \|v\|^2 > 0$, we conclude $\lambda = \bar\lambda$ — real. This is the "conjugate sandwich": the self-adjoint property lets you compute one quantity two ways, and the mismatch in conjugation forces the eigenvalue to be real.

**Memory hook:** "Conjugate sandwich — two computations, same quantity, forces $\lambda = \bar\lambda$."

**Connection to the worked example:** For $A = \begin{pmatrix}2&1\\1&2\end{pmatrix}$, we found $\lambda = 3$ and $\lambda = 1$. Both are real. Theorem 19.1 guarantees this is no coincidence — any symmetric matrix will have real eigenvalues only. No complex surprises hiding in symmetric matrices.

---

**Theorem 19.2** (Eigenvectors for distinct eigenvalues are orthogonal): If $Av_1 = \lambda_1v_1$ and $Av_2 = \lambda_2v_2$ with $\lambda_1 \neq \lambda_2$, then $\langle v_1, v_2\rangle = 0$.

Why believe it? This theorem is the crown jewel of geometric intuition. Evaluate $\langle Av_1, v_2\rangle$ two ways, using the two different eigenpairs. *First way:* $\langle Av_1, v_2\rangle = \lambda_1\langle v_1, v_2\rangle$ (substitute $Av_1 = \lambda_1v_1$). *Second way:* use self-adjointness to slide $A$ to the other slot: $\langle Av_1, v_2\rangle = \langle v_1, Av_2\rangle = \lambda_2\langle v_1, v_2\rangle$ (substitute $Av_2 = \lambda_2v_2$). *Equate the two expressions:* $\lambda_1\langle v_1, v_2\rangle = \lambda_2\langle v_1, v_2\rangle$, so $(\lambda_1-\lambda_2)\langle v_1, v_2\rangle = 0$. Since the eigenvalues differ by hypothesis, $\lambda_1 - \lambda_2 \neq 0$, so the inner product must be zero. Perpendicularity is forced.

**Memory hook:** "Eigenvalue gap vanishes the dot product — different lambdas, perpendicular vectors."

**Connection to the worked example:** Our $A = \begin{pmatrix}2&1\\1&2\end{pmatrix}$ has $q_1 = (1,1)$ for $\lambda=3$ and $q_2 = (1,-1)$ for $\lambda=1$. They're perpendicular: $q_1 \cdot q_2 = 0$. Theorem 19.2 guarantees this must happen for distinct eigenvalues. No orthogonalization step needed; symmetry delivers it for free.

---

**Theorem 19.3** (The Spectral Theorem): Every real symmetric $n \times n$ matrix $A$ factors as $A = Q\Lambda Q^T$ where $Q$ is orthogonal and $\Lambda$ is real diagonal.

Why believe it? The proof uses strong induction, and it's the most beautiful part. Key insight: after isolating one real eigenpair $(\lambda_1, q_1)$ (which exists by Theorem 19.1), the matrix $A$ maps the orthogonal complement of $q_1$ into itself — exactly because of self-adjointness and the sliding trick. This perpendicular-invariance allows recursion on a smaller symmetric problem. The induction never gets stuck on multiplicity mismatches like Day 11. Instead, it extracts one eigenvector per recursive step (always possible for symmetric matrices), and the geometric/algebraic matching happens automatically. By the time the recursion bottoms out, you've found exactly $n$ mutually orthogonal eigenvectors.

**Memory hook:** "Peel one eigenvector at a time, recurse on the perpendicular complement — symmetry guarantees success at every step."

**Connection to the worked example:** For $A = \begin{pmatrix}2&1\\1&2\end{pmatrix}$, we assembled $Q = \frac{1}{\sqrt{2}}\begin{pmatrix}1&1\\1&-1\end{pmatrix}$ (orthogonal) and $\Lambda = \begin{pmatrix}3&0\\0&1\end{pmatrix}$. Check: $Q\Lambda Q^T = A$. The spectral theorem says this *always* works for symmetric matrices, and $Q$ is *always* orthogonal, so inversion costs just a transpose ($O(n^2)$ memory, no arithmetic), versus general matrix inversion ($O(n^3)$ arithmetic). That speedup is why spectral methods are ubiquitous in applications.

## Proof roadmaps

**Theorem 19.1 — The conjugate sandwich.** Assume a possibly-complex eigenpair $(v,\lambda)$ with $Av = \lambda v$. The argument works by computing the quantity $v^*Av$ in two ways.

*Compute 1 (direct):* $v^*Av = \lambda v^*v$ (substitute the eigenvalue equation $Av = \lambda v$ directly).

*Compute 2 (via symmetry):* Conjugate-transpose the eigenvalue equation: $(Av)^* = (\lambda v)^* \implies v^*A^* = \bar\lambda v^*$. Since $A^* = A$ (real and symmetric), this becomes $v^*A = \bar\lambda v^*$. Now multiply on the right by $v$: $v^*Av = \bar\lambda v^*v$.

*Equate:* $\lambda v^*v = \bar\lambda v^*v$. Divide by $v^*v = \|v\|^2 > 0$: $\lambda = \bar\lambda$ (real).

**Theorem 19.2 — Inner product from two angles.** Let $Av_1 = \lambda_1v_1, Av_2 = \lambda_2v_2$, $\lambda_1 \neq \lambda_2$. Evaluate $\langle Av_1, v_2\rangle$ in two ways.

*Angle 1 (via first eigenpair):* Substitute $Av_1 = \lambda_1v_1$: $\langle Av_1, v_2\rangle = \lambda_1\langle v_1, v_2\rangle$.

*Angle 2 (via self-adjointness):* Use the sliding trick to move $A$ to the other slot: $\langle Av_1, v_2\rangle = \langle v_1, Av_2\rangle$. Now substitute $Av_2 = \lambda_2v_2$: $\langle v_1, Av_2\rangle = \lambda_2\langle v_1, v_2\rangle$.

*Equate and solve:* $\lambda_1\langle v_1, v_2\rangle = \lambda_2\langle v_1, v_2\rangle \implies (\lambda_1-\lambda_2)\langle v_1, v_2\rangle = 0$. Since $\lambda_1 \neq \lambda_2$, we have $\langle v_1, v_2\rangle = 0$.

**Theorem 19.3 — Peel one pair recursively.** The proof is an induction: at each step, peel off one eigenvector and recurse on the perpendicular complement.

(1) **Get one eigenvector.** By Theorem 19.1, $A$ has a real eigenvalue $\lambda_1$. Grab a corresponding unit eigenvector $q_1$ with $\|q_1\| = 1$.

(2) **Extend to orthonormal basis.** Use Gram-Schmidt to extend $\{q_1\}$ to an orthonormal basis $\{q_1, q_2, \ldots, q_n\}$. Form the orthogonal matrix $V = [q_1|\cdots|q_n]$ (columns are orthonormal).

(3) **Conjugate by $V$ to expose block structure.** Compute $B = V^TAV$. By the eigenvector property, $B e_1 = V^TAq_1 = \lambda_1 V^Tq_1 = \lambda_1 e_1$ (since $V^Tq_1$ extracts the first coordinate). By symmetry ($B = B^T$), the first row equals the transpose of the first column, i.e., $(\lambda_1, 0, \ldots, 0)$. So $B$ has block form $B = \begin{pmatrix}\lambda_1 & 0\\0 & C\end{pmatrix}$ where $C$ is symmetric $(n-1) \times (n-1)$.

(4) **Induction on $C$.** By the inductive hypothesis (smaller symmetric matrix), $C = Q'\Lambda'Q'^T$ for orthogonal $Q'$ and diagonal $\Lambda'$. Build the block-diagonal $Q'' = \begin{pmatrix}1 & 0\\0 & Q'\end{pmatrix}$ (orthogonal). Then $B = Q''\Lambda Q''^T$ with $\Lambda = \begin{pmatrix}\lambda_1 & 0\\0 & \Lambda'\end{pmatrix}$ diagonal.

(5) **Unwrap to get $A$.** From $B = V^TAV$, we have $A = VBV^T$. Substitute $B = Q''\Lambda Q''^T$: $A = V(Q''\Lambda Q''^T)V^T = (VQ'')\Lambda(VQ'')^T$. Set $Q = VQ''$ (orthogonal, being a product of orthogonal matrices). Thus $A = Q\Lambda Q^T$.

## Flashcards

**Q:** State the Spectral Theorem in full.

**A:** Every real symmetric $n \times n$ matrix $A$ factors as $A = Q\Lambda Q^T$, where $Q$ is orthogonal and $\Lambda$ is real diagonal.

**Q:** What is the one algebraic move that powers all three proofs today?

**A:** Symmetry allows sliding $A$ across the inner product: $\langle Av, w\rangle = \langle v, Aw\rangle$ (self-adjointness).

**Q:** Why must the eigenvalues of a real symmetric matrix be real?

**A:** Compute $v^*Av$ two ways — directly via the eigenvalue equation and via conjugate transpose — then equate to force $\lambda = \bar\lambda$.

**Q:** What is special about eigenvectors of a symmetric matrix for different eigenvalues?

**A:** They are orthogonal — evaluate $\langle Av_1, v_2\rangle$ both ways and the eigenvalue gap forces the inner product to zero.

**Q:** How does symmetry cure the two diseases from Day 11?

**A:** Real eigenvalues and automatic full rank (geometric multiplicity always equals algebraic, so no defectiveness).

**Q:** How do you interpret $A = Q\Lambda Q^T$ geometrically?

**A:** Rotate to the eigen-axes via $Q^T$, scale along them purely via $\Lambda$, rotate back via $Q$ (rigid).

**Q:** What is the key induction step in the Spectral Theorem proof?

**A:** Show that $A$ maps the orthogonal complement of $q_1$ into itself, restrict and apply induction to the smaller symmetric block.
