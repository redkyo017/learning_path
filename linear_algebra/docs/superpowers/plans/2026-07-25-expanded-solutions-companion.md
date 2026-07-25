# Expanded Solutions Companion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a fuller, easier-to-comprehend companion version of every terse exercise solution in the linear-algebra course (days 1–27), laid out for side-by-side comparison, without touching any original file.

**Architecture:** A triage pass first maps which solutions are too terse; then a per-day expansion pass writes one companion file per day under a new `content/solutions_expanded/` directory. Originals are read-only throughout; each companion file presents, per expanded exercise, a two-column table (verbatim original | expanded walk-through).

**Tech Stack:** Markdown with inline LaTeX (`$...$`); optional Python 3 + NumPy for numerical sanity-checks of computational solutions (venv already present via `requirements.txt`).

## Global Constraints

- **Never edit `content/day01.md`–`content/day30.md`** or any file outside `content/solutions_expanded/` and `docs/superpowers/`. Originals must remain byte-for-byte identical.
- **No git commits.** This directory is not a git repo and the user handles all version control. Replace every "commit" with a review checkpoint.
- **Scope is days 1–27 only.** Days 28–30 have no `## Solutions` section — skip them.
- **Two-column layout is required.** Left column = verbatim original solution, right column = expanded. Original text is copied exactly, never reworded.
- **Cell math rules:** inline math only (`$...$`), never display blocks (`$$...$$`); separate steps with `<br>`; keep matrices compact inline (`\begin{pmatrix}…\end{pmatrix}`). One small table per exercise.
- **"Expand only":** a companion file reproduces only the exercises judged too terse; already-clear ones are named in a coverage line, not reproduced.
- **Every added mathematical step must be verified correct** and must use that day's own notation and results.

---

## Per-Day Procedure (shared by all expansion tasks)

Every expansion task (Tasks 3–28) applies this exact procedure to its day. It is written out in full here so each task need only name its day and its triage entry.

**Companion file skeleton** (`content/solutions_expanded/dayNN.md`):

```markdown
# Day N — Expanded Solutions

Companion to `content/dayNN.md`. The **Original** column reproduces each
solution verbatim; the **Expanded** column fills in the skipped steps, states
why each step is legal, and adds a plain-language recap on the abstract ones.
Only solutions that were too terse to follow are reproduced here.

**Coverage:** expanded — 3, 6, 9, 10. Already clear (not reproduced) — 1, 2, 4, 5, 7, 8.

---

### Exercise 6 — <short restatement of the problem>

| Original | Expanded |
|---|---|
| <verbatim original solution text, inline math> | **Step 1 — <label>.** <shown algebra>. <br> **Step 2 — <label>.** <why this step is legal: which axiom/theorem/definition>. <br> **What just happened:** <one-sentence plain-language recap>. |

### Exercise 9 — <short restatement>

| Original | Expanded |
|---|---|
| … | … |
```

**Steps for the day (repeat per day):**

