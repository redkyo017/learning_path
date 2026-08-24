# Day 16 — The Schrödinger Equation

## Learning objectives

By the end of today you should be able to:
- Motivate (not derive) the time-dependent Schrödinger equation (TDSE)
  from a free-particle plane wave and the classical energy relation
  $E=p^2/2m+V$, and state precisely why this is a motivation and not a
  derivation.
- State the Born rule, normalize a given wavefunction, and explain why a
  complex-valued $\psi$ still produces only real, physical predictions.
- Separate variables on the TDSE to obtain the time-independent
  Schrödinger equation (TISE) $\hat H\phi=E\phi$, and explain precisely
  what "stationary state" does and does not mean.
- Solve the infinite square well completely: apply boundary conditions,
  derive the quantized $E_n$ and $\phi_n$, normalize them, and explain why
  $n=0$ is forbidden and why $\phi_n$ has exactly $n-1$ interior nodes.
- Verify orthogonality of the box eigenstates by direct integration, and
  expand an arbitrary state in that eigenbasis, interpreting $|c_n|^2$ as
  a measurement probability.
- Predict and explain probability "sloshing" in a two-state superposition
  from the beat frequency $(E_2-E_1)/\hbar$.

Time budget: ~4 hours.

## Reference material

- Griffiths, *Introduction to Quantum Mechanics*, 3rd ed., ch. 1 (the
  statistical interpretation and the Born rule) and ch. 2 (the
  time-independent Schrödinger equation and the infinite square well) —
  the direct source for essentially every formal result below.
- French & Taylor, *An Introduction to Quantum Physics*, the chapters on
  the Schrödinger equation and the particle in a box, as a second telling
  in different notation and with a more experimentally-driven framing.
- This file is self-contained; the texts above are useful for a second
  explanation in different words, not required to do today's work.
- Builds on day 5 (the classical wave equation, second order in time),
  day 6 (fixed-end boundary conditions producing discrete standing-wave
  modes), day 7 (dispersion relations, group velocity, and the mode-basis
  inner product), day 8 (global phase is unobservable), day 10 ($H =
  p^2/2m+V$ as the generator of time evolution), and day 15 (de Broglie's
  $\lambda=h/p$, $f=E/h$, and its stretch exercise's standing-wave guess
  at the box energies).

## Theory

### 1. Constructing the TDSE: a motivation, not a derivation

Nothing below is a derivation in the sense of days 1–14: there is no
Schrödinger equation "underneath" that we uncover by strict logical
necessity from older laws. What follows is a *motivated guess*, built to
reproduce the free particle's known wave behavior, whose only real
justification is that every experiment ever run against it — a century of
them — has confirmed its predictions. Say this plainly, because it matters:
we are about to *construct*, not *deduce*.

Start from day 15's free matter wave, a plane wave carrying the de Broglie
relations $p=\hbar k$ and $E=\hbar\omega$:
$$\psi(x,t) = e^{i(kx-\omega t)}.$$
Differentiate it once in space and once in time:
$$-i\hbar\,\partial_x\psi = -i\hbar(ik)\psi = \hbar k\,\psi = p\,\psi,
\qquad
i\hbar\,\partial_t\psi = i\hbar(-i\omega)\psi = \hbar\omega\,\psi = E\,\psi.$$
Notice the pattern: differentiating $\psi$ and multiplying by the right
constant hands back $p\psi$ or $E\psi$. Read this as an operator
statement — momentum and energy act on this wave as
$$\hat p \equiv -i\hbar\,\partial_x, \qquad \hat E \equiv i\hbar\,\partial_t.$$

Now demand that the classical energy relation $E = \dfrac{p^2}{2m}+V(x)$
hold as a relation between these *operators*, acting on $\psi$, rather than
between the classical numbers $E$ and $p$. Since $\hat p^2\psi =
(-i\hbar\partial_x)^2\psi = -\hbar^2\partial_x^2\psi$, this promotion gives
$$\boxed{\,i\hbar\,\frac{\partial\psi}{\partial t} =
-\frac{\hbar^2}{2m}\frac{\partial^2\psi}{\partial x^2} + V(x)\,\psi\,}$$
the **time-dependent Schrödinger equation**. It was not derived from
Newton's laws, from day 5's wave equation, or from anything else already
in hand; it was *built* so that a free-particle plane wave with the
correct de Broglie $p$ and $E$ automatically satisfies it, and then
extended to include a potential by the most natural guess available — and
it has agreed with every experiment run against it since 1926.

**Three things to flag immediately.**

