# Day 12 — Diagonalization Applications: Matrix Powers, Difference Equations

## Learning objectives

By the end of today you should be able to:
- Prove that if $A = PDP^{-1}$ then $A^k = PD^kP^{-1}$ for every positive
  integer $k$, and explain why this makes computing high matrix powers cheap.
- Convert a linear recurrence (difference equation) into a first-order matrix
  recurrence $x_{n+1} = Ax_n$, and use diagonalization to solve it in closed
  form.
- Reproduce, from scratch, the diagonalization-based derivation of Binet's
  formula for the Fibonacci numbers.
- Read off the long-run behavior of a linear recurrence (growth, decay, or
  stability) directly from the magnitude of $A$'s dominant eigenvalue.

## Reference material

- No dedicated video today. Before reading the Theory section, spend 5
  minutes sketching by hand: write out $A$, $A^2$, $A^3$ by direct matrix
  multiplication for a simple $2\times2$ matrix, and notice how quickly the
  bookkeeping grows. That felt cost is the motivation for everything below —
  diagonalization is the fix for exactly that pain.
- MIT OCW 18.06 (Strang), course page:
  [ocw.mit.edu/courses/18-06-linear-algebra-spring-2010](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/) —
  specifically **Lecture 24, "Markov matrices; Fourier series"**
  ([direct link](https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/resources/lecture-24-markov-matrices-fourier-series/)),
  which is the same $A^k = PD^kP^{-1}$ idea applied to Markov chains instead
  of Fibonacci — the ML-adjacent generalization of today's material. Skim it
  after finishing the exercises, and check the syllabus/problem-set page for
  that unit's problem set if you want more drill.
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  the applied-diagonalization problems in the chapter on eigenvalues and
  diagonalization (matrix powers, recurrence relations) — if you don't have
  a copy, the exercises below are self-contained and sufficient for today.

## Theory

Today builds directly on Day 11: you already know that if $A$ is
diagonalizable, $A = PDP^{-1}$, where the columns of $P$ are linearly
independent eigenvectors of $A$ and $D$ is the diagonal matrix of the
corresponding eigenvalues. Today is about *what that buys you*. There is
one small theorem, proved carefully, and then a full worked derivation that
does most of the conceptual work.

### Theorem 12.1 (Powers of a diagonalizable matrix)

If $A = PDP^{-1}$ with $D = \operatorname{diag}(\lambda_1, \dots, \lambda_n)$,
then for every integer $k \ge 1$,
$$A^k = PD^kP^{-1}, \qquad \text{where } D^k = \operatorname{diag}(\lambda_1^k, \dots, \lambda_n^k).$$

**Proof.** By induction on $k$.

*Base case ($k=1$).* $A^1 = A = PDP^{-1} = PD^1P^{-1}$, trivially true.

*Inductive step.* Suppose $A^k = PD^kP^{-1}$ for some $k \ge 1$ (inductive
hypothesis). Then
$$A^{k+1} = A \cdot A^k = (PDP^{-1})(PD^kP^{-1}).$$
Matrix multiplication is associative, so regroup the middle factors:
$$A^{k+1} = PD(P^{-1}P)D^kP^{-1}.$$
Since $P^{-1}P = I$ (definition of matrix inverse) and multiplying by $I$
changes nothing,
$$A^{k+1} = PDD^kP^{-1} = PD^{k+1}P^{-1},$$
using $D \cdot D^k = D^{k+1}$, which holds because $D$ is diagonal:
multiplying two diagonal matrices multiplies corresponding diagonal entries,
so $D \cdot D^k = \operatorname{diag}(\lambda_1 \cdot \lambda_1^k, \dots,
\lambda_n \cdot \lambda_n^k) = \operatorname{diag}(\lambda_1^{k+1}, \dots,
\lambda_n^{k+1}) = D^{k+1}$.

This is exactly the claim for $k+1$. By induction, $A^k = PD^kP^{-1}$ holds
for all integers $k \ge 1$. $\blacksquare$

