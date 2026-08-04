# Encoding Primers — How to Use This Companion

## What Primers Are

The 30-day linear algebra plan teaches core concepts through a traditional order: abstract definition → theorem → proof → one worked example → memory aids. Primers are an **encoding-side companion** that flips the sequence: you read a primer *before* the matching day file to front-load intuition, pictures, and memory hooks, then move to the main day file with concrete foundation already in place.

Each primer is a ~20-minute read plus a ~10-minute warm-up, designed to be read before `content/dayNN.md`.

## Why Primers

The 2026-08-04 content feasibility review identified the plan's main comprehension weakness: abstraction-first ordering combined with zero diagrams in a geometric subject. Primers address this through four encoding-side techniques proven to boost retention:

1. **Concrete before abstract:** Every definition starts with a tiny numeric example, then moves to the abstract statement.
2. **Pictures:** Each day's core ideas are sketched with ASCII/Unicode diagrams in plain markdown — the geometric story the theorems formalize.
3. **Graduated proof hints:** Instead of "prove it from scratch" or "read the full proof," proofs are scaffolded: key trick in one sentence → first move → middle rung → full sketch.
4. **Daily spaced retrieval:** Each primer's warm-up section reviews flashcards from prior days, closing the forgetting curve between the plan's 5–6-day-spaced review days.

## Six-Section Structure

Every primer follows the same fixed structure (five sections for Day 1 — no warm-up on the first day):

1. **Warm-up (retrieval first).** Instructions to refresh flashcards from three prior days — the two most recent content days plus one from roughly a week back. ~10 min.

2. **The hook.** One concrete numeric problem the day's material exists to solve. Stated with actual numbers, attempted with previous days' tools, showing exactly where they break down. Resolved at the end with "today's concept is the fix" — not the full solution.

3. **The pictures.** One ASCII/Unicode sketch per major concept with a plain-language caption — the geometric intuition behind the theorems. No external images.

4. **Concrete-first walkthrough.** For each definition or theorem: a tiny numeric example → the pattern it exhibits → the formal statement (citing the main file's numbering) → a one-line memory hook (slogan, etymology, or name-origin where it helps).

5. **Proof roadmaps.** For each proof the plan expects you to attempt: the key trick in one sentence, then graduated hints — *first move* → *middle rung* → *full sketch* — never the full proof itself.

6. **Flashcards.** 6–10 Q/A pairs per day for offline self-check. Format: `**Q:** … / **A:** …`. These cards become part of the warm-up for later days.

## Warm-up Schedule

Before reading each primer, work through the flashcards from the indicated prior days. The rule encoded is: **the two most recent content days + one from roughly a week back.**

| Primer day | Warm up with flashcards from |
|---|---|
| 1 | — (first day) |
| 2 | 1 |
| 3 | 2, 1 |
| 4 | 3, 2, 1 |
| 5 | 4, 3, 1 |
| 6 | 5, 4, 1 |
| 8 | 6, 5, 1 |
| 9 | 8, 6, 2 |
| 10 | 9, 8, 3 |
| 11 | 10, 9, 4 |
| 12 | 11, 10, 5 |
| 14 | 12, 11, 6 |
| 15 | 14, 12, 8 |
| 16 | 15, 14, 9 |
| 17 | 16, 15, 10 |
| 19 | 17, 16, 11 |
| 20 | 19, 17, 12 |
| 21 | 20, 19, 14 |
| 22 | 21, 20, 15 |
| 23 | 22, 21, 16 |
| 25 | 23, 22, 17 |
| 26 | 25, 23, 19 |

## What's Not Here

**Review days (7, 13, 18, 24, 27):** These days consolidate previous material and have no primers — their retrieval design is already the plan's strength.

**Capstone/exam days (28–30):** These days introduce no new theory and require no primers.

**Originals untouched:** All `content/dayNN.md` files remain byte-identical. Primers are a purely additive companion.

---

**Ready?** Start with `primers/day01.md`, then read `content/day01.md`. The sequence is primer first, main file second.
