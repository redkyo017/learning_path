# "Start here" guides for every day — design

**Date:** 2026-10-05
**Status:** approved in chat, awaiting written-spec review

## Problem

After reading a day's `content/dayNN.md`, the learner does not know how
to begin. Concretely, on Day 1:

1. The lab README says "diagnose inside `app`" but never gives the command
   to get a shell there; bring-up only opens `ws`. It ends with "No further
   hints here on purpose."
2. "Strip the toolbox" is a jargon heading. It is really a practice drill
   (recreate the incident in the bare `slim` container and find it with
   busybox only), and it never says how to enter `slim`.
3. One day mixes four activity kinds — Lab, Strip drill, Exercises,
   Neovim block — each with its own name and rules, with no plain
   explanation of what each is.
4. Exercise solutions sit directly under the questions with no
   instruction to predict first.

## Goal and success criterion

After reading any day, the learner knows — without opening `SOLUTION.md`
— the first command to type, which container/shell it runs in, what to
look at, when to write the journal, what "done" looks like, and what to do
when stuck.

The reference format is the six-item "Day 1 in plain steps" list the
learner approved in chat (reproduced under "Day 1 reference" below).

## Non-goals

- No change to `break.sh`, `verify.sh`, `SOLUTION.md`, `ANSWERS.md`,
  `gauntlet.sh`, the fleet, or the substance of `content/dayNN.md`.
