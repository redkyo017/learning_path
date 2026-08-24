# Day 10 — The Hamiltonian

## Learning objectives

By the end of today you should be able to:
- Construct the Hamiltonian $H(q,p)$ from a Lagrangian $L(q,\dot q)$ via the
  Legendre transform, eliminating $\dot q$ using $p=\partial L/\partial\dot q$.
- Derive Hamilton's equations $\dot q=\partial H/\partial p$ and
  $\dot p=-\partial H/\partial q$ from the differential of $H$, and use them
  to reproduce equations of motion you already know.
- State the condition under which $H=T+V$ (natural systems, time-independent
  constraints) and give an example of when it fails.
- Read a phase-space portrait fluently: identify fixed points, closed
  (bound) orbits, and a separatrix, and say what each one means physically.
- Explain in one paragraph why Hamiltonian flow preserves phase-space area
  (Liouville's theorem) and why that matters for statistical mechanics.

Time budget: ~3.5 hours.

## Reference material

- Taylor, *Classical Mechanics*, the chapter on Hamiltonian mechanics, or
  Goldstein, *Classical Mechanics*, the chapter covering the Legendre
  transform and Hamilton's equations — either treats today's construction
  more formally and generally (many degrees of freedom, general
  constraints) than the single-coordinate treatment below needs.
- This file is self-contained: every equation is derived from Day 9's
  results plus one geometric idea (the Legendre transform) introduced from
  scratch below.
- Builds directly on Day 9 (the Euler–Lagrange equation
  $\frac{d}{dt}\frac{\partial L}{\partial\dot q}=\frac{\partial L}{\partial q}$
  and the conjugate momentum $p=\partial L/\partial\dot q$) and reuses Day 2's
  $V(x)$-reading skills and Day 3's oscillator.

## Theory

Following Day 9's convention, today's file writes $L$ for the **Lagrangian**
and $T$ for **kinetic energy** (elsewhere in this course $L$ denotes angular
momentum and $K$ denotes kinetic energy; days 9–11 locally override both, and
today continues that override). We never write $\mathcal L$.

### Trading $(q,\dot q)$ for $(q,p)$: why bother

Day 9 left you with one **second-order** differential equation per
coordinate: the Euler–Lagrange equation
$\frac{d}{dt}\frac{\partial L}{\partial\dot q}=\frac{\partial L}{\partial q}$,
a single equation for $q(t)$ that involves $\ddot q$. Today reorganizes the
same physics into **two first-order** equations for the pair $(q,p)$ instead.
This isn't cosmetic bookkeeping: a system of first-order equations has a
uniform geometric picture (a *point* $(q,p)$ moving through a *flow field*,
built out in the Phase Space sections below) that a single second-order
equation for $q(t)$ alone doesn't offer as cleanly — velocity and position
sit on an equal footing, both first-order in time.

There is a second, larger reason this matters for this course specifically:
the object we're about to build, $H$, is **the object that generates time
evolution**. Today's $H$ is a function of $(q,p)$; when quantum mechanics
promotes $q$ and $p$ to operators (Day 16), $H$ becomes the operator that
appears, with an $i\hbar$ and a time derivative, in the single equation that
governs *everything* a quantum system does over time. Everything below is
building that object's classical ancestor.

### The Legendre transform, geometrically

Before applying it to mechanics, meet the tool itself on its own terms: the
**Legendre transform**. Take any convex function $f(v)$ (bowl-shaped — its
graph curves upward everywhere, so $f''(v)>0$). The ordinary way to describe
$f$ is to list, for every $v$, the height $f(v)$. There's a second, entirely
equivalent way to describe the same curve: **by its tangent lines** instead
of by its points.

Each tangent line to $f$ has some slope $p$ and touches the curve at exactly
one point $v(p)$ (convexity is exactly what guarantees "exactly one" — a
bowl-shaped curve has a strictly increasing slope, $f'(v)$, so each slope
value is achieved at a single $v$). That tangent line has the equation
$y = pv - g(p)$ for some vertical offset $g(p)$ depending only on the slope
$p$. The function
$$g(p) \;\equiv\; p\,v(p) - f(v(p)), \qquad \text{where } v(p) \text{ solves } f'(v)=p,$$
is the **Legendre transform** of $f$. Knowing $g(p)$ for every slope $p$ is
exactly as complete a description of the curve as knowing $f(v)$ for every
point $v$ — you've just re-encoded "a bowl-shaped curve" as "a family of
tangent lines" instead of "a family of points." Nothing is lost, because
convexity makes the map $v\leftrightarrow p$ one-to-one.

### The Legendre transform, as a recipe — one scalar example first

Mechanically, computing $g(p)$ is three steps: (1) solve $f'(v)=p$ for $v$ in
terms of $p$; (2) form $pv - f(v)$; (3) substitute the result of step 1 to
eliminate $v$, leaving a function of $p$ alone. Do this once, completely, on
kinetic energy itself, before touching any Lagrangian:

$$f(v) = \tfrac12 m v^2.$$

**Step 1.** $f'(v) = mv = p \implies v = p/m$.
**Step 2.** $g = pv - f(v) = pv - \tfrac12 mv^2$.
**Step 3.** Substitute $v=p/m$:
$$g(p) = p\cdot\frac{p}{m} - \frac12 m\left(\frac{p}{m}\right)^2
= \frac{p^2}{m} - \frac{p^2}{2m} = \frac{p^2}{2m}.$$

So the Legendre transform of $\tfrac12mv^2$ (a function of velocity) is
$p^2/2m$ (a function of momentum) — the same functional shape, re-expressed
in the conjugate variable. This is not a coincidence you need to memorize;
it's the direct algebraic content of $p=mv \iff v=p/m$ substituted into a
quadratic. Every Legendre transform below is this exact three-step recipe,
just with a fuller function than plain $\tfrac12mv^2$.

### Building $H(q,p)$ from $L(q,\dot q)$

Apply the identical recipe to the Lagrangian, treating $q$ as a fixed label
and $\dot q$ as the variable being transformed (exactly as $v$ was above).
Define
$$H(q,p) \;\equiv\; p\,\dot q - L(q,\dot q), \qquad p \equiv \frac{\partial L}{\partial\dot q},$$
where the defining relation $p=\partial L/\partial\dot q$ — already familiar
from Day 9 as the conjugate momentum — plays the role of "$f'(v)=p$" above:
solve it for $\dot q$ in terms of $(q,p)$, then substitute that into
$p\dot q - L$ to eliminate every remaining $\dot q$. The result, $H(q,p)$, is
the **Hamiltonian**: a function of position and momentum only, with no
velocity left in it anywhere. (The invertibility this requires — one $\dot q$
per $p$ — holds for exactly the reason convexity guaranteed it above: kinetic
energy is generically a positive quadratic in $\dot q$, so $\partial
L/\partial\dot q$ is strictly increasing in $\dot q$ and hence invertible.)

**Worked immediately, on the oscillator, to see the machine run once in
full:** $L = \tfrac12 m\dot q^2 - \tfrac12 k_s q^2$ (kinetic minus the spring
potential from Day 2). Then $p=\partial L/\partial\dot q = m\dot q\implies
\dot q = p/m$, and
$$H = p\dot q - L = p\cdot\frac{p}{m} - \left(\frac12 m\left(\frac{p}{m}\right)^2 - \frac12 k_sq^2\right)
= \frac{p^2}{m}-\frac{p^2}{2m}+\frac12k_sq^2 = \frac{p^2}{2m}+\frac12k_sq^2.$$
Worked Example 1 below re-derives this from a completely blank page and then
solves the resulting equations of motion; keep reading for where those
equations come from.

### Hamilton's equations, derived from $dH$

$H(q,p)$ is, by construction, a function of the two *independent* variables
$q$ and $p$ — so its total differential is simply
$$dH = \frac{\partial H}{\partial q}\,dq + \frac{\partial H}{\partial p}\,dp. \tag{i}$$
But we can also differentiate the defining formula $H=p\dot q(q,p)-L(q,\dot
q(q,p))$ directly:
$$dH = \dot q\,dp + p\,d\dot q - \frac{\partial L}{\partial q}\,dq - \frac{\partial L}{\partial\dot q}\,d\dot q
= \dot q\,dp - \frac{\partial L}{\partial q}\,dq,$$
where the two $d\dot q$ terms cancelled exactly because
$\partial L/\partial\dot q \equiv p$ by definition of the conjugate momentum
— the entire point of using that particular combination. Comparing this to
(i) term by term (both are valid expressions for the same $dH$ in terms of
the same independent $dq,dp$):
$$\frac{\partial H}{\partial p} = \dot q, \qquad \frac{\partial H}{\partial q} = -\frac{\partial L}{\partial q}.$$
The first is already Hamilton's first equation. For the second, invoke Day
9's Euler–Lagrange equation, $\frac{d}{dt}\frac{\partial L}{\partial\dot
q}=\frac{\partial L}{\partial q}$, i.e. (since $p\equiv\partial
L/\partial\dot q$) $\dot p = \partial L/\partial q$. Substituting:
$$\boxed{\dot q = \frac{\partial H}{\partial p}, \qquad \dot p = -\frac{\partial H}{\partial q}.}$$
These are **Hamilton's equations**: two first-order equations, exactly as
promised in the opening section, derived from nothing but the definition of
$H$ and Day 9's Euler–Lagrange equation — no new physical postulate entered
anywhere. Notice the near-symmetry of the pair: swapping $q\leftrightarrow
p$ and flipping one sign takes one equation to the other. That asymmetric
symmetry — a single minus sign separating an otherwise identical pair — is
the seed of the **Poisson bracket** structure Day 11 builds on top of this.

