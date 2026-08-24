# Day 7 — Fourier Intuition and Wave Packets

## Learning objectives

By the end of today you should be able to:
- Explain why decomposing a shape into the string's normal modes (Day 6) is
  an expansion in an orthogonal basis, and name the inner product that
  makes the modes orthogonal.
- Compute the Fourier sine-series coefficients of a square wave by direct
  integration, and explain the $1/n$ falloff and the Gibbs overshoot in
  words.
- Describe, at an honest intuition level, how a discrete sum over modes
  becomes an integral over a continuous band of wavenumbers $k$ — the
  Fourier transform — and build a localized wave packet from a narrow band
  of $k$'s.
- Derive the group velocity $v_g = d\omega/dk$ from the beat pattern of two
  superposed nearby-frequency waves, and contrast it with the phase
  velocity $v_{\mathrm{ph}}=\omega/k$.
- State the bandwidth theorem $\Delta x\,\Delta k \gtrsim 1$, derive the
  exact Gaussian equality case $\Delta x\,\Delta k = \tfrac12$, and apply it
  to everyday (non-quantum) examples.
- Explain why a nonlinear dispersion relation $\omega(k)$ makes a wave
  packet spread out in time, and predict simulation behavior from that fact
  before running it.

Time budget: ~3.5 hours.

## Reference material

- French, *Vibrations and Waves*, the chapter on Fourier analysis of
  periodic waveforms together with the chapter on wave groups and group
  velocity — the two chapters together are almost exactly today's syllabus,
  written by the same author whose oscillator chapters you used on Day 3.
- Eisberg & Resnick, *Quantum Physics of Atoms, Molecules, Solids, Nuclei,
  and Particles*, the early chapter that builds wave packets and group
  velocity classically, before ever introducing $\hbar$ — the closest match
  to today's "classical wave facts that quantum mechanics will later relabel"
  framing, and a preview of the reference you'll lean on again around Day 16.
- This file is self-contained: every equation below is derived or motivated
  in-line, so neither text is required to do today's work.
- Builds on **Day 5** (the wave equation and the concept of a dispersion
  relation $\omega(k)$ relating frequency to wavenumber) and **Day 6**
  (superposition, beats, and the standing-wave mode basis $k_n=n\pi/L$ on a
  fixed string).

## Theory

### The string's modes as an orthogonal basis

Day 6 showed that a string of length $L$ fixed at both ends supports
standing-wave modes $\sin(k_nx)$ with $k_n=n\pi/L$, $n=1,2,3,\dots$, and that
any allowed shape of the string is some superposition of these modes. This
is *exactly* the linear-algebra idea of expanding a vector in an orthogonal
basis, transplanted from $\mathbb{R}^n$ to a space of functions: the "vectors"
are now functions on $[0,L]$, and the role of the dot product is played by
the integral
$$\langle f,g\rangle \equiv \int_0^L f(x)g(x)\,dx.$$
Direct computation confirms the modes are mutually orthogonal under this
inner product: for $n\ne m$,
$$\int_0^L \sin(k_nx)\sin(k_mx)\,dx = 0,$$
(a standard product-to-sum identity reduces the integrand to a sum of
$\cos\big((n-m)\pi x/L\big)$ and $\cos\big((n+m)\pi x/L\big)$ terms, each of
which integrates to zero over $[0,L]$ whenever its argument's coefficient is
a nonzero integer multiple of $\pi/L$), while for $n=m$,
$$\int_0^L \sin^2(k_nx)\,dx = \frac{L}{2}$$
(using $\sin^2\theta=\tfrac12(1-\cos2\theta)$; the $\cos2\theta$ part
integrates to zero over the full length, leaving just the constant $\tfrac12$
times $L$). So $\{\sin(k_nx)\}$ is an orthogonal (not orthonormal, unless you
divide by $\sqrt{L/2}$) basis, exactly as $\{e_1,\dots,e_n\}$ is an
orthonormal basis of $\mathbb{R}^n$. Writing any reasonable shape $f(x)$ as
$$f(x) = \sum_{n=1}^{\infty} b_n \sin(k_nx)$$
is a **Fourier sine series**, and the coefficients are extracted by the same
trick you'd use in $\mathbb{R}^n$ — take the inner product with one basis
function and use orthogonality to kill every term but one:
$$\int_0^L f(x)\sin(k_mx)\,dx = \sum_n b_n\int_0^L\sin(k_nx)\sin(k_mx)\,dx =
b_m\cdot\frac{L}{2} \implies b_m = \frac{2}{L}\int_0^L f(x)\sin(k_mx)\,dx.$$
This is projecting $f$ onto each basis direction and reading off the
coefficient — nothing new conceptually beyond what you already know from
linear algebra, just carried out with an integral standing in for a finite
sum.

