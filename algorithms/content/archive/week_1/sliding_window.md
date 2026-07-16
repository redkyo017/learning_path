# Sliding window pattern

The sliding window pattern is an optimization technique used primarily for problems involving *contiguous subarrays or substrings*, where you need to find an optimal subsegment(e.g., maximum sum, logest substring without repeating characters).It efficiently processes data by maintaining a "window" that slides across the dataset, updating calculations incrementally rather than recomputing for each new subsegment.

### Recognition
- Problems involving contiguous subarrays/substrings: th pattern is applicable when you are looking for propperties within a continuous sequence of elements
- Need to find an "optimal" subsegment: this could be the longest, shortest, maximum, minimum, or a specific target value within a subsegment.
- Brute-force solutions involve nested loops: if a naive would require iterating through all possiable start aand end points of subsegment(O(n^2)), sliding window can often reduce this to O(n).

### How to apply
- Define the window: initialize two pointers, *left* and *right*, marking the boundaries of your window
- Expand the window: Move the right pointer to include new elements into the window.As you add elements, update any relevant cal;culations (e.g, sum, character counts).
- Shrink the window(if necessary): if the window violates a given condition(e.g., window size exceed a limit, a character count becomes too high), move the left pointer to remove elements from the window's beginning until the condition is met. Update calculations accordingly
- track the optimal result: at each step, after expanding and potentially shrinking the window, compare the current window's properties with your stored optimal result and update it if a better one is found.
- Repeat: Continue expanding and shrinking the window until the right pointer reaches the end of the input data.

### Key Insight:
The core insight of the sliding window pattern is that you dont need to re-process the entire window from scratch every time it moves. Instead, you can incrementally update your calculations by only cobnsidering the element entering the window and the element leaving the window. This transformation significantly reduces the time complexity, often fromm quadratic (O(n^2)) to linear (O(n))