# Day 6 — Superposition, Standing Waves, and Interferometers

## Learning objectives

By the end of today you should be able to:
- Prove that superposition of waves is a direct consequence of the
  linearity of the wave equation, not an extra physical assumption bolted
  on top of it.
- Compute the interference pattern from two coherent sources, derive the
  constructive/destructive conditions from path difference, and find
  two-slit fringe spacing.
- Derive the beat phenomenon from the sum of two nearby frequencies and
  find the beat frequency.
- Derive the standing-wave form from two counter-propagating waves, apply
  fixed-end boundary conditions, and obtain the discrete mode spectrum
  $k_n=n\pi/L$, $f_n=nv/2L$.
- Derive both output intensities of a Mach–Zehnder interferometer,
  $I_1\propto\cos^2(\phi/2)$ and $I_2\propto\sin^2(\phi/2)$, from an
  explicit beam-splitter convention, and verify energy conservation at
  every phase.

Time budget: ~3.5 hours.

## Reference material

- French, *Vibrations and Waves* (MIT Introductory Physics Series) — the
  chapters on superposition, beats, and standing waves cover exactly
  today's first four theory beats, with more worked numerical examples;
  Halliday, Resnick & Walker, *Fundamentals of Physics* is a gentler,
  more numerical alternative for the same material.
- Hecht, *Optics* — the interference chapter covers two-beam interference,
  the Michelson interferometer, and beam-splitter conventions in far more
  generality than needed today.
- This file is self-contained: everything you need is derived below.
- Builds on Day 5's sinusoidal traveling-wave conventions: $y=A\cos(kx-\omega
  t)$, $k=2\pi/\lambda$, $\omega=2\pi f$, $v_{\text{ph}}=\omega/k$, and the
  wave equation $\partial^2y/\partial t^2 = v^2\,\partial^2y/\partial x^2$
  those obey, plus Day 3's complex-exponential bookkeeping trick. Nothing
  beyond Days 1, 3, and 5 is assumed.

## Theory

### Superposition is a theorem about the wave equation, not an assumption

The wave equation from Day 5,
$$\frac{\partial^2 y}{\partial t^2} = v^2\,\frac{\partial^2 y}{\partial x^2},$$
is **linear**: every term is a first power of $y$ or one of its
derivatives, with no $y^2$, $y\,\partial y/\partial x$, or other nonlinear
combination anywhere. Suppose $y_1(x,t)$ and $y_2(x,t)$ are both solutions.
Then for any constants $a,b$,
$$\frac{\partial^2}{\partial t^2}(ay_1+by_2) = a\frac{\partial^2y_1}{\partial t^2}+b\frac{\partial^2y_2}{\partial t^2}
= a\,v^2\frac{\partial^2y_1}{\partial x^2}+b\,v^2\frac{\partial^2y_2}{\partial x^2}
= v^2\frac{\partial^2}{\partial x^2}(ay_1+by_2),$$
using only that partial differentiation is itself linear (derivative of a
sum is the sum of derivatives, constants pull out) and that $y_1,y_2$
individually satisfy the equation. So $ay_1+by_2$ *also* solves the wave
equation, for any $a,b$ and any two solutions. This is the entire content
of **superposition**: it is a direct algebraic consequence of linearity,
true for *any* linear wave equation (mechanical, electromagnetic,
whatever), and it is exactly what breaks down for nonlinear wave equations
(shock waves, some water waves) where two solutions added together
generally do *not* solve the equation. Everything below — interference,
beats, standing waves — is nothing more than this one linearity fact
applied to specific pairs of solutions.

### Two-source interference

