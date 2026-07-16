# Day 13 — Math & Optimization (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 171. Excel Sheet Column Number — Easy
Link: https://leetcode.com/problems/excel-sheet-column-number/

**Hint 1 (direction):** This looks like base conversion, but notice there's no symbol for "zero" in this system — A maps to 1, not 0. What does that do to the usual place-value formula?
**Hint 2 (technique):** Treat it as base-26 positional-value conversion, with a 1-indexed digit alphabet (A=1..Z=26) instead of 0-indexed.
**Hint 3 (structure):** Walk the string left to right, maintaining `result = result*26 + (char - 'A' + 1)` for each character.
**Hint 4 (implementation):** The off-by-one is the entire problem: use `char - 'A' + 1`, not `char - 'A'` — otherwise A would contribute 0 to every position, breaking multi-letter columns like "AA".

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** bijective base-26 conversion (1-indexed digits).
- **Core idea:** Excel columns are base-26 numbers with digits 1-26 (A-Z) rather than 0-25, so the standard "accumulate = accumulate*base + digit" loop works as long as you shift each letter's value up by one.
- **Algorithm:** 1) result = 0. 2) for each char c in the string left to right: result = result*26 + (c - 'A' + 1). 3) return result.
- **Complexity:** Time O(n), Space O(1).
- **Gotcha:** Confusing this with plain base-26 (digit = c-'A') silently gives wrong answers for any column with more than one letter, not just an off-by-one at the edges.

</details>

---

## Problem 2: 258. Add Digits — Easy
Link: https://leetcode.com/problems/add-digits/

**Hint 1 (direction):** You could simulate repeatedly summing digits until one remains — but the problem hints at an O(1) answer. What well-known property of a number relates it to the sum of its digits, over and over?
**Hint 2 (technique):** This is the "digital root," computable via modular arithmetic mod 9 (congruence: a number and its digit sum share the same remainder mod 9).
**Hint 3 (structure):** The digital root of n (for n > 0) is `1 + (n - 1) % 9`. No loop needed at all.
**Hint 4 (implementation):** Handle n == 0 as a special case (digital root of 0 is 0, but the formula `1 + (n-1)%9` would misfire on 0 with negative modulo behavior in some languages).

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** digital root via mod-9 congruence.
- **Core idea:** Repeated digit-summing converges to n mod 9, remapped to the range 1-9 (with 9 instead of 0 for nonzero multiples of 9) — this is a known number-theory identity, not something you need to simulate.
- **Algorithm:** 1) if n == 0 return 0. 2) if n % 9 == 0 return 9. 3) else return n % 9.  (equivalently `1 + (n-1)%9` for n>0).
- **Complexity:** Time O(1), Space O(1).
- **Gotcha:** Multiples of 9 (like 18, 81) must map to 9, not 0 — a naive `n % 9` alone breaks exactly on those inputs.

</details>

---

## Problem 3: 264. Ugly Number II — Medium
Link: https://leetcode.com/problems/ugly-number-ii/

**Hint 1 (direction):** Generating candidates and checking each for "ugliness" one at a time will be too slow for large n — think instead about *building* the sequence of ugly numbers directly, in increasing order, from smaller ugly numbers already found.
**Hint 2 (technique):** Dynamic programming with three pointers (one per prime factor 2, 3, 5), merging three sorted streams.
**Hint 3 (structure):** Maintain dp[1..n] where dp[1]=1, and three indices i2, i3, i5 all starting at 1 pointing into dp. Each step, dp[k] = min(dp[i2]*2, dp[i3]*3, dp[i5]*5); advance whichever pointer(s) produced that minimum.
**Hint 4 (implementation):** If two or three of the candidate products tie for the minimum, you must advance *all* of the matching pointers that step, not just one — otherwise you'll emit duplicate ugly numbers into the sequence.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** merge of three sorted sequences via DP with multi-pointer advance (classic "ugly number" / Hamming sequence generation).
- **Core idea:** Every ugly number beyond 1 is some earlier ugly number times 2, 3, or 5; by tracking one pointer per factor into the growing sequence and always taking the smallest next candidate, you generate the sequence in sorted order without recomputation or duplicates.
- **Algorithm:** 1) dp[1] = 1; i2=i3=i5=1. 2) for k = 2..n: next2=dp[i2]*2, next3=dp[i3]*3, next5=dp[i5]*5; dp[k] = min(next2,next3,next5); if dp[k]==next2, i2++; if dp[k]==next3, i3++; if dp[k]==next5, i5++ (all as independent ifs, not else-if). 3) return dp[n].
- **Complexity:** Time O(n), Space O(n) (can be reduced to O(1) with just the 3 last values + pointer offsets, but O(n) DP array is the standard clean solution).
- **Gotcha:** Using `else if` instead of independent `if` statements for the pointer advances will produce duplicate values in dp whenever two products tie (e.g. 2*3 == 3*2 == 6).

</details>
