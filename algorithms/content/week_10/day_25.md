# Day 25 — Advanced Dynamic Programming (Phase 2)

Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 115. Distinct Subsequences — Hard
Link: https://leetcode.com/problems/distinct-subsequences/

**Hint 1 (direction):** Think recursively about matching the tail of s (source) against the tail of t (target): when the last characters match, you have a choice — use that character or skip it — and both choices might contribute valid ways.
**Hint 2 (technique):** Two-sequence counting DP (not boolean reachability like yesterday — you're summing counts, not OR-ing booleans).
**Hint 3 (structure):** dp[i][j] = number of distinct subsequences of s[0:i] equal to t[0:j]. dp[i][j] = dp[i-1][j] + (s[i-1]==t[j-1] ? dp[i-1][j-1] : 0).
**Hint 4 (implementation):** dp[i][0] = 1 for every i (matching an empty target has exactly one way: pick nothing); dp[0][j]=0 for j>0. On a character match you must ADD dp[i-1][j] (skip this s character) on top of dp[i-1][j-1] (use it) — it is not an either/or choice.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Two-sequence counting DP
- **State:** dp[i][j] = number of distinct subsequences of s[:i] equal to t[:j]
- **Transition:** dp[i][j] = dp[i-1][j] + (s[i-1]==t[j-1] ? dp[i-1][j-1] : 0)
- **Base case:** dp[i][0] = 1 for all i; dp[0][j] = 0 for j > 0
- **Complexity:** Time O(m·n), Space O(n) with a rolling row
- **Gotcha:** the most common bug is treating the match case as exclusive (only adding dp[i-1][j-1]) instead of additive with the skip case — you always add dp[i-1][j] regardless of match.

</details>

---

## Problem 2: 120. Triangle — Medium
Link: https://leetcode.com/problems/triangle/

**Hint 1 (direction):** Instead of tracking the best path from the top down, think about the cheapest path from each cell to the bottom — if you already knew that for the row below, could you compute it for the row above in one pass?
**Hint 2 (technique):** Single-sequence bottom-up DP (in-place row reduction) — a lighter warm-up than yesterday's two-sequence problems, no extra dimension needed here.
**Hint 3 (structure):** Let dp[j] be the min path sum from cell (i,j) to the bottom. Process rows from the second-to-last up to the top: dp[j] = triangle[i][j] + min(dp[j], dp[j+1]).
**Hint 4 (implementation):** Initialize dp as a copy of the last row. Loop i from n-2 down to 0, and for each row loop j from 0 to i (row i has i+1 elements) — going the other direction (top-down) forces you to handle the two triangle edges (j=0 and j=i) as special cases, which bottom-up avoids entirely.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Single-sequence bottom-up DP over a triangular grid
- **State:** dp[j] = min path sum from cell (i,j) to the bottom row, reused in place as i decreases
- **Transition:** dp[j] = triangle[i][j] + min(dp[j], dp[j+1])
- **Base case:** dp initialized to the values of the last row
- **Complexity:** Time O(n²), Space O(n) (O(1) extra if you overwrite the triangle rows in place)
- **Gotcha:** top-down traversal needs explicit edge handling at j=0 and j=i each row; bottom-up sidesteps that, so prefer it even though both are valid.

</details>
