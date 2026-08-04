# Encoding Primers Playbook

A reusable guide for generating encoding-side companion primers for any structured learning path.
Produced from the linear algebra 30-day path (2026-08-04). Use this as the instruction set whenever
you need to create a similar primer companion for a different subject.

---

## What encoding primers are

Primers are short (~10 min) files a learner reads **before** the main content day file. They do not
replace the main file — they prime the brain for it. Originals are never modified.

**Pedagogical principles applied:**
- Concreteness-fading: start with a vivid concrete example, then name the abstract concept
- Dual coding: pair prose with described visual (diagram sketches, not image files)
- Spaced retrieval: Warm-up section forces recall of 3 prior days before reading
- Graduated proof scaffolding: give the proof's key trick, not the full derivation

---

## Anatomy of a primer — the six sections

Sections appear in this **exact order**, all as `##` headings:

```
## Warm-up
## The hook
## The pictures
## Concrete-first walkthrough
## Proof roadmaps
## Flashcards
```

**Exception:** The very first primer (Day 1) has no prior days to review, so omit `## Warm-up`.
That file therefore has 5 `##` sections.

### 1. Warm-up (skip for Day 1)

Format:
```
Spend 10 minutes answering the flashcards at the end of [primers/dayXX.md] (Day X),
[primers/dayYY.md] (Day Y), and [primers/dayZZ.md] (Day Z) before reading on.
```

