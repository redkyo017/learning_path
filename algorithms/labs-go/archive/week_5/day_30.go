package week5

/**
 * Definition for a binary tree node.
 * type TreeNode struct {
 *     Val int
 *     Left *TreeNode
 *     Right *TreeNode
 * }
 */
type TreeNode struct {
	Val   int
	Left  *TreeNode
	Right *TreeNode
}

// 94. Binary Tree Inorder Traversal https://leetcode.com/problems/binary-tree-inorder-traversal/description/
func InorderTraversal(root *TreeNode) []int {
	stack := []*TreeNode{}
	current := root

	res := []int{}
	for len(stack) > 0 || current != nil {
		for current != nil {
			stack = append(stack, current)
			current = current.Left
		}
		current = stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		res = append(res, current.Val)
		current = current.Right
	}
	return res
}

// 100. Same Tree https://leetcode.com/problems/same-tree/description/
func IsSameTree(p *TreeNode, q *TreeNode) bool {
	if p == nil && q == nil {
		return true
	}
	if p == nil || q == nil || (p.Val != q.Val) {
		return false
	}
	return IsSameTree(p.Left, q.Left) && IsSameTree(p.Right, q.Right)
}

// 101. Symmetric Tree https://leetcode.com/problems/symmetric-tree/description/
func IsSymmetric(root *TreeNode) bool {
	if root == nil {
		return true
	}
	var symmetric func(p, q *TreeNode) bool
	symmetric = func(p, q *TreeNode) bool {
		if p == nil && q == nil {
			return true
		}
		if p == nil || q == nil || (p.Val != q.Val) {
			return false
		}
		return symmetric(p.Left, q.Right) && symmetric(p.Right, q.Left)
	}
	return symmetric(root.Left, root.Right)
}
