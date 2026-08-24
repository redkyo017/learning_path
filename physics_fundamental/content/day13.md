# Day 13 — Blackbody Radiation and the Photon

## Learning objectives

By the end of today you should be able to:
- Count the standing-wave modes of a 1D cavity honestly from Day 6's
  $f_n=nv/2L$, and state (without re-deriving in full) why the 3D result
  scales as $dN/df\propto f^2$, including where the polarization factor of
  $2$ comes from.
- Combine mode counting with classical equipartition to derive the
  Rayleigh–Jeans law, and explain precisely why it predicts infinite energy
  in any warm cavity (the ultraviolet catastrophe).
- Re-derive the mode-average energy with Planck's discrete-energy
  assumption $E_n=nhf$, carrying the geometric-series partition-function
  calculation through every step to $\langle E\rangle=hf/(e^{hf/k_BT}-1)$,
  and assemble Planck's law from it.
- Extract Wien's displacement law and the Stefan–Boltzmann $T^4$ law as
  consequences of Planck's law, and use both numerically.
- Analyze the photoelectric effect's three experimental facts, show where
  the classical wave picture fails on each, and derive
  $eV_{\mathrm{stop}}=hf-\phi_w$ from photon energy conservation.
- Explain, with a concrete numerical example, why "photon energy" and
  "light intensity" are independent knobs — one set by frequency, one by
  photon number.

Time budget: ~3.5 hours.

## Reference material

- Eisberg & Resnick, *Quantum Physics of Atoms, Molecules, Solids, Nuclei,
  and Particles* — the chapters on blackbody radiation and the
  photoelectric effect are the standard rigorous historical treatment of
  everything below, including the original experimental facts tables.
- Halliday, Resnick & Walker, *Fundamentals of Physics*, the "modern
  physics" chapters near the end of the book — a gentler, more numerical
  companion covering the same material with more worked problems.
- This file is self-contained: every equation is derived below from
  material already in this course.
- Builds directly on Day 6 (standing-wave mode quantization $f_n=nv/2L$
  from boundary conditions), Day 8 (the factor of 2 from two independent
  polarizations of a transverse EM wave; also closes Day 8's forward flag
  from its Worked Example 3), and Day 12 (the Boltzmann factor, the
  partition function $Z$, $\langle E\rangle=\sum_iE_iP(E_i)$, equipartition
  at $\tfrac12k_BT$ per quadratic term, and the warning that assigning
  $k_BT$ to infinitely many modes cannot end well).

## Theory

### The blackbody problem: the crisis of 1900

