# Day 5 — Review: Days 1–4 (Closed-Book)

## Learning objectives

Today introduces no new theory. By the end of today you should be able to
reproduce, entirely from memory, all five of the following core results
established on Days 1–4:

- **Reversible universality.** Toffoli gates plus constant ancilla bits
  realize AND and NOT (and therefore, via De Morgan's law, OR), and any
  classical circuit with $g$ AND/OR/NOT gates converts to a reversible
  circuit with $O(g)$ Toffoli gates and $O(g)$ ancilla bits.
- **BPP and error amplification.** The definition of BPP, and the proof
  that majority-vote repetition drives the error probability down
  exponentially in the number of repetitions, via the Hoeffding/Chernoff
  bound.
- **The $2\times2$ spectral theorem for normal operators**, proved directly
  (not just quoted), and verified concretely on the Hadamard matrix $H$.
- **The Pauli matrices $X,Y,Z$ and Hadamard $H$**, re-derived from their
  defining algebraic properties (Hermitian, unitary, involutory, eigenvalues
  $\pm1$) rather than recalled from memory of the specific numbers.
- **Landauer's principle**, and exactly why a garbage-preserving reversible
  circuit escapes the bound that an overwrite-based irreversible circuit
  does not.

## How to use this review

This is a closed-book day: no new primer, no peeking at the Day 1–4 notes
files while attempting the questions below.

1. Open `notes/day05_review.md` and attempt every question in the **Review
   questions** section from memory, writing out full proofs/derivations, not
   just final answers or sketches.
2. Only after finishing (or running out of your allotted time) should you
   read the **Model answers** section below. Grade yourself question by
   question.
3. For anything wrong, incomplete, or missing a step, copy the correct
   version from Model answers into `notes/day05_review.md` *underneath* your
   original attempt — do not erase or overwrite the original attempt. The
   gap between your attempt and the model answer is itself useful data for
   the Day 15 gap analysis.
4. Finish with the journal entry at the bottom of this file.

## Review questions

Attempt all five closed-book, in `notes/day05_review.md`, before reading the
Model answers section.

1. Prove that Toffoli gates plus constant ancilla bits are universal for
   reversible classical computation.
2. State BPP, and prove that majority-vote repetition amplifies a BPP
   algorithm's success probability exponentially in the number of
   repetitions (the Chernoff/Hoeffding bound argument).
3. State and prove the spectral theorem for normal operators in the
   $2\times2$ case, and verify it explicitly for the Hadamard matrix $H$.
4. Derive the matrix forms of the Pauli matrices $X, Y, Z$ and the Hadamard
   matrix $H$ from their defining properties (unitary and
   Hermitian/involutory, with eigenvalues $\pm1$) — without looking them up.
5. State Landauer's principle, and explain its connection to reversible
   gates.

## Model answers

### 1. Toffoli + ancilla universality for reversible computation

**Claim.** Toffoli gates, together with constant ancilla bits (extra bits
fixed at a known value $0$ or $1$), realize a universal classical gate set
(AND, NOT, and hence OR) entirely reversibly; consequently, any classical
circuit built from $g$ AND/OR/NOT gates can be converted into a reversible
circuit using $O(g)$ Toffoli gates and $O(g)$ ancilla bits.

**Setup.** Recall $\text{Toffoli}(a,b,c) = (a,\ b,\ c \oplus (a\wedge b))$:
both controls pass through unchanged, and the target is XORed with
$a\wedge b$. Toffoli is its own inverse: applying it twice to $(a,b,c)$
gives $c'' = c \oplus (a\wedge b) \oplus (a\wedge b) = c$ (using
$x\oplus x = 0$), so it is a bijection on $\{0,1\}^3$, i.e. reversible.

**Step 1: Reversible AND.** Feed a fresh ancilla fixed at $0$ as the
target: $\text{Toffoli}(a,b,0) = (a,\ b,\ 0\oplus(a\wedge b)) = (a,b,a\wedge
b)$. The two data bits pass through unchanged and the ancilla now holds
$a\wedge b$.

**Step 2: Reversible NOT.** Fix *both* controls to the constant $1$:
$\text{Toffoli}(1,1,c) = (1,1,\ c\oplus(1\wedge1)) = (1,1,\ c\oplus1) =
(1,1,\neg c)$, since XOR with $1$ flips a bit. So Toffoli with both controls
tied to $1$ realizes NOT on the target line.

**Step 3: Reversible OR.** By De Morgan's law, $a\vee b =
\neg(\neg a\wedge\neg b)$. Using Step 2 to compute $\neg a$ and $\neg b$
(routed onto fresh ancillas to avoid destroying $a,b$), Step 1 to AND them,
then Step 2 again to negate the result, gives $a\vee b$ using only
Toffoli gates and constant/fresh ancillas.

Since Toffoli + ancillas realize AND, OR, and NOT — a functionally complete
classical gate set — they can compute *any* Boolean function, reversibly.

**Step 4: General circuit conversion, by induction on gate count $g$.**

*Base case* ($g=0$): a circuit with zero gates is the identity map, which is
trivially a bijection, hence reversible, using $0$ Toffolis and $0$
ancillas.

*Inductive step*: suppose any circuit with $g-1$ AND/OR/NOT gates converts
to a reversible circuit using $O(g-1)$ Toffoli gates and $O(g-1)$ ancilla
bits (inductive hypothesis). Consider a circuit with $g$ gates. Its first
$g-1$ gates convert, by the hypothesis, to a reversible sub-circuit using
$O(g-1)$ Toffolis/ancillas. The $g$-th gate is AND, OR, or NOT acting on
some existing wires (original inputs or outputs of earlier gates, all of
which are still available as wires in the reversible sub-circuit already
built). By Steps 1–3, this single gate is realized by $O(1)$ Toffoli gates
and $O(1)$ fresh ancilla bits, fed from the existing wires, producing one
new (possibly garbage-accompanied) output wire. Appending this $O(1)$-size
reversible gadget to the reversible sub-circuit for the first $g-1$ gates
keeps the whole thing reversible, because a composition of bijections is a
bijection. The total gate count is $O(g-1) + O(1) = O(g)$ Toffolis, and
likewise $O(g-1)+O(1) = O(g)$ ancilla bits.

By induction, this holds for all $g$. $\blacksquare$

**Remark (garbage).** Because each Toffoli/CNOT gadget is a bijection on
*all* of its input lines (data plus ancilla), no intermediate value can be
silently overwritten and discarded the way an ordinary irreversible circuit
does — every ancilla line ends up holding some "garbage" bit that must be
carried through to the output (or later uncomputed by running part of the
circuit in reverse). This is the structural price of staying reversible,
and it is unavoidable in general: a reversible circuit's entire output,
garbage included, must be a bijective function of its entire input.

### 2. BPP and Chernoff-bound error amplification

**Definition.** BPP (bounded-error probabilistic polynomial time) is the
class of languages decidable by a probabilistic polynomial-time algorithm
with two-sided error at most $1/3$ on every input — i.e. for every input
$x$, the algorithm outputs the correct answer with probability at least
$2/3$ (over its internal randomness), whether the correct answer is "yes"
or "no."

**Claim.** Running a BPP algorithm $k$ times independently on the same
input and taking the majority answer reduces the error probability to
$e^{-k/18}$ — exponentially small in $k$.

**Proof.** Fix an input $x$. Let $X_1,\dots,X_k \in \{0,1\}$ be independent
indicator random variables, $X_i = 1$ if the $i$-th run of the algorithm is
correct on $x$. Each $X_i$ is a bounded $[0,1]$-valued (here Bernoulli)
random variable with $\Pr[X_i=1] \ge 2/3$ by the BPP guarantee. Let
$S = \sum_{i=1}^k X_i$ be the number of correct runs, and let
$\bar S = S/k$ be the fraction correct. The majority vote is wrong exactly
when fewer than half the runs are correct, i.e. $\bar S < 1/2$ (treat the
boundary case $\bar S = 1/2$, e.g. with $k$ even, as also "not a strict
majority correct" — it only strengthens the bound to include it).

Let $\bar p = \mathbb{E}[\bar S] = \frac1k\sum_i \Pr[X_i=1] \ge 2/3$ (the
average of the per-run success probabilities). Hoeffding's inequality for a
mean of $k$ independent random variables bounded in $[0,1]$ states: for any
$t > 0$,
$$\Pr\big[\bar S - \bar p \le -t\big] \le e^{-2kt^2}.$$
Since $\bar p \ge 2/3$, the gap $\bar p - 1/2 \ge 2/3 - 1/2 = 1/6$. The
"wrong" event $\{\bar S \le 1/2\}$ is exactly $\{\bar S - \bar p \le
-(\bar p - 1/2)\}$, and since $\bar p - 1/2 \ge 1/6$ we have
$-(\bar p-1/2) \le -1/6$, so
$$\{\bar S \le 1/2\} = \{\bar S - \bar p \le -(\bar p - \tfrac12)\}
\subseteq \{\bar S - \bar p \le -\tfrac16\}$$
(a threshold event is monotone: if $a \le b$ then $\{Y \le a\} \subseteq
\{Y\le b\}$). Applying Hoeffding with $t = 1/6$:
$$\Pr[\text{majority wrong}] = \Pr[\bar S \le \tfrac12] \le
\Pr\big[\bar S - \bar p \le -\tfrac16\big] \le e^{-2k(1/6)^2} = e^{-k/18}.$$

So the constant is $c = 1/18$: repeating the algorithm $k$ times and taking
the majority vote is wrong with probability at most $e^{-k/18}$, which
decays exponentially in $k$. $\blacksquare$

(As a sanity-check use case: to push the error below $2^{-20}$, we'd need
$e^{-k/18} \le 2^{-20}$, i.e. $k \ge 18 \cdot 20\ln 2 \approx 250$ — a
modest, poly-size number of repetitions for an exponentially small error, the
whole point of the amplification lemma.)

### 3. Spectral theorem for normal $2\times2$ operators, applied to $H$

**Definition.** $A$ is *normal* iff $AA^\dagger = A^\dagger A$. Hermitian
($A = A^\dagger$) and unitary ($A^\dagger A = AA^\dagger = I$) matrices are
both special cases.

**Theorem ($2\times2$ case).** If $A$ is a normal $2\times2$ matrix, then
$A = UDU^\dagger$ for some unitary $U$ and diagonal $D$ — i.e. $A$ is
unitarily diagonalizable with an orthonormal eigenbasis, and the diagonal
entries of $D$ are exactly $A$'s eigenvalues.

**Proof.** Over $\mathbb{C}$, $A$'s characteristic polynomial has a root
(fundamental theorem of algebra), so $A$ has at least one eigenvalue
$\lambda_1$ with a corresponding unit eigenvector $v_1$: $Av_1 = \lambda_1
v_1$. Extend $\{v_1\}$ to an orthonormal basis $\{v_1, v_2\}$ of
$\mathbb{C}^2$, and let $U_1 = [v_1\ v_2]$, which is unitary by
construction (orthonormal columns).

In the basis $\{v_1,v_2\}$, write $A' = U_1^\dagger A U_1$. The first
column of $A'$ is $U_1^\dagger A v_1 = U_1^\dagger(\lambda_1 v_1) =
\lambda_1 U_1^\dagger v_1 = \lambda_1 e_1$ (since $U_1^\dagger v_1 = e_1$ by
orthonormality). So
$$A' = \begin{pmatrix}\lambda_1 & b \\ 0 & \lambda_2\end{pmatrix}$$
for some $b\in\mathbb{C}$ and $\lambda_2 = v_2^\dagger A v_2$.

Unitary conjugation preserves normality: $(U_1^\dagger A U_1)(U_1^\dagger A
U_1)^\dagger = U_1^\dagger AA^\dagger U_1$ and
$(U_1^\dagger AU_1)^\dagger(U_1^\dagger AU_1) = U_1^\dagger A^\dagger A
U_1$, and these are equal (since $AA^\dagger = A^\dagger A$) — so $A'$ is
normal too. Compute both products directly:
$$A'A'^\dagger = \begin{pmatrix}\lambda_1&b\\0&\lambda_2\end{pmatrix}
\begin{pmatrix}\lambda_1^*&0\\b^*&\lambda_2^*\end{pmatrix} =
\begin{pmatrix}|\lambda_1|^2+|b|^2 & b\lambda_2^*\\ \lambda_2 b^* &
|\lambda_2|^2\end{pmatrix},$$
$$A'^\dagger A' = \begin{pmatrix}\lambda_1^*&0\\b^*&\lambda_2^*\end{pmatrix}
\begin{pmatrix}\lambda_1&b\\0&\lambda_2\end{pmatrix} =
\begin{pmatrix}|\lambda_1|^2 & \lambda_1^*b \\ b^*\lambda_1 & |b|^2 +
|\lambda_2|^2\end{pmatrix}.$$
Equating the $(1,1)$ entries: $|\lambda_1|^2 + |b|^2 = |\lambda_1|^2$, so
$|b|^2 = 0$, i.e. $b = 0$. Hence $A' = \operatorname{diag}(\lambda_1,
\lambda_2) =: D$, and
$$A = U_1 A' U_1^\dagger = U_1 D U_1^\dagger.$$
$\blacksquare$

**Application to $H$.** $H = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1
\end{pmatrix}$ is real and symmetric, hence Hermitian ($H^\dagger = H$),
hence normal, so the theorem applies. Its trace is $0$ and its determinant
is $\frac12(1\cdot(-1) - 1\cdot1) = -1$, so its eigenvalues $\lambda_1,
\lambda_2$ satisfy $\lambda_1+\lambda_2 = 0$ and $\lambda_1\lambda_2 = -1$,
giving $\lambda^2 = 1$, i.e. $\lambda_{1,2} = \pm1$.

Solve $Hv = v$ directly: $\frac{1}{\sqrt2}(v_1+v_2) = v_1$ and
$\frac{1}{\sqrt2}(v_1-v_2)=v_2$; the first gives $v_2 = (\sqrt2-1)v_1 =
\tan(\pi/8)\,v_1$ (using $\tan(\pi/8)=\sqrt2-1$). A normalized eigenvector
is therefore $v_+ = \big(\cos\frac\pi8,\ \sin\frac\pi8\big)$, since
$\cos^2+\sin^2=1$ and $\sin(\pi/8)/\cos(\pi/8) = \tan(\pi/8)$ matches the
required ratio. The orthogonal unit vector $v_- =
\big(-\sin\frac\pi8,\ \cos\frac\pi8\big)$ is then automatically an
eigenvector for the remaining eigenvalue $-1$ (check: solving $Hv=-v$ gives
$v_2 = -(\sqrt2+1)v_1 = -\cot(\pi/8)\,v_1$, and indeed
$\cos(\pi/8)/(-\sin(\pi/8)) = -\cot(\pi/8)$, matching).

So with
$$U = \begin{pmatrix}\cos\frac\pi8 & -\sin\frac\pi8 \\ \sin\frac\pi8 &
\cos\frac\pi8\end{pmatrix}, \qquad D = \begin{pmatrix}1&0\\0&-1
\end{pmatrix},$$
($U$ is a real rotation by $\pi/8$, hence unitary — orthogonal — with
$U^\dagger = U^T$), direct multiplication confirms $H = UDU^\dagger$: with
$c=\cos(\pi/8), s=\sin(\pi/8)$,
$$UD = \begin{pmatrix}c & s\\ s & -c\end{pmatrix}, \qquad
UDU^\dagger = \begin{pmatrix}c&s\\s&-c\end{pmatrix}
\begin{pmatrix}c&s\\-s&c\end{pmatrix} =
\begin{pmatrix}c^2-s^2 & 2cs \\ 2cs & s^2-c^2\end{pmatrix} =
\begin{pmatrix}\cos\frac\pi4 & \sin\frac\pi4\\ \sin\frac\pi4 &
-\cos\frac\pi4\end{pmatrix} = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1
\end{pmatrix} = H,$$
using the double-angle identities $c^2-s^2=\cos(\pi/4)=\tfrac{1}{\sqrt2}$
and $2cs=\sin(\pi/4)=\tfrac{1}{\sqrt2}$. This is exactly the spectral
decomposition the theorem promised, worked out explicitly for $H$.

### 4. Deriving $X, Y, Z, H$ from their defining properties

**Goal.** Without recalling the specific numbers, derive matrix forms
starting only from: $2\times2$, Hermitian ($A=A^\dagger$), unitary
($A^\dagger A = I$), hence involutory ($A^2=I$, since Hermitian + unitary
gives $A^2 = A^\dagger A = I$), with eigenvalues $\pm1$ (forced by
Hermitian + involutory: eigenvalues of a Hermitian matrix are real, by
Problem 3's spectral theorem applied to the eigenvector equation; and
$A^2=I$ forces $\lambda^2=1$ for every eigenvalue, so $\lambda=\pm1$).

**General form.** Write a general Hermitian $2\times2$ matrix as
$$A = \begin{pmatrix} a & b \\ b^* & d\end{pmatrix}, \qquad a,d\in\mathbb R,\ b\in\mathbb C$$
(Hermitian forces real diagonal and conjugate-related off-diagonal
entries). Impose the involution condition $A^2 = I$:
$$A^2 = \begin{pmatrix}a^2+|b|^2 & b(a+d) \\ b^*(a+d) & |b|^2+d^2
\end{pmatrix} = \begin{pmatrix}1&0\\0&1\end{pmatrix}.$$
This gives three equations: $a^2+|b|^2=1$, $|b|^2+d^2=1$, and
$b(a+d) = 0$.

*Case $b = 0$* (diagonal matrices): then $a^2=1, d^2=1$, so $a,d\in\{+1,-1\}$
independently. Choosing the non-degenerate case $a=1,d=-1$ (so the two
eigenvalues are genuinely different, $+1$ and $-1$, rather than $A=\pm I$)
gives
$$Z = \begin{pmatrix}1&0\\0&-1\end{pmatrix},$$
with eigenvalue $+1$ for eigenvector $(1,0)^T = |0\rangle$ and eigenvalue
$-1$ for eigenvector $(0,1)^T = |1\rangle$ (immediate, since $Z$ is already
diagonal in the standard basis).

*Case $b \ne 0$*: then $a+d=0$, i.e. $d=-a$, and both remaining equations
reduce to the single constraint $a^2+|b|^2=1$ — i.e. $A$ is any trace-zero
Hermitian involution with $(a,b)$ on the circle $a^2+|b|^2=1$. This is a
one-real-parameter family of matrices (up to the phase of $b$); $X$ and $Y$
are the two canonical members singled out by taking $b$ real vs. purely
imaginary, and $a=0$ (equal-and-opposite diagonal entries, so both are
purely off-diagonal):

- $b = 1$ (real, unit modulus), $a=d=0$:
  $$X = \begin{pmatrix}0&1\\1&0\end{pmatrix}.$$
  Solve $Xv=v$: $v_2=v_1$, giving eigenvector $\frac{1}{\sqrt2}(1,1)^T$ for
  eigenvalue $+1$; solve $Xv=-v$: $v_2=-v_1$, giving eigenvector
  $\frac{1}{\sqrt2}(1,-1)^T$ for eigenvalue $-1$.

- $b = -i$ (purely imaginary, unit modulus), $a=d=0$:
  $$Y = \begin{pmatrix}0&-i\\i&0\end{pmatrix}.$$
  Solve $Yv=v$: first row gives $-iv_2=v_1$, i.e. $v_2 = iv_1$, giving
  eigenvector $\frac{1}{\sqrt2}(1,i)^T$ for eigenvalue $+1$ (check second
  row: $iv_1 = i\cdot1 = i = v_2$ ✓); solve $Yv=-v$: $v_2=-iv_1$, giving
  eigenvector $\frac{1}{\sqrt2}(1,-i)^T$ for eigenvalue $-1$.

So the bare algebraic conditions "Hermitian, unitary, eigenvalues $\pm1$"
determine a whole family of matrices (geometrically, the "Bloch-sphere
axis" observables $n\cdot\vec\sigma$ for unit vectors $n$); $X, Y, Z$ are
exactly the three canonical choices lying along the coordinate axes of that
family (purely-real off-diagonal, purely-imaginary off-diagonal, and purely
diagonal, respectively).

**Hadamard $H$.** $H$ also satisfies Hermitian + unitary + involutory +
eigenvalues $\pm1$ (verified in Problem 3), so it too lies in the
$b\ne0$, $d=-a$ family: from Problem 3, $a = d = \pm\frac{1}{\sqrt2}$ (take
$a=\frac1{\sqrt2}$) and $b=\frac1{\sqrt2}$ (real), consistent with
$a^2+b^2 = \tfrac12+\tfrac12=1$. What singles out this exact member of the
family (as opposed to $X$, $Y$, $Z$, or any other point on the circle) is
an additional design requirement not implied by Hermitian/unitary alone:
$H$ is required to be real, symmetric, and have all four entries of equal
magnitude (an "equal-weight, real, no relative phase" superposition
generator) — i.e. $a = |b|$ with $a,b$ both real and positive. Substituting
$a=b$ into $a^2+b^2=1$ gives $2a^2=1$, i.e. $a=b=\frac{1}{\sqrt2}$, and
$d=-a=-\frac1{\sqrt2}$, yielding exactly
$$H = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}.$$
The eigenvalues ($\pm1$) and eigenvectors
($(\cos\frac\pi8,\sin\frac\pi8)$ and $(-\sin\frac\pi8,\cos\frac\pi8)$) were
derived explicitly in Problem 3.

### 5. Landauer's principle and reversible gates

**Statement.** Landauer's principle: a logically irreversible operation —
one that maps two or more distinct input states to the same output state,
i.e. that *erases* information — must dissipate at least $kT\ln2$ of energy
as heat, where $k$ is Boltzmann's constant and $T$ is the absolute
temperature. This is a physical lower bound following from the second law
of thermodynamics applied to information, not merely an engineering
limitation of any particular hardware.

**Connection to reversible gates.** A gate (or circuit) is reversible
exactly when its function on all of its bits is a *bijection* — no two
distinct inputs are ever mapped to the same output, so nothing is erased.
CNOT and Toffoli are reversible in exactly this sense (each is its own
inverse), and Problem 1 showed that Toffoli plus constant ancilla bits can
realize any classical circuit reversibly, at the cost of carrying along
extra "garbage" output lines instead of overwriting/discarding
intermediate values.

Because a reversible circuit's every step is a bijection (never many-to-one),
no step of it performs a logically irreversible erasure, so Landauer's
bound — which applies specifically to many-to-one, information-destroying
steps — simply does not apply to any individual gate in it. By contrast, an
ordinary NAND-based irreversible circuit that overwrites an intermediate
wire with the output of the next gate performs a genuine erasure at every
such overwrite, and each one is individually subject to the $kT\ln2$ floor.

The trade a reversible circuit makes is therefore: more wires (space, for
the accumulated garbage) in exchange for no thermodynamic floor on erasure
energy — the physical motivation, prior to any mention of quantum
mechanics, for caring about reversible computation at all.

## Journal template

```
## Day 5 — Review: Days 1–4 (closed-book)
Key idea in my own words: ...
What confused me: ...
Which items needed correction, and why: ...
```
