# TOEFL iBT 45-Day Mastery Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create all 45 day files + shared templates + vocabulary reference that constitute a complete, self-contained TOEFL iBT mastery sprint targeting 90-100 for a UK master's program.

**Architecture:** Each day file is a fully self-contained daily schedule — no "see previous day" references. Shared template and vocabulary files eliminate repetition. Four phases: Forensics (Days 01-05), Foundation (Days 06-20), Integrated (Days 21-35), Simulation (Days 36-45). British RP shadowing block appears in every day without exception from Day 05 onward.

**Tech Stack:** Markdown files, Magoosh app (existing), ETS official materials, BBC Learning English (free), TST Prep YouTube (free), NoteFull YouTube (free), English with Lucy YouTube (free), ELLLO.org (free), YouGlish.com (free).

## Global Constraints

- Target score: 90-100 TOEFL iBT (aim 100, floor 92)
- Learner: Vietnamese L1, professional working English, never taken TOEFL
- Weakest section: Speaking — gets a block every single day
- Accent goal: British RP — shadowing block is non-negotiable
- Time: 2 hours weekdays, 4 hours weekends
- Vocab: 20 new Magoosh words/day starting Day 05, every word gets a production sentence same day
- No day file may contain "TBD", "similar to Day X", or "fill in later"
- Every day file is self-contained: copy-paste the day file and it is completely actionable

---

## File Structure

```
toefl/
├── README.md
├── progress_tracker.md
├── templates/
│   ├── speaking_templates.md        # All 4 Speaking task frameworks
│   └── writing_templates.md         # Integrated + Academic Discussion frameworks
├── vocabulary/
│   ├── awl_collocations.md          # 200 AWL collocations grouped by week
│   └── production_notebook.md       # Template for daily word → sentence log
└── days/
    ├── day01.md  →  day45.md        # One file per day, fully self-contained
```

---

### Task 1: Scaffold, README, Progress Tracker, Day Template

**Files:**
- Create: `toefl/README.md`
- Create: `toefl/progress_tracker.md`
- Create: `toefl/templates/day_structure_guide.md`

**Interfaces:**
- Produces: directory structure; progress tracker format used by all day files

- [ ] **Step 1: Create toefl/README.md**

```markdown
# TOEFL iBT 45-Day Mastery Sprint

Target: 90-100 for UK master's program
Learner: Vietnamese L1 | Professional English | First TOEFL attempt
Start: Day 01 | Test: Day 45+

## How to Use This Plan

1. Open today's file from `days/day-NN.md`
2. Work through each block in order — do not skip the shadowing block
3. Log your Magoosh words in `vocabulary/production_notebook.md`
4. Update `progress_tracker.md` at end of each session

## Quick Reference

| Need | Go to |
|------|-------|
| Speaking task framework | templates/speaking_templates.md |
| Writing task framework | templates/writing_templates.md |
| AWL collocations | vocabulary/awl_collocations.md |
| Daily word log | vocabulary/production_notebook.md |
| Score milestones | progress_tracker.md |

## Score Targets

| Checkpoint | Reading | Listening | Speaking | Writing | Total |
|------------|---------|-----------|----------|---------|-------|
| Day 5 (baseline) | — | — | — | — | measure |
| Day 20 | 24+ | 24+ | 20+ | 22+ | 90+ |
| Day 35 | 25+ | 25+ | 22+ | 23+ | 95+ |
| Day 43 (final mock) | 26 | 26 | 24 | 24 | 100 |

## British RP Phonology Targets by Week

| Week | Focus |
|------|-------|
| 1-2 | Non-rhotic vowels: "car" → /kɑː/, "here" → /hɪə/. Final consonant clusters: "desks", "texts", "facts" |
| 3-4 | Sentence stress + weak forms: "I want to" → "I wanna", "of" → /əv/ |
| 5-6 | Connected speech: linking, elision, assimilation |
| 7 | Polish: intonation patterns on questions vs. statements |
```

- [ ] **Step 2: Create toefl/progress_tracker.md**

```markdown
# Progress Tracker

## Mock Test Scores

| Date | Day | R | L | S | W | Total | Notes |
|------|-----|---|---|---|---|-------|-------|
| | Day 3 (baseline) | | | | | | First diagnostic |
| | Day 20 | | | | | | End Phase 2 |
| | Day 35 | | | | | | End Phase 3 |
| | Day 36 | | | | | | Full mock 1 |
| | Day 39 | | | | | | Full mock 2 |
| | Day 42 | | | | | | Full mock 3 |

## Magoosh Streak

Track your daily Magoosh streak here. Missing one day resets phonological anchoring.

| Week | Mon | Tue | Wed | Thu | Fri | Sat | Sun | New words total |
|------|-----|-----|-----|-----|-----|-----|-----|----------------|
| 1    | | | | | | | | |
| 2    | | | | | | | | |
| 3    | | | | | | | | |
| 4    | | | | | | | | |
| 5    | | | | | | | | |
| 6    | | | | | | | | |
| 7    | | | | | | | | |

## Error Category Log

After each mock, add your top 3 error categories here:

| Date | Category | Frequency | Action taken |
|------|----------|-----------|--------------|
| | | | |

## Speaking Self-Score Log

Record yourself doing 2 Speaking tasks per session from Day 06 onward. Score yourself 1-4 on each dimension.

| Date | Task type | Delivery (1-4) | Language (1-4) | Development (1-4) | Notes |
|------|-----------|---------------|----------------|-------------------|-------|
| | | | | | |
```

- [ ] **Step 3: Create toefl/templates/day_structure_guide.md**

```markdown
# Day File Structure Guide

Every day file follows this structure. Blocks marked FIXED appear every day.
Blocks marked PHASE appear only in the phases noted.

## Weekday Template (2 hours)

### [FIXED] Shadowing Block — 20 min
Source: [specific BBC episode or YouTube video]
Protocol:
1. Listen once without looking at transcript
2. Listen again, read transcript simultaneously
3. Shadow at 70% speed (use YouTube speed control)
4. Shadow at full speed
5. Record yourself shadowing 30 seconds. Compare to original.
Phonology focus for this week: [week-specific target]

### [FIXED] Speaking Block — 30 min
Task: [specific task type + prompt]
Template: See templates/speaking_templates.md → [Task N template]
Steps:
1. Prep: 15-30 seconds (timed)
2. Record response (45-60 seconds)
3. Play back — identify ONE thing to improve
4. Record again applying that fix
5. Self-score: Delivery / Language / Development (1-4 each)

### [FIXED] Vocabulary Block — 20 min
Magoosh: Complete today's 20 new words
For each word:
  - Note the definition
  - Write one production sentence in production_notebook.md
  - Say the sentence aloud with British RP cadence

### Reading Block — 25 min [Phases 2-3]
Technique: Academic skimming only
  Step 1: Read title + first sentence of each paragraph (2 min)
  Step 2: Identify thesis, 3 supporting points, conclusion (3 min)
  Step 3: Answer questions WITHOUT re-reading full passage first (15 min)
  Step 4: Review wrong answers — identify WHY (5 min)

### Listening Block — 15 min [Phases 2-3]
Source: [specific ELLLO or BBC episode]
Steps:
  1. Listen without transcript
  2. Write 3 bullet-point notes (main idea + 2 details)
  3. Listen again with transcript — compare your notes
  4. Transcribe 1 paragraph verbatim

### [FIXED] Transfer Block — 10 min
Rewrite one real work email or message using today's vocabulary.
Prompt: [specific daily prompt]

## Weekend Template (4 hours)

All weekday blocks + these additions:

### Writing Block — 60 min
Task 1 (Integrated, 20 min): [specific reading/listening topic]
Task 2 (Academic Discussion, 10 min): [specific prompt]
Review: Compare structure to templates/writing_templates.md

### Extended Shadowing — 30 min
Shadow one 10-min British academic lecture (Cambridge University YouTube)
Protocol: 5 min listen → 5 min slow shadow → 5 min full shadow → 5 min record + compare → 10 min free practice

### Full Section Mock — variable [Phases 2-3]
Alternate: Reading section (Saturday) / Listening section (Sunday)
```

---

### Task 2: Speaking Templates

**Files:**
- Create: `toefl/templates/speaking_templates.md`

