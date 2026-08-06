# Plain-English Glossaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one plain-English lookup glossary per math-heavy path — `linear_algebra/content/GLOSSARY.md` and `quantum_computing_foundations/content/GLOSSARY.md` — so a learner who forgot a definition can recover it in under a minute.

**Architecture:** Extract-then-write. For each path, an extraction task harvests every formally defined term, named object, and symbol from the `content/dayNN.md` files into a checklist file (the coverage contract). A writing task then produces the glossary against that checklist, and a verification task reconciles the two.

**Tech Stack:** Plain markdown with inline LaTeX (`$...$`), matching the existing day files. No code, no build step.

**Spec:** `docs/superpowers/specs/2026-08-06-plain-english-glossaries-design.md`

## Global Constraints

- **Additive only.** The ONLY files created are the two `GLOSSARY.md` files and the two checklist worknote files. Every existing file in both paths remains byte-identical. Do not open existing files with Write or Edit — read-only access.
- **No git commands.** Do not run `git commit`, `git add`, `git status`, `git diff`, or any other git command in any task. The user handles version control.
- **MODEL GATE:** Before starting Task 3 (the first content-writing task), the orchestrator MUST ask the user whether to switch model for content generation (standing user preference). Tasks 1–2 (extraction worknotes) may run on the current model.
- **Entry style rule:** every definition is 1–2 lines of straight English; math symbols allowed inside, but the sentence must still make sense if the symbols were deleted.
- **Coverage rule:** every checklist term ends as either a glossary entry or an explicit exclusion with a reason. No silent drops.
- Checklist worknotes live in `docs/superpowers/worknotes/` (repo root). They are working artifacts, not learner-facing content.

---

### Task 1: Term Extraction — Linear Algebra

**Files:**
- Create: `docs/superpowers/worknotes/2026-08-06-glossary-checklist-linalg.md`
- Read only: `linear_algebra/content/day01.md` … `day30.md` (30 files)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the checklist file in the exact format below. Tasks 3 and 5 parse it by these column headers — do not rename columns.

The checklist file has exactly three sections, in this order and format:

```markdown
# Glossary Term Checklist — Linear Algebra

## Terms

| # | Term | Symbol | Day | Theme | Kind | In glossary? | Notes |
|---|------|--------|-----|-------|------|--------------|-------|
| 1 | Vector space | $V$ | 1 | Vector Spaces | definition | | |
| 2 | Kernel | $\ker T$ | 9 | Linear Maps | definition | | |

## Symbols

| Symbol | Read as | First day | Meaning sketch |
|--------|---------|-----------|----------------|
| $\ker$ | "kernel" | 9 | inputs sent to zero |

## Confusable pairs

- kernel / image — both describe a linear map's behavior; input set vs output set
```

Column rules: **Kind** is one of `definition`, `named-object` (named theorems/algorithms/decompositions like "Gram–Schmidt", "rank–nullity theorem", "SVD"), or `notation`. **Theme** is a short section name reused for glossary grouping — keep the set of themes small (roughly 6–10), each covering a contiguous day range. **In glossary?** and **Notes** stay empty; Task 5 fills them.

- [ ] **Step 1: Create the checklist file**

Write `docs/superpowers/worknotes/2026-08-06-glossary-checklist-linalg.md` containing the three-section skeleton above (headers plus empty tables, no example rows).

- [ ] **Step 2: Harvest days 1–8**

Read `linear_algebra/content/day01.md` through `day08.md`. For each file, append one Terms row per formally defined term (anything introduced as a Definition, given a bold/italic first use with a meaning, or named in a theorem statement), and one Symbols row per new symbol. Record the day number and assign a Theme.

- [ ] **Step 3: Harvest days 9–16**

Same procedure for `day09.md` through `day16.md`. Skip pure-review days (they introduce no new terms — note them in a one-line comment under the Terms table, e.g. `<!-- Days 7, 13 reviewed: no new terms -->`).

- [ ] **Step 4: Harvest days 17–24**

Same procedure for `day17.md` through `day24.md`.

- [ ] **Step 5: Harvest days 25–30**

Same procedure for `day25.md` through `day30.md`.

- [ ] **Step 6: Finalize confusable pairs**

Fill the "Confusable pairs" section. Start from the spec's candidates — kernel/image, span/basis, rank/nullity, eigenvalue/eigenvector, row space/column space, injective/surjective, similar/congruent — keep those that actually appear in the harvested terms, drop those that don't, and add any new pair where two harvested terms are easily conflated. Each pair gets a one-line reason.