- *First order in time.* Day 5's wave equation, $\partial_t^2 y =
  v^2\partial_x^2 y$, is second order in time and needs two pieces of
  initial data ($y(x,0)$ and $\dot y(x,0)$) to fix its future. The TDSE is
  *first* order in time: $\psi(x,0)$ alone determines $\psi(x,t)$ for all
  later $t$. This is a structurally different kind of equation, not a
  cousin of day 5's — a hint that $\psi$ itself, not some real classical
  field, is the fundamental object being evolved.
- *Necessarily complex.* Suppose $\psi$ and $V$ were both real. Then the
  right side of the boxed equation is real, but the left side, $i\hbar
  \partial_t\psi$, is purely imaginary unless $\partial_t\psi=0$. A
  nontrivial, evolving, real-valued $\psi$ cannot satisfy this equation —
  $\psi$ must be complex-valued to work at all. This is unlike day 5's
  wave equation, which is perfectly happy with a real $y(x,t)$; complex
  numbers here are not a bookkeeping convenience, they are load-bearing.
- *Matter waves disperse.* For a free particle ($V=0$), substituting the
  plane wave back into the boxed equation gives $\hbar\omega =
  \hbar^2k^2/(2m)$, i.e. $\omega = \hbar k^2/(2m)$ — a dispersion relation
  of exactly the form $\omega=\alpha k^2$ that **Day 7, Exercise 3**
  analyzed in the abstract, with $\alpha=\hbar/2m$ here. That exercise
  showed $\omega=\alpha k^2$ forces $v_g = 2v_{ph}$: group and phase
  velocity split, so a matter-wave packet built from a spread of $k$'s
  necessarily spreads out in space as time goes on. Day 7's foreshadowing
  was exact — this is the equation it was foreshadowing.

### 2. What $\psi$ means: the Born rule

The TDSE says nothing yet about what $\psi$ *is* physically. The postulate
that answers that (Born, 1926) is the **Born rule**:
$$|\psi(x,t)|^2\,dx = \text{probability of finding the particle in }
[x,x+dx] \text{ at time } t.$$
Since "the particle is found somewhere" is a certainty, total probability
must be $1$, which forces the **normalization condition**
$$\int_{-\infty}^{\infty} |\psi(x,t)|^2\,dx = 1.$$
$|\psi|^2 = \psi^*\psi$ is manifestly real and non-negative for *any*
complex $\psi$ (Day 3's lesson from the sister quantum-computing path
applies verbatim: $z^*z=|z|^2\ge0$ for every complex $z$), which is exactly
why $\psi$ was allowed to be complex in Section 1 without breaking the
requirement that a *probability* be a real, non-negative number. Every
physically measurable prediction of quantum mechanics — probabilities,
expectation values — is built from bilinear combinations like $\psi^*\psi$
or $\psi^*\hat A\psi$ that come out real; the complex phase of $\psi$
itself is never directly observed.

That last point has a sharp consequence, recalled from **day 8's exercise
5**: two wavefunctions differing only by an overall constant phase,
$\psi$ and $e^{i\alpha}\psi$ for real $\alpha$, give *identical* $|\psi|^2$
at every point, since $|e^{i\alpha}\psi|^2 = |e^{i\alpha}|^2|\psi|^2 =
|\psi|^2$. Global phase was unobservable for a qubit-like state on day 8;
it is unobservable here for exactly the same algebraic reason, now applied
to a continuous wavefunction instead of a finite-dimensional vector.

> **Misconception:** "$\psi(x,t)$ is a physical wave in space, like a
> ripple on water." It is a probability *amplitude*, not a displacement of
> any physical medium — and the point is not merely semantic: for two
> particles, $\psi$ is a single function of *both* particles' positions,
> $\psi(x_1,x_2,t)$, living in a $6$-dimensional configuration space (three
> spatial coordinates each), with no 3-dimensional "wave in space" picture
> available at all once more than one particle is involved.

### 3. Stationary states: separating the TDSE into the TISE

