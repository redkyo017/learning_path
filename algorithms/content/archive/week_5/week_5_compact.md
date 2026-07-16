# 💾 Week 4 Compaction Summary (Trees)
Copy the block below for your next session context.

## 💻 Google Interview Prep: Tree Week Summary (Days 22-28)
Completed all 18 core Tree problems| including Hard tier.

Day|Focus Topic|Problems Solved|Core Pattern|Complexity
---|---|---|---|---|
Day 1|BFS/DFS Basics|"102. Level Order, 104. Max Depth, 226. Invert Tree"|"Level-Order Queue, Recursive DFS"|O(N)
Day 2|Balance & Path|"110. Balanced Tree, 543. Diameter, 112. Path Sum"|"Bottom-up Height Check, Global Max Tracking"|O(N)
Day 3|Ancestors|"236. LCA, 572. Subtree of Another Tree"|"Path Bubbling, Recursive Identity Check"|O(N)
Day 4|Views|199. Binary Tree Right Side View|BFS Level-End Capture / DFS Depth-Map|O(N)
Day 5|Structure|"114. Flatten, 116. Next Pointers, 105. Construct Tree"|"Reverse Post-order, Pointer Stitching, Map-Inorder"|O(N)
Day 6|BST Logic|"98. Validate BST, 235. LCA (BST), 230. Kth Smallest"|"Range Boundaries, Split-point Logic, Inorder Counter"|O(H)
Day 7|Hard Boss|"124. Max Path Sum, 297. Serialize/Deserialize"|"Post-order ""Gain"" vs ""Split"", Sentinel Pre-order"|O(N)

**Key Technical Takeaways:**
- Pointer Management: Mastered in-place tree mutation (Flattening) and iterative $O(1)$ space connectivity.
- Sentinel Values: Used "X" or "null" in serialization to represent structure in a 1D string.
- BST Optimization: Utilized $Left < Root < Right$ to prune search spaces and validate constraints via pointers (*int) to handle MinInt64 edge cases.
- Go Specifics: Optimized string building with strings.Join and used closure-based recursion with slice pointers for "Read-Head" state management.

**Mindset**: Focused on identifying whether info flows "Top-Down" (Level-order/Prefix) or "Bottom-Up" (Post-order/Path Sums).

Final Thought Before Graphs
In Trees, you always had a single "Root" and a clear downward direction. In Graphs, you will lose those luxuries. You’ll need to track "Visited" nodes to avoid infinite loops and handle multiple disconnected "Islands" of data.