### One honest computation: the square wave

The clearest classic example is a **square wave**: a periodic function that
is $+1$ on one half of each period and $-1$ on the other, with genuine jump
discontinuities. Take period $2L$, so $f(x)=+1$ for $0<x<L$ and $f(x)=-1$ for
$-L<x<0$, extended periodically; $f$ is odd, so only the sine modes above
appear (an odd function has zero overlap with any even function, and the
cosine modes are even). Using the coefficient formula (extended to the full
period, which for an odd function just doubles the half-period integral):
$$b_n = \frac{1}{L}\int_{-L}^{L} f(x)\sin(k_nx)\,dx =
\frac{2}{L}\int_0^{L}\sin(k_nx)\,dx = \frac{2}{L}\left[-\frac{\cos(k_nx)}{k_n}
\right]_0^{L} = \frac{2}{Lk_n}\big(1-\cos(k_nL)\big).$$
Since $k_nL = n\pi$, $\cos(k_nL)=\cos(n\pi)=(-1)^n$, and $Lk_n=n\pi$ regardless
of $L$, so
$$b_n = \frac{2}{n\pi}\big(1-(-1)^n\big) = \begin{cases} 4/(n\pi), & n
\text{ odd}\\ 0, & n\text{ even}\end{cases}.$$
$$\boxed{b_n = \frac{4}{n\pi},\quad n\text{ odd}}$$
Two qualitative features, both generic to functions with a genuine jump:
- **The $1/n$ falloff.** Coefficients shrink slowly — you need many terms to
  represent a sharp jump well, because a jump has content at *every*
  wavenumber, decaying only as $1/n$.
- **The Gibbs phenomenon.** No finite partial sum reproduces the jump
  exactly; every partial sum overshoots near the discontinuity by about $9\%$
  of the jump height, and adding more terms narrows the overshoot's width
  but does not shrink its height. This is a real, permanent feature of
  representing a discontinuity in a smooth-function basis, not a numerical
  bug.

> **Misconception:** "The wiggles near the jump (Gibbs overshoot) are
> numerical error, and adding enough terms makes them go away." They don't:
> the overshoot's *height* converges to a fixed fraction of the jump
> ($\approx 9\%$) no matter how many terms you add — only its *width*
> shrinks, squeezing the ringing closer and closer to the discontinuity
> itself. This is a structural fact about approximating a jump with smooth
> sine waves, not a defect of any particular partial sum.

### From sum to integral: the Fourier transform, informally

Everything above lived on a finite string of length $L$, with modes spaced
by $\Delta k = k_{n+1}-k_n = \pi/L$. Now imagine stretching the string to be
unboundedly long, $L\to\infty$: the mode spacing $\Delta k\to0$, the discrete
label $n$ stops being a useful bookkeeping device, and the sum over modes
starts to look like a Riemann sum for an integral over a continuous variable
$k$. Trading the sine series for the (complex-exponential) form used from
here on, the discrete decomposition
$$f(x) = \sum_n b_n \sin(k_nx) \quad\longrightarrow\quad
\psi(x) = \int_{-\infty}^{\infty} A(k)\,e^{ikx}\,dk$$
is the **Fourier transform**: instead of a discrete list of coefficients
$b_n$ attached to discrete modes, you get a continuous *amplitude density*
$A(k)$ attached to every real $k$. Full disclosure: this section is
deliberately informal. Making the limit precise (in what sense does the sum
converge to the integral, for which functions does $A(k)$ exist, how do you
invert the transform to get $A(k)$ back from $\psi(x)$) is a semester of
real analysis on its own, and nothing below depends on any of those
technicalities — only on the qualitative picture that a *band* of
neighboring $k$'s, each weighted by $A(k)$, adds up to a function of $x$.
That qualitative picture is exactly what you need for wave packets.

### Wave packets: carrier and envelope

Suppose $A(k)$ is not spread over all $k$ but is concentrated in a narrow
band around some central $k_0$ — say a bump of width $\Delta k$ centered at
$k_0$, with $\Delta k \ll k_0$. What does $\psi(x)=\int A(k)e^{ikx}dk$ look
like? Far from any special point, the different $e^{ikx}$ contributions
across the narrow band have nearly the same $k$, so they stay in step with
each other over some region and add constructively; far enough away in $x$
that the phases $kx$ across the band have spread out by more than a cycle,
they add destructively and cancel. The result is a **wave packet**: a
carrier oscillation at $k_0$ (the mean wavenumber) multiplying a slowly
varying **envelope** that is large near $x=0$ and decays away from it — a
localized "wave group" rather than an infinite train of identical crests.
Narrowing the $k$-band (smaller $\Delta k$, closer to a pure sinusoid) makes
the envelope *wider* in $x$; widening the $k$-band makes the envelope
*narrower*. That reciprocal relationship is the bandwidth theorem, derived
quantitatively below.

