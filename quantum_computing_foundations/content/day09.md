# Day 9 — Review: Days 6–8 (Closed-Book)

## Learning objectives

This is a closed-book review day: no new primer material. By the end of
today you should be able to re-derive, without notes, the four core results
that anchor Days 6–8:

- **Entanglement as a separability failure.** State the definition of a
  separable two-qubit pure state, and prove directly from it that the Bell
  state $|\Phi^+\rangle = \frac{1}{\sqrt2}(|00\rangle+|11\rangle)$ cannot be
  written as a tensor product of two single-qubit states.
- **The partial trace as an entanglement witness.** Compute the reduced
  density matrix of one half of an entangled pair via the partial trace, and
  explain why a *pure* global state with a *mixed* marginal is precisely the
  algebraic signature of entanglement.
- **The no-cloning theorem.** Reproduce the full proof that no unitary can
  clone an arbitrary unknown qubit state, including the linearity argument
  that produces the numerical contradiction.
- **Deutsch–Jozsa.** Rebuild the phase-kickback oracle identity, the full
  circuit, and the general-$n$ formula for the amplitude on
  $|0\rangle^{\otimes n}$, and show it exactly separates constant from
  balanced functions with a single, error-free oracle query.

## How to use this review

Before reading anything below the **Review questions** heading, attempt
every question closed-book — no notes, no earlier content files — writing
your full attempt in `notes/day09_review.md`. Only after you have written
(or given your best honest attempt at) all four answers should you compare
against the **Model answers** section here. Per the plan, do not overwrite
your original attempt when you find an error: append the corrected version
immediately below it in `notes/day09_review.md`, so the gap between your
first attempt and the correct answer stays visible as data for the Day 15
gap analysis. Finish by appending a Day 9 journal entry (template at the
bottom of this file) noting which of the four items were solid on the first
pass and which needed correction, and why.

## Review questions

Attempt all four closed-book, in order, before checking Model answers.

1. Prove that the Bell state $|\Phi^+\rangle = \frac{1}{\sqrt2}(|00\rangle +
   |11\rangle)$ is entangled — i.e. that it is **not** separable into a
   tensor product of two single-qubit states.
2. Compute the reduced density matrix of $|\Phi^+\rangle$'s first qubit
   (via the partial trace over the second qubit), and explain why the fact
   that it comes out maximally mixed is the signature of entanglement.
3. Write the full proof of the no-cloning theorem.
4. Re-derive the Deutsch–Jozsa circuit from scratch, and re-derive the
   general-$n$ formula for the amplitude on $|0\rangle^{\otimes n}$ after
   the circuit runs, showing it distinguishes constant from balanced
   functions with certainty.

## Model answers

### 1. $|\Phi^+\rangle$ is entangled

A two-qubit pure state $|\chi\rangle$ is **separable** iff it can be written
$|\chi\rangle = |a\rangle \otimes |b\rangle$ for some single-qubit states
$|a\rangle = a_0|0\rangle+a_1|1\rangle$ and $|b\rangle =
b_0|0\rangle+b_1|1\rangle$. A state that is not separable is **entangled**.

Suppose, for contradiction, that
$$|\Phi^+\rangle = (a|0\rangle+b|1\rangle)\otimes(c|0\rangle+d|1\rangle)
= ac|00\rangle + ad|01\rangle + bc|10\rangle + bd|11\rangle$$
for some $a,b,c,d \in \mathbb{C}$. Matching coefficients against
$|\Phi^+\rangle = \frac{1}{\sqrt2}|00\rangle + 0|01\rangle + 0|10\rangle +
\frac{1}{\sqrt2}|11\rangle$ forces the simultaneous conditions:

$$ac = \tfrac{1}{\sqrt2} \ne 0, \qquad ad = 0, \qquad bc = 0, \qquad bd =
\tfrac{1}{\sqrt2} \ne 0.$$

From $ac \ne 0$: both $a \ne 0$ and $c \ne 0$. From $bd \ne 0$: both $b \ne
0$ and $d \ne 0$.

Now look at $ad = 0$: since $a \ne 0$, this forces $d = 0$. But we just
established $d \ne 0$ from $bd \ne 0$ — a direct contradiction ($d$ cannot
be both zero and nonzero). (Equivalently, $bc=0$ with $c\ne 0$ forces $b=0$,
contradicting $b\ne 0$ from $bd\ne0$ — either equation alone suffices.)

No $a,b,c,d$ satisfy all four equations simultaneously, so no such
factorization exists. Hence $|\Phi^+\rangle$ is not separable — it is
entangled. $\blacksquare$

### 2. Reduced density matrix of $|\Phi^+\rangle$

