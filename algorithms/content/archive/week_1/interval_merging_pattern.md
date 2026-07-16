# The Interval Merging Pattern 
The Interval Merging Pattern is a common algorithmic technique for combining overlapping intervals into a minimal set of non-overlapping intervals. The process involves first sorting the intervals by their start times and then iterating through the sorted list to merge any intervals that overlap by adjusting the end time of the merged interval to the maximum end time of the overlapping ones. This simplifies the data by reducing the number of intervals, which can be useful in problems involving scheduling, resource allocation, and data analysis. 

**Step-by-step breakdown** 

1.Sort the intervals: Sort all the intervals in ascending order based on their start times.

2.Initialize a merged list: Create a new list and add the first interval from the sorted list to it. This will be the first potential merged interval.

3.Iterate and merge: Go through the rest of the sorted intervals, one by one.
- Check for overlap: Compare the current interval with the last interval added to the merged list. An overlap occurs if the current interval's start time is less than or equal to the last merged interval's end time.
- Merge if overlapping: If they overlap, update the end time of the last interval in the merged list to be the maximum of its current end time and the current interval's end time.
- Add if not overlapping: If there is no overlap, add the current interval as a new, separate interval to the merged list.

4.Return the result: The final list contains the non-overlapping intervals. 

#### Example 
- Input: [[1, 3], [2, 6], [8, 10], [15, 18]]
- Step 1: Sort: The list is already sorted by start time.
- Step 2: Initialize: merged_intervals = [[1, 3]]
- Step 3: Iterate:
    - Current interval: [2, 6]. It overlaps with [1, 3] because \(2\le 3\). Merge them. The new end is \(\max (3,6)=6\). merged_intervals = [[1, 6]].
    - Current interval: [8, 10]. It does not overlap with [1, 6] because \(8>6\). Add it. merged_intervals = [[1, 6], [8, 10]].
    - Current interval: [15, 18]. It does not overlap with [8, 10] because \(15>10\). Add it. merged_intervals = [[1, 6], [8, 10], [15, 18]].
- Step 4: Result: [[1, 6], [8, 10], [15, 18]] 