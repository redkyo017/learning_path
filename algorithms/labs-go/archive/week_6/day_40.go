package week6

// 34. Find First and Last Position of Element in Sorted Array https://leetcode.com/problems/find-first-and-last-position-of-element-in-sorted-array/description/
func SearchRange(nums []int, target int) []int {
	var findBound func(nums []int, target int, isFirst bool) int
	findBound = func(nums []int, target int, isFirst bool) int {
		left, right := 0, len(nums)-1
		res := -1
		for left <= right {
			mid := left + (right-left)/2
			if target == nums[mid] {
				res = mid
				if isFirst {
					right = mid - 1
				} else {
					left = mid + 1
				}
			} else if target < nums[mid] {
				right = mid - 1
			} else {
				left = mid + 1
			}
		}
		return res
	}
	first := findBound(nums, target, true)
	if first == -1 {
		return []int{-1, -1}
	}
	last := findBound(nums, target, false)
	return []int{first, last}
}

/**
 * Forward declaration of isBadVersion API.
 * @param   version   your guess about first bad version
 * @return 	 	      true if current version is bad
 *			          false if current version is good
 * func isBadVersion(version int) bool;
 */
func isBadVersion(version int) bool {
	return true
}

// 278. First Bad Version https://leetcode.com/problems/first-bad-version/description/
func FirstBadVersion(n int) int {
	res := 1
	left, right := 1, n
	for left <= right {
		mid := left + (right-left)/2
		if isBadVersion(mid) {
			res = mid
			right = mid - 1
		} else {
			left = mid + 1
		}
	}
	return res
}
