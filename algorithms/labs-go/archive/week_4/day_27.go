package week4

// 496. Next Greater Element I https://leetcode.com/problems/next-greater-element-i/description/
func NextGreaterElement(nums1 []int, nums2 []int) []int {
	stack := []int{}
	hashTable := make(map[int]int)
	for _, num := range nums2 {
		for len(stack) > 0 && num > stack[len(stack)-1] {
			top := stack[len(stack)-1]
			hashTable[top] = num
			stack = stack[:len(stack)-1]
		}
		stack = append(stack, num)
	}
	ans := []int{}
	for _, num := range nums1 {
		if val, ok := hashTable[num]; ok {
			ans = append(ans, val)
		} else {
			ans = append(ans, -1)
		}
	}
	return ans
}

// 739. Daily Temperatures https://leetcode.com/problems/daily-temperatures/description/
func DailyTemperatures(temperatures []int) []int {
	ans := make([]int, len(temperatures))
	stack := []int{}
	for i, temp := range temperatures {
		for len(stack) > 0 && temp > temperatures[stack[len(stack)-1]] {
			top := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			distance := i - top
			ans[top] = distance
		}
		stack = append(stack, i)
	}
	return ans
}
