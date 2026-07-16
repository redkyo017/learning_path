package week1

import "sort"

// 167. Two Sum II - Input Array Is Sorted https://leetcode.com/problems/two-sum-ii-input-array-is-sorted/description/
func TwoSumII(numbers []int, target int) []int {
	if len(numbers) < 2 {
		return []int{}
	}
	head, tail := 0, len(numbers)-1
	for head < tail {
		sum := numbers[head] + numbers[tail]
		if sum == target {
			return []int{head + 1, tail + 1}
		} else if sum < target {
			head++
		} else {
			tail--
		}
	}
	return []int{}
}

// 15. 3Sum https://leetcode.com/problems/3sum/description/
func ThreeSum(nums []int) [][]int {
	sort.Ints(nums)
	res := [][]int{}
	for i := 0; i < len(nums)-2; i++ {
		if i > 0 && nums[i] == nums[i-1] {
			continue
		}
		// Early termination optimization
		if nums[i] > 0 {
			break // If smallest number is positive, impossible to sum to 0
		}

		l, r := i+1, len(nums)-1
		for l < r {
			sum := nums[i] + nums[l] + nums[r]
			if sum == 0 {
				res = append(res, []int{nums[i], nums[l], nums[r]})
				for l < r && nums[l] == nums[l+1] {
					l++
				}
				for l < r && nums[r] == nums[r-1] {
					r--
				}
				l++
				r--
			} else if sum < 0 {
				l++
			} else {
				r--
			}
		}
	}
	return res
}
