# Drill — decision or detail?

The core Day-1 skill: telling a one-way door (expensive to reverse, others must
agree → deserves an ADR + C4) from a two-way door (cheap, local → just build it).
See `content/day01.md` "The decision / tradeoffs".

## Part A — warm-up (answers in `content/day01.md` Exercise 1)
Classify each, one line of reasoning: (a) PostgreSQL vs DynamoDB for the primary
store; (b) `chi` vs `gorilla/mux` router; (c) async vs inline order-confirmation
email; (d) JSON field-naming convention in an internal API; (e) 3 AZs vs 1.

## Part B — from YOUR system (the real rep)
List **10 choices** made in the system you reverse-engineered. For each, mark D
(decision) or d (detail) and give the reason using the two tests:
- **Reversibility:** how expensive to undo? (local refactor vs project)
- **Audience:** does anyone outside the author's module have to agree / build against it?

| # | The choice | D / d | Why (reversibility + audience) |
|---|------------|-------|--------------------------------|
| 1 |            |       |                                |
| 2 |            |       |                                |
| 3 |            |       |                                |
| 4 |            |       |                                |
| 5 |            |       |                                |
| 6 |            |       |                                |
| 7 |            |       |                                |
| 8 |            |       |                                |
| 9 |            |       |                                |
| 10|            |       |                                |

## Reflect (put this in results.md)
- How many of your **decisions** were actually written down anywhere before today?
- Find one choice whose classification *flips* with context (like (d) above: a naming
  convention is a detail internally, a contract once published). What flips it?
- Which one decision, if you'd documented it at the time, would have saved a later
  argument or incident?
