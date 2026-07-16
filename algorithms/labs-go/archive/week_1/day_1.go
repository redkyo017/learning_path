package week1

// Two Sum https://leetcode.com/problems/two-sum/
// * One-Pass Hash table approach
func TwoSum(nums []int, target int) []int {
	m := make(map[int]int, len(nums))
	for i, num := range nums {
		complement := target - num
		idx, ok := m[complement]
		if ok {
			return []int{i, idx}
		} else {
			m[num] = i
		}
	}
	return []int{}
}

// 20. Valid Parentheses https://leetcode.com/problems/valid-parentheses
func IsValid(s string) bool {
	open_close := map[rune]rune{
		'}': '{',
		']': '[',
		')': '(',
	}
	stack := []rune{}
	for _, char := range s {
		if char == '{' || char == '[' || char == '(' {
			stack = append(stack, char)
			continue
		}
		open := open_close[char]
		if len(stack) > 0 && stack[len(stack)-1] == open {
			stack = stack[:len(stack)-1]
		} else {
			stack = append(stack, char)
		}
	}
	if len(stack) == 0 {
		return true
	}

	return false
}