Rules:
- Name exactly 3 prior days — pick the most directly prerequisite ones
- Cite the **actual prior-day file paths** (`primers/dayXX.md`), NOT the current file
- Include a one-sentence reminder of what each prior day was about
- Self-referential paths (citing the file you're writing) are a bug to catch in review

### 2. The hook

- Open with a single concrete example using exact numbers (from the day's brief)
- Show the problem or question, then show why it's surprising or useful
- End with a one-line bridge: "Today you'll learn the machinery that explains this"
- Length: ~10–15 lines

### 3. The pictures

- Describe 3 visual metaphors or diagrams in prose — no actual images
- Each picture: 1 sentence naming it, 2–4 sentences describing what to visualize, 1 sentence
  naming the key insight the picture delivers
- Full paragraphs, no bullet points
- Total length: ~15–25 lines

### 4. Concrete-first walkthrough

- Cover each Definition/Theorem (or equivalent label) from the main file in order
- For each: cite it by exact number/name, give one concrete example,
  one memory-hook slogan (bold or italicized), note a common trap
- If the main file has a worked example, refer to it explicitly
- Full prose, no bullets; `###` sub-headings allowed inside this section
- Length: ~40–60 lines

### 5. Proof roadmaps

- **Key tricks only** — NOT full proofs, NOT base-case + inductive-step writeouts
- For each theorem/result: 1 paragraph (5–10 lines) describing the proof strategy, the one
  "aha" move, and why the argument works
- Target ~8–12 lines per result, total section ~15–25 lines
- Signal to check: if this section has `\blacksquare`, `QED`, or a multi-line algebra block,
  it has reproduced a full proof — trim it

### 6. Flashcards

Format (exact):
```markdown
**Q:** [question]

**A:** [answer]
```

Rules:
- Exactly **6–10** `**Q:**`/`**A:**` pairs
- Blank line between each pair
- Cover: key definition, key theorem, core formula, proof technique, common trap,
  application — aim for breadth across the day's concepts

---

## Format constraints

| Constraint | Value |
|---|---|
| Target line count | 180–220 (range: 150–250) |
| `##` headings | Exactly 6 (5 for Day 1) — no extra `##` headings |
| `###` sub-headings | Allowed freely inside any section |
| Bullet points | Only inside Flashcards; everywhere else: full prose paragraphs |
| Full proofs | Never — hint ladders / key tricks only |
| Citation numbers | Must match exactly what appears in the main content file |

**Why 180–220 and not just 150?** Implementers systematically hit 130–145 lines when aiming for
the 150 floor. Targeting the middle of the range produces files safely within spec.

---

## Implementer prompt template

Replace `[PLACEHOLDERS]` with subject-specific values from the day's brief.

```
You are writing Task [N] (Day [DD] primer — [Topic name]).

**Brief:** Read `/path/to/.superpowers/sdd/plan-name/task-N-brief.md` first — it is your
requirements and contains the exact numbers, concept names, and hook example to use verbatim.

**Main content reference:** `/path/to/content/dayDD.md`
Use this ONLY to verify that every label you cite actually exists there.

**Output file:** `/path/to/content/primers/dayDD.md`

**Domain context:**
- Citation format: [e.g., "Definition 4.1 / Theorem 3.2" or "Algorithm X" or "Gate X"]
- Pictures type: [e.g., geometric diagrams / execution traces / circuit diagrams]
- Section 5 name: [e.g., "Proof roadmaps" / "Algorithm analysis roadmaps" / "Derivation roadmaps"]
- Path structure: [sequential day-by-day / branching prerequisites]

**Structure — six sections in this exact order:**
1. `## Warm-up` — 3 prior days named by file path (primers/dayXX.md), 1 sentence each on what they covered
2. `## The hook` — concrete example with exact numbers from the brief
3. `## The pictures` — 3 described visuals, full prose
4. `## Concrete-first walkthrough` — each key concept cited by exact label, with memory hook slogans
5. `## [Proof/Algorithm analysis/Derivation/Reasoning] roadmaps` — key tricks only, NOT full derivations; 8–12 lines per result
6. `## Flashcards` — exactly 6–10 **Q:** / **A:** pairs

**Hard rules:**
- No extra `##` headings beyond these 6 (use `###` freely inside sections)
- No bullet points outside Flashcards — full prose paragraphs everywhere else
- Roadmaps section: if you have written more than 12 lines per result or reproduced a
  full derivation, trim to the key trick only
- Target 180–220 lines (hard range 150–250)

**Before reporting DONE, run these three checks from the project root:**
1. `grep -c "^## " content/primers/dayDD.md` → must equal 6
2. `grep -c "^\*\*Q:" content/primers/dayDD.md` → must equal 6–10
3. `wc -l content/primers/dayDD.md` → must be 150–250

Report: DONE + (sections=N, flashcards=N, lines=N)
```

---

## Reviewer checklist

**Critical:** use `grep -c "^## "` to count sections — **never visual scan**. Bold text
(`**bold**`) looks like a heading but does not count. Only lines starting with `## ` count.

```
Review Task [N] (Day [DD] primer — [Topic]). No git commands.

Files:
- Brief: /path/to/task-N-brief.md
- Created: /path/to/content/primers/dayDD.md
- Main: /path/to/content/dayDD.md

Spec checks (run grep for each — do NOT visually scan):
1. `grep -c "^## "` = 6?
2. Section order: Warm-up → Hook → Pictures → Walkthrough → Roadmaps → Flashcards?
3. Warm-up names the correct 3 prior days (from brief)?
4. Hook uses the exact example specified in the brief (specific numbers)?
5. All labels cited exist in the main content file?
6. No full derivation reproduced (no **Proof.** blocks, no multi-line calculation blocks)?
7. `grep -c "^\*\*Q:"` = 6–10?
8. `wc -l` = 150–250?

Return: Spec ✅ or ❌ | Quality: Approved or [findings] | One-line summary
```

---

## Common failure modes and fixes

| Failure | Root cause | Fix |
|---|---|---|
| File 130–145 lines | Implementer aimed at 150 floor | Tell them to aim 180–220; be explicit in prompt |
| 7–9 `##` sections | Added extra conceptual sections | Fold extras into the 6 required sections |
| Reviewer says wrong section count | Misread `**bold**` as `##` heading | Run `grep -c "^## "` directly — never accept visual counts |
| Roadmap is a full derivation | Implementer wrote complete proof | Trim to "key trick" paragraph; add explicit 12-line cap |
| Warm-up says "primers/dayDD.md" (current file) | Self-referential path | Fix to cite actual prior-day files |
| Wrong topic label in warm-up | Copy-paste error | Verify labels match the correct day's actual topic |
| File 149 lines (1 under) | Off-by-one vs soft "~150" bound | Adjudicate compliant; 1 line is noise |

---

## Final verification sweep

Run this from the primers directory after all files are written:

```bash
cd content/primers
for f in day01.md day02.md day03.md ...; do
  echo "=== $f ==="
  echo -n "sections: "; grep -c "^## " $f
  echo -n "flashcards: "; grep -c "^\*\*Q:" $f
  echo -n "lines: "; wc -l < $f
done
```

What to flag:
- `sections` ≠ 6 (except day01 where 5 is correct — no Warm-up)
- `flashcards` outside 6–10
- `lines` outside 150–250 (allow day01 at 149 if no Warm-up)

Also scan warm-up sections manually (or with an agent) for:
- Self-referential file paths (e.g., "primers/dayDD.md" inside dayDD.md itself)
- Topic labels that don't match the actual day's content

---

## Adapting for subjects other than linear algebra

The process rules, format constraints, reviewer grep checks, and failure-modes table are
**fully subject-independent** — use them unchanged for any path.

Two things need a subject-specific override: the **section-5 name** ("Proof roadmaps") and
the **citation format** in the walkthrough. Everything else is stable.

### Domain type table

| Domain type | Examples | Rename "Proof roadmaps" to | Citation format in walkthrough |
|---|---|---|---|
| Math-heavy | Linear algebra, calculus, statistics | Proof roadmaps (keep as-is) | "Definition 4.1", "Theorem 3.2" |
| CS / Algorithms | Algorithms, data structures, system design | Algorithm analysis roadmaps | "Algorithm X", "Claim: O(n log n)", pseudocode label |
| Physics / Quantum | Quantum computing, classical mechanics | Derivation roadmaps | "Gate X", "Postulate N", "Circuit: [name]" |
| Engineering | Networking, distributed systems, cloud | Reasoning roadmaps | "Principle X", "Protocol Y", component name |

### What changes per domain

**Section 5 — roadmaps**

For **CS/Algorithms**: describe the correctness argument and complexity class, not a math proof.
Key content: loop invariant idea, why the greedy choice is safe, the recurrence and its closed
form, why an amortized bound holds. Target: 1 paragraph per algorithm (8–12 lines).

For **Quantum/Physics**: describe the derivation steps without reproducing the full calculation.
Key content: what state/operator transforms to what, which approximation is made and why it holds,
what the circuit does at each step. Avoid full bra-ket algebra. Target: 1 paragraph per result.

For **Engineering paths**: describe the reasoning chain — why a design decision is correct, which
constraint it satisfies, what failure mode it prevents. Think "design rationale roadmap."

**Section 3 — The pictures**

Adapt "picture" to whatever visual aids are natural for the domain:
- Math: geometric diagrams, coordinate planes, matrix visualizations
- Algorithms: execution traces, call trees, array states before/after, graph layouts
- Quantum: circuit diagrams, Bloch sphere states, probability amplitude bars
- Engineering: architecture diagrams, sequence diagrams, data-flow sketches

The rule stays the same: describe the visual in prose (no actual image files), explain what to
look for, name the insight it delivers.

**Section 4 — citation format**

Replace "Def/Thm" with whatever the main content files use:
- Algorithms: "Algorithm 3.1", complexity claims, pseudocode labels
- Quantum: gate names, postulate numbers, circuit names
- Engineering: component names, protocol names, principle numbers

The reviewer check "All cited labels exist in the main file" is unchanged — just grep for the
actual label format used in the subject.

### Warm-up back-day schedule for non-sequential paths

For paths where days are not strictly sequential (e.g., a topic graph with branches), build a
warm-up schedule table in the README that explicitly lists which 3 days each primer should
review. Use shortest-path prerequisite distance to pick the 3 most relevant prior days.

### Quick checklist for a new subject

Before dispatching the first implementer on a new path, answer these five questions and
include the answers as a "Domain context" block in every implementer prompt:

1. What is the main content file format? (numbered Def/Thm / pseudocode / circuit names)
2. What type of "pictures" make sense for this domain?
3. What should "Proof roadmaps" be called? (use the domain table above)
4. Is the path sequential (Day 1 → Day 2 → …) or does it have branching prerequisites?
5. Does Day 1 have prior material to review? (if not, omit Warm-up from the first primer)

---

## Execution notes from the linear algebra run

- 22 primers, ~6–8 implementer fix rounds total across all files
- Most common issue: short files (130–145 lines) — solved by targeting 180–220
- Second most common: proof roadmaps reproducing full proofs — solved with explicit prose cap
- Section-count errors by reviewers using visual scan — solved with mandatory grep
- Warm-up self-referential paths — caught in final verification sweep, fixed with targeted edits
- Parallel execution (dispatch all implementers simultaneously) works fine since files are
  independent; sequential was ~3× slower
- Day 1 (no Warm-up) and the final verification pass are the only tasks that need special handling