**Check: the oscillator recovers SHM.** With $H=p^2/2m+\tfrac12k_sq^2$
derived above, Hamilton's equations give
$$\dot q = \frac{\partial H}{\partial p} = \frac{p}{m}, \qquad
\dot p = -\frac{\partial H}{\partial q} = -k_sq.$$
Differentiate the first and substitute the second: $\ddot q = \dot p/m =
-(k_s/m)q \equiv -\omega_0^2q$, exactly Day 3's simple-harmonic-oscillator
equation, with $\omega_0=\sqrt{k_s/m}$. Two first-order equations recombined
into the one second-order equation you already know how to solve — a
consistency check, not new content. Worked Example 1 carries this all the
way to an explicit $q(t)$.

### When does $H=T+V$?

In every example above, $H$ came out equal to $T+V$ — but that's a
*consequence* of the examples chosen, not the definition of $H$. $H$ is
*defined* by the Legendre transform, $H\equiv p\dot q-L$; whether it happens
to equal $T+V$ is a separate question with a precise answer.

For a **natural system** — kinetic energy quadratic in the velocities with
no explicit time dependence in the constraints (e.g. no track that itself
moves or rotates under you) — $T$ is a homogeneous degree-2 function of
$\dot q$, meaning $T(q,\lambda\dot q)=\lambda^2T(q,\dot q)$ for any $\lambda$
(true whenever $T=\tfrac12m(q)\dot q^2$ for some position-dependent
effective mass, as in this day's bead-on-a-wire example below). Euler's
theorem for homogeneous functions gives $\dot q\,\partial T/\partial\dot q =
2T$ for any such $T$; and since $V$ carries no $\dot q$-dependence at all,
$p=\partial L/\partial\dot q=\partial T/\partial\dot q$, so
$$H = p\dot q - L = \left(\dot q\frac{\partial T}{\partial\dot q}\right) - (T-V) = 2T - T + V = T+V.$$
So $H=T+V$ is *guaranteed* whenever the system is natural in this sense —
which is why every example in today's file (oscillator, pendulum, bead on a
wire, particle in gravity) shows it. The one-sentence caution: in a
**rotating frame**, the kinetic energy picks up terms linear in $\dot q$
(Coriolis-type cross terms) that break the homogeneous-degree-2 property,
and $H\ne T+V$ in general there — a full treatment is outside today's scope,
but the failure mode is worth knowing exists.

