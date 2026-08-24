# Day 3 — The Harmonic Oscillator, Deep

## Learning objectives

By the end of today you should be able to:
- Show that *any* smooth potential near a minimum produces simple harmonic
  motion, and derive $\omega_0 = \sqrt{V''(x_0)/m}$ from a Taylor expansion.
- Write the complete solution of $\ddot x = -\omega_0^2 x$ in both the
  amplitude/phase form and the complex-exponential form, and fix the
  integration constants from initial conditions.
- Explain the kinetic/potential energy exchange in SHM, including why the
  time-averages satisfy $\langle K\rangle = \langle V\rangle$.
- Classify the three damping regimes of $\ddot x + 2\beta\dot x+\omega_0^2x=0$
  directly from the characteristic equation's discriminant, and describe
  the qualitative shape of $x(t)$ in each.
- Derive the driven steady-state amplitude $A(\omega_d)$ and phase lag
  $\delta(\omega_d)$ using the complex-exponential method, locate the
  resonance peak, and explain the Q factor two ways: as a ring-down cycle
  count and as a peak-sharpness measure.
- Predict, before running it, how the oscillator-zoo simulation's panels
  change when damping or spring constant change.

Time budget: ~3 hours.

## Reference material

- French, *Vibrations and Waves*, the chapters on free, damped, and forced
  oscillations — the closest match to today's entire arc, written by
  someone who clearly thinks the harmonic oscillator deserves a whole book.
- Morin, *Introduction to Classical Mechanics*, the oscillations chapter, as
  a second telling of the same material with different worked examples.
- This file is self-contained: every equation below is derived here, so
  neither text is required to do today's work.
- Builds on **Day 1** (Newton's second law written and solved as an ODE)
  and **Day 2** (reading $F=-dV/dx$ off a potential curve, and the
  small-oscillation preview near a minimum). Today turns that preview into
  a complete, fluent toolkit.

## Theory

### Universality: every potential minimum is a spring in disguise

Day 2 showed that force is the negative slope of potential energy,
$F=-dV/dx$, and previewed that near a minimum this looks spring-like.
Today makes that precise for *any* smooth $V(x)$, not just $V(x)=\tfrac12
k_sx^2$.

Let $x_0$ be a point where $V$ has a local minimum, and Taylor-expand
$V(x)$ about it:
$$V(x) = V(x_0) + V'(x_0)(x-x_0) + \tfrac12 V''(x_0)(x-x_0)^2 + O\big((x-x_0)^3\big).$$
Two terms vanish or drop out for reasons specific to being at a minimum:
- $V(x_0)$ is a constant. Forces come from *derivatives* of $V$, so an
  additive constant in the potential is physically invisible — you may
  drop it (equivalently, redefine the zero of potential energy).
- $V'(x_0)=0$, precisely because $x_0$ is a minimum (an extremum of a
  smooth function has zero slope). This is the term that would give a
  constant, non-restoring force if it survived; it doesn't, because the
  minimum condition kills it outright.

What survives, to leading order in the displacement $u \equiv x-x_0$, is
$$V(x) \approx \tfrac12 V''(x_0)\,u^2 + \text{const}.$$
This is *exactly* the spring potential $\tfrac12 k_s u^2$ with the
identification $k_s \equiv V''(x_0)$ — provided $V''(x_0)>0$, which is
precisely the condition that $x_0$ is a genuine minimum (a stable
equilibrium) rather than a maximum or inflection point. The force is
$$F = -\frac{dV}{du} = -V''(x_0)\,u,$$
and Newton's second law, $m\ddot u = F$, gives
$$\ddot u = -\frac{V''(x_0)}{m}\,u \equiv -\omega_0^2\, u, \qquad
\boxed{\omega_0 = \sqrt{\frac{V''(x_0)}{m}}}.$$
This is the universality claim: *whatever* the full shape of $V$ far from
$x_0$ — a spring, a pendulum, a chemical bond, an electron in a lattice —
small enough oscillations about any stable equilibrium obey the same
equation, $\ddot u = -\omega_0^2 u$, with $\omega_0$ set entirely by the
curvature of $V$ at the bottom. For the literal spring potential
$V(x)=\tfrac12 k_s x^2$, $V''(x)=k_s$ everywhere, recovering the familiar
$\omega_0=\sqrt{k_s/m}$ as the special case it always was.

