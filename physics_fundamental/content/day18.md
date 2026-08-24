# Day 18 — The Rosetta Stone

## Learning objectives

By the end of today you should be able to:
- Translate fluently between the wave-mechanics notation of Days 12–17 and
  the Dirac/matrix notation of your quantum computing course, using one
  two-column dictionary that runs in both directions.
- Realize a qubit three independent ways — a truncated particle-in-a-box, a
  photon's polarization, and a photon's which-path state in a Mach–Zehnder
  interferometer — and show all three collapse to the same $2\times2$
  matrix mathematics.
- Read a Mach–Zehnder interferometer as a single-qubit circuit: identify
  the beam splitter as a Hadamard-like unitary and the phase shifter as a
  diagonal unitary, and reproduce Day 6's boxed intensity laws as
  measurement probabilities.
- Diagonalize a $2\times2$ two-level Hamiltonian built from two truncated
  energy levels plus a weak coupling, and interpret the eigenvalues as
  level repulsion.
- Apply a quarter-wave plate's matrix to both an eigenpolarization and a
  superposition polarization, and explain why the two outcomes differ.
- Locate every major topic of the upcoming course on this path's course
  map, and name which day of this path prepared it.
- Pass the readiness self-test at $9/12$ or better, unaided.

Time budget: ~4 hours.

## Reference material

- Griffiths, *Introduction to Quantum Mechanics* — the sections contrasting
  the position representation with abstract Dirac notation state today's
  dictionary from the quantum-mechanics side.
- Nielsen & Chuang, *Quantum Computation and Quantum Information* — the
  postulates-of-quantum-mechanics section states the same $2\times2$ matrix
  mathematics from the computing side; read it alongside
  `quantum_computing_foundations/content/day03.md`.
- Hecht, *Optics* — the polarization and interferometry chapters are the
  classical-optics companion to today's two photonic-qubit realizations.
