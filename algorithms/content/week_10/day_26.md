# Day 26 — Advanced Dynamic Programming (Phase 2)

Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 221. Maximal Square — Medium
Link: https://leetcode.com/problems/maximal-square/

**Hint 1 (direction):** For a cell that holds a '1', what actually limits how big a square of all-1s can have that cell as its bottom-right corner? Look at what its three neighbors (above, left, and diagonal up-left) each allow.
**Hint 2 (technique):** Grid DP where the value at each cell isn't a sum or boolean but a size — the side length of the largest square ending there.
**Hint 3 (structure):** dp[i][j] = 0 if matrix[i][j]=='0'; otherwise dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]). Track the running max of dp[i][j] as you fill the table.
**Hint 4 (implementation):** Pad the dp table to size (m+1) x (n+1) with an extra all-zero row and column so row 0 / column 0 of the real matrix don't need special-casing. The final answer is maxSide², not maxSide — don't forget to square it.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Grid DP — "largest square ending here" via min of three neighbors
- **State:** dp[i][j] = side length of the largest all-1s square whose bottom-right corner is (i,j)
- **Transition:** dp[i][j] = matrix[i][j]=='0' ? 0 : 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
- **Base case:** with padding, dp's border row/column are all 0; without padding, the true first row/column equal the matrix cell itself (0 or 1)
- **Complexity:** Time O(m·n), Space O(m·n) (reducible to O(n) rolling)
- **Gotcha:** using only left+up (forgetting the diagonal min) overcounts and produces squares that aren't actually all 1s; also the answer requested is area, so square the max side before returning.

</details>

---

## Problem 2: 309. Best Time to Buy and Sell Stock with Cooldown — Medium
Link: https://leetcode.com/problems/best-time-to-buy-and-sell-stock-with-cooldown/

**Hint 1 (direction):** This isn't just "holding vs. not holding" like the plain stock problem — there's a third situation to represent: the day right after you sold, when you're locked out of buying.
**Hint 2 (technique):** State-machine DP — exactly the "mode" flavor called out in this week's primer, with three explicit states per day.
**Hint 3 (structure):** Per day i, track hold[i] (max profit currently holding), sold[i] (max profit, just sold today), rest[i] (max profit, not holding and not just-sold). hold[i] = max(hold[i-1], rest[i-1]-price[i]); sold[i] = hold[i-1]+price[i]; rest[i] = max(rest[i-1], sold[i-1]).
**Hint 4 (implementation):** Seed hold[0] = -price[0] (bought on day 0), rest[0] = 0, and treat sold[0] as unreachable/0 (you can't sell on day 0). Roll the three values forward day by day — you only ever need the previous day's triple, not a full table.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** State-machine DP with 3 explicit states (holding / just-sold / resting)
- **State:** hold[i], sold[i], rest[i] as defined above
- **Transition:** hold[i]=max(hold[i-1], rest[i-1]-price[i]); sold[i]=hold[i-1]+price[i]; rest[i]=max(rest[i-1], sold[i-1])
- **Base case:** hold[0] = -price[0]; sold[0] = 0 (or treat as unreachable, loop from i=1); rest[0] = 0
- **Complexity:** Time O(n), Space O(1) (rolling scalars, no array needed)
- **Gotcha:** the cooldown is enforced purely by making rest[i] read from sold[i-1] (one day lag) instead of letting hold[i] read from sold[i-1] directly — if hold pulls straight from sold[i-1], you've silently deleted the cooldown day.

</details>
