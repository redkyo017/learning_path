# Day 14 — Quantum Phase Estimation & Shor's Algorithm

## Learning objectives

By the end of today you should be able to:
- Derive, explicitly, how controlled-$U^{2^j}$ applied to an ancilla in
  $\frac{1}{\sqrt2}(|0\rangle+|1\rangle)$ and a target eigenvector $|u\rangle$
  kicks the eigenvalue's phase back onto the ancilla — the direct
  generalization of Day 8's $\pm1$ phase-kickback identity to an arbitrary
  phase $e^{2\pi i\varphi}$.
- Derive that repeating this for $t$ ancilla qubits ($j=0,\dots,t-1$) leaves
  the ancilla register in $\frac{1}{\sqrt{2^t}}\sum_x e^{2\pi i\varphi x}
  |x\rangle$, recognize this as the QFT of a phase-peaked state, and explain
  why the *inverse* QFT recovers an estimate of $\varphi$.
- Assemble the full Shor's algorithm pipeline — QPE on the modular
  multiplication unitary, continued fractions, Miller's reduction — and
  trace every stage of the concrete $N=15,\ a=7$ example back to the day and
  step where it was derived.
- State exactly which piece of the pipeline (the modular-exponentiation
  circuit's own gate-level construction) this course takes as a given
  building block rather than derives, and why.
- Run the exact numerical QPE simulation for $N=15,\ a=7$ and interpret its
  output distribution.

## Reference material

- Nielsen & Chuang or Yanofsky & Mannucci's coverage of Quantum Phase
  Estimation and the full assembly of Shor's algorithm — the canonical
  source for the material below.
- Day 13's content (QFT definition, order-finding, continued fractions, and
  Miller's reduction) — today builds directly on all of it.
- The Day 14 implementation plan for this course:
  `quantum_computing_foundations/docs/superpowers/plans/2026-07-13-quantum-computing-15-day-plan.md`
  (has the exact step timings and the code listing; this document is the
  theory to pair with them).
- The theory below is self-contained given Day 13 — you do not need the book
  open to follow the derivations, but reading the matching chapter alongside
  is useful for a second explanation in different words.

## Theory

### Setup: what Quantum Phase Estimation estimates

Let $U$ be a unitary with an eigenvector $|u\rangle$ and eigenvalue
$e^{2\pi i\varphi}$ for some $\varphi\in[0,1)$, i.e. $U|u\rangle = e^{2\pi
i\varphi}|u\rangle$. **Quantum Phase Estimation (QPE)** is a circuit that,
given $|u\rangle$ and the ability to apply controlled-$U^{2^j}$ for
$j=0,\dots,t-1$, outputs a $t$-bit estimate of $\varphi$ using $t$ ancilla
qubits (the "phase register") prepared in $|0\rangle^{\otimes t}$, an $H$ on
each ancilla, the controlled-$U^{2^j}$ gates, and an inverse QFT on the
ancilla register at the end. Everything below derives why this works,
building directly on Day 13's QFT.

### Phase kickback, generalized from a $\pm1$ phase to an arbitrary phase

Recall Day 8 Step 2's identity: for an oracle acting as $X^{f(x)}$ on the
target, $U_f|x\rangle|-\rangle = (-1)^{f(x)}|x\rangle|-\rangle$, because
$|-\rangle$ is an eigenvector of $X$ with eigenvalue $-1$, and applying $X$
conditionally on $x$ kicks that eigenvalue, raised to the power $f(x)$, back
onto the control register as a phase. The mechanism there is general; only
the eigenvalue was special (it happened to be $-1$, i.e. $e^{2\pi i\cdot
\frac12}$). Today's derivation is the same mechanism with the restriction to
a $\{0,\tfrac12\}$-valued phase removed.

Take one ancilla qubit as control, in the state $\frac{1}{\sqrt2}(|0\rangle+
|1\rangle)$, and the target register in the eigenvector $|u\rangle$ of $U$
with eigenvalue $e^{2\pi i\varphi}$. Controlled-$U^{2^j}$ applies the
identity to the target when the control is $|0\rangle$, and applies
$U^{2^j}$ to the target when the control is $|1\rangle$:

$$\text{controlled-}U^{2^j}\Big[\tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)\otimes
|u\rangle\Big] = \tfrac{1}{\sqrt2}\Big(|0\rangle\otimes|u\rangle +
|1\rangle\otimes U^{2^j}|u\rangle\Big).$$

