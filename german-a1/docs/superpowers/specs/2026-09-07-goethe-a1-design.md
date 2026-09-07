# Goethe-Zertifikat A1: Start Deutsch 1 — Design Spec

**Date:** 2026-09-07
**Location:** `german-a1/`
**Duration:** 50 days, ~2.25 h/day (~112h total)

## Purpose & Goals

The learner is at absolute zero in German and needs the Goethe-Zertifikat A1: Start
Deutsch 1 as migration preparation. No exam date is booked, so the timeline is set by
readiness rather than by a deadline — but the certificate's validity window means the
exam should be sat promptly once a mock predicts a pass, not deferred indefinitely.

Mastery here is deliberately narrow. A1 is not "speaking German"; it is passing four
specific modules — Hören, Lesen, Schreiben, Sprechen — whose declared vocabulary scope
is the ~650-word official Goethe Wortliste and whose grammar scope stops well short of
the case system. The unconventional strategy is to treat that narrowness as the whole
plan: reverse-engineer from the exam on day 1, learn grammar only when a Wortliste
sentence forces it, and spend the freed time on daily spoken output, which is the
quarter of the score that cannot be crammed.

The learner's L1 is Vietnamese, which changes what is hard. Vietnamese has no
grammatical gender, no verb inflection, almost no consonant clusters, no released final
consonants, and is tonal. Those five facts predict where the time will leak, so the path
targets them directly rather than teaching a generic beginner syllabus.

## Success Criteria

By the end of day 50, without notes, the learner can:

1. Score 75+ on a full official Goethe A1 model test taken under timed conditions
   (the pass mark is 60; the margin absorbs exam-day nerves).
2. Deliver the Sprechen Teil 1 self-introduction from memory, unhesitating, covering
   name, age, country, residence, languages, job and hobby, plus spell a word aloud and
   say a phone number digit by digit.
3. Ask and answer a Teil 2 keyword-card question for any of the 14 vocabulary themes.
4. Write a Schreiben Teil 2 short message addressing all three prompt points in under
   ten minutes, choosing correctly between the informal and formal register.
5. Produce all 650 Tier 1 words with correct article and plural for every noun.
6. Fill a German form (Teil 1) without falling for the three standard traps: date order,
   Postleitzahl before Wohnort, handwritten signature.

## Constraints & Environment

| Constraint | Rule |
|---|---|
| Path type | Language — text content only. **No `code/` or `labs/` directory, no simulations, no scripts.** Verification is by shell one-liners over the authored files. |
| Git | Never commit, stage or push on the learner's behalf. No `git` commands in any authoring subagent. |
| Credentials | No real personal data in any file. The Sprechen scripts use bracketed slots (`[Vorname]`), never the learner's actual details. |
| Toolchain | Anki (free desktop), a phone voice recorder, a printer for the mock papers. Nothing else. |
| Budget | ~$150 total: everything free except italki community-tutor sessions from week 3. |
| Exercises | Every exercise ships with a hint and a solution sketch. Non-negotiable. |
| Approved resources | Only the five links listed below may appear in any file. |
| Orthography | `ä ö ü ß` written literally, never `ae oe ue ss`. |
| Grammar ceiling | Never teach case tables, adjective endings, Genitiv, Konjunktiv or Passiv — none is tested at A1. |


> **Allowlist widened 2026-09-07 (learner decision).** Five more URLs are approved for
> `RESOURCES.md` and `content/PRONUNCIATION.md`: de.wiktionary.org, dwds.de, dict.cc,
> schubert-verlag.de/aufgaben/, deutsch.lingolia.com/en/grammar — each fetched and confirmed
> working. Four further sites (Forvo, LEO, Easy German, AnkiWeb shared decks) are real but
> could not be verified from this environment and are listed only under an explicit
> "unverified" heading. slowgerman.com and mein-deutschbuch.de refused connection and are
> rejected. Full list: scratchpad briefs/approved-urls-v2.md

**Approved resources** (the only external links permitted in the path):

