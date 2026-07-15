# Day 12 — Grover's Optimality (BBBV) & Generalized Search

## Learning objectives

By the end of today you should be able to:
- State the Bennett–Bernstein–Brassard–Vazirani (BBBV) optimality theorem
  precisely, and explain what it does and does not prove about quantum
  search.
- Walk through the *structure* of the hybrid-argument proof sketch —
  correctly, and without overstating how much of the rigorous inequality
  chain it reconstructs.
- Derive the generalized amplitude-amplification rotation angle
  $\theta = 2\arcsin(\sqrt p)$ for an arbitrary state-preparation unitary
  $A$, by direct analogy with Day 11's derivation, and show Day 11's
  formula is the special case $A = H^{\otimes n}$.
- State the modified iteration count $k \approx \frac{\pi}{4}\sqrt{N/M}$ for
  known $M$, and know (without derivation) what changes when $M$ is
  unknown.

## Reference material

- Primer: Nielsen & Chuang, *Quantum Computation and Quantum Information*,
  or de Wolf's *Quantum Computing: Lecture Notes*, the sections covering the
  BBBV lower bound and generalized amplitude amplification.
- The theory below is self-contained — you do not need either text to do
  today's work, but reading the matching section alongside this is useful
  for a second explanation in different words, especially for the parts
  this file deliberately treats at sketch level (see below).

## Theory

### What's rigorous today, and what isn't

Today has two halves with genuinely different epistemic status, and it
matters that you know which is which:

- **Fully rigorous:** the rotation/geometric picture from Day 11 (recapped
  below) and today's generalization of it to an arbitrary state-preparation
  unitary $A$. Every step is a direct, checkable computation — reflections,
  inner products, trigonometric identities. You could reconstruct every line
  of it closed-book.
- **Sketch-level only:** the BBBV lower-bound proof (the hybrid argument).
  This is a genuinely hard result, and the full rigorous inequality chain —
  making "distinguishing power" precise as a variational-distance or
  amplitude bound, then chaining a probabilistic averaging argument over $N$
  oracles through $T$ queries — is beyond the scope of a 15-day survey
  course. What follows states the theorem precisely and explains the
  *structure* of the argument (which comparison is being made, why it
  bounds what it bounds), but it does not re-derive the exact constants or
  the full inequality chain. Treat the sketch as "here is why this kind of
  bound should exist and roughly how it's shaped," not as a proof you could
  reproduce from first principles. This is a deliberate scope boundary, not
  an oversight.

### Recap: the rotation picture (Day 11)

Day 11 set up the search problem in a real 2D subspace of the full $N$-
dimensional state space, spanned by $|good\rangle$ (uniform superposition
over the $M$ marked items) and $|bad\rangle$ (uniform superposition over
the $N-M$ unmarked items). The uniform starting state is
$$|s\rangle = \cos(\theta/2)|bad\rangle + \sin(\theta/2)|good\rangle,
\qquad \sin(\theta/2) = \sqrt{M/N}.$$
The oracle reflection $O_f = I - 2\sum_{x\text{ good}}|x\rangle\langle x|$
fixes $|bad\rangle$ and negates $|good\rangle$ — a reflection about the
$|bad\rangle$ axis within this subspace. The diffusion operator
$D = 2|s\rangle\langle s| - I$ reflects about $|s\rangle$. Composing two
reflections whose axes are separated by angle $\theta/2$ produces a
rotation by $\theta$, so each application of $D\cdot O_f$ rotates the
current state by $\theta$ toward $|good\rangle$. After $k$ iterations,
$$G^k|s\rangle = \cos\!\Big(\frac{(2k+1)\theta}{2}\Big)|bad\rangle +
\sin\!\Big(\frac{(2k+1)\theta}{2}\Big)|good\rangle,$$
so the probability of measuring a marked item is
$\sin^2\!\big((2k+1)\theta/2\big)$, maximized when $(2k+1)\theta/2$ is as
close as possible to $\pi/2$.

Everything in this recap is exact linear algebra — no approximation, no
averaging argument. It is the load-bearing rigorous result this whole
course treats Grover's algorithm as resting on.

