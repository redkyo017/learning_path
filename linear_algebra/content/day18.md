# Day 18 — Review (Days 14–17)

## Purpose

Today introduces no new theory. It is closed-book retrieval practice on
everything from Days 14–17: inner products, norms, and Cauchy-Schwarz;
orthogonal complements and Gram-Schmidt; orthogonal projections and least
squares; and orthogonal matrices and QR decomposition. As with Days 7 and 13,
this review sits mid-stream rather than at the end, because spaced retrieval
is what keeps material from quietly evaporating a few weeks later — the work
below is the deliberate, uncomfortable act of pulling the last four days back
out of memory *now*, while gaps are still cheap to close. This block of four
days was also unusually cumulative (Gram-Schmidt feeds projections, which
feed least squares, which feeds QR), so today is a good test of whether the
chain holds together end to end, not just whether each link survives alone.

## Instructions

Follow these steps in order, closed-book except where noted.

1. **Journal pass (~30 min).** Reread all four of your Day 14–17 journal
   entries. For every item you listed under "what confused me," re-derive it
   from scratch, closed-book, before moving on to the next one. If you can't
   re-derive something, that's exactly the kind of gap this review day exists
   to surface — note it, but keep going; you'll revisit it in the concept-gaps
   tally at the end.
2. **Full timed attempt (~150 min).** Attempt every problem in the Mixed
   review problem set below, closed-book, no notes, no solutions section, in
   one sitting timed at roughly 150 minutes total (about 9–10 minutes per
   problem on average — some will be faster, some slower). Do not look at the
   Solutions section until you've either finished or the timer runs out.