Consider two sources emitting identical sinusoidal waves of amplitude $A$,
wavelength $\lambda$, and the same frequency (**coherent** sources — a
fixed, time-independent phase relationship between them, taken here to be
in phase at the sources). At an observation point, the wave from source 1
has traveled a path length $r_1$, and from source 2 a path length $r_2$.
The two arriving waves are
$$y_1 = A\cos(kr_1-\omega t), \qquad y_2 = A\cos(kr_2-\omega t).$$
By superposition, the field at the observation point is $y=y_1+y_2$. Using
the sum-to-product identity $\cos u+\cos v = 2\cos\!\left(\frac{u+v}2\right)\cos\!\left(\frac{u-v}2\right)$
with $u=kr_1-\omega t$, $v=kr_2-\omega t$:
$$y = 2A\cos\!\left(\frac{k(r_1-r_2)}{2}\right)\cos\!\left(k\bar r-\omega t\right), \qquad \bar r=\frac{r_1+r_2}2.$$
This is again a sinusoidal wave at the same frequency $\omega$, but with
amplitude $2A\cos(\delta/2)$, where
$$\delta = k\Delta L, \qquad \Delta L = r_2-r_1$$
is the **phase difference** produced by the **path difference** $\Delta L$.
Since intensity is proportional to amplitude squared (Day 5),
$$I = 4A^2\cos^2(\delta/2) = 4I_s\cos^2(\delta/2),$$
where $I_s\propto A^2$ is the intensity from either source alone (written
$I_s$, not $I_1$, to keep this single-source intensity distinct from the
Mach–Zehnder *port*-1 intensity $I_1$ defined later in this file — the two
symbols never mean the same thing). This is the general two-source
interference law, derived — not assumed — directly from superposition and
one trig identity.

**Constructive/destructive conditions.** $I$ is maximal ($=4I_s$) when
$\cos^2(\delta/2)=1$, i.e. $\delta=2m\pi$ for integer $m$, i.e.
$$\Delta L = m\lambda \quad (\text{constructive}).$$
$I$ vanishes when $\delta=(2m+1)\pi$, i.e.
$$\Delta L = \left(m+\tfrac12\right)\lambda \quad (\text{destructive}).$$

**Two-slit maxima positions.** For slits separated by $d$ and a screen at
distance $L\gg d$, the path difference to a point at height $y$ on the
screen is, for small angles, $\Delta L \approx d\sin\theta \approx dy/L$
(the usual small-angle geometry: $\sin\theta\approx\tan\theta = y/L$).
Substituting the constructive condition:
$$y_m = \frac{m\lambda L}{d}, \qquad m=0,\pm1,\pm2,\dots,$$
so consecutive maxima are spaced by the **fringe spacing**
$$\Delta y = \frac{\lambda L}{d}$$
— used numerically in Worked Example 1.

**Phasor-addition picture.** The same result has a purely geometric
reading: represent each wave at the observation point by a rotating vector
(phasor) of length $A$; the two phasors differ in angle by the fixed phase
$\delta$ (they still rotate together at the common frequency $\omega$, so
their relative angle is frozen). Adding two equal-length vectors separated
by angle $\delta$ (an isosceles triangle bisected by the resultant) gives a
resultant of length $2A\cos(\delta/2)$ — exactly the amplitude found above
by algebra. This picture is worth keeping: it is the same construction
used for AC-circuit phasors and, later in this course, for the two-term
qubit-amplitude sums in Day 18's re-derivation of these same laws.

### Beats

Now superpose two waves of *different* frequencies $\omega_1,\omega_2$ but
equal amplitude, observed at one fixed point (drop the $x$-dependence and
just track $y(t)=\cos\omega_1t+\cos\omega_2t$). The same sum-to-product
identity applies, now with $u=\omega_1t,\,v=\omega_2t$:
$$y(t) = \cos\omega_1t+\cos\omega_2t = 2\cos\!\left(\frac{\omega_1-\omega_2}{2}t\right)\cos\!\left(\frac{\omega_1+\omega_2}{2}t\right).$$
When $\omega_1\approx\omega_2$ (both close to some common value), the
second factor oscillates rapidly at the average frequency
$\bar\omega=(\omega_1+\omega_2)/2$, while the first factor,
$E(t)=2\cos\!\left(\frac{\Delta\omega}{2}t\right)$ with
$\Delta\omega=\omega_1-\omega_2$, varies slowly — it is the **envelope**
that modulates the fast oscillation's amplitude.

