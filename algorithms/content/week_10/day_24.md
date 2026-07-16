# Day 24 — Advanced Dynamic Programming (Phase 2)

Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 45. Jump Game II — Medium
Link: https://leetcode.com/problems/jump-game-ii/

**Hint 1 (direction):** Instead of asking "where can I jump from index i?", ask "what is the farthest index I can possibly reach using at most k jumps?" — how does that reachable frontier grow as k increases?
**Hint 2 (technique):** This one is a trap for DP week — there's an O(n²) DP baseline, but the real optimal solution is greedy range-expansion (think BFS by levels, not a value table).
**Hint 3 (structure):** DP baseline: dp[i] = min jumps to reach i; dp[0]=0; dp[i] = min(dp[j]+1) over all j<i with j+nums[j]>=i. Greedy version: track curEnd (boundary reachable with jumps used so far) and farthest (best reach if you take one more jump); scan i from 0, updating farthest = max(farthest, i+nums[i]); when i hits curEnd, jumps++ and curEnd = farthest.
**Hint 4 (implementation):** Stop the greedy scan at index n-2, not n-1 — checking `i == curEnd` at the very last index can add a spurious extra jump once you've already arrived.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Greedy range/BFS-level expansion (the DP formulation exists but is asymptotically worse)
- **State:** farthest = max index reachable from any index scanned in the current "wave"; curEnd = right boundary of the current wave
- **Transition:** for i in [0, n-2]: farthest = max(farthest, i+nums[i]); if i == curEnd: jumps++, curEnd = farthest
- **Base case:** jumps=0, curEnd=0, farthest=0
- **Complexity:** Time O(n), Space O(1) for greedy; O(n²) time / O(n) space for the DP baseline
- **Gotcha:** looping through index n-1 in the `i==curEnd` check can register one extra unnecessary jump at the end — bound the loop to `n-1` exclusive.

</details>

---

## Problem 2: 97. Interleaving String — Medium
Link: https://leetcode.com/problems/interleaving-string/

**Hint 1 (direction):** Think about building s3 one character at a time from the front of s1 and s2 — at each position in s3, which source string could have just supplied that character, and does it matter which one supplied earlier characters?
**Hint 2 (technique):** Two-sequence boolean reachability DP over a grid of (prefix of s1, prefix of s2).
**Hint 3 (structure):** dp[i][j] = true if s3[0:i+j] can be formed by interleaving s1[0:i] and s2[0:j]. dp[i][j] = (dp[i-1][j] && s1[i-1]==s3[i+j-1]) || (dp[i][j-1] && s2[j-1]==s3[i+j-1]).
**Hint 4 (implementation):** Size the table (len(s1)+1) x (len(s2)+1); dp[0][0]=true; the first row and first column each need their own base-case pass since one of the two OR-branches doesn't exist there. Bail out immediately if len(s1)+len(s2) != len(s3).

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Two-sequence boolean DP
- **State:** dp[i][j] = can s3's first i+j characters be formed by interleaving s1's first i and s2's first j characters
- **Transition:** dp[i][j] = (dp[i-1][j] && s1[i-1]==s3[i+j-1]) || (dp[i][j-1] && s2[j-1]==s3[i+j-1])
- **Base case:** dp[0][0]=true; dp[i][0] = dp[i-1][0] && s1[i-1]==s3[i-1]; dp[0][j] = dp[0][j-1] && s2[j-1]==s3[j-1]
- **Complexity:** Time O(m·n), Space O(m·n) (reducible to O(n) with a rolling row)
- **Gotcha:** skipping the length check wastes time on impossible inputs and risks index confusion; also remember indices into s3 are `i+j-1`, offset from the s1/s2 indices you're iterating.

</details>
