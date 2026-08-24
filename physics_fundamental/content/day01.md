# Day 1 — Newton as Differential Equations

## Learning objectives

By the end of today you should be able to:
- Translate freely between kinematics language and ODE language: $v=\dot x$,
  $a=\dot v=\ddot x$, and read a position/velocity/acceleration graph as one
  consistent story.
- State Newton's three laws precisely, in words and as one equation each,
  including the second law as the ODE $m\ddot x = F(x,\dot x,t)$.
- Solve $m\ddot x = F$ by direct integration for a constant force, and use the
  result to derive the projectile range formula and the angle that maximizes
  it.
- Solve $m\dot v = mg-bv$ by separation of variables, deriving terminal
  velocity $v_{\mathrm{term}}=mg/b$ and the exponential-approach law
  $v(t)=v_{\mathrm{term}}(1-e^{-t/\tau})$, $\tau=m/b$.
- State the spring-force ODE $m\ddot x=-k_sx$, explain physically why it's a
  restoring force, and explain why solving it is deferred.
- Use dimensional analysis to check whether a proposed formula could possibly
  be right, and apply it to catch a genuine error.
- Explain why "no force" is not "no motion," and why heavier objects don't
  fall faster in vacuum but do reach higher terminal velocities in air.

Time budget: ~3 hours.

## Reference material

- Morin, *Introduction to Classical Mechanics*, Ch. 1–3 (kinematics, Newton's
  laws, one- and two-dimensional motion under a force), or
  Halliday/Resnick/Walker, *Fundamentals of Physics*, Ch. 2–3 and Ch. 5–6
  covering the same ground — either works as a second explanation in different
  words.
- This file is self-contained: every equation used below is derived or
  explicitly motivated from scratch; you don't need the reference text to do
  today's work.
- No prior days: this is Day 1 of the path, so there is nothing to build on
  yet — everything below is derived from scratch.

## Theory

### Kinematics as definitions, not laws

Before any physics enters the picture, position, velocity, and acceleration
are related by definitions, not by anything discovered in a lab. If $x(t)$
describes where an object is along one axis at time $t$, then **velocity** is
defined as its rate of change,
$$v(t) \;:=\; \frac{dx}{dt} \;=\; \dot x,$$
and **acceleration** is defined as the rate of change of velocity,
$$a(t) \;:=\; \frac{dv}{dt} \;=\; \dot v \;=\; \ddot x.$$
These are true by construction of the derivative — they hold for *any* motion
whatsoever, empty of physical content until a force law tells you what $x(t)$
actually is. The distinction matters: Newton's laws (next section) are genuine
empirical claims about the world; $v=\dot x$ and $a=\ddot x$ are not claims
about the world at all, just names for slopes.

The three graphs — $x$ vs. $t$, $v$ vs. $t$, $a$ vs. $t$ — are three views of
the same motion, related by the fundamental theorem of calculus in both
directions:
- **Differentiating** (slope-reading): the slope of the $x$-$t$ graph at any
  instant is the value of the $v$-$t$ graph at that instant; the slope of the
  $v$-$t$ graph is the value of the $a$-$t$ graph.
- **Integrating** (area-reading): the area under the $a$-$t$ graph between
  $t_1$ and $t_2$ equals $\Delta v = v(t_2)-v(t_1)$; the area under the
  $v$-$t$ graph over the same interval equals $\Delta x = x(t_2)-x(t_1)$.

Every derivation in today's file is just this idea applied to specific forces:
given $a(t)$ (from a force law and $F=ma$), integrate once for $v(t)$,
integrate again for $x(t)$.

### Newton's three laws, and the master ODE

**First law.** In an inertial reference frame, a body's velocity stays
constant — it neither speeds up, slows down, nor changes direction — unless a
nonzero *net* external force acts on it. As an equation: if $\sum \vec F = 0$,
then $\dot{\vec v}=0$, i.e., $\vec v(t)=\text{constant}$ (which includes, but
is not limited to, $\vec v=0$).

