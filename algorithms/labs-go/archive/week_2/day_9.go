package week2

// 383. Ransom Note https://leetcode.com/problems/ransom-note/description/
func CanConstruct(ransomNote string, magazine string) bool {
	if len(ransomNote) > len(magazine) {
		return false
	}
	freq := [26]int{}
	for _, letter := range magazine {
		freq[letter-'a']++
	}
	for _, letter := range ransomNote {
		freq[letter-'a']--
		if freq[letter-'a'] < 0 {
			return false
		}
	}

	return true
}

// 169. Majority Element https://leetcode.com/problems/majority-element/description/
func MajorityElement(nums []int) int {
	candidate := nums[0]
	n := len(nums)
	count := 1
	for i := 1; i < n; i++ {
		if nums[i] == candidate {
			count++
		} else {
			count--
		}
		if count == 0 {
			candidate = nums[i]
			count = 1
		}
	}

	// The Verification Phase (OPTIONAL)
	// check := 0
	// for _, num := range nums {
	// 	if num == candidate {
	// 		check++
	// 	}
	// }
	// if check > len(nums)/2 {
	// 	return candidate
	// }
	return candidate
}