### Group velocity, from a two-wave beat

Day 6 introduced beats from two waves of nearby frequency. Revisit that
superposition — the simplest possible "wave packet," built from just two
$k$'s instead of a continuous band — to extract a velocity out of it.
Superpose two waves of equal amplitude, wavenumbers $k_1,k_2$, and
frequencies $\omega_1=\omega(k_1)$, $\omega_2=\omega(k_2)$ set by whatever
dispersion relation the medium obeys (Day 5):
$$y(x,t) = \cos(k_1x-\omega_1t) + \cos(k_2x-\omega_2t).$$
Using the sum-to-product identity $\cos A+\cos B = 2\cos\!\big(\tfrac{A-B}2
\big)\cos\!\big(\tfrac{A+B}2\big)$ with $A=k_1x-\omega_1t$, $B=k_2x-\omega_2t$:
$$y(x,t) = 2\cos\!\left(\frac{\Delta k}{2}x - \frac{\Delta\omega}{2}t\right)
\cos\!\left(\bar kx-\bar\omega t\right),$$
where $\Delta k=k_1-k_2$, $\Delta\omega=\omega_1-\omega_2$, and
$\bar k,\bar\omega$ are the averages. The second cosine is the fast
**carrier**, riding along at the ordinary phase velocity $\bar\omega/\bar k$.
The first cosine is the slow **envelope** (Day 6's beat pattern) — it is
itself a wave, of the form $\cos\big(\tfrac{\Delta k}2(x-ut)\big)$ with
$$u = \frac{\Delta\omega}{\Delta k}.$$
As the two component waves are brought closer together in frequency
($\Delta k,\Delta\omega\to0$ while their ratio is held fixed at whatever the
dispersion relation dictates locally), the envelope speed becomes a
derivative:
$$\boxed{v_g \equiv \lim_{\Delta k\to0}\frac{\Delta\omega}{\Delta k} =
\frac{d\omega}{dk}}$$
This is the **group velocity**: the speed at which the *envelope* — the
energy, the information, the "packet" as a recognizable lump — travels, as
opposed to the **phase velocity** $v_{\mathrm{ph}}=\omega/k$, the speed of
the individual crests inside the envelope. Whenever $\omega(k)$ is a straight
line through the origin ($\omega=v_{\mathrm{ph}}k$ with constant
$v_{\mathrm{ph}}$ — a *non-dispersive* medium, e.g. Day 5's ideal string),
$d\omega/dk=v_{\mathrm{ph}}$ too: envelope and crests move together, and a
wave packet keeps its shape forever. Whenever $\omega(k)$ curves, $v_g$ and
$v_{\mathrm{ph}}$ split apart.

**Worked case: deep-water gravity waves**, whose measured dispersion
relation is $\omega=\sqrt{gk}$ — a fact about water we take as given here,
not something derived from first principles. Phase
velocity: $v_{\mathrm{ph}}=\omega/k=\sqrt{gk}/k=\sqrt{g/k}$. Group velocity:
$$v_g = \frac{d\omega}{dk} = \frac{d}{dk}\big(g^{1/2}k^{1/2}\big) =
\tfrac12 g^{1/2}k^{-1/2} = \tfrac12\sqrt{\frac gk} = \frac{v_{\mathrm{ph}}}2.$$
Ocean swell is the standard illustration: individual crests visibly
overtake and vanish at the *front* of a wave group, because the crests
(moving at $v_{\mathrm{ph}}$) outrun the group's envelope (moving at
$v_g=v_{\mathrm{ph}}/2$).

> **Misconception:** "Group velocity is always less than phase velocity."
> False in general — it depends entirely on the shape of $\omega(k)$. Deep
> water waves happen to give $v_g<v_{\mathrm{ph}}$, but Exercise 3 below (the
> dispersion relation $\omega=\alpha k^2$, which will reappear as literally
> the free-particle Schrödinger dispersion relation) gives $v_g=2v_{\mathrm
> {ph}}$ — group velocity *larger* than phase velocity. There is no
> universal ordering; you have to compute $d\omega/dk$ and $\omega/k$
> separately for the dispersion relation actually in front of you.

### The bandwidth theorem

The wave-packet picture above said, qualitatively, that a narrow band in $k$
gives a wide packet in $x$, and vice versa. Made quantitative with a Gaussian
band — the case that can be computed exactly, and the case that will recur
as the ground state of the quantum harmonic oscillator later in this course
— the relationship becomes exact.

Take a Gaussian amplitude profile centered at $k_0$,
$$A(k) = \exp\!\left[-\frac{(k-k_0)^2}{2a^2}\right]$$
for some width parameter $a$. Two widths matter here, and they are *not*
automatically the same number: the width of $A(k)$ itself, versus the width
of the **intensity** $|A(k)|^2$ — the quantity that will become a
probability density once $\hbar$ enters the picture in the QM course, so it
is the physically meaningful width to standardize on now. Since
$|A(k)|^2=\exp\!\big[-(k-k_0)^2/a^2\big]$ is itself Gaussian with standard
deviation $a/\sqrt2$, **define** $\Delta k$ to be that standard deviation:
$\Delta k \equiv a/\sqrt2$. (This is a third, distinct use of the symbol
$\Delta k$ today: not the mode spacing $\pi/L$ from the sum-to-integral
limit above, nor the beat's frequency separation $k_1-k_2$ from the
group-velocity derivation, but the width of one continuous amplitude band
around a single carrier $k_0$.)

Building the packet (shifting $k=k_0+q$ so the carrier factors out, and using
the standard Gaussian integral $\int_{-\infty}^{\infty}e^{-q^2/(2a^2)}
e^{iqx}dq = a\sqrt{2\pi}\,e^{-a^2x^2/2}$):
$$\psi(x) = \int A(k)e^{ikx}dk = e^{ik_0x}\int e^{-q^2/(2a^2)}e^{iqx}dq =
a\sqrt{2\pi}\;e^{ik_0x}\,e^{-a^2x^2/2}.$$
The intensity of the packet is $|\psi(x)|^2 = 2\pi a^2\,e^{-a^2x^2}$, itself
Gaussian with standard deviation $1/(a\sqrt2)$; define $\Delta x$ to be that
standard deviation: $\Delta x \equiv 1/(a\sqrt2)$.

Multiply the two widths:
$$\Delta x\,\Delta k = \frac{1}{a\sqrt2}\cdot\frac{a}{\sqrt2} = \frac12.$$
$$\boxed{\Delta x\,\Delta k = \tfrac12 \quad\text{(exact, for a Gaussian band)}}$$
For any *other* shape of $A(k)$ — a flat-topped or triangular band — the
product $\Delta x\,\Delta k$ comes out larger than $\tfrac12$ (the Gaussian
is the special shape that minimizes the product). A sharply-edged
(rectangular) band is a more extreme case still: its packet is a $\sin(x)/x$
profile whose tails decay too slowly for the standard-deviation width to
even be finite, so for that shape the product isn't just "somewhat larger"
— it can be made arbitrarily large. This is why the general statement is
written as an inequality rather than an exact value:
$$\Delta x\,\Delta k \gtrsim 1$$
In short: $\Delta x\,\Delta k\gtrsim1$ is the convention-agnostic rule of
thumb, true for essentially any reasonable definition of "width" and any
reasonable band shape, while $\Delta x\,\Delta k=\tfrac12$ is the exact
floor reached only by the Gaussian, and only under the specific
standard-deviation convention adopted above. (The simulation's panel (b) is
built exactly this way and reports the numerically measured $\Delta x\,
\Delta k$ directly, so you can check it against the value above.)

The same mathematics, with $x\to t$ and $k\to\omega$ (time and angular
frequency are Fourier partners in exactly the same way position and
wavenumber are — nothing above the integral sign cared that $x$ meant
"position"), gives the time-domain version, in the *same* standard-deviation
convention used above: a pulse of duration $\Delta t$ has an
angular-frequency spread $\Delta\omega\gtrsim1/\Delta t$, with Gaussian
equality $\Delta\omega\,\Delta t=\tfrac12$ exactly as before. Engineers
usually quote a *different* convention instead: full pulse width rather than
standard deviation, and ordinary frequency $\nu=\omega/2\pi$ rather than
angular frequency. In that convention the rule of thumb is named the
**time–bandwidth product**,
$$\Delta t\,\Delta\nu \sim 1,$$
a genuinely different numerical convention from the standard-deviation one
just above — *not* something you get by substituting $\omega=2\pi\nu$ into
$\Delta\omega\,\Delta t\gtrsim1$ (that substitution instead gives
$\Delta t\,\Delta\nu\gtrsim1/2\pi$). Both conventions express the identical
physical fact — reciprocal spread between duration and frequency content —
just with different bookkeeping of factors of $2\pi$ and of exactly how
"width" is defined; Exercise 4 below uses the named time–bandwidth-product
convention. Two everyday, entirely classical instances of the underlying
fact, either convention:
- A very short sound *click* has no well-defined pitch — its duration
  $\Delta t$ is tiny, so its frequency spread $\Delta\nu$ is necessarily
  huge; you cannot make a click both brief and pure-toned.
- A short radar pulse used for fine range resolution necessarily occupies a
  *broad* frequency band — the more precisely you localize the pulse in
  time, the more bandwidth its receiver has to be able to handle.

$$\boxed{\text{This is a fact about waves, not about quantum mechanics.}}$$

> **Misconception:** "The uncertainty principle is a piece of quantum
> weirdness with no classical analogue." Everything above — the bandwidth
> theorem, the exact Gaussian $\tfrac12$, the click and the radar pulse — is
> ordinary Fourier analysis applied to ordinary classical waves; nothing
> here mentions $\hbar$, probability, or measurement. The genuinely quantum
> content, added at the very end of today's Connection to QM section below,
> is just the physical claim $p=\hbar k$ — that a particle's momentum *is*
> $\hbar$ times a wavenumber. Once you accept that one physical input, the
> bandwidth theorem you just derived for ordinary waves *becomes* the
> Heisenberg uncertainty principle, unchanged in its mathematics.

### Dispersion and packet spreading

The wave-packet picture in "Carrier and envelope" above quietly assumed a
single snapshot in time. Let time back in: each component $e^{i(kx-\omega(k)
t)}$ in the band advances at its own phase velocity $\omega(k)/k$. If
$\omega(k)=v_{\mathrm{ph}}k$ is exactly linear (non-dispersive), every
component in the band has the *same* phase velocity, so the whole packet
$\psi(x,t)=\int A(k)e^{i(kx-\omega(k)t)}dk = \int A(k)e^{ik(x-v_{\mathrm{ph}}
t)}dk = \psi(x-v_{\mathrm{ph}}t,0)$ just rigidly translates, unchanged in
shape, at $v_{\mathrm{ph}}=v_g$. But if $\omega(k)$ is *nonlinear* (curved),
different $k$'s within the band have different *group* velocities
$v_g(k)=d\omega/dk$ — picture the band as many thin sub-bands, each behaving
like its own tiny wave packet centered on a slightly different $k$; each
sub-packet's envelope moves at *its own* $v_g(k)$, so sub-packets from one
edge of the band drift apart from sub-packets from the other edge, and the
whole packet widens. The packet **spreads** — it widens in $x$ over time, at
a rate set by how much $v_g(k)$ varies across the band's width $\Delta k$,
i.e. by the curvature $d^2\omega/dk^2$ — **not** by how the phase velocity
varies. Phase velocity varying with $k$ is neither necessary nor sufficient
for spreading: $\omega=ck+b$ (constant $b\ne0$) has a $k$-dependent phase
velocity $v_{\mathrm{ph}}=\omega/k=c+b/k$, yet $v_g=d\omega/dk=c$ is the
*same* for every $k$ in the band, so that packet translates rigidly with no
spreading at all. This is exactly what the simulation's panel (c) shows
directly.

## Worked examples

**1. Square-wave coefficients, numerically, and a convergence check.** Using
$b_n=4/(n\pi)$ for odd $n$: $b_1=4/\pi\approx1.273$, $b_3=4/3\pi\approx0.424$,
$b_5=4/5\pi\approx0.255$ — each successive odd coefficient smaller by close
to a factor matching $1/n$, confirming the slow $1/n$ falloff derived above.
As a check that the series is at least self-consistent at a smooth point
(away from the jump), evaluate the full series at $x=L/2$ (so $k_nx=n\pi/2$,
using $k_n=n\pi/L$): $f(L/2)$ should equal $+1$ by direct inspection of the
square wave (the midpoint of the top half), and the series gives
$$\sum_{n\text{ odd}}\frac{4}{n\pi}\sin\!\left(\frac{n\pi}{2}\right) =
\frac4\pi\left(1-\frac13+\frac15-\frac17+\cdots\right) = \frac4\pi\cdot
\frac\pi4 = 1,$$
using $\sin(n\pi/2)=(-1)^{(n-1)/2}$ for odd $n$ and the classical Leibniz
series $\pi/4=1-\tfrac13+\tfrac15-\cdots$ — the series reproduces $f(L/2)=1$
exactly, a nontrivial cross-check of the coefficients derived above against
an independently known numerical fact about $\pi$.

**2. Group velocity for deep-water waves.** Already derived in the Theory
section above: for $\omega=\sqrt{gk}$, $v_{\mathrm{ph}}=\sqrt{g/k}$ and
$v_g=\tfrac12\sqrt{g/k}=v_{\mathrm{ph}}/2$. Concretely, for ocean swell with
$k=0.05\ \text{m}^{-1}$ (wavelength $2\pi/k\approx126\,$m) and
$g=9.8\ \text{m/s}^2$: $v_{\mathrm{ph}}=\sqrt{9.8/0.05}=\sqrt{196}=14\ \text{
m/s}$, so $v_g=7\ \text{m/s}$ — the swell's energy (and any surfer riding the
group, not a single crest) advances at half the speed the individual crests
race past at.

