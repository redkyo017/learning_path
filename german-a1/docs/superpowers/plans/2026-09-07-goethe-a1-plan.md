# Goethe A1 Start Deutsch 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author a complete, runnable 50-day self-study path that takes a Vietnamese-L1 absolute beginner to a passing Goethe-Zertifikat A1: Start Deutsch 1.

**Architecture:** Pure content authoring — markdown day files, two CSV vocabulary decks, three reference templates. This is a **language path**: no `code/`, no `labs/`, no scripts, no simulations. Every task is verified by a shell one-liner over the authored files.

**Spec:** `german-a1/docs/superpowers/specs/2026-09-07-goethe-a1-design.md`

**Path type:** Language — text content only (per `skill.md` §Path Type Classification, treated as pure-science: code scaffold omitted).

## Global Constraints

Every task's requirements implicitly include this section. Values are copied verbatim from the spec.

- **No git.** Never run `git add`, `git commit`, `git push`, `git status`, `git diff` or `git log` — in this session or in any dispatched subagent. The learner handles all VCS.
- **No code.** No `.py`, `.sh`, `.tf`, `.go` files anywhere in `german-a1/`. Verification commands are run ad hoc from the shell; they are never saved as scripts.
- **No real personal data.** Sprechen scripts use bracketed slots (`[Vorname]`, `[Stadt]`), never the learner's actual name, address or phone number.
- **Every exercise ships a hint and a solution sketch.** Format, exactly:
  `1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>`
  For German, the sketch shows the target sentence, not just the rule.
- **CSV column order, fixed and identical in both deck files:**
  `german,article,plural,english,vietnamese,example,note`
- **Nouns are never bare.** A capitalised headword must have a `der`/`die`/`das` article and a
  plural. Non-nouns leave both columns empty. **Uncountable nouns** (Milch, Fleisch, Obst, Reis,
  Zucker, Salz, Butter, Wasser) keep their article and carry the literal text `kein Plural` in the
  plural column — never an empty column, and never omission from the deck.
- **Every row needs a Vietnamese gloss** (with full diacritics) and a complete German example sentence containing the headword, ending in `.`, `?` or `!`.
- **Exactly 50 day files** in `content/`, named `day01.md` … `day50.md`, zero-padded, no gaps.
- **Every day file carries all ten required headings** from the Content Day Skeleton (see File Structure below).

> **Allowlist widened 2026-09-07 (learner decision).** Five more URLs are approved for
> `RESOURCES.md` and `content/PRONUNCIATION.md`: de.wiktionary.org, dwds.de, dict.cc,
> schubert-verlag.de/aufgaben/, deutsch.lingolia.com/en/grammar — each fetched and confirmed
> working. Four further sites (Forvo, LEO, Easy German, AnkiWeb shared decks) are real but
> could not be verified from this environment and are listed only under an explicit
> "unverified" heading. slowgerman.com and mein-deutschbuch.de refused connection and are
> rejected. Full list: scratchpad briefs/approved-urls-v2.md

- **Approved links only** — these five and no others:
  - `https://learngerman.dw.com/en/nicos-weg/c-36519789`
  - `https://www.goethe.de/en/spr/kup/prf/prf/sd1.html`
  - `https://www.goethe.de/en/spr/kup/prf/prf/sd1/ueb.html`
  - `https://apps.ankiweb.net/`
  - `https://www.italki.com`
- **Duolingo and Babbel** may be named only in the mistakes list in `STRATEGY.md`, never linked, never instructed in a day file.
- **Orthography:** `ä ö ü ß` written literally, never `ae oe ue ss`.
- **Grammar ceiling:** never teach case tables, adjective endings, Genitiv, Konjunktiv or Passiv.

---

## Project Layout (target end state)

```
german-a1/
├── README.md                        # Task 1
├── STRATEGY.md                      # Task 2
├── runbook.md                       # Task 3
├── progress_tracker.md              # Task 1
├── content/
│   ├── GLOSSARY.md                  # Task 4
│   └── day01.md … day50.md          # Tasks 10–14
├── vocabulary/
│   ├── tier1_wortliste.csv          # Tasks 6–7
│   ├── tier2_fluency.csv            # Task 9
│   └── wordlists/01_personal.md …   # Task 8 (14 files)
├── templates/
│   ├── pronunciation_drills.md      # Task 5
│   ├── sprechen_scripts.md          # Task 5
│   └── schreiben_templates.md       # Task 5
└── docs/superpowers/{specs,plans}/  # already written
```

**The ten required day-file headings**, in order, verbatim:

```
# Day NN — <Title>
## Why this matters
## Core concepts
### Block 1 — Anki (25 min)
### Block 2 — Input (40 min)
### Block 3 — Output (40 min)
### Block 4 — Exam drill (30 min)
## Exercises
## Anti-patterns / Common mistakes
## Minimum viable day
## Done when
```

---

## Reusable verification commands

Tasks refer to these by name. Run from the repo root.

**VERIFY-STRUCTURE** — every day file has all ten headings:

```bash
for f in german-a1/content/day*.md; do
  for h in "## Why this matters" "## Core concepts" "### Block 1 — Anki (25 min)" \
           "### Block 2 — Input (40 min)" "### Block 3 — Output (40 min)" \
           "### Block 4 — Exam drill (30 min)" "## Exercises" \
           "## Anti-patterns / Common mistakes" "## Minimum viable day" "## Done when"; do
    grep -qF "$h" "$f" || echo "MISSING in $f: $h"
  done
done; echo "structure check complete"
```

**VERIFY-EXERCISES** — every exercise has a hint and a solution sketch, in equal number:

