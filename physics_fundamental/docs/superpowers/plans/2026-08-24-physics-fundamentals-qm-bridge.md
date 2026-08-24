# Physics Fundamentals → QM Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an 18-day, ~62.5-hour physics re-learning path in `physics_fundamental/` that takes a rusty-but-once-good learner from Newtonian mechanics to the doorstep of a photonics-flavored "Foundations of Quantum Mechanics" master's course.

**Architecture:** Pure content project — 18 markdown day files organized as a "backwards from QM" dependency spine (mechanics → waves/light → analytical mechanics → classical breakdown → Schrödinger/Dirac bridge), plus 7 standalone Python simulations, a strategy doc, glossary, and README roadmap. No build system, no tests-as-code; verification is checklist review plus running every simulation.

**Tech Stack:** GitHub-flavored Markdown with `$...$`/`$$...$$` LaTeX; Python 3 with numpy + matplotlib only.

**Spec:** `physics_fundamental/docs/superpowers/specs/2026-08-24-physics-fundamentals-qm-bridge-design.md`

## Global Constraints

Every task's requirements implicitly include all of the following.

**Process:**
- **NO git commands anywhere.** No `git add`, `git commit`, `git status`, `git diff`, `git log` — not in this session, not in any subagent dispatch. The user handles all version control. Task completion = files written and verified, nothing more.
- All paths below are relative to `physics_fundamental/` unless they start with `quantum_computing_foundations/` (a sibling directory used read-only for cross-references).
- Content/code file writing happens on Sonnet per the user's standing preference (the orchestrating session asks the user before switching; task briefs themselves don't change).