Because $|u\rangle$ is an eigenvector of $U$, it is also an eigenvector of
every power of $U$, with the eigenvalue raised to that power: $U^{2^j}
|u\rangle = e^{2\pi i\varphi \cdot 2^j}|u\rangle$. (Proof by induction on
$k$ that $U^k|u\rangle = e^{2\pi i\varphi k}|u\rangle$: true for $k=1$ by
hypothesis; if true for $k$, then $U^{k+1}|u\rangle = U(U^k|u\rangle) =
U(e^{2\pi i\varphi k}|u\rangle) = e^{2\pi i\varphi k}U|u\rangle = e^{2\pi
i\varphi k}e^{2\pi i\varphi}|u\rangle = e^{2\pi i\varphi(k+1)}|u\rangle$,
since $U$ is linear and $e^{2\pi i\varphi k}$ is a scalar that pulls
straight through. Setting $k=2^j$ gives the claim.) Substituting:

$$\tfrac{1}{\sqrt2}\Big(|0\rangle\otimes|u\rangle +
e^{2\pi i\varphi 2^j}|1\rangle\otimes|u\rangle\Big) =
\tfrac{1}{\sqrt2}\Big(|0\rangle + e^{2\pi i\varphi 2^j}|1\rangle\Big)
\otimes |u\rangle.$$

So the target register is left completely unchanged (still exactly
$|u\rangle$, unentangled from the control), while the control qubit picks
up the phase $e^{2\pi i\varphi 2^j}$ on its $|1\rangle$ branch. This is
exactly Day 8's identity with the eigenvalue's exponent generalized from the
two values $\{0,\tfrac12\}$ (giving $\pm1$) to an arbitrary $\varphi2^j\bmod
1$ — same mechanism, no new physics, just no longer restricted to a
$2$-valued phase.

### From one ancilla to the full phase register: recognizing a QFT

Now do this for every ancilla qubit $j=0,\dots,t-1$: prepare each in
$\frac{1}{\sqrt2}(|0\rangle+|1\rangle)$ via a Hadamard, and apply
controlled-$U^{2^j}$ with that ancilla as control and the (single, shared)
target register as target. By the previous derivation, applying
controlled-$U^{2^j}$ never changes the target away from $|u\rangle$ and
never entangles it with any ancilla — so the $t$ applications can be done in
any order, each acting on its own ancilla qubit and the same
still-$|u\rangle$ target, and the target factors out completely at the end.
The ancilla register is therefore left in the tensor product

$$\bigotimes_{j=0}^{t-1}\tfrac{1}{\sqrt2}\Big(|0\rangle_j +
e^{2\pi i\varphi 2^j}|1\rangle_j\Big).$$

Expand this product in the computational basis. Write $x\in\{0,\dots,
2^t-1\}$ in binary as $x = \sum_{j=0}^{t-1} x_j 2^j$ with $x_j\in\{0,1\}$,
so $|x\rangle = |x_{t-1}\rangle\otimes\cdots\otimes|x_0\rangle$. Multiplying
out the product, each ancilla qubit $j$ contributes a factor of
$e^{2\pi i\varphi 2^j}$ exactly when $x_j=1$ and a factor of $1$ when
$x_j=0$ — i.e. it contributes $e^{2\pi i\varphi 2^j x_j}$ in general. The
coefficient of $|x\rangle$ is therefore the product over $j$ of these
factors:

$$\prod_{j=0}^{t-1} e^{2\pi i\varphi 2^j x_j} = e^{2\pi i\varphi
\sum_{j=0}^{t-1} 2^j x_j} = e^{2\pi i\varphi x},$$

using $\sum_j 2^j x_j = x$ (that's just $x$'s binary expansion) and the fact
that a product of exponentials with the same base adds the exponents. So the
ancilla register, after all $t$ controlled-$U^{2^j}$ applications, is