```bash
for f in german-a1/content/day*.md; do
  h=$(grep -c '\*\*Hint:\*\*' "$f"); s=$(grep -c '\*\*Solution sketch:\*\*' "$f")
  [ "$h" -ge 3 ] && [ "$h" = "$s" ] || echo "$f: hints=$h sketches=$s (need >=3 and equal)"
done; echo "exercise check complete"
```

**VERIFY-VOCAB** — schema, bare nouns, missing glosses, duplicates:

```bash
for f in german-a1/vocabulary/*.csv; do
  head -1 "$f" | grep -qx 'german,article,plural,english,vietnamese,example,note' \
    || echo "$f: bad header"
  python3 -c 'import csv,sys
f=sys.argv[1]
for i,r in enumerate(csv.reader(open(f,encoding="utf-8")),1):
    if i==1 or not r or not any(r): continue
    if len(r)!=7: print(f"{f}:{i}: wrong column count ({len(r)})"); continue
    g,a,pl,en,vi,ex,_=[c.strip() for c in r]
    noun=g[:1].isupper()
    if noun and a not in ("der","die","das"): print(f"{f}:{i}: bare noun {g}")
    if noun and not pl: print(f"{f}:{i}: noun without plural {g}")
    if not noun and (a or pl): print(f"{f}:{i}: non-noun with article/plural {g}")
    if not en or not vi or not ex: print(f"{f}:{i}: missing gloss or example {g}")
    if ex and ex[-1] not in ".?!": print(f"{f}:{i}: example lacks final punctuation {g}")
    for c in (" weil "," dass "," wenn "," denn "):
        if c in " "+ex and "," not in ex: print(f"{f}:{i}: {g} example needs a comma before the subordinate clause")
' "$f"
done
python3 -c 'import csv,collections
h=[r[0] for f in ("german-a1/vocabulary/tier1_wortliste.csv","german-a1/vocabulary/tier2_fluency.csv")
   for i,r in enumerate(csv.reader(open(f,encoding="utf-8"))) if i and r]
print([w for w,c in collections.Counter(h).items() if c>1] or "no duplicates")'
echo "vocab check complete"
```

**Known limits of the vocabulary checker** (both are checker artefacts, not content defects):
- It treats any capitalised headword as a noun, so the verb phrase `Rad fahren` reports as a
  "bare noun". `Rad` must be capitalised; the row is correct.
- Quoted CSV fields (required wherever German punctuation needs a comma) mean naive
  comma-splitting — `cut -d, -fN`, `awk -F,` — mis-parses those rows. Always use a CSV-aware
  reader. Anki imports quoted CSV correctly.

**VERIFY-LINKS** — allowlist across the whole path:

```bash
grep -rhoE 'https?://[^ )`]+' german-a1 --include='*.md' --exclude-dir=docs | sed 's/[.,:;]*$//' | sort -u
```
Expected: exactly the five approved URLs and nothing else.

**VERIFY-DAYS** — all 50 files, no gaps:

```bash
ls german-a1/content/day*.md | wc -l
for n in $(seq -w 1 50); do [ -f "german-a1/content/day$n.md" ] || echo "missing day$n.md"; done
```

**VERIFY-NO-CODE:**

```bash
find german-a1 -name '*.py' -o -name '*.sh' -o -name '*.tf' -o -name '*.go' | grep . && echo "FAIL: code found" || echo "OK: no code"
```

---

## Task 1: Scaffold, README, progress tracker

**Files:**
- Create: `german-a1/README.md`
- Create: `german-a1/progress_tracker.md`
- Create: directories `content/`, `vocabulary/wordlists/`, `templates/`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: the directory tree every later task writes into; the day-index and quick-reference tables in `README.md` that Task 15 audits

- [ ] **Step 1: Create the tree**

```bash
mkdir -p german-a1/{content,vocabulary/wordlists,templates}
```

- [ ] **Step 2: Write `german-a1/README.md`**

Contains, in order: H1 `# Goethe-Zertifikat A1: Start Deutsch 1 — 50-Day Sprint`; a learner-profile table (level zero, L1 Vietnamese, 2–2.5 h/day, migration prep, ~$150); a "How to use this plan" numbered list of four steps (open `content/dayNN.md`, run the four blocks in order, log to `progress_tracker.md`, never skip Block 1); the five-row phase table copied from the spec §Curriculum; a quick-reference table mapping need → file for every file in the Project Layout; a day index table `Day | Phase | Focus` with all 50 rows filled from the per-day tables in Tasks 10–14; and a Resources section listing all five approved links with one line each on what it is and what it costs.

- [ ] **Step 3: Write `german-a1/progress_tracker.md`**

Three tables. Checkpoints — `Checkpoint | Target | Actual | Date` with rows: Day 3 (alphabet + numbers 0–100 aloud), Day 17 (325 Tier-1 words mature; Teil 1 from memory), Day 31 (all 650 words; first full mock), Day 42 (mock 60+), Day 50 (mock 75+). Mock log — `Mock # | Date | Hören /25 | Lesen /25 | Schreiben /25 | Sprechen /25 | Total /100` with six blank rows (days 31, 42, 44, 46, 48, 50). Anki log — `Week | Days hit /7 | New cards | Mature cards | Notes` with eight blank rows.

- [ ] **Step 4: Verify**

Run VERIFY-LINKS (README only is fine at this stage) and:
`find german-a1 -type d | sort`
Expected: `german-a1`, `content`, `docs`, `docs/superpowers`, `docs/superpowers/plans`, `docs/superpowers/specs`, `templates`, `vocabulary`, `vocabulary/wordlists`.

- [ ] **Step 5: Report** the two files and their line counts. No git.

