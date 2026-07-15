# Day 10 — Bernstein–Vazirani & Simon's Algorithm

## Learning objectives

By the end of today you should be able to:
- Derive $H^{\otimes n}\sum_x(-1)^{a\cdot x}|x\rangle = |a\rangle$ exactly
  from the Hadamard-transform identity, and recognize the
  Bernstein–Vazirani (BV) circuit as literally the Deutsch–Jozsa (DJ)
  circuit run against a different oracle.
- Trace a concrete Bernstein–Vazirani run, state by state, and confirm the
  hidden string is recovered with certainty in a single query.
- State Simon's promise precisely and explain why it is strictly stronger
  than DJ's constant/balanced promise, in terms of what a classical
  algorithm would need to do to verify it.
- Derive why measuring the second register in Simon's algorithm collapses
  the first register to $\frac{1}{\sqrt2}(|x\rangle+|x\oplus s\rangle)$,
  and why the following $H^{\otimes n}$ leaves nonzero amplitude only on
  strings $y$ with $y\cdot s \equiv 0 \pmod 2$.
- Recover a hidden $s\in\{0,1\}^n$ from $n-1$ independent linear samples by
  Gaussian elimination over $\mathbb{F}_2$.
- Explain, in one paragraph, how DJ, BV, and Simon's algorithm are all
  instances of a single "Hadamard – oracle – Hadamard" schema, applied to
  oracles that hide different kinds of structure.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*,
  or Ronald de Wolf's *Quantum Computing: Lecture Notes*, the sections
  covering the Bernstein–Vazirani and Simon's algorithms.
- The theory below is self-contained and builds directly on Day 8's
  phase-kickback derivation — you do not need the book to do today's work,
  but reading the matching section alongside this is useful for a second
  explanation in different words.

## Theory

### Recap: the Hadamard transform and phase kickback (Day 8)

For $x,y\in\{0,1\}^n$, write $x\cdot y = \sum_i x_iy_i \bmod 2$. The
$n$-fold Hadamard transform satisfies

$$H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_{y\in\{0,1\}^n}(-1)^{x\cdot y}|y\rangle.$$

An oracle for a Boolean function $f:\{0,1\}^n\to\{0,1\}$ acts as
$U_f|x\rangle|b\rangle = |x\rangle|b\oplus f(x)\rangle$. Feeding it the
ancilla $|-\rangle = \frac{1}{\sqrt2}(|0\rangle-|1\rangle)$ produces **phase
kickback**: if $f(x)=0$, $U_f|x\rangle|-\rangle = |x\rangle\otimes
\frac{1}{\sqrt2}(|0\rangle-|1\rangle) = |x\rangle|-\rangle$; if $f(x)=1$,
$U_f|x\rangle|-\rangle = |x\rangle\otimes\frac{1}{\sqrt2}(|1\rangle-|0\rangle)
= -|x\rangle|-\rangle$. Both cases are summarized by

$$U_f|x\rangle|-\rangle = (-1)^{f(x)}|x\rangle|-\rangle,$$

i.e. the oracle leaves the ancilla alone and writes $f(x)$ into the *phase*
of the data register instead of into a bit. This is the mechanism DJ, BV,
and (in a modified form) Simon's algorithm all exploit.

### The parity-orthogonality lemma

Both derivations below rest on one counting fact:

$$\sum_{x\in\{0,1\}^n}(-1)^{x\cdot z} = \begin{cases}2^n & z = 0^n\\ 0 & z\ne 0^n\end{cases}.$$