> **Misconception:** "$H$ is always the energy." Usually true for the
> systems this course builds — but only because those systems satisfy the
> natural-system condition just derived, not because $H$ and $T+V$ mean the
> same thing by definition. $H$ is *defined* by the Legendre transform of
> $L$; $T+V$ is a separate quantity you could compute directly from the
> physics. That $H=T+V$ follows from a proof, not a definition, is exactly
> why the proof has hypotheses (time-independent constraints) — and exactly
> why there exist systems (rotating frames, among others) where it fails.

### Phase space: trajectories as flow

A **phase-space point** is the pair $(q,p)$ — a full snapshot of a system's
state, both "where" and "how fast/which direction of momentum," at one
instant. Hamilton's equations say precisely how that point moves: $(\dot
q,\dot p) = (\partial H/\partial p,\,-\partial H/\partial q)$ is a **velocity
field** on the $(q,p)$-plane, exactly the kind of arrow-at-every-point
picture a weather map uses for wind. A system's entire time evolution, for
any initial condition, is a single curve through this field — a
**trajectory** — traced by following the arrows.

Because Hamilton's equations are first-order in time, an initial condition
$(q_0,p_0)$ determines the entire future *and* entire past trajectory
uniquely (the standard existence-and-uniqueness guarantee for first-order
ODEs with smooth right-hand sides, exactly as in Day 1). This has an
immediate geometric consequence:

> **Misconception:** "phase-space trajectories can cross." They cannot — not
> even at a single point (other than the trivial case of literally the same
> trajectory revisiting itself, e.g. a closed orbit). If two distinct
> trajectories crossed at some point $(q^*,p^*)$, that single state would
> have two different futures leaving it under identical dynamics —
> contradicting the determinism just stated. What phase portraits often
> show instead, and what genuinely can happen, is trajectories that get
> arbitrarily *close* to each other, or that both pass near — but never
> exactly through — a **fixed point** (a $(q,p)$ where both $\dot q=0$ and
> $\dot p=0$, so a trajectory starting exactly there never moves at all).