---

## Task 2: STRATEGY.md

**Files:**
- Create: `german-a1/STRATEGY.md`

**Interfaces:**
- Consumes: spec §Strategy
- Produces: section anchors `## The method`, `## Mistakes that waste 80% of your time`, `## Vietnamese-L1 interference`, `## What we deliberately do not do` — day files cite these by name

- [ ] **Step 1: `## The method`**

Exam-first reverse engineering. The four-block table with the *why* column from the spec. State the two rules that follow from it: grammar is learned only when a Wortliste sentence forces it; anything that does not move a module score is cut.

- [ ] **Step 2: `## Mistakes that waste 80% of your time`**

One subsection each — the mistake, why it *feels* productive, what to do instead (2–4 sentences): Duolingo streaks; learning case tables before the Wortliste; buying multiple textbooks; treating grammar as knowledge rather than reflex; delaying speaking until "ready"; passive video watching; learning nouns without article and plural; translating via English instead of Vietnamese→German; ignoring the Sprechen keyword-card format until the final week.

- [ ] **Step 3: `## Vietnamese-L1 interference`**

The four transfer errors, each with a concrete wrong/right example pair and the drill that fixes it, cross-referencing `templates/pronunciation_drills.md`: articles (no gender in Vietnamese); final consonants and clusters; verb conjugation (Vietnamese verbs do not inflect); tone vs. sentence intonation.

- [ ] **Step 4: `## What we deliberately do not do`**

The grammar ceiling list with the one-line reason: not tested at A1.

- [ ] **Step 5: Verify**

`grep -n '^## ' german-a1/STRATEGY.md` → exactly the four headings. Then VERIFY-LINKS: Duolingo and Babbel appear in prose here but must not be linked.

- [ ] **Step 6: Report** the heading list and word count. No git.

---

## Task 3: runbook.md

**Files:**
- Create: `german-a1/runbook.md`

**Interfaces:**
- Consumes: `STRATEGY.md` anchors from Task 2
- Produces: `§Bad days` and `§Anki recovery`, cited by the `## Minimum viable day` section of all 50 day files

- [ ] **Step 1: Write six sections**

1. `## Daily startup (2 min)` — open today's `content/dayNN.md`, glance at `progress_tracker.md`, set a physical timer, headphones in, phone in another room.
2. `## The session formula` — table `Block | Time | What you do`: Anki 25, Input 40, Output 40, Exam drill 30, total 135 min. Blocks run in order and are never reordered.
3. `## Bad days` — the minimum viable day: 45 minutes, Block 1 plus one output block. Explicitly permitted; skipping entirely is not.
4. `## Anki recovery` — one day missed: backlog plus that day's new cards. Two consecutive days missed: new cards to 0 for three days, clear the backlog first. Never delete the deck; never "forget" the whole deck.
5. `## Weekly review (Sundays, 20 min inside Block 4)` — update `progress_tracker.md`; list the ten words you keep failing; write them out by hand.
6. `## Troubleshooting` — `Symptom | Cause | Fix` table, at least: reviews above 150/day (added new cards too fast → drop new to 10 until the backlog clears); can't hear word boundaries (shadowing silently → shadow aloud); freeze when speaking (rehearsing in your head → record instead); forget articles (learned the noun bare → re-add with article and plural).

- [ ] **Step 2: Verify**

`grep -E '^\| *(Anki|Input|Output|Exam)' german-a1/runbook.md` → four rows reading 25, 40, 40, 30.

- [ ] **Step 3: Report** the heading list. No git.

---

## Task 4: content/GLOSSARY.md

**Files:**
- Create: `german-a1/content/GLOSSARY.md`

**Interfaces:**
- Consumes: nothing
- Produces: the plain-English term reference day files link to on first use of any German grammar term

- [ ] **Step 1: Write four grouped tables, `Term | Plain English | Example`**

Grammar: Artikel, Nomen, Verb, Konjugation, Nominativ, Akkusativ, Dativ, Perfekt, Partizip II, Modalverb, trennbares Verb, Imperativ, Umlaut, Plural, Possessivpronomen, W-Frage, Ja/Nein-Frage.
Exam: Hören, Lesen, Schreiben, Sprechen, Teil, Prüfung, Übungssatz, Wortliste, Buchstabieren, Modellsatz, Prüfungszentrum.
Anki: new card, review, mature card, leech, interval, backlog, ease.
Study method: shadowing, minimal pair, chunk, spaced repetition, production vs. recognition.

Every explanation is one sentence in plain English, never in grammar jargon. Every grammar row carries a German example.

- [ ] **Step 2: Verify**

`grep -c '^|' german-a1/content/GLOSSARY.md` → at least 45 table rows.

- [ ] **Step 3: Report** the term count. No git.

---

## Task 5: Templates

**Files:**
- Create: `german-a1/templates/pronunciation_drills.md`
- Create: `german-a1/templates/sprechen_scripts.md`
- Create: `german-a1/templates/schreiben_templates.md`

**Interfaces:**
- Consumes: `STRATEGY.md §Vietnamese-L1 interference` from Task 2
- Produces: three files day files cite by exact path. `sprechen_scripts.md` must define the fill-in self-introduction Day 1 fills and Day 17 tests from memory; `schreiben_templates.md` must define the short-message skeleton Day 25 onward reuses.

- [ ] **Step 1: `pronunciation_drills.md`**