### The complete solution of $\ddot x = -\omega_0^2 x$

Drop the constant/shift and just call the displacement $x$. The equation
$\ddot x = -\omega_0^2 x$ is linear, so any linear combination of solutions
is a solution (superposition). Direct substitution confirms $\cos\omega_0t$
and $\sin\omega_0t$ each solve it (differentiating twice brings down a
factor of $-\omega_0^2$ and returns the same function), so the general
solution is
$$x(t) = C_1\cos\omega_0 t + C_2 \sin\omega_0 t.$$
Two arbitrary constants are expected: a second-order ODE needs two initial
conditions, $x(0)$ and $\dot x(0)$, to pin down a unique trajectory.

**Amplitude/phase form.** The same solution can be written
$$x(t) = A\cos(\omega_0 t+\phi),$$
using the cosine-of-a-sum identity
$A\cos(\omega_0t+\phi)=A\cos\phi\cos\omega_0t - A\sin\phi\sin\omega_0t$,
so the two forms match with $C_1=A\cos\phi$, $C_2=-A\sin\phi$, i.e.
$A=\sqrt{C_1^2+C_2^2}$ and $\tan\phi = -C_2/C_1$. This is the form worth
memorizing: $A$ is the amplitude, $\phi$ the phase offset, both fixed by
initial conditions once and for all at $t=0$.

**Fixing constants from $x(0),\dot x(0)$.** From $x(t)=C_1\cos\omega_0t +
C_2\sin\omega_0t$: at $t=0$, $x(0)=C_1$ directly. Differentiating,
$\dot x(t) = -C_1\omega_0\sin\omega_0t + C_2\omega_0\cos\omega_0t$, so
$\dot x(0)=C_2\omega_0$, giving $C_2=\dot x(0)/\omega_0$. So
$$x(t) = x(0)\cos\omega_0t + \frac{\dot x(0)}{\omega_0}\sin\omega_0t,$$
a formula you should be able to write down on sight for any SHM problem
once $\omega_0$ is known.

### The complex-exponential method

Trig identities are error-prone under pressure; complex exponentials turn
the same algebra into arithmetic. Guess a complex trajectory
$$z(t) = \tilde A\, e^{i\omega t}, \qquad \tilde A = A\,e^{i\phi}\in\mathbb{C},$$
where $\tilde A$ is a single complex number packaging *both* the real
amplitude $A$ and phase $\phi$ — this is the same $e^{i\theta}$ machinery
that encodes a qubit's relative phase in $\mathbb C^2$; here it encodes a
literal oscillation's timing instead of a quantum phase, but the algebra is
identical. Differentiating a complex exponential is multiplication:
$\dot z = i\omega z$, $\ddot z = (i\omega)^2 z = -\omega^2 z$. Substituting
into $\ddot z = -\omega_0^2 z$ gives $-\omega^2 z = -\omega_0^2 z$, so
$\omega=\pm\omega_0$ — the complex guess solves the ODE algebraically, no
trig differentiation required. Taking $\omega=\omega_0$,
$$z(t) = \tilde A\, e^{i\omega_0 t} = A\,e^{i\phi}e^{i\omega_0t} =
A\,e^{i(\omega_0t+\phi)}.$$
Because the original ODE is real and linear, the real part of any complex
solution is itself a real solution:
$$x(t) = \mathrm{Re}[z(t)] = \mathrm{Re}\big[\tilde A\,e^{i\omega_0t}\big] =
A\cos(\omega_0t+\phi),$$
reproducing the amplitude/phase form exactly — the complex method is not a
different answer, it's a faster route to the same one. Its real payoff
shows up once damping and driving are added below, where trig-identity
bookkeeping becomes genuinely painful and the complex algebra stays trivial.

> **Misconception:** "You can take the real part partway through and keep
> going." You can't — $\mathrm{Re}[\cdot]$ only commutes with *linear*
> operations (addition, differentiation, multiplication by a real
> constant). Take $\mathrm{Re}[\cdot]$ exactly once, at the very end, after
> every derivative and every linear combination is done. Multiplying two
> complex trajectories together before taking the real part, for instance,
> gives the wrong answer, because $\mathrm{Re}[z_1z_2]\ne
> \mathrm{Re}[z_1]\mathrm{Re}[z_2]$ in general.

### Energy: the $K\leftrightarrow V$ slosh

