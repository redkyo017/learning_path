# Day 8 — Light and Polarization as a Two-State System

## Learning objectives

By the end of today you should be able to:
- State what each of the four Maxwell equations says physically (its
  source and what it forbids), and explain why $c=1/\sqrt{\mu_0\varepsilon_0}$
  being numerically equal to the measured speed of light was a
  *calculation*, not an assumption.
- Describe an electromagnetic wave's anatomy: the relative orientation of
  $\vec E$, $\vec B$, and $\vec k$, their phase relationship, and how
  intensity relates to field amplitude.
- Write down the Jones vector for horizontal, vertical, diagonal, and
  circular polarization, and compute with them (inner products, norms,
  change of basis).
- Derive Malus's law $I=I_0\cos^2\theta$ as a projection followed by a
  squared modulus, and use it to solve multi-polarizer problems.
- Explain, using a one-line Jones-vector computation, how a quarter-wave
  plate converts linear polarization into circular.

Time budget: ~3.5 hours.

## Reference material

- Griffiths, *Introduction to Electrodynamics* — the chapter that derives
  the electromagnetic wave equation from Maxwell's equations in vacuum
  covers today's field-theory beats (beat 1–3 below) in full rigor; we
  only need its conclusions, not its derivation, so reading it is optional
  background rather than a prerequisite.
- Hecht, *Optics* — the chapter on polarization is the standard reference
  for Jones calculus, Malus's law, and wave plates, with far more device
  detail (real crystal materials, real retardance tolerances) than today's
  physics-only treatment needs.
- This file is self-contained: every equation used below is derived,
  motivated from a stated experimental fact, or explicitly flagged as
  taken from a cited result.
- Builds on Day 5 (the wave equation and the sinusoidal traveling-wave
  form $\cos(kx-\omega t)$) and Day 6 (superposition of waves). Nothing
  beyond those two days, plus the complex-vector-space and bra-ket
  material you already know from the quantum-computing path, is assumed.

## Theory

### Fields as physical objects: the Lorentz force law

Before writing down Maxwell's equations, it's worth being precise about
what $\vec E$ and $\vec B$ *are*. They are defined operationally by the
**Lorentz force law**: a particle of charge $q$ moving with velocity
$\vec v$ in given field $\vec E$ and $\vec B$ feels a force
$$\vec F = q\left(\vec E + \vec v\times\vec B\right).$$
This is how you'd measure $\vec E$ and $\vec B$ at a point in principle:
place a test charge there, measure the force at $\vec v=0$ (that's
$q\vec E$), then measure the extra velocity-dependent force (that's the
$q\vec v\times\vec B$ term). Fields defined this way are not bookkeeping
devices — they carry real energy and momentum, which is what lets light
(a self-sustaining disturbance in exactly these fields, as beat 2 below
establishes) deliver energy across empty space from the Sun to your skin,
or momentum to a solar sail.

### The four Maxwell equations, one sentence each

Maxwell's equations are four experimentally-motivated statements about how
$\vec E$ and $\vec B$ are sourced and how they relate to each other. We
state each in one sentence — what it says, and what it forbids — without
manipulating any of the underlying partial differential equations; that
manipulation is Griffiths's job, not today's.

- **Gauss's law for $\vec E$.** Electric charge is the source of the
  electric field: field lines diverge outward from positive charge and
  converge inward on negative charge, with the total flux through any
  closed surface proportional to the enclosed charge. It forbids electric
  field lines from simply appearing or vanishing in empty space with no
  charge present.
- **Gauss's law for $\vec B$ (no monopoles).** Magnetic field lines never
  begin or end anywhere — every one closes on itself or extends to
  infinity. It forbids the existence of an isolated magnetic charge (a
  "magnetic monopole"): magnets always come as N/S pairs, with no known
  exception.
- **Faraday's law.** A magnetic field that changes in time creates a
  circulating electric field around it. It forbids a static charge
  configuration from ever inducing a genuinely circulating $\vec E$ — that
  effect requires a *changing* $\vec B$, which is why a stationary magnet
  induces nothing in a nearby loop of wire but a moving one does.
