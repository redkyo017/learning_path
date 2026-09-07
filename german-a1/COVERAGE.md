# Coverage audit — spec vs. shipped path

Audited 2026-09-07 against `docs/superpowers/specs/2026-09-07-goethe-a1-design.md`.
Every "Satisfied by" cell below was checked by opening the named file; every "Verified how"
command was run from the repo root and its output read. Gaps are recorded as gaps, not
softened.

## Structural requirements

| Spec requirement | Satisfied by | Verified how |
|---|---|---|
| 50-day timeline, `day01.md`–`day50.md`, zero-padded, no gaps | `content/day01.md` … `content/day50.md`; phase map and day index in `README.md` §Phase map and §Day index | `ls german-a1/content/day*.md \| wc -l` → `50`; the `seq -w 1 50` existence loop printed no `missing dayNN.md` line |
| Four-block daily loop, never reordered (Anki 25 / Input 40 / Output 40 / Exam drill 30) | The four `### Block N` headings in all 50 day files; `runbook.md` §The session formula; `README.md` §How to use this plan step 2 | VERIFY-STRUCTURE over all 50 files: `structure check complete` with no `MISSING` line, so all four block headings are present, verbatim and in the skeleton's order, in every file |
| Tier 1 = 650 words | `vocabulary/tier1_wortliste.csv`; the 14 themed lists in `vocabulary/wordlists/`; day slices in `README.md` §Day index (25/day, days 03–28) | Quote-aware CSV check → `tier1_wortliste.csv: 650 rows`; wordlist entry count across the 14 files (bolded entry lines minus the two bolded header lines each) → `TOTAL: 650` |
| Tier 2 = 320 words | `vocabulary/tier2_fluency.csv`; `README.md` §Quick reference; `STRATEGY.md` §Vocabulary tiers; `content/day50.md` | Quote-aware CSV check → `tier2_fluency.csv: 320 rows`. Wording reconciled after this audit: the spec, plan, `STRATEGY.md` and `day50.md` had carried the pre-build estimate `~350`; all now read 320 across days 32–41 (10 × 32 = 320), matching the shipped deck and the day index |
| Tier 3 deferred until after the exam; not built here | `STRATEGY.md` §Vocabulary tiers, Tier 3 row: "~1000 · A2 bridge vocabulary · After the exam — not part of this path"; `content/day50.md` §Done when, final checkbox | Read both. No `tier3*` file exists — the full file listing under `german-a1/` contains only `tier1_wortliste.csv` and `tier2_fluency.csv` in `vocabulary/` |
| Five approved resources, and no other external link | `README.md` §Resources (all five, annotated with cost); linked in context from the day files and `runbook.md` | `grep -rhoE 'https?://[^ )]+' german-a1 --include='*.md' --exclude-dir=docs \| sed 's/[.,]$//' \| sort -u` → exactly the five approved URLs, nothing else. The same grep over `vocabulary/*.csv` returned nothing |
| Duolingo/Babbel named only in the mistakes list, never linked, never instructed | `STRATEGY.md` §Mistakes that waste 80% of your time → "Duolingo streaks" | Link check above shows no Duolingo/Babbel URL anywhere; the names appear only in that STRATEGY section and the spec's rejected-alternatives paragraph |
| Four Vietnamese-L1 interference items, each drilled rather than mentioned | `STRATEGY.md` §Vietnamese-L1 interference: "Articles (no gender in Vietnamese)", "Final consonants and clusters", "Verb conjugation (Vietnamese verbs do not inflect)", "Tone versus sentence intonation"; drills in `templates/pronunciation_drills.md` (`ü`, `ö`, both `ch`, uvular `r`, final consonant release, clusters, intonation vs. Vietnamese tone) | Read the heading list of both files: all four items present as their own subsections, each with a matching drill section in `pronunciation_drills.md` |
| Mistakes list | `STRATEGY.md` §Mistakes that waste 80% of your time — nine entries, from "Duolingo streaks" through "Ignoring the Sprechen keyword-card format until the final week" | Read the file's heading list: nine `###` subsections under that `##` |
| Anki CSV schema, identical in both decks, with article and plural on every noun | `vocabulary/tier1_wortliste.csv` and `vocabulary/tier2_fluency.csv`, header `german,article,plural,english,vietnamese,example,note` | Quote-aware CSV check over both files reported **no findings**: no bare noun, no noun without a plural, no non-noun carrying an article or plural, no row missing an English gloss, Vietnamese gloss or example, no example without final `.`/`?`/`!`, and no row with a column count other than 7 |
| Minimum-viable-day rule in every day file | `## Minimum viable day` in all 50 day files; the durable rule in `runbook.md` §Bad days (Block 1 + Block 3, 45 min) | VERIFY-STRUCTURE → `structure check complete`, no `MISSING` line for `## Minimum viable day` in any of the 50 files |
| Anki recovery rule | `runbook.md` §Anki recovery — one-day-missed rule, two-consecutive-days rule (new cards to 0 for three days), and the two absolute prohibitions (never delete the deck, never "forget" the deck) | Read the section in full |
| Every exercise ships a hint and a solution sketch | The `## Exercises` block of all 50 day files | VERIFY-EXERCISES → `exercise check complete`, no file reported: every file has ≥3 hints and an equal number of solution sketches |
| No code anywhere in the path | Text-only tree — `content/`, `vocabulary/`, `templates/`, `docs/` | `find german-a1 -name '*.py' -o -name '*.sh' -o -name '*.tf' -o -name '*.go'` → `OK: no code` |
| Grammar ceiling: no case tables, adjective endings, Genitiv, Konjunktiv, Passiv | Akkusativ and Dativ are taught only as fixed chunks (`README.md` §Day index days 10 and 24; `content/day10.md`, `content/day24.md`); no declined attributive adjective is put in front of the learner | Three violations found in this audit and fixed: `content/day40.md` exercise 3 solution sketch (`die erste Lesen-Frage` → `Ich habe bei Lesen Teil 1 zu schnell gelesen.`), `tier1_wortliste.csv` row 14 (`ein neues Wort` → `Ich lerne heute ein Wort.`), row 461 (`eine gute Gewohnheit` → `Das ist meine Gewohnheit.`). Row count, order, headwords, articles, plurals, glosses and theme slugs unchanged — the 650-row count was re-verified after the edit |
| Every file in the path reachable from `README.md` | `README.md` §Quick reference | Compared the quick-reference table against the full `find german-a1 -type f` listing. Five rows were missing and have been added: `README.md` itself, the design spec, the plan, the worknotes ledger, and this file |
| Day index matches the authoritative day→theme map | `README.md` §Day index, days 03–28 | Compared all 26 slice rows against the computed day→theme map (`25*(N-3)+1 .. 25*(N-2)`). All 26 match on both word range and theme name(s); all 14 themes are covered; all 50 rows present |

