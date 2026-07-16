# Day 21 — DP Fundamentals (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 279. Perfect Squares — Medium
Link: https://leetcode.com/problems/perfect-squares/

**Hint 1 (direction):** For a target number n, think about the last perfect square you'd subtract off to get there, and how that connects n's answer to the answers for smaller numbers.
**Hint 2 (technique):** 1D unbounded "coin change"-style DP, where the available "coins" are perfect squares (1, 4, 9, 16, ...).
**Hint 3 (structure):** State: dp[i] = minimum number of perfect squares that sum to i. Transition: dp[i] = min over every j with j*j <= i of (dp[i - j*j] + 1).
**Hint 4 (implementation):** Size dp as n+1 with dp[0] = 0 (base case: zero needs zero squares); initialize every other entry to a large sentinel before taking the min, and precompute the list of perfect squares up to n once.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Unbounded knapsack-style 1D DP (minimum count variant)
- **State:** dp[i] = minimum number of perfect squares summing to i
- **Transition:** dp[i] = min(dp[i - j*j] + 1) for every j with j*j <= i
- **Base case:** dp[0] = 0
- **Complexity:** Time O(n * sqrt(n)), Space O(n)
- **Gotcha:** Forgetting to initialize non-zero dp entries to infinity/max-int before taking the min makes every result look artificially small.

</details>

---

## Problem 2: 300. Longest Increasing Subsequence — Medium
Link: https://leetcode.com/problems/longest-increasing-subsequence/

**Hint 1 (direction):** For each element, treat it as the last element of some increasing subsequence — what would you need to know about every earlier element to decide how long a subsequence ending here could be?
**Hint 2 (technique):** 1D DP where each state scans all previous states (O(n^2) baseline) — a patience-sorting/binary-search O(n log n) approach also exists, but master this recurrence first.
**Hint 3 (structure):** State: dp[i] = length of the longest increasing subsequence ending exactly at index i. Transition: dp[i] = max(dp[j] + 1) for every j < i where nums[j] < nums[i]; if no such j exists, dp[i] = 1.
**Hint 4 (implementation):** Initialize every dp[i] = 1 (base case: each element alone is a subsequence of length 1) before the double loop; the final answer is max(dp) over the whole array, not dp[n-1].

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** 1D DP with an O(n) inner scan per state (O(n^2) total)
- **State:** dp[i] = length of the LIS ending at index i
- **Transition:** dp[i] = max(dp[j] + 1) for all j < i with nums[j] < nums[i], else 1
- **Base case:** dp[i] = 1 for all i initially
- **Complexity:** Time O(n^2) for the DP version (O(n log n) with binary search over tails), Space O(n)
- **Gotcha:** The answer is max(dp[i]) across the whole array — the LIS does not have to end at the last element.

</details>

---

## Problem 3: 322. Coin Change — Medium
Link: https://leetcode.com/problems/coin-change/

**Hint 1 (direction):** For a given amount, think about the last coin you'd add to complete it, and how that connects this amount's answer to the answer for a strictly smaller amount.
**Hint 2 (technique):** Unbounded knapsack-style 1D DP (each coin denomination can be reused any number of times), minimizing a count instead of counting ways.
**Hint 3 (structure):** State: dp[i] = minimum number of coins needed to make amount i. Transition: dp[i] = min over every coin c (with c <= i) of (dp[i - c] + 1).
**Hint 4 (implementation):** Size dp as amount+1 with dp[0] = 0 (base case). Initialize all other entries to a sentinel larger than any possible answer (e.g. amount+1) so unreachable amounts are detectable; return -1 if dp[amount] still equals that sentinel at the end.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Unbounded knapsack-style 1D DP (minimum count variant)
- **State:** dp[i] = minimum coins required to make amount i
- **Transition:** dp[i] = min(dp[i - c] + 1) over all coins c <= i
- **Base case:** dp[0] = 0
- **Complexity:** Time O(amount * number of coins), Space O(amount)
- **Gotcha:** Using a sentinel that can overflow or alias with a real answer breaks the "unreachable" check — use amount+1 (an impossible count) and check for it explicitly before returning.

</details>
