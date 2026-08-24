# Day 15 — Matter Waves and the Synthesis

## Learning objectives

By the end of today you should be able to:
- State both de Broglie relations, $\lambda = h/p$ and $f = E/h$, and use them
  to compute the wavelength of any moving object, from an electron to a
  baseball.
- Describe the Davisson–Germer experiment (and electron two-slit
  interference) and explain precisely why diffraction is decisive evidence
  that matter has wave character.
- Re-derive Bohr's angular-momentum postulate $L = n\hbar$ from the
  requirement that an electron's matter wave close on itself around a
  circular orbit — turning yesterday's "mystery rule" into a consequence of
  a standing wave.
- Estimate when quantum effects matter for a given object, by comparing its
  de Broglie (or thermal de Broglie) wavelength to the relevant length scale
  of the system.
- Articulate, in your own words, the synthesis chain that closes the
  classical-breakdown phase of this course: particles are waves, confined
  waves form discrete modes, therefore confined particles have discrete
  energies.

Time budget: ~3.5 hours.

## Reference material

- Eisberg & Resnick, *Quantum Physics of Atoms, Molecules, Solids, Nuclei,
  and Particles*, the chapter on de Broglie's postulate and electron
  diffraction (covers Davisson–Germer in full historical detail, including
  the numbers used in Worked Example 3 below).
- French & Taylor, *An Introduction to Quantum Physics*, the chapter on
  matter waves and wave–particle duality (a complementary, more
  conceptually-driven treatment of the same material).
- The theory below is self-contained; the texts above are useful for a
  second explanation in different words, not required to do today's work.
- Builds directly on: day 6 (standing-wave modes on a string, $k_n =
  n\pi/L$, and the boxed sentence that boundary conditions turn a continuum
  of waves into a discrete list of modes), day 7 (wave packets), day 12
  (the thermal energy scale $k_BT$), day 13 ($E=hf$ for photons), and day 14
  (Bohr's energy levels $E_n = -13.6\,\text{eV}/n^2$, the postulate $L =
  n\hbar$ taken as given, and the photon momentum relation $p = h/\lambda$).

## Theory

### 1. de Broglie's symmetry bet

Days 13–14 forced a strange conclusion onto light: something long
understood as a wave — interference, diffraction, a continuous
electromagnetic field — also carries discrete particle attributes. A photon
of frequency $f$ carries energy $E = hf$ and momentum $p = h/\lambda$. Light,
a wave, has particle-like grains.

In 1924 Louis de Broglie asked the obvious symmetric question: if a wave
can behave like a particle, can a particle behave like a wave? He proposed
that the *same* relations, read backwards, apply to matter:
$$
\lambda = \frac{h}{p}, \qquad f = \frac{E}{h}.
$$
Nothing new is being defined here — these are the identical equations from
days 13–14, $E=hf$ and $p=h/\lambda$, just solved for $\lambda$ and asserted
to hold for *any* particle of momentum $p$ and energy $E$, electron or
baseball, not only photons. This was a bet, not a derivation: de Broglie had
no independent evidence for it in 1924. It is presented here up front
because the entire rest of today is either computing its consequences or
testing it against experiment — the theory beats below justify the bet
after the fact, the way the day actually unfolded historically.

### 2. Numbers immediately: why nobody noticed matter waves before

The reason wave behavior of matter went undetected for centuries is a
question of scale, answered by plugging real numbers into $\lambda = h/p$.

**A nonrelativistic electron accelerated through $E$ volts.** Its momentum
comes from $E = p^2/2m_e$ (nonrelativistic kinetic energy; valid here since
$E \ll m_ec^2 = 511\,\text{keV}$ for anything in this day), so $p =
\sqrt{2m_eE}$ and
$$
\lambda = \frac{h}{\sqrt{2m_eE}}.
$$
Pulling the constants $h$, $m_e$, and the eV-to-joule conversion together
into one number (worked in full in Worked Example 1) gives the convenient
form
$$
\lambda[\text{nm}] = \frac{1.226}{\sqrt{E[\text{eV}]}},
$$
valid whenever $E$ is entered in electron-volts. A $100\,\text{eV}$ electron
then has $\lambda \approx 0.123\,\text{nm}$ — comparable to the spacing
between atoms in a crystal ($\sim 0.1$–$0.3\,\text{nm}$) and to the Bohr
radius ($0.0529\,\text{nm}$, day 14). That is squarely in the range a
crystal lattice can diffract, which is exactly why Davisson–Germer (beat 3)
could see it.

