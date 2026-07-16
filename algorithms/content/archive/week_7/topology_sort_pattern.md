```
Topological Sort is a fundamental graph algorithm used to arrange nodes in a linear order such that for every directed edge, node comes before node. It is used primarily for dependency resolution.

Here is a comprehensive guide to understanding Topological Sort through a "mindset" approach, key patterns, and best practices. 
```

### 1. The Mindset Pattern: "Dependency Management"
When you see a problem involving ordering, scheduling, or tasks that cannot start until others finish, think Topological Sort. 
- DAG Required: The graph must be a Directed Acyclic Graph (DAG). If there is a cycle (e.g., A needs B, B needs C, C needs A), a topological sort is impossible.
- The "Zero-Dependency" Mindset: Ask yourself: "Which task can I start immediately because it has no prerequisites?"
- The "Unlock" Mindset: Once a task is completed, it "unlocks" other tasks that depended on it. 

Real-World Analogy: Building a House
1. Foundation -> Walls
2. Walls -> Roof
3. Foundation -> Plumbing
4. Roof -> Interior 
- Nodes: Foundation, Walls, Roof, Plumbing, Interior.
- Edges: Directed (e.g., Foundation Walls).
- Topological Order: Foundation -> Walls -> Plumbing -> Roof -> Interior (Multiple valid orders exist). 

### 2. Primary Algorithm: Kahn’s Algorithm (BFS-based)
This is the most intuitive approach, focusing on indegrees (number of incoming edges). 
Steps:
1. Calculate In-degree: Count the incoming edges for each node.
2. Initialize Queue: Add all nodes with in-degree 0 (no dependencies) to a queue.
3. Process Queue:
    1. Remove node `u` from the queue.
    2. Add `u` to the result list.
    3. For each neighbor `v` of `u`, decrease its in-degree by 1.
    4. If `v`'s in-degree becomes 0, add `v` to the queue.
4. Cycle Detection: If the resulting list contains fewer nodes than the total graph, a cycle exists (no topological sort). 

### 3. Alternative Algorithm: DFS-based
Steps:
1. Perform a DFS traversal.
2. After visiting all neighbors of a node (backtracking), push the node onto a stack.
3. Reverse the stack to get the topological order. 

### 4. Best Practices for Implementation
1. *Data Representation:*
- Represent the graph as an Adjacency List (Map<Integer, List<Integer>>).
- Store in-degrees in an array or map (int[] indegree). 
2. *Handling Multiple Valid Sorts*
- Topological sort is not unique. If two nodes have an in-degree of 0, you can pick either one first.
- If you need a specific type of order (e.g., lexicographical), use a Priority Queue instead of a normal Queue to always pick the smallest node first. 
3. *Cycle Detection Techniques*
- Kahn’s: If result.size() != numNodes, it's a cycle.
- DFS: Use three states for nodes (Unvisited, Visiting, Visited). If you encounter a "Visiting" node during DFS, you've found a cycle. 
4. *Time and Space Complexity*
- Time: `O(V+E)` where `V` is vertices and `E` is edges. We visit each node and edge once.
- Space: `O(V+E)` for the adjacency list and `O(V)` for the queue/in-degree array. 

### 5. Summary Table
Component|Concept
|---|---|
Prerequisite|	Directed Acyclic Graph (DAG)
Core Idea|	Process nodes with in-degree 0
Algorithm|	Kahn's Algorithm (BFS) is usually preferred.
Complexity|	`O(V+E)`Time, `O(V)` Space
Applications|	Course Prerequisites, Task Scheduling, Build Systems, Package Dependency Management

### 6. Example (LeetCode 207 - Course Schedule)
Nodes are courses, Edge A -> B means A is a prerequisite for B. 

``` Java
// Simplified Kahns Algorithm
public boolean canFinish(int numCourses, int[][] prerequisites) {
    List<List<Integer>> adj = new ArrayList<>();
    int[] indegree = new int[numCourses];
    // 1. Build Graph & In-degrees
    for (int[] pre : prerequisites) {
        adj.get(pre[0]).add(pre[1]);
        indegree[pre[1]]++;
    }
    // 2. Queue with 0-in-degree nodes
    Queue<Integer> queue = new LinkedList<>();
    for (int i = 0; i < numCourses; i++) {
        if (indegree[i] == 0) queue.add(i);
    }
    // 3. Process
    int count = 0;
    while (!queue.isEmpty()) {
        int curr = queue.poll();
        count++;
        for (int neighbor : adj.get(curr)) {
            indegree[neighbor]--;
            if (indegree[neighbor] == 0) queue.add(neighbor);
        }
    }
    return count == numCourses;
}
```