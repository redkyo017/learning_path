# Day 45 — Patching the day-44 error log; rewriting Schreiben

**Phase:** 4 — Simulation | **Total:** 2h15 | **New cards:** 0

## Why this matters

No new material today — the same rule as day 43. You work the day-44 error log end to
end, with Schreiben getting the dedicated fix, because a written mistake in Teil 1's
field order or a missing point in Teil 2's message is exactly the kind of error that
repeats mock after mock if it isn't rewritten by hand, not just noted.

## Core concepts

Keep using the same error-log format from day 43: module, item, your answer, the correct
answer, cause. Today's dedicated fix targets every wrong or incomplete Schreiben answer
specifically — you rewrite each one from scratch against `templates/schreiben_templates.md`,
rather than just marking it as understood.

### Block 1 — Anki (25 min)

Review only, 0 new cards. Clear the backlog.

### Block 2 — Input (40 min)

Go through the day-44 error log module by module and write the likely cause next to each
miss, exactly as on day 43. Do not fix anything yet.

### Block 3 — Output (40 min)

Rewrite every failed or incomplete Schreiben answer from the day-44 log. For Teil 1 field
mistakes, redo the field against the three traps in `templates/schreiben_templates.md`.
For Teil 2, rewrite the message from scratch, checking it against the prompt's three
points one by one — per that file's own rule, a message missing a point loses marks no
matter how clean the grammar is — before checking anything else.

### Block 4 — Exam drill (30 min)

Time yourself writing one full Schreiben module fresh, Teil 1 and Teil 2 both, to confirm
the fixes hold under time pressure and not just when you're rewriting slowly.

## Exercises

1. A common Teil 1 slip: you write a Geburtsdatum as "11.09.1998" for "9. November 1998." — **Hint:** German dates are day, then month, then year — English word order for "9 November" tempts you into month-first. — **Solution sketch:** `09.11.1998`, day first, then month, then year. Check the field order against `templates/schreiben_templates.md`'s first trap.
2. A common Teil 1 slip: you write an address line as "Stuttgart 70173" instead of the correct order. — **Hint:** Postleitzahl comes before Wohnort on a German form. — **Solution sketch:** `70173 Stuttgart.` Rewrite the address line with the digits first.
3. A common Teil 2 slip: your message cancels a Saturday meeting and proposes Sunday, but never asks for a reply. — **Hint:** `templates/schreiben_templates.md`'s own rule — a message missing one of its three points loses marks regardless of grammar. — **Solution sketch:** append the missing third point — `Kannst du mir bitte kurz schreiben?` — so the rewritten message covers all three points.

## Anti-patterns / Common mistakes

- Fixing the grammar in a failed Teil 2 message without first checking whether all three prompt points are covered. Per `templates/schreiben_templates.md`'s own rule, a message missing a point loses the same marks whether the German around it is perfect or not.
- Rewriting only the messages you got completely wrong and skipping the ones that were "mostly right." A mostly-right form with one wrong field — a swapped date order, a missing Postleitzahl — loses the same marks as a fully wrong one, so the error log includes partial misses too.

## Minimum viable day

Block 1 + the Schreiben rewrite from Block 3 only (45 min). See `runbook.md` §Bad days.

## Done when

- [ ] Anki review queue cleared, 0 new cards
- [ ] Every day-44 Schreiben error rewritten and checked against `templates/schreiben_templates.md`
- [ ] One full Schreiben module rewritten fresh, timed
