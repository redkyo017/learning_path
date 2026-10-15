---
name: condensing-a-book-for-memory
description: Use when asked to condense, summarise or "make a concise version" of a specific book or PDF the learner has already read — especially a math/science text with theorems and proofs — to consolidate it into long-term memory, as one file rather than a multi-day learning path. Also use when a scanned or OCR'd PDF is the source of truth for formulas.
---

# Condensing a Book for Long-Term Memory

Sub-skill of `skill.md` (building-learning-path). Use this one instead when the deliverable is **one condensed
companion to one book**, not a day-by-day path. Prompt template: `prompt_book_condense.md`.

**Announce at start:** "I'm using the condensing-a-book-for-memory skill."

## Core principle

**A scanned book's text layer is not the book.** OCR flattens exponents, drops fractions, renumbers theorems and
invents misprints. Drafters fed OCR text reconstruct formulas *from context* without noticing, and a reviewer fed the
same text approves them. Only a pass that compares the draft with the **page images** makes the file trustworthy.

## When NOT to use

- The learner wants to *learn* a subject from scratch, with labs, days and exercises → `skill.md`.
- The book is born-digital with a clean text layer and no formulas → run the same pipeline, but the image check may be
  a sample instead of every page (say which in the handoff).

## Step 0 — Questions (one round, ≤5, each with a default)

Read `LEARNER_PROFILE.md` first. Ask only what the request leaves open:

1. **Goal:** first-time learning vs. consolidating a book already read (default: consolidate).
2. **Output:** one `.md` at the repo root, untracked (default) vs. one file per chapter.
3. **Exercises:** point to the book's own (default) vs. write new ones (then each ships a hint + solution sketch).
4. **Proofs:** the author's own, condensed (default) vs. rewritten for clarity.
5. **Time budget for the practice plan** (default: 7-day sprint at 2–3 h/day + spaced sessions).

No scratch branch, no spec/plan files, no directory, unless the learner asks. Present a short in-chat design and wait
for a yes before writing.

## Pipeline

| # | Step | Who |
|---|---|---|
| 0 | `pdfinfo` + `pdftotext` on a few pages: if there is no text layer (image-only scan), tell the learner and offer `ocrmypdf` (needs their OK to install) or drafting straight from page images in smaller chunks | main model |
| 1 | `pdftotext -layout` into the scratchpad; find chapter boundaries (§1 headers, page headers); compute the PDF-page ↔ printed-page offset (form-feed count) | main model |
| 2 | Split into chunks of ~2–3k text lines on chapter boundaries, so that each chunk is one drafter | main model |
| 3 | **Draft**: one Sonnet subagent per chunk, in parallel, with the drafting brief below | Sonnet |
| 4 | Write front matter (strategy, mistakes, plan, references) while drafts run | main model |
| 5 | **Verify against page images**: one Sonnet subagent per part, in parallel, with the verify brief below | Sonnet |
| 6 | Normalise Part headings; write the **Map of Results** from the inventories; check every route claim in it against the verified text | main model |
| 7 | Assemble; run the checks in §Verification; spot-check 3–5 proofs yourself | main model |

## Drafting brief (save as `BRIEF.md` in the scratchpad; each dispatch names its chunk + output file)

