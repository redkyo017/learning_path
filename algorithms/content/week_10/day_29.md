# Day 29 — Advanced Dynamic Programming (Phase 2)

Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 44. Wildcard Matching — Hard
Link: https://leetcode.com/problems/wildcard-matching/

**Hint 1 (direction):** You've just solved a lookalike problem with a `*` in the pattern — before writing any transition, pin down exactly what `*` means HERE, because it is not the same rule.
**Hint 2 (technique):** Two-sequence DP over (text index, pattern index), where `*` matches any sequence of characters (including empty) — not "zero or more of the single preceding char" like regex.
**Hint 3 (structure):** dp[i][j] = does s[0:i] match p[0:j]? If p[j-1]=='?' or p[j-1]==s[i-1]: dp[i][j] = dp[i-1][j-1]. If p[j-1]=='*': dp[i][j] = dp[i-1][j] (star absorbs one more text character) || dp[i][j-1] (star matches empty here).
**Hint 4 (implementation):** dp[0][0]=true; dp[0][j] = dp[0][j-1] && p[j-1]=='*' (a leading run of stars can match empty, anything else can't). A `*` is allowed to match zero characters — don't assume it must consume at least one.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Two-sequence DP with an arbitrary-length wildcard transition
- **State:** dp[i][j] = does s[:i] match p[:j]
- **Transition:** dp[i][j] = dp[i-1][j-1] when p[j-1] matches s[i-1] via '?' or exact char; dp[i][j] = dp[i-1][j] || dp[i][j-1] when p[j-1]=='*'
- **Base case:** dp[0][0]=true; dp[0][j] = dp[0][j-1] && p[j-1]=='*'
- **Complexity:** Time O(m·n) (can be optimized to O(m+n) with a greedy two-pointer + backtrack pointer approach), Space O(m·n) or O(n) rolling
- **Gotcha:** confusing this with problem 10's regex-star semantics is the single most common bug — here `*` is a standalone token meaning "any substring" and never pairs with a preceding character.

</details>

---

## Problem 2: 87. Scramble String — Hard
Link: https://leetcode.com/problems/scramble-string/

**Hint 1 (direction):** Think recursively: for two equal-length strings to be scrambles of each other, there must be some split point dividing each into two parts that are, in some order (possibly swapped), scrambles of each other.
**Hint 2 (technique):** Interval-flavored DP via memoized recursion over pairs of substrings, sped up with a cheap sorted-character equality pre-check to prune impossible branches before recursing.
**Hint 3 (structure):** isScramble(s1 substring at i1 of length len, s2 substring at i2 of length len): for each split k in [1, len-1], return true if either (no-swap: isScramble(i1,i2,k) && isScramble(i1+k,i2+k,len-k)) or (swap: isScramble(i1,i2+len-k,k) && isScramble(i1+k,i2,len-k)) holds. Memoize on the triple (i1, i2, len).
**Hint 4 (implementation):** Base case: if the two substrings are identical, return true immediately. Before trying any split, compare sorted character counts of the two substrings — if they differ, return false without recursing (this pruning is what keeps the search tractable). Your memo key needs 3 coordinates (two starts + a length), not 2 — a plain [i][j] table can't distinguish which part of s2 you're matching against.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Interval DP via memoized recursion over (start1, start2, length) triples, with a character-multiset pruning check
- **State:** dp[i1][i2][len] = true if s1[i1:i1+len] and s2[i2:i2+len] are scrambles of each other
- **Transition:** try every split k in [1, len-1]; true if (dp[i1][i2][k] && dp[i1+k][i2+k][len-k]) [no swap] or (dp[i1][i2+len-k][k] && dp[i1+k][i2][len-k]) [swap]
- **Base case:** len==1: dp true iff s1[i1]==s2[i2]; also short-circuit true whenever the two substrings are character-for-character identical (saves huge recursion depth)
- **Complexity:** Time O(n⁴) (O(n³) states, O(n) split work each), Space O(n³) for the memo
- **Gotcha:** trying to collapse this into a 2D [i][j] table (like the palindrome interval DP two problems ago) silently loses which offset into s2 you're comparing against — you genuinely need 3 indices here.

</details>

---

## Problem 3: 312. Burst Balloons — Hard
Link: https://leetcode.com/problems/burst-balloons/

**Hint 1 (direction):** Picking "which balloon to burst first" makes the two resulting sides interact through the shared neighbor that changes with every burst — is there an order of bursting where a range's two sides become truly independent subproblems?
**Hint 2 (technique):** Interval DP, but the essential trick is to think about which balloon is burst LAST within a range [i,j], not first — its neighbors at burst time are the fixed boundary balloons i and j, so both sides stop interacting.
**Hint 3 (structure):** Pad the array with 1s at both ends: nums = [1] + original + [1]. dp[i][j] = max coins from bursting every balloon strictly between i and j. dp[i][j] = max over k in (i,j) of dp[i][k] + dp[k][j] + nums[i]*nums[k]*nums[j].
**Hint 4 (implementation):** Fill dp by increasing interval width (j-i), so every subrange dp depends on is already solved. dp[i][j] = 0 whenever j <= i+1 (nothing strictly between them). The final answer is dp[0][n+1] on the padded array (n = original length).
<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Interval DP framed around "the last event in the range," not the first
- **State:** dp[i][j] = max coins obtainable bursting all balloons in the open interval (i,j), given the padded boundary balloons at i and j survive until last
- **Transition:** dp[i][j] = max_{i<k<j} ( dp[i][k] + dp[k][j] + nums[i]·nums[k]·nums[j] ), where k is the balloon burst last in (i,j)
- **Base case:** dp[i][j] = 0 whenever j <= i+1 (no balloons strictly between them)
- **Complexity:** Time O(n³), Space O(n²)
- **Gotcha:** forgetting to pad both ends with virtual 1-value balloons breaks the boundary multiplication for the two outermost bursts; you must also fill by increasing range width (or recurse with memoization) since dp[i][j] depends only on strictly smaller sub-intervals.

</details>