## Success criteria (spec §Success Criteria)

| Spec requirement | Satisfied by | Verified how |
|---|---|---|
| 1 — Score 75+ on a full official model test, timed | `content/day50.md` §Block 2–4 (all four modules timed under exam-day conditions) and §Done when, which branches explicitly on the total: 75+ → book for ~day 56; 60–74 → repeat days 43–50; below 60 → return to day 32. Six mocks total (days 31, 42, 44, 46, 48, 50) logged in `progress_tracker.md` §Mock log; gates restated in `README.md` §Phase map | Read `content/day50.md` end to end: the three thresholds appear in exercise 1's solution sketch and again as the §Done when branch. `progress_tracker.md` §Mock log and §Checkpoints exist and carry the Mock 1–6 rows |
| 2 — Teil 1 self-introduction from memory: name, age, country, residence, languages, job, hobby, plus spelling aloud and a phone number digit by digit | `templates/sprechen_scripts.md` §Teil 1 (seven-sentence script with bracketed slots), §Buchstabieren, §Nummer; drilled in `content/day02.md` (Buchstabieren, 0–20) and `content/day03.md` (phone numbers digit by digit, incl. the `zwei`/`zwo` trap); gated at `content/day17.md` — three unbroken takes from memory, recorded; recited cold again in `content/day50.md` exercise 2 | Read all five files. The script covers all seven required facts; `day17.md` §Done when requires "delivered from memory, unhesitating, recorded, and logged" |
| 3 — Ask and answer a Teil 2 keyword-card question for any of the 14 themes | `templates/sprechen_scripts.md` §Teil 2 — a Frage/Antwort frame for each of the 14 Tier-1 themes, plus the keyword→question drill (Thema + Stichwort → question); live rehearsal in `content/day33.md` (italki #1, Teil 1 and Teil 2) and `content/day41.md` (full Sprechen simulation) | Read the Teil 2 table: 14 rows, one per theme slug `01_personal` … `14_communication`, matching the theme slugs used in both CSV decks |
| 4 — Schreiben Teil 2 in under ten minutes, all three prompt points, correct register | `templates/schreiben_templates.md` §Teil 2 with an informal and a formal worked example plus the comma trap; `content/day38.md` — a new formal Teil 2 message written under a 10-minute clock, ~30 words, three points checked | Read both. `day38.md` §Done when: "A new formal Teil 2 message is written in under 10 minutes, about 30 words" |
| 5 — Produce all 650 Tier 1 words with correct article and plural for every noun | `vocabulary/tier1_wortliste.csv` (schema makes a bare noun impossible); the 14 human-readable lists in `vocabulary/wordlists/`; article-plus-plural recall drilled in the day-file exercises across the deck-building days (e.g. `content/day16.md`, `content/day17.md` exercise 3) | Quote-aware CSV check over the 650 rows: no bare noun, no noun without a plural. Uncountables carry their article plus the literal `kein Plural` as the spec requires, so no core word was dropped for lacking a plural |
| 6 — Fill a German form (Teil 1) without the three traps | `templates/schreiben_templates.md` §Teil 1 — Formular ausfüllen, "Three traps": date order TT.MM.JJJJ, Postleitzahl before Wohnort, handwritten Unterschrift; drilled in `content/day25.md` (exercises 2 and 3, anti-patterns, §Done when) | Read both files. All three traps are named in the template and each is exercised by name in `day25.md`, whose §Done when requires "a practice Schreiben Teil 1 form filled in with all three traps checked" |

## Resolved during the build

Both items this section previously listed as open have been closed. They are kept here as a record
of what changed, not as outstanding work.

1. **Tier 2 size wording — resolved.** The spec, plan, `STRATEGY.md` and `content/day50.md` had
   carried the pre-build estimate `~350` against a shipped 320-row deck. All now read 320 across
   days 32–41 (10 × 32 = 320), matching the deck and the README day index.
2. **Übungssatz-supply rule relocated — resolved.** The durable rule lives in `runbook.md`
   §Mock papers and the Übungssatz supply. `content/day42.md` points there rather than restating
   it, and days 44, 46, 48 and 50 were repointed at the runbook section.

## Open items

None. Every finding from the whole-path review and its scoped re-review was either fixed or
explicitly ruled on; the rulings and their stated costs are recorded in
`docs/superpowers/worknotes/2026-09-07-sdd-ledger.md`.

**One honest limitation, not a defect.** Goethe publishes only a small number of free official
practice sets, so the later mocks are usually re-sits. A re-sat paper inflates the score. The
booking gate on day 50 should therefore rest on a first-sitting paper wherever one remains — this
is stated in `runbook.md` and in each mock day, rather than hidden.