3. **Break (~15 min).**
4. **Score and correct (~45 min).** Grade your attempt against the Solutions
   section below, problem by problem. For every problem you missed or got
   only partly right, rewrite the correct solution by hand from scratch — not
   just read it — and classify the miss as either a **concept gap** (you
   didn't know or misremembered the underlying theorem/definition) or an
   **arithmetic-only slip** (you knew exactly what to do but made a
   computational error executing it). This distinction is the point of the
   exercise: concept gaps need re-study, arithmetic slips just need more
   careful hand-checking next time.
5. **Journal entry (~15 min).** Fill in the Day 18 journal template at the
   bottom of this file and append it to your `journal.md`.

## Mixed review problem set

Problems are deliberately interleaved across topics (not grouped by day) —
mixing topics during retrieval practice is itself part of what makes it
effective. Each problem is labeled with the day/topic it targets so you can
tally your score by topic afterward.

1. **(Day 14: Cauchy-Schwarz)** For $u = (2,3)$ and $v = (-1,4)$ in
   $\mathbb{R}^2$ (standard dot product), verify Cauchy-Schwarz, the triangle
   inequality, and the parallelogram law by computing both sides of each
   numerically.
2. **(Day 15: Gram-Schmidt)** Run Gram-Schmidt by hand on $v_1 = (2,0,0)$,
   $v_2 = (1,2,0)$, $v_3 = (1,1,3)$ in $\mathbb{R}^3$. Show every step and
   verify the result is orthonormal.
3. **(Day 16: orthogonal projections)** Let $W =
   \operatorname{span}\{(1,1,1),(1,-1,0)\} \subseteq \mathbb{R}^3$. Compute
   $\operatorname{proj}_W(v)$ for $v = (1,2,3)$.
4. **(Day 17: orthogonal matrices)** Verify that
   $Q = \dfrac13\begin{pmatrix} 1 & 2 & 2 \\ 2 & 1 & -2 \\ 2 & -2 &
   1\end{pmatrix}$ is orthogonal by computing $Q^TQ$ directly.
5. **(Day 14: angle between vectors)** Compute the angle $\theta$ (in
   degrees, to two decimal places) between $u = (1,2,2)$ and $v = (2,2,1)$.
6. **(Day 15: orthogonal complements)** Let $W =
   \operatorname{span}\{(1,-1,1),(2,1,0)\} \subseteq \mathbb{R}^3$ (a plane
   through the origin). Find $W^\perp$ explicitly (give a basis), and verify
   $\dim W + \dim W^\perp = \dim \mathbb{R}^3$.
7. **(Day 16: least squares)** Fit $y = mx+b$ by least squares to the four
   points $(1,1), (2,2), (3,4), (4,7)$: set up $A$, form the normal
   equations, and solve for $m,b$ by hand.
8. **(Day 17: QR decomposition)** Compute the QR decomposition by hand (via
   Gram-Schmidt) of $A = \begin{pmatrix}1&0\\1&1\\1&1\end{pmatrix}$, whose
   columns are $a_1=(1,1,1)$, $a_2=(0,1,1)$. Verify $QR=A$.
9. **(Day 14: proof)** Prove the **polarization identity**: for all $u,v$ in
   a real inner product space, $\langle u,v\rangle =
   \dfrac{\|u+v\|^2 - \|u-v\|^2}{4}$. (This shows the inner product is
   completely recoverable from the norm it induces — a fact used constantly
   when people say "the norm determines the geometry.")
10. **(Day 15: proof)** Prove: if $W_1 \subseteq W_2$ are subspaces of an
    inner product space $V$, then $W_2^\perp \subseteq W_1^\perp$.
11. **(Day 16: proof)** Prove: $\operatorname{proj}_W$ is idempotent, i.e.
    $\operatorname{proj}_W(\operatorname{proj}_W(v)) = \operatorname{proj}_W(v)$
    for every $v \in V$. (Work directly from Definition 16.1 — don't just
    cite "projecting twice does nothing" as self-evident.)
12. **(Day 17: proof)** Prove: if $Q$ is an orthogonal matrix and $\lambda$
    is a **real** eigenvalue of $Q$ with (real, nonzero) eigenvector $v$,
    then $\lambda = \pm 1$.
13. **(Day 14: trap)** For $u = (1,2)$ and $v = (2,4)$, compute both sides
    of the Cauchy-Schwarz inequality numerically. What do you notice, and
    why was this forced to happen given the relationship between $u$ and
    $v$?
14. **(Day 15: conceptual)** In 2–4 sentences: why does the Gram-Schmidt
    process require its input vectors to be linearly independent? Concretely,
    what goes wrong, step by step, if you feed it a linearly *dependent* set
    (say $v_3 \in \operatorname{span}\{v_1,v_2\}$)?
15. **(Day 16: proof)** Prove: if $\hat x$ solves the normal equations
    $A^TA\hat x = A^Tb$, then $\|b\|^2 = \|A\hat x\|^2 + \|b - A\hat x\|^2$.
    (Use the fact, established in Theorem 16.2's proof, that $b - A\hat x \in
    C(A)^\perp$, together with the Pythagorean theorem for orthogonal
    vectors, Lemma 16.1.)
16. **(Day 17: least squares via QR)** Using the $Q,R$ you computed in
    Problem 8, solve the least-squares problem $Ax=b$ for
    $A = \begin{pmatrix}1&0\\1&1\\1&1\end{pmatrix}$, $b = (1,2,4)$, via
    $R\hat x = Q^Tb$ and back-substitution. Separately solve the normal
    equations $A^TA\hat x = A^Tb$ directly. Confirm the two solutions agree.

## Solutions

**1.** $\langle u,v\rangle = (2)(-1)+(3)(4) = -2+12 = 10$. $\|u\| =
\sqrt{4+9}=\sqrt{13}\approx3.606$, $\|v\| = \sqrt{1+16}=\sqrt{17}\approx4.123$.
*Cauchy-Schwarz:* $|10| \le \sqrt{13}\sqrt{17} = \sqrt{221} \approx 14.866$
✓. *Triangle:* $u+v = (1,7)$, $\|u+v\| = \sqrt{1+49}=\sqrt{50}=5\sqrt2
\approx 7.071 \le \|u\|+\|v\| \approx 3.606+4.123 = 7.729$ ✓. *Parallelogram:*
$\|u+v\|^2 = 50$; $u-v = (3,-1)$, $\|u-v\|^2 = 9+1=10$; sum $=60$. Right
side: $2(13)+2(17) = 26+34=60$. Equal ✓ (all three checks confirmed
numerically with NumPy).

**2.** $u_1 = v_1 = (2,0,0)$, $\langle u_1,u_1\rangle = 4$.
$\langle v_2,u_1\rangle = (1)(2)+0+0 = 2$, coefficient $2/4 = 1/2$:
$$u_2 = (1,2,0) - \tfrac12(2,0,0) = (1,2,0)-(1,0,0) = (0,2,0).$$
$\langle v_3,u_1\rangle = (1)(2)+0+0 = 2$, coefficient $1/2$, term $(1,0,0)$.
$\langle v_3,u_2\rangle = 0+(1)(2)+0 = 2$, $\langle u_2,u_2\rangle=4$,
coefficient $1/2$, term $(0,1,0)$:
$$u_3 = (1,1,3) - (1,0,0) - (0,1,0) = (0,0,3).$$
All three of $u_1,u_2,u_3$ already point along the coordinate axes with
norms $2,2,3$, so
$$e_1 = (1,0,0), \qquad e_2 = (0,1,0), \qquad e_3 = (0,0,1)$$
— the standard basis (an entirely legitimate, if unglamorous, output — this
particular $v_1,v_2,v_3$ happened to already be "staircase-shaped," so each
step's leftover component landed exactly on the next axis). Orthonormality
is immediate by inspection: all three pairwise dot products are $0$ and all
three norms are $1$ (confirmed numerically).

**3.** First check whether the spanning set is already orthogonal:
$\langle (1,1,1),(1,-1,0)\rangle = 1-1+0=0$ — yes, so only normalization is
needed (no full Gram-Schmidt required). $\|(1,1,1)\| = \sqrt3$,
$\|(1,-1,0)\| = \sqrt2$, so $e_1 = (1,1,1)/\sqrt3$, $e_2 = (1,-1,0)/\sqrt2$.
For $v=(1,2,3)$:
$$\langle v,e_1\rangle = \frac{1+2+3}{\sqrt3} = \frac{6}{\sqrt3} = 2\sqrt3,
\qquad \langle v,e_2\rangle = \frac{1-2+0}{\sqrt2} = \frac{-1}{\sqrt2}.$$
$$\operatorname{proj}_W(v) = 2\sqrt3\cdot\frac{(1,1,1)}{\sqrt3} +
\left(-\frac{1}{\sqrt2}\right)\frac{(1,-1,0)}{\sqrt2} = 2(1,1,1) -
\tfrac12(1,-1,0) = (2,2,2)-\left(\tfrac12,-\tfrac12,0\right).$$
$$\operatorname{proj}_W(v) = \left(\tfrac32,\ \tfrac52,\ 2\right).$$
(Confirmed numerically; also, the residual $v - \operatorname{proj}_W(v) =
(-\tfrac12,-\tfrac12,1)$ dots to $0$ with both $(1,1,1)$ and $(1,-1,0)$,
confirming it lies in $W^\perp$ as Lemma 16.2 guarantees.)

**4.** The columns of $Q$ are $(1,2,2)/3$, $(2,1,-2)/3$, $(2,-2,1)/3$.
Computing all pairwise dot products:
$$\left\langle\text{col}_1,\text{col}_1\right\rangle = \tfrac19(1+4+4)=1,
\quad \left\langle\text{col}_2,\text{col}_2\right\rangle =
\tfrac19(4+1+4)=1, \quad \left\langle\text{col}_3,\text{col}_3\right\rangle =
\tfrac19(4+4+1)=1,$$
$$\left\langle\text{col}_1,\text{col}_2\right\rangle =
\tfrac19(1\cdot2+2\cdot1+2\cdot(-2)) = \tfrac19(2+2-4)=0,$$
$$\left\langle\text{col}_1,\text{col}_3\right\rangle =
\tfrac19(1\cdot2+2\cdot(-2)+2\cdot1) = \tfrac19(2-4+2)=0,$$
$$\left\langle\text{col}_2,\text{col}_3\right\rangle =
\tfrac19(2\cdot2+1\cdot(-2)+(-2)\cdot1) = \tfrac19(4-2-2)=0.$$
So $Q^TQ = I_3$: $Q$ is orthogonal (confirmed numerically with NumPy —
`Q.T @ Q` returns the identity to floating-point precision).

**5.** $\langle u,v\rangle = (1)(2)+(2)(2)+(2)(1) = 2+4+2=8$. $\|u\| =
\sqrt{1+4+4}=3$, $\|v\|=\sqrt{4+4+1}=3$. $\cos\theta = 8/9 \approx 0.8889$.
$$\theta = \arccos(8/9) \approx 27.27°$$
(more precisely $27.2660...°$; confirmed with `np.degrees(np.arccos(8/9))`).

**6.** Let $n$ be the cross product of the two spanning vectors,
$n = (1,-1,1)\times(2,1,0)$:
$$n = \big((-1)(0)-(1)(1),\ (1)(2)-(1)(0),\ (1)(1)-(-1)(2)\big) =
(-1,\ 2,\ 3).$$
Check $n$ is orthogonal to both spanning vectors: $(1,-1,1)\cdot(-1,2,3) =
-1-2+3=0$ ✓; $(2,1,0)\cdot(-1,2,3) = -2+2+0=0$ ✓ (confirmed numerically).
Since $(1,-1,1)$ and $(2,1,0)$ are not scalar multiples of each other (the
first coordinates give a ratio of $1/2$ but the third coordinates give a
ratio $1/0$, undefined — they're independent), $\dim W = 2$; by Theorem
15.1, $\dim W^\perp = 3 - 2 = 1$, and since $n \in W^\perp$ is a single
nonzero vector, $W^\perp = \operatorname{span}\{(-1,2,3)\}$. Check:
$\dim W + \dim W^\perp = 2+1=3=\dim\mathbb{R}^3$ ✓.

**7.** $A = \begin{pmatrix}1&1\\2&1\\3&1\\4&1\end{pmatrix}$, $y =
(1,2,4,7)$.
$$A^TA = \begin{pmatrix}1+4+9+16 & 1+2+3+4 \\ 1+2+3+4 &
4\end{pmatrix} = \begin{pmatrix}30&10\\10&4\end{pmatrix},$$
$$A^Ty = \begin{pmatrix}1(1)+2(2)+3(4)+4(7)\\1+2+4+7\end{pmatrix} =
\begin{pmatrix}1+4+12+28\\14\end{pmatrix} = \begin{pmatrix}45\\14\end{pmatrix}.$$
Normal equations for $\hat x=\binom{m}{b}$: $30m+10b=45$, $10m+4b=14$.
Divide the first by $10$: $3m+b=4.5 \implies b = 4.5-3m$. Substitute into
the second: $10m+4(4.5-3m)=14 \implies 10m+18-12m=14 \implies -2m=-4
\implies m=2$. Then $b = 4.5-6=-1.5$.
**Fitted line: $y = 2x - 1.5$.** Check: fitted values at $x=1,2,3,4$ are
$0.5, 2.5, 4.5, 6.5$ against actual $1,2,4,7$; residuals $0.5,-0.5,-0.5,0.5$
sum to $0$ ✓, consistent with the intercept column forcing residuals to sum
to zero (confirmed numerically, matching `numpy.linalg.lstsq`).

**8.** $a_1=(1,1,1)$, $a_2=(0,1,1)$.
$v_1 = a_1 = (1,1,1)$, $\|v_1\| = \sqrt3$, so
$$q_1 = \frac{(1,1,1)}{\sqrt3}, \qquad r_{11}=\sqrt3.$$
$$r_{12} = \langle a_2,q_1\rangle = \frac{0+1+1}{\sqrt3} = \frac{2}{\sqrt3}.$$
$$v_2 = a_2 - r_{12}q_1 = (0,1,1) - \frac{2}{\sqrt3}\cdot\frac{(1,1,1)}{\sqrt3}
= (0,1,1) - \tfrac23(1,1,1) = \left(-\tfrac23,\ \tfrac13,\ \tfrac13\right).$$
$$\|v_2\| = \sqrt{\tfrac49+\tfrac19+\tfrac19} = \sqrt{\tfrac69} =
\sqrt{\tfrac23} = \frac{\sqrt6}{3}, \qquad q_2 = \frac{v_2}{\|v_2\|} =
\frac{(-2,1,1)}{\sqrt6}, \qquad r_{22} = \frac{\sqrt6}{3}.$$
Assembling:
$$Q = \begin{pmatrix}\tfrac1{\sqrt3} & -\tfrac2{\sqrt6} \\[4pt]
\tfrac1{\sqrt3} & \tfrac1{\sqrt6} \\[4pt] \tfrac1{\sqrt3} &
\tfrac1{\sqrt6}\end{pmatrix}, \qquad R = \begin{pmatrix}\sqrt3 &
\tfrac2{\sqrt3} \\[4pt] 0 & \tfrac{\sqrt6}{3}\end{pmatrix}.$$
**Verify $QR=A$.** Column 1: $r_{11}q_1 = \sqrt3\cdot(1,1,1)/\sqrt3 =
(1,1,1) = a_1$ ✓. Column 2: $r_{12}q_1 + r_{22}q_2 =
\tfrac2{\sqrt3}\cdot\tfrac{(1,1,1)}{\sqrt3} +
\tfrac{\sqrt6}{3}\cdot\tfrac{(-2,1,1)}{\sqrt6} = \tfrac23(1,1,1) +
\tfrac13(-2,1,1) = \left(\tfrac23-\tfrac23,\ \tfrac23+\tfrac13,\
\tfrac23+\tfrac13\right) = (0,1,1) = a_2$ ✓. Both columns match, and $r_{11},
r_{22}>0$ as guaranteed by Theorem 17.2 (confirmed numerically against
`numpy.linalg.qr`, up to the usual sign convention).

**9.** Expand both squared norms on the right using bilinearity and
symmetry, exactly as in the proofs of Theorems 14.2/14.3:
$$\|u+v\|^2 = \langle u,u\rangle + 2\langle u,v\rangle + \langle v,v\rangle
= \|u\|^2+2\langle u,v\rangle+\|v\|^2,$$
$$\|u-v\|^2 = \langle u,u\rangle - 2\langle u,v\rangle + \langle v,v\rangle
= \|u\|^2-2\langle u,v\rangle+\|v\|^2.$$
Subtracting the second from the first, the $\|u\|^2$ and $\|v\|^2$ terms
cancel exactly:
$$\|u+v\|^2 - \|u-v\|^2 = 4\langle u,v\rangle.$$
Dividing both sides by $4$:
$$\langle u,v\rangle = \frac{\|u+v\|^2-\|u-v\|^2}{4}. \qquad \blacksquare$$
(Numeric sanity check with $u=(2,3,-1)$, $v=(1,-2,4)$: $\langle u,v\rangle =
2-6-4=-8$, and $\|u+v\|^2-\|u-v\|^2 = \|(3,1,3)\|^2-\|(1,5,-5)\|^2 =
19-51=-32$, and $-32/4=-8$ — matches, confirmed numerically.)

**10.** Let $x \in W_2^\perp$, i.e. $\langle x,w\rangle = 0$ for every $w \in
W_2$. Since $W_1 \subseteq W_2$, every $w \in W_1$ is also in $W_2$, so in
particular $\langle x,w\rangle = 0$ holds for every $w \in W_1$ as well.
This is exactly the defining condition for $x \in W_1^\perp$. Since $x \in
W_2^\perp$ was arbitrary, $W_2^\perp \subseteq W_1^\perp$. $\blacksquare$
(Intuition: the *bigger* the subspace $W$, the *more* orthogonality
conditions a vector in $W^\perp$ must satisfy, so the *smaller* $W^\perp$
can be — orthogonal complementation reverses inclusions, mirroring how
$(W^\perp)^\perp = W$ from Day 15 Exercise 6 is consistent with applying
this inclusion-reversal twice.)

**11.** Let $e_1,\dots,e_k$ be an orthonormal basis of $W$, and write $p =
\operatorname{proj}_W(v) = \sum_{i=1}^k \langle v,e_i\rangle e_i$ (Definition
16.1). Apply Definition 16.1 again, this time to $p$:
$$\operatorname{proj}_W(p) = \sum_{j=1}^k \langle p,e_j\rangle e_j.$$
Compute $\langle p,e_j\rangle$ using bilinearity and orthonormality
($\langle e_i,e_j\rangle=\delta_{ij}$):
$$\langle p,e_j\rangle = \Big\langle \sum_{i=1}^k \langle v,e_i\rangle e_i,\
e_j\Big\rangle = \sum_{i=1}^k \langle v,e_i\rangle\langle e_i,e_j\rangle =
\langle v,e_j\rangle,$$
since only the $i=j$ term survives. Substituting back:
$$\operatorname{proj}_W(p) = \sum_{j=1}^k \langle v,e_j\rangle e_j = p.$$
So $\operatorname{proj}_W(\operatorname{proj}_W(v)) = \operatorname{proj}_W(v)$
for every $v \in V$: $\operatorname{proj}_W$ is idempotent. $\blacksquare$
(This is the algebraic form of "projecting an already-projected vector does
nothing," and it's a special case of Day 16 Exercise 7 — $\operatorname{proj}_W(w)=w$
for $w \in W$ — applied to $w = p \in W$; the derivation here just redoes
that argument from scratch for this specific $p$.)

**12.** Since $Q$ is orthogonal, the Corollary to Theorem 17.1 gives
$\|Qx\| = \|x\|$ for every $x \in \mathbb{R}^n$. Apply this with $x=v$:
$\|Qv\| = \|v\|$. But $v$ is an eigenvector with eigenvalue $\lambda$, so
$Qv = \lambda v$, hence
$$\|Qv\| = \|\lambda v\| = |\lambda|\,\|v\|.$$
Combining, $|\lambda|\,\|v\| = \|v\|$. Since $v$ is an eigenvector, $v \neq
0$, so $\|v\| \neq 0$ (positive-definiteness), and we can divide both sides
by $\|v\|$:
$$|\lambda| = 1 \implies \lambda = \pm 1. \qquad \blacksquare$$
(This is exactly why rotation matrices, which are orthogonal, have only
complex eigenvalues $e^{\pm i\theta}$ when $\theta \neq 0,\pi$ — a rotation
in the plane has *no* real eigenvector at all unless it's the identity or a
$180°$ rotation, precisely the two cases $\lambda=1,-1$ allowed here.)

**13.** $\langle u,v\rangle = (1)(2)+(2)(4) = 2+8=10$. $\|u\| =
\sqrt{1+4}=\sqrt5$, $\|v\| = \sqrt{4+16}=\sqrt{20}=2\sqrt5$. So $\|u\|\|v\| =
\sqrt5\cdot2\sqrt5 = 2\cdot5=10$. Both sides equal $10$ exactly: **equality
holds** in Cauchy-Schwarz. This was forced because $v = 2u$ — $u$ and $v$
are scalar multiples of each other (linearly dependent) — and by Day 14
Exercise 5, equality in Cauchy-Schwarz holds if and only if the two vectors
are linearly dependent. There was no need to compute anything to predict
this outcome; recognizing $v=2u$ first would have told you equality was
coming (confirmed numerically: $10 = 10.000\ldots$ to floating-point
precision).

**14.** Gram-Schmidt builds $u_k = v_k - \sum_{i<k}
\frac{\langle v_k,u_i\rangle}{\langle u_i,u_i\rangle}u_i$, and this
subtracted sum is exactly $\operatorname{proj}_{\operatorname{span}\{u_1,\dots,u_{k-1}\}}(v_k)$,
which by the span-equality property equals
$\operatorname{proj}_{\operatorname{span}\{v_1,\dots,v_{k-1}\}}(v_k)$. If
$v_3 \in \operatorname{span}\{v_1,v_2\}$ (a dependent set), then $v_3$ is
already entirely "explained" by $v_1,v_2$, so by Day 16 Exercise 7 its
projection onto that span is $v_3$ itself — meaning $u_3 = v_3 -
\operatorname{proj}(v_3) = v_3 - v_3 = 0$ exactly. Normalizing then requires
dividing by $\|u_3\|=0$, which is undefined, so the process breaks down at
that step rather than silently producing a wrong-but-valid answer. This is
precisely the contradiction Theorem 15.2's proof of part (a) rules out by
assuming the $v_i$ are linearly independent in the first place.

**15.** From the proof of Theorem 16.2, a vector $\hat x$ satisfying the
normal equations $A^TA\hat x = A^Tb$ satisfies $A^T(b-A\hat x) = 0$, i.e.
$b - A\hat x \in N(A^T) = C(A)^\perp$. Also $A\hat x \in C(A)$ trivially
(it's $A$ applied to some vector). Since $A\hat x \in C(A)$ and $b-A\hat x
\in C(A)^\perp$, these two vectors are orthogonal by definition of
orthogonal complement: $\langle A\hat x,\ b-A\hat x\rangle = 0$.

Now write $b = A\hat x + (b - A\hat x)$ and apply Lemma 16.1 (Pythagorean
theorem for orthogonal vectors) with $a = A\hat x$, $b_{\text{vec}} = b -
A\hat x$:
$$\|b\|^2 = \|A\hat x + (b-A\hat x)\|^2 = \|A\hat x\|^2 + \|b-A\hat x\|^2.
\qquad \blacksquare$$
(Numeric check using Problem 7's data: $y=(1,2,4,7)$, $\hat x = (2,-1.5)$,
$A\hat x = (0.5,2.5,4.5,6.5)$, residual $(0.5,-0.5,-0.5,0.5)$. $\|y\|^2 =
1+4+16+49=70$. $\|A\hat x\|^2+\|\text{residual}\|^2 =
(0.25+6.25+20.25+42.25) + (0.25+0.25+0.25+0.25) = 69+1=70$ — matches
exactly, confirmed numerically, and $\langle A\hat x,\text{residual}\rangle$
is $0$ to floating-point precision as the proof predicts.)

**16.** Using $Q,R$ from Problem 8 and $b=(1,2,4)$:
$$\langle b,q_1\rangle = \frac{1+2+4}{\sqrt3} = \frac{7}{\sqrt3}, \qquad
\langle b,q_2\rangle = \frac{(-2)(1)+(1)(2)+(1)(4)}{\sqrt6} =
\frac{-2+2+4}{\sqrt6} = \frac{4}{\sqrt6}.$$
Back-substitution on $R\hat x = Q^Tb = \left(\tfrac7{\sqrt3},
\tfrac4{\sqrt6}\right)$ for $\hat x = (x_1,x_2)$:
Row 2: $\dfrac{\sqrt6}{3}x_2 = \dfrac{4}{\sqrt6} \implies x_2 =
\dfrac{4}{\sqrt6}\cdot\dfrac{3}{\sqrt6} = \dfrac{12}{6}=2.$
Row 1: $\sqrt3\,x_1 + \dfrac{2}{\sqrt3}(2) = \dfrac{7}{\sqrt3} \implies
\sqrt3\,x_1 = \dfrac{7}{\sqrt3}-\dfrac{4}{\sqrt3} = \dfrac{3}{\sqrt3} =
\sqrt3 \implies x_1 = 1.$
So $\hat x = (1,2)$ via QR.

**Normal equations, directly.** $A^TA = \begin{pmatrix}1+1+1 & 0+1+1 \\
0+1+1 & 0+1+1\end{pmatrix} = \begin{pmatrix}3&2\\2&2\end{pmatrix}$, $A^Tb =
\begin{pmatrix}1+2+4\\0+2+4\end{pmatrix} = \begin{pmatrix}7\\6\end{pmatrix}$.
Solving $3x_1+2x_2=7$, $2x_1+2x_2=6$: subtracting the second from the first
gives $x_1 = 1$, then $2(1)+2x_2=6 \implies x_2=2$.

**Both methods give $\hat x = (1,2)$** — confirmed numerically, including a
direct check that `numpy.linalg.qr`'s $Q,R$ (up to column sign) and
`numpy.linalg.solve` on the normal equations agree with these hand
computations to floating-point precision.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $\langle u, v\rangle$ | "the inner product of $u$ and $v$" | the dot product; measures length and angle |
| $\Vert u\Vert$ | "the norm of $u$" | its length, $\sqrt{\langle u,u\rangle}$ |
| $\lvert\langle u,v\rangle\rvert \le \Vert u\Vert\Vert v\Vert$ | "Cauchy-Schwarz" | equality exactly when $u, v$ are parallel |
| $W^\perp$ | "$W$-perp, the orthogonal complement" | everything perpendicular to all of $W$ |
| $\operatorname{proj}_W(v)$ | "the projection of $v$ onto $W$" | the closest point of $W$ to $v$ |
| $A^TA\hat x = A^Tb$ | "the normal equations" | solve for the least-squares best fit $\hat x$ |
| $A = QR$ | "A as Q times R" | orthonormal $Q$, upper-triangular $R$ (Gram-Schmidt, packaged) |

Nothing new is introduced today — the table above recalls the symbols from
Days 14–17 a returning learner most wants back at their fingertips.

### The big ideas (conclusions)

- Cauchy-Schwarz $\lvert\langle u,v\rangle\rvert \le \|u\|\|v\|$ underwrites
  the whole week's geometry: it is what lets you define the angle between
  vectors, with equality exactly when they are parallel.
- Gram-Schmidt turns any linearly independent set into an orthonormal one
  spanning the same subspaces, one vector at a time.
- The orthogonal projection onto $W$ is the closest point in $W$, and least
  squares is precisely that projection onto a column space $C(A)$.
- $A = QR$ packages Gram-Schmidt as a factorization; $Q$'s orthonormal
  columns preserve lengths and give a numerically stable least-squares solve.
- These four days are one cumulative chain — Gram-Schmidt feeds projection,
  which feeds least squares, which feeds QR — not four independent topics.

### If you remember only 3 things

1. Cauchy-Schwarz and the closest-point (projection) picture are the two
   load-bearing ideas of the week; nearly everything else hangs off them.
2. Gram-Schmidt $\to$ projection $\to$ least squares $\to$ QR is a single
   connected chain — trace it end to end and the four days lock together.
3. This is retrieval, not rereading: a miss you label a *concept gap*
   (rather than an arithmetic slip) is the one worth re-studying now.

## Journal template

```
## Day 18 — Review (Days 14-17)
Score: __/__
Concept gaps found: ...
Arithmetic-only slips: ...
```