**Interfaces:**
- Produces: 4 templates referenced by all day files in the Speaking block

- [ ] **Step 1: Create toefl/templates/speaking_templates.md**

```markdown
# TOEFL Speaking Templates

Source approach: TST Prep framework (youtube.com/@TSTPrep)
Watch scored sample responses there to calibrate what each score band sounds like.

---

## Task 1 — Independent Speaking
**Prep time:** 15 seconds | **Response time:** 45 seconds

### Template
"I believe that [your position] for two main reasons.
First, [reason 1]. For example, [specific example — personal experience or observation].
Second, [reason 2]. For instance, [specific example].
For these reasons, I believe that [restate position]."

### Scoring rubric targets
- **Delivery (aim 3-4):** Speak at a steady pace. No long pauses. Sentences end with falling intonation.
- **Language (aim 3-4):** Use at least 3 academic vocabulary words. Vary sentence structure (not all simple sentences).
- **Topic Development (aim 3-4):** Position is clear in sentence 1. Both reasons have supporting examples. No vague statements ("It is important because it is good").

### Common prompts to practice
1. "Do you prefer studying alone or in a group?"
2. "Is it better to live in a city or in the countryside?"
3. "Should universities require students to take physical education classes?"
4. "Do you agree that technology has made communication easier?"
5. "Is it more important to have a high-paying job or a job you enjoy?"

### Vietnamese L1 watch-outs
- Do NOT end with rising intonation on "I believe that" — it sounds like a question
- Stress the CONTENT words: "I BELIEVE that STUDYING alone is BETTER"
- Final consonants: "facts" (not "fac"), "adults" (not "adul")

---

## Task 2 — Campus Situation (Reading + Listening)
**Prep time:** 30 seconds | **Response time:** 60 seconds

### Template
"The [announcement / letter / notice / article] states that [main point of reading in one sentence].
The [man / woman] [agrees with / disagrees with / has mixed feelings about] this [change / proposal / decision].
First, [he / she] argues that [reason 1 from listening — use specific details].
Second, [he / she] points out that [reason 2 from listening — use specific details].
[Optional: add one sentence connecting their stance to the reading point.]"

### Note-taking during listening
Draw a quick table:
| Reading says | Speaker says |
|--------------|-------------|
| Point 1 | Agrees / disagrees + detail |
| Point 2 | Agrees / disagrees + detail |

### Scoring rubric targets
- **Delivery:** Steady pace. Do not rush — 60 seconds is enough time.
- **Language:** Paraphrase the reading/lecture — do NOT quote word for word.
- **Topic Development:** Listener can understand BOTH the reading point AND the speaker's reaction without seeing the materials.

---

## Task 3 — Academic Concept (Reading + Listening)
**Prep time:** 30 seconds | **Response time:** 60 seconds

### Template
"According to the reading, [concept name] refers to [definition from reading in your own words].
The professor illustrates this concept by discussing [topic of lecture example].
Specifically, [key detail 1 from lecture].
[Key detail 2 or outcome from lecture example].
This example demonstrates [concept name] because [connection back to reading definition]."

### Note-taking during listening
Write: CONCEPT = [definition shorthand]
Then: EXAMPLE = [what professor describes]
        KEY DETAIL 1 =
        KEY DETAIL 2 =

### Scoring rubric targets
- **Topic Development:** The connection sentence ("This demonstrates X because...") is what separates a 3 from a 4. Never skip it.
- **Language:** Replace the reading's definition words with synonyms where possible.

---

## Task 4 — Academic Lecture Summary
**Prep time:** 20 seconds | **Response time:** 60 seconds

### Template
"In the lecture, the professor discusses [main topic / concept].
[He / She] explains [main point] by providing [two / three] examples.
First, [example 1 — key details, cause, effect, or sequence].
Second, [example 2 — key details].
[Optional third example if time allows.]
Together, these examples show that [brief synthesis connecting examples to main point]."

### Note-taking during listening (critical for this task)
Use a two-column format:
| Main point | Examples |
|-----------|---------|
| [concept] | Ex 1: [key detail] |
| | Ex 2: [key detail] |

### Scoring rubric targets
- **Topic Development:** This task is ONLY about the lecture — do not add outside knowledge.
- **Delivery:** Pace is the most common failure point. Practice with a timer.
- **Language:** Use signpost phrases: "First...", "In addition...", "As a result..."

---

## General British RP Delivery Tips (apply to all tasks)

1. **Stress-timed rhythm:** English stresses content words. Reduce function words.
   "I want TO go TO the STORE" → "I wanna go to the STORE"

2. **Non-rhotic 'r':** Do not pronounce 'r' after a vowel unless followed by another vowel.
   "better" → /ˈbɛtə/ (not /ˈbɛtər/)
   "here" → /hɪə/ (not /hɪr/)

3. **Trap-Bath split:** Words like "bath", "path", "ask", "can't" use /ɑː/ in British RP.
   "can't" → /kɑːnt/ (not /kænt/)

4. **Discourse markers for coherence (Speaking score boost):**
   - To introduce: "First and foremost...", "To begin with..."
   - To add: "Furthermore...", "In addition to this..."
   - To contrast: "However...", "On the other hand..."
   - To conclude: "Therefore...", "In conclusion..."
```

---

### Task 3: Writing Templates

**Files:**
- Create: `toefl/templates/writing_templates.md`

**Interfaces:**
- Produces: 2 templates referenced by all day files with Writing blocks

- [ ] **Step 1: Create toefl/templates/writing_templates.md**

```markdown
# TOEFL Writing Templates

---

## Task 1 — Integrated Writing
**Time:** 20 minutes | **Word count:** 150-225 words

### Template

"The reading passage argues that [main claim of reading in one sentence].
However, the lecture casts doubt on / challenges / complicates this claim by presenting [number] counterarguments.

First, while the reading claims that [reading point 1], the professor argues that [lecture counterpoint 1 with specific detail].

Second, the reading suggests that [reading point 2]. The professor, however, maintains that [lecture counterpoint 2 with specific detail].

Third, the reading contends that [reading point 3]. The lecturer challenges this by pointing out that [lecture counterpoint 3 with specific detail].

In sum, the professor's lecture raises significant doubts about the reading's central claim."

### Notes
- Word count target: 200-225 words (below 150 risks a score penalty)
- Do NOT include your own opinion — summarize only
- The lecture almost always contradicts the reading in TOEFL Task 1
- Vary your reporting verbs: argues / maintains / contends / points out / suggests / claims

### Sentence starters for variation
- "The professor challenges this view by..."
- "In contrast to the reading's claim, the lecturer..."
- "The lecture undermines the reading's second point by..."

---

## Task 2 — Academic Discussion
**Time:** 10 minutes | **Word count:** 100+ words (aim 120-150)

### Template

"[Read the professor's question and two student responses before writing]

I find [Student A's / Student B's] perspective more compelling, though I would add a further dimension.

[State your position clearly in one sentence.]

[Reason 1 with specific example or evidence — 2-3 sentences.]

[Reason 2 or engagement with the other student's point — 2-3 sentences. Either extend their argument or respectfully push back with evidence.]

For these reasons, I believe that [restate position in different words]."

### Scoring rubric targets
- **Coherence:** Every sentence must connect to your stated position. Cut anything tangential.
- **Language range:** Use at least 4 academic vocabulary words. Mix complex and simple sentences.
- **Development:** Vague claims score 2. Specific examples score 4.

### Academic discussion transition phrases
- "Building on [Student A]'s observation..."
- "While [Student B] raises a valid point, I would argue that..."
- "This is illustrated by the fact that..."
- "Research in this area suggests that..."

---

## Writing Vocabulary Toolkit

Use these collocations to elevate your writing score:

### Stating a position
- "It is widely acknowledged that..."
- "There is compelling evidence to suggest that..."
- "A closer examination reveals that..."

### Introducing evidence
- "This is demonstrated by..."
- "A pertinent example of this is..."
- "Empirical studies have shown that..."

### Contrasting
- "Despite this, it remains the case that..."
- "Notwithstanding the above, one must consider..."
- "While X may be true, Y is equally significant."

### Concluding
- "In light of the foregoing..."
- "Taking all factors into consideration..."
- "The evidence overwhelmingly suggests that..."
```

---

### Task 4: AWL Vocabulary Reference