**Beat frequency.** The audible/observable "beat" is a *loudness* maximum,
which occurs whenever $|E(t)|$ is maximal — and $|E(t)|=2|\cos(\Delta\omega
t/2)|$ reaches its maximum magnitude *twice* per period of
$\cos(\Delta\omega t/2)$ (once at each sign, $+2$ and $-2$, since both count
as "loud"). The cosine factor itself has period $2\pi/(\Delta\omega/2) =
4\pi/\Delta\omega$, so the perceived beats repeat with period half that,
$2\pi/\Delta\omega$, giving beat angular frequency $\Delta\omega$ and beat
frequency in Hz
$$f_{\text{beat}} = |f_1-f_2|$$
— the familiar rule that the beat frequency equals the plain difference of
the two frequencies, now derived rather than quoted. (It is *not* half the
difference; the factor of two from "$|\cos|$ peaks twice per cycle" exactly
cancels the factor of $\tfrac12$ inside the envelope's argument.)

### Standing waves

Now superpose two waves of equal amplitude and frequency traveling in
*opposite* directions (e.g. an incident wave and its reflection):
$$y_R = A\sin(kx-\omega t) \quad (\text{traveling in }+x), \qquad
y_L = A\sin(kx+\omega t) \quad (\text{traveling in }-x).$$
(Using $\sin$ rather than Day 5's $\cos$ is just a $\pi/2$ relabeling of
where $t=0$ is — the physics is identical.) Expand each with the angle-sum
formula and add:
$$y_R+y_L = A\big[\sin(kx-\omega t)+\sin(kx+\omega t)\big] = A\big[(\sin kx\cos\omega t-\cos kx\sin\omega t)+(\sin kx\cos\omega t+\cos kx\sin\omega t)\big],$$
and the $\cos kx\sin\omega t$ terms cancel exactly, leaving
$$y(x,t) = 2A\sin(kx)\cos(\omega t).$$
This is a **standing wave**: unlike a traveling wave, the $x$- and
$t$-dependence factor apart completely. Every point $x$ oscillates in place
with amplitude $2A\sin(kx)$ that depends only on position — there is no
$x-vt$ combination left, so nothing propagates. Points where $\sin(kx)=0$
(i.e. $kx=n\pi$) never move at all — **nodes** — and points where
$|\sin(kx)|=1$ oscillate with the maximum amplitude $2A$ — **antinodes**.

> **Misconception:** "standing waves transport energy, just like traveling
> waves do." They do not. A standing wave is two equal traveling waves
> carrying energy in *opposite* directions at every instant, so the net
> energy flux (power) is exactly zero everywhere, at every time — energy
> sloshes back and forth between kinetic and potential *locally*, between
> neighboring nodes and antinodes, but none of it drifts down the string.
> This is why standing-wave modes are also called **trapped modes**: the
> energy is confined between the boundaries, not carried through them.

**Fixed-end boundary conditions and the discrete spectrum.** For a string
of length $L$ fixed at both ends ($x=0$ and $x=L$), the boundary condition
is $y(0,t)=y(L,t)=0$ for *all* $t$. The form above already gives
$y(0,t)=2A\sin(0)\cos(\omega t)=0$ automatically. The condition at $x=L$
requires
$$\sin(kL) = 0 \quad\Longrightarrow\quad kL = n\pi, \quad n=1,2,3,\dots$$
($n=0$ is excluded — it gives $y\equiv0$, no wave at all). Using the
dispersion relation $\omega=vk$ from Day 5 ($v$ the wave speed on the
string, fixed by the string's tension and mass density, independent of
$n$), the allowed wavenumbers and frequencies are
$$\boxed{k_n = \frac{n\pi}{L}, \qquad f_n = \frac{n v}{2L}}, \qquad n=1,2,3,\dots$$
— the string's full harmonic series: a fundamental $f_1=v/2L$ and integer
multiples of it. Days 15 and 16 quote this pair of boxed results directly,
so keep the exact form in mind. Just as important is the sentence behind
*why* the spectrum is discrete at all:

> **Boundary conditions turn a continuum of waves into a discrete list of
> modes — remember this sentence; it is the entire origin story of
> quantization.**

Nothing about the wave equation itself restricts $k$ or $\omega$ — any real
$k$ gives a valid traveling-wave solution on an infinite string. It is
*only* the requirement that the solution also satisfy fixed boundary
conditions at two specific points that collapses the continuum of possible
$k$ down to the discrete list $k_n=n\pi/L$. Nothing quantum has entered yet
— this is 100% classical wave mechanics — but the *mechanism* (continuous
equation + boundary conditions $\Rightarrow$ discrete spectrum) is exactly
the mechanism Day 16 uses to get discrete energy levels for a particle in
a box, with $y$ replaced by the wavefunction $\psi$.

### Interferometers: Michelson (survey) and Mach–Zehnder (in full)

An **interferometer** splits a beam into two paths, lets them accumulate a
relative phase, and recombines them so that the phase difference is read
out as an intensity — turning an invisible phase into a measurable
brightness. Two standard layouts:

**Michelson interferometer (survey).** A beam splitter (BS) sends light
down two perpendicular arms, each ending in a mirror ($M_1$, movable;
$M_2$, fixed); both reflected beams return through the *same* BS and
recombine, traveling back toward the source (a small pickoff or the same
BS geometry routes the output to a detector). If $M_1$ is displaced by
$\Delta x$, the round trip in that arm changes by $2\Delta x$ (there and
back), giving phase $\phi=k(2\Delta x)=4\pi\Delta x/\lambda$ and detected
intensity that oscillates as $\cos^2(\phi/2)$ as $\Delta x$ is swept — a
displacement of just $\lambda/4$ (a fraction of a micron for visible light)
already carries $\phi$ through $\pi$, taking the output from bright to
dark (half a fringe cycle); a *full* bright-to-dark-to-bright cycle needs
$\phi$ to advance by $2\pi$, i.e. $\Delta x=\lambda/2$ — the standard
one-fringe-per-$\lambda/2$ result. Sub-micron mirror displacements are
therefore easily readable as whole fringes, which is why Michelson
interferometers are used for extremely sensitive length and vibration
measurements (famously, LIGO's gravitational-wave detectors are giant
Michelson interferometers).

**Mach–Zehnder (MZ) interferometer — full derivation.** The MZ splits a
beam at one beam splitter into two *spatially separate* arms and
recombines them at a *second* beam splitter, producing two distinct output
ports (unlike the Michelson, nothing retraces its path). This is the
layout Day 18 re-derives as a two-path qubit circuit, so every convention
below is stated explicitly so that re-derivation matches unambiguously.

Day 3 introduced the trick of bookkeeping oscillations as complex
exponentials ($x=\mathrm{Re}[\tilde A\,e^{i\omega t}]$); we use the same
device for fields: a phasor of length $A$ and angle $\alpha$ is the complex
number $A\,e^{i\alpha}$, and intensity is $|E|^2$. That is what motivates
writing a field's phase as $e^{i\phi}$ and its intensity as
$I_0=|E_0|^2$ below.

*Beam-splitter convention.* A lossless, 50/50 beam splitter must act as a
**unitary** transformation on its two input complex amplitudes $E_a,E_b$
(unitary, i.e. energy-preserving, because a beam splitter absorbs
nothing). Equal-magnitude, phase-free transmission and reflection at
*every* port cannot be unitary in general — Exercise 5 has you check this
directly — so real beam splitters carry a relative phase between the two
reflection paths. We adopt the standard real convention: transmission
carries no extra phase, and reflection carries a $\pi$ phase shift ($r\to
-r$) on one face but not the other. This gives the beam-splitter matrix
$$\begin{pmatrix}E_1\\E_2\end{pmatrix} = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}E_a\\E_b\end{pmatrix},$$
which is manifestly real, symmetric, and unitary
($M^TM=\tfrac12\begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}1&1\\1&-1\end{pmatrix}=\tfrac12\begin{pmatrix}2&0\\0&2\end{pmatrix}=I$),
so it conserves total intensity at every beam splitter individually, by
construction. We use this **same matrix for both beam splitters** in the
MZ (identical, ideal 50/50 splitters).

