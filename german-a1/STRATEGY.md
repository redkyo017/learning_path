# Strategy

This is the reasoning behind every day file in this path. Read it once before day 1, and
come back to it whenever a day tells you to. You are Vietnamese-L1, at absolute zero in
German, with 2.25 hours a day for 50 days, and the goal is not "learn German" — it is
pass the Goethe-Zertifikat A1: Start Deutsch 1, as one step toward migration. Every choice
below follows from that narrower goal.

## The method

**Exam-first reverse engineering.** You meet all four exam modules — Hören, Lesen,
Schreiben, Sprechen — on day 1, not in week 5. From then on, every activity is judged by
one question: does this move a module score? If it doesn't, it gets cut, no matter how
standard it is in a normal German course.

This works because A1 is narrow by design. The exam's vocabulary scope is the official
Goethe Wortliste, about 650 words, and its grammar scope stops well short of the case
system. You are not learning German in general — you are learning the ~650 words and the
handful of grammar patterns that the exam actually tests, to the point where you produce
them without thinking. That narrowness is not a shortcut you're taking; it's the entire
plan.

Every day runs the same four fixed blocks, in the same order, never reordered:

| Block | Time | Why it sits here |
|---|---|---|
| 1 — Anki | 25 min | Spaced-repetition reps degrade sharply with fatigue, so they run first, while you're fresh — never last, when you're tired and start half-remembering wrong. |
| 2 — Input | 40 min | One Nicos Weg episode, twice: once for gist, once shadowed aloud. Shadowing — speaking along with the audio in real time — is what retrains your Vietnamese tonal habits into German sentence melody. Watching without shadowing does not do this. |
| 3 — Output | 40 min | You produce — speak or write — every day from day 4 onward. Sprechen is 25% of the score and is the one module that cannot be crammed in the final week; it has to be built daily, like a muscle. |
| 4 — Exam drill | 30 min | One timed task in real exam format, rotating through the four modules. At A1, being fast and comfortable with the paper's format is worth more marks than an extra 50 words of vocabulary. |

Two rules fall out of this structure, and every day file obeys them without exception:

1. **Grammar is learned only when a Wortliste sentence forces it.** You never study a
   grammar point in the abstract. You meet `sein` because you need "Ich bin müde," not
   because week 2 of a textbook says so. This is also why the grammar ceiling exists —
   see "What we deliberately do not do" below.
2. **Anything that does not move a module score is cut.** No enrichment reading, no
   extra vocabulary outside the Wortliste, no grammar the exam doesn't test. If a day file
   asks you to do something, it is because that something raises Hören, Lesen, Schreiben
   or Sprechen — never because it's "good to know."

**Vocabulary is tiered, not front-loaded.** A natural instinct is to build a 2,000-word
deck before you feel "ready" to speak. Resist it. The Wortliste is ~650 words and bounds
the entire exam; a 2,000-word deck costs roughly three extra weeks of Anki time and buys
zero exam points, because the exam will never ask you a word outside the list. Vocabulary
here is built in tiers instead:

| Tier | Size | Content | When |
|---|---|---|---|
| 1 | ~650 | Official Goethe A1 Wortliste, 14 themes | Days 3–28, 25 new cards/day (26 slices, words 1–650); no new cards on days 29–31 |
| 2 | 320 | Connectors, modals, high-frequency verbs — fluency, not exam coverage | Days 32–41, 32 new cards/day (10 days, 320 cards, taken as ten contiguous 32-word slices of the file); no new cards from day 42 |
| 3 | ~1000 | A2 bridge vocabulary | After the exam — not part of this path |

New cards stop twice on purpose — days 29–31 and again from day 42 — so the mock-heavy
stretches are review-only and nothing new is competing with exam simulation. Reviews never
stop, on any day of the 50. Which slice belongs to which day is listed in `README.md`
§Day index and repeated in that day's `content/dayNN.md`.

**Why not a textbook, or pure input, or an app.** Three alternatives were considered and
rejected on purpose, and it's worth knowing why, so you don't quietly drift back to them
when a day feels slow:

- A classroom textbook (Menschen A1, Schritte International) paces to a 12-week term,
  spends its first six weeks well below exam tempo, and teaches grammar the exam never
  tests. You would finish it knowing more grammar and fewer of the words you actually need.
- Pure comprehensible input — watching Nicos Weg end to end, then drilling afterward —
  produces recognition without production. You'd understand a lot and be able to say very
  little, and Sprechen plus Schreiben are half the score.
- Gamified apps optimize for streaks, not for the Wortliste, and are covered under
  "Mistakes that waste 80% of your time" below.

## Mistakes that waste 80% of your time