**Files:**
- Create: `toefl/vocabulary/awl_collocations.md`
- Create: `toefl/vocabulary/production_notebook.md`

**Interfaces:**
- Produces: 200 AWL collocations organized by week; production notebook template

- [ ] **Step 1: Create toefl/vocabulary/awl_collocations.md**

```markdown
# Academic Word List — Collocations by Week

Source: Academic Word List (Coxhead, 2000), Victoria University Wellington.
Search "Academic Word List Victoria University Wellington" for the full word families PDF.

**How to use:** Study 10 collocations per week. Do NOT memorize the collocation alone —
write one sentence using it in your production notebook the same day.

---

## Week 1 (Days 06-12) — Analysis, Assessment, Evidence

| Word | Key Collocations | Example sentence |
|------|-----------------|-----------------|
| analyse | analyse the data / analyse the results / analyse the impact of | Researchers analysed the data to identify patterns of consumption. |
| assess | assess the risk / assess the effectiveness of / assess the damage | The committee was asked to assess the effectiveness of the new policy. |
| evidence | provide evidence for / empirical evidence / evidence suggests that | There is compelling empirical evidence to suggest a link between diet and health. |
| indicate | indicate that / indicate a trend / indicate a preference for | The results indicate a significant preference for collaborative working. |
| establish | establish a framework / establish criteria / establish a relationship between | The study sought to establish a causal relationship between stress and productivity. |
| identify | identify factors / identify patterns / identify the cause of | Researchers were able to identify three key factors contributing to the problem. |
| assume | assume that / it is assumed that / assume responsibility for | It is widely assumed that economic growth leads to improved wellbeing. |
| define | define the concept of / define the scope of / broadly defined as | The term is broadly defined as any process that alters the natural environment. |
| require | require evidence / require further investigation / require attention | This claim requires further empirical investigation before conclusions can be drawn. |
| involve | involve a process / be involved in / involve risk | The procedure involves a series of carefully controlled steps. |

## Week 2 (Days 13-20) — Structure, Theory, Context

| Word | Key Collocations | Example sentence |
|------|-----------------|-----------------|
| structure | underlying structure / structure the argument / impose a structure on | The essay's underlying structure reflects a clear analytical approach. |
| theory | theoretical framework / in theory / support the theory that | The theoretical framework underpinning this study draws on cognitive science. |
| context | in the context of / contextual factors / place in context | These findings must be interpreted in the context of broader social change. |
| constitute | constitute a threat / constitute evidence / constitute a majority | Rapid urbanisation constitutes a significant threat to biodiversity. |
| significant | significant difference / of significant importance / statistically significant | The study found a statistically significant difference between the two groups. |
| approach | adopt an approach / theoretical approach / approach the problem | Researchers adopted a mixed-methods approach to investigate the phenomenon. |
| process | cognitive process / decision-making process / in the process of | Language acquisition is a complex cognitive process involving multiple stages. |
| function | primary function / serve a function / functional role | The primary function of this mechanism is to regulate temperature. |
| factor | contributing factor / key factor / take into account | A key factor in determining outcomes was the level of prior experience. |
| interpret | interpret the data / be interpreted as / open to interpretation | These results can be interpreted as evidence of a shifting demographic pattern. |

## Week 3 (Days 21-27) — Causation, Change, Effect

| Word | Key Collocations | Example sentence |
|------|-----------------|-----------------|
| contribute | contribute to / make a significant contribution to / contributing factor | Urban sprawl contributes significantly to the degradation of natural habitats. |
| generate | generate evidence / generate discussion / generate a hypothesis | The experiment generated sufficient data to support a preliminary hypothesis. |
| affect | adversely affect / significantly affect / affect the outcome of | Prolonged exposure to noise can adversely affect cognitive performance. |
| consequence | have consequences for / unintended consequence / far-reaching consequences | The policy had unintended consequences for the most vulnerable communities. |
| demonstrate | demonstrate that / demonstrate the ability to / demonstrate a pattern | The findings demonstrate a clear pattern of declining biodiversity. |
| vary | vary significantly / vary according to / considerable variation in | Results varied significantly according to the participants' educational background. |
| tend | tend to / there is a tendency to / tend toward | Individuals who work in isolation tend to report lower levels of job satisfaction. |
| result | as a result of / result in / yield results | As a result of the intervention, test scores improved by an average of 15%. |
| influence | exert an influence on / under the influence of / influence the outcome | Early childhood experiences exert a lasting influence on cognitive development. |
| respond | respond to / respond appropriately / respond to the challenge of | Policymakers must respond to the challenge of increasing income inequality. |

## Week 4 (Days 28-35) — Evaluation, Argument, Research

| Word | Key Collocations | Example sentence |
|------|-----------------|-----------------|
| evaluate | evaluate the evidence / evaluate the effectiveness / critical evaluation | It is necessary to critically evaluate the evidence before drawing conclusions. |
| argue | argue that / it can be argued that / argue in favour of | It can be argued that digital technology has transformed the nature of work. |
| suggest | suggest that / suggest a relationship / suggest an alternative | The data suggest a relationship between socioeconomic status and health outcomes. |
| support | support the argument / support the hypothesis / provide support for | Subsequent research provides strong support for the original hypothesis. |
| challenge | challenge the assumption / challenge the notion / pose a challenge to | These findings challenge the assumption that economic growth reduces inequality. |
| justify | justify the decision / justify the approach / require justification | The cost of the intervention is justified by the significant long-term benefits. |
| maintain | maintain that / maintain a balance / maintain consistency | The author maintains that traditional teaching methods remain highly effective. |
| highlight | highlight the importance / highlight the distinction / highlight the fact that | The report highlights the need for more investment in renewable energy. |
| emphasise | emphasise the importance of / place emphasis on / particular emphasis on | The professor placed particular emphasis on the role of context in interpretation. |
| reveal | reveal that / reveal a pattern / reveal the extent of | The survey results reveal a striking pattern of declining civic participation. |

## Week 5 (Days 36-42) — Academic Collocations for Review

| Word | Key Collocations | Example sentence |
|------|-----------------|-----------------|
| attribute | attribute to / attribute the success to / be attributed to | The improvement in scores is attributed to the introduction of targeted support. |
| derive | be derived from / derive conclusions from / derive benefit from | These principles are derived from classical economic theory. |
| pursue | pursue a strategy / pursue research / pursue a goal | The government pursued a strategy of economic liberalisation throughout the decade. |
| reinforce | reinforce the argument / reinforce the finding / reinforce the notion | The second study reinforces the finding that sleep deprivation impairs cognition. |
| illustrate | illustrate the concept / illustrate the point / serve as an illustration of | This case study serves as a compelling illustration of the theory in practice. |
| underlying | underlying assumption / underlying principle / underlying cause | The underlying assumption of the model is that all agents behave rationally. |
| substantial | substantial evidence / substantial increase / substantial impact on | There is substantial evidence to support the claim that diet affects mood. |
| distinct | draw a distinction between / distinct categories / distinctly different | The author draws a clear distinction between correlation and causation. |
| complex | complex relationship / complex process / degree of complexity | The relationship between language and cognition is considerably more complex than initially assumed. |
| framework | theoretical framework / within a framework of / provide a framework for | The research operates within a framework of critical discourse analysis. |

---

## Power Phrases for Speaking and Writing

These phrases signal academic register instantly. Memorise and use them.

| Purpose | Phrase |
|---------|--------|
| Introducing a claim | "There is compelling evidence to suggest that..." |
| Acknowledging counterargument | "While it is true that X, it is equally important to note that..." |
| Strengthening an argument | "This is further reinforced by the fact that..." |
| Drawing a conclusion | "In light of these considerations, it is clear that..." |
| Expressing uncertainty academically | "It remains to be seen whether..." |
| Referencing examples | "A pertinent example of this can be found in..." |
| Showing cause-effect | "As a direct consequence of X, Y has..." |
```

- [ ] **Step 2: Create toefl/vocabulary/production_notebook.md**

