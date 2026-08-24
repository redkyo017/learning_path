# Day 5 — From Oscillators to Waves

## Learning objectives

By the end of today you should be able to:
- Derive the wave equation for a string, $\partial_t^2 y = v^2\partial_x^2 y$,
  from Newton's second law applied to a small mass element under tension.
- Verify, by direct chain-rule differentiation, that any twice-differentiable
  $f(x-vt)$ (and $g(x+vt)$) solves the wave equation, and state what
  $f(x-vt)$ represents physically.
- Work fluently with the relations $k=2\pi/\lambda$, $\omega=2\pi f$,
  $v_{\mathrm{ph}}=\omega/k$ for a sinusoidal wave
  $y=A\cos(kx-\omega t)$, converting between any two of
  $\{\lambda, f, v_{\mathrm{ph}}, k, \omega\}$.
- Find the two normal-mode frequencies of two coupled oscillators
  (symmetric and antisymmetric), both via a linear ansatz and via the
  faster add/subtract normal-coordinate shortcut.
- State what a dispersion relation $\omega(k)$ is, derive the ideal
  string's $\omega=vk$, and explain what "dispersive" means using a
  second example.
- Compute the average power transmitted by a sinusoidal wave on a string.

Time budget: ~3.5 hours.

## Reference material

- French, A.P., *Vibrations and Waves* — the chapters on wave motion on a
  string and on coupled oscillators cover exactly today's material, with
  many additional worked examples.
- Halliday, Resnick & Walker, *Fundamentals of Physics* — the chapters on
  transverse waves (wave speed on a string, sinusoidal waves, energy
  transport) cover the same ground with a more numerical, plug-and-chug
  flavor; useful for extra practice once today's derivations feel routine.
- This file is self-contained: everything you need is derived below.
- Builds on Day 3's SHM machinery: $x(t)=A\cos(\omega_0 t+\phi)$ with
  $\omega_0=\sqrt{k_s/m}$, and the complex-exponential ansatz for solving
  linear oscillator equations — both reused directly in today's
  coupled-oscillator analysis. Nothing beyond Day 3 is assumed.

## Theory

### Two coupled oscillators: normal modes

Consider two identical masses $m$, each attached to a wall by a spring of
constant $k_s$, and to each other by a third, *coupling* spring of
constant $k_c$ (kept notationally distinct from both $k_s$ and the wave
number $k$ introduced later today). Let $x_1, x_2$ be each mass's
displacement from its own equilibrium position. Newton's second law for
each mass, including the force each spring exerts, gives the coupled
equations of motion:
$$m\ddot x_1 = -k_sx_1 - k_c(x_1-x_2), \qquad m\ddot x_2 = -k_sx_2 - k_c(x_2-x_1).$$
Each mass feels its own wall spring plus the coupling spring's force,
which depends on the *relative* displacement $x_1-x_2$ (the coupling
spring pulls mass 1 toward mass 2 in proportion to how much farther out
mass 1 is, and vice versa).

**Solving by ansatz.** Following Day 3's complex-exponential method, try
$x_1(t)=A_1e^{i\omega t}$, $x_2(t)=A_2e^{i\omega t}$ for some common
frequency $\omega$ (physical displacements are the real parts, but since
both equations are linear with real coefficients, the complex algebra goes
through unchanged and we recover real solutions at the end). Substituting
and canceling the common factor $e^{i\omega t}$:
$$-m\omega^2A_1 = -k_sA_1-k_c(A_1-A_2), \qquad -m\omega^2A_2 = -k_sA_2-k_c(A_2-A_1),$$
which rearranges to the linear system
$$(k_s+k_c-m\omega^2)A_1 - k_cA_2 = 0, \qquad -k_cA_1+(k_s+k_c-m\omega^2)A_2 = 0.$$
This homogeneous system has a nontrivial solution $(A_1,A_2)\ne(0,0)$ only
if its determinant vanishes:
$$(k_s+k_c-m\omega^2)^2 - k_c^2 = 0 \quad\Longrightarrow\quad k_s+k_c-m\omega^2 = \pm k_c.$$
Two roots, two modes:
$$\textbf{Symmetric mode: } +k_c \Rightarrow m\omega^2=k_s \Rightarrow \omega_s=\sqrt{\frac{k_s}{m}},$$
$$\textbf{Antisymmetric mode: } -k_c \Rightarrow m\omega^2=k_s+2k_c \Rightarrow \omega_a=\sqrt{\frac{k_s+2k_c}{m}}.$$
Substituting each root back into the linear system shows the symmetric
root forces $A_1=A_2$ (both masses move identically), and the
antisymmetric root forces $A_1=-A_2$ (they move oppositely, same
amplitude) — hence the names.

