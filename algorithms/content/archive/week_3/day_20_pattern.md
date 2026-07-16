# 🗓️ Day 20 Wrap-up: Complex Manipulation

You have successfully completed Day 5 and mastered the highest level of linked list manipulation: combining multiple concepts and re-wiring the entire structure.
|Pattern|Problem Example|Core Mindset|
|---|---|---|
|Cycle-Based Re-wiring|61. Rotate List|"To move the tail to the front, I'll temporarily connect the tail to the head, creating a full cycle. Then I can move $X$ steps and break the cycle at the right spot."|

## 💡 Pattern: Cycle-Based List Re-wiring
Problem Solved: 61. Rotate List

The rotation problem is difficult because it requires finding both the length and the new start point in a length-dependent manner. The cycle trick turns a complex cut-and-paste operation into a simple traversal.

|Step|Technique Used|Rationale|
|---|---|---|
|1. Length & Closure|Traversal/Re-wiring|Find $L$ and locate tail. Connect tail.Next = head. This makes the list a continuous circle.
|2. Modulo Math|Arithmetic|Calculate offset = k % L. This reduces $k$ to the minimum necessary moves, preventing excessive traversal.|
|3. Find Breakpoint|Traversal|To rotate right by offset, the new tail is the node at position $L - \text{offset}$. Traverse L - offset steps from the original head to find the new tail.|
|4. Final Cut|Pointer Update|Set newHead = newTail.Next and then newTail.Next = nil to break the cycle and return the new start.|