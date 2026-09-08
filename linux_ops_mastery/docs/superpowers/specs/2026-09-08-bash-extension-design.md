# Bash Scripting Extension — Design Spec

**Date:** 2026-09-08
**Location:** `linux_ops_mastery/`
**Duration:** 3 days, ~2 h/day (~6h total)
**Appended as:** day08–day10 inside the existing `linux_ops_mastery/` path

---

## Purpose & Goals

The seven-day Linux ops path teaches a senior engineer to diagnose live systems
by reading kernel files directly. That skill is half the job. The other half is
automating it — writing scripts that can be trusted to run unattended, compose
into pipelines, and fail loudly instead of silently succeeding with wrong output.

This extension adds three days of bash scripting to the existing path, targeting
the specific gap that trips up engineers who already know the basics (variables,
`if/for/while`, one-liners) but have never been forced to reason about what
their scripts actually do at the process level. The learner writes scripts that
*feel* correct, watches them fail in non-obvious ways, diagnoses why, and
rebuilds them against the underlying model.

The product is a small `bash/ops-toolkit/` of reusable, hardened scripts that
the learner authors incrementally across the three days. By day 10 they own a
`diagnose.sh` that wraps the `/proc`-based moves from days 1–7 into a
composable CLI tool.

**Learner profile:** senior engineer, Linux daily, basics-level bash (one-liners,
`if/for/while`, occasional `$?`), avoids functions and explicit error handling,
no prior exposure to `set -euo pipefail`, traps, or subshell scope rules.

---

## Success Criteria

By the end of day 10, without notes, the learner can:

1. Explain why `cmd1 | cmd2` can silently discard `cmd1`'s non-zero exit code,
   and fix it with `set -o pipefail`.
2. Write a script header (`set -euo pipefail` + `trap 'cleanup' EXIT INT TERM`)
   and explain what each flag and trap line prevents.
3. Predict whether a variable assignment inside a subshell or pipeline is visible
   to the parent shell, and why.
4. Write a `usage()` function, a safe positional-arg parser, and a retry loop
   that backs off and propagates the correct exit code on final failure.
5. Reproduce any bug from days 8–10 inside a bare `sh` (POSIX) session, proving
   the model — not bash-specific flags — is what was learned.
6. Read an unfamiliar ops script and name the first three places it could fail
   silently before running it.

---

## Constraints & Environment

- **No new Docker services.** The existing `ws` container (Ubuntu 24.04) has
  bash 5.x and `sh` (dash). All labs run there.
- **No new Docker Compose changes.** Days 8–10 reuse the existing `linuxops`
  compose project brought up in the main path's prerequisites.
- **POSIX strip step.** Each day ends with repeating the diagnosis in `sh`
  (not bash). Bash-specific fixes (`[[ ]]`, `local`, arrays) are learned, but
  learners must also identify the POSIX-portable equivalent.
- **No credentials or secrets** in any file. Lab scripts use `localhost`,
  test files under `/tmp`, and no external services.
- **No git commits** during authoring. The learner handles all VCS.
- **Product files authored through labs.** `lib/log.sh`, `lib/trap.sh`,
  `lib/args.sh`, and `bin/diagnose.sh` are not handed to the learner pre-written
  — they emerge from the lab exercises.

---

## Strategy (the core design decision)

### The underlying truth: a script is a process tree

Most bash tutorials teach syntax. Flags, builtins, string operators — a
vocabulary organized by reference-card convenience, not by the model that
explains when things go wrong. A learner who finishes a syntax tour can write
scripts that work on happy-path input and fail silently on everything else,
because nothing in the tour forces them to confront what a script actually *is*.

A bash script is a process. It forks from a parent (inheriting environment,
open file descriptors, and signal disposition), and it spawns a tree of child
processes — subshells, pipelines, command substitutions. The behaviors that
cost senior engineers real debugging hours are all boundary phenomena:

- A pipeline is a chain of processes connected by pipes. Each process has its
  own exit code. By default, the pipeline's exit code is the last command's —
  meaning a failure anywhere else is silently discarded.
