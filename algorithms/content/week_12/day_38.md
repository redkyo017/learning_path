# Day 38 — Backtracking (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 17. Letter Combinations of a Phone Number — Medium
Link: https://leetcode.com/problems/letter-combinations-of-a-phone-number/

**Hint 1 (direction):** Each digit expands into a small fixed set of letters, and the final answer is every way of picking one letter per digit, in digit order — think about building one candidate string digit by digit rather than trying to generate all strings at once.
**Hint 2 (technique):** Backtrack over digit *positions*: at each recursive level, the "choice" is which letter (from that digit's mapped set) to append next.
**Hint 3 (structure):** State = (current partial string, index into the digit string). Base case = index reaches the end of digits -> record a copy of the partial string. Loop = for each letter mapped to `digits[index]`, append it, recurse on `index+1`, then remove it.
**Hint 4 (implementation):** Handle the empty-input edge case explicitly (return no combinations, not `[""]`), and if you're building the string with a mutable buffer, the "un-choose" is popping the last appended character before trying the next letter in the loop.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** fixed-depth backtracking over a small per-level choice set (Cartesian product via recursion).
- **State:** partial string built so far + current digit index; remaining choices = letters mapped to the digit at that index.
- **Base case:** index == len(digits) -> append the completed string to results.
- **Pruning:** none needed — every leaf at full depth is a valid answer, so this is closer to a controlled Cartesian-product generation than a pruned search.
- **Complexity:** Time O(4^n · n) where n = len(digits) (up to 4 letters per digit, n characters copied per leaf), Space O(n) recursion depth plus output.
- **Gotcha:** Empty `digits` string should return an empty result list, not a list containing an empty string — an easy off-by-one on the base case.

</details>

---

## Problem 2: 46. Permutations — Medium
Link: https://leetcode.com/problems/permutations/

**Hint 1 (direction):** Every element must appear exactly once in every output, in every possible order — think about what "remaining, unused elements" you'd need to track as you build one ordering at a time.
**Hint 2 (technique):** Backtrack by choosing, at each level, one not-yet-used element to place next; the choice set shrinks by exactly one element per level.
**Hint 3 (structure):** State = (current partial permutation, a used-marker per index or a "remaining" list). Base case = partial permutation length == n -> record a copy. Loop = for each index i not yet used: mark used, append nums[i] to partial, recurse, unmark used, remove nums[i] from partial.
**Hint 4 (implementation):** The un-choose step people skip is un-marking the `used[i]` flag (or re-inserting the removed element) *after* the recursive call returns — forgetting it means later sibling branches see an incorrectly-shrunk pool.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** full-permutation backtracking with a used-set.
- **State:** partial permutation (array) + boolean `used[]` array of length n tracking which indices are already placed.
- **Base case:** len(partial) == n -> append a copy of partial to results.
- **Pruning:** none beyond skipping already-used indices — all n! leaves are valid outputs (no duplicates in input here).
- **Complexity:** Time O(n · n!) (n! permutations, O(n) to copy each), Space O(n) recursion depth + O(n) used array.
- **Gotcha:** Appending the *live* partial-solution reference instead of a copy to the results list — since the same backing array/slice keeps mutating, all recorded "answers" end up pointing at the same final (wrong) state.

</details>
