# 🏁 Day 2 Wrap-up: Structure Conversion

## 🧠 Mindset: "The Mirror Effect"
Day 2 was about the relationship between Stacks and Queues.
- To make a Queue from Stacks: You need a second stack to "reverse" the flow. You only move elements when the "output" is empty (Amortized $O(1)$).
- To make a Stack from a Queue: You "rotate" the queue upon every push so the newest arrival is always the first in line ($O(N)$ Push).

### 🛠️ Patterns Mastered
|Pattern|Insight|Applied To|
---|---|---
Double-Stack Pouring|Reversing order by moving elements from one LIFO structure to another.|232. Queue using Stacks
One-Queue Rotation|Using the size of the queue to loop and re-enqueue elements, moving the tail to the head.|225. Stack using Queues

