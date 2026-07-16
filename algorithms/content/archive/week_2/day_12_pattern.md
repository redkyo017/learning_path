# 🧠 Pattern: Hash Map + Doubly Linked List (The Cache)

You used this pattern in **LRU Cache** to satisfy two conflicting requirements: instant access and instant order change.

**The Intuition: Separating Access from Order**

When a problem requires $O(1)$ access and $O(1)$ removal/reordering, you cannot rely on a single data structure:
1. Hash Map: Solves the $O(1)$ Access problem. We map key $\rightarrow$ CacheNode pointer.
2. Doubly Linked List: Solves the $O(1)$ Order problem. We can instantly remove a node from the middle and insert it at the head by updating its four surrounding pointers.

**Critical Technique: Dummy Nodes (Sentinels)**

The Head and Tail dummy nodes are placed permanently at the ends of the list , surrounding the actual data nodes.
- Benefit: They eliminate checks like if node.Prev != nil or if this.Head == nil, ensuring that all $O(1)$ helper functions (removeNode, addToHead) can be written without conditional logic, simplifying the implementation dramatically.

The $O(1)$ Operations:
|Operation|Steps (All O(1))|
|---|---|
|Get|Map lookup $\rightarrow$ moveToHead (remove $\rightarrow$ add to Head)|
|Eviction (LRU)|Remove the node pointed to by Tail.Prev (the LRU element) $\rightarrow$ Delete the entry from the Hash Map using its stored key.|