# Day 33 — Design & Tries (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 284. Peeking Iterator — Medium
Link: https://leetcode.com/problems/peeking-iterator/

**Hint 1 (direction):** Think about what breaks if you call `next()` just to "look ahead," then want to call `next()` again to actually consume that same element — you'd lose it.
**Hint 2 (technique):** Wrap the given `Iterator` and cache a single lookahead value — no new heavyweight structure, just a one-slot buffer in front of the existing iterator.
**Hint 3 (structure):** Fields: the wrapped `Iterator`, a `hasPeeked bool`, and a `peekedValue`. `peek()`: if `!hasPeeked`, pull `peekedValue = iterator.next()` and set `hasPeeked = true`; return `peekedValue`. `next()`: if `hasPeeked`, clear the flag and return the cached value; otherwise call `iterator.next()` directly. `hasNext()`: `hasPeeked || iterator.hasNext()`.
**Hint 4 (implementation):** Never let the underlying iterator's `next()` fire twice for one peeked value — the classic bug is `peek()` advancing the underlying iterator without caching the result, so a following `next()` silently skips the peeked element.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** single-slot lookahead buffer wrapping an iterator.
- **Core idea:** `peek()` needs to expose the next value without consuming it, so pull one value from the wrapped iterator into a cache slot and only clear that slot when `next()` actually consumes it.
- **Algorithm:** 1) Maintain `hasPeeked`, `peekedVal`, and the wrapped iterator `it`. 2) `peek()`: if `!hasPeeked`, `peekedVal = it.next()`, `hasPeeked = true`; return `peekedVal`. 3) `next()`: if `hasPeeked`, `hasPeeked = false`, return `peekedVal`; else return `it.next()`. 4) `hasNext()`: return `hasPeeked || it.hasNext()`.
- **Complexity:** Time O(1) per call, Space O(1) extra.
- **Gotcha:** `hasNext()` must count a cached peeked value even when the underlying iterator is exhausted — otherwise you'll report false right after peeking at the last element.

</details>

---

## Problem 2: 341. Flatten Nested List Iterator — Medium
Link: https://leetcode.com/problems/flatten-nested-list-iterator/

**Hint 1 (direction):** Each entry in the input is either an integer or another arbitrarily-deep nested list — think about what order integers surface in if you always deal with whatever is at the "front" of what's left, unpacking only when you must.
**Hint 2 (technique):** Use an explicit stack (not recursion) holding the not-yet-flattened elements, unpacking a nested list lazily the moment you need to know what's next — an iterative-DFS flattening pattern.
**Hint 3 (structure):** Initialize the stack with the input list's elements pushed in reverse order (so the true first element ends up on top). `hasNext()`: while the top of the stack is a list (not an integer), pop it and push its children, also in reverse order, until the top is an integer or the stack is empty; return whether the stack is non-empty. `next()`: call `hasNext()` first, then pop and return the integer now on top.
**Hint 4 (implementation):** Pushing a nested list's children in reverse order is what keeps the original left-to-right order intact once you start popping — get the push order backwards and every nesting level comes out reversed.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** lazy stack-based flattening (iterative DFS).
- **Core idea:** Eagerly flattening the whole structure up front wastes work if the caller stops early; instead keep a stack of `NestedInteger` and unpack a list into its children only when `hasNext()` needs to determine what comes next.
- **Algorithm:** 1) Constructor: push `nestedList` elements onto the stack in reverse order. 2) `hasNext()`: while the stack is non-empty and its top is a list, pop it and push its children in reverse order; return `!stack.isEmpty()`. 3) `next()`: call `hasNext()` to guarantee the top is an integer, then pop and return its value.
- **Complexity:** Time O(1) amortized per `next()`/`hasNext()` call (each `NestedInteger` is pushed and popped exactly once). Space O(total nested elements) for the stack.
- **Gotcha:** Calling `next()` without routing through the same "unpack until an integer is on top" logic first will crash or misbehave on a list-typed top-of-stack — always normalize via `hasNext()` before popping in `next()`.

</details>
