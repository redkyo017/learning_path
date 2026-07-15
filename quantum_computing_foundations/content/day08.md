# Day 8 — Quantum Parallelism & the Deutsch–Jozsa Algorithm

## Learning objectives

By the end of today you should be able to:
- State precisely what "quantum parallelism" does and does not give you, and
  correct the common misconception that it means reading out $f(x)$ for
  every $x$ simultaneously.
- Prove the phase-kickback identity $U_f|x\rangle|-\rangle =
  (-1)^{f(x)}|x\rangle|-\rangle$ from the oracle's defining action.
- Trace the full Deutsch–Jozsa circuit state-by-state for $n=1$, for both a
  constant and a balanced $f$.
- Derive, from scratch, the general-$n$ amplitude formula
  $\frac{1}{2^n}\sum_x(-1)^{f(x)}$ on $|0\rangle^{\otimes n}$, and show it is
  $\pm1$ for constant $f$ and exactly $0$ for balanced $f$.
- Compare Deutsch–Jozsa's one-query, zero-error guarantee against Day 2's
  randomized classical algorithm for the identical promise problem.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*,
  or Ronald de Wolf, *Quantum Computing: Lecture Notes*, the sections
  covering quantum query algorithms and the Deutsch–Jozsa algorithm.
- The theory below is self-contained — you do not need either text to do
  today's work, but reading the matching section alongside this is useful
  for a second explanation in different words.
