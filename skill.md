un---
name: building-learning-path
description: Use when asked to build a structured learning path, mastery plan, or "master X as fast as humanly possible" request — covers spec, plan, and content-authoring phases with model gates and path-type classification
---

# Building a Learning Path

## Overview

Three-phase workflow: **Spec → Plan → Content**. Each phase has a model gate — you must ask the user which model to use before proceeding to each phase. No git commits during any phase; the learner handles all VCS.

**Announce at start:** "I'm using the building-learning-path skill."

---

## Step 0 — Clarify before speccing

Ask the user these questions before writing anything (one round, then proceed):

1. **Subject & goal:** What do they want to master? What does "done" look like at work or in study?
2. **Learner profile:** Prior knowledge level, tools they already use, existing repo context.
3. **Time budget:** Hours/day and total number of days (firm or flexible)?
4. **Lab environment:** Cloud account, local Docker, pure text, etc.?
5. **Path type trigger** (auto-detect from subject, confirm if ambiguous): see §Path Type Classification below.

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
<Numbered list: what the learner can do without notes by the end>

## Constraints & Environment
<Lab setup, cost limits, toolchain, standing rules (no credentials, no commits, etc.)>

## Strategy (the core design decision)
<The unconventional "top 1%" approach + why alternatives were rejected>

## Curriculum
<Phase-by-phase outline with day-level granularity and h/day estimates>

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
- Global constraints block (no credentials, no git commits, no running real infra)
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
<2–3 bullets>
```

Applied/engineering paths add:
```markdown
## Lab
See `labs/dayNN/`. The goal: <one line>. Success signal: <one line>.

## Teardown
<checklist leaving zero billable resources>
```

### Practice problems — standing rule

**Every exercise ships with hints + solution sketches.** Never ship a bare problem. This is non-negotiable for all path types.

---

## Standing Constraints (apply to all paths)

| Constraint | Rule |
|---|---|
| Git commits | Never commit on the learner's behalf. No `git commit`, `git push`, or `git add` during authoring. |
| Credentials in files | Never write real secrets, keys, tokens, or account IDs into any file. Use placeholders + fill-in comments. Ship `*.tfvars.example` / `*.env.example`. |
| Git commands in subagents | Skip all `git status/diff/log` in implementer and reviewer dispatches. |
| Running real infra | Labs are *written*, not run, during authoring. |
| Exercises | Always ship hints + solution sketches for self-check. |
| Labs (engineering paths) | Always ship README + SOLUTION.md + teardown checklist. |
| Authorized testing (security paths) | All offensive labs target only the learner's own account and own deployed workload. State this explicitly in every offensive lab README. |

---

## Directory Layout Convention

```
<subject>/
├── README.md                   # quickstart, phase map, day index, usage
├── STRATEGY.md                 # unconventional "top 1%" strategy
├── content/
│   ├── GLOSSARY.md             # plain-English terms
│   ├── day01.md … dayNN.md
│   └── [primers/]              # optional encoding primers (see encoding-primers-playbook.md)
├── [code/ or labs/]            # applied/engineering paths only
│   └── dayNN/                  # README.md, SOLUTION.md, *.tf or *.go, teardown
└── docs/superpowers/
    ├── specs/                  # design spec
    └── plans/                  # implementation plan
```

Pure science paths omit `code/` and `labs/`.

---

## Quick Checklist

- [ ] Step 0: clarify (subject, learner profile, time budget, lab env, path type)
- [ ] Model gate: spec phase
- [ ] Classify path type (pure science / applied / hybrid)
- [ ] Write spec → `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- [ ] Model gate: plan phase
- [ ] Write plan → `docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md`
- [ ] Model gate: content phase
- [ ] Dispatch subagents (no git in dispatches, no real infra)
- [ ] Verify: all exercises have hints + solutions, all labs have README + SOLUTION + teardown
- [ ] Verify: no credentials or real secrets in any file
