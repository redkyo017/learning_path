# Day 20 — DP Fundamentals (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 139. Word Break — Medium
Link: https://leetcode.com/problems/word-break/

**Hint 1 (direction):** Think about the string prefix ending at each index — under what condition could that whole prefix be cleanly split into dictionary words, using only information about shorter prefixes?
**Hint 2 (technique):** 1D boolean DP over string prefixes, checking a dictionary set at each candidate split point.
**Hint 3 (structure):** State: dp[i] = true if the prefix s[0..i-1] (length i) can be fully segmented into dictionary words. Transition: dp[i] = true if there exists some j < i with dp[j] true AND s[j..i-1] in the word dictionary (kept as a hash set for O(1) lookup).
**Hint 4 (implementation):** Size dp as n+1 with dp[0] = true (empty prefix trivially breakable) as the base case; convert wordDict into a set before the loop rather than scanning the list repeatedly.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Segmentation DP over string prefixes with a dictionary set
- **State:** dp[i] = true if s[0:i] can be fully segmented into words from the dictionary
- **Transition:** dp[i] = OR over all j in [0,i) of (dp[j] AND s[j:i] in wordSet)
- **Base case:** dp[0] = true
- **Complexity:** Time O(n^2) (n positions x substring checks, each O(1) amortized with a set), Space O(n)
- **Gotcha:** Using a list/slice for word lookups instead of a set turns this into a much slower scan per candidate — always precompute a set for membership tests.

</details>

---

## Problem 2: 152. Maximum Product Subarray — Medium
Link: https://leetcode.com/problems/maximum-product-subarray/

**Hint 1 (direction):** With products, a single negative number can flip your best running result into your worst one and vice versa — what extra piece of information do you need to carry forward besides just "the best product ending here"?
**Hint 2 (technique):** 1D DP tracking two running values simultaneously — max-ending-here and min-ending-here — because sign flips and zeros can reset or invert the running chain.
**Hint 3 (structure):** State: maxDp[i] = max product of a subarray ending exactly at i; minDp[i] = min product of a subarray ending exactly at i. Transition: candidates = {nums[i], maxDp[i-1]*nums[i], minDp[i-1]*nums[i]}; maxDp[i] = max(candidates), minDp[i] = min(candidates).
**Hint 4 (implementation):** Initialize both maxDp and minDp to nums[0] before the loop (base case), and update the global answer as the running max of maxDp[i] at every step, not only once at the end.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Dual-state 1D DP (track both running max and running min)
- **State:** maxDp[i]/minDp[i] = max/min product of any subarray ending at index i
- **Transition:** maxDp[i] = max(nums[i], maxDp[i-1]*nums[i], minDp[i-1]*nums[i]); minDp[i] = min of the same three
- **Base case:** maxDp[0] = minDp[0] = nums[0]
- **Complexity:** Time O(n), Space O(1) with rolling variables
- **Gotcha:** Tracking only the running max (as in Kadane's for sums) silently gives wrong answers here — a very negative minDp times a new negative number can become the new maximum.

</details>

---

## Problem 3: 213. House Robber II — Medium
Link: https://leetcode.com/problems/house-robber-ii/

**Hint 1 (direction):** You already know how to solve this for a straight line of houses — what's different now is that the first and last house are adjacent, so think about which combinations of "include first" / "include last" are even legal.
**Hint 2 (technique):** Reuse the House Robber linear DP, run it twice on two overlapping sub-ranges to handle the circular constraint.
**Hint 3 (structure):** State (per run): dp[i] = max money from a linear (non-circular) subrange, same transition as House Robber: dp[i] = max(dp[i-1], dp[i-2] + nums[i]). Run once on houses[0..n-2] (excludes the last house) and once on houses[1..n-1] (excludes the first house); the answer is the max of the two runs.
**Hint 4 (implementation):** Handle n == 1 as a special case up front (return nums[0]) before splitting into two ranges, since a single house has no circular conflict at all.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Linear DP applied twice to break a circular constraint
- **State:** dp[i] = max money robbable from a linear range of houses (identical to House Robber)
- **Transition:** dp[i] = max(dp[i-1], dp[i-2] + houses[i])
- **Base case:** for each sub-range, seed the recurrence from that range's own first two elements
- **Complexity:** Time O(n), Space O(1) per run
- **Gotcha:** Forgetting the n == 1 edge case — excluding "the last house" and "the first house" from a single-house array can produce an empty range and mishandle the answer as 0 instead of nums[0].

</details>