- This day depends on Day 7's tensor-product formalism and no-cloning
  theorem, Day 6's measurement postulate, and Day 2's randomized classical
  algorithm for the same promise problem (kept there specifically for
  today's comparison).

## Theory

### The promise problem

Fix $n\ge1$ and a black-box (oracle) function $f:\{0,1\}^n\to\{0,1\}$,
promised to be one of exactly two kinds:

- **Constant:** $f(x)=0$ for every $x$, or $f(x)=1$ for every $x$.
- **Balanced:** $f(x)=1$ for exactly half of all $2^n$ inputs $x$ (and
  $f(x)=0$ for the other half).

The task is to decide which case holds, using as few queries to $f$ as
possible. (No other case is possible under the promise — a classical
algorithm that queried enough points to rule out both being consistent with
non-constant, non-balanced behavior could reject the promise, but here we
take the promise as given, exactly as Day 2 did.)

### The oracle and phase kickback

The oracle is realized as a unitary $U_f$ acting on an $n$-qubit "input"
register and a $1$-qubit "output" register:
$$U_f|x\rangle|y\rangle = |x\rangle|y\oplus f(x)\rangle,$$
for every $x\in\{0,1\}^n$ and $y\in\{0,1\}$. This is reversible (it is its
own inverse, by the same $\oplus$-cancellation argument as Day 1's Toffoli
gate: applying it twice XORs $f(x)$ into $y$ twice, and $f(x)\oplus f(x)=0$),
hence unitary, and it is the quantum generalization of "compute $f$" that
does not erase the input — exactly the reversible-computing discipline Day
1 established, now over a quantum register.

Define $|-\rangle = \frac{1}{\sqrt2}(|0\rangle - |1\rangle)$. This is the
key auxiliary state for today's whole construction.

**Claim (phase kickback):** $U_f|x\rangle|-\rangle =
(-1)^{f(x)}|x\rangle|-\rangle$ for every $x$.

**Proof.** Expand $|-\rangle$ and use linearity of $U_f$:
$$U_f|x\rangle|-\rangle = U_f\Big(|x\rangle\otimes
\tfrac{1}{\sqrt2}(|0\rangle-|1\rangle)\Big) =
\tfrac{1}{\sqrt2}\Big(U_f|x\rangle|0\rangle - U_f|x\rangle|1\rangle\Big).$$
Apply the oracle's defining action to each term:
$$U_f|x\rangle|0\rangle = |x\rangle|0\oplus f(x)\rangle = |x\rangle|f(x)\rangle,
\qquad
U_f|x\rangle|1\rangle = |x\rangle|1\oplus f(x)\rangle = |x\rangle|1\oplus
f(x)\rangle.$$
So
$$U_f|x\rangle|-\rangle = |x\rangle \otimes \tfrac{1}{\sqrt2}\Big(|f(x)\rangle
- |1\oplus f(x)\rangle\Big).$$
Now case on the value of $f(x)$:

- If $f(x)=0$: the bracket is $\frac{1}{\sqrt2}(|0\rangle - |1\rangle) =
  |-\rangle$. So $U_f|x\rangle|-\rangle = |x\rangle|-\rangle =
  (-1)^0|x\rangle|-\rangle$.
- If $f(x)=1$: the bracket is $\frac{1}{\sqrt2}(|1\rangle - |0\rangle) =
  -\frac{1}{\sqrt2}(|0\rangle-|1\rangle) = -|-\rangle$. So
  $U_f|x\rangle|-\rangle = -|x\rangle|-\rangle = (-1)^1|x\rangle|-\rangle$.

Both cases match $(-1)^{f(x)}|x\rangle|-\rangle$, so the identity holds for
every $x$. $\blacksquare$

The name "phase kickback" refers to exactly this: the oracle, which was
*defined* to XOR $f(x)$ into a target qubit, instead leaves the target qubit
completely unchanged (still $|-\rangle$) and "kicks back" the information
about $f(x)$ as a global phase $(-1)^{f(x)}$ multiplying the *input*
register. This is the single mechanical trick underlying Deutsch–Jozsa,
Bernstein–Vazirani, and Simon's algorithm (Day 10).

### The Hadamard-transform identity

The circuit applies $H^{\otimes n}$ (Hadamard on every input-register qubit,
independently) both before and after the oracle call. We need its action on
a computational basis state $|x\rangle$, $x = x_1x_2\cdots x_n \in\{0,1\}^n$.

**Claim:** $H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_{y\in\{0,1\}^n}
(-1)^{x\cdot y}|y\rangle$, where $x\cdot y = \sum_{i=1}^n x_iy_i \bmod 2$.

**Proof.** $H^{\otimes n}|x\rangle = H|x_1\rangle\otimes\cdots\otimes
H|x_n\rangle$, and for a single bit $x_i$, $H|x_i\rangle =
\frac{1}{\sqrt2}\big(|0\rangle + (-1)^{x_i}|1\rangle\big) =
\frac{1}{\sqrt2}\sum_{y_i\in\{0,1\}}(-1)^{x_iy_i}|y_i\rangle$ (check both
cases: $x_i=0$ gives $|0\rangle+|1\rangle$; $x_i=1$ gives $|0\rangle -
|1\rangle$ — both match $H$'s matrix directly). Tensoring these $n$
one-qubit sums together and multiplying out:
$$H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_{y_1,\dots,y_n\in\{0,1\}}
(-1)^{x_1y_1}(-1)^{x_2y_2}\cdots(-1)^{x_ny_n}|y_1y_2\cdots y_n\rangle =
\frac{1}{\sqrt{2^n}}\sum_{y\in\{0,1\}^n}(-1)^{x\cdot y}|y\rangle,$$
using $(-1)^{x_1y_1}\cdots(-1)^{x_ny_n} = (-1)^{\sum_i x_iy_i} =
(-1)^{x\cdot y}$. $\blacksquare$

The special case $x=0^n$ gives $H^{\otimes n}|0\rangle^{\otimes n} =
\frac{1}{\sqrt{2^n}}\sum_y|y\rangle$ — the uniform superposition over all
$2^n$ inputs, which is how the circuit begins.

### The Deutsch–Jozsa circuit, general $n$

The circuit, on an $n$-qubit input register initialized to
$|0\rangle^{\otimes n}$ and a $1$-qubit output register initialized to
$|1\rangle$:

1. Apply $H^{\otimes n}$ to the input register and $H$ to the output
   register.
2. Apply the oracle $U_f$ (input register controls, output register is the
   target).
3. Apply $H^{\otimes n}$ to the input register again.
4. Measure the input register in the standard basis.

**Stage 1.** Starting state $|0\rangle^{\otimes n}|1\rangle$. Applying the
Hadamard identity above (with $x=0^n$) to the input register, and directly
computing $H|1\rangle = |-\rangle$ for the output register:
$$|0\rangle^{\otimes n}|1\rangle \ \longrightarrow\
\frac{1}{\sqrt{2^n}}\sum_{x\in\{0,1\}^n}|x\rangle \otimes |-\rangle.$$

**Stage 2.** Apply $U_f$. By linearity, apply the phase-kickback identity to
each term of the sum independently:
$$\frac{1}{\sqrt{2^n}}\sum_x|x\rangle|-\rangle \ \longrightarrow\
\frac{1}{\sqrt{2^n}}\sum_x (-1)^{f(x)}|x\rangle \otimes |-\rangle.$$
The output register is completely unentangled from the input register at
this point and stays $|-\rangle$ throughout the rest of the circuit — every
bit of information about $f$ that survives is now encoded as a *phase* on
each input-register branch, not in the output register's state.

**Stage 3.** Apply $H^{\otimes n}$ to the input register. Using the
Hadamard-transform identity term by term:
$$\frac{1}{\sqrt{2^n}}\sum_x(-1)^{f(x)}|x\rangle \ \longrightarrow\
\frac{1}{\sqrt{2^n}}\sum_x(-1)^{f(x)}\left(\frac{1}{\sqrt{2^n}}\sum_y(-1)^{x\cdot
y}|y\rangle\right) = \frac{1}{2^n}\sum_y\left(\sum_x
(-1)^{f(x)+x\cdot y}\right)|y\rangle.$$
So the full post-circuit state of the input register (tensored with the
untouched $|-\rangle$ on the output register) is
$$\frac{1}{2^n}\sum_{y\in\{0,1\}^n}\left(\sum_{x\in\{0,1\}^n}
(-1)^{f(x)+x\cdot y}\right)|y\rangle \otimes |-\rangle.$$

**The amplitude on $|0\rangle^{\otimes n}$.** Set $y=0^n$. Then $x\cdot y =
0$ for every $x$, so the amplitude on $|0\rangle^{\otimes n}$ is exactly
$$\boxed{\ a_0 = \frac{1}{2^n}\sum_{x\in\{0,1\}^n}(-1)^{f(x)}\ }.$$
This is precisely the formula the plan calls for, and the derivation above
is the complete proof, not an assertion: it follows in three mechanical
steps (Hadamard, phase kickback, Hadamard) from the two identities proved
above.

**Constant case.** If $f\equiv0$, every term of the sum is $(-1)^0=1$, so
$a_0 = \frac{1}{2^n}\cdot 2^n = 1$. If $f\equiv1$, every term is
$(-1)^1=-1$, so $a_0 = \frac{1}{2^n}\cdot(-2^n) = -1$. Either way,
$|a_0|=1$ exactly — since $|0\rangle^{\otimes n}$'s amplitude has modulus
$1$ and the whole state is normalized, *every other basis state's amplitude
must be exactly $0$*. Measuring gives $y=0^n$ with probability
$|a_0|^2=1$: certainty.

**Balanced case.** Exactly $2^{n-1}$ of the $2^n$ values of $x$ have
$f(x)=0$ (contributing $+1$ to the sum) and exactly $2^{n-1}$ have
$f(x)=1$ (contributing $-1$), by the definition of balanced. So
$$\sum_x(-1)^{f(x)} = 2^{n-1}(+1) + 2^{n-1}(-1) = 0 \quad\Longrightarrow\quad
a_0 = 0.$$
Measuring gives $y=0^n$ with probability $|a_0|^2=0$: it is *impossible* to
observe the all-zeros outcome when $f$ is balanced.

**Conclusion.** A single oracle query, followed by the Hadamard–oracle–
Hadamard circuit and one measurement, distinguishes the two cases with
*certainty*: observe $y=0^n$ $\Rightarrow$ $f$ is constant; observe any
$y\ne0^n$ $\Rightarrow$ $f$ is balanced (this outcome must occur with
probability $1$ in the balanced case, since $y=0^n$ has probability $0$ and
the outcomes are exhaustive).

### Comparison with the classical randomized algorithm (Day 2)

Day 2, Step 4, Problem 5 gave the best classical strategy for this exact
promise problem: query $f$ at $m$ independently random points. If every
query returns $0$, the algorithm guesses "constant." Since a balanced $f$
has exactly half its inputs mapping to $0$, the chance that $m$ independent
random queries into a balanced $f$ all happen to land on $0$-inputs is
$(1/2)^m = 2^{-m}$ — so seeing $m$ zeros in a row gives confidence
$1-2^{-m}$ that $f$ is really constant, never certainty for any finite $m$.
To reach the same confidence used in Day 2 Step 3 ($2^{-20}$), the classical
algorithm needs $m=20$ queries, and even then there remains a genuine
(if tiny) $2^{-20}$ chance of being wrong.

Deutsch–Jozsa needs exactly **one** oracle query and produces the
**exact** answer with probability $1$, not merely high confidence. This is
the point of keeping Day 2's result on hand: the contrast is not "quantum
is faster at the same task" in some vague sense, but a precise, provable
gap in query count *and* a qualitative gap in error model — bounded-error
randomized ($1-2^{-k}$ for $k$ queries) versus exact/zero-error quantum ($1$
query, error $0$) for the identical promise problem.

## Common misconceptions

**The claim to correct:** "Quantum parallelism" means the circuit computes
$f(x)$ for *every* $x\in\{0,1\}^n$ *simultaneously*, and you can therefore
read off all $2^n$ values of $f$ at once from a single run.

**Why this is wrong, precisely.** After Stage 1–2 above, the joint state is
$\frac{1}{\sqrt{2^n}}\sum_x(-1)^{f(x)}|x\rangle\otimes|-\rangle$ (or, before
the phase-kickback trick, the more intuitive $\frac{1}{\sqrt{2^n}}\sum_x
|x\rangle|f(x)\rangle$). It is true that every term of this sum "contains"
$f$ evaluated at a different $x$ — in that narrow sense, $f$ has been
evaluated everywhere at once, and this much of "quantum parallelism" is
real. But you cannot get all $2^n$ values *out*:

- **The measurement postulate (Day 6)** says that measuring the input
  register in the standard basis collapses this superposition to exactly
  *one* term $|x\rangle$ (equivalently, one $(x,f(x))$ pair), chosen
  randomly with probability $|{\rm amplitude}|^2 = 1/2^n$ for each $x$ (in
  the un-kicked-back form), and irreversibly destroys the amplitude on
  every other branch. One run, one $(x,f(x))$ pair — no more information
  than a single classical query would have given you.
- **The no-cloning theorem (Day 7)** blocks the obvious workaround of
  copying the superposition into $2^n$ separate registers first and
  measuring each copy independently to recover all the values: there is no
  unitary that clones an arbitrary/unknown quantum state, so you cannot
  manufacture extra "look but don't disturb" copies of
  $\sum_x|x\rangle|f(x)\rangle$ to extract more than one measurement's worth
  of information from a single oracle call. The superposition genuinely
  holds all the information, but it is *locked* behind the fact that
  extracting any of it destroys the rest, and you cannot duplicate your way
  around that lock.

**Where the actual power comes from.** It is not the superposition by
itself, and not the measurement by itself — it is **interference** among
the branches, produced by a *further unitary* (here, the second layer of
$H^{\otimes n}$) applied *before* the measurement. The derivation above
shows exactly this mechanism: the second Hadamard layer recombines the
$2^n$ phased branches $(-1)^{f(x)}|x\rangle$ into new amplitudes
$\frac{1}{2^n}\sum_x(-1)^{f(x)+x\cdot y}$ on each output state $|y\rangle$.
For $y=0^n$ specifically, this recombination causes either **perfect
constructive interference** (all $2^n$ terms add with the same sign, when
$f$ is constant, giving amplitude $\pm1$) or **perfect destructive
interference** (the terms cancel in exact pairs, when $f$ is balanced,
giving amplitude $0$). No single branch $|x\rangle$ "knows" whether $f$ is
constant or balanced — that is a *global* property of $f$ across all $2^n$
inputs — and no single measurement of the pre-interference superposition
could reveal a global property like that either. It is only visible in how
the branches interfere with each other once combined by $H^{\otimes n}$,
right before the one measurement the algorithm is allowed.

**Corrected one-sentence statement:** quantum parallelism lets a single
circuit evaluate $f$ across a superposition of all $2^n$ inputs, but the
measurement postulate permits only one $(x,f(x))$ outcome per run and the
no-cloning theorem forecloses copying your way around that limit — so the
only way to extract a computational advantage is to apply further unitaries
that cause the branches to interfere *before* that one measurement,
exactly as the second Hadamard layer does above. This is one of the most
consequential points in the entire course: essentially every quantum
algorithm's "speedup" is an interference effect engineered before
measurement, not a parallel readout.

## Worked example

**Full state-by-state trace of the Deutsch–Jozsa circuit for $n=1$,** for
the constant function $f\equiv0$ and the balanced function $f(x)=x$.

Registers: one input qubit $|x\rangle$, one output qubit $|y\rangle$,
initialized to $|0\rangle|1\rangle$.

**Stage 0 (initialization).** State: $|0\rangle|1\rangle$.

**Stage 1 (Hadamards).** $H|0\rangle = |+\rangle =
\frac{1}{\sqrt2}(|0\rangle+|1\rangle)$ and $H|1\rangle = |-\rangle =
\frac{1}{\sqrt2}(|0\rangle-|1\rangle)$. State:
$$|+\rangle|-\rangle = \tfrac{1}{\sqrt2}\big(|0\rangle+|1\rangle\big)\otimes
|-\rangle = \tfrac{1}{\sqrt2}\big(|0\rangle|-\rangle + |1\rangle|-\rangle\big).$$
This state is identical for both cases of $f$ — the oracle has not been
called yet.

**Case A: $f\equiv0$ (constant), $f(0)=0,\ f(1)=0$.**

*Stage 2 (oracle).* Apply phase kickback to each term: $U_f|0\rangle|-\rangle
= (-1)^{f(0)}|0\rangle|-\rangle = |0\rangle|-\rangle$, and
$U_f|1\rangle|-\rangle = (-1)^{f(1)}|1\rangle|-\rangle = |1\rangle|-\rangle$.
State:
$$\tfrac{1}{\sqrt2}\big(|0\rangle|-\rangle + |1\rangle|-\rangle\big) =
|+\rangle|-\rangle.$$
(Unchanged — both terms picked up phase $(-1)^0=+1$.)

*Stage 3 (second Hadamard on input register).* $H|+\rangle = |0\rangle$
(Hadamard is its own inverse: $H(H|0\rangle)=|0\rangle$, so $H|+\rangle =
H(H|0\rangle) = |0\rangle$). State:
$$|0\rangle \otimes |-\rangle.$$

*Stage 4 (measurement).* The input qubit is in the pure state $|0\rangle$:
measuring gives outcome $0$ with probability $|\langle0|0\rangle|^2=1$ —
certainty. Matches the general formula: $a_0 = \frac{1}{2}\big((-1)^{f(0)}
+ (-1)^{f(1)}\big) = \frac{1}{2}(1+1) = 1$, and indeed the input register
collapsed to exactly $a_0 = 1$ on $|0\rangle$.

**Case B: $f(x)=x$ (balanced), $f(0)=0,\ f(1)=1$.**

*Stage 2 (oracle).* $U_f|0\rangle|-\rangle = (-1)^{f(0)}|0\rangle|-\rangle =
|0\rangle|-\rangle$, and $U_f|1\rangle|-\rangle = (-1)^{f(1)}|1\rangle|-\rangle
= -|1\rangle|-\rangle$. State:
$$\tfrac{1}{\sqrt2}\big(|0\rangle|-\rangle - |1\rangle|-\rangle\big) =
\tfrac{1}{\sqrt2}\big(|0\rangle-|1\rangle\big)\otimes|-\rangle = |-\rangle
\otimes |-\rangle.$$

*Stage 3 (second Hadamard on input register).* $H|-\rangle = |1\rangle$.
(Direct check: $H|-\rangle = \frac{1}{\sqrt2}(H|0\rangle - H|1\rangle) =
\frac{1}{\sqrt2}(|+\rangle-|-\rangle) = \frac{1}{\sqrt2}
\Big(\tfrac{|0\rangle+|1\rangle}{\sqrt2} - \tfrac{|0\rangle-|1\rangle}{\sqrt2}
\Big) = \frac{1}{2}\big(2|1\rangle\big) = |1\rangle$.) State:
$$|1\rangle \otimes |-\rangle.$$

*Stage 4 (measurement).* The input qubit is in the pure state $|1\rangle$:
measuring gives outcome $1$ with probability $1$ — certainty. Matches the
general formula: $a_0 = \frac{1}{2}\big((-1)^{f(0)}+(-1)^{f(1)}\big) =
\frac{1}{2}(1-1) = 0$, so all the amplitude is on $|1\rangle$, i.e. the
amplitude on $|1\rangle$ has modulus $1$ — exactly what the circuit
produced.

**Summary of the $n=1$ trace:** the constant case ends deterministically at
$|0\rangle$, the balanced case ends deterministically at $|1\rangle$; one
oracle call and one measurement settle the question with zero error, for
either case, exactly as the general-$n$ derivation in the Theory section
predicts with $a_0=\pm1$ (constant) versus $a_0=0$ (balanced).

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Redo the phase-kickback proof from scratch, without looking at the
   Theory section: show $U_f|x\rangle|-\rangle = (-1)^{f(x)}|x\rangle
   |-\rangle$ directly from $U_f|x\rangle|y\rangle = |x\rangle|y\oplus
   f(x)\rangle$.
2. Verify the Hadamard-transform identity $H^{\otimes n}|x\rangle =
   \frac{1}{\sqrt{2^n}}\sum_y(-1)^{x\cdot y}|y\rangle$ directly for $n=2$,
   $x=10$: write out $H\otimes H$ applied to $|1\rangle\otimes|0\rangle$ by
   brute-force tensor/matrix multiplication, and confirm it matches
   $\frac{1}{2}\sum_{y\in\{00,01,10,11\}}(-1)^{10\cdot y}|y\rangle$.
3. Trace the full $n=1$ Deutsch–Jozsa circuit (as in the Worked example) for
   the other two $n=1$ functions not covered there: the constant function
   $f\equiv1$, and the balanced function $f(x) = 1\oplus x$ (i.e. NOT).
   Write the exact state at every stage and confirm the final measurement
   still distinguishes constant from balanced with certainty.
4. Derive the general-$n$ amplitude formula $a_0 = \frac{1}{2^n}\sum_x
   (-1)^{f(x)}$ from scratch, without looking at the Theory section: start
   from $|0\rangle^{\otimes n}|1\rangle$ and carry the state through all
   three circuit stages symbolically.
5. Prove directly from the definition of "balanced" that $\sum_x(-1)^{f(x)}
   = 0$ whenever $f$ is balanced, and that $\sum_x(-1)^{f(x)} = \pm2^n$
   whenever $f$ is constant. (This is the counting argument the general
   derivation leans on — make it fully explicit.)
6. Take $n=2$ and the balanced function $f(00)=0, f(01)=1, f(10)=1,
   f(11)=0$ (i.e. XOR of the two input bits). Compute $a_0 =
   \frac{1}{4}\sum_x(-1)^{f(x)}$ directly by summing all four terms, and
   confirm $a_0=0$.
7. Suppose you only had a classical randomized algorithm's *confidence*
   guarantee, $1-2^{-k}$ after $k$ queries, and you wanted to reach
   confidence $1 - 2^{-50}$. How many classical queries $k$ are needed?
   Contrast this explicitly with how many quantum queries Deutsch–Jozsa
   needs for a *strictly stronger* guarantee (exact certainty) at any $n$.
8. Explain, in your own words and referencing the Common misconceptions
   section, exactly which step of the Deutsch–Jozsa circuit would need to
   be removed for the algorithm to degenerate into "no better than
   randomly reading out one $(x,f(x))$ pair" — i.e. identify precisely
   where the interference is doing the work.

## Solutions

**1.** $U_f|x\rangle|-\rangle = U_f|x\rangle\big(\tfrac{1}{\sqrt2}(|0\rangle
-|1\rangle)\big) = \tfrac{1}{\sqrt2}\big(U_f|x\rangle|0\rangle -
U_f|x\rangle|1\rangle\big) = \tfrac{1}{\sqrt2}\big(|x\rangle|f(x)\rangle -
|x\rangle|1\oplus f(x)\rangle\big) = |x\rangle\otimes\tfrac{1}{\sqrt2}
\big(|f(x)\rangle - |1\oplus f(x)\rangle\big)$. If $f(x)=0$: bracket is
$\tfrac{1}{\sqrt2}(|0\rangle-|1\rangle) = |-\rangle = (-1)^0|-\rangle$. If
$f(x)=1$: bracket is $\tfrac{1}{\sqrt2}(|1\rangle-|0\rangle) = -|-\rangle =
(-1)^1|-\rangle$. So $U_f|x\rangle|-\rangle = (-1)^{f(x)}|x\rangle|-\rangle$
in both cases.

**2.** $H\otimes H$ on $|1\rangle\otimes|0\rangle$: $H|1\rangle =
\tfrac{1}{\sqrt2}(|0\rangle-|1\rangle)$, $H|0\rangle =
\tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)$. Tensoring:
$$\tfrac{1}{2}(|0\rangle-|1\rangle)\otimes(|0\rangle+|1\rangle) =
\tfrac{1}{2}\big(|00\rangle+|01\rangle-|10\rangle-|11\rangle\big).$$
Now check the formula: $x=10$, so $x\cdot y = 1\cdot y_1 + 0\cdot y_2 \bmod2
= y_1$. So $(-1)^{x\cdot y}$ is $+1$ for $y=00,01$ (where $y_1=0$) and $-1$
for $y=10,11$ (where $y_1=1$), giving $\tfrac{1}{2}(|00\rangle+|01\rangle
-|10\rangle-|11\rangle)$ — identical to the direct computation.

**3.** *Constant $f\equiv1$:* Stage 1 state (same for all $f$):
$|+\rangle|-\rangle = \tfrac{1}{\sqrt2}(|0\rangle|-\rangle+|1\rangle
|-\rangle)$. Stage 2: $U_f|0\rangle|-\rangle=(-1)^1|0\rangle|-\rangle=
-|0\rangle|-\rangle$, $U_f|1\rangle|-\rangle=(-1)^1|1\rangle|-\rangle=
-|1\rangle|-\rangle$; state becomes $-\tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)
|-\rangle = -|+\rangle|-\rangle$. Stage 3: $H(-|+\rangle) = -|0\rangle$;
state $=-|0\rangle\otimes|-\rangle$. Stage 4: measuring gives outcome $0$
with probability $|-1|^2=1$ — certainty, global phase irrelevant to
measurement, matching $a_0 = \tfrac12((-1)^1+(-1)^1)=-1$.

