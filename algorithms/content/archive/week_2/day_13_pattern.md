# 💡 Pattern Summary: Prefix Sums with Hash Maps

This pattern is a powerful technique for solving problems that ask for the sum of a subarray (a contiguous segment) or sub-matrix in $O(N)$ time.

**The Thought Process & Mindset**

When you see a problem asking:
- "Count the number of subarrays where Sum = $k$.""Find the longest subarray where Sum $\leq k$."
- "Find the subarray with the maximum sum.
- "Your mind should immediately go to Prefix Sums.


# 🧠 Pattern: Prefix Sums + Hash Table

**1. The Intuition (The Mathematical Transformation)**

The brute-force way to find the sum of every subarray is $O(N^2)$. Prefix Sums reduces this to $O(N)$:

Let $P(j)$ be the sum of nums[0...j].The sum of any subarray nums[i...j] is calculated as:
    $$\text{Sum}(i, j) = P(j) - P(i-1)$$
    
When the problem requires $\text{Sum}(i, j) = k$, we substitute $k$:
    $$k = P(j) - P(i-1)$$
This equation reveals the single value we need to efficiently look up in the past:    
    $$P(i-1) = P(j) - k$$

The problem is now transformed into: "As I iterate and calculate $P(j)$ (the current sum), how many times has the required value $P(j) - k$ occurred in my past?"

**2. The Implementation (The Hash Map)**

The Hash Map (prefixSumFreqTable) is used to store the history of prefix sums encountered so far.

|Part|What it Stores|Why|
|---|---|---|
|Key|The value of the Prefix Sum ($P$)|Allows $O(1)$ lookups for the required past sum ($P(j)-k$).|
|Value|The Frequency (count) of that $P$|Tells us how many subarrays we just found (since each previous occurrence of $P(j)-k$ is the start of a new valid subarray).|

**3. The Crucial Initialization Edge Case**

    Map Initialization: prefixSumFreqTable[0] = 1

This step is critical because it allows us to count subarrays that start at index 0.
- If $P(j) = k$, then $P(j) - k = 0$.
- By initializing the map with a count of 1 for $P=0$, when $P(j)=k$, we correctly find that the required past sum of 0 has been seen once (representing the empty prefix before the array starts), counting the subarray nums[0...j].

This pattern ensures $O(N)$ time complexity, making it the optimal solution.