**3. Gaussian packet: from $\Delta k$ to $\Delta x$.** A laser pulse's
spatial amplitude profile is engineered to have $\Delta k = 0.4\ \text{
rad/m}$ (a Gaussian band centered at some large carrier $k_0$). Using the
boxed result $\Delta x\,\Delta k=\tfrac12$ derived above,
$$\Delta x = \frac{1}{2\Delta k} = \frac{1}{2(0.4)} = 1.25\ \text{m}.$$
Halving $\Delta k$ (a purer, more monochromatic beam) would double $\Delta x$
to $2.5\,$m — a *less* localized pulse — reproducing the reciprocal
relationship qualitatively described in "Carrier and envelope" above, now
with an exact number attached.

## Simulation

Run:
```
python3 code/day07_wave_packet_builder.py
```
Three panels. **(a)** partial sums of the square-wave sine series with
$N=1,3,9,33$ terms overlaid on the target square wave — watch the $1/n$
falloff (more terms track the flat tops better) and the Gibbs overshoot
(the ringing near each jump narrows but does not shrink in height as $N$
grows). **(b)** a wave packet $\sum_nA(k_n)\cos(k_nx)$ built from a Gaussian
band of $k$'s, shown at two different bandwidths — the console output and
the legend both report the measured $\Delta x$, the input $\Delta k$, and
their product, which should sit close to the $\tfrac12$ derived above for
both bandwidths despite one packet looking dramatically narrower than the
other. **(c)** the same kind of packet evolved under the nonlinear
dispersion relation $\omega=\alpha k^2$, snapshotted at three times in a
window that follows the packet's own group velocity — so any change in the
snapshots is genuine spreading, not just translation.