Look for solutions of the special separated form
$$\psi(x,t) = \phi(x)\,e^{-iEt/\hbar}$$
for some real constant $E$ and some function $\phi(x)$ independent of
time. Substitute into the boxed TDSE. The time derivative acts only on the
exponential:
$$i\hbar\,\partial_t\psi = i\hbar\left(-\frac{iE}{\hbar}\right)\phi(x)
e^{-iEt/\hbar} = E\,\phi(x)e^{-iEt/\hbar} = E\psi,$$
while the spatial derivative and $V(x)$ act only on $\phi(x)$, carrying the
common factor $e^{-iEt/\hbar}$ straight through unchanged. The TDSE
becomes, after cancelling the common $e^{-iEt/\hbar}$ from both sides,
$$-\frac{\hbar^2}{2m}\frac{d^2\phi}{dx^2} + V(x)\phi(x) = E\,\phi(x).$$
Day 10 identified $H = p^2/2m+V$ as **the Hamiltonian, the generator of
time evolution**. Writing that same object as an operator, with $\hat p
\to -i\hbar\partial_x$ exactly as in Section 1,
$$\hat H \equiv -\frac{\hbar^2}{2m}\frac{d^2}{dx^2} + V(x),$$
the separated equation is exactly
$$\boxed{\hat H\,\phi(x) = E\,\phi(x)}$$
the **time-independent Schrödinger equation (TISE)** — an eigenvalue
equation for the operator $\hat H$, with eigenvalue $E$ and eigenfunction
$\phi$. Every allowed energy of the system is an eigenvalue of $\hat H$;
every corresponding $\phi$ is called a **stationary state**.

**Why "stationary," precisely.** For a state of this separated form,
$$|\psi(x,t)|^2 = \big|\phi(x)\big|^2\,\big|e^{-iEt/\hbar}\big|^2 =
|\phi(x)|^2,$$
using $|e^{-iEt/\hbar}|=1$ for any real $E$ and $t$ — the probability
density is exactly time-independent. That is the entire content of
"stationary": nothing about the *particle* is frozen, only the measured
*probability distribution* of its position stays fixed for all time. The
wavefunction itself still oscillates in time through its complex phase,
$e^{-iEt/\hbar}$; it is only $|\psi|^2$ that stands still.

> **Misconception:** "A particle in a stationary state is at rest."
> Direct counterexample below: the box's ground state has $\langle
> p\rangle = 0$ (by symmetry, the particle is equally likely moving
> left as right), but $\langle p^2\rangle \ne 0$ — indeed $\langle
> p^2\rangle/2m = E_1 > 0$, a strictly positive kinetic energy. A
> stationary state has a *fixed distribution* of momentum, symmetric
> about zero, not zero momentum; "stationary" describes $|\psi|^2$, never
> a claim that the particle has stopped moving.

### 4. The particle in a box, completely

Take the simplest possible potential: an infinite square well,
$$V(x) = \begin{cases} 0, & 0 < x < L \\ \infty, & \text{otherwise,}
\end{cases}$$
where **here $L$ is a length** — the width of the box, not a Lagrangian or
angular momentum. An infinite potential outside $[0,L]$ means the particle
can never be found there at all, so $\phi(x)=0$ for $x\le0$ and $x\ge L$,
and continuity of $\phi$ forces the **boundary conditions**
$$\phi(0) = 0, \qquad \phi(L) = 0 —$$
day 6's fixed-string boundary conditions, verbatim, with $\phi$ in the role
of the string's displacement.

**Solving inside the box.** For $0<x<L$, $V=0$, so the TISE reads
$$-\frac{\hbar^2}{2m}\phi'' = E\phi \quad\Longrightarrow\quad
\phi'' = -k^2\phi, \qquad k \equiv \sqrt{\frac{2mE}{\hbar^2}}.$$
This is the familiar SHM-type ODE (day 3's equation, now in space instead
of time), with general solution $\phi(x) = A\sin(kx) + B\cos(kx)$.

**Applying the boundary conditions.** $\phi(0)=B=0$, eliminating the
cosine term. Then $\phi(L)=A\sin(kL)=0$; since $A=0$ would make
$\phi\equiv0$ everywhere (no particle at all — not a physical state), the
only way to satisfy this with $A\ne0$ is
$$kL = n\pi, \qquad n = 1, 2, 3, \ldots$$
**$n=0$ is explicitly excluded here** — not by hand-wave but because
$n=0$ gives $k=0$, hence $\phi(x)=A\sin(0)=0$ everywhere, the trivial,
unphysical non-solution. This is the origin of the box's **zero-point
energy**: the lowest allowed state is $n=1$, not $n=0$, so the minimum
energy is strictly positive — an early, concrete sign of the uncertainty
principle at work: confining a particle to a finite region forbids it from
also having exactly zero momentum.

**Quantized energies and eigenfunctions.** With $k_n = n\pi/L$,
$$E_n = \frac{\hbar^2 k_n^2}{2m} = \frac{n^2\pi^2\hbar^2}{2mL^2}, \qquad
\phi_n(x) = A_n\sin\!\left(\frac{n\pi x}{L}\right), \qquad n=1,2,3,\ldots$$