### Phase portraits: oscillator ellipses and the pendulum's global structure

**The oscillator.** Since $H=p^2/2m+\tfrac12k_sq^2$ is conserved along any
trajectory (Hamilton's equations make $dH/dt=\dot q\,\partial H/\partial
q+\dot p\,\partial H/\partial p = \dot q(-\dot p)+\dot p(\dot q)=0$
automatically, for *any* Hamiltonian, not just this one — energy
conservation is built into the structure, not assumed separately), every
trajectory lies entirely on one curve of constant $H$. For this $H$, that
curve is the ellipse $p^2/2m+\tfrac12k_sq^2=E$, with semi-axes
$\sqrt{2E/k_s}$ (along $q$) and $\sqrt{2mE}$ (along $p$). Different starting
energies trace out different, non-crossing, **nested ellipses** — larger $E$
gives a larger ellipse, all sharing the single fixed point $(q,p)=(0,0)$ at
their common center. The area enclosed by one ellipse is $\pi\sqrt{2E/k_s}\cdot\sqrt{2mE}=2\pi E\sqrt{m/k_s}=2\pi E/\omega_0$
— proportional to energy, a fact reused below.

**The pendulum, in full.** With $H(\theta,p_\theta)=p_\theta^2/2m\ell^2 +
mg\ell(1-\cos\theta)$ (derived in Worked Example 2; $\ell$ for pendulum
length here, kept distinct from the Lagrangian $L$), the portrait has three
qualitatively different regions, all visible on today's simulation:

- **Fixed points.** $\dot\theta=0,\dot p_\theta=0$ at $\theta=0$ (bottom,
  stable — small oscillations around it are exactly the ellipses above, in
  the small-angle limit) and at $\theta=\pm\pi$ (top, unstable).
- **Libration** (closed ovals around $\theta=0$, at energies $E<E_{\text
  {sep}}$): the pendulum swings back and forth between two turning points
  without ever reaching the top, exactly Day 2's bound-motion picture
  applied to $\theta$ instead of $x$.
- **Rotation** (open, wavy horizontal bands, at $E>E_{\text{sep}}$): the
  pendulum has enough energy to swing all the way over the top and keeps
  going around and around in one direction — $\theta$ increases (or
  decreases) without bound rather than turning back.
- **The separatrix**, the curve at exactly $E=E_{\text{sep}}$ passing
  through the unstable fixed points $\theta=\pm\pi$, is the boundary between
  the two regimes. It means something physically precise: a pendulum
  released with exactly this energy takes an *infinite* time to reach the
  top — it approaches $\theta=\pi$ ever more slowly and never quite arrives
  (worked out quantitatively in Worked Example 2) — so the ordinary
  oscillation period, finite for every libration orbit, **diverges** as $E$
  approaches $E_{\text{sep}}$ from below, and the "time to complete one
  rotation" similarly diverges as $E\to E_{\text{sep}}$ from above. The
  separatrix is a boundary no actual finite-time trajectory ever crosses.

### Liouville's theorem, in one paragraph

One more structural fact about Hamiltonian flow, worth having before Day 12:
the velocity field $(\dot q,\dot p)=(\partial H/\partial p,\,-\partial
H/\partial q)$ has zero divergence, computed directly —
$\partial\dot q/\partial q + \partial\dot p/\partial p =
\partial^2H/\partial q\,\partial p - \partial^2H/\partial p\,\partial q = 0$,
the two mixed partials cancelling exactly because they're equal for any
smooth $H$. A divergence-free flow is the phase-space analogue of an
incompressible fluid: it can stretch and shear a region of phase space into
wild shapes, but it can never change that region's *area* (or, in more
coordinates, volume). This is **Liouville's theorem**, and it is the reason
phase space is the natural home of statistical mechanics (Day 12): a
probability density spread over phase space gets carried along by the flow
without ever being artificially concentrated or diluted by the dynamics
itself, so "area/volume in phase space" can serve as an honest,
flow-invariant measure of how many microscopic states are consistent with a
given macroscopic description.

## Worked examples

