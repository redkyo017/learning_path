package week6

import (
	"math"
)

// 4. Median of Two Sorted Arrays https://leetcode.com/problems/median-of-two-sorted-arrays/description/
func FindMedianSortedArrays(nums1 []int, nums2 []int) float64 {
	if len(nums1) > len(nums2) {
		nums1, nums2 = nums2, nums1 // Ensure nums1 is the shorter array
	}
	m, n := len(nums1), len(nums2)
	left, right := 0, m

	for left <= right {
		i := (left + right) / 2
		j := (m+n+1)/2 - i

		// Handle boundaries for Array A
		leftA := math.MinInt64
		if i > 0 {
			leftA = nums1[i-1]
		}
		rightA := math.MaxInt64
		if i < m {
			rightA = nums1[i]
		}

		// Handle boundaries for Array B
		leftB := math.MinInt64
		if j > 0 {
			leftB = nums2[j-1]
		}
		rightB := math.MaxInt64
		if j < n {
			rightB = nums2[j]
		}

		if leftA > rightB {
			right = i - 1 // i is too big
		} else if leftB > rightA {
			left = i + 1 // i is too small
		} else {
			// Perfect partition found!
			maxLeft := max(leftA, leftB)
			if (m+n)%2 != 0 {
				return float64(maxLeft)
			}
			minRight := min(rightA, rightB)
			return (float64(maxLeft) + float64(minRight)) / 2.0
		}
	}
	return 0.0
}
