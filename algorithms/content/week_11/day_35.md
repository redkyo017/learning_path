# Day 35 — Design & Tries (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 295. Find Median from Data Stream — Hard
Link: https://leetcode.com/problems/find-median-from-data-stream/

**Hint 1 (direction):** Ask what `findMedian` actually needs from the whole stream — not the full sorted order, just fast access to the one or two values sitting right at the boundary between the lower and upper halves of everything seen so far.
**Hint 2 (technique):** Maintain two heaps: a max-heap holding the smaller (lower) half of the numbers seen so far, and a min-heap holding the larger (upper) half.
**Hint 3 (structure):** `lower` = max-heap, root is the largest value in the small half. `upper` = min-heap, root is the smallest value in the large half. Invariant: `len(lower) == len(upper)` or `len(lower) == len(upper) + 1`. `addNum` costs O(log n) (heap push/pop plus rebalancing); `findMedian` costs O(1) (just peek at the root(s)).
**Hint 4 (implementation):** After pushing a new number into one heap, always rebalance by moving that heap's root across if the size invariant is violated (Go's `container/heap` gives you `Push`/`Pop` as the O(log n) primitives — don't hand-roll raw slice inserts). Decide up front which heap keeps the extra element when the total count is odd, so `findMedian`'s even/odd branch stays consistent call after call.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** two-heap balanced partition (max-heap / min-heap).
- **Core idea:** Keeping the lower half in a max-heap and the upper half in a min-heap means the two values nearest the median (the largest of the lower half, the smallest of the upper half) always sit at the roots, giving O(1) median lookup at the cost of O(log n) insert-time rebalancing.
- **Algorithm:** `addNum(num)`: 1) push `num` onto `lower` (max-heap). 2) pop `lower`'s root and push it onto `upper`, so everything moved across is guaranteed ≤ everything already in `upper`. 3) if `len(upper) > len(lower)`, pop `upper`'s root and push it back onto `lower` to restore the size balance (`lower` ends with equal or one more element than `upper`). `findMedian()`: if `len(lower) > len(upper)`, return `lower`'s root (as float); else return the average of `lower`'s root and `upper`'s root.
- **Complexity:** Time O(log n) for `addNum`, O(1) for `findMedian`. Space O(n).
- **Gotcha:** Off-by-one drift in the size invariant is the #1 bug source — pick one consistent rule (e.g. "`lower` always holds the extra element when the count is odd") and enforce it on every single `addNum` call, not only when sizes "look" unbalanced.

</details>