One section per sound problem: the German sound, why it is hard for a Vietnamese speaker, a word ladder of 8 words, and a 2-minute daily drill.
`ü` (Tür, über, für, müde, Bücher, grün, fünf, München) · `ö` (schön, hören, können, zwölf, Köln, Löffel, öffnen, größer) · `ch` both variants (ich, nicht, Milch vs. auch, Buch, acht) · uvular `r` (rot, Frau, drei, Brot, Uhr, Jahr) · final consonant release (und, Kind, Hand, gut, Bett, weg) · clusters (Straße, sprechen, Stuhl, schwarz, Herbst, sprichst) · intonation vs. Vietnamese tone (statement falls, W-question falls, yes/no rises — three example sentences each).

- [ ] **Step 2: `sprechen_scripts.md`**

`## Teil 1 — Sich vorstellen` — fill-in script with bracketed slots, memorised once:

```
Ich heiße [Vorname] [Nachname].
Ich bin [Alter] Jahre alt.
Ich komme aus [Land].
Ich wohne in [Stadt].
Ich spreche [Sprache] und ein bisschen Deutsch.
Ich bin [Beruf] von Beruf.
Mein Hobby ist [Hobby].
```

Plus the two follow-up tasks: `Buchstabieren` (spell your surname aloud, German letter names given in a table) and `Nummer` (say a phone number digit by digit — write out the German convention and note that `zwei` is often said `zwo` on the phone).

`## Teil 2 — Fragen und Antworten` — the keyword-card format explained, then one question frame and one answer frame per Tier-1 theme, 14 pairs, e.g. `05_food` → `Frage: Was trinken Sie gern?` / `Antwort: Ich trinke gern Kaffee.`

`## Teil 3 — Bitten und darauf reagieren` — the picture-card format, five request frames (`Können Sie bitte …?`, `Öffnen Sie bitte …`, `Geben Sie mir bitte …`) and three response frames (`Ja, gerne.`, `Ja, natürlich.`, `Tut mir leid, ich kann nicht.`).

- [ ] **Step 3: `schreiben_templates.md`**

`## Teil 1 — Formular ausfüllen` — the standard fields with exact German labels (Familienname, Vorname, Straße/Hausnummer, Postleitzahl, Wohnort, Geburtsdatum, Geburtsort, Staatsangehörigkeit, Telefon, Unterschrift), what goes in each, and the three traps: date order is DD.MM.YYYY, Postleitzahl comes before Wohnort, Unterschrift is handwritten not printed.

`## Teil 2 — Kurze Mitteilung` — a ~30-word skeleton (Anrede → three content points → Gruß), written out twice as complete worked examples: informal (`Liebe Anna, … Viele Grüße, [Vorname]`) and formal (`Sehr geehrte Frau Müller, … Mit freundlichen Grüßen, [Vorname] [Nachname]`). State the rule that all three prompt points must be addressed or the module fails.

- [ ] **Step 4: Verify**

`wc -l german-a1/templates/*.md` → three files, each ≥ 40 lines. Then confirm no real personal data: `grep -riE 'hung|le\.hoang|@gmail' german-a1/templates/` → no output.

- [ ] **Step 5: Report** the line counts and the Teil 1 script verbatim. No git.

---

## Task 6: Tier 1 vocabulary, themes 01–07 (325 words)

**Files:**
- Create: `german-a1/vocabulary/tier1_wortliste.csv`

**Interfaces:**
- Consumes: the CSV schema from Global Constraints
- Produces: the file and header Task 7 appends to; the theme slugs Task 8 groups by

- [ ] **Step 1: Header, then ~46 rows per theme**

First line exactly: `german,article,plural,english,vietnamese,example,note`

| Slug | Coverage |
|---|---|
| `01_personal` | name, age, country, nationality, languages, spelling, greetings, farewells |
| `02_family` | family members, marital status, people, friends |
| `03_time` | numbers 0–100, days, months, seasons, clock time, dates, frequency |
| `04_home` | house, rooms, furniture, rent, address |
| `05_food` | food, drink, meals, shopping, quantities, prices, shops |
| `06_health` | body parts, illness, doctor, pharmacy, appointments |
| `07_work` | jobs, workplace, working hours, colleagues |

Copy these row shapes exactly:

```
Name,der,die Namen,name,tên,Mein Name ist Anna.,01_personal
heißen,,,to be called,tên là,Ich heiße Anna.,01_personal
Frau,die,die Frauen,woman / Mrs,phụ nữ / bà,Die Frau kommt aus Vietnam.,02_family
Tisch,der,die Tische,table,cái bàn,Der Tisch ist groß.,04_home
```

Rules: nouns capitalised, with article and plural; verbs, adjectives, adverbs, prepositions and question words lowercase with both columns empty; example sentences use only vocabulary already in the file or in the same theme; Vietnamese glosses carry full diacritics; no commas inside any field.

**If you cannot recall a plural or an article with confidence, omit the word.** A short correct deck beats a long wrong one — the learner cannot detect the error, and a wrong article learned on day 6 is still wrong on exam day.

- [ ] **Step 2: Verify count**

`tail -n +2 german-a1/vocabulary/tier1_wortliste.csv | grep -c .` → `325`

- [ ] **Step 3: Run VERIFY-VOCAB** → no output before `vocab check complete`.

- [ ] **Step 4: Verify theme distribution**

`tail -n +2 german-a1/vocabulary/tier1_wortliste.csv | cut -d, -f7 | sort | uniq -c` → seven slugs, each 40–55.

- [ ] **Step 5: Fix and re-run.** Do not proceed with a dirty VERIFY-VOCAB.

- [ ] **Step 6: Report** count, distribution, verification output. No git.

---

## Task 7: Tier 1 vocabulary, themes 08–14 (to 650 words)

**Files:**
- Modify: `german-a1/vocabulary/tier1_wortliste.csv` (append only — do not rewrite the header)

