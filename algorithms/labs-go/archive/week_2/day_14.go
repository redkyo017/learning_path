package week2

// 41. First Missing Positive https://leetcode.com/problems/first-missing-positive/description/
func FirstMissingPositive(nums []int) int {
	m := len(nums)
	for i := 0; i < m; {
		num := nums[i]
		if num <= m && num >= 1 && num != nums[num-1] {
			nums[i], nums[num-1] = nums[num-1], nums[i]
		} else {
			i++
		}
	}
	for i := 0; i < len(nums); i++ {
		if i+1 != nums[i] {
			return i + 1
		}
	}
	return m + 1
}