$$\frac{1}{\sqrt{2^t}}\sum_{x=0}^{2^t-1} e^{2\pi i\varphi x}|x\rangle.$$

Recall Day 13 Step 4's QFT definition on dimension $M=2^t$: $\text{QFT}
|y\rangle = \frac{1}{\sqrt M}\sum_x e^{2\pi i xy/M}|x\rangle$. Setting
$y = \varphi M = \varphi 2^t$ turns $e^{2\pi ixy/M}$ into exactly $e^{2\pi i
\varphi x}$ — so the state above is *exactly* $\text{QFT}|\varphi 2^t\rangle$
when $\varphi2^t$ happens to be an integer, and the QFT applied to a state
"peaked" at the (possibly non-integer) value $\varphi2^t$ in general. Either
way, it is a QFT output whose defining input parameter is $\varphi2^t$.
Since the QFT is unitary (Day 13 Step 4), it has an inverse, and applying
$\text{QFT}^{-1}$ to this state recovers $|\varphi2^t\rangle$ exactly when
$\varphi2^t\in\mathbb{Z}$, or a distribution sharply peaked around the
nearest integers to $\varphi2^t$ otherwise. Measuring the ancilla register
after the inverse QFT and dividing the outcome $x$ by $2^t$ therefore gives
an estimate of $\varphi$ good to about $t$ bits — this is precisely why the
QPE circuit ends with an inverse QFT on the phase register, not a forward
one.

### Assembling Shor's algorithm

Shor's algorithm factors a composite $N$ by reducing factoring to
*order-finding* (Day 13 Steps 1–3), then solving order-finding with QPE.
Concretely, for a randomly chosen $a$ with $\gcd(a,N)=1$:

- Define the **modular multiplication unitary** on the work register,
  $U_a|y\rangle = |ay\bmod N\rangle$. This is a permutation of the basis
  states $\{0,\dots,N-1\}$ and therefore unitary. **This course does not
  derive the gate-by-gate circuit that implements $U_a$ out of elementary
  gates** (i.e. how modular multiplication is actually built from
  Toffoli/CNOT-style reversible arithmetic circuits) — that construction is
  a substantial topic of its own and is taken as a given building block
  here, consistent with this course's scope boundary of not covering
  circuit-level arithmetic synthesis or physical implementation details.
  Everything below treats $U_a$ as an exact black-box unitary.
- $U_a$ acts as a cyclic shift on the orbit $\{a^0,a^1,\dots,a^{r-1}\bmod
  N\}$, where $r$ is the order of $a$ mod $N$ (Day 13 Step 1). It is a
  standard fact — also taken as given here, since deriving it is a
  side-quest in Fourier-diagonalizing a cyclic shift rather than something
  today's exercises ask for — that $U_a$'s eigenvectors are discrete-Fourier
  combinations of that orbit, with eigenvalues $e^{2\pi ik/r}$ for
  $k=0,\dots,r-1$. So $U_a$'s eigenphases directly encode $1/r$.
- Running QPE on $U_a$ with the work register prepared in the computational
  basis state $|1\rangle$ (which equals $a^0\bmod N$, and is therefore an
  equal superposition of all $r$ eigenvectors, not a single eigenvector)
  produces, after the inverse QFT and a measurement, a phase register
  outcome $x$ with $x/2^t \approx k/r$ for a uniformly random $k\in\{0,
  \dots,r-1\}$.
- Feed that phase estimate $\varphi\approx k/r$ into Day 13 Step 5's
  continued-fraction algorithm to recover $r$ (its denominator in lowest
  terms), provided $\gcd(k,r)=1$; if $k=0$ or the recovered denominator
  doesn't check out, rerun QPE (a different random $k$ is likely to be
  coprime to $r$).
- Feed $r$ into Day 13 Step 3.2's (Miller's) reduction: if $r$ is even and
  $a^{r/2}\not\equiv -1\pmod N$, then $\gcd(a^{r/2}-1,N)$ is a nontrivial
  factor of $N$.

### The $N=15,\ a=7$ pipeline, traced end to end