**1. The oscillator: full Legendre construction, then Hamilton's equations
solved.** Start from $L=\tfrac12m\dot q^2-\tfrac12k_sq^2$ (Day 3's oscillator
Lagrangian, from Day 9). Conjugate momentum: $p=\partial L/\partial\dot
q=m\dot q$, so $\dot q=p/m$. Legendre transform:
$$H = p\dot q - L = p\cdot\frac{p}{m} - \left(\frac12m\left(\frac pm\right)^2-\frac12k_sq^2\right)
= \frac{p^2}{2m}+\frac12k_sq^2.$$
Hamilton's equations: $\dot q=\partial H/\partial p=p/m$ and
$\dot p=-\partial H/\partial q=-k_sq$. Differentiate the first and
substitute the second: $\ddot q = \dot p/m = -(k_s/m)q=-\omega_0^2q$ with
$\omega_0=\sqrt{k_s/m}$, whose general solution (Day 3) is
$q(t)=A\cos(\omega_0t+\varphi)$, giving
$p(t)=m\dot q(t)=-mA\omega_0\sin(\omega_0t+\varphi)$. Direct substitution
confirms $H=\tfrac12k_sA^2$ (constant, as it must be): $\tfrac{p^2}{2m}=
\tfrac12mA^2\omega_0^2\sin^2(\cdot)=\tfrac12k_sA^2\sin^2(\cdot)$ (using
$m\omega_0^2=k_s$) and $\tfrac12k_sq^2=\tfrac12k_sA^2\cos^2(\cdot)$; adding
gives $\tfrac12k_sA^2\left(\sin^2+\cos^2\right)=\tfrac12k_sA^2$, independent
of $t$.

**2. The pendulum: separatrix energy, and classifying motion above/below
it.** A pendulum of length $\ell$ and bob mass $m$, angle $\theta$ from the
downward vertical, with $V(\theta)=mg\ell(1-\cos\theta)$ (Day 2, Worked
Example 2's height formula times $mg$; $V(0)=0$ at the bottom, the stable
equilibrium). Kinetic energy in terms of $\dot\theta$: $T=\tfrac12m\ell^2\dot\theta^2$
(speed $=\ell\dot\theta$ for a bob on a rigid rod/string of length $\ell$).
So $L=\tfrac12m\ell^2\dot\theta^2 - mg\ell(1-\cos\theta)$. Conjugate momentum:
$p_\theta=\partial L/\partial\dot\theta=m\ell^2\dot\theta\implies
\dot\theta=p_\theta/(m\ell^2)$. Legendre transform:
$$H = p_\theta\dot\theta - L = \frac{p_\theta^2}{m\ell^2} - \left(\frac12m\ell^2\left(\frac{p_\theta}{m\ell^2}\right)^2 - mg\ell(1-\cos\theta)\right)
= \frac{p_\theta^2}{2m\ell^2} + mg\ell(1-\cos\theta),$$
matching $T+V$ exactly, as guaranteed by the natural-system argument above
(the constraint — bob on a rod of fixed length $\ell$ — doesn't depend on
time). The unstable equilibrium is at $\theta=\pi$ (top), where
$p_\theta=0$; evaluating $H$ there,
$$E_{\text{sep}} = H(\pi,0) = mg\ell(1-\cos\pi) = mg\ell(1-(-1)) = 2mg\ell.$$
**Why it takes infinite time to arrive.** The pendulum equation of motion
(from Hamilton's equations, or equivalently $mL\ddot\theta=-mg\sin\theta$)
is $\ddot\theta=-(g/\ell)\sin\theta$. Near the top, write
$\varphi\equiv\pi-\theta$ (small): $\sin\theta=\sin(\pi-\varphi)=\sin\varphi
\approx\varphi$, and $\ddot\theta=-\ddot\varphi$, so the linearized equation
is $\ddot\varphi=(g/\ell)\varphi$ — a *positive* coefficient (unlike the
stable case at the bottom), whose decaying solution is
$\varphi(t)=\varphi_0e^{-\sqrt{g/\ell}\,t}$. This reaches $\varphi=0$ (i.e.
$\theta=\pi$, the top) only in the limit $t\to\infty$ — an exponential
never crosses its own asymptote at any finite time — confirming the
infinite-time approach claimed above from a genuine equation of motion, not
just from the shape of the energy curve.

**Classification.** At $E<2mg\ell$: solving $H=E$ for the turning angle
$\theta_{\max}$ where $p_\theta=0$ gives $mg\ell(1-\cos\theta_{\max})=E
\implies \cos\theta_{\max}=1-E/(mg\ell) $, a solvable value strictly between
$-1$ and $1$ — a genuine turning point exists on each side of $\theta=0$,
so the motion is **libration**, oscillating between $\pm\theta_{\max}$. At
$E>2mg\ell$: the equation $\cos\theta_{\max}=1-E/(mg\ell)$ would require
$\cos\theta_{\max}<-1$, impossible — there is *no* turning point at any
$\theta$, so $\dot\theta=p_\theta/(m\ell^2)$ never reaches zero and never
changes sign: the pendulum sails over the top continuously, **rotation**.
At exactly $E=2mg\ell$, the would-be turning point sits exactly at
$\theta=\pi$, coincident with the unstable equilibrium itself — the
separatrix, approached but (in finite time, frictionless) never reached, in
exact parallel with Day 2's Worked Example 1's $E=0$ edge case for the
double well.

**3. Particle in uniform gravity: $H$, equations, and the parabolic phase
flow.** $L=\tfrac12m\dot x^2 - mgx$ ($x$ measured upward, Day 2's uniform-gravity
potential $V=mgx$). Conjugate momentum: $p=m\dot x\implies\dot x=p/m$.
Legendre transform:
$$H = p\dot x - L = \frac{p^2}{m} - \left(\frac12m\left(\frac pm\right)^2 - mgx\right) = \frac{p^2}{2m}+mgx.$$
Hamilton's equations: $\dot x=\partial H/\partial p=p/m$ and
$\dot p=-\partial H/\partial x=-mg$ — a constant force, exactly Day 1's
free-fall. Eliminating time between the two equations (divide one by the
other): $dp/dx=\dot p/\dot x=-mg/(p/m)=-m^2g/p\implies p\,dp=-m^2g\,dx$,
which integrates to $\tfrac12p^2 = -m^2gx + \text{const}$, i.e.
$$x(p) = \frac{\text{const}-\tfrac12p^2}{m^2g},$$
a **parabola opening toward $-x$** in the $(x,p)$ phase plane, traced once
per trajectory (not repeatedly, since this system is unbound — a thrown
object doesn't return to the same $(x,p)$). Every trajectory is one such
parabola, shifted along $x$ — horizontally in this $(x,p)$ plane, since $p$
is the vertical axis and $x$ the horizontal one — by its own conserved
$H$-value (a family of parallel, non-crossing parabolas, consistent with
the no-crossing rule above).

## Simulation

Run:
```
python3 code/day10_phase_space.py
```
Panel (a) shows the oscillator's flow field (arrows/streamlines of
$(\dot q,\dot p)$) with four nested, analytically-drawn constant-energy
ellipses overlaid — check that the streamlines run exactly along the
ellipses, since the flow *is* the family of constant-$H$ curves for a
system with no other conserved quantity in play. Panel (b) shows the
pendulum's $H(\theta,p_\theta)$ as a contour plot: green closed ovals
(libration), the thick red separatrix through $\theta=\pm\pi$, and orange
open bands (rotation). The red curve appears to cross itself in an "X" at
each $\theta=\pm\pi$ — that crossing is only apparent: those are two
branches asymptotically approaching the unstable equilibrium from opposite
sides, never actually reaching it (exactly the infinite-time argument
above), which is consistent with the no-crossing misconception callout,
not an exception to it.

Before running, predict for yourself:
- Pick an energy just above $E_{\text{sep}}$ in panel (b) — before running,
  describe in words what that trajectory's contour should look like (open
  or closed? does $\theta$ turn around?).
