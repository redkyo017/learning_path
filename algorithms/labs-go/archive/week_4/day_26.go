package week4

import (
	"strconv"
	"strings"
)

// 394. Decode String https://leetcode.com/problems/decode-string/description/
func DecodeString(s string) string {
	strStack := []string{}
	countStack := []int{}
	currentStr := ""
	currenCount := 0
	for i := 0; i < len(s); i++ {
		if s[i] >= 'a' && s[i] <= 'z' {
			currentStr += string(s[i])
		}
		if s[i] >= '0' && s[i] <= '9' {
			num, _ := strconv.Atoi(string(s[i]))
			currenCount = currenCount*10 + num
		}
		if s[i] == '[' {
			strStack = append(strStack, currentStr)
			countStack = append(countStack, currenCount)
			currentStr = ""
			currenCount = 0
		}
		if s[i] == ']' {
			prevString := strStack[len(strStack)-1]
			strStack = strStack[:len(strStack)-1]
			multiplier := countStack[len(countStack)-1]
			countStack = countStack[:len(countStack)-1]
			var builder strings.Builder
			builder.Write([]byte(prevString))
			builder.Write([]byte(strings.Repeat(currentStr, multiplier)))
			currentStr = builder.String()
		}
	}
	return currentStr
}

// 22. Generate Parentheses https://leetcode.com/problems/generate-parentheses/description/
func GenerateParenthesis(n int) []string {
	res := []string{}
	var backtrack func(current string, open int, close int)
	backtrack = func(current string, open, close int) {
		if len(current) == n*2 || (open == n && close == n) {
			res = append(res, current)
			return
		}
		if open < n {
			backtrack(string(append([]byte(current), '(')), open+1, close)
		}
		if close < open {
			backtrack(string(append([]byte(current), ')')), open, close+1)
		}
	}
	backtrack("", 0, 0)
	return res
}