- A subshell (`$(...)`, `(...)`, a pipeline stage) is a child process. Variable
  assignments inside it do not propagate back to the parent. This is not a
  bash quirk — it is fork semantics.
- A `trap` is registered per-process. It does not fire in child processes. A
  cleanup trap on `EXIT` in the parent will not run if the exit happens inside
  a subshell.
- `set -e` does not abort on every error — it has documented exceptions (inside
  `if` conditions, `||` chains, `&&` chains). A script with `set -e` that
  *feels* safe still has paths where errors are silently swallowed.

The move mirrors days 1–7: **symptom → process boundary → the behavior that
proves it**. No claim about why a script failed survives unless it can be traced
to a fork, a pipeline, or a signal disposition.

### Why alternatives were rejected

**Pattern-catalogue approach** (teach the 8–10 common ops patterns, no unifying
theory): faster to deliver, easier to skim, and structurally incapable of
explaining *why* the patterns are what they are. A learner who memorises
`set -euo pipefail` without understanding exit codes will cargo-cult it into
scripts where it doesn't help and omit it from scripts where it does.

**Certification-style bash coverage** (arrays, arithmetic, regex, here-docs,
process substitution as first-class topics): correct and complete for a bash
reference, wrong for a 6-hour extension targeting a senior engineer's real gap.
The gap is not syntax breadth — it is the absence of a process model.

---

## Curriculum

### Day 08 — Exit codes are the contract (2h)

**Truth:** every process exits with exactly one integer. Pipelines are chains
of processes, and the default exit code of a pipeline is the last command's.
This is the boundary where most silent failures hide.

**Break scenario:** a backup script runs a pipeline (`find | tar`), `find`
fails on a permission-denied path, `tar` succeeds on partial input, the
pipeline exits 0. The backup job reports success. The backup is incomplete.

**Session plan:**
- 20 min: read the model — `echo $?`, exit code of a pipeline with a failed
  stage, `PIPESTATUS` array. No `set -e` yet.
- 20 min: `set -euo pipefail` — what each flag catches, what it does not catch
  (the `if`/`||`/`&&` exceptions). Derive from the process model.
- 30 min: lab — `break.sh` injects the pipeline failure; learner diagnoses,
  writes chain in `journal.md`, fixes, runs `verify.sh`.
- 20 min: ops pattern — `usage()` function, stderr logging (`log.sh`). Author
  `lib/log.sh` as the lab product.
- 10 min: strip step — repeat with `sh`. Identify which bash-isms to remove.

### Day 09 — Subshells and traps (2h)

**Truth:** a subshell is a child process. Variable changes inside it are
invisible to the parent. A `trap` is per-process — it will not fire in a child.
Cleanup that depends on a parent-registered `EXIT` trap silently fails if the
exit happens inside a subshell.

**Break scenario:** a deployment script uses `mktemp` to create a working
directory, registers a cleanup trap, then does work inside a subshell
(`cmd | while read line; do ...`). The user hits Ctrl-C inside the pipeline
loop. The trap doesn't fire. The temp directory is never removed. On the next
run, the script fails because the directory already exists.

**Session plan:**
- 20 min: read the model — fork and subshell scope. Show that `x=1; (x=2); echo $x`
  prints 1. Show that a pipeline's right-hand side runs in a subshell.
- 20 min: `trap 'cleanup' EXIT INT TERM` — when it fires, when it doesn't.
  Demonstrate trap inheritance (child inherits parent's trap disposition but
  can override; `EXIT` trap does not propagate into child processes).
- 30 min: lab — `break.sh` injects the Ctrl-C scenario; learner diagnoses,
  writes chain, fixes, runs `verify.sh`.
- 20 min: ops patterns — lockfile with `mkdir` (atomic), idempotency guard,
  `mktemp -d` with trap cleanup. Author `lib/trap.sh` as the lab product.
- 10 min: strip step — reproduce the trap scenario in `sh`.

### Day 10 — Argument contract + capstone (2h)

