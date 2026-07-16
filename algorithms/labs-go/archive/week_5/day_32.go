package week5

// 108. Convert Sorted Array to Binary Search Tree https://leetcode.com/problems/convert-sorted-array-to-binary-search-tree/description/
func SortedArrayToBST(nums []int) *TreeNode {
	if len(nums) == 0 {
		return nil
	}
	root := &TreeNode{}
	mid := len(nums) / 2
	// mid := left + (right - left) / 2
	root.Val = nums[mid]
	root.Left = SortedArrayToBST(nums[:mid])
	root.Right = SortedArrayToBST(nums[mid+1:])
	return root
}

// 112. Path Sum https://leetcode.com/problems/path-sum/description/
func HasPathSum(root *TreeNode, targetSum int) bool {
	if root == nil {
		return false
	}
	if (root.Val-targetSum) == 0 && root.Left == nil && root.Right == nil {
		return true
	}

	return HasPathSum(root.Left, targetSum-root.Val) || HasPathSum(root.Right, targetSum-root.Val)
}
