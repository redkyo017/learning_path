# Day 12 — Minimal Thermal Physics

## Learning objectives

By the end of today you should be able to:
- Explain temperature operationally, as a parameter that fixes the *average*
  energy per accessible mode of a system in thermal equilibrium — not the
  system's total energy.
- State the Boltzmann factor $P(E_i)\propto e^{-E_i/k_BT}$, motivate it from a
  small system exchanging energy with a large reservoir, and use it to
  compare the relative population of two energy levels.
- Build a partition function $Z=\sum_i e^{-E_i/k_BT}$ for a discrete set of
  levels and compute a thermal average $\langle E\rangle=\sum_i E_iP(E_i)$
  from it, including fully working the two-level system (populations vs.
  $T$, high-$T$ saturation, low-$T$ freeze-out).
- State the equipartition theorem, derive the $\tfrac12k_BT$-per-quadratic-
  term result for one degree of freedom, and apply it to count degrees of
  freedom in the classical oscillator and an ideal-gas atom.
- Predict, and explain in one paragraph why, equipartition must fail once a
  system has infinitely many modes.
- Recall $k_BT\approx1/40$ eV at room temperature as a working anchor value.

Time budget: ~3.5 hours.

## Reference material

- Schroeder, *An Introduction to Thermal Physics*, the chapters introducing
  the Boltzmann factor, the partition function, and equipartition — the
  closest match to today's scope and level.
- Halliday/Resnick/Walker, *Fundamentals of Physics*, the kinetic-theory and
  temperature chapters, for the ideal-gas and RMS-speed side of today in a
  more elementary register.
- This file is self-contained: every result below is derived or explicitly
  motivated from scratch; the texts above are useful for a second pass in
  different words, not required to do today's work.
- Builds on Day 3's harmonic oscillator (natural frequency $\omega_0$,
  spring constant $k_s=m\omega_0^2$, and its two quadratic energy terms) and
  Day 10's phase space $(q,p)$ — today is the first day that puts a
  probability distribution on that space rather than tracking one exact
  trajectory through it.

## Theory

### Why this day exists

This day exists to make tomorrow's blackbody derivation honest. Day 13
fixes the nineteenth century's worst theoretical failure — classical
physics predicting infinite energy radiated by any warm object — and the
fix requires exactly three tools: the Boltzmann factor, a partition-function
average over discrete levels, and the equipartition theorem (so you can see
precisely what it is that equipartition gets wrong). Today builds those
three tools and nothing more: this is the minimum thermal physics a
first course in quantum mechanics assumes you already have, not a
substitute for a real statistical-mechanics course.

### Temperature, operationally

Forget, for a moment, any definition of temperature involving thermometers
or mercury columns. Operationally, **temperature** is the single parameter
$T$ that controls how a system's energy is distributed, in equilibrium,
among its accessible states — some states more populated, some less, in a
pattern set entirely by $T$ (made precise in the next two sections). Two
systems placed in contact and left alone reach a common $T$ because that is
the single distribution both settle into once energy has had time to
redistribute; "thermal equilibrium" *means* "described by one shared $T$."

The natural energy scale that comes with a given $T$ is $k_BT$, where
$k_B=1.380649\times10^{-23}\text{ J/K}$ is Boltzmann's constant — the
conversion factor between the everyday temperature scale (kelvin) and an
energy. In electron-volts, $k_B=8.617\times10^{-5}\text{ eV/K}$. Today (and
Days 13–15) fix one convention for "room temperature," $T=300\text{ K}$, so
every numeric example below uses the same number:
$$k_BT \approx (8.617\times10^{-5}\text{ eV/K})(300\text{ K}) \approx 0.0259\text{ eV}.$$
$$\boxed{k_BT \approx 0.0259\text{ eV} \approx \frac{1}{40}\text{ eV at }T=300\text{ K (room temperature).}}$$
The precise value is $0.0259$ eV; "$\approx1/40$ eV" is the traditional
rounded mnemonic, and the two are used interchangeably below. This number
is worth memorizing outright: it recurs, unchanged, in Days 13–15 every
time something is compared against "the thermal energy scale."

### The Boltzmann factor, motivated lightly

