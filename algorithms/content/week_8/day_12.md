# Day 12 — Math & Optimization (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 172. Factorial Trailing Zeroes — Medium
Link: https://leetcode.com/problems/factorial-trailing-zeroes/

**Hint 1 (direction):** You are not going to compute n! (it explodes instantly). Ask instead: a trailing zero comes from a factor of 10 = 2 × 5 — which of those two prime factors is scarcer among the numbers 1..n?
**Hint 2 (technique):** Count factors of 5 using Legendre's formula (counting multiples of 5, 25, 125, ... among 1..n).
**Hint 3 (structure):** Since factors of 2 vastly outnumber factors of 5 in any run of consecutive integers, the count of trailing zeros equals the count of factor-5's in n!. Sum floor(n/5) + floor(n/25) + floor(n/125) + ... until the divisor exceeds n.
**Hint 4 (implementation):** Use a running divisor that you multiply by 5 each iteration rather than recomputing powers of 5, and watch for overflow on n if n is large — but the divisor itself grows past n quickly so the loop is short (O(log5 n)).

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Legendre's formula / prime-factor counting without computing the factorial.
- **Core idea:** Trailing zeros = min(count of 2s, count of 5s) in the prime factorization of n!, and 2s are always more abundant, so you only need to count multiples of 5, 25, 125, etc.
- **Algorithm:** 1) count = 0, power = 5. 2) while power <= n: count += n/power (integer division); power *= 5. 3) return count.
- **Complexity:** Time O(log5 n), Space O(1).
- **Gotcha:** Don't double-count — floor(n/25) already includes numbers like 25 contributing an *extra* 5, it's not double-counting the same multiple, it's counting an additional factor from numbers divisible by higher powers of 5.

</details>

---

## Problem 2: 231. Power of Two — Easy
Link: https://leetcode.com/problems/power-of-two/

**Hint 1 (direction):** Think about what a power of two looks like in binary, not in decimal — how many 1-bits does it have?
**Hint 2 (technique):** Use the bit-manipulation trick `n & (n-1)` to strip the lowest set bit.
**Hint 3 (structure):** A power of two has exactly one set bit. So n is a power of two iff n > 0 and `n & (n-1) == 0` (subtracting 1 flips the lowest set bit and everything below it, so ANDing clears it — if that was the only set bit, the result is 0).
**Hint 4 (implementation):** Guard n <= 0 first — the bit trick alone would wrongly accept 0 (since `0 & -1 == 0`), and negative numbers need explicit exclusion too.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** single-set-bit check via `n & (n-1)`.
- **Core idea:** Powers of two have exactly one bit set in binary; `n & (n-1)` clears the lowest set bit, so the result is zero exactly when there was only one bit to begin with.
- **Algorithm:** 1) if n <= 0 return false. 2) return (n & (n-1)) == 0.
- **Complexity:** Time O(1), Space O(1).
- **Gotcha:** Forgetting the n <= 0 guard is the whole bug surface here — everything else is a one-liner.

</details>

---

## Problem 3: 8. String to Integer (atoi) — Medium
Link: https://leetcode.com/problems/string-to-integer-atoi/

**Hint 1 (direction):** This isn't really a math problem, it's a careful state-walk through a string — think about what a real `atoi` implementation has to tolerate: leading noise, a sign, digits, then anything after.
**Hint 2 (technique):** Sequential character-class scanning (whitespace skip -> optional sign -> digit run) with clamping to the 32-bit range.
**Hint 3 (structure):** 1) Skip leading whitespace. 2) Read optional '+'/'-' (at most one). 3) Consume consecutive digit characters, building the number; stop at the first non-digit. 4) Clamp the result to [INT_MIN, INT_MAX] and apply sign. Anything not matching this shape at any point just ends the parse (not an error).
**Hint 4 (implementation):** Clamp *during* accumulation, not just at the end — build with a wider type (int64) or check against `INT_MAX/10` before each multiply so you don't overflow the accumulator itself before you get a chance to clamp.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** finite-state string scan with overflow clamping.
- **Core idea:** The whole problem is bookkeeping discipline — skip whitespace, read at most one sign, greedily consume digits, and clamp to int32 bounds the moment you'd exceed them, ignoring any trailing garbage.
- **Algorithm:** 1) i=0, skip spaces. 2) sign = 1; if s[i] is '+' or '-', set sign, i++. 3) result = 0; while s[i] is digit: d = s[i]-'0'; if result > (INT_MAX - d)/10 (pre-check to avoid overflow), return sign>0 ? INT_MAX : INT_MIN; result = result*10 + d; i++. 4) return sign*result.
- **Complexity:** Time O(n), Space O(1).
- **Gotcha:** Empty digit run after a lone sign (e.g. "+" or "words") must yield 0, and clamping must happen on the *unsigned* magnitude before applying sign — INT_MIN's magnitude (2147483648) exceeds INT_MAX (2147483647), so sign-aware clamping matters.

</details>