**Normalizing.** Demand $\int_0^L|\phi_n|^2dx=1$. Substituting $u=n\pi x/L$
(so $dx = (L/n\pi)\,du$, and $x:0\to L$ maps to $u:0\to n\pi$):
$$\int_0^L \sin^2\!\left(\frac{n\pi x}{L}\right)dx =
\frac{L}{n\pi}\int_0^{n\pi}\sin^2u\,du =
\frac{L}{n\pi}\left[\frac{u}{2}-\frac{\sin2u}{4}\right]_0^{n\pi} =
\frac{L}{n\pi}\cdot\frac{n\pi}{2} = \frac{L}{2},$$
using $\sin(2n\pi)=0$ for every integer $n$. So $A_n^2(L/2)=1$, giving
$A_n=\sqrt{2/L}$ for every $n$ (independent of $n$ — the box eigenfunctions
are all normalized by the *same* constant), and
$$\boxed{E_n = \frac{n^2\pi^2\hbar^2}{2mL^2}, \qquad \phi_n(x) =
\sqrt{\frac{2}{L}}\,\sin\!\left(\frac{n\pi x}{L}\right)}$$

**Matching day 15, triumphantly.** Day 15's stretch exercise reasoned about
standing de Broglie waves in a box, guessing $E_n = n^2h^2/(8mL^2)$ from
pure fitting arguments, with no Schrödinger equation in sight. Compare
that to the boxed result above, using $\hbar=h/2\pi$ so $\hbar^2 =
h^2/4\pi^2$:
$$\frac{n^2\pi^2\hbar^2}{2mL^2} = \frac{n^2\pi^2}{2mL^2}\cdot
\frac{h^2}{4\pi^2} = \frac{n^2h^2}{8mL^2}.$$
Identical, term for term. The real theory, run through boundary conditions
and an eigenvalue equation, reproduces exactly the numbers day 15 guessed
from standing-wave intuition alone — the guess was correct, and today is
the reason it had to be.

**Counting nodes.** $\phi_n(x)=\sqrt{2/L}\sin(n\pi x/L)$ vanishes at
$x = 0, L/n, 2L/n, \ldots, L$ — that is $n+1$ zeros total, but the two
endpoints are the (required) boundary zeros, not "nodes" in the usual
sense of a wave crossing zero inside the region. The number of **interior**
nodes (zeros strictly between $0$ and $L$) is
$$\#\text{nodes} = n-1.$$
$\phi_1$ (ground state) has zero interior nodes, and is single-signed
across the whole box; $\phi_2$ has exactly one interior node, at the
center $x=L/2$; each higher $n$ adds one more, exactly as day 6's
higher-harmonic standing waves on a string added one more interior node
per mode number.

### 5. Orthogonality and expansion in the eigenbasis

Two eigenfunctions with different $n$ are **orthogonal**:
$$\int_0^L \phi_n(x)\phi_m(x)\,dx = \delta_{nm}, \qquad n\ne m,$$
verified directly (worked in full for $n,m=1,2$ in the Exercises below;
the general integral uses the same product-to-sum identity and vanishes
term by term for any $n\ne m$). This is exactly day 7's mode-basis inner
product — different string harmonics were orthogonal there for the same
underlying reason (they are eigenfunctions of a linear operator with
distinct eigenvalues) — now recovered as a property of energy eigenstates
rather than vibrational modes.

Because $\{\phi_n\}$ is a complete orthonormal set, *any* state $\psi(x)$
that satisfies the same boundary conditions can be written as a
**basis expansion**
$$\psi(x) = \sum_{n=1}^\infty c_n\,\phi_n(x), \qquad
c_n = \int_0^L \phi_n(x)\,\psi(x)\,dx$$
(the formula for $c_n$ follows by multiplying both sides by $\phi_m$,
integrating, and using orthonormality to collapse the sum to the single
term $n=m$ — exactly the basis-expansion argument from your linear algebra
path, now applied to an infinite-dimensional function space instead of
$\mathbb R^n$). The new physical content, absent from pure linear algebra,
is the **measurement postulate**: $|c_n|^2$ is the probability that a
measurement of energy on a system in state $\psi$ returns the value $E_n$.
The Fourier-series machinery you already know is, in the box, literally
the machinery of quantum measurement statistics.

### 6. Superposition dynamics: beats, previewed

