# 15-Day Foundations of Quantum Computing Mastery Plan

**Date:** 2026-07-13
**Status:** Approved design

## Purpose

Reach genuine, derivation-level mastery of the University of Sussex "Foundations
of Quantum Computing" module syllabus in 15 days (4 hours/day, ~60 hours total),
run concurrently with ongoing coursework (no fixed exam date yet — the goal is to
get ahead of the lecture pace, not just keep up with it). Math-first: theory and
proof-derivation take priority over coding; light/occasional code is used only
where it sharpens geometric intuition (Bloch sphere, amplitude-amplification
rotation), never as a substitute for deriving results by hand.

## Learner context

- Background: a 30-day linear algebra intensive is essentially complete (Days
  1–29 done, high proof fluency on real vector spaces, eigenvalues, SVD), but
  complex vector spaces, Hermitian/unitary/normal matrices, and bra-ket notation
  were explicitly deferred from that plan — this plan builds them from scratch
  (Days 3–4).
- Strong software engineering background; Boolean logic/circuits move fast,
  formal complexity theory (P/BPP/NP) gets real but efficient treatment rather
  than assumed-known depth.
- Formally enrolled in the actual Sussex module. This is a "get ahead of /
  deepen beyond the lectures" sprint, not a from-zero intro course. No course
  problem sheets are available, so external problem banks supply exercise
  volume and closed-book test material instead.
- Motivation is a mix of career-relevant fluency, personal mastery, and real
  academic assessment — success criteria target "could defend this in an
  exam," not just "recognize the concept."

## Resources