```markdown
Source: chunk file (OCR, often garbled). When a formula/statement/proof is unclear, READ THE PDF PAGE with the Read
tool (`pages`, max 20; PDF page ≈ printed page + OFFSET). Correctness beats speed. Skip exercise lists, but keep
results the text states or relies on.

Per chapter: `## Chapter N — Title`, a one-paragraph big picture, then per section `### §k. Title` with:
**Definitions.** (bold terms)
**<Author's own label, e.g. Theorem 2 / N 3 / POS 1 / SC 4>.**
*Statement:* precise hypotheses + conclusion.
*Proof (author's):* the author's argument in numbered steps; each step names what it uses. Never substitute
another proof. If the book assumes it: *Assumed.* If the book leaves it to the reader: say so.
*Intuition:* 1–2 lines.  *Example:* one fully worked example (mark *ours* if it is not the author's).
End each chapter: `### Recall prompts — Chapter N` (5–10 closed-book prompts, no answers).

Style: the author's voice, concise, LaTeX ($…$, $$…$$), your own wording, no emoji.
Deliverables: the output .md + `<same>.inventory.txt` (one line per named result:
`Ch N §k | <label as the author writes it> | <one-line statement>`) + a final reply listing every place you
reconstructed from context WITHOUT opening the PDF.
```

## Verify brief (save as `VERIFY_BRIEF.md`)

```markdown
Compare the draft with the PDF PAGE IMAGES (Read tool, `pages`) over the page range given. Trust the images over
the OCR text and over the draft. Section by section:
1. Statements match the book (labels, hypotheses, conclusion).
2. Proofs follow the AUTHOR's route; "assumed" / "left to the reader" status is right.
3. Every formula and example number is correct — recompute; examples claimed as the author's match the book.
4. Completeness: every named/numbered result and every displayed formula reused later is present → add the
   missing ones in the draft's format, and to the inventory.
5. Misprint claims: look at the page. Real misprint → keep the correction + note "the book prints X".
   OCR artifact → use the book's value, remove the note.
6. Anything the book does not support and that is not labelled *ours* → remove or label it.
Edit in place with small edits; no restyling. Reply: fix counts by kind, the 5 biggest fixes, anything unverified.
```

Put the drafters' "reconstructed without the PDF" list in each verifier's task, as "check these first".

## Front-matter contract

The companion opens with, in order:

1. **How to make it stick:** at most 5 principles, each tied to a cited study (retrieval practice — Roediger & Karpicke
   2006; spacing — Cepeda et al. 2006/2008; interleaving — Rohrer & Taylor 2007; self-explanation — Chi et al. 1989;
   review — Dunlosky et al. 2013). Popular techniques without such evidence (e.g. "Feynman technique") are either
   left out or labelled *judgment*. Never invent statistics for "top 1%" / "80%".
2. **Mistakes** as a table: mistake → how you'd notice → do instead.
3. **Plan:** sprint (blank-page recall → check → rebuild proofs → mixed book exercises → recall prompts) **plus**
   spaced sessions at widening intervals (+1 w, +2 w, +1, 2, 4, 8 months) with a Leitner rule for misses.
4. **AI use:** quizzing and checking *after* an attempt, never instead of it.
5. **References** with full citations.

It closes with a **Map of Results**: each chapter as a chain *assumed → proved* (⇒ = "is used to prove") and a
"rebuild drills" table: key formula → what to derive it from.

## Verification (before handoff)

- Chapter headings in book order; one `### Recall prompts` per chapter (and interlude).
- `$$` count even; no line with an odd count of single `$` (multi-line inline math breaks renderers).
- Every label in the inventories appears in its own chapter's text (scripted check, per chapter).
- No leftover meta text: `OCR`, `drafter`, `brief`, `TODO`, `TBD`.
- Where examples are computational (eigenvalues, congruences, integrals), recompute a sample with a short script
  (Python `-I`, sympy/numpy if present).
- The handoff says what was verified against images, what only for arithmetic, and what not at all.
- Use `/usr/bin/grep` in this repo (plain `grep` is a shim).

## Common mistakes

| Mistake | Fix |
|---|---|
| Building the coverage list by grepping `Theorem\|Lemma\|Corollary` | Authors use their own labels (N 1, POS 2, SC 4, D1, EXP 3) and OCR mangles numbers. The inventory comes from the drafters reading the text, and is extended by the verifiers. |
| Reviewer gets the OCR text beside the draft | It approves the same garbled formula. The reviewer reads the page **images**. |
| Accepting "the book has a misprint" from a drafter | A claimed misprint can be an OCR artifact, and from the text alone the two look identical. Settle each one against the image. |
| Fixing a real misprint silently | The learner will compare against the book. Keep the correction with "the book prints X". |
| Writing the Map of Results from memory of the subject | Write it from the verified inventories, then check every proof-route claim against the verified chapter text. |
| A dangling "Part N intro" summarised from nothing | If the book's part page is a title page only, say so in one line. |