Consider an equal superposition of the two lowest stationary states,
$$\psi(x,t) = \frac{1}{\sqrt2}\Big[\phi_1(x)\,e^{-iE_1t/\hbar} +
\phi_2(x)\,e^{-iE_2t/\hbar}\Big].$$
Since $\phi_1,\phi_2$ are real, expanding $|\psi|^2=\psi^*\psi$ and using
$e^{i\theta}+e^{-i\theta}=2\cos\theta$ on the cross term gives
$$|\psi(x,t)|^2 = \tfrac12\Big[\phi_1(x)^2+\phi_2(x)^2\Big] +
\phi_1(x)\phi_2(x)\,\cos\!\left(\frac{E_2-E_1}{\hbar}\,t\right).$$
The probability density is no longer stationary at all: it oscillates
between the $\phi_1$-heavy and $\phi_2$-heavy shapes at angular frequency
$\Omega=(E_2-E_1)/\hbar$ — probability physically "sloshes" back and forth
inside the box. This is day 6's beat phenomenon (two nearby frequencies
superposing to produce a slow envelope oscillation), reappearing here not
in a displacement but in a probability density. The simulation below shows
this sloshing directly.

## Worked examples

**1. An electron in a $1\,\text{nm}$ box: $E_1$, $E_2$, and the $2\to1$
photon.**
Using $E_n=n^2\pi^2\hbar^2/(2mL^2)$ with $m=m_e=9.109\times10^{-31}\,
\text{kg}$, $\hbar=1.0546\times10^{-34}\,\text{J·s}$, $L=1\times10^{-9}\,
\text{m}$:
$$E_1 = \frac{\pi^2\hbar^2}{2m_eL^2} =
\frac{(9.8696)(1.1121\times10^{-68})}{2(9.109\times10^{-31})
(1\times10^{-18})} \approx 6.025\times10^{-20}\,\text{J} \approx
0.376\,\text{eV}.$$
Since $E_n\propto n^2$, $E_2 = 4E_1 \approx 1.504\,\text{eV}$. The $2\to1$
transition emits a photon carrying $\Delta E = E_2-E_1 = 3E_1 \approx
1.128\,\text{eV}$, so, using $hc = 1239.84\,\text{eV·nm}$,
$$\lambda = \frac{hc}{\Delta E} \approx \frac{1239.84\,\text{eV·nm}}
{1.128\,\text{eV}} \approx 1099\,\text{nm} \approx 1.10\,\mu\text{m},$$
in the near infrared — a useful sanity check that nanometer-scale
confinement (quantum dots, for instance) produces optical/near-IR
transition energies, the right order of magnitude for real devices.

**2. Normalizing $\phi_n$ from scratch.**
Demand $\int_0^L A^2\sin^2(n\pi x/L)\,dx = 1$. Substituting $u=n\pi x/L$
(so $dx=(L/n\pi)\,du$, $u:0\to n\pi$ as $x:0\to L$):
$$\int_0^L\sin^2\!\left(\frac{n\pi x}{L}\right)dx =
\frac{L}{n\pi}\int_0^{n\pi}\sin^2u\,du =
\frac{L}{n\pi}\left[\frac{u}{2}-\frac{\sin2u}{4}\right]_0^{n\pi} =
\frac{L}{n\pi}\cdot\frac{n\pi}{2} = \frac{L}{2}$$
(the $\sin2u$ term vanishes at both limits since $2n\pi$ is a multiple of
$2\pi$). So $A^2(L/2)=1$, giving $A=\sqrt{2/L}$ — the same constant for
every $n$, confirming the general result derived in Theory Section 4.

**3. Ground-state probability in the middle third of the box.**
Find $P = \int_{L/3}^{2L/3}|\phi_1(x)|^2\,dx$ with $\phi_1 =
\sqrt{2/L}\sin(\pi x/L)$. Using $\sin^2\theta = \tfrac12(1-\cos2\theta)$:
$$P = \frac{2}{L}\int_{L/3}^{2L/3}\tfrac12\left(1-\cos\frac{2\pi x}{L}
\right)dx = \frac1L\left[x - \frac{L}{2\pi}\sin\frac{2\pi x}{L}
\right]_{L/3}^{2L/3}.$$
At $x=2L/3$: $\sin(4\pi/3) = -\sqrt3/2$. At $x=L/3$: $\sin(2\pi/3) =
\sqrt3/2$. So
$$P = \frac1L\left[\left(\frac{2L}{3} + \frac{L\sqrt3}{4\pi}\right) -
\left(\frac{L}{3} - \frac{L\sqrt3}{4\pi}\right)\right] =
\frac13 + \frac{\sqrt3}{2\pi} \approx 0.3333 + 0.2757 \approx 0.609.$$
Even in the ground state, the particle is found in the (geometrically
one-third-sized) middle band with probability $\approx60.9\%$, well above
the naive classical uniform-distribution guess of exactly $1/3$ — the
ground state's single central hump concentrates probability in the middle
of the box.

