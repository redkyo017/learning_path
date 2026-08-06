/# Quantum Computing Foundations — Content Feasibility & Primer-Readiness Review (Design)

**Date:** 2026-08-05
**Status:** Approved design, awaiting implementation plan
**Target path:** `quantum_computing_foundations/`
**Rubric for Part 2:** `docs/superpowers/guides/encoding-primers-playbook.md` (repo root)

## Purpose

Produce a single review report that (1) audits the 15-day quantum computing
path for correctness and feasibility, and (2) assesses its readiness for an
encoding-primers companion built per the playbook. One report drives both the
content-fix decisions and the future primer plan. This is a review: no
existing file is modified; all fixes await explicit user approval.

## Scope and inputs

- `content/day01.md` … `content/day15.md` (~6,470 lines total)
- `content/README.md` (index, module map, code-lab notes)
- `docs/superpowers/specs/2026-07-13-quantum-computing-15-day-plan-design.md`
- `docs/superpowers/plans/2026-07-13-quantum-computing-15-day-plan.md`
- `code/day04_bloch_sphere.py`, `code/day11_grover_simulation.py`,
  `code/day14_shors_qpe_simulation.py` — **read-only**; scripts are not
  executed. If content changes are approved later, labs are updated then.

## Part 1 — Content feasibility audit (full depth)

Every day file is checked on four axes:

1. **Mathematical correctness.** Every definition, theorem statement, proof,
   circuit claim, and complexity claim is verified. Full-depth audit — no
   sampling.
2. **Internal consistency.** Label numbering, cross-references between days,
   exercise↔solution match, notation consistency across days.
3. **Prerequisite ordering.** No concept used before the day that introduces
   it; the module map in the README matches actual file contents.
4. **Time-budget realism.** The plan's stated per-day hours versus what each
   file's length and proof density realistically demand, with a corrected
   total estimate (same style as the linear algebra review, which found
   ~135–145h against a claimed 120h).

Code labs get a static check: imports, logic, and whether the expected
outputs documented in the content files and plan match what the code would
actually print. Mismatches are findings, not fixes.

## Part 2 — Primer-readiness assessment

Three deliverables, in the same report:

1. **Domain-context block** — the playbook's five new-subject questions
   answered for this path: citation format actually used in the day files;
   natural picture types (circuit diagrams, Bloch sphere states, amplitude
   bars); section-5 name (**Derivation roadmaps**, per the playbook's
   Quantum/Physics row); path structure (sequential); Day 1 warm-up omission.
2. **Per-day primer-ability verdict** — for each day: does it have citable
   labels a walkthrough can reference, and a concrete numeric example a hook
   can be built from? Gaps become findings.
3. **Warm-up schedule table** — which 3 prior days each primer names, with
   special-day handling. Proposal adopted in the design: **no primers for
   Days 5 and 9** (closed-book review days — a primer restating the material
   would defeat their purpose) **nor for Day 15's exam portion**; Day 15's
   "beyond discrete-time QC" theory section may merit a primer, to be decided
   by the verdict in deliverable 2. The schedule skips review days when
   naming warm-up back-days.

Part 2 closes with a cross-reference list: which Part-1 findings, if fixed,
would change primer briefs.

## Execution

- Analysis runs on the strong model; parallel review agents are dispatched
  (a batch of a few days per agent) to keep wall-clock reasonable.
- No git commands in agent dispatches.
- Model-switch rule: docs files (this spec, the plan, the report) are written
  with the current model; any future learner-facing content or code writing
  pauses first so the user can switch to a cheaper model.

## Output

One report: `docs/superpowers/reviews/2026-08-05-content-and-primer-readiness-review.md`
(under `quantum_computing_foundations/`), structured as:

1. Verdict summary (one paragraph + severity counts)
2. Findings ranked by severity: correctness errors → feasibility risks →
   consistency nits
3. Corrected time-budget table
4. Primer-readiness section (domain-context block, per-day verdicts,
   warm-up schedule)
5. Proposed fix list, awaiting user approval

No commits — the user handles version control.

## Success criteria

- All 15 day files audited on all four axes; all 3 labs statically checked.
- Every finding cites file and location precisely enough to act on.
- The primer-readiness section contains everything the playbook's
  "Quick checklist for a new subject" requires to dispatch implementers,
  with no further discovery needed.
