# 🌅 Day 3 Wrap-up: Thought, Mindset, and Pattern
You’ve successfully transitioned from "Analyzing" trees to "Building and Searching" them. Here is the summary for Day 3:

### 🧠 Thought: The Recursive "State"
In tree problems, your function arguments often represent the state. In SortedArrayToBST, the state was the current range of the array. In Path Sum, the state was the remaining sum needed.

### 🧘 Mindset: Construction is just "Middle-Out"
When building a balanced tree from a sorted source, the mindset is always: The middle is the boss. Once you pick the middle, the left and right subtrees become independent sub-problems that follow the exact same rule.

## 🛠️ Pattern: Root-to-Leaf Path Traversal
To validate a path property:
1. Nil check: Handle empty branches (usually return false or a neutral value).
2. Leaf check: The logic only "finalizes" when left == nil && right == nil.
3. Accumulation/Reduction: Pass a value down (like targetSum - root.Val) to keep track of progress without needing global variables.