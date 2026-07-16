# Monotonic stack

A monotonic stack is a standard stack that enforces a strict ordering rule: elements must remain either strictly increasing or strictly decreasing from bottom to top. 

## 1. The Mindset Pattern: "Search & Purge"
The core mindset for using a monotonic stack is shifting from "storing data" to "resolving queries" as you scan. 
- The Waiting Room Concept: Think of the stack as a "waiting room" for elements that haven't found their match yet (e.g., their "next greater element").
- The "Bully" Logic: When a new element arrives, it "bullies" out all elements currently on the stack that violate the monotonic rule.
    - Increasing Stack: If the new element is smaller, it kicks out larger elements to stay at the top.
    - Decreasing Stack: If the new element is larger, it kicks out smaller elements to stay at the top.
- Linear Time Efficiency: Every element is pushed and popped exactly once, transforming O(n²) brute-force nested loops into O(n) linear time solutions. 
## 2. Identifying the Problem
You should consider a monotonic stack if the problem asks for: 
- Nearest Neighbor: The "first" element to the left or right that is smaller or larger than the current one.
- Range Minimum/Maximum: Maintaining local extrema as you slide through an array.
- Histogram/Area Problems: Calculating the largest rectangle in a histogram or water trapping.
- Lexicographical Order: Removing duplicates while maintaining the smallest possible string order. 
## 3. Best Practices & Implementation
- Store Indices, Not Values: Most problems require the distance between elements or original positions. Storing indices in the stack allows you to look up both the value (arr[stack.top()]) and the position.
- Single Pass Consistency: While you can traverse an array in any direction, standard practice is to go left-to-right for simplicity.
- Standard Template:
```python
    stack = []
    for i in range(len(arr)):
        # While stack is not empty and current element violates monotonicity
        while stack and arr[i] > arr[stack[-1]]: # Example for Decreasing Stack
            top_index = stack.pop()
            # Process 'top_index'—arr[i] is its "Next Greater Element"
        stack.append(i)
```
- Handle Remaining Elements: After the loop, the stack may still contain elements that never found a "match." Decide if they need a default value (like -1 or array length) based on the problem requirements.
- Check for Monotonic Deque: If you need to remove elements from both ends (e.g., sliding window maximum), upgrade to a deque while maintaining the same monotonic logic.