Take a small system (it could be a single atom, a single vibrational mode,
anything with a short list of possible energies $E_i$) placed in contact
with a much larger **reservoir** — everything else, with a huge number of
internal degrees of freedom — with which it can freely exchange energy,
the total $E_{\text{tot}}=E_i+E_{\text{res}}$ held fixed. The system is
overwhelmingly more likely to be found in whichever of its own states $E_i$
leaves the reservoir with the *largest* number of accessible microstates,
because — this is the one fact about large systems this argument borrows
from a full stat-mech course, stated without proof — the number of
microstates of a big system grows so explosively fast with its energy that
essentially all the probability sits wherever that count is largest. Write
$\Omega_{\text{res}}(E)$ for that count and $S_{\text{res}}=k_B\ln
\Omega_{\text{res}}$ for the reservoir's entropy (defined properly in the
survey below); the probability of finding the small system at energy $E_i$
is proportional to $\Omega_{\text{res}}(E_{\text{tot}}-E_i)$.

Here is the one exponential step. Since the reservoir is huge and $E_i$ is
comparatively tiny, Taylor-expand $S_{\text{res}}$ to first order around
$E_{\text{tot}}$:
$$S_{\text{res}}(E_{\text{tot}}-E_i) \approx S_{\text{res}}(E_{\text{tot}}) - E_i\left.\frac{\partial S_{\text{res}}}{\partial E}\right|_{E_{\text{tot}}}.$$
The operational definition of temperature (borrowed here, proved properly
in a stat-mech course) is exactly $\partial S/\partial E=1/T$, so this reads
$S_{\text{res}}(E_{\text{tot}}-E_i)\approx S_{\text{res}}(E_{\text{tot}}) -
E_i/T$. Exponentiating ($\Omega_{\text{res}}=e^{S_{\text{res}}/k_B}$):
$$\Omega_{\text{res}}(E_{\text{tot}}-E_i) \approx \Omega_{\text{res}}(E_{\text{tot}})\, e^{-E_i/k_BT},$$
and since $P(E_i)\propto\Omega_{\text{res}}(E_{\text{tot}}-E_i)$ with the
$T$-independent prefactor $\Omega_{\text{res}}(E_{\text{tot}})$ absorbed
into the proportionality, this is exactly the **Boltzmann factor**:
$$\boxed{P(E_i) \propto e^{-E_i/k_BT}.}$$
That is the whole lightweight argument: state counting in words, one
Taylor expansion, one exponentiation. A real derivation — justifying why
$\Omega_{\text{res}}$ grows fast enough for the linear expansion to be the
whole story, and why $\partial S/\partial E=1/T$ is the right definition of
$T$ in the first place — is exactly what a first statistical-mechanics
course spends several weeks establishing rigorously; today only needs the
result.

> **Misconception: "at temperature $T$, every particle has energy
> $k_BT$."** The Boltzmann factor is a *distribution*, not a single value:
> most particles sit at low $E_i$ (where $e^{-E_i/k_BT}$ is largest) and a
> shrinking tail sits at high $E_i$, with $k_BT$ setting the scale over
> which the population falls off, not a value every particle takes. The
> two-level worked example below makes this concrete: even at $k_BT=\Delta$,
> the two populations are $73\%$ and $27\%$, never $50/50$, and never a
> single shared energy.

### Partition function and thermal averages: the two-level system

For a system with a discrete list of energies $E_0,E_1,E_2,\dots$, the
Boltzmann factor is turned into an actual probability by normalizing it —
dividing by the sum of the un-normalized weights over *every* state, so
that the probabilities add to 1. That sum is the **partition function**,
$$Z = \sum_i e^{-E_i/k_BT}, \qquad P(E_i) = \frac{e^{-E_i/k_BT}}{Z},$$
and $Z$ exists purely to make $\sum_iP(E_i)=1$ hold, which it does
immediately: $\sum_iP(E_i)=\frac{1}{Z}\sum_ie^{-E_i/k_BT}=\frac{Z}{Z}=1$.
Once you have $Z$ and the $P(E_i)$, the **thermal average** of the energy
is the ordinary probability-weighted sum
$$\langle E\rangle = \sum_i E_iP(E_i) = \frac{\sum_i E_ie^{-E_i/k_BT}}{Z}.$$