- [ ] **Step 7: Verify the checklist against expectations**

Check: (a) every day 1–30 is either represented by ≥1 row or listed in the review-day comment; (b) total Terms rows land in the ballpark of 100–150 (if far outside, re-scan the outlier days before proceeding); (c) every Theme covers a contiguous day range; (d) no duplicate Term rows (same concept harvested twice on different days → keep the defining day, note the reappearance in Notes).

---

### Task 2: Term Extraction — Quantum Computing

**Files:**
- Create: `docs/superpowers/worknotes/2026-08-06-glossary-checklist-quantum.md`
- Read only: `quantum_computing_foundations/content/day01.md` … `day15.md` (15 files)

**Interfaces:**
- Consumes: nothing (independent of Task 1; may run in parallel with it).
- Produces: checklist file in the **identical** three-section format defined in Task 1 (Terms / Symbols / Confusable pairs, same column headers). Tasks 4 and 6 parse it by those headers.

- [ ] **Step 1: Create the checklist file**

Write `docs/superpowers/worknotes/2026-08-06-glossary-checklist-quantum.md` with the same three-section skeleton as Task 1 Step 1, titled `# Glossary Term Checklist — Quantum Computing`.

- [ ] **Step 2: Harvest days 1–5**

Read `quantum_computing_foundations/content/day01.md` through `day05.md`; append Terms and Symbols rows per the Task 1 harvesting procedure. Quantum notation is dense — be exhaustive in the Symbols table: kets/bras, tensor product, dagger, Pauli matrices, common gate symbols (H, CNOT, etc.), measurement notation.

- [ ] **Step 3: Harvest days 6–10**

Same procedure for `day06.md` through `day10.md`.

- [ ] **Step 4: Harvest days 11–15**

Same procedure for `day11.md` through `day15.md`.

- [ ] **Step 5: Finalize confusable pairs**

Start from the spec's candidates — bra/ket, superposition/entanglement, unitary/Hermitian, pure/mixed state, gate/measurement, global/relative phase — keep, drop, and add per what was actually harvested. One-line reason per pair.

- [ ] **Step 6: Verify the checklist against expectations**

Check: (a) every day 1–15 represented or noted as review-only; (b) Terms rows in the ballpark of 60–90; (c) themes contiguous; (d) no duplicate rows.

---

### Task 3: Write `linear_algebra/content/GLOSSARY.md`

⚠️ **MODEL GATE:** confirm with the user whether to switch model before starting this task.

**Files:**
- Create: `linear_algebra/content/GLOSSARY.md`
- Read only: `docs/superpowers/worknotes/2026-08-06-glossary-checklist-linalg.md`; individual `linear_algebra/content/dayNN.md` files as needed to phrase entries faithfully.

**Interfaces:**
- Consumes: the checklist's Terms/Symbols/Confusable-pairs tables (Task 1 format).
- Produces: the finished glossary. Task 5 verifies it against the checklist — every entry's bold term should match its checklist Term text so reconciliation is mechanical.

The file layout, top to bottom:

```markdown
# Glossary — Linear Algebra

*Lookup for catch-up: scan for the term you forgot — this is not meant to be read in order. Full treatments live in the day files named in each section header.*

## Notation at a glance

| Symbol | Read as | Meaning |
|--------|---------|---------|
| $\ker T$ | "kernel of T" | the inputs T sends to zero |

## Jump index

[Vector Spaces (Days 1–4)](#vector-spaces-days-14) · [Linear Maps (Days 9–12)](#linear-maps-days-912) · …

## Vector Spaces (Days 1–4)

**Vector space ($V$)** — A set of objects you can add together and scale by numbers, where those operations behave the way arrow-addition and stretching do.

**Kernel ($\ker T$)** — All vectors $v$ where $T(v) = 0$; the inputs that get crushed to zero. It is the null space of the matrix.

> **Kernel vs Image**
>
> | | Kernel | Image |
> |---|---|---|
> | It is… | the input set | the output set |
> | Lives in… | the domain | the codomain |
> | Shows… | what goes to zero | what is reachable |
> | Matrix view | null space | span of pivot columns |
```

Entry rules (from the spec, restated so this task is self-contained):
- Format: `**Term ($symbol$)** — definition.` Symbol parenthetical omitted when no standard symbol exists.
- 1–2 lines of straight English; the sentence must survive with the math symbols deleted.
- Entries within a section appear in the order the path introduces them (checklist Day order), not alphabetically — the jump index handles navigation.
- Contrast boxes are blockquoted tables placed immediately after the second member of the pair, with 3–5 comparison rows each.