The density matrix of the pure joint state is
$$\rho = |\Phi^+\rangle\langle\Phi^+| = \tfrac12\big(|00\rangle+|11\rangle\big)\big(\langle00|+\langle11|\big)
= \tfrac12\Big(|00\rangle\langle00| + |00\rangle\langle11| + |11\rangle\langle00| + |11\rangle\langle11|\Big).$$

Write each term in tensor form, e.g. $|00\rangle\langle00| = |0\rangle\langle0|
\otimes |0\rangle\langle0|$, and $|00\rangle\langle11| = |0\rangle\langle1|
\otimes |0\rangle\langle1|$, etc.

The reduced density matrix of qubit 1 is the **partial trace over qubit 2**,
$\rho_1 = \mathrm{Tr}_2(\rho)$, which acts on a product term as
$\mathrm{Tr}_2(A\otimes B) = A \cdot \mathrm{Tr}(B)$. Applying this
term-by-term:

- $\mathrm{Tr}_2(|0\rangle\langle0|\otimes|0\rangle\langle0|) = |0\rangle\langle0| \cdot \mathrm{Tr}(|0\rangle\langle0|) = |0\rangle\langle0| \cdot 1 = |0\rangle\langle0|$
- $\mathrm{Tr}_2(|0\rangle\langle1|\otimes|0\rangle\langle1|) = |0\rangle\langle1| \cdot \mathrm{Tr}(|0\rangle\langle1|) = |0\rangle\langle1| \cdot \langle1|0\rangle = |0\rangle\langle1| \cdot 0 = 0$
- $\mathrm{Tr}_2(|1\rangle\langle0|\otimes|1\rangle\langle0|) = |1\rangle\langle0| \cdot \langle0|1\rangle = 0$
- $\mathrm{Tr}_2(|1\rangle\langle1|\otimes|1\rangle\langle1|) = |1\rangle\langle1| \cdot 1 = |1\rangle\langle1|$

So
$$\rho_1 = \tfrac12\big(|0\rangle\langle0| + 0 + 0 + |1\rangle\langle1|\big)
= \tfrac12\big(|0\rangle\langle0|+|1\rangle\langle1|\big) = \tfrac12 I.$$

**Why this indicates entanglement.** $\rho_1 = I/2$ has eigenvalues
$\tfrac12,\tfrac12$: it is *maximally mixed*, the density matrix of a
completely random classical bit, with zero information about any definite
pure state on qubit 1 alone. Contrast this with a genuinely separable pure
state $|a\rangle\otimes|b\rangle$: there,
$\mathrm{Tr}_2\big((|a\rangle\langle a|)\otimes(|b\rangle\langle b|)\big) =
|a\rangle\langle a| \cdot \mathrm{Tr}(|b\rangle\langle b|) = |a\rangle\langle
a| \cdot 1 = |a\rangle\langle a|$, which is rank 1 (pure) — separable pure
states always have pure marginals.

The global state $|\Phi^+\rangle$ is pure ($\rho$ has rank 1, one eigenvalue
$1$ and the rest $0$ — this is the pure-state signature proved on Day 6),
so it carries the maximum possible information a two-qubit state can carry.
Yet its qubit-1 marginal carries *none* — every bit of information about
$|\Phi^+\rangle$ is stored in the correlation between the two qubits, not
recoverable from either qubit examined in isolation. A mixed reduced
density matrix arising from a pure joint state is therefore an algebraic
*witness* of entanglement: it can only happen when the joint state fails to
factor as a product, exactly as proved in Question 1.

### 3. No-cloning theorem

**Claim:** there is no unitary $U$ (on two qubits) such that
$$U\big(|\psi\rangle\otimes|0\rangle\big) = |\psi\rangle\otimes|\psi\rangle
\qquad\text{for every single-qubit state } |\psi\rangle. \tag{$\ast$}$$

**Proof.** Suppose, for contradiction, that such a $U$ exists. Apply
$(\ast)$ to the two basis states $|0\rangle$ and $|1\rangle$:

$$U(|0\rangle\otimes|0\rangle) = |0\rangle\otimes|0\rangle = |00\rangle,
\qquad
U(|1\rangle\otimes|0\rangle) = |1\rangle\otimes|1\rangle = |11\rangle.$$

Now consider $|+\rangle = \frac{1}{\sqrt2}(|0\rangle+|1\rangle)$, itself a
valid single-qubit state, so $(\ast)$ must also hold for it directly:

$$U\big(|+\rangle\otimes|0\rangle\big) = |+\rangle\otimes|+\rangle
= \tfrac12\big(|00\rangle+|01\rangle+|10\rangle+|11\rangle\big). \tag{A}$$

