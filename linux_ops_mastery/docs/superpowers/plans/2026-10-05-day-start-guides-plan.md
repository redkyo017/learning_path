# "Start here" Guides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every day of `linux_ops_mastery` a plain, numbered "Start here" list and opt-in graded hints, so the learner always knows the first command to type after reading a day.

**Architecture:** Additive Markdown only. Each `labs/dayNN/README.md` gains two sections (Start here, Stuck? Hints); each `content/dayNN.md` gains three one-line additions; the top-level `README.md` gains one section. A structural check script is the "test"; a live run of each day's commands against the Docker fleet (or host, Days 8–10) is the acceptance check.

**Tech Stack:** Markdown, bash, Docker Compose v5 (project `linuxops`), busybox/Alpine containers.

**Spec:** `docs/superpowers/specs/2026-10-05-day-start-guides-design.md` — read it before any task.

All paths below are relative to `linux_ops_mastery/` unless absolute.

## Global Constraints

- **No git operations.** Do not `git add`, commit, or push. The learner commits. (Overrides the skill's default commit step.)
- No change to `break.sh`, `verify.sh`, `SOLUTION.md`, `ANSWERS.md`, `gauntlet.sh`, `labs/fleet/**`, `labs/lib/**`, or the substance of `content/dayNN.md`.
- No renaming of existing headings.
- Exact heading strings: `## Start here — plain steps` (em dash), `## Stuck? Hints`, `## How to approach any day`.
- Start-here items: 5–8, each formatted `N. **Bold verb phrase:** plain sentence(s)` — the check counts lines matching `^[0-9]+\. \*\*`.
- Every command in Start here is written to run **from the repo root `linux_ops_mastery/`** (host) or names the container it runs inside. Container entry form: `docker compose -p linuxops exec <svc> sh` (`ws` uses `bash`). Verified 2026-10-05: this works from the repo root with no `-f`.
- Hint ladder format (verbatim skeleton):
  ```markdown
  <details><summary>Hint 1 — where to look</summary>

  ...
  </details>
  ```
  Summaries: `Hint 1 — where to look`, `Hint 2 — what proves it`, `Hint 3 — almost there`. Blank line after each `<summary>` line is mandatory. Section ends with the exact line ``Still stuck: read `SOLUTION.md`.``
- Hint 3 names the cause; it never gives the repair command.
- Plain English: short sentences; any jargon gets a 3–6 word gloss on first use.
- Use `/usr/bin/grep` in any shell checks (the shell `grep` is aliased).

## Review Focus

1. **Learner pastes a Start-here command from the wrong directory** — every host command must say "from `linux_ops_mastery/`" in step 1 and use `labs/dayNN/...` paths (Day 6's existing README uses `../day06/` from `labs/fleet/`; Start here must not copy that form). Pinned by each task's live run, which executes from the repo root.
2. **Hints contradict `SOLUTION.md`** (pointing at the wrong file/cause) — each task's review step diffs hint claims against `SOLUTION.md` line by line.
3. **Hint 3 leaks the fix** (e.g. contains `kill`, `: >`, `truncate`, `systemctl daemon-reload`, `chmod` with the exact target) — each task's review step greps Hint 3 blocks for the SOLUTION's fix command.
4. **Container not running when the learner starts** (e.g. `proxy` currently exited; `sysd` needs the overlay) — Start here step for Days 1–7 includes the bring-up check or points to it; Day 5/6 live runs start from `docker compose -p linuxops up -d` state.
5. **`<details>` renders expanded/broken** because of a missing blank line — pinned by `check_guides.sh` rule 5.

## The structural check (used by every task)

Task 1 Step 1 writes this file. Save it at `/private/tmp/claude-504/-Users-hunghd-git-clone-learning-path/fe093ba9-63dd-4557-8adf-04c24959466e/scratchpad/check_guides.sh` (referred to below as `$CHECK`). If that scratchpad path is gone (new session), save it to any temp path and use that.

```bash
#!/usr/bin/env bash
# Structural check for the "Start here" guides. Usage: check_guides.sh [day ...]
# Run from linux_ops_mastery/. Days default to 01..10. Exit 0 = all pass.
G=/usr/bin/grep
days=("$@"); [ ${#days[@]} -eq 0 ] && days=(01 02 03 04 05 06 07 08 09 10)
fail=0
bad() { echo "FAIL day$1: $2"; fail=1; }
for d in "${days[@]}"; do
  L=labs/day$d/README.md; C=content/day$d.md
  sh=$($G -n '^## Start here — plain steps$' "$L" | cut -d: -f1)
  ag=$($G -n 'At a glance' "$L" | head -1 | cut -d: -f1)
  gl=$($G -nE '^(## Goal|\*\*Goal|## Scenario|## What this is)' "$L" | head -1 | cut -d: -f1)
  if [ -z "$sh" ]; then bad $d "no Start here heading"; else
    [ "$sh" -gt "$ag" ] || bad $d "Start here not after At a glance"
    [ -n "$gl" ] && { [ "$sh" -lt "$gl" ] || bad $d "Start here not before Goal/Scenario"; }
    n=$(awk -v s="$sh" 'NR>s && /^## /{exit} NR>s && /^[0-9]+\. \*\*/{c++} END{print c+0}' "$L")
    { [ "$n" -ge 5 ] && [ "$n" -le 8 ]; } || bad $d "Start here has $n bold numbered items (want 5-8)"
    sec=$(awk -v s="$sh" 'NR>s && /^## /{exit} NR>s' "$L")
    echo "$sec" | $G -q 'journal.md' || bad $d "Start here never mentions journal.md"
    echo "$sec" | $G -q 'verify.sh' || bad $d "Start here never mentions verify.sh"
  fi
  $G -q 'No further hints' "$L" && bad $d "'No further hints' still present"
  nd=$($G -c '<details>' "$L")
  if [ "$d" = 07 ]; then
    [ "$nd" -eq 0 ] || bad $d "Day 7 must have no hints"
    $G -q 'No hints today' "$L" || bad $d "Day 7 missing 'No hints today' line"
  else
    $G -q '^## Stuck? Hints$' "$L" || bad $d "no Stuck? Hints heading"
    { [ "$nd" -ge 3 ] && [ $((nd % 3)) -eq 0 ]; } || bad $d "$nd <details> blocks (want multiple of 3, >=3)"
    [ "$nd" -eq "$($G -c '</details>' "$L")" ] || bad $d "unbalanced <details>"
    nb=$(awk '/<summary>.*<\/summary>$/{getline nx; if (nx!="") c++} END{print c+0}' "$L")
    [ "$nb" -eq 0 ] || bad $d "$nb <summary> lines not followed by a blank line"
    $G -q 'Still stuck: read `SOLUTION.md`' "$L" || bad $d "missing 'Still stuck' SOLUTION pointer"
  fi
  $G -q 'Start here — plain steps' "$C" || bad $d "content At-a-glance lacks Start here pointer"
  sl=$($G -nE '^## Strip (the toolbox|step)$' "$C" | cut -d: -f1)
  if [ -n "$sl" ]; then
    nx=$(awk -v s="$sl" 'NR>s && NF{print; exit}' "$C")
    case "$nx" in "*Plain version:"*) ;; *) bad $d "Strip heading not followed by *Plain version:* line";; esac
  else bad $d "no Strip heading"; fi
  el=$($G -n '^## Exercises$' "$C" | cut -d: -f1)
  nx=$(awk -v s="$el" 'NR>s && NF{print; exit}' "$C")
  case "$nx" in "*How to use these:"*) ;; *) bad $d "Exercises heading not followed by *How to use these:* line";; esac
done
if [ ${#@} -eq 0 ]; then
  $G -q '^## How to approach any day$' README.md || { echo "FAIL README: no 'How to approach any day'"; fail=1; }
fi
[ $fail -eq 0 ] && echo "ALL PASS (${days[*]})"
exit $fail
```

Baseline (2026-10-05, before any task): every day fails; 71 FAIL lines total.

## Shared per-day recipe (every day task follows it)

For each day `NN` in the task:

1. **Read** `content/dayNN.md`, every file in `labs/dayNN/`, and `journal.md` (template + Day 1 example).
2. **Lab README — Start here.** Insert `## Start here — plain steps` immediately after the At-a-glance bullet list (before `## Goal` / `**Goal:**` / `## Scenario` / `## What this is`). 5–8 items, in this order where applicable: start the incident (`bash labs/dayNN/break.sh` from `linux_ops_mastery/`) → get into the right shell (exact command) → look at the symptom (1–2 read-only commands that show the symptom, not the cause) → write the chain in `journal.md` before fixing (template at top of that file; Day 1 example shows the style) → fix within the day's constraint → `bash labs/dayNN/verify.sh` and its exact success output → Strip drill pointer (enter `slim` with `docker compose -p linuxops exec slim sh`, or the day's actual target; snippet lives in `content/dayNN.md`) → teardown file. Merge items to stay ≤ 8.
3. **Lab README — Stuck? Hints** (not Day 7). Append `## Stuck? Hints` at the very end of the README: one line "Open one at a time. Try for 10 minutes before opening the next.", then the 3-hint ladder per cause (see task for count; each extra ladder under its own `### <cause name>` subheading), then ``Still stuck: read `SOLUTION.md`.``. Derive every hint from `SOLUTION.md`: Hint 1 = which truth / area; Hint 2 = the file or command whose output proves it; Hint 3 = the cause in plain words, no repair command.
4. **Lab README — No-further-hints line.** Replace any sentence starting "No further hints" with: "If you get stuck, use **Stuck? Hints** at the bottom of this file before opening `SOLUTION.md`." If a `## No spoilers` section exists, leave it, but if it states there are no hints anywhere, amend that one clause to say the hints at the bottom are opt-in.
5. **Content file — three additions:**
   a. In the "At a glance" list, append to the Lab item: ` — start with *Start here — plain steps* in `labs/dayNN/README.md`.`
   b. First non-blank line under `## Strip the toolbox` / `## Strip step`: an italic line beginning `*Plain version:` that says in one or two sentences what the drill asks and where it runs (with the exact entry command if it uses a container).
   c. First non-blank line under `## Exercises`: `*How to use these: optional, not tied to the lab. Read a question, write down your prediction, then read the hint and solution. Cover the solution first — it is printed right under the question.*`
6. **Structural check:** `bash $CHECK NN` → `ALL PASS (NN)`.
7. **Live run** (from `linux_ops_mastery/`): bring-up per the day; `bash labs/dayNN/break.sh`; run every Start-here symptom command non-interactively (`docker compose -p linuxops exec -T <svc> sh -c '<cmd>'`) and confirm it shows the symptom the step describes; apply the fix from `SOLUTION.md`; `bash labs/dayNN/verify.sh` → expected success output; perform the day's teardown so the fleet is clean for the next day. Record outputs in the task report.
8. **Review:** for every hint, quote the `SOLUTION.md` line that supports it; grep each Hint 3 for the SOLUTION's repair command (must be absent); `git diff --stat` shows only the two files for this day.

---

### Task 1: Day 1 pilot (sets the format)

**Files:**
- Modify: `labs/day01/README.md` (insert after At-a-glance block ending line 11; replace "No further hints here on purpose." sentence near line 33; append Stuck? Hints at end)
- Modify: `content/day01.md` (At-a-glance item 2 at lines 8–10; under `## Strip the toolbox` line 272; under `## Exercises` line 303)
- Create: `$CHECK` (script above)

**Interfaces:**
- Produces: the reference Start-here and hint style every later task copies; `$CHECK`.

- [ ] **Step 1: Write the check script** to `$CHECK` verbatim from "The structural check" above.
- [ ] **Step 2: Run it, confirm failure.** `bash $CHECK 01` → 8 FAIL lines incl. `no Start here heading`.
- [ ] **Step 3: Start here.** Insert this (approved by the learner; tighten wording only):

```markdown
## Start here — plain steps

1. **Start the lab:** on your Mac, from `linux_ops_mastery/`, run `bash labs/day01/break.sh`. It fills up the `/var/log` disk inside the `app` container.
2. **Get a shell in the broken container:** `docker compose -p linuxops exec app sh`. Everything until step 5's verify runs in this shell.
3. **Look at the symptom:** `df -h /var/log` says it is full. `du -sh /var/log` says almost nothing is there. Your job is to explain that gap.
4. **Write your reasoning in `journal.md` before fixing anything.** Copy the chain template at the top of that file; its Day 1 example shows the style.
5. **Fix it without restarting `app`,** then, back on your Mac, run `bash labs/day01/verify.sh` and wait for `PASS`.
6. **Strip-the-toolbox drill:** run `docker compose -p linuxops exec slim sh`, paste the 5-line snippet from "Strip the toolbox" in `content/day01.md`, and watch the same evidence appear with no `lsof`.
7. **Tidy up:** follow `labs/day01/teardown.md`. Leave the fleet running for Day 2.
```

- [ ] **Step 4: Stuck? Hints** — one ladder. Content (verify each against `labs/day01/SOLUTION.md` and adjust if it disagrees):
  - Hint 1: `df` counts blocks the filesystem still holds; `du` counts only files that still have a name. The missing bytes belong to a file with no name. That points to the FD table — what processes still hold open.
  - Hint 2: every open file of every process is a symlink under `/proc/<PID>/fd/`. `ls -l` on those shows where each points, and a deleted target ends in `(deleted)`.
  - Hint 3: a background process still has a big log file open after that file was deleted. The kernel cannot free the space until that descriptor is closed or the file is emptied through it.
- [ ] **Step 5: Replace** "No further hints here on purpose." per recipe step 4.
- [ ] **Step 6: Content additions** per recipe step 5. Day 1 Strip plain line: `*Plain version: a practice drill. Make the same "deleted but still open" file yourself inside the bare `slim` container (enter with `docker compose -p linuxops exec slim sh`), then find it with only busybox `ls` and `grep` — no `lsof`.*`
- [ ] **Step 7: Check:** `bash $CHECK 01` → `ALL PASS (01)`.
- [ ] **Step 8: Live run** per recipe step 7 (fleet: `docker compose -p linuxops up -d`; fix: either SOLUTION option; teardown per `labs/day01/teardown.md`). Also run the Strip snippet in `slim` and confirm a `(deleted)` line appears.
- [ ] **Step 9: Review** per recipe step 8. Present the Day 1 diff to the main session; later tasks start only after the main session accepts the Day 1 style.

### Task 2: Days 2–4

**Files:** Modify `labs/day0{2,3,4}/README.md`, `content/day0{2,3,4}.md`.

**Interfaces:** Consumes Task 1's style (read `labs/day01/README.md` Start here + Stuck? Hints first) and `$CHECK`.

Day-specific shape:
- **Day 2:** diagnose in `ws` and `app`; three independent causes → Start here says "three separate chains in `journal.md`, one per cause, before fixing any"; constraint: do not restart `app`, do not kill PID 1 or python. Hints: three ladders, `### Cause 1/2/3 — <plain name>` (names must not spoil — e.g. "the first process that won't die").
- **Day 3:** two deliverables (`req_id` into `/tmp/answer` on `app`; release the held file) — Start here states both; replace the "No further hints here." sentence at line 60. Hints: one ladder per deliverable (2 ladders).
- **Day 4:** diagnosis only — nothing to fix, no restart; deliverable is `/tmp/findings` on `app` in the exact README format → Start here's "fix" step becomes "write `/tmp/findings` exactly as shown in the README". Hints: one ladder per failure (memory kill, CPU throttle) = 2 ladders.

- [ ] **Step 1:** `bash $CHECK 02 03 04` → fails (record count).
- [ ] **Step 2:** Day 2 per recipe steps 1–5.
- [ ] **Step 3:** Day 3 per recipe steps 1–5.
- [ ] **Step 4:** Day 4 per recipe steps 1–5.
- [ ] **Step 5:** `bash $CHECK 02 03 04` → `ALL PASS (02 03 04)`.
- [ ] **Step 6:** Live run Days 2, 3, 4 in order per recipe step 7, teardown between days.
- [ ] **Step 7:** Review per recipe step 8.

### Task 3: Days 5–6

**Files:** Modify `labs/day0{5,6}/README.md`, `content/day0{5,6}.md`.

**Interfaces:** Consumes Task 1 style and `$CHECK`.

Day-specific shape:
- **Day 5:** Start here step 1 = bring up base fleet + `sysd` overlay — point to "Bring-up (Day 5 only)" and give the two commands rewritten to run from the repo root (`docker compose -p linuxops -f labs/fleet/docker-compose.yml -f labs/fleet/docker-compose.sysd.yml up -d --build sysd`); test that form live. Shell: confirm the working `exec` form for `sysd` from the repo root and the shell it has (`bash` expected — verify). Two incidents, two chains. Success output `3/3 checks passed`. If `sysd` exits on Docker Desktop, the Start here line points to the Colima fallback in `labs/fleet/README.md`; record in the report whether the live run succeeded or fell back. Hints: two ladders (`### Incident 1 — the 0777 file`, `### Incident 2 — the unit that won't start`).
- **Day 6:** `break.sh 1`..`5` then `random`; diagnose across `proxy`, `app`, `db`. Start here must use repo-root paths (`bash labs/day06/break.sh 1`, `bash labs/day06/verify.sh`), not the `../day06/` form. Steps: start rung 1 → enter the right container (the README/content say where the ladder is walked from — use that) → name the rung before touching anything → chain in journal → fix only that rung → verify → repeat for 2–5 → `random`. Hints: five ladders `### Rung N` — but Hint 1 for each must not name the rung outright (it says which question to ask first), since naming the rung is the skill. Before live run: `docker compose -p linuxops up -d` (proxy was found exited on 2026-10-05).

- [ ] **Step 1:** `bash $CHECK 05 06` → fails.
- [ ] **Step 2:** Day 5 per recipe steps 1–5.
- [ ] **Step 3:** Day 6 per recipe steps 1–5.
- [ ] **Step 4:** `bash $CHECK 05 06` → `ALL PASS (05 06)`.
- [ ] **Step 5:** Live run Day 5 (with overlay) then Day 6 rungs 1–5, teardown each.
- [ ] **Step 6:** Review per recipe step 8.

### Task 4: Day 7

**Files:** Modify `labs/day07/README.md`, `content/day07.md`.

Day-specific shape: `gauntlet.sh <1-5|all>` replaces `break.sh`; `verify.sh <N|all>`; 15 minutes per incident; fix each fully before the next; `ANSWERS.md` stays closed until all five chains are written. Insert Start here after At a glance, before `## What this is` — the existing "No spoilers below…" paragraph sits between them; put Start here after that paragraph but before `## What this is`. Steps: start incident 1 (`bash labs/day07/gauntlet.sh 1`) → start a 15-minute timer → find which container the symptom is in (the gauntlet output says; use the shell table in top-level README) → chain in journal → fix → `bash labs/day07/verify.sh 1` → repeat 2–5 → only then open `ANSWERS.md`. Final line of the section: "No hints today — that is the test. `ANSWERS.md` opens after all five chains are written." Also cover the Day 7 Neovim block in one step if the content's At-a-glance lists it first. No `Stuck? Hints` section. Content additions per recipe step 5.

- [ ] **Step 1:** `bash $CHECK 07` → fails.
- [ ] **Step 2:** Edit per above and recipe steps 1, 2, 5.
- [ ] **Step 3:** `bash $CHECK 07` → `ALL PASS (07)`.
- [ ] **Step 4:** Live run: `bash labs/day07/gauntlet.sh 1`, confirm the Start-here commands work and the symptom appears; repair per `ANSWERS.md` incident 1; `bash labs/day07/verify.sh 1` passes; teardown per `labs/day07/teardown.md`. (Only incident 1 is required live; others just confirm `gauntlet.sh N` starts.)
- [ ] **Step 5:** Review: no hint text anywhere in Day 7 Start here that names a mechanism; diff limited to the two files.

### Task 5: Days 8–10

**Files:** Modify `labs/day{08,09,10}/README.md`, `content/day{08,09,10}.md`.

Day-specific shape: host only — no Docker. Step 1 of Start here says so ("No Docker today — everything happens on your Mac under `/tmp/labNN/`"). Steps: `bash labs/dayNN/break.sh` → look at the files it created (`ls -l /tmp/labNN/`) → run the broken script the way the README's "The incident" section shows and observe the symptom → chain in journal → fix the script (edit it in place under `/tmp/labNN/`) → `bash labs/dayNN/verify.sh` → the Strip step from the content file → teardown section. Strip heading is `## Strip step` — plain line glosses what that day's Strip step asks (read it; it is not the `slim` container). One hint ladder per day. Note Day 8 creates a mode-000 file; Day 9 needs Ctrl-C — say "press Ctrl-C after the second server line" or whatever the README specifies.

- [ ] **Step 1:** `bash $CHECK 08 09 10` → fails.
- [ ] **Step 2–4:** Days 8, 9, 10 per recipe steps 1–5.
- [ ] **Step 5:** `bash $CHECK 08 09 10` → `ALL PASS (08 09 10)`.
- [ ] **Step 6:** Live run each on the host (macOS bash/zsh — note in the report any command that behaves differently on macOS vs. Linux, e.g. `stat` flags). For Day 9's Ctrl-C step, simulate with `timeout -s INT` or `kill -INT` and say which.
- [ ] **Step 7:** Review per recipe step 8.

### Task 6: Top-level README — "How to approach any day"

**Files:** Modify `README.md` — insert new section after "## The daily loop" section (before "## The arrow-key rule").

- [ ] **Step 1:** `bash $CHECK` (all days) — confirm the README FAIL line is present.
- [ ] **Step 2:** Insert:

```markdown
## How to approach any day

Each day has up to four kinds of activity. They have different names but
are simple:

- **Lab** — a script breaks something on purpose; you find out why, write
  it down, fix it, and a second script checks your fix.
- **Strip drill** ("Strip the toolbox" / "Strip step") — practice: do the
  same detection again with only bare tools, so you can still do it on a
  minimal server.
- **Exercises** — optional predict-then-check questions. Not tied to the
  lab. Cover the solution, guess, then read.
- **Neovim block** — Days 1 and 7 only: editor practice, separate from the
  incident.

The routine, every day:

1. Read `content/dayNN.md`.
2. Open `labs/dayNN/README.md` and follow **Start here — plain steps**.
3. Stuck? Open the hints at the bottom of that README, one at a time.
4. `SOLUTION.md` last — after your own attempt.
5. Teardown file before moving on.

### Getting a shell

Run these on your Mac from `linux_ops_mastery/`:

| Where | Command | Used on |
|---|---|---|
| `ws` (main shell, has every tool) | `docker compose -p linuxops exec ws bash` | Days 1–7 |
| `app` (the service being debugged) | `docker compose -p linuxops exec app sh` | Days 1–4, 6 |
| `slim` (busybox only) | `docker compose -p linuxops exec slim sh` | Strip drills |
| `db` | `docker compose -p linuxops exec db sh` | Day 6 |
| `proxy` | `docker compose -p linuxops exec proxy sh` | Day 6 |
| `sysd` (real systemd) | <the form verified in Task 3> | Day 5 |
| Your Mac | no container | Days 8–10 |

`exit` leaves a container shell.
```

  Fill the `sysd` row with the exact command Task 3 verified live. Confirm every row's "Used on" against the lab READMEs' "Environment" lines; correct the column if a README disagrees.
- [ ] **Step 3:** Live check every row: `docker compose -p linuxops exec -T <svc> <shell> -c 'echo ok'` for each container (bring `sysd` up via overlay for its row).
- [ ] **Step 4:** `bash $CHECK` → `ALL PASS (01 02 03 04 05 06 07 08 09 10)`.

### Task 7: Final review and handoff

- [ ] **Step 1:** `bash $CHECK` → `ALL PASS (...)` for all ten days plus README.
- [ ] **Step 2:** `git status --short` and `git diff --stat` — only the 20 day files, `README.md`, and the new spec/plan files appear. No other path changed.
- [ ] **Step 3:** Fresh-eyes read of Days 1, 4, 6, 8 Start here as a newcomer: every step names where to run it and has no undefined jargon. Fix any issue.
- [ ] **Step 4:** `bash labs/verify-teardown.sh` only if the learner wants the fleet down; otherwise leave the fleet up with no day's incident active (each day was torn down in its task).
- [ ] **Step 5:** Report to the learner: what changed, live-run results per day (incl. Day 5 Docker Desktop vs. Colima), anything not verified. Do not commit.
