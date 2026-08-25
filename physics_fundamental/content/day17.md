# Day 17 — The Quantum Oscillator, Tunneling, and Heisenberg's Uncertainty Principle

## Learning objectives

By the end of today you should be able to:
- State the quantum harmonic oscillator (QHO) spectrum
  $E_n=\hbar\omega_0(n+\tfrac12)$, explain why the levels are evenly
  spaced, and verify by direct differentiation that the Gaussian ground
  state solves the time-independent Schrödinger equation (TISE) for the
  QHO potential.
- Reproduce the zero-point-energy uncertainty estimate closed book and
  compute molecular zero-point energies from a spectroscopic $\omega_0$,
  comparing them against $k_BT$.
- Derive the decaying-exponential solution in a classically forbidden
  region, state the tunneling decay constant $\kappa$, and use the
  transmission estimate $\sim e^{-2\kappa d}$ to compare tunneling rates
  across particle masses.
- Convert Day 7's bandwidth theorem into Heisenberg's relation $\Delta
  x\,\Delta p \ge \hbar/2$ and use it for order-of-magnitude confinement
  and atomic-size estimates.
- State the free Gaussian spreading law and explain, via Ehrenfest's
  theorem, why macroscopic centers of mass still move classically; and
  correctly distinguish zero-point motion and tunneling from their most
  common misconceptions.

Time budget: ~4 hours.

## Reference material

- Griffiths, *Introduction to Quantum Mechanics*, ch. 2 — the harmonic
  oscillator and free-particle sections match today's spectrum, ground
  state, and packet-spreading material and uncertainty discussion.
- French & Taylor, *An Introduction to Quantum Physics* — chapters on
  wave packets, the uncertainty principle, and barrier penetration,
  covering the same ground with more narrative and fewer formal steps.
- Self-contained; neither text is required. Builds on Day 3 (classical
  oscillator, $\omega_0$), Day 7 (bandwidth theorem, Gaussian packets),
  and Day 16 (TISE, box, node-counting rule); touches Day 2's
  forbidden-region language, Day 8's electromagnetic waves, Day 12's
  freeze-out flag, and Day 13's field-mode-as-oscillator picture.

## Theory

### 1. Setting up the quantum oscillator

Day 3 built the classical oscillator by Taylor-expanding any potential
around a minimum: near an equilibrium point $x_0$, $V(x)\approx
V(x_0)+\tfrac12 V''(x_0)(x-x_0)^2$, giving $V(x)=\tfrac12 m\omega_0^2x^2$
(shifting the origin to $x_0$, dropping the constant) with
$\omega_0=\sqrt{V''(x_0)/m}$. That same quadratic potential, dropped into
the TISE from Day 16,
$$-\frac{\hbar^2}{2m}\frac{d^2\psi}{dx^2} + \frac12 m\omega_0^2x^2\,\psi
= E\psi,$$
defines the **quantum harmonic oscillator (QHO)** — arguably the single
most-used solvable system in all of quantum mechanics, because *any*
smooth potential looks quadratic near a minimum, and because (as beat 4
below explains) a mode of a quantized field is exactly this equation.

Solving this in general means finding every normalizable $\psi$ and $E$
that satisfy it. Honestly: the general method — a power-series ansatz
matched order by order, forced to terminate — is real algebraic labor
(the Hermite-polynomial machinery), and we are not grinding through it
today; your course will redo it faster with operator methods. What we
*will* do fully is verify the two lowest solutions by direct
substitution, enough to read off the whole pattern.

### 2. The ground state is a Gaussian

The claim: the ground state is
$$\phi_0(x) = A\,e^{-m\omega_0x^2/(2\hbar)}.$$
Worked Example 1 below substitutes this directly into the TISE above,
term by term, and shows it works only if the exponent's coefficient takes
exactly the value written here — reading off $E_0=\tfrac12\hbar\omega_0$
in the process. That the quantum ground state is a bell curve peaked at
the center, while the classical oscillator spends most of its time near
the (slow) turning points instead, is a first hint of how different the
two pictures are; Exercise 1 asks you to sketch this contrast.

### 3. The first excited state, and the node-counting rule

The next solution up the ladder is
$$\phi_1(x) \propto x\,e^{-m\omega_0x^2/(2\hbar)},$$
with energy $E_1=\tfrac32\hbar\omega_0$ (the same substitution-and-match
procedure as Worked Example 1 confirms this, one notch harder; we won't
repeat the algebra). Structurally, $\phi_1$ is the ground-state Gaussian
multiplied by $x$: it is odd, and it has exactly one node, at $x=0$. This
matches the node-counting rule you met for the particle in a box on
Day 16 — the $n$-th energy level (counting the ground state as $n=0$) has
exactly $n$ nodes — and it holds for every bound-state spectrum in one
dimension, not just the box. Each higher rung $\phi_n$ is this same
Gaussian times a degree-$n$ polynomial (the Hermite polynomials, which we
are deferring), always contributing exactly $n$ nodes.

