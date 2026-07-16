# Graph Algorithms

To master Graph Data Structures (GDS) and algorithms, you must move away from "linear thinking" (arrays/lists) and adopt relational thinking. In 2026, this remains the most critical skill for solving complex problems like network routing, social mapping, and dependency resolution.

## 1. The Mindset: Transformation of State
When approaching a graph problem, your mindset should be: "Everything is a State, and every Edge is a Transition."
- Nodes represent "States": A coordinate on a map, a person in a network, or a step in a process.
- Edges represent "Possibilities": A road connecting cities, a friendship, or a legal move in a game.
- The Problem is "Search": Most graph problems are simply asking, "Can I reach State B from State A, and what is the cost?"

## 2. Implementation Patterns: Choice of Tool
How you build the graph determines the efficiency of your algorithm. 
- **Adjacency List (Most Common)**: Uses an array of lists/vectors. Best for sparse graphs (fewer edges). It is memory-efficient and faster for iterating over neighbors.
- **Adjacency Matrix**: A 2D array (\(V\times V\)). Best for dense graphs or when you need to check if an edge exists between two specific nodes in \(O(1)\) time.
- **Edge List**: A simple list of pairs. Best for algorithms like Kruskal’s (Minimum Spanning Tree) where you need to sort all edges by weight. 

## 3. Algorithm Patterns & Best Practices
In 2026, competitive programming and system design prioritize these three pillars: 

**A. Traversal (The Foundation)** 
- Breadth-First Search (BFS): Use a Queue.
    - Best Practice: Use BFS for finding the shortest path in unweighted graphs. It explores "layer by layer."
- Depth-First Search (DFS): Use Recursion or a Stack.
    - Best Practice: Use DFS for **pathfinding**, detecting cycles, or topological sorting (ordering tasks with dependencies). 

**B. Shortest Path (The Optimization)** 
- Dijkstra’s Algorithm: Use a Priority Queue (Min-Heap).
    - Constraint: Only works if all edge weights are non-negative.
- Bellman-Ford: Use for graphs with negative weights.
    - Modern Note: Essential for detecting "negative cycles" in financial systems (arbitrage). 

**C. Connectivity & Components** 
- Union-Find (Disjoint Set Union): An incredibly efficient data structure for checking if two nodes belong to the same component.
    - Best Practice: Always implement Path Compression and Union by Rank to keep operations near \(O(1)\) time complexity.

## 4. How to Apply: The 4-Step Framework 
1. Model the Graph: Explicitly define what your nodes and edges are. Is it directed (one-way) or undirected? Is it weighted?
2. Handle Cycles: In 2026, "infinite loops" are the #1 bug in graph logic. Always use a visited set (or boolean array) to track where you have been.
3. Choose the Strategy:
    - Need the shortest path? -> BFS or Dijkstra.
    - Need to visit everything? -> DFS.
    - Need to group items? -> Union-Find.
4. Analyze Complexity:
- Most graph algorithms aim for \(O(V+E)\) where \(V\) is vertices and \(E\) is edges.
- If your complexity hits \(O(V^2)\) on a large sparse graph, you have chosen the wrong implementation.