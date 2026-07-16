# 🏁 Day 4 Wrap-up: Nested Logic

## 🧠 Mindset: "The Checkpoint & The Tree"
Day 4 was about handling structures where the "end" of an operation depends on a previously "paused" state.
- In Decode String, we used an explicit Stack to create "checkpoints" when we hit a [.
- In Generate Parentheses, we used an implicit Stack (Recursion) to explore a decision tree where each choice (open or close) was constrained by the history of the string.

### 🛠️ Patterns Mastered
|Pattern|Insight|Applied To|
---|---|---
|Nested Simulation|Use stacks to save current state (string/multiplier) before entering a nested scope.|394. Decode String|
|Constrained Backtracking|Use a recursive "decision tree" to explore all combinations, pruning invalid paths early|.22. Generate Parentheses