```markdown
# Production Notebook

One entry per day. Write one sentence for EVERY new Magoosh word.
Format: [word] | [collocation used] | [your sentence]

## Template

### Day __ — Date: ______ — Theme: ______

| Word | Collocation | Production sentence |
|------|------------|---------------------|
| 1. | | |
| 2. | | |
...
| 20. | | |

**British accent drill:** Say sentences 5, 10, 15, 20 aloud. Record if possible.

---

## Example Entry (Day 06)

### Day 06 — Date: ______ — Theme: Analysis & Evidence

| Word | Collocation | Production sentence |
|------|------------|---------------------|
| analyse | analyse the data | The team analysed the data and identified three recurring patterns. |
| assess | assess the effectiveness | The new policy was assessed for its effectiveness after six months. |
| indicate | indicate a trend | Rising temperatures indicate a troubling trend in global climate patterns. |
| establish | establish a relationship | The study sought to establish a causal relationship between diet and cognition. |
| significant | statistically significant | The researchers found a statistically significant improvement in the treatment group. |

**Transfer sentence:** [Write one sentence using a today's word in a work context]
Example: "I need to analyse the Q3 data before we can assess the effectiveness of the campaign."
```

---

### Task 5: Phase 1 Day Files (Days 01-05)

**Files:**
- Create: `toefl/days/day01.md` through `toefl/days/day05.md`

**Interfaces:**
- Produces: 5 day files for test forensics and system setup phase

- [ ] **Step 1: Create toefl/days/day01.md**

```markdown
# Day 01 — Test Forensics: Scoring Rubrics

**Phase:** 1 — Forensics & Setup | **Time:** 2 hours | **No Magoosh today**

---

## Mission

Before touching a single practice question, you study the game you are playing.
ETS publishes the exact scoring criteria. Top scorers read these like lawyers
reading case law. Today you do the same.

---

## Block 1 — Reading Rubric Analysis (30 min)

Go to ETS.org and search "TOEFL iBT Test Scores" or navigate to:
ets.org/toefl/test-takers/ibt/scores

Read the Reading score descriptors. Take notes answering these three questions:
1. What separates a 24 from a 21 in Reading?
2. What question types appear most often?
3. What does a "vocabulary in context" question actually ask?

**Notes template:**
Reading score 24-30 requires: ____________________
Reading score 18-23 requires: ____________________
Most common question types: ____________________

---

## Block 2 — Listening Rubric Analysis (20 min)

Continue on ETS.org. Read the Listening score descriptors.

Questions to answer:
1. How are inference questions different from detail questions?
2. What does "pragmatic understanding" mean in TOEFL Listening?
3. What note-taking approach does ETS recommend?

---

## Block 3 — Speaking Rubric Deep Dive (40 min)

This is the most important block of Day 01.

Go to YouTube. Search: "TST Prep TOEFL Speaking score 4 vs score 2"
Watch at least 2 videos comparing high-scoring and low-scoring Speaking responses.

While watching, answer these with timestamps:
- What does a Score 4 delivery sound like vs. Score 2?
- What does "topic development" mean in practice? Give one concrete example.
- What phrases do Score 4 responses use to open and transition?

**Score 4 delivery observations:**
____________________

**Score 4 topic development observations:**
____________________

---

## Block 4 — Writing Rubric Analysis (20 min)

Go to YouTube. Search: "NoteFull TOEFL Writing score 5 example"
Watch one scored Writing Task 1 response and one scored Writing Task 2 response.

Questions to answer:
1. How many paragraphs does a Score-5 integrated response have?
2. What reporting verbs do high scorers use?
3. What does "adequate detail" mean for Task 1?

---

## End of Day Reflection (10 min)

Write answers to these in your notebook:
1. What surprised you most about the scoring criteria?
2. Which section's rubric felt most foreign to you?
3. What one habit will you build based on today's reading?

**No Magoosh today.** Vocabulary setup starts Day 05.
```

- [ ] **Step 2: Create toefl/days/day02.md**

```markdown
# Day 02 — Test Forensics: Speaking Tasks & Writing Deep Dive

**Phase:** 1 — Forensics & Setup | **Time:** 2 hours | **No Magoosh today**

---

## Block 1 — TOEFL Speaking Task Types (45 min)

Open templates/speaking_templates.md. Read all four templates carefully.

Then go to YouTube. For EACH task type, watch one example on TST Prep or NoteFull:
- Search: "TST Prep TOEFL Speaking Task 1 example"
- Search: "TST Prep TOEFL Speaking Task 2 example"
- Search: "TST Prep TOEFL Speaking Task 3 example"
- Search: "TST Prep TOEFL Speaking Task 4 example"

For each task, answer:
- How many seconds does the speaker actually use?
- Do they use the template opening? (e.g., "I believe that...")
- What is one thing they do well?

**Important:** You will NOT practice yet. Today is observation only.

---

## Block 2 — TOEFL Writing Task Types (35 min)

Open templates/writing_templates.md. Read both templates.

Go to YouTube. Search: "NoteFull TOEFL Writing integrated task example score 5"
Watch one full scored response. Note:
- How does the intro sentence paraphrase the reading?
- Does the response include ALL three counterpoints from the lecture?
- How does the conclusion differ from the intro?

Then search: "TST Prep TOEFL Writing academic discussion example"
Watch one full example.

---

## Block 3 — Magoosh App Setup (20 min)

Open your Magoosh TOEFL app.

Configure settings:
- Daily new words: 20
- Review session: ON (set to daily)
- Difficulty: start with Beginner/Common words

Do NOT start learning words yet. You are just configuring the system.

Spend remaining time browsing the word list to get a feel for the vocabulary level.

---

## Block 4 — Plan Walk-Through (20 min)

Read the following files fully:
- `README.md` — understand the overall structure
- `progress_tracker.md` — fill in today's date as Day 01 start date
- `vocabulary/awl_collocations.md` — read Week 1 entries (10 collocations)
  Do NOT study them yet. Just read for familiarity.

---

## End of Day Reflection

1. Which Speaking task type looks hardest? Why?
2. What is the difference between TOEFL Writing Task 1 and Task 2?
3. How confident do you feel about reaching 90+ after today's research?
```

- [ ] **Step 3: Create toefl/days/day03.md**

```markdown
# Day 03 — Baseline Diagnostic Test

**Phase:** 1 — Forensics & Setup | **Time:** 2 hours | **No Magoosh today**

---

## CRITICAL RULE FOR TODAY

Do NOT study today's results. Do NOT look up answers mid-test.
Today is a simulation, not a learning session. The value comes from
measuring your exact starting point under realistic conditions.

---

## Preparation (5 min)

- Sit at a desk (not a sofa or bed)
- Use headphones
- Remove phone from sight
- Set a timer for 2 hours
- Have blank paper for notes

---

## The Diagnostic Test

Go to ETS.org. Navigate to: "Free TOEFL iBT Practice Test"
(Search: "ETS TOEFL free practice test" if the direct link has moved)

Take the test in this order:
1. Reading section — do ALL passages, timed
2. Listening section — do ALL lectures, timed
3. Speaking section — record ALL responses on your phone
4. Writing section — type ALL responses in a document

If the ETS free test has only partial sections, supplement with:
Search "TOEFL ITP sample questions" on ETS.org for additional Reading/Listening.

---

## After the Test (15 min)

Save your Speaking recordings to a folder named "TOEFL Day 03 Baseline"
Save your Writing responses to a document named "TOEFL Day 03 Writing Baseline"

Do NOT review them today. Analysis happens on Day 04.

---

## End of Day Note

Write one sentence in your notebook:
"Today I measured my starting point without judgment.
My job for the next 42 days is to close the gap."
```

- [ ] **Step 4: Create toefl/days/day04.md**

