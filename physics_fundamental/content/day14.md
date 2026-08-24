# Day 14 — Atoms, Spectra, and Atom–Light Interaction

## Learning objectives

By the end of today you should be able to:
- Explain, using the fact that accelerating charges radiate (day 8) and a
  quoted classical collapse-time estimate, why a classical "planetary"
  atom cannot be stable — and state Bohr's postulates as the fix.
- Derive the Bohr radius $r_n$ and energy levels $E_n = -13.6\,\text{eV}/n^2$
  from $L=n\hbar$ plus Newton's second law, and use them to compute
  spectral-line wavelengths (e.g. Balmer $\alpha$).
- Define the two-level atom and its three atom–light processes
  (absorption, spontaneous emission, stimulated emission), and derive
  Einstein's relations $B_{12}=B_{21}$ and $A_{21}/B_{21}=8\pi h f^3/c^3$
  from detailed balance, Boltzmann populations, and Planck's law.
- Explain, directly from the rate equations, why a two-level system cannot
  sustain a population inversion, and how a three- or four-level laser
  and its cavity get around this.
- State the meaning of $E=mc^2$, derive photon momentum $p=h/\lambda$ from
  the massless-particle limit, and use the (stated) Compton formula to
  compute a wavelength shift and an electron recoil energy.

Time budget: ~3.5 hours.

## Reference material

- Eisberg & Resnick, *Quantum Physics of Atoms, Molecules, Solids, Nuclei,
  and Particles*, the chapters on the Bohr atom, atomic spectra, the
  Einstein $A$/$B$ coefficients, and Compton scattering — the natural home
  for essentially all of today's derivations.
- Demtröder, *Laser Spectroscopy*, Vol. 1, or M. Fox, *Quantum Optics: An
  Introduction*, the introductory chapter on population inversion and
  laser gain, for a fuller treatment of the laser page below.
- This file is self-contained; the texts above are useful for a second
  explanation in different words, not required to do today's work.
- Builds on day 4 (angular momentum quantization, reduced mass), day 8
  (electromagnetic fields carry energy), day 12 (Boltzmann populations
  $N_2/N_1=e^{-\Delta/k_BT}$, $k_BT\approx1/40\,\text{eV}$ at room
  temperature), and day 13 ($E=hf$, Planck's spectral energy density).

Notation note: $L$ denotes **angular momentum** today, not the Lagrangian
of days 9–11 — those days are behind us, and no collision is intended.
Frequency is $f$ throughout, matching day 13's Planck-law convention.

## Theory

### 1. Rutherford's atom and its classical death sentence

Rutherford's scattering experiments (a small, dense, positive nucleus with
electrons orbiting at a distance) fix the *picture* of the atom, but
classical electromagnetism immediately kills it. Day 8 established that
oscillating and accelerating charges radiate electromagnetic energy — that
is how antennas work, and it is a direct consequence of Maxwell's
equations, not a special atomic phenomenon. An electron in a circular
orbit is constantly accelerating (centripetally, toward the nucleus), so
classically it must continuously radiate energy, exactly like a
decelerating charge in an antenna. As it radiates, it loses orbital
energy, so its orbit must shrink; as the orbit shrinks, the acceleration
increases, so the radiation rate increases, so the orbit shrinks faster
still — a runaway collapse. Plugging the classical Larmor radiated-power
formula into this feedback loop for a hydrogen atom gives a quoted
estimate: the electron would spiral into the nucleus in about
$10^{-11}\,\text{s}$.

Atoms do not do this. A hydrogen atom sitting on a shelf is stable for as
long as you care to wait, and it emits light only in discrete bursts, not
continuously. Classical mechanics plus classical electromagnetism predicts
that atoms cannot exist. They do. Something in the classical picture is
simply wrong at atomic scales — the first clue that a new set of rules is
needed.

### 2. Spectral lines: the second scandal