## Simulation

Run:
```
python3 code/day16_box_eigenstates.py
```
Two panels: **(a)** the first five box eigenfunctions $\phi_n$, drawn
inside the well and offset vertically at heights proportional to their
$E_n$ on a marked energy ladder, with $|\phi_n|^2$ overlaid as a lighter
curve — the standard textbook figure, showing quantized levels growing
quadratically apart and eigenfunction shapes gaining one node per level;
**(b)** the two-state superposition $|\psi(x,t)|^2$ from Theory Section 6,
sampled at five equally spaced times across half a sloshing period,
showing probability visibly sloshing left and right inside the box.

Before running, predict:
- Double the box width $L$ — each $E_n$ changes by what factor?
- Which $\phi_n$ (among the first five) has a node exactly at the box's
  center?
- In the superposition panel, predict the sloshing period from
  $E_2-E_1$ before reading it off the plot.

*The script ships separately; the predict-prompts stand on their own.*

## Exercises

Attempt every problem closed-book before checking the Hints, and only
then the Solutions.

**Retrieval**

1. Closed book: starting from the free-particle plane wave $\psi=
   e^{i(kx-\omega t)}$ and the de Broglie relations $p=\hbar k$,
   $E=\hbar\omega$, reconstruct the operator identifications $\hat p=
   -i\hbar\partial_x$, $\hat E=i\hbar\partial_t$, and the resulting TDSE.
2. Closed book: starting only from $V=0$ inside $[0,L]$, $V=\infty$
   outside, and the boundary conditions this forces, solve for the
   quantized $E_n$ and $\phi_n$ of the infinite square well.

**Standard**

3. A proton and an electron are each (hypothetically) confined to the
   *same* box of width $L$. Find the ratio of their energy-level
   spacings, and then explain — bringing in realistic length scales —
   why real nuclei need MeV-scale photons for transitions where atoms
   need only eV-scale photons.
4. Verify $\int_0^L\phi_1(x)\phi_2(x)\,dx = 0$ by explicit integration.

**Stretch**

5. A particle sits in the ground state of a box of width $L$. The right
   wall is suddenly (instantaneously) moved out to $2L$, so the particle
   is now in a bigger box, but its wavefunction has not had time to
   change: $\psi(x,0)$ is still the *old* ground state $\phi_1^{\text{old}}
   (x)$ for $0<x<L$, and (necessarily) zero for $L<x<2L$. Set up the
   integrals $c_n = \int_0^{2L}\phi_n^{\text{new}}(x)\,\psi(x,0)\,dx$ for
   the new box's eigenstates $\phi_n^{\text{new}}$, compute $c_1$
   numerically, and interpret why $|c_1|^2<1$.

## Hints

1. Differentiate the plane wave once in $x$ and once in $t$, compare each
   result to $p\psi$ and $E\psi$ respectively to read off the operators,
   then promote $E=p^2/2m+V$ to an operator statement acting on $\psi$.
2. Solve $\phi''=-k^2\phi$ inside the well, apply $\phi(0)=0$ first to
   kill one term, then apply $\phi(L)=0$ and ask what values of $kL$ avoid
   forcing $\phi\equiv0$.
3. Write $E_n\propto1/m$ at fixed $L$ for the ratio; for the MeV-vs-eV
   question, note $E_n\propto1/(mL^2)$ and compare how much $L$ shrinks
   going from an atomic size to a nuclear size against how much $m$ grows
   going from electron to proton.
4. Use the product-to-sum identity $\sin A\sin B =
   \tfrac12[\cos(A-B)-\cos(A+B)]$ with $A=\pi x/L$, $B=2\pi x/L$, then
   integrate each cosine term over $[0,L]$ separately.
5. Write the new box's normalized eigenstates $\phi_n^{\text{new}}(x) =
   \sqrt{1/L}\sin(n\pi x/2L)$ on $[0,2L]$, restrict the integral for $c_n$
   to $[0,L]$ (where $\psi(x,0)$ is nonzero), and use the same
   product-to-sum identity as Exercise 4 for $n=1$.

## Solutions