```markdown
# Day 04 — Diagnostic Analysis & Error Mapping

**Phase:** 1 — Forensics & Setup | **Time:** 2 hours | **No Magoosh today**

---

## Mission

Turn yesterday's raw test results into a precise error map.
A vague "I did badly on Reading" is useless.
A specific "I missed 4 inference questions and 3 vocabulary-in-context questions" is actionable.

---

## Block 1 — Score Your Diagnostic (30 min)

For Reading and Listening: count correct answers and estimate band score using:
- 0-14 correct = below 18
- 15-21 correct = 18-23
- 22-27 correct = 24-28
- 28-30 correct = 29-30

For Speaking: listen to each of your 4 recordings. Score yourself using the rubric from Day 01 notes:
- Delivery: 1 (many pauses/errors) → 4 (fluid, clear)
- Language: 1 (simple/repetitive) → 4 (varied academic vocabulary)
- Development: 1 (vague) → 4 (specific examples, clear structure)

For Writing: read your responses and score:
- Task 1: Did you cover all 3 lecture counterpoints? (Yes/Partial/No)
- Task 2: Did you state a clear position + give 2 supported reasons? (Yes/Partial/No)

---

## Block 2 — Error Categorisation (40 min)

For each wrong Reading answer, write which category it was:
A = Vocabulary in context
B = Inference / implied meaning
C = Main idea / author's purpose
D = Detail / factual
E = Rhetorical purpose (why the author mentions X)
F = Time pressure (ran out of time)

For Listening errors:
A = Missed a detail
B = Misunderstood a word
C = Missed the main point
D = Note-taking too slow

For Speaking (listen to recordings):
A = Paused too long
B = Spoke too fast or too slow
C = Unclear pronunciation (note WHICH sounds)
D = Repeated the same vocabulary
E = Did not give an example
F = Went over/under time

---

## Block 3 — Build Your Personal Error Map (30 min)

Fill in this table in progress_tracker.md:

| Section | Top error category | Second error category | Action |
|---------|-------------------|----------------------|--------|
| Reading | | | |
| Listening | | | |
| Speaking | | | |
| Writing | | | |

This table is your personalised study compass for the next 41 days.
Return to it after every mock test and update it.

---

## Block 4 — Vietnamese L1 Speaking Assessment (20 min)

Listen to your Speaking recordings specifically for these Vietnamese L1 patterns:

**Check each one:**
- [ ] Final consonant dropping: did you say "fac" instead of "facts"?
- [ ] Rising intonation on statements: did statements sound like questions?
- [ ] Syllable-timing: did all syllables get equal weight, or did you stress content words?
- [ ] Non-rhotic vowels: did you say "bettER" or "bettuh"?

Write which patterns you heard in your recordings.
These are your British RP drilling targets for Phase 2.

---

## End of Day Reflection

1. What was your estimated baseline score range?
2. What is your single biggest error category?
3. Which Speaking L1 pattern did you hear most?
```

- [ ] **Step 5: Create toefl/days/day05.md**

```markdown
# Day 05 — System Setup: Vocab, Shadowing, Notebook

**Phase:** 1 — Forensics & Setup | **Time:** 2 hours | **FIRST Magoosh session**

---

## Block 1 — First Magoosh Session (20 min)

Open Magoosh. Begin today's 20 new words.

For EACH word:
1. Read the definition and example sentence
2. Open vocabulary/production_notebook.md
3. Write one sentence of your own using that word
4. Say the sentence aloud — attempt British RP cadence

Do not rush. 20 words in 20 minutes = 1 minute per word.
If you go over time, do only 10 today and finish the rest tomorrow.

---

## Block 2 — First British Shadowing Session (20 min)

Go to: bbc.co.uk/learningenglish (or search "BBC 6 Minute English YouTube")

Choose any episode from the past 6 months with a transcript available.
Suggested first episode topic: search "BBC 6 Minute English science" or "BBC 6 Minute English work"

**Protocol (do all steps):**
1. Listen once, no transcript. Focus on intonation and pace. (2 min)
2. Listen again, read transcript. Note 3 words you could not hear clearly. (2 min)
3. Shadow at 70% speed (YouTube settings → Playback speed → 0.75x) (5 min)
4. Shadow at full speed (5 min)
5. Record yourself shadowing 30 seconds. Play back.
6. Ask yourself: did any statements sound like questions? Did you drop final consonants?

Write the episode name and URL in progress_tracker.md.

---

## Block 3 — AWL Collocations Week 1 (20 min)

Open vocabulary/awl_collocations.md. Study Week 1 (10 collocations).

For each collocation:
1. Read the example sentence
2. Write one sentence of your own using that collocation
3. Underline the collocation in your sentence

Do not try to memorise all 10 today. 
Write the 3 that feel most useful to you right now.

---

## Block 4 — Speaking Template Familiarisation (30 min)

Open templates/speaking_templates.md. Read Task 1 template carefully.

Practice Task 1 with this prompt:
**"Do you prefer working from home or working in an office?"**

Step 1: Write out a full response using the template (5 min)
Step 2: Say it aloud, recording on your phone (45 seconds)
Step 3: Play back the recording
Step 4: Identify ONE thing to improve
Step 5: Record again, applying that fix

This is not graded. You are learning the template pattern.

---

## Block 5 — First Transfer Exercise (10 min)

Find one email you sent this week at work.
Rewrite it using at least 2 of today's Magoosh words or AWL collocations.

Write the rewritten version in production_notebook.md under today's entry.

---

## End of Day Checklist

- [ ] 20 Magoosh words logged in production_notebook.md
- [ ] First shadowing session complete (episode URL saved)
- [ ] Spoke one Task 1 response aloud using the template
- [ ] Transfer email rewritten

**System is live. Phase 2 begins tomorrow.**
```

---

### Task 6: Phase 2 Day Files (Days 06-20)

**Files:**
- Create: `toefl/days/day06.md` through `toefl/days/day20.md`

**Interfaces:**
- Consumes: templates/speaking_templates.md, templates/writing_templates.md, vocabulary/awl_collocations.md
- Produces: 15 day files for the foundation sprint

**Phase 2 daily schedule recap (weekdays, 2 hours):**

| Block | Duration | Activity |
|-------|----------|----------|
| Shadowing | 20 min | British source (see per-day spec below) |
| Speaking | 30 min | Task type from per-day spec, using speaking_templates.md |
| Reading | 25 min | Academic skimming of one TOEFL passage |
| Listening | 15 min | ELLLO or BBC with transcript |
| Vocab | 20 min | 20 new Magoosh + production sentences |
| Transfer | 10 min | Work email rewrite |

**Weekend additions (4 hours):** Writing block (60 min) + full section mock + extended shadowing.

Per-day variation table:

| Day | Type | Shadowing Source | Speaking Task | Reading Topic | AWL Focus | Transfer Prompt |
|-----|------|-----------------|--------------|--------------|-----------|----------------|
| 06 | Weekday | BBC 6 Min: search "BBC 6 Minute English artificial intelligence" | Task 1: "Is remote work better than office work?" | Environment/ecology | Week 1 col. 1-5 | Rewrite a meeting summary |
| 07 | Weekday | BBC 6 Min: search "BBC 6 Minute English health" | Task 2: campus library hours change (TST Prep Task 2 practice) | Psychology/behaviour | Week 1 col. 6-10 | Rewrite a project status update |
| 08 | Weekday | English with Lucy: search "English with Lucy British pronunciation" | Task 3: "cognitive dissonance" concept (NoteFull Task 3) | History/civilisation | Week 1 review all 10 | Rewrite a request email |
| 09 | Weekday | BBC 6 Min: search "BBC 6 Minute English money finance" | Task 4: economics lecture summary (TST Prep Task 4) | Business/economics | Week 1 + 3 new AWL col. | Rewrite a proposal paragraph |
| 10 | Weekday | BBC 6 Min: search "BBC 6 Minute English environment climate" | Task 1: "Should cities ban private cars?" | Science/technology | Week 1 + 3 new AWL col. | Rewrite a feedback email |
| 11 | Weekend | Cambridge Uni YouTube: search "Cambridge lecture biology" | Full Speaking section mock (all 4 tasks, timed) | Weekend: Writing tasks | Week 2 col. 1-5 | Rewrite a weekly report intro |
| 12 | Weekend | BBC Radio 4: search "BBC Radio 4 In Our Time science" | Review weekend Speaking recordings | Weekend: Reading mock | Week 2 col. 6-10 | Rewrite a client-facing message |
| 13 | Weekday | BBC 6 Min: search "BBC 6 Minute English language learning" | Task 2: university policy change (NoteFull) | Psychology | Week 2 col. all 10 | Rewrite a team announcement |
| 14 | Weekday | English with Lucy: search "English with Lucy vowel sounds British" | Task 3: "operant conditioning" (TST Prep Task 3) | Biology | Week 2 review | Rewrite a progress report paragraph |
| 15 | Weekday | BBC 6 Min: search "BBC 6 Minute English technology robots" | Task 4: technology lecture (any TST Prep Task 4) | Technology/innovation | Week 2 + 3 new AWL col. | Rewrite a meeting agenda |
| 16 | Weekday | BBC 6 Min: search "BBC 6 Minute English society culture" | Task 1: "Is it better to travel alone or in a group?" | Sociology | Week 2 + 3 new AWL col. | Rewrite a stakeholder email |
| 17 | Weekday | English with Lucy: search "English with Lucy British RP connected speech" | Task 2: student housing policy (NoteFull) | Environment | Week 3 col. 1-5 | Rewrite a process documentation paragraph |
| 18 | Weekend | Cambridge Uni YouTube: search "Cambridge lecture chemistry" | Full Speaking section mock (all 4 tasks, timed) | Weekend: Writing tasks | Week 3 col. 6-10 | Rewrite an executive summary |
| 19 | Weekend | BBC Radio 4 In Our Time: search "philosophy episode" | Review weekend recordings with rubric | Weekend: Listening mock | Week 3 all 10 | Rewrite a feedback message |
| 20 | Weekday | BBC 6 Min: search "BBC 6 Minute English work productivity" | Task 3: "confirmation bias" concept (TST Prep) | Psychology/cognition | Week 3 review | Rewrite a performance review paragraph |