### 4. Why even spacing is the headline

The full spectrum is
$$E_n = \hbar\omega_0\left(n+\frac12\right), \qquad n=0,1,2,\dots$$
Contrast this with the particle in a box (Day 16), where $E_n\propto n^2$
and the *gaps* between levels grow without bound as $n$ increases. Here
every gap is identical:
$$E_{n+1}-E_n = \hbar\omega_0\left(n+\frac32\right) -
\hbar\omega_0\left(n+\frac12\right) = \hbar\omega_0,$$
for every $n$. Even spacing is not a curiosity — it is the reason the QHO
matters so much more than any other exactly-solvable potential.

Day 13 showed that a mode of a quantized electromagnetic field behaves,
mathematically, exactly like a mechanical oscillator of some frequency
$\omega$. Bolt that fact onto today's spectrum: the allowed energies of
one field mode are $\hbar\omega(n+\tfrac12)$, an evenly spaced ladder of
*countable energy lumps* sitting above an unavoidable zero-point floor.
Climbing from rung $n$ to rung $n+1$ always costs exactly one quantum
$\hbar\omega$ — and "one quantum of a light mode" is precisely what a
**photon** is. "The field has $n$ photons in this mode" now has an exact,
countable meaning: the mode sits on rung $n$ of this ladder. The raising
and lowering operators you will meet in the course, conventionally named
$a^\dagger$ (creation) and $a$ (annihilation), are built to literally
step a state up or down one rung — one photon — at a time; we are only
naming that vocabulary today, with the operator algebra itself deferred
to the course.

### 5. Zero-point energy: why nothing can sit still at the bottom

The lowest rung is not $E=0$ but $E_0=\tfrac12\hbar\omega_0$ — the
**zero-point energy**. Worked Example 1 gets this number exactly by
solving the TISE; here is *why* it has to be positive, using nothing but
an uncertainty-principle estimate (Heisenberg's relation itself is
derived properly in beat 7 below, but its content — confining a particle
in position costs momentum spread — is usable now).

Model a particle confined to some characteristic spread $\Delta x$ around
the bottom of the well. Confinement forces a momentum spread obeying (at
the saturating, best-case equality) $\Delta p = \hbar/(2\Delta x)$, so the
particle carries an irreducible kinetic energy on top of whatever
potential energy its spread costs:
$$E(\Delta x) \;\sim\; \frac{(\Delta p)^2}{2m} + \frac12 m\omega_0^2
(\Delta x)^2 \;=\; \frac{\hbar^2}{8m(\Delta x)^2} + \frac12
m\omega_0^2(\Delta x)^2.$$
Both terms are positive, and they trade off oppositely with $\Delta x$: the
kinetic piece falls as $\Delta x$ grows (a wider spread eases the momentum
squeeze), while the potential piece grows with $\Delta x$ (a wider spread
climbs the walls of the well). Minimize over $\Delta x$ by differentiating
and setting the result to zero:
$$\frac{dE}{d(\Delta x)} = -\frac{\hbar^2}{4m(\Delta x)^3} + m\omega_0^2
\Delta x = 0 \quad\Longrightarrow\quad (\Delta x)^4 =
\frac{\hbar^2}{4m^2\omega_0^2} \quad\Longrightarrow\quad (\Delta x)^2 =
\frac{\hbar}{2m\omega_0}.$$
Substituting this back into $E(\Delta x)$:
$$E_{\min} = \frac{\hbar^2}{8m}\cdot\frac{2m\omega_0}{\hbar} +
\frac12 m\omega_0^2\cdot\frac{\hbar}{2m\omega_0} = \frac{\hbar\omega_0}{4}
+ \frac{\hbar\omega_0}{4} = \frac{\hbar\omega_0}{2}.$$
This lands exactly on $E_0=\tfrac12\hbar\omega_0$ — no "factor of a few"
hedge needed, because the QHO's Gaussian ground state genuinely saturates
the uncertainty bound with equality. The physical content survives
regardless of that coincidence: **there is no value of $\Delta x$,
however small or large, at which $E(\Delta x)$ reaches zero.** Shrinking
$\Delta x$ to sit "at the bottom" drives the kinetic term to infinity —
perfectly still means $\Delta x=0$ and hence infinite momentum spread.
Some minimum energy is unavoidable — structurally, not thermally.