A **blackbody** is an idealized object that absorbs all radiation falling
on it at every wavelength (hence "black") and, in thermal equilibrium at
temperature $T$, re-emits radiation with a spectrum that experiment shows
depends on *nothing but $T$* — not the material, not the shape, not
anything else. A convenient physical realization is a cavity with a small
hole: radiation bounces around inside, is absorbed and re-emitted by the
walls until it reaches thermal equilibrium with them, and a small sample
leaks out the hole with the universal equilibrium spectrum. Measuring that
spectrum — energy density per unit frequency, as a function of $f$, at
fixed $T$ — was one of the best-measured curves in physics by 1900. No
known theory fit it. The whole content of today is the story of why the
obvious classical calculation fails badly, and the one non-classical
patch (Planck's) that fixes it completely.

### Counting cavity modes: 1D honestly, 3D by scaling

**1D, done in full.** Day 6 derived, from the fixed-end boundary condition
on a string of length $L$, the discrete allowed frequencies
$$f_n = \frac{nv}{2L}, \qquad n=1,2,3,\dots$$
An electromagnetic cavity of length $L$ with conducting walls (field forced
to zero at each wall, exactly the fixed-string boundary condition) supports
standing electromagnetic modes with the identical structure, $v\to c$:
$$f_n = \frac{nc}{2L}.$$
How many modes have frequency at or below some value $f$? Solving
$f_n\le f$ for $n$ gives $n\le 2Lf/c$, so the mode count is
$$N(f) = \frac{2Lf}{c} \qquad\Longrightarrow\qquad \frac{dN}{df} = \frac{2L}{c}$$
— a constant mode density in 1D. This is nothing but Day 6's harmonic
series, counted rather than listed.

**3D, by stated scaling.** A cubical cavity of side $L$ supports modes
indexed by three positive integers $(n_x,n_y,n_z)$, one per spatial
direction, each obeying the same standing-wave logic as the 1D case
independently along its own axis:
$$f = \frac{c}{2L}\sqrt{n_x^2+n_y^2+n_z^2} \equiv \frac{c}{2L}\,n, \qquad n=\sqrt{n_x^2+n_y^2+n_z^2}.$$
Each allowed triple $(n_x,n_y,n_z)$ is one lattice point, spaced by $1$
along each axis, in the positive octant of an abstract "$n$-space." The
number of modes with frequency at or below $f$ is the number of lattice
points inside the sphere of radius $n=2Lf/c$ — and since the points are
spaced by exactly $1$, that count is well approximated (for large $n$) by
the *volume* of the region: one-eighth of a sphere of radius $n$ (only the
positive octant is physical), doubled once more for the two independent
transverse polarizations a traveling EM wave carries (Day 8: a light wave
has exactly two orthogonal polarization states for any given direction and
frequency, and each is an independent mode here):
$$N(f) = 2\times\frac18\times\frac{4}{3}\pi n^3 = \frac{\pi}{3}\left(\frac{2Lf}{c}\right)^3 = \frac{8\pi L^3f^3}{3c^3}.$$
Differentiating, and writing $V=L^3$ for the cavity volume,
$$\boxed{\frac{dN}{V\,df} = \frac{8\pi f^2}{c^3}}$$
— the number of modes per unit volume per unit frequency interval. The
geometric content of that whole paragraph is the "shell in $n$-space"
picture: modes with frequency between $f$ and $f+df$ live in a thin
spherical shell of radius $n$ and thickness $dn$, whose volume grows as
$n^2\,dn \propto f^2\,df$ — that single scaling, $dN/df\propto f^2$, is the
one fact from this derivation that matters below; the constant out front
is bookkeeping.

### Rayleigh–Jeans and the ultraviolet catastrophe

Classically, treat each cavity mode as an independent oscillator in
thermal equilibrium at temperature $T$. Day 12's equipartition theorem
assigns $\tfrac12k_BT$ per quadratic degree of freedom; an oscillating EM
mode has two such terms (electric-field energy and magnetic-field energy,
playing the role kinetic and potential energy play for a mechanical
oscillator), giving each mode an average energy
$$\langle E\rangle_{\text{classical}} = k_BT$$
regardless of its frequency — the classical average is frequency-blind.
Multiplying by the mode density derived above gives the classical
prediction for the spectral energy density (energy per unit volume per
unit frequency):
$$u_{\text{RJ}}(f) = \frac{8\pi f^2}{c^3}\cdot k_BT = \frac{8\pi k_BT}{c^3}f^2 \qquad \textbf{(Rayleigh–Jeans law)}.$$
This matches experiment beautifully at low frequency. But the total energy
density in the cavity is $\int_0^\infty u_{\text{RJ}}(f)\,df$, and that
integral **diverges** — $f^2$ grows without bound, so the classical
prediction is that *every* warm cavity contains infinite electromagnetic
energy, concentrated at arbitrarily high (ultraviolet and beyond)
frequency. This is the **ultraviolet catastrophe**, and it is exactly the
danger Day 12 flagged in its closing paragraph: assign $k_BT$ to every one
of an infinite family of modes and the sum cannot possibly converge.
Equipartition, a theorem that works perfectly for the finite handful of
degrees of freedom in an ideal gas, is being asked here to hold for
infinitely many oscillators at once — and the crisis of 1900 is that
question, cashed in as an experimentally falsified prediction.

### Planck's move — the centerpiece: quantizing the exchange

Planck's fix was surgical: keep every other classical ingredient (the mode
counting above, thermal equilibrium, the Boltzmann-factor machinery of
Day 12) and change exactly one assumption — that a mode of frequency $f$
can only exchange energy with the cavity walls in whole multiples of a
fixed quantum:
$$E_n = nhf, \qquad n=0,1,2,3,\dots,$$
for a new constant $h$ to be fixed by matching experiment. This is
*not* yet "light comes in photon particles" — it is a statement about
how a mode's energy is restricted, formally identical to Day 12's
discrete-energy-level machinery. With this restriction, the average
energy of a mode is no longer the classical $k_BT$; it must be recomputed
using Day 12's partition-sum recipe, $\langle E\rangle = \sum_n E_n P(E_n)$
with $P(E_n)\propto e^{-E_n/k_BT}$ (the Boltzmann factor).

