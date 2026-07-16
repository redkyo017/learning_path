# 🏁 Wrap-up: Week 6 | Day 2

### Thought & MindsetToday was about Stateful Traversal. In the past, we let the "Recursion Stack" handle the state for us. Today, you built a manual stack to pause and resume a traversal. This is a critical skill for building iterators, stream processors, or any system where you can't load all data into memory at once.

### The Pattern: Controlled Stack Inorder
The key to "flattening" a BST into an iterator without using $O(N)$ space is the Push-Left strategy:
1. Go as far left as possible (smallest values first).
2. When you "consume" a node (Root), immediately pivot to its Right child and repeat the "Push-Left" process.This ensures you always have the next smallest value ready at the top of the stack.