*Setup and propagation.* A single beam of amplitude $E_0$ enters input port
$a$ of BS1; port $b$ has nothing entering it ($E_b=0$). Immediately after
BS1, the two arms carry
$$E_{\text{arm}1} = \frac{E_0}{\sqrt2}, \qquad E_{\text{arm}2} = \frac{E_0}{\sqrt2}$$
(equal amplitude, no relative phase yet, from the matrix above with
$E_b=0$). The two arms then propagate to BS2; let $\phi$ be the *net* extra
phase arm 2 accumulates relative to arm 1 (from a path-length difference,
a glass sample, whatever — $\phi=0$ means the two arms are perfectly
balanced). Taking arm 1's phase as the reference,
$$E_{\text{arm}1}\to\frac{E_0}{\sqrt2}, \qquad E_{\text{arm}2}\to\frac{E_0}{\sqrt2}e^{i\phi}.$$

*Recombination at BS2.* Feeding these two arms into the same beam-splitter
matrix as its two inputs:
$$\begin{pmatrix}E_1\\E_2\end{pmatrix} = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}E_0/\sqrt2\\(E_0/\sqrt2)e^{i\phi}\end{pmatrix}
= \frac{E_0}{2}\begin{pmatrix}1+e^{i\phi}\\1-e^{i\phi}\end{pmatrix}.$$

