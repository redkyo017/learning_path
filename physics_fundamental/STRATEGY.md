# STRATEGY.md

*Read this before day 1. It won't teach you a single equation — it tells you
how to spend eighteen days so the equations stick.*

This path assumes a specific learner, not "someone learning physics." You
were once solid in high-school and university physics and you are rusty now.
Your math is freshly sharp — you just finished the `linear_algebra/` path.
You have already worked through `quantum_computing_foundations/`, so Dirac
notation, qubits, and gates are not new vocabulary; what's missing is the
physical story underneath that formalism — where a Hamiltonian, a
wavefunction, or "quantization" actually comes from. A "Foundations of
Quantum Mechanics" course, part of a quantum computing/information master's,
starts in roughly fifteen days. You have 3–4 focused hours a day and eighteen
days total. That is not enough time to re-learn physics the way you learned
it the first time, chapter by chapter, and it doesn't need to be — you're not
starting from zero, you're reactivating and redirecting something you
already built once.

## The protocol

Most people re-learning a subject under a deadline default to the method
they used the first time: read, watch a lecture, do the assigned problems,
move on to the next chapter. That method assumes a semester and no fixed
target. You have neither. The five habits below are what this path is built
around — not suggestions layered on top of the content, but the reason the
content is organized the way it is. Each has a concrete action for today, not
just a philosophy to agree with.

### Learn backwards from the target

This path is not the traditional physics curriculum compressed into eighteen
days. It is the dependency graph of a first quantum mechanics course, walked
in the order QM actually needs the pieces. The spine is:

**mechanics → waves → Hamiltonians → quantum evidence → Schrödinger →
Dirac**

Newton's laws (days 1–4) exist because "physics is solving an ODE for how a
system evolves" is the picture the Schrödinger equation (day 16) reuses
directly. Waves and interference (days 5–8) exist because superposition,
standing modes, and two-state polarization are the classical rehearsal for
qubit superposition and photonic qubits (day 18). The Lagrangian and
Hamiltonian (days 9–11) exist because "state + a function that generates its
evolution" is the exact object QM promotes to operators. The classical
breakdown (days 12–15) exists because you need to feel *why* classical
physics failed — not just be told photons and matter waves exist — before
the Schrödinger equation looks like the fix instead of an arbitrary new rule.
Nothing here is included because "a well-rounded physicist should know it";
it's included because something later in the spine consumes it.

**Do this today:** before opening a day's file, write one sentence answering
"what does today's topic feed into, further down the spine?" For day 1, that
sentence is "solving F=ma as an ODE becomes solving the Schrödinger equation
as an ODE for ψ." Keep these sentences in one running log — by day 18 it is
the map of the whole course, written in your own words instead of the
professor's.

### Derive, don't re-read

