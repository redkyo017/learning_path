# Day 41 — Backtracking (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 47. Permutations II — Medium
Link: https://leetcode.com/problems/permutations-ii/

**Hint 1 (direction):** Same "place one unused element per level" shape as Permutations, but now the input has duplicate values — think about what makes two different index-choices produce the identical permutation, and how to notice that at the moment of choosing rather than after the fact.
**Hint 2 (technique):** Backtrack with a `used[]` array exactly like Permutations, plus a sort-first + skip-equal-sibling guard: at each level, don't pick an index whose value equals a value you already tried (and finished) at this same level.
**Hint 3 (structure):** State = (partial permutation, `used[]` boolean array) over *sorted* nums. Base case = len(partial) == n -> record copy. Loop over all indices i: skip if `used[i]`; skip if `i > 0 and nums[i] == nums[i-1] and !used[i-1]` (sibling-duplicate guard); else mark used[i], append, recurse, un-mark, remove.
**Hint 4 (implementation):** The guard condition is `!used[i-1]`, not `used[i-1]` — `!used[i-1]` means "the previous equal value was already un-chosen and we're back at this level trying its sibling," which is exactly the redundant branch to skip; get the negation backwards and you either miss valid permutations or don't dedupe at all.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** full-permutation backtracking with used-set + sort-first + skip-equal-sibling duplicate guard.
- **State:** partial permutation + `used[]` boolean array over sorted nums.
- **Base case:** len(partial) == n -> record copy of partial.
- **Pruning:** sort nums; at each level, only allow the *first* not-yet-used occurrence among equal values to be chosen next (guard: skip i if `nums[i]==nums[i-1] and !used[i-1]`), collapsing branches that would otherwise produce identical permutations.
- **Complexity:** Time O(n · n!) worst case (bounded above by distinct-input case, less with duplicates), Space O(n) recursion depth + used array.
- **Gotcha:** Using `used[i-1]` instead of `!used[i-1]` in the guard is the single most common mistake on this exact problem — trace through `[1,1,2]` by hand if the condition feels off.

</details>

---

## Problem 2: 131. Palindrome Partitioning — Medium
Link: https://leetcode.com/problems/palindrome-partitioning/

**Hint 1 (direction):** You need every way to cut the string into pieces where every piece is a palindrome — think about choosing where the *next cut* goes, one prefix at a time, rather than trying to place all cuts simultaneously.
**Hint 2 (technique):** Backtrack over cut positions: at each level, the choice is how long the *next* palindromic prefix (starting from your current position) should be; only recurse into a candidate prefix if it actually is a palindrome, i.e. check-then-recurse (validity check before descending, not after).
**Hint 3 (structure):** State = (partial list of pieces so far, start index into s). Base case = start == len(s) -> record a copy of the partial list. Loop `end` from `start+1` to len(s): let piece = s[start:end]; if piece is a palindrome, append piece to partial, recurse with start=end, then remove piece (un-choose); if not a palindrome, skip this `end` (still try longer/shorter ends — don't return the whole call).
**Hint 4 (implementation):** Don't return out of the function the moment one `end` fails the palindrome check — just `continue` the loop to try the next `end`; the un-choose step people forget here is popping the just-appended piece off the partial list before trying the next candidate length.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** backtracking over cut points with a check-before-descend validity gate (partition enumeration).
- **State:** partial list of palindromic pieces so far + start index marking the unpartitioned remainder of s.
- **Base case:** start == len(s) -> every character has been assigned to some piece; record a copy of the partial list.
- **Pruning:** only recurse into a candidate piece `s[start:end]` if it is already verified to be a palindrome — this avoids exploring any subtree rooted at an invalid piece, which is far cheaper than building a full partition and checking it at the end.
- **Complexity:** Time O(n · 2^n) worst case (2^n possible partitions, O(n) palindrome check each — can be reduced to O(1) checks with an O(n^2) precomputed palindrome table), Space O(n) recursion depth + output.
- **Gotcha:** Recomputing the palindrome check naively for every substring gives O(n) per check inside an already-exponential search; for larger inputs, precompute an `isPalin[i][j]` table via DP first so each check is O(1).

</details>
