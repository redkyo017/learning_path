# Quantum Path Content & Primer-Readiness Review — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce one review report auditing all 15 quantum-path day files for correctness/feasibility and assessing primer-readiness per the encoding-primers playbook.

**Architecture:** Five parallel batch-audit agents (3 days each) write per-day findings files; one cross-day agent checks global consistency; the orchestrator then does the time-budget analysis, primer-readiness synthesis, and report assembly inline.

**Tech Stack:** Review agents (read-only), bash/grep verification, markdown outputs. No code is executed.

## Global Constraints

- **Review only** — no file under `content/` or `code/` is modified. The only writes are new files under `docs/superpowers/reviews/` (findings + final report).
- **No git commands anywhere** — not by the orchestrator, not in any agent dispatch. The user handles version control.
- **Code labs are read-only** — statically checked, never executed.
- **Full audit depth** — every definition, claim, lemma, proof, circuit claim, and complexity claim in every day file is verified; no sampling.
- All paths below are relative to `quantum_computing_foundations/` unless absolute.
- Findings severity scale (used everywhere): **CRITICAL** = mathematical/factual error a learner would absorb; **MAJOR** = feasibility risk (time budget, missing prerequisite, broken exercise↔solution pairing); **MINOR** = consistency nit (notation drift, phrasing, cross-reference off).
- Reference documents: spec at `docs/superpowers/specs/2026-08-05-content-and-primer-readiness-review-design.md`; primer rubric at repo root `../docs/superpowers/guides/encoding-primers-playbook.md`.

---

### Task 1: Structure and label inventory

**Files:**
- Create: `docs/superpowers/reviews/findings/inventory.md`
- Read: `content/day01.md` … `content/day15.md`, `content/README.md`

**Interfaces:**
- Produces: `findings/inventory.md` — per day: `##`/`###` heading list, bold named labels (`**Claim …:**`, `**Lemma: …**`, etc.), exercise count, solution count, worked-example presence, line count. Consumed by Tasks 2, 3, 5.

- [ ] **Step 1: Generate the raw inventory** (orchestrator, inline)

Run from `quantum_computing_foundations/content/`:

```bash
for f in day01.md day02.md day03.md day04.md day05.md day06.md day07.md \
         day08.md day09.md day10.md day11.md day12.md day13.md day14.md day15.md; do
  echo "## $f"
  echo "lines: $(wc -l < $f)"
  echo "### headings"; grep -nE "^##+ " $f
  echo "### named labels"; grep -nE "^\*\*(Definition|Theorem|Lemma|Proposition|Corollary|Claim|Postulate|Fact|Principle)[^*]*\*\*" $f || echo "(none)"
  echo "### exercises"; grep -cE "^[0-9]+\. " $f
  echo
done
```

- [ ] **Step 2: Write `findings/inventory.md`** — paste the output, organized per day, and add a one-line note per day naming its worked example (from the `## Worked example` section) if present.

- [ ] **Step 3: Verify** — `grep -c "^## day" docs/superpowers/reviews/findings/inventory.md` must equal 15.

---

### Task 2: Parallel batch audits (5 agents)

**Files:**
- Create: `docs/superpowers/reviews/findings/day01.md` … `findings/day15.md` (one per day, written by agents)
- Read (agents): assigned day files, `content/README.md`, `findings/inventory.md`, assigned code lab if any

**Interfaces:**
- Consumes: `findings/inventory.md` (Task 1)
- Produces: 15 findings files in the exact format given in the prompt below. Consumed by Tasks 3, 4, 5, 6.

- [ ] **Step 1: Dispatch all five agents in parallel** using this prompt, substituting from the table below:

| Batch | [DAYS] | [FILES] | [CODELAB] |
|---|---|---|---|
| A | 1, 2, 3 | day01.md day02.md day03.md | (none) |
| B | 4, 5, 6 | day04.md day05.md day06.md | `code/day04_bloch_sphere.py` (belongs to day 4) |
| C | 7, 8, 9 | day07.md day08.md day09.md | (none) |
| D | 10, 11, 12 | day10.md day11.md day12.md | `code/day11_grover_simulation.py` (belongs to day 11) |
| E | 13, 14, 15 | day13.md day14.md day15.md | `code/day14_shors_qpe_simulation.py` (belongs to day 14) |

Prompt template (fill [DAYS], [FILES], [CODELAB]; all paths relative to `quantum_computing_foundations/`):