> **Misconception:** "Zero-point energy is just leftover thermal
> jiggling — cool the system enough and it goes away." It does not. The
> derivation above never mentioned temperature; it is a statement about
> confinement and the uncertainty principle, true even in the strict limit
> $T\to0$. Two physical facts confirm it: molecular vibrations carry
> exactly this zero-point energy in their lowest state no matter how cold
> the sample is (Worked Example 2 computes it for CO); and liquid
> helium-4 never freezes at ordinary atmospheric pressure, all the way
> down to absolute zero — its atoms' zero-point motion is large enough
> (because helium is light and weakly bound) to keep shaking the lattice
> apart, and only high pressure (tens of atmospheres) can force it solid.

### 6. Tunneling: amplitude where classically nothing can go

Day 2 introduced the language of a classically forbidden region: wherever
the total energy $E$ is less than the potential $V(x)$, a classical
particle cannot be there at all (its kinetic energy would have to be
negative). Quantum mechanically, drop $E<V$ into the TISE on that region
(constant $V$ for simplicity):
$$-\frac{\hbar^2}{2m}\psi'' + V\psi = E\psi \quad\Longrightarrow\quad
\psi'' = \frac{2m(V-E)}{\hbar^2}\,\psi = \kappa^2\psi, \qquad
\kappa \equiv \frac{\sqrt{2m(V-E)}}{\hbar}.$$
Because $V>E$, the right-hand coefficient $\kappa^2$ is positive — contrast
this with the classically *allowed* region, where $E>V$ flips the sign and
the TISE reads $\psi''=-k^2\psi$ with real $k=\sqrt{2mE}/\hbar$ (Day 16's
oscillatory box solutions $\sin,\cos$). A positive coefficient has
**exponential**, not oscillatory, solutions:
$$\psi(x) = C\,e^{\kappa x} + D\,e^{-\kappa x}.$$
On a barrier extending to $x\to+\infty$, normalizability kills the
growing piece ($C=0$), leaving a pure decaying tail $\psi\propto
e^{-\kappa x}$: the wavefunction doesn't vanish the instant it crosses
into $V>E$ territory, it decays smoothly, carrying nonzero amplitude into
a region a classical particle could never enter.

For a *thin* barrier of width $d$, that decaying tail hasn't died out by
the far side, so some amplitude survives to leak through and continue as
an ordinary wave beyond it. Matching $\psi$ and its slope at both edges
(the same continuity conditions Day 16 used at the box walls) is more
bookkeeping than we need today; the useful result is that transmission
falls off as
$$T \;\sim\; e^{-2\kappa d}$$
for a barrier thick enough that $\kappa d\gg1$ (stated here, not
re-derived). Note $\kappa\propto\sqrt{m}$, so tunneling favors light
particles heavily (Exercise 4), and $T$ falls off exponentially in both
$d$ and $\sqrt{V-E}$ — the sensitivity the STM below exploits.

This is exactly the same mathematics as an **evanescent light wave** — an
optical effect this path has not covered, but one that happens to Day 8's
electromagnetic waves, and worth meeting here for the parallel.
Total internal reflection doesn't kill the field on the far side of the
interface outright — it produces an evanescent field that decays
exponentially, carrying no energy away on its own, and if a second
medium is brought close enough within that decay length some light
couples across and re-emerges as a genuine propagating wave — "frustrated"
total internal reflection. A tunneling wavefunction and an evanescent
light wave obey the same kind of equation for the same reason: both are
waves meeting a region where the local wave equation demands real
exponentials instead of oscillations.

> **Misconception:** "A tunneling particle briefly borrows energy it
> doesn't have, violating energy conservation, and pays it back later."
> Energy is conserved throughout, with no exception: $E$ is a single
> fixed number — an eigenvalue of the stationary wavefunction — the same
> on both sides of the barrier and inside it. What changes inside is not
> the particle's energy but the *character* of the wavefunction: it stops
> oscillating and starts decaying, because there is no classical
> trajectory where $E<V$. Nothing is borrowed; there is simply amplitude
> leaking through where a classical particle could not go, with $E$
> unchanged the entire time.

Tunneling is not an exotic laboratory curiosity. **Alpha decay**: an
alpha particle sits behind a Coulomb barrier it could never classically
climb, yet nuclei decay at a rate set almost entirely by $e^{-2\kappa d}$
(Gamow's explanation, and the origin of the huge spread in observed
half-lives). **Tunnel diodes**: junctions thin enough that electrons
tunnel straight through, giving current-voltage behavior ordinary diodes
cannot produce. **The scanning tunneling microscope (STM)**: a tip held a
fraction of a nanometer above a surface, imaging it atom by atom via a
current exponentially sensitive to the gap $d$ through exactly the
$e^{-2\kappa d}$ law above.

### 7. Heisenberg's relation, from wave mathematics you already have