**The geometric series, done in full.** Let $x \equiv e^{-hf/k_BT}$
(so $0<x<1$ for any $f,T>0$). The partition function is the geometric
series
$$Z = \sum_{n=0}^\infty e^{-nhf/k_BT} = \sum_{n=0}^\infty x^n = \frac{1}{1-x}$$
(the standard geometric-series sum, valid since $|x|<1$). The unnormalized
numerator needs $\sum_n n\,x^n$, obtained by differentiating the geometric
series itself with respect to $x$:
$$\sum_{n=0}^\infty x^n = \frac{1}{1-x} \quad\xrightarrow{\ d/dx\ }\quad \sum_{n=0}^\infty n\,x^{n-1} = \frac{1}{(1-x)^2} \quad\xrightarrow{\ \times\, x\ }\quad \sum_{n=0}^\infty n\,x^n = \frac{x}{(1-x)^2}.$$
Then
$$\langle E\rangle = \frac{\sum_n nhf\,x^n}{\sum_n x^n} = hf\cdot\frac{x/(1-x)^2}{1/(1-x)} = hf\cdot\frac{x}{1-x}.$$
Substituting back $x=e^{-hf/k_BT}$ and multiplying numerator and
denominator by $e^{hf/k_BT}$ to clear the negative exponent,
$$\frac{x}{1-x} = \frac{e^{-hf/k_BT}}{1-e^{-hf/k_BT}} = \frac{1}{e^{hf/k_BT}-1},$$
giving the final result
$$\boxed{\langle E\rangle = \frac{hf}{e^{hf/k_BT}-1}}$$
— every step shown, no step skipped. (Worked Example 1 restates this
computation on its own, with commentary, for closed-book retrieval
practice.)

### Two limits, one formula

**Low frequency, $hf/k_BT\to0$.** Write $\varepsilon=hf/k_BT$ and Taylor
expand the exponential: $e^\varepsilon-1 = \varepsilon+\tfrac12\varepsilon^2+\cdots
= \varepsilon\left(1+\tfrac12\varepsilon+\cdots\right)$. Then
$$\langle E\rangle = \frac{hf}{\varepsilon\left(1+\tfrac12\varepsilon+\cdots\right)} = \frac{k_BT}{1+\tfrac12\varepsilon+\cdots} \;\xrightarrow[\varepsilon\to0]{}\; k_BT,$$
recovering the classical equipartition result exactly — at low frequency,
the discreteness of $E_n=nhf$ is invisible because $k_BT$ is huge compared
to the spacing $hf$ between adjacent allowed energies, and a coarse-grained
staircase looks like a continuum.

**High frequency, $hf/k_BT\to\infty$.** Now $\varepsilon\gg1$, so
$e^\varepsilon\gg1$ and $e^\varepsilon-1\approx e^\varepsilon$:
$$\langle E\rangle \approx \frac{hf}{e^{hf/k_BT}} = hf\,e^{-hf/k_BT} \;\xrightarrow[f\to\infty]{}\; 0$$
exponentially — high-frequency modes are almost never excited at all,
because reaching even their first excited state ($n=1$, energy $hf$)
already costs far more than the thermal budget $k_BT$ has on offer. These
modes are said to **freeze out**.

> **Misconception:** "Planck proposed that light is made of particles
> (photons)." He did not — and the distinction is both historically and
> conceptually real, not pedantic. Planck quantized only the *exchange* of
> energy between the cavity's oscillating modes and its walls, treated it
> explicitly as a calculational device to force agreement with experiment,
> and by his own later account was uncomfortable with it for years,
> hoping a classical justification would eventually be found. Light
> itself, in Planck's picture, still propagated as a continuous
> electromagnetic wave between emission and absorption events — only the
> exchange was granular. It was **Einstein**, in 1905, who made the far
> bolder claim that light *itself*, in transit through empty space with no
> walls or matter anywhere nearby, exists as localized quanta of energy
> $hf$ — the photoelectric section below is exactly that claim, and it is
> a logically separate step from anything Planck asserted five years
> earlier.

### Planck's law, assembled

Multiply the corrected mode-average energy by the same mode density
derived earlier — nothing about the mode-counting geometry changed, only
what each mode's average energy actually is:
$$\boxed{u_{\text{Planck}}(f) = \frac{8\pi f^2}{c^3}\cdot\frac{hf}{e^{hf/k_BT}-1} = \frac{8\pi h f^3}{c^3\left(e^{hf/k_BT}-1\right)}}$$
— **Planck's radiation law**. At low $f$ it reduces to the Rayleigh–Jeans
law exactly (the low-frequency limit above gives back $\langle
E\rangle\to k_BT$, recovering $u_{\text{RJ}}(f)=8\pi k_BTf^2/c^3$
term for term). At high $f$ it is suppressed by the exponential freeze-out
factor, $u_{\text{Planck}}(f)\to (8\pi h/c^3)f^3e^{-hf/k_BT}$, which falls
to zero far faster than $f^2$ ever grows — so
$\int_0^\infty u_{\text{Planck}}(f)\,df$ **converges**, and the ultraviolet
catastrophe is gone. One curve, agreeing with the classical prediction
exactly where classical physics was already known to be right, and
curing it exactly where classical physics was catastrophically wrong.

