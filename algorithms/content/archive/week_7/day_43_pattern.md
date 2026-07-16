🏁 Day 1 Wrap-up: Thought, Mindset, and Pattern
Congratulations on finishing the first day of Graph Week! Here is the compaction of what we mastered today:
- The Pattern: Grid Traversal (DFS/BFS) * Used for exploring contiguous regions in a 2D array.
    - Crucial Mechanic: You must have a way to avoid revisiting nodes (either a visited set/matrix or by "sinking" the island by changing the input value).
- The Mindset: Connectivity
    - Unlike Trees, Graphs don't have a "Root." We use a nested loop to find a starting point, and the traversal finds everything connected to it.
    - Infinite Loop Prevention: If the target state (like a new color) is the same as the current state, you must exit early to prevent a recursive death-spiral.
- The Technique: Result Accumulation
    - To count or sum properties of a graph component, use the return value of the recursive function (1 + dfs(neighbors)) rather than passing a counter down as a parameter.

Key Takeaway: You have transitioned from hierarchical data (Trees) to interconnected data (Graphs).