*Intensities.* Using $|1+e^{i\phi}|^2=(1+\cos\phi)^2+\sin^2\phi=2+2\cos\phi=4\cos^2(\phi/2)$
and $|1-e^{i\phi}|^2=2-2\cos\phi=4\sin^2(\phi/2)$ (both by the
half-angle identity $1\pm\cos\phi=2\cos^2(\phi/2)$ or $2\sin^2(\phi/2)$),
and writing $I_0=|E_0|^2$:
$$\boxed{I_1 = I_0\cos^2(\phi/2), \qquad I_2 = I_0\sin^2(\phi/2).}$$
**Port labeling:** output port $1$ (the $\cos^2$ port) is the **bright
port** — at $\phi=0$ it receives $I_1=I_0$, all of the light, while port
$2$ receives $I_2=0$ and is the **dark port**. As $\phi$ increases from $0$
to $\pi$, the light smoothly redistributes until, at $\phi=\pi$, port $1$
is fully dark and port $2$ is fully bright. This labeling — port $1=\cos^2$
is bright at $\phi=0$, port $2=\sin^2$ is dark at $\phi=0$ — is exactly
what Day 18 must reproduce when it re-derives these same two curves as
qubit-amplitude probabilities.

**Energy conservation, checked at every phase.**
$$I_1+I_2 = I_0\cos^2(\phi/2)+I_0\sin^2(\phi/2) = I_0\big[\cos^2(\phi/2)+\sin^2(\phi/2)\big] = I_0$$
identically, for *every* value of $\phi$ — the two outputs are perfectly
**complementary**. No light is ever created or destroyed by the
interferometer; $\phi$ only steers how the fixed total $I_0$ splits between
the two ports.

> **Misconception:** "destructive interference destroys energy." It does
> not — energy is never created or destroyed by interference, only
> *redistributed* in space. When port 1 goes dark ($\phi=\pi$ above), that
> "missing" light has not vanished; it has all reappeared at port 2, exactly
> as the identity $I_1+I_2=I_0$ shows. Interference is a rearrangement of
> where energy goes, never a violation of energy conservation — the same
> point applies to the dark fringes in the two-slit pattern earlier in this
> file: the energy missing from a dark fringe shows up as extra energy in
> the neighboring bright fringes.

## Worked examples

**1. Two-slit fringe spacing.** A red laser ($\lambda=633\text{ nm}$)
illuminates two slits separated by $d=0.100\text{ mm}$, with a screen
$L=2.00\text{ m}$ away. Using $\Delta y=\lambda L/d$ derived above:
$$\Delta y = \frac{(633\times10^{-9})(2.00)}{1.00\times10^{-4}} = 1.266\times10^{-2}\text{ m} \approx 12.7\text{ mm}.$$
Bright fringes are spaced about $1.27\text{ cm}$ apart on the screen — easily
visible to the eye, which is why the two-slit experiment is such a
convenient classroom demonstration.

**2. String fixed at both ends: harmonic series and mode shapes.** A string
of length $L=0.50\text{ m}$ has wave speed $v=200\text{ m/s}$. Using
$f_n=nv/2L$ derived above:
$$f_1 = \frac{200}{2(0.50)} = 200\text{ Hz}, \qquad f_2=400\text{ Hz}, \qquad f_3=600\text{ Hz},$$
an evenly spaced harmonic series with fundamental $200\text{ Hz}$. Mode
shapes follow from $k_n=n\pi/L$ substituted into $y=2A\sin(k_nx)\cos(\omega_nt)$:
- $n=1$: $\sin(k_1x)=\sin(\pi x/L)$ peaks at $x=L/2$. Nodes only at the two
  fixed ends $x=0,L$; one antinode at the midpoint $x=L/2$.
- $n=2$: $\sin(2\pi x/L)$ has an additional node at $x=L/2$ (nodes at
  $0,L/2,L$); antinodes at $x=L/4$ and $x=3L/4$.
- $n=3$: nodes at $x=0,\,L/3,\,2L/3,\,L$; antinodes at $x=L/6,\,L/2,\,5L/6$.

Each successive mode adds exactly one more node between the fixed ends,
consistent with $k_n=n\pi/L$ giving $n-1$ interior nodes for mode $n$.

