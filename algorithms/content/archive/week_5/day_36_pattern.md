# 🌅 Day 7 Wrap-up: The Final Boss
### 🧠 Thought: The Multi-Channel Messenger
In standard problems, recursion usually answers one question: "What is the depth?" or "Is this balanced?" In Day 7, we realized a single recursive call can do two things at once.

- In Max Path Sum, the function returns the best straight line (local info for the parent) while simultaneously checking if the full path through the node (global info) is the world record.
- In Serialization, the "X" or "null" markers aren't just characters—they are structural signals that tell the reconstruction algorithm exactly when to stop building a branch and "pop" back up.

### 🧘 Mindset: Global vs. Local Responsibilities
Hard problems often feel overwhelming because we try to solve the whole tree at once. The "Hard" mindset is about strict delegation:
- The Global State: "I will keep one variable (maxSum) to record the best thing I've ever seen across the entire tree."
- The Local Promise: "Each node only has to worry about its own value and what its immediate children tell it. If my children provide negative value, I ignore them."
- The Format Contract: "I promise to deserialize exactly how I serialized. If I put the root first in the string, I must read the root first in the reconstruction."

### 🛠️ Pattern: Post-order Updates & Sentinel Reconstruction
1. Post-order Return-Update:
``` Go
// Get info from children first
left := max(0, dfs(node.Left))
right := max(0, dfs(node.Right))
// Update global record using the "Split" path
globalMax = max(globalMax, node.Val + left + right)
// Return the "Single" path to the parent
return node.Val + max(left, right)
```
2. Pre-order Sentinel Reconstruction: Using a marker (like "X") to represent nil turns a non-linear tree into a linear sequence that can be parsed with a single pass. The sentinel acts as a "close bracket" for your recursion.