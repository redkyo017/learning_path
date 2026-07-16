# Day 15 — Math & Optimization (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 65. Valid Number — Hard
Link: https://leetcode.com/problems/valid-number/

**Hint 1 (direction):** Don't reach for a regex or a giant pile of nested if-statements from scratch — think about the string as a sequence of *phases* a valid number passes through (sign, digits, decimal point, digits, exponent marker, sign, digits), where certain phases can only appear once and only in certain orders.
**Hint 2 (technique):** Finite-state machine (or a careful single-pass character scan tracking a small set of boolean flags) over the string.
**Hint 3 (structure):** Track flags: seenDigit, seenDot, seenExponent (and reset seenDigit-after-exponent tracking separately). Walk the string once: a sign is only valid at index 0 or immediately after 'e'/'E'; a '.' is only valid if not seen before and no exponent seen yet; 'e'/'E' is only valid if not seen before and at least one digit has been seen before it; any other character invalidates immediately. At the end, the string is valid only if at least one digit was seen (and if an exponent appeared, at least one digit must appear after it too).
**Hint 4 (implementation):** Use two separate "have I seen a digit" trackers conceptually — one for the mantissa (before 'e') and confirm digits exist after 'e' too — a lone "3e" or ".e1" or "e5" must be rejected; also a bare "." with no digits on either side ("." alone) is invalid, but ".5" and "5." are valid.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** finite-state machine / single-pass flag-tracking string validation.
- **Core idea:** A valid number is a strict grammar (optional sign, digits, optional single decimal point, optional single exponent marker followed by optional sign and mandatory digits) — enforce it with a handful of boolean flags updated in one left-to-right pass rather than trying to pattern-match substrings.
- **Algorithm:** 1) seenDigit=false, seenDot=false, seenExp=false. 2) for each char c at index i: if digit, seenDigit=true; else if c is '+'/'-': invalid unless i==0 or previous char is 'e'/'E'; else if c=='.': invalid if seenDot or seenExp, else seenDot=true; else if c is 'e'/'E': invalid if seenExp or !seenDigit, else seenExp=true, reset seenDigit=false (to require digits after exponent); else return false. 3) return seenDigit (true only if digits existed after the last reset).
- **Complexity:** Time O(n), Space O(1).
- **Gotcha:** The exponent case is the trap: after seeing 'e', you must require at least one *new* digit before the string ends — reusing the pre-exponent seenDigit flag without resetting it will wrongly accept malformed strings like "1e".

</details>

---

## Problem 2: 224. Basic Calculator — Hard
Link: https://leetcode.com/problems/basic-calculator/

**Hint 1 (direction):** Parentheses mean you might need to pause evaluating the current expression, dive into a nested one, and come back — what data structure naturally supports "pause here, remember it, resume later" in the right order?
**Hint 2 (technique):** Stack-based expression evaluation, tracking a running result and sign, pushing state on '(' and popping on ')'.
**Hint 3 (structure):** Maintain `result`, `sign` (1 or -1, applied to the *next* number), and a stack. Scan left to right: on digit, accumulate the full multi-digit number; on '+'/'-', apply the pending number*sign to result, then set sign for the next number; on '(', push the current (result, sign) onto the stack and reset result=0, sign=1 for the sub-expression; on ')', apply the final pending number, then pop the outer (savedResult, savedSign) and combine: result = savedResult + savedSign*result.
**Hint 4 (implementation):** Numbers can be multi-digit, so don't apply the sign the instant you see a digit — accumulate the full number across consecutive digit characters first, and only fold it into `result` when you hit a '+', '-', ')', or end of string; also remember to apply the last pending number at the very end of the string (after the loop), since there's no trailing operator to trigger it.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** stack-based recursive-descent-style expression evaluation (no operator precedence needed since only + and - and parens are involved).
- **Core idea:** Since the grammar only has +, -, and parentheses (no * or / to worry about precedence for), you can evaluate left to right with a single running result and sign, using a stack purely to save/restore state across parenthesis boundaries.
- **Algorithm:** 1) result=0, sign=1, num=0, stack=[]. 2) for each char: if digit, num = num*10 + digit. elif '+': result += sign*num; num=0; sign=1. elif '-': result += sign*num; num=0; sign=-1. elif '(': push(result), push(sign); reset result=0, sign=1. elif ')': result += sign*num; num=0; result *= pop(); result += pop(). 3) after loop, result += sign*num (flush last pending number). 4) return result.
- **Complexity:** Time O(n), Space O(n) (stack depth bounded by nesting depth of parentheses).
- **Gotcha:** Forgetting to flush the final pending `num` after the loop ends (e.g. an expression ending in a bare number with no trailing operator) silently drops the last term.

</details>