Rereading feels like learning and mostly isn't — it produces recognition
("yes, I remember this equation") without production ("I can generate this
equation from nothing"). Production is what a closed-book exam, and a
closed-book course, actually demands. This path trades rereading for a
standing morning ritual.

**Do this today:** before you touch today's file, take a blank sheet of
paper and, from memory alone, re-derive every boxed equation from
*yesterday's* file. Ten minutes, no notes, no peeking. Whatever you can't
reproduce is today's real backlog item — resolve it on paper before you move
on to new content, because tomorrow's derivation almost certainly builds on
it.

### Retrieval beats review

Every day ships 4–6 practice problems in three tiers — retrieval, standard,
stretch — each with a one-line hint and a full solution sketch. The tiers
and the hint/solution split exist for one reason: to force retrieval instead
of recognition. A hint you read before attempting the problem is a solution
you've partially seen; a solution you read before attempting the hint is a
worked example you're pretending was a test.

**Do this today:** close the theory section before you open the exercises.
Attempt every problem fully closed-book. If you're stuck for more than five
minutes, read *only* the hint for that problem, then go back and try again.
Only open the solution sketch after a genuine attempt with the hint in hand
— never before.

### One Fermi estimate per day

A Fermi estimate — a fast, order-of-magnitude answer built from a chain of
defensible guesses, no lookup tables — is the fastest test of whether you
actually understand a piece of physics or just recognize its equation. Each
day of this path carries one, matched to that day's topic:

| Day | Topic | Fermi estimate |
|---|---|---|
| 1 | Newton as differential equations | Estimate the terminal velocity of a skydiver from drag-force reasoning alone. |
| 2 | Energy and potential wells | Estimate Earth's escape speed using only g and Earth's radius. |
| 3 | The harmonic oscillator, deep | Estimate the resonant frequency of a car bouncing on its suspension. |
| 4 | Momentum, angular momentum, symmetry | Estimate the angular momentum of a spinning bicycle wheel and how long friction takes to stop it. |
| 5 | From oscillators to waves | Estimate the speed of a pulse sent down a taut clothesline. |
| 6 | Superposition, standing waves, interferometers | Estimate the fringe spacing of a two-slit setup you could build on a tabletop with a laser pointer. |
| 7 | Fourier intuition and wave packets | Estimate the frequency bandwidth needed to produce a 1-nanosecond light pulse. |
| 8 | Light and polarization as a two-state system | Estimate the intensity remaining after light polarized along the first polarizer's axis passes through three polarizers, each rotated 30° from the last. |
| 9 | Action and the Lagrangian | Estimate the action, in units of ħ, for a thrown baseball's one-second flight — and see why classical mechanics looks classical. |
| 10 | The Hamiltonian and phase space | Estimate the phase-space area enclosed by one swing of a playground swing, in units of ħ. |
| 11 | Poisson brackets and the quantum preview | Estimate Δx·Δp for a dust grain located and weighed to ordinary precision, and express it as a multiple of ħ/2, to see how far it sits from the uncertainty floor. |
| 12 | Minimal thermal physics | Estimate the average speed of a nitrogen molecule in the room you're sitting in. |
| 13 | Blackbody radiation and the photon | Estimate how many visible photons a light bulb emits per second. |
| 14 | Atoms, spectra, atom–light interaction | Estimate the radius of a hydrogen atom from ħ, the electron mass, the electron charge, and the Coulomb constant 1/(4πε₀) alone. |
| 15 | Matter waves and the synthesis | Estimate the de Broglie wavelength of a thrown baseball and compare it to that of an electron in an old CRT tube. |
| 16 | The Schrödinger equation | Estimate the ground-state energy of an electron confined to a box one angstrom wide. |
| 17 | Quantum oscillator, tunneling, uncertainty | Estimate the odds of a thrown baseball tunneling through a brick wall in the age of the universe. |
| 18 | The Rosetta Stone | Estimate the number of photons in a single attenuated laser pulse used to carry one photonic qubit down an optical fiber. |

**Do this today:** before starting the day's formal exercises, spend ten
minutes on that day's estimate. Write down every assumption you're making
and the chain of multiplications that gets you to an order of magnitude —
the answer matters far less than whether you can defend each step.

### Interleave

Learning that stays inside the day it was taught feels solid and evaporates
fast. This path forces old material back into view on a schedule, so it
never gets the chance to fully fade.

**Do this today:** from day 2 on, each day's stretch problem is written to
reach back into an earlier day's result (or push one step further) — treat
that reach-back as the point of the stretch tier, not an inconvenience. In
addition, on every fourth day
(days 4, 8, 12, 16), before starting that day's new content, pick one boxed
equation from three or more days back and re-derive it blind, exactly as in
the morning ritual above, before reading anything new.

## The time-wasters

The five habits above are what to spend your hours on. Equally important is
recognizing the ways to lose those hours without noticing — each of these
feels like studying while producing almost nothing that survives contact
with a closed-book problem.

### Grinding projectile and statics problem sets

These are the most available practice problems in the world and the least
useful ones here — QM never asks you to compute a projectile's range or a
ladder's normal force. **Replacement:** do this path's 4–6 curated problems
per day, closed-book, once. When they're done, move on — do not go looking
for supplementary problem sets to "make sure it stuck."

### Passive lecture videos

Watching someone else derive an equation feels like understanding it and
mostly transfers recognition, not the ability to reproduce it yourself.
**Replacement:** attempt the derivation on paper first. Only reach for a
video afterward, to resolve one specific stuck point, and watch only the
segment covering that point — not the lecture from the start.

### Chasing mathematical rigor before physical intuition

Wanting to fully justify a step before trusting it is a reasonable instinct
that costs too much time here. **Replacement:** before formalizing a result,
check it against a limiting case or a units sanity check — what happens as a
variable goes to zero or infinity, does the equation reduce to something you
already trust — and only chase the rigorous justification later, if a
specific gap is bothering you.

### Skipping analytical mechanics

Days 9–11 (action, the Lagrangian, the Hamiltonian, Poisson brackets) are the
part of the classical canon most tempting to treat as optional depth,
because nothing on those days looks like it's "about quantum mechanics" yet.
**Replacement:** treat them as load-bearing, not enrichment — every later
piece of quantum formalism (the Hamiltonian operator, the commutator) is
introduced in the course as "the same object you already know, now with a
hat on it." Skipping days 9–11 means meeting that object for the first time
mid-course instead of recognizing it.

### Treating historical experiments as trivia

It's easy to reduce blackbody radiation, the photoelectric effect, and
Davisson–Germer to flashcard facts — "who discovered what, in what year."
**Replacement:** for each historical experiment, reconstruct the actual
falsification argument: what did classical physics predict, specifically,
and what did the experiment actually show that classical physics could not
produce. The date and the name are the least useful part of the story.

### Note-taking as transcription

Copying a derivation into a notebook line-by-line as you read it feels
productive and mostly builds a transcript you will never reread.
**Replacement:** read with the notebook closed. Afterward, write down only
your own restated version of the idea and the boxed equation reproduced from
memory — the derive-don't-reread ritual, applied in real time instead of the
next morning.

## What we cut and why

Eighteen days cannot cover the full high-school-through-university physics
canon, and pretending otherwise is how a path like this ends up shallow
everywhere instead of deep where it matters. The following five areas are
cut entirely rather than given a token, too-shallow-to-be-useful treatment:

| Cut | Why it doesn't block the QM course |
|---|---|
| Fluids (statics, dynamics, Bernoulli's equation) | QM never asks you to model a flowing continuum; nothing in the fluid picture recurs as formalism anywhere later in the spine. |
| Thermodynamic cycles (engines, Carnot efficiency, entropy accounting) | Only equilibrium thermal facts — the Boltzmann factor, equipartition — feed forward, into blackbody radiation on day 13. Cycles and engine efficiency have no downstream use. |
| DC/AC circuits | This course leans toward atom–light interaction and photonics; what it needs from electromagnetism is fields and oscillation, which days 5–8 supply directly. Circuit topology isn't reused. |
| Geometric-optics instruments (lens and mirror imaging systems, ray-tracing design) | The optics this course needs is wave optics — interference and polarization — covered on days 6 and 8. Imaging-system ray tracing doesn't reappear. |
| Rigid-body dynamics beyond angular momentum (inertia tensors, precession, gyroscopic motion) | Angular momentum conservation itself (day 4) carries forward into central forces and, later, orbital angular momentum in quantum systems. The full rigid-body tensor machinery on top of that doesn't recur. |

## How a day works

Every `content/dayXX.md` file has the same shape, so that by day 3 you're
spending your attention on the physics instead of figuring out where to look
for it.

1. **Learning goals and time budget.** A short list of what you should be
   able to do by the end of the day, and the hour estimate you're working
   against. If you're running well past that estimate, that's a signal to
   check the misconception callouts before pushing further, not to just grind
   longer.
2. **Reference material.** A short pointer to what's assumed going in —
   which earlier days this one leans on, and anything external worth having
   open.
3. **Theory, as narrative with derivations.** Every named equation is
   derived or physically motivated in the text — nothing is dropped in for
   you to accept on faith. Common-misconception callouts sit inline, right
   where the mistake actually happens, not collected in a list at the end.
4. **2–3 fully worked examples.** Complete solutions, walked start to
   finish, modeling the kind of reasoning the exercises will expect from you.
5. **A simulation section, on sim days only.** Seven of the eighteen days
   (3, 6, 7, 10, 13, 16, 17) pair the theory with a short, runnable Python
   script — something you can tweak a parameter in and immediately see the
   consequence, rather than trust the text's description of what a curve
   looks like.
6. **4–6 closed-book exercises**, tiered retrieval / standard / stretch.
   Solvable from that day's content plus prior days only — nothing requires
   material you haven't seen yet.
7. **Hints**, one per exercise, each a single non-spoiling nudge — enough to
   get unstuck, never enough to hand you the answer.
8. **Full solution sketches**, to be read only after a genuine attempt using
   the hint.
9. **A closing "Connection to QM" box** — what today's result specifically
   buys you in the actual course: which lecture it will make easier, which
   piece of notation it de-mystifies, which later day of this path it feeds.

The hour budget rises as the material does: **days 1–4 run about 3 hours**
(rebuilding mechanics you've mostly seen before), **days 5–15 run about 3.5
hours** (new structure — waves, analytical mechanics, the classical
breakdown — arriving at a steady pace), and **days 16–18 run about 4 hours**
(the bridge itself, where the path's whole point gets cashed in). That adds
up to roughly 62.5 hours across the eighteen days. Days 16–18 are written so
that overlapping them with the first weeks of the actual course, if your
schedule needs that, is by design rather than a failure to finish on time.
