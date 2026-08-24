# Day 2 — Energy and Potential Wells

## Learning objectives

By the end of today you should be able to:
- Derive the work–energy theorem $\int F\,dx = \Delta K$ from Newton's second
  law, using the chain-rule trick $\ddot x = v\,dv/dx$.
- Define a conservative force, construct its potential energy
  $V(x) = -\int F\,dx$, and recover the force from the potential via
  $F = -dV/dx$.
- Derive energy conservation $E = K + V = \text{const}$ directly from
  Newton's second law for a conservative force.
- Read an arbitrary $V(x)$ diagram fluently: locate turning points, classify
  equilibria as stable or unstable from the curvature of $V$, and decide
  whether the resulting motion is bound or free at a given energy.
- Use energy conservation as a solving tool — get a speed or a turning
  point algebraically, without ever writing down or integrating the
  equation of motion.
- Derive the escape-velocity condition as a pure energy argument and
  compute it numerically for Earth.

Time budget: ~3 hours.

## Reference material

- Morin, *Introduction to Classical Mechanics*, ch. 5 (conservation of
  energy and momentum), or Halliday/Resnick, the chapters on "Kinetic
  Energy and Work" and "Potential Energy and Conservation of Energy" —
  either covers today's material in the same order used below.
- This file is self-contained: everything is derived from scratch, so the
  reference chapters are useful for a second explanation in different words,
  not required to do today's work.
- Builds on Day 1's result that classical mechanics is the statement
  $m\ddot x = F$ together with initial conditions; today builds a tool
  (energy) that often lets you skip solving that differential equation
  entirely.

## Theory

### From $m\ddot x = F$ to the work–energy theorem

Day 1 fixed the object of study: given a force $F$, motion is the solution
of $m\ddot x = F$. Today's first move is an algebraic trick that turns this
statement about acceleration into a statement about *speed*, without
solving any differential equation.

Write $F(x) = m\ddot x$, for a force that depends only on position (we'll
restrict to this case — it is exactly the case that has a potential energy,
as the next section shows). The acceleration $\ddot x = dv/dt$ can be
rewritten using the chain rule:
$$\ddot x = \frac{dv}{dt} = \frac{dv}{dx}\frac{dx}{dt} = v\,\frac{dv}{dx}.$$
This is the single trick that makes today's whole toolkit work: whenever a
force depends only on $x$, trade $d/dt$ for $d/dx$ by multiplying and
dividing by $v$. Substituting into Newton's second law,
$$F(x) = mv\,\frac{dv}{dx} \quad\Longrightarrow\quad F(x)\,dx = mv\,dv.$$
Integrate both sides from position $x_1$ (speed $v_1$) to position $x_2$
(speed $v_2$):
$$\int_{x_1}^{x_2} F(x)\,dx = \int_{v_1}^{v_2} mv\,dv =
\left[\tfrac12 mv^2\right]_{v_1}^{v_2} = \tfrac12 mv_2^2 - \tfrac12 mv_1^2.$$
Defining the **kinetic energy** $K \equiv \tfrac12 mv^2$ and the **work**
done by the force as $W \equiv \int_{x_1}^{x_2} F\,dx$, this reads
$$\boxed{W = \Delta K}$$
the **work–energy theorem**: the work done by the net force on an object
equals the change in its kinetic energy. Nothing beyond Newton's second law
and one chain-rule substitution went into this — it is not a new physical
law, it is $m\ddot x = F$ rewritten in a more useful variable.

### Conservative forces and the potential $V(x)$

