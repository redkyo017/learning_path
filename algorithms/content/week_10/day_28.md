# Day 28 — Advanced Dynamic Programming (Phase 2)

Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 516. Longest Palindromic Subsequence — Medium
Link: https://leetcode.com/problems/longest-palindromic-subsequence/

**Hint 1 (direction):** Compare the two ends of a substring first — when they match, what does that tell you about the best you can do with everything strictly between them?
**Hint 2 (technique):** Interval DP over substring bounds [i,j], filled by increasing interval length rather than row-by-row.
**Hint 3 (structure):** dp[i][j] = length of the longest palindromic subsequence within s[i..j]. If s[i]==s[j]: dp[i][j] = dp[i+1][j-1] + 2. Else: dp[i][j] = max(dp[i+1][j], dp[i][j-1]).
**Hint 4 (implementation):** dp[i][i] = 1 for every i. For adjacent pairs (j=i+1) the "interior" dp[i+1][j-1] would refer to an inverted range — treat that term as 0 there. Fill the table with i decreasing from n-1 to 0 and j increasing from i+1, so dp[i+1][...] is always already computed.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Interval DP over substring [i,j], filled by increasing length
- **State:** dp[i][j] = length of the longest palindromic subsequence in s[i..j]
- **Transition:** dp[i][j] = dp[i+1][j-1]+2 if s[i]==s[j], else max(dp[i+1][j], dp[i][j-1])
- **Base case:** dp[i][i] = 1 for all i; dp[i][j] = 0 when i > j (empty range)
- **Complexity:** Time O(n²), Space O(n²) (reducible to O(n) with careful diagonal-order rolling)
- **Gotcha:** filling the table in plain row-major order reads dp[i+1][...] before it's been computed — you must fill by increasing interval length, or equivalently iterate i downward.

</details>

---

## Problem 2: 10. Regular Expression Matching — Hard
Link: https://leetcode.com/problems/regular-expression-matching/

**Hint 1 (direction):** Walk s and the pattern from the start together; at each pair of positions, the current pattern token dictates how much input it can consume — but a token followed by `*` needs a fundamentally different rule from a plain token.
**Hint 2 (technique):** Two-sequence DP over (text index, pattern index), with a dedicated branch for `*` meaning "zero or more of the single preceding element."
**Hint 3 (structure):** dp[i][j] = does s[0:i] match p[0:j]? If p[j-1] is not '*': dp[i][j] = dp[i-1][j-1] && (p[j-1]=='.' || p[j-1]==s[i-1]). If p[j-1]=='*': dp[i][j] = dp[i][j-2] (zero occurrences of the preceding element) || (dp[i-1][j] && (p[j-2]=='.' || p[j-2]==s[i-1])) (one more occurrence, consuming from s).
**Hint 4 (implementation):** dp[0][0]=true. dp[0][j] needs its own left-to-right initialization for patterns like "a*b*c*" that can match the empty string: dp[0][j] = dp[0][j-2] when p[j-1]=='*'. Remember '.' matches any single character in the non-star branch.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Two-sequence DP with a Kleene-star transition
- **State:** dp[i][j] = does s[:i] fully match p[:j] (both ends anchored)
- **Transition:** non-star: dp[i][j] = dp[i-1][j-1] && charMatch(s[i-1], p[j-1]); star: dp[i][j] = dp[i][j-2] || (dp[i-1][j] && charMatch(s[i-1], p[j-2]))
- **Base case:** dp[0][0]=true; dp[0][j] built left-to-right using the star rule, false otherwise
- **Complexity:** Time O(m·n), Space O(m·n) (reducible to O(n) rolling)
- **Gotcha:** a `*` binds to exactly the single preceding pattern element, so its "one token back" index is j-2, not j-1; also note this is full-string matching (implicit anchors) — the anchoring is the same as Wildcard Matching, but the `*` semantics are not.

</details>
