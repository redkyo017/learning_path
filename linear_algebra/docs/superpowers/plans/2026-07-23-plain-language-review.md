# Plain-Language Review Sections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Append a `## Plain-language review` section (notation decoder, big
ideas, proof sketches, 3-things recap) to each of the 30 day files in
`linear_algebra/content/`, per the approved spec.

**Architecture:** Pure markdown authoring. Each day file gets exactly one new
section inserted immediately before its `## Journal template` section; all
existing content stays byte-for-byte unchanged. A final scripted pass
verifies structure and theorem coverage across all 30 files.

**Tech Stack:** Markdown + LaTeX (existing style), one Python verification
script (stdlib only) run from the scratchpad.

**Spec:** `docs/superpowers/specs/2026-07-23-plain-language-review-design.md`
(read it before starting any task).

## Global Constraints

- **NO git operations.** Do not run `git add`, `git commit`, or any other git
  command. The user stages and commits everything themselves. (This
  overrides the default commit steps of any execution skill.)
- Modify ONLY `content/day01.md` … `content/day30.md`. Never touch
  `README.md`, `journal.md`, `starter_code/`, `solutions/`, or the spec.
- All paths below are relative to
  `/Users/hunghd/git_clone/learning_path/linear_algebra/`.
- Existing file content must remain byte-for-byte unchanged; the ONLY edit
  per file is inserting the new section directly before the line
  `## Journal template`, followed by a blank line.
- Hard-wrap prose at ~78 columns to match the existing files' style.
- The new section uses the exact skeleton and rules in "Canonical template"
  below. Subsection titles must match character-for-character (the
  verification script greps for them).
- "If you remember only 3 things" must have exactly 3 numbered items in
  every file.
