# Day 9 — Action and the Lagrangian

## Learning objectives

By the end of today you should be able to:
- State the principle of stationary action, $S[q]=\int_{t_1}^{t_2}L\,dt$
  as a number assigned to an entire path $q(t)$, and explain why "least
  action" is an informal (and sometimes wrong) nickname for a
  *stationarity* condition.
- Derive the Euler–Lagrange equation $\frac{d}{dt}\frac{\partial
  L}{\partial\dot q}=\frac{\partial L}{\partial q}$ from $\delta S=0$ via
  $q\to q+\epsilon\eta$, integration by parts, and fixed endpoints —
  reproducing every step without looking it up.
- Justify $L=T-V$ by showing Euler–Lagrange applied to $L=\tfrac12 m\dot
  x^2-V(x)$ reproduces Newton's second law exactly.
- Apply Euler–Lagrange to the free particle, the harmonic oscillator, and
  the pendulum in $\theta$, obtaining its exact equation of motion with
  zero force decomposition.
- Choose generalized coordinates that make a mechanical constraint
  disappear, carried through fully on one system (a bead on a driven,
  rotating rod).
- State and prove, in two lines from Euler–Lagrange, that a cyclic
  coordinate's conjugate momentum $p=\partial L/\partial\dot q$ is
  conserved, and connect this to Day 4's symmetry-conservation dictionary.

Time budget: ~3.5 hours.

## Reference material

- Morin, *Introduction to Classical Mechanics* — the chapter introducing
  the Lagrangian method (action, Euler–Lagrange, worked constrained
  systems) covers today's material in the same spirit, with more worked
  problems than we have room for.
- Taylor, *Classical Mechanics* — the Lagrangian-mechanics chapter is the
  standard reference for today's exact beats, and a good source of
  further practice in the style of today's Atwood and wedge examples.
- Landau & Lifshitz, *Mechanics* — the opening chapter derives the same
  material from a more austere, symmetry-first starting point (deriving
  the *form* of $L$ from homogeneity of space and time, rather than
  positing $L=T-V$ and checking consequences); an advanced pointer, not
  needed today.
- Self-contained: every equation below is derived from stationarity of
  the action or a prior result. Builds on Day 1 ($m\ddot x=F$), Day 2
  ($F=-dV/dx$), Day 3 ($\ddot x=-\omega_0^2x$), Day 4 (symmetry $\to$
  conserved quantity).

## Theory

### Why reformulate mechanics at all

Newton's second law is a vector equation. That's fine for a free particle
or a falling ball, but it gets clumsy once *constraints* enter: a bead on
a wire, a block on a wedge, a pendulum bob on a rigid rod. In each case
some of the force is a **constraint force** (a normal force, a tension)
whose only job is to keep the object on the allowed path — it does no
work and you usually don't care about its value, yet Newton's law forces
you to introduce it, solve for it, and eliminate it algebraically.

The Lagrangian method sidesteps this. It works with a single **scalar**
function of the coordinates and their time derivatives, in *any*
convenient coordinates that respect the constraints automatically — an
angle instead of $(x,y)$ — so constraint forces doing no work never need
to be written down. That is today's payoff, demonstrated below. A second
reason this day exists: the **Lagrangian** is also the object Feynman
later showed sits underneath quantum mechanics (today's closing section
says how), and is built, tomorrow, into the Hamiltonian this course
revolves around.

**Notation flag, binding for Days 9–11.** From here through Day 11, $T$
denotes **kinetic energy** (elsewhere, $K$), and $L$ denotes the
**Lagrangian** (on Day 4, $L$ denoted angular momentum — a genuine
collision; angular momentum below will be named in words instead). The
script letter used for the Lagrangian in other texts is never used here,
and there is no dedicated period symbol — periods are written $2\pi/
\omega$, as in earlier days.

### The action: a number assigned to a whole path

Consider a system described by one generalized coordinate $q(t)$ (position,
angle, arc length — whatever is convenient), and a function $L(q,\dot
q,t)$ built from it, called the **Lagrangian**. Given any candidate path
$q(t)$ running from a fixed value $q(t_1)=q_1$ to a fixed value
$q(t_2)=q_2$, define the **action**
$$S[q] = \int_{t_1}^{t_2} L\big(q(t),\dot q(t),t\big)\,dt.$$
$S$ is not a function of a number — it is a **functional**: feed it an
entire path $q(t)$ on $[t_1,t_2]$, and it returns a single real number,
generally different for different candidate paths between the same
endpoints.

The **principle of stationary action** states: the path nature actually
takes is the one for which $S$ is *stationary* under small variations of
the path with endpoints fixed, i.e. $\delta S=0$ to first order in any
small deformation of $q(t)$ — often called "least action" (see below).