- **The Ampère–Maxwell law.** Both electric currents and a changing
  electric field create a circulating magnetic field. Ampère's original
  law had only the current term; Maxwell's addition of the changing-$\vec
  E$ term closes the loop — a changing electric field creates a magnetic
  field just as a current does, which is exactly what lets the $\vec E$
  and $\vec B$ fields in a light wave continuously regenerate each other
  through empty space, with no current or charge required at all.

**The wave equation, and $c$.** Combining Faraday's law with the
Ampère–Maxwell law — a genuine derivation, but one requiring vector
calculus we're not doing today; take it as a cited result from Griffiths
— produces a wave equation for $\vec E$ (and separately for $\vec B$) in
vacuum, propagating at speed
$$c = \frac{1}{\sqrt{\mu_0\varepsilon_0}}.$$
Here $\mu_0$ and $\varepsilon_0$ are constants measured in entirely
electric and magnetic experiments — $\varepsilon_0$ from the force between
static charges (Coulomb's law), $\mu_0$ from the force between
current-carrying wires — with no light or optics involved at all.
Plugging in the measured values,
$$c = \frac{1}{\sqrt{(4\pi\times10^{-7}\ \text{T·m/A})(8.854\times10^{-12}\ \text{C}^2/\text{N·m}^2)}} \approx 3.00\times10^{8}\ \text{m/s},$$
which matches the independently measured speed of light to within
experimental error. This match is the single most consequential numerical
coincidence in the history of physics: "light is an electromagnetic wave"
was not proposed as a doctrine and then confirmed — it fell straight out
of a calculation Maxwell did with constants from static-electricity and
magnetism experiments, decades before anyone connected it to optics.

### Electromagnetic wave anatomy

The wave-equation solution for a plane wave traveling in direction $\vec
k$ has a specific, rigid geometric structure (again taken as a cited
consequence of Maxwell's equations, not re-derived):

- $\vec E$, $\vec B$, and the propagation direction $\vec k$ are mutually
  perpendicular: $\vec E\perp\vec B$, $\vec E\perp\vec k$, $\vec B\perp\vec
  k$. Light is a **transverse** wave, exactly as Day 5's string was;
  "polarization," defined precisely below, is simply the direction
  $\vec E$ points.
- $\vec E$ and $\vec B$ oscillate **in phase**: they reach zero together
  and their peaks coincide in time, unlike, say, position and velocity in
  an oscillator (Day 3), which are $90°$ out of phase.
- Their magnitudes are locked together, $|\vec E| = c|\vec B|$, at every
  instant and every point.
- **Intensity** — the energy flux, power per unit area — is proportional
  to the square of the field amplitude, $I\propto E_0^2$ (the same
  amplitude-squared rule you already met for mechanical wave energy in
  Day 5; here $E_0$ is the peak electric-field magnitude). This one fact is
  why Malus's law, derived below, involves the *square* of a projected
  amplitude: intensity goes as the square of the amplitude, so it
  responds to projections quadratically rather than linearly.

### Polarization: the direction of $\vec E$

**Polarization** is simply the direction $\vec E$ points as the wave
oscillates, viewed looking along $\vec k$. If $\vec E$ stays along a
fixed line, oscillating back and forth along it, the light is **linearly
polarized** along that line.

Now suppose two linearly polarized waves of equal amplitude, one along
$x$ and one along $y$, are combined (Day 6 superposition) with their
oscillations $90°$ out of phase — one traces $\cos(kx-\omega t)$, the
other $\cos(kx-\omega t + 90°) = -\sin(kx-\omega t)$. At a fixed point in
space, the tip of the resulting $\vec E$ vector traces
$$\vec E(t) \propto \big(\cos\omega t,\ -\sin\omega t\big),$$
a vector of constant length rotating uniformly in the $xy$-plane as time
advances — this is **circular polarization**. Two equal-amplitude linear
waves at $90°$ phase have combined into a single rotating field, not into
"some horizontal and some vertical light mixed together."

> **Misconception:** "circular polarization is a mixture of horizontal and
> vertical light." It is not a *mixture* — it is a **coherent
> superposition** of the two with a *definite, fixed relative phase*
> ($90°$) — and, remarkably, an ordinary linear polarizer cannot tell the
> two apart by itself. A linear polarizer at *any* angle $\theta$
> transmits exactly half the incident intensity from circular light, and
> an *equal incoherent mixture* of horizontal and vertical light *also*
> transmits exactly half through a linear polarizer at *any* angle
> $\theta$ — every single linear-polarizer setting gives the identical
> reading for both. What breaks the tie is a quarter-wave plate
> (introduced later in today's Theory) placed before the final polarizer:
> it converts circular light into a *definite* linear state, which the
> polarizer that follows then passes completely or blocks completely
> depending on its angle — whereas the same quarter-wave plate leaves an
> incoherent horizontal/vertical mixture as an incoherent
> horizontal/vertical mixture (each component is already an eigenstate of
> the plate), which still transmits exactly half through the final
> polarizer no matter how it's oriented. Deterministic pass-or-block after
> "quarter-wave-plate then polarizer" for the superposition, versus a
> stubborn, unbudgeable one-half for the mixture — that operational
> difference *is* the content of "coherent superposition $\ne$ mixture."
> It is one of the central distinctions the QM course spends real effort
> on (a mixed state vs. a pure superposition state, described by entirely
> different mathematical objects), and this is your first concrete,
> classical example of it.

### Jones vectors: polarization as a 2-dimensional complex vector space

A polarization state is completely specified by a **normalized
2-component complex vector** — a **Jones vector** — recording the
complex amplitude of the $E$-field's $x$- and $y$-components. Using
bra-ket labels for the four states you'll use constantly from here on:
$$|H\rangle = \binom{1}{0}, \qquad |V\rangle = \binom{0}{1}, \qquad
|D\rangle = \frac{1}{\sqrt2}\binom{1}{1}, \qquad
|R\rangle = \frac{1}{\sqrt2}\binom{1}{i}, \qquad
|L\rangle = \frac{1}{\sqrt2}\binom{1}{-i}.$$
$|H\rangle$ and $|V\rangle$ are horizontal and vertical linear
polarization; $|D\rangle$ is linear polarization along the $45°$
diagonal (equal real amplitude in both components — the two are exactly
in phase, giving a fixed line at $45°$, per the linear-polarization
construction above); $|R\rangle,|L\rangle$ are the two circular states
from the previous section, with the relative phase of $\pm90°$ encoded as
a factor of $\pm i$ (recall $i=e^{i\pi/2}$ is precisely a $90°$ phase
shift). Each is normalized under the complex inner product
$\langle\psi|\psi\rangle = \sum_i\psi_i^*\psi_i = 1$ — exactly the inner
product you built in the quantum-computing path, doing exactly the same
job: turning "total intensity is finite and fixed" into a clean algebraic
condition.

**A polarizer as a projection.** An ideal polarizer with transmission
axis along a unit direction $|n\rangle$ transmits only the component of
the incoming Jones vector along $|n\rangle$: the transmitted *amplitude*
is $\langle n|\psi\rangle$, and — because intensity is amplitude squared
— the transmitted *intensity* is $I = I_0|\langle n|\psi\rangle|^2$.
Crucially, the transmitted light doesn't just get dimmer: its new Jones
vector is $|n\rangle$ itself (rescaled), not the old $|\psi\rangle$
dimmed. The polarizer **re-aligns** whatever gets through to its own
axis.

> **Misconception:** "a polarizer acts as a sieve, passing through
> whatever light was already aligned with it unchanged, and blocking the
> rest." A sieve doesn't change the size of the particles that pass; a
> polarizer *does* change the polarization state of what passes — it
> **projects**. Every photon that makes it through emerges polarized
> exactly along the polarizer's own axis, regardless of its polarization
> beforehand (as long as it wasn't exactly perpendicular to that axis).
> This is precisely why a $45°$ polarizer inserted between two crossed
> ($0°$/$90°$) polarizers *increases* the transmitted light from zero to
> something nonzero — see Worked Example 1. A sieve could never do that;
> a projection can, because each polarizer resets the state before the
> next one measures it.

**Rotation.** A linear polarization state at angle $\theta$ to the
horizontal is $|\theta\rangle = \cos\theta\,|H\rangle + \sin\theta\,|V\rangle
= \binom{\cos\theta}{\sin\theta}$ — you can check this is normalized for
any $\theta$ since $\cos^2\theta+\sin^2\theta=1$, and reduces to $|H\rangle$
at $\theta=0$ and $|D\rangle$ at $\theta=45°$ exactly as it should. This
one-parameter family is the classical-optics avatar of a real-amplitude
qubit rotation.

The punchline of this section: **polarization is a 2-dimensional complex
vector space — the same arena as the qubit you met in the
quantum-computing path.** Everything you already know about $\mathbb C^2$,
inner products, normalization, and orthonormal bases applies here
directly; the only new content today is which physical states occupy
which vectors.

### Malus's law: projection, then square

Send linearly polarized light $|\theta\rangle=\binom{\cos\theta}{\sin\theta}$
(polarized at angle $\theta$ to the horizontal) through a polarizer whose
transmission axis is horizontal, $|H\rangle$. By the projection rule
above, the transmitted amplitude is
$$\langle H|\theta\rangle = (1,0)\binom{\cos\theta}{\sin\theta} = \cos\theta,$$
and since intensity is amplitude squared (the wave-anatomy fact
$I\propto E_0^2$ established earlier), the transmitted intensity is
$$I = I_0\cos^2\theta,$$
**Malus's law**: one projection ($\cos\theta$, the amplitude surviving),
then one squaring (to get from amplitude to intensity). Nothing about
this derivation depended on the axis being horizontal specifically — for
any two linear polarizers with relative angle $\theta$ between their
axes, the same two steps give the same law.

### Wave plates: birefringence and the quarter-wave plate

Some crystals (e.g. calcite, quartz) are **birefringent**: light
polarized along one crystal axis (the "fast" axis) travels at a different
speed than light polarized along the perpendicular axis (the "slow"
axis), because the material's refractive index genuinely differs between
the two directions. Passing a fixed thickness of such a crystal therefore
delays one polarization component's phase relative to the other by a
fixed amount — this is the entire mechanism of a **wave plate**: no
absorption, no filtering, just a relative phase shift between the two
linear components.

Fix a phase convention once, since wave plates are exactly where it
starts to matter: we write a wave's real field as
$E=\mathrm{Re}\!\left[A\,e^{i(kx-\omega t)}\right]$, so an added optical
delay $\delta$ multiplies that component's complex amplitude $A$ by
$e^{+i\delta}$. (The labels "right" and "left" attached to $|R\rangle$
and $|L\rangle$ above are themselves convention-dependent — different
texts assign the opposite handedness to the same $\pm i$ — but the
physical content, a fixed $\pm90°$ relative phase, is not.)

A **quarter-wave plate** (QWP) is cut to a thickness that introduces a
relative phase delay of exactly $\delta=90°$, i.e. a factor of
$e^{i\pi/2}=i$ under the convention just fixed, between the fast and slow
axes. Aligning the plate's fast axis with $|H\rangle$, its action on a
general input is the Jones matrix $M=\begin{pmatrix}1&0\\
0&i\end{pmatrix}$ (dropping an overall physically-irrelevant phase common
to both components — Exercise 5 makes precise why that's allowed). Acting
on the diagonal input $|D\rangle$:
$$M|D\rangle = \begin{pmatrix}1&0\\0&i\end{pmatrix}\frac{1}{\sqrt2}\binom{1}{1}
= \frac{1}{\sqrt2}\binom{1}{i} = |R\rangle.$$
One line: a quarter-wave plate turns diagonal linear polarization into
right-circular polarization, exactly as claimed. Worked Example 2 restates
this with the bookkeeping spelled out.

### Consolidation survey: DC circuits

*(Survey — paragraph depth, no derivations.)* A DC circuit is described by
three quantities: **voltage** $V$ (electric potential difference, in
volts, the energy per unit charge available to drive current between two
points), **current** $I$ (charge flow rate, in amps — this $I$ is
current, not the light intensity of earlier sections; the collision is
purely notational), and **resistance**
$R$ (a material property relating the two). For an ohmic resistor these
are tied together by the empirical relation $V=IR$ (**Ohm's law** — an
experimental fact about many materials, not a law of nature in the sense
Maxwell's equations are). Two bookkeeping rules, both direct consequences
of conservation laws you've already used all course: **Kirchhoff's current
law** (the total current flowing into any junction equals the total
current flowing out — charge conservation applied to a node) and
**Kirchhoff's voltage law** (the sum of voltage changes around any closed
loop is zero — energy conservation applied to a loop, since a charge
returning to its starting point has done zero net work). That's the whole
toolkit needed to analyze any DC resistor network; we stop here because
today's job is a *map* of where circuits sit in your physics, not circuit
problem-solving.

### Consolidation survey: geometric optics

*(Survey — paragraph depth, no derivations.)* **Geometric (ray) optics**
treats light as straight-line rays that bend at interfaces (reflection,
refraction via Snell's law) and are focused by lenses and mirrors to form
images — the framework behind cameras, telescopes, eyeglasses, and the
thin-lens equation $1/d_o+1/d_i=1/f$ relating object distance, image
distance, and focal length. It is an extremely good approximation
whenever every relevant length scale is much larger than the wavelength
of light, which is why it suffices for most everyday optical-instrument
design. We deliberately do not build ray optics up in this course: the
quantum mechanics this path leads to needs **wave optics** — interference,
diffraction, and (via today's polarization formalism) coherent
superposition of field amplitudes — because those are the phenomena with
direct quantum analogues (probability amplitudes interfering is
literally the same mathematics as light amplitudes interfering). Ray
optics is the $\lambda\to0$ limit of wave optics and would teach you
almost nothing about the amplitude/superposition structure the QM course
actually needs.

## Worked examples

**1. The three-polarizer puzzle: adding an obstacle that helps.**
Unpolarized light of intensity $I_0$ — modeled as an incoherent, uniformly
random mixture of linear polarization at every angle $\theta$ (in
contrast to the *coherent* superposition that makes circular polarization
a single definite state, per the misconception above) — is sent through a
polarizer at $0°$, then directly through a second polarizer at $90°$.
Since the two are crossed, whatever intensity survives the first
polarizer picks up a further factor of $\cos^2(90°)=0$ from Malus's law
at the second: nothing gets through, regardless of that first intensity's
value.

Now insert a third polarizer at $45°$ *between* the other two.

*Step 1 (unpolarized $\to$ $0°$ polarizer).* Averaging Malus's law over a
uniformly random incoming angle $\theta$ gives the transmitted fraction
$\langle\cos^2\theta\rangle = \frac{1}{2\pi}\int_0^{2\pi}\cos^2\theta\,d\theta
= \tfrac12$ (using $\cos^2\theta=\tfrac12(1+\cos2\theta)$, whose average
over a full period is $\tfrac12$). So $I_1 = I_0/2$, now polarized along
$0°$.

*Step 2 ($0°\to45°$ polarizer).* Malus's law with $\Delta\theta=45°$:
$I_2 = I_1\cos^2(45°) = \frac{I_0}{2}\cdot\frac12 = \frac{I_0}{4}$, now
polarized along $45°$.

*Step 3 ($45°\to90°$ polarizer).* Malus's law with $\Delta\theta=45°$
again: $I_3 = I_2\cos^2(45°) = \frac{I_0}{4}\cdot\frac12 = \boxed{\frac{I_0}{8}}$.

Inserting a third obstruction *increased* the transmitted light from
exactly zero to $I_0/8$ — impossible for a sieve, unremarkable for a
sequence of projections, each of which re-aligns the light to its own
axis before the next one acts.

**2. Quarter-wave plate on diagonal input, in full.** Input:
$|D\rangle=\frac{1}{\sqrt2}\binom11$. QWP with fast axis along $H$:
$M=\begin{pmatrix}1&0\\0&i\end{pmatrix}$. Output:
$$M|D\rangle = \begin{pmatrix}1&0\\0&i\end{pmatrix}\frac{1}{\sqrt2}\binom11
= \frac{1}{\sqrt2}\binom{1}{i} = |R\rangle,$$
right-circular polarization, normalized ($\tfrac12(1^2+|i|^2)=1$) exactly
as claimed in the theory section. Rotating the QWP by $45°$ so its fast
axis instead sits along $|D\rangle$ and $|{-}45°\rangle$ would instead
leave the input state $|D\rangle$ completely unchanged (it's an
eigenvector of the plate in that orientation) — a useful sanity check you
can verify yourself with the same matrix machinery.

**3. Laser-pointer photon flux — an order-of-magnitude estimate.** A
typical red laser pointer emits $P=1\text{ mW}$ at $\lambda=650\text{ nm}$.
Each photon carries energy $E=hf=hc/\lambda$ (this relation is *used*
here, not derived — Day 13 derives and justifies $E=hf$ properly; treat
this worked example as a forward-flagged estimate you'll revisit there):
$$E = \frac{hc}{\lambda} = \frac{(6.626\times10^{-34}\text{ J·s})(3.00\times10^8\text{ m/s})}{650\times10^{-9}\text{ m}}
\approx 3.06\times10^{-19}\text{ J} \approx 1.91\text{ eV}.$$
The photon *emission rate* is power divided by energy per photon:
$$\dot N = \frac{P}{E} = \frac{1\times10^{-3}\text{ J/s}}{3.06\times10^{-19}\text{ J}}
\approx 3.3\times10^{15}\text{ photons/s}.$$
Roughly three thousand trillion photons per second — a number so large
that the classical, continuous-intensity description used throughout
today's Jones-vector formalism is an excellent approximation for a laser
pointer, even though the underlying light is, at bottom, a stream of
discrete quanta. (Flag: Day 13, Exercise 4, revisits exactly this
calculation once $E=hf$ has been properly justified rather than merely
used.)

## Exercises

Attempt every problem closed-book before checking the Hints, and only
then the Solutions.

**Retrieval**

1. State, in one sentence each and closed-book, the physical meaning of
   all four Maxwell equations (Gauss's law for $\vec E$, Gauss's law for
   $\vec B$, Faraday's law, the Ampère–Maxwell law): what each one says is
   the source of a field, and what each one forbids.
2. Verify directly, using the complex inner product $\langle a|b\rangle =
   \sum_i a_i^*b_i$, that $|R\rangle=\frac{1}{\sqrt2}\binom1i$ is
   normalized, and that it is orthogonal to the opposite circular state
   $|L\rangle=\frac{1}{\sqrt2}\binom1{-i}$.

**Standard**

3. **Malus cascade.** $N$ ideal polarizers are placed in a row; the first
   is at angle $90°/N$ to the incoming light's polarization, and each
   subsequent one is rotated a further $90°/N$, so the last is at exactly
   $90°$ from the input. Light of intensity $I_0$, polarized at $0°$,
   enters. Find the transmitted intensity fraction as a function of $N$,
   and evaluate its limit as $N\to\infty$.
4. Decompose the diagonal state $|D\rangle=\frac{1}{\sqrt2}\binom11$ (a)
   in the $\{|H\rangle,|V\rangle\}$ basis, and (b) in the
   $\{|{+}45°\rangle,|{-}45°\rangle\}$ basis, where
   $|{+}45°\rangle=\frac{1}{\sqrt2}\binom11$ and
   $|{-}45°\rangle=\frac{1}{\sqrt2}\binom1{-1}$. What's qualitatively
   different about the two decompositions?

**Stretch**

5. Show that any normalized Jones vector can be written
   $\alpha|H\rangle+\beta|V\rangle$ with $|\alpha|^2+|\beta|^2=1$. Then, in
   one paragraph, explain why multiplying an entire Jones vector by a
   global phase $e^{i\varphi}$ (a fixed real $\varphi$, the same for both
   components) produces a state that is experimentally indistinguishable
   from the original under any intensity measurement.

## Hints

1. For each equation, ask: what physical quantity sources this field
   (charge, current, a changing field), and what specific thing would
   this equation *rule out* if it were violated (e.g. an isolated magnetic
   charge)? Don't reopen the theory section until you've written all four
   from memory.
2. Compute $\langle R|R\rangle$ and $\langle R|L\rangle$ by writing out
   $\langle R|=\frac{1}{\sqrt2}(1,-i)$ (conjugate-transpose the ket) and
   multiplying entrywise; remember $i^*=-i$ and $i\cdot i = -1$.
3. Apply Malus's law once per polarizer, using the *same* angle step
   $90°/N$ each time, and multiply the $N$ resulting factors together.
   For the limit, write $x=\pi/(2N)$ in radians and use the small-angle
   approximation $\cos^2x\approx1-x^2$ together with
   $(1-x^2)^N\approx e^{-Nx^2}$.
4. For (a), just read the components off the vector directly — no
   computation needed. For (b), look closely at how $|D\rangle$ and
   $|{+}45°\rangle$ were each defined above.
5. A general Jones vector is *already* a pair of two complex numbers —
   ask what those two numbers must be called to match the required form.
   For the phase part, write out the projection amplitude
   $\langle n|e^{i\varphi}\psi\rangle$ for a general measurement axis
   $|n\rangle$ and see what happens when you take its squared modulus.

## Solutions

**1.** *Gauss's law for $\vec E$:* electric charge sources the electric
field (field lines diverge from $+$ charge, converge on $-$ charge);
forbids field lines appearing/vanishing with no charge present. *Gauss's
law for $\vec B$:* there is no magnetic charge — field lines never begin
or end; forbids an isolated magnetic monopole. *Faraday's law:* a
time-changing magnetic field creates a circulating electric field;
forbids a static magnetic field from inducing any EMF (only a *changing*
one can). *Ampère–Maxwell law:* electric current and a time-changing
electric field both create a circulating magnetic field; the
changing-$\vec E$ term closes the loop, letting a changing $\vec E$
generate a $\vec B$ in vacuum with no current or charge needed at all —
exactly what lets the two fields in a light wave keep regenerating each
other.

**2.** Normalization: $\langle R|R\rangle = \left(\frac{1}{\sqrt2}\right)^2
\left(1^*\cdot1 + i^*\cdot i\right) = \frac12\left(1 + (-i)(i)\right) =
\frac12(1+1) = 1$, using $(-i)(i)=-i^2=1$. So $|R\rangle$ is normalized.
Orthogonality: writing $\langle R| = \frac{1}{\sqrt2}(1,-i)$ (conjugating
each entry of the ket, then treating it as a row),
$$\langle R|L\rangle = \frac{1}{\sqrt2}(1,-i)\cdot\frac{1}{\sqrt2}\binom{1}{-i}
= \frac12\left(1\cdot1 + (-i)\cdot(-i)\right) = \frac12\left(1+i^2\right)
= \frac12(1-1) = 0.$$
So $|R\rangle$ and $|L\rangle$ are orthogonal — the two circular states
form an orthonormal basis of the same $\mathbb C^2$, exactly as
$\{|H\rangle,|V\rangle\}$ and $\{|{+}45°\rangle,|{-}45°\rangle\}$ do.

**3.** Each polarizer contributes the same Malus factor $\cos^2(90°/N)$
relative to the one before it, and there are $N$ of them in a row, so the
transmitted fraction is
$$f(N) = \left[\cos^2\left(\frac{90°}{N}\right)\right]^N.$$
For the limit, write the step angle in radians as $x=\pi/(2N)$, so
$f(N)=[\cos^2x]^N=(1-\sin^2x)^N$. For large $N$, $x$ is small, so
$\sin^2x\approx x^2=\pi^2/(4N^2)$, giving
$$f(N) \approx \left(1-\frac{\pi^2}{4N^2}\right)^N \approx
\exp\left(-\frac{\pi^2}{4N}\right) \xrightarrow[N\to\infty]{} e^0 = 1.$$
(Numerically: $f(4)\approx0.531$, $f(10)\approx0.781$, $f(100)\approx0.976$,
$f(1000)\approx0.9975$ — climbing steadily to $1$.) So splitting a full
$90°$ rotation into more and more, smaller and smaller steps lets you
rotate the polarization through the same total angle with *vanishing*
photon loss in the limit — the discrete-polarizer analog of an adiabatic
rotation: many small, gentle nudges accomplish what one abrupt, large
change cannot.

**4.** (a) By direct inspection of the definition,
$|D\rangle=\frac{1}{\sqrt2}\binom11 = \frac{1}{\sqrt2}|H\rangle +
\frac{1}{\sqrt2}|V\rangle$: an even $50/50$ split between $|H\rangle$ and
$|V\rangle$, since $\left|\frac{1}{\sqrt2}\right|^2+\left|\frac{1}{\sqrt2}
\right|^2 = \tfrac12+\tfrac12=1$. (b) $|D\rangle$ *is* $|{+}45°\rangle$ by
definition — they're the same vector — so the decomposition in this
basis is trivial: $|D\rangle = 1\cdot|{+}45°\rangle + 0\cdot|{-}45°\rangle$.
What's qualitatively different: the same physical state looks like an
even, fully-spread superposition in one basis ($\{H,V\}$) and like a
single definite basis state (zero spread at all) in another
($\{{+}45°,{-}45°\}$) — "how spread out a state is" is not an intrinsic
property of the state, only of the state *relative to a chosen basis*,
exactly the same basis-dependence you already met for qubit superposition
in the quantum-computing path.

**5.** Any Jones vector is, by definition, a pair of complex numbers
$\binom{a}{b}$ for some $a,b\in\mathbb C$. Since $|H\rangle=\binom10$ and
$|V\rangle=\binom01$ form the standard basis of $\mathbb C^2$,
$$\binom ab = a\binom10+b\binom01 = a|H\rangle+b|V\rangle,$$
so simply setting $\alpha=a,\beta=b$ gives the required form for *any*
Jones vector — there is nothing left to prove beyond unpacking what
"standard basis" means. If the vector is normalized,
$\langle\psi|\psi\rangle=|\alpha|^2+|\beta|^2=1$ by definition of the
inner product, which is exactly the stated normalization condition.

For the phase part: let $|\psi'\rangle=e^{i\varphi}|\psi\rangle$ for some
fixed real $\varphi$. Any intensity measurement (through a polarizer, a
wave plate followed by a polarizer, anything at all) reduces to computing
$|\langle n|\psi'\rangle|^2$ for some measurement direction $|n\rangle$
(possibly complex, to allow circular/elliptical analyzers). Then
$$\left|\langle n|\psi'\rangle\right|^2 = \left|e^{i\varphi}\langle n|\psi
\rangle\right|^2 = \left|e^{i\varphi}\right|^2\left|\langle n|\psi\rangle
\right|^2 = \left|\langle n|\psi\rangle\right|^2,$$
since $|e^{i\varphi}|=1$ for any real $\varphi$ — the global phase factors
out of every squared modulus and vanishes identically, for *every* choice
of $|n\rangle$, not just one special measurement. So $|\psi\rangle$ and
$e^{i\varphi}|\psi\rangle$ predict identical outcomes for every possible
intensity measurement you could ever perform on the light: they are the
same physical state. This is the classical-optics version of the exact
statement the quantum-computing path makes about a qubit's global phase
being physically irrelevant — here it isn't a postulate, it's a directly
checkable fact about how squared moduli behave.

## Connection to QM

Malus's law *is* the Born rule for a polarization qubit: $\cos^2\theta$
is nothing but the transition probability $|\langle\theta|\psi\rangle|^2$
between two polarization states written in exactly the bra-ket notation
you already know, and the projection-then-square structure you derived
today is, symbol for symbol, the same structure the Born rule imposes on
every quantum measurement. When your QM course introduces the polarization
qubit — almost certainly the first physical qubit implementation it shows
you — it will use exactly the Jones vectors built today: $|H\rangle,
|V\rangle$ as the computational basis, $|D\rangle$ and $|{-}45°\rangle$ as
the Hadamard-rotated basis, $|R\rangle,|L\rangle$ as the "circular" basis
used for a different single-qubit measurement. Nothing about those
conventions changes between today and that lecture.

The three-polarizer puzzle is your first hands-on encounter with
**non-commuting measurements**: measuring "is it polarized at $0°$?" and
then "is it polarized at $45°$?" does not commute with measuring "is it
polarized at $0°$?" and then directly "is it polarized at $90°$?" — the
order and the intermediate measurement change the outcome probabilities,
precisely the phenomenon behind the quantum no-cloning intuition and the
uncertainty principle for non-commuting observables. And wave plates are,
literally, single-qubit unitary gates you can hold in your hand and
rotate with your fingers: a **half**-wave plate with its fast axis at
$22.5°$ implements exactly the Hadamard gate ($M(22.5°)=\frac{1}{\sqrt2}
\begin{pmatrix}1&1\\1&-1\end{pmatrix}$ sends $|H\rangle\mapsto|D\rangle$
and $|V\rangle\mapsto|{-}45°\rangle$, turning a basis state into an equal
superposition), while today's quarter-wave plate implements a different
single-qubit unitary — the one that turns a linear basis state into a
circular one — built from nothing but birefringent crystal geometry
rather than abstract linear algebra. Your
course's photonics labs, whenever they arrive, will be running Jones-
vector arithmetic identical to today's — the polarizing beamsplitters,
wave plates, and detectors on an optical table are exactly the physical
Jones-calculus machinery this day built from Maxwell's equations up.