The second piece of evidence classical physics could not explain: heated
gases don't emit a smooth continuous spectrum (which is what an
accelerating-and-collapsing classical electron would produce, a rainbow
smear as it spirals through every radius). They emit *discrete* lines —
sharp, individual wavelengths, different for every element, forming an
atomic fingerprint. Balmer, working purely empirically on the visible
lines of hydrogen in 1885, found they fit a strikingly simple numerical
pattern:
$$\frac{1}{\lambda} = R\left(\frac{1}{4} - \frac{1}{n^2}\right), \qquad
n = 3, 4, 5, \ldots,$$
with $R\approx 1.097\times10^{7}\,\text{m}^{-1}$ (the Rydberg constant)
fit to the data. This is numerology — a pattern with no mechanism behind
it, discovered thirty years before anyone could explain why an atom would
prefer this specific family of wavelengths over any other. A formula that
fits perfectly and explains nothing is a scandal begging for a theory.

### 3. Bohr's model: postulates and the derivation of $r_n$ and $E_n$

In 1913, Bohr proposed a patch — not a derivation from first principles,
but an honest, inspired guess with three postulates:

1. The electron moves in a circular orbit around the nucleus, held there
   by the Coulomb attraction, and — aside from postulate 3 — obeys
   ordinary Newtonian mechanics.
2. Only orbits with quantized angular momentum are allowed:
   $$L = n\hbar, \qquad n = 1, 2, 3, \ldots$$
3. The electron radiates *only* when it jumps between allowed orbits, and
   the emitted or absorbed photon carries away exactly the energy
   difference: $hf = E_i - E_f$. While sitting in an allowed orbit, it
   does *not* radiate, in flat contradiction to postulate 1's classical
   mechanics and to day 8's electromagnetism.

Postulate 3 is a deliberate, glaring inconsistency — an orbiting charge
that classically must radiate, declared by fiat not to. Bohr's model is
scaffolding, not a consistent theory; its virtue is that scaffolding built
this way produces numbers that match experiment exactly.

**Deriving $r_n$.** Newton's second law provides the centripetal force via
Coulomb attraction ($k_e \equiv 1/4\pi\epsilon_0$, charge $e$, electron
mass $m_e$, nucleus taken fixed and infinitely heavy for now):
$$\frac{k_e e^2}{r^2} = \frac{m_e v^2}{r} \quad\Longrightarrow\quad
m_e v^2 r = k_e e^2. \tag{i}$$
Postulate 2 gives $L = m_e v r = n\hbar$, so $v = n\hbar/(m_e r)$.
Substituting into (i):
$$m_e\left(\frac{n\hbar}{m_e r}\right)^2 r = k_e e^2
\quad\Longrightarrow\quad \frac{n^2\hbar^2}{m_e r} = k_e e^2
\quad\Longrightarrow\quad r_n = \frac{n^2\hbar^2}{m_e k_e e^2}.$$
Define the **Bohr radius** $a_0 \equiv \hbar^2/(m_e k_e e^2)$, so
$r_n = n^2 a_0$. Numerically $a_0 = 5.29\times10^{-11}\,\text{m}$ — the
first appearance of the correct atomic size scale from a first-principles
(if patched) calculation.

**Deriving $E_n$.** Total energy is kinetic plus Coulomb potential energy:
$$E = \tfrac{1}{2}m_ev^2 - \frac{k_ee^2}{r}.$$
From (i), $m_ev^2 = k_ee^2/r$, so the kinetic term is
$\tfrac{1}{2}k_ee^2/r$, giving
$$E = \frac{1}{2}\frac{k_ee^2}{r} - \frac{k_ee^2}{r} =
-\frac{1}{2}\frac{k_ee^2}{r}.$$
Substituting $r_n = n^2a_0$ and simplifying (using
$k_ee^2 = \hbar^2/(m_ea_0)$ from the definition of $a_0$):
$$E_n = -\frac{1}{2}\frac{k_ee^2}{n^2a_0} =
-\frac{m_ek_e^2e^4}{2\hbar^2}\cdot\frac{1}{n^2}.$$
Plugging in the constants gives the famous result
$$\boxed{E_n = -\frac{13.6\,\text{eV}}{n^2}}, \qquad n=1,2,3,\ldots$$
(worked numerically for $n=1$ in Worked Example 1 below). The negative
sign means bound states: energy must be supplied to remove the electron
to $r\to\infty$ ($E_\infty = 0$).