1. Read `content/dayNN.md` in full — Theory, Exercises, and Solutions — plus that day's entry in `content/solutions_expanded/TRIAGE.md`.
2. For each exercise flagged terse in the triage entry, draft the two-column row: copy the original solution **verbatim** into the left cell; write the expanded walk-through in the right cell (skipped algebra shown, each non-obvious step justified by the day's axiom/theorem/definition, a "What just happened" recap on abstract proofs).
3. Write the coverage line naming every exercise as either expanded or already-clear (the two lists together must equal the full exercise set).
4. **Verify** (the content-test cycle) — see the verification steps embedded in each task.

---

## Task 1: Triage pass — map terse solutions across all 27 days

**Files:**
- Create: `content/solutions_expanded/TRIAGE.md`
- Read only: `content/day01.md`–`content/day27.md`

**Interfaces:**
- Produces: `TRIAGE.md`, a per-day list consumed by every expansion task. Format per day: `## Day N` then a table with columns `Exercise | Verdict (expand/clear) | Reason`.

- [ ] **Step 1: Read every in-scope Solutions section**

Read the `## Solutions` section of each `content/dayNN.md` for N = 1..27, together with that day's exercises so terseness is judged in context.

- [ ] **Step 2: Classify each solution against the bar**

Flag `expand` when a step is asserted without intermediate algebra, "clearly/obviously/it follows" hides work, a proof names a technique without carrying it out, or a step's legality (axiom/theorem/definition) is unstated. Otherwise `clear`.

- [ ] **Step 3: Write `TRIAGE.md`**

One `## Day N` section per day, each a `Exercise | Verdict | Reason` table covering every numbered solution in that day.

- [ ] **Step 4: Verify coverage**

Run: `cd content && for f in day{01..27}.md; do echo -n "$f exercises: "; grep -c '^\*\*[0-9]' "$f"; done`
Expected: for each day, the count of numbered solutions equals the number of rows for that day in `TRIAGE.md`. Cross-check that no exercise is missing.

- [ ] **Step 5: Checkpoint**

Present `TRIAGE.md` to the user for confirmation of targeting before writing any companion files. (No commit.)

---

## Task 2: Pilot — day 1 companion file (locks the format)

**Files:**
- Create: `content/solutions_expanded/day01.md`
- Read only: `content/day01.md`, `content/solutions_expanded/TRIAGE.md`

**Interfaces:**
- Consumes: the day-1 entry of `TRIAGE.md`.
- Produces: the canonical companion-file format that Tasks 3–28 copy.

- [ ] **Step 1: Apply the Per-Day Procedure to day 1**

Follow the shared Per-Day Procedure above for `content/day01.md`, producing `content/solutions_expanded/day01.md`.

- [ ] **Step 2: Verify originals untouched**

Run: `ls -la content/day01.md && wc -c content/day01.md`
Expected: `content/day01.md` was never opened for writing; byte count unchanged from before the task. Only `content/solutions_expanded/day01.md` is new.

- [ ] **Step 3: Verify coverage line is complete**

Confirm the coverage line's `expanded` + `already clear` lists together equal all 10 day-1 exercises, with none listed twice.

- [ ] **Step 4: Verify the math**

Re-derive each added algebra step by hand. For the computational ones (e.g. span-membership in Ex. 6–7), sanity-check numerically:
Run: `cd .. && python -c "import numpy as np; print(np.allclose(np.array([2,3,5.]), 2*np.array([1,0,1.])+3*np.array([0,1,1.])))"`
Expected: `True` (confirms the Ex-worked coefficients).

- [ ] **Step 5: Verify format**

Confirm: one two-column table per expanded exercise; left cell text matches the original verbatim; cells use inline `$...$` only (no `$$`), steps separated by `<br>`.

- [ ] **Step 6: Checkpoint**

Present `day01.md` to the user as the format exemplar. Adjust the shared skeleton if the user wants changes, since Tasks 3–28 will follow it. (No commit.)

---

## Tasks 3–28: Per-day expansion (days 2–27)

Each task below applies the **Per-Day Procedure** and the **same five verification steps as Task 2** (originals untouched → coverage line complete → math re-derived, numeric sanity-check where computational → format check → checkpoint) to one day. The day-specific input is that day's `TRIAGE.md` entry. No commits.

Grouped by course arc for navigation; each remains an independently reviewable task with its own deliverable file `content/solutions_expanded/dayNN.md`.

**Phase A — Foundations (subspaces, transformations, elimination)**

- [ ] **Task 3: Day 2** — `content/solutions_expanded/day02.md` (basis, dimension, ~11 solutions)
- [ ] **Task 4: Day 3** — `day03.md` (linear transformations, ~10)
- [ ] **Task 5: Day 4** — `day04.md` (rank–nullity, ~10)
- [ ] **Task 6: Day 5** — `day05.md` (Gaussian elimination, ~10)
- [ ] **Task 7: Day 6** — `day06.md` (four subspaces, ~9)
- [ ] **Task 8: Day 7** — `day07.md` (review/consolidation, ~20 solutions — larger)

**Phase B — Determinants, inverses, eigenvalues**

- [ ] **Task 9: Day 8** — `day08.md` (determinants, ~10)
- [ ] **Task 10: Day 9** — `day09.md` (inverse, LU, ~9)
- [ ] **Task 11: Day 10** — `day10.md` (eigen basics, ~10)
- [ ] **Task 12: Day 11** — `day11.md` (diagonalization, ~10)
- [ ] **Task 13: Day 12** — `day12.md` (diagonalization applications, ~8)
- [ ] **Task 14: Day 13** — `day13.md` (review/consolidation, ~17 — larger)

**Phase C — Inner products & orthogonality**

- [ ] **Task 15: Day 14** — `day14.md` (inner products, ~10)
- [ ] **Task 16: Day 15** — `day15.md` (Gram–Schmidt, ~10)
- [ ] **Task 17: Day 16** — `day16.md` (least squares, ~10)
- [ ] **Task 18: Day 17** — `day17.md` (QR decomposition, ~9)
- [ ] **Task 19: Day 18** — `day18.md` (review/consolidation, ~16 — larger)
- [ ] **Task 20: Day 19** — `day19.md` (spectral theorem, ~10)
- [ ] **Task 21: Day 20** — `day20.md` (quadratic forms, ~10)

**Phase D — SVD, PCA, change of basis**

- [ ] **Task 22: Day 21** — `day21.md` (SVD from scratch, ~10)
- [ ] **Task 23: Day 22** — `day22.md` (SVD low-rank, ~8)
- [ ] **Task 24: Day 23** — `day23.md` (PCA from scratch, ~8)
- [ ] **Task 25: Day 24** — `day24.md` (review/consolidation, ~14 — larger)
- [ ] **Task 26: Day 25** — `day25.md` (change of basis, ~6)
- [ ] **Task 27: Day 26** — `day26.md` (trace/det/Cholesky, ~5)
- [ ] **Task 28: Day 27** — `day27.md` (review/consolidation, ~16 — larger)

**Per-task step template (identical for Tasks 3–28), shown once in full:**

- [ ] **Step 1:** Read `content/dayNN.md` (Theory + Exercises + Solutions) and the day's `TRIAGE.md` entry.
- [ ] **Step 2:** Apply the Per-Day Procedure → write `content/solutions_expanded/dayNN.md` (coverage line + one two-column table per terse exercise, original verbatim left, expanded right).
- [ ] **Step 3:** Verify originals untouched (`wc -c content/dayNN.md` unchanged; only the new companion file created).
- [ ] **Step 4:** Verify coverage line accounts for every exercise exactly once (expanded ∪ clear = all, disjoint).
- [ ] **Step 5:** Re-derive every added step; for computational solutions, numeric sanity-check with a one-line `python -c` NumPy check.
- [ ] **Step 6:** Verify format (two-column table per exercise, verbatim left cell, inline `$...$` only, `<br>` step breaks).
- [ ] **Step 7:** Review checkpoint (no commit).

---

## Task 29: Final verification sweep

**Files:**
- Read only: all of `content/` and `content/solutions_expanded/`

- [ ] **Step 1: Confirm all in-scope companion files exist**

Run: `ls content/solutions_expanded/day{01..27}.md`
Expected: all 27 files listed, none missing.

- [ ] **Step 2: Confirm originals unchanged**

Run: `cd content && ls day{01..30}.md` and confirm modification times predate this work (or compare byte counts to a snapshot taken before Task 1).
Expected: no original `dayNN.md` modified.

- [ ] **Step 3: Confirm no stray display math in tables**

Run: `grep -l '\$\$' content/solutions_expanded/*.md || echo "none"`
Expected: `none` (all math is inline per the cell rules).

- [ ] **Step 4: Spot-check three companion files**

Open the day-7, day-19, and day-27 companion files and confirm each has a complete coverage line and correctly-rendering two-column tables.

- [ ] **Step 5: Final checkpoint**

Report completion to the user with the list of created files. (No commit — user handles VCS.)

---

## Self-Review

- **Spec coverage:** scope (days 1–27) → Tasks 1–28; output dir + companion files → Tasks 2–28; two-column layout + verbatim original → Global Constraints + Per-Day Procedure + format-check steps; "expand only" + coverage line → Per-Day Procedure step 3 and every task's coverage-check step; math-rendering decision → Global Constraints cell rules + Step "verify format"; math correctness → every task's re-derivation step; originals untouched → Global Constraints + every task's "originals untouched" step + Task 29. All spec sections mapped.
- **Placeholder scan:** the `<…>` angle-bracket tokens in the skeleton are illustrative template fields, not plan placeholders — the actual content is produced per day from real exercises. No "TBD/TODO/handle edge cases" left.
- **Type consistency:** file paths (`content/solutions_expanded/dayNN.md`), the `TRIAGE.md` artifact name, and the coverage-line vocabulary ("expanded"/"already clear") are used consistently across Task 1, the Per-Day Procedure, and Tasks 2–29.
