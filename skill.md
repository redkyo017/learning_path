---
name: building-learning-path
description: Use when asked to build a structured learning path, mastery plan, or "master X as fast as humanly possible" request — covers spec, plan, and content-authoring phases with model gates and path-type classification. Also use to triage, check, update or refresh an existing path (Refresh mode).
---

# Building a Learning Path

## Overview

Three-phase workflow: **Spec → Plan → Content**, preceded by **Phase 0 — Scratch branch**. Each of the
three phases has a model gate — you must ask the user which model to use before proceeding to each one.
The learner handles all official VCS: nothing is ever pushed, and the scratch branch is deleted before handoff.

**Announce at start:** "I'm using the building-learning-path skill."

**Sub-skill — condensing one book.** When the request is to condense a specific book or PDF into one companion
file for memory (not a multi-day path), use `skill_book_condense.md` instead; its prompts are in
`prompt_book_condense.md`.

---

## Step 0 — Clarify before speccing

Requests arrive in two styles (both in `basic_prompt.md`): the short **v1** prompt ("master [skill]… N-day
plan… ask me questions") and the slotted **v2** template (outcome, profile, time, environment, source of
truth, plus "rules for you"). Treat them the same way: **the v2 rules are this skill's defaults**, applied
to v1 requests too (see §Standing Constraints → Accuracy, Evidence, Honest scope).

**Read `LEARNER_PROFILE.md` (repo root) first** — it is the learner's standing background (role, strong
skills, gaps, work context, practice environment, preferences). Use it to pre-fill the learner-profile and
lab-environment slots; ask only about what is missing, marked `(?)`, or plausibly stale for this subject.
If the answers reveal a new lasting fact, offer to append it to the profile (dated) — don't edit it silently.

Then extract every slot the request already answers, and ask **one round, at most 7 questions, only for
slots still missing or ambiguous** — each with a suggested default the learner can accept by replying
"defaults". A fully filled v2 prompt may need only 1–2 questions. Then proceed.

1. **Subject & concrete outcome:** What do they want to master? What must they be able to *do* at the end (at work, in an exam)?
2. **Learner profile:** Prior knowledge of *this* subject — the general background comes from `LEARNER_PROFILE.md`.
3. **Time budget:** Hours/day and total days (firm or flexible)? A day count in the request is a guess unless they say it is firm.
4. **Lab environment:** Cloud account, local Docker, pure text, etc.?
5. **Source of truth:** Syllabus, exam spec, or exact product versions to target (e.g. "WSO2 IS 7.3").
6. **Path type trigger** (auto-detect from subject, confirm if ambiguous): see §Path Type Classification below.

**Reality check before speccing.** If the time budget can't reach the outcome, say so and propose an honest
duration or a narrower scope — don't silently agree to an impossible plan. If the subject depends on tools,
versions, exams or APIs that change, check current official sources now (web search) so the spec is built on
today's facts, not training-cutoff memory.

---

## Model Gates — REQUIRED before each phase

**Before Phase 1 (Spec):**
> "I'm ready to write the spec. This is a planning/reasoning document — I can write it on the current model or switch to a reasoning model. Which would you prefer?"

**Before Phase 2 (Plan):**
> "Ready to write the implementation plan. Same question — current model or reasoning/planning model?"

**Before Phase 3 (Content files, code, primers):**
> "Ready to start writing content files. Content writing is cheaper on Sonnet. Switch models, or keep the current one?"

Never skip the gate, even if the previous phase just ran.

---

## Path Type Classification

Classify the path before writing the spec. It determines the code scaffold decision.

| Category | Examples | Code simulation? |
|---|---|---|
| **Pure science** | Math, linear algebra, physics, chemistry, biology, statistics | No — text content only. Add sims only if the learner explicitly asks. |
| **Applied / engineering** | AWS, networking, security, Golang, algorithms, distributed systems, CS | Yes — initialize a code scaffold alongside content. |
| **Hybrid** | Quantum computing, signal processing, ML theory | Ask the learner: "This path has theoretical and computational sides — do you want runnable simulations?" |

For **pure science** paths: omit `code/` directory and any sim scaffold. Content is text + practice problems with hints and solution sketches.

For **applied/engineering** paths: initialize `labs/` (Terraform for cloud paths) or `code/` (language examples for CS/Go paths) as part of the spec directory layout. All lab files are *authored* here; the learner runs them — never run `terraform apply` or start real infrastructure during authoring.

---

## Phase 0 — Scratch branch (applies to all paths)

