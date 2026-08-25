# Physics Fundamentals — A Bridge to Quantum Mechanics

An eighteen-day physics path for someone who has done the linear algebra and
quantum computing foundations paths in this repo, and is now about to take a
photonics-flavored quantum mechanics course with no physics background to
stand on. It assumes you can differentiate, integrate, and manipulate complex
numbers and matrices comfortably, and it assumes you remember no physics at
all. It ends with you able to read $\hat H\psi=E\psi$ as both a differential
equation and a matrix eigenvalue problem, and to see an interferometer as a
quantum circuit.

## Start here

**Read [`STRATEGY.md`](STRATEGY.md) before day 1.** It explains the protocol
each day follows, the study habits that waste time in a path like this one,
and — importantly — what was deliberately cut and why. The day files assume
you have read it.

The rhythm is one file per day, worked in order, closed-book:

1. Read the **Learning objectives** and the stated time budget.
2. Work through **Theory**, doing the algebra yourself rather than reading it.
3. Read the **Worked examples** only after attempting them.
4. Run the **Simulation**, if the day has one — predict before you run.
5. Attempt every **Exercise** closed-book, then the **Hints**, and only then
   the **Solutions**.
6. Read the closing **Connection to QM** section, which names exactly what the
   day buys you in the course.

**Total budget: ~62.5 hours over 18 days**, at 3–4 hours per day. Days 16–18
are deliberately placed so they may overlap the first weeks of your course —
that is by design, not a scheduling failure. See the last section below.

## The five phases

| Phase | Days | What it does |
|---|---|---|
| 1 — Mechanics re-foundation | 1–4 | Newton's laws as differential equations, energy and potential wells, the harmonic oscillator in depth, and conservation laws from symmetry. |
| 2 — Waves & light | 5–8 | Coupled oscillators into the wave equation, standing waves and interferometers, Fourier intuition and wave packets, and polarization as a genuine two-state system. |
| 3 — Analytical mechanics | 9–11 | The action principle, the Lagrangian and Hamiltonian reformulations, and Poisson brackets — the classical structure quantum mechanics is built on top of. |
| 4 — The classical breakdown | 12–15 | Thermal physics, blackbody radiation and the photon, atomic spectra and atom–light interaction, and matter waves: the four places classical physics visibly failed. |
| 5 — The bridge | 16–18 | The Schrödinger equation solved completely for the box, the quantum oscillator with tunneling and uncertainty, and a dictionary translating everything into the notation of your course. |

## Day index