*Proof.* If $z=0^n$, every term $(-1)^{x\cdot 0} = 1$, so the sum is $2^n$.
If $z\ne0^n$, pick any index $i$ with $z_i=1$, and pair each string $x$
with $x\oplus e_i$ (flip bit $i$; $e_i$ is the string that is $1$ only in
position $i$). This pairing is an involution with no fixed points, so it
partitions all $2^n$ strings into $2^{n-1}$ disjoint pairs. Within a pair,
$(x\oplus e_i)\cdot z = x\cdot z \oplus e_i\cdot z = x\cdot z \oplus z_i =
x\cdot z \oplus 1$, so $(-1)^{(x\oplus e_i)\cdot z} = -(-1)^{x\cdot z}$: the
two terms in every pair cancel exactly. Summing $2^{n-1}$ pairs of
cancelling terms gives $0$. $\blacksquare$

### Bernstein–Vazirani: statement and general derivation

**Problem.** An oracle computes $f(x) = a\cdot x \bmod 2$ for a hidden
$a\in\{0,1\}^n$. Find $a$. Classically, since each query can reveal at most
one linear equation about $a$'s bits, and the bits are otherwise
independent, you need $n$ queries (e.g. query the $n$ standard-basis
vectors $e_i$ one at a time; $f(e_i) = a_i$ reads off bit $i$ directly),
and no clever classical strategy beats this — you cannot get more than one
bit of information about a completely unconstrained $n$-bit string from one
Boolean-valued query.

**Circuit.** Prepare $|0\rangle^{\otimes n}$ on the data register and
$|1\rangle$ on the ancilla; apply $H^{\otimes n}$ to the data register and
$H$ to the ancilla (giving $|-\rangle$); query the oracle once; apply
$H^{\otimes n}$ to the data register again; measure the data register in
the standard basis.

**Derivation.** After the first Hadamard layer the data register is
$\frac{1}{\sqrt{2^n}}\sum_x|x\rangle$. Querying the oracle with $f(x)=a\cdot
x$ applies phase kickback termwise:

$$\frac{1}{\sqrt{2^n}}\sum_x|x\rangle \;\longrightarrow\; \frac{1}{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}|x\rangle$$

(the ancilla stays $|-\rangle$ throughout and is dropped from here on).
Now apply $H^{\otimes n}$ a second time, using the Hadamard-transform
identity on each $|x\rangle$ in the sum — this is the "use the identity
twice" referred to in the learning objectives: once implicitly, to produce
the uniform superposition above from $H^{\otimes n}|0\rangle^{\otimes n}$,
and once explicitly here:

$$H^{\otimes n}\left[\frac{1}{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}|x\rangle\right] = \frac{1}{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}\, H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}\left[\frac{1}{\sqrt{2^n}}\sum_y(-1)^{x\cdot y}|y\rangle\right].$$

Swap the order of summation and combine the exponents (using $(-1)^{a\cdot
x}(-1)^{x\cdot y} = (-1)^{x\cdot(a\oplus y)}$, since $a\cdot x \oplus x\cdot
y = x\cdot(a\oplus y) \pmod 2$ by bilinearity of the mod-2 dot product):

$$= \frac{1}{2^n}\sum_y\left[\sum_x (-1)^{x\cdot(a\oplus y)}\right]|y\rangle.$$

By the orthogonality lemma, the bracketed sum is $2^n$ when $a\oplus y =
0^n$ (i.e. $y=a$) and $0$ for every other $y$. So the whole expression
collapses to exactly

$$\frac{1}{2^n}\cdot 2^n\,|a\rangle = |a\rangle.$$

Measuring the data register now returns $a$ with probability $1$: **one
query, zero error, exact recovery of all $n$ bits of $a$ at once** — a
strict improvement on the classical $n$-query lower bound, using exactly
the same circuit shape as Deutsch–Jozsa (Day 8), pointed at a linear oracle
instead of a constant/balanced one.

### Simon's algorithm: statement and why the promise is stronger

**Problem.** An oracle computes $f:\{0,1\}^n\to\{0,1\}^n$, promised to be
exactly 2-to-1 with $f(x) = f(y) \iff y = x\oplus s$ for some hidden
$s\ne0^n$. Find $s$.