Day 7 proved a fact about *any* wave built from a superposition of
frequencies: no wave packet can be simultaneously narrow in position and
narrow in wave number, and specifically a Gaussian packet saturates the
bound with equality,
$$\Delta x\,\Delta k = \frac12,$$
with $\Delta x\,\Delta k\gtrsim1$ for a general packet shape. Day 7 was
careful to flag this as *a fact about waves, not quantum mechanics* — it
follows from Fourier analysis alone and applies equally to a pulse of
sound or a ripple of water.

Quantum mechanics enters through a single physical fact: de Broglie's
relation $p=\hbar k$. A spread in wave number $\Delta k$ is therefore a
spread in momentum $\Delta p=\hbar\,\Delta k$. Multiply the Gaussian
equality above through by $\hbar$:
$$\hbar\,\Delta x\,\Delta k = \Delta x\,(\hbar\Delta k) = \Delta x\,\Delta p
= \frac{\hbar}{2} \qquad\text{(Gaussian equality)},$$
and, since every other packet shape only does worse ($\Delta x\,\Delta
k\gtrsim1$ in general),
$$\boxed{\Delta x\,\Delta p \ge \frac{\hbar}{2}}$$
in general. This is **Heisenberg's uncertainty relation**. It is not a new
postulate bolted onto quantum mechanics from outside; it is Day 7's
wave-packet mathematics wearing $p=\hbar k$ — and this is exactly the route
your course will retrace formally, replacing "Fourier transform pair"
with "operators that don't commute," to derive the same inequality for any
pair of incompatible observables.

**What it does and does not say.** $\Delta x$ and $\Delta p$ are the
statistical spreads (standard deviations) of position and momentum
outcomes across a large ensemble of *identically prepared* copies of the
same quantum state — never a statement about one clumsy or disturbing
measurement on a single particle. Concretely: prepare the same state a
thousand times, measure position on half the copies and momentum on the
other half (never both on one copy, since measuring alters the state);
the two resulting histograms have spreads obeying $\Delta x\,\Delta
p\ge\hbar/2$. This is a property of the *state itself* — the shape of
$\psi$ — not of apparatus quality or an unavoidable jolt from looking; a
perfect, disturbance-free instrument could not evade it, because the
limitation lives in the wavefunction's own Fourier structure, exactly as
Day 7 showed for classical wave packets.

The relation powers real estimates, not just a formal bound: it explains
why an electron cannot be confined inside a nucleus (Exercise 3's method,
scaled to nuclear size, gives a kinetic energy vastly larger than nuclear
binding energies) and, as Worked Example 3 shows, why hydrogen has the
size and binding energy it does.

### 8. Free Gaussian packet spreading, and Ehrenfest's teaser

For a free particle ($V=0$), a Gaussian wave packet initially of width
$\Delta x_0$ does not sit still — Day 7's dispersion relation means
different momentum components travel at different phase and group
speeds, and a packet with a large momentum spread $\Delta k$ (equivalently
a small $\Delta x_0$, by the bandwidth theorem) spreads out faster. The
exact result, stated here rather than derived (the derivation requires
propagating each Fourier component of the initial Gaussian forward in
time and reassembling the packet, a calculation your course will carry
out formally):
$$\Delta x(t) = \Delta x_0\sqrt{1+\left(\frac{\hbar t}{2m(\Delta x_0)^2}
\right)^2}.$$
Read backward from the formula: $\Delta x(t)\to\Delta x_0$ as $t\to0$
(no spreading yet) and $\Delta x(t)$ grows roughly linearly in $t$ once
$t$ is large; and — matching the qualitative point above — a *smaller*
$\Delta x_0$ makes the correction term $\hbar t/(2m\Delta x_0^2)$ larger
for the same $t$, so **narrower packets spread faster**, not slower. This
is the same content as the uncertainty relation read as a rate: squeezing
the initial position spread forces a larger momentum spread, and a larger
momentum spread means a wider range of velocities racing the packet apart
sooner.

One more piece, as a teaser rather than a full derivation: **Ehrenfest's
theorem** states that expectation values obey Newton-like equations,
$d\langle x\rangle/dt = \langle p\rangle/m$ and $d\langle p\rangle/dt =
-\langle dV/dx\rangle$, for *any* quantum state in *any* potential. For a
free particle or oscillator specifically — both quadratic in $x$ at
most — the force $-dV/dx$ is linear in $x$, so $\langle dV/dx\rangle$
equals $dV/dx$ at the single point $\langle x\rangle$ exactly, with no
approximation. So $\langle x(t)\rangle$ traces the *exact* classical
trajectory even while the packet's width spreads (free particle) or
breathes (oscillator) independently around that moving center: quantum
uncertainty shows up entirely in the spread, never in where the center
goes — exactly why Exercise 5's thrown ball obeys ordinary Newtonian
mechanics despite its wavefunction technically spreading the whole time.

