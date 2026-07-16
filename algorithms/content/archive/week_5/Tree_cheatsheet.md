# 🌲 Tree Week: The Ultimate Cheat Sheet
1. The "Big Three" Traversals
- Inorder (Left, Root, Right): The "BST Cheat Code." Always results in sorted order for BSTs. Use for 98. Validate BST and 230. Kth Smallest.
- Pre-order (Root, Left, Right): The "Structure Builder." Best for cloning or serializing. Use for 297. Serialize/Deserialize and 105. Construction.
- Post-order (Left, Right, Root): The "Bottom-Up Reporter." Use when a parent needs information from its children to make a decision. Use for 543. Diameter and 124. Max Path Sum.

2. Recursive Strategy: The "Three Questions"
When writing a tree DFS, always ask:
    1. Base Case: What do I return for a nil node? (Usually 0, true, or nil).
    2. Recursive Call: What info do I need from my Left and Right children?
    3. Return Value: What do I send back up to my parent?

3. BFS (Level Order) Template
Always use a Queue. Capture the levelSize at the start of the for loop to process the tree one "floor" at a time. This is essential for 102. Level Order and 199. Right Side View.


### 🛠️ Tree Week: The Pattern Cheat Sheet
Before we dive into the code, let’s look at the "Big 4" patterns you've mastered this week:
|Pattern|Best For...|Key Tool|
---|---|---
DFS (Depth First)|Paths, Sums, Validation|Recursion / Stack
BFS (Breadth First)|Level-order, Shortest Path|Queue
Inorder (BST)|Sorted data, Kth smallest|Left → Root → Right
Post-order|Bottom-up info (like Max Path)|Process children 