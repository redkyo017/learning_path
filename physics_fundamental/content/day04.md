# Day 4 — Momentum, Angular Momentum, and Symmetry

## Learning objectives

By the end of today you should be able to:
- Derive conservation of total momentum for a two-particle isolated system
  directly from Newton's second and third laws, and state how the argument
  generalizes to $N$ particles.
- Solve one-dimensional perfectly inelastic and elastic collision problems,
  correctly identifying which quantities (momentum, kinetic energy, or
  both) are conserved in each case.
- Use the center-of-mass frame to solve an elastic collision by inspection
  (velocities simply reverse), then transform the result back to the lab
  frame.
- Define angular momentum $\vec L=\vec r\times\vec p$, derive
  $d\vec L/dt=\vec\tau$, and prove that a central force conserves $\vec L$.
- State the informal symmetry $\leftrightarrow$ conservation-law dictionary
  (space translation $\to$ momentum, rotation $\to$ angular momentum, time
  translation $\to$ energy) and explain, in your own words, why these three
  quantities are singled out.
- Describe, at survey depth, rigid-body rotation ($I$, $L=I\omega$,
  $K=\tfrac12 I\omega^2$) and orbital motion (Kepler's laws, circular-orbit
  speed) without needing to re-derive every detail.

Time budget: ~3 hours.

## Reference material

- Halliday, Resnick & Walker, *Fundamentals of Physics* — the chapters on
  momentum and collisions, and on rotation, cover the same ground with many
  more worked numerical examples.
- Morin, *Introduction to Classical Mechanics* — the chapters on momentum
  and angular momentum are more terse and more general (they do the
  $N$-body and central-force arguments in full vector form); useful once
  today's material feels routine.
