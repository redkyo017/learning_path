# Day 14 — Math & Optimization (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 50. Pow(x, n) — Medium
Link: https://leetcode.com/problems/powx-n/

**Hint 1 (direction):** Multiplying x by itself n times is correct but wasteful — the primer's "halve the work each step" idea applies directly here. What does x^8 have in common with (x^4)^2?
**Hint 2 (technique):** Fast exponentiation (exponentiation by squaring), iterative or recursive.
**Hint 3 (structure):** Recursively: pow(x, n) = pow(x, n/2)^2, with an extra factor of x multiplied in if n is odd. Base case pow(x, 0) = 1. Handle negative n by computing pow(1/x, -n) (or pow(x, -n) and inverting at the end).
**Hint 4 (implementation):** n = INT_MIN is the classic trap: `-n` overflows a 32-bit int, so cast n to a wider type (int64) before negating, or handle the sign using unsigned magnitude arithmetic.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** exponentiation by squaring (binary exponentiation).
- **Core idea:** x^n can be computed in O(log n) by recursively squaring: halve the exponent each step, and only multiply in one extra x when the exponent is odd — this mirrors binary representation of n.
- **Algorithm:** 1) if n < 0, convert to computing 1/x raised to -n (using a widened type for -n). 2) iterative version: result = 1, base = x, exp = n; while exp > 0: if exp is odd, result *= base; base *= base; exp /= 2. 3) return result (inverted if original n was negative).
- **Complexity:** Time O(log n), Space O(1) iterative (O(log n) recursion stack if recursive).
- **Gotcha:** Negating INT_MIN overflows; also x = 0 with negative n (division by zero) and x = 0, n = 0 (define as 1) are edge cases worth a deliberate check.

</details>

---

## Problem 2: 43. Multiply Strings — Medium
Link: https://leetcode.com/problems/multiply-strings/

**Hint 1 (direction):** You can't parse these into native integers (they're described as arbitrarily long) — think back to how you multiply two numbers by hand on paper, digit by digit, and where each partial product's contribution lands.
**Hint 2 (technique):** Simulate grade-school long multiplication into a result digit array, using index arithmetic to place each digit-pair product.
**Hint 3 (structure):** For two numbers of length m and n, the result has at most m+n digits. For every pair of digits (i from num1, j from num2), their product contributes to result positions i+j and i+j+1 (tens and units of that partial product), accumulated with carries resolved at the end (or as you go).
**Hint 4 (implementation):** The key index identity: multiplying digit at position i (from the end, or from num1's index) with digit at position j lands its contribution at `result[i+j+1]` (low digit) and adds carry into `result[i+j]` (high digit) — get this indexing right and initialize the result array to size m+n filled with zeros; strip leading zeros (but keep at least one digit) before returning.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** manual long multiplication into a fixed-size digit accumulator array.
- **Core idea:** Represent the product in a result array of length len(num1)+len(num2); each digit-pair multiplication's result is added into two adjacent positions of that array (mimicking carrying in hand multiplication), and a final carry-cleanup pass converts it to a valid digit string.
- **Algorithm:** 1) result = array of zeros, size m+n. 2) for i from m-1 down to 0: for j from n-1 down to 0: mul = digit(num1[i]) * digit(num2[j]); p1 = i+j, p2 = i+j+1; sum = mul + result[p2]; result[p2] = sum % 10; result[p1] += sum / 10. 3) Build string from result skipping leading zeros; if all zero, return "0".
- **Complexity:** Time O(m*n), Space O(m+n).
- **Gotcha:** Forgetting to strip leading zeros produces wrong output for cases like "0" * anything or when the true product has fewer digits than m+n; also don't forget `result[p1] += ...` (accumulate, don't overwrite) since multiple partial products can land on the same index.

</details>

---

## Problem 3: 204. Count Primes — Medium
Link: https://leetcode.com/problems/count-primes/

**Hint 1 (direction):** Testing each number below n for primality individually (even with trial division) will be too slow at scale — think about eliminating composites in bulk instead of testing numbers one at a time.
**Hint 2 (technique):** Sieve of Eratosthenes.
**Hint 3 (structure):** Create a boolean array of size n, initially all "possibly prime." Starting from 2, for each number still marked prime, mark all of its multiples (starting from its square) as composite. Count remaining unmarked entries.
**Hint 4 (implementation):** Two easy-to-miss optimizations/edge cases: only need to sieve up to sqrt(n) as the outer loop bound (multiples of anything larger were already struck by smaller factors); start marking multiples from `i*i` (not `2*i`) since smaller multiples were already struck by smaller primes; and remember the count is primes *less than* n, so n and n-1 need care (n itself is excluded, array size n covers indices 0..n-1).

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Sieve of Eratosthenes.
- **Core idea:** Instead of checking each number for primality independently, mark off all multiples of each found prime in one pass; every composite gets crossed out by its smallest prime factor, so the total work across all primes is near-linear.
- **Algorithm:** 1) if n < 3 return 0. 2) isComposite = array[0..n-1] all false. 3) for i from 2 to sqrt(n): if not isComposite[i]: for j from i*i to n-1 step i: isComposite[j] = true. 4) count entries from 2 to n-1 where isComposite is false.
- **Complexity:** Time O(n log log n), Space O(n).
- **Gotcha:** The problem asks for primes strictly less than n (not <= n) — off-by-one here silently over/under-counts by exactly one prime near the boundary.

</details>