Before running, predict:
- Double the $k$-bandwidth in panel (b) — does the packet get wider or
  narrower in $x$? By roughly what factor?
- In panel (c), the group velocity is $v_g(k)=2\alpha k$, which *increases*
  with $k$ — so higher-$k$ sub-packets move faster than lower-$k$ ones.
  Given that the packet as a whole moves toward $+x$, which edge of the
  spreading packet (leading or trailing) should end up carrying
  predominantly higher-$k$ content, and which predominantly lower-$k$
  content?
- Reduce `NK` (panel (b)/(c)'s number of $k$-samples used to build the
  packet) to just $3$ — with only 3 discrete $k$'s instead of a fine
  continuum, does the result still look like a single localized envelope,
  or does it look more like a multi-wave beat pattern? What does that tell
  you about how many modes the sum-to-integral limit in the Theory section
  actually needs to look continuous?

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. Starting from two superposed waves $\cos(k_1x-\omega_1t)+\cos(k_2x-
   \omega_2t)$, derive the envelope's speed $u=\Delta\omega/\Delta k$ and
   take the limit $\Delta k\to0$ to get $v_g=d\omega/dk$.
2. State the bandwidth theorem in your own words, and give one everyday
   example of it that is *not* the sound-click or radar-pulse example used
   in the Theory section above.