*Balanced $f(x)=1\oplus x$:* Stage 2: $U_f|0\rangle|-\rangle =
(-1)^{f(0)}|0\rangle|-\rangle = (-1)^1|0\rangle|-\rangle=-|0\rangle|-\rangle$;
$U_f|1\rangle|-\rangle=(-1)^{f(1)}|1\rangle|-\rangle=(-1)^0|1\rangle|-\rangle=
|1\rangle|-\rangle$. State: $\tfrac{1}{\sqrt2}(-|0\rangle+|1\rangle)|-\rangle
= -\tfrac{1}{\sqrt2}(|0\rangle-|1\rangle)|-\rangle=-|-\rangle|-\rangle$.
Stage 3: $H(-|-\rangle)=-|1\rangle$; state $=-|1\rangle\otimes|-\rangle$.
Stage 4: outcome $1$ with probability $1$ — certainty, matching $a_0=
\tfrac12((-1)^1+(-1)^0)=0$, all amplitude on $|1\rangle$.

Both extra cases confirm the same rule: constant $\to$ outcome $0$;
balanced $\to$ outcome $1$; deterministically, up to an irrelevant global
phase.

**4.** Start: $|0\rangle^{\otimes n}|1\rangle$. Stage 1: $H^{\otimes n}
|0\rangle^{\otimes n} = \tfrac{1}{\sqrt{2^n}}\sum_x|x\rangle$ (Hadamard
identity with $x=0^n$, since $0\cdot y=0$ for all $y$), $H|1\rangle=
|-\rangle$; state $\tfrac{1}{\sqrt{2^n}}\sum_x|x\rangle|-\rangle$. Stage 2:
phase kickback on each term gives $\tfrac{1}{\sqrt{2^n}}\sum_x(-1)^{f(x)}
|x\rangle|-\rangle$. Stage 3: apply $H^{\otimes n}$ termwise using the
Hadamard identity, $\tfrac{1}{\sqrt{2^n}}\sum_x(-1)^{f(x)}
\big(\tfrac{1}{\sqrt{2^n}}\sum_y(-1)^{x\cdot y}|y\rangle\big) =
\tfrac{1}{2^n}\sum_y\big(\sum_x(-1)^{f(x)+x\cdot y}\big)|y\rangle$, tensored
with the unchanged $|-\rangle$. Reading off the $y=0^n$ coefficient (where
$x\cdot y=0$ for every $x$) gives $a_0 = \tfrac{1}{2^n}\sum_x(-1)^{f(x)}$.

