# Day 22 — DP Fundamentals (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 32. Longest Valid Parentheses — Hard
Link: https://leetcode.com/problems/longest-valid-parentheses/

**Hint 1 (direction):** Think about each ')' character individually — for it to end a valid run, what would need to be true about the character(s) immediately before it, and about whatever came before that?
**Hint 2 (technique):** 1D DP indexed by string position, where only ')' positions ever hold a nonzero value (a stack-based approach also works, but build the DP recurrence first).
**Hint 3 (structure):** State: dp[i] = length of the longest valid parentheses substring ending exactly at index i (dp[i] = 0 whenever s[i] == '('). Transition: if s[i]==')' and s[i-1]=='(', dp[i] = dp[i-2] + 2 (a fresh matched pair plus whatever valid run preceded it). If s[i]==')' and s[i-1]==')', check the character just before the matched run ending at i-1: if s[i - dp[i-1] - 1] == '(', dp[i] = dp[i-1] + 2 + dp[i - dp[i-1] - 2].
**Hint 4 (implementation):** Guard every index used in the transition (i-1, i-2, i-dp[i-1]-1, i-dp[i-1]-2) against going below 0 before dereferencing; the final answer is max(dp) over the whole array, not dp[n-1].

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** 1D DP on string positions with a "jump back over the matched run" transition
- **State:** dp[i] = length of the longest valid parentheses substring ending at index i
- **Transition:** dp[i] = dp[i-2] + 2 if s[i-1]=='('; dp[i] = dp[i-1] + 2 + dp[i-dp[i-1]-2] if s[i-1]==')' and the character before that matched run is '('
- **Base case:** dp[0] = 0; dp[i] = 0 whenever s[i] == '('
- **Complexity:** Time O(n), Space O(n)
- **Gotcha:** Negative index access when dp[i-1] reaches back past the start of the string — every lookup index must be bounds-checked before use; this is the single most common bug in this problem.

</details>

---

## Problem 2: 72. Edit Distance — Hard
Link: https://leetcode.com/problems/edit-distance/

**Hint 1 (direction):** Think about the last characters of each of the two strings' prefixes you're currently comparing — either they match for free, or you must pay for one of a small fixed set of corrective actions to reconcile them.
**Hint 2 (technique):** Classic 2D DP comparing two strings, one dimension per string's prefix length.
**Hint 3 (structure):** State: dp[i][j] = minimum edit operations to convert the first i characters of word1 into the first j characters of word2. Transition: if word1[i-1] == word2[j-1], dp[i][j] = dp[i-1][j-1] (characters already match, no cost); otherwise dp[i][j] = 1 + min(dp[i-1][j] [delete], dp[i][j-1] [insert], dp[i-1][j-1] [replace]).
**Hint 4 (implementation):** Size the table (m+1) x (n+1). Base case: dp[i][0] = i (delete all i characters to reach empty), dp[0][j] = j (insert all j characters from empty).

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Two-string 2D DP (prefix vs. prefix)
- **State:** dp[i][j] = min operations to convert word1[0:i] into word2[0:j]
- **Transition:** dp[i][j] = dp[i-1][j-1] if chars match, else 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
- **Base case:** dp[i][0] = i, dp[0][j] = j
- **Complexity:** Time O(m*n), Space O(m*n) (reducible to O(min(m,n)) with a rolling row)
- **Gotcha:** Mixing up which neighbor corresponds to insert vs. delete relative to word1 vs. word2 — write out which string each dimension represents before coding, since insert/delete swap direction depending on which word you treat as the "source".

</details>