## Worked examples

**1. Verify the Gaussian ground state solves the QHO TISE; normalize it;
read off $E_0$.**

Try $\phi_0(x)=Ae^{-\alpha x^2}$ for an undetermined constant $\alpha>0$,
and substitute into the TISE
$-\frac{\hbar^2}{2m}\phi_0''+\frac12m\omega_0^2x^2\phi_0=E\phi_0$.
Differentiate twice:
$$\phi_0' = -2\alpha x\,\phi_0, \qquad
\phi_0'' = -2\alpha\,\phi_0 + (-2\alpha x)(-2\alpha x\,\phi_0)
= \left(-2\alpha + 4\alpha^2x^2\right)\phi_0.$$
Substitute:
$$-\frac{\hbar^2}{2m}\left(-2\alpha+4\alpha^2x^2\right)\phi_0 +
\frac12m\omega_0^2x^2\phi_0 = E\phi_0,$$
$$\left(\frac{\hbar^2\alpha}{m}\right)\phi_0 +
\left(\frac12m\omega_0^2 - \frac{2\hbar^2\alpha^2}{m}\right)x^2\phi_0 =
E\phi_0.$$
For this to hold at *every* $x$ (not just one value), the $x^2\phi_0$ term
and the constant term must separately match the right-hand side's
constant $E\phi_0$ — meaning the coefficient of $x^2\phi_0$ on the left
must vanish:
$$\frac12m\omega_0^2 = \frac{2\hbar^2\alpha^2}{m}
\;\Longrightarrow\; \alpha^2 = \frac{m^2\omega_0^2}{4\hbar^2}
\;\Longrightarrow\; \alpha = \frac{m\omega_0}{2\hbar}$$
(taking the positive root, since $\alpha>0$ is required for
normalizability). This confirms the claimed form
$\phi_0(x)=Ae^{-m\omega_0x^2/(2\hbar)}$ exactly. What remains is the
constant term, which now directly gives the energy:
$$E_0 = \frac{\hbar^2\alpha}{m} = \frac{\hbar^2}{m}\cdot
\frac{m\omega_0}{2\hbar} = \frac{\hbar\omega_0}{2}.$$
So $\phi_0$ solves the TISE only for this one specific $\alpha$, and doing
so forces $E_0=\tfrac12\hbar\omega_0$ — the ground-state energy is not an
extra assumption, it falls straight out of demanding the substitution
work.

Normalizing: $\int_{-\infty}^{\infty}|\phi_0|^2dx = A^2\int e^{-2\alpha
x^2}dx = A^2\sqrt{\pi/(2\alpha)} = 1$, using the standard Gaussian integral
$\int e^{-cx^2}dx=\sqrt{\pi/c}$ with $c=2\alpha$. Solving,
$$A = \left(\frac{2\alpha}{\pi}\right)^{1/4} =
\left(\frac{m\omega_0}{\pi\hbar}\right)^{1/4}.$$
So the fully normalized ground state is $\phi_0(x)=
\left(\dfrac{m\omega_0}{\pi\hbar}\right)^{1/4}e^{-m\omega_0x^2/(2\hbar)}$.

**2. CO molecule vibration: zero-point energy versus room-temperature
thermal energy (closing Day 12, Exercise 4).**

Day 12, Exercise 4 asked why a diatomic gas's measured heat capacity
falls short of equipartition's prediction of $\tfrac72k_BT$ (three
translational, two rotational, two vibrational quadratic terms) near room
temperature, and flagged "which physics is responsible" as not yet
available — that physics is exactly today's zero-point/level-spacing
story.

