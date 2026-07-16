# 🧠 The Linked List Mindset: Thinking in Pointers

The biggest shift from arrays to linked lists is that you are no longer manipulating data values; you are manipulating pointers (memory addresses).
|Mindset Shift|Array Thinking|Linked List Thinking|
|---|---|---|
|Indexing|arr[i]|current.Next|
|Iteration|i++|current = current.Next|
|Deletion|arr.remove(i)|previous.Next = current.Next (Skips the node)|

The Golden Rule: Always think about the predecessor node (the node before the one you want to change). To delete a node, you must update the Next pointer of the node that currently points to it.

## 💡 Pattern 1: The Dummy Node Technique (The Head-Case Solution)

This is the single most important pattern for linked list modifications. It solved the edge cases in both Problem 21 and Problem 203.
|||
|---|---|
|What is it?|A new, temporary node (d or dummy) created before the original head.
|Why use it?|It provides a safe, guaranteed predecessor for the first element of the list.|
|What does it solve?|Head Modification: It allows you to remove or change the original head (e.g., removing a duplicate head in a sorted list, or removing the head if it equals val in Problem 203) without needing special if head == nil or if head.Val == val checks.|
|How to use it?|(1.) d := ListNode{Next: head}. (2.) Start your main pointer: current := &d. (3.) Return d.Next.|

## 💡 Pattern 2: Conditional Pointer Advance (Deletion/Skipping)

This pattern is the key to solving removal problems like Problem 83 (Duplicates) and Problem 203 (Remove Elements). It focuses on when to move your main pointer (current).

|Condition|Action|Rationale|
|---|---|---|
|Node needs to be removed/skipped (current.Next.Val == target)|Update Pointer: current.Next = current.Next.Next DO NOT ADVANCE current|current must stay put because the new current.Next might also need to be removed (e.g., three duplicates in a row: 1 -> 1 -> 1).|
Node is safe/unique (current.Next.Val != target)|Advance Pointer: current = current.Next|The check is complete for the current position, and you can move on to the next.|

    // Only advance if the next node is NOT a duplicate
    if current.Val != current.Next.Val {
        current = current.Next 
    } else {
        // If it's a duplicate, skip it, but keep 'current'
        current.Next = current.Next.Next 
    }