Authoring a path creates thousands of lines of new files. Without a git baseline, every review and every
fix-round re-review has to be handed the **full contents** of every file it reviews, repeatedly. On a
15-task path that dominates the entire token cost — measured at 27,000+ lines of review packages on one
run, where diffs would have been a fraction.

Before Phase 1, create the authoring branch:

    git checkout -b authoring/<subject>

Then commit after each completed task, so `superpowers:subagent-driven-development`'s
`scripts/review-package PLAN_FILE BASE HEAD` can produce a diff. Record BASE (`git rev-parse HEAD`)
before dispatching each implementer.

**Never push. Not once, not to any remote.**

### Two rules learned the hard way

**Only checkpoint when no implementer is running.** A commit taken while a subagent is mid-edit captures
its work-in-progress, and the next round's diff comes back empty because the changes are already
committed. Wait for the completion notification, then commit.

**Diffs only help where files already exist in the baseline.** Every file in a new path is new, so a diff
of the whole tree against `master` equals its full contents — the *final whole-branch review* gets no
benefit and should be pointed at a file manifest instead, letting it read selectively. The saving is in
the per-task fix rounds, which is where most of the review volume actually is.

### Teardown before handoff — exact sequence

A plain `git switch master` while the commits live only on the scratch branch **removes every authored
file from the working tree**. Use this order:

    git reset --soft master        # branch pointer back to master, all changes staged
    git switch master              # safe now: both refs identical, index and worktree preserved
    git reset                      # unstage, so the path directory is untracked again
    git branch -D authoring/<subject>
    git status                     # verify: path untracked, the learner's own edits still theirs

Result: `master` untouched, every authored file present as an untracked change for the learner to commit
and push themselves. Stage only the path's own directory — never sweep up the learner's unrelated edits.

### When git is not reachable from here

Sometimes git lives only inside a container while this session runs outside it, or the sandbox blocks it.
Do not silently fall back to full-content review packages — **ask the learner and hand them the exact
commands to run**, at both ends. Give them something they can paste, not a description of what you want.

At the start:

> "I can't run git from here. Please run this and tell me when it's done:
> `git checkout -b authoring/<subject>`"

At each checkpoint:

> "Task N is complete and no agent is running. Please run:
> `git add <subject>/ && git commit -m 'WIP: task N (scratch)'`
> then paste me the output of `git rev-parse --short HEAD` so I can use it as the next diff baseline."

At teardown, give all five lines at once and ask them to paste back the final `git status`:

> "All tasks are done. Please run these in this exact order — the order matters, because a plain
> `git switch master` first would delete every authored file from your working tree:
> ```
> git reset --soft master
> git switch master
> git reset
> git branch -D authoring/<subject>
> git status
> ```
> Then paste me the `git status` output so I can confirm the path is untracked and nothing was pushed."

**Batch the checkpoints when the learner is the one running them.** Committing after every task means
interrupting them fifteen times, which nobody sustains — the scheme gets abandoned halfway and you end up
with neither diffs nor a clean history. Ask for a checkpoint every three or four tasks instead, or at
natural boundaries such as the end of a batch of parallel day-tasks. Fewer, larger diffs still beat full
file contents by a wide margin.

If they decline entirely, say plainly that reviews will fall back to full file contents and cost
substantially more, then proceed that way without raising it again.

---

## Phase 1 — Spec (docs/superpowers/specs/)

**File:** `<subject>/docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`

Required sections:

```markdown
# <Subject> — Design Spec

**Date:** YYYY-MM-DD
**Location:** `<subject>/`
**Duration:** N days, ~X h/day (~Yh total)

## Purpose & Goals
<1-3 paragraphs: what mastery looks like, learner profile, why unconventional strategy>

## Success Criteria
<Numbered list: what the learner can do without notes by the end — traceable to the concrete outcome>

## Constraints & Environment
<Lab setup, cost limits, toolchain, standing rules (no credentials, no commits, etc.)>

## Target Versions & Sources (as of YYYY-MM-DD)
<Exact versions / exam spec / syllabus targeted, with links to the official sources checked.
Pure-science paths: the reference texts instead.>

## Strategy (the core design decision)
<The unconventional fast-track approach + why alternatives were rejected. Must name:
- the load-bearing fundamentals that are NOT skipped, and why
- the ~20% of concepts/skills that carry most real-world use, in dependency order
- where the learner should use AI as tutor/checker vs. work without it
Claims are backed by evidence (learning research, official docs, practitioners) or labelled as judgment.>

## Curriculum
<Phase-by-phase outline with day-level granularity and h/day estimates, plus
no-notes checkpoints (e.g. end of each week) and a final capstone that matches the concrete outcome>

## Directory Layout
<Full target tree, annotated>

## Content Day Skeleton
<Markdown template for a single day file>
```