**Recovering Balmer.** Postulate 3 says an emitted photon carries
$hf = E_{n_i}-E_{n_f}$ for a downward jump $n_i>n_f$. Using
$f = c/\lambda$:
$$\frac{1}{\lambda} = \frac{E_{n_i}-E_{n_f}}{hc} =
\frac{13.6\,\text{eV}}{hc}\left(\frac{1}{n_f^2}-\frac{1}{n_i^2}\right).$$
The prefactor $13.6\,\text{eV}/hc$ evaluates to exactly Balmer's empirical
$R\approx1.097\times10^7\,\text{m}^{-1}$, and setting $n_f=2$ reproduces
Balmer's formula from Section 2 term for term. Thirty years of numerology
falls out of three postulates.

**Reduced mass, one sentence.** The nucleus isn't truly infinite; day 4's
stretch exercise defined the reduced mass $\mu = m_1m_2/(m_1+m_2)$ for two
orbiting bodies, and replacing $m_e$ with the electron–proton reduced mass
$\mu\approx0.9995\,m_e$ throughout the derivation above refines every
$E_n$ by about $0.05\%$ — the correction that distinguishes hydrogen's
spectrum from deuterium's.

> **Misconception:** electrons orbit the nucleus like planets orbit the
> sun. Bohr's circular orbits are scaffolding that reproduces the right
> numbers, not a picture of what an electron actually does. Tomorrow
> (day 15) replaces "orbit" with *stationary state* — a standing wave
> pattern with no trajectory at all, no defined position or orbital
> radius at any instant, only a probability distribution. The orbit
> picture is a ladder you're about to kick away.

### 4. Why Bohr is wrong — but useful

Score the model honestly. It gets the *energies* right, but only for
hydrogen (one electron, one proton) — it fails for helium and beyond,
where electron–electron repulsion has no place in the derivation above.
It gets the *size scale* right: $a_0\approx0.5\,\text{Å}$ is genuinely the
size of an atom. It gets the *picture* wrong: there are no orbits, and
(as true quantum mechanics later shows) the ground state doesn't even
have $L=\hbar$ as postulate 2 demanded — it has $L=0$. What survives, and
is Bohr's real and permanent legacy, is the *structural* idea: atoms have
discrete **stationary states** with definite energies, and light is
emitted or absorbed only in **quantum jumps** between them, each jump
producing or consuming one photon of energy $E=hf$. That structural
skeleton — states, jumps, $E=hf$ — is exactly what day 15's correct
quantum treatment keeps, while replacing "orbit" with "wavefunction."

### 5. The two-level atom: absorption, spontaneous and stimulated emission

For everything that follows, replace the full atom with the simplest
possible caricature: a **two-level atom**, with just two energy levels
$E_1<E_2$, gap $\Delta = E_2-E_1 = hf$ for some transition frequency $f$.
This abstraction throws away every detail of the real atom except the one
transition you care about — and it is the model your course will use
constantly, from laser physics to the two-level systems that later become
physical qubits.

Three things can happen when this atom sits in a field of light at
frequency $f$ (spectral energy density $u(f)$, day 13):

- **Absorption.** An atom in level 1 absorbs a photon and jumps to level
  2. The rate (per atom in level 1) is proportional to how much light is
  present: rate $= B_{12}\,u(f)$.
- **Spontaneous emission.** An atom in level 2 decays to level 1 on its
  own, emitting a photon in a random direction with random phase, with a
  rate that does *not* depend on the ambient field at all: rate $=
  A_{21}$.
- **Stimulated emission.** An atom in level 2, in the presence of the
  field, is induced to decay early, emitting a photon that is an exact
  **copy** of the field that triggered it: same frequency, same
  direction, same phase. Rate $= B_{21}\,u(f)$.

$B_{12}$, $A_{21}$, and $B_{21}$ are the **Einstein coefficients** —
fixed properties of the atomic transition, independent of temperature or
field strength. The next section shows they are not three independent
numbers; thermodynamic consistency locks two relations between them.

> **Misconception:** stimulated emission is some exotic, specialized
> process. It is exactly backwards: stimulated emission is the *majority*
> process running inside every laser pointer, laser diode, and fiber
> amplifier on Earth — it is the workhorse. Spontaneous emission is the
> genuinely strange one: an atom in an empty, dark box, with no field
> present to trigger anything, decays anyway. The honest resolution (as
> your course will show) is that the box is never really empty — the
> quantum vacuum has fluctuations, and spontaneous emission is stimulated
> emission by the vacuum field. "Nothing is there" turns out to be doing
> the triggering.