**1.** Differentiating $\psi=e^{i(kx-\omega t)}$: $\partial_x\psi=ik\psi
\Rightarrow -i\hbar\partial_x\psi=\hbar k\psi=p\psi$, so $\hat p=
-i\hbar\partial_x$. Similarly $\partial_t\psi=-i\omega\psi \Rightarrow
i\hbar\partial_t\psi=\hbar\omega\psi=E\psi$, so $\hat E=i\hbar\partial_t$.
Promoting $E=p^2/2m+V$ with these operators, acting on $\psi$, and using
$\hat p^2 = (-i\hbar\partial_x)^2=-\hbar^2\partial_x^2$:
$$i\hbar\,\partial_t\psi = -\frac{\hbar^2}{2m}\partial_x^2\psi + V\psi.$$

**2.** Inside the well, $V=0$, so $-\tfrac{\hbar^2}{2m}\phi''=E\phi
\Rightarrow \phi''=-k^2\phi$ with $k=\sqrt{2mE/\hbar^2}$, general solution
$\phi=A\sin kx+B\cos kx$. $\phi(0)=0\Rightarrow B=0$. $\phi(L)=A\sin
kL=0$; taking $A=0$ gives the trivial $\phi\equiv0$ (unphysical), so
instead $\sin kL=0\Rightarrow kL=n\pi$, $n=1,2,3,\ldots$ ($n=0$ excluded
since it also forces $\phi\equiv0$). Then $k_n=n\pi/L$ gives $E_n=
\hbar^2k_n^2/2m = n^2\pi^2\hbar^2/(2mL^2)$, and normalizing
$A\sin(n\pi x/L)$ as in Worked Example 2 gives $A=\sqrt{2/L}$, so
$\phi_n(x)=\sqrt{2/L}\sin(n\pi x/L)$.

**3.** At fixed $L$, $E_n\propto1/m$, so the level-spacing ratio for
proton vs. electron is simply
$$\frac{\Delta E_{\text{proton}}}{\Delta E_{\text{electron}}} =
\frac{m_e}{m_p} \approx \frac{1}{1836}$$
— a proton confined to the *same* box has $1836\times$ *smaller* level
spacings than an electron, the opposite of "needing more energy." The
resolution is that real nuclei are not the same size as atoms: atomic
confinement is $L_{\text{atom}}\sim1\,\text{nm}$ (Worked Example 1 gave
$E_1\approx0.376\,\text{eV}$ there), while nuclear confinement is
$L_{\text{nucleus}}\sim5\,\text{fm}=5\times10^{-15}\,\text{m}$, about
$2\times10^5$ times smaller. Since $E_n\propto1/(mL^2)$, the ratio of a
proton's ground energy in the nuclear box to the electron's ground energy
in the atomic box is
$$\frac{E_1^{\,p}}{E_1^{\,e}} = \frac{m_e}{m_p}\left(\frac{L_{\text{atom}}}
{L_{\text{nucleus}}}\right)^2 \approx \frac{1}{1836}\times
\left(\frac{10^{-9}}{5\times10^{-15}}\right)^2 =
\frac{1}{1836}\times(2\times10^5)^2 \approx 2.18\times10^7,$$
so $E_1^{\,p} \approx 0.376\,\text{eV}\times2.18\times10^7 \approx
8.2\,\text{MeV}$. The enormous shrinkage in $L$ (squared) overwhelms the
$1836\times$ mass penalty by many orders of magnitude, which is exactly
why nuclear transitions sit at MeV while atomic transitions sit at eV —
size, not mass, sets the scale.

**4.** With $\phi_1=\sqrt{2/L}\sin(\pi x/L)$, $\phi_2=\sqrt{2/L}
\sin(2\pi x/L)$:
$$\int_0^L\phi_1\phi_2\,dx = \frac2L\int_0^L
\sin\!\left(\frac{\pi x}{L}\right)\sin\!\left(\frac{2\pi x}{L}\right)dx.$$
Using $\sin A\sin B=\tfrac12[\cos(A-B)-\cos(A+B)]$ with $A=\pi x/L$,
$B=2\pi x/L$ (so $A-B=-\pi x/L$, $A+B=3\pi x/L$):
$$= \frac1L\int_0^L\left[\cos\!\left(\frac{\pi x}{L}\right) -
\cos\!\left(\frac{3\pi x}{L}\right)\right]dx.$$
Each term integrates to zero separately:
$$\int_0^L\cos\!\left(\frac{\pi x}{L}\right)dx =
\frac{L}{\pi}\big[\sin\pi-\sin0\big] = 0, \qquad
\int_0^L\cos\!\left(\frac{3\pi x}{L}\right)dx =
\frac{L}{3\pi}\big[\sin3\pi-\sin0\big] = 0.$$
So $\int_0^L\phi_1\phi_2\,dx = 0$, confirming orthogonality by direct
computation.

