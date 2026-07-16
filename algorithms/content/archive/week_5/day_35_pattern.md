# 🌅 Day 6 Wrap-up: Thought, Mindset, and Pattern
BSTs are all about exploiting order.

### 🧠 Thought: The Inorder Secret
Every time you see "BST" and "Sorted" or "Kth" in the same sentence, your brain should immediately think Inorder Traversal. It turns a complex tree into a simple sorted list.

### 🧘 Mindset: Use the Property to Prune
In the LCA problem, we didn't search the whole tree; we used the node values to decide which half to throw away. This is the "Binary Search" part of Binary Search Trees.

### 🛠️ Pattern: Range Boundaries
For validation or searching within limits, passing min and max (ideally as pointers to handle nil boundaries) is the most robust way to ensure global constraints are met.