Day 13 Step 3.3 established $\gcd(7,15)=1$ and computed the order of $7$
mod $15$ by brute force: $7^1=7$, $7^2=49\bmod15=4$, $7^3=28\bmod15=13$,
$7^4=91\bmod15=1$ — so $r=4$ is the smallest exponent giving $1$, and no
smaller power works. $r=4$ is even, and $7^{2}\bmod15=4\ne14\equiv-1
\pmod{15}$, so Miller's reduction applies: $\gcd(7^2-1,15)=\gcd(3,15)=3$,
a nontrivial factor, confirming $15=3\times5$.

Tracing this into the QPE pipeline: $U_7$'s eigenphases are $e^{2\pi ik/4}$
for $k=0,1,2,3$. Running QPE (with $t=6$ ancilla qubits, as in today's code)
on the work register started in $|1\rangle$ should return phase-register
outcomes $x$ clustering at $x/2^6\approx k/4$, i.e. at $x\approx0,16,32,48$
(the four multiples of $\tfrac14$ scaled to a $64$-outcome register).
Suppose a run measures $x=16$: the phase estimate is $\varphi=16/64=0.25=
\tfrac14$. Running Day 13 Step 5's continued-fraction expansion on $0.25$
returns $\tfrac14$ directly (it is already in lowest terms with a small
denominator), recovering $r=4$ — matching the brute-force value from Day 13
exactly. Feeding $r=4$ into Miller's reduction reproduces the factor $3$
computed above. A measurement of $x=0$ (i.e. $k=0$) would instead give
$\varphi=0$, whose continued fraction is the uninformative $0/1$ — this is
the case where the run must be repeated with fresh randomness, since $k=0$
carries no information about $r$.

**Explicit traceability, per step:**

| Pipeline step | Originating derivation |
|---|---|
| Controlled-$U^{2^j}$ kicks back phase $e^{2\pi i\varphi2^j}$ | Today's Theory / Exercise 1, generalizing Day 8 Step 2's $\pm1$ phase-kickback identity |
| Ancilla register becomes $\frac{1}{\sqrt{2^t}}\sum_x e^{2\pi i\varphi x}|x\rangle$; inverse QFT recovers $\varphi$ | Today's Theory / Exercise 2, built on Day 13 Step 4's QFT definition and unitarity |
| $U_a|y\rangle=|ay\bmod N\rangle$, eigenphases encode $1/r$ | Given building block (not derived — see scope note above) |
| Phase estimate $\varphi\approx k/r\;\Rightarrow\;$ recover $r$ | Day 13 Step 5, continued fractions |
| $r$ even, $a^{r/2}\not\equiv-1\Rightarrow\gcd(a^{r/2}-1,N)$ is a nontrivial factor | Day 13 Step 3.2 (Miller's reduction), numeric example Step 3.3 |
| $N=15,a=7,r=4$, factor $3$ | Day 13 Step 3.3, reused verbatim today |

## Worked example

**Claim:** for $N=15,\ a=7$, a single QPE run with outcome $x=48$ (out of
$2^6=64$ phase-register states) still recovers the correct order $r=4$ and
factor $3$, via a different $k$ than the $x=16$ case traced above.

$\varphi = 48/64 = 0.75 = \tfrac34$. Continued-fraction expansion of
$0.75$: integer part $0$, remainder $0.75$; reciprocal $1/0.75=1.3\overline
3$; integer part $1$, remainder $0.3\overline3$; reciprocal $1/0.3\overline3
=3$; integer part $3$, remainder $0$ — expansion terminates. Reading off
convergents, $0.75 = 0 + \cfrac{1}{1+\cfrac{1}{3}} = \cfrac{1}{4/3} =
\cfrac{3}{4}$, so the fraction recovered is $\tfrac34$, denominator $r=4$ —
the same order as before (as it must be: $r$ is a property of $a$ and $N$
alone, not of which $k$ a given run happens to sample). Here $k=3$: indeed
$3/4=0.75$ matches $\varphi$ exactly, and $\gcd(k,r)=\gcd(3,4)=1$, so this
run's $k$ is coprime to $r$ and the continued fraction lands exactly on
$k/r$ with no rounding needed. Feeding $r=4$ into Miller's reduction gives
the identical factor $3$ computed above, since Miller's reduction only ever
sees $r$, not which $k$ produced it.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Derive, explicitly and without skipping the induction step, the identity
   $$\text{controlled-}U^{2^j}\Big[\tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)
   \otimes|u\rangle\Big] = \tfrac{1}{\sqrt2}\Big(|0\rangle+e^{2\pi i\varphi
   2^j}|1\rangle\Big)\otimes|u\rangle$$
   for $U|u\rangle=e^{2\pi i\varphi}|u\rangle$, and state precisely which
   single restriction, if removed from Day 8's $\pm1$ phase-kickback
   identity, turns it into this one.
2. Derive, explicitly, that repeating Exercise 1 for ancilla qubits
   $j=0,\dots,t-1$ leaves the ancilla register in $\frac{1}{\sqrt{2^t}}
   \sum_{x=0}^{2^t-1}e^{2\pi i\varphi x}|x\rangle$, and explain — referencing
   Day 13's QFT definition by name — why this state is recognizable as a
   QFT output and why the circuit therefore ends with an *inverse* QFT
   rather than a forward one.
3. Using $N=15,\ a=7,\ r=4$ from Day 13, write out the full Shor's-algorithm
   pipeline in your own words: what QPE is run on, what it returns, what
   step recovers $r$ from that return value, and what step recovers a
   factor of $N$ from $r$.
4. Reproduce the traceability table above from scratch (without looking at
   it) in your notes file: for each of the six pipeline steps, name the
   specific day and step number where it was derived.
5. Without opening the code file, predict what
   `code/day14_shors_qpe_simulation.py` does at each stage (building $U_a$,
   finding $r$ classically, building the QPE state, applying
   controlled-$U^{2^j}$, applying the inverse QFT, measuring) and predict
   the shape of its printed output before running it.

## Solutions

**1.** Controlled-$U^{2^j}$ leaves the target alone when the control is
$|0\rangle$ and applies $U^{2^j}$ to the target when the control is
$|1\rangle$, so
$$\text{controlled-}U^{2^j}\Big[\tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)
\otimes|u\rangle\Big]=\tfrac{1}{\sqrt2}\Big(|0\rangle\otimes|u\rangle+
|1\rangle\otimes U^{2^j}|u\rangle\Big).$$
Claim: $U^k|u\rangle=e^{2\pi i\varphi k}|u\rangle$ for every integer
$k\ge1$. Base case $k=1$ is the hypothesis $U|u\rangle=e^{2\pi i\varphi}
|u\rangle$. Inductive step: assume $U^k|u\rangle=e^{2\pi i\varphi k}
|u\rangle$; then $U^{k+1}|u\rangle=U(U^k|u\rangle)=U\big(e^{2\pi i\varphi k}
|u\rangle\big)$. Since $U$ is linear, the scalar $e^{2\pi i\varphi k}$
passes through: $=e^{2\pi i\varphi k}\,U|u\rangle=e^{2\pi i\varphi k}\cdot
e^{2\pi i\varphi}|u\rangle=e^{2\pi i\varphi(k+1)}|u\rangle$, closing the
induction. Setting $k=2^j$ gives $U^{2^j}|u\rangle=e^{2\pi i\varphi2^j}
|u\rangle$. Substituting into the expression above:
$$\tfrac{1}{\sqrt2}\Big(|0\rangle\otimes|u\rangle+e^{2\pi i\varphi2^j}
|1\rangle\otimes|u\rangle\Big)=\tfrac{1}{\sqrt2}\Big(|0\rangle+e^{2\pi
i\varphi2^j}|1\rangle\Big)\otimes|u\rangle,$$
factoring $|u\rangle$ back out since it multiplies both terms identically.
This is the claimed identity. Day 8's identity is the special case
$\varphi2^j\in\{0,\tfrac12\}$ (so $e^{2\pi i\varphi2^j}\in\{1,-1\}$, written
there as $(-1)^{f(x)}$): the single restriction removed to get today's
identity is that the eigenvalue's phase is allowed to be *any* real number
in $[0,1)$ rather than only one of two values.