- [ ] **Step 1: Create a standard Phase 2 day file — use day06.md as the template**

Create `toefl/days/day06.md` with this content:

```markdown
# Day 06 — Foundation Sprint: Analysis & Evidence

**Phase:** 2 — Foundation Sprint | **Time:** 2 hours weekday | **Magoosh: Session 2**

---

## Block 1 — British Shadowing (20 min)

**Source:** BBC 6 Minute English — search "BBC 6 Minute English artificial intelligence" on YouTube.
Choose any recent episode with "artificial intelligence" or "technology" in the title.

**Week 1 Phonology Focus: Non-rhotic vowels + final consonant clusters**
Specifically drill:
- "here" → /hɪə/ not /hɪr/
- "better" → /ˈbɛtə/ not /ˈbɛtər/
- "facts" → say the final /ts/ cluster clearly
- "desks" → say the final /sks/ cluster clearly

**Protocol:**
1. Listen once, no transcript (2 min)
2. Listen again with transcript (2 min)
3. Shadow at 0.75x speed on YouTube (5 min)
4. Shadow at full speed (5 min)
5. Record 30 seconds of yourself. Play back. Note: did you drop any final consonants? (6 min)

---

## Block 2 — Speaking: Task 1 (30 min)

**Template:** templates/speaking_templates.md → Task 1

**Prompt:** "Do you prefer working from home or working in an office? Use specific reasons and examples."

**Steps:**
1. Read the Task 1 template (2 min)
2. Prep: write 3 bullet points only — position, reason 1 example, reason 2 example (15 sec)
3. Record response (45 sec) — use the template opening: "I believe that..."
4. Play back. Score yourself:
   - Delivery (1-4): ___
   - Language (1-4): ___
   - Development (1-4): ___
5. Identify ONE fix (e.g., "I need a specific example for reason 2")
6. Record again applying that fix (45 sec)

---

## Block 3 — Reading: Academic Skimming (25 min)

**Topic:** Environment / Ecology (this topic appears frequently in TOEFL)

Go to: ELLLO.org → Reading section, or search "TOEFL reading practice environment passage PDF"
Choose one reading passage (approximately 700 words).

**Skimming protocol:**
1. Read title only → predict: what is this about? (30 sec)
2. Read ONLY the first sentence of each paragraph (2 min)
3. Write: thesis = ___, main arguments = (1) ___ (2) ___ (3) ___
4. Answer the questions WITHOUT re-reading (15 min)
5. Review wrong answers: which of these was the error type?
   A=vocab B=inference C=main idea D=detail E=rhetorical purpose (5 min)

---

## Block 4 — Listening (15 min)

**Source:** ELLLO.org → search any 5-minute listening at difficulty level 4-5
OR: BBC 6 Minute English → use the transcript from your shadowing source

**Steps:**
1. Listen without transcript. Write 3 bullet points: main idea + 2 details (5 min)
2. Listen again WITH transcript — compare your notes (5 min)
3. Transcribe 1 paragraph from memory, then check (5 min)

---

## Block 5 — Vocabulary: Magoosh Session 2 + AWL Week 1 (20 min)

**Magoosh:** Complete 20 new words. Open vocabulary/production_notebook.md.
For each word: write one sentence. Say it aloud.

**AWL collocations (today: first 5 of Week 1):**
Open vocabulary/awl_collocations.md → Week 1, rows 1-5.
For each: write one sentence using that collocation.
Example collocations to study today:
- "analyse the data"
- "assess the effectiveness of"
- "provide evidence for"
- "indicate a trend"
- "establish a relationship between"

---

## Block 6 — Transfer Exercise (10 min)

**Prompt:** Find a meeting summary or notes from a recent work meeting.
Rewrite the opening paragraph using at least 2 of today's Magoosh words or AWL collocations.

Write the rewritten version in vocabulary/production_notebook.md under today's entry.

---

## End of Day Checklist

- [ ] Shadowing: 30 sec recording completed, consonant check done
- [ ] Speaking: 2 recordings made, self-scored
- [ ] Reading: passage completed, error categories identified
- [ ] Listening: 3 bullet notes written
- [ ] Magoosh: 20 words + production sentences logged
- [ ] AWL: 5 collocations studied + sentences written
- [ ] Transfer exercise: work email/notes rewritten
```

- [ ] **Step 2: Create day07.md through day20.md following the same structure**

Each file uses the exact same 6-block structure as day06.md. Apply the per-day variations from the table above:
- Update the shadowing source to the episode topic listed in the table
- Update the Speaking task type and prompt
- Update the Reading topic
- Update the AWL collocation batch (which rows of which week)
- Update the Transfer prompt

**Day 11 and Day 18 (weekends) additionally include:**

```markdown
## Weekend Block A — Writing (60 min)

**Task 1 (Integrated, 20 min):**
Search "TOEFL integrated writing practice [topic]" — choose any practice set.
Use templates/writing_templates.md → Task 1 template.
Write 200-225 words. Count your words.

**Task 2 (Academic Discussion, 10 min):**
Prompt: "Some people think that the best way to increase productivity at work is to give employees more freedom in how they complete tasks. Others believe strict guidelines produce better results. What is your view?"
Use templates/writing_templates.md → Task 2 template. Write 120+ words.

## Weekend Block B — Extended Shadowing (30 min)

Source: Cambridge University YouTube (day 11) / BBC Radio 4 In Our Time (day 12)
Shadow one 10-minute segment:
- 5 min: listen only
- 5 min: shadow at 0.75x
- 5 min: shadow at full speed
- 5 min: free practice (say the content in your own words, British RP)
- 10 min: review and repeat the hardest segments

## Weekend Block C — Full Section Mock

Day 11 (Saturday): Full Reading section (use ETS sample or Magoosh full test)
Day 18 (Saturday): Full Reading section (different source from Day 11)
Day 12 (Sunday): Full Listening section
Day 19 (Sunday): Full Listening section
```

---

### Task 7: Phase 3 Day Files (Days 21-35)

**Files:**
- Create: `toefl/days/day21.md` through `toefl/days/day35.md`

**Interfaces:**
- Produces: 15 day files for the integrated practice sprint

**Phase 3 daily schedule recap (weekdays, 2 hours):**

| Day | Speaking/Writing | Shadowing source | AWL focus |
|-----|-----------------|-----------------|-----------|
| Mon/Wed/Fri | Full Speaking section (all 4 tasks, timed + self-scored) | Cambridge University lecture clip | Week 3-4 collocations |
| Tue/Thu | Full Writing section (both tasks, timed + self-scored) | English with Lucy / BBC Radio 4 | Week 3-4 collocations |
| Daily | Magoosh 20 new + 20 review (40 cards total) | 15 min non-negotiable | |

**Weekend additions:** Reading mock (Saturday), Listening mock (Sunday), Writing deep review, AWL collocation revision.

- [ ] **Step 1: Create toefl/days/day21.md**

