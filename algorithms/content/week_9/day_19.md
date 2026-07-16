# Day 19 — DP Fundamentals (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 63. Unique Paths II — Medium
Link: https://leetcode.com/problems/unique-paths-ii/

**Hint 1 (direction):** Same grid-walking setup as before, but now some cells are simply forbidden to stand on at all — think about what that does to both the recurrence and the very first row/column.
**Hint 2 (technique):** Grid DP identical to Unique Paths, with obstacles forcing a dp value of 0 wherever they occur.
**Hint 3 (structure):** State: dp[i][j] = number of paths from (0,0) to (i,j). Transition: if grid[i][j] is an obstacle, dp[i][j] = 0; otherwise dp[i][j] = dp[i-1][j] + dp[i][j-1] (treating out-of-bounds neighbors as 0).
**Hint 4 (implementation):** The first row/column is no longer automatically all 1s — an obstacle anywhere in row 0 or column 0 makes every cell after it in that line unreachable (0), not just the obstacle cell itself.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Grid path-counting DP with blocked cells
- **State:** dp[i][j] = number of paths from (0,0) to (i,j) avoiding obstacles
- **Transition:** dp[i][j] = 0 if obstacle, else dp[i-1][j] + dp[i][j-1]
- **Base case:** dp[0][0] = 1 if not an obstacle, else 0; propagate 0 forward along the first row/column once an obstacle is hit
- **Complexity:** Time O(m*n), Space O(n) with a rolling row
- **Gotcha:** An obstacle early in the first row or column zeroes out everything downstream of it in that line, not just the single blocked cell.

</details>

---

## Problem 2: 64. Minimum Path Sum — Medium
Link: https://leetcode.com/problems/minimum-path-sum/

**Hint 1 (direction):** Same movement rules as the path-counting grid problems, but now you're optimizing a cost instead of counting routes — what's the cheapest way to have arrived at each cell?
**Hint 2 (technique):** 2D grid DP with a min-cost transition instead of a sum-of-counts transition.
**Hint 3 (structure):** State: dp[i][j] = minimum path sum to reach (i,j). Transition: dp[i][j] = grid[i][j] + min(dp[i-1][j], dp[i][j-1]).
**Hint 4 (implementation):** Base case: dp[0][0] = grid[0][0]. Row 0 and column 0 each have only one possible incoming direction, so dp[0][j] = dp[0][j-1] + grid[0][j] and dp[i][0] = dp[i-1][0] + grid[i][0] — don't apply the min() formula there, since one side doesn't exist.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Grid min-cost DP
- **State:** dp[i][j] = minimum path sum from (0,0) to (i,j)
- **Transition:** dp[i][j] = grid[i][j] + min(dp[i-1][j], dp[i][j-1])
- **Base case:** dp[0][0] = grid[0][0]; first row/column accumulate along the single available direction
- **Complexity:** Time O(m*n), Space O(n) with a rolling row (O(1) extra if mutating the grid in place)
- **Gotcha:** Applying min(dp[i-1][j], dp[i][j-1]) on the boundary row/column where one term doesn't exist yet — treat the missing neighbor as infinity or handle boundaries in a separate pass.

</details>

---

## Problem 3: 91. Decode Ways — Medium
Link: https://leetcode.com/problems/decode-ways/

**Hint 1 (direction):** At each position in the string, ask how many distinct ways of decoding everything up to here could be extended by looking at just the current digit, and the current digit paired with the previous one.
**Hint 2 (technique):** 1D DP over string prefixes, similar shape to Climbing Stairs but with a validity check gating each of the two transitions.
**Hint 3 (structure):** State: dp[i] = number of ways to decode the first i characters. Transition: dp[i] += dp[i-1] if s[i-1] != '0' (single-digit decode valid); dp[i] += dp[i-2] if the two-character substring s[i-2..i-1] forms a valid number between 10 and 26 (two-digit decode valid).
**Hint 4 (implementation):** Size the array n+1 with dp[0] = 1 (empty prefix has exactly one way: decode nothing) as the base case; a '0' that can't validly pair with the previous digit should contribute 0 to dp[i], not crash your indexing.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** String-prefix 1D DP with two conditional transitions
- **State:** dp[i] = number of ways to decode the prefix of length i
- **Transition:** dp[i] = dp[i-1] (if s[i-1] != '0') + dp[i-2] (if 10 <= int(s[i-2:i]) <= 26)
- **Base case:** dp[0] = 1; dp[1] = 1 if s[0] != '0' else 0
- **Complexity:** Time O(n), Space O(1) with two rolling variables
- **Gotcha:** A '0' can never stand alone — it's only valid as the second digit of "10" or "20"; missing this makes dp incorrectly count decodings through a lone zero.

</details>