### Wien's displacement law

Every Planck curve has a single peak; where it sits should depend on $T$.
Converting Planck's law to a wavelength density with $f=c/\lambda$,
$df=-(c/\lambda^2)\,d\lambda$ (the sign flips because increasing $\lambda$
means decreasing $f$; the intensity carried by a frequency interval must
equal that carried by the corresponding wavelength interval),
$$u(\lambda) = \frac{8\pi hc}{\lambda^5}\cdot\frac{1}{e^{hc/\lambda k_BT}-1}.$$
Maximizing over $\lambda$ at fixed $T$: writing $a\equiv hc/k_BT$ and
differentiating $u(\lambda)=8\pi hc\,\lambda^{-5}\left(e^{a/\lambda}-1\right)^{-1}$
with the product and chain rules, setting $du/d\lambda=0$ and simplifying
leaves (after substituting $x\equiv a/\lambda = hc/\lambda k_BT$) the
**transcendental equation**
$$\frac{x\,e^x}{e^x-1} = 5 \qquad\Longleftrightarrow\qquad (x-5)e^x+5=0,$$
which has no closed-form solution (an $x$ and an $e^x$ can't be
algebraically untangled) but is solved numerically to
$$x \approx 4.9651.$$
Since $x=hc/\lambda_{\max}k_BT$ at the peak, this rearranges to
$$\boxed{\lambda_{\max}T = b}, \qquad b = \frac{hc}{4.9651\,k_B} \approx 2.898\times10^{-3}\ \text{m·K}$$
— **Wien's displacement law**: the peak wavelength moves *inversely* with
$T$ (hotter objects peak at *shorter* wavelength — "displaced" toward
blue/UV), with the numerical constant $b$ traceable, step by step, to the
root of that one transcendental equation.

### Stefan–Boltzmann law

The total energy density is $u=\int_0^\infty u_{\text{Planck}}(f)\,df$.
Substituting $x=hf/k_BT$ (so $f=k_BTx/h$, $df=(k_BT/h)\,dx$):
$$u = \frac{8\pi h}{c^3}\left(\frac{k_BT}{h}\right)^4\int_0^\infty\frac{x^3}{e^x-1}\,dx.$$
The remaining integral is a standard one (it is, in fact, $\Gamma(4)\zeta(4)$
— a Gamma function times a Riemann zeta value, the origin of the specific
number rather than something to re-derive here) and evaluates to
$$\int_0^\infty\frac{x^3}{e^x-1}\,dx = \frac{\pi^4}{15}.$$
So
$$u = \frac{8\pi^5k_B^4}{15h^3c^3}\,T^4 \qquad\Longrightarrow\qquad \boxed{u \propto T^4}$$
— the **Stefan–Boltzmann law**. (Converting this volume energy density to
power radiated per unit surface area introduces one further geometric
factor of $c/4$, giving the familiar $P/A=\sigma T^4$ with
$\sigma\approx5.67\times10^{-8}\ \text{W/m}^2\text{K}^4$; the $T^4$
scaling itself, which is the physics content, is already visible above.)
The finiteness of this integral — contrasted with the Rayleigh–Jeans
integral's outright divergence — is the ultraviolet catastrophe's cure,
stated as a number.

### The photoelectric effect: three facts the wave picture cannot explain

Shine light on a clean metal surface in vacuum and measure the ejected
electrons ("photoelectrons"). Three facts, all solidly established by
experiment before 1905:

| Experimental fact | Classical wave prediction | What actually happens |
|---|---|---|
| **Threshold frequency.** No electrons at all below some $f_0$, however intense the light. | None expected — enough intensity (energy delivered over time) at *any* frequency should eventually eject electrons. | No emission below $f_0$, at any intensity, ever. |
| **Instantaneous emission.** Electrons appear with no measurable delay, even in very dim light. | A delay is expected at low intensity — the electron should need time to absorb enough wave energy to escape (like slowly heating water to boiling). | Emission is immediate, even at the lowest intensities tested. |
| **Effect of intensity.** Brighter light increases the emitted *current*, but never the electrons' maximum kinetic energy. | Brighter light means more energy in the wave, which should raise the energy delivered to (and hence the KE of) each ejected electron. | Only raising the *frequency* raises the maximum KE; intensity only raises the *number* of electrons per second. |