- [DW Nicos Weg A1](https://learngerman.dw.com/en/nicos-weg/c-36519789) — complete free A1 video course
- [Goethe Start Deutsch 1 exam page](https://www.goethe.de/en/spr/kup/prf/prf/sd1.html) — format, centres, booking
- [Goethe A1 practice materials](https://www.goethe.de/en/spr/kup/prf/prf/sd1/ueb.html) — official model tests and the Wortliste
- [Anki](https://apps.ankiweb.net/) — spaced repetition, free on desktop
- [italki](https://www.italki.com) — community tutors, ~$8–10/hr

## Strategy (the core design decision)

**Exam-first reverse engineering.** The learner meets all four exam modules on day 1,
not in week 5. Everything after is judged by one question: does this move a module score?

The daily session is four fixed blocks, never reordered:

| Block | Time | Why it sits here |
|---|---|---|
| 1 — Anki | 25 min | Reps degrade sharply with fatigue, so they run before anything else, never last. |
| 2 — Input | 40 min | One Nicos Weg episode twice: once for gist, once shadowed aloud. Shadowing is what retrains Vietnamese tonal habits into German sentence melody. |
| 3 — Output | 40 min | Production every day from day 4. Sprechen is 25% of the score and is the one module that cannot be crammed in the final week. |
| 4 — Exam drill | 30 min | One timed task in real exam format, rotating modules. Format familiarity is worth more marks at A1 than extra vocabulary. |

**Vocabulary is tiered, not front-loaded.** The learner's instinct was a 2000-word deck.
The official Wortliste is ~650 words and bounds the entire exam; front-loading 2000 costs
roughly three extra weeks and buys zero exam points.

| Tier | Size | Content | When |
|---|---|---|---|
| 1 | ~650 | Official Goethe A1 Wortliste, 14 themes | Days 3–28, 25 new cards/day |
| 2 | 320 | Connectors, modals, high-frequency verbs — fluency, not coverage | Days 32–41, 32/day |
| 3 | ~1000 | A2 bridge | **After** the exam. Not built in this path. |

**Rejected alternatives.** A textbook course (Menschen A1, Schritte International) was
rejected: it paces to a classroom term, spends its first six weeks below exam tempo, and
teaches grammar the exam does not test. A pure comprehensible-input approach (Nicos Weg
end to end, then drill) was rejected: it produces recognition without production, and
Sprechen and Schreiben are half the score. App-gamified study (Duolingo, Babbel) was
rejected outright — it optimises for streaks over the Wortliste and is the single
largest documented time sink for exam-driven beginners.

**Vietnamese-L1 targeting.** Four transfer errors get dedicated drilling rather than
incidental correction: articles (no gender in Vietnamese, so nouns are only ever stored
as `der Tisch, die Tische`), final consonants and clusters (`Straße`, `sprichst`,
`Herbst`), verb conjugation (Vietnamese verbs do not inflect, so this is reps not
explanation), and tone versus sentence intonation (fixed by shadowing). Plus the sounds
Vietnamese lacks entirely: `ü ö`, both `ch` variants, and uvular `r`.

**Failure is designed for.** Every day file carries a 45-minute minimum viable version
(Anki plus one output block) for bad days, and the runbook carries an Anki recovery rule,
because a two-day lapse that turns into deck bankruptcy is how these plans actually die.

## Curriculum

| Phase | Days | h/day | Goal | Gate |
|---|---|---|---|---|
| 0 — Recon | 1–3 | 2.25 | See the real exam; wire Anki; drill the sounds Vietnamese lacks | Alphabet and numbers 0–100 aloud |
| 1 — Engine | 4–17 | 2.25 | Nicos Weg first half; Wortliste words 1–375; Sprechen Teil 1 locked | Teil 1 from memory, recorded |
| 2 — Expansion | 18–31 | 2.25 | Nicos Weg second half; Wortliste words 376–650 (deck complete day 28); Perfekt and modals; Schreiben templates | First full mock, day 31 |
| 3 — Output | 32–42 | 2.25 | Tier 2 deck; italki 2×/week; full timed modules | Full mock 60+, day 42 |
| 4 — Simulation | 43–50 | 2.25 | Four timed mocks alternating with error-patching days | Full mock 75+, day 50 → book exam ~day 56 |

Grammar reflexes, in the order a Wortliste sentence first demands them — days 4–17:
`sein`; `haben`; regular present endings; W-questions; yes/no word order; `der/die/das`
plus plural; Akkusativ as a fixed chunk; `nicht` and `kein`; possessives; separable
verbs; `um/am/im`; `es gibt`; imperative; consolidation. Days 18–31: Perfekt with
`haben`; Perfekt with `sein`; irregular Perfekt; `können`/`müssen`; `wollen`/`möchten`;
`dürfen`/`sollen`; Dativ as fixed chunks; prepositions of place; `weil`; `dass`;
comparatives; verb-second word order; consolidation; mock.

Day 50 ends with an explicit written branch: 75+ → book the exam for ~day 56; 60–74 →
repeat days 43–50 once; below 60 → return to day 32.

## Directory Layout

```
german-a1/
├── README.md                        # quickstart, phase map, day index, resource list
├── STRATEGY.md                      # the top-1% method, mistakes list, VN-L1 interference
├── runbook.md                       # daily startup, block formula, bad-day + Anki recovery rules
├── progress_tracker.md              # checkpoint gates, mock score log, Anki streak log
├── content/
│   ├── GLOSSARY.md                  # plain-English German grammar + exam + Anki terms
│   └── day01.md … day50.md          # one self-contained session each
├── vocabulary/
│   ├── tier1_wortliste.csv          # 650 words, Anki-importable
│   ├── tier2_fluency.csv            # 320 words
│   └── wordlists/01_personal.md …   # 14 themed human-readable lists
├── templates/
│   ├── pronunciation_drills.md      # Vietnamese-specific sound fixes
│   ├── sprechen_scripts.md          # Teil 1–3 scripts and frames
│   └── schreiben_templates.md       # form-filling + short-message templates
└── docs/superpowers/
    ├── specs/2026-09-07-goethe-a1-design.md
    └── plans/2026-09-07-goethe-a1-plan.md
```

No `code/` or `labs/` directory — this is a language path.

**Anki CSV schema**, identical in both deck files:

```
german,article,plural,english,vietnamese,example,note
Tisch,der,die Tische,table,cái bàn,Der Tisch ist groß.,04_home
gehen,,,to go,đi,Ich gehe nach Hause.,10_routine
```

Nouns (capitalised headwords) must carry a `der`/`die`/`das` article and a plural;
uncountable nouns (Milch, Fleisch, Reis, Salz) carry their article plus the literal
`kein Plural`, so that no core word is dropped for lacking a plural; non-nouns leave both
columns empty. Every row needs a Vietnamese gloss and a complete
German example sentence containing the headword. This schema is the mechanism that makes
criterion 5 achievable — a noun cannot enter the deck bare.

## Content Day Skeleton

```markdown
# Day NN — <Title>

**Phase:** N — <Name> | **Total:** 2h15 | **New cards:** NN

## Why this matters

<One short paragraph, concrete: which exam module today's work moves, and why now.>

## Core concepts

### Block 1 — Anki (25 min)
<Named word slice, e.g. "theme 03_time, words 101–125". Never "do your reps".>

### Block 2 — Input (40 min)
<Named Nicos Weg lesson. Two passes: gist, then shadowed aloud.>

### Block 3 — Output (40 min)
<Production task: speak or write. Recorded or timed.>

### Block 4 — Exam drill (30 min)
<One timed task in real exam format. Names the module and the source.>

## Exercises

1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
3. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>

## Anti-patterns / Common mistakes

- <mistake specific to today's material>
- <mistake specific to today's material>

## Minimum viable day

Block 1 + Block 3 only (45 min). See `runbook.md` §Bad days.

## Done when

- [ ] <checkable outcome>
- [ ] <checkable outcome>
```

Every exercise carries a hint and a solution sketch. For German this means the sketch
shows the target sentence, not just a rule — a learner at A1 cannot reconstruct
`Ich fahre mit dem Bus zur Arbeit.` from "use Dativ after mit".