- [ ] **Step 1: Write header, notation table, and jump index**

Create the file with the how-to-use line, then the full "Notation at a glance" table — one row per Symbols-table row in the checklist, columns Symbol / Read as / Meaning — then the jump index with one link per Theme in the checklist, each labeled `Theme (Days N–M)`.

- [ ] **Step 2: Write the first half of the theme sections**

For each of the first half of the themes (by day order): a `## Theme (Days N–M)` header, then one entry per checklist row in that theme, following the entry rules. Consult the relevant day file whenever unsure how the path defines a term — the glossary must match the path's terminology, not generic textbook phrasing.

- [ ] **Step 3: Write the remaining theme sections**

Same procedure for the remaining themes.

- [ ] **Step 4: Insert contrast boxes**

For each pair in the checklist's Confusable-pairs section, insert a blockquoted contrast table immediately after the later-introduced member's entry. Rows drawn from: *It is… / Lives in… / Shows… / Matrix view / Compute it by…* — pick the 3–5 that genuinely differ for that pair.

- [ ] **Step 5: Self-check against the checklist**

Walk the checklist top to bottom: every Term row has a matching bold entry (or you deliberately excluded it — keep a private list of exclusions and reasons for the task report); every Symbols row appears in the notation table; every confusable pair has a contrast box; jump-index anchors resolve to real headers. Fix anything missing before finishing.

---

### Task 4: Write `quantum_computing_foundations/content/GLOSSARY.md`

**Files:**
- Create: `quantum_computing_foundations/content/GLOSSARY.md`
- Read only: `docs/superpowers/worknotes/2026-08-06-glossary-checklist-quantum.md`; individual `quantum_computing_foundations/content/dayNN.md` files as needed.

**Interfaces:**
- Consumes: the quantum checklist (Task 2 format).
- Produces: the finished glossary; Task 6 reconciles entries against checklist Term text.

The file layout, top to bottom:

```markdown
# Glossary — Quantum Computing Foundations

*Lookup for catch-up: scan for the term you forgot — this is not meant to be read in order. Full treatments live in the day files named in each section header.*

## Notation at a glance

| Symbol | Read as | Meaning |
|--------|---------|---------|
| $|\psi\rangle$ | "ket psi" | a quantum state, written as a column vector |
| $\langle\phi|$ | "bra phi" | the dual of a ket, written as a row vector |

## Jump index

[Qubits & States (Days 1–3)](#qubits--states-days-13) · [Gates (Days 4–6)](#gates-days-46) · …

## Qubits & States (Days 1–3)

**Superposition** — A state that is a weighted mix of basis states at once; the weights are complex numbers whose squared sizes give measurement probabilities.

> **Bra vs Ket**
>
> | | Ket $|\psi\rangle$ | Bra $\langle\psi|$ |
> |---|---|---|
> | It is… | a state | its dual |
> | Math object | column vector | row vector (conjugate transpose) |
> | Combine as… | $\langle\phi|\psi\rangle$ = inner product | $|\psi\rangle\langle\phi|$ = outer product |
```

Entry rules (restated so this task is self-contained):
- Format: `**Term ($symbol$)** — definition.` Symbol parenthetical omitted when no standard symbol exists.
- 1–2 lines of straight English; the sentence must survive with the math symbols deleted.
- Entries within a section appear in the order the path introduces them (checklist Day order), not alphabetically — the jump index handles navigation.
- Contrast boxes are blockquoted tables placed immediately after the second member of the pair, with 3–5 comparison rows each. Row labels drawn from: *It is… / Lives in… / Shows… / Math object / Compute it by…* — pick the 3–5 that genuinely differ for that pair.

The notation table matters even more here than in linear algebra — it must decode every piece of Dirac notation, gate symbol, and operator decoration ($|\psi\rangle$, $\langle\phi|$, $\otimes$, $\dagger$, $\oplus$, Pauli $X/Y/Z$, $H$, CNOT, measurement symbols) harvested in the checklist.

- [ ] **Step 1: Write header, notation table, and jump index**

Create the file with the how-to-use line, then the full "Notation at a glance" table — one row per Symbols-table row in the checklist, columns Symbol / Read as / Meaning — then the jump index with one link per Theme in the checklist, each labeled `Theme (Days N–M)`.

- [ ] **Step 2: Write the first half of the theme sections**

