# 🧠 Pattern 1: The "Complement" Search (Hash Maps)
*Found in*: Two Sum, 3Sum, 4Sum II, Subarray Sum Equals K.

*The Intuition*
In a brute-force approach (nested loops), you pick a number $A$ and then scan the entire rest of the array looking for $B$ such that $A + B = Target$. This is slow ($O(N^2)$) because you are repeatedly searching for information you've already seen.
The key insight is rewriting the equation:
$$B = Target - A$$
Instead of "searching for a pair," you are asking: "Have I seen the complement of my current number before?"

#### When to use this pattern:
1. Relationship Check: You need to find elements that relate to each other (sum, difference, pair).
2. Unsorted Data: You cannot use Two Pointers (start/end) because the array isn't sorted, and sorting it would take too long ($O(N \log N)$).
3. History Lookup: You need to access past elements instantly ($O(1)$).

*Why Google Loves It:*
It tests your ability to Trade Space for Time. You accept $O(N)$ space complexity (the map) to achieve $O(N)$ time complexity. This is a fundamental engineering trade-off.
# 🧠 Pattern 2: The "LIFO" Dependency (Stacks)
*Found in*: Valid Parentheses, Calculator Problems, HTML/XML Parsing, Recursion.

*The Intuition*
Imagine you are peeling an onion. You cannot touch the inner layers until you peel the outer ones. Conversely, you can't close the outer layer until the inner layer is finished.
This represents nested dependencies. The "Last" thing you started (the most recent opening bracket) must be the "First" thing you finish (the next closing bracket).
#### When to use this pattern:
1. Nested Structures: Anything involving brackets (), hierarchy, or directory paths (e.g., cd /a/b/../c).
2. Matching Pairs: When an "opening" event must wait for a "closing" event, and they can be nested.
3. Reversing Order: When you need to process things in reverse order of how they arrived.

*Why Google Loves It:*
It tests your understanding of local vs. global state. You don't care about the first bracket you saw; you only care about the most recent one. This mimics how compilers and browser history work.
📊 Summary: How to Spot Them

| If the problem asks... | And the data is...| Think... |
|---|---|---|
|Find a pair/triplet that sums to X|Unsorted|Hash Map (Complement Search)
|Find a pair/triplet that sums to X|Sorted|"Two Pointers (Coming in Week 1, Day 3)"
|Validate the order/structure||Sequential/Nested|Stack
|Find the 'Next Greater Element'|Sequential| Monotonic Stack (Coming in Week 4)