**The faster route: normal coordinates.** The same result falls out with
no determinant at all if you add and subtract the two original equations
of motion. Adding:
$$m(\ddot x_1+\ddot x_2) = -k_s(x_1+x_2) - k_c(x_1-x_2) - k_c(x_2-x_1) = -k_s(x_1+x_2),$$
since the two coupling terms are exact negatives of each other and cancel.
Writing $s=x_1+x_2$, this is $m\ddot s=-k_ss$ — a plain, uncoupled SHM
equation with frequency $\omega_s=\sqrt{k_s/m}$, exactly the single-mass
natural frequency from Day 3. This makes physical sense: when both masses
move together ($x_1=x_2$ at all times), the coupling spring's length
never changes, so it exerts no force at all, and each mass feels only its
own wall spring.

Subtracting the two equations instead:
$$m(\ddot x_1-\ddot x_2) = -k_s(x_1-x_2) - k_c(x_1-x_2) - k_c(x_1-x_2) = -(k_s+2k_c)(x_1-x_2),$$
using $-k_c(x_1-x_2)-(-k_c(x_2-x_1))=-2k_c(x_1-x_2)$. Writing $d=x_1-x_2$,
this is $m\ddot d = -(k_s+2k_c)d$ — again plain SHM, now with frequency
$\omega_a=\sqrt{(k_s+2k_c)/m}$, matching the determinant calculation. The
coupling spring's own extension is exactly the relative displacement
$d=x_1-x_2$ itself — nothing doubled there. The factor of $2$ instead
comes from how $d$'s equation of motion is assembled: dividing each
original equation by $m$, mass 1's coupling force contributes
$-(k_c/m)\,d$ to $\ddot x_1$, while mass 2's coupling force (the same
spring, pulling the other way) contributes $+(k_c/m)\,d$ to $\ddot x_2$.
Subtracting $\ddot x_2$ from $\ddot x_1$ turns that difference into a
sum, $-(k_c/m)d - (k_c/m)d = -(2k_c/m)d$, which is exactly why $2k_c$, not
$k_c$, ends up multiplying $d$.

The quantities $s=x_1+x_2$ and $d=x_1-x_2$ are called **normal
coordinates**: each one obeys its own single, uncoupled SHM equation, even
though the original $x_1,x_2$ are coupled. This is the general moral of
coupled-oscillator problems: **$N$ coupled oscillators have $N$ normal
modes, and in each mode — expressed in the right coordinates — the whole
system swings as one big SHM at a single frequency.** Exercise 4 and
Worked Example 3 extend this idea to three masses and to two pendulums,
respectively.

### The continuum limit: the wave equation for a string