**A thrown baseball.** Mass $m \approx 0.145\,\text{kg}$, speed $v \approx
40\,\text{m/s}$ (a fast pitch), so $p = mv \approx 5.8\,\text{kg·m/s}$ and
$$
\lambda = \frac{h}{p} \approx \frac{6.626\times10^{-34}}{5.8} \approx
1.1\times10^{-34}\,\text{m}.
$$
No object, no slit, no detector in the universe resolves a length that
small — it is roughly $20$ orders of magnitude below a proton's size. The
baseball's wave nature is not weak, exactly; it is *real* by the same
equation that governs the electron, but its wavelength is so absurdly far
below anything measurable that classical mechanics is, for every practical
purpose, exact. This is the general rule that will recur all day:
whether "wave behavior" is visible is entirely a question of whether
$\lambda$ is comparable to some length scale you can actually probe.

### 3. Davisson–Germer: matter waves measured

If electrons have a wavelength given by $\lambda = h/p$, then a beam of
electrons hitting a crystal — whose atoms are spaced by a fixed, known
distance, exactly like the rulings on a diffraction grating — should
produce diffraction peaks at angles fixed by that wavelength, in precise
analogy to X-ray diffraction off the same crystal.

In 1927, Clinton Davisson and Lester Germer fired a beam of $54\,\text{eV}$
electrons at a nickel crystal and measured a pronounced peak in the
scattered intensity at a specific angle. Worked Example 3 below carries out
the calculation Davisson and Germer themselves needed: take the known
nickel atomic spacing, compute the de Broglie wavelength of a $54\,\text{eV}$
electron from $\lambda = h/p$, predict the diffraction angle from the
grating condition, and compare to what was measured. The agreement (to
within experimental accuracy) is the direct experimental confirmation of de
Broglie's bet — not indirect, not statistical, but the same kind of sharp
diffraction peak X-rays produce off the same crystal, now produced by
particles with rest mass and charge.

The modern, conceptually cleaner version of the same fact is electron
two-slit interference: send electrons one at a time through a double slit,
far enough apart that at most one electron is ever in flight. Each electron
registers as a single, particle-like dot on the detector — never a smeared
wave — yet after enough electrons accumulate, the dots build up, one by
one, into the unmistakable fringe pattern of two-slit interference. Neither
"purely a particle" nor "purely a wave" describes this correctly by itself;
beat 5 below states precisely what does.

### 4. The synthesis: Bohr's postulate derived, not assumed

Day 14 handed you Bohr's rule $L = n\hbar$ as a postulate — a rule that
worked, matched hydrogen's spectrum, but came from nowhere inside the
theory. De Broglie's hypothesis derives it.

Picture the electron's matter wave wrapped around a circular orbit of
radius $r$. For the wave to be a consistent, single-valued standing wave —
not one that destructively cancels itself lap after lap — its own
circumference must contain a whole number of wavelengths:
$$
2\pi r = n\lambda, \qquad n = 1, 2, 3, \dots
$$
This is exactly day 6's boundary condition in a new setting: a wave
confined to a loop (rather than pinned between two walls) can only exist in
modes where the loop length is a whole number of wavelengths — the
circular analogue of fitting standing-wave modes into a fixed length.
Now substitute de Broglie's relation $\lambda = h/p$:
$$
2\pi r = n\frac{h}{p} \quad\Longrightarrow\quad rp = \frac{nh}{2\pi} =
n\hbar.
$$
But $rp$ is exactly the electron's orbital angular momentum $L$ for
circular motion (momentum $p$ tangent to a circle of radius $r$), so
$$
L = n\hbar.
$$
This is Bohr's postulate — the one rule in day 14 that had no justification
beyond "it fits the data" — obtained here as a direct consequence of two
things you already had: the de Broglie relation and the standing-wave
boundary condition from day 6. It is not a coincidence dressed up to look
like a derivation; it is the actual historical route by which physicists
in the 1920s came to accept that quantization was not a special rule about
atoms but a general fact about confined waves. Worked Example 2 repeats
this derivation with every step spelled out.

Pulling the thread all the way through gives the sentence this whole
course phase has been building toward:

> **The synthesis.** Particles are waves (de Broglie) → confined waves form
> discrete modes (day 6) → therefore confined particles have discrete
> energies. **Quantization is boundary conditions applied to matter
> waves.**

Every discrete energy level you have met so far — the standing-wave modes
of day 6, the hydrogen levels of day 14 — is one instance of this single
mechanism. Tomorrow's Schrödinger equation is the general machine that
carries out "boundary conditions on a matter wave" for any potential, not
just a circular orbit or a fixed string.

### 5. Wave–particle straight talk

The two-slit result in beat 3 is disorienting only if you insist on
picturing the electron as either a classical marble or a classical ripple.
It is neither, and saying so precisely removes the mystery without denying
the strangeness:

An electron is described at every instant by a single object, its
wavefunction $\psi$. The wavefunction propagates and interferes exactly
like a wave — this is why two-slit fringes appear, why Davisson–Germer
sees diffraction peaks, why the standing-wave condition in beat 4 is the
right question to ask. What the wavefunction is *not* is a literal
mechanical vibration of some medium, and it is not a description of a
particle riding along some hidden track. Its mode structure (the standing
waves of beat 4) fixes the allowed energies; the modulus of $\psi$ fixes
where the electron is likely to be *found* when a measurement is made — the
precise statement of that last fact (the Born rule) is tomorrow's job to
formalize, but the qualitative shape of it is already visible in the
two-slit experiment: interference builds up the *pattern of where dots are
likely to land*, one discrete dot — one detection event — at a time.

A localized detection event is itself already familiar from day 7: a
single sharp $k$ (a single de Broglie wavelength) describes a wave spread
over all space, not a particle found "here." Getting something localized —
an electron arriving at one point on a screen — requires superposing many
$k$'s into a wave packet, exactly as day 7 built packets by adding plane
waves. Day 7's uncertainty relation between packet width and the spread of
$k$'s in it, $\Delta x\,\Delta k \gtrsim 1$, is already the trade-off
between localization and momentum spread that this whole beat has been
describing in words; day 16 formalizes it as $\Delta x\,\Delta p \gtrsim
\hbar$.

> **Misconception:** "the electron travels along the wave," as if the wave
> were a track or a pilot signal guiding a small particle through space.
> This gets the relationship backwards. The wave is not something the
> electron rides; the wave *is* the electron's complete description. There
> is no additional, more fundamental "real position" that the wave merely
> steers — asking "which slit did the particle really go through, given
> that the wave went through both" presupposes a classical trajectory that
> the theory does not contain and that no experiment has ever found.

> **Misconception:** "wave–particle duality means the electron is sometimes
> a wave and sometimes a particle," switching identity depending on
> circumstances. It is one consistent kind of object — a quantum state —
> at all times. That object propagates the way waves propagate (hence
> interference, diffraction, the standing-wave energy quantization of beat
> 4) and is detected the way particles are detected (a single, localized,
> indivisible event at the screen). "Duality" names the fact that both a
> wave-like description and particle-like measurement outcomes belong to
> the same object, not that the object alternates between two different
> classical identities.

### 6. When is quantum relevant

Beat 2 already contains the general principle: quantum wave effects are
visible exactly when the de Broglie wavelength is comparable to (or larger
than) the relevant length scale of the problem, and invisible when
$\lambda$ is far smaller than that scale. For a single particle with a
definite momentum, "the relevant length scale" might be a slit spacing or a
crystal lattice constant, as in beat 3. For a large collection of particles
in thermal equilibrium at temperature $T$, there is no single momentum —
day 12 gave you the thermal energy scale $k_BT$ and the resulting
order-of-magnitude thermal momentum $p \sim \sqrt{mk_BT}$. Substituting
that scaling into $\lambda = h/p$ motivates a wavelength associated with an
entire thermal population, the **thermal de Broglie wavelength**:
$$
\lambda_{th} = \frac{h}{\sqrt{2\pi m k_BT}}.
$$
The scaling $\lambda_{th} \propto 1/\sqrt{mk_BT}$ is exactly what
$p\sim\sqrt{mk_BT}$ predicts; the precise numerical prefactor $2\pi$ inside
the square root comes from a proper statistical-mechanics average over the
thermal momentum distribution (quoted here rather than re-derived, since
that derivation needs machinery beyond day 12) and does not change the
order-of-magnitude conclusions below.