The simplest nontrivial case, and today's running example, is a **two-level
system**: a ground state at $E_0=0$ and one excited state at $E_1=\Delta$
(any gap $\Delta>0$ — a spin in a field, a two-level atom, anything with
exactly two accessible states). Then
$$Z = e^{-0/k_BT} + e^{-\Delta/k_BT} = 1 + e^{-\Delta/k_BT},$$
$$P(E_0) = \frac{1}{1+e^{-\Delta/k_BT}}, \qquad P(E_1) = \frac{e^{-\Delta/k_BT}}{1+e^{-\Delta/k_BT}}.$$
Two limits are worth holding in your head permanently, since Worked example
1 below computes them numerically. As $T\to0$, $\Delta/k_BT\to\infty$, so
$e^{-\Delta/k_BT}\to0$: $P(E_0)\to1$ and $P(E_1)\to0$ — the system is
**frozen out** into the ground state, because there simply isn't enough
thermal energy on offer to reach the gap. As $T\to\infty$,
$\Delta/k_BT\to0$, so $e^{-\Delta/k_BT}\to1$: $P(E_0)\to\tfrac12$ and
$P(E_1)\to\tfrac12$ — the populations **saturate** at equal occupation, not
because the excited state becomes preferred, but because an
infinitely-large thermal energy budget can no longer distinguish a finite
gap $\Delta$ from zero. Exercise 5 makes this saturation exact and
quantitative in $\langle E\rangle$.

> **Misconception: "temperature measures total energy."** A struck match
> and a bathtub of warm water can have the *same* temperature while the
> bathtub holds vastly more total energy (far more molecules, each
> contributing its share) — and a tiny spark can be at a temperature far
> higher than the bathtub's while carrying far less total energy overall.
> Temperature fixes the *distribution per mode* (via the Boltzmann factor
> above) — an intensive quantity, the same at every point in a uniform
> system regardless of its size — while total energy is *extensive*, scaling
> with how much stuff there is. Confusing the two makes statements like
> "the spark is hotter, so it must carry more energy" feel obvious when
> they are not.

### Equipartition: $\tfrac12k_BT$ per quadratic term

Many mechanical energies are **quadratic** in some variable: kinetic energy
$K=p^2/2m$ is quadratic in momentum $p$; a spring's potential energy
$\tfrac12k_sx^2$ (Day 3) is quadratic in displacement $x$. For any such
term, write it generically as $\varepsilon(\xi)=\tfrac12a\xi^2$ for a
constant $a>0$ and a variable $\xi$ (either a momentum or a position) that
classically ranges continuously over all real values. The Boltzmann factor
now weights a *continuum* of values of $\xi$ rather than a discrete list, so
the sums above become integrals:
$$\langle\varepsilon\rangle = \frac{\displaystyle\int_{-\infty}^{\infty}\tfrac12a\xi^2\,e^{-a\xi^2/2k_BT}\,d\xi}{\displaystyle\int_{-\infty}^{\infty}e^{-a\xi^2/2k_BT}\,d\xi}.$$
Both integrals are Gaussian integrals; writing $\alpha:=a/2k_BT$ to shorten
the notation, the two standard results (stated here from a table of
integrals, not re-derived — that derivation belongs to a calculus or
stat-mech course, not today) are
$$\int_{-\infty}^{\infty}e^{-\alpha\xi^2}\,d\xi = \sqrt{\frac{\pi}{\alpha}}, \qquad \int_{-\infty}^{\infty}\xi^2e^{-\alpha\xi^2}\,d\xi = \frac{1}{2\alpha}\sqrt{\frac{\pi}{\alpha}}.$$
Substituting,
$$\langle\varepsilon\rangle = \frac{\tfrac12a\cdot\frac{1}{2\alpha}\sqrt{\pi/\alpha}}{\sqrt{\pi/\alpha}} = \frac{a}{4\alpha} = \frac{a}{4\left(\dfrac{a}{2k_BT}\right)} = \frac{k_BT}{2}.$$
$$\boxed{\langle\varepsilon\rangle = \tfrac12k_BT \text{ per quadratic degree of freedom.}}$$
Notice the constant $a$ canceled completely — the result is $\tfrac12k_BT$
for *any* quadratic term, regardless of whether it is heavy or light,
stiff or soft, momentum or position. This is the **equipartition theorem**:
every independent quadratic term in a classical system's energy carries the
same average energy, $\tfrac12k_BT$, no more and no less.