**Interfaces:**
- Consumes: the file from Task 6
- Produces: the complete 650-row deck Tasks 8 and 15 depend on

- [ ] **Step 1: Append ~46 rows per theme**

| Slug | Coverage |
|---|---|
| `08_travel` | transport, tickets, station, airport, journeys, holidays |
| `09_city` | places in town, directions, buildings, bank, post office |
| `10_routine` | daily-routine verbs, housework, appointments |
| `11_clothes` | clothes, colours, sizes, wearing and buying |
| `12_weather` | weather, seasons, temperature |
| `13_freetime` | hobbies, sport, music, TV, invitations |
| `14_communication` | phone, email, internet, letters, school, course, forms |

Same row rules as Task 6. Check each headword against themes 01–07 before writing it — the duplicate check catches collisions, but fixing them late is expensive.

- [ ] **Step 2: Verify total**

`tail -n +2 german-a1/vocabulary/tier1_wortliste.csv | grep -c .` → 640–660

- [ ] **Step 3: Run VERIFY-VOCAB** → clean.

- [ ] **Step 4: Verify all 14 themes**

`tail -n +2 german-a1/vocabulary/tier1_wortliste.csv | cut -d, -f7 | sort -u | wc -l` → `14`

- [ ] **Step 5: Report** total, theme count, verification output. No git.

---

## Task 8: Themed wordlists (14 markdown files)

**Files:**
- Create: `german-a1/vocabulary/wordlists/01_personal.md` … `14_communication.md`

**Interfaces:**
- Consumes: `vocabulary/tier1_wortliste.csv` from Task 7 — one file per `note` slug, same words, same order
- Produces: the human-readable lists day files name in Block 1

- [ ] **Step 1: Write each file by hand from the CSV rows for that slug**

Each file: H1 with the theme name in English; `**Word count:** N`; a study-method line (*25 words per session. Read the word aloud, say article and plural from memory, then say the example sentence aloud. Cover the German and reproduce it from the Vietnamese.*); `---`; then one entry per word:

```markdown
**der Tisch, die Tische** — table / cái bàn
> Der Tisch ist groß.
```

Non-nouns drop the article and plural: `**gehen** — to go / đi`.

- [ ] **Step 2: Verify**

`ls german-a1/vocabulary/wordlists | wc -l` → `14`
`grep -h '^\*\*' german-a1/vocabulary/wordlists/*.md | grep -v '^\*\*Word count:\*\*' | grep -v '^\*\*Study method:\*\*' | wc -l` → `650`, matching the CSV row count. The two bolded header lines per file must be excluded or the count overshoots by 28.

- [ ] **Step 3: Report** the file list and one sample file's first 12 lines. No git.

---

## Task 9: Tier 2 fluency deck (320 words)

**Files:**
- Create: `german-a1/vocabulary/tier2_fluency.csv`

**Interfaces:**
- Consumes: the CSV schema; must not duplicate any headword in `tier1_wortliste.csv`
- Produces: the Phase-3 deck day files 32–42 draw from

- [ ] **Step 1: Same header, ~50 rows per group**

| Slug | Coverage |
|---|---|
| `t2_connectors` | und, aber, oder, denn, weil, dass, wenn, deshalb, trotzdem, also, zuerst, dann, danach, zum Schluss |
| `t2_modals` | können, müssen, wollen, dürfen, sollen, möchten — as conjugated chunks |
| `t2_verbs` | the next 50 highest-frequency verbs not in Tier 1, Perfekt form in `note` after the slug |
| `t2_adverbs` | immer, oft, manchmal, nie, gestern, heute, morgen, gerade, schon, noch |
| `t2_opinion` | Ich finde…, Ich glaube…, Meiner Meinung nach…, Ich mag…, lieber, am liebsten |
| `t2_smalltalk` | greetings, polite formulas, agreeing, disagreeing, asking for repetition |
| `t2_examphrases` | Können Sie das bitte wiederholen? · Wie schreibt man das? · Entschuldigung, ich verstehe nicht. |

Perfekt goes in `note` after the slug, space-separated:

```
fahren,,,to drive / to go,đi (bằng xe),Ich fahre mit dem Bus.,t2_verbs ist gefahren
```

Multi-word phrase headwords are allowed but must never contain a comma — rewrite the phrase if it needs one.

- [ ] **Step 2: Verify count** → `tail -n +2 … | grep -c .` → 340–370

- [ ] **Step 3: Run VERIFY-VOCAB** across both CSVs → clean, and the duplicate check prints nothing.

- [ ] **Step 4: Report** count and verification output. No git.

---

## Task 10: content/day01–day03 (Phase 0 — Recon)

**Files:**
- Create: `german-a1/content/day01.md`, `day02.md`, `day03.md`

**Interfaces:**
- Consumes: `templates/pronunciation_drills.md`, `templates/sprechen_scripts.md` (Task 5); `vocabulary/tier1_wortliste.csv` (Task 7)
- Produces: the day-file format Tasks 11–14 copy verbatim

**Per-day content:**

| Day | Title | New cards | Block 2 | Block 3 | Block 4 |
|---|---|---|---|---|---|
| 01 | See the exam | 0 | Goethe exam page + download the Übungssatz | Fill in and record the Teil 1 script | `ü` and `ö` ladders + final-consonant drill |
| 02 | Buchstabieren and 0–20 | 0 | Nicos Weg A1.1 Kapitel 1 | Spell your surname aloud, recorded | `ch` (both) and uvular `r` drills |
| 03 | 21–100 and the reversed digits | 25 (words 1–25, `01_personal`) | Nicos Weg A1.1 Kapitel 2 | Say ten phone numbers aloud, recorded | Consonant clusters + read STRATEGY.md end to end |