**3. Mach–Zehnder with a glass sample.** A glass slab of thickness
$t=2.5\ \mu\text{m}$ and index $n_g=1.50$ is inserted into arm 2 of an
otherwise perfectly balanced MZ ($\phi=0$ without it), illuminated at
vacuum wavelength $\lambda_0=500\text{ nm}$. Replacing a thickness $t$ of
air (index $1$) with glass (index $n_g$) changes the optical path length of
that arm by $(n_g-1)t$, adding phase
$$\phi = \frac{2\pi}{\lambda_0}(n_g-1)t = \frac{2\pi}{500\times10^{-9}}(0.50)(2.5\times10^{-6}) = 2\pi(2.5) = 5\pi.$$
Then $\phi/2=2.5\pi=2\pi+\pi/2$, so $\cos(\phi/2)=\cos(\pi/2)=0$ and
$\sin(\phi/2)=\sin(\pi/2)=1$:
$$I_1 = I_0\cos^2(2.5\pi) = 0, \qquad I_2 = I_0\sin^2(2.5\pi) = I_0.$$
Inserting this particular sample completely reverses the interferometer's
balance: the bright port and dark port swap entirely (port 1 goes fully
dark, port 2 goes fully bright) — exactly the kind of measurement that lets
an MZ interferometer determine a sample's thickness or index with
extraordinary precision from a simple brightness reading.

## Simulation

Run:
```
python3 code/day06_interference_standing_waves.py
```
Four analytic panels: **(a)** two-source interference intensity
$I(y)\propto\cos^2\!\left(\pi dy/(\lambda L)\right)$ across a screen, for an
adjustable source separation $d$; **(b)** beats — $y(t)=\cos\omega_1t+\cos
\omega_2t$ plotted with its envelope $\pm2\cos(\Delta\omega\,t/2)$ overlaid;
**(c)** the Mach–Zehnder outputs $I_1,I_2$ vs. $\phi\in[0,4\pi]$, plus their
sum plotted as a flat line at $I_0$; **(d)** the first three fixed-end
standing-wave modes $\sin(n\pi x/L)$ for $n=1,2,3$, each drawn at a few
time snapshots overlaid — the mode shape's zero-crossings (nodes) stay at
the same $x$ in every snapshot, only the amplitude between them changes
sign and size.

Before running, predict:
- If you move the two sources closer together (decrease $d$), do the
  fringes in panel (a) get wider or narrower? (Check against $\Delta
  y=\lambda L/d$ derived above before you look at the plot.)
- If you detune the two beat frequencies further apart in panel (b), does
  the envelope oscillate faster or slower?
- In panel (c), find the phase(s) where both MZ ports are exactly equal —
  what fraction of $I_0$ does each port carry there?
- In panel (d), for the $n=3$ mode, how many interior nodes (besides the
  two fixed ends) do you expect before you look — and does every time
  snapshot agree on where they sit?

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. Starting from two counter-propagating waves of equal amplitude and
   frequency, $y_R=A\sin(kx-\omega t)$ and $y_L=A\sin(kx+\omega t)$, use the
   angle-sum formulas to derive the standing-wave form
   $y=2A\sin(kx)\cos(\omega t)$.
2. Starting from the fixed-end boundary condition $y(0,t)=y(L,t)=0$ applied
   to $y=2A\sin(kx)\cos(\omega t)$, derive $k_n=n\pi/L$ and then
   $f_n=nv/2L$.

**Standard**

3. Two tuning forks are sounded together; fork A is known to be exactly
   $440\text{ Hz}$, and the pair produces a beat frequency of $4\text{
   Hz}$. A small piece of wax is stuck to fork B — which only ever *lowers*
   a fork's frequency — and the beat frequency drops to $2\text{ Hz}$.
   Determine fork B's original frequency, with your reasoning.
4. A pipe is closed at one end ($x=0$) and open at the other ($x=L$). The
   closed end must be a node (like a fixed string end); the open end is
   instead an **antinode**. Using $y=2A\sin(kx)\cos(\omega t)$, derive the
   allowed wavenumbers $k_n$ and frequencies $f_n$, and show that only *odd*
   multiples of the fundamental frequency appear.

**Stretch**

5. Re-derive both Mach–Zehnder output intensities step by step from the
   beam-splitter matrix given in the Theory section (show the two matrix
   multiplications explicitly), verify $I_1+I_2=I_0$ at a general phase
   $\phi$, and answer: at $\phi=\pi$, where did the light go? As a side
   check, show that a *hypothetical* beam splitter with no relative phase
   at all (replace the $-1$ in the matrix with $+1$) is **not** unitary,
   confirming that the $\pi$-phase convention is not optional.