Total mechanical energy is
$$E = \tfrac12 m\dot x^2 + \tfrac12 k_s x^2 = K + V.$$
Substitute $x(t)=A\cos(\omega_0t+\phi)$ and $\dot x(t) =
-A\omega_0\sin(\omega_0t+\phi)$, writing $\theta\equiv\omega_0t+\phi$
for brevity, and using $m\omega_0^2=k_s$:
$$K(t) = \tfrac12 m A^2\omega_0^2\sin^2\theta = \tfrac12 k_sA^2\sin^2\theta,
\qquad V(t) = \tfrac12 k_sA^2\cos^2\theta.$$
Adding, $K+V = \tfrac12k_sA^2(\sin^2\theta+\cos^2\theta) = \tfrac12 k_sA^2$
— a constant, confirming energy conservation directly from the SHM
solution (not assumed, *derived*). Using the double-angle identities
$\sin^2\theta = \tfrac12(1-\cos2\theta)$, $\cos^2\theta=\tfrac12(1+\cos2\theta)$:
$$K(t) = \tfrac14k_sA^2\big(1-\cos2\theta\big), \qquad
V(t) = \tfrac14k_sA^2\big(1+\cos2\theta\big).$$
Both oscillate at $2\omega_0$ — twice the mechanical frequency, because
each is a squared sinusoid — about a shared mean of $\tfrac14k_sA^2=E/2$.
So $K$ and $V$ slosh back and forth out of phase with each other: a full
cosine cycle averages to zero, $\langle\cos2\theta\rangle=0$, so averaging
each expression above directly kills the oscillating term and leaves only
the shared mean, giving the time-averaged equality
$$\langle K\rangle = \langle V\rangle = \frac{E}{2}.$$

### Damping: three regimes from one discriminant

A drag force proportional to velocity, $F_{\text{drag}}=-b\dot x$, added to
the spring force gives $m\ddot x = -k_sx - b\dot x$, conventionally written
$$\ddot x + 2\beta\dot x + \omega_0^2 x = 0, \qquad \beta \equiv
\frac{b}{2m}>0.$$
Guess $x=\mathrm{Re}[e^{\lambda t}]$ for constant (possibly complex)
$\lambda$: substituting gives the **characteristic equation**
$$\lambda^2 + 2\beta\lambda + \omega_0^2 = 0 \implies \lambda =
-\beta \pm \sqrt{\beta^2-\omega_0^2}.$$
The sign of the discriminant $\beta^2-\omega_0^2$ splits the physics into
three qualitatively different regimes.

**Underdamped ($\beta<\omega_0$).** The discriminant is negative, so
$\lambda = -\beta \pm i\omega_1$ with $\omega_1\equiv\sqrt{\omega_0^2-\beta^2}$
real. The general real solution is
$$x(t) = A\,e^{-\beta t}\cos(\omega_1 t+\phi),$$
an oscillation at the shifted frequency $\omega_1<\omega_0$ inside a
decaying envelope $Ae^{-\beta t}$. This is "ringing down."

**Critically damped ($\beta=\omega_0$).** The discriminant is zero, giving
a repeated root $\lambda=-\beta$. A single exponential $e^{-\beta t}$ is
one solution, but a second-order ODE needs two independent solutions; the
repeated-root case of a linear ODE always produces $te^{-\beta t}$ as the
second one (direct substitution confirms it solves the equation too). So
$$x(t) = (C_1+C_2t)\,e^{-\beta t}$$
— the fastest possible return toward $x=0$ that still avoids oscillating
past it (any nonzero $\beta$ larger than this makes the return slower, not
faster, which is why critical damping is the design target for car doors
and analog meter needles).

**Overdamped ($\beta>\omega_0$).** The discriminant is positive, giving two
distinct real, negative roots $\lambda_\pm = -\beta\pm\sqrt{\beta^2-\omega_0^2}$
(both negative since $\sqrt{\beta^2-\omega_0^2}<\beta$). The general
solution
$$x(t) = C_1e^{\lambda_+t} + C_2e^{\lambda_-t}$$
is a sum of two decaying exponentials — no $\sin$ or $\cos$ anywhere, so
$x(t)$ can cross zero **at most once**, then decay monotonically. There is
no oscillation at all.