**5.** The new box ($[0,2L]$) has normalized eigenstates
$\phi_n^{\text{new}}(x) = \sqrt{1/L}\sin(n\pi x/2L)$ (normalizing over
$[0,2L]$ the same way as Worked Example 2, with $2L$ in place of $L$).
Since $\psi(x,0)=\sqrt{2/L}\sin(\pi x/L)$ on $[0,L]$ and $0$ on $[L,2L]$,
$$c_n = \int_0^{2L}\phi_n^{\text{new}}(x)\,\psi(x,0)\,dx =
\sqrt{\frac{2}{L^2}}\int_0^L \sin\!\left(\frac{n\pi x}{2L}\right)
\sin\!\left(\frac{\pi x}{L}\right)dx.$$
For $n=1$: using the same product-to-sum identity as Exercise 4 with
$A=\pi x/2L$, $B=\pi x/L$ (so $A-B=-\pi x/2L$, $A+B=3\pi x/2L$),
$$\int_0^L\sin\!\left(\frac{\pi x}{2L}\right)\sin\!\left(\frac{\pi x}{L}
\right)dx = \frac12\int_0^L\left[\cos\!\left(\frac{\pi x}{2L}\right) -
\cos\!\left(\frac{3\pi x}{2L}\right)\right]dx$$
$$= \frac12\left(\left[\frac{2L}{\pi}\sin\frac{\pi x}{2L}\right]_0^L -
\left[\frac{2L}{3\pi}\sin\frac{3\pi x}{2L}\right]_0^L\right) =
\frac12\left(\frac{2L}{\pi}(1) - \frac{2L}{3\pi}(-1)\right) =
\frac12\left(\frac{2L}{\pi}+\frac{2L}{3\pi}\right) = \frac{4L}{3\pi}.$$
So
$$c_1 = \frac{\sqrt2}{L}\cdot\frac{4L}{3\pi} = \frac{4\sqrt2}{3\pi}
\approx 0.600, \qquad |c_1|^2 = \frac{32}{9\pi^2} \approx 0.360.$$
$|c_1|^2\approx36\%$ is the probability that an *energy measurement* right
after the sudden expansion would find the particle in the new box's ground
state. It is well below $1$ because the old ground-state wavefunction —
confined entirely to the left half of the new, doubled box — is *not* an
eigenstate of the new, bigger box at all; it is a superposition of
infinitely many new eigenstates, and the sudden expansion has genuinely
excited the particle into a mix of new energy levels rather than leaving
it purely in the new ground state. (A short consistency check: the new
$n=2$ eigenstate, $\sqrt{1/L}\sin(\pi x/L)$ on $[0,2L]$, coincides in
shape with $\psi(x,0)$ exactly on $[0,L]$, giving an even larger $|c_2|^2=
1/2$ — the true "nearest" state to the frozen wavefunction is $n=2$, not
$n=1$, and $|c_1|^2+|c_2|^2\approx0.86<1$ leaves the rest spread over
$n=3,4,\ldots$, consistent with normalization.)

## Connection to QM

Today is the day the last two months of preparation cash out directly:
the TISE $\hat H\phi=E\phi$ *is* the eigenvalue problem your course opens
with, just specialized from an abstract Hermitian operator on a
finite-dimensional $\mathbb C^n$ (the spectral theorem you already proved
for unitary and Hermitian matrices) to a differential operator on an
infinite-dimensional space of functions — same structure, same
orthogonality, same "diagonalize and read off the physics" strategy,
now with the extra machinery of boundary conditions replacing the finite
matrix. The measurement postulate you'll formalize early in the course
($|c_n|^2$ as outcome probability, $\{\phi_n\}$ as the measurement basis)
is exactly Section 5 above, already exercised on a completely solved,
completely honest example rather than stated as an abstract axiom.

The particle in a box is also the course's recurring toy model: every
perturbation-theory calculation, every discussion of tunneling and finite
wells, and every "add a small correction to a solvable system" exercise
you will meet takes today's clean $E_n$ and $\phi_n$ as the base case to
perturb away from. And the photonics tie flagged in day 14's laser
section is not a metaphor — a laser cavity's resonant modes obey literally
the same boundary-condition mathematics as today's box (Dirichlet-type
conditions at two reflecting walls), so day 6's string, day 13's cavity
modes, and today's box are one recurring piece of mathematics wearing
three different physical costumes.