The Day 3 harmonic oscillator has exactly two such terms — kinetic
$p^2/2m$ and potential $\tfrac12k_sx^2$ — so equipartition gives its total
average energy as
$$\langle E_{\text{osc}}\rangle = \tfrac12k_BT + \tfrac12k_BT = k_BT,$$
a result that, remarkably, does not depend on $\omega_0=\sqrt{k_s/m}$ at
all: a stiff oscillator and a soft one, at the same temperature, carry the
same average energy. Worked example 2 below applies this directly; Exercise
2 applies the same counting logic to a monatomic ideal-gas atom (three
translational quadratic terms only), and Exercise 4 to a full diatomic
molecule (translation, rotation, *and* vibration).

For a mole of particles it's standard to restate the same prediction as a
**molar heat capacity**, $C_V:=d\langle E\rangle/dT$, using the gas
constant $R:=N_Ak_B\approx8.31\text{ J/(mol·K)}$ ($N_A$ is Avogadro's
number — $R$ is just $k_B$ rescaled to a per-mole basis). An average
energy $\langle E\rangle=\tfrac{n}{2}k_BT$ per particle, for $n$ quadratic
terms, corresponds to $C_V=\tfrac{n}{2}R$ per mole — the same counting,
in whichever unit ($k_BT$ per particle or $R$ per mole) a given problem
asks for; Exercise 4 below uses the per-mole form.

### Where equipartition must fail

Equipartition's result, $\tfrac12k_BT$ per mode, does not depend on which
mode you pick or on any property of that mode beyond "it's quadratic" —
every accessible quadratic degree of freedom gets an equal, fixed share of
$k_BT$, independent of how many other modes exist. That independence is
exactly the seam that tears. If a physical system possesses only finitely
many quadratic modes, the total average energy is finite, and everything
above is fine. But if a system has *infinitely many* accessible modes — and
Day 13 will show that an electromagnetic field trapped in a box is exactly
such a system, with one independent oscillator mode for every possible
standing-wave pattern the box can support, and no upper limit on how many
wiggles a standing wave can have — then equipartition assigns $\tfrac12k_BT$
to each of infinitely many modes, and the total predicted energy is
infinite. At *any* nonzero temperature. This is not a subtle correction
needed at extreme conditions; it is total, immediate nonsense the moment you
add up infinitely many equal, nonzero shares. Hold this thought for exactly
one day.

### Survey: entropy, in two paragraphs

**Entropy** is a count, dressed in convenient units. For a system with
$\Omega$ equally likely microscopic arrangements ("microstates") consistent
with some macroscopic description ("macrostate" — a given total energy, a
given volume, and so on), the entropy is defined as $S:=k_B\ln\Omega$. The
logarithm is there so that entropy adds when independent systems are
combined (two independent systems with $\Omega_1$ and $\Omega_2$
microstates have $\Omega_1\Omega_2$ joint microstates, and
$\ln(\Omega_1\Omega_2)=\ln\Omega_1+\ln\Omega_2$), matching the everyday
intuition that entropy, like energy or volume, should be extensive. This is
precisely the $\Omega_{\text{res}}$ and $S_{\text{res}}$ used to motivate
the Boltzmann factor above — nothing new is being introduced here beyond a
name and a formal definition for an idea already at work in that argument.

The reason entropy tends to increase in an isolated system left alone is
not a mysterious force pushing it that way — it is that macrostates with
larger $\Omega$ have overwhelmingly more microstates than macrostates with
smaller $\Omega$, for any system with a large number of particles, so a
system started in an unusual, low-$\Omega$ configuration and then left to
evolve through its available microstates essentially always ends up
looking like one of the enormously more numerous high-$\Omega$
configurations soon after — not because any individual microstate is
favored, but because there are astronomically more of the high-$\Omega$
kind to end up in. A full stat-mech course makes this statistical argument
precise and quantifies exactly how overwhelming "overwhelmingly" is; today
this is stated only at the level needed to make sense of the four
sentences below.

### Survey: the laws of thermodynamics, in four sentences

The **zeroth law**: if two systems are each in thermal equilibrium with a
third, they are in thermal equilibrium with each other — the fact that
makes "temperature" a single, transitive, well-defined quantity at all. The
**first law**: energy is conserved, $dU=dQ-dW$, where $dQ$ is heat added to
a system and $dW$ is work done *by* the system on its surroundings. The
**second law**: the total entropy of an isolated system never decreases,
which is the precise statement behind the loose sense above that systems
drift toward their overwhelmingly more probable, higher-$\Omega$
configurations. The **third law**: as $T\to0$, the entropy of a system
approaches a constant (often zero), reflecting that a system's ground state
typically has vastly fewer accessible microstates than any state at
nonzero temperature.

