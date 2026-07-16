# Two pointer pattern

the two pointer technique uses two references to traverse a data structure (usually and *array* or *linked list*) simutaneously, often from differenty position or moving at different speeds.

When to Recognize this pattern:
- sorted array or can be sort
- Need to find pairs/triplets that meet a condition
- Questions about palindromes (check from both ends)
- need to remove/modify element in-place
- want to reduce O(n^2) to O(n) by avoiding nested loops

#### Common Two pointer Patters:
1. Opposite Direction (Converging)

```
Start: [1, 2, 3, 4, 5, 6]

        ↑              ↑
        left          right

Move: Compare, then move pointers toward each other
Used for: Sorted array searches, palindromes
```
2. Same Direction (Chasing)
```        
Start: [1, 2, 3, 4, 5, 6]
        ↑  ↑
    slow fast

Move: Both move forward, usually at different speeds
Used for: In-place modifications, cycle detection
```

#### Key insight
Two pointers eliminate one loop by intelligently moving pointers based on comparison results, reducing time complexcity from O(n^2) to O(n)