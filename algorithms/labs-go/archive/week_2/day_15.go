package week2

func SingleNumber(nums []int) int {
	// O(1) AUXILIARY SPACE
	res := 0
	for _, num := range nums {
		res ^= num
	}
	return res
}
