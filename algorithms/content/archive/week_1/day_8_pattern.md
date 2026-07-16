# 🧠 Pattern: Expand Around Center

You have just implemented the Expand Around Center pattern, which is the most intuitive and clean way to solve this problem.

**The Intuition: The Center is Key**

Any string of length $N$ has $2N - 1$ possible centers:
- $N$ centers at single characters (for odd palindromes).
- $N-1$ centers in the gaps between characters (for even palindromes).

If we iterate through all $2N - 1$ potential centers, and for each one, we expand the pointers outwards, the total time complexity will be $O(N^2)$ because:

- We run the helper function $2N - 1 \approx O(N)$ times.
- The helper function runs at most $O(N)$ comparisons.
- Total Time: $O(N) \times O(N) = O(N^2)$.

**Contrast with Dynamic Programming (DP)**

|Feature|Expand Around Center|Dynamic Programming (DP)|
|---|---|---|
|Complexity|Time: $O(N^2)$, Space: $O(1)$ (or $O(N)$ for result)|Time: $O(N^2)$, Space: $O(N^2)$|
|Approach|Two Pointers/Greedy: Check all possibilities by expanding from the center.|Look-up Table: Build up the solution from smaller subproblems (is s[i:j] a palindrome?).|
|Google Preference|Often preferred for its $O(1)$ space and simplicity during whiteboarding.|Requires more state and careful indexing.|

# 🧠 Pattern: Dynamic Programming (Bottom-Up)

**The Intuition: The Truth Table**
The core idea of DP here is to create a 2D boolean table, $P$, where:
    $$P[i][j] = \begin{cases} \text{true} & \text{if the substring } s[i..j] \text{ is a palindrome} \\ \text{false} & \text{otherwise} \end{cases}$$
    
Instead of checking every possible substring from scratch, we rely on a recurrence relation:
    $$\text{Palindrome at } s[i..j] \text{ is TRUE if:}$$

1.The end characters match: $s[i] == s[j]$
2.The inner substring is also a palindrome: $P[i+1][j-1]$ is $\text{true}$

### 🏗️ Step-by-Step DP Implementation
The DP table is usually built **Bottom-Up**, from the smallest substrings to the largest.

**Step 1: Initialization (Base Cases)**

We start with substrings of length 1 and 2, which don't require checking a smaller inner substring.

**Case 1: Length 1**
- Any single character is a palindrome.
- $P[i][i] = \text{true}$ for all $i$.
**Case 2: Length 2**
- The substring $s[i..i+1]$ is a palindrome if $s[i] == s[i+1]$.
- $P[i][i+1] = (s[i] == s[i+1])$

**Step 2: Recurrence (Length $\ge 3$)**

We iterate through substring length $L$ from 3 up to $N$.
For a fixed length $L$, the starting index $i$ goes from $0$ to $N-L$.The ending index $j$ is calculated as $j = i + L - 1$.
The **Recurrence Relation** is applied:
    $$P[i][j] = (s[i] == s[j]) \land P[i+1][j-1]$$
This works because when we calculate $P[i][j]$, we are guaranteed that $P[i+1][j-1]$ (the inner substring, which is shorter) has already been computed.

**Step 3: Tracking the Result**
During the calculation, every time we set $P[i][j] = \text{true}$, we compare the current length $(L)$ with the max_length found so far, updating the start_index and max_length if $L$ is greater.


## 🆚 DP vs. Expand Around Center
|Feature|DP (Bottom-Up)|Expand Around Center|
|---|---|---|
|Time Complexity|$O(N^2)$ (Guaranteed)|$O(N^2)$ (Guaranteed)|
|Space Complexity|$O(N^2)$ (For the 2D DP table)|$O(1)$ (No auxiliary storage needed)|
|Mindset|Building History: Compute smaller results first, then use them for larger results.|Greedy Optimization: Check every center point, expand as far as possible.
|Typical Interview Choice|DP is chosen when the next step must rely on a previous, specific result (e.g., Matrix Chain Multiplication).|Expand Around Center is often preferred for Palindromes due to its $O(1)$ space.|