package week2

// 128. Longest Consecutive Sequence https://leetcode.com/problems/longest-consecutive-sequence/description/
func LongestConsecutive(nums []int) int {
	if len(nums) == 0 {
		return 0
	}

	// 1. Convert the array to a Set for O(1) lookups
	set := make(map[int]bool)
	for _, num := range nums {
		set[num] = true
	}

	maxConsecutive := 0

	// 2. Iterate through the Set, checking only for "starter" elements
	for num := range set {
		// Check: Is 'num' the START of a sequence? (i.e., is num-1 missing?)
		if set[num-1] {
			// If num-1 exists, this 'num' is not the start. Skip it.
			continue
		}

		// If we reach here, 'num' is a starter. Begin counting the sequence.
		currentNum := num
		currentStreak := 1

		// Increment and count until the next number is not found
		for set[currentNum+1] {
			currentNum++
			currentStreak++
		}

		// Update the global maximum streak
		if currentStreak > maxConsecutive {
			maxConsecutive = currentStreak
		}
	}

	return maxConsecutive
}