**Day-file anatomy (every `content/dayXX.md`, in this order):**
1. `# Day N — <Title>` then `## Learning objectives` — "By the end of today you should be able to:" + 4–7 concrete, testable bullets, then a stated time budget line (e.g., "Time budget: ~3 hours").
2. `## Reference material` — 2–4 bullets: which standard text chapter matches (Halliday/Resnick, Morin, French's *Vibrations and Waves*, Eisberg–Resnick, Griffiths QM as appropriate per day), a note that the file is self-contained, and pointers to prior days it builds on.
3. `## Theory` — narrative-with-derivations. Every named equation is derived or physically motivated in-line, never dropped in. Use `###` subsections. Include the day's **common-misconception callouts** as blockquotes beginning `> **Misconception:**` (at least 2 per day) placed where they bite.
4. `## Worked examples` — 2–3 fully worked, numbered, each with a bold one-line statement then complete solution including numbers where relevant.
5. `## Exercises` — 4–6 problems, numbered continuously, grouped under three bold tier labels: **Retrieval** (1–2 problems: state/derive/verify things from today's theory), **Standard** (2–3 problems: apply today's tools to new setups), **Stretch** (1 problem: combines today with a prior day or pushes one step further). Open with the house line: "Attempt every problem closed-book before checking the Hints, and only then the Solutions."
6. `## Hints` — one short hint per exercise, numbered to match. A hint names the tool or first move ("write energy conservation between the top and the turning point") without giving the answer.
7. `## Solutions` — full solution sketch per exercise, numbered to match: the key steps and the final answer, in the style of `quantum_computing_foundations/content/day03.md`'s Solutions section (complete but compressed — no skipped logical steps, no essay padding).
8. `## Connection to QM` — closing section, 1–3 paragraphs: exactly what this day buys in the QM course, naming the course concepts it unlocks.
9. Days with a simulation add `## Simulation` between Worked examples and Exercises: what to run (`python3 code/<file>.py`), what to look at, and 2–3 "now change this parameter and predict before you run" prompts.

**Formatting/notation conventions (used identically in all 18 files):**
- Math: `$...$` inline, `$$...$$` display, matching the house style of `quantum_computing_foundations/content/day03.md`.
- Symbols: $x, v, a$ kinematics; $\omega$ angular frequency; $\omega_0$ natural frequency; $k$ wave number (spring constant is $k_s$ wherever both could collide, i.e., days 3, 5, 16, 17); $V(x)$ potential energy; $T$ kinetic energy in analytical-mechanics days 9–11 (elsewhere $K$); $L$ Lagrangian in days 9–11, angular momentum elsewhere (each of days 9–11 states this explicitly on first use); $\mathcal{L}$ is NOT used; $H$ Hamiltonian; $\{f,g\}$ Poisson bracket; $\hbar$, $h$; $\psi$ wavefunction; Jones vectors as 2-component column vectors with $|H\rangle, |V\rangle$ labels.
- Problems must be solvable from that day's content plus prior days only — no forward references, no outside material.
- Target length per day file: 350–600 lines (the quantum path's heavy days run ~370; phase-5 days may reach 600 with solutions).

**Simulations (all 7):**
- numpy + matplotlib only. No scipy, no animation libraries (use multi-panel snapshots instead of animation).
- ≤150 lines each, single file, runs clean via `python3 code/<file>.py` with no arguments, ends with `plt.show()`.
- Header docstring: one-line purpose, then 2–3 "TWEAK:" lines naming parameters to change and what to expect.
- Where numerical integration is needed, use the Euler–Cromer method (semi-implicit Euler): `v += a(x)*dt; x += v*dt` — stable for oscillatory systems, no scipy dependency.

**Per-day verification checklist (run for every day file before calling its task done):**
1. All anatomy sections present, in order, correctly headed.
2. Every named equation in Theory is derived or explicitly motivated ("we take from experiment...").
3. Exercise count 4–6; tiers labeled; hints don't spoil; every exercise has a matching hint AND solution; solutions actually solve the stated problem.
4. Exercises use only this day + prior days.
5. Notation matches the conventions block above.
6. ≥2 `> **Misconception:**` callouts.
7. Time budget stated and plausible: ~3h for days 1–4, ~3.5h for days 5–15, ~4h for days 16–18.
8. Sim days: script exists, runs clean, `## Simulation` section present with predict-before-run prompts.

---

## File Structure

```
physics_fundamental/
├── README.md                              (Task 21)
├── STRATEGY.md                            (Task 1)
├── content/
│   ├── day01.md … day18.md                (Tasks 2–19)
│   └── GLOSSARY.md                        (Task 20)
├── code/
│   ├── day03_oscillator_zoo.py            (Task 4)
│   ├── day06_interference_standing_waves.py (Task 7)
│   ├── day07_wave_packet_builder.py       (Task 8)
│   ├── day10_phase_space.py               (Task 11)
│   ├── day13_blackbody_curves.py          (Task 14)
│   ├── day16_box_eigenstates.py           (Task 17)
│   └── day17_packet_evolution.py          (Task 18)
└── docs/superpowers/{specs,plans}/        (already exist)
```

Task order = file order: STRATEGY.md first (it frames how every day file is meant to be used), days 1–18 in sequence (later days cross-reference earlier ones), then GLOSSARY (needs the corpus to exist), then README (indexes everything), then the final coherence pass.

---

### Task 1: STRATEGY.md

**Files:**
- Create: `STRATEGY.md`

**Interfaces:**
- Produces: section names `## The protocol`, `## The time-wasters`, `## What we cut and why` — day files and README refer to STRATEGY.md generically (no anchor links), so only the file's existence and these three sections are load-bearing.

- [ ] **Step 1: Draft STRATEGY.md (~150–250 lines) with this exact structure:**

1. Title + framing paragraph: who this is for (rusty former physics student, strong recent math from the linear algebra path, completed quantum computing foundations path, QM course in a quantum-info master's starting in ~15 days, 3–4 h/day).
2. `## The protocol` — the top-1% re-learner method, one subsection each, each with a concrete "do this today" instruction:
   - **Learn backwards from the target.** The path is the dependency graph of a QM course, not the traditional curriculum. State the spine explicitly (mechanics → waves → Hamiltonians → quantum evidence → Schrödinger → Dirac).
   - **Derive, don't re-read.** Every named equation: close the file next morning and re-derive it on paper. Include the concrete morning ritual (10 min, yesterday's boxed equations, blank paper).
   - **Retrieval beats review.** Do the exercises closed-book; the Hints→Solutions escalation exists so you never peek at a solution before attempting a hint.
   - **One Fermi estimate per day.** Give the list of 18 suggested estimates, one per day, matched to that day's topic (e.g., day 3: "estimate the resonant frequency of a car on its suspension"; day 13: "estimate how many visible photons a light bulb emits per second").
   - **Interleave.** Each day's Stretch problem deliberately reaches back; additionally, every 4th day re-derive one equation from ≥3 days ago.
3. `## The time-wasters` — the 80% traps, one short subsection each with the *specific replacement behavior*: grinding projectile/statics problem sets; passive lecture videos; chasing mathematical rigor before physical intuition; skipping analytical mechanics; treating the historical experiments (blackbody, photoelectric) as trivia rather than evidence; note-taking as transcription.
4. `## What we cut and why` — table of the cut list from the spec (fluids, thermodynamic cycles, DC/AC circuits, geometric-optics instruments, rigid-body dynamics beyond angular momentum), each with one line on why it doesn't block a QM course.
5. `## How a day works` — walk through the day-file anatomy from the learner's side: objectives → theory with derivations → worked examples → sim (some days) → closed-book exercises → hints → solutions → QM connection box; state the 3/3.5/4-hour budgets by phase.

- [ ] **Step 2: Verify:** all five sections present; every protocol subsection has a concrete instruction; 18 Fermi estimates listed; cut-list table matches the spec's five items; no git or commit references anywhere.

---

### Task 2: Day 1 — Newton as Differential Equations

**Files:**
- Create: `content/day01.md`

**Interfaces:**
- Produces: the framing sentence "classical mechanics is: given $F(x,v,t)$, solve $m\ddot{x}=F$" — quoted back by days 5, 9, 16. Also the drag time-constant result $v(t)=v_{\mathrm{term}}(1-e^{-t/\tau})$, $\tau=m/b$, reused as the exponential-approach archetype in day 12.

- [ ] **Step 1: Draft `content/day01.md` (~3h day) with this content brief:**

*Learning objectives:* translate between kinematics language and ODE language; solve $m\ddot{x}=F$ for constant force, linear drag, and spring force (preview); use dimensional analysis to check any result; state all three Newton laws precisely and as ODE statements.

*Theory beats (in order):*
1. Kinematics as definitions, not laws: $v=\dot x$, $a=\dot v$; position/velocity/acceleration graphs read together.
2. Newton's three laws stated precisely; the second as the ODE $m\ddot{x}=F(x,\dot x,t)$ — "the rest of classical mechanics is choosing $F$ and solving." Box this framing.
3. Constant force: integrate twice → projectile motion as two independent ODEs; derive range formula.
4. Linear drag: solve $m\dot v = mg - bv$ by separation → terminal velocity $v_{\mathrm{term}}=mg/b$ and $v(t)=v_{\mathrm{term}}(1-e^{-t/\tau})$ with $\tau=m/b$; the exponential-approach picture.
5. Spring force preview: $m\ddot x = -k_s x$ stated, solution deferred to day 3 deliberately ("the most important ODE in physics gets its own day").
6. Dimensional analysis as a checking tool: worked micro-example (check the range formula's dimensions); the habit statement.
- Misconception callouts (≥2): "no force means no motion" (vs. no *acceleration*); "heavier objects fall faster" (drag vs. vacuum, tie to the drag section).

*Worked examples:* (1) projectile launched at angle θ — derive time of flight, range, maximize over θ; (2) raindrop with linear drag — compute $v_{\mathrm{term}}$ and $\tau$ for given m, b, sketch $v(t)$; (3) block on incline with kinetic friction — set up and solve the ODE for $v(t)$.

*Exercises:* Retrieval: (1) state the three laws as one sentence + one equation each; (2) dimensional-check a given (slightly wrong) formula and find the error. Standard: (3) two-stage motion: constant thrust then drag-only coast; (4) Atwood machine acceleration from $F=ma$ on each mass. Stretch: (5) quadratic drag $m\dot v = -cv^2$: solve by separation, contrast $1/t$ decay with the linear-drag exponential.

*Connection to QM:* Schrödinger's equation plays the exact role $F=ma$ plays here — the dynamical rule you solve given the setup; "given the potential, find the motion" survives into QM as "given the potential, find the allowed states."

- [ ] **Step 2: Run the per-day verification checklist** (Global Constraints) against the file; fix anything failing before done.

---

### Task 3: Day 2 — Energy and Potential Wells

**Files:**
- Create: `content/day02.md`

**Interfaces:**
- Consumes: day 1's $m\ddot x = F$ framing.
- Produces: the V(x)-diagram reading skills (turning points, stable/unstable equilibria, bound vs. free motion) that days 3, 10, 16 quote; the relation $F=-dV/dx$.

- [ ] **Step 1: Draft `content/day02.md` (~3h day) with this content brief:**

*Learning objectives:* derive the work–energy theorem from Newton; define conservative forces and construct $V(x)$; read any $V(x)$ diagram fluently (turning points, equilibria, bound vs. free); use energy conservation as a solving tool that skips the ODE.

*Theory beats:*
1. Work–energy theorem derived: $\int F\,dx = \Delta(\tfrac12 mv^2)$ via chain rule $\ddot x = v\,dv/dx$.
2. Conservative forces; $V(x) = -\int F\,dx$; $F = -dV/dx$; gravity and spring potentials derived.
3. Energy conservation $E = K + V$ derived from Newton (differentiate, show $\dot E = 0$ for conservative $F$).
4. **The core skill:** reading $V(x)$ diagrams. Given an arbitrary bumpy $V(x)$ figure (describe it precisely in words + a simple ASCII/described figure): turning points where $E=V$; allowed/forbidden regions; stable equilibrium at minima ($V''>0$), unstable at maxima; bound motion between two turning points vs. free (escaping) motion. Walk through one figure at three different energies.
5. Small-oscillation preview: near a minimum, motion is oscillatory (full treatment day 3).
6. Escape velocity as an energy argument.
- Misconceptions: "energy is a substance stored in objects" (it's bookkeeping of one conserved number); "a particle at a turning point has zero force" (zero *velocity*; force is $-dV/dx \ne 0$).

*Worked examples:* (1) double-well $V(x)$ described concretely (e.g., $V(x) = x^4 - 2x^2$): classify the motion at $E=-0.5, 0, +1$ — turning points, bound-or-free, which well; (2) pendulum by energy: speed at bottom given release angle, no ODE; (3) escape velocity from Earth derived and computed.

*Exercises:* Retrieval: (1) derive $F=-dV/dx$ from the definition of $V$; (2) for $V(x)=\tfrac12 k_s x^2$, find turning points at energy $E$. Standard: (3) given $V(x)=x^3-3x$ find equilibria, classify stability, sketch motion at two energies; (4) ball rolling off a hemisphere — where does it leave? (energy + circular-motion condition). Stretch: (5) period of oscillation between turning points as the integral $T = 2\int_{x_1}^{x_2} dx/\sqrt{2(E-V)/m}$ — derive the formula, evaluate for the spring to recover day 3's answer in advance.

*Connection to QM:* the potential well IS the stage of every QM problem; bound states ↔ discrete energies, scattering states ↔ continuum; "classically forbidden region" gets its meaning from today's turning points — QM particles leak into it (tunneling, day 17).

- [ ] **Step 2: Run the per-day verification checklist**; fix failures.

---

### Task 4: Day 3 — The Harmonic Oscillator (deep) + sim

**Files:**
- Create: `content/day03.md`
- Create: `code/day03_oscillator_zoo.py`

**Interfaces:**
- Consumes: day 2's $V(x)$ minima and small-oscillation preview.
- Produces: SHM solution conventions $x(t)=A\cos(\omega_0 t+\phi)$, $\omega_0=\sqrt{k_s/m}$; the complex-exponential method $x = \mathrm{Re}[\tilde A e^{i\omega t}]$; the Taylor-expansion-around-a-minimum argument. Days 5, 10, 13, 17 all quote these.

- [ ] **Step 1: Draft `content/day03.md` (~3h day) with this content brief:**

*Learning objectives:* show any potential minimum yields SHM with $\omega_0=\sqrt{V''(x_0)/m}$; solve $\ddot x = -\omega_0^2 x$ completely and fluently, including via complex exponentials; describe energy sloshing $K\leftrightarrow V$; classify damped regimes; explain resonance and Q qualitatively and quantitatively.

*Theory beats:*
1. Universality: Taylor-expand $V$ about a minimum, drop the constant, kill the linear term (it's a minimum) → $V \approx \tfrac12 V''(x_0)(x-x_0)^2$ → every small oscillation is SHM. Box $\omega_0 = \sqrt{V''(x_0)/m}$.
2. Full solution of $\ddot x = -\omega_0^2 x$: general solution, amplitude/phase form, fixing constants from initial conditions.
3. The complex-exponential method: guess $e^{i\omega t}$, connect to the learner's linear-algebra/quantum background explicitly ("the same $e^{i\theta}$ machinery as qubit phases").
4. Energy: $E = \tfrac12 m\dot x^2 + \tfrac12 k_s x^2$ constant; K and V each oscillate at $2\omega_0$; average equality $\langle K\rangle = \langle V\rangle$.
5. Damping: $\ddot x + 2\beta\dot x + \omega_0^2 x = 0$ via the complex guess → under/critical/over-damped regimes from the discriminant.
6. Driving + resonance: steady-state amplitude $A(\omega_d)$ derived with complex exponentials; resonance peak near $\omega_0$; phase lag behavior (in phase far below, $90°$ at resonance, $180°$ far above); Q factor as ring-down count and as peak sharpness.
- Misconceptions: "resonance means the drive frequency equals $\omega_0$ exactly" (peak shifts with damping; and the $90°$ phase point is $\omega_0$); "damping always reduces amplitude gradually" (overdamped systems don't oscillate at all).

*Worked examples:* (1) $V(x) = V_0[(a/x) + (x/a)]$-style two-term potential (pick one cleanly differentiable): find minimum, compute $\omega_0$ via Taylor; (2) ring-down: given amplitude halves in N cycles, extract $\beta$ and Q; (3) driven oscillator: compute steady-state amplitude at three drive frequencies, locate the peak.

*Simulation section:* run `python3 code/day03_oscillator_zoo.py`; predict-prompts: "halve the damping — how much taller and narrower does the resonance peak get?", "set $\beta > \omega_0$ — predict the shape of $x(t)$ before looking", "double $k_s$ — which way does the resonance peak move?"

*Exercises:* Retrieval: (1) derive $\omega_0=\sqrt{V''/m}$ from Taylor expansion (closed book); (2) verify $x = A\cos\omega_0 t + B\sin\omega_0 t$ solves the SHM ODE and fix A, B from $x(0), \dot x(0)$. Standard: (3) mass between two springs (spring constants $k_1, k_2$) — find $\omega_0$ both in series and parallel arrangements; (4) pendulum period from Taylor-expanding its exact $V(\theta)=mgl(1-\cos\theta)$. Stretch: (5) derive the driven steady-state phase lag $\tan\delta = 2\beta\omega_d/(\omega_0^2-\omega_d^2)$ via complex exponentials and interpret its three regimes.

*Connection to QM:* the quantum harmonic oscillator (day 17) inherits everything: $\omega_0$ sets the level spacing $\hbar\omega_0$; photons are quanta of an EM field mode that IS this oscillator; the course's ladder-operator algebra is today's complex-exponential trick promoted to operators.

- [ ] **Step 2: Write `code/day03_oscillator_zoo.py`** per Global Constraints (numpy+matplotlib, ≤150 lines, Euler–Cromer, TWEAK header). Three panels: (a) undamped $x(t)$ with $K(t), V(t)$ overlaid to show sloshing; (b) $x(t)$ for the three damping regimes at fixed $\omega_0$ (β = 0.2ω₀, ω₀, 2ω₀); (c) steady-state amplitude vs. drive frequency sweep for 3 damping values (compute amplitude analytically from the derived formula — no need to integrate the driven case).

- [ ] **Step 3: Run `python3 code/day03_oscillator_zoo.py`** — expect: clean run, three panels, resonance peaks visibly taller/narrower for smaller β.

- [ ] **Step 4: Run the per-day verification checklist**; fix failures.

---

### Task 5: Day 4 — Momentum, Angular Momentum, Symmetry

**Files:**
- Create: `content/day04.md`

**Interfaces:**
- Consumes: days 1–2 (Newton, energy).
- Produces: the informal Noether statement (symmetry → conservation law) quoted by days 9 and 11; $\vec L = \vec r\times\vec p$ conserved under central forces.

- [ ] **Step 1: Draft `content/day04.md` (~3h day) with this content brief:**

*Learning objectives:* derive momentum conservation from Newton's third law; solve elastic/inelastic collisions; define $\vec L=\vec r\times\vec p$ and show central forces conserve it; state the symmetry↔conservation dictionary informally; survey rotation and orbits at concept level.

*Theory beats:*
1. Momentum conservation derived from N2+N3 for a two-body system; generalization stated.
2. Collisions: perfectly inelastic (momentum only) and elastic (momentum + energy) in 1D; the center-of-mass frame trick.
3. Angular momentum: $\vec L=\vec r\times\vec p$; $d\vec L/dt = \vec\tau$; central force ⇒ $\vec\tau=0$ ⇒ $\vec L$ conserved; equal-areas (Kepler's 2nd) as a one-line consequence.
4. The symmetry dictionary (informal Noether): space-translation symmetry → momentum; rotation symmetry → angular momentum; time-translation symmetry → energy. Frame as "why these three quantities and not others."
5. *Consolidation survey* (labeled as such, paragraph depth each): rigid-body rotation ($I$, $L=I\omega$, $K=\tfrac12 I\omega^2$, no derivations); gravity and orbits (Kepler's laws stated, circular-orbit speed derived in 3 lines).
- Misconceptions: "momentum and kinetic energy are interchangeable bookkeeping" (inelastic collisions conserve one, not the other); "angular momentum needs circular motion" (a straight-moving free particle has constant $\vec L$ about any point).

*Worked examples:* (1) 1D elastic collision, general masses — derive final velocities, check equal-mass swap limit; (2) skater pulling arms in: $I\omega$ conservation with numbers, where the kinetic-energy increase comes from; (3) comet at perihelion vs. aphelion via $L$ conservation.

*Exercises:* Retrieval: (1) derive two-body momentum conservation from N3; (2) show central force ⇒ $dL/dt=0$. Standard: (3) ballistic pendulum (inelastic collision + energy sweep-up, flags which conservation law applies in which phase); (4) circular orbit: derive $v(r)$ and the period–radius relation. Stretch: (5) reduce the two-body problem to one body with reduced mass $\mu = m_1m_2/(m_1+m_2)$ — derive, then explain in one paragraph why this matters for the hydrogen atom (day 14).

*Connection to QM:* conserved quantities become operators commuting with $\hat H$; the symmetry dictionary survives verbatim; angular momentum will be *quantized* — and the reduced-mass trick is exactly how the hydrogen atom becomes a one-body problem in the course.

- [ ] **Step 2: Run the per-day verification checklist**; fix failures.

---

### Task 6: Day 5 — From Oscillators to Waves

**Files:**
- Create: `content/day05.md`

**Interfaces:**
- Consumes: day 3's SHM machinery (normal-mode language builds on it).
- Produces: the wave equation $\partial_t^2 y = v^2\partial_x^2 y$; sinusoidal-wave conventions $y = A\cos(kx-\omega t)$ with $k=2\pi/\lambda$, $\omega=2\pi f$, $v_{\mathrm{ph}}=\omega/k$; dispersion-relation concept. Days 6, 7, 8, 16 quote all of these.

- [ ] **Step 1: Draft `content/day05.md` (~3.5h day) with this content brief:*

*Learning objectives:* derive the wave equation for a string from Newton on a mass element; verify $f(x\pm vt)$ solves it; work fluently with $k, \omega, \lambda, f, v_{\mathrm{ph}}$; find normal modes of two coupled oscillators; state what a dispersion relation is.

*Theory beats:*
1. Two coupled oscillators: solve for normal modes (symmetric/antisymmetric) via ansatz or symmetry; the moral "N coupled oscillators have N modes; each mode is one big SHM."
2. Continuum limit: string under tension, Newton on an element → $\partial_t^2 y = (T_s/\mu)\,\partial_x^2 y$ (use $T_s$ for tension to avoid the kinetic-energy $T$ collision — state this).
3. General solution $f(x-vt)+g(x+vt)$; verify by chain rule.
4. Sinusoidal waves: definitions of $k, \omega$; phase velocity $v_{\mathrm{ph}} = \omega/k$; the traveling-phase picture.
5. Dispersion relations: for the ideal string $\omega = vk$ (non-dispersive); the *idea* that other systems give $\omega(k)$ nonlinear, and that this will matter enormously (day 7's group velocity, day 16's matter waves).
6. Energy transport in a wave (result + intuition; brief derivation for the string's power).
- Misconceptions: "the medium travels with the wave" (the wave pattern moves; elements oscillate in place); "wave speed depends on how hard you shake" (it's a property of the medium: $\sqrt{T_s/\mu}$).

*Worked examples:* (1) verify $y=f(x-vt)$ solves the wave equation via chain rule, explicitly; (2) guitar string numbers: given $T_s, \mu, L$, compute wave speed and fundamental frequency (uses standing-wave $\lambda=2L$ informally, formalized day 6); (3) two coupled pendulums: find both mode frequencies.

*Exercises:* Retrieval: (1) derive the string wave equation from Newton on an element (closed book); (2) for $y = 0.02\cos(4\pi x - 200\pi t)$ (SI), extract $\lambda, f, v_{\mathrm{ph}}$, direction. Standard: (3) same pulse on two joined strings of different $\mu$ — what changes across the joint ($f$ fixed, $\lambda$ and $v$ change); (4) three coupled masses: write the equations of motion and verify the given middle mode. Stretch: (5) given the dispersion relation $\omega = \sqrt{gk}$ (deep-water waves), compute $v_{\mathrm{ph}}(k)$ and observe longer waves travel faster — one paragraph on why this makes wave *packets* interesting (sets up day 7).

*Connection to QM:* the Schrödinger equation is a wave equation for matter with a *different* dispersion relation ($\omega \propto k^2$) — first-order in time, and that difference is why quantum wave packets spread; "each mode is one big SHM" returns as "each field mode is one quantum oscillator."

- [ ] **Step 2: Run the per-day verification checklist**; fix failures.

---

### Task 7: Day 6 — Superposition, Standing Waves, Interferometers + sim

**Files:**
- Create: `content/day06.md`
- Create: `code/day06_interference_standing_waves.py`

**Interfaces:**
- Consumes: day 5's sinusoidal-wave conventions.
- Produces: path-difference interference condition; standing-wave quantization $f_n = nv/2L$; Mach–Zehnder output laws $I_1 \propto \cos^2(\phi/2)$, $I_2 \propto \sin^2(\phi/2)$. Days 15, 16, 18 quote these directly (day 18 re-reads the MZ as a qubit circuit).

- [ ] **Step 1: Draft `content/day06.md` (~3.5h day) with this content brief:**

*Learning objectives:* apply superposition to compute interference from path difference; derive beats; derive standing waves and the discrete mode spectrum from boundary conditions; compute both output intensities of a Mach–Zehnder interferometer as a function of arm phase.

*Theory beats:*
1. Linearity of the wave equation ⇒ superposition; this is a *theorem about the equation*, not an extra assumption.
2. Two-source interference: path difference → phase difference $\delta = k\Delta L$; constructive/destructive conditions; two-slit maxima positions derived; phasor-addition picture.
3. Beats: $\cos\omega_1 t + \cos\omega_2 t$ → envelope at $(\omega_1-\omega_2)/2$; beat frequency.
4. Standing waves: counter-propagating equal waves → $y = 2A\sin(kx)\cos(\omega t)$; nodes/antinodes; fixed-end boundary conditions → $k_n = n\pi/L$, $f_n = nv/2L$. **Box and flag:** "boundary conditions turn a continuum of waves into a discrete list of modes — remember this sentence; it is the entire origin story of quantization."
5. Interferometers: Michelson layout and output vs. mirror displacement; then Mach–Zehnder carefully — beam splitter conventions (50/50, with the $\pi$ phase shift on one reflection stated as the convention that keeps energy conserved), two paths, recombination; derive $I_1 \propto \cos^2(\phi/2)$ and $I_2\propto\sin^2(\phi/2)$; note the outputs are complementary (energy conservation check).
- Misconceptions: "destructive interference destroys energy" (it redistributes it — the other MZ port brightens); "standing waves transport energy" (they don't; they're trapped modes).

*Worked examples:* (1) two-slit: given $\lambda, d, L$ compute fringe spacing; (2) string fixed at both ends: full harmonic series for given $v, L$, sketch first three modes; (3) MZ with a glass sample (thickness $t$, index $n$) in one arm: compute $\phi$ and both output intensities.

*Simulation section:* run `python3 code/day06_interference_standing_waves.py`; predict-prompts: "move the sources closer together — do the fringes get wider or narrower?", "detune the beat frequencies further apart — what happens to the envelope?", "in the MZ panel, find the phase where BOTH ports are equal — what fraction is each?"

*Exercises:* Retrieval: (1) derive the standing-wave form from two counter-propagating waves (sum-to-product identity); (2) derive $f_n = nv/2L$ from fixed-end boundary conditions. Standard: (3) beats: two tuning forks numbers → beat frequency, and which is sharper given one is loaded; (4) pipe open at one end: derive the odd-harmonics-only spectrum (different boundary condition — same method). Stretch: (5) MZ interferometry: derive both output intensities from the beam-splitter convention step by step, verify $I_1 + I_2 = I_0$ at every phase, and answer "where did the light go at $\phi=\pi$?"

*Connection to QM:* your course will send *single photons* through the Mach–Zehnder and get the same $\cos^2$/$\sin^2$ laws as *probabilities* — today's amplitudes become probability amplitudes; and the boxed boundary-condition sentence is exactly how the particle-in-a-box (day 16) gets discrete energies.

- [ ] **Step 2: Write `code/day06_interference_standing_waves.py`** per Global Constraints. Three panels, all analytic (no integration): (a) two-source interference intensity pattern on a screen vs. position for adjustable source separation; (b) beats: $y(t)$ sum of two nearby frequencies with envelope overlaid; (c) Mach–Zehnder: $I_1, I_2$ vs. $\phi \in [0, 4\pi]$ showing complementarity, plus their sum as a flat line.

- [ ] **Step 3: Run `python3 code/day06_interference_standing_waves.py`** — expect clean run, three panels, MZ curves summing to a constant.

- [ ] **Step 4: Run the per-day verification checklist**; fix failures.

---

### Task 8: Day 7 — Fourier Intuition and Wave Packets + sim

**Files:**
- Create: `content/day07.md`
- Create: `code/day07_wave_packet_builder.py`

**Interfaces:**
- Consumes: day 5's dispersion relation; day 6's superposition.
- Produces: group velocity $v_g = d\omega/dk$; the bandwidth theorem $\Delta x\,\Delta k \gtrsim 1$ with the Gaussian equality case $\Delta x\,\Delta k = \tfrac12$. Day 17 converts these verbatim into $\Delta x\,\Delta p \ge \hbar/2$.

- [ ] **Step 1: Draft `content/day07.md` (~3.5h day) with this content brief:**

*Learning objectives:* decompose a periodic shape into harmonics (concept + one real computation); explain the Fourier transform as the continuum limit; build a wave packet from a band of $k$'s; derive $v_g = d\omega/dk$; state and use $\Delta x\,\Delta k\gtrsim1$.

*Theory beats:*
1. Fourier series conceptually: the string's modes (day 6) are a basis; any shape on the string = sum of modes. Explicit connection to the learner's linear algebra: "this is expansion in an orthogonal basis, with $\int \sin(k_nx)\sin(k_mx)dx$ as the inner product."
2. One honest computation: square-wave Fourier coefficients ($b_n = 4/n\pi$ for odd $n$), showing the $1/n$ falloff and Gibbs wiggle in words.
3. Fourier transform as continuum limit: sum over discrete $k_n$ → integral over $k$; $\psi(x) = \int A(k)e^{ikx}dk$ at the intuition level (no rigor, no convergence theory — say so).
4. Wave packets: narrow Gaussian band $A(k)$ around $k_0$ → localized packet; carrier vs. envelope.
5. Group velocity derived from the two-wave beat (day 6's beats revisited): envelope moves at $\Delta\omega/\Delta k \to d\omega/dk$; contrast $v_g$ vs $v_{\mathrm{ph}}$ for $\omega=\sqrt{gk}$ ($v_g = v_{\mathrm{ph}}/2$).
6. The bandwidth theorem: narrow in $x$ ⇔ wide in $k$; Gaussian case computed ($\Delta x\,\Delta k = 1/2$); everyday instances (short sound click has no pitch; short radar pulse has broad spectrum). **Box:** "this is a fact about waves, not about quantum mechanics."
7. Dispersion spreading: if $\omega(k)$ is nonlinear, different $k$'s travel at different speeds → packets spread.
- Misconceptions: "the uncertainty principle is quantum weirdness" (it's the boxed classical wave fact, plus $p=\hbar k$); "group velocity is always less than phase velocity" (depends on the dispersion relation).

*Worked examples:* (1) square-wave coefficients computed; (2) $\omega=\sqrt{gk}$: compute $v_g/v_{\mathrm{ph}}$; (3) Gaussian packet: given $\Delta k$, compute $\Delta x$ and interpret.

*Simulation section:* run `python3 code/day07_wave_packet_builder.py`; predict-prompts: "double the k-bandwidth — does the packet get wider or narrower?", "add dispersion — which part of the packet outruns which?", "reduce to 3 modes — what does the 'packet' look like now?"

*Exercises:* Retrieval: (1) derive $v_g = d\omega/dk$ from two superposed nearby-frequency waves; (2) state the bandwidth theorem and give one non-quantum example not in the text. Standard: (3) for $\omega = \alpha k^2$ (foreshadowing matter waves — label it as such), compute $v_g$ and show $v_g = 2v_{\mathrm{ph}}$; (4) a 1 μs radar pulse: estimate its frequency bandwidth. Stretch: (5) triangle-wave Fourier coefficients; compare falloff rate with the square wave and connect smoothness ↔ high-$k$ content.

*Connection to QM:* multiply today by $\hbar$: $p = \hbar k$, $E=\hbar\omega$, and $\Delta x\,\Delta k \gtrsim 1$ becomes Heisenberg's $\Delta x\,\Delta p \gtrsim \hbar$; a particle IS a wave packet, its velocity is $v_g$, and exercise (3)'s dispersion relation is literally the free Schrödinger equation's.

- [ ] **Step 2: Write `code/day07_wave_packet_builder.py`** per Global Constraints. Panels: (a) partial sums of the square-wave series (N = 1, 3, 9, 33 terms overlaid); (b) wave packet built as $\sum_n A(k_n)\cos(k_n x)$ with Gaussian weights, shown for two bandwidths (narrow → wide packet, wide → narrow packet), with $\Delta x \cdot \Delta k$ annotated; (c) packet snapshots at 3 times with quadratic dispersion $\omega = \alpha k^2$ showing spreading (evaluate the sum at each $t$ with $\cos(k_nx - \omega_nt)$ — pure numpy, no integrator).

- [ ] **Step 3: Run `python3 code/day07_wave_packet_builder.py`** — expect clean run; wider $k$-band gives visibly narrower packet; dispersion panel shows spreading.

- [ ] **Step 4: Run the per-day verification checklist**; fix failures.

---

### Task 9: Day 8 — Light and Polarization as a Two-State System

**Files:**
- Create: `content/day08.md`

**Interfaces:**
- Consumes: day 5's wave equation, day 6's superposition.
- Produces: Jones-vector conventions — $|H\rangle = \binom{1}{0}$, $|V\rangle=\binom{0}{1}$, diagonal $\tfrac{1}{\sqrt2}\binom{1}{1}$, circular $\tfrac{1}{\sqrt2}\binom{1}{\pm i}$ — and Malus's law $I = I_0\cos^2\theta$. Day 18 builds the polarization qubit from exactly these.

- [ ] **Step 1: Draft `content/day08.md` (~3.5h day) with this content brief:**

*Learning objectives:* say what each Maxwell equation means physically; describe an EM wave's anatomy and why $c$ is forced; compute with Jones vectors; derive Malus's law; explain wave plates' action on polarization states.

*Theory beats:*
1. Fields as physical objects: $\vec E$ and $\vec B$ defined by the force law $\vec F = q(\vec E + \vec v\times\vec B)$; fields carry energy and momentum.
2. The four Maxwell equations, each in one sentence of physics (what it says, what it forbids): Gauss (charges source E), no monopoles, Faraday (changing B makes E), Ampère–Maxwell (currents and changing E make B). NO PDE manipulation — state that the wave solution follows from combining the last two, and quote $c = 1/\sqrt{\mu_0\varepsilon_0}$ with the numerical punchline (compute it: it equals the measured speed of light — "light is an electromagnetic wave" was a *calculation* before it was a doctrine).
3. EM wave anatomy: $\vec E \perp \vec B \perp \vec k$, in phase, $|E|=c|B|$; intensity $\propto E_0^2$.
4. Polarization as the direction of $\vec E$: linear, and then circular as two linears $90°$ out of phase.
5. **Jones vectors:** polarization state = normalized 2-component complex vector; the four standard states listed above; polarizer as a projection; general rotation. Make the punchline explicit: "polarization is a 2-dimensional complex vector space — the same arena as the qubit you met in the quantum computing path."
6. Malus's law derived as projection-then-square: $I = I_0\cos^2\theta$.
7. Wave plates conceptually: birefringence delays one component; quarter-wave plate turns diagonal into circular (show it with Jones vectors — one line).
8. *Consolidation survey* (labeled, one paragraph each): DC circuits (what V, I, R are and Kirchhoff in words); geometric optics (rays, lenses, images — why we skip it: QM needs wave optics, not ray optics).
- Misconceptions: "polarizers act as sieves passing aligned light unchanged" (they *project*: transmitted light is re-aligned to the polarizer axis — this is why the three-polarizer puzzle works); "circular polarization is a mixture of H and V" (it's a coherent superposition with a definite phase — mixture vs. superposition, flagged as a preview of a central course distinction).

*Worked examples:* (1) the three-polarizer puzzle: $0°$ then $90°$ blocks all; insert $45°$ between them → $I_0/8$ passes — computed via successive Malus projections; (2) quarter-wave plate on diagonal input: Jones-vector computation ending in circular; (3) laser-pointer photon flux: 1 mW at 650 nm → photons/second (uses $E=hf$ with a forward flag to day 13; label as an estimate).

*Exercises:* Retrieval: (1) match each Maxwell equation to its one-sentence meaning, closed book; (2) verify the circular Jones vector is normalized and orthogonal to the opposite circular. Standard: (3) Malus cascade: N polarizers each rotated $90°/N$ — transmitted fraction, and its $N\to\infty$ limit; (4) decompose diagonal polarization in the H/V basis and in the ±45° basis. Stretch: (5) show that ANY normalized Jones vector can be written as $\alpha|H\rangle + \beta|V\rangle$ with $|\alpha|^2+|\beta|^2=1$, and explain in one paragraph why the global phase of the vector has no physical meaning for intensity measurements.

*Connection to QM:* Malus's law IS the Born rule for the polarization qubit ($\cos^2\theta$ = transition probability); the three-polarizer puzzle is your first non-commuting-measurements phenomenon; wave plates are single-qubit unitaries you can hold in your hand. Your course's photonics experiments live in exactly this formalism.

- [ ] **Step 2: Run the per-day verification checklist**; fix failures.

---

### Task 10: Day 9 — Action and the Lagrangian

**Files:**
- Create: `content/day09.md`

**Interfaces:**
- Consumes: day 1's ODE framing, day 3's oscillator, day 4's Noether-informal.
- Produces: Euler–Lagrange equation $\frac{d}{dt}\frac{\partial L}{\partial\dot q} = \frac{\partial L}{\partial q}$ with $L = T - V$; generalized-coordinate methodology. Day 10 consumes $p = \partial L/\partial\dot q$.

- [ ] **Step 1: Draft `content/day09.md` (~3.5h day) with this content brief:**

*Learning objectives:* state the principle of least action; derive Euler–Lagrange from stationarity (once, carefully); apply it to free particle, oscillator, pendulum; exploit generalized coordinates on a constrained system; connect symmetry of $L$ to conservation (Noether made semi-precise).

*Theory beats:*
1. Why reformulate: forces are clumsy with constraints; a scalar ($L$) beats vectors; and this road leads to QM. State $T$ = kinetic energy for days 9–11, tension/periods renamed accordingly (notation flag per Global Constraints).
2. The action $S[q] = \int_{t_1}^{t_2} L(q,\dot q)\,dt$ as a number assigned to each *path*; "nature picks the path making $S$ stationary."
3. Euler–Lagrange derived via the standard variation $q\to q+\epsilon\eta$, integration by parts, endpoints fixed — done slowly, every step shown; this is the day's one hard derivation.
4. $L = T - V$ justified by recovering Newton: E–L on $L = \tfrac12 m\dot x^2 - V(x)$ gives $m\ddot x = -dV/dx$. (State honestly: $T-V$ is justified by its consequences.)
5. Three applications in increasing slickness: free particle (straight line), harmonic oscillator (recover day 3), pendulum in $\theta$ — the exact equation $\ddot\theta = -(g/l)\sin\theta$ with zero force-decomposition.
6. Generalized coordinates: bead on a rotating/shaped wire or block-on-movable-incline — pick ONE and do it fully; the moral "choose coordinates that make constraints invisible."
7. Noether semi-precise: if $L$ doesn't depend on $q$ ($q$ cyclic), then $\partial L/\partial\dot q$ is conserved — prove in two lines from E–L; connect back to day 4's dictionary.
- Misconceptions: "nature minimizes the action" (stationary, not always minimal); "the Lagrangian is the energy" ($T-V$, not $T+V$ — and the difference is the whole point of day 10's Legendre transform).

*Worked examples:* (1) pendulum via E–L start to finish; (2) Atwood machine via one generalized coordinate; (3) block sliding on a frictionless movable wedge (two coordinates, the classic).

*Exercises:* Retrieval: (1) derive E–L closed book (the day's core retrieval act); (2) show a cyclic coordinate's conjugate momentum is conserved. Standard: (3) bead on a vertical circular hoop rotating about its diameter at $\Omega$: find the E–L equation and equilibrium angles; (4) projectile via E–L in $x, y$ simultaneously. Stretch: (5) write the double-pendulum Lagrangian (set up only, no solving) and count how much force-based bookkeeping this avoided.

*Connection to QM:* Feynman's path-integral formulation says the quantum particle takes ALL paths, each weighted by $e^{iS/\hbar}$; classical mechanics is the stationary-phase limit. Even before path integrals, tomorrow's Hamiltonian — the object your entire course revolves around — is built directly from today's $L$.

- [ ] **Step 2: Run the per-day verification checklist**; fix failures.

---

### Task 11: Day 10 — The Hamiltonian + sim

**Files:**
- Create: `content/day10.md`
- Create: `code/day10_phase_space.py`

**Interfaces:**
- Consumes: day 9's $L$ and $p=\partial L/\partial\dot q$.
- Produces: $H(q,p)$, Hamilton's equations $\dot q = \partial H/\partial p$, $\dot p = -\partial H/\partial q$; phase-space portrait reading (oscillator ellipses, pendulum separatrix). Days 11, 16 consume $H$; day 11 consumes phase-space functions $f(q,p)$.

- [ ] **Step 1: Draft `content/day10.md` (~3.5h day) with this content brief:**

*Learning objectives:* construct $H$ from $L$ via the Legendre transform; derive and use Hamilton's equations; identify when $H = T+V$; read phase-space portraits fluently (closed orbits, separatrix, fixed points).

*Theory beats:*
1. Motivation: trade $(q,\dot q)$ for $(q,p)$ — two first-order equations instead of one second-order; and "the object that generates time evolution" is what QM will quantize.
2. Legendre transform gently: geometric picture (describing a convex function by its tangent lines), then the recipe $H(q,p) = p\dot q - L$ with $\dot q$ eliminated via $p = \partial L/\partial\dot q$. One fully-worked scalar example before any mechanics.
3. Hamilton's equations derived from $dH$; symmetry of the pair; check on the oscillator: $H = p^2/2m + \tfrac12 k_s q^2$ → recover SHM.
4. When $H = T + V$: yes for natural systems with time-independent constraints; one-sentence caution (rotating frames break it) without a full treatment.
5. Phase space: state $(q,p)$ as a point; motion as a flow. Oscillator → nested ellipses (area ↔ energy); pendulum → the full portrait: libration ovals, rotation bands, the separatrix through the unstable equilibrium, and what the separatrix *means* (infinite-period boundary).
6. Liouville teaser, one paragraph: Hamiltonian flow preserves phase-space area; why this makes phase space the natural home of statistical mechanics (used day 12).
- Misconceptions: "$H$ is always the energy" (usually, with stated conditions — but it's *defined* by the transform, not by being $T+V$); "phase-space trajectories can cross" (they can't — determinism; crossing would mean two futures from one state).

*Worked examples:* (1) full Legendre-transform construction of $H$ for the oscillator + Hamilton's equations solved; (2) pendulum $H(\theta, p_\theta)$: compute the separatrix energy, classify motion above/below it; (3) particle in gravity: $H$, equations, phase portrait (parabolic flow).

*Simulation section:* run `python3 code/day10_phase_space.py`; predict-prompts: "pick an energy just above the separatrix — describe the trajectory before running", "double the pendulum length — which features of the portrait move and which are unchanged?", "why do no two streamlines ever cross?"

*Exercises:* Retrieval: (1) derive Hamilton's equations from $H = p\dot q - L$ closed book; (2) construct $H$ for $L = \tfrac12 m\dot x^2 - \tfrac12 k_s x^2$ and verify Hamilton's equations reproduce SHM. Standard: (3) $H$ for a bead on a parabolic wire $y = ax^2$ (Legendre transform with a position-dependent mass term); (4) sketch (described in words/coordinates) the phase portrait of $V(x) = x^4 - 2x^2$ from day 2 — including the figure-eight separatrix. Stretch: (5) relativistic-flavored $L = -mc^2\sqrt{1-\dot x^2/c^2}$: compute $p$, then $H$, and recognize $H = \sqrt{p^2c^2 + m^2c^4}$ (flag: this expression returns in day 14's Compton discussion).

*Connection to QM:* the course's fundamental equation is $i\hbar\,\partial_t|\psi\rangle = \hat H|\psi\rangle$ — today's $H$ with hats on. Writing $H = p^2/2m + V$ and promoting $p \to -i\hbar\,\partial_x$ is literally how day 16 builds the Schrödinger equation. Energy eigenstates, level spacings, time evolution: all properties of $\hat H$.

- [ ] **Step 2: Write `code/day10_phase_space.py`** per Global Constraints. Two panels: (a) oscillator phase portrait — streamplot or quiver of $(\dot q, \dot p)$ field plus 4 nested energy ellipses drawn analytically; (b) pendulum phase portrait — contour plot of $H(\theta,p_\theta)$ over $\theta\in[-2\pi,2\pi]$ with the separatrix contour highlighted in a distinct color/width, libration and rotation contours labeled via title/legend.

- [ ] **Step 3: Run `python3 code/day10_phase_space.py`** — expect clean run, separatrix visibly distinct, no trajectory crossings.

- [ ] **Step 4: Run the per-day verification checklist**; fix failures.

---

### Task 12: Day 11 — Poisson Brackets and the Quantum Preview

**Files:**
- Create: `content/day11.md`

**Interfaces:**
- Consumes: day 10's $H$ and phase-space functions.
- Produces: $\{f,g\}$ definition; $\dot f = \{f,H\}$; canonical bracket $\{q,p\}=1$; the quantization dictionary table $\{,\}\to\frac{1}{i\hbar}[,]$. Day 18's Rosetta Stone reprints this table.

- [ ] **Step 1: Draft `content/day11.md` (~3.5h day) with this content brief:**

*Learning objectives:* compute Poisson brackets; show $\dot f = \{f,H\}$; verify $\{q,p\}=1$; use vanishing brackets to identify conserved quantities; state the canonical-quantization dictionary and why commutators are then *natural*.

Written-to-be-re-read note: open the file with an italic line — "*Read this day twice: once now, once after week 2 of your course, when commutators have appeared. It is designed to be better the second time.*"

*Theory beats:*
1. Definition $\{f,g\} = \frac{\partial f}{\partial q}\frac{\partial g}{\partial p} - \frac{\partial f}{\partial p}\frac{\partial g}{\partial q}$; algebraic properties (antisymmetry, linearity, product rule) verified quickly.
2. The master equation: $\frac{df}{dt} = \{f,H\}$ derived in four lines from Hamilton's equations. "One bracket to rule all time evolution."
3. Conservation: $f$ conserved ⇔ $\{f,H\}=0$; redo day 4's results in this language (momentum conserved when $H$ is translation-invariant, etc.).
4. Canonical brackets: $\{q,p\}=1$, $\{q,q\}=\{p,p\}=0$ — "the multiplication table of mechanics."
5. The dictionary, presented as a two-column table (classical | quantum): $f(q,p)$ | operator $\hat f$; $\{f,g\}$ | $\frac{1}{i\hbar}[\hat f,\hat g]$; $\{q,p\}=1$ | $[\hat q,\hat p]=i\hbar$; $\dot f=\{f,H\}$ | Heisenberg equation $\frac{d\hat f}{dt} = \frac{1}{i\hbar}[\hat f,\hat H]$; conserved ⇔ bracket with $H$ vanishes | conserved ⇔ commutes with $\hat H$. Frame honestly: this is a *pattern that quantization follows*, not a derivation of QM.
6. Why commutators are then natural, not weird: QM keeps the entire algebraic structure of mechanics and changes only what the bracket *is*. The non-commutativity $[\hat q,\hat p]\ne0$ is the mathematical seat of the uncertainty principle (day 17 closes this loop).
7. Two-level truncation idea in one paragraph: keep only two energy states of any system → every observable becomes a $2\times2$ matrix → the qubit; this is why your quantum computing path's $2\times2$ matrices describe real atoms (day 14, day 18).
- Misconceptions: "Poisson brackets are just notation" (they're coordinate-independent structure — the *same* bracket in any canonical coordinates); "QM replaces classical mechanics' equations" (it replaces the bracket and keeps the equations' shape).

*Worked examples:* (1) verify $\{q,p\}=1$ and compute $\{q,H\}, \{p,H\}$ for the oscillator, recovering Hamilton's equations; (2) central force in 2D: show $\{L_z, H\}=0$ by direct computation; (3) oscillator time evolution of $q$ via iterated brackets → recover $\cos\omega_0 t$ series (first three terms, then recognize the series).

*Exercises:* Retrieval: (1) derive $\dot f = \{f,H\}$ from Hamilton's equations, closed book; (2) verify antisymmetry and the product rule from the definition. Standard: (3) compute $\{L_z, x\}, \{L_z, y\}, \{L_z, p_x\}$ and interpret (rotations rotate things); (4) free particle: show $p$ and $H$ conserved, and $x - pt/m$ conserved too — interpret it. Stretch: (5) take the quantization dictionary at its word: from $[\hat q,\hat p]=i\hbar$, compute $[\hat q,\hat p^2]$ using only the algebra ($[A,BC]=[A,B]C+B[A,C]$), and check it matches $i\hbar\,\{q,p^2\}_{PB}$ computed classically.

*Connection to QM:* this day IS the connection; close instead with a half-page "what to re-derive after course week 2" list: the master equation, the dictionary table, exercise 5.

- [ ] **Step 2: Run the per-day verification checklist**; fix failures (including the re-read italic line).

---

### Task 13: Day 12 — Minimal Thermal Physics

**Files:**
- Create: `content/day12.md`

**Interfaces:**
- Consumes: day 3's oscillator (equipartition applied to it), day 10's phase-space teaser.
- Produces: Boltzmann factor $e^{-E/k_BT}$; partition-function average $\langle E\rangle = \sum E_i e^{-E_i/k_BT}/\sum e^{-E_i/k_BT}$; equipartition ($\tfrac12 k_BT$ per quadratic term). Day 13's Planck derivation consumes all three directly.

- [ ] **Step 1: Draft `content/day12.md` (~3.5h day) with this content brief:**

*Learning objectives:* explain temperature as a statement about average energy; motivate and use the Boltzmann factor; compute thermal averages from a partition function for discrete levels; state and apply equipartition; predict where equipartition must fail.

*Theory beats:*
1. Framing: "this day exists to make day 13's blackbody derivation honest — it is the minimum thermal physics a QM course assumes, no more."
2. Temperature operationally; $k_BT$ as the thermal energy scale; numbers ($k_BT \approx 1/40$ eV at room temperature — an anchor value used repeatedly in days 13–15).
3. Boltzmann factor motivated by the small-system-plus-reservoir argument (lightweight version: reservoir entropy/state-counting told in words and one exponential step — flag the full derivation as stat-mech-course material); result: $P(E_i)\propto e^{-E_i/k_BT}$.
4. Partition function $Z = \sum_i e^{-E_i/k_BT}$; averages $\langle E\rangle = \sum_i E_i P(E_i)$; the two-level system fully worked as the running example (populations vs. $T$, saturation at high $T$, freeze-out at low $T$).
5. Equipartition: each quadratic degree of freedom carries $\langle E\rangle = \tfrac12 k_BT$ — derived for one quadratic term via the Gaussian integral (state the integral result; don't develop integral tables); classical oscillator gets $k_BT$ total (two quadratic terms).
6. Where it must fail: equipartition is temperature-independent per mode — if a system has infinitely many modes, classical physics predicts infinite energy. One paragraph, deliberately ominous: "hold this thought for exactly one day."
7. *Consolidation survey* (labeled): entropy in two paragraphs (state-counting flavor); the laws of thermodynamics in four sentences.
- Misconceptions: "temperature measures total energy" (average per mode, not total; a spark vs. a bathtub); "at temperature T every particle has energy $k_BT$" (it's a distribution — some far above, most below).

*Worked examples:* (1) two-level system, gap $\Delta$: populations at $k_BT = 0.1\Delta, \Delta, 10\Delta$; (2) classical oscillator average energy via equipartition = $k_BT$; (3) RMS speed of a nitrogen molecule at room temperature.

*Exercises:* Retrieval: (1) write the Boltzmann factor and compute the ratio of populations for a given gap and temperature; (2) state equipartition and count quadratic terms for a 3D ideal-gas atom. Standard: (3) three-level system: compute $Z$ and $\langle E\rangle$ at one temperature; (4) diatomic molecule heat-capacity puzzle: count modes (translation, rotation, vibration), note the experimental "freeze-out" and flag it as quantum. Stretch: (5) for the two-level system derive $\langle E\rangle(T)$ in closed form and show it saturates at $\Delta/2$ as $T\to\infty$; explain in one paragraph why a classical continuum of levels would never saturate (this is the exact mathematical move Planck makes tomorrow).

*Connection to QM:* Planck's blackbody fix (tomorrow) is nothing but today's discrete-level average applied to light; freeze-out (exercises 4–5) is quantization visible in 1900-era data; and the two-level thermal system returns in your course as the maximally mixed qubit state.

- [ ] **Step 2: Run the per-day verification checklist**; fix failures.

---

### Task 14: Day 13 — Blackbody Radiation and the Photon + sim

**Files:**
- Create: `content/day13.md`
- Create: `code/day13_blackbody_curves.py`

**Interfaces:**
- Consumes: day 6's standing-wave mode counting ($f_n = nv/2L$), day 12's Boltzmann/partition machinery and equipartition.
- Produces: Planck's law and the quantized-oscillator average $\langle E\rangle = hf/(e^{hf/k_BT}-1)$; the photon $E=hf$; work function/stopping potential. Days 14, 15 consume $E=hf$ everywhere.

- [ ] **Step 1: Draft `content/day13.md` (~3.5h day) with this content brief:**

*Learning objectives:* count cavity modes (1D honestly, 3D by stated scaling); derive Rayleigh–Jeans and articulate the ultraviolet catastrophe; redo the average with $E_n = nhf$ to get Planck's law; extract Wien and Stefan–Boltzmann as consequences; analyze the photoelectric effect classically vs. with photons.

*Theory beats:*
1. Setup: a hot cavity's radiation spectrum as THE 1900 problem; blackbody = perfect absorber, universal spectrum.
2. Mode counting: 1D cavity modes from day 6's $f_n = nv/2L$ — count modes below $f$ honestly; state the 3D result $dN/df \propto f^2$ with the geometric reasoning sketched (shell in $n$-space, factor 2 for polarization — cite day 8) but not belabored.
3. Rayleigh–Jeans: (modes per frequency) × (equipartition $k_BT$ per mode) → $u(f) \propto f^2 k_BT$ → integral diverges. The ultraviolet catastrophe stated plainly: classical physics predicts infinite energy in every warm box; day 12's ominous paragraph cashed in.
4. **Planck's move — the day's centerpiece, fully derived:** allow each mode only $E_n = nhf$; compute $\langle E\rangle$ with day 12's partition sum (geometric series, done completely) → $\langle E\rangle = hf/(e^{hf/k_BT}-1)$; low-$f$ limit recovers $k_BT$ (Taylor expand — classical physics survives where it worked); high-$f$ modes freeze out → spectrum peaks and dies. Assemble Planck's law.
5. Consequences: Wien displacement (state $\lambda_{\max}T = b$, derive the origin as maximizing Planck's law — set up the transcendental equation, quote its numerical root); Stefan–Boltzmann $\propto T^4$ (state, with the integral's origin indicated).
6. Photoelectric effect: the experimental facts table (threshold frequency, instantaneous emission, intensity raises current not energy); what the classical wave picture predicts for each (wrong on all three); Einstein: light arrives as quanta $E = hf$; $eV_{\mathrm{stop}} = hf - \phi_w$ (work function $\phi_w$); slope of $V_{\mathrm{stop}}$ vs. $f$ measures $h$ — Millikan's reluctant confirmation, one sentence.
- Misconceptions: "Planck proposed photons" (Planck quantized exchange with matter and considered it a trick; Einstein made light itself grainy — the distinction is historically and conceptually real); "brighter light means more energetic electrons" (more *numerous*; only frequency raises per-electron energy).

*Worked examples:* (1) the geometric-series computation of $\langle E\rangle$ for a quantized mode, start to finish (this is also exercise-able as retrieval; the worked version carries full commentary); (2) the Sun as a blackbody: $T \approx 5800$ K → $\lambda_{\max}$ via Wien, compare to visible; (3) photoelectric: given $\phi_w$ (sodium) and $\lambda$, compute stopping potential; check the threshold.

*Simulation section:* run `python3 code/day13_blackbody_curves.py`; predict-prompts: "double T — the peak moves which way, and the area grows by what factor?", "where exactly do the RJ and Planck curves agree, and why there?", "at the Sun's temperature, is the peak inside the visible band?"

*Exercises:* Retrieval: (1) reproduce the quantized-mode $\langle E\rangle$ geometric-series derivation closed book; (2) state the three photoelectric facts and what the wave picture wrongly predicts for each. Standard: (3) cosmic microwave background at $T=2.7$ K: find $\lambda_{\max}$ and the corresponding photon energy in eV, compare to $k_BT$; (4) a photon counter: how many 500 nm photons per second is 1 nW? (closes day 8's forward flag). Stretch: (5) show $\langle E\rangle \to k_BT$ as $hf/k_BT \to 0$ by Taylor expansion, and $\to hf\,e^{-hf/k_BT}$ as $hf/k_BT\to\infty$; explain in one paragraph how this single formula contains both classical physics and its death.

*Connection to QM:* $E=hf$ is the first quantum equation of your course; "each field mode is a quantized oscillator" is the seed of quantum optics — the photon states your photonics-flavored course manipulates in interferometers are exactly these mode quanta.

- [ ] **Step 2: Write `code/day13_blackbody_curves.py`** per Global Constraints. Two panels: (a) Planck spectral curves at T = 3000, 4500, 5800 K with Wien peaks marked by vertical dashed lines, visible band shaded; (b) Planck vs. Rayleigh–Jeans at 5800 K on log-log axes showing agreement at low frequency and divergence at high.

- [ ] **Step 3: Run `python3 code/day13_blackbody_curves.py`** — expect clean run; peaks shift blue with T; RJ hugs Planck at low $f$ and explodes at high $f$.

- [ ] **Step 4: Run the per-day verification checklist**; fix failures.

---

### Task 15: Day 14 — Atoms, Spectra, and Atom–Light Interaction

**Files:**
- Create: `content/day14.md`

**Interfaces:**
- Consumes: day 4's reduced-mass and angular momentum, day 12's Boltzmann populations, day 13's $E=hf$ and Planck's law.
- Produces: Bohr levels $E_n = -13.6\,\mathrm{eV}/n^2$; the two-level atom + Einstein $A$/$B$ coefficient relations; photon momentum $p = E/c = h/\lambda$; Compton shift $\Delta\lambda = \frac{h}{m_ec}(1-\cos\theta)$ (stated). Day 15 consumes Bohr + photon momentum; day 18 consumes the two-level atom.

- [ ] **Step 1: Draft `content/day14.md` (~3.5h day) with this content brief:**

*Learning objectives:* explain why classical atoms can't exist; derive the Bohr levels from quantized angular momentum; compute spectral-line wavelengths; distinguish absorption, spontaneous emission, stimulated emission and derive the Einstein A/B relations; explain a laser in one page; use photon momentum and the Compton formula.

*Theory beats:*
1. Rutherford's atom and its classical death sentence: accelerating charge radiates (state as fact from day 8's fields carrying energy); estimate quoted — the classical electron spirals in within $\sim10^{-11}$ s. Atoms shouldn't exist; they do.
2. Spectral lines: discrete emission/absorption lines as the second scandal; Balmer's numerology $1/\lambda = R(1/4 - 1/n^2)$ stated as the pattern begging for a mechanism.
3. Bohr: postulates stated honestly as inspired guessing ($L = n\hbar$ + classical circular orbits + radiation only on jumps); derive $r_n$ and $E_n = -13.6\,\mathrm{eV}/n^2$ completely; recover Balmer; note the reduced-mass refinement (day 4 exercise 5 cashed in, one sentence).
4. Why Bohr is wrong-but-useful: right energies (for hydrogen only), right size scale, wrong picture (no orbits — day 15 and your course replace them); its real legacy is "stationary states + quantum jumps emitting $E=hf$ photons."
5. **Atom–light interaction (the photonics payload):** the two-level atom abstraction introduced explicitly as "the model your course will use constantly." Three processes defined: absorption ($B_{12}$), spontaneous emission ($A_{21}$), stimulated emission ($B_{21}$ — emitted photon is a *copy*: same frequency, direction, phase). Einstein's equilibrium argument fully derived: two-level populations in Boltzmann ratio (day 12) + rate balance in a Planck field (day 13) → $B_{12}=B_{21}$ and $A/B = 8\pi h f^3/c^3$ — emphasize what the argument shows: spontaneous emission is *forced to exist* by thermodynamic consistency.
6. The laser in one page: population inversion (why two levels can't lase, three/four can — Boltzmann says $N_2<N_1$ at any temperature), the cavity as a mode selector (day 6's standing waves), stimulated emission's copying as the source of coherence.
7. Relativity teaser (labeled as such, results-with-motivation not derivations): $E=mc^2$ meaning; photon: massless, $E = pc$ → $p = h/\lambda$; Compton scattering as photon-electron billiards, formula $\Delta\lambda = \frac{h}{m_ec}(1-\cos\theta)$ stated and used — its significance: photons carry momentum like particles, interference notwithstanding.
- Misconceptions: "electrons orbit like planets" (Bohr's picture is scaffolding; stationary states are standing waves — tomorrow); "stimulated emission is exotic" (it's the majority process inside every laser pointer; spontaneous emission is the strange one — it's stimulated by vacuum, as your course will show).

*Worked examples:* (1) Bohr-level derivation from $L=n\hbar$ start to finish with numbers for $n=1$; (2) Balmer α wavelength ($n=3\to2$) computed, located in the visible; (3) Einstein-relations derivation as a worked argument (populations + rates + Planck matching); (4) Compton: 0.1 nm X-ray at $90°$ — compute $\Delta\lambda$ and the electron's kinetic energy.

*Exercises:* Retrieval: (1) re-derive $E_n$ from Bohr's postulates closed book; (2) state the three atom–light processes and which coefficient governs each. Standard: (3) hydrogen ionization: minimum photon frequency from $n=1$, and from $n=2$; (4) ratio of stimulated to spontaneous emission rates in a thermal field at given $T$ and $f$ (uses $A/B$ + Planck occupancy) — evaluate for visible light at room temperature and for microwaves, interpret the contrast. Stretch: (5) why can't a two-level system lase in steady state? Rate-equation argument sketch showing $N_2 \le N_1$ under any pumping via the same $B$ both ways.

*Connection to QM:* the two-level atom IS the physical qubit of many photonics platforms; your course's Rabi oscillations are the coherent version of today's rate-equation story; and quantized $L = n\hbar$ is the first appearance of the angular-momentum quantization the course derives properly.

- [ ] **Step 2: Run the per-day verification checklist**; fix failures. (Note: this is the densest day — if it exceeds 600 lines, trim the relativity teaser first, never the Einstein-relations derivation.)

---

### Task 16: Day 15 — Matter Waves and the Synthesis

**Files:**
- Create: `content/day15.md`

**Interfaces:**
- Consumes: day 6's standing-wave quantization sentence, day 7's packets, day 13's $E=hf$, day 14's Bohr levels + photon momentum.
- Produces: de Broglie $\lambda = h/p$; the synthesis sentence "quantization = boundary conditions on matter waves"; thermal de Broglie estimate. Day 16 opens from exactly here.

- [ ] **Step 1: Draft `content/day15.md` (~3.5h day) with this content brief:**

*Learning objectives:* state and use $\lambda = h/p$; describe Davisson–Germer and why it's decisive; re-derive Bohr's $L=n\hbar$ from a standing matter wave; estimate when quantum effects matter; articulate the synthesis in one's own words.

*Theory beats:*
1. de Broglie's symmetry bet: light — long thought a wave — carries particle attributes ($E=hf$, $p=h/\lambda$, days 13–14); perhaps matter — long thought particles — carries wave attributes with the SAME relations read backwards: $\lambda = h/p$, $f = E/h$.
2. Numbers immediately: electron at 100 eV → $\lambda \approx 0.12$ nm (atomic scale — measurable); thrown baseball → $\lambda \sim 10^{-34}$ m (hopeless — why nobody noticed).
3. Davisson–Germer: electrons off a nickel crystal show diffraction peaks at angles matching $\lambda = h/p$ — matter waves measured; electron two-slit interference (single electrons, fringes build up dot by dot) as the cleaner modern statement.
4. **The synthesis (centerpiece):** electron in a Bohr orbit as a wave that must close on itself: $2\pi r = n\lambda$ + $\lambda = h/p$ → $L = rp = n\hbar$ — Bohr's mystery postulate DERIVED from the standing-wave condition. Then the general chain, boxed: *particles are waves (de Broglie) → confined waves form discrete modes (day 6) → therefore confined particles have discrete energies. Quantization is boundary conditions applied to matter waves.*
5. Wave–particle straight talk: the electron is neither a classical wave nor a classical particle; it's described by a wavefunction whose mode structure gives energies and whose modulus gives probabilities (Born, formalized tomorrow); what "duality" does and doesn't mean, without mysticism.
6. When is quantum relevant: compare $\lambda_{\mathrm{dB}}$ to the system size; thermal de Broglie wavelength $\lambda_{th} = h/\sqrt{2\pi m k_BT}$ (motivated from $p \sim \sqrt{mk_BT}$, day 12) — evaluate for an electron and for a helium atom at room temperature.
- Misconceptions: "the electron travels along the wave" (the wave IS the electron's description, not its trail); "wave–particle duality means sometimes-wave-sometimes-particle" (one consistent object — a quantum state — with wave-like propagation and particle-like detection).

*Worked examples:* (1) electron vs. baseball $\lambda$ computed; (2) the Bohr-condition-from-standing-waves derivation in full; (3) Davisson–Germer: given crystal spacing, predict the diffraction angle for 54 eV electrons (the historical numbers).

*Exercises:* Retrieval: (1) state both de Broglie relations and compute $\lambda$ for a 1 keV electron; (2) reproduce the standing-wave → $L=n\hbar$ derivation closed book. Standard: (3) neutron diffraction: what kinetic energy gives $\lambda = 0.1$ nm? Compare to $k_BT$ at room temperature (thermal neutrons — flag the connection); (4) electron microscope resolution argument: why electrons beat light at the same "optics." Stretch: (5) particle confined to a 1D box of size $L$ treated by pure standing-wave reasoning: allowed $\lambda_n = 2L/n$ → $p_n = nh/2L$ → $E_n = n^2h^2/8mL^2$ — derive it TODAY from waves alone; tomorrow the Schrödinger equation reproduces it exactly (this exercise is deliberately day 16's headline result, obtained a day early with 1924-era tools).

*Connection to QM:* you now hold every ingredient of the course's day one: states are waves, observables from mode structure, probabilities from amplitudes, quantization from confinement. Tomorrow assembles them into THE equation.

- [ ] **Step 2: Run the per-day verification checklist**; fix failures.

---

### Task 17: Day 16 — The Schrödinger Equation + sim

**Files:**
- Create: `content/day16.md`
- Create: `code/day16_box_eigenstates.py`

**Interfaces:**
- Consumes: day 15's de Broglie relations and box exercise; day 10's $H = p^2/2m + V$; day 6's boundary-condition quantization; day 5's dispersion-relation concept.
- Produces: TDSE and TISE; Born rule + normalization; box results $E_n = n^2\pi^2\hbar^2/2mL^2$, $\psi_n = \sqrt{2/L}\sin(n\pi x/L)$; orthogonality. Days 17–18 consume all of it.

- [ ] **Step 1: Draft `content/day16.md` (~4h day) with this content brief:**

*Learning objectives:* motivate the TDSE from plane waves + $E = p^2/2m + V$; state the Born rule and normalize wavefunctions; separate variables to the TISE; solve the particle in a box completely; verify orthogonality of eigenstates; connect box modes to day 6's standing waves.

*Theory beats:*
1. The construction (honest about its status — a motivation, not a derivation; validated by experiment): free matter wave $\psi = e^{i(kx-\omega t)}$ with $p=\hbar k$, $E=\hbar\omega$. Notice: $-i\hbar\,\partial_x\psi = p\psi$ and $i\hbar\,\partial_t\psi = E\psi$. Demand $E = \frac{p^2}{2m} + V$ hold as an operator statement → $i\hbar\,\partial_t\psi = -\frac{\hbar^2}{2m}\partial_x^2\psi + V\psi$. Flag: first-order in time (unlike day 5's wave equation), complex-valued *necessarily*; the dispersion relation $\omega = \hbar k^2/2m$ is day 7 exercise 3's — matter waves disperse, packets spread.
2. What $\psi$ means: Born rule $|\psi(x)|^2 dx$ = probability; normalization $\int|\psi|^2dx = 1$; why complex $\psi$ still yields real predictions; global phase is unobservable (day 8 exercise 5 recalled).
3. Stationary states: separation $\psi(x,t) = \phi(x)e^{-iEt/\hbar}$ → TISE $\hat H\phi = E\phi$ with $\hat H = -\frac{\hbar^2}{2m}\partial_x^2 + V(x)$ — day 10's Hamiltonian with hats, stated in exactly those words; stationary means $|\psi|^2$ time-independent, not "nothing happens."
4. **Particle in a box, fully:** infinite well $V=0$ inside $[0,L]$; boundary conditions $\phi(0)=\phi(L)=0$ (day 6's fixed string verbatim) → $\phi_n = \sqrt{2/L}\sin(n\pi x/L)$, $E_n = \frac{n^2\pi^2\hbar^2}{2mL^2}$; normalization computed; match to day 15's stretch exercise triumphantly (same numbers, real theory now); zero-point energy ($n=0$ forbidden — and why: it would be $\phi\equiv0$); nodes count $n-1$.
5. Orthogonality $\int\phi_n\phi_m dx = \delta_{nm}$ verified by the integral (day 7's mode-basis inner product recalled); expansion of an arbitrary state in eigenstates = Fourier series = "the basis expansion from your linear algebra path, now with physical meaning: $|c_n|^2$ is the probability of measuring $E_n$."
6. Superposition dynamics preview: two-state superposition $\propto \phi_1 e^{-iE_1t/\hbar} + \phi_2 e^{-iE_2t/\hbar}$ → $|\psi|^2$ oscillates at $(E_2-E_1)/\hbar$ — day 6's beats, now in probability; one paragraph, sim shows it.
- Misconceptions: "$\psi$ is a physical wave in space like a water wave" (it's a probability amplitude; for 2 particles it lives in 6 dimensions — one sentence); "the particle in a stationary state is at rest" ($\langle p\rangle = 0$ but $\langle p^2\rangle \ne 0$; kinetic energy is real).

*Worked examples:* (1) electron in a 1 nm box: $E_1, E_2$ in eV and the $2\to1$ photon's wavelength; (2) normalize $\phi_n$ from scratch; (3) ground state: probability of finding the particle in the middle third (integral computed).

*Simulation section:* run `python3 code/day16_box_eigenstates.py`; predict-prompts: "double the box width — each $E_n$ changes by what factor?", "which $\phi_n$ has a node exactly at the center?", "in the superposition panel, predict the sloshing period from $E_2 - E_1$ before reading it off."

*Exercises:* Retrieval: (1) reconstruct the TDSE motivation from the plane wave closed book; (2) solve the box from boundary conditions closed book (the single most course-relevant retrieval act in the path). Standard: (3) proton vs. electron in the same box: level-spacing ratio, and why nuclei need MeV where atoms need eV; (4) verify $\phi_1 \perp \phi_2$ by explicit integration. Stretch: (5) box with one wall suddenly moved from $L$ to $2L$ (state frozen): expand the old ground state in the new basis — set up the $c_n$ integrals, compute $c_1$ numerically, interpret $|c_1|^2 < 1$.

*Connection to QM:* this is the course's first two weeks, pre-lived: TISE as eigenvalue problem (your linear-algebra spectral theorem, infinite-dimensional), measurement postulate via $|c_n|^2$, and the box as the toy model everything else perturbs. The photonics tie: a cavity's photon modes obey the same boundary-condition mathematics — day 6, day 13, and today are one story.

- [ ] **Step 2: Write `code/day16_box_eigenstates.py`** per Global Constraints. Two panels: (a) first 5 box eigenfunctions $\phi_n$ offset vertically at heights proportional to $E_n$ inside a drawn well, with the energy ladder marked on the axis (the standard textbook figure, plus $|\phi_n|^2$ as a lighter overlay); (b) two-state superposition $|\psi(x,t)|^2$ at 5 equally spaced times across half a sloshing period, showing probability sloshing left↔right (analytic evaluation — no integrator).

- [ ] **Step 3: Run `python3 code/day16_box_eigenstates.py`** — expect clean run; $E_n$ spacing grows quadratically; sloshing visible.

- [ ] **Step 4: Run the per-day verification checklist**; fix failures.

---

### Task 18: Day 17 — Quantum Oscillator, Tunneling, Uncertainty + sim

**Files:**
- Create: `content/day17.md`
- Create: `code/day17_packet_evolution.py`

**Interfaces:**
- Consumes: day 3's classical oscillator, day 7's bandwidth theorem and packet spreading, day 16's TISE and box.
- Produces: QHO ladder $E_n = \hbar\omega_0(n+\tfrac12)$; $\Delta x\,\Delta p \ge \hbar/2$; Gaussian free-packet spreading law $\Delta x(t) = \Delta x_0\sqrt{1 + (\hbar t/2m\Delta x_0^2)^2}$ (stated). Day 18 consumes the QHO ladder (photons) and uncertainty.

- [ ] **Step 1: Draft `content/day17.md` (~4h day) with this content brief:**

*Learning objectives:* state the QHO spectrum and ground state and explain (not re-derive) their structure; compute zero-point energies; explain tunneling via evanescent waves; convert day 7's bandwidth theorem into Heisenberg's relation and use it for estimates; describe Gaussian packet spreading quantitatively.

*Theory beats:*
1. QHO setup: $V = \tfrac12 m\omega_0^2 x^2$ into the TISE; solution *structure* presented, not the Hermite grind (say so): $E_n = \hbar\omega_0(n+\tfrac12)$, evenly spaced; ground state is a Gaussian $\phi_0 \propto e^{-m\omega_0 x^2/2\hbar}$ — VERIFY it satisfies the TISE by direct differentiation (that much is honest work, done fully); first excited state shown, node count rule carried over from day 16.
2. Why even spacing is the headline: a quantized field mode is an oscillator (day 13), so its levels $n\hbar\omega$ are *countable energy lumps* — photons; "add one photon" = "climb one rung"; ladder-operator names dropped as vocabulary for the course ($a, a^\dagger$, "creation/annihilation"), algebra deferred to the course.
3. Zero-point energy $\tfrac12\hbar\omega_0$: why the uncertainty principle forbids a resting particle at the bottom (the estimate: minimize $\langle E\rangle \sim \frac{\hbar^2}{2m(\Delta x)^2} + \tfrac12 m\omega_0^2(\Delta x)^2$ — done fully, lands within a factor of the exact answer); physical reality: molecular vibrations at $T\to0$, liquid helium never freezing at ambient pressure (one sentence each).
4. Tunneling qualitatively: in the classically forbidden region ($E < V$, day 2's language) the TISE gives decaying exponentials $e^{-\kappa x}$, $\kappa = \sqrt{2m(V-E)}/\hbar$, not oscillation; a thin barrier lets the tail through — transmission $\sim e^{-2\kappa d}$ (stated, with the analogy: frustrated total internal reflection — evanescent light waves jumping a gap, day 8's wave optics); consequences named: alpha decay, tunnel diodes, scanning tunneling microscope.
5. Heisenberg for real: $\Delta x\,\Delta k \ge \tfrac12$ (day 7, Gaussian equality) times $\hbar$: $\Delta x\,\Delta p \ge \hbar/2$; what it does and doesn't say (statistical spreads over repeated preparations, not measurement clumsiness — one careful paragraph); estimates it powers: hydrogen's size (minimize energy with $\Delta x$), why electrons can't live inside nuclei.
6. Free Gaussian packet: spreading law stated (formula above), with the physical reading — narrower start spreads faster (day 7's dispersion + big $\Delta k$); Ehrenfest teaser one paragraph: $\langle x\rangle$ obeys Newton, quantum corrections ride on the spread.
- Misconceptions: "zero-point motion is thermal jiggling that better cooling removes" (it survives $T=0$; it's structural); "tunneling particles briefly violate energy conservation" (energy is conserved; the forbidden region has amplitude, not a classical trajectory).

*Worked examples:* (1) verify the Gaussian ground state solves the QHO TISE and read off $E_0 = \tfrac12\hbar\omega_0$; (2) CO molecule vibration: given $\omega_0$ from spectroscopy, compute zero-point energy, compare with $k_BT$ at room temperature (vibrations frozen — day 12 exercise 4 closed); (3) uncertainty estimate of hydrogen's ground-state size and energy — land within a factor of 2 of Bohr's $-13.6$ eV.

*Simulation section:* run `python3 code/day17_packet_evolution.py`; predict-prompts: "halve the initial width — does it spread faster or slower?", "increase the mass tenfold — what happens to the spreading time?", "at what time has the width doubled? Predict from the formula, then measure on the plot."

*Exercises:* Retrieval: (1) state the QHO spectrum and sketch the two lowest $|\phi_n|^2$ (describe nodes and symmetry); (2) reproduce the zero-point uncertainty estimate for the QHO closed book. Standard: (3) electron trapped to $\Delta x = 0.1$ nm: minimum momentum spread and kinetic-energy scale in eV; (4) tunneling scaling: for an electron and a 1 eV, 0.5 nm barrier compute $\kappa$ and $e^{-2\kappa d}$; repeat for a proton — why chemistry has electron transfer but not proton teleportation. Stretch: (5) a thrown 0.1 kg ball localized to $\Delta x_0 = 1$ mm: compute the doubling time of its wave packet and compare to the age of the universe — write three sentences on why classical mechanics is safe.

*Connection to QM:* the QHO is the most-used system in your course (field modes, trapped ions, cavity photons); "n photons in a mode" now has exact meaning; and Heisenberg's relation arrived not as an axiom but as day 7's wave mathematics wearing $p = \hbar k$ — which is how your course will actually derive it too (Fourier + commutators).

- [ ] **Step 2: Write `code/day17_packet_evolution.py`** per Global Constraints. Two panels: (a) free Gaussian $|\psi(x,t)|^2$ snapshots at 4 times using the analytic complex-Gaussian evolution (code the closed-form $\psi(x,t)$ with complex numpy directly — no PDE solver), with $\Delta x(t)$ annotated per snapshot; (b) $\Delta x(t)$ curve vs. the stated formula for two initial widths, showing narrower-spreads-faster.

- [ ] **Step 3: Run `python3 code/day17_packet_evolution.py`** — expect clean run; both panels; narrower initial packet visibly overtakes the wider one's width.

- [ ] **Step 4: Run the per-day verification checklist**; fix failures.

---

### Task 19: Day 18 — The Rosetta Stone

**Files:**
- Create: `content/day18.md`

**Interfaces:**
- Consumes: essentially everything — by name: day 6 (MZ laws), day 8 (Jones vectors, Malus), day 11 (dictionary table), day 14 (two-level atom), day 16 (box eigenstates, Born rule), day 17 (QHO/photons); plus, read-only, `quantum_computing_foundations/content/day03.md` (complex vector spaces & the qubit), `day04.md` (unitaries & Bloch sphere), `day06.md` (measurement, Born rule & density matrices), `day07.md` (multi-qubit & entanglement).
- Produces: the finished path; the readiness self-test.

- [ ] **Step 1: Draft `content/day18.md` (~4h day) with this content brief:**

*Learning objectives:* translate fluently between wave mechanics and Dirac/matrix formalism; realize a qubit three ways (truncated well, polarization, MZ paths); read a Mach–Zehnder as a single-qubit circuit; locate every upcoming course topic on this path's map; pass the readiness self-test.

*Theory beats:*
1. **The dictionary**, as a full two-column table with a worked row-by-row commentary: $\psi(x)$ | $|\psi\rangle$; $\int \phi_n^*\psi\,dx$ | $\langle n|\psi\rangle$; $\int|\psi|^2dx=1$ | $\langle\psi|\psi\rangle=1$; operators $-i\hbar\partial_x$ | matrices; TISE $\hat H\phi_n = E_n\phi_n$ | eigenvalue problem $H|n\rangle = E_n|n\rangle$; expansion $\psi = \sum c_n\phi_n$ | $|\psi\rangle = \sum c_n|n\rangle$; $|c_n|^2$ | Born rule; $e^{-iEt/\hbar}$ phases | unitary evolution $U = e^{-iHt/\hbar}$. Cross-reference: "the right-hand column is precisely the formalism of `quantum_computing_foundations` days 3–6 — re-skim day03's inner-product section with today's left column in mind."
2. Also reprint day 11's classical↔quantum table (Poisson→commutator) beneath it: the two tables together are the whole conceptual map.
3. **Two-level truncation:** take the box's lowest two levels, ignore the rest (justified when energies/drives only reach those two) → states $\alpha|1\rangle + \beta|2\rangle$, all observables $2\times2$ matrices → the qubit; the same truncation on an atom = day 14's two-level atom; "a qubit is not a thing — it's any quantum system you've agreed to use two levels of."
4. **Photonic qubit #1 — polarization:** day 8's Jones vectors REREAD as qubit states: $|H\rangle,|V\rangle \to |0\rangle,|1\rangle$; wave plates = single-qubit unitaries (give the quarter-wave plate's $2\times2$ matrix); Malus = Born rule (the sentence from day 8, now with full context); polarizing beam splitter = measurement in the H/V basis.
5. **Photonic qubit #2 — the Mach–Zehnder as a circuit:** which-path as the qubit basis (upper/lower arm = $|0\rangle/|1\rangle$); 50/50 beam splitter as a Hadamard-like $2\times2$ unitary (give the matrix $\frac{1}{\sqrt2}\begin{pmatrix}1 & i\\ i & 1\end{pmatrix}$, note convention variants in one sentence); phase shifter as $\mathrm{diag}(1, e^{i\phi})$; multiply the three matrices → output probabilities $\cos^2(\phi/2), \sin^2(\phi/2)$ — **exactly day 6's intensity laws**, now derived as a quantum circuit. Single-photon reading: one photon, both arms, interferes with itself; detector clicks follow the Born rule.
6. **The course map:** a table of likely course topics (postulates & Dirac formalism; two-level dynamics/Rabi oscillations; harmonic oscillator & quantized light; interferometry & photon statistics; measurement theory; entanglement) with, per row: which days of this path prepared it and which `quantum_computing_foundations` day connects.
7. **Readiness self-test** (replaces the standard exercise tiers, labeled as such): 12 questions spanning the whole path — 2 mechanics (V(x) reading; oscillator $\omega_0$ from a potential), 2 waves (standing-wave quantization; group velocity), 2 analytical (construct an $H$; a Poisson bracket), 2 quantum evidence (Planck's average; photoelectric numbers), 2 wave mechanics (box energies; uncertainty estimate), 2 bridge (MZ matrix product; polarization-qubit Born rule). Each with hint and full solution per house format. Pass bar stated: 9/12 unaided = ready; below that, the per-question solutions name which day to revisit.
- Misconceptions: "wave mechanics and matrix mechanics are different theories" (same theory, different bases — the dictionary is exact); "the photon splits at the beam splitter" (the *amplitude* splits; detection is always whole photons — this distinction is the course's entire measurement chapter in embryo).

*Worked examples:* (1) the full MZ matrix product, symbolic then at $\phi = 0, \pi/2, \pi$; (2) two-level truncation worked: box levels 1–2 with a weak driving term, written as a $2\times2$ matrix problem; (3) quarter-wave plate acting on $|H\rangle$-vs-diagonal inputs via its matrix.

*Connection to QM:* one closing page — "What you can now do": walk into the course able to read $\hat H|\psi\rangle = E|\psi\rangle$ as both a differential equation and a matrix equation, see every interferometer as a circuit, and know where each new topic hangs on the map. Plus the standing instruction: re-read day 11 after course week 2.

- [ ] **Step 2: Verify cross-references:** every `quantum_computing_foundations/content/dayXX.md` file named in day18 exists with the topic claimed (day03 complex vector spaces/qubit; day04 unitaries/Bloch; day06 measurement/Born/density matrices; day07 entanglement).

- [ ] **Step 3: Run the per-day verification checklist** (self-test counts as the exercise tiers: 12 questions, each with hint + solution); fix failures.

---

### Task 20: GLOSSARY.md

**Files:**
- Create: `content/GLOSSARY.md`

**Interfaces:**
- Consumes: all 18 day files (terms must actually appear in the corpus).
- Produces: the glossary README links to.

- [ ] **Step 1: Read `quantum_computing_foundations/content/GLOSSARY.md`** and match its entry format and tone exactly (plain-English house style).

- [ ] **Step 2: Draft `content/GLOSSARY.md`:** 60–80 terms, alphabetical, each entry = **term** — one/two plain-English sentences a non-physicist could follow, ending with "(Day N)" locating first serious use. Must include at minimum: action, amplitude, angular momentum, beats, blackbody, Boltzmann factor, Born rule, bound state, boundary condition, commutator (as previewed), conservative force, dispersion relation, eigenstate, equipartition, evanescent wave, Fourier series, group velocity, Hamiltonian, harmonic oscillator, interference, Jones vector, Lagrangian, Mach–Zehnder interferometer, Malus's law, matter wave, mode, normal mode, normalization, partition function, phase space, phase velocity, photon, Planck's constant, Poisson bracket, polarization, population inversion, potential well, resonance, separatrix, standing wave, stationary state, stimulated emission, superposition, tunneling, turning point, two-level system, uncertainty principle, wave packet, wavefunction, work function, zero-point energy.

- [ ] **Step 3: Verify checklist↔corpus reconciliation** (the lesson from the glossaries project): for every entry, `grep -il` the term across `content/day*.md` and confirm at least one hit AND that the cited day is the right one; remove or re-day any entry that fails; spot-add glaring omissions found while grepping.

---

### Task 21: README.md

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: every file in the project (it indexes them).
- Produces: the path's front page.

- [ ] **Step 1: Draft `README.md` (~120–180 lines):**

1. Title + three-sentence pitch (who it's for, what it assumes — the linear algebra and quantum computing paths by name — where it lands: ready for a photonics-flavored QM course).
2. "Start here": read STRATEGY.md first; the daily rhythm; total budget ~62.5 h over 18 days at 3–4 h/day; note that days 16–18 may overlap the course's first weeks by design.
3. **Phase map:** the five phases with one-line descriptions and day ranges (from the spec).
4. **Day index table:** Day | Title | Hours | Simulation — 18 rows, sim column linking `code/` files where they exist, "—" elsewhere.
5. Prerequisites paragraph: calculus fluency, linear algebra (path), complex numbers; what is NOT assumed (remembering any physics).
6. Simulations: how to run (`python3 code/<file>.py`), dependency line (`pip install numpy matplotlib`).
7. Pointer to the cut list in STRATEGY.md and to `content/GLOSSARY.md`.
8. Course-overlap note: which days to prioritize if the course starts before day 18 (answer: never skip 9–11 or 16; days 12–14 compress best — one honest paragraph).

- [ ] **Step 2: Verify the index against the corpus:** every table row's title matches the actual `# Day N — <Title>` heading in the corresponding file (fix the README, not the day files); every linked sim file exists; hours match the phase budgets.

---

### Task 22: Final Coherence Pass

**Files:**
- Modify (fix-only): any file failing a check below.

**Interfaces:**
- Consumes: the entire corpus. Produces: the ship-ready state.

- [ ] **Step 1: Cross-reference sweep.** `grep -n "day0\|day1\|Day 0\|Day 1" content/*.md README.md STRATEGY.md` and verify every mention of another day refers to content that actually exists there (day 6's boxed sentence quoted by 15/16; day 7's bandwidth theorem in 17; day 8's Jones vectors in 18; day 11's table reprinted in 18; day 12's exercise 4 closed by 17; day 15's stretch matched by 16). Fix mismatches at the *referencing* end.

- [ ] **Step 2: Run all seven simulations** in sequence: `for f in code/*.py; do python3 "$f"; done` (close each window to proceed, or run with `MPLBACKEND=Agg` for a headless pass). Expected: seven clean exits, no exceptions, no warnings other than benign matplotlib font notices.

- [ ] **Step 3: Anatomy audit.** For each of the 18 day files confirm mechanically: all required `##` sections present in order; exercise/hint/solution counts match (`grep -c` per section); ≥2 misconception callouts; time budget stated. Produce a pass/fail line per file and fix every fail.

- [ ] **Step 4: Notation audit.** `grep -n "mathcal{L}" content/*.md` must return nothing; spot-check that $k_s$ is used for spring constants in days 3, 5, 16, 17 and $T_s$ for string tension in day 5; days 9–11 each flag the $L$/$T$ notation switch on first use.

- [ ] **Step 5: Report.** Summarize to the user: files created, checks run and their results, anything cut or deviated from this plan — and remind that committing is theirs to do.

---

## Self-Review (performed)

**Spec coverage:** STRATEGY.md → Task 1; 18 day files → Tasks 2–19 matching the spec's five phases and per-day content including the photonics weighting (interferometers in Task 7, Jones vectors in Task 9, Einstein A/B + two-level atom in Task 15, photonic qubits/MZ-as-circuit in Task 19); 7 sims → embedded in Tasks 4, 7, 8, 11, 14, 17, 18; glossary → Task 20; README → Task 21; verification section of the spec → per-task checklists + Task 22. Out-of-scope items (hydrogen solution, spin algebra, perturbation theory, LaTeX builds, commits) appear in no task. No gaps found.

**Placeholder scan:** no TBD/TODO; every exercise names its actual problem; every sim step specifies panels and method; hints/solutions required per-problem by the anatomy contract in Global Constraints rather than restated 18 times.

**Type consistency (here: notation/interface consistency):** $\omega_0$, $k_s$, $T_s$, $V(x)$, Jones-vector basis, MZ output laws $\cos^2(\phi/2)/\sin^2(\phi/2)$, box results, and the day-11 dictionary are defined once and consumed by name in later tasks' Interfaces blocks; day-18's beam-splitter matrix convention is stated where used.