### 6. Einstein's equilibrium argument: deriving $B_{12}=B_{21}$ and $A_{21}/B_{21}$

Put a large collection of two-level atoms — populations $N_1$ in level 1,
$N_2$ in level 2 — inside a cavity in thermal equilibrium at temperature
$T$, bathed in the cavity's own blackbody radiation field, spectral
energy density $u(f)$. Two independent facts about this equilibrium:

**Fact 1 — detailed balance.** In steady state, the rate of atoms leaving
level 1 (absorption) must equal the rate of atoms arriving into level 1
(both emission processes), or the populations would drift:
$$N_1 B_{12}\,u(f) = N_2 A_{21} + N_2 B_{21}\,u(f). \tag{ii}$$

**Fact 2 — Boltzmann populations (day 12).** Thermal equilibrium fixes the
population ratio directly from the energy gap:
$$\frac{N_2}{N_1} = e^{-\Delta/k_BT} = e^{-hf/k_BT}.$$

Solve (ii) for $u(f)$. Divide through by $N_1$ and let
$x\equiv N_2/N_1 = e^{-hf/k_BT}$:
$$B_{12}\,u = x\left(A_{21}+B_{21}\,u\right)
\quad\Longrightarrow\quad u\left(B_{12}-xB_{21}\right) = xA_{21}
\quad\Longrightarrow\quad
u(f) = \frac{A_{21}}{B_{12}/x - B_{21}} =
\frac{A_{21}}{B_{12}\,e^{hf/k_BT} - B_{21}}. \tag{iii}$$

Now demand this be physically sane in the **high-temperature limit**. As
$T\to\infty$, the cavity field must become arbitrarily intense
($u(f)\to\infty$ at any fixed $f$ — a well-established feature of thermal
radiation, and the same physics behind the Rayleigh–Jeans divergence day
13 discussed). In (iii), $u(f)\to\infty$ requires the denominator
$\to0$. But as $T\to\infty$, $e^{hf/k_BT}\to1$, so the denominator
$\to B_{12}-B_{21}$. For this to vanish at every frequency, we need
$$\boxed{B_{12} = B_{21}}.$$
Absorption and stimulated emission are governed by the *same*
coefficient — call it $B$. This alone is a nontrivial, testable
consequence of nothing but detailed balance plus Boltzmann statistics.

With $B_{12}=B_{21}\equiv B$, (iii) simplifies to
$$u(f) = \frac{A_{21}}{B\left(e^{hf/k_BT}-1\right)}.$$
Now match this to Planck's law itself (day 13 derived the cavity's actual
spectral energy density, driven by counting electromagnetic modes and
weighting each by its thermal photon occupancy):
$$u(f) = \frac{8\pi h f^3}{c^3}\cdot\frac{1}{e^{hf/k_BT}-1}.$$
The $1/(e^{hf/k_BT}-1)$ factor is identical in both expressions — it must
be, since both describe the same physical field — so the *prefactors*
must match too:
$$\boxed{\frac{A_{21}}{B_{21}} = \frac{8\pi h f^3}{c^3}}.$$

**The moral, stated plainly.** Nothing above assumed spontaneous emission
existed as a distinct mechanism — $A_{21}$ was carried along as an
unknown symbol. But if $A_{21}$ were zero, (iii) would give $u(f)=0$ for
every temperature, which is false: hot cavities glow. Thermodynamic
consistency — Boltzmann statistics plus detailed balance plus the
already-known Planck spectrum — *forces* $A_{21}>0$ to exist. Spontaneous
emission isn't an extra assumption bolted onto the two-level atom; it is
mathematically required for the model to be consistent with the thermal
equilibrium that day 12 and day 13 already established. This is Einstein's
1917 argument, and it predicted stimulated emission's practical
consequence (optical gain, hence lasers) decades before anyone built one.

### 7. The laser in one page