## Hints

1. Expand $\sin(kx\mp\omega t)$ with the sine angle-sum formula and add the
   two expansions term by term — one pair of terms cancels.
2. The $x=0$ condition is automatic; the $x=L$ condition forces
   $\sin(kL)=0$ — solve for the allowed $k$, then use $\omega=vk$.
3. Work out both algebraically possible values of fork B's frequency
   before loading, then ask which one moving *downward* in frequency is
   consistent with the beat frequency decreasing.
4. Apply node-at-$x=0$ (automatic) and antinode-at-$x=L$ (i.e.
   $|\sin(kL)|=1$, not $\sin(kL)=0$) and see which integers $n$ satisfy it.
5. Just carry out the two matrix multiplications from the Theory section
   with a symbolic $\phi$; for the unitarity check, compute $M^TM$ with the
   sign flipped and see what it gives instead of $I$.

## Solutions

**1.** Expand both terms:
$$\sin(kx-\omega t) = \sin kx\cos\omega t - \cos kx\sin\omega t, \qquad
\sin(kx+\omega t) = \sin kx\cos\omega t + \cos kx\sin\omega t.$$
Adding: $y_R+y_L = A\left[2\sin kx\cos\omega t\right] = 2A\sin(kx)\cos(\omega t)$,
since the $\cos kx\sin\omega t$ terms are equal and opposite and cancel.

**2.** $y(0,t)=2A\sin(0)\cos(\omega t)=0$ for all $t$ automatically, since
$\sin 0=0$. At $x=L$: $y(L,t)=2A\sin(kL)\cos(\omega t)=0$ for *all* $t$
requires $\sin(kL)=0$ (the $\cos(\omega t)$ factor is not identically zero),
so $kL=n\pi$ for integer $n\ge1$ ($n=0$ gives the trivial $y\equiv0$), i.e.
$k_n=n\pi/L$. Using $\omega=vk$ (Day 5 dispersion relation),
$\omega_n=vk_n=nv\pi/L$, so $f_n=\omega_n/2\pi = nv/(2L)$.

**3.** Before loading, the beat frequency of $4\text{ Hz}$ means fork B is
either $440+4=444\text{ Hz}$ or $440-4=436\text{ Hz}$ — beats only reveal
$|f_A-f_B|$, not the sign. Loading fork B with wax can only *decrease*
$f_B$. If $f_B=444\text{ Hz}$, decreasing it moves it *toward* $440\text{
Hz}$, so $|f_A-f_B|$ shrinks — consistent with the observed drop to
$2\text{ Hz}$ (fork B would now be at $442\text{ Hz}$, or $438\text{ Hz}$
if loaded further past $440\text{ Hz}$ — either is consistent with a
$2\text{ Hz}$ beat, since beats only reveal $|f_A-f_B|$). If instead
$f_B=436\text{ Hz}$, decreasing it further moves it *away* from $440\text{
Hz}$, so the beat frequency could only grow, contradicting the observed
decrease. Hence fork B's original frequency was $\boxed{444\text{ Hz}}$.

**4.** Node at $x=0$ is automatic (as in Exercise 2). Antinode at $x=L$
means $|\sin(kL)|=1$, i.e. $kL = \dfrac{\pi}{2},\dfrac{3\pi}{2},\dfrac{5\pi}{2},\dots
= (2n-1)\dfrac{\pi}{2}$ for $n=1,2,3,\dots$ (even multiples of $\pi/2$ would
give $\sin=0$, a node, not an antinode — only odd multiples of $\pi/2$
work). So
$$k_n = \frac{(2n-1)\pi}{2L} \quad\Longrightarrow\quad f_n = \frac{vk_n}{2\pi} = \frac{(2n-1)v}{4L}, \quad n=1,2,3,\dots$$
The fundamental is $f_1=v/4L$, and every allowed frequency is
$f_n=(2n-1)f_1$ — an **odd-harmonics-only** spectrum ($f_1,3f_1,5f_1,\dots$),
in contrast to the fixed-fixed string's full harmonic series from Exercise
2. This is the same method (node/antinode boundary conditions on the same
standing-wave form) applied to a different physical boundary condition,
giving a qualitatively different spectrum.

