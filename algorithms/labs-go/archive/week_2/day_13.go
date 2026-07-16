package week2

// 560. Subarray Sum Equals K https://leetcode.com/problems/subarray-sum-equals-k/description/
// Problem Type: Array / Prefix Sum / Hash MapKey
// Insight: This problem asks for the sum of a subarray (a contiguous segment). The sum of any subarray from index $i$ to $j$ can be found using the Prefix Sum technique.
// Prefix Sum: Let $P[x]$ be the sum of all elements from index 0 up to index $x$.The sum of the subarray from $i$ to $j$ is $P[j] - P[i-1]$.
// Hint 1:As you iterate through the array and calculate the current prefix sum, $P_{\text{current}}$, you are looking for a previous prefix sum, $P_{\text{previous}}$, such that:
// $$P_{\text{current}} - P_{\text{previous}} = k$$
// Rearrange this equation to see what value you need to look up instantly in a Hash Map.
// Consider:What value should the Hash Map store as the Key, and what should it store as the Value? (Hint: Multiple subarrays might start at the same prefix sum point.)
func SubarraySum(nums []int, k int) int {
	res := 0
	prefixSumFreqTable := make(map[int]int)
	prefixSumFreqTable[0] = 1
	currentSum := 0
	for _, num := range nums {
		currentSum += num

		requiredPrevSum := currentSum - k
		if count, ok := prefixSumFreqTable[requiredPrevSum]; ok {
			res += count
		}

		prefixSumFreqTable[currentSum]++
	}

	return res
}