**5.** *Balanced:* by definition exactly $2^{n-1}$ inputs have $f(x)=0$
(each contributing $(-1)^0=1$) and exactly $2^{n-1}$ have $f(x)=1$ (each
contributing $(-1)^1=-1$). Sum $= 2^{n-1}(1) + 2^{n-1}(-1) = 0$. *Constant:*
if $f\equiv0$, all $2^n$ terms are $+1$, sum $=2^n$; if $f\equiv1$, all
$2^n$ terms are $-1$, sum $=-2^n$. So the sum is $\pm2^n$ in the constant
case, exactly matching the two sub-cases.

**6.** $f(00)=0\Rightarrow(-1)^0=1$; $f(01)=1\Rightarrow(-1)^1=-1$;
$f(10)=1\Rightarrow(-1)^1=-1$; $f(11)=0\Rightarrow(-1)^0=1$. Sum $=
1-1-1+1=0$. $a_0 = \tfrac14(0) = 0$, confirming balanced $\Rightarrow$
$a_0=0$.

**7.** Need $1-2^{-k} \ge 1-2^{-50}$, i.e. $k\ge50$: $50$ classical
randomized queries are needed for confidence $1-2^{-50}$, and even then
there is a genuine (if astronomically small) $2^{-50}$ chance of error, for
*any* $n$ — the classical query count needed for a fixed confidence level
does not depend on $n$ either (Day 2's bound $2^{-m}$ was already
independent of $n$), but no finite $k$ ever gives certainty. Deutsch–Jozsa
needs exactly $1$ quantum query, for *any* $n$, and gets the exactly
correct answer with probability $1$ — a strictly stronger guarantee
(certainty vs. arbitrarily-high-but-not-perfect confidence) using
exponentially fewer queries.

**8.** Removing Stage 3 (the second layer of $H^{\otimes n}$, applied to
the input register after the oracle call) and measuring immediately after
Stage 2 instead: the state at that point is $\tfrac{1}{\sqrt{2^n}}\sum_x
(-1)^{f(x)}|x\rangle\otimes|-\rangle$, and since a global phase
$(-1)^{f(x)}$ on a computational basis term does not change measurement
probabilities in that same basis, measuring the input register here gives
a uniformly random $x\in\{0,1\}^n$ with probability $1/2^n$ each — exactly
what one classical query at a uniformly random point would give you, with
no advantage whatsoever. It is specifically the second Hadamard layer,
applied *before* the measurement, that converts the per-branch phases
$(-1)^{f(x)}$ into interference in the standard basis — constructive on
$|0\rangle^{\otimes n}$ for constant $f$, perfectly destructive on
$|0\rangle^{\otimes n}$ for balanced $f$ — which is the only place in the
whole circuit where the global constant/balanced distinction becomes
visible to a measurement.

## Journal template

```
## Day 8 — Quantum parallelism & the Deutsch–Jozsa algorithm
Key idea in my own words: ...
What confused me: ...
```