- [ ] **Step 1: Write `day01.md` using this exact skeleton**

````markdown
# Day 01 — See the exam

**Phase:** 0 — Recon | **Total:** 2h15 | **New cards:** 0

## Why this matters

You cannot reverse-engineer a test you have never seen. Today you look at the real
Start Deutsch 1 papers before learning a single grammar rule, so that every hour after
this one has a target. You will not understand the German — that is expected and is not
the point.

## Core concepts

### Block 1 — Anki (25 min)

Install Anki: https://apps.ankiweb.net/

Create a deck named `A1 Tier 1`. Import `vocabulary/tier1_wortliste.csv`, mapping the
columns in this order: german, article, plural, english, vietnamese, example, note.
Set new cards/day to 25 and maximum reviews/day to 200. Do not study yet — today is setup.

### Block 2 — Input (40 min)

Open the exam page: https://www.goethe.de/en/spr/kup/prf/prf/sd1.html
Write down the four modules and how long each takes.

Then open the practice materials: https://www.goethe.de/en/spr/kup/prf/prf/sd1/ueb.html
Download the Übungssatz PDF and its audio. Skim all four modules. Do not translate.

### Block 3 — Output (40 min)

Play the Sprechen section of the model test and watch one candidate introduce themselves.
Open `templates/sprechen_scripts.md` and fill every bracketed slot with your real details.
Read your completed Teil 1 script aloud five times. Record the fifth attempt.

### Block 4 — Exam drill (30 min)

Open `templates/pronunciation_drills.md`. Do the `ü` ladder, then the `ö` ladder, then the
final-consonant drill: und, Kind, Hand, gut, Bett, weg. Record all six. Play it back.
You are establishing a baseline, not judging quality.

## Exercises

1. Write down, without looking, how many minutes the Hören module lasts and how many parts it has. — **Hint:** it is the shortest module and the audio plays a fixed number of times. — **Solution sketch:** Hören lasts about 20 minutes and has three parts; check your answer against the front page of the Übungssatz you downloaded and correct it there.
2. Say your seven Teil 1 sentences aloud from your filled-in script, then check which one you stumbled on. — **Hint:** the stumble is almost always the `Ich bin … von Beruf.` line, because the job word is new. — **Solution sketch:** e.g. `Ich heiße Anna Nguyen. Ich bin 30 Jahre alt. Ich komme aus Vietnam. Ich wohne in Hanoi. Ich spreche Vietnamesisch und ein bisschen Deutsch. Ich bin Ingenieurin von Beruf. Mein Hobby ist Fußball.` Rewrite the line you stumbled on with a simpler job word and re-record.
3. Listen to your recording of `und, Kind, Hand`. Is the final `d` audible? — **Hint:** in Vietnamese, final stops are unreleased, so a German listener hears `un, Kin, Han`. — **Solution sketch:** exaggerate the release until it sounds wrong to you — `und-uh`, `Kind-uh` — then dial it back halfway. Re-record and compare.

## Anti-patterns / Common mistakes

- Trying to understand the Übungssatz German today. You will not, and attempting it turns a 40-minute orientation into a demoralising two-hour dictionary session.
- Studying Anki cards on day 1 before the deck settings are right. Fix new cards/day to 25 first, or you will build a review backlog you spend week 2 digging out of.

## Minimum viable day

Block 1 + Block 3 only (45 min). See `runbook.md` §Bad days.

## Done when

- [ ] Anki is installed and the Tier 1 deck imported with 25 new cards/day set
- [ ] You can name all four exam modules and their durations
- [ ] Your Teil 1 script is filled in and recorded once
````

- [ ] **Step 2: Write `day02.md` and `day03.md`** from the per-day table above, using the identical heading set. Day 03 is the first day with real Anki study (25 new cards, theme `01_personal`).

- [ ] **Step 3: Run VERIFY-STRUCTURE and VERIFY-EXERCISES** → no MISSING lines for day01–03.

- [ ] **Step 4: Report** both verification outputs. No git.

---

## Task 11: content/day04–day17 (Phase 1 — Engine)

**Files:**
- Create: `german-a1/content/day04.md` … `day17.md` (14 files)

**Interfaces:**
- Consumes: the Task 10 skeleton; `vocabulary/wordlists/01_personal.md`–`07_work.md`; `templates/sprechen_scripts.md`
- Produces: days 04–17, ending in the Day 17 checkpoint `progress_tracker.md` gates on

**Per-day content** — Block 1 is always the named 25-word slice; Block 2 is the named Nicos Weg A1.1 lesson, two passes (gist, then shadowed aloud); Block 4 rotates Hören → Lesen → Schreiben → Sprechen.

**Anki pacing rule (binding, days 03–31).** 25 new cards per day on days 03–28,
contiguous and non-overlapping, starting at word 1 on day 03 and ending at word 650 on
day 28. Days 29, 30 and 31 add **no** new cards — 29 and 30 are consolidation and mock
preparation, and day 31 is a full mock, which must never introduce new material. The
theme column below tells you which theme the day's slice falls in; compute the exact
25-word slice from the rule. Every day file must name both the theme and the slice
(e.g. "theme 02_family, words 76–100").


