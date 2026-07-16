# 🌅 Day 4 Wrap-up: Thought, Mindset, and Pattern
You’ve mastered the "Horizontal" perspective of trees today

### 🧠 Thought: The Level-Order SnapshotThe defining thought for today was: "How do I isolate one floor of the building?" The for $i := 0; i < l; i++$ loop inside the while queue loop is the standard tool for this. It allows you to perform logic that depends on level boundaries (like zigzagging or picking the rightmost node).

### 🧘 Mindset: Choose Your Tool (BFS vs. DFS)
- BFS is usually the "default" for level-based problems, but it can consume a lot of memory for very wide trees ($O(W)$).
- DFS can solve many level problems (like Right Side View) with less memory ($O(H)$) if you track the depth and visit children in a specific order.

### 🛠️ Pattern: Queue-Based BFS Template
- Initialize: Queue with root.
- Level Loop: Capture size := len(queue).
- Process Level: Iterate size times, pop nodes, and add their children.
- Level Logic: Perform specific tasks (like res = append(res, layer)) after the inner loop finishes.