## Worked examples

**1. Two-level system: populations at $k_BT=0.1\Delta,\ \Delta,\ 10\Delta$.**
Using $P(E_0)=1/(1+e^{-\Delta/k_BT})$ and $P(E_1)=e^{-\Delta/k_BT}/(1+e^{-\Delta/k_BT})$
from the theory section, with $x:=\Delta/k_BT$:

- $k_BT=0.1\Delta \Rightarrow x=10$: $e^{-10}=4.54\times10^{-5}$, so
  $Z=1.0000454$, $P(E_0)=0.999955$, $P(E_1)=4.54\times10^{-5}$ — almost
  total freeze-out into the ground state.
- $k_BT=\Delta \Rightarrow x=1$: $e^{-1}=0.3679$, so $Z=1.3679$,
  $P(E_0)=1/1.3679=0.7311$, $P(E_1)=0.3679/1.3679=0.2689$ — a genuine
  73/27 split, not 50/50, even though the thermal energy scale now matches
  the gap exactly.
- $k_BT=10\Delta \Rightarrow x=0.1$: $e^{-0.1}=0.9048$, so $Z=1.9048$,
  $P(E_0)=1/1.9048=0.5250$, $P(E_1)=0.9048/1.9048=0.4750$ — close to, but
  not yet exactly, the $50/50$ saturation value, which Exercise 5 shows is
  approached but never reached at any finite $T$.