**Truth:** a script's interface is its argument contract — the set of inputs it
accepts, the outputs it produces, and the exit codes it emits. A fragile
argument parser is a broken contract: it silently accepts wrong input and
produces wrong output with exit code 0.

**Break scenario:** an ops script parses `$1`, `$2` positionally. Called with a
flag it doesn't recognise, or with a missing required argument, it silently uses
an empty string or an unset variable and proceeds. The operation runs on the
wrong target with no error.

**Session plan:**
- 20 min: read the model — `$@` vs `$*`, `${1:?error}`, `getopts` basics.
  Show that unquoted `$1` on an empty argument list doesn't error by default
  (without `set -u`).
- 20 min: safe arg parsing pattern — `getopts` loop, required vs optional args,
  `usage()` on error. Connect back to exit-code contract from day 8.
- 30 min: lab — `break.sh` injects the fragile-arg scenario; learner diagnoses,
  writes chain, fixes, runs `verify.sh`.
- 20 min: ops pattern + capstone — retry-with-backoff loop (exit code propagation
  on final failure); then author `lib/args.sh` and assemble `bin/diagnose.sh`,
  sourcing all three lib files. `diagnose.sh` accepts a PID or a resource class
  flag, runs the appropriate `/proc` chain from days 1–7, and retries transient
  failures up to N times before propagating a non-zero exit.
- 10 min: strip step — run `diagnose.sh` under `sh -n` (syntax check) and
  identify any bash-only constructs.

---

## Directory Layout

New files and directories only. Nothing in `linux_ops_mastery/` is removed or
renamed.

```
linux_ops_mastery/
├── README.md                        ← UPDATE: add day08–10 rows to day map table
├── STRATEGY.md                      ← UPDATE: add "The bash extension" section
├── content/
│   ├── day01.md … day07.md          ← untouched
│   ├── day08.md                     ← NEW
│   ├── day09.md                     ← NEW
│   └── day10.md                     ← NEW
├── labs/
│   ├── day01/ … day07/              ← untouched
│   ├── day08/
│   │   ├── README.md
│   │   ├── break.sh
│   │   ├── verify.sh
│   │   ├── teardown.md
│   │   └── SOLUTION.md
│   ├── day09/
│   │   ├── README.md
│   │   ├── break.sh
│   │   ├── verify.sh
│   │   ├── teardown.md
│   │   └── SOLUTION.md
│   └── day10/
│       ├── README.md
│       ├── break.sh
│       ├── verify.sh
│       ├── teardown.md
│       └── SOLUTION.md
└── bash/
    └── ops-toolkit/
        ├── lib/
        │   ├── log.sh       ← authored in day 8 lab
        │   ├── trap.sh      ← authored in day 9 lab
        │   └── args.sh      ← authored in day 10 lab
        └── bin/
            └── diagnose.sh  ← capstone, assembled in day 10
```

`docs/superpowers/specs/` and `docs/superpowers/plans/` receive the spec and
plan files. `content/GLOSSARY.md` receives new bash-specific entries.

---

## Content Day Skeleton

All three day files follow this structure, consistent with days 1–7:

```markdown
# Day N — <Title>

## Why this matters
<1 paragraph: concrete ops scenario where this model failure costs real time>

## The underlying truth
<The process-model concept for today. Read the raw behavior first, before
 any pattern or flag is introduced.>

## Breaking it down
<Step-by-step: demonstrate the failure mode with minimal reproducible examples.
 Connect each example back to the truth above.>

## The pattern
<The ops scripting pattern that the truth demands. Derive it — don't state it
 as a rule to memorise.>

## Lab
See `labs/dayNN/`. Break scenario: <one line>. Success signal: `verify.sh` exits 0.

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
3. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>

## Anti-patterns
- <pattern to avoid, with the process-model reason it fails>
- <pattern to avoid>
- <pattern to avoid>

## Strip step
Repeat today's lab diagnosis inside `sh` (not bash). Identify which constructs
require bash; find the POSIX-portable equivalent for each.
```