> **Misconception:** "Damping always makes an oscillator wobble to a stop
> gradually." Only the *underdamped* case oscillates while decaying.
> Overdamped systems (thick honey instead of light oil in the shock
> absorber) don't oscillate even once past their first zero crossing —
> heavier damping can remove the oscillation entirely rather than just
> shrinking it.

**The quality factor $Q$.** For weak damping ($\beta\ll\omega_0$, so
$\omega_1\approx\omega_0$), the amplitude envelope is $Ae^{-\beta t}$, so
the time for the amplitude to halve is $t_{1/2}=\ln2/\beta$. Define
$$Q \equiv \frac{\omega_0}{2\beta}.$$
Two equivalent readings of $Q$, both used below:
- **Ring-down count.** The number of oscillation periods $T_1=2\pi/\omega_1
  \approx 2\pi/\omega_0$ elapsed while the amplitude decays to $1/e$ of its
  start (at $t=1/\beta$) is $(1/\beta)/T_1 \approx \omega_0/(2\pi\beta) =
  Q/\pi$ — so $Q$ is, up to the factor $\pi$, literally a count of how many
  cycles the system rings for before dying out.
- **Peak sharpness.** Shown below: $Q$ also equals $\omega_0$ divided by
  the full width of the driven resonance peak — a sharper, taller resonance
  peak is the same underlying weak-damping condition as a longer ring-down.

### Driving and resonance

Add a sinusoidal drive force $F_0\cos\omega_dt$ to the damped equation,
divide by $m$, and write $f_0\equiv F_0/m$:
$$\ddot x + 2\beta\dot x + \omega_0^2 x = f_0\cos\omega_dt.$$
Use the complex method again: seek the steady-state response as
$x(t)=\mathrm{Re}[z(t)]$ with $z(t) = \tilde X e^{i\omega_dt}$ driven by the
complex forcing $f_0e^{i\omega_dt}$ (whose real part is the actual drive).
Since $\dot z = i\omega_d z$ and $\ddot z=-\omega_d^2z$, substituting gives
$$\big(-\omega_d^2 + 2i\beta\omega_d + \omega_0^2\big)\tilde X\,e^{i\omega_dt}
= f_0e^{i\omega_dt} \implies \tilde X = \frac{f_0}{(\omega_0^2-\omega_d^2)
+ 2i\beta\omega_d}.$$
Write the denominator in polar form, $(\omega_0^2-\omega_d^2)+2i\beta\omega_d
= R\,e^{i\delta}$, with
$$R = \sqrt{(\omega_0^2-\omega_d^2)^2 + 4\beta^2\omega_d^2}, \qquad
\tan\delta = \frac{2\beta\omega_d}{\omega_0^2-\omega_d^2}.$$
Then $\tilde X = (f_0/R)\,e^{-i\delta}$, and taking the real part of
$\tilde X e^{i\omega_dt}$ gives the steady-state solution
$$x(t) = A(\omega_d)\cos(\omega_dt-\delta), \qquad
\boxed{A(\omega_d) = \frac{f_0}{\sqrt{(\omega_0^2-\omega_d^2)^2 +
4\beta^2\omega_d^2}}}.$$
The system oscillates at the *drive* frequency $\omega_d$ (not $\omega_0$),
lagging the drive by phase $\delta$.

**Phase-lag regimes.** From $\tan\delta = 2\beta\omega_d/(\omega_0^2-\omega_d^2)$:
far below resonance ($\omega_d\ll\omega_0$) the denominator is large and
positive, so $\delta\to0^+$ — the mass tracks the drive almost in phase.
Exactly at $\omega_d=\omega_0$ the denominator vanishes, so $\delta=90°$
regardless of $\beta$. Far above resonance ($\omega_d\gg\omega_0$) the
denominator is large and negative, so $\delta\to180°$ — the mass moves
opposite the drive.

**Locating the peak.** Maximize $A(\omega_d)$ by minimizing
$R^2=(\omega_0^2-\omega_d^2)^2+4\beta^2\omega_d^2$. Let $u=\omega_d^2$;
$dR^2/du = -2(\omega_0^2-u)+4\beta^2=0$ gives $u=\omega_0^2-2\beta^2$, so
$$\omega_{d,\text{peak}} = \sqrt{\omega_0^2-2\beta^2} \;<\; \omega_0$$
(valid whenever $\beta<\omega_0/\sqrt2$; for larger $\beta$ the amplitude
falls monotonically with $\omega_d$ and there is no interior peak at all).
The amplitude peak sits *below* $\omega_0$, and only coincides with
$\omega_0$ in the weak-damping limit $\beta\to0$.