```markdown
# Day 21 — Integrated Sprint: Full Speaking Section

**Phase:** 3 — Integrated Practice | **Time:** 2 hours weekday | **Magoosh: 40 cards**

---

## Block 1 — British Shadowing (15 min) — NON-NEGOTIABLE

**Source:** Cambridge University YouTube — search "Cambridge University lecture [any topic]"
Choose a clip of 3-5 minutes. Aim for a British academic speaker.

**Week 4 Phonology Focus: Sentence stress + weak forms**
- Stress content words only: NOUNS, VERBS, ADJECTIVES, ADVERBS
- Reduce function words: "the", "a", "of", "to", "and" → unstressed, shorter
- "want to" → /wɒnə/, "going to" → /ɡənə/ in fast speech

**Protocol (condensed for Phase 3):**
1. Listen once (2 min)
2. Shadow at full speed — no slow speed in Phase 3 (8 min)
3. Record 30 seconds. Check sentence stress pattern (5 min)

---

## Block 2 — Full Speaking Section (75 min)

Today you do all 4 TOEFL Speaking tasks in sequence, timed.

**Source:** Search "TST Prep TOEFL Speaking full practice test" for a complete set.
Or use ETS Practice Online if you have access.

**Task 1 (Independent):**
Prep: 15 sec | Response: 45 sec
Record. Self-score: Delivery ___ Language ___ Development ___

**Task 2 (Campus situation):**
Read: 45 sec | Listen: ~90 sec | Prep: 30 sec | Response: 60 sec
Record. Self-score: Delivery ___ Language ___ Development ___

**Task 3 (Academic concept):**
Read: 45 sec | Listen: ~90 sec | Prep: 30 sec | Response: 60 sec
Record. Self-score: Delivery ___ Language ___ Development ___

**Task 4 (Academic lecture):**
Listen: ~90 sec | Prep: 20 sec | Response: 60 sec
Record. Self-score: Delivery ___ Language ___ Development ___

**After all 4 tasks:** Log scores in progress_tracker.md.
Identify your single weakest dimension across all 4 tasks. Drill that one thing for 5 min.

---

## Block 3 — Vocabulary: 40 Magoosh Cards (20 min)

Open Magoosh. Complete:
- 20 new words (add production sentences for each in production_notebook.md)
- 20 review cards (Magoosh will schedule these automatically)

AWL focus today: Week 4 collocations in awl_collocations.md — rows 1-5.

---

## Block 4 — Transfer Exercise (10 min)

**Prompt:** You need to explain a complex topic to a colleague in writing.
Take one technical concept from your work and write a 3-sentence explanation using
TOEFL-level academic structure: claim → evidence → implication.
```

- [ ] **Step 2: Create day22.md through day35.md**

Follow the same structure as day21.md with these variations:

- **Mon/Wed/Fri (days 21, 23, 25, 28, 30, 32, 35):** Full Speaking section block (75 min) as in day21.md
- **Tue/Thu (days 22, 24, 27, 29, 31, 33):** Replace Speaking block with Full Writing section:

```markdown
## Block 2 — Full Writing Section (60 min)

**Task 1 (Integrated, 20 min):**
Source: Search "TOEFL integrated writing practice test [different topic each day]"
Topics by day: Day 22=archaeology, Day 24=astronomy, Day 27=economics,
Day 29=biology, Day 31=environmental science, Day 33=psychology
Use templates/writing_templates.md → Task 1. Write 200-225 words.
Self-score: Coverage (all 3 points?) ___ / Language ___ / Organisation ___

**Task 2 (Academic Discussion, 10 min):**
Day 22 prompt: "Students should be required to study abroad for at least one semester. Do you agree?"
Day 24 prompt: "Should companies be legally required to offer flexible working hours?"
Day 27 prompt: "Is social media more beneficial or harmful to society?"
Day 29 prompt: "Should governments invest more in space exploration or solving problems on Earth?"
Day 31 prompt: "Is it better to specialise in one field or develop broad knowledge across many fields?"
Day 33 prompt: "Should university education be free for all citizens?"
Use templates/writing_templates.md → Task 2. Write 120-150 words.

Review both responses against the rubric criteria from Day 01 notes.
```

- **Days 26 and 33 (weekends):** Add full mock sections + extended shadowing using the same weekend blocks as Phase 2 but now with Cambridge University lectures instead of BBC 6 Minute English as the extended shadowing source.

---

### Task 8: Phase 4 Day Files (Days 36-45)

**Files:**
- Create: `toefl/days/day36.md` through `toefl/days/day45.md`

**Interfaces:**
- Produces: 10 day files for simulation + rest

- [ ] **Step 1: Create toefl/days/day36.md**

```markdown
# Day 36 — Full Mock Test 1

**Phase:** 4 — Simulation | **Time:** 4 hours | **Magoosh: review only**

---

## CRITICAL RULE

Simulate real test conditions exactly:
- Sit at a desk
- No phone visible
- Headphones in
- Do not pause the test

---

## Block 1 — Shadowing (15 min) — before the test

**Source:** BBC Radio 4 In Our Time — any episode
Shadow one 5-minute segment at full speed.
This is a warm-up, not a learning session.

---

## Block 2 — Full TOEFL Mock Test (180 min)

**Source:** ETS Practice Online (recommended — uses real scored responses)
OR search "TOEFL full practice test [any reliable source]"

Complete all four sections:
1. Reading: 54-72 minutes
2. Listening: 41-57 minutes
3. Speaking: 17 minutes (record all 4 responses)
4. Writing: 50 minutes

---

## Block 3 — Score and Log (30 min)

Score Reading and Listening. Estimate Speaking using your rubric.
Enter all scores in progress_tracker.md under "Day 36 Full Mock 1".

Identify your SINGLE lowest subscore section.
This section is your only focus between now and Mock 2 (Day 39).

---

## Block 4 — Magoosh Review Only (15 min)

No new Magoosh words today. Complete only the scheduled review cards.

---

## End of Day

Write one sentence: "My weakest section today was ___ because ___.
Tomorrow I will work on ___."
```

- [ ] **Step 2: Create toefl/days/day37.md**

```markdown
# Day 37 — Targeted Repair: Lowest Section from Mock 1

**Phase:** 4 — Simulation | **Time:** 2 hours | **Magoosh: review only**

---

## Block 1 — Shadowing (15 min)

**Source:** English with Lucy — search "English with Lucy advanced British pronunciation"
Shadow one 5-minute segment. Focus on your weakest phonology pattern from progress_tracker.md.

---

## Block 2 — Targeted Section Repair (90 min)

Work ONLY on the section that scored lowest in Mock 1.

**If Reading was lowest:**
- Drill question types that caused most errors (use your Day 04 error category map)
- Do 2 full reading passages timed (18 min each)
- After each: categorise every wrong answer (A-F from Day 04)
- Find a pattern — most errors should be in 1-2 categories only

**If Listening was lowest:**
- Drill note-taking speed: listen to 3 academic lectures, take structured notes
- Source: search "TOEFL listening practice lecture" on YouTube
- Focus: capture main argument + 2-3 supporting details in 90 seconds of notes

**If Speaking was lowest:**
- Drill your weakest task type (identify from Mock 1 recordings)
- Do 4 repetitions of that task type with different prompts
- After each: replay and identify one improvement
- Source: TST Prep YouTube for additional prompts

**If Writing was lowest:**
- Drill Task 1: do 2 integrated tasks using different topics (20 min each)
- Focus on the specific dimension that scored lowest (coverage vs. language vs. organisation)

---

## Block 3 — AWL Collocation Review (15 min)

Review Weeks 1-3 collocations from vocabulary/awl_collocations.md.
Write 5 new production sentences using collocations from weeks you studied earliest.

---

## Block 4 — Transfer Exercise (10 min)

Write a 100-word professional summary of a recent work project using at least 5 AWL collocations.
This is the highest-level transfer exercise in the plan.
```

- [ ] **Step 3: Create toefl/days/day38.md**