| Day | Grammar reflex | Theme slice | Block 3 (output) |
|---|---|---|---|
| 04 | `sein` (all persons) | 01_personal | Read the theme list aloud, recorded; self-correct against the drills |
| 05 | `haben` (all persons) | 01_personal | Ten `Ich habe …` sentences aloud |
| 06 | regular present endings | 02_family | Describe your family in six sentences, recorded |
| 07 | W-questions (Wie/Wo/Woher/Was/Wann) | 02_family | Ask and answer five W-questions aloud |
| 08 | yes/no question word order | 03_time | Ten yes/no questions and short answers |
| 09 | `der/die/das` + plural drilling | 03_time | Say article + plural for 30 nouns from memory |
| 10 | Akkusativ as a fixed chunk (`einen/eine/ein`) | 04_home | Describe your room in eight sentences |
| 11 | `nicht` and `kein` | 04_home | Ten negated sentences, recorded |
| 12 | possessives `mein/dein/Ihr` | 05_food | Teil 2 question pair for `05_food` |
| 13 | separable verbs (`aufstehen`, `einkaufen`) | 05_food | Narrate your morning in six sentences |
| 14 | time expressions `um/am/im` | 06_health | Book a doctor's appointment aloud, both roles |
| 15 | `es gibt` | 06_health | Describe what there is in your town, six sentences |
| 16 | imperative (for Sprechen Teil 3) | 07_work | Five Teil 3 requests and responses |
| 17 | consolidation — **Phase 1 checkpoint** | 07_work | Deliver Teil 1 from memory, unhesitating, recorded; log in `progress_tracker.md` |

- [ ] **Step 1: Write the fourteen files.** Identical heading set to Task 10. `## Why this matters` names the module today's work moves. Three exercises per day, each with hint and solution sketch, at least one drilling the day's grammar reflex and at least one drilling article+plural. Two anti-patterns per day, specific to that day's material — never recycled boilerplate.

- [ ] **Step 2: Verify count** → `ls german-a1/content/day*.md | wc -l` → `17`

- [ ] **Step 3: Run VERIFY-STRUCTURE and VERIFY-EXERCISES** → clean.

- [ ] **Step 4: Verify Block 3 tasks are distinct**

```bash
grep -h -A3 '^### Block 3' german-a1/content/day*.md | grep -vE '^(--|### Block 3|$)' | sort | uniq -d | head
```
Expected: no output.

- [ ] **Step 5: Report** count and verification outputs. No git.

---

## Task 12: content/day18–day31 (Phase 2 — Expansion)

**Files:**
- Create: `german-a1/content/day18.md` … `day31.md` (14 files)

**Interfaces:**
- Consumes: the Task 10 skeleton; `vocabulary/wordlists/08_travel.md`–`14_communication.md`; `templates/schreiben_templates.md`
- Produces: days 18–31, ending in the first full mock