Classical electromagnetism — a continuous wave delivering energy smoothly
and cumulatively to whatever it illuminates — is wrong on every single
row.

**Einstein's fix.** Treat light, in transit, as arriving in discrete
quanta (**photons**) each carrying energy $E=hf$ — the same $h$ Planck's
blackbody fit already needed, now promoted from "quantized exchange" to
"the light itself is grainy," the leap flagged in the misconception above.
A photon is absorbed by (at most) one electron, all-or-nothing. Ejecting
an electron costs a fixed minimum energy $\phi_w$, the **work function** —
the energy binding the most weakly held electron to the metal. Energy
conservation for the most energetic ejected electrons (those requiring
only the minimum $\phi_w$) gives
$$hf = \phi_w + K_{\max},$$
where $K$ is kinetic energy (this day's notation; $\phi_w$ always carries
the subscript $w$ to keep it distinct from the phase $\phi$ used
elsewhere in this course). Applying a reverse ("stopping") voltage
$V_{\text{stop}}$ just large enough to halt even the fastest electrons,
$eV_{\text{stop}}=K_{\max}$, gives
$$\boxed{eV_{\text{stop}} = hf - \phi_w}.$$

This single relation explains all three facts at once: a threshold
$f_0=\phi_w/h$ exists because $hf<\phi_w$ simply cannot eject an electron,
no matter how many such (too-weak) photons arrive per second; emission is
instantaneous because each photon-electron interaction is a single
one-shot quantum event, with no energy to accumulate over time; and
intensity (more photons per second) raises only the *number* of
independent one-shot events per second — the *current* — while each
individual event still transfers exactly $hf$, set by frequency alone.

> **Misconception:** "brighter light means more energetic ejected
> electrons." It does not. *Brighter* means *more photons per second*
> arriving, which ejects *more* electrons per second (more current) — but
> each photon still carries exactly $hf$, the same energy as a dim beam of
> the same color. Only raising the *frequency* raises the energy available
> per photon, and hence the maximum kinetic energy each ejected electron
> can carry. "Brighter" and "more energetic per electron" are answers to
> two entirely different questions — one about photon number, one about
> photon energy — and $E=hf$ is precisely the statement that only
> frequency controls the second one.

**Millikan's slope.** Plotting $V_{\text{stop}}$ against $f$ for several
frequencies of light on the same metal gives a straight line with slope
$h/e$ and $y$-intercept $-\phi_w/e$ — Robert Millikan spent nearly a
decade trying to experimentally disprove Einstein's photon hypothesis and
instead measured exactly this straight line, extracting a value of $h$
that matched Planck's blackbody-derived constant to within about half a
percent, becoming light-quanta's most reluctant and most convincing
witness.

## Worked examples

**1. The geometric-series computation of $\langle E\rangle$, start to
finish.** With $x=e^{-hf/k_BT}$, the partition function is
$Z=\sum_{n=0}^\infty x^n = 1/(1-x)$. Differentiating the same series with
respect to $x$ and multiplying by $x$ gives $\sum_n n\,x^n = x/(1-x)^2$.
The average energy is the ratio
$$\langle E\rangle = \frac{\sum_n nhf\,x^n}{\sum_n x^n} = hf\cdot\frac{x/(1-x)^2}{1/(1-x)} = \frac{hf\,x}{1-x}.$$
Restoring $x=e^{-hf/k_BT}$ and multiplying top and bottom by $e^{hf/k_BT}$:
$$\frac{x}{1-x} = \frac{e^{-hf/k_BT}}{1-e^{-hf/k_BT}}\cdot\frac{e^{hf/k_BT}}{e^{hf/k_BT}} = \frac{1}{e^{hf/k_BT}-1}.$$
So $\langle E\rangle = hf/(e^{hf/k_BT}-1)$. Sanity check at $hf/k_BT=1$
(numerically, $x=e^{-1}\approx0.368$): $\langle E\rangle = hf\cdot
0.368/(1-0.368) = hf\cdot0.582$ — comfortably between the classical value
$hf\cdot1$ (at $hf/k_BT\to0$, in units where $k_BT=hf$) and the frozen-out
value $hf\cdot0$, exactly the intermediate regime the two limiting cases
above bracket.