- If you doubled the pendulum length $\ell$ in the script, which features of
  panel (b) would move, and which would stay exactly where they are?
- Why can no two streamlines (or contour curves at different energies) in
  either panel ever cross?

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. Starting only from $H(q,p)\equiv p\dot q-L(q,\dot q)$ with $p=\partial
   L/\partial\dot q$, derive Hamilton's equations
   $\dot q=\partial H/\partial p$, $\dot p=-\partial H/\partial q$.
2. Construct $H$ for $L=\tfrac12m\dot x^2-\tfrac12k_sx^2$ from scratch, then
   verify that Hamilton's equations for that $H$ reproduce the simple
   harmonic oscillator equation $\ddot x=-\omega_0^2x$.

**Standard**

3. A bead of mass $m$ is constrained to a parabolic wire $y=ax^2$ in a
   vertical plane ($x$ horizontal, $y$ vertical, $a>0$, gravity $g$ pulling
   in $-y$). Using $x$ as the generalized coordinate, construct $L(x,\dot
   x)$, find $p$, and construct $H(x,p)$.
4. Describe, in words and with labeled coordinates (no computer needed), the
   phase portrait of $V(x)=x^4-2x^2$ from Day 2, using $T=p^2/2m$ so
   $H=p^2/2m+x^4-2x^2$. Identify the fixed points, the shape of the
   trajectories at $E$ slightly below $0$, at $E=0$ exactly (name the shape
   this traces), and at $E$ slightly above $0$.

**Stretch**

5. A relativistic free particle has Lagrangian
   $L=-mc^2\sqrt{1-\dot x^2/c^2}$. Compute $p=\partial L/\partial\dot x$,
   invert it for $\dot x$ in terms of $p$, then construct $H=p\dot x-L$ and
   show it simplifies to $H=\sqrt{p^2c^2+m^2c^4}$.