The integral $W=\int_{x_1}^{x_2}F\,dx$ above depended only on the two
endpoints $x_1, x_2$, not on any details of the trip between them — even
though the particle is free to double back, overshoot, and retrace ground
along the way. This holds because $F$ depends on $x$ alone: $\int F(x)\,dx$
is an ordinary single-variable definite integral, and the fundamental
theorem of calculus makes any such integral a function of its two
endpoints only, however winding the trajectory that connects them. (In more
than one dimension this endpoint-only property is a real restriction,
called path-independence, that not every force satisfies; here it follows
automatically from $F$ being a function of $x$ alone.) A force that depends
only on position,
$F=F(x)$, is called **conservative**, and for such a force we define the
**potential energy**
$$V(x) \;\equiv\; -\int_{x_0}^{x} F(x')\,dx',$$
for some arbitrarily chosen reference point $x_0$ where $V(x_0)=0$ (only
*differences* in $V$ are ever physical, so the reference point is a free
choice of bookkeeping, not a physical fact). By the fundamental theorem of
calculus, differentiating this definition immediately gives back the force:
$$\frac{dV}{dx} = -F(x) \quad\Longrightarrow\quad \boxed{F = -\frac{dV}{dx}}.$$
Read this both ways: $V$ is built by integrating $-F$, and $F$ is recovered
by differentiating $-V$. Two forces you already know, rebuilt as
potentials:

**Uniform gravity near a surface.** Take $x$ as height above the ground,
positive upward. Near a planet's surface the gravitational force on a mass
$m$ is the constant $F = -mg$ (pointing down, i.e. in the $-x$ direction).
Then
$$V(x) = -\int_0^x(-mg)\,dx' = mg\int_0^x dx' = mgx,$$
choosing $V(0)=0$ at ground level. This is the familiar $V=mgh$ formula,
now derived rather than quoted.

**The spring, $F=-k_sx$.** Hooke's law says the restoring force of an ideal
spring is proportional to displacement from equilibrium and opposite in
sign: $F(x) = -k_sx$, with spring constant $k_s>0$. Then
$$V(x) = -\int_0^x(-k_sx')\,dx' = k_s\int_0^x x'\,dx' = \tfrac12 k_sx^2,$$
choosing $V(0)=0$ at the equilibrium position. This parabola is the
potential every simple-harmonic-oscillator problem from here on is built
on top of (Day 3 does the resulting motion in full).

### Energy conservation, derived (not assumed)

Define the total mechanical energy $E \equiv K + V$, with $K=\tfrac12mv^2$
and $V=V(x)$. Claim: for a conservative force, $E$ is constant along any
trajectory satisfying $m\ddot x = F$. Proof — differentiate $E$ with
respect to time and show the result is zero:
$$\frac{dE}{dt} = \frac{dK}{dt} + \frac{dV}{dt}.$$
For the kinetic term, using $K=\tfrac12mv^2$ and the chain rule,
$$\frac{dK}{dt} = mv\,\frac{dv}{dt} = v\,(m\dot v) = vF,$$
where the last step used Newton's second law, $m\dot v = F$. For the
potential term, using the chain rule the other way ($V$ depends on $t$ only
through $x(t)$),
$$\frac{dV}{dt} = \frac{dV}{dx}\frac{dx}{dt} = (-F)\,v = -Fv,$$
using $F=-dV/dx$ from the previous section. Adding the two:
$$\frac{dE}{dt} = vF + (-Fv) = 0.$$
So $E=K+V$ is constant in time — **energy conservation** — and note exactly
what was used to prove it: only Newton's second law and the existence of a
potential (i.e. $F$ depending on $x$ alone). Energy conservation is not an
independent postulate on top of $m\ddot x=F$; for a conservative force, it
*is* $m\ddot x=F$, integrated once.

> **Misconception:** "Energy is a substance, stored inside an object, that
> gets used up or transferred like a fluid." It isn't a substance and there
> is nothing "inside" anything. $E=K+V$ is a single number you compute from
> a state (position and velocity); the content of the theorem above is that
> *this particular number* stays fixed as the state evolves in time under a
> conservative force. "Energy is conserved" is a bookkeeping statement about
> one number, not a claim about stuff flowing between containers.

### The core skill: reading a $V(x)$ diagram

Everything above was algebra. This section is the actual payoff: given a
graph of $V(x)$ and a value of $E$, you should be able to read off the
entire qualitative story of the motion without solving anything.

Since $E=K+V$ and $K=\tfrac12mv^2\ge0$ always, rearranging gives
$$K = E - V(x) \ge 0 \quad\Longrightarrow\quad V(x) \le E.$$
This one inequality is the entire reading technique. A region of $x$ where
$V(x) \le E$ is **classically allowed** (the particle can be there, moving
with speed $v=\sqrt{2(E-V(x))/m}$); a region where $V(x) > E$ is
**classically forbidden** (would require $K<0$, impossible for a real
particle). A **turning point** is a value of $x$ where $V(x)=E$ exactly —
there $K=0$, the particle is momentarily at rest, and it reverses direction
because it cannot press on into the forbidden region on the other side of
that point.

**Equilibria and their stability.** A point $x_e$ with $F(x_e)=0$, i.e.
$V'(x_e)=0$, is an equilibrium — a particle placed there exactly at rest
stays at rest. Its stability is read from the curvature of $V$ at that
point:
- If $V''(x_e) > 0$ ($x_e$ is a local **minimum** of $V$), nearby points have
  higher $V$ on both sides, so $F=-V'$ points back toward $x_e$ on both
  sides — this is a **stable** equilibrium. A particle nudged slightly away
  gets pushed back and oscillates around $x_e$ (small-oscillation preview
  below).
- If $V''(x_e) < 0$ ($x_e$ is a local **maximum** of $V$), the force points
  *away* from $x_e$ on both sides — an **unstable** equilibrium. A particle
  nudged slightly away accelerates further away.

> **Misconception:** "A particle sitting at a turning point has zero force
> on it, since it's momentarily at rest." Zero force and zero velocity are
> different things. At a turning point, $v=0$ by definition ($K=E-V=0$
> there), but the force is $F=-V'(x)$, which is generally *not* zero at that
> point — it's whatever the slope of $V$ happens to be there. (The only
> case where a turning point *does* have zero force is if it happens to
> coincide with an equilibrium, e.g. the particle asymptotically approaches
> an unstable maximum — an edge case revisited in the first worked example.)
> A nonzero force at a turning point is precisely *why* the particle turns
> around instead of just stopping there forever.

**Bound vs. free motion, walked through on one figure.** Picture a $V(x)$
that looks like this, described precisely: a hard wall at $x=0$ where $V$
shoots up steeply (so $x<0$ is always forbidden); descending from the wall,
$V$ dips down to a broad minimum of $V=-3$ near $x=2$ (a well); rising out
of the well, $V$ climbs to a local maximum, a barrier, of $V=+1$ at $x=6$;
beyond the barrier, $V$ descends again and flattens out, approaching the
constant value $V=0$ from above as $x\to\infty$. Sketched:

```
 V
 |\
 | \                       (barrier)
 |  \                        /\
 |   \                      /  \               V -> 0  (flat, x -> infinity)
 |    \                    /    \_____________________________
 |     \                  /
 |      \________________/
 |       (broad minimum, V=-3, near x=2)
 |__________________________________________________________ x
 0        2              6                 10   ...
(wall)                (barrier peak)
```
(The baseline drawn along the bottom is the position axis, not $V=0$;
$V=0$ is the flat segment on the right, where the curve asymptotes.)

Now read off three energies on this one figure:

- **$E=-1$** (below both the barrier top and the flat asymptote): $V(x)\le
  E$ only in a narrow band straddling the well bottom at $x=2$. Two turning
  points bracket the well, and the motion is **bound** — the particle
  oscillates back and forth between them forever, never reaching the
  barrier.
- **$E=+0.5$** (above the flat asymptote $V\to0$, but below the barrier
  peak $V=1$): the allowed region near the well grows (turning points move
  further apart), but the particle still cannot cross the barrier at $x=6$,
  since $V=1>E$ there — so this is still **bound**, just with larger
  amplitude. Notice that the flat region far to the right (where
  $V\approx0<E$) is also "allowed" by the inequality $V\le E$, but the
  particle can never actually get there — it's cut off by the forbidden
  barrier in between. Allowed is not the same as reachable; connectivity of
  the allowed region matters, not just the inequality at each point in
  isolation.
- **$E=+2$** (above the barrier peak $V=1$): now $V(x)\le E$ everywhere
  from the wall all the way out to $x\to\infty$, since even the barrier top
  is now below $E$. There is only **one** turning point left (the wall at
  $x=0$). A particle released in the well and moving rightward now sails
  over the barrier and continues to $x\to\infty$ without ever turning back
  — this is **free** (unbound, escaping) motion.

The general pattern: **bound motion** happens between two turning points
that enclose a finite allowed region on both sides; **free motion** happens
when the allowed region extends to infinity in at least one direction, so
there are either one or zero (finite) turning points on that side.

### Small-oscillation preview

Near any stable equilibrium ($V''(x_e)>0$), a Taylor expansion of $V$ gives
$V(x) \approx V(x_e) + \tfrac12 V''(x_e)(x-x_e)^2 + \cdots$ — to leading
order in the displacement, *every* potential well looks like a spring well,
$V\approx\text{const} + \tfrac12 k_{\text{eff}}(x-x_e)^2$ with effective
spring constant $k_{\text{eff}}=V''(x_e)$. This is why the spring potential
derived above is not just one example among many — it is the universal
local shape of small motion around any stable equilibrium. Day 3 works out
the resulting oscillatory motion in full; today's job is only to recognize
that it will be oscillatory, from the curvature sign.

### Escape velocity as an energy argument

Near a planet's surface the constant-force potential $V=mgx$ derived above
is only a local approximation (it assumes $g$ doesn't change with height) —
and it cannot answer an escape-velocity question at all, because a constant
force never gets weaker, so under that approximation reaching $x\to\infty$
would need infinite energy. The real gravitational force between a mass $m$
and a planet of mass $M$, at separation $r$, is the inverse-square law
$F(r) = -\dfrac{GMm}{r^2}$ (attractive, pointing toward the planet; taking
outward $r$ as positive). Its potential, by the same definition used
throughout today,
$$V(r) = -\int_{\infty}^{r} F(r')\,dr' = -\int_\infty^r\left(-\frac{GMm}{r'^2}\right)dr'
= GMm\int_\infty^r \frac{dr'}{r'^2} = GMm\left[-\frac1{r'}\right]_\infty^r
= -\frac{GMm}{r},$$
choosing the reference point at $r\to\infty$ so $V(\infty)=0$ (the standard
convention for gravity, unlike the "ground level" reference used for
uniform gravity above). Unlike the constant-force potential, $V(r)\to0$ as
$r\to\infty$ instead of diverging, which is exactly why escape to infinity
with finite energy is even possible here.

**Escape condition.** A projectile launched radially outward from the
surface $r=R$ with speed $v$ "just escapes" if it can reach $r\to\infty$
with kinetic energy asymptotically approaching zero — the marginal case
$E=0$ exactly (any $E<0$ means a turning point exists at finite $r$, i.e.
the object falls back; any $E>0$ means it escapes with leftover speed at
infinity). Energy conservation between the surface and infinity:
$$E = \tfrac12 mv_{\text{esc}}^2 - \frac{GMm}{R} = 0
\quad\Longrightarrow\quad v_{\text{esc}} = \sqrt{\frac{2GM}{R}}.$$
This is worked numerically for Earth in Worked example 3 below.

## Worked examples

**1. The double well $V(x)=x^4-2x^2$, classified at three energies.**

Equilibria: $V'(x) = 4x^3-4x = 4x(x-1)(x+1) = 0$ at $x=-1,0,1$. Curvature:
$V''(x)=12x^2-4$, so $V''(0)=-4<0$ (unstable maximum, $V(0)=0$) and
$V''(\pm1)=8>0$ (stable minima, $V(\pm1)=1-2=-1$). This is a symmetric
double well: two stable wells at $x=\pm1$ (depth $-1$) separated by a
barrier of height $0$ at $x=0$. Since $V\to+\infty$ as $x\to\pm\infty$, the
particle is bound for *any* finite energy — there is no "free" behavior
here, only the question of whether motion stays in one well or spans both.

- **$E=-0.5$:** solve $x^4-2x^2=-0.5$. With $u=x^2$: $u^2-2u+0.5=0 \Rightarrow
  u = 1\pm\tfrac{\sqrt2}{2} = 1.7071$ or $0.2929$, giving four turning
  points $x=\pm1.3066,\pm0.5412$. Since $E=-0.5 < V(0)=0$, the barrier is
  forbidden ($V(0)=0>E$), so the particle is confined to *one* well only —
  oscillating either between $x=0.5412$ and $x=1.3066$ (right well) or the
  mirror pair on the left, depending on which side it started on.
- **$E=0$** (exactly the barrier height): solve $x^4-2x^2=0 \Rightarrow
  x^2(x^2-2)=0 \Rightarrow x=0,\pm\sqrt2$. This is the marginal case: $x=0$
  is itself a turning point, but it coincides with the unstable equilibrium
  — the particle asymptotically creeps toward $x=0$ but (in the idealized,
  frictionless limit) never actually arrives in finite time. This is the
  edge case flagged in the turning-point misconception above: at $x=0$
  here, both $v=0$ *and* $F=-V'(0)=0$, because this turning point sits
  exactly on top of the equilibrium.
- **$E=1$** (above the barrier): solve $x^4-2x^2=1$. With $u=x^2$:
  $u^2-2u-1=0 \Rightarrow u=1\pm\sqrt2$; only $u=1+\sqrt2\approx2.4142$ is
  non-negative, giving turning points $x=\pm1.5538$ only. Since
  $E=1>V(0)=0$, the barrier is now allowed territory too — the particle
  oscillates across *both* wells as one connected motion, passing through
  $x=0$ with nonzero speed, between the single pair of turning points
  $x=\pm1.5538$.

**2. Pendulum speed at the bottom, by energy — no ODE.**

A pendulum of length $L$ is released from rest at angle $\theta_0$ from the
vertical. Find its speed at the bottom of the swing.

Take the bottom of the swing as the height reference ($V=0$ there). At
angle $\theta$, the bob sits a height $h(\theta) = L(1-\cos\theta)$ above
the bottom (elementary geometry: the bob is a distance $L\cos\theta$ below
the pivot, and the bottom point is a distance $L$ below the pivot, so the
bob's height above the bottom is $L - L\cos\theta$). Using the uniform-
gravity potential $V=mgh$ derived above, energy conservation between
release ($\theta_0$, $v=0$) and the bottom ($\theta=0$, speed $v$):
$$\underbrace{mgL(1-\cos\theta_0)}_{E \text{ at release}} =
\underbrace{\tfrac12 mv^2}_{E \text{ at bottom}} \quad\Longrightarrow\quad
v = \sqrt{2gL(1-\cos\theta_0)}.$$
Numerically, for $L=1.0\text{ m}$, $\theta_0=60°$, $g=9.8\text{ m/s}^2$:
$1-\cos60° = 1-0.5=0.5$, so $v=\sqrt{2(9.8)(1.0)(0.5)}=\sqrt{9.8}\approx
3.13\text{ m/s}$ — obtained without ever writing down the pendulum's
(nonlinear, generally unsolvable in closed form) equation of motion.

**3. Escape velocity from Earth, derived and computed.**

Using $v_{\text{esc}}=\sqrt{2GM/R}$ derived above, with
$G=6.674\times10^{-11}\text{ N·m}^2/\text{kg}^2$,
$M_\oplus=5.972\times10^{24}\text{ kg}$, $R_\oplus=6.371\times10^6\text{ m}$:
$$GM_\oplus = (6.674\times10^{-11})(5.972\times10^{24}) \approx
3.986\times10^{14}\ \text{m}^3/\text{s}^2,$$
$$v_{\text{esc}} = \sqrt{\frac{2(3.986\times10^{14})}{6.371\times10^{6}}}
= \sqrt{1.2513\times10^{8}} \approx 1.119\times10^4\text{ m/s}
\approx 11.2\text{ km/s}.$$
Cross-check using $GM=gR^2$ (valid since $g=GM/R^2$ at the surface by
definition), so $v_{\text{esc}}=\sqrt{2gR}$: with $g=9.8\text{ m/s}^2$,
$v_{\text{esc}}=\sqrt{2(9.8)(6.371\times10^6)}=\sqrt{1.249\times10^8}
\approx1.117\times10^4\text{ m/s}$ — matching to three significant figures,
as it should since both routes encode the same physical constants.

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. Starting only from the definition $V(x) = -\int_{x_0}^x F(x')\,dx'$,
   derive $F=-dV/dx$.
2. For the spring potential $V(x) = \tfrac12 k_s x^2$, find the turning
   point(s) at total energy $E$ (assume $E\ge0$, as it must be for this
   potential).

**Standard**

3. For $V(x) = x^3-3x$: find all equilibria and classify each as stable or
   unstable, then describe (with turning points exact where possible,
   numerical otherwise) the motion at $E=0$ and at $E=3$.
4. A small ball starts at rest (given an infinitesimal nudge) at the very
   top of a frictionless hemisphere of radius $R$ and slides down the
   outside. At what angle $\theta$ (measured from the top, i.e. from the
   vertical through the center) does it leave the surface?

**Stretch**

5. Starting from energy conservation, derive the period of oscillation
   between two turning points $x_1<x_2$ as
   $$T = 2\int_{x_1}^{x_2} \frac{dx}{\sqrt{2(E-V(x))/m}}.$$
   Then evaluate this integral for the spring potential $V(x)=\tfrac12
   k_sx^2$ and show it reproduces $T=2\pi\sqrt{m/k_s}$ — the period Day 3
   derives by solving the equation of motion directly.

## Hints

1. Differentiate the definition using the fundamental theorem of calculus
   — no new derivation is needed, just apply $d/dx$ to both sides.
2. A turning point is where all the energy is potential: set $K=0$, i.e.
   $E=V(x)$, and solve for $x$.
3. Set $V'(x)=0$ for equilibria and use the sign of $V''(x)$ to classify
   each. For each energy, find every real root of $V(x)=E$, then check the
   sign of $E-V(x)$ in each interval between roots to see which regions are
   allowed and which are connected to which.
4. Write energy conservation between the top and angle $\theta$ to get
   $v(\theta)^2$ as one equation; you need a second equation besides energy
   conservation — what happens to the normal force at the moment the ball
   leaves the surface?
5. Solve the energy-conservation equation $E=\tfrac12mv^2+V(x)$ for
   $v=dx/dt$, invert to get $dt$ in terms of $dx$, and integrate over one
   trip between the turning points — think about why a full period is
   twice that one-way trip.

## Solutions

**1.** By the fundamental theorem of calculus, if $V(x) =
-\int_{x_0}^x F(x')\,dx'$, then
$$\frac{dV}{dx} = -\frac{d}{dx}\int_{x_0}^x F(x')\,dx' = -F(x),$$
so $F(x) = -dV/dx$.

**2.** At a turning point $K=0$, so $E=V(x)=\tfrac12k_sx^2$, giving
$x^2 = 2E/k_s$ and hence two turning points
$$x = \pm\sqrt{2E/k_s}, \qquad E\ge0$$
(required since $V(x)=\tfrac12k_sx^2\ge0$ everywhere for this potential, so
no motion — and no real turning point — exists at $E<0$). (This matches
the amplitude $A=\sqrt{2E/k_s}$ used in Exercise 5.)

**3.** $V'(x)=3x^2-3=3(x-1)(x+1)=0$ at $x=\pm1$. $V''(x)=6x$: at $x=1$,
$V''=6>0$ (stable minimum, $V(1)=1-3=-2$); at $x=-1$, $V''=-6<0$ (unstable
maximum, $V(-1)=-1+3=2$). Since $V\to-\infty$ as $x\to-\infty$ and
$V\to+\infty$ as $x\to+\infty$, the far-left region is always allowed at
any finite energy — bound motion (in the sense of being trapped on both
sides forever) is only possible on the well side of the barrier.

At $E=0$: solve $x^3-3x=0 \Rightarrow x(x-\sqrt3)(x+\sqrt3)=0$, roots
$x=-\sqrt3,0,\sqrt3$. Checking signs of $V(x)-E$ between roots: $V<0$
(allowed) for $x\le-\sqrt3$ and for $0\le x\le\sqrt3$; $V>0$ (forbidden) for
$-\sqrt3<x<0$; $V>0$ (forbidden) for $x>\sqrt3$. So there are two disjoint
allowed regions: $x\le-\sqrt3$ (extends to $-\infty$, a single turning
point at $x=-\sqrt3$ — **free** motion, the particle approaches from
$-\infty$, turns around, returns to $-\infty$) and $0\le x\le\sqrt3$ (two
turning points bracketing the well minimum at $x=1$ — **bound**,
oscillating motion confined near the well).

At $E=3$ (above the local-max barrier height $V(-1)=2$): solve
$x^3-3x-3=0$. This cubic has only one real root (discriminant
$-4(-3)^3-27(-3)^2=108-243=-135<0$), numerically near $x\approx2.10$. Since
$E=3$ now exceeds the barrier peak $V(-1)=2$, the forbidden hump around
$x=-1$ disappears — $V(x)\le E$ continuously all the way from $x\to-\infty$
through the former barrier location and the well, up to the single turning
point at $x\approx2.10$. Motion is again **free**: the particle sweeps in
from $-\infty$, over what used to be a barrier, through the well, turns
around once near $x\approx2.10$, and heads back to $-\infty$.

**4.** Let $\theta$ be the angle from the top, measured from the center.
Height above the center-level, at angle $\theta$: $h(\theta)=R\cos\theta$
(elementary geometry of the hemisphere). Energy conservation from the top
($\theta=0$, $v=0$, height $R$) to angle $\theta$ (height $R\cos\theta$,
speed $v$), using $V=mgh$:
$$mgR = mgR\cos\theta + \tfrac12mv^2 \quad\Longrightarrow\quad
v^2 = 2gR(1-\cos\theta). \tag{i}$$
The ball leaves the surface when the normal force $N\to0$. Up to that
point, Newton's second law in the radial direction needs one kinematic
fact we haven't derived yet: in uniform circular motion the velocity
vector turns with the position vector, giving an inward acceleration
$v^2/R$ — a kinematics fact we take as given here (Day 4's orbit survey
motivates it). With that, and gravity's inward radial component
$mg\cos\theta$ against the surface pushing outward with $N$:
$$mg\cos\theta - N = \frac{mv^2}{R} \quad\xrightarrow{N=0}\quad
v^2 = gR\cos\theta. \tag{ii}$$
Equating (i) and (ii):
$$2gR(1-\cos\theta) = gR\cos\theta \;\Longrightarrow\; 2-2\cos\theta=\cos\theta
\;\Longrightarrow\; \cos\theta = \tfrac23 \;\Longrightarrow\;
\theta = \arccos(2/3) \approx 48.2°.$$

**5.** From energy conservation, $E=\tfrac12mv^2+V(x)$, solve for the speed:
$$v = \frac{dx}{dt} = \sqrt{\frac{2(E-V(x))}{m}}$$
(taking the positive root; the particle's speed is the magnitude of $v$
regardless of direction of travel). Separating variables,
$$dt = \frac{dx}{\sqrt{2(E-V(x))/m}}.$$
The time to travel from turning point $x_1$ to turning point $x_2$ is the
integral of this over that range:
$$t_{1\to2} = \int_{x_1}^{x_2}\frac{dx}{\sqrt{2(E-V(x))/m}}.$$
By time-reversal symmetry, the return trip from $x_2$ back to $x_1$ retraces
the same path at the same speed at each point, so it takes exactly the same
time $t_{1\to2}$. One full period is one round trip, so
$$T = 2\,t_{1\to2} = 2\int_{x_1}^{x_2}\frac{dx}{\sqrt{2(E-V(x))/m}}.$$

For the spring, $V(x)=\tfrac12k_sx^2$ with turning points $x_{1,2}=\mp A$,
$A=\sqrt{2E/k_s}$ (Exercise 2), so $E=\tfrac12k_sA^2$. Then
$$E-V(x) = \tfrac12k_sA^2-\tfrac12k_sx^2 = \tfrac12k_s(A^2-x^2)
\;\Longrightarrow\; \sqrt{\frac{2(E-V)}{m}} = \sqrt{\frac{k_s}{m}}\sqrt{A^2-x^2}
= \omega_0\sqrt{A^2-x^2},$$
defining $\omega_0\equiv\sqrt{k_s/m}$ (the natural frequency Day 3 will use
formally). So
$$T = 2\int_{-A}^{A}\frac{dx}{\omega_0\sqrt{A^2-x^2}}
= \frac{2}{\omega_0}\Big[\arcsin(x/A)\Big]_{-A}^{A}
= \frac{2}{\omega_0}\left(\frac\pi2-\left(-\frac\pi2\right)\right)
= \frac{2\pi}{\omega_0}.$$
So $T = 2\pi/\omega_0 = 2\pi\sqrt{m/k_s}$ — exactly the SHM period Day 3
derives by solving $m\ddot x=-k_sx$ directly, obtained here purely from an
energy integral.

## Connection to QM

Every quantum-mechanics problem you will meet in this course starts by
writing down a potential $V(x)$ and asking what happens to a particle
placed in it — the well, the barrier, the flat asymptote you learned to
read today *is* the stage on which the entire subject is performed. The
classification you practiced above — bound motion between two turning
points versus free motion escaping to infinity — reappears almost
unchanged as the classification of quantum states: a particle trapped in a
well produces **bound states** with discrete, quantized energies (the
particle-in-a-box and the hydrogen atom are both bound-state problems),
while a particle with enough energy to escape to infinity produces
**scattering states** with a continuous range of allowed energies.

The classically forbidden region — where today's inequality $V(x)>E$
prevents any classical particle from ever going — is exactly the region
where quantum mechanics does something classically impossible: the
wavefunction does not vanish there, and a particle has a nonzero
probability of appearing on the far side of a barrier it classically could
never cross. That phenomenon, **tunneling**, is covered in full on Day 17,
but its entire meaning rests on being able to point at a $V(x)$ diagram and
say precisely where the forbidden region is — which is exactly today's
skill.

Finally, the small-oscillation preview above (every stable equilibrium
locally looks like a spring well) is the reason the quantum harmonic
oscillator — solved exactly, with evenly spaced energy levels — is one of
the few potentials solved exactly in every introductory QM course: it is
the universal first approximation to *any* potential well near its
minimum, quantum or classical alike.
