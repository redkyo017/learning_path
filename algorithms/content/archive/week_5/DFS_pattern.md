# DEPTH FIRST SEARCH
Depth-First Search (DFS) is a problem-solving mindset of "go deep before going wide," exploring one path to its end before backtracking, like navigating a maze by always turning down a new path until a dead end, then retracing steps to find another route. The thought process involves recursion or a stack to manage this "go deep" action, asking what information is needed from the parent (previous sum/state) and what to return (current path/subtree info). The pattern is used for finding paths, connectivity, cycles, or solving problems solvable by exploring all possibilities deeply (e.g., permutations, subsets, tree traversals like preorder/inorder/postorder). 

## Thought Process & Mindset
- "Go Deep First": Don't explore neighbors broadly; pick one neighbor and explore its entire branch.
- Backtracking: When you hit a dead end (no unvisited neighbors), return (backtrack) to the last decision point and try another option.
- Recursion/Stack: This naturally maps to recursive function calls or using an explicit stack data structure (LIFO - Last In, First Out) to remember where to return.
- State Management: Crucial questions: What info does a node need from its parent (e.g., accumulated sum, visited status)? What does it pass back up (e.g., subtree total)?.
- Avoid Loops: Keep track of visited nodes to prevent infinite cycles in graphs. 

## Core Patterns & Applications
- Maze Solving/Pathfinding: Find a path (not necessarily shortest).
- Connectivity: Detect if two nodes are connected or find connected components in a graph.
- Cycle Detection: Identify loops in graphs.
- Tree Traversal (Pre/In/Postorder): Systematic ways to visit nodes.
- Backtracking Problems: Generating permutations, subsets, solving N-Queens, Word Search.
- Graph Representation: Models exploring a huge graph by breaking it down recursively. 

## How It Works (Conceptual)
- Start: Pick a node and go down one path as far as possible.
- Explore: At each node, push it onto the stack and explore one of its unvisited neighbors.
- Dead End: If no unvisited neighbors, pop the node (backtrack) and try another neighbor of the node below it.
- Repeat: Continue until the stack is empty. 