> **Misconception:** "nature minimizes the action." In general it does
> not — it makes the action *stationary*, exactly the way a vanishing
> derivative does not mean a minimum (it could be a maximum or a saddle).
> Over short time intervals the classical path below usually is a
> minimum, which is why the nickname stuck, but longer intervals can
> produce genuinely saddle-point stationary paths (a pendulum swinging
> longer than half a period can have a second, non-minimizing
> stationary path between the same endpoints). The statement the
> derivation below actually proves is $\delta S=0$ — stationarity, not
> minimality.

### The Euler–Lagrange equation, derived carefully

This is the day's one hard derivation; every step is shown. Let $q(t)$
be the true path, the one making $S$ stationary. Consider a
nearby *comparison* path
$$q(t) \;\to\; q(t) + \epsilon\,\eta(t),$$
where $\epsilon$ is a small real parameter and $\eta(t)$ is an arbitrary
smooth function satisfying $\eta(t_1)=\eta(t_2)=0$ — the endpoints are
held fixed, so every comparison path starts and ends exactly where the
true path does; $\eta$ is otherwise completely free. The corresponding
velocity changes to $\dot q(t)+\epsilon\dot\eta(t)$.

Plugging the shifted path into the action and Taylor-expanding $L$ to
first order in the small parameter $\epsilon$ (using the ordinary
multivariable chain rule on $L(q,\dot q,t)$, treating $q$ and $\dot q$ as
the two arguments being shifted):
$$L\big(q+\epsilon\eta,\ \dot q+\epsilon\dot\eta,\ t\big) =
L(q,\dot q,t) + \epsilon\left(\frac{\partial L}{\partial q}\,\eta +
\frac{\partial L}{\partial\dot q}\,\dot\eta\right) + O(\epsilon^2).$$
Integrating over $[t_1,t_2]$ and differentiating with respect to
$\epsilon$ at $\epsilon=0$ gives the **first variation** of the action:
$$\delta S := \left.\frac{d}{d\epsilon}S[q+\epsilon\eta]\right|_{\epsilon=0}
= \int_{t_1}^{t_2}\left(\frac{\partial L}{\partial q}\,\eta +
\frac{\partial L}{\partial\dot q}\,\dot\eta\right)dt.$$

The second term still has $\dot\eta$ in it, not $\eta$, so it can't yet be
compared with the first term. Fix this with **integration by parts** on
that term alone:
$$\int_{t_1}^{t_2}\frac{\partial L}{\partial\dot q}\,\dot\eta\,dt =
\left[\frac{\partial L}{\partial\dot q}\,\eta\right]_{t_1}^{t_2} -
\int_{t_1}^{t_2}\frac{d}{dt}\!\left(\frac{\partial L}{\partial\dot q}
\right)\eta\,dt.$$
The boundary term vanishes identically, because $\eta(t_1)=\eta(t_2)=0$
by construction (this is *exactly* why the endpoints were held fixed —
without that condition this boundary term would survive and the argument
below would not go through). What's left is
$$\delta S = \int_{t_1}^{t_2}\left(\frac{\partial L}{\partial q} -
\frac{d}{dt}\frac{\partial L}{\partial\dot q}\right)\eta(t)\,dt.$$

Now impose the actual physical condition: the true path makes $S$
stationary against *every* admissible variation, so $\delta S=0$ for
*every* smooth $\eta(t)$ vanishing at the endpoints — not one particular
choice, all of them. Write $f(t) := \partial L/\partial q -
\frac{d}{dt}(\partial L/\partial\dot q)$, so the condition reads
$\int_{t_1}^{t_2}f(t)\eta(t)\,dt = 0$ for every such $\eta$. This forces
$f(t)\equiv0$ on the whole interval (the **fundamental lemma of the
calculus of variations**): if $f(t_0)\ne0$ at some interior point, choose
$\eta$ to be a smooth bump function, positive and sharply peaked at
$t_0$, zero elsewhere and at the endpoints — then the integral is
dominated by the region near $t_0$ and comes out nonzero, a
contradiction. So $f(t)=0$ at every point, i.e.
$$\boxed{\ \frac{d}{dt}\frac{\partial L}{\partial\dot q} =
\frac{\partial L}{\partial q}\ }$$
the **Euler–Lagrange equation**. This is the master equation for the rest
of today, and it holds for *any* Lagrangian $L(q,\dot q,t)$, not just the
specific ones ($T-V$) considered below. If a system has several
independent generalized coordinates $q_1,\dots,q_n$, running the identical
argument with independent variations $\eta_i(t)$ of each coordinate in
turn gives one such equation *per coordinate*,
$\frac{d}{dt}\frac{\partial L}{\partial\dot q_i} = \frac{\partial
L}{\partial q_i}$ for every $i$ — used below in the two-coordinate wedge
example.

### $L=T-V$: justified by recovering Newton