```
You are auditing days [DAYS] of a 15-day quantum computing learning path.
READ-ONLY review: modify nothing except the findings files you create.
Run NO git commands. Do NOT execute any code.

Read fully: content/[each of FILES], content/README.md,
docs/superpowers/reviews/findings/inventory.md.
Code lab to statically check: [CODELAB].

For EACH assigned day, verify at full depth — every definition, named claim,
lemma, proof, circuit claim, and complexity claim. Re-derive the math yourself
step by step; do not trust the file. Check:

1. CORRECTNESS — wrong statements, broken proofs, wrong matrices/amplitudes/
   probabilities, wrong complexity claims, wrong physics.
2. INTERNAL CONSISTENCY — every exercise has a matching solution and the
   solution actually solves the stated exercise; cross-references to other
   days/files resolve; notation consistent within the file.
3. PREREQUISITES — every concept used is introduced in this file or an
   earlier day (use inventory.md to check where things are introduced).
4. TIME-BUDGET NOTES — estimate honest completion hours for the day given
   its length and proof density (state your assumption for learner level:
   comfortable with linear algebra, new to quantum).
5. CODE LAB (only the day that owns [CODELAB]) — static check: do imports,
   logic, and printed output match what the content file and README claim?
6. PRIMER-ABILITY — does this day have (a) citable named labels or clear
   ### section names a primer walkthrough can reference, and (b) a concrete
   numeric example usable as a primer hook? Quote the best hook candidate.

Write ONE findings file per day at
docs/superpowers/reviews/findings/dayNN.md (NN zero-padded), exact format:

# Day NN findings
## Correctness
- [NN-C1] CRITICAL|MAJOR|MINOR — content/dayNN.md:<line> — <claim> — <why wrong> — <suggested fix>
(or "- none")
## Consistency
(same bullet format, IDs NN-S1, NN-S2, …)
## Prerequisites
(same bullet format, IDs NN-P1, …)
## Time budget
- estimated hours: <N–M h> — <one-line justification>
## Code lab
(same bullet format, IDs NN-L1, …; or "- not applicable")
## Primer-ability
- citable labels: yes|partial|no — <examples of labels present>
- hook candidate: <quoted concrete example with numbers, and its line number>

Final message: one line per day — "dayNN: X critical / Y major / Z minor,
est hours H". Nothing else.
```

- [ ] **Step 2: Verify all 15 findings files exist and are well-formed**

```bash
cd docs/superpowers/reviews/findings
for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15; do
  test -f day$n.md || echo "MISSING day$n.md"
  grep -q "^## Primer-ability" day$n.md || echo "MALFORMED day$n.md"
done
```
Expected: no output. Re-dispatch a fix-up agent for any missing/malformed file.

---

### Task 3: Cross-day consistency and prerequisite audit (1 agent)

**Files:**
- Create: `docs/superpowers/reviews/findings/cross-day.md`
- Read (agent): `findings/inventory.md`, all 15 `findings/dayNN.md`, `content/README.md`, targeted reads of day files

**Interfaces:**
- Consumes: Task 1 inventory, Task 2 findings files
- Produces: `findings/cross-day.md` with IDs X1, X2, … in the same bullet/severity format. Consumed by Task 6.

- [ ] **Step 1: Dispatch the cross-day agent:**

```
You are running the cross-day pass of a review of a 15-day quantum path.
READ-ONLY; no git commands; write only
docs/superpowers/reviews/findings/cross-day.md.

Read docs/superpowers/reviews/findings/inventory.md and all 15
findings/dayNN.md files first, then spot-read content/dayNN.md files as
needed to confirm each suspicion (all paths relative to
quantum_computing_foundations/). Check:

1. NOTATION DRIFT across days (e.g., ket conventions, oracle definitions,
   qubit-ordering/endianness in circuits, symbols renamed midway).
2. PREREQUISITE ORDERING across the whole path: build the concept graph
   from inventory.md; flag any day using a concept no earlier day
   introduces. Pay attention to batch boundaries (days 3→4, 6→7, 9→10,
   12→13) where per-batch agents could not see neighbors.
3. README/module map accuracy: does content/README.md's Day/Module/Topic
   table match what each file actually covers?
4. REVIEW-DAY COVERAGE: days 5 and 9 are closed-book review days and day 15
   is the final exam — does every question they ask correspond to material
   actually established on the days they claim to review?

Output docs/superpowers/reviews/findings/cross-day.md:

# Cross-day findings
## Notation
- [X1] CRITICAL|MAJOR|MINOR — <files:lines> — <issue> — <suggested fix>
(or "- none"; continue numbering X2, X3, … across all sections)
## Prerequisite ordering
## README accuracy
## Review-day coverage

Final message: "cross-day: X critical / Y major / Z minor". Nothing else.
```

- [ ] **Step 2: Verify** — `grep -c "^## " docs/superpowers/reviews/findings/cross-day.md` equals 4 (plus title); file exists and each section has bullets or "- none".

---