**Second law.** In an inertial frame, the net force on a body of mass $m$
determines its acceleration through
$$\vec F_{\text{net}} = m\vec a.$$
Restricting to one dimension and writing $a=\ddot x$, this becomes a statement
about $x(t)$ itself:
$$m\ddot x = F(x,\dot x,t).$$
This is a genuine ordinary differential equation: an equation relating a
function $x(t)$ to its own derivatives. Two initial conditions — a starting
position $x(0)$ and a starting velocity $\dot x(0)$ — are exactly enough to
pick out one solution (a second-order ODE needs two constants of integration;
this is why "position and velocity" is always the complete initial data for a
Newtonian system, never more, never less).

$$\boxed{\text{Classical mechanics is: given } F(x,v,t)\text{, solve } m\ddot{x}=F.}$$
Every topic in this path through Day 18 — projectiles, drag, springs, orbits,
oscillators, rigid bodies — is an instance of this one template. The physics
of a given system lives entirely in *choosing* the right $F$; once $F$ is
chosen, what remains is a (sometimes hard) mathematics problem: solve the
ODE. Day 1's real content is showing you three choices of $F$ simple enough
to solve by hand, so you feel the template working before it gets harder.

**Third law.** If body 1 exerts a force on body 2, body 2 exerts a force on
body 1 of equal magnitude and opposite direction:
$$\vec F_{1\to2} = -\vec F_{2\to1}.$$
This is what makes "force" a relationship between two bodies rather than a
property of one; it is also why internal forces inside an isolated system of
bodies always cancel in pairs when you sum forces over the whole system (a
fact you'll use to justify momentum conservation in a later day, though today
you only need the statement itself).

> **Misconception: "no force means no motion."** The first law says zero net
> force means zero *acceleration* — constant velocity — not zero velocity. An
> object already moving, with no net force acting on it (a puck on
> frictionless ice), keeps moving forever at the same speed in the same
> direction; it takes a force to change that motion, not to sustain it. The
> everyday intuition that "things stop unless you keep pushing" is really an
> observation about friction and drag (unbalanced forces that are always
> present in ordinary experience), not a statement about the absence of force.

**Building $F$: empirical force laws and constraints.** Not every force
that goes into $F(x,\dot x,t)$ comes from a fundamental law like gravity.
Two other ingredients recur constantly when you build a real $F$, and both
deserve names now, before you meet them in the worked examples below.
**Constraint forces**, like the normal force $N$ a surface exerts, are not
given by a formula in advance — their magnitude is whatever value makes some
other motion impossible (e.g. an object not passing through a rigid
surface), so you solve for $N$ from that requirement (typically, zero
acceleration perpendicular to the surface) rather than looking it up.
**Empirical force laws**, like the linear drag $F_{\text{drag}}=-bv$ already
used above, are rules fit to how a real material behaves rather than derived
from something more basic; **kinetic friction** is the same kind of rule —
once two surfaces slide against each other, experiment shows the friction
force has magnitude $f=\mu_kN$, proportional to the normal force pressing
the surfaces together and opposing the sliding, with $\mu_k$ (the
coefficient of kinetic friction) a measured material property, exactly the
same status as $b$ in the drag law. Finally, an **ideal string and pulley**
— massless, inextensible, frictionless — is a constraint idealization:
because the string is massless, $F=ma$ applied to any tiny piece of it
forces the tension $T$ to be the same all along its length (any imbalance on
a massless piece would produce infinite acceleration); because the string is
inextensible and wraps a fixed pulley, the two ends must move with equal
speed and the same acceleration magnitude, $|a_1|=|a_2|$. None of this
changes the day's thesis — it sharpens it. $F$ in $m\ddot x=F$ is rarely one
clean formula read off a table; it is often assembled from constraint
conditions, experimental rules, and idealizations like these, exactly as
Worked Example 3 and Exercise 4 below do.

### Constant force: integrating twice, and projectile motion