The Euler–Lagrange equation says nothing yet about what $L$ *is* for a
mechanical system — that has to be supplied as a further physical
ingredient. The standard choice, for a system with kinetic energy $T$ and
potential energy $V(q)$, is
$$L = T - V.$$
Be honest about the logical status of this choice: we are *not* deriving
$L=T-V$ from something deeper today (Landau & Lifshitz, cited above, is
where that deeper derivation from symmetry principles lives). We are
*positing* it and checking that the consequence is right — and the check
is immediate. For one particle in one dimension, $T=\tfrac12m\dot x^2$
and $V=V(x)$, so
$$L = \tfrac12 m\dot x^2 - V(x).$$
Compute the two pieces of the Euler–Lagrange equation:
$$\frac{\partial L}{\partial\dot x} = m\dot x
\quad\Longrightarrow\quad
\frac{d}{dt}\frac{\partial L}{\partial\dot x} = m\ddot x,
\qquad\qquad
\frac{\partial L}{\partial x} = -\frac{dV}{dx}.$$
The Euler–Lagrange equation then reads
$$m\ddot x = -\frac{dV}{dx},$$
which is exactly Day 1's Newton's second law $m\ddot x = F$ combined with
Day 2's $F=-dV/dx$. $L=T-V$ reproduces Newtonian mechanics *exactly*, for
every potential-derived force — that agreement, checked here and reused
in every application below, is the entire justification offered today.

