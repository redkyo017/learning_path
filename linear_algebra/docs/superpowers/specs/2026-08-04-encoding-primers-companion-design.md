# Encoding Primers Companion — Design

**Date:** 2026-08-04
**Status:** Approved design (user approved structure in session; awaiting spec review)

## Purpose

The 30-day plan's retrieval machinery (closed-book gates, interleaved review days,
journals) is strong, but the *encoding* side — how each concept is first met — is
traditional textbook order: abstract definition → theorem → proof printed below →
one worked example after all theory → memory aids ("big ideas," "key tricks,"
notation decoder) at the bottom of the file. The 2026-08-04 content feasibility
review confirmed this is the plan's main comprehension/memorization weakness:
abstraction-first ordering, zero diagrams in a geometric subject, no graduated
scaffold between "attempt proof from scratch" and "read the full proof," no daily
retrieval between review days spaced 5–6 days apart.

This companion fixes the encoding side without touching the originals — the same
pattern as `content/solutions_expanded/`. Each content day gets a primer read
*before* the main day file that front-loads intuition, pictures, concrete
examples, memory hooks, proof scaffolding, and daily spaced retrieval.

## Learner context

Same as the 30-day plan spec: solid high-school algebra, no formal linear algebra
course, strong 3Blue1Brown/Khan geometric intuition, weak problem-solving fluency,
limited proof-writing experience. Self-paced (the 4h/day framing is not a
constraint the primers need to respect). Goal: comprehend and retain the material
as effectively as possible — encoding-side techniques (concreteness fading, dual
coding, advance organizers, graduated hints, spaced retrieval) are the point.

## Scope

- **22 primer files**: `content/primers/dayNN.md` for the content days only —
  days 1–6, 8–12, 14–17, 19–23, 25–26.
- **1 index file**: `content/primers/README.md` — what primers are, how to use
  them (read primer → then main day file), and the spaced warm-up schedule.
- **Excluded**: review days (7, 13, 18, 24, 27) and capstone/exam days (28–30) —
  they introduce no new theory and their retrieval design is already the plan's
  strength. `solutions_expanded/` and all code untouched.
- **Originals byte-untouched.** No edits to `content/dayNN.md`.

## Per-primer structure (fixed section order)

Each primer is read before its main day file; target ~150–250 lines, a 15–20
minute read plus a ~10 minute warm-up.

1. **Warm-up (retrieval first).** Instructions to run flashcards from day N−1,
   day N−2, and roughly one week back (the exact back-days listed explicitly per
   primer), ~10 min. Day 1's primer has no warm-up (nothing prior); Day 2 warms
   up on Day 1 only, etc. This closes the forgetting-curve gap between the
   plan's 5–6-day-spaced review days.
2. **The hook.** One concrete numeric problem the day's material exists to
   solve, felt before any definition — stated with actual numbers, attempted
   with the previous days' tools, showing exactly where they break. Resolved at
   the end of the section with "today's concept is the fix" (not the full
   solution — the main file does that).
3. **The pictures.** One ASCII/unicode sketch per major concept with a
   plain-language caption — the geometric story the day's theorems formalize.
   Pictures must be renderable in plain markdown (code blocks), no external
   images.
4. **Concrete-first walkthrough.** For each definition/theorem in the main
   file, in the main file's order: tiny numeric example → the pattern it
   exhibits → "this is what Definition/Theorem X.Y formalizes" (citing the main
   file's numbering exactly) → a one-line memory hook (slogan, plus etymology or
   name-origin where it helps, e.g. *eigen* = German "own").
5. **Proof roadmaps.** For each proof the plan expects the learner to attempt:
   the key trick in one sentence, then graduated hints — *first move* → *middle
   rung* → *full sketch* — so an attempt has intermediate footholds. Never the
   full proof (the main file has it).
6. **Flashcards.** 6–10 plain markdown Q/A cards per day (definitions as
   "state precisely," slogans, key tricks, traps). Format: `**Q:** … / **A:** …`
   pairs — offline-usable with no tooling; Anki export is out of scope.

## Content rules

- All mathematics identical in substance to the main files; primers cite the
  main file's Definition/Theorem numbers and never renumber or restate full
  proofs.
- Primers must not contradict main-file content. One deliberate exception:
  where the 2026-08-04 review found a pedagogy defect in a main file, the
  primer presents the learner-appropriate route — specifically Day 23's primer
  leads with the eigenbasis/linear-algebra-only intuition for variance
  maximization (not Lagrange multipliers), and Day 4's primer does not lean on
  the calculus exercise. Main-file errata remain a separate, undecided work
  item; primers must remain correct whether or not those errata are later
  applied.
- No forward references to material not yet covered by that day, except
  explicitly flagged "coming on Day NN" teasers.
- Tone: plain language, second person, consistent with the existing
  "Plain-language review" sections' register.

## Execution model (two-phase, by user request)

- **Phase 1 — preparation (current, high-capability model):** this spec, then
  an implementation plan containing a complete per-day brief for every primer:
  the hook problem (with numbers), the picture list (what each sketch shows),
  per-theorem memory hooks/slogans, proof-roadmap hint ladders, and the
  flashcard list (question topics + answers in brief). All creative/mathematical
  decisions are made in the plan.
- **Phase 2 — crafting (cheaper model, e.g. Sonnet):** expand the briefs into
  the 22 primer files + README, mechanically following the plan. **Before any
  primer file is written, stop and prompt the user to switch models.**
- No git commits at any point — the user handles all version control.

## Success criteria

- Every content day (1–6, 8–12, 14–17, 19–23, 25–26) has a primer following the
  six-section structure, plus `primers/README.md`.
- Each primer's warm-up names explicit prior days; flashcards exist for every
  primer day so every warm-up reference resolves.
- Every definition/theorem in a main file's Theory section has a corresponding
  walkthrough entry and memory hook in its primer; every attempt-expected proof
  has a roadmap with a three-rung hint ladder.
- All main files remain byte-identical; spot-check via `git status`.
- A reader with only the previous days' knowledge can follow each primer
  start-to-finish (no untaught tools).

## Out of scope

- Main-file errata from the 2026-08-04 review (separate decision).
- Anki/SRS tooling or export formats.
- Primers for review/capstone/exam days.
- Any change to code labs, starter code, or solutions.
