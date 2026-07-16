# 🌅 Day 2 Wrap-up: Thought, Mindset, and Pattern
You've completed the "Verticality" phase of trees! Here is your summary.

### 🧠 Thought: BFS for Shortest, DFS for Longest
- Max Depth: DFS (Recursive) is intuitive, but **iterative DFS requires a stack with pairs.**
- Min Depth: BFS is king. You stop the moment you see the first leaf, making it potentially much faster than DFS.

### 🧘 Mindset: Don't Recalculate
In the **Balanced Tree** problem, the naive approach is $O(N^2)$ because it calls height() inside every recursive call. The "Google Mindset" is to ask: "Can I calculate the height and check balance at the same time?" This brings you to $O(N)$.
### 🛠️ Pattern: The Bottom-Up Sentinel
When you need to validate a property (like balance) while calculating a value (like height), use a Sentinel Value (like -1 or INT_MIN) to "short-circuit" the recursion once a violation is found.