**2.** By Exercise 1, preparing ancilla qubit $j$ in $\frac{1}{\sqrt2}
(|0\rangle+|1\rangle)$ (via a Hadamard on $|0\rangle$) and applying
controlled-$U^{2^j}$ with the shared target register in $|u\rangle$ leaves
that target exactly in $|u\rangle$, unentangled from ancilla $j$, while
ancilla $j$ becomes $\frac{1}{\sqrt2}(|0\rangle+e^{2\pi i\varphi2^j}
|1\rangle)$. Because the target is returned to $|u\rangle$ unchanged and
unentangled after *every* one of these applications, the $j=0,\dots,t-1$
operations can be composed one after another, each acting on a distinct
ancilla qubit and the same still-pure $|u\rangle$ target, and the target
factors out of the full state at the end — leaving the ancilla register in
the tensor product $\bigotimes_{j=0}^{t-1}\frac{1}{\sqrt2}(|0\rangle_j+
e^{2\pi i\varphi2^j}|1\rangle_j)$. Writing $x=\sum_j x_j2^j$ in binary and
expanding this product term by term, the coefficient attached to basis
state $|x\rangle=|x_{t-1}\rangle\otimes\cdots\otimes|x_0\rangle$ is the
product, over $j$, of $e^{2\pi i\varphi2^j}$ whenever $x_j=1$ and $1$
whenever $x_j=0$ — i.e. $\prod_j e^{2\pi i\varphi2^jx_j}=e^{2\pi i\varphi
\sum_j2^jx_j}=e^{2\pi i\varphi x}$, using $\sum_j2^jx_j=x$. Including the
overall normalization $1/\sqrt{2^t}$ that comes from the $t$ factors of
$1/\sqrt2$, the ancilla register is exactly $\frac{1}{\sqrt{2^t}}\sum_{x=0}
^{2^t-1}e^{2\pi i\varphi x}|x\rangle$. Day 13's QFT on dimension $M=2^t$ is
$\text{QFT}|y\rangle=\frac{1}{\sqrt M}\sum_xe^{2\pi ixy/M}|x\rangle$; taking
$y=\varphi M=\varphi2^t$ makes $e^{2\pi ixy/M}=e^{2\pi i\varphi x}$
identically, so the ancilla state above is precisely $\text{QFT}|\varphi
2^t\rangle$ (exactly, when $\varphi2^t\in\mathbb{Z}$; as a QFT of a state
peaked there, in general). A QFT output is inverted by the QFT's inverse
(it's unitary, Day 13 Step 4), so applying $\text{QFT}^{-1}$ to this
ancilla state recovers $|\varphi2^t\rangle$ (or a distribution sharply
peaked around the nearest integers to $\varphi2^t$) — hence the circuit
ends with an *inverse* QFT, and measuring afterward and dividing by $2^t$
estimates $\varphi$.

**3.** Choose $a=7$ coprime to $N=15$. Build (as a given unitary, per the
scope note in Theory) $U_7|y\rangle=|7y\bmod15\rangle$. Run QPE: prepare the
work register in $|1\rangle$, apply Hadamards to $t$ ancilla qubits, apply
controlled-$U_7^{2^j}$ for each ancilla, apply the inverse QFT to the
ancilla register, and measure it. By Exercise 2's mechanism, the result is
a phase estimate $\varphi\approx k/r$ for a uniformly random $k\in\{0,1,2,
3\}$, since $U_7$'s eigenphases are $e^{2\pi ik/4}$ (Day 13's $r=4$).
Feeding $\varphi$ into Day 13 Step 5's continued-fraction algorithm
recovers the denominator $r=4$ (provided $k\ne0$ and $\gcd(k,4)=1$; $k=1,3$
work directly, $k=2$ gives the reduced fraction $1/2$ and must be detected
and retried). Feeding $r=4$ into Day 13 Step 3.2's Miller's reduction —
check $r$ even (yes) and $7^{2}\bmod15=4\ne14\equiv-1\pmod{15}$ (yes) —
gives $\gcd(7^2-1,15)=\gcd(3,15)=3$, a nontrivial factor of $15$, so
$15=3\times5$.