**2. Classical oscillator: average energy via equipartition.** Take a
Day-3 mass-spring oscillator with $m=0.02\text{ kg}$, $k_s=8\text{ N/m}$
(so $\omega_0=\sqrt{k_s/m}=20\text{ rad/s}$), held at room temperature,
$T=300\text{ K}$ (today's convention), so
$k_BT\approx4.14\times10^{-21}\text{ J}$ (from
$k_BT=1.38\times10^{-23}\times300\text{ K}$). Equipartition assigns
$\tfrac12k_BT$ to the kinetic term and $\tfrac12k_BT$ to the potential
term, for
$$\langle E_{\text{osc}}\rangle = k_BT \approx 4.14\times10^{-21}\text{ J} \approx 0.0259\text{ eV},$$
regardless of $\omega_0$ — a *much lighter or stiffer* spring at the same
temperature would give the identical answer, which is exactly the
counterintuitive content of the theorem: equipartition doesn't know or
care about $m$ or $k_s$ individually, only that there are two quadratic
terms.

**3. RMS speed of a nitrogen molecule at room temperature.** A
translational degree of freedom is quadratic in momentum
($K_x=p_x^2/2m=\tfrac12mv_x^2$), so equipartition gives
$\tfrac12m\langle v_x^2\rangle=\tfrac12k_BT$, i.e.
$\langle v_x^2\rangle=k_BT/m$, and identically for $v_y,v_z$. Summing the
three independent directions,
$$\langle v^2\rangle = \langle v_x^2\rangle+\langle v_y^2\rangle+\langle v_z^2\rangle = \frac{3k_BT}{m}, \qquad v_{\text{rms}}:=\sqrt{\langle v^2\rangle} = \sqrt{\frac{3k_BT}{m}}.$$
For N$_2$ at $T=300\text{ K}$: molar mass $M=0.0280\text{ kg/mol}$, so
$m=M/N_A=0.0280/(6.022\times10^{23})=4.65\times10^{-26}\text{ kg}$. Then
$$3k_BT = 3(1.381\times10^{-23}\text{ J/K})(300\text{ K}) = 1.243\times10^{-20}\text{ J},$$
$$v_{\text{rms}} = \sqrt{\frac{1.243\times10^{-20}}{4.65\times10^{-26}}} = \sqrt{2.67\times10^{5}} \approx 517\text{ m/s}.$$
This lands squarely in the textbook ballpark quoted for nitrogen at room
temperature (commonly cited anywhere from about $505$ to $520$ m/s,
depending on the exact $T$ and molar mass used) — a useful sanity check
that this genuinely macroscopic-sounding number (over $1000$ mph) is what
"room temperature" means at the molecular level.

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. A two-level system has gap $\Delta=0.2\text{ eV}$ at room temperature
   ($T=300\text{ K}$, today's convention, so $k_BT\approx0.0259\text{ eV}$).
   Write the Boltzmann factor and compute the ratio $P(E_1)/P(E_0)$.
2. State the equipartition theorem in one sentence, then count the number
   of quadratic degrees of freedom for a single monatomic ideal-gas atom
   (translation only — no internal structure), and give its average energy.

**Standard**

3. A three-level system has energies $E_0=0,\ E_1=\Delta,\ E_2=2\Delta$.
   At $k_BT=\Delta$, compute $Z$ and $\langle E\rangle$ (in units of
   $\Delta$).
4. A diatomic molecule (two atoms joined by a bond that can stretch) has
   three translational, two rotational, and two vibrational quadratic
   degrees of freedom. Count the total and state the equipartition
   prediction for $\langle E\rangle$. Then explain why the *measured* heat
   capacity of diatomic gases like N$_2$ near room temperature matches a
   *smaller* count than the one you just found, and flag which physics
   (not yet available to you) is responsible.

**Stretch**

5. For the two-level system, derive the closed form $\langle E\rangle(T)$
   from $Z$ and show algebraically that it saturates at $\Delta/2$ as
   $T\to\infty$. Then consider a single mode with an *unbounded* ladder of
   evenly spaced discrete levels $0,\varepsilon,2\varepsilon,3\varepsilon,
   \dots$ (Planck's actual model for one mode of light, met tomorrow) in
   place of only two levels. Explain, in one paragraph, why this discrete
   mode does *not* saturate the way the two-level system does — its
   average energy keeps climbing as $T$ increases, approaching the
   ordinary equipartition value $k_BT$ once $\varepsilon\ll k_BT$ — but
   instead **freezes out**, contributing far less than $\tfrac12k_BT$,
   whenever $\varepsilon\gg k_BT$ (exactly Worked example 1's
   $k_BT=0.1\Delta$ row, with $\varepsilon$ playing the role of $\Delta$).
   Then contrast this with a genuine classical *continuum* of levels (no
   gap at all between neighbors): explain why such a mode has nothing to
   freeze out below and so always delivers the full $k_BT$, at any $T$ —
   and why this is precisely why the classical catastrophe lives in the
   *sum over infinitely many modes*, not in any single mode's average.

## Hints

1. Write $P(E_i)\propto e^{-E_i/k_BT}$ first; the ratio of two populations
   is just the ratio of their (un-normalized) Boltzmann factors — $Z$
   cancels, so you never need to compute it for a ratio.
2. Go back to the definition of a quadratic term (kinetic energy in each
   independent direction of motion) and count how many independent
   directions a point-like atom has.
3. Compute $e^{-\Delta/k_BT}$ and $e^{-2\Delta/k_BT}$ at $k_BT=\Delta$
   first (i.e. $e^{-1}$ and $e^{-2}$), then assemble $Z$ as their sum plus
   1, and $\langle E\rangle$ as the same weights applied to $0,\Delta,2\Delta$
   and divided by $Z$.
4. Add the three counts to get the total; equipartition's prediction is
   $\tfrac12k_BT$ times that total. For the second part, recall that
   vibration is the *stiffest* of the three motions (the largest energy
   gap between its levels) and ask whether $k_BT$ at room temperature is
   actually big enough to reach that gap.
5. Write $\langle E\rangle=\Delta\,P(E_1)=\Delta\,e^{-\Delta/k_BT}/Z$ using
   the two-level $Z$ from the theory section, then simplify by dividing
   numerator and denominator by $e^{-\Delta/k_BT}$. For the discrete-ladder
   paragraph, set up the analogous sum for levels $E_n=n\varepsilon$ (a
   geometric series for $Z$), then examine the two limits
   $\varepsilon\ll k_BT$ and $\varepsilon\gg k_BT$ separately — one
   recovers the ordinary equipartition value, the other reproduces Worked
   example 1's freeze-out row.

## Solutions

**1.** $P(E_i)\propto e^{-E_i/k_BT}$, with $E_0=0,\ E_1=\Delta$. The ratio
of the (un-normalized) factors is
$$\frac{P(E_1)}{P(E_0)} = \frac{e^{-\Delta/k_BT}}{e^{-0/k_BT}} = e^{-\Delta/k_BT} = e^{-0.2/0.0259} = e^{-7.72} \approx 4.4\times10^{-4}.$$
The excited state is populated about $1$ time in every $2260$ ground-state
occupations.

**2.** Equipartition: every independent quadratic term in a classical
system's energy carries average energy $\tfrac12k_BT$. A point-like
monatomic atom has kinetic energy $K=\tfrac{p_x^2+p_y^2+p_z^2}{2m}$ — three
independent quadratic terms (one per spatial direction), and no other
quadratic terms (no internal structure to vibrate or rotate). So
$$\langle E\rangle = 3\times\tfrac12k_BT = \tfrac32k_BT.$$

**3.** At $k_BT=\Delta$: $e^{-E_0/k_BT}=e^0=1$,
$e^{-E_1/k_BT}=e^{-1}=0.36788$, $e^{-E_2/k_BT}=e^{-2}=0.13534$. So
$$Z = 1+0.36788+0.13534 = 1.50321.$$
$$\langle E\rangle = \frac{0\cdot1+\Delta\cdot0.36788+2\Delta\cdot0.13534}{1.50321} = \frac{\Delta(0.36788+0.27067)}{1.50321} = \frac{0.63855\,\Delta}{1.50321} \approx 0.425\,\Delta.$$
As a sanity check, $0.425\Delta$ sits between $E_0=0$ and $E_1=\Delta$,
below the midpoint $0.5\Delta$ — consistent with the still-substantial
ground-state population pulling the average down, only partly offset by
the smaller but nonzero $E_2$ population pulling it back up.

**4.** Total quadratic degrees of freedom: $3\ (\text{translation}) +
2\ (\text{rotation}) + 2\ (\text{vibration}) = 7$. Equipartition predicts
$\langle E\rangle=\tfrac72k_BT$, i.e. a molar heat capacity of
$C_V=\tfrac72R$. Measured heat capacities of diatomic gases like N$_2$ near
room temperature instead match $C_V\approx\tfrac52R$ — as if only the $5$
translational-plus-rotational terms were active and the $2$ vibrational
terms were simply absent from the count. This "**freeze-out**" of the
vibrational modes is exactly the low-temperature limit of the two-level
system's behavior from the theory section, applied per mode: the
vibrational energy-level spacing for a typical diatomic bond is large
compared to room-temperature $k_BT$ (a stiffer, higher-frequency motion
than rotation), so — precisely as in Worked example 1's $k_BT=0.1\Delta$
row — the vibrational mode sits almost entirely in its ground level and
contributes essentially none of its equipartition share. Classical physics
has no mechanism to produce this selective freeze-out (equipartition
predicts $\tfrac12k_BT$ per mode *regardless* of temperature or stiffness);
the missing ingredient is **quantization** of the vibrational energy
levels, which is not developed until later in this course but is flagged
here as the resolution.

**5.** From the theory section, $Z=1+e^{-\Delta/k_BT}$ and
$\langle E\rangle=\Delta\,P(E_1)=\dfrac{\Delta\,e^{-\Delta/k_BT}}{1+e^{-\Delta/k_BT}}$.
Divide numerator and denominator by $e^{-\Delta/k_BT}$:
$$\langle E\rangle = \frac{\Delta}{e^{\Delta/k_BT}+1}.$$
As $T\to\infty$, $\Delta/k_BT\to0$. Plainly: the numerator stays fixed at
$\Delta$ (it doesn't depend on $T$ at all), while in the denominator
$e^{\Delta/k_BT}\to e^0=1$, so the denominator goes to $1+1=2$. Hence
$$\langle E\rangle \to \frac{\Delta}{2},$$
the boxed saturation value — confirming, in closed form, the pattern
Worked example 1 showed numerically approaching $50/50$ occupation.

*The discrete unbounded ladder does not saturate — it freezes out
instead.* Now take a single mode with levels $E_n=n\varepsilon$,
$n=0,1,2,\dots$, without end (Planck's model for one mode of light,
tomorrow). Its partition function is a geometric series,
$Z=\sum_{n=0}^\infty e^{-n\varepsilon/k_BT}=1/(1-e^{-\varepsilon/k_BT})$,
and the same kind of sum used for $\langle E\rangle$ above (done in full
tomorrow) gives
$$\langle E\rangle = \frac{\varepsilon}{e^{\varepsilon/k_BT}-1}.$$
This ladder has no top level, so unlike the two-level system it has no
$\Delta/2$-style ceiling to level off at. Instead, two different regimes
appear depending on how $\varepsilon$ compares to $k_BT$ *at fixed
temperature*. When $\varepsilon\ll k_BT$ (the level spacing is fine
compared to the thermal scale), $e^{\varepsilon/k_BT}-1\approx
\varepsilon/k_BT$, so $\langle E\rangle\to k_BT$ — the *ordinary
equipartition value*, growing linearly with $T$ exactly as a classical
mode would, not a saturation ceiling. But when $\varepsilon\gg k_BT$ —
exactly Worked example 1's $k_BT=0.1\Delta$ row, with $\varepsilon$ playing
the role of $\Delta$ — the mode **freezes out**: $e^{\varepsilon/k_BT}$ is
enormous, so $\langle E\rangle\approx\varepsilon\,e^{-\varepsilon/k_BT}$ is
exponentially small, far below the equipartition share $\tfrac12k_BT$.

A genuine classical *continuum* (no gap at all between neighboring levels,
i.e. $\varepsilon\to0$) has nothing to freeze out below at any $T$, so it
always delivers the full $k_BT$, however cold the system is — which is
exactly why summing $k_BT$ over infinitely many continuum modes (the
equipartition-failure paragraph above) diverges, while summing the
*discrete* ladder's $\langle E\rangle$ over infinitely many modes
converges: a box supports modes of arbitrarily short wavelength, i.e.
arbitrarily large $\varepsilon$, and every one of those high-$\varepsilon$
modes is frozen out and contributes almost nothing, even though the
low-$\varepsilon$ modes still reach the full $k_BT$. Discreteness — not
any ceiling on a single mode's average — is what tames the sum; the
classical catastrophe was always a statement about the *sum over modes*,
never about any one mode failing to have a finite average.

## Connection to QM

Tomorrow's fix for blackbody radiation is nothing but today's discrete-level
average, applied to light instead of to a spin or a two-level atom. Planck's
move is to replace each mode of the electromagnetic field's classical,
unbounded continuum of possible energies with a discrete, evenly-spaced
ladder $0,\varepsilon,2\varepsilon,3\varepsilon,\dots$ and then run exactly
the partition-function machine built above — build $Z$, compute
$\langle E\rangle$ — on that ladder instead of on a two-level system. You
already have every piece of that computation; only the number of levels
per mode changes, from two to infinitely many but *discrete*. As Exercise 5
shows, a single discrete mode by itself still delivers the full classical
$k_BT$ whenever its spacing $\varepsilon$ is small compared to $k_BT$ —
discreteness alone does not shrink any one mode's average below the
classical value. What it does instead is make each mode's average depend
on $\varepsilon$: modes with $\varepsilon\gg k_BT$ freeze out and
contribute almost nothing, while modes with $\varepsilon\ll k_BT$ still
contribute the full $k_BT$. Since a box supports infinitely many modes of
ever-shorter wavelength (ever-larger $\varepsilon$), the classical
catastrophe — which lives in *summing $k_BT$ over infinitely many modes*,
exactly as the equipartition-failure paragraph above argued — is cured
because the high-$\varepsilon$ tail of that sum is exponentially
suppressed, rather than every mode contributing a flat, unshrinking
$k_BT$ regardless of temperature.

The freeze-out you diagnosed in Exercises 4 and 5 is quantization showing
up in data that predates quantum mechanics by decades: measured diatomic
heat capacities disagreeing with equipartition's $\tfrac72k_BT$ prediction
were a nineteenth-century puzzle with no classical resolution, resolved
only once vibrational (and, at low enough $T$, rotational) energy was
understood to come in discrete, unevenly-reachable steps rather than a
classical continuum — the same discreteness argument Day 13 formalizes for
light and your QM course formalizes for every bound system you'll meet.

Finally, the two-level system built today as a toy example returns, largely
unchanged, as one of the first nontrivial states in your quantum computing
course: a qubit held at temperature $T$ (rather than prepared in a pure
state) is described by exactly the $P(E_0),P(E_1)$ populations derived
above, and the $T\to\infty$ saturation point $P(E_0)=P(E_1)=\tfrac12$ is the
**maximally mixed qubit state** — the state of complete classical
uncertainty about which basis state you'd find on measurement, arrived at
here by nothing more exotic than turning up the temperature on the
simplest possible thermal system.