**2. The Sun as a blackbody.** The Sun's surface temperature is
$T\approx5800\ \text{K}$. By Wien's law derived above,
$$\lambda_{\max} = \frac{b}{T} = \frac{2.898\times10^{-3}\ \text{m·K}}{5800\ \text{K}} \approx 5.00\times10^{-7}\ \text{m} = 500\ \text{nm}.$$
$500\ \text{nm}$ sits almost exactly in the middle of the visible band
($\sim400$–$700\ \text{nm}$) — the Sun's spectrum peaks in green light, and
human vision, unsurprisingly, evolved its peak sensitivity right there too.

**3. Photoelectric stopping potential for sodium.** Sodium's work function
is $\phi_w\approx2.28\ \text{eV}$. Illuminate it with violet light,
$\lambda=400\ \text{nm}$. Using the convenient conversion
$hc\approx1240\ \text{eV·nm}$ (derived once: $hc=(6.626\times10^{-34}\
\text{J·s})(3.00\times10^8\ \text{m/s})=1.988\times10^{-25}\ \text{J·m}$,
and $1.988\times10^{-25}\ \text{J·m}/(1.602\times10^{-19}\ \text{J/eV}) =
1.241\times10^{-6}\ \text{eV·m} = 1241\ \text{eV·nm}$), the photon energy
is
$$hf = \frac{hc}{\lambda} = \frac{1240\ \text{eV·nm}}{400\ \text{nm}} = 3.10\ \text{eV}.$$
Threshold check first: the threshold wavelength is $\lambda_0 = hc/\phi_w =
1240/2.28 \approx 544\ \text{nm}$, and $400\ \text{nm} < 544\ \text{nm}$
(shorter wavelength means higher frequency), so this light is above
threshold and electrons *are* emitted. Then
$$K_{\max} = hf - \phi_w = 3.10 - 2.28 = 0.82\ \text{eV} \qquad\Longrightarrow\qquad V_{\text{stop}} = \frac{K_{\max}}{e} = 0.82\ \text{V}.$$

## Simulation

Run:
```
python3 code/day13_blackbody_curves.py
```
Two panels: **(a)** Planck spectral curves $u(f)$ at $T=3000,\,4500,\,5800\
\text{K}$, each with a vertical dashed line marking that curve's Wien peak
$\lambda_{\max}$ (or $f_{\max}$), and the visible band shaded for
reference; **(b)** Planck vs. Rayleigh–Jeans at $T=5800\ \text{K}$ on
log-log axes, showing the two curves overlapping at low frequency and the
Rayleigh–Jeans curve diverging upward while Planck's curve turns over and
falls at high frequency.

Before running, predict:
- Double $T$ — the peak moves which way, and the area grows by what
  factor? (Check against Wien's law and the Stefan–Boltzmann $T^4$ scaling
  derived above before you look at the plot.)
- Where exactly do the RJ and Planck curves agree, and why there?
- At the Sun's temperature, is the peak inside the visible band?

*The script ships separately; the predict-prompts stand on their own.*

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. Reproduce, closed-book, the geometric-series derivation of
   $\langle E\rangle = hf/(e^{hf/k_BT}-1)$ starting from $E_n=nhf$ and the
   Boltzmann factor $P(E_n)\propto e^{-E_n/k_BT}$.
2. State the three experimental photoelectric facts (threshold, timing,
   effect of intensity) and, for each, state precisely what the classical
   wave picture wrongly predicts.

**Standard**

3. The cosmic microwave background radiation is an almost perfect
   blackbody spectrum at $T=2.7\ \text{K}$. Find $\lambda_{\max}$ using
   Wien's law, then the corresponding photon energy $hf=hc/\lambda_{\max}$
   in eV, and compare it to $k_BT$ at the same temperature.
4. A photon counter registers a light power of $1\ \text{nW}$ at
   $\lambda=500\ \text{nm}$. How many photons per second is that? (This
   closes Day 8's Worked Example 3 forward flag — the same style of
   calculation, now with $E=hf$ properly justified rather than merely
   used.)

**Stretch**

5. Starting from $\langle E\rangle=hf/(e^{hf/k_BT}-1)$, show by Taylor
   expansion that $\langle E\rangle\to k_BT$ as $hf/k_BT\to0$, and that
   $\langle E\rangle\to hf\,e^{-hf/k_BT}$ as $hf/k_BT\to\infty$. In one
   paragraph, explain how a single formula can contain both classical
   physics (where it worked) and classical physics's death (where it
   didn't).

