package week1

// 15. 3Sum https://leetcode.com/problems/3sum/description/

// 49. Group Anagrams https://leetcode.com/problems/group-anagrams/description/
func GroupAnagrams(strs []string) [][]string {
	res := [][]string{}
	anagrams := make(map[string][]string)
	// 1st approach
	// for i := 0; i < len(strs); i++ {
	// 	sortedStr := []byte(strs[i])
	// 	sort.Slice(sortedStr, func(i, j int) bool {
	// 		return sortedStr[i] < sortedStr[j]
	// 	})
	// 	key := string(sortedStr)
	// 	anagrams[key] = append(anagrams[key], strs[i])
	// }
	// 2nd approach
	for _, str := range strs {
		anagram := [26]byte{}
		for _, ch := range str {
			anagram[ch-'a']++
		}
		key := string(anagram[:])
		anagrams[key] = append(anagrams[key], str)
	}
	for _, group := range anagrams {
		res = append(res, group)
	}
	return res
}