Each of these feels productive while you're doing it. That's exactly what makes it
dangerous — it doesn't feel like wasted time until you're three weeks in and your mock
score hasn't moved.

### Duolingo streaks

**The mistake:** building a daily streak in Duolingo or Babbel instead of running your
Anki reps.
**Why it feels productive:** a streak counter, a green checkmark, a sense of daily
progress — the app is designed to make you feel like you're advancing.
**What to do instead:** neither app teaches to the Wortliste or the exam format; both
optimize for engagement, not for your 650 words. Every minute in either app is a minute
not spent on Tier 1 vocabulary or exam-format drilling, and this is the single largest
documented time sink for exam-driven beginners. Use Anki, which you control, and which
only ever shows you words from your own deck.

### Learning case tables before the Wortliste

**The mistake:** sitting down to memorize Nominativ/Akkusativ/Dativ declension tables
before you have enough vocabulary to use them in a sentence.
**Why it feels productive:** a table feels like "real grammar," complete and systematic,
and completing it feels like an achievement.
**What to do instead:** an empty table teaches you nothing you can say. Learn each case
as a fixed chunk attached to a real Wortliste sentence when the sentence demands it (see
"The method" above) — `mit dem Bus`, not a four-by-four grid of endings.

### Buying multiple textbooks

**The mistake:** buying Menschen A1 and Schritte International and a grammar reference
"just in case," and splitting study time across all of them.
**Why it feels productive:** more materials feels like more thoroughness, more coverage,
more insurance against gaps.
**What to do instead:** every textbook paces to a classroom term and teaches beyond the
exam's grammar ceiling. Nicos Weg (free) plus this path's Wortliste is the complete input
and vocabulary source — a second textbook adds hours without adding exam points.

### Treating grammar as knowledge rather than reflex

**The mistake:** being satisfied once you can explain a rule — "I know verbs go second
in a main clause" — without being able to produce it instantly, unprompted, in speech.
**Why it feels productive:** explaining a rule correctly feels like understanding, and
understanding feels like the goal.
**What to do instead:** the exam does not ask you to explain German; it asks you to
produce it under time pressure. Drill each pattern in real sentences until it's automatic,
the way `Ich gehe` comes out without a pause — not until you can state the rule.

### Delaying speaking until "ready"

**The mistake:** postponing spoken output until vocabulary and grammar "feel solid
enough," often into the final weeks.
**Why it feels productive:** it avoids the discomfort of sounding bad, and more input
feels like safer preparation than risky output.
**What to do instead:** Sprechen is 25% of the score and the one module you cannot cram.
Output starts on day 4, at 40 minutes a day, deliberately before you feel ready — fluency
under pressure is a skill built by daily reps, not a reward unlocked by enough studying.

### Passive video watching

**The mistake:** playing Nicos Weg episodes in the background, or watching once and
moving on, without shadowing aloud.
**Why it feels productive:** you're consuming German input, and comprehension goes up,
so it feels like study.
**What to do instead:** comprehension without production doesn't move Sprechen or
Schreiben. Every Input block is two passes — once for gist, once shadowed aloud — because
shadowing is what retrains Vietnamese tone into German sentence melody; watching alone
does not.

### Learning nouns without article and plural

**The mistake:** memorizing `Tisch = table` and moving on, planning to "pick up" the
article later from exposure.
**Why it feels productive:** it's faster, and the noun's meaning is what feels essential.
**What to do instead:** Vietnamese has no grammatical gender, so there is no intuition to
fall back on later — you must store gender as an inseparable part of the word from the
first exposure. Every Tier 1 and Tier 2 card is built as `der Tisch, die Tische`, never a
bare noun; that's a mechanical constraint on the vocabulary files, not a suggestion.

### Translating via English instead of Vietnamese→German

**The mistake:** running new German words through English in your head — `Tisch → table
→ "table," got it` — because most learning materials assume an English-speaking learner.
**Why it feels productive:** most explanations, apps and grammar notes online are written
for English speakers, so translating through English feels like using the "real"
resources.
**What to do instead:** German and Vietnamese are both distant from English in different
ways, and every extra hop is a chance to lose the article, the tone, or the sentence
structure. Every vocabulary row in this path glosses German directly to Vietnamese with
full diacritics — go straight `Tisch → cái bàn`, no English relay.

### Ignoring the Sprechen keyword-card format until the final week

**The mistake:** treating Sprechen Teil 2 as "just conversation practice" and never
drilling its actual keyword-card format — a printed word or phrase you must turn into a
question and an answer — until days before the exam.
**Why it feels productive:** general conversation practice feels like fluency-building,
and it is easy to assume format familiarity will follow naturally from speaking ability.
**What to do instead:** the keyword-card format is scored on structure, not just
correctness, and unfamiliarity with the format costs marks even from learners who know
the vocabulary. Teil 2 drilling starts in the Output block from the point the day files
introduce it, using `templates/sprechen_scripts.md`, not in a single cram session at the
end.