> **Misconception:** "the Lagrangian is the total energy." It is not:
> $L=T-V$, not $T+V$. $T+V$ is the energy, conserved for time-independent
> $L$ (Day 4's dictionary); $T-V$ is the different object whose
> stationarity *generates the equations of motion* in the first place.
> Tomorrow's Hamiltonian, built from $L$ by a Legendre transform, *is*
> essentially the energy — why $T-V$ is the right object to vary, and
> how the transform to $T+V$ works, is Day 10's whole content.

### Three applications, in increasing slickness

**Free particle.** $L=\tfrac12m\dot x^2$ (no potential). $\partial
L/\partial\dot x=m\dot x$, so $\frac{d}{dt}(m\dot x)=m\ddot x$; and
$\partial L/\partial x=0$. Euler–Lagrange: $m\ddot x=0$, i.e. $\ddot x=0$
— constant velocity. The same argument runs separately for each Cartesian
component ($x$, $y$, $z$ each get their own independent copy of this
one-line result), which is exactly what "a straight line in space" means:
trivial, but a clean check that the machinery does nothing more than it
should when there's nothing for it to do.

**Harmonic oscillator (recovering Day 3).** $L=\tfrac12m\dot
x^2-\tfrac12k_sx^2$, with $k_s$ the spring constant (the subscript avoids
the wave-number collision established on earlier days). $\partial
L/\partial\dot x=m\dot x\Rightarrow\frac{d}{dt}(\cdot)=m\ddot x$; $\partial
L/\partial x=-k_sx$. Euler–Lagrange: $m\ddot x=-k_sx$, i.e.
$$\ddot x = -\frac{k_s}{m}x = -\omega_0^2 x, \qquad
\omega_0=\sqrt{k_s/m},$$
exactly Day 3's simple harmonic motion with exactly Day 3's natural
frequency — the two routes are forced to agree, since $L=T-V$ was built
to reproduce Newton's law, but it's worth seeing that agreement play out
before trusting the method somewhere the Newtonian route is painful.

**Pendulum in $\theta$ — the payoff.** A bob of mass $m$ swings on a
massless rigid rod of length $l$, pivoted at a fixed point. Rather than
Cartesian $(x,y)$ with the rod's tension as an unknown constraint force,
use the angle $\theta$ from the vertical as the single generalized
coordinate — a choice that makes the constraint "distance from pivot is
always $l$" automatically, algebraically true, with no force needed to
enforce it. Position: $x=l\sin\theta$, $y=-l\cos\theta$ (pivot at the
origin, $y$ measuring height upward). Then
$$\dot x = l\cos\theta\,\dot\theta, \qquad \dot y = l\sin\theta\,\dot\theta,
\qquad
v^2=\dot x^2+\dot y^2 = l^2\dot\theta^2\big(\cos^2\theta+\sin^2\theta\big)
= l^2\dot\theta^2.$$
So $T=\tfrac12ml^2\dot\theta^2$, and $V=mgy=-mgl\cos\theta$. The
Lagrangian is
$$L = \tfrac12 ml^2\dot\theta^2 + mgl\cos\theta.$$
Euler–Lagrange:
$$\frac{\partial L}{\partial\dot\theta} = ml^2\dot\theta
\ \Longrightarrow\
\frac{d}{dt}\frac{\partial L}{\partial\dot\theta} = ml^2\ddot\theta,
\qquad\qquad
\frac{\partial L}{\partial\theta} = -mgl\sin\theta,$$
so $ml^2\ddot\theta=-mgl\sin\theta$, i.e.
$$\boxed{\ \ddot\theta = -\frac{g}{l}\sin\theta\ }.$$
Notice what did *not* happen: no resolving gravity into components, no
rod tension anywhere — the constraint was built into the choice of
$\theta$ from the start.

For small $\theta$, $\sin\theta\approx\theta$, giving
$\ddot\theta\approx-(g/l)\theta$ — the same simple-harmonic form as the
oscillator, with $\omega_0=\sqrt{g/l}$ in place of $\sqrt{k_s/m}$. For
$l=1\text{ m}$, $g=9.8\text{ m/s}^2$: $\omega_0\approx3.13$ rad/s, one
full back-and-forth cycle taking about $2\pi/\omega_0\approx2.0\text{ s}$
(never written "$T=2\pi/\omega_0$," since $T$ is kinetic energy this
phase).

### Generalized coordinates make constraints disappear: a bead on a driven rotating rod

The pendulum illustrated the moral once; here it is pushed further, on a
system where a naive Newtonian treatment needs a genuinely nontrivial
constraint force that Lagrangian mechanics never touches.

A bead of mass $m$ is threaded on a rigid, frictionless rod lying in a
horizontal plane, free to slide along the rod, while the rod is spun by
a motor at **fixed, externally prescribed** angular velocity $\omega$
about a vertical axis through one end. The bead has exactly one genuine
degree of freedom — its distance $r$ along the rod — since the rod's
angle $\phi=\omega t$ is imposed from outside, not something the bead's
dynamics affects.

In plane polar coordinates, $v^2=\dot r^2+r^2\dot\phi^2$. Substituting
the *prescribed* $\dot\phi=\omega$ (legitimate exactly because $\phi$ is
externally driven, not a dynamical variable needing its own equation —
see the misconception below) gives $v^2=\dot r^2+r^2\omega^2$; the rod
is horizontal, so $V=0$:
$$L = T = \tfrac12 m\dot r^2 + \tfrac12 m r^2\omega^2.$$
Euler–Lagrange for the one remaining coordinate $r$:
$$\frac{\partial L}{\partial\dot r}=m\dot r \ \Longrightarrow\
\frac{d}{dt}\frac{\partial L}{\partial\dot r}=m\ddot r, \qquad\qquad
\frac{\partial L}{\partial r} = mr\omega^2,$$
so $m\ddot r = mr\omega^2$, i.e.
$$\ddot r = \omega^2 r.$$
This has general solution $r(t)=Ae^{\omega t}+Be^{-\omega t}$: any bead
started with a nonzero outward displacement or velocity runs away from
the axis exponentially. Nothing about "centrifugal force" was invoked by
hand — the $r\omega^2$ term fell straight out of differentiating the
$\tfrac12mr^2\omega^2$ piece of the kinetic energy, itself just $v^2$ in
polar coordinates with the known rod motion substituted in. And, as
promised, the rod's sideways push on the bead never appeared: choosing
$(r,\phi)$ with $\phi$ prescribed made that constraint force irrelevant
to the equation of motion we wanted. **The moral: choose coordinates that
make the constraint invisible, and the constraint force never has to be
computed.**

> **Misconception:** "any known constraint can be plugged into $L$ before
> applying Euler–Lagrange, even for a coordinate you still want an
> equation of motion for." Valid only when the substituted quantity is
> genuinely *not* dynamical, as $\phi=\omega t$ is above (motor-driven,
> no equation of motion needed). Substituting a guessed $\phi(t)$ for a
> coordinate that is *not* externally prescribed would silently discard
> its real equation of motion and corrupt the rest. The rotating-hoop
> exercise below uses this same trick, for the same reason.

### Cyclic coordinates and Noether, made semi-precise

Suppose a Lagrangian simply does not depend on one of its coordinates,
$\partial L/\partial q = 0$ — such a $q$ is called **cyclic** (it may
still depend on $\dot q$; only the coordinate itself, not its rate, is
absent). The Euler–Lagrange equation immediately gives, in two lines:
$$\frac{d}{dt}\frac{\partial L}{\partial\dot q} = \frac{\partial L}
{\partial q} = 0 \qquad\Longrightarrow\qquad
\frac{\partial L}{\partial\dot q} = \text{constant in time}.$$
Define the **generalized (conjugate) momentum** $p:=\partial
L/\partial\dot q$; the two-line argument above is exactly the statement
that a cyclic coordinate's conjugate momentum is conserved. (This $p$ is
precisely the object Day 10 builds the Hamiltonian from — flagged now,
used tomorrow.)