Comparing $\lambda_{th}$ to the typical spacing between particles gives a
sharp criterion: if $\lambda_{th}$ is much *smaller* than the interparticle
spacing, the particles behave classically (their wave packets don't
overlap); if $\lambda_{th}$ is comparable to or *larger* than the spacing,
the particles' wave natures overlap and quantum statistics (which this
course has not yet covered) becomes unavoidable.

Evaluating $\lambda_{th}$ at room temperature ($T=300\,\text{K}$, so $k_BT
\approx 4.14\times10^{-21}\,\text{J}$) for two cases makes the criterion
concrete. For an electron ($m_e = 9.109\times10^{-31}\,\text{kg}$):
$$
\lambda_{th} = \frac{h}{\sqrt{2\pi m_ek_BT}} =
\frac{6.626\times10^{-34}}{\sqrt{2\pi(9.109\times10^{-31})
(4.14\times10^{-21})}} \approx 4.3\,\text{nm}.
$$
This is more than an order of magnitude *larger* than the $\sim0.2$–$0.3\,
\text{nm}$ spacing between atoms in a metal, which is exactly why the
conduction electrons in a metal cannot be treated as a classical gas even
at room temperature — their wave packets overlap, and a proper description
needs quantum statistics. For a helium-4 atom ($m_{\text{He}} =
6.646\times10^{-27}\,\text{kg}$, about $7300$ times heavier than the
electron):
$$
\lambda_{th} = \frac{6.626\times10^{-34}}{\sqrt{2\pi(6.646\times10^{-27})
(4.14\times10^{-21})}} \approx 0.05\,\text{nm} = 0.5\,\text{Å}.
$$
That is comparable to an atom's own size, but far smaller than the several
nanometers of typical spacing between atoms in helium gas at room
temperature and pressure — so room-temperature helium gas behaves
classically, and it takes cooling all the way down to a few kelvin (where
$\lambda_{th}$ grows large enough to rival the interparticle spacing) before
helium's wave nature forces itself on the system as superfluidity.

## Worked examples

**1. de Broglie wavelength of a $100\,\text{eV}$ electron, and of a thrown
baseball, computed explicitly.**

*Electron.* Nonrelativistic kinetic energy gives $p = \sqrt{2m_eE}$. With
$E = 100\,\text{eV} = 100\times1.602\times10^{-19}\,\text{J} =
1.602\times10^{-17}\,\text{J}$ and $m_e = 9.109\times10^{-31}\,\text{kg}$:
$$
p = \sqrt{2(9.109\times10^{-31})(1.602\times10^{-17})} =
\sqrt{2.919\times10^{-47}} = 5.402\times10^{-24}\,\text{kg·m/s}.
$$
$$
\lambda = \frac{h}{p} = \frac{6.626\times10^{-34}}{5.402\times10^{-24}} =
1.227\times10^{-10}\,\text{m} = 0.123\,\text{nm}.
$$
The same calculation, done symbolically with $E$ left in eV, produces the
reusable constant quoted in Theory beat 2: writing $E$ in joules as
$E[\text{eV}]\times1.602\times10^{-19}$,
$$
\lambda = \frac{h}{\sqrt{2m_e\cdot E[\text{eV}]\cdot1.602\times10^{-19}}}
= \frac{h}{\sqrt{2m_e\cdot1.602\times10^{-19}}}\cdot
\frac{1}{\sqrt{E[\text{eV}]}},
$$
and evaluating the constant factor,
$$
\frac{h}{\sqrt{2m_e\cdot1.602\times10^{-19}}} =
\frac{6.626\times10^{-34}}{\sqrt{2.919\times10^{-49}}} =
\frac{6.626\times10^{-34}}{5.402\times10^{-25}} = 1.226\times10^{-9}\,
\text{m} = 1.226\,\text{nm},
$$
gives exactly $\lambda[\text{nm}] = 1.226/\sqrt{E[\text{eV}]}$ — checked
against the direct calculation above: $1.226/\sqrt{100} = 0.1226\,
\text{nm}$, matching. This constant is reused in Exercise 1 and Worked
Example 3 below.

