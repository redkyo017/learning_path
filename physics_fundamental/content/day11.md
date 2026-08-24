# Day 11 — Poisson Brackets and the Quantum Preview

*Read this day twice: once now, once after week 2 of your quantum computing
course, when commutators have appeared. It is designed to be better the
second time.*

## Learning objectives

By the end of today you should be able to:
- Define the Poisson bracket $\{f,g\}$ for phase-space functions and verify
  its antisymmetry, linearity, and Leibniz product rule directly from the
  definition.
- Derive the master evolution equation $\dot f=\{f,H\}$ from Hamilton's
  equations in four lines, and explain why it deserves the name "one
  bracket to rule all time evolution."
- Verify the canonical bracket $\{q,p\}=1$, and use vanishing brackets with
  $H$ to identify conserved quantities — redoing Day 4's momentum,
  angular-momentum, and energy results in exact bracket language.
- State the canonical-quantization dictionary
  $\{\cdot,\cdot\}\to\frac{1}{i\hbar}[\cdot,\cdot]$ and explain precisely
  what it does and does not establish.
- Explain why non-commuting operators are a natural, structure-preserving
  consequence of quantization rather than an ad hoc weirdness, and connect
  $[\hat q,\hat p]\ne0$ to the uncertainty principle (Day 17 closes this
  loop).
- Describe, at survey depth, why truncating a quantum system to two energy
  levels produces the $2\times2$ matrix structure of a qubit.

Time budget: ~3.5 hours.

## Reference material

- Goldstein, Poole & Safko, *Classical Mechanics* — the chapter on Poisson
  brackets and canonical transformations covers the same ground with more
  machinery (canonical transformations, generating functions) than today
  needs.
- Landau & Lifshitz, *Mechanics* — the short, famously dense section on
  Poisson brackets is the classic terse treatment of exactly today's
  material; good for a second, more compressed pass.
- Shankar, *Principles of Quantum Mechanics* — the opening chapters (the
  mathematical postulates of quantum mechanics, and the correspondence
  principle connecting them to classical mechanics) state today's
  dictionary from the quantum side; read alongside this day's second
  reading, after commutators have appeared in your course.
- This file is self-contained: everything below is derived, not assumed.
- Builds on Day 10's Hamiltonian $H(q,p)$, phase-space functions $f(q,p)$,
  and Hamilton's equations $\dot q=\partial H/\partial p$,
  $\dot p=-\partial H/\partial q$; and on Day 4's informal
  symmetry-conservation dictionary, which today restates in exact algebraic
  form.

## Theory

### A notation note before we start: two meanings of $L$

Days 9–11 use $L$ for the **Lagrangian**, stated explicitly in each of those
three files on first use — a deliberate, temporary override of $L$'s more
common meaning elsewhere in this course. Today's second worked example
needs the *z*-component of **angular momentum** (Day 4's $\vec
L=\vec r\times\vec p$), which would otherwise collide head-on with that
override. To avoid any ambiguity, today (and only today) writes angular
momentum's *z*-component as $L_z$ rather than a bare $L$; every appearance
of $L_z$ below means angular momentum, never the Lagrangian, and the
Lagrangian never appears again after this paragraph. From Day 12 onward,
$L$ reverts to its more common meaning, angular momentum.

### The Poisson bracket: definition

For two phase-space functions $f(q,p)$ and $g(q,p)$ built from a single
canonical pair $(q,p)$, define the **Poisson bracket**
$$\{f,g\} = \frac{\partial f}{\partial q}\frac{\partial g}{\partial p} - \frac{\partial f}{\partial p}\frac{\partial g}{\partial q}.$$
It takes two phase-space functions and returns a third phase-space
function, by combining their partial derivatives in the one antisymmetric
way available: "$f$'s $q$-sensitivity against $g$'s $p$-sensitivity, minus
the mirror-image term." For a system with several canonical pairs
$(q_i,p_i)$ — needed below for two-dimensional motion, where
$(q_1,q_2,p_1,p_2)=(x,y,p_x,p_y)$ — the definition generalizes by summing
over every pair:
$$\{f,g\} = \sum_i\left(\frac{\partial f}{\partial q_i}\frac{\partial g}{\partial p_i} - \frac{\partial f}{\partial p_i}\frac{\partial g}{\partial q_i}\right).$$
Everything proved below for one pair carries over term-by-term to the sum,
since each term is an independent copy of the single-pair structure.

### Algebraic properties, verified quickly