## Hints

1. Write $x=e^{-hf/k_BT}$, sum the geometric series for $Z$, then get
   $\sum_n n x^n$ by differentiating the geometric series with respect to
   $x$ and multiplying by $x$ — don't try to sum $\sum n x^n$ from
   scratch.
2. For each fact, ask what a continuous wave delivering energy smoothly
   over time would predict, then contrast with what quantized, one-shot
   photon absorption predicts instead.
3. Compute $\lambda_{\max}=b/T$ first, then use $hf=hc/\lambda_{\max}$ with
   the $hc\approx1240\ \text{eV·nm}$ shortcut; separately compute $k_BT$ in
   eV using $k_B\approx8.617\times10^{-5}\ \text{eV/K}$, and take the
   ratio.
4. Convert the photon wavelength to a photon energy in joules first (via
   $hc\approx1240\ \text{eV·nm}$, then eV$\to$J), then divide the given
   power by that single-photon energy.
5. For the low-frequency limit, expand $e^\varepsilon-1$ to first order in
   $\varepsilon=hf/k_BT$; for the high-frequency limit, note $e^\varepsilon
   \gg1$ so $e^\varepsilon-1\approx e^\varepsilon$. For the essay part,
   think about which limit reproduces equipartition and which one is the
   mechanism that kills the ultraviolet catastrophe.

## Solutions

**1.** With $x=e^{-hf/k_BT}$: $Z=\sum_{n=0}^\infty x^n=1/(1-x)$.
Differentiating $\sum_n x^n=1/(1-x)$ with respect to $x$ gives $\sum_n
n\,x^{n-1}=1/(1-x)^2$; multiplying both sides by $x$ gives $\sum_n
n\,x^n=x/(1-x)^2$. Then
$$\langle E\rangle = \frac{\sum_n E_nP(E_n)}{\sum_nP(E_n)} = \frac{\sum_n nhf\,x^n}{\sum_n x^n} = hf\cdot\frac{x/(1-x)^2}{1/(1-x)} = \frac{hf\,x}{1-x}.$$
Substituting $x=e^{-hf/k_BT}$ back and multiplying numerator and
denominator by $e^{hf/k_BT}$:
$$\frac{x}{1-x} = \frac{e^{-hf/k_BT}\cdot e^{hf/k_BT}}{(1-e^{-hf/k_BT})\cdot e^{hf/k_BT}} = \frac{1}{e^{hf/k_BT}-1},$$
so $\langle E\rangle = hf/(e^{hf/k_BT}-1)$, as required.

**2.** *Threshold:* classical wave picture predicts electrons are ejected
at *any* frequency, given enough intensity or time; actual result is a
hard threshold $f_0$ below which no emission occurs at any intensity.
*Timing:* classical picture predicts a measurable delay at low intensity
(time needed to accumulate enough wave energy); actual result is
instantaneous emission at every intensity. *Effect of intensity:*
classical picture predicts brighter light delivers more energy per
electron (higher $K_{\max}$); actual result is that intensity changes only
the number of electrons emitted per second (current), never $K_{\max}$,
which depends on frequency alone.

**3.** Wien: $\lambda_{\max}=b/T = (2.898\times10^{-3}\ \text{m·K})/(2.7\
\text{K}) \approx 1.073\times10^{-3}\ \text{m} = 1.07\ \text{mm}$ (in the
microwave band, as the name "cosmic microwave background" promises).
Photon energy: converting $\lambda_{\max}$ to nm, $1.073\times10^{-3}\
\text{m} = 1.073\times10^6\ \text{nm}$, so
$$hf = \frac{1240\ \text{eV·nm}}{1.073\times10^6\ \text{nm}} \approx 1.16\times10^{-3}\ \text{eV}.$$
$k_BT$ at $T=2.7\ \text{K}$: $k_BT = (8.617\times10^{-5}\ \text{eV/K})(2.7\
\text{K}) \approx 2.33\times10^{-4}\ \text{eV}$. The ratio
$hf/k_BT \approx 1.16\times10^{-3}/2.33\times10^{-4} \approx 5.0$ — which
is exactly the Wien constant $x\approx4.965$ found in the Theory section,
since that constant is, by construction, the ratio $hf_{\max}/k_BT$ at
*any* temperature. The peak photon energy always sits at about $5k_BT$,
never at $1k_BT$ — a fact hidden inside Wien's law that this exercise
makes explicit.

