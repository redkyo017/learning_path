package week1

// 3. Longest Substring Without Repeating Characters https://leetcode.com/problems/longest-substring-without-repeating-characters/description/
func LengthOfLongestSubstring(s string) int {
	left, right := 0, 0
	count := make(map[byte]int)
	longest := 0
	// for right < len(s) {
	// 	count[s[right]]++
	// 	if count[s[right]] > 1 {
	// 		for count[s[right]] > 1 && left <= right {
	// 			count[s[left]]--
	// 			left++
	// 		}
	// 	}
	// 	right++
	// 	longest = max(longest, len(s[left:right]))
	// }
	for i := 0; i < len(s); i++ {
		prevIdx, ok := count[s[i]]
		if ok {
			left = max(left, prevIdx+1)
		}
		count[s[i]] = i
		right++
		longest = max(longest, len(s[left:right]))
	}
	return longest
}

// 11. Container With Most Water https://leetcode.com/problems/container-with-most-water/description/
func MaxArea(height []int) int {
	left, right, res := 0, len(height)-1, 0
	for left < right {
		res = max(res, min(height[left], height[right])*(right-left))
		if height[left] < height[right] {
			left++
		} else {
			right--
		}
	}
	return res
}
