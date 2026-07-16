# Day 27 — Advanced Dynamic Programming (Phase 2)

Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 377. Combination Sum IV — Medium
Link: https://leetcode.com/problems/combination-sum-iv/

**Hint 1 (direction):** Despite the name, this counts ordered sequences, not combinations — think about which number could be the LAST one placed to complete a sum of t.
**Hint 2 (technique):** 1D unbounded counting DP over the target sum (like unbounded knapsack, but counting permutations instead of combinations).
**Hint 3 (structure):** dp[t] = number of ordered sequences from nums summing to exactly t. dp[t] = sum over each num in nums of dp[t-num], whenever t-num >= 0.
**Hint 4 (implementation):** dp[0] = 1 (the empty sequence sums to 0, one way). Loop t as the OUTER loop (1 to target) and nums as the INNER loop — that nesting order is exactly what makes this count permutations; it's the reverse of the nesting you'd use to count combinations.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Unbounded counting DP over target sum, order-sensitive (outer loop = target, inner loop = items)
- **State:** dp[t] = number of ordered sequences of nums that sum exactly to t
- **Transition:** dp[t] = Σ dp[t-num] for every num ≤ t
- **Base case:** dp[0] = 1
- **Complexity:** Time O(target · len(nums)), Space O(target)
- **Gotcha:** the outer/inner loop order is the entire trick here — swapping it (items outer, target inner) turns this into a combination-counting DP with a different, smaller answer.

</details>

---

## Problem 2: 416. Partition Equal Subset Sum — Medium
Link: https://leetcode.com/problems/partition-equal-subset-sum/

**Hint 1 (direction):** "Split into two equal-sum halves" is really just asking a yes/no question about a single target number derived from the total.
**Hint 2 (technique):** 0/1 knapsack feasibility DP (subset-sum boolean variant) — each number is used at most once, unlike yesterday's unbounded reuse.
**Hint 3 (structure):** target = sum/2 (immediately return false if sum is odd). dp[s] = true if some subset of numbers processed so far sums to exactly s. For each num: dp[s] = dp[s] || dp[s-num].
**Hint 4 (implementation):** For each number, iterate s DOWNWARD from target to num (not upward) — this reverse direction is what guarantees each number is only used once per outer iteration, in contrast to Combination Sum IV's forward loop that intentionally allows reuse.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** 0/1 knapsack subset-sum (boolean feasibility DP)
- **State:** dp[s] = can some subset of the numbers examined so far sum to exactly s
- **Transition:** for each num: for s from target down to num: dp[s] = dp[s] || dp[s-num]
- **Base case:** dp[0] = true, all other entries false initially
- **Complexity:** Time O(n · target), Space O(target)
- **Gotcha:** iterating s forward instead of backward lets the same number be reused within one item's pass, silently converting this into an unbounded-knapsack bug that overcounts feasibility.

</details>
