package week4

// 84. Largest Rectangle in Histogram https://leetcode.com/problems/largest-rectangle-in-histogram/description/
func LargestRectangleArea(heights []int) int {
	res := 0
	stack := []int{}
	heights = append(heights, 0) // Add a dummy 0 to the end to force the stack to empty
	for i, height := range heights {
		for len(stack) > 0 && height < heights[stack[len(stack)-1]] {
			top := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			h := heights[top]
			width := 0
			if len(stack) == 0 {
				width = i
			} else {
				leftBoundary := stack[len(stack)-1]
				width = i - leftBoundary - 1
			}
			if h*width > res {
				res = h * width
			}
		}
		stack = append(stack, i)
	}
	return res
}