- **Primary text:** Yanofsky & Mannucci, *Quantum Computing for Computer
  Scientists*. Its chapter progression (Boolean logic → complex vector spaces
  → qubits → algorithms → number theory/Shor's → beyond) maps closely onto
  this syllabus, and it's written for a CS audience rather than a physics one.
- **Exercise bank (Schaum's-equivalent):** Ronald de Wolf's *Quantum
  Computing: Lecture Notes* — free, rigorous, exercise-rich; supplies the
  problem-set volume and the Day 15 practice-exam material.
- **Reference / canonical derivations:** Nielsen & Chuang, *Quantum
  Computation and Quantum Information* — used to cross-check derivations and
  pull additional chapter-end problems.
- **Light code (occasional only):** Qiskit or plain NumPy, used only on
  flagged days (4, 11, optionally 14) for visualization/verification — never a
  daily requirement.

## Structure — interleaved (Option B)

Rather than covering the seven syllabus modules strictly in order with a solid
block of abstract linear algebra before any quantum content, math and its
quantum application are fused within the same day wherever the dependency
allows (e.g. normal-matrix spectral theory and single-qubit unitaries land on
the same day). Every day still maps to exactly one official module so lecture
cross-referencing stays possible; only the internal math/application split
within adjacent modules is tightened. This avoids the common demotivation trap
of several days of pure abstract setup with no quantum payoff, and matches the
plan's core learning principle: apply new formalism within the same session
it's introduced, not days later.

## 15-day sequence

| Day | Module(s) | Focus |
|---|---|---|
| 1 | 1a | Boolean circuits, gate universality (NAND), reversible logic (NOT/CNOT/Toffoli), reversible circuit construction, Landauer's principle |
| 2 | 1b | Complexity classes (P, NP, BPP), circuit complexity, randomized algorithms & amplification — closes Module 1 |
| 3 | 2a | Complex vector spaces from scratch: complex inner product/norm, Hermitian adjoint, unitary operators — then immediately define a qubit as a unit vector in ℂ², bra-ket notation |
| 4 | 2b + 3a | Normal matrices & spectral theorem — immediately applied to single-qubit unitaries: Pauli matrices, Hadamard, phase gates, Bloch sphere geometry. **Light code: plot single-qubit states on Bloch sphere** |
| 5 | — | **Review.** Closed-book: reversible circuits, complexity definitions, spectral theorem proof, single-qubit gates from bra-ket definitions, no notes |
| 6 | 2c + 3b | Measurement postulate, Born rule, density matrices for single qubits, basis-dependence of measurement — closes Module 2; completes single-qubit unitary transformations |
| 7 | 3c | Tensor products, composite state spaces, entanglement, Bell states, CNOT as entangler, no-cloning proof — closes Module 3 |
| 8 | 4a | Quantum parallelism properly defined (explicitly debunking "compute all branches and read them out"), Deutsch-Jozsa derived from interference |
| 9 | — | **Review.** Closed-book: entanglement/Bell-state proofs, Deutsch-Jozsa re-derivation from scratch |
| 10 | 4b | Bernstein-Vazirani, Simon's algorithm, phase kickback as the unifying mechanism — closes Module 4 |
| 11 | 5a | Grover's algorithm: oracle construction, amplitude amplification derived geometrically (rotation in a 2D real subspace). **Light code: simulate one small Grover instance** |
| 12 | 5b | Grover's optimality (BBBV lower bound intuition), generalized search — closes Module 5 |
| 13 | 6a | Number theory for Shor's (modular arithmetic, Euler's theorem, order-finding, continued fractions) + Quantum Fourier Transform derived from first principles |
| 14 | 6b | Quantum Phase Estimation built on Day 13's QFT, then full Shor's assembly (order-finding → factoring reduction → RSA implications) — closes Module 6. **Heaviest day; if it overflows, borrow from Day 15's morning** |
| 15 | 7 + capstone | BQP in the complexity landscape, adiabatic/continuous-time QC, quantum advantage claims & open problems — then full closed-book practice exam (de Wolf + N&C exercises, all 7 modules) + gap analysis mapped back to source day |

## Daily rhythm

**Content day**, 4-hour block:

- **0:00–0:25 — Primer from primary source.** Yanofsky & Mannucci chapter, or
  de Wolf's notes for that topic.
- **0:25–1:45 — Core theory/proof study.** Work through derivations by hand,
  not by reading passively.
- **1:45–1:55 — Break.**
- **1:55–3:15 — Problem set.** de Wolf exercises / N&C chapter problems,
  closed-notes where feasible.
- **3:15–3:40 — Teach-it-back.** Write the day's concept as if explaining it
  to a classmate who missed the lecture.
- **3:40–4:00 — Journal entry, module checklist tick, save point.**

**Review day** (Days 5, 9): no primer or new material — entirely closed-book
mixed problems from the phase's days, plus re-derivation of anything flagged
in the journal.

## Unconventional strategies (what the plan deliberately does differently)

| Strategy | Why it works |
|---|---|
| Derive every gate from bra-ket first principles, never memorize matrices | Memorized matrices are brittle the moment an exam question deviates from the textbook example; re-derivation builds transferable fluency |
| Classical baseline before every quantum concept | Module 1 (Boolean logic, complexity, randomization) before Module 2 is deliberate — "quantum speedup" is meaningless without a rigorous classical comparison, and skipping it leads to over- or under-claiming what quantum computers do |
| Learn algorithms via their geometric picture, not their circuit diagram | Grover's as rotation in a 2D real subspace, QPE as eigenvalue extraction via inverse QFT — what makes a 15-day pace derivable instead of memorized |
| Immediate application, same day as the abstraction | Interleaving (Option B) — new linear algebra is used to define a real quantum object within the same session, not days later, which is what actually cements abstract math |
| Teach-it-back over re-reading | Forces retrieval, exposes gaps immediately instead of false confidence from recognition |
| Closed-book timed self-tests at every phase boundary | Recognition under untimed, open-book conditions doesn't transfer to exam conditions |

## Mistakes this plan is designed to block

| Mistake | Why it wastes time | How the plan blocks it |
|---|---|---|
| Treating superposition as "classical probability with an unknown value" | The most common beginner misconception — misses that amplitudes are complex and interfere (can cancel), unlike probabilities | Day 6 explicitly separates the Born rule/measurement postulate from any classical-probability analogy before entanglement is introduced |
| Believing "quantum parallelism" means computing all branches and reading them all out | Directly contradicts no-cloning and measurement collapse; leads to wrong intuitions about every quantum algorithm that follows | Day 8 explicitly debunks this the same day quantum parallelism is introduced, before Deutsch-Jozsa is derived |
| Memorizing Grover's/Shor's as fixed circuit recipes | Brittle under any exam variant that changes the oracle or problem framing | Both are derived from their geometric/algebraic principle (rotation, eigenvalue extraction), not presented as fixed diagrams |
| Skipping the classical complexity foundations as "not real quantum stuff" | Can't reason rigorously about what quantum computers actually gain without a P/BPP/NP baseline | Module 1 is Days 1–2, before any quantum content, non-negotiable |
| Conflating physical qubit hardware with the math/CS model | This module is CS/math-assessed, not physics-assessed — hardware trivia is a time sink that isn't tested | Plan stays entirely in the abstract-qubit/circuit-model layer; no hardware implementation content included |
| Never testing under closed-book, timed conditions | False confidence from open-book problem solving | Days 5, 9, and 15 are closed-book; Day 15 is a full timed practice exam |

## Success criteria

- Can derive (not recall) the spectral theorem for normal operators and
  construct the standard single-qubit gates from it, without notes.
- Can explain, in the format of a "correcting a classmate's misconception"
  note, why superposition ≠ classical probability and why quantum
  parallelism ≠ free parallel readout.
- Can derive Deutsch-Jozsa, Bernstein-Vazirani, and Simon's algorithm from the
  phase-kickback mechanism, closed-book.
- Can derive Grover's amplitude amplification geometrically and state why it's
  optimal (BBBV), closed-book.
- Can assemble Shor's algorithm from QFT + QPE + continued fractions, tracing
  every step to a specific derivation from Days 13–14.
- Passes the Day 15 closed-book practice exam (de Wolf + N&C exercises
  spanning all 7 modules).

## Out of scope (deliberately deferred)

- Physical qubit implementations (superconducting, trapped-ion, photonic,
  etc.) — this module is assessed on the CS/math model, not hardware.
- Quantum error correction and fault tolerance — a natural, substantial
  follow-on topic, not part of this 15-day sprint.
- Quantum cryptography protocols (BB84, etc.) beyond what naturally falls out
  of Shor's RSA implications.
- Daily mandatory coding — code appears only on the three flagged days (4,
  11, and optionally 14) for intuition, per learner preference.
