# Linked List - Dummy node - Practical
A dummy node (or sentinel node) is a non-data-containing placeholder node added to a linked list to simplify operations and eliminate the need for special-case code when dealing with the head of the list or an empty list. 
You should apply a dummy node in the following scenarios:

### When to Use a Dummy Node
- Operations that May Change the Head: The primary use case is in algorithms where the head of the linked list might be modified or deleted. By placing a dummy node immediately before the actual head, you ensure a stable, constant reference point that always "points" to the start of the current, actual list (via its next pointer).
- Simplifying Edge Cases: The dummy node allows you to treat all nodes, including the first one, uniformly. This avoids numerous if conditions to check for a null head or for operations on an empty list, resulting in cleaner, less error-prone code.
- Building a New List from Scratch: When merging two sorted lists or filtering nodes to create a new list, a dummy node acts as a temporary starting point for the new list. You can build the entire new list by appending to subsequent nodes and simply return dummy.next as the new head when finished.
- Complex Pointer Manipulations: For algorithms involving multiple pointers, such as reversing a list in groups, partitioning a list, or detecting cycles, the dummy node helps manage the flow of pointers smoothly without worrying about the integrity of the original head reference.
- Doubly Linked Lists: In doubly linked lists, dummy nodes can act as both the "dummy head" and "dummy tail," linking to each other in an empty list and providing a consistent boundary for all operations, making the list effectively circular and eliminating all special cases for the first and last elements. 

### Common Problem Examples
Specific LeetCode-style problems where dummy nodes are highly effective include:
- Merge Two Sorted Lists
- Remove Nth Node From End of List
- Remove Duplicates from Sorted List II
- Swap Nodes in Pairs 

By using a dummy node, you ensure that even if the original head is deleted or changed during an operation, you still have an anchored reference to the beginning of the resulting list. 