But $U(|+\rangle\otimes|0\rangle)$ can *also* be computed a second way, using
only the fact that $U$ is **linear** (every unitary is linear) and the two
values of $U$ already fixed above:

$$|+\rangle\otimes|0\rangle = \tfrac{1}{\sqrt2}\big(|0\rangle+|1\rangle\big)\otimes|0\rangle
= \tfrac{1}{\sqrt2}\big(|0\rangle\otimes|0\rangle + |1\rangle\otimes|0\rangle\big),$$

so

$$U\big(|+\rangle\otimes|0\rangle\big)
= \tfrac{1}{\sqrt2}\Big[U(|0\rangle\otimes|0\rangle) + U(|1\rangle\otimes|0\rangle)\Big]
= \tfrac{1}{\sqrt2}\big(|00\rangle + |11\rangle\big). \tag{B}$$

Compare (A) and (B) coefficient-by-coefficient in the basis
$\{|00\rangle,|01\rangle,|10\rangle,|11\rangle\}$:

$$\text{(A)}: \left(\tfrac12,\ \tfrac12,\ \tfrac12,\ \tfrac12\right)
\qquad\text{vs.}\qquad
\text{(B)}: \left(\tfrac{1}{\sqrt2},\ 0,\ 0,\ \tfrac{1}{\sqrt2}\right).$$

These are numerically different vectors: $\tfrac12 \ne \tfrac{1}{\sqrt2}$
(the first is $0.5$, the second $\approx 0.707$), and beyond the magnitude
mismatch, (A) has nonzero weight $\tfrac12$ on $|01\rangle$ and $|10\rangle$
while (B) has exactly $0$ weight there. (Equivalently: (B) is
$|\Phi^+\rangle$, which Question 1 proved is entangled, while (A) is the
manifestly separable product $|+\rangle\otimes|+\rangle$ — an entangled
state and a separable state can never be equal as vectors.)

But $U(|+\rangle\otimes|0\rangle)$ is a single, well-defined vector — it is
$U$ applied once to one fixed input. It cannot simultaneously equal (A) and
(B), since $\text{(A)} \ne \text{(B)}$. This is a contradiction.

Therefore no unitary $U$ satisfying $(\ast)$ for *every* $|\psi\rangle$ can
exist: **no universal quantum cloning machine is possible.** $\blacksquare$

(The proof used only two input states, $|0\rangle$ and $|1\rangle$, to pin
down $U$'s action on them via $(\ast)$, and then exploited that $(\ast)$ is
required to hold *also* for the superposition $|+\rangle$ — the clash
between "linearity applied to a superposition of already-fixed cases" and
"the cloning postulate applied directly to that same superposition" is the
entire content of the theorem.)

### 4. Deutsch–Jozsa: circuit and general-$n$ amplitude formula

**Problem.** $f:\{0,1\}^n\to\{0,1\}$ is promised to be either *constant*
($f(x)$ the same value for all $x$) or *balanced* (exactly half of the
$2^n$ inputs give $f(x)=1$). Determine which, using the oracle
$U_f|x\rangle|y\rangle = |x\rangle|y\oplus f(x)\rangle$ as few times as
possible.

**Circuit.**

1. Prepare the input register in $|0\rangle^{\otimes n}$ and a single
   output/ancilla qubit in $|1\rangle$.
2. Apply $H^{\otimes n}$ to the input register and $H$ to the ancilla. The
   ancilla becomes $H|1\rangle = |-\rangle = \frac{1}{\sqrt2}(|0\rangle -
   |1\rangle)$, and the input register becomes $\frac{1}{\sqrt{2^n}}\sum_x
   |x\rangle$. Joint state:
   $$\frac{1}{\sqrt{2^n}}\sum_{x\in\{0,1\}^n} |x\rangle \otimes |-\rangle.$$
3. Apply $U_f$. **Phase-kickback identity:** for any $x$,
   $$U_f|x\rangle|-\rangle = U_f|x\rangle\tfrac{1}{\sqrt2}(|0\rangle-|1\rangle)
   = \tfrac{1}{\sqrt2}\big(|x\rangle|f(x)\rangle - |x\rangle|1\oplus f(x)\rangle\big).$$
   If $f(x)=0$: this is $\tfrac{1}{\sqrt2}(|x\rangle|0\rangle -
   |x\rangle|1\rangle) = |x\rangle|-\rangle = (-1)^0|x\rangle|-\rangle$. If
   $f(x)=1$: this is $\tfrac{1}{\sqrt2}(|x\rangle|1\rangle -
   |x\rangle|0\rangle) = -|x\rangle|-\rangle = (-1)^1|x\rangle|-\rangle$.
   Either way, $U_f|x\rangle|-\rangle = (-1)^{f(x)}|x\rangle|-\rangle$: the
   oracle leaves the ancilla in $|-\rangle$ untouched and "kicks back" a
   phase onto the input register instead. Applying this to every branch of
   the superposition:
   $$\frac{1}{\sqrt{2^n}}\sum_x (-1)^{f(x)}|x\rangle \otimes |-\rangle.$$
