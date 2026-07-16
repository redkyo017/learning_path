# Day 40 — Backtracking (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 39. Combination Sum — Medium
Link: https://leetcode.com/problems/combination-sum/

**Hint 1 (direction):** You're picking numbers (with repeats allowed) that add up exactly to a target — think about what a running total tells you at each step: whether to keep exploring, stop and record, or stop and discard.
**Hint 2 (technique):** Backtrack over candidates where each level's choice is "which candidate to add next," and the same candidate can be chosen again immediately after itself (unlimited reuse).
**Hint 3 (structure):** State = (partial combination, running sum, start index into candidates). Base case = sum == target -> record; sum > target -> return early (invalid, prune). Loop `i` from `start` to end: choose candidates[i], recurse with start=i (not i+1, since reuse is allowed) and sum+candidates[i], un-choose.
**Hint 4 (implementation):** Sort candidates first so you can `break` out of the loop the moment `candidates[i] > target - sum` — since everything after is even larger, this prunes whole subtrees instead of visiting each one only to reject it inside the recursive call.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** backtracking with unlimited reuse per element ("combination with repetition"), sum-bounded pruning.
- **State:** partial combination + running sum + start index (recursing with `start=i` again, since an element can be reused).
- **Base case:** sum == target -> record copy of partial; sum > target -> return without recording (invalid branch).
- **Pruning:** sort candidates ascending, then break the loop as soon as `candidates[i] + sum > target` — no need to try larger candidates once one is already too big.
- **Complexity:** Time roughly O(n^(target/min_candidate)) in the worst case (exponential, bounded by target and smallest candidate), Space O(target/min_candidate) recursion depth + output.
- **Gotcha:** Passing `start=i+1` instead of `start=i` on the recursive call — that's the Combination Sum II move (no reuse); here it silently forbids reusing the same value and gives wrong (incomplete) answers.

</details>

---

## Problem 2: 40. Combination Sum II — Medium
Link: https://leetcode.com/problems/combination-sum-ii/

**Hint 1 (direction):** Same sum-to-target shape as Problem 1, but now each number can only be used as many times as it appears in the input, and the input may contain duplicate values — think about what changes in your recursive "which index can I pick next" logic when reuse is no longer allowed.
**Hint 2 (technique):** Backtrack exactly like Combination Sum, except each level advances the start index *past* the element just chosen (no self-reuse), plus a sort-first + skip-equal-sibling guard to avoid two different index-paths producing the same multiset.
**Hint 3 (structure):** State = (partial combination, running sum, start index) over *sorted* candidates. Base case = sum == target -> record; sum > target -> return early. Loop `i` from `start` to end: if `i > start and candidates[i] == candidates[i-1]`, skip (sibling-duplicate guard); else choose candidates[i], recurse with start=i+1 and sum+candidates[i], un-choose.
**Hint 4 (implementation):** The duplicate guard (`i > start` check) and the "advance start to i+1" reuse rule are two separate fixes solving two separate problems — mixing them up (e.g. using `i > 0` for the duplicate check) either under- or over-prunes; also keep the same `break` early-exit from Problem 1 once `candidates[i] + sum > target`.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** backtracking with no-reuse-per-index + sort-first + skip-equal-sibling duplicate guard, sum-bounded pruning.
- **State:** partial combination + running sum + start index into sorted candidates; recursing with `start=i+1` since each array position can be used at most once.
- **Base case:** sum == target -> record copy; sum > target -> return without recording.
- **Pruning:** sort ascending, `break` once `candidates[i] + sum > target`; separately, skip `i > start` where `candidates[i] == candidates[i-1]` to avoid duplicate combinations from repeated values.
- **Complexity:** Time O(2^n) worst case (each element in/out), Space O(n) recursion depth + output.
- **Gotcha:** Forgetting that duplicate *values* here represent genuinely repeated array elements (not a single reusable value) — the fix is skip-if-same-as-previous-sibling at each level, not deduping the input before search (which would silently drop needed copies).

</details>