**4.** See the traceability table in Theory above: (i) phase kickback with
an arbitrary phase → today's Exercise 1, generalizing Day 8 Step 2; (ii) the
ancilla register as a QFT output and inverse-QFT recovery → today's
Exercise 2, built on Day 13 Step 4; (iii) $U_a$ as a given permutation unitary
with eigenphases encoding $1/r$ → stated as a given building block, not
derived (scope note); (iv) continued fractions recovering $r$ from $\varphi$
→ Day 13 Step 5; (v) Miller's reduction recovering a factor from $r$ → Day
13 Step 3.2, with the numeric $N=15,a=7$ check in Step 3.3; (vi) the reused
numeric values $N=15,a=7,r=4$, factor $3$ → Day 13 Step 3.3 verbatim.

**5.** The code (i) builds `U` as an $N\times N$ permutation matrix with
$U[(a\cdot y)\bmod N, y]=1$ — the exact matrix form of $U_a|y\rangle=|ay
\bmod N\rangle$; (ii) finds $r$ classically by repeated multiplication mod
$N$ until it hits $1$, printing it as a check against Day 13 Step 3.3's
hand computation ($r=4$ expected); (iii) builds the full $2^t\times N$-
dimensional QPE state exactly, starting the work register in $|1\rangle$
and the phase register in an equal superposition over all $2^t$ values
($t=6$); (iv) applies controlled-$U^{2^j}$ for all $j$ at once by applying
$U^x$ to the work-register block associated with each phase-register basis
state $x$ (since $x$'s binary digits pick out exactly which powers of $2$
apply — this is a direct computational shortcut for doing all $t$
controlled operations from Exercise 2 simultaneously); (v) applies the
exact inverse-QFT matrix to the phase register; (vi) measures by summing
$|\text{amplitude}|^2$ over the work-register index for each phase-register
value $x$, and prints the highest-probability outcomes. Predicted output:
the printed order matches Day 13's $r=4$, and the top-probability $x$ values
cluster near $x/2^t\approx0,\ 0.25,\ 0.5,\ 0.75$ — i.e. $x\approx0,16,32,48$
out of $64$ — the four multiples of $1/r=1/4$, exactly as traced in the
Worked example above.

