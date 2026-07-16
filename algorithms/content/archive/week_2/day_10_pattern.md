# 🧠 Pattern: Hash Set for $O(1)$ Set Operations

You used this pattern in Intersection of Two Arrays to achieve maximum efficiency.
**The Intuition: Instant Membership Check**

A Hash Set (or a map used as a set, like map[int]bool in Go) is the fundamental tool for solving problems that involve set theory concepts:
1. Union: Combine unique elements from two lists.
2. Intersection: Find common elements in two lists.
3. Difference: Find elements in one list but not the other.
4. Uniqueness: Ensure a list contains no duplicates.

**The Efficiency Advantage:**
|Feature|Hash Set (map[T]bool)|List/Array Search|
|---|---|---|
|Membership Check|$O(1)$ average time|$O(N)$ linear time|
|Adding a Unique Element|$O(1)$ average time|$O(N)$ (check for existence first)
|Space|$O(N)$ where $N$ is unique elements|$O(N)$\

The key interview tip is the space optimization: when comparing two arrays of size $N$ and $M$, always create the Hash Set from the smaller array ($\min(N, M)$) to minimize auxiliary space.

# 💡 Pattern: Cycle Detection via State Tracking
You used this pattern in Happy Number to ensure the process terminates.

**The Intuition: If it Repeats, it's a Loop**

In certain iterative algorithms, the state (the current number in Happy Number) can only take on a finite number of possible values. If the process does not terminate at a known end state (like 1), it must eventually repeat a state it has visited before, entering an infinite loop.

**The Implementation:**
1. Initialize a visited Hash Set.
2. In a while loop, before calculating the next state:
    - Check if the current state is in visited. If yes, a cycle is found $\rightarrow$ return false.
    - If no, add the current state to visited.
    - Calculate the next state.
3. Define the loop's termination condition (e.g., n == 1 for Happy Number). If the loop terminates naturally, return true.

**Alternative Cycle Detection:** While the Hash Set method is universally applicable and easy to implement, there is another $O(1)$ space technique for cycle detection called the Floyd's Tortoise and Hare (Slow/Fast Pointers) Algorithm. We will use this in a future day when we cover linked lists, but it can also be applied here!