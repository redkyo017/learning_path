package week1

// 5. Longest Palindromic Substring https://leetcode.com/problems/longest-palindromic-substring/description/
func LongestPalindrome(s string) string {
	// SLIDING WINDOW
	// n := len(s)
	// if n < 2 {
	// 	return s
	// }

	// var expandAroundCenter func(string, int, int) string
	// expandAroundCenter = func(s string, left, right int) string {
	// 	for left >= 0 && right < n && s[left] == s[right] {
	// 		left--
	// 		right++
	// 	}
	// 	// When the loop breaks, left and right have OVER-EXPANDED by 1.
	// 	// The last valid palindrome was s[left+1 : right-1].
	// 	return s[left+1 : right]
	// }
	// longest := ""
	// for i := 0; i < n; i++ {
	// 	oddPalindrome := expandAroundCenter(s, i, i)
	// 	evenPalindrome := expandAroundCenter(s, i, i+1)

	// 	if len(oddPalindrome) > len(longest) {
	// 		longest = oddPalindrome
	// 	}
	// 	if len(evenPalindrome) > len(longest) {
	// 		longest = evenPalindrome
	// 	}
	// }
	// return longest

	// (DP) APPROACH
	n := len(s)
	if n < 2 {
		return ""
	}
	// dp[i][j] will be true if s[i..j] is a palindrome
	// Initializes to false by default
	dp := make([][]bool, n)
	for i := range dp {
		dp[i] = make([]bool, n)
	}
	start, maxLen := 0, 1 // Start with the single-character base case
	// Base Case 1: Length 1 (All single characters are palindromes)
	for i := 0; i < n; i++ {
		dp[i][i] = true
	}

	// Base Case 2: Length 2
	for i := 0; i < n-1; i++ {
		if s[i] == s[i+1] {
			dp[i][i+1] = true
			start = i
			maxLen = 2
		}
	}
	// Core Recurrence: Length L from 3 up to N
	for L := 3; L <= n; L++ {
		for i := 0; i < n-L; i++ {
			j := i + L - 1
			// Check 1: Do the inner boundaries match?
			// Check 2: Was the sub-palindrome inside (s[i+1...j-1]) true?
			if s[i] == s[j] && dp[i+1][j-1] {
				dp[i][j] = true

				// Update result if a longer palindrome is found
				if L > maxLen {
					start = i
					maxLen = L
				}
			}
		}
	}
	return s[start : start+maxLen]
}