**Why this promise is strictly stronger than DJ's.** DJ's promise
partitions all possible functions into exactly *two* global classes
(constant or exactly balanced), and — as Day 2's randomized algorithm
showed — a classical algorithm can already resolve *that* two-way question
with bounded error using only $O(1)$ random queries: if $f$ is balanced,
each independent random query has probability $1/2$ of landing on either
output value, so a handful of repeated queries drives the "looks constant
by fluke" error down exponentially fast with no dependence on $n$. DJ's
quantum advantage over the *bounded-error* classical model is therefore
about achieving *certainty* with *one* query, not about needing
exponentially many classical queries in the first place.

Simon's promise is a different kind of object: it does not ask you to
classify $f$ into one of two buckets, it asks you to *identify* one
specific hidden string $s$ out of $2^n-1$ possible nonzero candidates,
where the only observable trace of $s$ is a *collision*: two specific
inputs $x$ and $x\oplus s$ that happen to produce the same output. A
classical algorithm learns nothing about $s$ from any query that doesn't
land on both members of some colliding pair, and by a birthday-paradox
argument, random queries only start finding such collisions after
$\Omega(2^{n/2})$ of them (there are $2^{n-1}$ colliding pairs scattered
among $\binom{2^n}{2}$ possible pairs of queries). This is a *provable*
exponential classical query lower bound, not merely an "easy with more
patience" gap — it survives randomization and bounded error, unlike DJ's.
That is the concrete sense in which "2-to-1 with a hidden period" is a
strictly stronger, more information-rich promise than "constant vs.
balanced": it encodes an exponentially large space of possible hidden
structures ($2^n-1$ candidate values of $s$) rather than a binary global
classification, and (historically) it was exactly this exponential
separation that inspired Shor's algorithm.

### Simon's circuit: collapse and the linear constraint on $y$

Because $f$ is not single-bit-valued, Simon's algorithm cannot use the
single-ancilla phase-kickback trick from DJ/BV. Instead it uses $f$ as a
direct **value oracle** into a second, $n$-qubit register: $U_f|x\rangle
|0\rangle^{\otimes n} = |x\rangle|f(x)\rangle$.

**Circuit.** Prepare $|0\rangle^{\otimes n}|0\rangle^{\otimes n}$, apply
$H^{\otimes n}$ to the first register, query the oracle, **measure the
second register**, apply $H^{\otimes n}$ to the first register, measure it.

**Derivation.** After $H^{\otimes n}$ and the oracle call, the joint state
is

$$\frac{1}{\sqrt{2^n}}\sum_x |x\rangle|f(x)\rangle.$$

Measuring the second register yields some outcome $z$. Because $f$ is
exactly 2-to-1 with period $s$, exactly two values of $x$ produce $f(x)=z$:
call them $x_0$ and $x_0\oplus s$. Before the measurement, both branches
carried amplitude $1/\sqrt{2^n}$; the total probability of observing $z$ is
therefore $2\cdot\frac{1}{2^n} = \frac{2}{2^n}$, and by the Born rule the
first register collapses to the renormalized sum of exactly those two
surviving branches:

$$\frac{\frac{1}{\sqrt{2^n}}|x_0\rangle + \frac{1}{\sqrt{2^n}}|x_0\oplus s\rangle}{\sqrt{2/2^n}} = \frac{1}{\sqrt2}\big(|x_0\rangle + |x_0\oplus s\rangle\big).$$

Now apply $H^{\otimes n}$ to this and use the Hadamard-transform identity
on each term:

$$H^{\otimes n}\cdot\frac{1}{\sqrt2}\big(|x_0\rangle+|x_0\oplus s\rangle\big) = \frac{1}{\sqrt2}\cdot\frac{1}{\sqrt{2^n}}\sum_y\Big[(-1)^{x_0\cdot y} + (-1)^{(x_0\oplus s)\cdot y}\Big]|y\rangle.$$