Take, from spectroscopy (an experimental input, not something we derive),
the CO bond's vibrational frequency $\omega_0\approx4.04\times10^{14}$
rad/s (corresponding to a vibrational wavenumber near $2143\ \text{cm}^{-1}$,
a standard measured value for CO). The zero-point energy is
$$E_0 = \frac12\hbar\omega_0 = \frac12\left(1.055\times10^{-34}\
\text{J·s}\right)\left(4.04\times10^{14}\ \text{s}^{-1}\right)
\approx 2.13\times10^{-20}\ \text{J} \approx 0.133\ \text{eV}.$$
Compare with the thermal scale at room temperature, $T\approx300$ K:
$$k_BT = \left(8.617\times10^{-5}\ \text{eV/K}\right)(300\ \text{K})
\approx 0.026\ \text{eV}.$$
The level spacing $\hbar\omega_0\approx0.266$ eV is roughly ten times
$k_BT$, so exciting the *first* vibrational level above the ground state
costs vastly more thermal energy than is typically available; the
Boltzmann suppression factor $e^{-\hbar\omega_0/k_BT}\sim e^{-10}\sim
5\times10^{-5}$ makes that excitation exceedingly rare. Vibration is
frozen out at room temperature — precisely the "smaller count than
equipartition predicts" Day 12 flagged, now fully explained: the
vibrational quadratic term does contribute its $k_BT$ share only once
$k_BT$ becomes comparable to the level spacing $\hbar\omega_0$ (i.e., at
much higher temperature than room temperature for a stiff bond like
CO's).

**3. Hydrogen's size and binding energy from the uncertainty principle
alone.**

Model the electron as confined to some spread $\Delta x$ around the
proton, carrying kinetic energy from the confinement and Coulomb potential
energy from the attraction. Using the order-of-magnitude form
$\Delta p\sim\hbar/\Delta x$ (not the strict $\hbar/(2\Delta x)$ bound —
more on this choice below):
$$E(\Delta x) \sim \frac{\hbar^2}{2m(\Delta x)^2} - \frac{k_ee^2}{\Delta x},$$
where $k_e\equiv1/(4\pi\epsilon_0)$ is the Coulomb constant ($k_e$, not
$k$, to keep it clear of beat 6's wave number — the same symbol Day 14
used), $e$ the elementary charge, $m$ the electron mass. Minimize:
$$\frac{dE}{d(\Delta x)} = -\frac{\hbar^2}{m(\Delta x)^3} +
\frac{k_ee^2}{(\Delta x)^2} = 0 \;\Longrightarrow\;
\Delta x = \frac{\hbar^2}{mk_ee^2}.$$
This is *exactly* the textbook definition of the Bohr radius,
$a_0=\hbar^2/(mk_ee^2)\approx5.29\times10^{-11}$ m $=0.529$ Å — the
uncertainty-principle estimate reproduces hydrogen's size directly.
Substituting back:
$$E_{\min} = \frac{\hbar^2}{2m}\left(\frac{mk_ee^2}{\hbar^2}\right)^2 -
k_ee^2\left(\frac{mk_ee^2}{\hbar^2}\right) = \frac{mk_e^2e^4}{2\hbar^2} -
\frac{mk_e^2e^4}{\hbar^2} = -\frac{mk_e^2e^4}{2\hbar^2} \approx -13.6\
\text{eV},$$
landing on the exact Bohr ground-state energy. Be honest about what this
"exactness" is worth: it is a coincidence of hydrogen's numbers combined
with the choice $\Delta p\sim\hbar/\Delta x$ rather than the strict
inequality's $\hbar/(2\Delta x)$; the stricter bound shifts both numbers
by an $O(1)$–$O(4)$ factor (still the right order of magnitude, not
exactly $-13.6$ eV). An uncertainty-principle estimate should be trusted
for its *scale*, not its last digit — hydrogen landing on the textbook
number exactly is a pleasant bonus, not the rule.

## Simulation

Run `python3 code/day17_packet_evolution.py`.

The script shows two panels. Panel (a) evolves a free Gaussian wave
packet $\psi(x,t)$ analytically (the closed-form complex-Gaussian
solution, no PDE solver) and plots $|\psi(x,t)|^2$ at four snapshots in
time, annotating $\Delta x(t)$ on each snapshot so you can watch the
packet visibly widen. Panel (b) plots $\Delta x(t)$ against the stated
spreading-law formula for two different initial widths side by side, so
you can watch the narrower packet's curve overtake the wider one's.

Before running, predict:
- Halve the initial width $\Delta x_0$ — does the packet spread faster or
  slower?
- Increase the mass tenfold — what happens to the spreading time?
- At what time has the width doubled? Predict from the formula first,
  then measure it off the plot.

*The script ships separately; the predict-prompts stand on their own.*

## Exercises

Attempt every problem closed-book before checking the Hints, and only
then the Solutions.

**Retrieval**

1. State the QHO energy spectrum $E_n$, and sketch (describe in words is
   fine) $|\phi_0|^2$ and $|\phi_1|^2$: their symmetry (even/odd) and their
   node counts, contrasted with where a classical oscillator of the same
   energy would spend most of its time.
2. Reproduce, closed book, the zero-point-energy uncertainty estimate for
   the QHO: set up $E(\Delta x)$, minimize it, and state both $(\Delta x)^2$
   at the minimum and $E_{\min}$.

**Standard**

3. An electron is confined to a region of size $\Delta x=0.1$ nm
   (roughly one atomic radius). Using the equality form of Heisenberg's
   relation, find the minimum momentum spread $\Delta p$, and convert the
   corresponding kinetic-energy scale $(\Delta p)^2/(2m)$ into eV.
4. An electron approaches a $1$ eV, $0.5$ nm wide barrier. Compute
   $\kappa$ and the transmission estimate $e^{-2\kappa d}$. Then repeat
   for a proton facing the identical barrier ($V-E=1$ eV, $d=0.5$ nm),
   using $m_p/m_e\approx1836$. Explain in 2–3 sentences why chemistry
   routinely involves electron transfer between molecules but never
   proton "teleportation" through a comparable barrier.

**Stretch**

5. A thrown ball ($m=0.1$ kg) is localized to $\Delta x_0=1$ mm at the
   moment it leaves your hand. Using the free Gaussian spreading law,
   find the time $t_{\text{double}}$ at which its position spread has
   doubled ($\Delta x(t_{\text{double}})=2\Delta x_0$), and compare it to
   the age of the universe ($\approx4.3\times10^{17}$ s). Then write
   three sentences on why classical mechanics is entirely safe to use for
   thrown balls, cars, and planets, despite every quantum wave packet
   technically spreading forever.

## Hints

1. The spectrum was stated in Theory beat 4; for the sketches, recall that
   $\phi_0$ is a plain Gaussian (even, no nodes) and $\phi_1$ is $x$ times
   that Gaussian (odd, one node at the origin) — then think about where a
   classical oscillator moves *slowest* (and therefore spends the most
   time) at a given energy.
2. Write $E(\Delta x)\sim\dfrac{(\Delta p)^2}{2m}+\tfrac12m\omega_0^2
   (\Delta x)^2$ with $\Delta p=\hbar/(2\Delta x)$, differentiate with
   respect to $\Delta x$, and set the result to zero — exactly the
   computation in Theory beat 5.
3. Use $\Delta p=\hbar/(2\Delta x)$ directly (the equality case), then
   $(\Delta p)^2/(2m_e)$; convert joules to eV by dividing by
   $1.602\times10^{-19}$.
4. $\kappa=\sqrt{2m(V-E)}/\hbar$ with $V-E$ converted to joules first;
   then $2\kappa d$ with $d$ in meters. For the proton, $\kappa$ scales
   with $\sqrt{m}$, so just rescale the electron's $\kappa$ by
   $\sqrt{m_p/m_e}$ rather than recomputing from scratch.
5. Set $\Delta x(t_{\text{double}})=2\Delta x_0$ in the spreading formula,
   square both sides, and solve for the bracketed term before solving for
   $t$; don't forget the resulting square root of $3$.

## Solutions

**1.** $E_n=\hbar\omega_0(n+\tfrac12)$, $n=0,1,2,\dots$, evenly spaced by
$\hbar\omega_0$. $\phi_0\propto e^{-m\omega_0x^2/(2\hbar)}$ is even, with
no nodes, and $|\phi_0|^2$ is a bell curve peaked at $x=0$. $\phi_1
\propto xe^{-m\omega_0x^2/(2\hbar)}$ is odd, with one node at $x=0$, and
$|\phi_1|^2$ has two humps straddling the origin, vanishing exactly at
the center. This is the opposite of the classical oscillator's behavior
at the same energy: a classical oscillator moves fastest (spends the
*least* time) at the center and slowest (spends the *most* time) near
its turning points, so its classical probability density is peaked near
the edges of its motion, not the center — $|\phi_0|^2$'s central peak is
a genuinely nonclassical feature of the quantum ground state.

**2.** Set $E(\Delta x) = \dfrac{\hbar^2}{8m(\Delta x)^2} +
\dfrac12m\omega_0^2(\Delta x)^2$ (using $\Delta p=\hbar/(2\Delta x)$).
Differentiating and setting to zero:
$$-\frac{\hbar^2}{4m(\Delta x)^3} + m\omega_0^2\Delta x = 0
\;\Longrightarrow\; (\Delta x)^4 = \frac{\hbar^2}{4m^2\omega_0^2}
\;\Longrightarrow\; (\Delta x)^2 = \frac{\hbar}{2m\omega_0}.$$
Substituting back gives $E_{\min}=\dfrac{\hbar\omega_0}{4}+
\dfrac{\hbar\omega_0}{4}=\dfrac{\hbar\omega_0}{2}$, matching $E_0$ exactly.

**3.** $\Delta p = \dfrac{\hbar}{2\Delta x} = \dfrac{1.055\times10^{-34}}
{2(1\times10^{-10})} \approx 5.27\times10^{-25}$ kg·m/s. Kinetic-energy
scale:
$$\frac{(\Delta p)^2}{2m_e} = \frac{(5.27\times10^{-25})^2}
{2(9.109\times10^{-31})} \approx 1.53\times10^{-19}\ \text{J} \approx
0.95\ \text{eV}.$$
This is the order of magnitude of real atomic binding energies (compare
hydrogen's $13.6$ eV, itself set by the same confinement mechanism at a
similar length scale, Worked Example 3) — confining an electron to
sub-nanometer scales costs roughly an eV, which is exactly the currency
atomic physics runs on.

**4.** Electron: $V-E=1\ \text{eV}=1.602\times10^{-19}$ J.
$$\kappa = \frac{\sqrt{2m_e(V-E)}}{\hbar} =
\frac{\sqrt{2(9.109\times10^{-31})(1.602\times10^{-19})}}
{1.055\times10^{-34}} \approx 5.12\times10^{9}\ \text{m}^{-1}.$$
With $d=0.5\ \text{nm}=5\times10^{-10}$ m: $2\kappa d \approx 2(5.12
\times10^9)(5\times10^{-10}) \approx 5.12$, so $T\sim e^{-5.12}\approx
6\times10^{-3}$ — a small but very much nonzero transmission chance.

Proton: $\kappa$ scales as $\sqrt{m}$, and $m_p/m_e\approx1836$, so
$\sqrt{m_p/m_e}\approx42.8$, giving $\kappa_p\approx42.8\times5.12
\times10^9\approx2.19\times10^{11}\ \text{m}^{-1}$ and $2\kappa_pd
\approx219$, so $T\sim e^{-219}\approx10^{-96}$ — utterly negligible.
Chemistry involves electron transfer constantly (bonding, redox, charge
transport) because electron tunneling through molecular-scale barriers
sits at the fast, common $\sim10^{-3}$–$10^{-1}$ scale computed above;
the same barrier is, for all practical purposes, a solid wall to a
proton, whose extra mass suppresses $T$ by roughly ninety-three further
orders of magnitude. Proton tunneling isn't literally zero in nature (it
appears in some enzyme reactions over far thinner barriers), but nothing
like everyday electron transfer.