The simplest force law is a constant, $F(x,\dot x,t) = F_0$: independent of
position, velocity, and time. Newton's second law becomes
$$m\ddot x = F_0 \quad\Longrightarrow\quad \ddot x = \frac{F_0}{m} \equiv a_0 \text{ (constant)}.$$
Integrate once ($\ddot x = \dot v$, so this is $\dot v = a_0$):
$$v(t) = v_0 + a_0 t,$$
where $v_0 := v(0)$ is the constant of integration, fixed by the initial
velocity. Integrate again ($\dot x = v(t)$ just found):
$$x(t) = x_0 + v_0 t + \tfrac12 a_0 t^2,$$
where $x_0 := x(0)$. These are the familiar constant-acceleration formulas —
derived here, not assumed, as the direct consequence of integrating $m\ddot x
= F_0$ twice.

**Projectile motion as two independent ODEs.** Launch a projectile and neglect
air resistance. Gravity acts only in the vertical ($y$) direction, with
constant magnitude $mg$ pointing down, and there is no horizontal force at
all. Crucially, the force in each direction depends on neither the position
nor the velocity in the *other* direction, so the two-dimensional problem
splits into two completely independent one-dimensional constant-force
problems:
$$m\ddot x = 0, \qquad m\ddot y = -mg.$$
With launch speed $v_0$ at angle $\theta$ above horizontal, from $x_0=y_0=0$,
the two solutions from above (with $a_0=0$ horizontally, $a_0=-g$ vertically)
are
$$x(t) = v_0\cos\theta\, t, \qquad y(t) = v_0\sin\theta\, t - \tfrac12 g t^2.$$

**Time of flight and range.** The projectile lands when $y=0$ again (for a
launch and landing at the same height):
$$0 = v_0\sin\theta\, t\left(1 - \frac{g t}{2v_0\sin\theta}\right) \quad\Longrightarrow\quad t=0 \ \text{ or } \ t_{\text{flight}} = \frac{2v_0\sin\theta}{g}.$$
The nonzero root is the time of flight. Substituting into $x(t)$ gives the
**range**:
$$R = x(t_{\text{flight}}) = v_0\cos\theta \cdot \frac{2v_0\sin\theta}{g} = \frac{v_0^2 \cdot 2\sin\theta\cos\theta}{g} = \frac{v_0^2\sin(2\theta)}{g},$$
using the double-angle identity $2\sin\theta\cos\theta = \sin(2\theta)$. This
range formula is derived — not quoted — from nothing but $m\ddot x=F$ applied
twice.

**Why heavier objects don't fall faster in vacuum.** For a falling body with
gravity as the only force, $mg = ma \Rightarrow a=g$: the mass cancels, so
*every* object has the same acceleration $g$ regardless of how heavy it is.
This is Galileo's result, recovered here as a one-line consequence of Newton's
second law rather than an independent empirical fact. Hold onto this — the
next section shows exactly where it stops being true.

### Linear drag: terminal velocity and the exponential approach

Add air resistance to a falling body, modeled (for objects that are small,
slow, or moving through a viscous medium) as a drag force proportional to
speed and opposing the motion. Taking downward as positive, with gravity $mg$
down and drag $bv$ up (opposing the downward motion), Newton's second law
gives
$$m\dot v = mg - bv.$$
This is no longer a constant-force equation — the right side depends on $v$
itself — so integrating twice won't work directly. Instead, solve it by
**separation of variables**: collect all the $v$-dependence on one side, all
the $t$-dependence on the other,
$$\frac{dv}{mg-bv} = \frac{dt}{m}.$$
Substitute $u = mg-bv$, so $du = -b\,dv$, i.e. $dv = -du/b$:
$$\int \frac{-du/b}{u} = \int \frac{dt}{m} \quad\Longrightarrow\quad -\frac{1}{b}\ln|u| = \frac{t}{m} + C.$$
So $\ln|mg-bv| = -\dfrac{bt}{m} + C'$, and exponentiating,
$$mg - bv = A\,e^{-bt/m},$$
for some constant $A$. Dropped from rest, $v(0)=0$, fixes $A = mg$. Solving
for $v$:
$$v(t) = \frac{mg}{b}\left(1 - e^{-bt/m}\right).$$
Two named quantities fall out of this. First, the **terminal velocity**
$v_{\mathrm{term}}$ — the value $v$ approaches as $t\to\infty$, when the
exponential has died away — read directly off the formula, or equivalently
found by setting $\dot v = 0$ in the original ODE ($0 = mg -
bv_{\mathrm{term}}$):
$$v_{\mathrm{term}} = \frac{mg}{b}.$$
Second, the **time constant** $\tau := m/b$, the natural time scale of the
exponential. Writing the solution in terms of both:
$$\boxed{v(t) = v_{\mathrm{term}}\left(1-e^{-t/\tau}\right), \qquad \tau = \frac{m}{b}.}$$
This is the **exponential-approach** pattern: a quantity climbs from $0$
toward an asymptote $v_{\mathrm{term}}$, closing $1-e^{-1}\approx 63\%$ of
the total gap to $v_{\mathrm{term}}$ by $t=\tau$, and $1-e^{-3}\approx 95\%$
of that same total gap by $t=3\tau$, and never (in the model) exactly
reaching the asymptote. You will see this exact
shape again — with different letters — throughout the rest of physics; today
it enters via air drag.

