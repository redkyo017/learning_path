# Day 17 — Phase 3 interview rep (45 min, timed)

**Problem 3 in `reference/interview-problems.md`:** *Ride-sharing dispatch OR news
feed.* Pick one and design the core.

## How to run it
1. Set a timer for **45 minutes**. Whiteboard or markdown — your choice.
2. Run `reference/design-method.md` **in order**, out loud or in writing:
   requirements + scale numbers → constraints → top-3 NFRs → ≥2 options →
   tradeoff table → decision (one-sentence "why this over the runner-up") →
   how-it-breaks (red-team).
3. Produce at least a **C2 container diagram** and one **capacity estimate that
   drives a decision** (e.g. the fan-out cost that sets the push/pull threshold,
   or the driver-location write rate that forces an async lossy path).
4. Bring in what this phase drilled where it fits: service boundaries (Day 12),
   sync vs async + events (Days 13–14), CQRS where justified (Day 15), saga +
   outbox for money/state changes (Day 16), and a safe **rollout** story (today).

## Self-grade (score /10) — from the interview bank
- Requirements + scale numbers stated (2)
- Named top-3 NFRs and designed to them (2)
- ≥2 options compared, not one (1)
- A capacity estimate that drove a decision (1)
- Data model + storage choice justified (1)
- Failure modes / red-team pass (2)
- One clear "why this over the alternative" per key decision (1)

## Then check yourself
The **graduated hints and a solution sketch are in `reference/interview-problems.md`
under Problem 3** (feed: the fan-out-on-write vs -on-read vs hybrid tradeoff *is*
the whole problem; ride: geo-indexing + a trip state machine + a high-rate,
lossy-OK driver-location path). **Try the full 45 minutes before you look.** Then
compare: did you run the method in order, and did you defend the tradeoff — not
match the sketch word-for-word?

Save your attempt (design + score + the questions you couldn't answer confidently)
in `design/` and log any gaps into `BACKLOG.md`.