Since $(x_0\oplus s)\cdot y = x_0\cdot y \oplus s\cdot y \pmod2$ by
bilinearity, $(-1)^{(x_0\oplus s)\cdot y} = (-1)^{x_0\cdot y}(-1)^{s\cdot
y}$, so the bracket factors as

$$(-1)^{x_0\cdot y}\big[1 + (-1)^{s\cdot y}\big] = \begin{cases}2\cdot(-1)^{x_0\cdot y} & s\cdot y \equiv 0 \pmod2\\ 0 & s\cdot y \equiv 1 \pmod2.\end{cases}$$

So the final amplitude on $|y\rangle$ is nonzero **only** for $y$ satisfying
$y\cdot s \equiv 0 \pmod 2$ — exactly half of all $2^n$ strings (the
$s^\perp$ subspace has dimension $n-1$, i.e. $2^{n-1}$ elements), and among
those, every amplitude has the same magnitude (up to the sign
$(-1)^{x_0\cdot y}$), so measuring gives a *uniformly random* $y$ from that
set. A single run therefore yields one random linear equation $y\cdot
s\equiv0$ about $s$; running the circuit repeatedly and collecting $n-1$
*independent* such $y$'s pins $s$ down uniquely up to the trivial all-zero
solution (which is always a solution of a homogeneous system, but is
excluded by the promise $s\ne0^n$) — recovering $s$ then becomes a linear
algebra problem over $\mathbb{F}_2 = \{0,1\}$ with mod-2 arithmetic, solved
by Gaussian elimination exactly as over $\mathbb{R}$, except every "$-1$"
is replaced by "$+1$" (since $-1\equiv1\pmod2$) and every division is by
$1$ (the only nonzero element of $\mathbb{F}_2$).

### Unifying view

