# 🏁 Day 6 Wrap-up: Advanced Monotonic Structures

## 🧠 Mindset: "Aggressive Pruning"
Day 6 was about the "Survival of the Fittest" logic.
- The Core Idea: As new information comes in, old information that can no longer be the "answer" (because it's smaller or out of bounds) must be discarded immediately.
- Monotonicity: By keeping the stack/queue sorted, we reduce an $O(N \cdot K)$ problem (checking every window) into an $O(N)$ problem (every element enters and leaves the queue exactly once).

### 🛠️ Patterns Mastered
Pattern|Insight|Applied To|
---|---|---
|Virtual Indexing|Using % n to treat a linear array as a circle without extra space.|503. Next Greater Element II|
Monotonic Queue| Using a Deque to maintain the "best" candidate in a moving range.|239. Sliding Window Max