> **Misconception: "heavier objects fall faster."** In vacuum, they don't —
> the section above showed $a=g$ regardless of mass. What actually depends on
> mass is $v_{\mathrm{term}}=mg/b$: for two objects of the *same size and
> shape* (hence the same drag coefficient $b$) but different mass, the heavier
> one has a larger terminal velocity and so, dropped from a modest height
> where both are still well below $v_{\mathrm{term}}$, reaches the ground
> sooner. The everyday observation ("a rock falls faster than a feather") is a
> fact about drag relative to weight — governed by $b$ versus $mg$ — not a
> fact about gravity treating heavier objects differently. Drop both in a
> vacuum chamber and they land together.

### Spring force preview: the ODE that gets its own day

One more force law, stated but not yet solved. A spring (or, more generally,
any restoring force near a stable equilibrium) pulls back toward equilibrium
with a force proportional in magnitude to the displacement from it: if $x$
measures displacement from equilibrium, the force is $F=-k_sx$ for some
positive constant $k_s$ (the spring constant) — the minus sign encoding
"restoring": positive displacement produces a force in the negative direction,
and vice versa. Newton's second law gives
$$m\ddot x = -k_s x.$$
Notice this doesn't fit either trick used so far: it isn't constant (so
integrating twice directly doesn't work — the right side depends on $x$, which
is the very thing we're solving for), and it doesn't separate the way the drag
equation did — not as a first-order equation in $v$ alone, though an energy
trick exists that Day 2 hints at (the right side depends on $x$, not on
$\dot x$, so there's no clean substitution turning it into a first-order
equation in one variable the way $m\dot v = mg-bv$ was first-order in $v$).
Solving it requires a different
technique — guessing a functional form and checking it — that deserves its own
careful treatment. This equation is arguably the single most important ODE in
physics: harmonic oscillators show up in mechanical springs, pendulums
(approximately), electrical circuits, sound, light, and — as you'll meet later
in the QM course — the quantum harmonic oscillator. It gets its own day (Day
3).

### Dimensional analysis as a checking habit

Every physical quantity carries dimensions built from a small set of base
dimensions — for mechanics, mass ($M$), length ($L$), and time ($T$). A
velocity has dimension $LT^{-1}$, an acceleration $LT^{-2}$, a force (via
$F=ma$) $MLT^{-2}$. Any equation that claims to relate physical quantities
must have *matching* dimensions on both sides — you cannot equate a length to
a velocity, no matter what the algebra says, because "length" and "velocity"
are not comparable things. This gives a cheap, purely mechanical check on any
formula you derive or recall: work out the dimensions of both sides
independently, and see if they agree.

**Worked micro-example.** Check the range formula derived above, $R =
v_0^2\sin(2\theta)/g$. The left side, a range, has dimension $L$. On the
right: $[v_0^2] = L^2T^{-2}$, $\sin(2\theta)$ is a pure number (dimensionless,
since angles are dimensionless), and $[g] = LT^{-2}$. So
$$\left[\frac{v_0^2\sin(2\theta)}{g}\right] = \frac{L^2T^{-2}}{LT^{-2}} = L,$$
which matches the left side. The formula passes the check (it does not *prove*
the formula correct — a dimensionless numerical factor like $2$ or $\tfrac12$
could still be wrong and dimensional analysis would never catch it — but any
formula that *fails* this check is guaranteed wrong, and that is most of what
the habit is for).

**The habit:** after deriving or recalling any formula, before trusting it,
spend ten seconds checking that both sides have the same dimensions. It costs
almost nothing and catches a large fraction of algebra slips — a dropped mass,
an inverted ratio, a $g$ that should have been $g^2$ — for free.

## Worked examples

**1. Projectile launched at an angle: time of flight, range, and the optimal
angle.** A ball is launched from ground level at speed $v_0=20\text{ m/s}$ at
angle $\theta=30^\circ$ above horizontal ($g=9.8\text{ m/s}^2$). Find the time
of flight, the range, and the angle (for the same $v_0$) that maximizes range.

*Solution.* From the theory section, $t_{\text{flight}} = 2v_0\sin\theta/g$
and $R = v_0^2\sin(2\theta)/g$. Numerically:
$$t_{\text{flight}} = \frac{2(20)(\sin 30^\circ)}{9.8} = \frac{2(20)(0.5)}{9.8} = \frac{20}{9.8} \approx 2.04\text{ s}.$$
$$R = \frac{(20)^2\sin(60^\circ)}{9.8} = \frac{400(0.8660)}{9.8} = \frac{346.4}{9.8} \approx 35.3\text{ m}.$$
(Check via $x(t_{\text{flight}})=v_0\cos\theta\,t_{\text{flight}} =
20(0.8660)(2.04)\approx 35.3\text{ m}$ — matches.)

To maximize $R(\theta) = v_0^2\sin(2\theta)/g$ over $\theta$ for fixed $v_0$,
differentiate and set to zero:
$$\frac{dR}{d\theta} = \frac{2v_0^2\cos(2\theta)}{g} = 0 \quad\Longrightarrow\quad \cos(2\theta)=0 \quad\Longrightarrow\quad 2\theta = 90^\circ \quad\Longrightarrow\quad \theta = 45^\circ.$$
At $\theta=45^\circ$, $\sin(2\theta)=\sin 90^\circ = 1$, its maximum possible
value, confirming this is a maximum (not just a critical point):
$$R_{\max} = \frac{v_0^2}{g} = \frac{400}{9.8} \approx 40.8\text{ m}.$$

**2. Raindrop with linear drag: terminal velocity, time constant, and the
shape of $v(t)$.** A small raindrop of mass $m=5\times10^{-6}\text{ kg}$ falls
from rest with a linear drag coefficient $b=5\times10^{-6}\text{ kg/s}$. Find
$v_{\mathrm{term}}$ and $\tau$, and evaluate $v(t)$ at $t=\tau$ and $t=3\tau$.

*Solution.*
$$v_{\mathrm{term}} = \frac{mg}{b} = \frac{(5\times10^{-6})(9.8)}{5\times10^{-6}} = 9.8\text{ m/s}, \qquad \tau = \frac{m}{b} = \frac{5\times10^{-6}}{5\times10^{-6}} = 1\text{ s}.$$
(These numbers were chosen to make the arithmetic clean; a real millimetre-
scale raindrop is actually in the quadratic-drag regime, which you'll meet
in Exercise 5, not this linear one — and note the identity
$v_{\mathrm{term}} = g\tau$, itself dimensionally consistent: $[g][\tau] =
(LT^{-2})(T) = LT^{-1}$, a velocity.) So $v(t) = 9.8\,(1-e^{-t})$ m/s with $t$
in seconds. At $t=\tau=1\text{ s}$:
$$v(1) = 9.8(1-e^{-1}) = 9.8(1-0.368) = 9.8(0.632) \approx 6.2\text{ m/s} \quad (63\% \text{ of terminal}),$$
and at $t=3\tau=3\text{ s}$:
$$v(3) = 9.8(1-e^{-3}) = 9.8(1-0.0498) \approx 9.3\text{ m/s} \quad (95\% \text{ of terminal}).$$
Sketch: the curve starts at $v=0$ with its steepest slope (equal to $g$, since
at $t=0$ the drag term $bv/m$ vanishes and the raindrop is momentarily in free
fall), bends over as drag grows with speed, passes through $6.2$ m/s at $t=1$
s, $9.3$ m/s at $t=3$ s, and flattens out asymptotically toward the horizontal
line $v=9.8$ m/s, never quite reaching it.

**3. Block on an incline with kinetic friction: solving the ODE for $v(t)$.**
A block is released from rest on an incline at angle $\phi=30^\circ$ with
coefficient of kinetic friction $\mu_k=0.2$. Find $v(t)$ while sliding, and
the speed after $2\text{ s}$.

*Solution.* Set up an axis along the incline, positive pointing down-slope.
Perpendicular to the incline the block has no acceleration, so the normal
force balances the perpendicular component of gravity: $N = mg\cos\phi$.
Kinetic friction has magnitude $\mu_k N = \mu_k mg\cos\phi$ and opposes the
motion — since the block slides down-slope, friction points up-slope. Newton's
second law along the incline:
$$m\dot v = mg\sin\phi - \mu_k mg\cos\phi = mg(\sin\phi - \mu_k\cos\phi).$$
The mass cancels, leaving a **constant** acceleration $a =
g(\sin\phi-\mu_k\cos\phi)$ — this is exactly the constant-force case from the
theory section, just with a force law built from two pieces instead of one.
(This is the condition for the block to keep accelerating once already
sliding, not a statement about whether static friction lets it start moving
in the first place: $\tan\phi > \mu_k$ means gravity's pull down-slope
exceeds what kinetic friction can supply, so the block keeps speeding up
rather than slowing down; check: $\tan 30^\circ = 0.577 > 0.2$, consistent
with the acceleration assumed here.) Integrating once, with $v(0)=0$:
$$v(t) = a\,t, \qquad a = g(\sin\phi-\mu_k\cos\phi) = 9.8\big(0.5 - 0.2(0.866)\big) = 9.8(0.5-0.1732) = 9.8(0.3268) \approx 3.203\text{ m/s}^2.$$
After $t=2\text{ s}$: $v(2) = 3.203 \times 2 \approx 6.41\text{ m/s}$.

## Exercises

Attempt every problem closed-book before checking the Hints, and only then the
Solutions.

**Retrieval**

1. State Newton's three laws, each as one sentence in your own words followed
   by one equation.
2. A student, working from $m\dot v = mg - bv$, proposes that terminal
   velocity is $v_{\mathrm{term}} = mgb$ (rather than $mg/b$). Use dimensional
   analysis (you will need the dimension of $b$, obtainable from
   $F_{\text{drag}}=bv$) to show this cannot be right, and state what the
   correct dimensional combination of $m$, $g$, $b$ must be.

**Standard**

3. A particle of mass $m=1\text{ kg}$, moving horizontally, starts at rest
   and is pushed by a constant thrust $F=10\text{ N}$ for $t_1=2\text{ s}$
   (no drag during this stage). At $t=t_1$ the thrust cuts off, and from
   then on the only force is linear drag, $m\dot v=-bv$, with
   $b=0.5\text{ kg/s}$. Find $v(t)$ in both stages, the speed at
   $t=4\text{ s}$, and the total distance traveled by $t=4\text{ s}$.
4. An Atwood machine has two masses, $m_1=2\text{ kg}$ and $m_2=3\text{ kg}$,
   connected by a massless, inextensible string over a massless, frictionless
   pulley ($g=9.8\text{ m/s}^2$). Using $F=ma$ on each mass separately, find
   the common acceleration magnitude $a$ and the string tension $T$.

**Stretch**

5. A different drag law is quadratic in speed: $m\dot v = -cv^2$ (no gravity
   term — think of a puck sliding on a surface with quadratic air resistance
   and no other forces). Starting from speed $v_0$ at $t=0$, solve for $v(t)$
   by separation of variables, and contrast its long-time behavior with the
   exponential decay of linear drag.

## Hints

1. Go back to the three statements in Theory (first law, second law as $F=ma$,
   third law); restate each in your own words, then attach the one equation
   each already carries — don't derive anything new.
2. Work out the dimension of $b$ from $F=bv$ (force divided by velocity), then
   combine the dimensions of $m$, $g$, $b$ in the proposed formula and compare
   to the dimension of a velocity.
3. Stage 1 is the constant-force integration from Theory (find $v_1=v(t_1)$
   and the distance covered). Stage 2 is the same separation-of-variables
   method used for the raindrop, but with the gravity term simply absent —
   solve $m\dot v=-bv$ from initial speed $v_1$.
4. Draw a free-body diagram for each mass on its own and write Newton's
   second law for each mass separately (the ideal-string discussion in
   Theory tells you both masses share the same tension $T$ and the same
   acceleration magnitude $a$; careful with signs — one mass accelerates up,
   the other down). You now have two equations in the two unknowns $a$ and
   $T$.
5. Separate variables the same way as the linear-drag derivation, but note
   $\int v^{-2}\,dv$ is a power, not a logarithm. Solve fully for $v(t)$
   before comparing how it behaves at large $t$ to
   $v_{\mathrm{term}}(1-e^{-t/\tau})$'s approach.

## Solutions

**1.** *First law:* a body's velocity stays constant unless a net force acts
       on it. $\sum\vec F = 0 \Rightarrow \dot{\vec v}=0$. *Second law:* net
       force equals mass times acceleration. $\vec F_{\text{net}}=m\vec a$
       (equivalently $m\ddot x = F$). *Third law:* forces between two bodies
       come in equal-and-opposite pairs. $\vec F_{1\to2} = -\vec F_{2\to1}$.

**2.** From $F_{\text{drag}} = bv$, $[b] = [F]/[v] = (MLT^{-2})/(LT^{-1}) =
       MT^{-1}$ (consistent with SI units of kg/s). The proposed formula's
       dimension:
$$[mgb] = M \cdot (LT^{-2}) \cdot (MT^{-1}) = M^2LT^{-3},$$
which is not $LT^{-1}$ (velocity) — the formula is dimensionally impossible,
independent of any numerical factor, so it must be wrong. Checking the actual
formula, $[mg/b] = (M\cdot LT^{-2})/(MT^{-1}) = LT^{-1}$, a velocity — the
correct structure divides by $b$, it does not multiply by it. (This matches
$v_{\mathrm{term}}=mg/b$ derived in Theory.)

**3.** *Stage 1* (constant force, no drag): $a_1 = F/m = 10/1 = 10\text{
       m/s}^2$. $v(t)=a_1t$ for $0\le t\le t_1$; at $t_1=2\text{ s}$, $v_1 =
       10(2)=20\text{ m/s}$. Distance covered: $x_1 = \tfrac12 a_1 t_1^2 =
       \tfrac12(10)(4) = 20\text{ m}$.

*Stage 2* (drag only, starting from $v_1$ at $t_1$): this is the same
separation-of-variables ODE as the raindrop but with no $mg$ source term,
$m\dot v = -bv$. Separating: $dv/v = -(b/m)\,dt$, so $\ln v = -(b/m)(t-t_1) +
C$, and with $v(t_1)=v_1$:
$$v(t) = v_1\,e^{-(t-t_1)/\tau}, \qquad \tau = m/b = 1/0.5 = 2\text{ s}.$$
At $t=4\text{ s}$ (i.e. $\Delta t = t-t_1 = 2\text{ s} = \tau$): $v(4) =
20\,e^{-1} \approx 7.36\text{ m/s}$.

Distance in stage 2: $x_{\text{coast}} = \int_0^{\Delta t} v_1
e^{-t'/\tau}\,dt' = v_1\tau\left(1-e^{-\Delta t/\tau}\right) = 20(2)(1-e^{-1})
= 40(0.632) \approx 25.3\text{ m}$.

Total distance by $t=4\text{ s}$: $x_1 + x_{\text{coast}} \approx 20 + 25.3 =
45.3\text{ m}$.

**4.** Take $m_2>m_1$, so $m_2$ accelerates downward and $m_1$ upward, both
       with the same magnitude $a$, connected by tension $T$ (same on both
       sides — massless, frictionless pulley and massless string). $F=ma$ on
       each mass, taking each mass's direction of motion as positive for that
       mass:
$$m_2g - T = m_2a \qquad (m_2\text{, moving down}),$$
$$T - m_1g = m_1a \qquad (m_1\text{, moving up}).$$
Adding the two equations eliminates $T$:
$$m_2g - m_1g = (m_1+m_2)a \quad\Longrightarrow\quad a = \frac{(m_2-m_1)g}{m_1+m_2} = \frac{(3-2)(9.8)}{5} = \frac{9.8}{5} \approx 1.96\text{ m/s}^2.$$
Substituting back into the $m_1$ equation: $T = m_1(a+g) = 2(1.96+9.8) =
2(11.76) \approx 23.5\text{ N}$. (Check with the $m_2$ equation:
$T=m_2(g-a)=3(9.8-1.96)=3(7.84)\approx 23.5\text{ N}$ — consistent.)

**5.** Separate variables: $dv/v^2 = -(c/m)\,dt$. Integrating ($\int v^{-2}dv
       = -1/v$):
$$-\frac{1}{v} = -\frac{c}{m}t + C.$$
At $t=0$, $v=v_0$: $C=-1/v_0$. So $\dfrac{1}{v} = \dfrac{c}{m}t +
\dfrac{1}{v_0}$, giving
$$v(t) = \frac{v_0}{1 + \dfrac{cv_0}{m}t}.$$
At large $t$, the $1$ in the denominator becomes negligible and $v(t) \approx
\dfrac{m}{ct}$ — a **power-law ($1/t$) decay**, in contrast to linear drag's
**exponential approach** to a nonzero asymptote,
$v_{\mathrm{term}}(1-e^{-t/\tau})$ (or, in a no-source-term case like
Exercise 3's coast phase, an **exponential decay** to zero,
$v=v_0e^{-t/\tau}$). Either way, an exponential eventually falls below any power law no
matter how the constants are chosen, so quadratic drag leaves a much longer
"tail" of slow residual motion than linear drag does. A second contrast: the
quadratic-drag time scale, read off as $t^* = m/(cv_0)$ (where the denominator
equals $2$, i.e. $v=v_0/2$), depends on the initial speed $v_0$ itself,
whereas the linear-drag time constant $\tau=m/b$ does not depend on how fast
the motion started — a qualitative difference between the two drag laws, not
just a difference in decay shape.

## Connection to QM

Today's real content is the template, not any one force law: $F=ma$ is the
dynamical rule of classical mechanics — given the force built from the
physical setup, you solve an ODE for the trajectory $x(t)$. The QM course
you're heading toward fills the exact same logical slot with the Schrödinger
equation, $i\hbar\,\partial\psi/\partial t = \hat H\psi$ (or, once time is
separated out, the time-independent form $\hat H\psi = E\psi$): given the
potential energy $V(x)$ that defines the Hamiltonian $\hat H$, you solve this
equation for the allowed wavefunctions and energies. "Given $F$, solve for
$x(t)$" becomes "given $V(x)$, solve for $\psi$" — the same template, a
different unknown, a different equation, but the same intellectual move of
choosing the physics (the force, or the potential) and then doing the
mathematics (solving the ODE, or its quantum analogue).

The exponential-approach pattern from linear drag is not a one-off either. The
same shape — a quantity relaxing exponentially toward, or away from, some
reference value, governed by a single time constant — recurs across physics:
radioactive decay, RC circuits, and, later in the QM course, the decay of
unstable quantum states and the factor $e^{-iEt/\hbar}$ that falls directly
out of separating the time-dependent Schrödinger equation. Recognizing "this
is the exponential-approach shape again" will save real derivation time later.

Finally, the dimensional-analysis habit built today on the range formula
transfers unchanged: checking that a computed energy, probability, or
normalization has the right units is exactly the discipline practiced here,
and it remains one of the fastest ways to catch a dropped factor of $\hbar$,
$m$, or $c$ in a quantum calculation before trusting the result.
