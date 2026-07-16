package week6

// 162. Find Peak Element https://leetcode.com/problems/find-peak-element/description/
func FindPeakElement(nums []int) int {
	left, right := 0, len(nums)-1
	for left < right {
		mid := left + (right-left)/2
		if mid < right && nums[mid] < nums[mid+1] {
			left = mid + 1
		} else {
			right = mid
		}
	}
	return right
}

// 69. Sqrt(x) https://leetcode.com/problems/sqrtx/description/
func MySqrt(x int) int {
	if x == 1 {
		return 1
	}
	res := 0
	left, right := 1, x
	for left < right {
		mid := left + (right-left)/2
		if mid*mid <= x {
			res = mid
			left = mid + 1
		} else {
			right = mid
		}
	}
	return res
}
