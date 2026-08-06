# Plain-English Glossaries for Math-Heavy Paths — Design

**Date:** 2026-08-06
**Status:** Approved by user (design discussion), pending spec review
**Scope:** `linear_algebra` and `quantum_computing_foundations` learning paths

## Problem

Both paths are math-heavy. When the learner returns after time away and has forgotten a definition ("what was nullity again?"), the only recovery route today is digging back through day files or primers — sequential documents designed for first-pass learning, not lookup. Primers own encoding (intuition, pictures, flashcards); nothing owns *fast retrieval of forgotten definitions*.

## Solution

One additive glossary file per path, written in straight English:

- `linear_algebra/content/GLOSSARY.md`
- `quantum_computing_foundations/content/GLOSSARY.md`

All existing files remain byte-identical (same additive rule as the primers companion).

## File Structure

Each glossary has, in order:

1. **How-to-use line.** One sentence: this is a lookup for catch-up, not a read-through.
2. **Notation at a glance.** A table decoding every symbol the path uses. Columns: *Symbol* / *Read as* (how to say it aloud) / *Meaning* (plain English). Examples: `|ψ⟩` / "ket psi" / a quantum state as a column vector; `ker` / "kernel" / the inputs sent to zero.
3. **Jump index.** Links to each theme section.
4. **Term sections grouped by theme**, with day ranges in the headers (e.g. `## Linear Maps (Days 9–12)`), so an entry implicitly points at where the full treatment lives. No per-entry day citations.
5. **Contrast boxes** embedded in the relevant sections (see Entry Formats).

## Entry Formats

**Default entry — one-liner:**

```markdown
**Kernel ($\ker T$)** — All vectors $v$ where $T(v) = 0$; the inputs that get crushed to zero. It is the null space of the matrix.
```

Rules:
- 1–2 lines of straight English per term.
- Math symbols allowed inside, but the sentence must still make sense if the symbols were removed.
- Bold term first, symbol in parentheses when one exists, em-dash, then the definition.

**Contrast box — for confusable pairs:**

```markdown
> **Kernel vs Image**
>
> | | Kernel | Image |
> |---|---|---|
> | It is… | the input set | the output set |
> | Lives in… | the domain | the codomain |
> | Shows… | what goes to zero | what is reachable |
> | Matrix view | null space | span of pivot columns |
```

Candidate pairs (finalized during the extraction pass):
- **Linear algebra:** kernel/image, span/basis, rank/nullity, eigenvalue/eigenvector, row space/column space, injective/surjective, similar/congruent matrices.
- **Quantum:** bra/ket, superposition/entanglement, unitary/Hermitian, pure/mixed state, gate/measurement, global/relative phase.

## Coverage

Every formally defined term in the path: definitions, named theorem-objects, and notation. Expected scale: ~100–150 entries for linear algebra (30 days), ~60–90 for quantum (15 days).

## Build Approach: Extract-Then-Write

1. **Extraction pass.** Read every `content/dayNN.md` in the path and harvest each formally defined term, named object, and symbol into a coverage checklist (working artifact, not shipped).
2. **Writing pass.** Write the glossary against that checklist so terminology, symbols, and definition numbering conventions match the path's actual content — not generic textbook phrasing.
3. **Verification.** Cross-check the finished glossary against the checklist: every harvested term either has an entry or a recorded reason for exclusion.

Rejected alternative: writing from standard curriculum knowledge. Faster, but a catch-up tool that names things differently from the material it serves is worse than none.

## Out of Scope (YAGNI)

- Per-entry cross-links into day files (theme headers carry day ranges instead).
- Flashcards or retrieval scheduling (primers own that).
- Any modification to existing day files, primers, or solutions.
- Glossaries for other paths (can reuse this design later if wanted).

## Process Notes

- Per the learner's standing preference, confirm a possible model switch **before** writing the glossary content files; specs/plans are fine on the current model.
- No git commits unless explicitly requested.

## Success Criteria

- A learner who has forgotten any defined term in either path can find a plain-English answer in one file, in under a minute, without re-reading day files.
- Every symbol used in the path appears in the notation table.
- Extraction checklist fully reconciled (no silent coverage gaps).
