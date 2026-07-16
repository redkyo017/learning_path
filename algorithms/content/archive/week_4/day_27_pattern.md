# 🏁 Day 5 Wrap-up: Monotonic Stack I

## 🧠 Mindset: "Indices are More Powerful"
Day 5 taught us the power of the Monotonic Stack for "Look Ahead" problems.
- The "Wait" Pattern: When an element can't be processed yet, it goes into the stack "waiting room."
- Value vs. Index: Storing the index is almost always better than storing the value because an index gives you both the value (arr[i]) and the position/distance.

### 🛠️ Patterns Mastered
|Pattern	|Insight|	Applied To
---|---|---
|Monotonic Stack (Decreasing)|	Keep elements in decreasing order. A larger element "solves" the pending items on the stack.|	496. Next Greater Element I|
|Index-Based Monotonic Stack|	Store indices to calculate distances or spans between elements.|	739. Daily Temperatures