Deutsch–Jozsa, Bernstein–Vazirani, and Simon's algorithm are all the same
circuit *shape* — prepare a uniform superposition with $H^{\otimes n}$,
extract hidden structure with one oracle call, apply $H^{\otimes n}$ again,
and read out the resulting interference pattern by measurement — pointed
at oracles that hide progressively richer structure. DJ's oracle hides a
single global bit (constant vs. balanced), extracted via phase kickback and
read out as "is all the amplitude on $|0\rangle^{\otimes n}$, or none of
it." BV's oracle hides an entire linear functional $a\cdot x$, extracted
via the identical phase-kickback mechanism, and the second Hadamard layer
concentrates *all* the amplitude onto the single basis state $|a\rangle$ —
reading off every bit of the hidden string in one shot with certainty.
Simon's oracle hides something combinatorially richer still — an
exactly-2-to-1 pairing structure — which cannot be phase-kicked back with a
single ancilla qubit (the output isn't one bit), so the schema is adapted:
a genuine value oracle into a second register, an intermediate measurement
that collapses the first register onto a two-term superposition
$\frac{1}{\sqrt2}(|x\rangle+|x\oplus s\rangle)$, and only *then* the same
second Hadamard layer, which no longer concentrates onto a single basis
state but instead onto a uniformly random $y$ constrained by $y\cdot
s\equiv0$. In every case the underlying engine is the same parity-sum
orthogonality lemma proved above — it is what forces amplitude to
concentrate on (DJ, BV) or be constrained to a subspace around (Simon) the
oracle's hidden data — and the amount of information recovered per run
(all of it, exactly, for BV; one random linear bit of it, for Simon)
tracks exactly how much hidden structure the oracle's promise encodes.

## Worked example

**Bernstein–Vazirani for $n=3$, $a=101$ (i.e. $a_2a_1a_0 = 1,0,1$), traced
state by state.**

Since $a_1=0$, $a\cdot x = x_2\oplus x_0$ (only bits $2$ and $0$ of $x$
contribute). Signs $(-1)^{a\cdot x}$ for every $x_2x_1x_0$:

| $x$ | $x_2\oplus x_0$ | $(-1)^{a\cdot x}$ |
|---|---|---|
| 000 | 0 | $+1$ |
| 001 | 1 | $-1$ |
| 010 | 0 | $+1$ |
| 011 | 1 | $-1$ |
| 100 | 1 | $-1$ |
| 101 | 0 | $+1$ |
| 110 | 1 | $-1$ |
| 111 | 0 | $+1$ |

**Stage 0.** $|000\rangle\otimes|1\rangle$.

**Stage 1 (after $H^{\otimes3}$ on the data register, $H$ on the
ancilla).**

$$\frac{1}{\sqrt8}\big(|000\rangle+|001\rangle+\cdots+|111\rangle\big)\otimes|-\rangle.$$

**Stage 2 (after one oracle query — phase kickback using the table
above).**

$$\frac{1}{\sqrt8}\Big[|000\rangle-|001\rangle+|010\rangle-|011\rangle-|100\rangle+|101\rangle-|110\rangle+|111\rangle\Big]\otimes|-\rangle.$$

**Stage 3 (after the second $H^{\otimes3}$ on the data register).** By the
general derivation above, this must equal $|101\rangle$ exactly. Check it
directly on two basis states using $\text{amp}(y) = \frac{1}{8}\sum_x
(-1)^{a\cdot x}(-1)^{x\cdot y} = \frac{1}{8}\sum_x(-1)^{x\cdot(a\oplus y)}$:

- $y=101=a$: $a\oplus y = 000$, so every term in the sum is $(-1)^0=1$;
  the sum is $8$, giving $\text{amp}(101) = 8/8 = 1$.
- $y=000$: $a\oplus y = 101 \ne 0$, so by the orthogonality lemma the sum
  is $0$, giving $\text{amp}(000)=0$. (Directly: $x\cdot101 = x_2\oplus
  x_0$, which is exactly the sign pattern tabulated above — four $+1$'s and
  four $-1$'s, summing to $0$.)

The same cancellation happens for every $y\ne101$, by the orthogonality
lemma applied to $z=a\oplus y\ne0$. So Stage 3 is exactly $|101\rangle
\otimes|-\rangle$.

**Stage 4 (measurement).** Measuring the data register returns $101$ with
probability $1$ — the hidden string $a=101$ is recovered exactly, in a
single oracle query, with no possibility of error.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Redo the general Bernstein–Vazirani derivation from scratch: starting
   from $H^{\otimes n}|0\rangle^{\otimes n} = \frac{1}{\sqrt{2^n}}\sum_x
   |x\rangle$, apply phase kickback for $f(x)=a\cdot x$, then apply
   $H^{\otimes n}$ again and use the parity-orthogonality lemma to show the
   result is exactly $|a\rangle$. Be explicit about where the identity
   $H^{\otimes n}|x\rangle=\frac{1}{\sqrt{2^n}}\sum_y(-1)^{x\cdot y}|y\rangle$
   is used, and where $(-1)^{a\cdot x}(-1)^{x\cdot y}=(-1)^{x\cdot(a\oplus
   y)}$ is used.
2. Trace the exact state at every stage (as in the Worked example) for
   $n=3$, $a=110$. Tabulate $(-1)^{a\cdot x}$ for all 8 values of $x$, write
   the state after the oracle call, and confirm the final measurement
   outcome is $110$ with certainty.
3. Explain, in your own words, why Simon's promise ("$f$ is exactly 2-to-1
   with $f(x)=f(x\oplus s)$ for a hidden $s\ne0$") is strictly stronger
   than Deutsch–Jozsa's promise ("$f$ is constant or exactly balanced"),
   referencing what a bounded-error classical algorithm would need to do to
   verify each promise and how many queries that takes.
4. Sketch the argument for why measuring the second register after one
   Simon oracle query collapses the first register to $\frac{1}{\sqrt2}
   (|x_0\rangle+|x_0\oplus s\rangle)$ for the observed second-register
   value, and then derive why applying $H^{\otimes n}$ to that collapsed
   state leaves nonzero amplitude only on strings $y$ with $y\cdot
   s\equiv0\pmod2$.
5. Let $s = 1010$ (so $n=4$). Construct three concrete vectors
   $y_1,y_2,y_3\in\{0,1\}^4$, linearly independent over $\mathbb{F}_2$, each
   satisfying $y_i\cdot s\equiv0\pmod2$ — verify each one directly. Then set
   up the homogeneous linear system $y_i\cdot s' = 0$ (unknowns
   $s'=(s_1,s_2,s_3,s_4)$) and solve it by Gaussian elimination over
   $\mathbb{F}_2$, showing every row-reduction step explicitly. Confirm the
   unique nonzero solution is $s'=1010$.
6. Write one paragraph explaining how Deutsch–Jozsa, Bernstein–Vazirani,
   and Simon's algorithm are all "the same circuit" (Hadamard — oracle
   phase-kickback/value-query — Hadamard) applied to oracles hiding
   different kinds of structure, and how much information about that
   hidden structure each one's measurement reveals per run.

## Solutions

**1.** Start from the input state $|0\rangle^{\otimes n}$ and apply
$H^{\otimes n}$, using the Hadamard-transform identity with $x=0^{\otimes
n}$: $H^{\otimes n}|0\rangle^{\otimes n} = \frac{1}{\sqrt{2^n}}\sum_x
(-1)^{0\cdot x}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_x|x\rangle$ (first use
of the identity). One oracle query with phase kickback multiplies every
term by $(-1)^{f(x)}=(-1)^{a\cdot x}$, giving $\frac{1}{\sqrt{2^n}}\sum_x
(-1)^{a\cdot x}|x\rangle$. Apply $H^{\otimes n}$ again, this time expanding
each $|x\rangle$ via the identity (second use):

$$H^{\otimes n}\!\left[\frac1{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}|x\rangle\right] = \frac1{2^n}\sum_x(-1)^{a\cdot x}\sum_y(-1)^{x\cdot y}|y\rangle = \frac1{2^n}\sum_y\left[\sum_x(-1)^{a\cdot x}(-1)^{x\cdot y}\right]|y\rangle.$$

Using $a\cdot x\oplus x\cdot y = x\cdot(a\oplus y)\pmod2$ (bilinearity of
the mod-2 dot product, distributing $x\cdot(\cdot)$ over $\oplus$), the
inner sum is $\sum_x(-1)^{x\cdot(a\oplus y)}$, which by the
parity-orthogonality lemma equals $2^n$ if $y=a$ and $0$ otherwise. So the
whole sum collapses to $\frac1{2^n}\cdot2^n|a\rangle = |a\rangle$ exactly.

**2.** $a=110$: $a_2=1,a_1=1,a_0=0$, so $a\cdot x = x_2\oplus x_1$.

| $x$ | $x_2\oplus x_1$ | $(-1)^{a\cdot x}$ |
|---|---|---|
| 000 | 0 | $+1$ |
| 001 | 0 | $+1$ |
| 010 | 1 | $-1$ |
| 011 | 1 | $-1$ |
| 100 | 1 | $-1$ |
| 101 | 1 | $-1$ |
| 110 | 0 | $+1$ |
| 111 | 0 | $+1$ |

Stage 0: $|000\rangle|1\rangle$. Stage 1 (after $H^{\otimes3}$, $H$):
$\frac{1}{\sqrt8}\sum_x|x\rangle\otimes|-\rangle$. Stage 2 (after the
oracle, using the table): $\frac{1}{\sqrt8}\big[|000\rangle+|001\rangle
-|010\rangle-|011\rangle-|100\rangle-|101\rangle+|110\rangle+|111\rangle
\big]\otimes|-\rangle$. Stage 3 (after the second $H^{\otimes3}$): by
Solution 1's general result this is exactly $|110\rangle\otimes|-\rangle$.
Direct check: $\text{amp}(110) = \frac18\sum_x(-1)^{x\cdot(a\oplus
110)}=\frac18\sum_x(-1)^{x\cdot0}=\frac{8}{8}=1$; for any $y\ne110$,
$a\oplus y\ne0$ so the orthogonality lemma forces $\text{amp}(y)=0$. Stage
4: measuring returns $110$ with probability $1$.

**3.** DJ's promise is a two-way global classification (constant vs.
balanced). By Day 2's Chernoff-bound argument, a classical randomized
algorithm resolves this with error $\le2^{-k}$ using only $O(k)$ queries —
$O(1)$ queries already give a fixed constant confidence, with no
dependence on $n$; the quantum advantage there is going from
"bounded-error, few queries" to "zero-error, one query," not from
"impossible" to "possible." Simon's promise instead hides a specific value
$s$ out of $2^n-1$ candidates, detectable classically only by observing an
actual collision $f(x)=f(x\oplus s)$ between two queried points. Since
collisions occur only between an input and one specific partner
($x\oplus s$) out of $2^n-1$ other possible query points, a
birthday-paradox argument shows random queries need $\Omega(2^{n/2})$ tries
before a collision even *appears*, let alone confirms $s$ — an exponential
classical lower bound that holds even with randomization and bounded
error. This is qualitatively different from DJ's promise: Simon's promise
provably forces exponentially many classical queries, whereas DJ's promise
never did once bounded error was allowed.

