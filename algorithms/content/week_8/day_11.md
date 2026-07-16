# Day 11 — Math & Optimization (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 7. Reverse Integer — Medium
Link: https://leetcode.com/problems/reverse-integer/

**Hint 1 (direction):** Don't think about strings — think about how you'd peel digits off a number one at a time, the same `n % 10` / `n /= 10` move from the primer.
**Hint 2 (technique):** This is a place-value digit extraction problem combined with a 32-bit overflow check performed *before* the overflow happens.
**Hint 3 (structure):** Loop: pop last digit via `%10`/`/10` from input, push it into a running `result = result*10 + digit`. Stop when input hits 0. Sign falls out naturally if you keep it signed.
**Hint 4 (implementation):** Check for overflow before the multiply-add, not after (by the time it overflows in a fixed-width int it's too late) — compare against `INT_MAX/10` and the last digit against `INT_MAX%10`.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** digit-by-digit reversal via mod/div, with pre-emptive overflow guard.
- **Core idea:** Build the reversed number one digit at a time; since the result itself can overflow a 32-bit int, you must detect that *before* the multiply, using the bound on what the next digit can safely add.
- **Algorithm:** 1) result = 0. 2) while n != 0: digit = n % 10 (careful with sign for negative n); if result > INT_MAX/10 or (result == INT_MAX/10 and digit > 7) return 0 (and symmetric check for INT_MIN/-8); result = result*10 + digit; n /= 10. 3) return result.
- **Complexity:** Time O(log10 n), Space O(1).
- **Gotcha:** Language-dependent `%` sign behavior on negative numbers — verify your language's modulo keeps the sign of the dividend, and pick your overflow bound (7 for positive, 8 for negative since INT_MIN = -2147483648) precisely.

</details>

---

## Problem 2: 9. Palindrome Number — Easy
Link: https://leetcode.com/problems/palindrome-number/

**Hint 1 (direction):** You're told not to convert to a string — so think about how you'd compare the number to a version of itself built backwards, without ever materializing the full reverse.
**Hint 2 (technique):** Reverse only half the digits and compare the two halves — no full string reversal, no full-number reversal (which risks overflow anyway).
**Hint 3 (structure):** Negative numbers and numbers ending in 0 (but not 0 itself) can be rejected immediately. Otherwise, peel digits off the end into a `reversedHalf` accumulator while original shrinks, until original <= reversedHalf, then compare.
**Hint 4 (implementation):** For odd digit counts, the middle digit ends up in `reversedHalf` — divide it by 10 before comparing (`reversedHalf/10 == remaining`) rather than requiring exact equality.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** half-reversal digit comparison.
- **Core idea:** A palindrome number's first half mirrors its second half, so you only need to reverse half the digits and compare — this also sidesteps the overflow risk of reversing the whole number.
- **Algorithm:** 1) If x < 0 or (x % 10 == 0 and x != 0) return false. 2) revertedHalf = 0. 3) while x > revertedHalf: revertedHalf = revertedHalf*10 + x%10; x /= 10. 4) return x == revertedHalf or x == revertedHalf/10.
- **Complexity:** Time O(log10 n), Space O(1).
- **Gotcha:** Trailing-zero numbers like 10, 100 are never palindromes (except 0 itself) — miss that check and your loop condition breaks.

</details>

---

## Problem 3: 66. Plus One — Easy
Link: https://leetcode.com/problems/plus-one/

**Hint 1 (direction):** The array represents one big number's digits in order — think about what "adding one" does to a number's digits from the rightmost end, and when it actually needs to touch the next digit over.
**Hint 2 (technique):** This is a carry-propagation pass over the digit array, walked right to left.
**Hint 3 (structure):** Walk from the last index backward: if digit < 9, increment it and return immediately (no carry needed). If digit == 9, set it to 0 and continue left (carry propagates).
**Hint 4 (implementation):** The edge case is all-9s (e.g. `[9,9,9]` -> `[1,0,0,0]`): if the loop finishes without an early return, you must allocate a new array one element longer with a leading 1 followed by zeros.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** right-to-left carry propagation.
- **Core idea:** Adding one only cascades past a digit when that digit is 9; the moment you hit a non-9 digit you can increment and stop, so most inputs resolve in O(1) amortized work.
- **Algorithm:** 1) for i from last index to 0: if digits[i] < 9, digits[i]++, return digits. 2) else digits[i] = 0 (carry continues). 3) If loop exhausts (all were 9), return a new array of length n+1 with 1 followed by n zeros.
- **Complexity:** Time O(n) worst case, Space O(1) extra (O(n) only in the all-9s new-array case).
- **Gotcha:** Forgetting the all-9s case (`[9]` -> `[1,0]`) is the classic bug — don't just return the mutated array without checking whether every digit rolled over.

</details>