- No renaming of headings (other files cross-reference "Strip the
  toolbox" / "Strip step").
- No full tutorial walkthroughs; hints stop short of the fix.

## Changes

### 1. `labs/dayNN/README.md` — new "Start here — plain steps" section (Days 1–10)

Inserted directly after the existing **At a glance** block, before
`## Goal` / `**Goal:**` / `## Scenario`. Format:

```markdown
## Start here — plain steps

1. **<Short verb phrase>:** <one or two plain sentences, exact command in backticks>.
2. ...
```

Rules:

- 5–8 numbered items. Plain English, short sentences, no jargon without
  a 3–6 word gloss on first use.
- Each item says *where* the command runs: "on your Mac, from
  `linux_ops_mastery/`" vs. "inside `app`" etc. Every container is
  entered with an exact command, e.g.
  `docker compose -p linuxops exec app sh`
  (`ws` uses `bash`; `sysd` per Day 5's bring-up section; Days 8–10 are
  host-only — say so in step 1).
- Order always covers: start the incident → get into the right shell →
  look at the symptom (name the first one or two read-only commands that
  *show the symptom*, not the cause) → write the chain in `journal.md`
  before fixing (point at the template + Day 1 example in that file) →
  fix within the day's constraint (e.g. no restart of `app`) → run
  `verify.sh` and expect its stated success output → the Strip drill
  (how to enter `slim`, or for Days 8–10 what the "Strip step" means)
  → teardown file.
- Day-specific shape is respected: Day 2 three causes / three chains;
  Day 3 two deliverables; Day 4 diagnosis-only (write `/tmp/findings`,
  nothing to fix); Day 5 overlay bring-up and two incidents; Day 6 rungs
  1→5 then `random`; Day 7 `gauntlet.sh`, 15-minute clock, `ANSWERS.md`
  closed until all five chains exist.
- The existing "No further hints here…" sentence (Days 1, 3) is replaced
  by a pointer to the "Stuck?" section below. Other existing text stays.

### 2. `labs/dayNN/README.md` — new "Stuck? Hints" section (all days except Day 7)

Placed at the end of the README. Three collapsed hints, then the
solution pointer:

```markdown
## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next.

<details><summary>Hint 1 — where to look</summary>

Which of the four truths / which area of the system.
</details>

<details><summary>Hint 2 — what proves it</summary>

The file or command whose output proves the cause.
</details>

<details><summary>Hint 3 — almost there</summary>

The cause stated plainly; the fix left for the learner.
</details>

Still stuck: read `SOLUTION.md`.
```

- Hints must agree with that day's `SOLUTION.md`; Hint 3 names the cause
  but not the exact repair command.
- Multi-incident days (2, 5, 6) get one hint ladder per cause/incident/
  rung, each as its own `###` subheading inside "Stuck? Hints". Day 6 may
  instead give one generic ladder that applies to any rung, plus a
  one-line Hint 1 per rung — writer's choice, kept short.
- **Day 7 gets no hints.** Its "Start here" ends with: "No hints today —
  that is the test. `ANSWERS.md` opens after all five chains are written."

### 3. `content/dayNN.md` — three small additions (Days 1–10)

a. **At a glance** list: the Lab item gains "— start with *Start here —
   plain steps* in `labs/dayNN/README.md`".

b. Directly under `## Strip the toolbox` (Days 1–7) or `## Strip step`
   (Days 8–10), one italic line before the existing text:
   - Days 1–7: `*Plain version: a practice drill. Recreate the same kind of
     problem inside the bare `slim` container (enter with
     `docker compose -p linuxops exec slim sh`) and find it again with only
     busybox tools — no friendly tool allowed.*` Adjust wording per day if
     that day's strip section targets a different container.
   - Days 8–10: a one-line plain gloss of what that day's Strip step
     actually asks, derived from its text.

c. Directly under `## Exercises`, one italic line:
   `*How to use these: optional, not tied to the lab. Read a question, write
   down your prediction, then read the hint and solution. Cover the
   solution first — it is printed right under the question.*`

### 4. Top-level `README.md` — "How to approach any day"

New section after "The daily loop". Contents:

- One plain sentence each for the four activity kinds: **Lab** (fix a
  broken system the script breaks for you), **Strip drill** (redo the
  detection with only bare tools), **Exercises** (optional
  predict-then-check questions), **Neovim block** (Days 1 and 7 only,
  editor practice).
- The per-day routine in 5 lines: read the content → open the lab README
  and follow "Start here" → hints only if stuck → `SOLUTION.md` last →
  teardown.
- A "getting a shell" table: `ws`, `app`, `slim`, `db`, `proxy`, `sysd`
  (Day 5), host (Days 8–10), each with its exact command.

## Day 1 reference (approved format)

1. **Start the lab:** from `linux_ops_mastery/`, run `bash labs/day01/break.sh`. It fills up the `/var/log` disk inside `app`.
2. **Get a shell in the broken container:** `docker compose -p linuxops exec app sh`
3. **Look at the symptom:** `df -h /var/log` shows it full. `du -sh /var/log` shows almost nothing there. Your job is to explain that gap.
4. **Write your reasoning in `journal.md`** before fixing anything. Copy the template at the top of the file; the Day 1 example entry shows the expected style.
5. **Fix it without restarting `app`,** then run `bash labs/day01/verify.sh` and wait for `PASS`.
6. **Strip-the-toolbox drill:** run `docker compose -p linuxops exec slim sh`, paste the 5-line snippet from `content/day01.md`, and see the same evidence appear with no `lsof`.

(Final Day 1 text may add a teardown step and tighten wording; meaning
stays the same.)

## Verification

- **Accuracy:** every hint is checked against that day's `SOLUTION.md`
  (Day 7 has no hints, so nothing to check there). A
  reviewer confirms no hint points away from the real cause and no Hint 3
  hands over the fix command.
- **Commands:** every container-entry and symptom command in "Start
  here" is run against the live fleet (Days 1–7; Day 5 with the `sysd`
  overlay) or the host (Days 8–10) after `break.sh`, and must work as
  written. Use `/usr/bin/grep` in any checks (shell `grep` is aliased).
- **Non-regression:** `git diff --stat` touches only the 20 day files above
  (10 lab READMEs, 10 content files) plus the top-level `README.md`; every change is additive except the
  replaced "No further hints" sentences.
- **Rendering:** `<details>` blocks render collapsed in a Markdown
  preview (blank line after `<summary>` line present).

## Build approach

Spec and plan on the main model; per-day writing delegated to Sonnet
subagents (one per day or per small group of days), each given its
day's `content/dayNN.md`, `labs/dayNN/*`, and this spec. Main model
reviews and runs the live checks. No git commits — the learner commits.
