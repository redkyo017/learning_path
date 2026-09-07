# Runbook

This is the file you open when you are not sure what to do next — a normal day, a bad day, or a day you already missed. It does not motivate you. It tells you what to do.

If you have never opened this path before, read `README.md` and `STRATEGY.md` first. This file assumes you already know the plan; it only tells you how to run it.

## Daily startup (2 min)

Before the timer starts, do these four things in order:

1. Open today's file: `content/dayNN.md` (for example `content/day07.md`).
2. Glance at `progress_tracker.md` — check yesterday's status and today's date so you know which day number you are actually on.
3. Set a physical timer for the session (phone timer is fine, but then put the phone in another room).
4. Headphones in. Phone in another room. You cannot shadow German audio and answer Zalo messages in the same 2.25 hours.

Do not skip step 2. If you lost count of the day number, `progress_tracker.md` is the source of truth, not memory.

## The session formula

Every full day is four blocks, run in this order, never reordered. Input trains your ear before Output asks your mouth to produce anything, and the Exam drill only makes sense after you have used the material once. Swapping the order breaks that chain.

| Block | Time | What you do |
|---|---|---|
| Anki | 25 min | Clear the review queue for `tier1_wortliste.csv` (plus `tier2_fluency.csv` from day 32 — Tier 1 stays in review to the end; only the *new* cards move to Tier 2) before touching any new cards. |
| Input | 40 min | Listen or read from today's `content/dayNN.md` — Nicos Weg episode, shadowing, or the day's reading text. |
| Output | 40 min | Speak or write using today's Sprechen or Schreiben template. Produce something, even if it is wrong. |
| Exam drill | 30 min | Work the day's exam-format exercises from `content/dayNN.md`. |
| **Total** | **135 min** | — |

135 minutes is the full session. If you only have 90, do not compress all four blocks — see Bad days below instead.

## Bad days

A bad day is not a missed day. If you have 45 minutes, or you are too tired for a full session, this is what "still counted" looks like:

- **Block 1 — Anki (full 25 min).** Never skip the queue. A skipped queue on day N becomes a bigger queue on day N+1.
- **Block 3 — Output (~20 min).** Produce something out loud or on paper — the Sprechen or Schreiben task from today's `content/dayNN.md`. Block 2 (Input) is the block that gets dropped on a bad day, because Output is the module you cannot cram.

That is the minimum viable day: **Block 1 + Block 3** only, 45 minutes — the line every ordinary study day carries under "Minimum viable day". Two classes of day are the documented exception, and their own files say so: the mock days (31, 42, 44, 46, 48, 50), where there is no reduced version at all because a partial mock produces numbers you cannot compare — move the whole mock to your next full session instead; and day 49, whose reduced version keeps Block 1 but spends the remaining 20 minutes on a cut of its exam-day logistics check instead of Block 3. Days 34 and 37 keep Block 1 + Block 3 but scope the transcription down to the first 30 seconds. Everywhere else the rule holds as written, and where it holds it is explicitly allowed — mark it as a completed day in `progress_tracker.md`, not a missed one. What is not allowed is skipping the day entirely. A day with zero minutes is a missed day, and missed days are what Anki recovery below is for. If you can do the minimum viable day, do it — it is always better than nothing, and it is enough to keep the schedule intact.

## Anki recovery

Anki is the one part of this path that punishes silence. The rules below are the only correct response to a missed day — do not improvise.

**One day missed:** the next time you open Anki, you will see your normal backlog (yesterday's reviews that came due) plus today's new-card quota. Do both in the same session before you touch anything else. Do not split it across two sessions and do not skip the new cards to "catch up faster" — the backlog is reviews, the quota is new cards, and both are due today.

**Two consecutive days missed:** set new cards to 0 for the next three days. Clear the backlog first — reviews only, no new cards — until the queue is back under control, then resume the normal new-card quota for whichever day you are actually on (`README.md` §Day index gives the day-by-day slice, and today's `content/dayNN.md` header repeats it; the quota is 0 on days 29–31 and from day 42 anyway, so on those days this rule changes nothing).

**Never do either of these, no matter how far behind you are:**

- Never delete the deck.
- Never use Anki's "forget" option on the whole deck.

Both feel like a fresh start. Both throw away every interval you have already earned. A three-day backlog is recoverable in a few extra sessions; a forgotten deck is not — it puts every card back at zero, including the ones you already know cold. If the backlog feels too big to face, that is what the three-day new-cards-to-0 rule above is for. The Anki app itself is at https://apps.ankiweb.net/ if you need to reinstall or sync, but the deck file stays untouched either way.

## Mock papers and the Übungssatz supply

Goethe publishes only a small number of free official practice sets for Start Deutsch 1, and this path schedules more full mocks than there are unseen papers — days 31, 42, 44, 46, 48 and 50. Assume you will run out, and follow this rule on every mock day:

1. **Use each official set once**, on the first mock that calls for it. Never spend an unseen paper on anything but a full, timed mock.
2. **When no unseen set is left, re-sit one you did at least ten days ago.** Sooner than ten days and you are testing your memory of the paper, not your German.
3. **On a re-sit, score only the items you got wrong last time.** Treat every item you already got right as untimed review — read it, don't clock it.
4. **A re-sat paper inflates the score**, above all in Lesen and Schreiben, where you may remember the text or the prompt. Write "re-sit" next to that number in `progress_tracker.md` so you read it correctly later.
5. **Rest the 75+ booking gate on a first-sitting paper wherever one still remains.** Booking the real exam off an inflated re-sit total is the single mistake this rule exists to prevent.

The official practice page is https://www.goethe.de/en/spr/kup/prf/prf/sd1/ueb.html — check it before each mock in case Goethe has added a set.

## Weekly review (Sundays, 20 min inside Block 4)

On Sundays, spend the first 20 of Block 4's 30 minutes on review instead of the exam drill (the remaining 10 minutes still go to the drill — don't drop it entirely):

1. Update `progress_tracker.md` — mark the week's days, note anything you skipped or repeated.
2. Pull up your Anki stats and list the ten words you keep failing (highest lapse count, or the ten that "again" the most often).
3. Write those ten words out by hand, with article and plural where they apply — on paper, not typed. Handwriting is what makes them stick when review alone hasn't.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Reviews above 150/day | You added new cards too fast for the reviews to stay manageable | Drop new cards to 10/day until the backlog clears, then return to the day's normal quota |
| Can't hear where one word ends and the next begins | You've been shadowing silently, in your head | Shadow aloud, even quietly — silent shadowing doesn't train your mouth or your ear |
| You freeze when trying to speak | You've been rehearsing sentences in your head instead of producing them | Record yourself instead of rehearsing — a recording forces the sentence out, even imperfect |
| You keep forgetting der/die/das | You learned the noun bare, without its article | Re-add the card with article and plural in the front (e.g. "die Wohnung, -en"), never the noun alone |
| Anki backlog feels unrecoverable | Two or more days missed, no new cards added since | Follow Anki recovery above — new cards to 0 for three days, clear the backlog first, never delete or forget the deck |

If a problem isn't in this table, it's probably a pacing problem, not a method problem — check `README.md` §Day index and today's `content/dayNN.md` before changing what you're doing.