This is Day 4's informal symmetry dictionary, now with an actual proof
attached. If $L$ doesn't depend on $x$ (translation symmetry — true for
the free particle above, and, as the wedge example shows, also for the
*total* horizontal position of a two-body system with no external
horizontal force), $p=\partial L/\partial\dot x=m\dot x$ is exactly
ordinary momentum, conserved. If $L$ doesn't depend on an angle
(rotational symmetry), its conjugate momentum is exactly angular
momentum about that axis — the day-4 quantity today's notation flag
renamed out of the letter $L$. The same style of argument, one level more
advanced (varying with $t$ itself), shows a time-independent $L$
conserves an energy-like quantity — what Day 10's Legendre transform
turns into the Hamiltonian.

## Worked examples

**1. The pendulum via Euler–Lagrange, start to finish.**
$$x=l\sin\theta,\quad y=-l\cos\theta \quad\Longrightarrow\quad
v^2=l^2\dot\theta^2.$$
$$T=\tfrac12ml^2\dot\theta^2, \qquad V=-mgl\cos\theta.$$
$$L = \tfrac12ml^2\dot\theta^2 + mgl\cos\theta.$$
$$\frac{\partial L}{\partial\dot\theta}=ml^2\dot\theta
\ \Longrightarrow\ \frac{d}{dt}\frac{\partial L}{\partial\dot\theta}
=ml^2\ddot\theta, \qquad\qquad
\frac{\partial L}{\partial\theta}=-mgl\sin\theta.$$
$$ml^2\ddot\theta=-mgl\sin\theta \quad\Longrightarrow\quad
\boxed{\ \ddot\theta=-\frac{g}{l}\sin\theta\ }.$$
No tension, no radial/tangential decomposition, anywhere above.

**2. The Atwood machine via one generalized coordinate.** Two masses
$m_1,m_2$ hang from an ideal string over a frictionless, massless
pulley. Let $x$ be how far $m_1$ has descended; since the string length
is fixed, $m_2$ rises by exactly the same $x$ — one coordinate describes
the whole system. Both masses move at speed $|\dot x|$, so
$$T = \tfrac12 m_1\dot x^2 + \tfrac12 m_2\dot x^2 = \tfrac12(m_1+m_2)
\dot x^2.$$
Measuring height upward, $m_1$'s height decreases as $x$ grows and
$m_2$'s increases by the same amount, so (dropping an additive constant,
which never affects the equation of motion since only $\partial V/\partial
x$ enters)
$$V = -m_1gx + m_2gx = (m_2-m_1)gx.$$
$$L = T-V = \tfrac12(m_1+m_2)\dot x^2 - (m_2-m_1)gx.$$
Euler–Lagrange: $\frac{\partial L}{\partial\dot x}=(m_1+m_2)\dot x
\Rightarrow(m_1+m_2)\ddot x$; $\frac{\partial L}{\partial x}=-(m_2-m_1)g
=(m_1-m_2)g$. So
$$(m_1+m_2)\ddot x = (m_1-m_2)g \qquad\Longrightarrow\qquad
\ddot x = \frac{(m_1-m_2)g}{m_1+m_2},$$
the standard Atwood-machine result (positive when $m_1>m_2$, i.e. the
heavier mass descends, exactly as it should). For $m_1=3\text{ kg}$,
$m_2=2\text{ kg}$: $\ddot x=(1)(9.8)/5=1.96\text{ m/s}^2$. At no point did
the string tension appear in this calculation — a Newtonian treatment
needs it as an unknown, written into both masses' force equations and
then eliminated.

**3. Block on a frictionless movable wedge — the classic two-coordinate
problem.** A wedge of mass $M$, incline angle $\alpha$, sits on a
frictionless floor, free to slide horizontally; a block of mass $m$
slides on the wedge's (also frictionless) incline. Two generalized
coordinates suffice: $X$, the wedge's horizontal position, and $s$, the
block's position down the incline relative to the wedge. In the lab
frame, taking the slope to descend toward increasing $x$,
$$x_{\text{block}} = X + s\cos\alpha, \qquad
y_{\text{block}} = -s\sin\alpha.$$
Differentiating, $\dot x_{\text{block}}=\dot X+\dot s\cos\alpha$,
$\dot y_{\text{block}}=-\dot s\sin\alpha$, so
$$v_{\text{block}}^2 = (\dot X+\dot s\cos\alpha)^2 + \dot s^2\sin^2\alpha
= \dot X^2 + 2\dot X\dot s\cos\alpha + \dot s^2.$$
With the wedge moving only horizontally at speed $\dot X$,
$$T = \tfrac12M\dot X^2 + \tfrac12m\left(\dot X^2+2\dot X\dot s\cos\alpha
+\dot s^2\right), \qquad V = -mgs\sin\alpha,$$
$$L = \tfrac12(M+m)\dot X^2 + m\dot X\dot s\cos\alpha + \tfrac12m\dot s^2
+ mgs\sin\alpha.$$
$L$ does not depend on $X$ itself — only $\dot X$ — so $X$ is **cyclic**:
$$\frac{\partial L}{\partial\dot X} = (M+m)\dot X + m\dot s\cos\alpha =
\text{const} \qquad\Longrightarrow\qquad
(M+m)\ddot X + m\ddot s\cos\alpha = 0. \tag{i}$$
This *is* the semi-precise Noether statement in action: no external
horizontal force acts on the wedge+block system, so total horizontal
momentum $(M+m)\dot X+m\dot s\cos\alpha$ is exactly conserved — (i) is
nothing but $\dot{(\text{momentum})}=0$.