**5.** Set $\Delta x(t_{\text{double}})=2\Delta x_0$ in $\Delta x(t) =
\Delta x_0\sqrt{1+(\hbar t/(2m\Delta x_0^2))^2}$:
$$4 = 1 + \left(\frac{\hbar t_{\text{double}}}{2m(\Delta x_0)^2}\right)^2
\;\Longrightarrow\; \frac{\hbar t_{\text{double}}}{2m(\Delta x_0)^2} =
\sqrt3 \;\Longrightarrow\; t_{\text{double}} =
\frac{2m(\Delta x_0)^2\sqrt3}{\hbar}.$$
Plugging in $m=0.1$ kg, $\Delta x_0=1\times10^{-3}$ m (so $(\Delta x_0)^2
=1\times10^{-6}$ m$^2$):
$$t_{\text{double}} = \frac{2(0.1)(1\times10^{-6})(1.732)}
{1.055\times10^{-34}} \approx 3.3\times10^{27}\ \text{s}.$$
This is about $7.6\times10^9$ — roughly seven and a half *billion* —
times the age of the universe. The ball's wave packet is, strictly,
spreading every instant of flight, like any quantum wave packet; but the
spreading rate scales as $1/m$, and a $0.1$ kg ball is roughly $10^{29}$
times more massive than an electron, buying back enormous time on top of
the millimeter- rather than atomic-scale starting width. Classical
mechanics is safe for thrown balls, cars, and planets not because
quantum mechanics stops applying, but because the spreading timescale is
so many orders of magnitude beyond any timescale of interest — longer
than the universe has existed — that the classical trajectory is exact
for every practical purpose.

## Connection to QM

The quantum harmonic oscillator is the single most-used exactly-solvable
system ahead of you: every field mode, trapped-ion motional state, and
cavity photon mode is modeled as one of these ladders. "$n$ photons in a
mode" now has an exact, countable meaning — rung $n$ of beat 4's ladder —
and the ladder-operator vocabulary named today ($a$, $a^\dagger$,
creation/annihilation) is the formal machinery the course uses to move
between rungs without ever touching a Hermite polynomial.

Heisenberg's relation arrived not as an axiom from on high but as
Day 7's Fourier mathematics wearing $p=\hbar k$ — exactly the route the
course retraces, replacing "wave-packet bandwidth" with "operators that
fail to commute," to derive $\Delta x\,\Delta p\ge\hbar/2$ and eventually
a whole family of analogous relations from the same commutator logic.

Tunneling, finally, is the mechanism the course leans on whenever a
system's energy sits below a barrier it must cross: the formal treatment
ahead adds only the boundary-matching algebra to turn today's
"$T\sim e^{-2\kappa d}$" into an exact coefficient — the physics of *why*
particles cross forbidden regions is already fully in your hands.
