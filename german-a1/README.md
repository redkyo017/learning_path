# Goethe-Zertifikat A1: Start Deutsch 1 — 50-Day Sprint

## Learner profile

| Field | Value |
|---|---|
| Starting level | Zero — no prior German |
| L1 | Vietnamese |
| Daily time | 2–2.5 h/day |
| Purpose | Migration preparation |
| Budget | ~$150 total |

## How to use this plan

1. Open today's file: `content/dayNN.md`.
2. Run the four blocks in order — Anki, Input, Output, Exam drill.
3. Log your results to `progress_tracker.md`.
4. Never skip Block 1, even on a bad day.

## Phase map

| Phase | Days | h/day | Goal | Gate |
|---|---|---|---|---|
| 0 — Recon | 1–3 | 2.25 | See the real exam; wire Anki; drill the sounds Vietnamese lacks | Alphabet and numbers 0–100 aloud |
| 1 — Engine | 4–17 | 2.25 | Nicos Weg, first half; Wortliste words 1–375 (themes 01–08); Sprechen Teil 1 locked | Teil 1 from memory, recorded |
| 2 — Expansion | 18–31 | 2.25 | Nicos Weg, second half; Wortliste words 376–650 (themes 08–14, all 650 done); Perfekt and modals; Schreiben templates | First full mock, day 31 |
| 3 — Output | 32–42 | 2.25 | Tier 2 deck; italki 2×/week; full timed modules | Full mock 60+, day 42 |
| 4 — Simulation | 43–50 | 2.25 | Four timed mocks alternating with error-patching days | Full mock 75+, day 50 → book exam ~day 56 |

"First half" and "second half" of Nicos Weg are this path's own division of the single DW
A1 course — DW publishes Nicos Weg A1 as one course of roughly 76 short episodes, with no
official split into two sub-levels and no chapter numbering. Day files therefore cite episodes by
topic ("the travel-themed episode"), never by a chapter number.

## Quick reference

| Need | File |
|---|---|
| Daily lesson for day NN | `content/dayNN.md` |
| Plain-English grammar, exam and Anki terms | `content/GLOSSARY.md` |
| The top-1% method, mistakes list, Vietnamese-L1 interference | `STRATEGY.md` |
| Daily startup, block formula, bad-day and Anki recovery rules | `runbook.md` |
| Checkpoint gates, mock score log, Anki streak log | `progress_tracker.md` |
| Tier 1 deck, 650 words, Anki-importable | `vocabulary/tier1_wortliste.csv` |
| Tier 2 deck, 320 words (32/day, days 32–41) | `vocabulary/tier2_fluency.csv` |
| Themed, human-readable word lists (14 files) | `vocabulary/wordlists/01_personal.md` … |
| IPA sound inventory, spelling-to-sound rules, how to look a word up | `content/PRONUNCIATION.md` |
| Vietnamese-specific sound fixes | `templates/pronunciation_drills.md` |
| Sprechen Teil 1–3 scripts and frames | `templates/sprechen_scripts.md` |
| Form-filling and short-message templates | `templates/schreiben_templates.md` |
| This overview — learner profile, phase map, day index, resource list | `README.md` |
| Curated resources beyond the core five — dictionaries, pronunciation lookup, extra practice | `RESOURCES.md` |
| The design spec this path is built to | `docs/superpowers/specs/2026-09-07-goethe-a1-design.md` |
| The implementation plan behind the spec | `docs/superpowers/plans/2026-09-07-goethe-a1-plan.md` |
| Authoring worknotes and task ledger | `docs/superpowers/worknotes/2026-09-07-sdd-ledger.md` |
| Spec-requirement coverage audit | `COVERAGE.md` |

## Day index

**New-card pacing, binding for the whole path:** 25 new Tier-1 cards a day on days 03–28
only — 26 contiguous, non-overlapping slices covering words 1–650 (day 03 = words 1–25,
day 04 = 26–50, … day 28 = 626–650). Zero new cards on days 29, 30 and 31. Tier 2 runs at
32 new cards a day on days 32–41. Zero new cards from day 42 to day 50 — day 42 is a full
mock and mocks never introduce new material. Reviews continue
every single day regardless; only *new* cards ever stop.

The theme labels below are read off the finished `vocabulary/tier1_wortliste.csv` row
order, not estimated: the 14 themes run between 42 and 55 words each, so a 25-word slice
often straddles two themes — where it does, both are named.

Tier 2 works the same way. Days 32–41 each take a contiguous 32-word slice of
`vocabulary/tier2_fluency.csv` in file order (day 32 = words 1–32, … day 41 = 289–320, all
320 introduced). Its seven groups run between 36 and 55 words each and none is a multiple
of 32, so most days straddle two groups — where they do, both are named.

