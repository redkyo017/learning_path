# Plain-language review sections for the linear algebra path — Design

**Date:** 2026-07-23
**Status:** Approved by user (pending spec review)

## Problem

The 30-day linear algebra path (`content/day01.md`–`day30.md`) has strong
formal content, but the notation and formal proofs (⟺ chains,
minimal-counterexample arguments, tagged equations) are hard to absorb and
retain. The user wants each day extended with easy-to-digest conclusions,
proof intuition, and a memorizable summary — without touching the rigorous
material.

## Decision summary

| Question | Decision |
|----------|----------|
| Rewrite vs append | **Keep existing content untouched; append one new section per day** |
| Notation help | **Per-day notation decoder table** (no global glossary file) |
| Proof retelling depth | **Idea-only sketches** (3–6 sentences + bolded one-line key trick per theorem) |
| Placement | **Inside each `dayNN.md`**, inserted before `## Journal template` |

## The new section

Every day file gains exactly one section, `## Plain-language review`, with
this fixed skeleton (identical order every day so review becomes ritual):

### 1. `### Notation decoder`
A markdown table: `| Symbol | Read it as | In today's context |`.

- Covers **only symbols actually used that day**.
- A symbol explained on an earlier day reappears only while it is still
  likely to be confusing (e.g. $\iff$ and quantifiers may repeat across the
  first days, then drop off). Matrix-entry subscripts, decomposition letters
  (LU, QR, SVD factors), etc. appear on the day they are introduced.
- "Read it as" gives a spoken-English rendering; "In today's context" ties
  it to that day's concrete objects.

### 2. `### The big ideas (conclusions)`
3–5 bullets. Each bullet is **one self-contained plain-English sentence**
stating a result of the day ("what is true"), reciteable from memory. No
proofs; symbols only when unavoidable.

### 3. `### Proof sketches`
One block per **named theorem** in that day's Theory section:

- A bolded header line: `**Theorem N.M — key trick: <one-line trick>**`
- 3–6 sentences retelling the proof idea in words (why the trick works),
  minimal symbols.
- Ends with a pointer to the formal proof above (e.g. "Full version:
  Theorem 10.1 above.").
- Definitions do not get sketches; only theorems/propositions with proofs.
  Days whose Theory section has no proved theorem (if any) omit this
  subsection.

### 4. `### If you remember only 3 things`
A numbered list of exactly 3 items — the ultra-compressed recall layer.
May overlap with "big ideas" (deliberate, spaced-repetition style). An item
may be a warning/trap (e.g. "repeated eigenvalue ≠ enough eigenvectors")
rather than a theorem.

## Placement rule

The section is inserted immediately **before** `## Journal template` in each
file, so the journal remains the final section. All existing content is
byte-for-byte unchanged.

## Scope

- All 30 files: `content/day01.md` … `content/day30.md`.
- No changes to `README.md`, `journal.md`, `starter_code/`, `solutions/`,
  or any other file.
- No new files besides this spec and the implementation plan.

## Quality / verification

After all 30 sections are written, a consistency pass checks:

1. Every named, proved theorem in each day's Theory section has a matching
   proof sketch (grep theorem headers vs sketch headers).
2. Each file contains exactly one `## Plain-language review` section, placed
   directly before `## Journal template`.
3. Decoder tables are valid markdown (header row + separator + ≥1 data row)
   and LaTeX delimiters are balanced.
4. "If you remember only 3 things" has exactly 3 items in every file.

Spot-check rendering of a few representative files (an early day, a
proof-heavy middle day such as day10, a capstone day) in markdown preview.

## Out of scope

- Rewriting or simplifying the existing Theory sections.
- A global NOTATION.md or CHEATSHEET.md (can be added later if wanted).
- Changes to exercises, solutions, or code labs.
