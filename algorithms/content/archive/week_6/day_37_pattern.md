# 🏁 Wrap-up: Week 6 | Day 1
### Thought & Mindset
Today was about moving from Reading (Week 5) to Writing (Week 6). In Binary Search Trees, modification isn't just about changing a value; it's about maintaining a specific mathematical invariant.

### The Pattern: "Return-to-Parent" (Recursive Re-wiring)
When modifying trees in languages with pointers (like Go), the cleanest pattern is: node.Child = function(node.Child, target)

This removes the need to track the "Parent" node manually. Instead, the recursion handles the parent-child relationship for you. If you delete a node, you return nil to the parent; if you insert, you return the new node to the parent; otherwise, you return the existing node to keep the link intact.