| Day | Title | Hours | Simulation |
|---|---|---|---|
| 1 | [Newton as Differential Equations](content/day01.md) | ~3 | — |
| 2 | [Energy and Potential Wells](content/day02.md) | ~3 | — |
| 3 | [The Harmonic Oscillator, Deep](content/day03.md) | ~3 | [`day03_oscillator_zoo.py`](code/day03_oscillator_zoo.py) |
| 4 | [Momentum, Angular Momentum, and Symmetry](content/day04.md) | ~3 | — |
| 5 | [From Oscillators to Waves](content/day05.md) | ~3.5 | — |
| 6 | [Superposition, Standing Waves, and Interferometers](content/day06.md) | ~3.5 | [`day06_interference_standing_waves.py`](code/day06_interference_standing_waves.py) |
| 7 | [Fourier Intuition and Wave Packets](content/day07.md) | ~3.5 | [`day07_wave_packet_builder.py`](code/day07_wave_packet_builder.py) |
| 8 | [Light and Polarization as a Two-State System](content/day08.md) | ~3.5 | — |
| 9 | [Action and the Lagrangian](content/day09.md) | ~3.5 | — |
| 10 | [The Hamiltonian](content/day10.md) | ~3.5 | [`day10_phase_space.py`](code/day10_phase_space.py) |
| 11 | [Poisson Brackets and the Quantum Preview](content/day11.md) | ~3.5 | — |
| 12 | [Minimal Thermal Physics](content/day12.md) | ~3.5 | — |
| 13 | [Blackbody Radiation and the Photon](content/day13.md) | ~3.5 | `day13_blackbody_curves.py` *(pending)* |
| 14 | [Atoms, Spectra, and Atom–Light Interaction](content/day14.md) | ~3.5 | — |
| 15 | [Matter Waves and the Synthesis](content/day15.md) | ~3.5 | — |
| 16 | [The Schrödinger Equation](content/day16.md) | ~4 | `day16_box_eigenstates.py` *(pending)* |
| 17 | [The Quantum Oscillator, Tunneling, and Heisenberg's Uncertainty Principle](content/day17.md) | ~4 | `day17_packet_evolution.py` *(pending)* |
| 18 | [The Rosetta Stone](content/day18.md) | ~4 | — |

Day 18 replaces the usual exercise tiers with a **twelve-question readiness
self-test** spanning the whole path. The pass bar is 9/12 unaided; each
solution names the day to revisit if you missed it.

## Prerequisites

You need calculus you can actually use — differentiation and integration by
hand, partial derivatives, and enough comfort with ordinary differential
equations to recognize $\ddot x=-\omega_0^2x$ and know what solves it. You
need the linear algebra path (or equivalent): vector spaces, bases, inner
products, eigenvalues and eigenvectors, Hermitian and unitary matrices. You
need complex numbers, including $e^{i\theta}=\cos\theta+i\sin\theta$ used
fluently rather than looked up. The quantum computing foundations path is
assumed alongside this one — days 8, 11, 16, and 18 cite it directly.

**No physics is assumed.** Not mechanics, not electromagnetism, not
thermodynamics. Every physical law used is either derived in place or
explicitly flagged as an experimental input the path takes on faith.

## Simulations

Seven days have an accompanying simulation. Four exist today; three are
specified but not yet written — their `## Simulation` sections in the day
files describe what to look at and what to predict, so those days still work
without the script.

```bash
pip install numpy matplotlib
python3 code/day03_oscillator_zoo.py
```

Each script runs with no arguments, opens a multi-panel matplotlib figure,
and carries `TWEAK:` lines in its header docstring naming the parameters
worth changing. The specifications for the three pending scripts
(`day13_blackbody_curves.py`, `day16_box_eigenstates.py`,
`day17_packet_evolution.py`) live in the Simulations section of
[`docs/superpowers/plans/2026-08-24-physics-fundamentals-qm-bridge.md`](docs/superpowers/plans/2026-08-24-physics-fundamentals-qm-bridge.md).

Always predict before you run. The prompts in each `## Simulation` section
are the point of the exercise; watching the plot without having committed to
an answer first teaches almost nothing.

## Glossary and cut list

[`content/GLOSSARY.md`](content/GLOSSARY.md) defines every term the path uses
in plain English, alphabetically, each entry naming the day where the term is
first used in earnest. It opens with a notation table covering the symbol
collisions worth memorizing — $k$ versus $k_s$ versus $k_e$, and the three
different jobs $L$ does across the path.

What this path deliberately does **not** cover — the full hydrogen solution,
spin algebra, perturbation theory, and a good deal else — is listed with
reasons in [`STRATEGY.md`](STRATEGY.md)'s *What we cut and why* section. Read
it if you are tempted to add material; most of the omissions are things your
course will do properly, and doing them badly first is worse than not doing
them.

## If your course starts before day 18

That is expected — phase 5 is built to overlap. If you have to compress, the
honest ordering is this. **Never skip days 9–11 or day 16.** Days 9–11 are the
Lagrangian, Hamiltonian, and Poisson-bracket structure that your course will
assume without teaching, and there is no way to pick it up later from lecture;
day 16 is the Schrödinger equation and the particle in a box, which is the
base case every subsequent topic perturbs away from. Days 12–14 compress
best: they are the historical case that classical physics failed, and while
that story is genuinely worth having, your course will re-cover the
photoelectric effect and Bohr's model in its own first weeks. Read them
quickly, do the retrieval-tier exercises only, and come back to the rest when
the term calms down.

If you have time for exactly one day out of the whole path, it is day 18 —
but only after day 16, because most of what it translates comes from there.
