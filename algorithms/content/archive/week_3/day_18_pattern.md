# 🧠 Day 18 Mindset: Structure Over Content

Day 18 shifted the focus from finding an answer (like Day 17) to active structural manipulation (reversing or building).
|Mindset Shift|Two-Pointer (Relative Motion)|Reversal/Manipulation (Absolute Pointer Control)|
|---|---|---|
|Goal|Pointers move relative to each other to detect a state.|Pointers are surgically re-wired to change the list structure itself.|
|Insight|If I move one faster, they must meet in a cycle.|To reverse, I must preserve the rest of the list before cutting/changing the Next pointer.|
|Focus|Safety & Preservation. The order of operations (saving the next node vs. setting the new Next) is critical to avoid losing the list.|

## 💡 Pattern 1: Iterative List Reversal (The Three-Pointer Dance)
Problem Solved: 206. Reverse Linked List
This is the core, $O(N)$ time, $O(1)$ space technique for reversing a singly linked list.

|Pointer|	Role|	Action (Order of Operations)|
|---|---|---|
|current|	The node being processed.	|Moves to next after it is reversed.|
|prev|	The new Next pointer target (the node immediately before current in the new order).|	Moves to current after current is reversed.|
|next_node|	A temporary holding variable.	|Saves current.Next before the link is broken.

**The Three Critical Steps Inside the Loop:**
1. Save: next_node = current.Next (Preserves the reference to the rest of the list).
2. Reverse: current.Next = prev (The actual re-wiring).
3. Advance: prev = current and current = next_node (Shifts the pointers for the next iteration).

## 💡 Pattern 2: Half-Reversal for Symmetry/Palindrome Check
Problem Solved: 234. Palindrome Linked List
This pattern combines the two most powerful $O(1)$ space list techniques:

|Step|Pattern Used|Core Action|
|---|---|---|
|1. Find Middl|Fast/Slow Pointers|slow is located at the start of the second half.|
|2. Reverse|Iterative Reversal|Reverse the list starting from the slow pointer to get a reversed second half.|
|3. Compare|Two Pointers|Compare the original head with the new head of the reversed half, node by node.

## 💡 Pattern 3: Arithmetic & List Construction
Problem Solved: 2. Add Two Numbers
This problem primarily teaches the structure for building a new list from an arbitrary process, combined with simple arithmetic rules.

|Technique|	Role|	Mindset Check|
|---|---|---|
|Dummy Node|	Builds the result list without worrying about the head.|	"I don't need to know where the list starts yet, I'll just attach nodes to the dummy's Next."|
|Pointers|	l1, l2 (read); current (write).|	Pointers are advanced independently after their value is consumed.|
|Carry|	Stores the overflow (sum / 10).	|The loop condition must account for a remaining carry even after both lists are exhausted(`l1 != nil or l2 != nil`)
|Value|	sum % 10.|	The node value is always the remainder after carry is calculated.|

## ✅ New Solution for Problem 206. Reverse Linked List (Recursive)
|Aspect|Evaluation|Details|
|---|---|---|
|Correctness|Pass|The three core steps of recursive reversal are perfectly implemented: newHead stores the final answer, head.Next.Next = head performs the reversal of the link, and head.Next = nil breaks the forward link, preventing a cycle.|
|Core Pattern|Mastered|This demonstrates a strong understanding of how to use the call stack to manage state and solve structural problems recursively.|
|Time Complexity|O(N)|Optimal. Each of the $N$ nodes is visited exactly once.|
|Space Complexity|O(N)|The space complexity is $O(N)$ due to the depth of the recursion stack. This is the main trade-off compared to the $O(1)$ iterative solution.