**Why two levels can't lase.** Optical amplification means: more photons
come out than went in, i.e. the *net* stimulated emission rate exceeds
the absorption rate, $N_2Bu > N_1Bu$. Since $B_{12}=B_{21}=B$ (Section 6),
this condition is simply $N_2>N_1$ — a **population inversion**. But
Boltzmann's law (day 12) gives $N_2/N_1=e^{-hf/k_BT}<1$ for $E_2>E_1$ at
*any* positive temperature — level 2 is always less populated than level
1 in thermal equilibrium, full stop. No amount of heating a two-level
system produces inversion; heating only pushes the ratio toward $1$, never
past it. (The rate-equation version of this argument, for a two-level
system driven by an external pump rather than just heated, is worked out
completely in Worked Example 3's companion, Exercise 5.)

**Three or four levels get around it.** Add a third level, $E_3>E_2$,
reached by fast optical or electrical pumping, that decays *quickly and
non-radiatively* down to level 2 (the "lasing" upper level), while level 1
(the lasing lower level) is comparatively empty because the pump never
puts atoms there directly and level 1 drains away quickly too (four-level
scheme) or is simply the ground state depleted by the pump (three-level
scheme). Population piles up in level 2 relative to level 1 without ever
requiring $N_2$ to exceed a *thermal* population of some other pair of
levels — the inversion is engineered between 2 and 1, using level 3 as a
one-way door that side-steps the two-level Boltzmann trap entirely.

**The cavity as mode selector.** An optical cavity — two mirrors facing
each other — supports only a discrete set of resonant standing-wave
modes, exactly day 6's standing-wave boundary-condition story applied to
light instead of a string. Only photons matching a cavity resonance
survive many round trips instead of leaking out; every other frequency
and direction is discarded. This is what turns a general glow of
amplified spontaneous emission into one sharply defined frequency and
direction.

**Stimulated emission as the source of coherence.** Recall Section 5's
copy property: every stimulated photon shares the exact frequency,
direction, and phase of the photon that triggered it. Inside a cavity
selecting one mode, a single spontaneously-emitted seed photon triggers a
stimulated copy, which triggers another copy of *itself*, cascading into
an avalanche of identical photons — same frequency, direction, and phase
throughout. That shared phase across an enormous number of photons is
literally what "coherent light" means; it is the direct, mechanical
consequence of the copying property, not a separate assumption.

### 8. Relativity teaser (labeled): $E=mc^2$, photon momentum, Compton scattering

*This section previews results the course develops properly; it motivates
and states, rather than derives from scratch.*

**$E=mc^2$.** Mass is a form of stored energy: a particle at rest still
carries energy $E_0=mc^2$, exactly as real as kinetic energy. Day 10's
relativistic Hamiltonian, $H=\sqrt{p^2c^2+m^2c^4}$, contains this as the
$p=0$ special case: $H=mc^2$, energy present even with zero momentum.

**Photon momentum.** A photon is massless. Setting $m=0$ in that same
relation collapses it to $E=pc$ — the relativistic energy–momentum
relation for anything with no rest mass. Combined with day 13's photon
energy $E=hf=hc/\lambda$, this gives photon momentum directly:
$$p = \frac{E}{c} = \frac{hf}{c} = \frac{h}{\lambda}.$$
A wave that carries no mass nevertheless pushes on things it hits, with a
momentum fixed entirely by its wavelength.

**Compton scattering.** Picture a photon and an electron colliding like
two billiard balls — an elastic collision in which both relativistic
energy and momentum are conserved between the incoming photon, the
outgoing (longer-wavelength, lower-energy) photon, and the recoiling
electron. Carrying out that conservation bookkeeping (day 15's and the
course's proper treatment of relativistic collisions) yields the
**Compton formula**, stated here and used, not derived:
$$\Delta\lambda = \lambda' - \lambda = \frac{h}{m_ec}(1-\cos\theta),$$
where $\theta$ is the photon's scattering angle and $m_ec$ is the
electron's rest momentum-scale. The constant $h/(m_ec)=2.43\,\text{pm}$
is the electron's *Compton wavelength*. The significance: a photon
recoils off an electron and loses energy in exactly the way a particle
with momentum $p=h/\lambda$ should — direct proof that light, in its
interaction with matter, carries momentum like a particle, interference
experiments (day 6) notwithstanding. Worked Example 4 computes a concrete
case.

## Worked examples

**1. Bohr-level numbers for $n=1$.**
Using $a_0=\hbar^2/(m_ek_ee^2)$ and $E_n=-\tfrac12 k_ee^2/r_n$ derived
above:
$$r_1 = a_0 = 5.29\times10^{-11}\,\text{m} = 52.9\,\text{pm}, \qquad
E_1 = -13.6\,\text{eV}.$$
The orbital speed follows from $L=m_ev_1r_1=\hbar$:
$$v_1 = \frac{\hbar}{m_ea_0} =
\frac{1.055\times10^{-34}}{(9.109\times10^{-31})(5.29\times10^{-11})}
\approx 2.19\times10^{6}\,\text{m/s},$$
about $0.73\%$ of $c$ — small enough that the non-relativistic derivation
in Section 3 is self-consistent for hydrogen's ground state.

**2. Balmer $\alpha$ wavelength ($n=3\to2$).**
$$\frac{1}{\lambda} = R\left(\frac{1}{4}-\frac{1}{9}\right) =
R\cdot\frac{5}{36} = (1.097\times10^7\,\text{m}^{-1})(0.1389) \approx
1.524\times10^6\,\text{m}^{-1},$$
$$\lambda \approx 6.56\times10^{-7}\,\text{m} = 656\,\text{nm}.$$
That's deep red, visible light — the famous H$\alpha$ line, the strongest
line in hydrogen's visible spectrum and a direct consequence of the
$n=3\to2$ jump computed entirely from Section 3's $E_n$ formula.

**3. Einstein-relations derivation as a worked argument.**
Take a cavity of two-level atoms with $\Delta=hf$ at temperature $T$.
Step through Section 6's logic on paper, numbers optional:

- Write detailed balance: $N_1B_{12}u=N_2A_{21}+N_2B_{21}u$.
- Insert Boltzmann: $N_2/N_1=e^{-hf/k_BT}$, giving
  $u=A_{21}/\left(B_{12}e^{hf/k_BT}-B_{21}\right)$.
- Take $T\to\infty$: the field must diverge, forcing the denominator to
  vanish as $e^{hf/k_BT}\to1$, so $B_{12}=B_{21}\equiv B$.
- With $B_{12}=B_{21}$, $u=A_{21}/[B(e^{hf/k_BT}-1)]$; matching the known
  Planck form $u=(8\pi hf^3/c^3)/(e^{hf/k_BT}-1)$ term-by-term gives
  $A_{21}/B=8\pi hf^3/c^3$.

The whole argument uses only: rate balance (bookkeeping), day 12's
Boltzmann populations, and day 13's Planck law — no new physics, only
consistency. That two universal relations between three otherwise
unrelated atomic constants fall out of pure thermodynamic bookkeeping is
the payoff.

**4. Compton scattering: $0.1\,\text{nm}$ X-ray at $\theta=90°$.**
$\lambda = 0.1\,\text{nm} = 100\,\text{pm}$. At $\theta=90°$,
$\cos\theta=0$, so
$$\Delta\lambda = \frac{h}{m_ec}(1-0) = 2.43\,\text{pm}.$$
The scattered photon has $\lambda' = 100+2.43 = 102.43\,\text{pm}$.
Photon energies, using $hc=1239.84\,\text{eV}\cdot\text{nm}$:
$$E_\gamma = \frac{hc}{\lambda} = \frac{1239.84\,\text{eV}\cdot
\text{nm}}{0.1\,\text{nm}} = 12{,}398\,\text{eV}, \qquad
E_\gamma' = \frac{1239.84}{0.10243} \approx 12{,}105\,\text{eV}.$$
Energy conservation hands the difference to the recoiling electron:
$$K_e = E_\gamma - E_\gamma' \approx 12{,}398 - 12{,}105 \approx
294\,\text{eV}.$$
A photon that lost under $2.5\%$ of its wavelength (a small fractional
shift) still kicked an electron with nearly $300\,\text{eV}$ of kinetic
energy — a genuinely particle-like recoil, exactly as the momentum
$p=h/\lambda$ from Section 8 predicts.

## Exercises

Attempt every problem closed-book before checking the Hints, and only
then the Solutions.

**Retrieval**

1. Re-derive $E_n=-13.6\,\text{eV}/n^2$ from Bohr's three postulates,
   closed book: start from $L=n\hbar$ and Newton's second law for
   circular Coulomb orbits.
2. State the three atom–light processes (absorption, spontaneous
   emission, stimulated emission) and name which Einstein coefficient
   governs each.

**Standard**

3. Hydrogen ionization: find the minimum photon frequency that can ionize
   a hydrogen atom starting from $n=1$, and, separately, starting from
   $n=2$.
4. The ratio of stimulated to spontaneous emission rates in a thermal
   field at temperature $T$ and frequency $f$ is
   $B\,u(f)/A_{21}$. Using Section 6's relations, show this ratio equals
   $1/(e^{hf/k_BT}-1)$, then evaluate it (a) for visible light
   ($f$ such that $hf\approx2\,\text{eV}$) at room temperature, and
   (b) for microwaves ($f=10\,\text{GHz}$) at room temperature.
   Interpret the contrast.

**Stretch**

5. Why can't a two-level system lase in steady state? Sketch the rate
   equation for a two-level atom pumped and de-excited through the *same*
   optical transition (same $B$ coefficient in both directions, plus
   spontaneous decay $A$), solve for the steady-state population
   difference $N_1-N_2$, and show it stays $\ge0$ for any pump strength.

## Hints

1. Set up the centripetal-force equation with Coulomb attraction, bring
   in $L=m_evr=n\hbar$ to eliminate $v$, solve for $r_n$, then substitute
   back into $E=\tfrac12m_ev^2-k_ee^2/r$.
2. Match each process to whether its rate depends on the field ($u(f)$)
   or not, and on which level's population it acts on.
3. Ionization from level $n$ means the electron ends at $E=0$; the photon
   supplies $|E_n|$. Convert eV to Hz via $f=E/h$.
4. Write $u(f)$ in Planck form, divide by $A_{21}/B_{21}=8\pi hf^3/c^3$,
   and simplify. For each numeric case, compute $hf/k_BT$ first and check
   whether it's large or small before evaluating the exponential.
5. Write $dN_2/dt = N_1Bu - N_2Bu - N_2A$, set it to zero for steady
   state, and solve for $N_1-N_2$ in terms of manifestly positive
   quantities.

## Solutions

**1.** Centripetal force: $k_ee^2/r^2 = m_ev^2/r \Rightarrow m_ev^2r =
k_ee^2$. Quantization: $L=m_evr=n\hbar \Rightarrow v=n\hbar/(m_er)$.
Substitute: $m_e(n\hbar/m_er)^2r=k_ee^2 \Rightarrow
r_n=n^2\hbar^2/(m_ek_ee^2)=n^2a_0$. Energy:
$E=\tfrac12m_ev^2-k_ee^2/r$; since $m_ev^2=k_ee^2/r$, this is
$E=\tfrac12k_ee^2/r - k_ee^2/r = -\tfrac12k_ee^2/r$. Substituting
$r=n^2a_0$ and simplifying the constants gives
$E_n=-m_ek_e^2e^4/(2\hbar^2n^2)$, which evaluates numerically to
$-13.6\,\text{eV}/n^2$.

**2.** Absorption: atom in level 1 absorbs a photon, jumps to level 2;
governed by $B_{12}$, rate $\propto u(f)$. Spontaneous emission: atom in
level 2 decays unprompted, random direction/phase; governed by $A_{21}$,
rate independent of $u(f)$. Stimulated emission: atom in level 2 is
triggered by the field to decay, emitting a copy (same frequency,
direction, phase) of the triggering field; governed by $B_{21}$, rate
$\propto u(f)$.

**3.** From $n=1$: ionization needs $E=0-E_1=13.6\,\text{eV}$.
$13.6\,\text{eV} = 13.6\times1.602\times10^{-19}\,\text{J} =
2.179\times10^{-18}\,\text{J}$.
$f = E/h = 2.179\times10^{-18}/6.626\times10^{-34} \approx
3.29\times10^{15}\,\text{Hz}$.
From $n=2$: needs $E=0-E_2=0-(-13.6/4)=3.4\,\text{eV} =
5.447\times10^{-19}\,\text{J}$.
$f = 5.447\times10^{-19}/6.626\times10^{-34}\approx8.22\times10^{14}\,
\text{Hz}$ — about a quarter of the $n=1$ frequency, matching
$3.4/13.6=1/4$.

**4.** $u(f) = \dfrac{8\pi hf^3}{c^3}\cdot\dfrac{1}{e^{hf/k_BT}-1}$, and
$A_{21}/B_{21}=8\pi hf^3/c^3$, so
$$\frac{B\,u(f)}{A_{21}} = \frac{u(f)}{A_{21}/B_{21}} =
\frac{1}{e^{hf/k_BT}-1}.$$
**(a) Visible light, room temperature.** $hf\approx2\,\text{eV}$,
$k_BT\approx1/40\,\text{eV}=0.025\,\text{eV}$ (day 12's anchor), so
$hf/k_BT\approx80$. Ratio $\approx1/(e^{80}-1)\approx e^{-80}$ — utterly,
astronomically negligible (of order $10^{-35}$).
**(b) Microwaves, room temperature.** $f=10\,\text{GHz}$:
$hf = (6.626\times10^{-34})(10^{10}) = 6.626\times10^{-24}\,\text{J}
\approx 4.14\times10^{-5}\,\text{eV}$. $hf/k_BT \approx
4.14\times10^{-5}/0.025 \approx 1.66\times10^{-3}$, small, so
$e^x-1\approx x$: ratio $\approx 1/(1.66\times10^{-3})\approx 600$.
**Interpretation.** For visible light at room temperature, stimulated
emission is negligible compared to spontaneous emission — ordinary warm
objects glow almost entirely by spontaneous emission, which is why you
need a genuinely non-thermal, intense field (or a laser cavity) to make
stimulated emission dominate at optical frequencies. For microwaves at
the *same* temperature, stimulated emission outruns spontaneous emission
by hundreds of times — thermal microwave fields are "occupied" enough
that stimulated processes take over easily, which is exactly why masers
(the microwave predecessor of the laser) were built and understood
before optical lasers.

**5.** Rate equation for the upper level, with pump and stimulated
emission both driven by the same field/coefficient $B$ (absorption
$N_1Bu$ feeds level 2, stimulated emission $N_2Bu$ and spontaneous decay
$N_2A$ drain it):
$$\frac{dN_2}{dt} = N_1Bu - N_2Bu - N_2A.$$
Steady state ($dN_2/dt=0$):
$$N_1Bu = N_2Bu + N_2A \quad\Longrightarrow\quad
Bu(N_1-N_2) = N_2A \quad\Longrightarrow\quad
N_1-N_2 = \frac{N_2A}{Bu}.$$
The right side is a ratio of manifestly positive quantities ($N_2,A,B,u
\ge0$, with $u>0$ whenever there's any pumping at all), so
$N_1-N_2\ge0$ for *any* pump intensity $u$ — population never inverts.
As $u\to\infty$, $N_1-N_2\to0^+$: the best a two-level system pumped
through its own transition can do is *equalize* the populations
(saturation), never invert them, because the same $B$ that pumps atoms up
also stimulates them back down exactly as fast. This is precisely why a
third (or fourth) level, reached by a *different* transition, is
necessary for lasing.

## Connection to QM

Today's two-level atom is not a simplification you'll discard — it *is*
the physical qubit implemented by many photonics platforms your course
will use (a two-level electronic or spin transition addressed by light).
The rate-equation story above (populations flowing between two levels
under a driving field, plus decay) is the incoherent, classical-probability
shadow of a fully coherent quantum process: when the course derives Rabi
oscillations, you'll see the *same* two-level system, driven the *same*
way, but tracking a coherent quantum amplitude instead of a population —
Rabi oscillations are what today's absorption/stimulated-emission balance
looks like before you average away the phase information the copying
property in Section 5 already told you was there.

Bohr's postulate $L=n\hbar$ is also the very first appearance of angular
momentum quantization — an ad hoc rule here, forced by fitting hydrogen's
spectrum, but one the course later *derives* properly from the
eigenvalues of the quantum angular momentum operator, with none of
Bohr's classical-orbit baggage attached. You've already met the answer;
day 15 onward shows you where it actually comes from.