### Task 4: Time-budget analysis (inline)

**Files:**
- Read: `docs/superpowers/plans/2026-07-13-quantum-computing-15-day-plan.md` (claimed schedule), all 15 `findings/dayNN.md` (Time budget sections)
- Output: corrected time-budget table held for Task 6 (no separate file)

**Interfaces:**
- Consumes: Task 2 per-day hour estimates
- Produces: markdown table `| Day | Claimed h | Estimated h | Delta | Driver |` + corrected path total, embedded in the report by Task 6.

- [ ] **Step 1: Extract claimed per-day hours** from the 2026-07-13 plan's schedule section.
- [ ] **Step 2: Collect estimated hours** — `grep -A1 "^## Time budget" findings/day*.md`.
- [ ] **Step 3: Build the table**, compute per-day deltas and the corrected total; note the top 3 over-budget days and what drives them (proof density, exercise count, lab time).

---

### Task 5: Primer-readiness synthesis (inline)

**Files:**
- Read: repo root `docs/superpowers/guides/encoding-primers-playbook.md`, `findings/inventory.md`, Primer-ability sections of all 15 `findings/dayNN.md`
- Output: primer-readiness section held for Task 6 (no separate file)

**Interfaces:**
- Consumes: Task 1 inventory, Task 2 primer-ability verdicts
- Produces: three report subsections — domain-context block, per-day verdict table, warm-up schedule table.

- [ ] **Step 1: Write the domain-context block** answering the playbook's five new-subject questions with what the audit actually found. Known from pre-plan inspection (verify against inventory): labels are **named**, not numbered (`**Claim (phase kickback):**`, `**Lemma: …**`, `###` section names) — citation format is quoted label names + gate names; pictures = circuit diagrams, Bloch-sphere states, amplitude bars; section 5 = **Derivation roadmaps**; path is sequential; Day 1 has no prior material (omit Warm-up).
- [ ] **Step 2: Build the per-day verdict table** — `| Day | Primer? | Citable labels | Hook candidate |`. Days 5 and 9: **no primer** (closed-book review). Day 15: primer only if its "beyond discrete-time QC" theory section got a *yes/partial* citable-labels verdict from batch E; exam portion gets none either way.
- [ ] **Step 3: Build the warm-up schedule table** for each primer-bearing day: 3 most-prerequisite prior *primer-bearing* days (never days 5/9; Day 1 has no Warm-up; days 2–3 name however many prior days exist). Justify each row in one phrase using the concept graph from `cross-day.md`.

---

### Task 6: Report assembly and final verification (inline)

**Files:**
- Create: `docs/superpowers/reviews/2026-08-05-content-and-primer-readiness-review.md`
- Read: all files under `findings/`, Task 4 and Task 5 outputs

**Interfaces:**
- Consumes: everything above.
- Produces: the final report — the plan's sole user-facing deliverable.

- [ ] **Step 1: Assemble the report** with exactly these sections:

```markdown
# Quantum Computing Foundations — Content & Primer-Readiness Review
## Verdict
(one paragraph + counts: N critical / N major / N minor across N findings)
## Findings — correctness (CRITICAL)
## Findings — feasibility (MAJOR)
## Findings — consistency (MINOR)
(every finding keeps its ID, file:line, description, suggested fix;
cross-day X-findings sorted into these three sections by severity)
## Corrected time budget
(Task 4 table + narrative)
## Primer-readiness
### Domain-context block
### Per-day verdicts
### Warm-up schedule
## Part-1 findings that affect primer briefs
(cross-reference list: finding ID → which day's primer brief changes and how)
## Proposed fix list (awaiting approval)
(numbered, ordered by severity; each names the file to change — NO fixes applied)
```

- [ ] **Step 2: Coverage check** — every finding ID present in `findings/*.md` appears exactly once in the report:

```bash
grep -hoE "\[[0-9]{2}-[CSPL][0-9]+\]|\[X[0-9]+\]" docs/superpowers/reviews/findings/*.md | sort -u > /tmp_ids
grep -oE "\[[0-9]{2}-[CSPL][0-9]+\]|\[X[0-9]+\]" docs/superpowers/reviews/2026-08-05-content-and-primer-readiness-review.md | sort -u > /tmp_rpt
diff /tmp_ids /tmp_rpt
```
(Use the session scratchpad directory for the temp files.) Expected: empty diff. Fix any omissions.

- [ ] **Step 3: Confirm zero modifications** to `content/` and `code/` — `git status` is the user's tool; instead verify by construction: this plan never opened those files for writing. State this in the report's Verdict section.

- [ ] **Step 4: Present the report summary to the user** — verdict paragraph, severity counts, top findings, and the ask: approve/adjust the proposed fix list. No commits.
