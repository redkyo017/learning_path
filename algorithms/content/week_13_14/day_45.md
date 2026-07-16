# Day 45 — Course Schedule (Weeks 13-14 consolidation)

**Protocol reminder:** same as always — hard 20-25 min timer, hint only after genuinely stuck, log outcome to `content/spaced_review_deck.md` or `content/error_log.md`.

Theory: this problem is fully covered by `content/archive/week_7/topology_sort_pattern.md` (Kahn's algorithm + DFS-based alternative, cycle detection, and a worked Course Schedule example) — read that first if the Week 7 material feels rusty, rather than a new primer.

## Problem: 207. Course Schedule — Medium
Link: https://leetcode.com/problems/course-schedule/

**Hint 1 (direction):** Each prerequisite pair is a dependency — "to take course A you must first take course B" — so before writing any code, ask what it would mean for it to be *impossible* to ever finish all courses.
**Hint 2 (technique):** Model courses as nodes and prerequisites as directed edges, and recognize this as a cycle-detection question on a directed graph — you can finish all courses iff the graph is a DAG.
**Hint 3 (structure):** Use Kahn's algorithm: build an adjacency list and an in-degree array from the prerequisite pairs, then seed a queue with every course whose in-degree is 0 (no unmet prerequisites).
**Hint 4 (implementation):** Process the queue, incrementing a "courses completed" counter and decrementing neighbors' in-degree as you go, enqueueing any neighbor that hits 0; at the end, compare that counter to `numCourses` — if it's short, a cycle exists.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Topological Sort (Kahn's algorithm)
- **Core idea:** a valid course order exists iff the prerequisite graph is a DAG (no cycles); Kahn's algorithm processes zero-in-degree nodes first and "unlocks" dependents as their in-degree hits zero.
- **Algorithm:** build adjacency list + in-degree counts from prerequisite pairs; seed a queue with in-degree-0 nodes; repeatedly pop, count, decrement neighbors' in-degree, enqueue any that hit 0; if final count equals numCourses, no cycle.
- **Complexity:** Time O(V+E), Space O(V+E)
- **Gotcha:** prerequisite pairs are given as [course, prerequisite] — get the edge direction right (prerequisite -> course) or the in-degree counts come out backwards.

</details>