**5.** Input $E_0$ into port $a$ of BS1 ($E_b=0$):
$$\begin{pmatrix}E_{\text{arm}1}\\E_{\text{arm}2}\end{pmatrix} = \frac1{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}E_0\\0\end{pmatrix} = \frac1{\sqrt2}\begin{pmatrix}E_0\\E_0\end{pmatrix}.$$
Arm 2 accumulates relative phase $\phi$: $(E_{\text{arm}1},E_{\text{arm}2})
\to (E_0/\sqrt2,\ (E_0/\sqrt2)e^{i\phi})$. Feed into BS2:
$$\begin{pmatrix}E_1\\E_2\end{pmatrix} = \frac1{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}E_0/\sqrt2\\(E_0/\sqrt2)e^{i\phi}\end{pmatrix} = \frac{E_0}{2}\begin{pmatrix}1+e^{i\phi}\\1-e^{i\phi}\end{pmatrix}.$$
Intensities: $I_1=|E_1|^2=\dfrac{I_0}{4}|1+e^{i\phi}|^2=\dfrac{I_0}{4}(2+2\cos\phi)=I_0\cos^2(\phi/2)$,
and similarly $I_2=\dfrac{I_0}{4}(2-2\cos\phi)=I_0\sin^2(\phi/2)$, using
$1\pm\cos\phi=2\cos^2(\phi/2)$ or $2\sin^2(\phi/2)$. Sum:
$$I_1+I_2 = I_0\left[\cos^2(\phi/2)+\sin^2(\phi/2)\right] = I_0$$
for every $\phi$, by the Pythagorean identity — energy is conserved at
every phase, not just special ones. At $\phi=\pi$: $I_1=I_0\cos^2(\pi/2)=0$
and $I_2=I_0\sin^2(\pi/2)=I_0$ — **all the light has moved to port 2**;
none was destroyed, it was entirely redirected to the other output.

*Unitarity check with the sign flipped:* replace the beam-splitter matrix
with the hypothetical, phase-free $M'=\frac1{\sqrt2}\begin{pmatrix}1&1\\1&1\end{pmatrix}$.
Then $M'^TM' = \frac12\begin{pmatrix}1&1\\1&1\end{pmatrix}\begin{pmatrix}1&1\\1&1\end{pmatrix}
= \frac12\begin{pmatrix}2&2\\2&2\end{pmatrix} = \begin{pmatrix}1&1\\1&1\end{pmatrix} \ne I.$
This is not unitary (its columns are not even orthogonal — both columns are
identical), so $M'$ would not conserve energy for a general input (e.g.
feeding in $E_a=1,E_b=-1$ gives outputs $(0,0)$, all the input energy
gone). The $\pi$-phase convention used throughout this file
($-1$, not $+1$, in the matrix) is exactly what is needed to make the
beam splitter unitary, confirming it is a physical requirement and not an
arbitrary bookkeeping choice.

## Connection to QM

Your course will send *single photons*, one at a time, through this exact
Mach–Zehnder layout. The classical amplitudes $E_1,E_2$ derived above
become quantum *probability amplitudes*, and the classical intensities
$I_1,I_2$ (fractions of the total classical energy $I_0$) become
*probabilities* of detecting the single photon at each output port — the
same $\cos^2(\phi/2)$ and $\sin^2(\phi/2)$ formulas, same beam-splitter
matrix, same complementarity ($I_1+I_2=I_0$ becomes $P_1+P_2=1$), just
reinterpreted. Day 18 will re-derive this entire calculation as a two-path
qubit circuit, using the port labeling fixed today (port 1 bright/$\cos^2$
at $\phi=0$, port 2 dark/$\sin^2$ at $\phi=0$) so that the two derivations
line up term for term.

The boxed sentence from the standing-wave section — "boundary conditions
turn a continuum of waves into a discrete list of modes" — is exactly the
mechanism Day 16 uses to get the particle-in-a-box's discrete energy
levels: the classical wave equation is replaced by the time-independent
Schrödinger equation, the fixed-end boundary conditions $y(0)=y(L)=0$
become $\psi(0)=\psi(L)=0$, and the same $k_n=n\pi/L$ quantization survives
essentially unchanged, now producing discrete *energies*
$E_n\propto k_n^2\propto n^2$ instead of discrete frequencies. Today's
purely classical derivation is, mechanically, a full dry run of that later
quantum calculation.