**Antisymmetry:** $\{f,g\}=-\{g,f\}$. Swapping $f\leftrightarrow g$ in the
definition swaps the two terms and their labels:
$$\{g,f\} = \frac{\partial g}{\partial q}\frac{\partial f}{\partial p} - \frac{\partial g}{\partial p}\frac{\partial f}{\partial q} = -\left(\frac{\partial f}{\partial q}\frac{\partial g}{\partial p} - \frac{\partial f}{\partial p}\frac{\partial g}{\partial q}\right) = -\{f,g\}.$$
Immediate corollary: $\{f,f\}=-\{f,f\}\implies\{f,f\}=0$ for any $f$ — a
fact used twice below ($\{q,q\}=\{p,p\}=0$ and $\{H,H\}=0$).

**Linearity in each argument:** for constants $\alpha,\beta$,
$\{\alpha f_1+\beta f_2,\,g\} = \alpha\{f_1,g\}+\beta\{f_2,g\}$, because
partial differentiation is itself linear — $\partial(\alpha f_1+\beta
f_2)/\partial q = \alpha\,\partial f_1/\partial q+\beta\,\partial
f_2/\partial q$, and likewise for $\partial/\partial p$; substitute into
the definition and the linear combination distributes term by term.
Linearity in the second slot follows from antisymmetry plus linearity in
the first slot.

**Leibniz product rule:** $\{f,gh\} = \{f,g\}h + g\{f,h\}$. Apply the
ordinary product rule to $\partial(gh)/\partial p$ and
$\partial(gh)/\partial q$ inside the definition:
$$\{f,gh\} = \frac{\partial f}{\partial q}\left(\frac{\partial g}{\partial p}h+g\frac{\partial h}{\partial p}\right) - \frac{\partial f}{\partial p}\left(\frac{\partial g}{\partial q}h+g\frac{\partial h}{\partial q}\right)$$
$$= h\left(\frac{\partial f}{\partial q}\frac{\partial g}{\partial p}-\frac{\partial f}{\partial p}\frac{\partial g}{\partial q}\right) + g\left(\frac{\partial f}{\partial q}\frac{\partial h}{\partial p}-\frac{\partial f}{\partial p}\frac{\partial h}{\partial q}\right) = h\{f,g\}+g\{f,h\}.$$
Written as $\{f,g\}h+g\{f,h\}$ this already has the exact shape the
operator commutator's product rule will have later today (the dictionary
section below, and Exercise 5) — nothing about the ordering was forced by
today's classical algebra alone, but the shape survives the transition
unchanged.

### The master equation: $\dot f=\{f,H\}$

For any phase-space function $f(q,p)$ with no explicit time dependence,
evaluated along an actual trajectory $q(t),p(t)$, the chain rule gives
$$\frac{df}{dt} = \frac{\partial f}{\partial q}\dot q + \frac{\partial f}{\partial p}\dot p.$$
Substitute Hamilton's equations $\dot q=\partial H/\partial p$,
$\dot p=-\partial H/\partial q$ (Day 10):
$$\frac{df}{dt} = \frac{\partial f}{\partial q}\frac{\partial H}{\partial p} - \frac{\partial f}{\partial p}\frac{\partial H}{\partial q}.$$
The right-hand side is exactly the definition of $\{f,H\}$. Hence
$$\boxed{\dot f = \{f,H\}}$$
— four lines, and it holds for *every* phase-space function $f$ at once:
position, momentum, energy, angular momentum, or any function you invent.
This is why it earns the name "one bracket to rule all time evolution" —
Hamilton's two separate equations for $\dot q$ and $\dot p$ are themselves
just the special cases $f=q$ and $f=p$ (Worked example 1 below checks this
explicitly), and every other equation of motion in this course is a further
special case of the same one bracket. If $f$ *does* carry explicit time
dependence — as in Exercise 4 below — the chain rule picks up one extra
term, $\dot f=\{f,H\}+\partial f/\partial t$, which reduces to the boxed
result whenever $f$ has no explicit $t$ in it.

### Conservation in bracket language: redoing Day 4

A phase-space function $f$ with no explicit time dependence is conserved
exactly when $\dot f=0$, which by the boxed equation means exactly
$$f\text{ conserved} \iff \{f,H\}=0.$$
This single criterion reproduces every conservation law from Day 4:

- **Momentum.** For one coordinate $q$, $\{p,H\}=\dfrac{\partial p}{\partial q}\dfrac{\partial H}{\partial p}-\dfrac{\partial p}{\partial p}\dfrac{\partial H}{\partial q} = 0 - \dfrac{\partial H}{\partial q} = -\dfrac{\partial H}{\partial q}$
  (using $\partial p/\partial q=0$ and $\partial p/\partial p=1$, since $q$
  and $p$ are independent phase-space coordinates). This vanishes exactly
  when $H$ doesn't depend on $q$ — precisely Day 4's "the physics doesn't
  care *where* it is," now an exact algebraic statement rather than an
  informal pattern.
