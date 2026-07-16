package week4

// 503. Next Greater Element II https://leetcode.com/problems/next-greater-element-ii/description/
func NextGreaterElements(nums []int) []int {
	n := len(nums)
	ans := make([]int, n)
	for i, _ := range ans {
		ans[i] = -1
	}
	stack := []int{}
	for i := 0; i < 2*n-1; i++ {
		for len(stack) > 0 && nums[i%n] > nums[stack[len(stack)-1]] {
			top := stack[len(stack)-1]
			ans[top] = nums[i%n]
			stack = stack[:len(stack)-1]
		}
		if i < n {
			stack = append(stack, i)
		}
	}
	return ans
}

// 239. Sliding Window Maximum https://leetcode.com/problems/sliding-window-maximum/description/
func MaxSlidingWindow(nums []int, k int) []int {
	dequeStack := []int{}
	ans := []int{}
	for i, num := range nums {
		for len(dequeStack) > 0 && num > nums[dequeStack[len(dequeStack)-1]] {
			dequeStack = dequeStack[:len(dequeStack)-1]
		}
		dequeStack = append(dequeStack, i)
		if len(dequeStack) > 0 && dequeStack[0] < i-k+1 {
			dequeStack = dequeStack[1:]
		}
		if i >= k-1 && len(dequeStack) > 0 {
			ans = append(ans, nums[dequeStack[0]])
		}
	}
	return ans
}
