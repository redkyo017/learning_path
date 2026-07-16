package week1

import (
	"strings"
)

// 121. Best Time to Buy and Sell Stock https://leetcode.com/problems/best-time-to-buy-and-sell-stock/description/
func MaxProfit(prices []int) int {
	minPrice := prices[0]
	maxProfit := 0
	for _, price := range prices[1:] {
		if price < minPrice {
			minPrice = price
		}
		profit := price - minPrice
		if profit > maxProfit {
			maxProfit = profit
		}
	}
	return maxProfit
}

// 125. Valid Palindrome https://leetcode.com/problems/valid-palindrome/description/
func IsPalindrome(s string) bool {
	var isAlphanumeric func(char byte) bool
	isAlphanumeric = func(char byte) bool {
		return (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z') || (char >= '0' && char <= '9')
	}
	left, right := 0, len(s)-1
	for left < right {
		if s[left] == ' ' || !isAlphanumeric(s[left]) {
			left++
			continue
		}
		if s[right] == ' ' || !isAlphanumeric(s[right]) {
			right--
			continue
		}
		if strings.ToLower(string(s[left])) != strings.ToLower(string(s[right])) {
			return false // Found a mismatch? Game over.
		}
		left++
		right--
	}
	return true
}