**Why this matters computationally.** Computing $A^k$ directly by repeated
matrix multiplication costs $k-1$ matrix multiplications, each $O(n^3)$ for
an $n\times n$ matrix (or at best $O(\log k)$ multiplications via repeated
squaring — still $O(n^3 \log k)$, and still not a closed form you can plug
$k$ into symbolically). Once $A$ is diagonalized, $D^k$ costs only $n$ scalar
exponentiations — each diagonal entry raised to the $k$-th power
*independently*, since a diagonal matrix acts on each coordinate axis
separately with no interaction between them. The one-time cost of finding
$P$ and $D$ (solving the characteristic polynomial, Day 10–11's work) is
paid once; after that, $A^k$ for *any* $k$ — including symbolic $k$, or
$k \to \infty$ — is cheap, and closed form.

### Setting up a difference equation as a matrix recurrence

A **linear difference equation** (recurrence) expresses each term of a
sequence as a fixed linear combination of the previous few terms. The
standard trick for solving one is to stack the last few terms into a vector
and rewrite the recurrence as a single matrix multiplication — turning a
recurrence in one variable into Theorem 12.1's setting.

## Worked example: Binet's formula for the Fibonacci numbers

The Fibonacci sequence is defined by $F_0 = 0$, $F_1 = 1$, and
$F_{n+1} = F_n + F_{n-1}$ for $n \ge 1$. We derive a closed-form expression
for $F_n$ — no recursion, no loop, just plug in $n$.

**Step 1: rewrite as a matrix recurrence.** Stack consecutive terms into a
vector $x_n = \begin{pmatrix}F_{n+1}\\F_n\end{pmatrix}$. The recurrence
$F_{n+1} = F_n + F_{n-1}$ together with the trivial identity $F_n = F_n$
gives
$$\begin{pmatrix}F_{n+1}\\F_n\end{pmatrix} = \begin{pmatrix}1&1\\1&0\end{pmatrix}\begin{pmatrix}F_n\\F_{n-1}\end{pmatrix},
\qquad\text{i.e. } x_n = Ax_{n-1}, \quad A = \begin{pmatrix}1&1\\1&0\end{pmatrix}.$$
Check: $A\begin{pmatrix}F_n\\F_{n-1}\end{pmatrix} = \begin{pmatrix}1\cdot
F_n + 1\cdot F_{n-1}\\ 1\cdot F_n + 0\cdot F_{n-1}\end{pmatrix} =
\begin{pmatrix}F_n+F_{n-1}\\F_n\end{pmatrix} = \begin{pmatrix}F_{n+1}\\F_n\end{pmatrix}$ ✓.
Unrolling, $x_n = A^n x_0$ where $x_0 = \begin{pmatrix}F_1\\F_0\end{pmatrix}
= \begin{pmatrix}1\\0\end{pmatrix}$.

**Step 2: find $A$'s eigenvalues.** The characteristic polynomial is
$$\det(A - \lambda I) = \det\begin{pmatrix}1-\lambda & 1\\1 & -\lambda\end{pmatrix}
= (1-\lambda)(-\lambda) - 1 = \lambda^2 - \lambda - 1.$$
By the quadratic formula, $\lambda = \frac{1 \pm \sqrt{5}}{2}$. Name the two
roots
$$\varphi = \frac{1+\sqrt5}{2} \approx 1.618 \quad(\text{the golden ratio}),
\qquad \psi = \frac{1-\sqrt5}{2} \approx -0.618.$$
Both are real and distinct ($\sqrt5 \ne 0$), so $A$ is diagonalizable
(Day 11: distinct eigenvalues guarantee diagonalizability).

**Step 3: find the eigenvectors.** For $\lambda = \varphi$, solve
$(A - \varphi I)v = 0$:
$$\begin{pmatrix}1-\varphi & 1\\1 & -\varphi\end{pmatrix}\begin{pmatrix}v_1\\v_2\end{pmatrix} = 0
\implies v_1 - \varphi v_2 = 0 \implies v_1 = \varphi v_2.$$
(The first row gives $(1-\varphi)v_1 + v_2 = 0$; since $\varphi$ satisfies
$\varphi^2 - \varphi - 1 = 0$, i.e. $\varphi - 1 = 1/\varphi$, both rows are
consistent — a direct check: $(1-\varphi)\varphi + 1 = \varphi - \varphi^2+1
= \varphi - (\varphi+1) + 1 = 0$ ✓.) Taking $v_2 = 1$ gives the eigenvector
$v_\varphi = \begin{pmatrix}\varphi\\1\end{pmatrix}$. By the same computation
with $\psi$ in place of $\varphi$ (which also satisfies $\psi^2-\psi-1=0$),
$v_\psi = \begin{pmatrix}\psi\\1\end{pmatrix}$.

**Step 4: assemble $P$, $D$, and diagonalize.**
$$P = \begin{pmatrix}\varphi & \psi\\1&1\end{pmatrix}, \qquad
D = \begin{pmatrix}\varphi & 0\\0&\psi\end{pmatrix}, \qquad A = PDP^{-1}.$$
$P$ is invertible because $\varphi \ne \psi$ (its columns are not parallel):
$\det P = \varphi - \psi = \sqrt5 \ne 0$, so
$$P^{-1} = \frac{1}{\sqrt5}\begin{pmatrix}1 & -\psi\\-1&\varphi\end{pmatrix}.$$

**Step 5: apply Theorem 12.1.** $A^n = PD^nP^{-1}$ with
$D^n = \begin{pmatrix}\varphi^n&0\\0&\psi^n\end{pmatrix}$. Then
$$x_n = A^n x_0 = PD^nP^{-1}\begin{pmatrix}1\\0\end{pmatrix}.$$
Compute $P^{-1}\begin{pmatrix}1\\0\end{pmatrix} = \frac{1}{\sqrt5}\begin{pmatrix}1\\-1\end{pmatrix}$,
then $D^n\cdot\frac{1}{\sqrt5}\begin{pmatrix}1\\-1\end{pmatrix} =
\frac{1}{\sqrt5}\begin{pmatrix}\varphi^n\\-\psi^n\end{pmatrix}$, then
$$P\cdot\frac{1}{\sqrt5}\begin{pmatrix}\varphi^n\\-\psi^n\end{pmatrix}
= \frac{1}{\sqrt5}\begin{pmatrix}\varphi\cdot\varphi^n - \psi\cdot\psi^n\\ \varphi^n - \psi^n\end{pmatrix}
= \frac{1}{\sqrt5}\begin{pmatrix}\varphi^{n+1}-\psi^{n+1}\\\varphi^n-\psi^n\end{pmatrix}.$$
Recall $x_n = \begin{pmatrix}F_{n+1}\\F_n\end{pmatrix}$, so reading off the
second coordinate gives **Binet's formula**:
$$\boxed{F_n = \frac{\varphi^n - \psi^n}{\sqrt5}}.$$

**Step 6: verify against the known base cases.** $F_0 = \frac{\varphi^0 -
\psi^0}{\sqrt5} = \frac{1-1}{\sqrt5} = 0$ ✓. $F_1 = \frac{\varphi-\psi}{\sqrt5}
= \frac{\sqrt5}{\sqrt5} = 1$ ✓ (using $\varphi - \psi = \sqrt5$ from Step 4).
Both match the definition, and since the formula satisfies the same linear
recurrence (any linear combination of $\varphi^n$ and $\psi^n$ does, because
they are the eigenvalues of the recurrence's matrix), matching the two seed
values pins down that it agrees with $F_n$ for *all* $n$.

### Second example: fast computation of $A^{10}$

Let $B = \begin{pmatrix}4&-2\\1&1\end{pmatrix}$. Characteristic polynomial:
$\det(B-\lambda I) = (4-\lambda)(1-\lambda) - (-2)(1) = \lambda^2-5\lambda+6
= (\lambda-2)(\lambda-3)$, so $\lambda_1=2,\lambda_2=3$. Eigenvector for
$\lambda=2$: $(B-2I)v=0 \Rightarrow \begin{pmatrix}2&-2\\1&-1\end{pmatrix}v=0
\Rightarrow v_1=v_2$, take $\begin{pmatrix}1\\1\end{pmatrix}$. Eigenvector
for $\lambda=3$: $(B-3I)v=0 \Rightarrow \begin{pmatrix}1&-2\\1&-2\end{pmatrix}v=0
\Rightarrow v_1=2v_2$, take $\begin{pmatrix}2\\1\end{pmatrix}$. So
$P=\begin{pmatrix}1&2\\1&1\end{pmatrix}$, $D=\begin{pmatrix}2&0\\0&3\end{pmatrix}$,
$\det P = 1-2=-1$, $P^{-1}=\begin{pmatrix}-1&2\\1&-1\end{pmatrix}$ (dividing
by $\det P=-1$ flips signs: $P^{-1}=\frac{1}{-1}\begin{pmatrix}1&-2\\-1&1\end{pmatrix}
= \begin{pmatrix}-1&2\\1&-1\end{pmatrix}$). Then, without ever multiplying
$B$ by itself nine times,
$$B^{10} = PD^{10}P^{-1} = \begin{pmatrix}1&2\\1&1\end{pmatrix}\begin{pmatrix}2^{10}&0\\0&3^{10}\end{pmatrix}\begin{pmatrix}-1&2\\1&-1\end{pmatrix}
= \begin{pmatrix}1024&2\cdot59049\\1024&59049\end{pmatrix}\begin{pmatrix}-1&2\\1&-1\end{pmatrix}.$$
Multiplying out: top-left $= -1024+118098=117074$, top-right
$=2048-118098=-116050$, bottom-left $=-1024+59049=58025$, bottom-right
$=2048-59049=-57001$. So $B^{10}=\begin{pmatrix}117074&-116050\\58025&-57001\end{pmatrix}$
— two scalar exponentiations ($2^{10}$, $3^{10}$) and a fixed amount of
$2\times2$ bookkeeping, regardless of whether the exponent were 10 or
10,000.

## Unconventional edge

The trap: treating diagonalization as an abstract exercise you do to pass a
problem set, with no real payoff once the proof is written. In fact it is
the difference between an $O(n^3)$-per-step *naive* matrix power
computation (or even $O(n^3\log k)$ with repeated squaring) and an
essentially $O(n)$-per-step *closed form* once you've paid the one-time
$O(n^3)$ cost of diagonalizing $A$ — the eigendecomposition amortizes across
every future power you'll ever need, including symbolic ones. This is also
not a Fibonacci-specific party trick: it is *exactly* the mechanism behind
analyzing the long-run behavior of Markov chains (state distribution after
$n$ steps $= A^n x_0$) and linear population models (age-structured growth
models, e.g. Leslie matrices) — the entire reason those fields care about
eigenvalues at all is that the dominant eigenvalue of the transition matrix
governs the long-run growth rate or steady state, read directly off $D^n$
without ever forming $A^n$ by brute force.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–4 are computational; 5–8 are proof/conceptual.

1. Let $A = \begin{pmatrix}2&0\\0&3\end{pmatrix}$. Diagonalization is trivial
   here since $A$ is already diagonal. Compute $A^{10}$ directly and
   confirm it equals $PD^{10}P^{-1}$ with $P=I$.
2. Let $A = \begin{pmatrix}3&1\\0&2\end{pmatrix}$. Find $A$'s eigenvalues
   and eigenvectors, diagonalize $A = PDP^{-1}$, and use this to compute
   $A^5$ by hand.
3. Let $C = \begin{pmatrix}0&2\\1&1\end{pmatrix}$. Find $C$'s eigenvalues
   and eigenvectors, diagonalize, and compute $C^6$.
4. Using the $B = \begin{pmatrix}4&-2\\1&1\end{pmatrix}$ diagonalization
   from the worked example above, compute $B^2$ two ways — (a) directly by
   matrix multiplication, (b) via $PD^2P^{-1}$ — and confirm they agree.
5. Consider the recurrence $a_{n+1} = 3a_n - 2a_{n-1}$ with $a_0=1, a_1=2$.
   (a) Write it as $x_n = Ax_{n-1}$ with $x_n=\begin{pmatrix}a_{n+1}\\a_n\end{pmatrix}$,
   identifying $A$. (b) Find $A$'s eigenvalues and eigenvectors. (c)
   Diagonalize and derive a closed-form expression for $a_n$. (d) Verify
   your formula against $a_0=1$ and $a_1=2$.
6. Prove rigorously: if $A = PDP^{-1}$, then for all integers $j,k \ge 1$,
   $A^{j+k} = A^jA^k$ (i.e. the usual exponent law still holds), using
   Theorem 12.1 and the fact that $D^jD^k=D^{j+k}$ for diagonal matrices.
7. Prove: if $A = PDP^{-1}$ is $n\times n$ and every eigenvalue $\lambda_i$
   of $A$ satisfies $|\lambda_i| < 1$, then $A^k \to 0$ (the zero matrix) as
   $k \to \infty$. (Hint: show $D^k \to 0$ entrywise first, then use
   $A^k = PD^kP^{-1}$ and the fact that $P, P^{-1}$ are fixed matrices not
   depending on $k$.)
8. Conceptual: for a difference equation $x_n = Ax_{n-1}$ with $A$
   diagonalizable, the long-run behavior of $x_n$ as $n\to\infty$ is
   governed by the eigenvalue of $A$ with the largest absolute value (the
   **dominant eigenvalue** $\lambda_{\max}$). Explain, in your own words,
   what happens to $x_n$ in each of these three cases: (a) $|\lambda_{\max}|
   > 1$, (b) $|\lambda_{\max}| = 1$, (c) $|\lambda_{\max}| < 1$. Then explain
   why, for a Markov chain's transition matrix (whose dominant eigenvalue is
   always exactly $1$), this is precisely why the chain settles into a
   *stationary distribution* instead of the state vector blowing up or
   decaying to zero.

## Solutions

**1.** $A^{10} = \begin{pmatrix}2^{10}&0\\0&3^{10}\end{pmatrix} =
\begin{pmatrix}1024&0\\0&59049\end{pmatrix}$ by direct computation, since
raising a diagonal matrix to a power just raises each diagonal entry. With
$P=I$, $D=A$: $PD^{10}P^{-1} = I \cdot A^{10}\cdot I = A^{10}$, trivially
the same. This confirms Theorem 12.1 in the degenerate case where $A$ is
already diagonal (eigenvectors are the standard basis vectors).

**2.** Characteristic polynomial: $\det(A-\lambda I) =
(3-\lambda)(2-\lambda) = 0$, so $\lambda_1=3,\lambda_2=2$ (upper triangular,
so eigenvalues are the diagonal entries directly — consistent). For
$\lambda=3$: $(A-3I)v=0 \Rightarrow \begin{pmatrix}0&1\\0&-1\end{pmatrix}v=0
\Rightarrow v_2=0$, take $\begin{pmatrix}1\\0\end{pmatrix}$. For $\lambda=2$:
$(A-2I)v=0\Rightarrow\begin{pmatrix}1&1\\0&0\end{pmatrix}v=0\Rightarrow
v_1=-v_2$, take $\begin{pmatrix}-1\\1\end{pmatrix}$. So
$P=\begin{pmatrix}1&-1\\0&1\end{pmatrix}$, $D=\begin{pmatrix}3&0\\0&2\end{pmatrix}$,
$\det P=1$, $P^{-1}=\begin{pmatrix}1&1\\0&1\end{pmatrix}$. Then
$A^5=PD^5P^{-1}=\begin{pmatrix}1&-1\\0&1\end{pmatrix}\begin{pmatrix}243&0\\0&32\end{pmatrix}\begin{pmatrix}1&1\\0&1\end{pmatrix}
=\begin{pmatrix}243&-32\\0&32\end{pmatrix}\begin{pmatrix}1&1\\0&1\end{pmatrix}
=\begin{pmatrix}243&211\\0&32\end{pmatrix}$.

**3.** $\det(C-\lambda I) = (0-\lambda)(1-\lambda)-2\cdot1 =
\lambda^2-\lambda-2=(\lambda-2)(\lambda+1)$, so $\lambda_1=2,\lambda_2=-1$.
For $\lambda=2$: $(C-2I)v=0\Rightarrow\begin{pmatrix}-2&2\\1&-1\end{pmatrix}v=0
\Rightarrow v_1=v_2$, take $\begin{pmatrix}1\\1\end{pmatrix}$. For
$\lambda=-1$: $(C+I)v=0\Rightarrow\begin{pmatrix}1&2\\1&2\end{pmatrix}v=0
\Rightarrow v_1=-2v_2$, take $\begin{pmatrix}-2\\1\end{pmatrix}$. So
$P=\begin{pmatrix}1&-2\\1&1\end{pmatrix}$, $D=\begin{pmatrix}2&0\\0&-1\end{pmatrix}$,
$\det P=1+2=3$, $P^{-1}=\frac13\begin{pmatrix}1&2\\-1&1\end{pmatrix}$. Then
$D^6=\begin{pmatrix}64&0\\0&1\end{pmatrix}$ (since $(-1)^6=1$), and
$C^6=PD^6P^{-1}=\begin{pmatrix}1&-2\\1&1\end{pmatrix}\begin{pmatrix}64&0\\0&1\end{pmatrix}\cdot\frac13\begin{pmatrix}1&2\\-1&1\end{pmatrix}
=\frac13\begin{pmatrix}64&-2\\64&1\end{pmatrix}\begin{pmatrix}1&2\\-1&1\end{pmatrix}
=\frac13\begin{pmatrix}66&126\\63&129\end{pmatrix}
=\begin{pmatrix}22&42\\21&43\end{pmatrix}$.

**4.** (a) Direct: $B^2 = \begin{pmatrix}4&-2\\1&1\end{pmatrix}\begin{pmatrix}4&-2\\1&1\end{pmatrix}
= \begin{pmatrix}16-2&-8-2\\4+1&-2+1\end{pmatrix} =
\begin{pmatrix}14&-10\\5&-1\end{pmatrix}$. (b) Via diagonalization (using
$P,D,P^{-1}$ from the worked example): $D^2=\begin{pmatrix}4&0\\0&9\end{pmatrix}$,
$PD^2=\begin{pmatrix}1&2\\1&1\end{pmatrix}\begin{pmatrix}4&0\\0&9\end{pmatrix}
=\begin{pmatrix}4&18\\4&9\end{pmatrix}$, then
$PD^2P^{-1}=\begin{pmatrix}4&18\\4&9\end{pmatrix}\begin{pmatrix}-1&2\\1&-1\end{pmatrix}
=\begin{pmatrix}-4+18&8-18\\-4+9&8-9\end{pmatrix}=\begin{pmatrix}14&-10\\5&-1\end{pmatrix}$.
Both methods agree.

**5.** (a) $a_{n+1}=3a_n-2a_{n-1}$ together with $a_n=a_n$ gives
$\begin{pmatrix}a_{n+1}\\a_n\end{pmatrix} = \begin{pmatrix}3&-2\\1&0\end{pmatrix}\begin{pmatrix}a_n\\a_{n-1}\end{pmatrix}$,
so $A=\begin{pmatrix}3&-2\\1&0\end{pmatrix}$. (b) $\det(A-\lambda I) =
(3-\lambda)(-\lambda)-(-2)(1) = \lambda^2-3\lambda+2=(\lambda-1)(\lambda-2)$,
so $\lambda_1=2,\lambda_2=1$. For $\lambda=2$:
$(A-2I)v=0\Rightarrow\begin{pmatrix}1&-2\\1&-2\end{pmatrix}v=0\Rightarrow
v_1=2v_2$, take $\begin{pmatrix}2\\1\end{pmatrix}$. For $\lambda=1$:
$(A-I)v=0\Rightarrow\begin{pmatrix}2&-2\\1&-1\end{pmatrix}v=0\Rightarrow
v_1=v_2$, take $\begin{pmatrix}1\\1\end{pmatrix}$. (c)
$P=\begin{pmatrix}2&1\\1&1\end{pmatrix}$, $D=\begin{pmatrix}2&0\\0&1\end{pmatrix}$,
$\det P=1$, $P^{-1}=\begin{pmatrix}1&-1\\-1&2\end{pmatrix}$. With
$x_0=\begin{pmatrix}a_1\\a_0\end{pmatrix}=\begin{pmatrix}2\\1\end{pmatrix}$,
$P^{-1}x_0=\begin{pmatrix}1&-1\\-1&2\end{pmatrix}\begin{pmatrix}2\\1\end{pmatrix}
=\begin{pmatrix}1\\0\end{pmatrix}$. Then
$x_n=PD^nP^{-1}x_0=PD^n\begin{pmatrix}1\\0\end{pmatrix}
=P\begin{pmatrix}2^n\\0\end{pmatrix}=\begin{pmatrix}2\\1\end{pmatrix}2^n
=\begin{pmatrix}2^{n+1}\\2^n\end{pmatrix}$. Reading off the second
coordinate: $a_n = 2^n$. (Equivalently, the general solution is
$a_n=c_1 2^n+c_2 1^n$, and matching $a_0=1,a_1=2$ forces $c_1=1,c_2=0$.)
(d) Check: $a_0=2^0=1$ ✓, $a_1=2^1=2$ ✓.

**6.** By Theorem 12.1, $A^j = PD^jP^{-1}$ and $A^k=PD^kP^{-1}$. Then
$$A^jA^k = (PD^jP^{-1})(PD^kP^{-1}) = PD^j(P^{-1}P)D^kP^{-1} = PD^jD^kP^{-1}$$
using $P^{-1}P=I$ and associativity, exactly as in the proof of Theorem
12.1. Since $D$ is diagonal, $D^jD^k=\operatorname{diag}(\lambda_1^j\lambda_1^k,\dots)
=\operatorname{diag}(\lambda_1^{j+k},\dots)=D^{j+k}$. So
$A^jA^k = PD^{j+k}P^{-1} = A^{j+k}$ (again by Theorem 12.1, applied to
exponent $j+k$). $\blacksquare$

**7.** Since $D=\operatorname{diag}(\lambda_1,\dots,\lambda_n)$,
$D^k=\operatorname{diag}(\lambda_1^k,\dots,\lambda_n^k)$. For each $i$,
$|\lambda_i|<1$ implies $\lambda_i^k \to 0$ as $k\to\infty$ (a standard
scalar limit: $|\lambda_i^k| = |\lambda_i|^k \to 0$ since $|\lambda_i|<1$).
So every diagonal entry of $D^k$ tends to $0$, i.e. $D^k \to 0$ (the zero
matrix) entrywise. Now $A^k = PD^kP^{-1}$ by Theorem 12.1, where $P$ and
$P^{-1}$ are fixed matrices (their entries don't change with $k$). Each
entry of $A^k$ is a fixed finite sum of products of entries of $P$, entries
of $D^k$, and entries of $P^{-1}$; since the entries of $D^k$ all $\to 0$
and everything else is constant in $k$, each entry of $A^k$ is a finite sum
of terms each tending to $0$, hence tends to $0$ itself. So $A^k \to 0$
entrywise, i.e. $A^k \to 0$ as $k\to\infty$. $\blacksquare$

**8.** For large $n$, $x_n = A^nx_0 = PD^nP^{-1}x_0$ is dominated by the
term involving $\lambda_{\max}^n$, since every other eigenvalue's power
shrinks relative to it (this is why it's called "dominant"). (a) If
$|\lambda_{\max}|>1$, that term grows without bound, so $\|x_n\|\to\infty$
— the sequence diverges (exponential growth), as in the Fibonacci sequence
itself ($\varphi\approx1.618>1$). (b) If $|\lambda_{\max}|=1$, that term
neither grows nor decays in magnitude, so $x_n$ settles toward a fixed
nonzero limit (if $\lambda_{\max}=1$ exactly and it's the unique dominant
eigenvalue) or oscillates with bounded magnitude (if $\lambda_{\max}=-1$ or
complex with modulus 1) — no blow-up, no collapse to zero. (c) If
$|\lambda_{\max}|<1$, then by Exercise 7's logic applied to the dominant
term, $x_n \to 0$ — the sequence decays to the zero vector regardless of
starting point. For a Markov chain's transition matrix, the dominant
eigenvalue is always exactly $1$ (a structural fact about stochastic
matrices — their rows/columns sum to 1, which forces $\lambda=1$ to be an
eigenvalue and no eigenvalue to exceed it in magnitude). By case (b), the
state vector $x_n = A^nx_0$ therefore neither blows up nor vanishes as
$n\to\infty$: it converges to a fixed nonzero vector — the **stationary
distribution** — which is exactly the eigenvector for $\lambda=1$
(normalized to sum to 1). This is the same $A^n = PD^nP^{-1}$ machinery
from today, just with the extra structural guarantee $|\lambda_{\max}|=1$
baked in by what a Markov matrix *is*.

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab recomputes the Fibonacci closed form numerically two ways —
via direct diagonalization ($A^n = PD^nP^{-1}$, built by hand from
`numpy.linalg.eig`'s output) and via NumPy's built-in
`numpy.linalg.matrix_power` — and checks they agree. Open
`starter_code/day12_diagonalization_applications.py` — it has one function
to complete, `fib_via_diagonalization`.

**Hint:** this is the exact computation from Step 5 of the worked example,
just done with NumPy arrays instead of pencil and paper. Build
`D_n = np.diag(eigvals ** n)`, then `A_n = eigvecs @ D_n @
np.linalg.inv(eigvecs)` (this is $PD^nP^{-1}$ with `eigvecs` playing the
role of $P$), then apply `A_n` to the starting vector `[1.0, 0.0]`
(representing $x_0 = (F_1, F_0)$) and return index `1` (the $F_n$
component) as a float. Note `numpy.linalg.eig` returns complex-typed
eigenvalues/eigenvectors even when the true values are real (small
imaginary rounding artifacts), so the final answer should be cast with
`.real`.

Fill in the `TODO`, then run the file directly
(`python starter_code/day12_diagonalization_applications.py`); it should
print matching values for $n=10, 20, 30$ under both methods, with no
assertion errors, and save a plot of the two eigenvector directions of the
Fibonacci matrix to `starter_code/day12_eigenvector_directions.png`.

If you get stuck for more than ~10 minutes, check
`solutions/day12_diagonalization_applications.py` — but only after a real
attempt.

Once your implementation passes, extend it: pick the recurrence from
Exercise 5 ($a_{n+1}=3a_n-2a_{n-1}$), build its matrix $A$ with NumPy,
diagonalize it with `np.linalg.eig`, and confirm numerically that
$a_n = 2^n$ for a few values of $n$ — this checks your by-hand derivation
in Exercise 5 against the computer, the same verify-what-you-solved pattern
as every other code lab this month.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $A^k = PD^kP^{-1}$ | "the $k$-th power, computed the cheap way" | diagonalize once, then only $D^k$ changes with $k$ |
| $D^k = \operatorname{diag}(\lambda_1^k,\dots,\lambda_n^k)$ | "raise each diagonal eigenvalue to the $k$" | the only real work left in computing $A^k$ |
| $x_n = Ax_{n-1}$ | "one step of the recurrence is one matrix multiply" | stacking consecutive terms turns a recurrence into this |
| $\varphi,\ \psi$ | "phi and psi — the roots $\tfrac{1\pm\sqrt5}{2}$" | eigenvalues of the Fibonacci matrix; $\varphi$ is the golden ratio |
| $F_n$ | "the $n$-th Fibonacci number" | its closed form is Binet's formula |
| $\lambda_{\max}$ | "the dominant (largest-magnitude) eigenvalue" | its size alone decides growth, decay, or steady state |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- Once $A = PDP^{-1}$, every power is $A^k = PD^kP^{-1}$: you diagonalize
  once, then just raise the diagonal eigenvalues to the $k$-th power.
- That converts expensive repeated matrix multiplication into a closed form
  you can evaluate at any $k$ — even symbolic $k$, or $k \to \infty$.
- Any linear recurrence becomes $x_n = Ax_{n-1}$ by stacking the last few
  terms into a vector, so diagonalization solves it in closed form (Binet's
  formula for Fibonacci is the poster child).
- The long-run behavior of $x_n$ is governed entirely by the dominant
  eigenvalue: magnitude $>1$ blows up, $<1$ decays to zero, $=1$ settles —
  which is why a Markov chain reaches a stationary distribution.

### Proof sketches

**Theorem 12.1 — key trick: in $A^{k+1} = A\cdot A^k = (PDP^{-1})(PD^kP^{-1})$,
the inner $P^{-1}P$ collapses to $I$.**
Induct on $k$. The base case $A^1 = PD^1P^{-1}$ is just the definition of
diagonalizability. Assuming $A^k = PD^kP^{-1}$, write $A^{k+1} =
(PDP^{-1})(PD^kP^{-1})$; the adjacent $P^{-1}P$ in the middle is $I$, leaving
$PDD^kP^{-1} = PD^{k+1}P^{-1}$, using that diagonal matrices multiply
entrywise so $D\,D^k = D^{k+1}$. That is exactly the claim for $k+1$. Full
version: Theorem 12.1 above.

### If you remember only 3 things

1. $A^k = PD^kP^{-1}$ — diagonalize once, then each power costs only $n$
   scalar exponentiations down the diagonal.
2. Stack a recurrence's terms into a vector to get $x_n = Ax_{n-1} = A^n x_0$,
   then diagonalize for a closed form (Binet: $F_n = (\varphi^n -
   \psi^n)/\sqrt5$).
3. The dominant eigenvalue's magnitude alone tells you the long run: $>1$
   grows, $<1$ decays, $=1$ holds steady (the Markov-chain case).

## Journal template

```
## Day 12 — Diagonalization applications
Key theorem in my own words: ...
What confused me: ...
```