- `### Proof sketches` is omitted only when the day's Theory section
  contains no proved Theorem/Proposition/Lemma (definitions and
  algorithm-only days don't need sketches).

---

## Canonical template (use for every day)

Insert this structure (with real content) before `## Journal template`:

```markdown
## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| ...    | ...        | ...                |

### The big ideas (conclusions)

- (3–5 bullets, each ONE self-contained plain-English sentence stating a
  result of the day. No proofs. Symbols only when unavoidable.)

### Proof sketches

**Theorem N.M — key trick: <one-line trick in plain words>.**
(3–6 sentences retelling why the proof works, minimal symbols. Last
sentence: "Full version: Theorem N.M above.")

### If you remember only 3 things

1. ...
2. ...
3. ...
```

Content rules (from the spec — apply to every day):

- **Decoder:** only symbols actually used that day. A symbol decoded on an
  earlier day reappears only while still likely confusing (e.g. $\iff$ and
  quantifiers may repeat in week 1, then drop off). New objects (LU/QR/SVD
  factor letters, $\ker$, $\operatorname{im}$, norms, inner products…) are
  decoded the day they first appear. "Read it as" = spoken-English
  rendering; "In today's context" ties it to that day's concrete objects.
- **Big ideas:** state *what is true*, reciteable from memory.
- **Proof sketches:** one block per named, proved Theorem/Proposition/Lemma
  in that day's Theory section, in the same order. The bolded trick line is
  the memory hook; the sketch is idea-only, not step-by-step. Definitions
  get no sketch.
- **3 things:** the ultra-compressed recall layer; overlap with big ideas is
  deliberate. One item may be a warning/trap instead of a theorem.

## Gold-standard example (day10) — match this quality and tone

This is the complete, ready-to-insert section for `content/day10.md`.
Task 2 inserts it verbatim; all other days must match its density and voice.

```markdown
## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $\lambda$ | "lambda — the stretch factor" | how much $A$ scales an eigenvector |
| $Av = \lambda v$ | "$A$ acting on $v$ is just $v$ scaled by $\lambda$" | the defining equation of an eigenpair |
| $\det(A - \lambda I)$ | "the determinant test for $\lambda$" | equals zero exactly when $\lambda$ is an eigenvalue |
| $p_A(\lambda)$ | "the characteristic polynomial of $A$" | its roots are the eigenvalues |
| $\iff$ | "is exactly the same statement as" | eigenvalue $\iff$ determinant test gives zero |
| $(*)$, $(**)$, $(\dagger)$ | "nicknames for equations, to refer back to them" | labels used inside the independence proof |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- An eigenvector is a direction the matrix does not turn: $A$ only
  stretches, shrinks, or flips it, by the factor $\lambda$.
- You never find eigenvalues by searching vectors: $\lambda$ is an
  eigenvalue exactly when $\det(A - \lambda I) = 0$.
- The characteristic polynomial of an $n \times n$ matrix has degree $n$,
  so there are at most $n$ eigenvalues (exactly $n$ over the complex
  numbers, counting repeats).
- A perfectly real matrix can have complex eigenvalues — rotations are the
  classic example.
- Eigenvectors belonging to different eigenvalues are automatically
  linearly independent — no extra check ever needed.

### Proof sketches

**Theorem 10.1 — key trick: turn "does a special vector exist?" into "is
one number zero?".**
Saying $\lambda$ is an eigenvalue means $(A - \lambda I)v = 0$ has a
nonzero solution. A homogeneous system has a nonzero solution exactly when
its matrix is singular — otherwise you could multiply by the inverse and
force $v = 0$. And singular means determinant zero (Day 8). Chain the three
equivalences and the infinite vector search collapses into finding roots of
one polynomial. Full version: Theorem 10.1 above.

**Theorem 10.2 — key trick: apply $A$, multiply by $\lambda_k$, subtract —
the last vector cancels.**
Assume the smallest possible dependent set of eigenvectors for distinct
eigenvalues. Feed the dependence relation through $A$ (each $v_i$ picks up
its own $\lambda_i$), separately multiply the same relation by
$\lambda_k$, and subtract: the last vector drops out, leaving a dependence
among fewer eigenvectors. That contradicts "smallest", because the
distinct-eigenvalue differences $\lambda_i - \lambda_k$ are nonzero and
can't rescue the coefficients. So no dependent set exists at all. Full
version: Theorem 10.2 above.

### If you remember only 3 things

1. $Av = \lambda v$ with $v \neq 0$: the matrix doesn't turn $v$, it only
   scales it by $\lambda$.
2. Eigenvalues are the roots of $\det(A - \lambda I) = 0$ — a polynomial
   problem, not a vector search.
3. Distinct eigenvalues give automatically independent eigenvectors, but a
   repeated eigenvalue may not have enough eigenvectors (Exercise 4's trap).
```

---

### Task 1: Verification script

**Files:**
- Create: `<scratchpad>/check_review_sections.py` (scratchpad — NOT in the
  repo; the spec says no new repo files besides spec + plan)

**Interfaces:**
- Produces: `python check_review_sections.py [dayNN.md ...]` — checks the
  given files (default: all 30) and prints PASS/FAIL per file with reasons.
  Later tasks run it after each batch.

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
"""Structural checks for Plain-language review sections (spec 2026-07-23)."""
import re
import sys
from pathlib import Path

CONTENT = Path("/Users/hunghd/git_clone/learning_path/linear_algebra/content")

def check_file(path: Path) -> list[str]:
    errors = []
    text = path.read_text()

    # 1. Exactly one review section, directly before the journal section.
    if text.count("## Plain-language review") != 1:
        errors.append("expected exactly one '## Plain-language review'")
        return errors
    review_start = text.index("## Plain-language review")
    journal = text.find("## Journal template")
    if journal == -1:
        errors.append("missing '## Journal template'")
        return errors
    if journal < review_start:
        errors.append("review section must come before journal template")
    between = text[review_start:journal]
    review = between  # review section body = everything up to the journal

    # 2. Required subsections present, in order.
    required = ["### Notation decoder",
                "### The big ideas (conclusions)",
                "### If you remember only 3 things"]
    pos = 0
    for heading in required:
        idx = review.find(heading)
        if idx == -1:
            errors.append(f"missing '{heading}'")
        elif idx < pos:
            errors.append(f"'{heading}' out of order")
        else:
            pos = idx

    # 3. Decoder table: header + separator + >=1 data row.
    decoder = re.search(r"### Notation decoder\n+((?:\|.*\n)+)", review)
    if not decoder:
        errors.append("notation decoder has no markdown table")
    else:
        rows = decoder.group(1).strip().splitlines()
        if len(rows) < 3:
            errors.append("decoder table needs header, separator, >=1 row")

    # 4. Exactly 3 numbered items in the 3-things list.
    three = review.split("### If you remember only 3 things")[-1]
    items = re.findall(r"^\d+\.\s", three, flags=re.M)
    if len(items) != 3:
        errors.append(f"'3 things' has {len(items)} items, expected 3")

    # 5. Theorem coverage: every proved theorem in Theory has a sketch.
    theory = text[:review_start]
    proved = []
    for m in re.finditer(
            r"### (Theorem|Proposition|Lemma) (\d+\.\d+)", theory):
        # Only count it if a proof follows before the next heading.
        tail = theory[m.end():]
        nxt = tail.find("\n### ")
        block = tail[:nxt] if nxt != -1 else tail
        if "**Proof" in block or "*Proof" in block:
            proved.append(m.group(2))
    for num in proved:
        if not re.search(rf"\*\*(Theorem|Proposition|Lemma) {re.escape(num)} —",
                         review):
            errors.append(f"no proof sketch for {num}")
    if proved and "### Proof sketches" not in review:
        errors.append("day has proved theorems but no '### Proof sketches'")

    # 6. Balanced LaTeX delimiters in the new section (crude but effective).
    if review.count("$") % 2 != 0:
        errors.append("odd number of '$' in review section")

    return errors

def main() -> int:
    names = sys.argv[1:] or [f"day{i:02d}.md" for i in range(1, 31)]
    failed = 0
    for name in names:
        errs = check_file(CONTENT / name)
        if errs:
            failed += 1
            print(f"FAIL {name}: " + "; ".join(errs))
        else:
            print(f"PASS {name}")
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Verify the script fails on unmodified files**

Run: `python <scratchpad>/check_review_sections.py day01.md`
Expected: `FAIL day01.md: expected exactly one '## Plain-language review'`
(exit code 1). This is the "failing test" for every later task.

---

### Task 2: Days 06–10 (includes the gold-standard day10)

**Files:**
- Modify: `content/day06.md`, `content/day07.md`, `content/day08.md`,
  `content/day09.md`, `content/day10.md`
- Test: `python <scratchpad>/check_review_sections.py day06.md day07.md
  day08.md day09.md day10.md`

**Interfaces:**
- Consumes: verification script from Task 1; canonical template + gold
  example above.
- Produces: five completed review sections; day10 becomes the reference
  other tasks compare against.

This batch goes first because day10's section is already fully written
above — inserting it verbatim calibrates you before writing original
sections for days 06–09 (determinants, inverses/LU, four subspaces —
theorem-heavy days).

- [ ] **Step 1: Insert the gold-standard section into day10.md**

Insert the entire `## Plain-language review` block from "Gold-standard
example (day10)" above, verbatim, immediately before the line
`## Journal template` in `content/day10.md`, with a blank line after the
inserted block.

- [ ] **Step 2: Verify day10 passes**

Run: `python <scratchpad>/check_review_sections.py day10.md`
Expected: `PASS day10.md`

- [ ] **Step 3: Write sections for day06–day09, one file at a time**

For each file: read the whole day file first; list its proved
Theorems/Propositions/Lemmas; then write the section following the
canonical template and content rules, matching day10's density and voice.
Insert before `## Journal template`.

- [ ] **Step 4: Verify the batch passes**

Run: `python <scratchpad>/check_review_sections.py day06.md day07.md day08.md day09.md day10.md`
Expected: `PASS` for all five files.

---

### Task 3: Days 01–05

**Files:**
- Modify: `content/day01.md` … `content/day05.md`
- Test: `python <scratchpad>/check_review_sections.py day01.md day02.md
  day03.md day04.md day05.md`

**Interfaces:**
- Consumes: script (Task 1), gold standard in `content/day10.md` (Task 2).
- Produces: five completed review sections.

Week-1 note: these days introduce the foundational notation ($\in$,
$\subseteq$, $\operatorname{span}$, $\forall/\exists$, set-builder
notation, $\ker$, $\operatorname{im}$…). Decoder tables here are the
largest of the whole path — err on the side of decoding every symbol a
newcomer could stumble on, including $\iff$ and quantifiers.

- [ ] **Step 1: Write sections for day01–day05, one file at a time**

Same procedure as Task 2 Step 3 (read file → list proved theorems → write
section → insert before `## Journal template`).

- [ ] **Step 2: Verify the batch passes**

Run: `python <scratchpad>/check_review_sections.py day01.md day02.md day03.md day04.md day05.md`
Expected: `PASS` for all five files.

---

### Task 4: Days 11–15

**Files:**
- Modify: `content/day11.md` … `content/day15.md`
- Test: `python <scratchpad>/check_review_sections.py day11.md day12.md
  day13.md day14.md day15.md`

**Interfaces:**
- Consumes: script (Task 1), gold standard in `content/day10.md`.
- Produces: five completed review sections.

Content note: diagonalization, inner products, Gram–Schmidt. Decode newly
introduced notation ($P^{-1}AP$, $\langle u, v \rangle$, $\|v\|$,
$v^\perp$, projection formulas) the day it first appears. Day 13 (if it is
a review/consolidation day with no new proved theorems) may legitimately
omit `### Proof sketches` — the script allows this.

- [ ] **Step 1: Write sections for day11–day15, one file at a time**

For each file: read the whole day file first; list its proved
Theorems/Propositions/Lemmas; write the section following the canonical
template and content rules, matching `content/day10.md`'s density and
voice; insert it immediately before `## Journal template`.

- [ ] **Step 2: Verify the batch passes**

Run: `python <scratchpad>/check_review_sections.py day11.md day12.md day13.md day14.md day15.md`
Expected: `PASS` for all five files.

---

### Task 5: Days 16–20

**Files:**
- Modify: `content/day16.md` … `content/day20.md`
- Test: `python <scratchpad>/check_review_sections.py day16.md day17.md
  day18.md day19.md day20.md`

**Interfaces:**
- Consumes: script (Task 1), gold standard in `content/day10.md`.
- Produces: five completed review sections.

Content note: least squares, QR, spectral theorem, quadratic forms. The
spectral theorem day (19) is the proof-heaviest of the path — its sketches
are the most valuable ones you will write; spend the effort to find a
genuinely memorable one-line trick per theorem.

- [ ] **Step 1: Write sections for day16–day20, one file at a time**

For each file: read the whole day file first; list its proved
Theorems/Propositions/Lemmas; write the section following the canonical
template and content rules, matching `content/day10.md`'s density and
voice; insert it immediately before `## Journal template`.

- [ ] **Step 2: Verify the batch passes**

Run: `python <scratchpad>/check_review_sections.py day16.md day17.md day18.md day19.md day20.md`
Expected: `PASS` for all five files.

---

### Task 6: Days 21–25

**Files:**
- Modify: `content/day21.md` … `content/day25.md`
- Test: `python <scratchpad>/check_review_sections.py day21.md day22.md
  day23.md day24.md day25.md`

**Interfaces:**
- Consumes: script (Task 1), gold standard in `content/day10.md`.
- Produces: five completed review sections.

Content note: SVD, low-rank approximation, PCA, change of basis. Decode
the SVD factor letters ($U$, $\Sigma$, $V^T$, $\sigma_i$) and the
covariance-matrix notation on first appearance.

- [ ] **Step 1: Write sections for day21–day25, one file at a time**

For each file: read the whole day file first; list its proved
Theorems/Propositions/Lemmas; write the section following the canonical
template and content rules, matching `content/day10.md`'s density and
voice; insert it immediately before `## Journal template`.

- [ ] **Step 2: Verify the batch passes**

Run: `python <scratchpad>/check_review_sections.py day21.md day22.md day23.md day24.md day25.md`
Expected: `PASS` for all five files.

---

### Task 7: Days 26–30

**Files:**
- Modify: `content/day26.md` … `content/day30.md`
- Test: `python <scratchpad>/check_review_sections.py day26.md day27.md
  day28.md day29.md day30.md`

**Interfaces:**
- Consumes: script (Task 1), gold standard in `content/day10.md`.
- Produces: five completed review sections.

Content note: capstone days (26–30) synthesize earlier material and may
have few or no new proved theorems — their "big ideas" and "3 things"
should emphasize connections across days (e.g. "PCA is just the spectral
theorem applied to a covariance matrix"). Omitting `### Proof sketches` is
expected where there is nothing new to prove.

- [ ] **Step 1: Write sections for day26–day30, one file at a time**

For each file: read the whole day file first; list its proved
Theorems/Propositions/Lemmas; write the section following the canonical
template and content rules, matching `content/day10.md`'s density and
voice; insert it immediately before `## Journal template`.

- [ ] **Step 2: Verify the batch passes**

Run: `python <scratchpad>/check_review_sections.py day26.md day27.md day28.md day29.md day30.md`
Expected: `PASS` for all five files.

---

### Task 8: Full consistency pass and spot-render

**Files:**
- Modify: none expected (fix-ups only if checks fail)
- Test: `python <scratchpad>/check_review_sections.py` (all 30 files)

**Interfaces:**
- Consumes: all 30 completed sections; verification script.
- Produces: a fully verified content set; the plan's checkboxes all done.

- [ ] **Step 1: Run the full check**

Run: `python <scratchpad>/check_review_sections.py`
Expected: `PASS dayNN.md` for all 30 files, exit code 0. Fix any FAIL
directly in the offending file and re-run until clean.

- [ ] **Step 2: Confirm existing content untouched**

Run: `git -C /Users/hunghd/git_clone/learning_path diff --stat -- linear_algebra/content/`
(read-only inspection, allowed) and then, for three representative files:
`git -C /Users/hunghd/git_clone/learning_path diff -U0 -- linear_algebra/content/day02.md linear_algebra/content/day10.md linear_algebra/content/day28.md`
Expected: every hunk is pure addition (`+` lines only) located immediately
before `## Journal template`. Any deletion/modification of an existing
line is a bug — restore the original text.

- [ ] **Step 3: Spot-render three files**

Open `day02.md` (early), `day19.md` (proof-heavy), `day28.md` (capstone)
in a markdown preview (or `less`) and confirm: decoder tables render as
tables, LaTeX delimiters are balanced, sketches read naturally aloud.

- [ ] **Step 4: Report**

Tell the user the work is complete, list the 30 modified files, and remind
them that nothing was staged or committed (their preference) — staging is
theirs to do.