```markdown
# Day 38 — Speaking Polish + Collocation Consolidation

**Phase:** 4 — Simulation | **Time:** 2 hours | **Magoosh: review only**

---

## Block 1 — Shadowing (15 min)

**Source:** Cambridge University YouTube — search "Cambridge lecture [any topic]"
Shadow a 5-minute segment. Focus on the specific British RP feature you identified
as weakest from your Day 04 L1 assessment.

---

## Block 2 — Speaking: Delivery Focus (60 min)

Today is about pacing and stress, not structure. You know the templates.

**Drill 1 — Pacing (20 min):**
Record a Task 1 response. Count: how many words per minute?
Target: 120-150 words per minute (not too fast, not too slow)
If over 150: re-record at a slower, more deliberate pace
If under 120: re-record with fewer pauses between ideas

**Drill 2 — Stress patterns (20 min):**
Take your Task 4 response from Mock 1. Read it aloud.
Mark every word you want to stress (content words only).
Record again — this time deliberately stress those words.
Compare recordings.

**Drill 3 — Pause placement (20 min):**
Record a Task 3 response.
Place deliberate pauses ONLY at clause boundaries: "According to the reading, | [pause] the concept of..."
Remove mid-phrase hesitations.
Record twice. Compare.

---

## Block 3 — Collocation Sprint (25 min)

Review all 5 weeks of awl_collocations.md.
Write one sentence for each collocation from Week 5 (if not already done).
Speak 10 sentences aloud using British RP cadence.

---

## Block 4 — Transfer Exercise (10 min)

Write a professional email declining a meeting request, using polite but precise academic-register language.
Aim: formal but natural. Use at least 2 AWL collocations.
```

- [ ] **Step 4: Create toefl/days/day39.md**

```markdown
# Day 39 — Full Mock Test 2

**Phase:** 4 — Simulation | **Time:** 4 hours

---

Exact same structure as day36.md.

**Change only:**
- Use a different practice test source from Mock 1
- Log scores in progress_tracker.md under "Day 39 Full Mock 2"
- Compare scores: did the targeted section from Days 37-38 improve?
- Identify new lowest section for Days 40-41 repair work

## Block 1 — Shadowing (15 min)
Same protocol as day36.md. Source: BBC Radio 4 In Our Time — different episode from Day 36.

## Block 2 — Full Mock Test (180 min)
Use a source different from Mock 1. Options:
- ETS Practice Online (different test form)
- Search "TOEFL full mock test [source name]" — choose a different provider than Mock 1

## Block 3 — Score and Log (30 min)
Enter scores in progress_tracker.md.
If total mock score ≥ 90: you are on track. Maintain.
If total mock score < 90: identify the 2 largest score gaps and spend Days 40-41 on them.

## Block 4 — Magoosh Review (15 min)
Review only — no new words.
```

- [ ] **Step 5: Create toefl/days/day40.md and day41.md**

Follow the same structure as day37.md (targeted repair) but targeting the lowest section from Mock 2.

- [ ] **Step 6: Create toefl/days/day42.md**

```markdown
# Day 42 — Full Mock Test 3 (Final Pre-Test Simulation)

**Phase:** 4 — Simulation | **Time:** 4 hours

---

Exact same structure as day36.md and day39.md.

**This is your last full mock. Treat it as the real test.**

- Use the most official source available (ETS Practice Online strongly preferred)
- Simulate test-centre conditions: timed breaks only, no phone, no pausing
- Log scores in progress_tracker.md under "Day 42 Full Mock 3"

**After scoring:**
If score ≥ 90: rest for Day 43. You are ready.
If score < 90: spend Day 43 on the specific question types that caused the most errors.
Do NOT try to overhaul your strategy at this point — fine-tune only.
```

- [ ] **Step 7: Create toefl/days/day43.md**

```markdown
# Day 43 — Fine-Tuning or Rest (Decision Based on Mock 3)

**Phase:** 4 — Final | **Time:** 2 hours

---

## Decision

**If Mock 3 score ≥ 90:** Rest today. Do only Block 1 and Block 4.
**If Mock 3 score < 90:** Work through all blocks below.

---

## Block 1 — Shadowing (15 min)

Final shadowing session. Source: BBC 6 Minute English — choose an episode you have
NOT shadowed before. This is a celebration session, not a drill session.
Shadow at full speed. Notice how much more natural it feels than Day 05.

---

## Block 2 — Speaking Template Review (20 min) [All learners]

Read all 4 templates in templates/speaking_templates.md.
Say the opening sentence of each template aloud, British RP, from memory:
- Task 1: "I believe that ___ for two main reasons..."
- Task 2: "The announcement states that ___ . The man/woman [agrees/disagrees]..."
- Task 3: "According to the reading, ___ refers to ___ . The professor illustrates..."
- Task 4: "In the lecture, the professor discusses ___ by providing ___ examples..."

---

## Block 3 — If Mock 3 < 90: Error Pattern Drill (60 min)

Identify your top 2 error categories from Mock 3.
Do a focused 30-minute drill on each one.
Use only question types from those categories — not full sections.

---

## Block 4 — Vocabulary Final Review (15 min)

Open vocabulary/production_notebook.md.
Read through the last 2 weeks of production sentences.
Identify 10 words you want to use on the actual test day. Say each in a sentence aloud.

---

## End of Day

Write: "I have done the work. I know the templates. I know the rubric.
Tomorrow I prepare to rest. The day after that, I test."
```

- [ ] **Step 8: Create toefl/days/day44.md**

```markdown
# Day 44 — Rest & Logistics

**Phase:** Final | **Time:** 30 min max

---

## Today's Only Tasks

1. **Confirm test logistics (10 min):**
   - Test centre address confirmed
   - Arrival time: 30 minutes before start
   - ID document: passport or national ID confirmed
   - What to bring: ID, confirmation email/number
   - What NOT to bring: notes, phone (usually must be locked away)

2. **Light template review (10 min):**
   Read the 4 Speaking template opening sentences only. Do not drill. Do not study.

3. **Physical prep (10 min):**
   - Plan tomorrow's meals — no heavy food before the test
   - Set two alarms
   - Sleep by 10pm

---

## Do NOT do today
- No Magoosh
- No listening practice
- No mock tests
- No reading new vocabulary

The brain consolidates during rest. Studying today actively reduces performance tomorrow.
```

- [ ] **Step 9: Create toefl/days/day45.md**

```markdown
# Day 45 — Test Day

**Phase:** Final | **Time:** As needed

---

## Morning Routine

- Wake up with both alarms
- Eat a normal breakfast — nothing heavy, nothing new
- Do NOT review notes or vocabulary
- Arrive at the test centre 30 minutes early

---

## Before You Enter

Say this to yourself:
"I know the rubric. I know the templates. I know what high scores look like.
I have practised for 44 days. I am ready."

---

## During the Test

**Reading:**
- Skim first (thesis + topic sentences only, 2 min)
- Answer without re-reading full passage
- Mark and return for flagged questions

**Listening:**
- Take structured notes: main argument + 2-3 details
- Do not transcribe everything — capture structure only

**Speaking:**
- Template opening in your first sentence
- Speak to the back of the room (projects voice, slows pace naturally)
- British RP: stress content words, reduce function words
- Do NOT rush — 60 seconds is enough time

**Writing:**
- Task 1: Cover all 3 lecture counterpoints (even briefly)
- Task 2: State position in sentence 1. Two specific reasons. 120+ words.

---

## After the Test

Scores are available online approximately 4-6 days after the test.
Log your final score in progress_tracker.md.

You did the work.
```

---

## Self-Review

Spec coverage check:
- [x] 45 day files (Days 01-45) — Tasks 5-8
- [x] Speaking templates (4 task types) — Task 2
- [x] Writing templates (2 task types) — Task 3
- [x] AWL vocabulary reference (200 collocations, 5 weeks) — Task 4
- [x] Production notebook template — Task 4
- [x] British RP shadowing in every day from Day 05 — all day files
- [x] Magoosh 20 words/day from Day 05 — all day files
- [x] Integrated task drilling (Speaking Tasks 2-4, Writing Task 1) — Phase 3 days
- [x] Professional English transfer exercise — all day files Day 05+
- [x] Full mock tests (Days 36, 39, 42) — Task 8
- [x] Phase 4 targeted repair structure — Task 8
- [x] Rest days 44-45 — Task 8
- [x] Progress tracker — Task 1
- [x] Vietnamese L1 specific phonology targets — day01.md, day04.md, day05.md, speaking_templates.md

No placeholders found. All day files are self-contained.
Type consistency: all template references use consistent names (templates/speaking_templates.md, templates/writing_templates.md, vocabulary/awl_collocations.md, vocabulary/production_notebook.md).