- This file is self-contained: everything you need is derived below.
- Builds on Day 1 (Newton's second law as an ODE, $\vec F=m\vec a$) and
  Day 2 (energy conservation and the potential $V(x)$). Nothing beyond
  those two days is assumed.

## Theory

### Momentum conservation from Newton's third law

Define the momentum of a particle as $\vec p = m\vec v$. Newton's second
law, from Day 1, is $\dfrac{d\vec p}{dt} = \vec F$ (this is the more
general statement of $\vec F=m\vec a$; it reduces to it whenever $m$ is
constant, which is all we need today).

Consider two particles, labeled 1 and 2, that interact with each other and
with nothing else (an *isolated* two-body system). Let $\vec F_{12}$ be the
force on particle 1 due to particle 2, and $\vec F_{21}$ the force on
particle 2 due to particle 1. Newton's second law for each particle reads
$$\frac{d\vec p_1}{dt} = \vec F_{12}, \qquad \frac{d\vec p_2}{dt} = \vec F_{21}.$$
Newton's third law states $\vec F_{12} = -\vec F_{21}$ — the forces of a
mutual interaction are always equal and opposite. Adding the two equations
of motion:
$$\frac{d}{dt}\left(\vec p_1+\vec p_2\right) = \vec F_{12}+\vec F_{21} = \vec F_{12} - \vec F_{12} = 0.$$
So the **total momentum** $\vec P = \vec p_1+\vec p_2$ of an isolated
two-body system is constant in time. This is the full derivation, not a
motivated guess: it follows from N2 and N3 alone, with no further physical
assumption.

**Generalization to $N$ particles.** For $N$ mutually interacting,
otherwise isolated particles, sum Newton's second law over all of them:
$\frac{d}{dt}\sum_i\vec p_i = \sum_i \vec F_i$, where $\vec F_i$ is the net
force on particle $i$ from every other particle. Every pairwise interaction
force $\vec F_{ij}$ appears exactly twice in the double sum
$\sum_i\vec F_i = \sum_{i\ne j}\vec F_{ij}$ — once as $\vec F_{ij}$ and once
as $\vec F_{ji}=-\vec F_{ij}$ — so the two cancel pairwise and the entire
sum vanishes. Hence $\frac{d}{dt}\sum_i\vec p_i = 0$: **total momentum of
any isolated system is conserved**, regardless of how many particles it
contains or how complicated the internal forces are, as long as every
internal force obeys Newton's third law. If instead there is a net
*external* force $\vec F_{\text{ext}}$ acting on the system, the same
argument gives $\dfrac{d\vec P}{dt} = \vec F_{\text{ext}}$ — internal
forces still cancel, only the external force can change total momentum.

### Collisions in one dimension: inelastic and elastic

A collision is a brief, often violent, interaction between two bodies. As
long as any external forces (gravity, friction) are negligible compared to
the enormous, brief contact forces during the collision itself — or act for
too short a time to matter — total momentum is conserved through the
collision even though we typically know nothing about the details of the
contact force. This is what makes collision problems tractable: momentum
conservation is a bookkeeping statement between "before" and "after" that
sidesteps the messy interaction in between entirely.

**Perfectly inelastic collision.** The two bodies stick together and move
with a common final velocity $v_f$. Momentum conservation alone determines
$v_f$:
$$m_1v_{1i} + m_2v_{2i} = (m_1+m_2)v_f \quad\Longrightarrow\quad v_f = \frac{m_1v_{1i}+m_2v_{2i}}{m_1+m_2}.$$
Nothing here requires kinetic energy to be conserved, and in general it is
not: some of it is converted to heat, sound, and permanent deformation
during the collision. The kinetic energy lost is
$$\Delta K = \left(\tfrac12 m_1v_{1i}^2+\tfrac12 m_2v_{2i}^2\right) - \tfrac12(m_1+m_2)v_f^2 \ge 0,$$
which is strictly positive for any inelastic collision (equality holds only
if $v_{1i}=v_{2i}$, i.e. no actual collision occurs).

> **Misconception:** "momentum and kinetic energy are interchangeable
> bookkeeping — if one is conserved, so is the other." They are two
> independent conserved-or-not quantities with different transformation
> properties (momentum is linear in $v$, kinetic energy is quadratic), and
> a collision can conserve one without conserving the other. A perfectly
> inelastic collision conserves momentum but *not* kinetic energy; only an
> *elastic* collision (defined next) conserves both simultaneously, and
> that is a special, restrictive condition on the collision, not the
> generic case.

**Elastic collision.** Both momentum and kinetic energy are conserved:
$$m_1v_{1i}+m_2v_{2i} = m_1v_{1f}+m_2v_{2f} \tag{momentum}$$
$$\tfrac12 m_1v_{1i}^2+\tfrac12 m_2v_{2i}^2 = \tfrac12 m_1v_{1f}^2+\tfrac12 m_2v_{2f}^2. \tag{kinetic energy}$$
Rewrite momentum conservation as $m_1(v_{1i}-v_{1f}) = m_2(v_{2f}-v_{2i})$,
and kinetic-energy conservation, using $a^2-b^2=(a-b)(a+b)$, as
$$m_1(v_{1i}-v_{1f})(v_{1i}+v_{1f}) = m_2(v_{2f}-v_{2i})(v_{2f}+v_{2i}).$$
Dividing this second equation by the first (valid whenever $v_{1i}\ne
v_{1f}$, i.e. an actual collision happens) cancels the $m_1(v_{1i}-v_{1f})=
m_2(v_{2f}-v_{2i})$ factor on each side, leaving
$$v_{1i}+v_{1f} = v_{2i}+v_{2f} \quad\Longrightarrow\quad v_{1f}-v_{2f} = -\left(v_{1i}-v_{2i}\right).$$
This is a clean intermediate result worth naming: **the relative velocity
of the two bodies exactly reverses sign in an elastic collision.**
Substituting $v_{2f}=v_{1i}+v_{1f}-v_{2i}$ into the momentum equation and
solving for $v_{1f}$ (and the mirror-image steps for $v_{2f}$) gives the
final velocities in closed form:
$$v_{1f} = \frac{(m_1-m_2)v_{1i}+2m_2v_{2i}}{m_1+m_2}, \qquad v_{2f} = \frac{(m_2-m_1)v_{2i}+2m_1v_{1i}}{m_1+m_2}.$$
Worked Example 1 below applies these to numbers and checks the equal-mass
limit.

### The center-of-mass frame trick

Define the center-of-mass velocity $V_{\text{cm}} = \dfrac{m_1v_{1i}+m_2v_{2i}}{m_1+m_2}$
— by the momentum-conservation result above, this is the same before and
after the collision, since $(m_1+m_2)V_{\text{cm}}$ is exactly the (constant)
total momentum. Work in the frame moving at $V_{\text{cm}}$: define
$u_1=v_1-V_{\text{cm}}$, $u_2=v_2-V_{\text{cm}}$ for each body, at any time.
By construction, $m_1u_1+m_2u_2 = m_1v_1+m_2v_2-(m_1+m_2)V_{\text{cm}} = 0$
identically — **total momentum is exactly zero in this frame**, before and
after the collision (it is an inertial frame, since $V_{\text{cm}}$ is
constant, so momentum conservation still applies inside it).

With zero total momentum, $u_{2}=-(m_1/m_2)u_{1}$ at all times. Substituting
this constraint into kinetic-energy conservation shows the kinetic energy
is proportional to $u_1^2$ alone, both before and after; conservation of
kinetic energy therefore forces $u_{1f}^2=u_{1i}^2$, i.e. $u_{1f}=\pm
u_{1i}$. The choice $u_{1f}=u_{1i}$ is the trivial "no collision happened"
solution, so the physical elastic collision has $u_{1f}=-u_{1i}$, and hence
also $u_{2f}=-u_{2i}$. (This kinetic-energy step in the COM frame is
legitimate because $K_{\text{lab}}=K_{\text{cm}}+\tfrac12(m_1+m_2)V_{\text{cm}}^2$,
and $V_{\text{cm}}$ is constant through the collision, so conserving total
kinetic energy in the lab frame is exactly equivalent to conserving the
internal kinetic energy $K_{\text{cm}}$ in the COM frame — the bulk term
$\tfrac12(m_1+m_2)V_{\text{cm}}^2$ cannot change either way.) **In the center-of-mass frame, an elastic collision
simply reverses every velocity** — no algebra needed once you're in that
frame. Transforming back ($v_{1f}=u_{1f}+V_{\text{cm}}$, etc.) reproduces
exactly the closed-form result above; this is a useful shortcut precisely
because it replaces solving two simultaneous equations with one frame shift
plus a sign flip.

### Angular momentum and torque

Define the **angular momentum** of a particle about a chosen origin as
$$\vec L = \vec r \times \vec p,$$
where $\vec r$ is the particle's position relative to that origin.
Differentiate using the product rule for cross products:
$$\frac{d\vec L}{dt} = \frac{d\vec r}{dt}\times\vec p + \vec r\times\frac{d\vec p}{dt} = \vec v\times\vec p + \vec r\times\vec F,$$
using $d\vec p/dt=\vec F$ (Newton's second law) in the second term. The
first term vanishes identically: $\vec v\times\vec p = \vec v\times(m\vec
v) = m(\vec v\times\vec v) = 0$, since the cross product of any vector with
itself is zero. So
$$\frac{d\vec L}{dt} = \vec r\times\vec F \;=:\; \vec\tau,$$
which *defines* the **torque** $\vec\tau$ about the same origin. This
relation, $d\vec L/dt=\vec\tau$, is the exact rotational analogue of
$d\vec p/dt = \vec F$ — angular momentum plays the role for rotational
motion that ordinary momentum plays for translational motion, and it was
derived, not assumed, directly from $\vec L$'s definition and Newton's
second law.

> **Misconception:** "angular momentum requires circular motion." It does
> not — $\vec L=\vec r\times\vec p$ is defined for *any* trajectory about
> *any* chosen origin. A completely free particle (no force at all) moving
> in a straight line at constant velocity has $\vec\tau=\vec r\times\vec
> F=0$ trivially (since $\vec F=0$), so $\vec L$ is constant — and indeed
> $|\vec L|=mvb$, where $b$ is the perpendicular distance from the origin
> to the line of motion, stays fixed for the entire straight-line path,
> since neither $v$ nor $b$ changes. Circular motion is one situation that
> conserves angular momentum about its center; it is nowhere near the only
> one.

### Central forces conserve angular momentum; Kepler's second law

A **central force** is one that always points along the line joining the
particle to a fixed center, i.e. $\vec F = f(r)\,\hat r$ for some scalar
function $f(r)$ of the distance $r=|\vec r|$ alone, where $\hat r=\vec
r/r$. Gravity and the Coulomb force are the two central forces you will use
most; both have this exact form.

For a central force, the torque about that same center is
$$\vec\tau = \vec r\times\vec F = \vec r\times f(r)\hat r = \frac{f(r)}{r}\,(\vec r\times\vec r) = 0,$$
since $\vec r\times\vec r=0$ for any vector $\vec r$ (the cross product of
a vector with any scalar multiple of itself vanishes). Combined with
$d\vec L/dt=\vec\tau$ derived above, this gives immediately
$$\frac{d\vec L}{dt} = 0 \quad\Longrightarrow\quad \vec L \text{ is conserved under any central force}.$$
This is the key result of the day: it holds for *any* central force law
$f(r)$ — inverse-square gravity, the inverse-square Coulomb force, or
anything else with the same $f(r)\hat r$ structure — not just for the
specific case of gravity.

**Kepler's second law falls out in one line.** The area swept out by the
position vector $\vec r$ in a small time $dt$ is $dA=\tfrac12|\vec r\times
d\vec r|$ (only the component of $d\vec r$ perpendicular to $\vec r$
contributes to the cross product, and that component times $r$, halved, is
exactly the area of the thin triangular sliver swept). Dividing by $dt$,
$$\frac{dA}{dt} = \frac12\left|\vec r\times\vec v\right| = \frac{|\vec L|}{2m},$$
using $\vec L = \vec r\times m\vec v = m(\vec r\times\vec v)$. Since $\vec
L$ is constant for any central force (as just shown), $dA/dt$ is constant
too: **equal areas are swept out in equal times** — Kepler's second law,
here seen to be nothing more than angular momentum conservation restated
geometrically, true for any orbit under any central force, not a special
fact about gravity alone.

### The symmetry dictionary: an informal statement of Noether's theorem

Look at the three conservation laws collected so far, across today and
Days 1–2, side by side with the situation each one requires:

- If the physics of an isolated system doesn't care *where* it is located
  in space (shift the whole system sideways and nothing about how it
  behaves changes) — **momentum** is conserved.
- If the physics doesn't care *which direction* it's oriented in (rotate
  the whole system and nothing changes — true whenever the only forces are
  central, pointing along lines that rotate along with everything else) —
  **angular momentum** is conserved.
- If the physics doesn't care *when* it happens (run the same experiment
  today or tomorrow and get the same behavior) — **energy** is conserved
  (Day 2).

This pattern — a continuous symmetry of the physics implies a conserved
quantity — is the informal, pre-calculus-of-variations statement of
**Noether's theorem**, one of the deepest results in all of physics. A full
proof needs the machinery of Days 9–11 (the Lagrangian and the principle of
least action); for now, take it as an empirical pattern you've just derived
three instances of, and notice it is not a coincidence that these three
particular quantities are the famous conserved ones.

**Why these three, and not some other conserved quantity?** Because empty
space, left alone, genuinely has these three symmetries built in: it looks
the same at every location (homogeneity), the same in every direction
(isotropy), and the laws of physics don't change from one moment to the
next. Any truly isolated system therefore *automatically* inherits all
three symmetries and hence all three conservation laws — momentum, angular
momentum, and energy are conserved for essentially any isolated system you
could construct, which is exactly why they are the three quantities every
physics course drills first. A conserved quantity tied to some other,
made-up symmetry (say, "shift only the $x$-coordinate of particle 1") would
only be conserved for very special, contrived force laws that happen to
respect that made-up symmetry — which is why you never hear about it.

### Consolidation survey: rigid-body rotation

*(Survey — paragraph depth, no derivations; a first map of the territory,
not proofs.)* A rigid body rotating about a fixed axis behaves, for
rotational purposes, exactly like a point mass does for translational
purposes, with each translational quantity replaced by its rotational
counterpart. Mass $m$ is replaced by the **moment of inertia**
$I=\sum_i m_ir_i^2$ (a sum, over every mass element of the body, of that
element's mass times the square of its distance from the rotation axis) —
$I$ depends on the axis chosen and on how the mass is distributed relative
to it, not just on the total mass. Momentum $p=mv$ is replaced by angular
momentum $L=I\omega$ for rotation about a fixed axis (a general
asymmetric body can have $\vec L$ not parallel to $\vec\omega$, but that
subtlety doesn't arise for the fixed-axis case used here), and kinetic
energy $K=\tfrac12mv^2$ is replaced by
rotational kinetic energy $K=\tfrac12I\omega^2$, where $\omega$ is the
body's angular velocity. Every conservation law derived above for a point
particle's $\vec L=\vec r\times\vec p$ applies equally to $L=I\omega$ for a
rotating rigid body — Worked Example 2 uses exactly this to explain a
spinning skater.

### Consolidation survey: gravity and orbits

*(Survey — paragraph depth; results are stated, not derived, except for
the one short geometric fact below — Exercise 4 is where the actual
algebra happens.)* Kepler's three empirical laws, discovered decades
before Newton explained them, state: (1) planets orbit the Sun on
ellipses with the Sun at one focus; (2) equal areas are swept out in equal
times (derived above, for any central force, as a consequence of angular
momentum conservation); (3) the square of the orbital period is
proportional to the cube of the orbit's semi-major axis, $T^2\propto a^3$.
For a body in uniform circular motion, the centripetal acceleration
$a=v^2/r$ (directed inward) follows from one geometric fact: over a short
time $\Delta t$ the velocity vector turns through the same small angle
$\Delta\theta=v\Delta t/r$ that the position vector does, so
$|\Delta v|=v\,\Delta\theta=v^2\Delta t/r$, giving
$a=|\Delta v|/\Delta t=v^2/r$. Newton's law of gravitation, $F=GMm/r^2$
— which we take as given, an experimentally established force law — then
supplies exactly this centripetal force for a circular orbit; balancing
the two determines the orbital speed $v(r)$ and, from it, the
period-radius relation (Kepler's third law, circular case). Exercise 4
below works through that algebra in full.

## Worked examples

**1. Elastic collision, general masses — numbers and the equal-mass
check.** A ball of mass $m_1=3\text{ kg}$ moves at $v_{1i}=4\text{ m/s}$
and collides elastically, head-on, with a ball of mass $m_2=1\text{ kg}$
moving at $v_{2i}=-2\text{ m/s}$ (approaching from the opposite direction).
Using the closed-form result derived above:
$$v_{1f} = \frac{(3-1)(4)+2(1)(-2)}{3+1} = \frac{8-4}{4} = 1\text{ m/s}, \qquad
v_{2f} = \frac{(1-3)(-2)+2(3)(4)}{3+1} = \frac{4+24}{4} = 7\text{ m/s}.$$
Check momentum: before, $3(4)+1(-2)=10$; after, $3(1)+1(7)=10$. ✓. Check
kinetic energy: before, $\tfrac12(3)(16)+\tfrac12(1)(4)=24+2=26\text{ J}$;
after, $\tfrac12(3)(1)+\tfrac12(1)(49)=1.5+24.5=26\text{ J}$. ✓. Now check
the equal-mass limit symbolically: setting $m_1=m_2=m$ in the general
formulas gives $v_{1f}=\dfrac{0\cdot v_{1i}+2mv_{2i}}{2m}=v_{2i}$ and
$v_{2f}=\dfrac{0\cdot v_{2i}+2mv_{1i}}{2m}=v_{1i}$ — **the two bodies
exactly swap velocities**, the familiar result for equal-mass elastic
collisions (e.g. one billiard ball striking an identical one at rest: the
moving ball stops, the struck ball takes off with the exact initial
velocity).

**2. Skater pulling arms in: $I\omega$ conservation and where the extra
kinetic energy comes from.** A skater spinning with arms extended has
$I_1=5\text{ kg·m}^2$ at $\omega_1=2\text{ rad/s}$. She pulls her arms in,
reducing her moment of inertia to $I_2=1.25\text{ kg·m}^2$. On frictionless
ice, gravity (acting through her center of mass) and the normal force from
the ice (acting at her blades) both have lines of action *parallel* to the
vertical rotation axis, and a force parallel to a chosen axis produces zero
torque about that axis regardless of where it's applied — so neither
contributes any torque about the spin axis, and $L=I\omega$
is conserved:
$$I_1\omega_1 = I_2\omega_2 \quad\Longrightarrow\quad \omega_2 = \frac{I_1\omega_1}{I_2} = \frac{5\times2}{1.25} = 8\text{ rad/s}.$$
Kinetic energy, however, is *not* conserved: $K_1=\tfrac12I_1\omega_1^2=
\tfrac12(5)(4)=10\text{ J}$, while $K_2=\tfrac12I_2\omega_2^2=\tfrac12
(1.25)(64)=40\text{ J}$ — kinetic energy exactly quadrupled ($K_2/K_1=4$). This is not a
violation of energy conservation: the skater's muscles do real mechanical
work pulling her arms inward. Each part of an arm moves both radially
(inward) and tangentially (speeding up as $r$ shrinks with $L$ fixed), so
the muscular force pulling it inward is not perpendicular to its velocity
and therefore does positive work on it — that work, ultimately paid for by
the skater's chemical (muscular) energy, is exactly the $30\text{ J}$
increase in rotational kinetic energy. Angular momentum is conserved
because there's no external torque; kinetic energy is not conserved
because there is internal work — the two statements are entirely
consistent.

**3. Comet at perihelion vs. aphelion via $L$ conservation.** A comet's
closest approach to the Sun (perihelion) is $r_p=0.5\text{ AU}$, and its
farthest point (aphelion) is $r_a=50\text{ AU}$. At both of these special
points the comet's velocity is purely tangential (perpendicular to the
radius vector, by the definition of the turning points of the radial
distance), so $|\vec L|=mv_pr_p=mv_ar_a$ exactly, with no angle factor
needed. If the comet's speed at perihelion is $v_p=40\text{ km/s}$, then
$$v_a = \frac{v_pr_p}{r_a} = \frac{40\times0.5}{50} = 0.4\text{ km/s}.$$
The comet is $100\times$ farther from the Sun at aphelion and moves
$100\times$ slower there — a direct, numerical illustration of angular
momentum conservation doing the work that in Day 2's language would
otherwise require solving the full orbit equation.

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. Starting only from Newton's second law $d\vec p_i/dt=\vec F_i$ applied
   separately to each of two particles in an isolated system, and Newton's
   third law, derive that the total momentum $\vec p_1+\vec p_2$ is
   constant in time. State in one sentence how the argument generalizes to
   $N$ particles.
2. Starting from the definition $\vec L=\vec r\times\vec p$, derive
   $d\vec L/dt=\vec\tau=\vec r\times\vec F$, and show that if $\vec F$ is a
   central force ($\vec F=f(r)\hat r$), then $d\vec L/dt=0$.

**Standard**

3. A bullet of mass $m=10\text{ g}$ moving horizontally at speed $v_0$
   embeds itself in a wooden block of mass $M=2\text{ kg}$ hanging at rest
   from a long string (a *ballistic pendulum*). The block-plus-bullet then
   swings upward, rising to a maximum height $h=5\text{ cm}$ above its
   starting point. Take $g=9.8\text{ m/s}^2$. Find $v_0$. Explicitly state
   which conservation law
   applies during the (brief) embedding phase and which applies during the
   (subsequent) swing-up phase, and why they are different laws.
4. A satellite orbits the Earth ($M_E=5.97\times10^{24}\text{ kg}$) in a
   circular orbit of radius $r=7000\text{ km}$. Derive the orbital speed
   $v(r)$ from Newton's law of gravitation supplying the centripetal force,
   then derive the period-radius relation $T^2=\dfrac{4\pi^2}{GM_E}r^3$.
   Evaluate both $v$ and $T$ numerically for this orbit
   ($G=6.674\times10^{-11}\text{ N·m}^2/\text{kg}^2$).

**Stretch**

5. Two masses $m_1,m_2$ interact only through a central force depending on
   their separation, $\vec F_{12}=f(r)\hat r$ with $\vec r=\vec r_1-\vec
   r_2$. Write Newton's second law for each mass separately, then combine
   the two equations to show that the *relative coordinate* $\vec r$ obeys
   $\mu\ddot{\vec r}=f(r)\hat r$, a genuine one-body equation of motion,
   where $\mu=\dfrac{m_1m_2}{m_1+m_2}$ is the **reduced mass**. Then, in
   one paragraph, explain why this reduction matters for the hydrogen atom
   (Day 14).

## Hints

1. Write $d\vec p_1/dt=\vec F_{12}$ and $d\vec p_2/dt=\vec F_{21}$
   separately, add them, and invoke Newton's third law on the interaction
   force pair.
2. Product rule on $\vec r\times\vec p$ — one of the two terms dies by a
   property of the cross product.
3. Identify what's conserved during each phase separately before writing
   any equations — the embedding is fast and violent (one law applies), the
   swing-up is slow and governed by gravity alone (a different law
   applies); do not use the same conservation law for both phases.
4. Set the gravitational force $GM_Em/r^2$ equal to the centripetal force
   $mv^2/r$ required for circular motion and solve for $v$; then use
   $T=2\pi r/v$ and substitute.
5. Divide each body's equation of motion by its own mass, then subtract.

## Solutions

**1.** For particles 1 and 2, Newton's second law gives
$\frac{d\vec p_1}{dt}=\vec F_{12}$ and $\frac{d\vec p_2}{dt}=\vec F_{21}$,
where $\vec F_{12}$ is the force on 1 from 2 and vice versa. Adding:
$$\frac{d}{dt}(\vec p_1+\vec p_2) = \vec F_{12}+\vec F_{21}.$$
Newton's third law gives $\vec F_{21}=-\vec F_{12}$, so the right side is
identically zero, hence $\vec p_1+\vec p_2$ is constant in time.
*Generalization:* for $N$ particles, summing Newton's second law over all
of them gives $\frac{d}{dt}\sum_i\vec p_i=\sum_{i\ne j}\vec F_{ij}$, and
every pairwise term $\vec F_{ij}$ in that double sum is canceled by its
Newton's-third-law partner $\vec F_{ji}=-\vec F_{ij}$, so the total
momentum of any isolated $N$-particle system is conserved, exactly as for
$N=2$.

**2.** By the product rule for cross products,
$$\frac{d\vec L}{dt} = \frac{d\vec r}{dt}\times\vec p + \vec r\times\frac{d\vec p}{dt} = \vec v\times(m\vec v) + \vec r\times\vec F.$$
The first term is $m(\vec v\times\vec v)=0$ since any vector crossed with
itself is zero. The second term is $\vec r\times\vec F=:\vec\tau$ by
definition of torque. So $d\vec L/dt=\vec\tau$ in general. For a central
force $\vec F=f(r)\hat r=\frac{f(r)}{r}\vec r$, the torque is
$\vec\tau=\vec r\times\frac{f(r)}{r}\vec r=\frac{f(r)}{r}(\vec r\times\vec
r)=0$, since $\vec r\times\vec r=0$ for any vector. Hence
$d\vec L/dt=0$: $\vec L$ is conserved.

**3.** *Phase 1 (embedding, fast/violent): momentum only.* The bullet-block
contact force is enormous and acts for a tiny time, so momentum (not
energy — energy is lost to deformation and heat, exactly as in the
perfectly-inelastic-collision paragraph and the momentum/KE misconception
callout in Theory) is conserved:
$$mv_0 = (M+m)v_f \quad\Longrightarrow\quad v_f = \frac{mv_0}{M+m}.$$
*Phase 2 (swing-up, slow, governed by gravity alone): mechanical energy
only.* The string tension does no work (always perpendicular to the
motion) and gravity is conservative, so
$$\tfrac12(M+m)v_f^2 = (M+m)gh \quad\Longrightarrow\quad v_f = \sqrt{2gh}.$$
Numerically, $v_f=\sqrt{2(9.8)(0.05)}=\sqrt{0.98}\approx0.990\text{ m/s}$.
Substituting back into the Phase 1 result with $M+m=2.01\text{ kg}$,
$m=0.01\text{ kg}$:
$$v_0 = \frac{(M+m)v_f}{m} = \frac{2.01\times0.990}{0.01} \approx 199\text{ m/s}.$$
The two conservation laws are genuinely different: momentum is conserved
whenever there's no net external impulse (true during the near-instant
collision, regardless of how much kinetic energy is dissipated), while
mechanical energy is conserved whenever every force doing work is
conservative (true during the swing, where gravity is the only force doing
work) — the collision violates the energy condition, and the swing
violates nothing, which is exactly why one law each applies to a different
phase.

**4.** Using the survey's $a=v^2/r$ for uniform circular motion, the
centripetal force required is $ma=mv^2/r$. Setting Newton's gravitational
force equal to this:
$$\frac{GM_Em}{r^2} = \frac{mv^2}{r} \quad\Longrightarrow\quad v = \sqrt{\frac{GM_E}{r}}.$$
The orbital period is the circumference divided by the speed:
$$T = \frac{2\pi r}{v} = \frac{2\pi r}{\sqrt{GM_E/r}} = 2\pi\sqrt{\frac{r^3}{GM_E}} \quad\Longrightarrow\quad T^2 = \frac{4\pi^2}{GM_E}r^3.$$
Numerically: $GM_E = (6.674\times10^{-11})(5.97\times10^{24}) \approx
3.984\times10^{14}\text{ m}^3/\text{s}^2$. With $r=7.0\times10^6\text{ m}$:
$$v = \sqrt{\frac{3.984\times10^{14}}{7.0\times10^6}} = \sqrt{5.692\times10^{7}} \approx 7545\text{ m/s} \approx 7.54\text{ km/s}.$$
$$T = \frac{2\pi(7.0\times10^6)}{7545} \approx 5830\text{ s} \approx 97.2\text{ minutes},$$
consistent with the well-known ~90-minute period of low-Earth-orbit
satellites.

**5.** Newton's second law for each mass, with $\vec F_{12}=f(r)\hat r$ the
force on 1 due to 2 and $\vec F_{21}=-f(r)\hat r$ its N3 reaction:
$$m_1\ddot{\vec r}_1 = f(r)\hat r, \qquad m_2\ddot{\vec r}_2 = -f(r)\hat r.$$
Divide the first equation by $m_1$ and the second by $m_2$, then subtract
the second from the first:
$$\ddot{\vec r}_1-\ddot{\vec r}_2 = f(r)\hat r\left(\frac{1}{m_1}+\frac{1}{m_2}\right).$$
The left side is $\ddot{\vec r}$, since $\vec r=\vec r_1-\vec r_2$ by
definition. Defining $\mu$ by $\frac1\mu=\frac1{m_1}+\frac1{m_2}$, i.e.
$\mu=\dfrac{m_1m_2}{m_1+m_2}$, this becomes
$$\mu\ddot{\vec r} = f(r)\hat r,$$
which is Newton's second law for a single fictitious particle of mass
$\mu$ at position $\vec r$, moving under the same central-force law
$f(r)\hat r$. Meanwhile, the earlier momentum-conservation result (theory
beat 1) says the center of mass $\vec R=\frac{m_1\vec r_1+m_2\vec
r_2}{m_1+m_2}$ moves at constant velocity, since there is no external
force. So the general two-body central-force problem splits exactly into
trivial free motion of $\vec R$ plus a genuine one-body problem for $\vec
r$ with mass $\mu$ — nothing is approximated; this is an exact algebraic
reduction.

*Why it matters for the hydrogen atom:* the proton (mass $m_p$) and
electron (mass $m_e$) interact via the Coulomb force, which depends only
on their separation — exactly the central-force setup just reduced. So the
two-body proton-electron problem becomes, exactly, a one-body problem for
a single particle of reduced mass $\mu=\dfrac{m_em_p}{m_e+m_p}\approx
0.9995\,m_e$ (since $m_p\gg m_e$) moving in the fixed Coulomb potential,
while the true center of mass drifts freely and can simply be ignored. Day
14 will use exactly this reduction to turn the two-body proton-electron
Coulomb problem into a one-body central-force problem with reduced mass
$\mu$, which is what makes the hydrogen atom solvable as a single-particle
Schrödinger equation rather than an intractable two-body one.

## Connection to QM

Every conserved quantity built today reappears in quantum mechanics as an
operator that commutes with the Hamiltonian $\hat H$ — momentum becomes
$\hat p$, angular momentum becomes $\hat L$, and "conserved" becomes
"commutes with $\hat H$, so its expectation value doesn't change in time."
The symmetry dictionary survives this transition essentially unchanged in
spirit: translational symmetry of $\hat H$ still means $\hat p$ commutes
with it, rotational symmetry still means $\hat L$ commutes with it, and
time-translation symmetry (a Hamiltonian with no explicit time dependence)
still means energy is conserved. What's new in the quantum theory is that
angular momentum, unlike its classical counterpart, is *quantized*: the
magnitude-squared operator $\hat L^2$ has eigenvalues
$\hbar^2\,\ell(\ell+1)$ and one component $\hat L_z$ has eigenvalues
$m_\ell\hbar$, for integer (or, for spin, half-integer) quantum numbers —
a discreteness with no classical analogue, but built directly on top of
the same $\vec L=\vec r\times\vec p$ and $[\hat L,\hat H]=0$ structure
introduced today.

The reduced-mass reduction from Exercise 5 is not a mere curiosity: it is
the exact tool that turns the hydrogen atom's two-body electron-proton
Coulomb problem into a solvable one-body Schrödinger equation in Day 14,
with the reduced mass $\mu\approx0.9995\,m_e$ appearing directly in the
formula for the hydrogen energy levels. Without today's algebraic
reduction, "solve the hydrogen atom" would mean solving an intractable
two-particle partial differential equation instead of the clean one-body
central-potential problem the course actually solves.