**4.** After $H^{\otimes n}$ and one oracle query, the joint state is
$\frac{1}{\sqrt{2^n}}\sum_x|x\rangle|f(x)\rangle$. Because $f$ is exactly
2-to-1 with period $s$, every value $z$ in $f$'s range is produced by
exactly two inputs, $x_0$ and $x_0\oplus s$; each contributes amplitude
$\frac{1}{\sqrt{2^n}}$ to the joint state. Measuring the second register
and observing $z$ projects onto exactly those two terms and renormalizes
(dividing by the square root of their combined probability
$\frac2{2^n}$), leaving the first register in $\frac{1}{\sqrt2}
(|x_0\rangle+|x_0\oplus s\rangle)$. Applying $H^{\otimes n}$ and expanding
both terms via the Hadamard identity gives amplitude on $|y\rangle$
proportional to $(-1)^{x_0\cdot y}+(-1)^{(x_0\oplus s)\cdot y} =
(-1)^{x_0\cdot y}\big[1+(-1)^{s\cdot y}\big]$ (using $(x_0\oplus s)\cdot y
= x_0\cdot y\oplus s\cdot y$). The bracket is $2$ when $s\cdot
y\equiv0\pmod2$ and $0$ when $s\cdot y\equiv1\pmod2$, so only strings $y$
orthogonal to $s$ (mod 2) survive with nonzero amplitude.

