# Journal

## Why keep this

Writing up what you did — in your own words, right after doing it — is what turns a lab
exercise into retained knowledge. `content/STRATEGY.md` calls this out as a core habit:
spaced retrieval via writeups. The goal isn't polish; it's forcing yourself to
articulate the attack, the fix, and the gap in your understanding while it's still fresh.
Fill in one entry per day, right after you finish that day's drills — before you move on
to the next day.

## Entry template

Copy this block for each day and fill it in.

```
### Day NN — <title> (YYYY-MM-DD)

**What I attacked:** <the target and the vulnerability/weakness>

**How:** <the tool(s) and steps that got you from nothing to exploited>

**What defended it:** <the control you applied, and how you confirmed it actually
blocked or detected the attack>

**What confused me:** <the part that took longest to click, or still doesn't fully>

**One thing to revisit:** <a concept, tool, or edge case worth coming back to later>
```

## Phase retrospectives

Beyond the daily entries above, this path has four larger checkpoints — one at the end
of each phase, plus a final one closing out the whole 21-day core. Copy each block
below into a new entry in this file when you reach that day, in addition to that day's
normal 5-field entry.

### Phase 1 retro (Day 6, end of Days 0–6)

> **Phase 1 retro, before moving on:** this is the end of Phase 1 (Days 0–6). Before
> starting Phase 2, add a second, larger entry to `journal.md` answering: *of
> everything from threat modeling through privilege escalation, which single skill
> do you trust yourself to do again today, unaided, with no notes — and which one
> would you still need to look up?* Naming the gap honestly now is cheaper than
> discovering it mid-attack later.

### Phase 2 retro (Day 12, end of Days 7–12)

> This is also an **end-of-Phase-2 checkpoint**, same structure as Day 6's
> end-of-Phase-1 retro: before moving on, skim back over `content/day07-http.md`
> through today and confirm you could still explain, from memory, what each day's
> core bug was and what specifically fixed it. If any day's answer doesn't come
> immediately, that's the day to revisit before Day 13.

### Phase 3 retro (Day 18, end of Days 13–18)

```
### Phase 3 Retro — Cloud / AWS (Days 13–18)

**Chains that surprised me most:** <which combination of separate days' skills
clicked together in a way you didn't expect until Day 18 forced it>

**One control that would have stopped the most stages at once:** <pick a single
AWS control from Days 13–18 and name every stage across the whole phase it would
have blocked, not just one day's>

**Muscle memory built this phase:** <one AWS CLI pattern — an IAM policy document,
an IMDS curl, a cloudtrail lookup-events filter — you can now write without
looking it up>

**Biggest gap before Phase 4:** <a cloud concept from Days 13–18 that's still
shaky>

**Cloud teardown close-out:** confirm, right now, that every lab from Days 13–18
has actually been torn down — re-run each day's `teardown.sh` (or its documented
checks) once more here and record the result. Phase 3 is the only phase in this
path with a real dollar cost attached to leaving something running by accident.
```

### Final retrospective (Day 21, end of the whole path)

```
### Capstone Retrospective — the whole path (YYYY-MM-DD)

**The single most valuable thing I built:** <not "learned" -- built. A skill, a habit,
or an artifact from this path you'd actually reach for again.>

**The bug class I now recognize fastest:** <across all 21 days, which vulnerability
pattern do you now spot on sight, in code or in a report, without having to think
about it?>

**The stage I'm still least confident in:** <recon, foothold, escalation, lateral
movement, detection, or reporting -- name the one weakest link honestly, the same way
Section 1's residual-risk habit asks you to name a system's weakest link honestly.>

**What "attacker mindset before tools" (STRATEGY.md, Day 0) actually meant by the end:**
<in your own words now, not the definition you'd have given on Day 0.>

**My next specialization, and why:** <the Extension Module you picked from ROADMAP.md,
and the one sentence that made you pick it over the others.>
```

---

<!-- Day entries start below this line. -->
