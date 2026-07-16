# Doubly Linked List
A Doubly Linked List can manipulate the order of elements in O(1) time complexity for certain operations, specifically insertion and deletion of a node when the node's reference is already known. This efficiency stems from the bidirectional pointers within each node.

**How it achieves O(1) manipulation:**

Each node in a Doubly Linked List contains three components:
- Data: The actual value stored in the node.
- next pointer: A pointer to the subsequent node in the list.
- prev pointer: A pointer to the preceding node in the list.
## 1. Insertion (when the insertion point is known):
If you have a reference to a node X and want to insert a new node N either before or after X, you only need to modify a constant number of pointers: 

Inserting N after X.

    N.prev = X
    N.next = X.next
    X.next.prev = N  (if X.next exists)
    X.next = N

Inserting N before X.

    N.next = X
    N.prev = X.prev
    X.prev.next = N  (if X.prev exists)
    X.prev = N

In both cases, a fixed number of pointer assignments are performed, regardless of the list's size, resulting in O(1) time complexity.
##  2. Deletion (when the node to be deleted is known):
If you have a reference to a node X that needs to be deleted, you can bypass X by adjusting the next pointer of X.prev and the prev pointer of X.next:

    X.prev.next = X.next  (if X.prev exists)
    X.next.prev = X.prev  (if X.next exists)

Again, a fixed number of pointer modifications are required, leading to O(1) time complexity for deletion.
### Important Considerations:
- Finding the node: The O(1) complexity for insertion and deletion only applies after the target node or insertion point has been identified. If you need to search for a specific value or position in the list, that search operation will typically take O(N) time in the worst case, where N is the number of nodes in the list.
- Head and Tail Operations: Insertion at the head or tail, and deletion of the head or tail, are also O(1) operations if you maintain pointers to the head and tail of the list. These are special cases of insertion/deletion where one of the prev or next pointers might be null.