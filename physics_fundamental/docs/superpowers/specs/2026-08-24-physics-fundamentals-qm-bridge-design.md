# Physics Fundamentals → QM Bridge: Design Spec

**Date:** 2026-08-24
**Status:** Approved design, pending implementation plan
**Location:** `physics_fundamental/`

## Purpose

An 18-day, ~60–75 hour physics re-learning path that prepares the learner for a
"Foundations of Quantum Mechanics" class in a quantum computing/information
master's program. The class starts in ~15 days; days 16–18 of this path may
overlap the first course weeks by design.

The learner was once strong at high-school and university physics but is long
out of practice, has fresh math (see the completed `linear_algebra/` path), and
has completed the 15-day `quantum_computing_foundations/` path (Dirac notation,
qubits, gates). This path supplies the *physical* story underneath that
formalism: where Hamiltonians, waves, and quantization come from. The course
is expected to lean toward **atom–light interaction and photonics**, so the
path gives extra weight to interference machines, polarization as a two-state
system, and how atoms absorb and emit light.

## Strategy (the core design decision)

**Backwards from QM.** Rather than the traditional curriculum order, the
content is the dependency graph of a first QM course, taught in the order QM
needs it. Classical physics is framed as "the theory QM deforms." Breadth
across the HS/university canon is honored through short *conceptual
consolidation* sections at survey depth, and an explicit cut list — never by
pretending depth the hour budget cannot fund.

Approaches rejected: a compressed traditional survey (breadth everywhere,
depth nowhere — punished hard by a QM course) and a parallel two-track design
(breadth track + depth track — too much daily structure for an 18-day window).

## Constraints

- 3–4 focused hours/day; day files state their time estimate and must fit it.
- No git commits by Claude — the user handles all VCS.
- No git commands inside subagent dispatches during execution.
- Spec/plan/docs written on the reasoning model; content/code file writing
  requires asking the user before switching to Sonnet.
- Practice problems always ship with hint blocks and solution sketches.
- Python simulations: numpy + matplotlib only, single runnable scripts.

## Directory layout

```
physics_fundamental/
├── README.md                  # roadmap: phase map, day index, time budget, usage
├── STRATEGY.md                # unconventional-strategy + mistakes-to-avoid doc
├── content/
│   ├── day01.md … day18.md
│   └── GLOSSARY.md            # plain-English glossary, style of LA/quantum ones
├── code/
│   └── dayXX_<topic>.py       # 7 simulations (list below)
└── docs/superpowers/
    ├── specs/                 # this document
    └── plans/                 # implementation plan (writing-plans output)
```

## Curriculum

### Phase 1 — Mechanics re-foundation (days 1–4, ~3h/day)

- **Day 1 — Newton as differential equations.** Compressed kinematics/Newton
  re-derivation: F=ma as an ODE, solved for constant force, linear drag,
  springs. Establishes the frame "physics = solving ẍ = f(x)."
- **Day 2 — Energy and potential wells.** Work, kinetic/potential energy,
  conservation. Fluency in reading V(x) diagrams: turning points, stable and
  unstable equilibria, bound vs. free motion.
- **Day 3 — The harmonic oscillator, deep.** SHM emerging from any potential
  minimum, amplitude/phase, energy exchange, damped and driven oscillation,
  resonance. *Sim: oscillator zoo.*
- **Day 4 — Momentum, angular momentum, symmetry.** Conservation of momentum
  and angular momentum, central forces, Noether's insight informally
  (symmetry → conservation law). Consolidation survey: rotational dynamics,
  gravity/orbits.

### Phase 2 — Waves & light (days 5–8, ~3.5h/day)

- **Day 5 — From oscillators to waves.** Coupled oscillators → the wave
  equation; traveling waves; phase vs. group velocity intuition.
- **Day 6 — Superposition and standing waves.** Interference, beats, standing
  waves; boundary conditions → discrete modes — the classical origin of
  "quantization." Two-path interferometers (Michelson, Mach–Zehnder) as the
  cleanest interference machines — built here classically, reused on day 18 as
  qubit circuits. *Sim: interference/standing waves.*
- **Day 7 — Fourier intuition and wave packets.** Any shape as a sum of modes;
  wave packets; the classical bandwidth theorem Δx·Δk ≳ 1 (uncertainty before
  quantum). *Sim: build a wave packet from modes.*
- **Day 8 — Light, for a photonics-flavored course.** Fields; what each
  Maxwell equation *says* (no PDE grinding); light as an EM wave. Then
  polarization done properly as a *two-state system*: linear/circular bases,
  Malus's law, wave plates conceptually, Jones-vector notation — deliberately
  the same 2-vector math as qubits. Consolidation survey: circuits and
  geometric optics, one paragraph each.

### Phase 3 — Analytical mechanics (days 9–11, ~3.5h/day)

- **Day 9 — Action and the Lagrangian.** Principle of least action;
  Euler–Lagrange derived once, applied three times (free particle, oscillator,
  pendulum).
- **Day 10 — The Hamiltonian.** Legendre transform (gently), H as total
  energy, Hamilton's equations, phase-space portraits. *Sim: phase-space
  flows.*
- **Day 11 — Poisson brackets and the quantum preview.** Conserved quantities
  via brackets; the honest preview "replace {,} with commutators and you have
  QM." Written to be re-read after week 2 of the course.

