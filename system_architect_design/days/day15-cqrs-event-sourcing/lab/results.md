# Day 15 Lab Results

## Fold vs projection (Steps 2–3)

| Order | `state` (fold, true) | `view` (projection, before fix) |
|-------|----------------------|---------------------------------|
| order-1 | status=____ | status=____ |
| order-2 | status=____ | status=____  ← mismatch = the bug |

- Why does the fold report the correct status while the projection is wrong? ______

## Replay reproduces state (Step 4)

- After `replay`, the view matched the prior `project` output? yes / no
- Read model is a pure function of the ____________ .

## Break-it / fix-it (Step 5)

- Bug: the projector never handled the ______________ event.
- Fix applied: __________________________________________________
- After fix + replay, order-2 view status: ____
- Why this is safer than a CRUD data-migration script: __________________

## Append-only guarantee (optional)

- `UPDATE events ...` result: ___________________________________________

## Takeaways

- Why `apply` (the fold) must be pure: ___________________________________
- Where eventual consistency enters, and the two escape hatches: __________
- When would I NOT event-source a domain: _______________________________