**Standard**

3. **(Foreshadows matter waves — cited again on Day 16.)** For the
   dispersion relation $\omega=\alpha k^2$ ($\alpha$ a constant), compute
   $v_g$ and $v_{\mathrm{ph}}$ separately, and show $v_g=2v_{\mathrm{ph}}$.
4. A radar system emits a pulse of duration $\Delta t = 1\ \mu\text{s}$.
   Using the time-domain bandwidth theorem from the Theory section, estimate
   the pulse's frequency bandwidth $\Delta\nu$.

**Stretch**

5. A triangle wave $g(x)$ (period $2L$, odd, ramping linearly from $-1$ at
   $x=-L/2$ up to $+1$ at $x=L/2$ and back down to $-1$ at $x=3L/2$) has
   $g'(x)$ equal to a square wave of amplitude $2/L$, shifted by a quarter
   period relative to the square wave analyzed in the Theory section.
   Using that relationship, find $g(x)$'s Fourier sine coefficients, compare
   their falloff rate with the square wave's $b_n=4/(n\pi)$, and explain in
   one or two sentences why smoothness (no jump, only a slope kink) buys an
   extra power of $1/n$.

## Hints

1. Use the identity $\cos A+\cos B = 2\cos\big(\tfrac{A-B}2\big)\cos\big(
   \tfrac{A+B}2\big)$ with $A=k_1x-\omega_1t$, $B=k_2x-\omega_2t$, and
   identify which factor is the slowly varying envelope.
