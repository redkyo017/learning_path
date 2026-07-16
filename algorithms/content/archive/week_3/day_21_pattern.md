# 🧠 Day 6 Wrap-up: Recursion and Doubly Linked Structures

## 💡 Pattern 1: The Recursive Leap of Faith
In Recursive Reversal, the mindset is: "I don't care how the rest of the list gets reversed; I trust the function to return a reversed tail. I only care about connecting the current head to the end of that reversed tail."
- Recursive step: head.Next.Next = head
- Safety step: head.Next = nil

## 💡 Pattern 2: The Sentinel Strategy
In Doubly Linked Lists, the mindset is: "Empty space is dangerous." By using dummyHead and dummyTail, you ensure that every node—including the first and last—always has a neighbor on both sides.
- Benefit: No more if head == nil or if curr.Next == nil checks.
- Standard Move: When inserting, always identify the nodes to the left (prev) and right (next), then update all 4 pointers.