- **Angular momentum.** Worked example 2 below computes $\{L_z,H\}=0$
  directly for any central potential $V(r)$ — the exact bracket-language
  counterpart of Day 4's "central forces conserve $\vec L$."
- **Energy.** By antisymmetry, $\{H,H\}=0$ automatically, for *any* $H$,
  with no assumption needed. So whenever $H$ itself carries no explicit
  time dependence (Day 4's "the physics doesn't care *when* it happens"),
  $H$ is trivially conserved by the boxed equation — the bracket makes
  visible exactly why energy is the "free" conservation law of the three:
  it doesn't need a special cancellation the way momentum and angular
  momentum do, because $\{H,H\}=0$ holds identically for every Hamiltonian.

### Canonical brackets: the multiplication table of mechanics

Treat $q$ and $p$ themselves as phase-space functions ($f=q$ is the
function that reads off the coordinate; $\partial q/\partial q=1$,
$\partial q/\partial p=0$, and likewise for $p$). Then
$$\{q,p\} = \frac{\partial q}{\partial q}\frac{\partial p}{\partial p} - \frac{\partial q}{\partial p}\frac{\partial p}{\partial q} = (1)(1)-(0)(0) = 1,$$
and $\{q,q\}=\{p,p\}=0$ by the antisymmetry corollary above (or by the same
direct computation, e.g. $\{q,q\}=\dfrac{\partial q}{\partial q}\dfrac{\partial q}{\partial p}-\dfrac{\partial q}{\partial p}\dfrac{\partial q}{\partial q}=(1)(0)-(0)(1)=0$).
These three numbers,
$$\{q,p\}=1,\qquad \{q,q\}=0,\qquad \{p,p\}=0,$$
are the **canonical brackets** — the complete "multiplication table" that
$q$ and $p$ obey among themselves, true for any Hamiltonian whatsoever,
since nothing about $H$ entered the computation. Every other bracket
involving compound phase-space functions (Worked examples 1–2, Exercises
3–5) reduces to this table plus the algebraic properties (linearity,
Leibniz rule) proved above — you never need to return to raw partial
derivatives once you know $\{q,p\}=1$ and the algebra rules.

> **Misconception:** "Poisson brackets are just a notational trick for
> writing partial derivatives compactly." They are not mere shorthand: the
> bracket is a coordinate-*independent* structure — computing $\{f,g\}$ in
> any pair of canonical coordinates related by a canonical transformation
> (a change of phase-space coordinates that preserves the canonical
> brackets $\{Q,P\}=1$, etc.) gives the *same* answer, even though the
> individual partial derivatives $\partial f/\partial q$ look completely
> different in the new coordinates. That invariance — proved properly in a
> full mechanics course, stated here only as a fact to be aware of — is
> exactly why the bracket, not the underlying partial derivatives, is the
> object that survives the transition to quantum mechanics below: the
> commutator $[\hat q,\hat p]=i\hbar$ has no "coordinate system" to depend
> on in the first place, so it is the bracket's coordinate-independent
> algebraic content, not its calculus formula, that quantization keeps.

### The dictionary: classical brackets to quantum commutators

Canonical quantization is the recipe that replaces every classical
phase-space function $f(q,p)$ with a linear operator $\hat f$ acting on a
complex vector space of states, and replaces the Poisson bracket with
$\dfrac{1}{i\hbar}$ times the operator commutator, $[\hat f,\hat g]:=\hat
f\hat g-\hat g\hat f$ — the same commutator you have been computing on
matrices in your quantum computing course. Line up the classical and
quantum objects side by side:

| Classical | Quantum |
|---|---|
| $f(q,p)$ | operator $\hat f$ |
| $\{f,g\}$ | $\dfrac{1}{i\hbar}[\hat f,\hat g]$ |
| $\{q,p\}=1$ | $[\hat q,\hat p]=i\hbar$ |
| $\dot f=\{f,H\}$ | Heisenberg equation $\dfrac{d\hat f}{dt}=\dfrac{1}{i\hbar}[\hat f,\hat H]$ |
| conserved $\iff \{f,H\}=0$ (for $f$ with no explicit $t$) | conserved $\iff [\hat f,\hat H]=0$ (commutes with $\hat H$; for $\hat f$ with no explicit $t$) |

Read this table **honestly**: nothing above is a *derivation* of quantum
mechanics from classical mechanics — quantum mechanics is a distinct
physical theory, with its own postulates (states as vectors, observables
as Hermitian operators, the Born rule you'll meet in your course), and no
amount of classical algebra forces those postulates into existence. What
the table states is narrower and still remarkable: quantization is the
recipe that keeps the *entire algebraic skeleton* of classical mechanics —
antisymmetry, linearity, the Leibniz rule, the master evolution equation's
exact shape — and changes only one thing, what the bracket symbol
$\{\cdot,\cdot\}$ actually *means*. Every algebraic identity you can prove
about Poisson brackets using only antisymmetry, linearity, and the Leibniz
rule (not the calculus formula) automatically has a quantum counterpart,
because the commutator satisfies the identical three properties: $[\hat
f,\hat g]=-[\hat g,\hat f]$; $[\hat f,\hat g]$ is linear in each slot; and
$[\hat f,\hat g\hat h]=[\hat f,\hat g]\hat h+\hat g[\hat f,\hat h]$ (used in
Exercise 5, and identical in shape to the Leibniz rule proved above, with
scalar multiplication replaced by operator multiplication in the natural
order).

### Why commutators are then natural, not weird

The first time you meet $[\hat q,\hat p]=i\hbar\ne0$ in a quantum course,
it can look like an arbitrary, almost magical rule bolted onto matrix
mechanics. Today's table shows it is nothing of the kind: it is the
*direct quantum image* of $\{q,p\}=1\ne0$, a fact you derived above from
nothing but the definition of the Poisson bracket, with no quantum content
at all. Classical mechanics already has a non-symmetric, non-vanishing
bracket between position and momentum; quantization does not invent
non-commutativity, it simply carries an existing algebraic fact from one
structure (the Poisson bracket, built from calculus on phase space) into
another (the commutator, built from operator multiplication) that obeys
the same three defining rules. The genuinely new physical content is that
operators generically fail to commute with each other in a way that
*matters for measurement* — $[\hat q,\hat p]\ne0$ is, in fact, the precise
mathematical seat of Heisenberg's uncertainty principle, since two
observables with a nonzero commutator cannot in general have simultaneous
sharp values (Day 17 makes this quantitative and closes this loop). But the
*algebraic form* of the noncommutativity — that it is the bracket carried
over, with a factor of $i\hbar$ — is exactly what today's dictionary
predicts, not a separate mystery.

### Two-level truncation: where the qubit comes from

One paragraph, because it is a preview, not a derivation you're equipped to
complete yet: take *any* physical quantum system — an atom, a molecule, a
superconducting circuit — with infinitely many energy levels in general,
and restrict attention to just two of them (say the ground state and one
excited state, isolated by an energy gap much larger than any other energy
scale in the problem, so that transitions to every other level are
negligible). Inside that two-dimensional subspace, *every* observable
operator — energy, any component of spin, any coupling to an external
field — becomes, in some orthonormal basis of the subspace, an ordinary
$2\times2$ Hermitian matrix acting on a two-component complex vector: the
exact mathematical object your quantum computing course calls a qubit and
builds every single-qubit gate from. This is why the Pauli matrices and
$2\times2$ unitaries you already know are not an abstract toy model
invented for computer science — they are the *exact* mathematics of any
real two-level quantum system, and Days 14 and 18 will use precisely this
truncation on real atomic and spin systems.

> **Misconception:** "quantum mechanics replaces classical mechanics'
> equations with different ones." It does not replace the *equations* —
> Hamilton's equation $\dot f=\{f,H\}$ and the Heisenberg equation
> $d\hat f/dt=\frac{1}{i\hbar}[\hat f,\hat H]$ have *identical shape*, as
> the dictionary table shows line by line. What quantum mechanics replaces
> is the bracket itself (a calculus construction on phase space becomes an
> algebraic construction on operators) and the nature of the objects being
> evolved ($q,p$ as numbers become $\hat q,\hat p$ as operators, and the
> classical state — a point $(q,p)$ — becomes a vector in a complex vector
> space). The *form* of the dynamics is conserved almost perfectly; the
> *content* of what's being evolved changes completely. Conflating these
> two things is what makes quantum mechanics look like an unrelated set of
> new rules rather than the same skeleton wearing new flesh.

## Worked examples

**1. Recall $\{q,p\}=1$ and compute $\{q,H\},\{p,H\}$ for the harmonic
oscillator, recovering Hamilton's equations.** Take
$H=\dfrac{p^2}{2m}+\tfrac12 m\omega_0^2q^2$ (Day 10's oscillator
Hamiltonian). The canonical bracket $\{q,p\}=1$ was verified in general
above; it doesn't depend on which $H$ is in play. Now compute
$$\{q,H\} = \frac{\partial q}{\partial q}\frac{\partial H}{\partial p} - \frac{\partial q}{\partial p}\frac{\partial H}{\partial q} = (1)\left(\frac{p}{m}\right) - (0)(m\omega_0^2q) = \frac{p}{m},$$
$$\{p,H\} = \frac{\partial p}{\partial q}\frac{\partial H}{\partial p} - \frac{\partial p}{\partial p}\frac{\partial H}{\partial q} = (0)\left(\frac{p}{m}\right) - (1)(m\omega_0^2q) = -m\omega_0^2q.$$
By the master equation, $\dot q=\{q,H\}=p/m$ and $\dot p=\{p,H\}=-m\omega_0^2q$
— exactly Hamilton's equations $\dot q=\partial H/\partial p$,
$\dot p=-\partial H/\partial q$ evaluated on this $H$. This is not a
coincidence: $f=q$ and $f=p$ substituted into the boxed master equation
*are*, term for term, Hamilton's two equations; today's single bracket law
contains Day 10's two equations as its two simplest special cases.

**2. Central force in two dimensions: show $\{L_z,H\}=0$ by direct
computation.** Take $H=\dfrac{p_x^2+p_y^2}{2m}+V(r)$ with
$r=\sqrt{x^2+y^2}$ (kinetic plus a central potential, Day 10's planar
form), and $L_z=xp_y-yp_x$ (Day 4's angular momentum, restricted to its
$z$-component in the $xy$-plane; recall today's notation note — this $L_z$
is angular momentum, not the Lagrangian). Using the two-pair bracket sum
with $(q_1,q_2,p_1,p_2)=(x,y,p_x,p_y)$:
$$\{L_z,H\} = \frac{\partial L_z}{\partial x}\frac{\partial H}{\partial p_x} - \frac{\partial L_z}{\partial p_x}\frac{\partial H}{\partial x} + \frac{\partial L_z}{\partial y}\frac{\partial H}{\partial p_y} - \frac{\partial L_z}{\partial p_y}\frac{\partial H}{\partial y}.$$
The needed partials: $\partial L_z/\partial x=p_y$, $\partial
L_z/\partial p_x=-y$, $\partial L_z/\partial y=-p_x$, $\partial
L_z/\partial p_y=x$; and, using the chain rule on $V(r)$ with
$\partial r/\partial x=x/r$, $\partial r/\partial y=y/r$: $\partial
H/\partial x=V'(r)\,x/r$, $\partial H/\partial y=V'(r)\,y/r$, $\partial
H/\partial p_x=p_x/m$, $\partial H/\partial p_y=p_y/m$. Substituting:
$$\{L_z,H\} = p_y\cdot\frac{p_x}{m} - (-y)\cdot V'(r)\frac{x}{r} + (-p_x)\cdot\frac{p_y}{m} - x\cdot V'(r)\frac{y}{r}$$
$$= \frac{p_xp_y}{m} + \frac{V'(r)\,xy}{r} - \frac{p_xp_y}{m} - \frac{V'(r)\,xy}{r} = 0.$$
The kinetic-energy terms cancel against each other, and the two
potential-energy terms cancel against each other separately — and this
holds for *any* function $V(r)$ of the radial distance alone, exactly
matching Day 4's statement that angular momentum is conserved under *any*
central force, not just gravity or the Coulomb force specifically.

**3. Oscillator: time evolution of $q$ via iterated brackets, recovering
the $\cos\omega_0t$ series.** Take the same oscillator as Example 1, and
the initial condition $q(0)=q_0$, $p(0)=0$ (released from rest), so the
motion should be pure cosine. Build the Taylor series of $q(t)$ about
$t=0$ using nothing but repeated brackets against $H$: from Example 1,
$\dot q=\{q,H\}=p/m$, so at $t=0$, $\dot q(0)=0/m=0$. Differentiate again
using the master equation on $\dot q$ itself:
$$\ddot q = \{\dot q,H\} = \left\{\frac{p}{m},H\right\} = \frac{1}{m}\{p,H\} = \frac{1}{m}(-m\omega_0^2q) = -\omega_0^2q,$$
so $\ddot q(0)=-\omega_0^2q_0$. One more iteration:
$$\dddot q = \{\ddot q,H\} = -\omega_0^2\{q,H\} = -\omega_0^2\dot q,$$
so $\dddot q(0)=-\omega_0^2\cdot0=0$, and one more:
$$q^{(4)} = \{\dddot q,H\} = -\omega_0^2\{\dot q,H\} = -\omega_0^2\ddot q = \omega_0^4q,$$
so $q^{(4)}(0)=\omega_0^4q_0$. The Taylor series
$q(t)=\sum_n q^{(n)}(0)\,t^n/n!$ then reads
$$q(t) = q_0 + 0\cdot t - \frac{\omega_0^2q_0}{2!}t^2 + 0\cdot t^3 + \frac{\omega_0^4q_0}{4!}t^4 - \cdots = q_0\left[1 - \frac{(\omega_0t)^2}{2!} + \frac{(\omega_0t)^4}{4!} - \cdots\right].$$
The bracketed first three nonzero terms are exactly the first three terms
of the Taylor series of $\cos(\omega_0t)$, so the pattern of alternating
signs on even powers is recognizable well before summing the whole series:
$q(t)=q_0\cos(\omega_0t)$, the familiar oscillator solution, rebuilt from
nothing but repeated applications of $\dot f=\{f,H\}$ rather than from
solving the differential equation directly. (Starting instead from a
general $p(0)=p_0\ne0$ reintroduces the odd-power terms and produces the
full $q_0\cos\omega_0t+\frac{p_0}{m\omega_0}\sin\omega_0t$ solution by the
identical method — the calculation above simply isolates the cosine part
by starting from rest.)

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. Starting only from the chain rule and Hamilton's equations
   $\dot q=\partial H/\partial p$, $\dot p=-\partial H/\partial q$, derive
   $\dot f=\{f,H\}$ for a general phase-space function $f(q,p)$.
2. From the definition
   $\{f,g\}=\frac{\partial f}{\partial q}\frac{\partial g}{\partial p}-\frac{\partial f}{\partial p}\frac{\partial g}{\partial q}$
   alone, verify antisymmetry ($\{f,g\}=-\{g,f\}$) and the Leibniz product
   rule ($\{f,gh\}=\{f,g\}h+g\{f,h\}$).

**Standard**

3. For $L_z=xp_y-yp_x$, compute $\{L_z,x\}$, $\{L_z,y\}$, and
   $\{L_z,p_x\}$. Interpret the results as an infinitesimal transformation
   of $(x,y)$: if $\delta x=\epsilon\{x,L_z\}$ and $\delta y=\epsilon\{y,L_z\}$
   for a small parameter $\epsilon$, what geometric operation is $L_z$
   generating?
4. A free particle has $H=p^2/2m$ (one coordinate $q\equiv x$). Show
   $\{p,H\}=0$ and $\{H,H\}=0$ (so both are conserved), and then show that
   $g(x,p,t)=x-pt/m$ is *also* conserved, i.e. $dg/dt=0$, using
   $dg/dt=\{g,H\}+\partial g/\partial t$. Interpret $g$ physically.

**Stretch**

5. Take the quantization dictionary at its word. From $[\hat q,\hat
   p]=i\hbar$ alone, and the operator identity
   $[A,BC]=[A,B]C+B[A,C]$, compute $[\hat q,\hat p^2]$. Separately, compute
   the classical bracket $\{q,p^2\}$ directly from the definition, and
   check that $[\hat q,\hat p^2] = i\hbar\,\{q,p^2\}$, exactly as the
   dictionary $\{f,g\}\to\frac{1}{i\hbar}[\hat f,\hat g]$ predicts.

## Hints

1. Write $df/dt$ by the chain rule in terms of $\dot q$ and $\dot p$ first,
   substitute Hamilton's equations second, and recognize the bracket
   definition third — three substitutions, four lines total.
2. For antisymmetry, swap $f$ and $g$ in the definition and compare term by
   term. For the Leibniz rule, apply the ordinary calculus product rule to
   $\partial(gh)/\partial p$ and $\partial(gh)/\partial q$ separately
   before substituting into the bracket definition.
3. Use the two-pair sum $\{f,g\}=\sum_i(\partial_{q_i}f\,\partial_{p_i}g-\partial_{p_i}f\,\partial_{q_i}g)$
   with $(q_1,q_2,p_1,p_2)=(x,y,p_x,p_y)$; only one term in the sum survives
   for each bracket you need. For the interpretation, write out the pair
   $(\delta x,\delta y)$ as a $2\times2$ matrix acting on $(x,y)$ and
   compare it to the small-angle form of a familiar $2\times2$ geometric
   transformation.
4. $H$ depends only on $p$, so $\{p,H\}$ and $\{H,H\}$ both vanish almost by
   inspection. For $g=x-pt/m$, use linearity to split $g$ into its two
   pieces, and don't forget the explicit-$t$ term in the master equation.
5. For the commutator, apply $[A,BC]=[A,B]C+B[A,C]$ with $A=\hat q$,
   $B=C=\hat p$ and simplify using $[\hat q,\hat p]=i\hbar$ twice. For the
   classical bracket, differentiate $p^2$ with respect to $p$ directly in
   the single-pair definition.

## Solutions

**1.** For $f(q,p)$ evaluated along a trajectory, the chain rule gives
$$\frac{df}{dt} = \frac{\partial f}{\partial q}\dot q + \frac{\partial f}{\partial p}\dot p.$$
Substituting Hamilton's equations $\dot q=\partial H/\partial p$,
$\dot p=-\partial H/\partial q$:
$$\frac{df}{dt} = \frac{\partial f}{\partial q}\frac{\partial H}{\partial p} - \frac{\partial f}{\partial p}\frac{\partial H}{\partial q}.$$
The right-hand side is exactly $\{f,H\}$ by definition, so
$\dot f=\{f,H\}$.

**2.** *Antisymmetry:* directly from the definition,
$$\{g,f\} = \frac{\partial g}{\partial q}\frac{\partial f}{\partial p} - \frac{\partial g}{\partial p}\frac{\partial f}{\partial q},$$
which is exactly $-1$ times $\{f,g\}=\frac{\partial f}{\partial q}\frac{\partial g}{\partial p}-\frac{\partial f}{\partial p}\frac{\partial g}{\partial q}$
with the two terms relabeled — the same two products, opposite sign
overall, so $\{g,f\}=-\{f,g\}$.

*Leibniz rule:* apply the ordinary product rule inside the definition,
$$\{f,gh\} = \frac{\partial f}{\partial q}\left(\frac{\partial g}{\partial p}h+g\frac{\partial h}{\partial p}\right) - \frac{\partial f}{\partial p}\left(\frac{\partial g}{\partial q}h+g\frac{\partial h}{\partial q}\right),$$
and regroup the four resulting terms by whether they carry a factor of $h$
or a factor of $g$:
$$= h\left(\frac{\partial f}{\partial q}\frac{\partial g}{\partial p}-\frac{\partial f}{\partial p}\frac{\partial g}{\partial q}\right) + g\left(\frac{\partial f}{\partial q}\frac{\partial h}{\partial p}-\frac{\partial f}{\partial p}\frac{\partial h}{\partial q}\right) = h\{f,g\} + g\{f,h\}.$$

**3.** Using $\{f,g\}=\partial_xf\,\partial_{p_x}g-\partial_{p_x}f\,\partial_xg+\partial_yf\,\partial_{p_y}g-\partial_{p_y}f\,\partial_yg$
with $f=L_z=xp_y-yp_x$ (so $\partial_xL_z=p_y$, $\partial_{p_x}L_z=-y$,
$\partial_yL_z=-p_x$, $\partial_{p_y}L_z=x$):

$\{L_z,x\}$: only the $-\partial_{p_x}L_z\,\partial_xx$ term survives
($\partial_xx=1$, all other partials of $g=x$ are $0$):
$\{L_z,x\}=-(-y)(1)=y$.

$\{L_z,y\}$: only the $-\partial_{p_y}L_z\,\partial_yy$ term survives:
$\{L_z,y\}=-(x)(1)=-x$.

$\{L_z,p_x\}$: only the $\partial_xL_z\,\partial_{p_x}p_x$ term survives
($\partial_{p_x}p_x=1$): $\{L_z,p_x\}=(p_y)(1)=p_y$.

*Interpretation:* by antisymmetry, $\{x,L_z\}=-\{L_z,x\}=-y$ and
$\{y,L_z\}=-\{L_z,y\}=x$, so
$$\delta x=\epsilon\{x,L_z\}=-\epsilon y, \qquad \delta y=\epsilon\{y,L_z\}=\epsilon x.$$
As a matrix, $\binom{\delta x}{\delta y}=\epsilon\begin{pmatrix}0&-1\\1&0\end{pmatrix}\binom{x}{y}$,
which is exactly the infinitesimal form of a counterclockwise rotation by
angle $\epsilon$ about the origin. $L_z$ generates rotations of the plane
— brackets with $L_z$ literally rotate things, matching the interpretation
the exercise asks for.

**4.** $H=p^2/2m$ depends only on $p$, so
$\{p,H\}=\partial_qp\,\partial_pH-\partial_pp\,\partial_qH = (0)(p/m)-(1)(0)=0$
(both $\partial_qp=0$ and $\partial_qH=0$ since neither depends on $q$).
And $\{H,H\}=0$ for any $H$ by the antisymmetry corollary. Both are
conserved.

For $g=x-pt/m$ (with $q\equiv x$), using linearity,
$$\{g,H\} = \{x,H\} - \frac{t}{m}\{p,H\} = \{x,H\} - 0.$$
Compute $\{x,H\}=\partial_xx\,\partial_pH-\partial_px\,\partial_xH=(1)(p/m)-(0)(0)=p/m$.
So $\{g,H\}=p/m$. The explicit-time-dependence term is
$\partial g/\partial t=-p/m$ (differentiating $-pt/m$ with respect to $t$
at fixed $x,p$). Adding,
$$\frac{dg}{dt} = \{g,H\}+\frac{\partial g}{\partial t} = \frac{p}{m}-\frac{p}{m}=0,$$
so $g$ is conserved. *Interpretation:* for a free particle, $p/m=v$ is the
(constant) velocity, so $x(t)=x_0+vt$, i.e. $x_0=x(t)-vt=x-pt/m$ exactly —
$g$ is nothing but the particle's fixed initial position, recovered from
its position and momentum at any later time. It is a genuine, non-obvious
conserved quantity that isn't one of Day 4's three usual suspects
(momentum, angular momentum, energy); it reflects Galilean boost symmetry
rather than a spatial, rotational, or temporal one.

**5.** *Quantum side:* with $A=\hat q$, $B=C=\hat p$,
$$[\hat q,\hat p^2] = [\hat q,\hat p]\hat p + \hat p[\hat q,\hat p] = (i\hbar)\hat p + \hat p(i\hbar) = 2i\hbar\hat p,$$
using $[\hat q,\hat p]=i\hbar$ (a number, so it commutes freely with
$\hat p$) in both terms.

*Classical side:* directly from the single-pair definition, with $g=p^2$,
$$\{q,p^2\} = \frac{\partial q}{\partial q}\frac{\partial(p^2)}{\partial p} - \frac{\partial q}{\partial p}\frac{\partial(p^2)}{\partial q} = (1)(2p) - (0)(0) = 2p.$$

*Check:* the dictionary predicts $[\hat q,\hat p^2]=i\hbar\{q,p^2\}$.
Substituting: $i\hbar\{q,p^2\}=i\hbar(2p)=2i\hbar p$, which matches
$[\hat q,\hat p^2]=2i\hbar\hat p$ exactly (writing $\hat p$ for the operator
in place of the classical number $p$). The purely algebraic quantum
computation and the purely calculus-based classical computation agree
precisely as the dictionary claims they must.

## Connection to QM

This day *is* the connection — there is no separate physics to layer on
top, only a habit to build: when your quantum computing course reaches
commutators, matrix mechanics, or the Heisenberg picture, stop and
re-derive three things from memory before reading ahead in that course.

**First, the master equation.** Re-derive $\dot f=\{f,H\}$ from Hamilton's
equations (Exercise 1), then write down its quantum image, the Heisenberg
equation $\dfrac{d\hat f}{dt}=\dfrac{1}{i\hbar}[\hat f,\hat H]$, from
memory, and check you can say in one sentence why the two have identical
shape (the algebra — antisymmetry, linearity, the Leibniz rule — is
preserved by quantization; only what the bracket symbol means changes).

**Second, the dictionary table.** Re-derive each of its five rows from
scratch: $f\to\hat f$; $\{f,g\}\to\frac{1}{i\hbar}[\hat f,\hat g]$;
$\{q,p\}=1\to[\hat q,\hat p]=i\hbar$; the master equation
$\to$ the Heisenberg equation; and "conserved $\iff$ bracket with $H$
vanishes" $\to$ "conserved $\iff$ commutes with $\hat H$." This exact table
reappears as the Rosetta Stone on Day 18, once every other piece of the
picture (wavefunctions, operators, the hydrogen atom) is in place — the
second reading this day asks for should leave you able to reconstruct it
without looking it up.

**Third, Exercise 5.** Redo the direct check that $[\hat q,\hat
p^2]=i\hbar\{q,p^2\}$, and then try it on one operator pair from your
quantum computing course (any two Pauli matrices are a good choice) to see
the same three algebraic properties — antisymmetry, linearity, the Leibniz
rule — doing exactly the same job on genuinely finite-dimensional matrices
that they did here on $\hat q$ and $\hat p$. That is the thread the
two-level truncation paragraph above is quietly pulling: the same bracket
algebra governs both an oscillator's infinite-dimensional operators and a
qubit's $2\times2$ matrices, because "obeys these three algebraic rules,"
not "acts on this particular vector space," is the entire content of what
a bracket — classical or quantum — is.