### Phase 4 — The classical breakdown (days 12–15, ~3.5h/day)

- **Day 12 — Minimal thermal physics.** Temperature, Boltzmann distribution,
  equipartition — exactly what blackbody radiation needs, nothing more.
- **Day 13 — Blackbody and the photon.** Rayleigh–Jeans catastrophe, Planck's
  fix, photoelectric effect, Einstein's photon. *Sim: Rayleigh–Jeans vs.
  Planck curves.*
- **Day 14 — Atoms, spectra, and atom–light interaction.** Rutherford's
  stability problem, spectral lines, the Bohr model as inspired guessing —
  why it works and why it's wrong. Then how light talks to atoms: absorption,
  spontaneous vs. stimulated emission, Einstein A/B coefficients, the laser in
  one page, and the two-level atom as the recurring model of the course.
  Relativity teaser: E=mc², photon momentum, Compton scattering.
- **Day 15 — Matter waves and the synthesis.** de Broglie hypothesis,
  Davisson–Germer. Synthesis: particles are waves, waves come in modes, modes
  are discrete → quantization is boundary conditions on matter waves.

### Phase 5 — The bridge (days 16–18, ~4h/day; may overlap course start)

- **Day 16 — The Schrödinger equation.** Motivated (plane wave + E=ħω, p=ħk +
  energy conservation), Born rule, normalization; particle in a box fully
  worked. *Sim: box eigenstates.*
- **Day 17 — Quantum oscillator, tunneling, uncertainty.** QHO results and
  structure (not the full series solution), tunneling qualitatively, wave
  packets and the genuine uncertainty principle. *Sim: evolving Gaussian
  packet.*
- **Day 18 — The Rosetta Stone.** Explicit dictionary between wave mechanics
  and the Dirac/qubit formalism: ψ(x) ↔ |ψ⟩, operators ↔ matrices, energy
  eigenstates ↔ computational basis, two-level systems as truncated atoms.
  Photonic qubits made concrete: polarization qubit (Jones vectors from day 8
  become |0⟩/|1⟩), beam splitters as unitaries, the Mach–Zehnder
  interferometer from day 6 re-read as a single-photon qubit circuit.
  Cross-references specific `quantum_computing_foundations/content/dayXX.md`
  files by name. Ends with a self-test gating "ready for the course."

## Anatomy of a day file

Each `content/dayXX.md` contains, in order:

1. **Learning goals + time estimate** (must fit the day's hour budget).
2. **Theory** as narrative-with-derivations: every named equation is derived
   or physically motivated, never dropped in.
3. **2–3 fully worked examples.**
4. **4–6 practice problems** in three tiers — retrieval, standard, stretch —
   each with a hint block and a solution sketch. Problems must be solvable
   from that day's content plus prior days only.
5. **"Connection to QM" closing box:** what this day buys in the course.
6. **Common-misconception callouts** inline where they bite.

## Simulations (7)

| File | Shows |
|---|---|
| `day03_oscillator_zoo.py` | SHM, damped, driven; resonance sweep |
| `day06_interference_standing_waves.py` | Two-wave interference, beats, standing-wave modes, Mach–Zehnder output vs. phase |
| `day07_wave_packet_builder.py` | Summing modes into a packet; Δx·Δk trade-off |
| `day10_phase_space.py` | Phase portraits: oscillator, pendulum |
| `day13_blackbody_curves.py` | Rayleigh–Jeans vs. Planck vs. data |
| `day16_box_eigenstates.py` | Particle-in-a-box eigenfunctions and energies |
| `day17_packet_evolution.py` | Gaussian packet spreading / bouncing |

Each: single script, numpy + matplotlib only, ≤150 lines, "tweak this
parameter" prompts in a header comment, runs clean via `python3 <file>`.

## STRATEGY.md contents

The path's front door, written first:

- **Top-1% re-learner protocol:** learn backwards from the target formalism;
  derive-don't-reread; close the book and re-derive every named equation the
  next morning; a daily Fermi estimate; interleave old problems into new days.
- **The 80% time-wasters:** grinding projectile/statics problem sets; passive
  lecture videos; chasing math rigor before physical intuition; skipping
  analytical mechanics; treating the historical experiments as trivia instead
  of evidence; note-taking as transcription.
- **The cut list, honestly:** fluids, thermodynamic cycles, DC/AC circuits,
  geometric-optics instruments, rigid-body dynamics beyond angular momentum —
  each with one line on why it does not block a QM course.

## Verification

- Built via subagent-driven development (pattern of `aws_security_components/`
  and `cyber_security/`), no git commands in any dispatch.
- Per-day review gate: derivations correct; problems solvable from allowed
  content; hints don't spoil; solutions complete; QM-connection box accurate;
  time estimate plausible for the stated hour budget.
- All sims execute without error and produce their plots.
- README day index, phase map, and cross-references verified against the
  actual files (reconcile checklist ↔ corpus, per lesson learned on the
  glossaries project).

## Out of scope

Spin/angular-momentum algebra, hydrogen atom solution, perturbation theory,
identical particles, density matrices (the course itself and the existing
quantum path cover these); any LaTeX/PDF build; any commit or push.
