# Day 14 Lab Results

## Fan-out (Step 2)

| Group | Records received | Distinct offsets? |
|-------|------------------|-------------------|
| inventory | ____ | yes / no |
| analytics | ____ | yes / no |

- Both groups received every event because: _______________________________

## Replay (Step 3)

- `--reset-offsets --to-earliest` on `analytics`: count went from ____ back to ____ and re-climbed to ____.
- `inventory` was affected? yes / no — why: ______________________________
- What must be true of topic retention for this to work: _________________

## Break-it: poison message (Step 4)

- Naive consumer behavior on the malformed record: ________________________
- On restart it: ____________________________ (crash loop? / skipped?)
- Blast radius (what else stopped being processed): _______________________
- `--describe` LAG on the stuck partition: ____

## Fix: dead-letter (Step 5)

- With `-dlq`, the bad record went to: __________ and processing __________.
- DLQ headers captured: origin offset ____, error: _______________________

## Takeaways

- Unit of ordering AND parallelism: __________
- Notification vs ECST — which did I choose and why: _____________________
- When would I NOT use events: ___________________________________________
