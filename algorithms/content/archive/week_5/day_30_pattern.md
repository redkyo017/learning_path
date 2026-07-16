# 🌅 Day 1 Wrap-up: Thought, Mindset, and Pattern

### 🧠 Thought: Moving from Linear to Hierarchical
In previous weeks, we dealt with "Next" or "Previous" (Arrays/Lists). Today, you shifted your thinking to "Left" and "Right." You've learned that tree problems are essentially sub-problems; if the left and right subtrees satisfy a condition, the root can then satisfy that condition.

### 🧘 Mindset: The Power of the Base Case
Tree recursion lives or dies by its base cases.
- The "Both Null" Case: Usually means you've reached the end of a path successfully (Return true).
- The "One Null/Mismatch" Case: Usually means the structural or value-based symmetry has broken (Return false). Always define these before you write the recursive step.

### 🛠️ Pattern: The "Mirror" and "Identity" Checks
- Identity (Same Tree): Compare p.left with q.left and p.right with q.right.
- Mirror (Symmetric Tree): Compare p.left with q.right and p.right with q.left.
- Iterative DFS: Using a stack to simulate recursion is a high-signal skill for Google interviews, especially for inorder traversals.
