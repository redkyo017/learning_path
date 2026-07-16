# Dynamic programming

Dynamic Programming (DP) is an algorithmic technique for solving complex problems by breaking them down into simpler, overlapping subproblems. It leverages the solutions of these subproblems to construct the solution for the original problem, avoiding redundant computations. 

### Key Characteristics of Problems Solvable with Dynamic Programming:

- Optimal Substructure: The optimal solution to the overall problem can be constructed from the optimal solutions of its subproblems.
- Overlapping Subproblems: The problem can be broken down into smaller subproblems that are solved multiple times during a recursive approach. 

### How to Apply Dynamic Programming:
- **Identify the State**: Define what information needs to be stored to solve the subproblems. This often involves one or more variables representing the current "state" of the problem. For example, in the Fibonacci sequence, the state is simply the index n.
- **Define the Recurrence Relation (State Transition Equation)**: Establish a mathematical relationship that expresses the solution of a larger problem in terms of the solutions of its smaller subproblems. This is the core of the DP solution.
- **Determine the Base Cases**: Identify the simplest subproblems whose solutions are known directly without further recursion. These are the stopping conditions for your recurrence.
- **Choose an Approach**:
    - **Memoization (Top-Down)**: This involves a recursive approach where you store the results of subproblems in a cache (e.g., an array or hash map) as they are computed. If a subproblem is encountered again, its pre-computed result is retrieved from the cache instead of recomputing it. 
    ```
        memo = {}
        def fib_memo(n):
            if n <= 1:
                return n
            if n in memo:
                return memo[n]
            memo[n] = fib_memo(n-1) + fib_memo(n-2)
            return memo[n]
    ```
    - **Tabulation (Bottom-Up)**: This involves an iterative approach where you solve subproblems starting from the base cases and build up to the solution of the original problem. This typically involves filling a DP table (array or matrix) iteratively. 
    ```
        def fib_tab(n):
            if n <= 1:
                return n
            dp = [0] * (n + 1)
            dp[1] = 1
            for i in range(2, n + 1):
                dp[i] = dp[i-1] + dp[i-2]
            return dp[n]
    ```
    - **Handle Base Cases**: Define the solutions for the simplest subproblems, which serve as the starting point for the recurrence relation.
    - **Construct the Solution**: Use the stored solutions of subproblems to arrive at the final solution for the original problem.


# 🧠 The DP Mindset: Thinking Recursively, Solving Iteratively
    
**1.Identify the Substructure (The "Overlapping Subproblems" Test)**
    
The first step is to ask: Can the solution to the big problem be built directly from the solutions to smaller versions of the same problem?

- Longest Palindromic Substring: Yes.
    - The question: "Is $s[i..j]$ a palindrome?"
    - The answer depends on a smaller problem: "Is the inner substring $s[i+1..j-1]$ a palindrome?
- "If $s[i]$ matches $s[j]$, the answer to the big problem is the same as the answer to the small problem. This recursive dependency is the DP trigger.

**2.Define the State (The DP Array)**

Once you've identified the substructure, you need a way to store the answers to those small subproblems. This is your DP table (or array).

- What information do you need to cache? For this problem, you need to cache a boolean value: is it a palindrome?
- How many variables define a subproblem? A substring is defined by its start index ($i$) and end index ($j$).
- The State Definition: $\mathbf{DP[i][j]}$ will store a true or false value indicating if $s[i..j]$ is a palindrome.

**3. Establish the Recurrence Relation (The Rule)**

This is the mathematical or logical rule that connects the large problem to the small problem.
- Recurrence: $DP[i][j] = (s[i] == s[j]) \land DP[i+1][j-1]$
    - It reads: "The substring from $i$ to $j$ is a palindrome if 1) the outside characters match AND 2) the substring inside of them is also a palindrome."
    
**4.Determine the Order of Computation (The Bottom-Up Build)**

You must compute the DP table in an order that ensures that when you calculate $DP[i][j]$, the required smaller value, $DP[i+1][j-1]$, has already been computed.
- $DP[i+1][j-1]$ is a shorter substring than $DP[i][j]$.
- Conclusion: You must solve the problem by increasing length ($L$) first.

|Order of Iteration|Why it Works|
|---|---|
|Outer Loop: Length ($L=1$ to $N$)|Ensures we compute smaller lengths before larger ones.|
|Inner Loop: Start Index ($i=0$ to $N-L$)|Ensures we cover all possible substrings for the current length.|
|Calculated Index: End Index ($j=i+L-1$)|The indices move diagonally across the table, always relying on values already computed (above and to the left).|

## 💡 Summary: The "When to DP" Check

You should consider DP when a problem satisfies these conditions:
- Optimal Substructure: A global optimal solution can be constructed from optimal solutions of its subproblems (e.g., the longest path, the minimum cost).
- Overlapping Subproblems: The recursive solution repeatedly solves the exact same subproblems (this is why we use the DP table to memoize the results).

For the Palindromic Substring problem, while the Expand Around Center approach is often preferred for its $O(1)$ space, the DP approach is the clearest demonstration of these two core principles.