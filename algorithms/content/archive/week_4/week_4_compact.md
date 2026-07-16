# 💾 Week 4 Compaction Summary

## 💻 Google Interview Prep: Week 4 Summary (Stacks & Queues)
Day|Focus Topic|Problems Solved|Core Pattern|Complexity Goal
---|---|---|---|---
Day 1|Interface Design|232. Implement Queue using Stacks|Double-Stack Reversal (Pouring)|O(1) Amortized
Day 2|Structure Rotation|225. Implement Stack using Queues|One-Queue Rotation|O(N) Push
Day 3|String Parsing|"71. Simplify Path| 150. Eval RPN"|"Path Simulation| Postfix Evaluation"|O(N)
Day 4|Nested Logic|"394. Decode String| 22. Generate Parentheses"|"State Checkpoints| Constrained Backtracking"|O(N) / O(2n)
Day 5|Monotonic Stack I|"496. Next Greater I| 739. Daily Temperatures"|Decreasing Stack (Lookahead for Greater)|O(N)
Day 6|Monotonic Queue|"503. Next Greater II| 239. Sliding Window Max"|"Circular Modulo| Monotonic Deque (Max in Range)"|O(N)
Day 7|Finale Challenge|84. Largest Rectangle in Histogram|Increasing Stack + Sentinel (Flush)|O(N)

Key Takeaways/Mindset:
- Monotonic Property: Used stacks to find "Next/Previous Smaller/Greater" elements in $O(N)$ by maintaining a specific order and "pruning" useless data.
- Sentinel Pattern: Added dummy values (like 0 in Histogram) to handle boundary conditions and flush remaining stack elements automatically.
- Indices over Values: Storing indices in the stack is more powerful than storing values, as indices provide both the value ($arr[i]$) and the distance/width.