**5.** Choose $y_1=0100$, $y_2=0001$, $y_3=1110$. Verify each against
$s=1010$ (dot product mod 2, componentwise):
$y_1\cdot s = 0\cdot1+1\cdot0+0\cdot1+0\cdot0=0$;
$y_2\cdot s = 0\cdot1+0\cdot0+0\cdot1+1\cdot0=0$;
$y_3\cdot s = 1\cdot1+1\cdot0+1\cdot1+0\cdot0=1+0+1+0=2\equiv0\pmod2$. All
three check out. They are linearly independent over $\mathbb{F}_2$: $y_1$
is the only one with a $1$ in position 2, $y_2$ is the only one with a $1$
in position 4, and $y_3$ has a $1$ in position 1 that neither of the
others has — three rows with distinct "leading" pivot positions are
automatically independent.

Set up the homogeneous system for unknown $s'=(s_1,s_2,s_3,s_4)$, rows
= $y_1,y_2,y_3$ (augmented column all zero):

$$\begin{array}{cccc|c} 0&1&0&0&0\\ 0&0&0&1&0\\ 1&1&1&0&0 \end{array}$$

Gaussian elimination over $\mathbb{F}_2$ (row operations use XOR instead of
subtraction, since $-1\equiv1$):

*Step 1 — get a pivot in column 1.* Rows 1 and 2 have a $0$ there; row 3
has a $1$. Swap row 1 and row 3:

