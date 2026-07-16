# Day 39 — Backtracking (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 78. Subsets — Medium
Link: https://leetcode.com/problems/subsets/

**Hint 1 (direction):** Every subset, including the empty one and the full set, counts as a valid answer — think about recording your partial solution at *every* level of the recursion, not just at the deepest one.
**Hint 2 (technique):** Backtrack over elements in order, where at each level the choice is binary: include the current element in the partial subset, or don't.
**Hint 3 (structure):** State = (current partial subset, start index into nums). Base case = none needed to stop recording — record the partial subset at the *start* of every call, then loop `i` from `start` to end: append nums[i], recurse with start=i+1, pop nums[i].
**Hint 4 (implementation):** Because you record on entry rather than only at a depth-n leaf, the "un-choose" (popping the last appended element after the recursive call) still has to happen for every iteration of the loop, not just the last one.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** "include/skip per position" backtracking, recording at every node (power-set enumeration).
- **State:** partial subset (array) + a `start` index marking which elements are still eligible to be added (never look backward, to avoid re-ordering the same subset).
- **Base case:** implicit — record the partial subset immediately on entering each call; recursion naturally stops when `start` exceeds the array length (loop just doesn't execute).
- **Pruning:** none needed — no duplicates in input, so every combination of positions from `start` onward is a distinct valid subset.
- **Complexity:** Time O(n · 2^n) (2^n subsets, O(n) to copy each), Space O(n) recursion depth + output.
- **Gotcha:** Recording a reference to the mutable partial-subset array instead of a copy — same bug family as Permutations, and just as fatal here since the array keeps changing after being "recorded."

</details>

---

## Problem 2: 90. Subsets II — Medium
Link: https://leetcode.com/problems/subsets-ii/

**Hint 1 (direction):** This is the same subset-generation shape as Problem 1, but the input can repeat values — think about what would make two different recursive branches produce the exact same subset, and how you'd notice that before it happens rather than de-duplicating the output afterward.
**Hint 2 (technique):** Same include/skip backtracking as Subsets, plus a duplicate-skipping guard: sort the array first so equal values sit adjacent, then at each level skip a candidate if it's equal to the previous *sibling* candidate already tried at this same recursion depth.
**Hint 3 (structure):** State = (partial subset, start index) as before, over a *sorted* nums. Record the partial subset on entry. Loop `i` from `start` to end: if `i > start and nums[i] == nums[i-1]`, skip this `i` entirely (continue) — that's the sibling-duplicate guard, not a global "used value" check; otherwise choose nums[i], recurse with start=i+1, un-choose.
**Hint 4 (implementation):** The skip condition must be `i > start`, not `i > 0` — you're allowed to reuse an equal value going *deeper* (as the next chosen element after already picking one copy), you're only forbidden from picking the *same* value twice as alternatives at the *same* level.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** subset backtracking + sort-first + skip-equal-sibling duplicate guard.
- **State:** partial subset + start index into the sorted nums array.
- **Base case:** implicit, same as Subsets — record on entry to every call.
- **Pruning:** sort nums, then at each level skip any index `i > start` where `nums[i] == nums[i-1]`; this collapses the branches that would otherwise generate byte-identical subsets from different copies of the same value.
- **Complexity:** Time O(n · 2^n) worst case (still bounded by the power set, less in practice with duplicates), Space O(n) recursion depth + output.
- **Gotcha:** Confusing "skip if equal to previous element in the array" with "skip if equal to previous *sibling in this loop*" — the guard is `i > start`, checked freshly at every recursion level, not a single global dedup pass.

</details>