4. Apply $H^{\otimes n}$ to the input register again (the ancilla now
   factors out and is discarded). First, derive the needed identity from
   scratch: for a single qubit, $H|0\rangle = \frac{1}{\sqrt2}(|0\rangle +
   |1\rangle)$ and $H|1\rangle = \frac{1}{\sqrt2}(|0\rangle - |1\rangle)$
   can both be written as $H|x_i\rangle = \frac{1}{\sqrt2}\sum_{y_i\in\{0,1\}}
   (-1)^{x_i y_i}|y_i\rangle$ (check $x_i=0$: both signs are $+1$, giving
   $|0\rangle+|1\rangle$; check $x_i=1$: signs are $+1,-1$, giving
   $|0\rangle-|1\rangle$). Tensoring over the $n$ qubits of $x = x_1\cdots
   x_n$:
   $$H^{\otimes n}|x\rangle = \bigotimes_{i=1}^n \frac{1}{\sqrt2}\sum_{y_i}(-1)^{x_iy_i}|y_i\rangle
   = \frac{1}{\sqrt{2^n}}\sum_{y\in\{0,1\}^n} (-1)^{\sum_i x_iy_i}|y\rangle
   = \frac{1}{\sqrt{2^n}}\sum_y (-1)^{x\cdot y}|y\rangle,$$
   where $x\cdot y = \sum_i x_iy_i \bmod 2$. Now apply this to the
   post-oracle state:
   $$H^{\otimes n}\left[\frac{1}{\sqrt{2^n}}\sum_x (-1)^{f(x)}|x\rangle\right]
   = \frac{1}{\sqrt{2^n}}\sum_x (-1)^{f(x)} \cdot \frac{1}{\sqrt{2^n}}\sum_y (-1)^{x\cdot y}|y\rangle
   = \frac{1}{2^n}\sum_y \left[\sum_x (-1)^{f(x)+x\cdot y}\right]|y\rangle.$$
5. Measure the input register in the standard basis.

**General-$n$ amplitude formula.** Read off the coefficient of $y=0^n$ (the
all-zero string) in the sum above: since $x\cdot 0^n = 0$ for every $x$,
$$\text{amplitude on } |0\rangle^{\otimes n} = \frac{1}{2^n}\sum_{x} (-1)^{f(x)}.$$

**Constant case.** If $f(x)=0$ for all $x$: $\sum_x(-1)^{f(x)} =
\sum_x(-1)^0 = 2^n\cdot 1 = 2^n$, so the amplitude is $\frac{2^n}{2^n}=1$. If
$f(x)=1$ for all $x$: $\sum_x(-1)^1 = 2^n\cdot(-1) = -2^n$, so the amplitude
is $-1$. Either way the amplitude has modulus $1$, so the probability of
measuring $0^n$ is $|{\pm1}|^2 = 1$ — measuring the input register yields
$0^n$ **with certainty**.

**Balanced case.** Exactly $2^{n-1}$ inputs have $f(x)=0$ (contributing
$+1$ each) and $2^{n-1}$ have $f(x)=1$ (contributing $-1$ each), so
$$\sum_x (-1)^{f(x)} = 2^{n-1}(+1) + 2^{n-1}(-1) = 0,$$
giving amplitude $0$ on $|0\rangle^{\otimes n}$: the probability of
measuring $0^n$ is exactly $0$ — it **never** occurs.

**Conclusion.** After the circuit above, measuring the input register gives
$0^n$ with probability $1$ if $f$ is constant, and with probability $0$ if
$f$ is balanced. A single measurement outcome — $0^n$ or anything else —
therefore determines, with **zero error and exactly one oracle query**,
which case holds. (Sanity check at $n=1$: constant $f\equiv0$ gives
amplitude $\frac{1}{2}\big((-1)^0+(-1)^0\big)=1$ on $|0\rangle$; balanced
$f(x)=x$ gives $\frac{1}{2}\big((-1)^0+(-1)^1\big)=0$ — consistent with the
general formula.)

## Journal template

```
## Day 9 — Review: Days 6–8 (closed-book)
Key idea in my own words: ...
What confused me: ...
Which items needed correction, and why: ...
```