$$\begin{array}{cccc|c} 1&1&1&0&0\\ 0&0&0&1&0\\ 0&1&0&0&0 \end{array}$$

*Step 2 — get a pivot in column 2.* Row 2 has a $0$ there, row 3 has a
$1$. Swap row 2 and row 3:

$$\begin{array}{cccc|c} 1&1&1&0&0\\ 0&1&0&0&0\\ 0&0&0&1&0 \end{array}$$

*Step 3 — clear column 2 above the new pivot.* Row 1 has a $1$ in column
2; replace row 1 with row 1 XOR row 2: $(1\oplus0,\ 1\oplus1,\ 1\oplus0,\
0\oplus0) = (1,0,1,0)$:

$$\begin{array}{cccc|c} 1&0&1&0&0\\ 0&1&0&0&0\\ 0&0&0&1&0 \end{array}$$

This is reduced row-echelon form, with pivots in columns 1, 2, 4 and column
3 free. Reading off the equations: row 1 gives $s_1\oplus s_3=0$, i.e.
$s_1=s_3$; row 2 gives $s_2=0$; row 3 gives $s_4=0$. Let $s_3=t$ be the free
parameter; then $s_1=t$, $s_2=0$, $s_4=0$, for $t\in\{0,1\}$. $t=0$ gives
the trivial all-zero solution (always present for a homogeneous system,
but excluded by Simon's promise $s\ne0^n$); $t=1$ gives the unique nonzero
solution

$$s' = (1,0,1,0) = 1010,$$

exactly recovering the hidden $s$. In general, an $n$-bit $s$ needs $n-1$
independent samples of this kind: an $(n-1)$-row system with rank $n-1$
has a null space of dimension exactly $1$, spanned by $s$ itself, so its
only two solutions are $0^n$ and $s$ — the promise's exclusion of $0^n$
then pins $s$ down uniquely.

**6.** Deutsch–Jozsa, Bernstein–Vazirani, and Simon's algorithm all follow
the same circuit shape: use $H^{\otimes n}$ to spread the input register
into a uniform superposition, extract information about a hidden oracle
using exactly one query, apply $H^{\otimes n}$ again, and read off the
resulting interference pattern by measurement. What differs is only the
richness of the hidden structure and, correspondingly, how much of it one
run reveals. DJ's oracle hides a single global bit (constant or balanced)
and, via phase kickback, the second Hadamard layer either puts all
amplitude on $|0\rangle^{\otimes n}$ or none of it — one run answers a
one-bit question with certainty. BV's oracle hides an entire hidden vector
$a$ via the linear function $a\cdot x$; the identical phase-kickback
mechanism and second Hadamard layer now concentrate all amplitude onto the
single state $|a\rangle$ — one run reveals all $n$ bits of $a$ at once,
with certainty. Simon's oracle hides a combinatorially richer object (a
2-to-1 pairing determined by $s$) that can't be phase-kicked back with a
single-qubit ancilla, so the schema is adapted with a genuine value oracle
into a second register and an intermediate measurement — and the same
final Hadamard layer, instead of concentrating on one basis state, spreads
uniformly over the exponentially large set of $y$ with $y\cdot s\equiv0$,
so one run yields only one random linear bit of information about $s$,
requiring $n-1$ repeated runs plus classical Gaussian elimination over
$\mathbb{F}_2$ to finish the job. The common engine underneath all three is
the parity-orthogonality lemma: it is precisely what forces the
post-second-Hadamard amplitude to concentrate exactly on, or be confined to
a subspace determined by, whatever string the oracle encoded.

## Journal template

```
## Day 10 — Bernstein–Vazirani & Simon's algorithm
Key idea in my own words: ...
What confused me: ...
```
