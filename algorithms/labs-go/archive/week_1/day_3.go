package week1

// 242. Valid Anagram https://leetcode.com/problems/valid-anagram/description/
func IsAnagram(s string, t string) bool {
	if len(s) != len(t) {
		return false
	}
	frequentTable := make(map[rune]int, len(s))
	for _, char := range s {
		frequentTable[char]++
	}
	for _, char := range t {
		frequentTable[char]--
		if (frequentTable[char]) < 0 {
			return false
		}
	}
	return true
}

// 387. First Unique Character in a String https://leetcode.com/problems/first-unique-character-in-a-string/description/
func FirstUniqChar(s string) int {
	// census := make(map[rune]int, len(s))
	// for _, char := range s {
	// 	census[char]++
	// }
	// for i, char := range s {
	// 	if census[char] == 1 {
	// 		return i
	// 	}
	// }
	// return -1
	freq := make([]int, 26)

	for _, char := range s {
		freq[char-'a']++
	}

	for i, char := range s {
		if freq[char-'a'] == 1 {
			return i
		}
	}
	return -1
}
