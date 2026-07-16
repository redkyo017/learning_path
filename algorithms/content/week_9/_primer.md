# Primer: Dynamic Programming Fundamentals

**Core idea:** DP = recursion + memoization (cache subproblem results) or the equivalent
bottom-up table build. It applies when a problem has *optimal substructure* (the optimal
answer is built from optimal answers to smaller subproblems) and *overlapping subproblems*
(the naive recursion recomputes the same subproblem many times).

**Recognize by:** "count the number of ways to...", "minimum/maximum cost to reach...", or a
sequence of decisions (take/skip, buy/sell, climb 1 or 2 steps) where later choices depend on
the state left behind by earlier ones.

**Mental model — always answer these three before coding:**
1. **State:** what varies between subproblems? (e.g. "current index", "remaining capacity")
2. **Transition:** how do you compute `state[i]` from smaller states?
3. **Base case:** what's the smallest subproblem you can answer directly?
Then decide: top-down (recursion + memo table) or bottom-up (iterative array/table fill) —
same logic, different control flow.

**Pitfalls:** picking a state that's too thin (loses information you need) or too fat (blows
up time/space); forgetting the base case; off-by-one between "prefix of length i" and "index
i" when sizing the DP array (usually want size n+1, not n).