## Code lab

Today's code is already written at
`quantum_computing_foundations/code/day14_shors_qpe_simulation.py`, per the
plan's Step 4. It does not need to be rewritten — it builds the entire
$N=15,\ a=7$ pipeline as exact matrices (small enough to brute-force
directly; no physical noise, no approximate gate decomposition of any kind):
$U_a$ as an exact permutation matrix, the full QPE state (work register
started in $|1\rangle$, phase register with $t=6$ ancilla qubits), the
controlled-$U^{2^j}$ step applied as $U^x$ block-by-block, and the exact
inverse-QFT matrix on the phase register, finishing with an exact
measurement histogram.

Consistent with the scope note in Theory above, the script's `U` is built
directly as a permutation matrix from the formula $U_a|y\rangle=|ay\bmod
N\rangle$ — it does **not** construct $U_a$ from elementary reversible
gates the way a real quantum circuit would need to; that gate-level
synthesis is out of scope for this course and is treated as a given
building block here, exactly as it is in the derivation above.

Run it with:
```bash
cd quantum_computing_foundations
python3 code/day14_shors_qpe_simulation.py
```

**Expected output** (per the plan's Step 4): the printed order matches
Day 13 Step 3.3's hand computation, $r=4$; and the high-probability
phase-register outcomes cluster at $x/2^t$ values close to $0/4,\ 1/4,\
2/4,\ 3/4$ — i.e. multiples of $1/r=1/4$ — the exact numerical confirmation
of the entire week's most complex derivation chain. After running it, pick
one high-probability outcome, run it through Day 13 Step 5's
continued-fraction algorithm by hand, and confirm you recover $r=4$ (see
the Worked example above for a fully worked instance of this check with
$x=48$).

## Journal template

```
## Day 14 — Quantum Phase Estimation & Shor's algorithm
Key idea in my own words: ...
What confused me: ...
Did today overrun the 4-hour budget? If so, how much of Day 15's morning
did I need to borrow: ...
```
