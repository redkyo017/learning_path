# 🏁 Day 1 Wrap-up: Stack Basics & Design

## 🧠 Mindset: "Snapshotting & Future-Proofing"

On Day 1, we shifted from simply using a stack to designing and optimizing with it.
- Design Mindset: When asked for $O(1)$ access to a property (like min), the mindset is to store the answer as you go. Each element in the stack doesn't just store its value; it stores the "state of the world" at that height.
- Optimization Mindset: We learned that while a stack is the natural "simulation" tool for "undo" operations (backspaces), it costs $O(N)$ space. To hit $O(1)$ space, we must reverse our perspective—processing from the end allows us to skip what we know will be deleted.

### 🛠️ Patterns Mastered

Pattern|Insight|Applied To
---|---|---
State Tracking|Each node carries auxiliary data (like currentMin) to preserve history during a Pop().|155. Min Stack|
LIFO Simulation|Using Push and Pop to simulate real-world "undo" or "nested" logic.|844. Backspace Compare (Stack approach)
Backward Traversal|Processing strings from right-to-left to handle "destructive" operations (backspaces) in $O(1)$ space.|844. Backspace Compare (Optimal approach)