### The BBBV optimality theorem

**Theorem (Bennett–Bernstein–Brassard–Vazirani, 1997).** Let $N = 2^n$, and
suppose a quantum algorithm is given oracle access to a function
$f:\{0,1\}^n\to\{0,1\}$ promised to have a *unique* marked item (i.e.
$f(x)=1$ for exactly one $x$, and $0$ elsewhere), with no other structure
assumed. If the algorithm makes $T$ queries to the oracle before measuring
and outputting a guess for the marked item, then its probability of
outputting the correct marked item is $O(T^2/N)$.

Equivalently: to achieve a success probability bounded away from $0$ by
some fixed constant (say, at least $1/2$), the algorithm needs
$$T = \Omega(\sqrt N)$$
queries. Since Grover's algorithm solves the same problem with
$O(\sqrt N)$ queries (Day 11), Grover's algorithm is optimal among
*all* quantum algorithms for this problem, up to constant factors — not
just optimal among algorithms built the way Grover's algorithm happens to
be built.

Two things worth being precise about, since the theorem is easy to
misstate: (1) it is a statement about *query complexity* — it says nothing
about classical time/space, and nothing about problems where the oracle has
extra exploitable structure (Grover's own generalization below assumes
nothing changes about the oracle, only about the search prior); (2) it
bounds the success probability of *any* $T$-query algorithm, not just
"Grover-shaped" ones — this is what makes it a genuine lower bound on the
problem, not merely a property of one particular algorithm.

### The hybrid-argument sketch

*(Flagged above as sketch-level — read this as "the shape of the argument," not a
reproducible proof.)*