**4.** Photon energy at $\lambda=500\ \text{nm}$:
$$hf = \frac{1240\ \text{eV·nm}}{500\ \text{nm}} = 2.48\ \text{eV} = (2.48)(1.602\times10^{-19}\ \text{J}) \approx 3.97\times10^{-19}\ \text{J}.$$
Photon rate is power divided by energy per photon:
$$\dot N = \frac{P}{hf} = \frac{1\times10^{-9}\ \text{W}}{3.97\times10^{-19}\ \text{J}} \approx 2.5\times10^{9}\ \text{photons/s}.$$
About two and a half billion photons per second — a genuinely countable
rate for modern single-photon detectors, unlike Day 8's laser-pointer
estimate of $\sim10^{15}$ photons/s, which is utterly uncountable and
looks perfectly continuous. Same formula, same $E=hf$, six orders of
magnitude of power apart is the entire difference between "count them one
at a time" and "measure a smooth intensity."

**5.** *Low frequency:* let $\varepsilon=hf/k_BT\to0$. Taylor expand
$e^\varepsilon-1 = \varepsilon+\tfrac12\varepsilon^2+O(\varepsilon^3) =
\varepsilon\left(1+\tfrac12\varepsilon+O(\varepsilon^2)\right)$. Then
$$\langle E\rangle = \frac{hf}{\varepsilon\left(1+\tfrac12\varepsilon+\cdots\right)} = \frac{hf}{\varepsilon}\cdot\frac{1}{1+\tfrac12\varepsilon+\cdots} = k_BT\left(1-\tfrac12\varepsilon+\cdots\right) \xrightarrow[\varepsilon\to0]{} k_BT,$$
using $hf/\varepsilon=k_BT$ by definition of $\varepsilon$. *High
frequency:* let $\varepsilon\to\infty$. Then $e^\varepsilon\gg1$, so
$e^\varepsilon-1\approx e^\varepsilon$ to arbitrarily good accuracy, giving
$\langle E\rangle \approx hf/e^\varepsilon = hf\,e^{-hf/k_BT} \to 0$.
*Essay:* the low-frequency limit is exactly classical equipartition,
$\langle E\rangle=k_BT$ — where energy quanta $hf$ are minuscule next to
the thermal budget $k_BT$, the discreteness of $E_n=nhf$ is
unmeasurably fine-grained, and the classical continuum picture is an
excellent approximation, which is *why* classical physics worked at all
for the frequencies and temperatures physicists had easy experimental
access to before 1900. The high-frequency limit is the opposite regime:
once a single quantum $hf$ costs far more than the available thermal
energy $k_BT$, a mode essentially never acquires even its first quantum,
and its average energy collapses exponentially toward zero — this is
precisely the mechanism, absent from the classical calculation, that
tames the $f^2$ growth of the mode density and rescues the total energy
integral from divergence. One formula, one parameter ($hf/k_BT$) sweeping
from $0$ to $\infty$, contains the entire story: classical physics is the
$\varepsilon\to0$ shadow of a deeper quantized theory, and its failure at
high frequency is that same theory's $\varepsilon\to\infty$ shadow.

## Connection to QM

$E=hf$ is the first genuinely quantum equation in this entire course —
everything before today (waves, oscillators, statistical mechanics) was
100% classical physics, however suggestively it was arranged. From here
forward, your QM course will treat "a field mode is a quantized
oscillator with energy levels spaced by $hf$" (equivalently $\hbar\omega$,
since $\omega=2\pi f$) as a basic building block, not a special case: it
is the seed of quantum optics, and the same mode-quantization logic
derived today from a mirrored cavity is exactly what underlies a laser
cavity, a microwave resonator, or a single trapped photon in an optical
fiber. Days 14 and 15 will use $E=hf$ directly and repeatedly, treating
today's derivation — not just the formula, but the fact that it comes
from restricting a classical mode to discrete energy — as already
established.

There is also a direct, concrete link back to Day 6 and Day 8's
Mach–Zehnder interferometer: the classical field amplitudes that
interfered there, port by port, are — once you take today's step
seriously — amplitudes for finding a *single photon*, a quantum of
exactly the energy $hf$ derived today, at one output port or the other.
The photonics-flavored quantum optics your course builds toward manipulates
precisely these mode quanta in interferometers structurally identical to
Day 6's, with the classical intensities $I_1,I_2$ reinterpreted as photon
detection probabilities. Today's derivation is what makes that
reinterpretation legitimate rather than a change of vocabulary.