The $s$-equation: $\frac{\partial L}{\partial\dot s}=m\dot X\cos\alpha+
m\dot s\Rightarrow\frac{d}{dt}(\cdot)=m\ddot X\cos\alpha+m\ddot s$; and
$\frac{\partial L}{\partial s}=mg\sin\alpha$. So
$$\ddot X\cos\alpha + \ddot s = g\sin\alpha. \tag{ii}$$
From (i), $\ddot X = -\dfrac{m\cos\alpha}{M+m}\ddot s$. Substituting into
(ii):
$$-\frac{m\cos^2\alpha}{M+m}\ddot s + \ddot s = g\sin\alpha
\quad\Longrightarrow\quad
\ddot s\,\frac{M+m-m\cos^2\alpha}{M+m} = g\sin\alpha.$$
Since $M+m-m\cos^2\alpha=M+m\sin^2\alpha$,
$$\ddot s = \frac{(M+m)g\sin\alpha}{M+m\sin^2\alpha}, \qquad\qquad
\ddot X = -\frac{mg\sin\alpha\cos\alpha}{M+m\sin^2\alpha}.$$
**Sanity checks.** As $M\to\infty$, $\ddot X\to0$ and $\ddot s\to
g\sin\alpha$, the ordinary fixed-incline result. The two accelerations
satisfy (i) — momentum conservation — by construction, since that is
exactly how $\ddot X$ was eliminated; and the signs match intuition: as
the block slides down ($\ddot s>0$), the wedge recoils oppositely
($\ddot X<0$) to keep total momentum at its initial value of zero. For
$M=2\text{ kg}$, $m=1\text{ kg}$, $\alpha=30°$ ($\sin\alpha=0.5$,
$\cos\alpha\approx0.866$, $g=9.8\text{ m/s}^2$):
$$\ddot s = \frac{(3)(9.8)(0.5)}{2+0.25} \approx 6.53\text{ m/s}^2,
\qquad
\ddot X = -\frac{(1)(9.8)(0.5)(0.866)}{2.25} \approx -1.89\text{ m/s}^2.$$
As in the pendulum and Atwood examples, no normal force ever entered a
single line of this calculation.

## Exercises

Attempt every problem closed-book before checking the Hints, and only
then the Solutions.

**Retrieval**

1. Derive the Euler–Lagrange equation from $\delta S=0$, closed book:
   the variation $q\to q+\epsilon\eta$, the first-order expansion of $L$,
   the integration by parts, the vanishing boundary term, and the
   fundamental-lemma argument that produces the final equation.
2. Prove, in general (not for one particular $L$), that if a coordinate
   $q$ is cyclic ($\partial L/\partial q=0$) then its conjugate momentum
   $p=\partial L/\partial\dot q$ is conserved.

**Standard**

3. A bead of mass $m$ slides frictionlessly on a vertical circular hoop
   of radius $R$, spun about a vertical diameter at fixed, prescribed
   angular velocity $\Omega$. Let $\theta$ be the bead's angle from the
   bottom of the hoop. Find the Euler–Lagrange equation for $\theta$, and
   all equilibrium angles ($\ddot\theta=0$ for all time) as a function of
   $\Omega$.
4. A projectile of mass $m$ moves under gravity alone in a vertical
   plane, $x$ horizontal and $y$ vertical (upward positive). Write
   $L=T-V$ in terms of $\dot x,\dot y,y$, and derive both equations of
   motion via Euler–Lagrange applied to $x$ and $y$ simultaneously.

**Stretch**

5. A double pendulum: mass $m_1$ on a massless rod of length $l_1$
   hanging from a fixed pivot at angle $\theta_1$ from vertical, and mass
   $m_2$ on a massless rod of length $l_2$ hanging from *$m_1$* (not the
   pivot) at angle $\theta_2$ from vertical. Write the full Lagrangian
   $L(\theta_1,\theta_2,\dot\theta_1,\dot\theta_2)$ — no need to derive or
   solve the equations of motion. Then, in a short paragraph, describe
   what a Newtonian free-body treatment would have required that the
   Lagrangian setup never touched.