The proof compares the algorithm's behavior across many different oracles.
Define $O_0$ to be the oracle with *no* marked item at all (the all-zero
function), and for each $i \in \{0,\dots,N-1\}$, define $O_i$ to be the
oracle marking item $i$ alone. The algorithm doesn't know in advance which
oracle it's facing — it must be built to work for every $O_i$ simultaneously
(and to behave sensibly on $O_0$, since that's a legitimate input too).

The key move: run the *same* algorithm against $O_0$ and separately against
each $O_i$, and track how far its internal quantum state after $t$ queries
against $O_i$ has diverged from its state after $t$ queries against $O_0$.
A single query can only touch the oracle's answer on the one input the
algorithm currently has amplitude on; since the algorithm's state just
before the query is spread out over many of the $N$ possible inputs (it has
no way to concentrate on the "right" one — it hasn't seen $O_i$ yet), the
amount that one query can *possibly* shift the state toward "the version
that has seen evidence of item $i$," averaged over which $i$ is the true
marked item, is small — the sketch's claim is that each query moves this
averaged divergence by at most $O(1/\sqrt N)$.

Summing (via a triangle-inequality bound: divergences from individual steps
add, they don't cancel or compound multiplicatively) over $T$ queries gives
a total accumulated divergence of $O(T/\sqrt N)$. Since a measurement's
ability to distinguish "this is $O_i$" from "this is $O_0$" is governed by
how far apart the corresponding *quantum states* are, and success
probability is related to the *square* of that distinguishing amplitude
(the Born rule again — probabilities are squared amplitudes), the
achievable success probability after $T$ queries is
$$O\big((T/\sqrt N)^2\big) = O(T^2/N).$$
Setting this $\ge$ some constant forces $T = \Omega(\sqrt N)$.

What this sketch does *not* do, and what a full treatment (Nielsen & Chuang
or the original BBBV paper) would supply: the precise definition of
"divergence" being bounded (typically a sum-of-squared-amplitude-shift
quantity), the exact per-query bound with its constant, and the careful
triangle-inequality bookkeeping that turns "each step contributes
$O(1/\sqrt N)$" into a rigorous sum rather than a hand-wave. That chain is
the part this course treats as out of scope.

### Generalized amplitude amplification

Day 11's construction used one specific state-preparation unitary,
$A = H^{\otimes n}$, to build the uniform starting state $|s\rangle =
A|0\rangle^{\otimes n}$. Nothing in the rotation argument actually required
$A$ to be $H^{\otimes n}$, or the resulting split between "good" and "bad"
amplitude to be $M/N$. Replace $A$ with an arbitrary unitary satisfying
$$A|0\rangle = \sqrt p\,|good\rangle + \sqrt{1-p}\,|bad\rangle$$
for some $p \in (0,1]$ — $A$ prepares a state with "prior probability" $p$
of being good, not necessarily the uniform $M/N$.

**Deriving $\theta$, by direct analogy with Day 11.** Day 11 parametrized
$|s\rangle$ as $\cos(\theta/2)|bad\rangle + \sin(\theta/2)|good\rangle$ with
$\sin(\theta/2) = \sqrt{M/N}$. Apply exactly the same parametrization to
$A|0\rangle$: since $A|0\rangle$ is a unit vector in the real 2D subspace
spanned by $|good\rangle,|bad\rangle$ (a unit vector because
$|\sqrt p|^2 + |\sqrt{1-p}|^2 = p + (1-p) = 1$, and real/orthogonal exactly
as $|good\rangle,|bad\rangle$ were in Day 11), it can equally be written as
$$A|0\rangle = \cos(\theta/2)|bad\rangle + \sin(\theta/2)|good\rangle$$
for some angle $\theta$. Matching coefficients against the given form
$A|0\rangle = \sqrt p\,|good\rangle + \sqrt{1-p}\,|bad\rangle$ term by term:
$$\cos(\theta/2) = \sqrt{1-p}, \qquad \sin(\theta/2) = \sqrt p.$$
The second equation gives
$$\theta = 2\arcsin(\sqrt p).$$
(The first equation is consistent with this, since
$\cos(\theta/2) = \sqrt{1-\sin^2(\theta/2)} = \sqrt{1-p}$ automatically once
$\sin(\theta/2)=\sqrt p$ — the parametrization only has one free angle, so
one matched coefficient already determines $\theta$; the other is a
consistency check.) Setting $A = H^{\otimes n}$ and $p = M/N$ recovers
Day 11's $\sin(\theta/2) = \sqrt{M/N}$ exactly — Day 11 is the special case
of this derivation with a uniform prior.

**The reflections generalize too, by the same replacement.** The oracle
reflection $O_f = I - 2\sum_{x\text{ good}}|x\rangle\langle x|$ is unchanged
— it depends only on which items are marked, not on how the starting state
was prepared — so it still fixes $|bad\rangle$ and negates $|good\rangle$,
i.e. it is still the reflection about the $|bad\rangle$ axis. Day 11's
diffusion operator $D = 2|s\rangle\langle s| - I$ generalizes to
$$D_A = 2A|0\rangle\langle0|A^\dagger - I = 2\,(A|0\rangle)(A|0\rangle)^\dagger - I,$$
which is exactly the reflection-about-a-unit-vector formula $2|v\rangle
\langle v| - I$, applied to the unit vector $v = A|0\rangle$ instead of
$v=|s\rangle$ — the identity "$2|v\rangle\langle v|-I$ reflects about $v$"
holds for *any* unit vector $v$, so $D_A$ reflects about $A|0\rangle$ for
exactly the reason $D$ reflected about $|s\rangle$ in Day 11; nothing about
that fact depended on $|s\rangle$ specifically being uniform. Composing
$O_f$ then $D_A$ is therefore a composition of two reflections at angle
$\theta/2$ apart (the angle between the $|bad\rangle$ axis and $A|0\rangle$)
— by the same rotation-composition fact used in Day 11, $G_A = D_A O_f$
rotates by $\theta = 2\arcsin(\sqrt p)$ per application, and
$$G_A^k A|0\rangle = \cos\!\Big(\frac{(2k+1)\theta}{2}\Big)|bad\rangle +
\sin\!\Big(\frac{(2k+1)\theta}{2}\Big)|good\rangle,$$
identical in form to Day 11's result with $A|0\rangle$ in place of
$|s\rangle$. This is "generalized amplitude amplification": the entire
Grover machinery works verbatim for any state-preparation unitary and any
prior $p$, not only the uniform one.

### The modified iteration count

The success probability after $k$ rotations is $\sin^2\big((2k+1)\theta/2
\big)$, maximized when $(2k+1)\theta/2$ is as close as possible to
$\pi/2$, i.e. at
$$k^\star \approx \frac{\pi}{2\theta} - \frac12.$$
For the standard search setting ($p = M/N$ with $M \ll N$), $\theta =
2\arcsin(\sqrt{M/N}) \approx 2\sqrt{M/N}$ (small-angle approximation,
valid when $M/N$ is small), so
$$k^\star \approx \frac{\pi}{4\sqrt{M/N}} - \frac12 \approx
\frac{\pi}{4}\sqrt{\frac{N}{M}}.$$
This is the standard heuristic iteration count for known $M$: run
$k \approx \frac{\pi}{4}\sqrt{N/M}$ iterations of $D_A O_f$ (with
$A = H^{\otimes n}$) and measure. It is an $O(1)$-accurate approximation to
the true peak $k^\star$ — good enough to guarantee $\Theta(1)$ success
probability, but (see the worked example and exercises below) not always
exactly the nearest integer to the true continuous peak, since it drops
the $-\tfrac12$ term and uses the small-angle approximation for $\theta$.

**If $M$ is unknown** (no derivation — this is a forward pointer only): the
formula above needs $M$ as an input, so an unknown $M$ means either (a)
first estimating $M$ via a separate procedure such as *quantum counting*
(a phase-estimation-based technique, previewed conceptually here and
properly built on the Quantum Fourier Transform machinery of Days 13–14),
or (b) sidestepping the estimate entirely with an adaptive/exponential
schedule — try increasing guessed iteration counts (e.g. doubling:
$1,2,4,8,\dots$) and check after each whether the oracle reports success,
which achieves expected query complexity $O(\sqrt{N/M})$ without ever
knowing $M$ in advance. Both are named here only as pointers to what exists
beyond today's derivation.

## Worked example

**Claim:** the generalized amplitude-amplification formula reduces exactly
to Day 11's formula for $A = H^{\otimes n}$, and the resulting optimal
iteration count is consistent with (saturates the order of) the BBBV lower
bound.

Take $N = 64$, $M = 1$ (a uniquely marked item, exactly the BBBV setting).
Then $p = M/N = 1/64$, and by the derivation above,
$$\theta = 2\arcsin(\sqrt{1/64}) = 2\arcsin(1/8) \approx 2(0.125328) =
0.250656 \text{ rad},$$
matching Day 11's formula $\sin(\theta/2) = \sqrt{M/N} = 1/8$ exactly, as it
must, since $H^{\otimes n}|0\rangle^{\otimes n}$ is precisely the uniform
$|s\rangle$ of Day 11.

The exact peak iteration count is
$$k^\star \approx \frac{\pi}{2\theta} - \frac12 =
\frac{3.14159}{0.501311} - 0.5 \approx 6.268 - 0.5 = 5.768,$$
which rounds to $k=6$; the heuristic $\frac{\pi}{4}\sqrt{N/M} =
\frac{\pi}{4}\cdot 8 \approx 6.283$ also rounds to $k=6$ — the two agree
here. Checking neighboring integers directly, with $\theta/2 = 0.125328$:

| $k$ | $(2k+1)\theta/2$ (rad) | $\sin^2(\cdot)$ |
|---|---|---|
| 5 | 1.37861 | 0.9635 |
| 6 | 1.62926 | 0.9966 |
| 7 | 1.87992 | 0.9076 |

$k=6$ is indeed the peak, with success probability $\approx 0.997$ —
essentially certain detection of the marked item.

Now cross-check against BBBV: $T=6$ queries is $\Theta(\sqrt N) =
\Theta(\sqrt{64}) = \Theta(8)$ — the same order the lower bound says is
*necessary* for constant success probability. Grover's algorithm, using
$T=6\approx\sqrt{64}$ queries, achieves success probability $\approx0.997$,
i.e. $\Theta(1)$ — exactly the order the BBBV bound $O(T^2/N)$ permits at
$T=\Theta(\sqrt N)$ (plug in $T=8$: $T^2/N = 64/64 = 1$, an $O(1)$ ceiling,
which Grover's actual $\approx1$ success probability sits right up against).
So the BBBV theorem isn't merely "not violated" here — Grover's algorithm
sits at the exact order the theorem says is the best *any* algorithm could
achieve, confirming that Grover's algorithm doesn't just solve the problem,
it solves it optimally up to constant factors.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. State the BBBV theorem precisely: what is being bounded (as a function
   of what), what promise on $f$ is assumed, and what asymptotic
   consequence for $T$ follows from demanding constant success
   probability?
2. In your own words, explain the hybrid-argument setup: what are $O_0$ and
   $O_i$, and why does bounding how much a *single* query can shift the
   algorithm's state — averaged over which $i$ is the true marked item,
   since the algorithm cannot know this in advance — give a way to bound
   how fast the algorithm's behavior against $O_i$ can diverge from its
   behavior against $O_0$?
3. Taking as given (not to be re-derived — this is the sketch's stated
   premise) that each query changes the accumulated distinguishing power by
   at most $O(1/\sqrt N)$ on average, derive: (a) the total accumulated
   divergence after $T$ queries, (b) the resulting bound on success
   probability (recall probability scales as the *square* of a
   distinguishing amplitude), and (c) the asymptotic lower bound on $T$
   needed for constant success probability.
4. Sanity-check the BBBV bound at $T=1$: plug $T=1$ into $O(T^2/N)$ and
   compare its order of magnitude to the success probability of the
   trivial classical strategy "guess one item at random and hope it's
   marked." Explain why this consistency check, though far from a proof,
   is a reasonable thing to verify before trusting the general bound.
5. For a state-preparation unitary $A$ with $A|0\rangle =
   \sqrt p\,|good\rangle + \sqrt{1-p}\,|bad\rangle$, derive $\theta =
   2\arcsin(\sqrt p)$ by writing $A|0\rangle$ in the
   $\cos(\theta/2)|bad\rangle+\sin(\theta/2)|good\rangle$ parametrization
   and matching coefficients. Show this reduces to Day 11's
   $\sin(\theta/2)=\sqrt{M/N}$ when $A = H^{\otimes n}$ and $p=M/N$.
6. Show that $D_A = 2A|0\rangle\langle0|A^\dagger - I$ reflects about
   $A|0\rangle$ within the 2D $\{|good\rangle,|bad\rangle\}$ subspace (cite
   the general "$2|v\rangle\langle v|-I$ reflects about unit vector $v$"
   fact), and explain why composing $O_f$ then $D_A$ is therefore a
   rotation by $\theta$, exactly as in Day 11.
7. Derive the modified iteration count $k\approx\frac\pi4\sqrt{N/M}$ for
   known $M$ from the peak condition $(2k+1)\theta/2\approx\pi/2$ together
   with the small-angle approximation $\theta\approx2\sqrt{M/N}$ (valid for
   $M\ll N$). Which two approximations does this heuristic make relative to
   the exact peak $k^\star = \frac{\pi}{2\theta}-\frac12$?
8. For $N=100$, $M=1$: compute $\theta$ exactly (leave in terms of
   $\arcsin$, then evaluate numerically), compute the heuristic $k =
   \frac\pi4\sqrt{N/M}$ and round it to the nearest integer, and separately
   compute the exact success probability $\sin^2\big((2k+1)\theta/2\big)$
   at $k=7$ and at $k=8$. Which integer actually gives the higher success
   probability, and does it match the rounded heuristic?
9. In one sentence each, state the two remedies mentioned (without
   derivation) for the case where $M$ is unknown.

## Solutions

**1.** For a quantum algorithm making $T$ oracle queries to a function
$f:\{0,1\}^n\to\{0,1\}$ promised to have a unique marked input among
$N=2^n$, the probability that the algorithm's final measurement correctly
outputs the marked item is $O(T^2/N)$. Demanding this probability be
bounded away from $0$ by a fixed constant forces $T = \Omega(\sqrt N)$ —
i.e. no quantum algorithm, of any design, can solve unstructured search
with asymptotically fewer than $\Theta(\sqrt N)$ queries, so Grover's
$O(\sqrt N)$-query algorithm is optimal up to constant factors.

**2.** $O_0$ is the oracle that marks nothing (the all-$0$ function); $O_i$
is the oracle marking exactly item $i$. Because the algorithm must work
correctly no matter which $i$ is the hidden marked item (it has no prior
information distinguishing one $i$ from another), its behavior against
$O_i$ can only start to differ from its behavior against $O_0$ once its
queries have actually "touched" evidence about item $i$ specifically. Since
before any such evidence arrives the algorithm's state is necessarily
spread across many candidate items (it has nothing yet to concentrate its
amplitude on), a single query's ability to shift the state toward
"looks like $O_i$" is small when averaged over all $i$ — and summing these
small per-query shifts over $T$ queries bounds how far the $O_i$-trajectory
can have wandered from the $O_0$-trajectory by query $T$, which in turn
bounds how confidently a final measurement can tell $O_i$ apart from $O_0$
(and hence identify $i$).

**3.** (a) If each of $T$ queries contributes at most $O(1/\sqrt N)$ to the
accumulated divergence, and divergences from successive queries add via a
triangle-inequality bound rather than canceling, the total divergence after
$T$ queries is at most $T\cdot O(1/\sqrt N) = O(T/\sqrt N)$. (b) Success
probability is governed by the *square* of a distinguishing amplitude (Born
rule), so the achievable success probability is $O\big((T/\sqrt N)^2\big)
= O(T^2/N)$. (c) Setting $O(T^2/N) \ge c$ for a fixed constant $c>0$ gives
$T^2 = \Omega(N)$, i.e. $T = \Omega(\sqrt N)$. (Note, as flagged in the
Theory section: this derivation is legitimate algebra applied to the
sketch's *stated* premise — it is not a re-derivation of *why* the
per-query bound is $O(1/\sqrt N)$, which is the part left at sketch level.)

**4.** At $T=1$, $O(T^2/N) = O(1/N)$. The trivial classical strategy of
guessing one item uniformly at random succeeds with probability exactly
$1/N$. These match in order of magnitude — a single query (quantum or
classical) cannot do asymptotically better than blind guessing, which is
exactly what should be true, since one query reveals only one bit of
information about a needle hidden among $N$ haystacks and cannot
meaningfully narrow the search. This doesn't prove the general bound (a
single matching data point never proves a general theorem), but a bound
whose $T=1$ case *disagreed* with the obvious classical baseline would be
an immediate red flag that something in the statement was wrong — so
checking it costs little and rules out a class of errors.

**5.** Writing $A|0\rangle$ in the same real-2D-subspace parametrization
Day 11 used for $|s\rangle$: since $A|0\rangle$ is a unit vector in
$\text{span}\{|good\rangle,|bad\rangle\}$, it equals $\cos(\theta/2)
|bad\rangle+\sin(\theta/2)|good\rangle$ for some $\theta$. Matching this
against the given $A|0\rangle=\sqrt p|good\rangle+\sqrt{1-p}|bad\rangle$
coefficient-by-coefficient gives $\sin(\theta/2)=\sqrt p$ and
$\cos(\theta/2)=\sqrt{1-p}$ (mutually consistent, since $\sin^2+\cos^2=
p+(1-p)=1$). Solving the first for $\theta$: $\theta = 2\arcsin(\sqrt p)$.
Setting $A=H^{\otimes n}$, $A|0\rangle^{\otimes n}=|s\rangle$ and $p=M/N$
(by definition of $|good\rangle,|bad\rangle$ as uniform superpositions over
the $M$ marked and $N-M$ unmarked items), this becomes $\theta=
2\arcsin(\sqrt{M/N})$, i.e. $\sin(\theta/2)=\sqrt{M/N}$ — exactly Day 11's
formula.

**6.** For any unit vector $v$, $(2|v\rangle\langle v|-I)|v\rangle =
2|v\rangle-|v\rangle=|v\rangle$ (fixes $v$), and for any $w\perp v$,
$(2|v\rangle\langle v|-I)|w\rangle = 0-|w\rangle=-|w\rangle$ (negates the
orthogonal complement) — which is exactly the defining action of "reflect
about $v$." $D_A=2A|0\rangle\langle0|A^\dagger-I = 2|v\rangle\langle v|-I$
with $v=A|0\rangle$ is this same formula, so $D_A$ reflects about
$A|0\rangle$, for a reason that never referenced $A|0\rangle$ being
uniform. $O_f$ separately reflects about $|bad\rangle$ (unchanged from Day
11, since it depends only on which items are marked). The angle between
the $|bad\rangle$ axis and the $A|0\rangle$ axis is, by construction,
$\theta/2$ — so composing two reflections at angle $\theta/2$ apart gives a
rotation by $\theta$, by the same "composition of two reflections is a
rotation by twice the angle between their axes" fact Day 11 used, applied
verbatim with $A|0\rangle$ in place of $|s\rangle$.

**7.** The peak condition $(2k+1)\theta/2\approx\pi/2$ solves to $k\approx
\frac{\pi}{2\theta}-\frac12 = k^\star$. Substituting the small-angle
approximation $\theta\approx2\sqrt{M/N}$: $k\approx\frac{\pi}{2\cdot2
\sqrt{M/N}}-\frac12 = \frac{\pi}{4}\sqrt{N/M}-\frac12$. Dropping the
$-\frac12$ (justified only up to $O(1)$ additive error, i.e. it can shift
which integer is nearest by one) gives the commonly quoted heuristic
$k\approx\frac\pi4\sqrt{N/M}$. The two approximations made, in order: (i)
replacing the exact $\theta=2\arcsin(\sqrt{M/N})$ with its small-angle
approximation $2\sqrt{M/N}$ (accurate when $M\ll N$), and (ii) dropping the
additive $-\frac12$ term from the exact peak location. Both are $O(1)$-
scale approximations — fine for the asymptotic $\Theta(\sqrt{N/M})$ query
count, but, as Exercise 8 shows, not always enough to land on the exact
optimal *integer* iteration count.

**8.** $p=M/N=1/100$, $\sqrt p = 0.1$, so $\theta=2\arcsin(0.1)\approx
2(0.100167)=0.200335$ rad. Heuristic: $k\approx\frac\pi4\sqrt{100/1}=
\frac\pi4\cdot10\approx7.854$, which rounds to $k=8$. Checking the exact
success probability with $\theta/2=0.100167$:
- $k=7$: $(15)(0.100167)=1.502513$ rad; $\sin^2(1.502513)\approx0.99534$.
- $k=8$: $(17)(0.100167)=1.702847$ rad; $\sin^2(1.702847)\approx0.98266$.

$k=7$ gives the strictly higher success probability, not $k=8$ — the naive
rounding of the heuristic $\approx7.854\to8$ is actually one iteration past
the true optimum (consistent with the exact-peak formula $k^\star=
\frac{\pi}{2\theta}-\frac12\approx7.842-0.5=7.342$, which correctly rounds
to $k=7$). This confirms Exercise 7's point: the commonly quoted heuristic
is accurate to $O(1)$ but its naive nearest-integer rounding can miss the
true optimal iteration count by one — checking the neighboring integers
directly (as done here) is the reliable way to pin down the exact optimum
when it matters, and both are still $\gtrsim0.98$ success probability
regardless, so the practical cost of the off-by-one is small.

**9.** (a) If $M$ is unknown, it can first be estimated via *quantum
counting*, a phase-estimation-based procedure (built on machinery from
Days 13–14), and the estimate plugged into the known-$M$ formula. (b)
Alternatively, an adaptive/exponential schedule — trying geometrically
increasing guessed iteration counts (e.g. $1,2,4,8,\dots$) and checking for
success after each — finds a marked item in expected $O(\sqrt{N/M})$
queries without ever needing to know $M$ in advance.

## Journal template

```
## Day 12 — Grover's optimality (BBBV) & generalized search
Key idea in my own words: ...
What confused me: ...
```
