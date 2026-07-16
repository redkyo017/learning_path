package week1

import (
	"sort"
)

// 56. Merge Intervals https://leetcode.com/problems/merge-intervals/description/
func Merge(intervals [][]int) [][]int {
	// Sort by start time: Crucial step for O(N log N)
	sort.Slice(intervals, func(i, j int) bool {
		return intervals[i][0] < intervals[j][0]
	})
	res := [][]int{intervals[0]}
	for _, interval := range intervals {
		lastMerged := res[len(res)-1]
		// Check for overlap: lastMerged's end is >= current interval's start
		if lastMerged[1] >= interval[0] {
			// Overlap: Update the end of the last merged interval
			newMerge := []int{lastMerged[0], max(lastMerged[1], interval[1])}
			res[len(res)-1] = newMerge
		} else {
			// No overlap: Add the current interval as a new component
			res = append(res, interval)
		}
	}
	return res
}

// 238. Product of Array Except Self https://leetcode.com/problems/product-of-array-except-self/description/
func ProductExceptSelf(nums []int) []int {
	n := len(nums)
	// 1. Initialize the result array (O(N) space, but this doesn't count against the O(1) extra space constraint)
	products := make([]int, n)

	// --- PASS 1: Calculate Prefix Products (Left) ---
	// At the end of this loop, products[i] holds the product of all elements to the LEFT of nums[i].

	// The product to the left of index 0 is always 1.
	products[0] = 1

	for i := 1; i < n; i++ {
		// products[i] = products[i-1] * nums[i-1]
		// Current left product is the previous left product multiplied by the number at the previous index.
		products[i] = products[i-1] * nums[i-1]
	}
	// products array now looks like: [1, 1, 2, 6] for input [1, 2, 3, 4]

	// --- PASS 2: Calculate Suffix Products (Right) and Final Result ---
	// We only need one variable (rightProduct) to track the running product from the right.

	rightProduct := 1 // Start with the product to the right of the last element being 1.

	for i := n - 1; i >= 0; i-- {
		// 1. Final Answer: products[i] (Left Product) * rightProduct (Right Product)
		products[i] = products[i] * rightProduct

		// 2. Update Right Product: Incorporate the number we just passed
		rightProduct = rightProduct * nums[i]
	}

	return products
}