## Hints

1. Write the pieces in order — the first-order Taylor expansion of
   $L(q+\epsilon\eta,\dot q+\epsilon\dot\eta,t)$, then integration by
   parts on only the $\dot\eta$ term, then the fixed-endpoint condition
   killing the boundary term — and invoke the fundamental lemma only at
   the end, once the integral is of the form $\int f(t)\eta(t)\,dt=0$ for
   arbitrary $\eta$.
2. Start directly from the Euler–Lagrange equation and substitute the
   cyclic condition $\partial L/\partial q=0$ into it; the result should
   take two lines, as in the Theory section.
3. Follow the rotating-rod derivation in Theory: substitute the hoop's
   prescribed $\dot\phi=\Omega$ into the kinetic energy *before*
   differentiating, leaving $\theta$ as the one genuine coordinate. For
   equilibria, factor the $\ddot\theta$ equation and ask when each factor
   vanishes; one branch exists only once $\Omega$ exceeds a threshold.
4. Two independent one-line applications of Euler–Lagrange, one per
   coordinate — notice which coordinate is cyclic before grinding
   through both.
5. Write both masses' Cartesian positions in terms of $\theta_1,\theta_2$
   as in the single pendulum, remembering $m_2$'s position is relative to
   $m_1$'s (already-moving) position, not the fixed pivot; $v_2^2$ then
   has a cross term in $\cos(\theta_1-\theta_2)$. For the second part,
   count the unknown rod-tension components a Newtonian treatment of two
   linked rods would introduce.

## Solutions

**1.** Expand $L(q+\epsilon\eta,\dot q+\epsilon\dot\eta,t) = L(q,\dot
q,t) + \epsilon\left(\frac{\partial L}{\partial q}\eta+\frac{\partial
L}{\partial\dot q}\dot\eta\right)+O(\epsilon^2)$ by the multivariable
chain rule. Integrate and differentiate at $\epsilon=0$:
$\delta S=\int_{t_1}^{t_2}\left(\frac{\partial L}{\partial q}\eta+
\frac{\partial L}{\partial\dot q}\dot\eta\right)dt$. Integrate the
second term by parts: $\int\frac{\partial L}{\partial\dot q}\dot\eta\,dt
= \left[\frac{\partial L}{\partial\dot q}\eta\right]_{t_1}^{t_2} -
\int\frac{d}{dt}\left(\frac{\partial L}{\partial\dot q}\right)\eta\,dt$;
the boundary term vanishes because $\eta(t_1)=\eta(t_2)=0$. So
$\delta S=\int_{t_1}^{t_2}\left(\frac{\partial L}{\partial q}-
\frac{d}{dt}\frac{\partial L}{\partial\dot q}\right)\eta\,dt$. Setting
$\delta S=0$ for every admissible $\eta$ and invoking the fundamental
lemma (a bump function peaked wherever the bracket is nonzero would give
a nonzero integral, a contradiction) forces the bracket to vanish
identically:
$\frac{d}{dt}\frac{\partial L}{\partial\dot q}=\frac{\partial L}
{\partial q}$.

**2.** From the Euler–Lagrange equation, $\frac{d}{dt}\frac{\partial L}
{\partial\dot q}=\frac{\partial L}{\partial q}$. If $q$ is cyclic, the
right side is $0$ by definition, so $\frac{d}{dt}\left(\frac{\partial
L}{\partial\dot q}\right)=0$, i.e. $p=\partial L/\partial\dot q$ does not
change in time — it is conserved.

**3.** Following the rotating-rod pattern: with $\phi=\Omega t$
prescribed, the bead's distance from the axis is $\rho=R\sin\theta$ and
its height is $z=-R\cos\theta$, so
$v^2=\dot\rho^2+\rho^2\Omega^2+\dot z^2 = R^2\dot\theta^2\cos^2\theta +
R^2\Omega^2\sin^2\theta + R^2\dot\theta^2\sin^2\theta =
R^2\dot\theta^2+R^2\Omega^2\sin^2\theta$. So
$$L = \tfrac12mR^2\dot\theta^2 + \tfrac12mR^2\Omega^2\sin^2\theta +
mgR\cos\theta.$$
Euler–Lagrange: $\frac{\partial L}{\partial\dot\theta}=mR^2\dot\theta
\Rightarrow\frac{d}{dt}(\cdot)=mR^2\ddot\theta$; $\frac{\partial L}
{\partial\theta}=mR^2\Omega^2\sin\theta\cos\theta - mgR\sin\theta$. So
$$mR^2\ddot\theta = mR^2\Omega^2\sin\theta\cos\theta - mgR\sin\theta
\quad\Longrightarrow\quad
\ddot\theta = \sin\theta\left(\Omega^2\cos\theta - \frac{g}{R}\right).$$
Equilibria need the right side zero: either $\sin\theta=0$, giving
$\theta=0$ (bottom) or $\theta=\pi$ (top) for *any* $\Omega$; or
$\cos\theta=g/(R\Omega^2)$, solvable only when $\Omega^2>g/R$ (strict —
at equality this root coincides with $\theta=0$, not a distinct
equilibrium). So at or below the threshold $\Omega_c=\sqrt{g/R}$ only the
bottom and top are equilibria; strictly above it, a third pair appears at
$\theta_{\text{eq}}=\pm\arccos\!\big(g/(R\Omega^2)\big)$ — the bead
climbs away from the bottom as the spin passes threshold.

