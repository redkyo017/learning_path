package week2

// 349. Intersection of Two Arrays https://leetcode.com/problems/intersection-of-two-arrays/description/
func Intersection(nums1 []int, nums2 []int) []int {
	if len(nums1) > len(nums2) {
		nums1, nums2 = nums2, nums1
	}
	freq1 := make(map[int]bool)
	for _, num := range nums1 {
		freq1[num] = true
	}
	freq2 := make(map[int]bool)
	for _, num := range nums2 {
		if freq1[num] {
			freq2[num] = true
		}
	}
	res := []int{}
	for key := range freq2 {
		res = append(res, key)
	}
	return res
}

// 202. Happy Number https://leetcode.com/problems/happy-number/description/
func IsHappy(n int) bool {
	visited := map[int]bool{}
	for n != 1 {
		sum := 0
		for n >= 1 {
			mod := n % 10
			sum += (mod * mod)
			n /= 10
		}
		if visited[sum] {
			return false
		}
		visited[sum] = true
		n = sum
	}
	return true
}