2. Reread the boxed inequality and the boxed sentence right after it, then
   think about what a short-duration signal must be built from — no example
   list here, that's for you to supply.
3. Differentiate $\omega=\alpha k^2$ directly for $v_g$, and divide by $k$
   for $v_{\mathrm{ph}}=\omega/k$; then form the ratio.
4. Use the time–bandwidth product $\Delta t\,\Delta\nu\sim1$ (the named
   engineering convention from the Theory section) directly; no other
   formula is needed.
5. Write $g'(x)$ as the known square-wave sine series evaluated at a
   shifted argument $x+L/2$, expand $\sin\big(k_n(x+L/2)\big)$ with the
   angle-addition formula (noting $k_nL/2=n\pi/2$), then integrate the
   resulting series for $g'(x)$ term by term to recover $g(x)$.

## Solutions

**1.** $\cos(k_1x-\omega_1t)+\cos(k_2x-\omega_2t) = 2\cos\!\Big(\dfrac{(k_1-
k_2)x-(\omega_1-\omega_2)t}2\Big)\cos\!\Big(\dfrac{(k_1+k_2)x-(\omega_1+
\omega_2)t}2\Big)$, using the sum-to-product identity with $A=k_1x-\omega_1t$,
$B=k_2x-\omega_2t$. Writing $\Delta k=k_1-k_2$, $\Delta\omega=\omega_1-
\omega_2$, the first (slow) factor is $\cos\!\big(\tfrac{\Delta k}2(x-ut)
\big)$ with $u=\Delta\omega/\Delta k$ — a wave moving at speed $u$. As the
two frequencies are brought together, $\Delta k,\Delta\omega\to0$ along the
dispersion curve, so $u\to d\omega/dk$ by the definition of the derivative:
$v_g=d\omega/dk$.

**2.** The bandwidth theorem: a wave (or wave packet) that is narrowly
localized in one variable (position $x$, or time $t$) necessarily has a
*wide* spread in the Fourier-conjugate variable ($k$, or frequency $\omega$/
$\nu$), and vice versa; quantitatively $\Delta x\,\Delta k\gtrsim1$ (or, in
the time–bandwidth-product convention, $\Delta t\,\Delta\nu\sim1$), with
equality at exactly $\tfrac12$ (in the $x$–$k$, standard-deviation
convention) for a Gaussian profile. A different everyday example, staying
within today's own string picture: plucking a guitar string sharply at one
point excites *many* of Day 6's modes $\sin(k_nx)$ at once (a brief, sharply
localized pluck in $x$ needs a wide band of $k_n$'s to build), which is
exactly why the initial pluck sounds bright and percussive — rich in many
frequencies — before the higher modes damp out faster than the fundamental
and the sustained note narrows down toward one nearly pure tone. Narrowing
the initial disturbance in $x$ (a sharper pluck) only widens the band of
modes it excites, the same reciprocal tradeoff, with no quantum mechanics
involved.

**3.** $v_g = d\omega/dk = d(\alpha k^2)/dk = 2\alpha k$. $v_{\mathrm{ph}} =
\omega/k = \alpha k^2/k = \alpha k$. Ratio: $v_g/v_{\mathrm{ph}} = 2\alpha k
/(\alpha k) = 2$, i.e. $v_g = 2v_{\mathrm{ph}}$ — the group travels *twice*
as fast as the individual crests, the opposite ordering from the deep-water
wave example in the Theory section, which is exactly the point of the
"group velocity is always less than phase velocity" misconception callout.

**4.** Using the time–bandwidth-product convention $\Delta t\,\Delta\nu\sim1$
with $\Delta t=1\ \mu\text{s}=10^{-6}\,$s:
$$\Delta\nu \sim \frac{1}{\Delta t} = \frac{1}{10^{-6}\,\text{s}} = 10^6\
\text{Hz} = 1\ \text{MHz}.$$
A radar pulse only a microsecond long necessarily occupies roughly a
megahertz of receiver bandwidth or more — a standard rule of thumb in radar
and communications engineering, derived here from the same mathematics as
the Gaussian wave-packet result above.

