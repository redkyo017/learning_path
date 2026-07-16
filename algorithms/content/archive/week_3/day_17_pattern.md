# Day 17: Cycle Detection & Two-Pointer Alignment.

## 🧠 Mindset: Relative Motion and Alignment
Day 17 was all about using two pointers to leverage relative motion and path length alignment to solve structural problems without needing extra storage (Hash Maps/Sets).

|Mindset Shift|	Array/Single Pointer|	Two Pointers/Relative Motion|
|---|---|---|
|Goal	|Find a value or modify a structure.|	Detect a structural property (cycle, intersection) based on movement.|
|Insight|	I need to know the entire list structure.|	I only need to know how the pointers relate to each other.|
|Focus|	Node value or node position.|	The distance between pointers and the total path length traveled.|

## 💡 Pattern 1: Fast/Slow Pointers (Floyd's Cycle Detection)
Problem Solved: 141. Linked List Cycle
|Component|Description|Key Takeaway|
|---|---|---|
|Goal|Detect if a cycle exists in $O(N)$ time and $O(1)$ space.|Avoiding the Hash Set penalty.
|Technique|Two pointers: slow (1x speed) and fast (2x speed).|The speed difference ensures the distance between them shrinks by 1 with every iteration.|
Meeting Point|If a cycle exists, fast will eventually lap slow, meaning slow == fast.|Crucial: The pointers must move at least once before you check for equality to avoid a false positive at the start.|
|Termination|If fast or fast.Next is nil, the list ends, and there is no cycle.|This happens when fast exits the

## 💡 Pattern 2: Two-Pointer Path Alignment
Problem Solved: 160. Intersection of Two Linked Lists

|Component|Description|Key Takeaway|
|---|---|---|
|Goal|Find the first common node (memory address) between two lists of possibly unequal lengths in $O(L_A + L_B)$ time and $O(1)$ space.|Compensate for length differences without a separate counting pass.|
|Technique (Optimal)|The A + B Path Trick: When a pointer reaches the end of its list, redirect it to the head of the other list.By the time they meet (or both hit nil), they will have traveled the exact same total distance: $L_A + L_B$.|
|Alignment|When they travel $L_A + L_B$ steps, the pointers are guaranteed to be perfectly aligned at the intersection point, regardless of $L_A$ and $L_B$'s difference.|This cleverly normalizes the starting points.|
Intersection Check|The result is the node where pA == pB (same memory address). If they reach nil simultaneously (pA == pB == nil), there is no intersection.|Crucial: Always compare the pointers (pA == pB), not the values (pA.Val == pB.Val).|