> **Misconception:** "Resonance means the drive frequency exactly equals
> $\omega_0$." Precisely false in two related ways: the amplitude peak
> actually sits at $\omega_{d,\text{peak}}=\sqrt{\omega_0^2-2\beta^2}$, a
> little *below* $\omega_0$, shifting further down as damping grows; the
> point that *is* exactly at $\omega_d=\omega_0$ is the $90°$ phase-lag
> point, not the amplitude maximum. The two only coincide when damping is
> weak enough that $\beta^2\ll\omega_0^2$.

**Peak sharpness and $Q$ again.** Near resonance, write $\omega_d=\omega_0+\epsilon$
with $\epsilon$ small: $\omega_0^2-\omega_d^2 = -( \omega_d-\omega_0)(\omega_d+\omega_0)
\approx -2\omega_0\epsilon$, so
$$R^2 \approx 4\omega_0^2\epsilon^2 + 4\beta^2\omega_0^2 =
4\omega_0^2(\epsilon^2+\beta^2), \qquad A^2(\omega_d) \approx
\frac{f_0^2}{4\omega_0^2(\epsilon^2+\beta^2)},$$
a Lorentzian in $\epsilon$ whose half-maximum points are at $\epsilon=\pm\beta$
— a full width at half maximum of $\Delta\omega_d = 2\beta$. So
$$Q = \frac{\omega_0}{\Delta\omega_d} = \frac{\omega_0}{2\beta},$$
identical to the ring-down definition above — one number, two readings:
how many cycles the system rings for after being struck, and how narrow
its resonance peak is when driven continuously.

## Worked examples

**1. Universality applied to a two-term potential.** Let
$V(x) = V_0\left(\dfrac ax + \dfrac xa\right)$ for $x>0$, $V_0,a>0$. Find
the equilibrium and $\omega_0$ for a mass $m$ there.

*Solution.* $V'(x) = V_0\left(-\dfrac{a}{x^2}+\dfrac1a\right)$. Setting
$V'(x)=0$: $\dfrac{a}{x^2}=\dfrac1a \implies x^2=a^2 \implies x=a$ (taking
the physical branch $x>0$). Second derivative: $V''(x) = 2V_0a/x^3$, so at
$x=a$, $V''(a) = 2V_0a/a^3 = 2V_0/a^2 > 0$ — confirming a genuine minimum.
By the universality result,
$$\omega_0 = \sqrt{\frac{V''(a)}{m}} = \sqrt{\frac{2V_0}{ma^2}}.$$
Sanity check: doubling $V_0$ (a stiffer well) increases $\omega_0$;
doubling $a$ (a wider, gentler well, since the well's curvature scales as
$1/a^2$) decreases $\omega_0$ — both match intuition about well shape.

**2. Ring-down: extracting $\beta$ and $Q$ from a decay count.** A lightly
damped oscillator has $\omega_0=2\pi\ \text{rad/s}$ (period $T_1\approx1\,$s
at weak damping) and its amplitude is observed to halve every $N=10$
cycles. Find $\beta$ and $Q$.

*Solution.* Weak damping means $\omega_1\approx\omega_0$, so $N$ cycles
take time $t_N \approx N\cdot(2\pi/\omega_0) = 10\cdot1\,\text{s}=10\,$s.
The envelope is $Ae^{-\beta t}$, halving when $\beta t_{1/2}=\ln2$:
$$\beta = \frac{\ln2}{t_N} = \frac{\ln2}{10\,\text{s}} \approx
0.0693\ \text{s}^{-1}.$$
Then $Q=\omega_0/(2\beta) = 2\pi/(2\times0.0693) \approx 45.3$. Equivalently,
directly from $t_N=NT_1$: $\beta = \omega_0\ln2/(2\pi N)$ and
$Q=\pi N/\ln2 = \pi(10)/0.693\approx45.3$ — the same number either way, and
$\beta\ll\omega_0$ ($0.0693\ll6.28$) confirms the weak-damping approximation
used was self-consistent.

**3. Driven amplitude at three frequencies, and the peak.** Take
$\omega_0=10\,\text{rad/s}$, $\beta=1\,\text{rad/s}$ (so $Q=\omega_0/2\beta=5$),
$f_0=1$ (arbitrary consistent units). Compute $A(\omega_d)$ at
$\omega_d=5,\,10,\,20\,\text{rad/s}$, and locate the exact peak.

