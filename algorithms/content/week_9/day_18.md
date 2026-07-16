# Day 18 — DP Fundamentals (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 746. Min Cost Climbing Stairs — Easy
Link: https://leetcode.com/problems/min-cost-climbing-stairs/

**Hint 1 (direction):** You may start from step 0 or step 1 for free, and the "top" is one step past the last index — think about what it costs to arrive at each step from the two steps that could precede it.
**Hint 2 (technique):** 1D bottom-up DP, a minimum-cost variant of the climbing-stairs recurrence.
**Hint 3 (structure):** Let dp[i] = minimum cost to reach step i (reaching i means every step stepped on so far is paid for, but not the cost of leaving i). Transition: dp[i] = min(dp[i-1] + cost[i-1], dp[i-2] + cost[i-2]).
**Hint 4 (implementation):** Size dp as n+1 (indices 0..n) so dp[n] represents reaching just past the last stair — the answer is dp[n]. Base case: dp[0] = dp[1] = 0, since both are valid free starting points.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Minimum-cost 1D DP
- **State:** dp[i] = min cost to reach step i, where the "top" is index n (one past the last stair)
- **Transition:** dp[i] = min(dp[i-1] + cost[i-1], dp[i-2] + cost[i-2])
- **Base case:** dp[0] = 0, dp[1] = 0
- **Complexity:** Time O(n), Space O(1)
- **Gotcha:** Confusing "cost to reach step i" with "cost including leaving step i" — cost[i] is paid when stepping off i, not when arriving at it.

</details>

---

## Problem 2: 55. Jump Game — Medium
Link: https://leetcode.com/problems/jump-game/

**Hint 1 (direction):** Before reaching for a full table, ask whether you truly need the answer at every index individually, or just the single furthest point you've ever been able to reach so far.
**Hint 2 (technique):** This can be framed as reachability DP, but the standard efficient solution is a greedy scan tracking the furthest reachable index — notice that each dp[i] only ever needs the running max, not individual past values, which is why the DP collapses to greedy.
**Hint 3 (structure):** DP framing: dp[i] = true if index i is reachable, transition dp[i] = true if some j < i has dp[j] true and j + nums[j] >= i. Greedy simplification: maintain furthest = max(furthest, i + nums[i]) while scanning, and fail as soon as i > furthest.
**Hint 4 (implementation):** Iterate left to right; the instant you find an index i with i > furthest (current index is unreachable), return false immediately rather than scanning further.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Reachability DP collapsed into a greedy furthest-reach scan
- **State:** furthest = max index reachable using positions processed so far (compresses dp[i]=true/false into one running value)
- **Transition:** furthest = max(furthest, i + nums[i]) for each i that is itself reachable (i <= furthest)
- **Base case:** furthest = 0 before the loop starts
- **Complexity:** Time O(n), Space O(1)
- **Gotcha:** Updating furthest using nums[i] even when i itself is unreachable (i > furthest) gives a wrong, over-optimistic result — check reachability of i before using it.

</details>

---

## Problem 3: 62. Unique Paths — Medium
Link: https://leetcode.com/problems/unique-paths/

**Hint 1 (direction):** Every cell in the grid can only be entered from two specific neighboring directions — think about what determines how many distinct routes lead into a given cell.
**Hint 2 (technique):** 2D grid DP (a closed-form combinatorics formula also exists, but build the DP recurrence first).
**Hint 3 (structure):** State: dp[i][j] = number of distinct paths from (0,0) to cell (i,j). Transition: dp[i][j] = dp[i-1][j] + dp[i][j-1], since a cell can only be entered from above or from the left.
**Hint 4 (implementation):** Base case: every cell in row 0 and column 0 has exactly 1 path (dp[0][j] = dp[i][0] = 1), since there is only one way to walk straight along an edge.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Grid path-counting DP
- **State:** dp[i][j] = number of distinct paths from (0,0) to (i,j)
- **Transition:** dp[i][j] = dp[i-1][j] + dp[i][j-1]
- **Base case:** dp[0][j] = 1 for all j; dp[i][0] = 1 for all i
- **Complexity:** Time O(m*n), Space O(n) with a rolling 1D row
- **Gotcha:** m and n (rows vs. columns) are easy to swap — confirm which loop bound corresponds to which dimension before indexing.

</details>