**Per-day content** — Block 2 is Nicos Weg A1.2. Block 3 alternates: odd days speaking (the Teil 2 question pair for the day's theme, recorded), even days writing (one Schreiben Teil 2 short message, hand-timed to 10 minutes). Block 4 uses single tasks to day 23, then full official Übungssatz sections from day 24.

| Day | Grammar reflex | Theme slice | Note |
|---|---|---|---|
| 18 | Perfekt with `haben` | 08_travel | |
| 19 | Perfekt with `sein` | 08_travel | |
| 20 | irregular Perfekt, high-frequency | 09_city | |
| 21 | `können` / `müssen` | 09_city | |
| 22 | `wollen` / `möchten` | 10_routine | |
| 23 | `dürfen` / `sollen` | 10_routine | |
| 24 | Dativ as fixed chunks (`mit dem Bus`, `zum Arzt`) | 11_clothes | Block 4 → full Übungssatz sections from here |
| 25 | prepositions of place | 11_clothes | Introduce Schreiben Teil 1 and its three traps |
| 26 | `weil` as a memorised chunk | 12_weather | |
| 27 | `dass` as a memorised chunk | 12_weather | |
| 28 | comparatives `gut/besser`, `gern/lieber` | 13_freetime | |
| 29 | verb-second word order review | review only — no new cards | |
| 30 | consolidation | review only — no new cards | Mock preparation: print the papers, set the timer |
| 31 | **first full mock** | review only — no new cards | All four modules, timed, one sitting; score and log all five numbers |

- [ ] **Step 1: Write the fourteen files.** Same rules as Task 11. Day 31 keeps the four-block headings — Anki runs first, then the mock modules occupy Blocks 2–4 — and its exercises are the post-mock error analysis, each with hint and solution sketch.

- [ ] **Step 2: Verify count** → `31`

- [ ] **Step 3: Run VERIFY-STRUCTURE and VERIFY-EXERCISES** → clean.

- [ ] **Step 4: Verify all 650 words are scheduled**

`grep -hoE 'words [0-9]+–[0-9]+' german-a1/content/day*.md | sed 's/words //' | tr '–' ' ' | awk '{print $2}' | sort -n | tail -1` → `650`. Then confirm days 29–31 name no new cards: `grep -l 'New cards:\*\* 0' german-a1/content/day29.md german-a1/content/day30.md german-a1/content/day31.md | wc -l` → `3`.

- [ ] **Step 5: Report** count and verification outputs. No git.

---

## Task 13: content/day32–day42 (Phase 3 — Output)

**Files:**
- Create: `german-a1/content/day32.md` … `day42.md` (11 files)

**Interfaces:**
- Consumes: the Task 10 skeleton; `vocabulary/tier2_fluency.csv` (Task 9); the day-31 mock results
- Produces: days 32–42, ending in the 60+ gate

**Per-day content** — Block 1 switches to the Tier 2 deck (32 new cards/day; Tier 1 in review only). Block 4 runs full timed modules at exam speed from the second Übungssatz.

| Day | Block 1 (Tier 2 group) | Block 3 (output) | Block 4 (module) |
|---|---|---|---|
| 32 | t2_connectors | 90-second monologue on `08_travel`, recorded | Hören, full, timed |
| 33 | t2_connectors | **italki session #1** — Teil 1 and Teil 2 live | Lesen, full, timed |
| 34 | t2_modals | Transcribe your day-32 recording; mark your own errors | Schreiben, full, timed |
| 35 | t2_modals | 90-second monologue on `13_freetime`, recorded | Sprechen, all three Teile, timed |
| 36 | t2_verbs | **italki session #2** — Teil 3 requests | Hören, full, timed |
| 37 | t2_verbs | Transcribe your day-35 recording; mark your own errors | Lesen, full, timed |
| 38 | t2_adverbs | Schreiben Teil 2 in under 10 minutes, formal register | Schreiben, full, timed |
| 39 | t2_opinion | **italki session #3** — unscripted small talk | Sprechen, all three Teile, timed |
| 40 | t2_smalltalk | 90-second monologue on `07_work`, recorded | Hören + Lesen back to back |
| 41 | t2_examphrases | **italki session #4** — full Sprechen simulation | Schreiben, full, timed |
| 42 | review only, no new cards | Rest the voice | **Full mock** — all four modules, timed. Gate: 60+ |

Each italki day states the written agenda the learner sends the tutor beforehand.

- [ ] **Step 1: Write the eleven files.** Same rules as Task 11. Day 42 must contain the exact phrase `full mock` so the Task 14 verification finds it.

- [ ] **Step 2: Verify count** → `42`

- [ ] **Step 3: Run VERIFY-STRUCTURE and VERIFY-EXERCISES** → clean.

- [ ] **Step 4: Report** count and verification outputs. No git.

---

## Task 14: content/day43–day50 (Phase 4 — Simulation)

**Files:**
- Create: `german-a1/content/day43.md` … `day50.md` (8 files)

**Interfaces:**
- Consumes: the Task 10 skeleton; the day-42 mock results
- Produces: the complete 50-file set, ending in the booking decision

**Per-day content** — mocks alternate with error-patching days. On patching days there are **no new Anki cards and no new material**: Block 1 is review only, Blocks 2–4 work the previous mock's error log.

| Day | Type | Content |
|---|---|---|
| 43 | patching | Work the day-42 error log. Re-drill every missed Hören item at half speed. |
| 44 | **full mock** | All four modules, timed. Score and log. |
| 45 | patching | Work the day-44 error log. Rewrite every failed Schreiben answer. |
| 46 | **full mock** | All four modules, timed. Score and log. |
| 47 | patching | Work the day-46 error log. Re-record every Sprechen answer that stalled. |
| 48 | **full mock** | All four modules, timed. Score and log. |
| 49 | patching | Work the day-48 error log. Exam-day logistics: ID, centre, arrival time, what to bring. |
| 50 | **full mock** | Final mock, timed, then the booking decision. |

Day 50's `## Done when` states the branch explicitly:
- 75+ → book the exam for ~day 56 at your nearest centre: https://www.goethe.de/en/spr/kup/prf/prf/sd1.html
- 60–74 → repeat days 43–50 once, then re-decide
- below 60 → return to day 32

Day 50 also states what comes next: Tier 3, the 1000-word A2 bridge, begins **after** the exam and is not part of this path.

- [ ] **Step 1: Write the eight files.** Same rules as Task 11. Days 44, 46, 48 and 50 must each contain the exact phrase `full mock`.

- [ ] **Step 2: Run VERIFY-DAYS** → `50` and no missing files.

- [ ] **Step 3: Run VERIFY-STRUCTURE and VERIFY-EXERCISES** → clean across all 50.

- [ ] **Step 4: Verify the mock schedule**

`grep -l 'full mock' german-a1/content/day*.md` → day31, day42, day44, day46, day48, day50.

- [ ] **Step 5: Report** all verification outputs. No git.

---

## Task 15: Final audit

**Files:**
- Modify: `german-a1/README.md` (day index and quick-reference tables — fill any gaps)

**Interfaces:**
- Consumes: every file from Tasks 1–14 and the spec
- Produces: the closing audit

- [ ] **Step 1: Run every verification in sequence**

VERIFY-DAYS · VERIFY-STRUCTURE · VERIFY-EXERCISES · VERIFY-VOCAB · VERIFY-LINKS · VERIFY-NO-CODE.
All must be clean. VERIFY-LINKS must return exactly the five approved URLs.

- [ ] **Step 2: Check the spec's six success criteria are each reachable**

For each criterion in the spec, name the day file and section that delivers it. Criterion 5 (all 650 nouns with article and plural) is satisfied by VERIFY-VOCAB returning no bare-noun lines.

- [ ] **Step 3: Confirm no personal data leaked**

`grep -riE 'le\.hoang|@gmail|redkyo' german-a1/ --exclude-dir=docs` → no output. (Without the exclusion the check matches its own text in this plan file.)

- [ ] **Step 4: Complete the README day index** — all 50 rows present, each matching the per-day tables in Tasks 10–14.

- [ ] **Step 5: Report** every verification output and hand the tree to the learner for staging. **No git.**

---

## Notes for the executor

- This is content authoring, not code. The verification commands are run from the shell and are never saved into the repo — VERIFY-NO-CODE will fail if you save them as scripts.
- Tasks 6, 7, 9, 11, 12, 13 and 14 are the expensive ones (bulk German authoring). They are independent of each other once Tasks 1–5 exist, so they parallelise well. Tasks 8 and 15 depend on the vocabulary tasks completing.
- If you cannot recall a German plural, article or Perfekt form with confidence, omit the word rather than guessing.
- Never run `git` in any form.
