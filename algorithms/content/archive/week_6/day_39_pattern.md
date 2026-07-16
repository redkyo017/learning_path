# 🏁 Wrap-up: Week 6 | Day 3
### Thought & Mindset
Today was about Identifying the Anomaly. In a sorted array, everything follows a predictable trend. In a rotated array, there is exactly one "break" in the trend. Binary search still works here because we can determine which side of the mid contains that "break" by comparing mid to the boundaries (left or right).

### The Pattern: Property-Based Halving
Instead of just checking if a number is bigger or smaller than target, we check: "Is this segment consistent or inconsistent?"

If nums[left] <= nums[mid], the left is consistent.

If nums[mid] > nums[right], the "drop-off" (minimum) is to the right.