Now imagine not two or three discrete masses, but a continuous string:
mass per unit length $\mu$, stretched to tension $T_s$. (We write the
tension $T_s$, never bare $T$, specifically to avoid collision with the
kinetic energy $T$ used elsewhere in this course — a collision this
subject invites easily, since tension and energy both show up naturally
in the same paragraph once you start computing power, as we do at the end
of today's Theory.) Let $y(x,t)$ be the string's small transverse
displacement at position $x$ and time $t$, and assume the slope
$\partial y/\partial x$ stays small everywhere, so the small-angle
approximation $\sin\theta\approx\tan\theta=\partial y/\partial x$ applies
and the tension's *magnitude* $T_s$ stays essentially uniform along the
string (only its direction, tangent to the string, varies).

Isolate a short element of the string between $x$ and $x+\Delta x$, of
mass $\mu\,\Delta x$. Two tension forces act on it, one from the string
material at each end, each directed along the local tangent, pointing
away from the element. The transverse (vertical) component of the pull at
the right end is $T_s\sin\theta(x+\Delta x)\approx T_s\,\partial y/\partial
x\big|_{x+\Delta x}$; the transverse component of the pull at the left end
(pointing the other way along $x$) is $-T_s\,\partial y/\partial
x\big|_{x}$. The net transverse force on the element is therefore
$$F_y \approx T_s\left[\frac{\partial y}{\partial x}\bigg|_{x+\Delta x} - \frac{\partial y}{\partial x}\bigg|_{x}\right] \approx T_s\,\frac{\partial^2 y}{\partial x^2}\,\Delta x,$$
where the last step recognizes the bracketed difference, divided by
$\Delta x$, as exactly the definition of $\partial^2y/\partial x^2$ in the
limit $\Delta x\to0$ (a second derivative is the rate of change of a first
derivative). Newton's second law for the transverse motion of this element,
mass $\mu\,\Delta x$, is $\mu\,\Delta x\,\partial^2y/\partial t^2 = F_y$.
Dividing both sides by $\Delta x$ and taking $\Delta x\to0$:
$$\mu\,\frac{\partial^2 y}{\partial t^2} = T_s\,\frac{\partial^2 y}{\partial x^2} \quad\Longrightarrow\quad \boxed{\frac{\partial^2 y}{\partial t^2} = v^2\,\frac{\partial^2 y}{\partial x^2}}, \qquad v \equiv \sqrt{\frac{T_s}{\mu}}.$$
This is the (one-dimensional, non-dispersive) **wave equation**, derived —
not guessed — from Newton's second law on an infinitesimal element, exactly
the way Day 1's $\vec F=m\vec a$ was applied to point masses, now applied
to a continuum. The constant $v=\sqrt{T_s/\mu}$ has units of speed, as you
can check directly: $[T_s]=\text{N}=\text{kg·m/s}^2$, $[\mu]=\text{kg/m}$,
so $[T_s/\mu]=\text{m}^2/\text{s}^2$.

> **Misconception:** "wave speed depends on how hard you shake the
> string." It does not. $v=\sqrt{T_s/\mu}$ depends only on two properties
> of the *medium* — the tension it's held at and its mass per unit length
> — not on the amplitude, frequency, or vigor of whatever disturbance you
> send down it. Shake the string harder and you get a bigger-amplitude
> wave traveling at the *same* speed $v$, not a faster one. (This is a
> feature of the *linear* wave equation specifically; some strongly
> nonlinear systems really do have amplitude-dependent speeds, but the
> ideal string is not one of them.)

### The general traveling-wave solution: $f(x-vt)$ and $g(x+vt)$

Claim: for *any* twice-differentiable function $f$ of a single variable,
$y(x,t)=f(x-vt)$ solves the wave equation. Physically, $f(x-vt)$ is a
fixed spatial profile $f(u)$ that rigidly shifts to larger $x$ as $t$
increases, at speed $v$: whatever the shape looked like at $t=0$, at time
$t$ the exact same shape reappears shifted by $vt$ to the right. This is
the precise meaning of "a wave traveling in the $+x$ direction at speed
$v$," and the explicit chain-rule verification that it actually solves
$\partial_t^2y=v^2\partial_x^2y$ is carried out in Worked Example 1 below.
By an identical argument (replace $t\to-t$ in the substitution), $g(x+vt)$
solves the same equation and represents a fixed profile traveling in the
$-x$ direction at speed $v$.

Because the wave equation is **linear** — every term is a first power of
$y$ or one of its derivatives, with no products or higher powers of $y$ —
the sum of any two solutions is again a solution (this is the
*superposition principle*: substitute $y=y_1+y_2$ into
$\partial_t^2y-v^2\partial_x^2y$ and the equation splits term-by-term into
$(\partial_t^2y_1-v^2\partial_x^2y_1)+(\partial_t^2y_2-v^2\partial_x^2y_2)$,
which is $0+0=0$ if each $y_i$ individually solves it). Hence the fully
general solution of the string's wave equation is
$$y(x,t) = f(x-vt) + g(x+vt)$$
for arbitrary functions $f,g$ — a right-moving profile and a left-moving
profile, superposed. (That this exhausts *every* solution, not merely *a*
family of solutions, follows from switching coordinates to
$u=x-vt,\ w=x+vt$: by the chain rule the wave-equation operator
$\partial_t^2-v^2\partial_x^2$ becomes proportional to $\partial^2/
\partial u\,\partial w$, so the wave equation reduces to
$\partial^2y/\partial u\,\partial w=0$; integrating once in $w$ shows
$\partial y/\partial u$ can depend on $u$ alone, and integrating once
more in $u$ gives $y=f(u)+g(w)$ for some single-variable functions $f,g$
— exactly the general solution above, with nothing left over. We will not
belabor this change of variables further; what matters today is that the
family $f(x-vt)+g(x+vt)$ solves the equation and is rich enough to build
every wave you'll meet.)

> **Misconception:** "the medium travels along with the wave." It does
> not. Each point of the string oscillates transversally *in place*,
> moving only in $y$, never in $x$ — you can watch a single grain of dust
> glued to the string and it will never migrate down the string's length.
> What propagates in the $x$-direction is the *pattern* $f(x-vt)$: the
> particular value of displacement $y$ found at a given point right now
> will be found a little farther along a moment later, but no piece of
> string material makes that trip. (Ocean waves are the everyday version
> of this: a floating buoy mostly bobs up and down in place as a swell
> passes, not surfing along with it — real water adds some small circular
> drift on top of this idealized picture, but the core transverse-only
> motion is the same.)

### Sinusoidal waves: $k$, $\omega$, $\lambda$, $f$, and phase velocity

The most important special case of $f(x-vt)$ is the sinusoidal wave
$$y(x,t) = A\cos(kx-\omega t),$$
which is exactly $f(u)=A\cos(ku)$ evaluated at $u=x-vt$, *provided*
$k(x-vt)=kx-(kv)t$ matches $kx-\omega t$, i.e. provided $\omega = kv$. The
constant $k$ is called the **wave number**; despite the shared letter, it
has nothing to do with any spring constant (written $k_s$ throughout this
course precisely to keep the two apart).

**Wavelength.** $\lambda$ is defined as the spatial period: the smallest
positive shift in $x$ that reproduces the same displacement pattern at
every fixed $t$, i.e. $y(x+\lambda,t)=y(x,t)$ for all $x,t$. Since cosine
has period $2\pi$, this requires $k\lambda = 2\pi$, giving
$$k = \frac{2\pi}{\lambda}.$$

**Frequency.** The frequency $f$ is the number of cycles per second, so
one full cycle takes $1/f$ seconds; requiring $\omega\cdot(1/f)=2\pi$ (one
full cycle of the cosine advances its phase by exactly $2\pi$, the same
periodicity argument used for $\lambda$ above, now applied in time instead
of space) gives
$$\omega = 2\pi f.$$

**Phase velocity.** Fix attention on a single point of constant phase,
$kx-\omega t = \text{const}$ — say, always sitting on a wave crest.
Differentiating this constraint with respect to $t$ (treating $x$ as the
position of that particular crest, which moves as $t$ advances):
$$k\,\frac{dx}{dt} - \omega = 0 \quad\Longrightarrow\quad \frac{dx}{dt} = \frac{\omega}{k} \equiv v_{\mathrm{ph}}.$$
This is the **phase velocity**: the speed at which a point of fixed phase
(a crest, a trough, a zero-crossing) travels. For the sinusoidal wave to
match $f(x-vt)$ at all, we needed $\omega=kv$ above, so $v_{\mathrm{ph}} =
\omega/k = v$ — the phase velocity of a sinusoidal wave on an ideal string
*is* the same wave speed $v=\sqrt{T_s/\mu}$ derived from Newton's law,
for every choice of $k$ (a fact revisited, and shown to be special, in
the very next subsection).

**The traveling-phase picture.** The misconception callout above already
warned that no string material actually travels; what "travels," precisely,
is the phase $kx-\omega t$ (or equivalently, the location of any chosen
crest). Holding the phase fixed and solving for $x(t)$ as above is the
cleanest way to see this: it is a *statement about the phase*,
$dx/dt=\omega/k$, not a statement about any particle's velocity — a
string element's own transverse velocity is $\partial y/\partial t$, an
entirely different quantity (used again in the energy-transport
subsection below).

### Dispersion relations

For the sinusoidal wave $y=A\cos(kx-\omega t)$ to actually solve the
string's wave equation $\partial_t^2y=v^2\partial_x^2y$, substitute
directly:
$$\frac{\partial^2 y}{\partial t^2} = -\omega^2A\cos(kx-\omega t), \qquad \frac{\partial^2 y}{\partial x^2} = -k^2A\cos(kx-\omega t).$$
Equating $-\omega^2 = v^2(-k^2)$ (the common factor $A\cos(kx-\omega t)$
cancels) gives
$$\omega^2 = v^2k^2 \quad\Longrightarrow\quad \omega = vk \qquad (v=\sqrt{T_s/\mu}\text{ fixed, taking the positive root}).$$
A relation of the form $\omega=\omega(k)$, giving the frequency that a
wave of a given wave number *must* have in order to solve the governing
equation, is called a **dispersion relation**. For the ideal string, the
dispersion relation $\omega=vk$ is *linear* in $k$: every wave number
propagates at the identical phase velocity $v_{\mathrm{ph}}=\omega/k=v$,
independent of $k$. A system with this property — phase velocity
independent of wavelength — is called **non-dispersive**.

Not every wave-supporting system is like this. In general $\omega(k)$ can
be any function determined by the system's own governing equation, and
whenever $v_{\mathrm{ph}}=\omega(k)/k$ actually depends on $k$, different
wavelengths travel at different speeds — the system is **dispersive**.
Exercise 5 works a concrete dispersive example (deep-water waves,
$\omega=\sqrt{gk}$). Why this distinction matters enormously going
forward: Day 7 defines the *group velocity* $v_g=d\omega/dk$, the speed at
which a localized wave *packet* (a superposition of many wave numbers)
actually travels — for a non-dispersive system $v_g=v_{\mathrm{ph}}$
always (differentiate $\omega=vk$: $d\omega/dk=v$), so the distinction is
invisible on the ideal string; for a dispersive system the two speeds
differ, and packets change shape as they propagate. Day 16 will meet a
dispersion relation of a completely different character,
$\omega\propto k^2$, for matter waves — see Connection to QM below.

### Energy transport on a string

A sinusoidal wave carries energy along the string even though no material
travels (per the misconception above). To see how much, and how fast,
consider the point at coordinate $x$ dividing the string into a "left"
piece and a "right" piece. By the same tension analysis used to derive the
wave equation, the transverse force that the left piece exerts on the
right piece, at the cut point $x$, is $F_y(x,t) = -T_s\,\partial y/\partial
x(x,t)$ (the transverse component of the tension pull, in the small-slope
approximation used throughout today, with the sign fixed by the
requirement that tension always acts to restore the string toward
straightness). The instantaneous **power** delivered by the left piece to
the right piece — the rate at which the left piece does work on the point
at $x$ — is this force times that point's own transverse velocity,
$\partial y/\partial t$:
$$P(x,t) = -T_s\,\frac{\partial y}{\partial x}\,\frac{\partial y}{\partial t}.$$

For the sinusoidal wave $y=A\cos(kx-\omega t)$:
$$\frac{\partial y}{\partial x} = -Ak\sin(kx-\omega t), \qquad \frac{\partial y}{\partial t} = A\omega\sin(kx-\omega t),$$
so
$$P(x,t) = -T_s\big(-Ak\sin(kx-\omega t)\big)\big(A\omega\sin(kx-\omega t)\big) = T_sA^2k\omega\sin^2(kx-\omega t).$$
Averaging over a full cycle, using $\langle\sin^2\rangle=\tfrac12$:
$$\langle P\rangle = \tfrac12\,T_sA^2k\omega.$$
Substituting $T_s=\mu v^2$ and $k=\omega/v$ (both established above):
$$T_sk\omega = \mu v^2\cdot\frac{\omega}{v}\cdot\omega = \mu v\omega^2 \quad\Longrightarrow\quad \boxed{\langle P\rangle = \tfrac12\,\mu v\,\omega^2A^2}.$$
Energy transport scales as the *square* of the amplitude and the *square*
of the frequency — doubling either one quadruples the average power
carried, a useful rule of thumb whenever comparing two waves on the same
string.

## Worked examples

**1. Verifying $y=f(x-vt)$ solves the wave equation, by explicit chain
rule.** Let $u \equiv x-vt$, so $y(x,t)=f(u)$ for an arbitrary
twice-differentiable $f$. By the chain rule,
$$\frac{\partial y}{\partial x} = f'(u)\,\frac{\partial u}{\partial x} = f'(u)\cdot 1 = f'(u), \qquad \frac{\partial^2 y}{\partial x^2} = f''(u)\cdot 1 = f''(u).$$
For the time derivatives, $\partial u/\partial t = -v$, so
$$\frac{\partial y}{\partial t} = f'(u)\,\frac{\partial u}{\partial t} = -v f'(u).$$
Differentiating again with respect to $t$ (product rule is not needed
since $-v$ is constant; only $f'(u)$ depends on $t$, again through $u$):
$$\frac{\partial^2 y}{\partial t^2} = -v\,\frac{\partial}{\partial t}\big[f'(u)\big] = -v\,f''(u)\,\frac{\partial u}{\partial t} = -v\,f''(u)\,(-v) = v^2f''(u).$$
Comparing the two results: $\partial_t^2y = v^2f''(u) = v^2\,\partial_x^2y$ —
exactly the wave equation, for *any* choice of $f$, confirmed by direct
differentiation with no assumption about $f$'s specific form. The
identical computation with $u=x+vt$ (so $\partial u/\partial t=+v$ instead
of $-v$) gives $\partial_t^2y = (+v)^2g''(u) = v^2\partial_x^2y$ as well —
the sign flip in $\partial u/\partial t$ gets squared away, which is
exactly why *both* $f(x-vt)$ and $g(x+vt)$ solve the same equation despite
representing opposite directions of travel.

**2. Guitar string: wave speed and fundamental frequency.** A guitar's
low string has tension $T_s=80\text{ N}$, linear mass density
$\mu=5\text{ g/m}=0.005\text{ kg/m}$, and vibrating length
$L=0.65\text{ m}$ (here $L$ is a length — not Day 4's angular momentum).
The wave speed is
$$v = \sqrt{\frac{T_s}{\mu}} = \sqrt{\frac{80}{0.005}} = \sqrt{16000} \approx 126.5\text{ m/s}.$$
A string fixed at both ends supports a standing wave only when the length
fits a half-integer number of wavelengths; the lowest (fundamental) case
fits exactly half a wavelength along the string, $\lambda_1 = 2L$ (this is
used here informally as a boundary-condition fact from ordinary
observation of standing waves; Day 6 derives it properly as a consequence
of requiring $y=0$ at both fixed ends). Here $\lambda_1 = 2(0.65) =
1.30\text{ m}$, so
$$f_1 = \frac{v}{\lambda_1} = \frac{126.5}{1.30} \approx 97.3\text{ Hz}.$$
This is in the right ballpark for a guitar's lowest open string (the
standard low E is $82.4\text{ Hz}$; the round numbers chosen here are for
clean arithmetic, not an exact string spec) — a useful sanity check that
the formula is being used correctly, not just algebraically.

**3. Two coupled pendulums: both mode frequencies.** Two identical simple
pendulums, each of mass $m=0.5\text{ kg}$ and length $L=1\text{ m}$, hang
side by side and are connected, at the height of their bobs, by a light
spring of constant $k_c=2\text{ N/m}$. For small swings, each pendulum
bob's horizontal displacement $x_i \approx L\theta_i$ obeys the same
linearized equation as a mass on a spring of effective constant $mg/L$
(the standard small-angle pendulum result), plus the coupling-spring
force exactly as in the two-mass problem above:
$$m\ddot x_1 = -\frac{mg}{L}x_1 - k_c(x_1-x_2), \qquad m\ddot x_2 = -\frac{mg}{L}x_2 - k_c(x_2-x_1).$$
This is *algebraically identical* to the two-coupled-oscillator system
derived in Theory, with $k_s\to mg/L$. Reusing that result directly:
$$\omega_s = \sqrt{\frac{g}{L}} = \sqrt{\frac{9.8}{1}} \approx 3.13\text{ rad/s} \qquad\text{(symmetric: both bobs swing in phase)},$$
$$\omega_a = \sqrt{\frac{g}{L}+\frac{2k_c}{m}} = \sqrt{9.8 + \frac{2(2)}{0.5}} = \sqrt{9.8+8} = \sqrt{17.8} \approx 4.22\text{ rad/s} \qquad\text{(antisymmetric: bobs swing oppositely)}.$$
As a check, the symmetric mode's frequency depends only on $g/L$, with no
trace of $k_c$ — exactly as expected, since when both pendulums swing
together in step, the connecting spring never stretches and might as well
not be there.

## Exercises

Attempt every problem closed-book before checking the Hints, and only
then the Solutions.

**Retrieval**

1. Starting from Newton's second law applied to a small element of
   string (mass $\mu\,\Delta x$) under tension $T_s$, derive the wave
   equation $\partial_t^2y = v^2\partial_x^2y$ and identify $v$ in terms
   of $T_s$ and $\mu$.
2. A wave on a string is described (SI units) by
   $y(x,t) = 0.02\cos(4\pi x - 200\pi t)$. Extract the wavelength
   $\lambda$, frequency $f$, phase velocity $v_{\mathrm{ph}}$, and
   direction of travel.

**Standard**

3. A long sinusoidal wave train of frequency $f$ travels along a string
   of mass density $\mu_1$, which is joined end-to-end to a second string
   of a different mass density $\mu_2$, both under the same tension
   $T_s$. As the wave crosses the joint onto the second string, which of
   $f$, $\lambda$, $v_{\mathrm{ph}}$ stay fixed and which change, and why?
   (State the physical reason each quantity does or doesn't change, not
   just the algebra.)
4. Three identical masses $m$ are connected in a line by four identical
   springs of constant $k_c$: one from a wall to mass 1, one from mass 1
   to mass 2, one from mass 2 to mass 3, and one from mass 3 to a second
   wall. Write the three equations of motion, then verify by direct
   substitution that $x_1(t)=A\cos\omega t$, $x_2(t)=0$,
   $x_3(t)=-A\cos\omega t$ solves all three simultaneously for a specific
   $\omega$, and find that $\omega$.

**Stretch**

5. A deep-water surface wave has dispersion relation $\omega=\sqrt{gk}$
   ($g$ = gravitational acceleration). Compute $v_{\mathrm{ph}}(k)$ and
   determine whether longer or shorter wavelengths travel faster. In one
   paragraph, explain why this makes a localized wave *packet* (many
   wavelengths superposed) behave differently from a single sinusoidal
   wave over time.

## Hints

1. Balance the transverse tension forces at the two ends of the element
   using the small-slope approximation $\sin\theta\approx\partial y/
   \partial x$; the difference of the two ends' slopes, divided by
   $\Delta x$, becomes a second derivative in the $\Delta x\to0$ limit.
2. Match $y=0.02\cos(4\pi x-200\pi t)$ term-by-term against
   $A\cos(kx-\omega t)$ to read off $k$ and $\omega$ directly, then apply
   $k=2\pi/\lambda$, $\omega=2\pi f$, $v_{\mathrm{ph}}=\omega/k$.
3. Think about what boundary condition the joint itself imposes on both
   strings simultaneously — one quantity has to match on both sides of
   the joint at every instant, or the string would tear apart or overlap.
4. Write $m\ddot x_i=$ (sum of spring forces on mass $i$) for each $i$
   separately, exactly as in the two-mass case but now with three masses
   and four springs; then just substitute the given $x_1,x_2,x_3$ into
   each equation and see what $\omega$ makes it balance (note $x_2\equiv0$
   simplifies the middle equation immediately).
5. Divide $\omega=\sqrt{gk}$ by $k$ to get $v_{\mathrm{ph}}(k)$, then ask
   how $v_{\mathrm{ph}}$ changes as $k$ decreases (recall $k=2\pi/\lambda$,
   so small $k$ means long $\lambda$).

## Solutions

**1.** Take a string element between $x$ and $x+\Delta x$, mass
$\mu\,\Delta x$. Tension $T_s$ pulls at each end along the local tangent;
using $\sin\theta\approx\partial y/\partial x$ for small slopes, the net
transverse force is
$$F_y \approx T_s\left[\frac{\partial y}{\partial x}\bigg|_{x+\Delta x}-\frac{\partial y}{\partial x}\bigg|_x\right] \approx T_s\frac{\partial^2y}{\partial x^2}\,\Delta x$$
in the limit $\Delta x\to0$ (the bracketed quantity divided by $\Delta x$
is exactly the definition of the second $x$-derivative). Newton's second
law, $\mu\,\Delta x\,\partial_t^2y = F_y$, gives, after dividing by
$\Delta x$,
$$\mu\,\partial_t^2y = T_s\,\partial_x^2y \quad\Longrightarrow\quad \partial_t^2y = v^2\partial_x^2y, \qquad v=\sqrt{T_s/\mu}.$$

**2.** Matching against $A\cos(kx-\omega t)$: $A=0.02\text{ m}$,
$k=4\pi\text{ rad/m}$, $\omega=200\pi\text{ rad/s}$. Then
$$\lambda = \frac{2\pi}{k} = \frac{2\pi}{4\pi} = 0.5\text{ m}, \qquad f = \frac{\omega}{2\pi} = \frac{200\pi}{2\pi} = 100\text{ Hz}, \qquad v_{\mathrm{ph}} = \frac{\omega}{k} = \frac{200\pi}{4\pi} = 50\text{ m/s}.$$
(Check: $\lambda f = 0.5\times100=50\text{ m/s}$, matching $v_{\mathrm{ph}}$
independently.) Since the wave has the form $\cos(kx-\omega t)$ —
i.e. $f(x-v_{\mathrm{ph}}t)$ with $v_{\mathrm{ph}}>0$ — it travels in the
**$+x$ direction**.

**3.** The tension $T_s$ is continuous along the whole joined string (it
is one physical string under one overall tension, just with a change of
material at the joint), but $\mu$ differs on the two sides, so
$v=\sqrt{T_s/\mu}$ **changes** at the joint (larger $\mu_2$ means smaller
$v$ on that side, and vice versa). The frequency $f$ **stays fixed**
across the joint: the joint itself must move with a single, unambiguous
transverse displacement at each instant (the two strings are tied
together there), so whatever oscillation frequency is imposed at the
joint is shared by both sides — a boundary condition, not a
consequence of the wave equation on either side alone. Since $v=f\lambda$
on each side and $f$ is common but $v$ differs, $\lambda$ **must also
change**, in exact proportion to $v$ (the side with smaller $\mu$, hence
larger $v$, has the longer wavelength for the same $f$).

**4.** Newton's second law on each mass, including its two neighboring
spring forces (mass 1 and mass 3 each also feel one wall spring):
$$m\ddot x_1 = -k_cx_1 - k_c(x_1-x_2) = -k_c(2x_1-x_2),$$
$$m\ddot x_2 = -k_c(x_2-x_1) - k_c(x_2-x_3) = -k_c(-x_1+2x_2-x_3),$$
$$m\ddot x_3 = -k_c(x_3-x_2) - k_cx_3 = -k_c(2x_3-x_2).$$
Substitute $x_1=A\cos\omega t$, $x_2=0$, $x_3=-A\cos\omega t$ (so
$\ddot x_1=-\omega^2A\cos\omega t$, $\ddot x_2=0$, $\ddot x_3=\omega^2A\cos\omega t$):

*Equation 1:* $m(-\omega^2A) = -k_c(2A-0) \Rightarrow -m\omega^2A=-2k_cA \Rightarrow \omega^2=\dfrac{2k_c}{m}$.

*Equation 2:* LHS $=m\ddot x_2=0$. RHS $=-k_c(-x_1+2x_2-x_3)=-k_c(-x_1-x_3)$
since $x_2\equiv0$, and in this mode $x_1+x_3=A\cos\omega t+(-A\cos\omega
t)=0$ at every instant, so RHS $=-k_c\cdot0=0$ too. Both sides are
identically $0$ at every instant, so this equation is satisfied
automatically, for any $\omega$ — consistent with $x_2\equiv0$ requiring
no restoring dynamics of its own in this particular mode, precisely
because $x_1$ and $x_3$ always cancel.

*Equation 3:* $m(\omega^2A) = -k_c(2(-A)-0) = 2k_cA \Rightarrow m\omega^2A=2k_cA \Rightarrow \omega^2=\dfrac{2k_c}{m}$,
matching Equation 1 exactly.

All three equations are satisfied by the same single value
$$\omega = \sqrt{\frac{2k_c}{m}}.$$
Physically, this is the mode where the outer masses swing in exact
opposition while the middle mass stays motionless — the middle mass sits
at a node of this particular collective oscillation, which is why
$x_2\equiv0$ is a consistent (not merely assumed) solution: with $x_2$
pinned at $0$, its own equation reduces to a trivial $0=0$ identity rather
than constraining $\omega$ at all, and the two outer equations agree with
each other on the one value of $\omega$ that works.

**5.** $v_{\mathrm{ph}}(k) = \dfrac{\omega}{k} = \dfrac{\sqrt{gk}}{k} =
\sqrt{\dfrac{g}{k}}$. This is a *decreasing* function of $k$, so as
$k=2\pi/\lambda$ decreases — i.e. as $\lambda$ grows — $v_{\mathrm{ph}}$
increases: **longer wavelengths travel faster** on deep water (this is
the real reason a distant storm's long-period swell reliably outruns and
arrives ahead of its shorter, choppier wind waves). *Why this matters for
packets:* a localized disturbance is not one pure wavelength but a
superposition of many $k$'s (Day 7 makes this precise via Fourier
synthesis); on a non-dispersive string, every one of those components
would travel at the identical speed $v$, so the whole superposition
glides along rigidly, unchanged in shape. Here, because
$v_{\mathrm{ph}}(k)$ genuinely depends on $k$, the long-wavelength
components of any localized packet systematically pull ahead of the
short-wavelength components, so the packet doesn't just translate — it
visibly spreads and reshapes as it travels, a phenomenon with no
counterpart on the ideal string and the entire reason Day 7 needs a
*second* velocity (the group velocity) to describe how a packet as a
whole actually moves.

## Connection to QM

The Schrödinger equation is, formally, a wave equation for matter — but
one with a strikingly different character from today's string equation in
two specific ways, both of which trace directly back to today's
machinery. First, it is *first-order* in time
($i\hbar\,\partial\psi/\partial t = -\frac{\hbar^2}{2m}\partial^2\psi/
\partial x^2 + V\psi$), unlike the string's second-order
$\partial_t^2y=v^2\partial_x^2y$. Second, substituting a plane wave
$\psi\propto e^{i(kx-\omega t)}$ into the free-particle Schrödinger
equation ($V=0$) gives the dispersion relation $\omega = \hbar k^2/2m$ —
quadratic in $k$, in sharp contrast to the string's linear $\omega=vk$.
This is precisely a *dispersive* system in today's sense, and Exercise 5's
lesson about wave packets applies directly: because $v_{\mathrm{ph}}=
\omega/k=\hbar k/2m$ depends on $k$, a localized quantum wave packet
(built from many momentum components $p=\hbar k$, exactly as a real
particle's position must be at least somewhat localized) inevitably
spreads over time, in a way an ideal string's non-dispersive pulse never
does. This spreading is not a minor mathematical curiosity — it is one of
the qualitatively new features Day 16 will need to explain, and its root
cause is nothing more exotic than "the dispersion relation is nonlinear in
$k$," a concept introduced today.

Today's other central idea — "$N$ coupled oscillators have $N$ normal
modes, each one big SHM" — also returns essentially unchanged in the
quantum theory, in the guise of quantum field theory's statement that
"each field mode is one quantum harmonic oscillator." There, an
electromagnetic field (or any other field) is decomposed into normal
modes exactly as today's two masses were decomposed into symmetric and
antisymmetric coordinates, except the number of modes is infinite instead
of two or three; each mode then gets quantized as an independent quantum
oscillator, and a "photon" turns out to be one quantum of excitation of
one such mode. The two-mass and three-mass problems worked today are, in
this precise sense, the smallest possible toy versions of the normal-mode
decomposition that underlies all of quantum field theory.