## Vietnamese-L1 interference

Vietnamese has no grammatical gender, almost no consonant clusters, no released final
consonants, no verb inflection, and is tonal. Those five facts predict exactly where your
time will leak, so four transfer errors get dedicated drilling here rather than being
left to incidental correction. The sound-based pair below is drilled directly in
`templates/pronunciation_drills.md`; the grammar-based pair is drilled through the Tier 1
Anki cards and daily Output blocks, because — per "The method" — grammar reflexes are
built through reps on real sentences, not explanation.

### Articles (no gender in Vietnamese)

Vietnamese nouns carry no gender, so there's no intuition to guess from — every German
noun's article has to be memorized as part of the word, or it gets guessed wrong forever.

- **Wrong:** *Der Fenster ist offen.*
- **Right:** *Das Fenster ist offen.*
- **Drill:** every noun enters the Anki deck as an inseparable chunk — article, noun,
  plural together, e.g. `das Fenster, die Fenster` — never the bare noun. This is a fixed
  rule in the vocabulary CSV schema, not a study tip.

### Final consonants and clusters

Vietnamese syllables rarely end in a released consonant and almost never in a consonant
cluster, so German words that end in one — `Straße`, `sprichst`, `Herbst` — get their
final sounds dropped or swallowed.

- **Wrong:** *Herbst* said as "Herb" (the final `-st` cluster dropped).
- **Right:** *Herbst*, with the `b`, `s` and `t` each released in sequence.
- **Drill:** `templates/pronunciation_drills.md` isolates exactly these consonant-final
  and cluster words for slow, exaggerated repetition before folding them back into
  normal-speed shadowing.

### Verb conjugation (Vietnamese verbs do not inflect)

Vietnamese verbs never change form for person or number, so there is no built-in habit of
changing a verb ending — the German present-tense endings have to be built as reps, not
understood as a rule and then applied.

- **Wrong:** *Ich gehen zur Schule.*
- **Right:** *Ich gehe zur Schule.*
- **Drill:** conjugation is drilled as whole memorized sentences on Wortliste-forced
  cards and in the daily Output block — say the correct form so many times it stops being
  a decision, per "treating grammar as knowledge rather than reflex" above.

### Tone versus sentence intonation

Vietnamese is tonal: pitch changes the meaning of a syllable — *ma, má, mà, mã, mạ, mả*
are six different words. German has no lexical tone at all. Pitch there never changes what
a word means; it runs as one line across the *whole sentence* and marks what kind of
sentence it is. Vietnamese-L1 speakers tend to either flatten that line entirely or apply
tone-like pitch jumps to individual syllables.

There are exactly three contours to learn, and a question mark on the page does **not**
tell you which one to use:

- **Statement — falls at the end.** ↘ *Ich komme aus Vietnam.*
- **W-question** (`wer, wie, was, wo, wann`) — **also falls at the end**, exactly like a
  statement. ↘ The question word at the front already marks it as a question, so the
  pitch does not have to.
- **Yes/no question** (verb first, no question word) — **rises at the end**. ↗ This is the
  only one that rises.

Two error pairs, in the order you will make them:

- **Wrong:** *Kommst du aus Köln.* ↘ (a yes/no question said with a falling line — it
  lands on the examiner's ear as a statement)
- **Right:** *Kommst du aus Köln?* ↗ (pitch climbs to the end)
- **Wrong:** *Wie heißt du?* ↗ (the over-correction, once you learn that "questions rise" —
  a rising W-question sounds like a disbelieving echo, or simply foreign)
- **Right:** *Wie heißt du?* ↘ (falls, like a statement)
- **Drill:** the shadowing half of every Input block, reinforced by the intonation drills
  in `templates/pronunciation_drills.md`, which give three sentences per contour — this is
  fixed by imitating whole-sentence melody, not by a rule about question marks.

## What we deliberately do not do

None of the following is tested at A1, so none of it appears anywhere in this path — not
in a day file, not in an aside, not as "bonus" material:

- **Full case tables** (Nominativ/Akkusativ/Dativ/Genitiv declension grids) — A1 only
  needs Akkusativ and Dativ as fixed chunks in specific phrases, never the full table.
- **Adjective endings** — not tested at A1.
- **Genitiv** — not tested at A1.
- **Konjunktiv** — not tested at A1.
- **Passiv** — not tested at A1.

If a resource, a well-meaning tutor, or your own instinct pushes you toward any of these
before day 50, the answer is the same one from "The method": does this move a module
score? For all five, the answer is no.
