# 🎨 Visualizing the Day 6 Boss: Median of Two Sorted Arrays

The core difficulty of this problem is finding a partition (a "cut") across two different arrays simultaneously so that the combined left side and combined right side are balanced.

*How the Binary Search works here:*
1. The Cut ($i$ and $j$): We pick a cut $i$ in the smaller array. This automatically forces a cut $j$ in the larger array to ensure exactly half the elements are on the left.
2. The Cross-Check: We check if the largest element on the left of Array A (L1) is $\le$ the smallest on the right of Array B (R2), and vice versa.
3. The Adjustment: If L1 > R2, our cut in Array A is too far to the right, so we move it left. If L2 > R1, our cut is too far left, so we move it right.