## Hints

1. Write $dH$ two ways and compare coefficients of $dq$ and $dp$.
2. Follow the three-step recipe (solve $p=\partial L/\partial\dot x$ for
   $\dot x$; form $p\dot x-L$; substitute to eliminate $\dot x$) exactly as
   done for the oscillator in the Theory section, then apply Hamilton's
   equations and combine them into one second-order equation.
3. Compute $\dot y$ via the chain rule ($y=ax^2\implies\dot y=2ax\dot x$),
   write $T=\tfrac12m(\dot x^2+\dot y^2)$ in terms of $\dot x$ alone, and
   $V=mgy=mgax^2$; then apply the same three-step Legendre recipe.
4. Find where $V'(x)=0$ (same equilibria as Day 2's Worked Example 1) and
   use the sign of $V''$ to classify them; then think about which energy
   value makes the "turning point" coincide with the unstable equilibrium at
   $x=0$, exactly as in that same Day 2 example.
5. $\sqrt{1-\dot x^2/c^2}$ differentiates via the chain rule; after finding
   $p$, square both sides of the relation between $p$ and $\dot x$ to solve
   for $\dot x^2$ algebraically rather than trying to isolate $\dot x$
   directly. Keep every intermediate expression exact (no approximations) —
   the algebra is supposed to close perfectly.

## Solutions

**1.** Since $H$ is a function of the independent variables $(q,p)$,
$dH=\frac{\partial H}{\partial q}dq+\frac{\partial H}{\partial p}dp$.
Differentiating the definition directly: $dH = \dot q\,dp+p\,d\dot q -
\frac{\partial L}{\partial q}dq-\frac{\partial L}{\partial\dot q}d\dot q$;
the last term is $p\,d\dot q$ (since $\partial L/\partial\dot q\equiv p$),
which cancels the $p\,d\dot q$ term already present, leaving
$dH=\dot q\,dp-\frac{\partial L}{\partial q}dq$. Matching coefficients of
$dp$: $\partial H/\partial p=\dot q$. Matching coefficients of $dq$:
$\partial H/\partial q=-\partial L/\partial q$. Day 9's Euler–Lagrange
equation says $\frac{d}{dt}\frac{\partial L}{\partial\dot q}=\frac{\partial
L}{\partial q}$, i.e. (since $p=\partial L/\partial\dot q$) $\dot
p=\partial L/\partial q$, so $\partial H/\partial q=-\dot p$, i.e.
$\dot p=-\partial H/\partial q$. Both of Hamilton's equations obtained.

**2.** $p=\partial L/\partial\dot x=m\dot x\implies\dot x=p/m$.
$$H=p\dot x-L=p\cdot\frac pm-\left(\frac12m\left(\frac pm\right)^2-\frac12k_sx^2\right)=\frac{p^2}{2m}+\frac12k_sx^2.$$
Hamilton: $\dot x=\partial H/\partial p=p/m$, $\dot p=-\partial H/\partial
x=-k_sx$. Differentiate the first in time and substitute the second:
$\ddot x=\dot p/m=-(k_s/m)x=-\omega_0^2x$ with $\omega_0=\sqrt{k_s/m}$ —
exactly the SHM equation.

**3.** $y=ax^2\implies\dot y=2ax\dot x$, so
$T=\tfrac12m(\dot x^2+\dot y^2)=\tfrac12m\dot x^2(1+4a^2x^2)$, and
$V=mgy=mgax^2$, giving
$$L=\tfrac12m\dot x^2(1+4a^2x^2)-mgax^2.$$
$$p=\frac{\partial L}{\partial\dot x}=m\dot x(1+4a^2x^2)\implies
\dot x=\frac{p}{m(1+4a^2x^2)}.$$
$$H=p\dot x-L=\frac{p^2}{m(1+4a^2x^2)}-\left(\frac12m\left(\frac{p}{m(1+4a^2x^2)}\right)^2(1+4a^2x^2)-mgax^2\right)$$
$$=\frac{p^2}{m(1+4a^2x^2)}-\frac{p^2}{2m(1+4a^2x^2)}+mgax^2
=\boxed{\frac{p^2}{2m(1+4a^2x^2)}+mgax^2}.$$
The result is $T+V$ with a **position-dependent effective mass**
$m_{\text{eff}}(x)=m(1+4a^2x^2)$ — consistent with the natural-system
argument (the wire is a time-independent constraint), and a direct
illustration of how curvature of the constraint feeds into $H$ through the
momentum term rather than the potential term.

