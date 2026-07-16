package week5

// 98. Validate Binary Search Tree https://leetcode.com/problems/validate-binary-search-tree/description/
func IsValidBST(root *TreeNode) bool {
	// The "Range" Strategy
	if root == nil {
		return true
	}
	// var isValid func(node *TreeNode, min int, max int) bool
	// isValid = func(node *TreeNode, min int, max int) bool {
	// 	if node == nil {
	// 		return true
	// 	}
	// 	if node.Val <= min || node.Val >= max {
	// 		return false
	// 	}
	// 	return isValid(node.Left, min, node.Val) && isValid(node.Right, node.Val, max)
	// }
	// return isValid(root, math.MinInt64, math.MaxInt64)
	// The "Inorder" Way
	var prev *int
	var dfs func(curr *TreeNode) bool
	dfs = func(curr *TreeNode) bool {
		if curr == nil {
			return true
		}
		leftValid := dfs(curr.Left)
		if !leftValid {
			return false
		}
		if prev != nil && curr.Val <= *prev {
			return false
		}
		prev = &curr.Val
		return dfs(curr.Right)
	}
	return dfs(root)
}

// 235. Lowest Common Ancestor of a Binary Search Tree https://leetcode.com/problems/lowest-common-ancestor-of-a-binary-search-tree/description/
func LowestCommonAncestor(root, p, q *TreeNode) *TreeNode {
	curr := root
	for curr != nil {
		if p.Val < curr.Val && q.Val < curr.Val {
			curr = curr.Left
		} else if p.Val > curr.Val && q.Val > curr.Val {
			curr = curr.Right
		} else {
			return curr // p.Val <= curr.Val && q.Val >= curr.Val) || (p.Val >= curr.Val && q.Val <= curr.Val
		}
	}
	return nil
}

// 230. Kth Smallest Element in a BST https://leetcode.com/problems/kth-smallest-element-in-a-bst/description/
func KthSmallest(root *TreeNode, k int) int {
	var result int
	var dfs func(node *TreeNode)
	dfs = func(node *TreeNode) {
		if node == nil || k < 0 {
			return
		}
		dfs(node.Left)
		if k > 0 {
			k--
			if k == 0 {
				result = node.Val
				return
			}
		}
		dfs(node.Right)
	}
	dfs(root)
	return result
}
