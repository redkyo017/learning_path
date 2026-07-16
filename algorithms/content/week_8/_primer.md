# Primer: Math & Optimization

**Core idea:** many problems reduce to a mathematical property or invariant (digit
manipulation, bit tricks, number theory) rather than a clever data structure. The "aha" is
almost always in reasoning about the numbers themselves first.

**Recognize by:** the problem talks about integers/digits/primes/powers, or asks you to
compute something without extra space, or in O(log n) via repeated halving/doubling.

**Mental model:** before reaching for a hash map or array, ask: what's the mathematical
structure here — parity, modular arithmetic, binary representation, place value? Fast
exponentiation (Pow(x,n)) and digit-DP-style problems both come from "can I halve the work
each step instead of doing it linearly."

**Pitfalls:** integer overflow (know your language's int bounds), off-by-one when extracting
digits (`n % 10` then `n /= 10` loops), forgetting sign/zero/negative edge cases.