*Solution.* Using $A(\omega_d)=f_0/\sqrt{(\omega_0^2-\omega_d^2)^2+4\beta^2\omega_d^2}$:

- $\omega_d=5$: $\omega_0^2-\omega_d^2=75$, $4\beta^2\omega_d^2=100$,
  $R=\sqrt{75^2+100}=\sqrt{5725}\approx75.66$, so $A\approx1/75.66\approx0.0132$.
- $\omega_d=10=\omega_0$: $\omega_0^2-\omega_d^2=0$, $4\beta^2\omega_d^2=400$,
  $R=\sqrt{400}=20$, so $A=1/20=0.0500$.
- $\omega_d=20$: $\omega_0^2-\omega_d^2=-300$, $4\beta^2\omega_d^2=1600$,
  $R=\sqrt{300^2+1600}=\sqrt{91600}\approx302.65$, so $A\approx0.0033$.

Exact peak: $\omega_{d,\text{peak}}=\sqrt{\omega_0^2-2\beta^2}=\sqrt{98}
\approx9.90\,\text{rad/s}$, giving $R=\sqrt{2^2+4(1)^2(98)}=\sqrt{396}
\approx19.90$, so $A_{\text{peak}}\approx0.0503$ — barely above the value
at $\omega_d=\omega_0$ ($0.0500$), because $Q=5$ is only mildly underdamped.
The three sample points ($0.0132\to0.0500\to0.0033$) rise toward the peak
from below and then fall away above it, consistent with the low-frequency
floor $A(0)=f_0/\omega_0^2=1/100=0.0100$: as $\omega_d\to0$, $R\to\omega_0^2$,
a finite value, so $A$ approaches the finite floor $f_0/\omega_0^2$ rather
than zero, while as $\omega_d\to\infty$, $R$ grows like $\omega_d^2$, so
$A\sim f_0/\omega_d^2\to0$. The curve is therefore asymmetric about the
peak: gentler below resonance, where it only has to climb from a nonzero
floor, and steeper above resonance, where it falls all the way to zero.

## Simulation

Run:
```
python3 code/day03_oscillator_zoo.py
```
Three panels: **(a)** an undamped oscillator's $x(t)$ with $K(t)$ and
$V(t)$ overlaid, showing the sloshing derived above (watch them trade off
at twice the mechanical frequency, summing to a flat $E$ line); **(b)**
$x(t)$ for three fixed-$\omega_0$ damping values — under, critical, and
overdamped — so you can see the qualitative reshaping the theory predicts,
not just read about it; **(c)** the steady-state amplitude $A(\omega_d)$
from the boxed formula above, swept over drive frequency, for three
different damping strengths, so the peak-height/peak-width trade-off is
visible directly.

Before running, predict:
- Halve the damping — how much taller and narrower does the resonance peak
  get?
- Set $\beta>\omega_0$ — predict the shape of $x(t)$ before looking.
- Double $k_s$ — which way does the resonance peak move?

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. Derive $\omega_0=\sqrt{V''(x_0)/m}$ from the Taylor expansion of a
   general potential about a minimum $x_0$, closed book.
2. Verify by direct substitution that $x(t)=A\cos\omega_0t+B\sin\omega_0t$
   solves $\ddot x=-\omega_0^2x$ for any constants $A,B$, then fix $A,B$ in
   terms of $x(0)$ and $\dot x(0)$.

**Standard**

3. A mass $m$ sits between two springs with constants $k_{s1},k_{s2}$ in two
   different arrangements: **(a)** each spring runs from the mass to its
   own fixed wall, on opposite sides, both at natural length when the mass
   is at equilibrium (a *parallel* arrangement); **(b)** the two springs
   are connected end to end in a single line between one wall and the mass
   (a *series* arrangement). Find $\omega_0$ in each case.
4. A simple pendulum (point mass $m$, string length $l$, small angle
   $\theta$) has potential energy $V(\theta)=mgl(1-\cos\theta)$. Using the
   arc-length coordinate $s=l\theta$ and the tangential form of Newton's
   second law, $m\ddot s = F_{\text{tangential}}$, find $\omega_0$ and the
   period, treating $s$ as an ordinary 1-D position coordinate.

