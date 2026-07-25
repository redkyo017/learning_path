# The Design Method

Run this **every day, in order**, on every design. The method is the skill you
are building; the daily topics are just reps that exercise it. Do not shortcut a
step because the answer feels obvious — the discipline is the point.

## The 7 steps

### 1. Requirements
- **Functional:** what must it do? List the core use cases as verbs.
- **Scale & shape:** who uses it, how many, how often? Read/write ratio? Data
  size? Growth rate? Spiky or steady?
- Write down what is **explicitly out of scope**. Scope creep kills designs.

### 2. Constraints
- Budget, team size/skills, deadline.
- Latency SLA, availability target, compliance/data-residency.
- Existing stack you must live with. Build-vs-buy posture.

### 3. NFRs — pick the top 3 that dominate
From `nfr-checklist.md`, choose the **three** "-ilities" that this system lives
or dies by. You cannot optimize for all of them; naming the top 3 forces the
tradeoffs to surface. Everything downstream is judged against these three.

### 4. Options — generate ≥2 viable designs
**Never evaluate a single option.** A design with no alternative is a decision
you can't defend. Sketch at least two genuinely different approaches (e.g.
monolith vs services; SQL vs KV; sync vs async).

### 5. Tradeoffs — compare options against the top-3 NFRs
Build a table. Rows = options, columns = your top-3 NFRs (+ cost + complexity).
Be concrete: "p99 ~20ms" beats "fast".

| Option | NFR-1 | NFR-2 | NFR-3 | Cost | Complexity |
|--------|-------|-------|-------|------|------------|
| A      | …     | …     | …     | …    | …          |
| B      | …     | …     | …     | …    | …          |

### 6. Decision
Choose one. State **why this over the runner-up in a single sentence**. If you
can't, you haven't understood the tradeoff yet — go back to step 5. This
sentence becomes the heart of your ADR.

### 7. How it breaks (the red-team pass)
Attack your own design. Walk each failure scenario and answer "what happens?":
- **Load spike / 10× growth** — where's the first bottleneck?
- **A dependency is down or slow** — does it cascade?
- **Network partition** — which side wins, and is that correct?
- **A bad deploy** — blast radius? rollback path?
- **A hot key / hot partition** — does one tenant sink everyone?
- **Data loss / duplicate delivery** — is the system correct under retries?

If you can't answer a scenario, that's your next design task — not a detail to
"handle later."

## The two questions that separate architects from builders

1. **"When would I NOT use this?"** — For every pattern and technology, name the
   alternative and the condition under which the alternative wins. Anyone can say
   what a queue does; few can say when *not* to add one.
2. **"How does it break?"** — Anticipating failure before it happens is the whole
   job. The happy path is the easy 20%.

## Timeboxing

At 2–3 hrs/day, spend ~10 min on steps 1–3, ~30 min on 4–6, ~20 min on step 7.
The estimate should be to the **order of magnitude that changes the design**, not
to three significant figures.