---

## Phase 2 — Plan (docs/superpowers/plans/)

**File:** `<subject>/docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md`

**REQUIRED SUB-SKILL:** Use `superpowers:writing-plans` for task decomposition.

Plan header must include:
- Pointer to the spec file
- Global constraints block (no credentials, no git commands **in subagents**, no running real infra)
- Project layout diagram (target end-state)
- Per-day task list using `- [ ]` checkboxes

Each day task specifies exactly which files to create and what each file contains. No vague "write Day N" entries.

---

## Phase 3 — Content Authoring

**REQUIRED SUB-SKILL:** Use `superpowers:subagent-driven-development` to dispatch one subagent per task.

### Dispatch rules

- **No git commands** in any subagent dispatch (no `git status`, `git log`, `git diff`).
- Each subagent writes exactly the files assigned to its task — nothing more.
- Subagents must not run real infrastructure (`terraform apply`, cloud CLI commands, language compilers against real services).
- Parallel dispatch is preferred for independent day files.

### Content day file structure (all paths)

```markdown
# Day N — <Title>

## Why this matters
<1 short paragraph, concrete and specific>

## Core concepts
<Body of the day's content>

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. ...

## Anti-patterns / Common mistakes
<2–3 bullets: the mistake → how you'd notice you're making it → what to do instead>

## Done when
<A self-check that proves the day is done: a verify script, problems answered without notes,
or an artifact built — never "read the section">

## Spaced review
<2–4 quick recall prompts from earlier days (e.g. day N−1, N−3, N−7); omit on Day 1>
```

Applied/engineering paths add:
```markdown
## Lab
See `labs/dayNN/`. The goal: <one line>. Success signal: <one line>.

## Teardown
<checklist leaving zero billable resources>
```

### Verification commands — make the check match the rule's scope

Every task's final step ships `grep`/`bash -n` checks. Two failure modes cost real rework on a past path:

- **A check narrower than the rule it enforces.** The forbidden-word sweep ran over `content/` and
  `labs/dayNN/` only, so the stack and seed files were never swept and shipped nine violations. If a rule
  says "anywhere", the check must say `-r` over the whole tree.
- **A check that greps for a literal the code never contains.** `grep -q 'lib/common.sh'` fails against
  the correct idiom `. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"`, and reported all
  eight day files as broken when every one was fine. Grep for a distinctive fragment, not a path you
  imagine the file spells out.

When a check fails across *every* file it inspects, suspect the check before the files.

### Practice problems — standing rule

**Every exercise ships with hints + solution sketches.** Never ship a bare problem. This is non-negotiable for all path types.

---

## Refresh mode — updating an existing path (v3 prompt)

Paths go stale: versions ship, flags and APIs get deprecated, exams change, best practice moves on. Refresh
mode updates a path **in place** — it does not re-run Spec → Plan → Content. Triggered by the v3 prompt in
`basic_prompt.md`, or any "check / update / refresh the X path" request.

**v3a — Triage (read-only, no edits, no branch).** For each path report: last refresh date
(`REFRESH_LOG.md` → spec date → last commit touching the path), subject volatility (fast: cloud, AI,
security, tools; medium: languages, databases, exams; slow: math, physics), and the likely drift since.
Rank and recommend which to refresh now.

**v3b — Refresh one path:**

1. **Clarify** (≤5 questions with defaults): scope (whole path / days / topics), known changes on the
   learner's side, whether labs may be re-run locally.
2. **Baseline:** read the spec's Target Versions & Sources, `REFRESH_LOG.md`, README, and the day index.
   Older specs without that section: reconstruct it from the content first.
3. **Research** current official sources for each targeted product/standard/exam: release notes,
   changelogs, deprecation notices, docs, exam specs, security advisories. Memory is not a source.
   Parallel research subagents are fine for large paths — one per product or topic area.
4. **Drift report** (in chat, before editing), each finding with file:line, source link, fix, effort:
   **WRONG NOW** (incorrect, broken, removed, unsafe) · **OUTDATED** (works but superseded) ·
   **MISSING** (new and belongs here) · **CHECKED, STILL CORRECT** (coverage evidence).
5. **Model gate**, then **apply:** create the Phase 0 scratch branch `refresh/<subject>`. WRONG NOW fixes
   go ahead; OUTDATED/MISSING items that add days, labs, or more than a section need the learner's OK.
   Every edit to a file that already exists gets a real diff, so per-fix reviews stay cheap.