**Stretch**

5. Starting from $\ddot x+2\beta\dot x+\omega_0^2x=f_0\cos\omega_dt$, derive
   the steady-state phase lag $\tan\delta = 2\beta\omega_d/(\omega_0^2-\omega_d^2)$
   using the complex-exponential method (not by memorizing the boxed
   result), and interpret the three regimes $\omega_d\ll\omega_0$,
   $\omega_d=\omega_0$, $\omega_d\gg\omega_0$.

## Hints

1. Write $V(x)$'s Taylor series about $x_0$ to second order, and ask which
   terms are forced to vanish specifically *because* $x_0$ is a minimum.
2. Differentiate the proposed $x(t)$ twice and compare to $-\omega_0^2x(t)$
   term by term; then evaluate $x(t)$ and $\dot x(t)$ at $t=0$ separately.
3. In each arrangement, write the total restoring force on the mass for a
   displacement $x$ from equilibrium, then match it to $-k_{s,\text{eff}}x$
   before invoking $\omega_0=\sqrt{k_{s,\text{eff}}/m}$. For the series
   case, ask what force the massless junction between the springs can
   sustain.
4. Substitute $\theta=s/l$ into $V(\theta)$ to get $V$ as a function of the
   position coordinate $s$, then apply today's universality result to
   $V(s)$ directly around $s=0$.
5. Write the complex forcing $f_0e^{i\omega_dt}$ and complex response
   $\tilde X e^{i\omega_dt}$, substitute, solve for $\tilde X$ as a complex
   number, and read $\delta$ off its polar form.

## Solutions

**1.** Expand $V(x) = V(x_0)+V'(x_0)(x-x_0)+\tfrac12V''(x_0)(x-x_0)^2+\dots$
The constant $V(x_0)$ is physically irrelevant (forces depend only on
derivatives of $V$), and $V'(x_0)=0$ because $x_0$ is an extremum. Keeping
only the surviving term, $V(x)\approx\tfrac12V''(x_0)(x-x_0)^2+\text{const}$,
which is a spring potential with $k_s\equiv V''(x_0)$. The force is
$F=-dV/dx = -V''(x_0)(x-x_0)$, and Newton's second law gives
$m\ddot u = -V''(x_0)u$ for $u=x-x_0$, i.e. $\ddot u=-(V''(x_0)/m)u$.
Matching to $\ddot u=-\omega_0^2u$ gives $\omega_0=\sqrt{V''(x_0)/m}$.

**2.** $\ddot x(t) = -A\omega_0^2\cos\omega_0t - B\omega_0^2\sin\omega_0t =
-\omega_0^2\big(A\cos\omega_0t+B\sin\omega_0t\big) = -\omega_0^2x(t)$ for
any $A,B$ — confirmed. At $t=0$: $x(0)=A\cos0+B\sin0=A$, so $A=x(0)$.
Differentiating, $\dot x(t)=-A\omega_0\sin\omega_0t+B\omega_0\cos\omega_0t$,
so $\dot x(0)=B\omega_0$, giving $B=\dot x(0)/\omega_0$.

**3.** **(a) Parallel.** Displacing the mass by $x$ stretches one spring by
$x$ and compresses the other by $x$ (they sit on opposite sides), so each
contributes a restoring force $-k_{s1}x$ and $-k_{s2}x$; the total is
$F=-(k_{s1}+k_{s2})x$, matching $-k_{s,\text{eff}}x$ with $k_{s,\text{eff}}=k_{s1}+k_{s2}$.
So $\omega_0=\sqrt{(k_{s1}+k_{s2})/m}$.
**(b) Series.** Let the (massless) junction between the springs sit at
displacement $y$ when the mass is at $x$. The same force $F$ is transmitted
through both springs (a massless junction in equilibrium feels no net
force, so the two spring tensions must be equal): $F=-k_{s1}y=-k_{s2}(x-y)$.
Solving for $y$ from the first equality, $y=-F/k_{s1}$; substituting into the
second, $F = -k_{s2}\big(x+F/k_{s1}\big) \implies F\big(1+k_{s2}/k_{s1}\big) = -k_{s2}x
\implies F = -\dfrac{k_{s1}k_{s2}}{k_{s1}+k_{s2}}x$. So $k_{s,\text{eff}}=k_{s1}k_{s2}/(k_{s1}+k_{s2})$
and $\omega_0=\sqrt{k_{s1}k_{s2}/\big(m(k_{s1}+k_{s2})\big)}$ — smaller than either
individual spring's own frequency with $m$, since series springs are more
compliant (softer) than either alone.