**5.** $g'(x)$ is a square wave of amplitude $2/L$, equal to $+2/L$ for
$|x|<L/2$ and $-2/L$ for $L/2<|x|<L$ — this is $2/L$ times the Theory
section's $\pm1$ square wave $s(x)=\sum_{n\text{ odd}}(4/(n\pi))\sin(k_nx)$
(with $k_n=n\pi/L$), evaluated at the shifted argument $x+L/2$ (shifting
left by a quarter of the full period $2L$ turns the "jump-at-0" square wave
into the "flat-topped around 0" one that matches $g'$):
$$g'(x) = \frac2L\,s\!\left(x+\frac L2\right) = \frac2L\sum_{n\text{ odd}}
\frac{4}{n\pi}\sin\!\left(k_nx+\frac{n\pi}2\right) = \sum_{n\text{ odd}}
\frac{8}{Ln\pi}\sin\!\left(k_nx+\frac{n\pi}2\right).$$
For odd $n$, $\sin\big(k_nx+\tfrac{n\pi}2\big) = \sin(k_nx)\cos\big(\tfrac{n
\pi}2\big)+\cos(k_nx)\sin\big(\tfrac{n\pi}2\big) = (-1)^{(n-1)/2}\cos(k_nx)$
(the $\cos(n\pi/2)$ term vanishes for odd $n$, and $\sin(n\pi/2)=(-1)^{(n-1)/
2}$ for odd $n$). So
$$g'(x) = \sum_{n\text{ odd}} \frac{8(-1)^{(n-1)/2}}{Ln\pi}\cos(k_nx).$$
Integrating term by term ($\int\cos(k_nx)\,dx=\sin(k_nx)/k_n$, and $k_n=n
\pi/L$ so dividing by $k_n$ multiplies by $L/(n\pi)$, exactly canceling the
explicit $L$ already sitting in the denominator and contributing one more
power of $1/n$) and fixing the integration constant to zero (matching
$g(0)=0$, an odd function):
$$g(x) = \sum_{n\text{ odd}} \frac{8(-1)^{(n-1)/2}}{Ln\pi}\cdot\frac{L}{n\pi}
\sin(k_nx) = \sum_{n\text{ odd}} \frac{8(-1)^{(n-1)/2}}{n^2\pi^2}\sin(k_nx).$$
$$\boxed{b_n = \frac{8(-1)^{(n-1)/2}}{n^2\pi^2},\quad n\text{ odd}}$$
— the standard triangle-wave result, and, satisfyingly, independent of $L$
just as the square wave's $b_n=4/(n\pi)$ was: both are pure numbers, as they
must be since $g$ and $s$ are dimensionless amplitudes and $k_nx$ is a
dimensionless argument regardless of how long the string is. The triangle
wave's coefficients fall off as $1/n^2$, one power of $n$ faster
than the square wave's $1/n$ — exactly one extra power for each derivative
of smoothness gained: the square wave has a jump (discontinuous itself), the
triangle wave is continuous but has a kink (discontinuous *derivative*).
Each additional derivative of continuity you buy shifts high-$n$ content to
lower amplitude, because reproducing a sharper feature (a jump) requires
more high-wavenumber content than reproducing a gentler one (a kink); a
perfectly smooth (infinitely differentiable) periodic function has
coefficients that fall off faster than *any* power of $n$.

## Connection to QM

Multiply today's results by $\hbar$ and you have already derived two of the
central facts of quantum mechanics classically, without knowing it. The
physical postulate that makes the leap (introduced properly on Day 16) is
just $p=\hbar k$ and $E=\hbar\omega$ — a particle's momentum and energy are
$\hbar$ times a wave's wavenumber and angular frequency. Substituting into
today's bandwidth theorem, $\Delta x\,\Delta k\gtrsim1$ becomes $\Delta x\,
\Delta p\gtrsim\hbar$ — the Heisenberg uncertainty principle — and the exact
Gaussian case $\Delta x\,\Delta k=\tfrac12$ becomes the exact minimum-
uncertainty bound $\Delta x\,\Delta p=\hbar/2$ quoted throughout the QM
course, with no new mathematics at all: it is exactly today's Gaussian
wave-packet computation with a constant $\hbar$ inserted. Likewise, a
quantum particle *is* (in this picture) a wave packet, and its velocity —
the speed at which the particle itself, as a localized thing, actually
travels — is $v_g=d\omega/dk$, not the phase velocity of the underlying
wave. Finally, Exercise 3's dispersion relation $\omega=\alpha k^2$ is not a
random example: substituting $E=\hbar\omega$, $p=\hbar k$ into the
free-particle energy $E=p^2/2m$ gives $\hbar\omega = \hbar^2k^2/(2m)$, i.e.
$\omega = (\hbar/2m)k^2$ — exactly today's $\omega=\alpha k^2$ with
$\alpha=\hbar/2m$. So Exercise 3's result $v_g=2v_{\mathrm{ph}}$, derived
today from pure algebra with no physics content beyond "differentiate and
divide," is already the correct group velocity of a free quantum particle;
the free Schrödinger equation you'll meet later in this course is, in the
language of today's Theory section, nothing but the dispersion relation for
matter waves.