- This file is self-contained. It cites, without re-deriving, results
  already built in Days 6, 8, 11, 14, 16, and 17 of this path, and in Days
  3, 4, 6, and 7 of `quantum_computing_foundations` (read-only
  cross-references — you do not need to reopen those files to follow
  today's argument, only to go deeper afterward).

## Theory

### The dictionary: one theory, two bases

Everything from Day 12 onward has been building the left-hand column below;
everything in your quantum computing course so far has been building the
right-hand column. They are the same theory, read in two different
representations of the same abstract vector space.

| Wave mechanics (Days 12–17) | Dirac / matrix mechanics (quantum computing course) |
|---|---|
| $\psi(x)$ | $\lvert\psi\rangle$ |
| $\int \phi_n^*\psi\,dx$ | $\langle n\vert\psi\rangle$ |
| $\int\lvert\psi\rvert^2dx=1$ | $\langle\psi\vert\psi\rangle=1$ |
| operator $-i\hbar\,\partial_x$ | a matrix |
| TISE $\hat H\phi_n=E_n\phi_n$ | eigenvalue problem $H\lvert n\rangle=E_n\lvert n\rangle$ |
| expansion $\psi=\sum_n c_n\phi_n$ | $\lvert\psi\rangle=\sum_n c_n\lvert n\rangle$ |
| $\lvert c_n\rvert^2$ | Born rule |
| phase $e^{-iEt/\hbar}$ | unitary evolution $U=e^{-iHt/\hbar}$ |

Row by row, in the order that actually builds understanding:

1. **$\psi(x)$ vs. $\lvert\psi\rangle$.** $\psi(x)$ is the *component list*
   of an abstract state vector $\lvert\psi\rangle$ in the (continuous, so
   infinite) basis of position eigenstates — exactly as a Jones vector
   $(a,b)^T$ is the component list of a polarization state in the $\{H,V\}$
   basis. $\lvert\psi\rangle$ is the basis-independent object; $\psi(x)$ is
   one particular representation of it, chosen because position is
   convenient for a particle in a potential.
2. **$\int\phi_n^*\psi\,dx$ vs. $\langle n\vert\psi\rangle$.** Both compute
   the same thing: "how much of basis state $n$ is inside $\psi$." The
   integral is the inner product written out in the position
   representation (Day 16's expansion coefficients); the bracket is the
   same inner product written abstractly, exactly as taught in
   `quantum_computing_foundations/day03.md`'s inner-product section.
   Re-skim that section now with this row in mind — the integral *is* the
   bracket, not an analogy to it.
3. **Normalization.** $\int\lvert\psi\rvert^2dx=1$ (Day 16's normalization
   condition) is $\langle\psi\vert\psi\rangle=1$ written in the position
   basis: total probability integrates, in this basis, to a Riemann
   integral rather than a finite sum, because position is a continuous
   label rather than a discrete one — the only real novelty the continuum
   introduces.
4. **Operators become matrices.** $-i\hbar\,\partial_x$ (Day 15's momentum
   operator) is a linear operator on an infinite-dimensional space; in any
   *finite* truncation (below) it becomes an ordinary matrix, for exactly
   the reason your course represents observables as Hermitian matrices.
   Nothing about "matrix" versus "differential operator" is fundamental —
   both are linear maps on a vector space, differing only in whether the
   space is finite- or infinite-dimensional.
5. **TISE vs. eigenvalue problem.** $\hat H\phi_n=E_n\phi_n$ (Day 16) *is*
   $H\lvert n\rangle=E_n\lvert n\rangle$ — literally the same equation,
   with $\phi_n$ written out as a function of $x$ on the left and treated
   abstractly on the right. Solving a differential equation for
   eigenfunctions and diagonalizing a matrix for eigenvectors are the same
   operation performed on two different representations of $\hat H$.
6. **Expansion in eigenstates.** Day 16's $\psi=\sum_n c_n\phi_n$ is
   $\lvert\psi\rangle=\sum_n c_n\lvert n\rangle$ — any state is a
   superposition of energy eigenstates, weighted by the same coefficients
   $c_n=\langle n\vert\psi\rangle$ that row 2 defined.
7. **$\lvert c_n\rvert^2$ and the Born rule.** Day 16's rule "the
   probability of finding energy $E_n$ is $\lvert c_n\rvert^2$" is not an
   analogy to the Born rule you meet in your course — it *is* the Born
   rule, already stated in wave-mechanics language before you had the name
   for it.
8. **Time dependence as unitary evolution.** Day 17's stationary-state
   phase $e^{-iE_nt/\hbar}$ attached to each $\phi_n$ is the eigenvalue
   form of the general evolution law $\lvert\psi(t)\rangle
   =U(t)\lvert\psi(0)\rangle$, $U(t)=e^{-iHt/\hbar}$: applied to an energy
   eigenstate, $U(t)\lvert n\rangle=e^{-iE_nt/\hbar}\lvert n\rangle$,
   recovering exactly the phase Day 17 attached by hand. $U$ is unitary
   ($U^\dagger U=I$) because $H$ is Hermitian — the same fact that makes
   every gate in your course's circuits unitary.

> **Misconception:** "wave mechanics and matrix mechanics are different
> theories, and quantum mechanics happens to admit two independent
> formulations that agree by luck." They are not two theories that agree —
> they are one theory, written in two bases of the same abstract vector
> space, exactly as a vector in the plane can be written in Cartesian or
> polar coordinates. Every row of the table above is a single equation
> viewed through two notational choices, not two separate facts that happen
> to match. Historically, Heisenberg's matrix mechanics (1925) and
> Schrödinger's wave mechanics (1926) were developed independently and
> looked unrelated for about a year, until Schrödinger himself proved they
> were unitarily equivalent — the same proof this table walks through row
> by row, eighty-plus years later, as a warm-up exercise rather than a
> research result.

### Day 11's table, reprinted

Day 11 built a second dictionary — classical mechanics to quantum
mechanics via the canonical-quantization recipe — as a preview, before any
of the machinery above existed. Reprinted here verbatim, the two tables
together are the whole conceptual map of this path: today's table converts
between two *representations* of quantum mechanics; Day 11's converts
*into* quantum mechanics from classical mechanics in the first place.

| Classical | Quantum |
|---|---|
| $f(q,p)$ | operator $\hat f$ |
| $\{f,g\}$ | $\dfrac{1}{i\hbar}[\hat f,\hat g]$ |
| $\{q,p\}=1$ | $[\hat q,\hat p]=i\hbar$ |
| $\dot f=\{f,H\}$ | Heisenberg equation $\dfrac{d\hat f}{dt}=\dfrac{1}{i\hbar}[\hat f,\hat H]$ |
| conserved $\iff \{f,H\}=0$ (for $f$ with no explicit $t$) | conserved $\iff [\hat f,\hat H]=0$ (commutes with $\hat H$; for $\hat f$ with no explicit $t$) |

Stack the two tables mentally: Day 11 gets you *into* quantum mechanics
from classical mechanics (bracket $\to$ commutator); today's table gets you
*between* the two equivalent internal descriptions of quantum mechanics
itself (differential-equation basis $\to$ abstract-vector basis). Nothing
in either table is optional machinery — every later topic in your course
is a further elaboration of one row of one of these two tables.

### Two-level truncation: where a qubit actually comes from

Day 11 previewed this in one paragraph; here is the full statement. Take
the particle-in-a-box eigenstates from Day 16, $\phi_n(x)=\sqrt{2/L}\,
\sin(n\pi x/L)$ with $E_n=n^2\pi^2\hbar^2/(2mL^2)$, and suppose every
physically relevant energy scale in a problem (a driving field, a coupling
to another system) only ever connects the two lowest levels, $\phi_1$ and
$\phi_2$, leaving every $\phi_n$ with $n\ge3$ energetically inaccessible.
Then it is an excellent approximation to discard every basis state except
$\lvert1\rangle,\lvert2\rangle$ and work entirely inside the
two-dimensional subspace they span. Any state in that subspace is
$$\lvert\psi\rangle = \alpha\lvert1\rangle+\beta\lvert2\rangle,
\qquad \lvert\alpha\rvert^2+\lvert\beta\rvert^2=1,$$
and every observable — the truncated Hamiltonian, any coupling operator —
restricted to this subspace is, in the $\{\lvert1\rangle,\lvert2\rangle\}$
basis, an ordinary $2\times2$ Hermitian matrix. That is a qubit: not a
special kind of particle, but *any* quantum system once you have agreed to
keep only two of its levels. Day 14's two-level atom is the identical
construction performed on an atom's ground and one excited state instead
of a box's two lowest modes — same truncation, same resulting $2\times2$
matrix problem, different physical system underneath. Worked example 2
below carries the box version through explicitly.

$$\boxed{\text{A qubit is not a thing --- it is any quantum system you have agreed to use two levels of.}}$$

### Photonic qubit #1: polarization, reread

Day 8's Jones vectors already are qubit states; today just changes the
name. Relabel $\lvert H\rangle=(1,0)^T\to\lvert0\rangle$ and
$\lvert V\rangle=(0,1)^T\to\lvert1\rangle$. Then:

- **Wave plates are single-qubit unitaries.** A quarter-wave plate acts, in
  the $e^{i(kx-\omega t)}$ convention Day 8 fixed, as
  $$\mathrm{QWP} = \begin{pmatrix}1&0\\0&i\end{pmatrix},$$
  a diagonal unitary ($\mathrm{QWP}^\dagger\mathrm{QWP}=I$ since
  $\lvert i\rvert^2=1$) — a phase gate, in your course's language, applied
  to the polarization qubit. Worked example 3 below runs it on two
  different inputs.
- **Malus's law is the Born rule.** Day 8's Malus's law,
  $I=I_0\cos^2\theta$ for a polarizer at angle $\theta$ to the incoming
  polarization, is the probability of measuring the polarization qubit to
  be in the state $\lvert\theta\rangle=\cos\theta\lvert H\rangle
  +\sin\theta\lvert V\rangle$ given that it started aligned with $H$:
  $\lvert\langle\theta\vert H\rangle\rvert^2=\cos^2\theta$. It was the Born
  rule the entire time, stated in an optics course before either side had
  a name for what it was doing.
- **A polarizing beam splitter is a measurement in the $H/V$ basis.** It
  routes $\lvert H\rangle$ and $\lvert V\rangle$ to two distinct output
  ports with certainty, and routes any superposition
  $\alpha\lvert H\rangle+\beta\lvert V\rangle$ to the two ports with
  probabilities $\lvert\alpha\rvert^2,\lvert\beta\rvert^2$ — a projective
  measurement in the computational basis, built from glass and a coating.

### Photonic qubit #2: the Mach–Zehnder as a circuit

Day 6 derived the Mach–Zehnder interferometer's two output intensities
classically, from a fixed beam-splitter matrix convention. Reread as a
qubit circuit: the which-path degree of freedom (upper arm vs. lower arm)
*is* the qubit basis, $\lvert\text{arm }1\rangle\to\lvert0\rangle$,
$\lvert\text{arm }2\rangle\to\lvert1\rangle$.

**The beam splitter is a single-qubit unitary.** Day 6 fixed the 50/50,
energy-conserving beam-splitter matrix as
$$M = \frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix},$$
with output port $1$ (the $\cos^2$ port) the *bright* port at $\phi=0$.
This $M$ is real, symmetric, and satisfies $M^2=I$ — it is exactly the
Hadamard gate from your quantum computing course, discovered independently
in classical optics decades earlier. *(One-sentence convention note: some
texts instead symmetrize the beam splitter as $\frac{1}{\sqrt2}
\begin{pmatrix}1&i\\i&1\end{pmatrix}$; that variant is unitary too, but it
swaps which output port is bright at $\phi=0$, so it is not the convention
used here or in Day 6.)*

**The phase shifter is a diagonal unitary.** A path-length difference or
inserted sample (Day 6's glass-slab example) applies
$$P(\phi) = \begin{pmatrix}1&0\\0&e^{i\phi}\end{pmatrix}$$
to the which-path state — the phase gate again, now generated optically by
an actual extra path length rather than a wave plate.

**The full circuit.** A photon entering arm $1$ (state $\lvert0\rangle$)
passes through $M$ (first beam splitter), then $P(\phi)$ (the phase
difference between the arms), then $M$ again (second beam splitter). The
output state is $M\,P(\phi)\,M\lvert0\rangle$, and the probability of
detection at port $k$ is $\lvert\langle k\vert MP(\phi)M\vert0\rangle
\rvert^2$ by the Born rule. Worked example 1 below carries out this exact
product and shows it reproduces Day 6's boxed laws,
$I_1=I_0\cos^2(\phi/2)$, $I_2=I_0\sin^2(\phi/2)$, term for term and port
for port.

**Single-photon reading.** Send one photon at a time. It does not go down
one arm or the other — its probability amplitude is present in *both* arms
simultaneously (that is what $M\lvert0\rangle=\frac{1}{\sqrt2}(1,1)^T$
means), and the two amplitudes interfere at the second beam splitter
exactly as the classical field amplitudes did in Day 6. What is never
divided is the *detector click*: every trial produces exactly one photon
at exactly one port, with the click statistics across many trials
reproducing $\cos^2(\phi/2)$ and $\sin^2(\phi/2)$ as relative *frequencies*
rather than as a continuous intensity.

> **Misconception:** "the photon splits at the beam splitter, part going
> down each arm." A photon is never divided — detection is always a whole
> photon at one port, never half a photon at each of two ports. What
> splits is the *probability amplitude*, the complex number
> $\frac{1}{\sqrt2}$ attached to each arm in $M\lvert0\rangle$; amplitudes
> are mathematical bookkeeping devices, not fractions of a physical
> particle. The distinction between "the amplitude is in both arms" and
> "the photon is in both arms" is not pedantry — it is, in embryonic form,
> the entire subject of the measurement chapter your quantum computing
> course has not reached yet: amplitudes evolve smoothly and can
> interfere with themselves (Day 6's whole derivation), while measurement
> outcomes are always sharp, whole, and probabilistic (the Born rule
> applied at the very last step, and only there). Keep the two words
> — amplitude and outcome — as separate in your head as this paragraph
> keeps them on the page.

### The course map

| Course topic | Prepared by (this path) | Connects to (`quantum_computing_foundations`) |
|---|---|---|
| Postulates & Dirac formalism | Days 11, 16, 18 | `day03.md` — Complex Vector Spaces & the Qubit |
| Two-level dynamics / Rabi oscillations | Days 14, 18 | `day04.md` — Normal Matrices, Spectral Theorem, Single-Qubit Unitaries & the Bloch Sphere |
| Harmonic oscillator & quantized light | Day 17 | not among the four pinned days above — watch for it later in the course |
| Interferometry & photon statistics | Days 6, 17, 18 | `day06.md` — Measurement, the Born Rule & Density Matrices |
| Measurement theory | Days 16, 18 | `day06.md` — Measurement, the Born Rule & Density Matrices |
| Entanglement | not built by this path — every state here has been a single particle or a single photon | `day07.md` — Multi-Qubit States, Entanglement & No-Cloning |

That last row is worth sitting with: this entire eighteen-day path has
been, deliberately, a *single-particle* theory. Entanglement is the first
genuinely new physical phenomenon your course introduces that has no
counterpart anywhere in these eighteen days — everything else on the map
is a formalization of something you have already computed.

## Worked examples

**1. The full Mach–Zehnder matrix product, symbolic then at
$\phi=0,\pi/2,\pi$.** Compute $M\,P(\phi)\,M\,\lvert0\rangle$ with
$M=\frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}$,
$P(\phi)=\begin{pmatrix}1&0\\0&e^{i\phi}\end{pmatrix}$,
$\lvert0\rangle=\binom{1}{0}$.

*Step 1:* $M\lvert0\rangle=\frac{1}{\sqrt2}\binom{1}{1}$.

*Step 2:* $P(\phi)\cdot\frac{1}{\sqrt2}\binom{1}{1}
=\frac{1}{\sqrt2}\binom{1}{e^{i\phi}}$.

*Step 3:* $M\cdot\frac{1}{\sqrt2}\binom{1}{e^{i\phi}}
=\frac12\begin{pmatrix}1&1\\1&-1\end{pmatrix}\binom{1}{e^{i\phi}}
=\frac12\binom{1+e^{i\phi}}{1-e^{i\phi}}.$

So, symbolically,
$$MP(\phi)M\lvert0\rangle = \frac12\binom{1+e^{i\phi}}{1-e^{i\phi}},$$
identical in form to Day 6's $\binom{E_1}{E_2}=\frac{E_0}{2}
\binom{1+e^{i\phi}}{1-e^{i\phi}}$ with $E_0=1$. Detection probabilities are
$$P_1=\left\lvert\frac{1+e^{i\phi}}{2}\right\rvert^2=\cos^2(\phi/2),
\qquad
P_2=\left\lvert\frac{1-e^{i\phi}}{2}\right\rvert^2=\sin^2(\phi/2),$$
using the same half-angle identities Day 6 used. Now evaluate:

- $\phi=0$: state becomes $\frac12\binom{2}{0}=\binom{1}{0}$, so
  $P_1=1,P_2=0$ — port 1 fully bright, matching Day 6's $\phi=0$ boundary
  exactly (port 1 is the bright port).
- $\phi=\pi/2$: $1+i,\ 1-i$, both of magnitude $\sqrt2$, so
  $P_1=P_2=\tfrac12$ — an even split, matching
  $\cos^2(\pi/4)=\sin^2(\pi/4)=\tfrac12$.
- $\phi=\pi$: $1+e^{i\pi}=0$, $1-e^{i\pi}=2$, so the state becomes
  $\binom{0}{1}$: $P_1=0,P_2=1$ — ports fully reversed, matching Day 6's
  $\phi=\pi$ boundary exactly (port 1 fully dark, port 2 fully bright).

Every number matches Day 6's boxed laws and port labels precisely, with
the same computation performed as a $2\times2$ matrix circuit rather than
a classical-field calculation.

**2. Two-level truncation on the box: levels 1–2 with a weak coupling.**
Take an electron in a box of length $L=2\text{ nm}$. From Day 16,
$E_n=n^2\pi^2\hbar^2/(2mL^2)$ gives $E_1=0.0941\text{ eV}$,
$E_2=4E_1=0.3763\text{ eV}$ (levels 3 and up are assumed energetically
irrelevant here). Suppose a weak perturbation couples the two levels with
real matrix element $\varepsilon=0.050\text{ eV}$ (e.g., a small applied
field), so the truncated Hamiltonian in the $\{\lvert1\rangle,
\lvert2\rangle\}$ basis is the $2\times2$ Hermitian matrix
$$H = \begin{pmatrix}E_1 & \varepsilon\\ \varepsilon & E_2\end{pmatrix}
= \begin{pmatrix}0.0941 & 0.050\\ 0.050 & 0.3763\end{pmatrix}\text{eV}.$$
Diagonalize: for a general $2\times2$ Hermitian matrix
$\begin{pmatrix}a&\varepsilon\\\varepsilon&b\end{pmatrix}$ the eigenvalues
are $\lambda_\pm=\frac{a+b}{2}\pm\sqrt{\left(\frac{a-b}{2}\right)^2
+\varepsilon^2}$ (the standard $2\times2$ secular equation
$(a-\lambda)(b-\lambda)-\varepsilon^2=0$, solved by the quadratic formula).
Here $\frac{a+b}{2}=0.2352\text{ eV}$, $\frac{a-b}{2}=-0.1411\text{ eV}$,
so
$$\lambda_\pm = 0.2352 \pm\sqrt{(0.1411)^2+(0.050)^2}
= 0.2352\pm\sqrt{0.01991+0.0025}=0.2352\pm0.1497.$$
$$\lambda_+ = 0.385\text{ eV}, \qquad \lambda_- = 0.0855\text{ eV}.$$
Compare to the uncoupled levels $E_2=0.376$, $E_1=0.0941$: the coupling
pushes the upper level *up* (from $0.376$ to $0.385$) and the lower level
*down* (from $0.0941$ to $0.0855$) — **level repulsion**, the generic
behavior of any two coupled levels, and exactly the $2\times2$
diagonalization your course performs on every single-qubit Hamiltonian.
Day 14's two-level atom is this identical calculation with an atomic
ground/excited pair standing in for $\lvert1\rangle,\lvert2\rangle$.

**3. Quarter-wave plate on $\lvert H\rangle$ versus on the diagonal
state.** Apply $\mathrm{QWP}=\begin{pmatrix}1&0\\0&i\end{pmatrix}$ to two
different inputs.

*Input $\lvert H\rangle=\binom{1}{0}$:*
$$\mathrm{QWP}\binom{1}{0} = \binom{1}{0} = \lvert H\rangle.$$
Nothing happens — $\lvert H\rangle$ is an eigenstate of the diagonal QWP
matrix (eigenvalue $1$), so the plate's fast/slow axes aligned with $H/V$
leave pure $H$ polarization completely unaffected.

*Input diagonal, $\lvert D\rangle=\frac{1}{\sqrt2}\binom{1}{1}$:*
$$\mathrm{QWP}\cdot\frac{1}{\sqrt2}\binom{1}{1}
= \frac{1}{\sqrt2}\binom{1}{i}.$$
This is exactly the circular-polarization state
$\frac{1}{\sqrt2}(1,i)^T$ from Day 8's pinned circular states
$\frac{1}{\sqrt2}(1,\pm i)^T$ — the same unitary that does *nothing* to
$\lvert H\rangle$ converts a $45^\circ$-diagonal input entirely into
circular polarization. The lesson generalizes directly to qubit gates: a
gate's effect depends entirely on the input basis relative to the gate's
own eigenbasis — trivial on the gate's eigenstates, maximally
transformative on an equal superposition of them (compare: a phase gate
does nothing to $\lvert0\rangle$ or $\lvert1\rangle$ but rotates
$\lvert+\rangle$ around the Bloch sphere's equator).

## Readiness self-test

This section replaces the standard Exercises/Hints/Solutions tiers.
Twelve questions span the whole path — attempt every one closed-book,
exactly as you would sit them without notes, before checking the Hints,
and only after that, the Solutions.

**Pass bar: $9/12$ correct, unaided, means you are ready to start the
course.** Below $9/12$, each solution below names the day to revisit
before moving on.

**Mechanics**

1. *(V(x) reading)* A particle of mass $m=0.50\text{ kg}$ moves under
   $V(x)=\tfrac12 k_sx^2$ with $k_s=8.0\text{ N/m}$, confined so this form
   holds for $\lvert x\rvert\le1.0\text{ m}$. Its total mechanical energy
   is $E=2.0\text{ J}$. Find the turning points and describe the motion.
2. *(oscillator $\omega_0$ from a potential)* A particle of mass
   $m=0.10\text{ kg}$ sits in $V(x)=V_0\big(1-\cos(x/a)\big)$ with
   $V_0=0.50\text{ J}$, $a=0.20\text{ m}$. Find the small-oscillation
   angular frequency $\omega_0$ about $x=0$.

**Waves**

3. *(standing-wave quantization)* A string of length $L=1.2\text{ m}$ has
   wave speed $v=150\text{ m/s}$ and is fixed at both ends. Find the first
   three allowed frequencies.
4. *(group velocity)* A wave has dispersion relation
   $\omega(k)=c_0k+\alpha k^3$ with $c_0=300\text{ m/s}$,
   $\alpha=2.0\text{ m}^3/\text{s}$. Find the group velocity at
   $k=5.0\text{ rad/m}$, and compare it to the phase velocity there.

**Analytical**

5. *(construct an $H$)* A block of mass $m$ slides without friction on an
   incline of angle $\theta$, with generalized coordinate $s$ measured
   along the incline from the top. Construct the Hamiltonian $H(s,p)$.
6. *(a Poisson bracket)* Compute $\{x^2,p\}$ directly from the single-pair
   definition.

**Quantum evidence**

7. *(Planck's average energy)* A cavity mode has frequency
   $f=1.0\times10^{13}\text{ Hz}$ at temperature $T=300\text{ K}$. Compute
   Planck's average energy $\langle E\rangle=hf/(e^{hf/k_BT}-1)$ and
   compare it to the classical equipartition value $k_BT$.
8. *(photoelectric numbers)* A metal with work function $\phi=2.0\text{
   eV}$ is illuminated at $\lambda=400\text{ nm}$. Find the maximum
   photoelectron kinetic energy and the stopping voltage.

**Wave mechanics**

9. *(box energies)* An electron is confined to a box of length
   $L=2.0\text{ nm}$. Find $E_1,E_2,E_3$.
10. *(uncertainty estimate)* For the same electron confined to
    $\Delta x=L=2.0\text{ nm}$, use $\Delta x\,\Delta p\ge\hbar/2$ to
    estimate a minimum kinetic energy, and compare it (order of magnitude)
    to $E_1$ from Question 9.

**Bridge**

11. *(MZ matrix product)* For the Mach–Zehnder circuit of this day's
    Theory section, find $P_1$ and $P_2$ at $\phi=2\pi/3$.
12. *(polarization-qubit Born rule)* A polarization qubit is prepared in
    $\lvert\psi\rangle=\cos30^\circ\lvert H\rangle+\sin30^\circ\lvert
    V\rangle$. Find the probability of measuring it in the diagonal state
    $\lvert D\rangle=\frac{1}{\sqrt2}(\lvert H\rangle+\lvert V\rangle)$.

## Hints

1. Set $E=\tfrac12k_sx^2$ and solve for $x$; check the result lies inside
   the region where the parabolic form is valid.
2. Taylor-expand $\cos(x/a)$ to second order in $x$, identify the
   effective spring constant $k_s$ from the resulting quadratic term, then
   use $\omega_0=\sqrt{k_s/m}$.
3. Use $f_n=nv/2L$ directly (Day 6's boxed result) for $n=1,2,3$.
4. Differentiate $\omega(k)$ to get $v_g(k)$; separately divide $\omega(k)$
   by $k$ to get $v_p(k)$; evaluate both at the given $k$.
5. Write $L=T-V=\tfrac12m\dot s^2-mg\sin\theta\,s$, find
   $p=\partial L/\partial\dot s$, then Legendre-transform,
   $H=p\dot s-L$, eliminating $\dot s$ in favor of $p$.
6. Apply $\{f,g\}=\partial_xf\,\partial_pg-\partial_pf\,\partial_xg$ with
   $f=x^2$, $g=p$ directly — only one of the two terms survives.
7. Compute $hf$ and $k_BT$ separately in joules, form the ratio
   $hf/k_BT$, then evaluate the exponential.
8. Convert the photon energy $hc/\lambda$ to eV first, then subtract the
   work function; the stopping voltage in volts equals the kinetic energy
   in eV divided by the elementary charge.
9. Use $E_n=n^2\pi^2\hbar^2/(2mL^2)$ from Day 16 directly with $n=1,2,3$.
10. Solve $\Delta x\,\Delta p=\hbar/2$ for $\Delta p_{\min}$, then estimate
    $KE\sim(\Delta p_{\min})^2/2m$; compare orders of magnitude with
    Question 9's $E_1$, don't expect an exact match.
11. Use $P_1=\cos^2(\phi/2)$, $P_2=\sin^2(\phi/2)$ directly, or redo the
    matrix product from Worked example 1 with $\phi=2\pi/3$ substituted.
12. Write $\lvert\psi\rangle$ as a column vector, take the inner product
    with $\lvert D\rangle$, and square its magnitude — or use the fact
    that this is Malus's law with the angle between the two states.

## Solutions

**1.** $\tfrac12(8.0)x^2=2.0\Rightarrow x^2=0.50\Rightarrow
x=\pm0.71\text{ m}$, well inside $\lvert x\rvert\le1.0\text{ m}$. The
particle undergoes bound, symmetric simple-harmonic oscillation between
$x=-0.71\text{ m}$ and $x=+0.71\text{ m}$, turning around at each point
where all its energy is potential. *(If missed: revisit Days 1–2, energy
conservation and turning points.)*

**2.** $\cos(x/a)\approx1-\tfrac12(x/a)^2$, so
$V(x)\approx\frac{V_0}{2a^2}x^2$, giving effective
$k_s=V_0/a^2=0.50/(0.20)^2=12.5\text{ N/m}$. Then
$\omega_0=\sqrt{k_s/m}=\sqrt{12.5/0.10}=\sqrt{125}\approx11.2\text{
rad/s}$. *(If missed: revisit Day 3, oscillators from an expanded
potential.)*

**3.** $f_n=nv/2L=n(150)/2.4=n(62.5\text{ Hz})$:
$f_1=62.5\text{ Hz}$, $f_2=125\text{ Hz}$, $f_3=187.5\text{ Hz}$.
*(If missed: revisit Day 6, standing waves and quantization.)*

**4.** $v_g=d\omega/dk=c_0+3\alpha k^2=300+3(2.0)(25)=300+150
=450\text{ m/s}$. Phase velocity $v_p=\omega/k=c_0+\alpha
k^2=300+2.0(25)=350\text{ m/s}$. The two differ ($v_g\ne v_p$) because the
medium is dispersive; the wave packet's envelope moves at $450\text{
m/s}$, faster than any individual crest. *(If missed: revisit Day 5,
dispersion.)*

**5.** $L=\tfrac12m\dot s^2-mg\sin\theta\,s$, so
$p=\partial L/\partial\dot s=m\dot s\Rightarrow\dot s=p/m$. Then
$$H=p\dot s-L = p\cdot\frac{p}{m}-\left[\frac12m\left(\frac{p}{m}\right)^2
-mg\sin\theta\,s\right]=\frac{p^2}{m}-\frac{p^2}{2m}+mg\sin\theta\,s
=\boxed{\frac{p^2}{2m}+mg\sin\theta\,s}.$$
*(If missed: revisit Days 9–11, the Legendre transform to $H(q,p)$.)*

**6.** $\{x^2,p\}=\partial_x(x^2)\cdot\partial_pp-\partial_p(x^2)
\cdot\partial_xp = (2x)(1)-(0)(0)=2x$. *(If missed: revisit Day 11,
Poisson brackets.)*

**7.** $hf=(6.626\times10^{-34})(1.0\times10^{13})=6.63\times10^{-21}
\text{ J}$. $k_BT=(1.381\times10^{-23})(300)=4.14\times10^{-21}\text{
J}$. Ratio $hf/k_BT=1.60$, so $e^{1.60}-1\approx3.95$, giving
$\langle E\rangle=6.63\times10^{-21}/3.95\approx1.68\times10^{-21}
\text{ J}$ — about $40\%$ of the classical value $k_BT$, illustrating
Planck's suppression of high-frequency modes relative to the classical
(Rayleigh–Jeans) prediction. *(If missed: revisit Day 12, blackbody
radiation.)*

**8.** $E_{\text{photon}}=hc/\lambda=(6.626\times10^{-34})(2.998\times10^8)
/(4.00\times10^{-7})=4.97\times10^{-19}\text{ J}=3.10\text{ eV}$. Maximum
kinetic energy $KE_{\max}=3.10-2.0=1.10\text{ eV}$; stopping voltage
$V_{\text{stop}}=KE_{\max}/e\approx1.10\text{ V}$. *(If missed: revisit
Day 13, the photoelectric effect.)*

**9.** $E_1=\pi^2\hbar^2/(2mL^2)$ with $L=2.0\times10^{-9}\text{ m}$,
$m=9.11\times10^{-31}\text{ kg}$: $E_1\approx1.51\times10^{-20}\text{ J}
=0.0941\text{ eV}$. Since $E_n=n^2E_1$: $E_2=0.376\text{ eV}$,
$E_3=0.847\text{ eV}$. *(If missed: revisit Day 16, particle in a box.)*

**10.** $\Delta p_{\min}=\hbar/(2\Delta x)=(1.055\times10^{-34})/
(4.0\times10^{-9})=2.64\times10^{-26}\text{ kg m/s}$. Estimated
$KE\sim(\Delta p_{\min})^2/2m=(2.64\times10^{-26})^2/
(1.82\times10^{-30})\approx3.8\times10^{-22}\text{ J}\approx0.0024\text{
eV}$ — smaller than the exact $E_1=0.0941\text{ eV}$ from Question 9 by a
factor of almost exactly $4\pi^2\approx39.5$. That factor is not an error:
the uncertainty bound uses the *minimum possible* $\Delta p$ for a flat
guess at $\Delta x$, while the true ground state's momentum spread,
carried by the curved $\sin(\pi x/L)$ profile, is larger than this flat
lower bound by exactly enough to produce the extra $4\pi^2$. The
uncertainty estimate gets the right functional form
($KE\sim\hbar^2/m\Delta x^2$) but not the exact numerical prefactor — that
requires the actual wavefunction, i.e. Day 16's full calculation.
*(If missed: revisit Day 17, the uncertainty principle.)*

**11.** $P_1=\cos^2(\pi/3)=(0.5)^2=0.25$, $P_2=\sin^2(\pi/3)=
(\sqrt3/2)^2=0.75$. Check via the matrix product:
$1+e^{i2\pi/3}=1+(-0.5+i0.866)=0.5+i0.866$, magnitude$^2=0.25+0.75=1.0$;
dividing by the overall factor of $4$ from $\lvert(1+e^{i\phi})/2\rvert^2$
gives $P_1=0.25$, matching. $P_1+P_2=1.0$, energy/probability conserved.
*(If missed: revisit Day 6 and today's Worked example 1.)*

**12.** $\lvert\psi\rangle=(\cos30^\circ,\sin30^\circ)^T=
(\sqrt3/2,\,1/2)^T$. $\langle D\vert\psi\rangle
=\frac{1}{\sqrt2}\left(\frac{\sqrt3}{2}+\frac12\right)
=\frac{\sqrt3+1}{2\sqrt2}$. Probability
$=\left(\frac{\sqrt3+1}{2\sqrt2}\right)^2=\frac{(\sqrt3+1)^2}{8}
=\frac{4+2\sqrt3}{8}\approx0.933$. Cross-check via Malus's law: the angle
between $\lvert\psi\rangle$ ($30^\circ$ from $H$) and $\lvert D\rangle$
($45^\circ$ from $H$) is $15^\circ$, and $\cos^2(15^\circ)\approx0.933$ —
the polarization Born rule and Malus's law are the same formula, as
Theory established. *(If missed: revisit Day 8, polarization and Malus's
law, and today's Photonic qubit #1 section.)*

## Connection to QM

**What you can now do.** Walk into your quantum computing course able to
read $\hat H\lvert\psi\rangle=E\lvert\psi\rangle$ simultaneously as a
differential equation you could solve by separation of variables (Day 16)
and as a matrix eigenvalue problem you could solve by diagonalization
(Worked example 2, and every unitary in your course) — the same equation,
never two different ones. You can see any interferometer, any wave-plate
setup, any two-level atom as a quantum circuit built from $2\times2$
unitaries, because you have now derived, by hand, three independent
physical systems that all reduce to that same mathematics. And you have a
map: when your course introduces a new topic, you can place it against
this path's eighteen days and know exactly which piece of physics prepared
it and which of it is genuinely new (entanglement, chiefly — nothing here
built that, and the course map above says so honestly).

**The standing instruction.** Re-read Day 11 again after week 2 of your
course, once commutators have appeared in lecture. It was designed, on
its own first page, to be better the second time — and by then you will
also have today's two dictionaries in hand, which turns Day 11's preview
into a completed picture rather than a promise. That second reading is
the last item on this path's syllabus, even though it happens after the
path is finished.