**4.** Substitute $\theta=s/l$: $V(s) = mgl\big(1-\cos(s/l)\big)$. This is
an ordinary function of the position coordinate $s$, and
$m\ddot s=F_{\text{tangential}}=-dV/ds$ is exactly Newton's second law for
a particle of mass $m$ moving along the coordinate $s$ — so today's
universality result applies directly to $V(s)$ with "mass" $m$ (no moment
of inertia needed, because $s$ was defined as an actual arc-length
position, not an angle). Compute $V'(s) = mgl\cdot\sin(s/l)\cdot(1/l) =
mg\sin(s/l)$, and $V''(s) = mg\cos(s/l)\cdot(1/l) = (mg/l)\cos(s/l)$. At the
equilibrium $s=0$: $V''(0)=mg/l$. So
$$\omega_0 = \sqrt{\frac{V''(0)}{m}} = \sqrt{\frac{mg/l}{m}} =
\sqrt{\frac gl}, \qquad T = \frac{2\pi}{\omega_0} = 2\pi\sqrt{\frac lg},$$
the standard small-angle pendulum period, recovered here purely from the
Taylor-expansion-about-a-minimum argument rather than a separate rotational
derivation.

**5.** Write the drive as the real part of $f_0e^{i\omega_dt}$ and seek a
steady-state response $x(t)=\mathrm{Re}[\tilde Xe^{i\omega_dt}]$ for
complex $\tilde X$. Substituting the complex trajectory
$z(t)=\tilde Xe^{i\omega_dt}$ into the complex version of the ODE
($\dot z=i\omega_dz$, $\ddot z=-\omega_d^2z$):
$$\big(-\omega_d^2+2i\beta\omega_d+\omega_0^2\big)\tilde X = f_0 \implies
\tilde X = \frac{f_0}{(\omega_0^2-\omega_d^2)+2i\beta\omega_d}.$$
Write the denominator $D=(\omega_0^2-\omega_d^2)+2i\beta\omega_d$ in polar
form $D=Re^{i\delta}$ with $\tan\delta = \mathrm{Im}(D)/\mathrm{Re}(D) =
2\beta\omega_d/(\omega_0^2-\omega_d^2)$. Then $\tilde X = (f_0/R)e^{-i\delta}$,
so $x(t)=\mathrm{Re}\big[(f_0/R)e^{-i\delta}e^{i\omega_dt}\big] =
(f_0/R)\cos(\omega_dt-\delta)$ — the drive leads the response by $\delta$.
Regimes: for $\omega_d\ll\omega_0$, $\omega_0^2-\omega_d^2>0$ and large, so
$\tan\delta\to0^+$, $\delta\to0$ (in-phase tracking); for $\omega_d=\omega_0$
the denominator's real part vanishes, so $\tan\delta\to\infty$, $\delta=90°$
regardless of $\beta$; for $\omega_d\gg\omega_0$, $\omega_0^2-\omega_d^2$ is
large and negative, so $\tan\delta\to0^-$ from the correct branch, giving
$\delta\to180°$ (response opposes the drive).

## Connection to QM

The quantum harmonic oscillator (Day 17) inherits today's classical result
wholesale: the same $\omega_0=\sqrt{k_s/m}$ (or $\sqrt{V''(x_0)/m}$ for a
Taylor-expanded well) reappears as the energy-level spacing $\hbar\omega_0$
between adjacent quantum states — the discreteness is new, but the
frequency that sets its scale is exactly today's frequency, unchanged.
Every photon is a quantum of a single electromagnetic field mode that *is*
this oscillator, which is why "quantizing the harmonic oscillator" is the
first real calculation of quantum field theory and quantum optics alike.
And the course's ladder-operator algebra ($a$, $a^\dagger$, and the
commutator $[a,a^\dagger]=1$) is today's complex-exponential trick promoted
from a scalar computation to an operator one: today you multiplied a
complex number by $i\omega$ to differentiate it; there, you'll act with an
operator that raises or lowers an energy quantum, built from exactly the
same $x$ and $\dot x$ (or $p$) combination you used today, packaged the
same complex way.