6. **Verify:** re-run changed labs where they can run locally; the scope-matching verification rules
   above apply. Say plainly which labs could not be run.
7. **Record:** update the spec's Target Versions & Sources (new as-of date) and append to
   `<subject>/REFRESH_LOG.md`:

       ## YYYY-MM-DD
       Checked: <scope, versions/sources checked>
       Changed: <findings fixed, by category>
       Deferred: <proposed but not applied, and why>
       Not verified: <labs not re-run>

8. **Teardown** exactly as Phase 0.

**Never touch** the learner's own notes and progress (`PROGRESS.md`, their edits in day files). Don't
"modernize" content that is still correct — a refresh changes only what the sources show has drifted.

---

## Standing Constraints (apply to all paths)

| Constraint | Rule |
|---|---|
| Git commits | Commits are permitted ONLY on the Phase 0 scratch branch, purely so reviews can use diffs. **Never `git push`.** Never commit on the learner's behalf to `master`. Delete the scratch branch before handoff. |
| Credentials in files | Never write real secrets, keys, tokens, or account IDs into any file. Use placeholders + fill-in comments. Ship `*.tfvars.example` / `*.env.example`. |
| Git commands in subagents | Skip all `git status/diff/log` in implementer and reviewer dispatches. |
| Running real infra | Labs are *written*, not run, during authoring. |
| Labs repo split | The learner runs labs in a separate repo (see `LEARNER_PROFILE.md` → Practice environment). This repo holds only content, authored lab sources and progress — never `.terraform/`, state files, installed dependencies or lab outputs. When helping during a lab, work in the labs repo; fix the lab *source* here first, then tell the learner what to copy over. Terraform state and `*.tfvars` are never committed in either repo. |
| Exercises | Always ship hints + solution sketches for self-check. |
| Accuracy & freshness | Anything that changes (versions, CLI flags, APIs, exam formats, prices) is checked against current official sources; state the version/date targeted and link the source. If unsure, say so — never guess. |
| Evidence | "Top 1%" / "80%" in a request are figures of speech. Never invent statistics; back advice with evidence or label it as judgment. |
| Honest scope | Push back when the time budget can't reach the outcome; propose a realistic duration or narrower scope. |
| Active practice | Every day ends in something done and self-checkable (§Done when), with spaced review of earlier days. |
| Labs (engineering paths) | Always ship README + SOLUTION.md + teardown checklist. |
| Authorized testing (security paths) | All offensive labs target only the learner's own account and own deployed workload. State this explicitly in every offensive lab README. |

---

## Directory Layout Convention

```
<subject>/
├── README.md                   # quickstart, phase map, day index, usage
├── STRATEGY.md                 # fast-track strategy, kept fundamentals, mistakes, AI-use guidance
├── REFRESH_LOG.md              # dated refresh entries (created on first refresh)
├── content/
│   ├── GLOSSARY.md             # plain-English terms
│   ├── day01.md … dayNN.md
│   └── [primers/]              # optional encoding primers (see docs/superpowers/guides/encoding-primers-playbook.md)
├── [code/ or labs/]            # applied/engineering paths only
│   └── dayNN/                  # README.md, SOLUTION.md, *.tf or *.go, teardown
└── docs/superpowers/
    ├── specs/                  # design spec
    └── plans/                  # implementation plan
```

Pure science paths omit `code/` and `labs/`.

---

## Quick Checklist

New path (v1/v2 prompt) — for a refresh (v3), follow §Refresh mode steps 1–8 instead.

- [ ] Step 0: read LEARNER_PROFILE.md, extract slots from the v1/v2 prompt, ask ≤7 questions with defaults (outcome, profile, time, lab env, source of truth, path type)
- [ ] Reality check: time budget vs. outcome; check current official sources for changing tools/versions/exams
- [ ] Phase 0: create the scratch branch (or ask the learner to, if git is unreachable here)
- [ ] Model gate: spec phase
- [ ] Classify path type (pure science / applied / hybrid)
- [ ] Write spec → `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- [ ] Model gate: plan phase
- [ ] Write plan → `docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md`
- [ ] Model gate: content phase
- [ ] Dispatch subagents (no git in dispatches, no real infra)
- [ ] Verify: all exercises have hints + solutions, all labs have README + SOLUTION + teardown
- [ ] Verify: every day has "Done when" + (from Day 2) "Spaced review"; spec lists target versions with sources
- [ ] Verify: no credentials or real secrets in any file
- [ ] Phase 0 teardown: `reset --soft` → `switch master` → `reset` → `branch -D`, then verify the
      path is untracked on `master` and nothing was pushed
