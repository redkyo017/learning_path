# Day 17 — DP Fundamentals (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 70. Climbing Stairs — Easy
Link: https://leetcode.com/problems/climbing-stairs/

**Hint 1 (direction):** Think about the last move you make to reach step n — what are the only two ways you could have arrived there, and how does that connect the answer for n to the answers for smaller n?
**Hint 2 (technique):** This is 1D dynamic programming — specifically the same recurrence shape as the Fibonacci sequence.
**Hint 3 (structure):** Let dp[i] = number of distinct ways to reach step i. Transition: dp[i] = dp[i-1] + dp[i-2], since the last move landing on i was either a single step from i-1 or a double step from i-2.
**Hint 4 (implementation):** Base cases: dp[1] = 1, dp[2] = 2. Size the array n+1 so index n is directly usable, and note you only ever need the last two values, so O(1) space is possible.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Fibonacci-style 1D DP
- **State:** dp[i] = number of ways to reach step i
- **Transition:** dp[i] = dp[i-1] + dp[i-2]
- **Base case:** dp[1] = 1, dp[2] = 2
- **Complexity:** Time O(n), Space O(1) with two rolling variables
- **Gotcha:** Off-by-one on whether dp[0] means "0 ways" or "1 way (do nothing, already there)" — pick a convention and stay consistent with your base cases.

</details>

---

## Problem 2: 118. Pascal's Triangle — Easy
Link: https://leetcode.com/problems/pascals-triangle/

**Hint 1 (direction):** Each entry in a row depends only on two specific entries in the row directly above it — work out which two before writing anything.
**Hint 2 (technique):** This is 2D DP where the recurrence is exactly Pascal's combinatorial identity C(n,k) = C(n-1,k-1) + C(n-1,k), built row by row (bottom-up, no recursion needed).
**Hint 3 (structure):** State: dp[i][j] = value at row i, position j. Transition: dp[i][j] = dp[i-1][j-1] + dp[i-1][j], treating a missing neighbor (j-1 < 0 or j past the row's end) as 0.
**Hint 4 (implementation):** The first and last element of every row is always 1 — handle those as an explicit per-row base case rather than indexing out of bounds; row i (0-indexed) has i+1 elements.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Row-by-row 2D DP with edge boundaries
- **State:** dp[i][j] = value at row i, column j
- **Transition:** dp[i][j] = dp[i-1][j-1] + dp[i-1][j] (0 if out of range)
- **Base case:** dp[i][0] = dp[i][i] = 1 for every row i
- **Complexity:** Time O(numRows^2), Space O(numRows^2) for the full output
- **Gotcha:** Building a row in place from the previous row's slice can corrupt values you still need to read — construct each new row as a fresh slice.

</details>

---

## Problem 3: 198. House Robber — Medium
Link: https://leetcode.com/problems/house-robber/

**Hint 1 (direction):** At each house you face a binary decision, and that decision has a knock-on effect on which houses are even choosable next — think about what you gain versus what you're forced to give up.
**Hint 2 (technique):** 1D DP with a take/skip decision at each index.
**Hint 3 (structure):** Let dp[i] = max money obtainable from houses 0..i. Transition: dp[i] = max(dp[i-1], dp[i-2] + nums[i]) — either skip house i (keep dp[i-1]) or rob it (dp[i-2] plus its value, since house i-1 must then be left alone).
**Hint 4 (implementation):** Base cases: dp[0] = nums[0], dp[1] = max(nums[0], nums[1]). Guard arrays of length 1 or 2 before ever indexing i-2.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Take/skip 1D DP
- **State:** dp[i] = max money robbable from the first i+1 houses
- **Transition:** dp[i] = max(dp[i-1], dp[i-2] + nums[i])
- **Base case:** dp[0] = nums[0], dp[1] = max(nums[0], nums[1])
- **Complexity:** Time O(n), Space O(1) with two rolling variables
- **Gotcha:** Forgetting that "rob house i" adds nums[i] to dp[i-2], not dp[i-1] — adjacent houses can never both be robbed.

</details>