| Day | Phase | Focus |
|---|---|---|
| 01 | 0 — Recon | See the exam |
| 02 | 0 — Recon | Buchstabieren and 0–20 |
| 03 | 0 — Recon | 21–100 and the reversed digits; first Anki slice — theme 01_personal, words 1–25 |
| 04 | 1 — Engine | `sein` (all persons) — themes 01_personal / 02_family, words 26–50 |
| 05 | 1 — Engine | `haben` (all persons) — theme 02_family, words 51–75 |
| 06 | 1 — Engine | Regular present endings — themes 02_family / 03_time, words 76–100 |
| 07 | 1 — Engine | W-questions (Wie/Wo/Woher/Was/Wann) — theme 03_time, words 101–125 |
| 08 | 1 — Engine | Yes/no question word order — themes 03_time / 04_home, words 126–150 |
| 09 | 1 — Engine | `der/die/das` + plural drilling — theme 04_home, words 151–175 |
| 10 | 1 — Engine | Akkusativ as a fixed chunk (`einen/eine/ein`) — themes 04_home / 05_food, words 176–200 |
| 11 | 1 — Engine | `nicht` and `kein` — theme 05_food, words 201–225 |
| 12 | 1 — Engine | Possessives `mein/dein/Ihr` — themes 05_food / 06_health, words 226–250 |
| 13 | 1 — Engine | Separable verbs (`aufstehen`, `einkaufen`) — theme 06_health, words 251–275 |
| 14 | 1 — Engine | Time expressions `um/am/im` — themes 06_health / 07_work, words 276–300 |
| 15 | 1 — Engine | `es gibt` — theme 07_work, words 301–325 |
| 16 | 1 — Engine | Imperative (for Sprechen Teil 3) — themes 07_work / 08_travel, words 326–350 |
| 17 | 1 — Engine | Consolidation — theme 08_travel, words 351–375; Phase 1 checkpoint: Teil 1 from memory, recorded |
| 18 | 2 — Expansion | Perfekt with `haben` — themes 08_travel / 09_city, words 376–400 |
| 19 | 2 — Expansion | Perfekt with `sein` — themes 09_city / 10_routine, words 401–425 |
| 20 | 2 — Expansion | Irregular Perfekt, high-frequency — theme 10_routine, words 426–450 |
| 21 | 2 — Expansion | `können` / `müssen` — themes 10_routine / 11_clothes, words 451–475 |
| 22 | 2 — Expansion | `wollen` / `möchten` — theme 11_clothes, words 476–500 |
| 23 | 2 — Expansion | `dürfen` / `sollen` — themes 11_clothes / 12_weather, words 501–525 |
| 24 | 2 — Expansion | Dativ as fixed chunks (`mit dem Bus`, `zum Arzt`) — theme 12_weather, words 526–550 |
| 25 | 2 — Expansion | Prepositions of place — themes 12_weather / 13_freetime, words 551–575; Schreiben Teil 1 and its three traps |
| 26 | 2 — Expansion | `weil` as a memorised chunk — theme 13_freetime, words 576–600 |
| 27 | 2 — Expansion | `dass` as a memorised chunk — themes 13_freetime / 14_communication, words 601–625 |
| 28 | 2 — Expansion | Comparatives `gut/besser`, `gern/lieber` — theme 14_communication, words 626–650 — Tier 1 complete |
| 29 | 2 — Expansion | Verb-second word order review — no new cards |
| 30 | 2 — Expansion | Consolidation; mock preparation — no new cards |
| 31 | 2 — Expansion | First full mock — all four modules, timed; score and log — no new cards |
| 32 | 3 — Output | Tier 2 words 1–32, t2_connectors; 90-second monologue on 08_travel |
| 33 | 3 — Output | Tier 2 words 33–64, t2_connectors / t2_modals; italki session #1 — Teil 1 and Teil 2 live |
| 34 | 3 — Output | Tier 2 words 65–96, t2_modals / t2_verbs; transcribe day-32 recording and self-correct |
| 35 | 3 — Output | Tier 2 words 97–128, t2_verbs; 90-second monologue on 13_freetime |
| 36 | 3 — Output | Tier 2 words 129–160, t2_verbs / t2_adverbs; italki session #2 — Teil 3 requests |
| 37 | 3 — Output | Tier 2 words 161–192, t2_adverbs / t2_opinion; transcribe day-35 recording and self-correct |
| 38 | 3 — Output | Tier 2 words 193–224, t2_opinion / t2_smalltalk; Schreiben Teil 2 in under 10 minutes, formal register |
| 39 | 3 — Output | Tier 2 words 225–256, t2_smalltalk; italki session #3 — unscripted small talk |
| 40 | 3 — Output | Tier 2 words 257–288, t2_smalltalk / t2_examphrases; 90-second monologue on 07_work |
| 41 | 3 — Output | Tier 2 words 289–320, t2_examphrases — Tier 2 complete; italki session #4 — full Sprechen simulation |
| 42 | 3 — Output | Full mock — gate 60+ |
| 43 | 4 — Simulation | Patching: day-42 error log; re-drill missed Hören items at half speed |
| 44 | 4 — Simulation | Full mock — all four modules, timed; score and log |
| 45 | 4 — Simulation | Patching: day-44 error log; rewrite every failed Schreiben answer |
| 46 | 4 — Simulation | Full mock — all four modules, timed; score and log |
| 47 | 4 — Simulation | Patching: day-46 error log; re-record every stalled Sprechen answer |
| 48 | 4 — Simulation | Full mock — all four modules, timed; score and log |
| 49 | 4 — Simulation | Patching: day-48 error log; exam-day logistics — ID, centre, arrival time, what to bring |
| 50 | 4 — Simulation | Final mock, timed, then the booking decision |

## Resources

- [DW Nicos Weg A1](https://learngerman.dw.com/en/nicos-weg/c-36519789) — complete free A1 video course, used for Block 2 shadowing throughout. Free.
- [Goethe Start Deutsch 1 exam page](https://www.goethe.de/en/spr/kup/prf/prf/sd1.html) — official exam format, centres and booking. Free to browse; the exam fee is paid at booking.
- [Goethe A1 practice materials](https://www.goethe.de/en/spr/kup/prf/prf/sd1/ueb.html) — official model tests (Übungssätze) and the Wortliste that bounds this whole plan. Free.
- [Anki](https://apps.ankiweb.net/) — spaced-repetition flashcards, used for Block 1 every day. Free on desktop.
- [italki](https://www.italki.com) — community tutors for live speaking practice from week 3. ~$8–10/hr.

For dictionaries, pronunciation lookup, extra practice sites, and unverified extras, see `RESOURCES.md`.