For each of the first half of the themes (by day order): a `## Theme (Days N–M)` header, then one entry per checklist row in that theme, following the entry rules. Consult the relevant day file whenever unsure how the path defines a term — the glossary must match the path's terminology, not generic textbook phrasing.

- [ ] **Step 3: Write the remaining theme sections**

Same procedure for the remaining themes.

- [ ] **Step 4: Insert contrast boxes**

For each pair in the checklist's Confusable-pairs section, insert a blockquoted contrast table immediately after the later-introduced member's entry, per the contrast-box rule above.

- [ ] **Step 5: Self-check against the checklist**

Walk the checklist top to bottom: every Term row has a matching bold entry (or you deliberately excluded it — keep a private list of exclusions and reasons for the task report); every Symbols row appears in the notation table; every confusable pair has a contrast box; jump-index anchors resolve to real headers. Fix anything missing before finishing.

---

### Task 5: Verify Linear Algebra Glossary

**Files:**
- Modify: `docs/superpowers/worknotes/2026-08-06-glossary-checklist-linalg.md` (fill "In glossary?" and "Notes" columns ONLY — this is the sole permitted modification of an existing file in the whole plan, and it is a worknote, not learner content)
- Read only: `linear_algebra/content/GLOSSARY.md`

**Interfaces:**
- Consumes: Task 1's checklist and Task 3's glossary.
- Produces: a fully reconciled checklist (no empty "In glossary?" cells) and a verification verdict: PASS, or a defect list for Task 3 rework.

- [ ] **Step 1: Reconcile terms**

For every Terms row, search the glossary for the term. Fill "In glossary?" with `yes` or `excluded`; for `excluded`, the Notes cell must state the reason (e.g., "synonym of row 12, covered there"). Zero empty cells when done.

- [ ] **Step 2: Reconcile symbols and pairs**

Confirm every Symbols row appears in the notation table and every Confusable pair has a contrast box. Note any misses.

- [ ] **Step 3: Style audit**

Sample every 5th entry plus all contrast boxes and check: entry format matches `**Term ($symbol$)** — definition.`; each definition is 1–2 lines; each sentence still makes sense with the math symbols deleted; jump-index links anchor correctly.

- [ ] **Step 4: Confirm additivity and report**

Confirm this task wrote to nothing except the checklist's two columns, and that Tasks 1–4 created only the four planned new files. Report PASS or the defect list (each defect: checklist row / glossary location, what is wrong, what the fix is).

---

### Task 6: Verify Quantum Glossary

**Files:**
- Modify: `docs/superpowers/worknotes/2026-08-06-glossary-checklist-quantum.md` ("In glossary?" and "Notes" columns only)
- Read only: `quantum_computing_foundations/content/GLOSSARY.md`

**Interfaces:**
- Consumes: Task 2's checklist and Task 4's glossary.
- Produces: reconciled checklist + PASS/defect-list verdict, same shape as Task 5.

- [ ] **Step 1: Reconcile terms**

For every Terms row in the quantum checklist, search the glossary for the term. Fill "In glossary?" with `yes` or `excluded`; for `excluded`, the Notes cell must state the reason (e.g., "synonym of row 12, covered there"). Zero empty cells when done.

- [ ] **Step 2: Reconcile symbols and pairs**

Confirm every Symbols row appears in the notation table and every Confusable pair has a contrast box. Note any misses.

- [ ] **Step 3: Style audit**

Sample every 5th entry plus all contrast boxes and check: entry format matches `**Term ($symbol$)** — definition.`; each definition is 1–2 lines; each sentence still makes sense with the math symbols deleted; jump-index links anchor correctly.

- [ ] **Step 4: Confirm additivity and report**

Confirm this task wrote to nothing except the checklist's two columns, and that Tasks 1–4 created only the four planned new files. Report PASS or the defect list (each defect: checklist row / glossary location, what is wrong, what the fix is).

---

## Execution Notes

- Order: Tasks 1 and 2 can run in parallel. Task 3 depends on Task 1; Task 4 on Task 2; Task 5 on Task 3; Task 6 on Task 4. The two path pipelines (1→3→5 and 2→4→6) are independent.
- **The MODEL GATE sits between the extraction tasks and Task 3/4** — do not dispatch any content-writing task before the user answers.
- If Task 5 or 6 returns defects, apply fixes to the glossary file only, then re-run the failed verification steps.
- Success criteria (from spec): any defined term findable in one file in under a minute; every path symbol in the notation table; checklist fully reconciled.