**4.** Equilibria (Day 2, Worked Example 1): $V'(x)=4x^3-4x=0$ at
$x=-1,0,1$; $V''(0)=-4<0$ (unstable maximum, $V=0$), $V''(\pm1)=8>0$ (stable
minima, $V=-1$). Fixed points of the flow: $(x,p)=(\pm1,0)$ are centers
(surrounded by closed orbits), $(x,p)=(0,0)$ is a saddle. At $E$ slightly
below $0$: two separate closed loops, one encircling each stable minimum,
since the barrier at $x=0$ (height $0$) is inaccessible — the particle
oscillates within a single well, matching Day 2's classification at
$E=-0.5$. At exactly $E=0$: the curve $p^2/2m+x^4-2x^2=0$ passes through the
saddle $(0,0)$ itself — since this point is simultaneously on both would-be
loops, the two loops merge into a single self-crossing curve through the
origin, the classic **figure-eight separatrix** (two lobes, one around each
well, touching at the saddle). At $E$ slightly above $0$: a single closed
loop encircling *both* minima, since the particle now has enough energy to
cross the former barrier and range over both wells as one connected orbit —
matching Day 2's $E=1$ classification, now seen as one curve in phase space
rather than a pair of turning points on the $x$-axis.

**5.** $\frac{d}{d\dot x}\sqrt{1-\dot x^2/c^2} =
\frac{-\dot x/c^2}{\sqrt{1-\dot x^2/c^2}}$, so
$$p=\frac{\partial L}{\partial\dot x} = -mc^2\cdot\frac{-\dot x/c^2}{\sqrt{1-\dot x^2/c^2}}
= \frac{m\dot x}{\sqrt{1-\dot x^2/c^2}} = m\gamma\dot x,
\qquad \gamma \equiv \frac{1}{\sqrt{1-\dot x^2/c^2}}.$$
Squaring: $p^2(1-\dot x^2/c^2)=m^2\dot x^2 \implies p^2 = \dot
x^2(m^2+p^2/c^2) \implies \dot x^2 = \dfrac{p^2c^2}{m^2c^2+p^2}$, so
$\dot x = pc/\sqrt{m^2c^2+p^2}$ (taking the positive root; $p$ carries the
sign of the velocity). Also, $1-\dot x^2/c^2 = 1-\dfrac{p^2}{m^2c^2+p^2}
=\dfrac{m^2c^2}{m^2c^2+p^2}$, so $\sqrt{1-\dot x^2/c^2} =
\dfrac{mc}{\sqrt{m^2c^2+p^2}}$. Now assemble $H=p\dot x-L$:
$$H = p\cdot\frac{pc}{\sqrt{m^2c^2+p^2}} + mc^2\cdot\frac{mc}{\sqrt{m^2c^2+p^2}}
= \frac{p^2c+m^2c^3}{\sqrt{m^2c^2+p^2}}
= \frac{c(p^2+m^2c^2)}{\sqrt{p^2+m^2c^2}} = c\sqrt{p^2+m^2c^2},$$
i.e.
$$\boxed{H = \sqrt{p^2c^2+m^2c^4}},$$
the relativistic energy–momentum relation. (Flag: this exact expression
returns in Day 14's discussion of Compton scattering.)

## Connection to QM

Today's construction is, quite literally, one differentiation step away
from the equation the entire QM course is built around: the time-dependent
Schrödinger equation, $i\hbar\,\partial_t|\psi\rangle = \hat H|\psi\rangle$,
where $\hat H$ is today's $H$ with hats on its $q$'s and $p$'s. Day 16
builds it by taking exactly the oscillator- and free-particle-style
Hamiltonians constructed today, $H=p^2/2m+V(x)$, and promoting
$p\to-i\hbar\,\partial_x$ — the same $H=T+V$ expression this file derived
from a Legendre transform becomes, symbol for symbol, the operator that
generates quantum time evolution.

Everything phase space taught you today about $H$ has a direct quantum
image. A closed classical orbit at fixed energy $E$ becomes, in the quantum
problem, an **energy eigenstate**: the oscillator's nested ellipses (area
$2\pi E/\omega_0$, derived above) are the classical shadow of the quantum
harmonic oscillator's evenly spaced energy levels, $E_n=\hbar\omega_0(n+\tfrac12)$
— evenly spaced in energy because the classical ellipse area is exactly
linear in $E$. And the "$H$ is defined by a transform, not merely by being
$T+V$" lesson from today's first misconception matters again immediately:
$\hat H$ in QM is *always* defined as the operator generating time
evolution (via $i\hbar\partial_t|\psi\rangle=\hat H|\psi\rangle$), and only
*sometimes* takes the familiar $p^2/2m+V$ form — precisely the natural-system
condition derived today, now carried over unchanged into the quantum
setting.