*Baseball.* $m = 0.145\,\text{kg}$, $v = 40\,\text{m/s}$, so $p = mv =
5.8\,\text{kg·m/s}$ and
$$
\lambda = \frac{6.626\times10^{-34}}{5.8} = 1.14\times10^{-34}\,\text{m}.
$$
The electron's wavelength is atomic-scale and directly measurable by
crystal diffraction; the baseball's is about $24$ orders of magnitude
smaller ($1.14\times10^{-34}\,\text{m}$ versus $1.23\times10^{-10}\,
\text{m}$) and utterly unmeasurable — the entire content of "classical
objects don't show wave behavior" is contained in this one comparison.

**2. Bohr's postulate $L = n\hbar$ derived in full from a standing matter
wave, closed book.**

*Setup.* An electron of momentum $p$ moves on a circular orbit of radius
$r$. Treat its matter wave as a standing wave wrapped around the
circumference, the circular analogue of day 6's string modes.

*Step 1 — boundary condition.* For the wave to be single-valued as it
wraps around (no discontinuity where the loop closes on itself, exactly the
requirement that made day 6's string modes discrete), the circumference
must be a whole number of wavelengths:
$$
2\pi r = n\lambda, \qquad n = 1, 2, 3, \dots
$$

*Step 2 — insert the de Broglie relation.* $\lambda = h/p$, so
$$
2\pi r = n\frac{h}{p}.
$$

*Step 3 — solve for $rp$.*
$$
rp = \frac{nh}{2\pi} = n\hbar,
$$
using $\hbar \equiv h/2\pi$.

*Step 4 — identify $rp$ as angular momentum.* For circular motion, the
momentum $p$ is tangent to the circle, perpendicular to the radius $r$, so
the orbital angular momentum has magnitude exactly $L = rp$. Substituting:
$$
L = n\hbar.
$$
This is precisely Bohr's postulate from day 14, now obtained from the
standing-wave condition plus $\lambda=h/p$ — no independent assumption
about angular momentum was needed.

**3. Davisson–Germer: predicting the diffraction angle for $54\,\text{eV}$
electrons off nickel.**

*Predicted wavelength.* Using the constant from Worked Example 1 with $E =
54\,\text{eV}$:
$$
\lambda = \frac{1.226\,\text{nm}}{\sqrt{54}} = \frac{1.226}{7.348} =
0.167\,\text{nm}.
$$

*Diffraction condition.* Nickel's regularly spaced surface atoms act as a
diffraction grating with spacing $d = 0.215\,\text{nm}$ (the historical
value for the nickel crystal used). This is day 6's path-difference
interference condition in a new setting: two adjacent rows of surface
atoms, spaced by $d$, each scatter the incoming wave, and the two scattered
waves travel an extra path difference of $d\sin\phi$ before recombining.
Exactly as in day 6, constructive interference — a diffraction peak —
requires that path difference to be a whole number of wavelengths,
$d\sin\phi = n\lambda$; taking the first order ($n=1$) gives the grating
condition $\lambda = d\sin\phi$, where $\phi$ is the angle between the
incident and scattered beams, so
$$
\sin\phi = \frac{\lambda}{d} = \frac{0.167}{0.215} = 0.777
\quad\Longrightarrow\quad \phi = \arcsin(0.777) \approx 51^\circ.
$$

*Comparison to experiment.* Davisson and Germer measured a sharp intensity
peak at $\phi \approx 50^\circ$. The $1^\circ$ difference between the
predicted $51^\circ$ and the measured $50^\circ$ is well within the
precision of the historical apparatus and the simplified single-layer
grating model used here (the real crystal has additional structure that
produces small corrections). The predicted and measured angles agreeing
this closely, using a wavelength computed from $\lambda=h/p$ with no free
parameters, is exactly why this experiment settled the matter: it is a
quantitative, falsifiable prediction that came true.

## Exercises

Attempt every problem closed-book before checking the Hints, and only then
the Solutions.

**Retrieval**

1. State both de Broglie relations. Then compute the de Broglie wavelength
   of an electron accelerated through $1000\,\text{V}$ (a "$1\,\text{keV}$
   electron").
2. Closed book: reproduce the full standing-wave derivation of $L=n\hbar$
   from Worked Example 2 (boundary condition, de Broglie relation,
   identification of $rp$ as angular momentum).

**Standard**

3. Neutron diffraction is used to probe crystal structures with $\lambda
   \approx 0.1\,\text{nm}$. What kinetic energy (in eV) must a neutron have
   for $\lambda = 0.1\,\text{nm}$? Compare this energy to $k_BT$ at room
   temperature ($T \approx 300\,\text{K}$, day 12) and comment on the term
   "thermal neutrons."
4. Electron microscopes achieve far finer resolution than optical
   microscopes built with comparable lens geometry ("the same optics").
   Using the fact that diffraction-limited resolution scales with the
   wavelength used, explain quantitatively why electrons beat visible light
   at this — compute a representative electron wavelength (pick any
   accelerating voltage in the range used by real instruments, e.g.
   $10$–$100\,\text{kV}$) and compare it to visible light's $\sim
   500\,\text{nm}$.

**Stretch**

5. A particle of mass $m$ is confined to a one-dimensional box of length
   $L$ (here $L$ denotes the box length, not angular momentum — a different
   use of the same letter from beat 4's Bohr derivation). Using pure
   standing-wave reasoning alone (no Schrödinger equation, which you meet
   tomorrow): argue that the allowed wavelengths are $\lambda_n = 2L/n$ for
   $n=1,2,3,\dots$, convert to momentum via de Broglie, and derive the
   allowed energies $E_n = n^2h^2/(8mL^2)$. This is deliberately the
   headline result of tomorrow's Schrödinger-equation treatment of the same
   box, obtained here a full day early using only 1924-era tools (standing
   waves plus $\lambda=h/p$) — tomorrow reproduces these exact numbers by an
   entirely different route.

## Hints

1. Write down $\lambda=h/p$, $f=E/h$ first; then get momentum from $E =
   p^2/2m_e$ for the $1\,\text{keV}$ electron, exactly as in Worked Example
   1's electron case, and reuse the $1.226\,\text{nm}/\sqrt{E[\text{eV}]}$
   shortcut if you want a check.
2. Start from "the wave must be single-valued going once around the
   loop" and work forward through the three substitutions of Worked
   Example 2 without looking at it.
3. Get momentum from $\lambda=h/p$ first, then convert momentum to kinetic
   energy via $E=p^2/2m_n$ with the neutron mass; compute $k_BT$ from day
   12's constant and compare orders of magnitude, not exact values.
4. Use the same $1.226\,\text{nm}/\sqrt{V[\text{eV}]}$ relation (with $V$ in
   volts numerically equal to the electron's kinetic energy in eV) for a
   voltage of your choosing, then take the ratio of that wavelength to
   visible light's.
5. Fit standing waves into a box exactly like day 6's string with both
   ends fixed: work out how many half-wavelengths span the box for mode
   $n$, solve for $\lambda_n$, then chain $\lambda_n\to p_n\to E_n$ using
   the same two relations used everywhere else today.

## Solutions

**1.** De Broglie's relations: $\lambda = h/p$ and $f=E/h$. For a $1000\,
\text{eV}$ electron, using the constant from Worked Example 1:
$$
\lambda = \frac{1.226\,\text{nm}}{\sqrt{1000}} = \frac{1.226}{31.62} =
0.0388\,\text{nm} = 38.8\,\text{pm}.
$$
(Direct check: $p=\sqrt{2m_eE}=\sqrt{2(9.109\times10^{-31})
(1.602\times10^{-16})} = 1.708\times10^{-23}\,\text{kg·m/s}$, and
$\lambda = h/p = 6.626\times10^{-34}/1.708\times10^{-23} = 3.88\times
10^{-11}\,\text{m}$ — matches.)

**2.** Boundary condition for a wave wrapped around a loop of radius $r$
to be single-valued: $2\pi r = n\lambda$, $n=1,2,3,\dots$. Substitute de
Broglie's $\lambda = h/p$: $2\pi r = nh/p$, so $rp = nh/2\pi = n\hbar$.
For circular motion, $p$ is tangent to the orbit and perpendicular to $r$,
so $rp$ is exactly the orbital angular momentum $L$. Hence $L=n\hbar$ —
Bohr's postulate, obtained from a standing-wave condition plus de Broglie's
relation, with no separate assumption about angular momentum quantization.

**3.** From $\lambda=h/p$: $p = h/\lambda = 6.626\times10^{-34}/
1\times10^{-10} = 6.626\times10^{-24}\,\text{kg·m/s}$. Kinetic energy with
the neutron mass $m_n = 1.675\times10^{-27}\,\text{kg}$:
$$
E = \frac{p^2}{2m_n} = \frac{(6.626\times10^{-24})^2}
{2(1.675\times10^{-27})} = \frac{4.390\times10^{-47}}{3.35\times10^{-27}}
= 1.310\times10^{-20}\,\text{J} = 0.0818\,\text{eV}.
$$
Room-temperature thermal energy: $k_BT = (8.617\times10^{-5}\,\text{eV/K})
(300\,\text{K}) \approx 0.0259\,\text{eV}$. The neutron energy needed for
atomic-scale diffraction, $0.082\,\text{eV}$, is within about a factor of
$3$ of $k_BT$ at room temperature — the same order of magnitude, not a
coincidence dressed up: neutrons thermalized in a room-temperature
moderator naturally have a spread of energies straddling this range, which
is exactly why they are called "thermal neutrons" and exactly why they are
useful for crystallography — their thermal equilibrium energy happens to
correspond to a de Broglie wavelength matching interatomic spacing.

**4.** Diffraction-limited resolution scales with the wavelength used, so
the ratio of resolutions between two instruments with comparable lens
geometry ("the same optics") equals the ratio of wavelengths. Take a
representative electron microscope voltage, $V=60{,}000\,\text{eV}$
(nonrelativistic estimate is slightly off at this energy, but adequate for
an order-of-magnitude comparison):
$$
\lambda_e = \frac{1.226\,\text{nm}}{\sqrt{60000}} = \frac{1.226}{244.9}
\approx 5.0\times10^{-3}\,\text{nm} = 5.0\,\text{pm}.
$$
Visible light: $\lambda_{\text{light}} \approx 500\,\text{nm}$. The ratio
is
$$
\frac{\lambda_{\text{light}}}{\lambda_e} = \frac{500}{0.005} =
100{,}000,
$$
so an electron microscope operating at this voltage has, in principle, a
diffraction-limited resolution roughly five orders of magnitude finer than
a comparable optical instrument — this is the quantitative reason electron
microscopes resolve individual atomic planes while optical microscopes
cannot resolve anything smaller than roughly half a wavelength of visible
light ($\sim 200$–$300\,\text{nm}$).

**5.** A particle confined between two walls at $x=0$ and $x=L$ (here $L$
is the box length, not angular momentum) supports standing waves that must
vanish at both walls, exactly as in day 6's fixed-fixed string. The mode
with $n$ antinodes fits $n$ half-wavelengths between the walls:
$$
L = n\frac{\lambda_n}{2} \quad\Longrightarrow\quad \lambda_n =
\frac{2L}{n}, \qquad n=1,2,3,\dots
$$
De Broglie's relation converts this to momentum:
$$
p_n = \frac{h}{\lambda_n} = \frac{h}{2L/n} = \frac{nh}{2L}.
$$
Nonrelativistic kinetic energy then gives the allowed energies:
$$
E_n = \frac{p_n^2}{2m} = \frac{1}{2m}\left(\frac{nh}{2L}\right)^2 =
\frac{n^2h^2}{8mL^2}.
$$
This is exactly the energy spectrum tomorrow's Schrödinger equation
produces for a particle in a box, obtained here from standing-wave
reasoning and $\lambda=h/p$ alone — a genuine 1924-era derivation of what
looks, at first glance, like a distinctly 1926-era result.

## Connection to QM

Today closes the classical-breakdown phase of this course by handing you,
in explicit and derived form, every ingredient the quantum-computing-style
formalism starts from: physical states are described by waves (de
Broglie), observable quantities like energy come from the mode structure of
those waves under confinement (day 6's boundary conditions, reapplied here
to a circular orbit and to a box), and quantization itself — the single
strangest fact from days 6 through 14 — is now understood as nothing more
exotic than a wave fitting into a finite region. The wavefunction language
introduced informally in beat 5 (a single object, not "sometimes-wave,
sometimes-particle") is the direct ancestor of the state vectors used
throughout the rest of a quantum-mechanics course.

What is still missing is the *general* machine: a rule that takes any
potential — not just a circular orbit or a box with infinitely hard walls —
and produces its allowed standing waves and energies automatically.
Tomorrow's Schrödinger equation is exactly that machine, and its first
worked case reproduces, by a completely different mathematical route, the
same $E_n = n^2h^2/8mL^2$ you derived by hand in Exercise 5 today — the
cleanest possible demonstration that today's synthesis was not a loose
analogy but the literal content of quantum mechanics, stated a day ahead of
the formalism that makes it general.
