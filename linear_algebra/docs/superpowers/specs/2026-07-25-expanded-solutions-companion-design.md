# Expanded Solutions Companion — Design

**Date:** 2026-07-25
**Status:** Approved design, pending spec review

## Problem

The `## Solutions` sections in the 30-day linear-algebra course are often
*too terse to follow*. A motivated self-learner frequently hits a leap: a step
asserted without the intermediate algebra, a "clearly / it follows that" that
hides real work, a proof that names a technique but does not show it, or a
result stated without saying why the step is legal. The brevity, not
incorrectness, is what makes them hard to understand.

## Goal

Produce a fuller, easier-to-comprehend version of each terse solution, laid
out so the learner can compare the original against the expanded version on
one page — **without modifying the original course files.**

## Non-goals

- Not editing theory, exercises, worked examples, or the Python code-lab
  solutions.
- Not rewriting or "improving" the original solutions in place. Originals stay
  byte-for-byte untouched.
- Not padding solutions that are already followable.
- Not covering days 28–30 (capstones — no `## Solutions` section).

## Scope

The `## Solutions` section of **`content/day01.md` through `content/day27.md`**
(days 28–30 have no exercise solutions). Roughly 290 numbered solutions across
27 files.

## Output

A new directory `content/solutions_expanded/` containing one companion file
per in-scope day: `content/solutions_expanded/dayNN.md`.

Original `content/dayNN.md` files are never edited.

### Companion file structure

Each companion file:

1. **Header** — day number/title, a one-line note on what the file is, and an
   honest **coverage line** listing which exercise numbers were judged already
   clear and therefore skipped (so the file is transparent about what it does
   and does not expand).
2. **One entry per expanded exercise**, in exercise-number order. "Expand
   only": the file includes **only** the exercises that needed expanding; the
   already-clear ones are named in the coverage line but not reproduced.

### Per-exercise entry format

Each entry is:

- A short heading: the exercise number and its statement (so the file is
  usable on its own).
- A **two-column markdown table**: left column **Original** (the existing
  solution text, verbatim), right column **Expanded** (the fuller version).

```
### Exercise 6 — is span(S) all of R^3, a plane, or a line?

| Original | Expanded |
|---|---|
| (1,2,0)+(0,1,1)=(1,3,1), the third vector, so span(S)=span of the first two; they are not scalar multiples, so a plane through the origin. | **Step 1 — spot the redundancy.** Add the first two vectors coordinate-wise: $(1,2,0)+(0,1,1)=(1,3,1)$, which is exactly the third vector, so the third adds nothing new. <br> **Step 2 — why two vectors give a plane.** The two remaining vectors are not scalar multiples … <br> **What just happened:** three vectors that *look* independent collapse to two, so the span is 2-dimensional. |
```

### Math-rendering decision (two columns + heavy LaTeX)

The user requires a two-column layout; the risk is that this course's heavy
LaTeX renders poorly in narrow table cells. Chosen "best reasonable" handling:

- **Inline math only** in cells (`$...$`), never display blocks (`$$...$$`),
  which break tables.
- **`<br>` to separate steps** within a cell — a standard markdown-table
  idiom, not an HTML document.
- **Keep matrices compact** (`\begin{pmatrix}…\end{pmatrix}` inline); acceptable
  in the viewers this course targets (GitHub, VS Code preview, Obsidian).
- **One small table per exercise** (a single content row), not one giant table
  per day — keeps each comparison readable.
- Some wrapping in cells is accepted as the cost of the required two-column
  layout.

## The bar for expanding

Expand a solution when a motivated self-learner would hit a leap:

- an algebra step is asserted without the intermediate work,
- "clearly / obviously / it follows that" hides a real step,
- a proof names a technique but does not carry it out,
- a result is stated without saying *why* the step is legal (which axiom,
  theorem, or definition licenses it).

Leave a solution unexpanded (list it in the coverage line) when every step is
already followable.

## What "expanded" contains

For each expanded solution, add, around the verbatim original:

- the skipped algebra, shown step by step;
- a statement of *why* each non-obvious step is legal (the axiom / theorem /
  definition it rests on);
- a short plain-language **"What just happened"** on the conceptually abstract
  proofs.

Additions use that day's own notation and definitions, and match the existing
voice of the course.

## Method (per day, step by step)

1. Read that day's **Theory + Exercises + Solutions together** so additions use
   the day's own notation and results.
2. Judge each solution against the bar above.
3. Write the companion file: coverage line + a two-column entry per terse
   solution.
4. **Verify every added algebra/proof step is mathematically correct** before
   moving on.

## Process

1. **Triage pass** — scan all 27 days and produce a short map: for each day,
   which exercise numbers are too terse and why. User confirms targeting before
   any companion file is written.
2. **Expansion pass** — work day by day through the triage map, generating the
   companion files.

## Success criteria

- `content/day01.md`–`day27.md` are unchanged (verifiable by diff / git).
- `content/solutions_expanded/dayNN.md` exists for each in-scope day.
- Every companion file has a coverage line accounting for all exercises.
- Each expanded entry shows the verbatim original beside a fuller version in a
  two-column table.
- Every added mathematical step is correct and uses the day's notation.