**4.** $L=T-V=\tfrac12m(\dot x^2+\dot y^2)-mgy$ ($V=mgy$, $y$ upward). For
$x$: $\frac{\partial L}{\partial\dot x}=m\dot x\Rightarrow m\ddot x$;
$\frac{\partial L}{\partial x}=0$ ($x$ cyclic). So $\ddot x=0$ — constant
horizontal velocity, and (Exercise 2) the conserved $m\dot x$ is just
ordinary horizontal momentum, since no horizontal force acts. For $y$:
$\frac{\partial L}{\partial\dot y}=m\dot y\Rightarrow m\ddot y$;
$\frac{\partial L}{\partial y}=-mg$. So $\ddot y=-g$. Together,
$\ddot x=0,\ \ddot y=-g$ is exactly ordinary projectile motion.

**5.** Positions (pivot at origin, $y$ upward): $x_1=l_1\sin\theta_1$,
$y_1=-l_1\cos\theta_1$; $x_2=l_1\sin\theta_1+l_2\sin\theta_2$,
$y_2=-l_1\cos\theta_1-l_2\cos\theta_2$. Differentiating and squaring, as
in the pendulum example but now with a cross term since $m_2$'s velocity
has contributions from both angles:
$$v_1^2 = l_1^2\dot\theta_1^2, \qquad
v_2^2 = l_1^2\dot\theta_1^2 + l_2^2\dot\theta_2^2 +
2l_1l_2\dot\theta_1\dot\theta_2\cos(\theta_1-\theta_2),$$
using $\cos\theta_1\cos\theta_2+\sin\theta_1\sin\theta_2=
\cos(\theta_1-\theta_2)$. So
$$T = \tfrac12(m_1+m_2)l_1^2\dot\theta_1^2 + \tfrac12m_2l_2^2\dot\theta_2^2
+ m_2l_1l_2\dot\theta_1\dot\theta_2\cos(\theta_1-\theta_2),$$
$$V = -(m_1+m_2)gl_1\cos\theta_1 - m_2gl_2\cos\theta_2,$$
$$L = \tfrac12(m_1+m_2)l_1^2\dot\theta_1^2 + \tfrac12m_2l_2^2\dot\theta_2^2
+ m_2l_1l_2\dot\theta_1\dot\theta_2\cos(\theta_1-\theta_2) +
(m_1+m_2)gl_1\cos\theta_1 + m_2gl_2\cos\theta_2.$$
A Newtonian treatment would need the tension in each rod as two further
unknowns, resolved into horizontal/vertical components at both masses,
plus Newton's third law applied where rod 2's tension acts oppositely on
$m_1,m_2$ at their shared joint — before any elimination down to two
final equations. The Lagrangian setup never introduced either tension:
both fixed-length constraints were built into $\theta_1,\theta_2$ from
the first line.

## Connection to QM

Richard Feynman's path-integral formulation of quantum mechanics takes
today's action and turns it into the entire theory: a quantum particle
takes *every* path between two points simultaneously, each weighted by a
complex phase $e^{iS[q]/\hbar}$, and the total quantum amplitude is the
sum (really an integral) of that phase over all paths. Classical
mechanics — the single, definite trajectory Euler–Lagrange produces —
emerges as the *stationary-phase limit* of that sum: paths near the
classical one, where $S$ barely changes to first order (exactly today's
$\delta S=0$), add up coherently, while paths far from it oscillate and
cancel almost completely. The classical trajectory isn't a separate law
bolted onto quantum mechanics — it's the one path that survives
destructive interference among the rest, and today's derivation is,
symbol for symbol, the mathematics behind why.

Even without the path-integral picture, today's work feeds directly into
tomorrow: Day 10 takes the conjugate momentum $p=\partial L/\partial\dot
q$ defined today and uses it, via a Legendre transform, to build the
**Hamiltonian** $H$ — the object your entire quantum mechanics course is
organized around (whose eigenvalues are energies, which generates time
evolution, which sits on both sides of the Schrödinger equation). Nothing
about $H$ can be defined without $L$ and $p$ exactly as built today.
