package week5

import "math"

// 104. Maximum Depth of Binary Tree https://leetcode.com/problems/maximum-depth-of-binary-tree/description/
func MaxDepth(root *TreeNode) int {
	// RECURSIVE WAY
	// var depth func(node *TreeNode) int
	// depth = func(node *TreeNode) int {
	// 	if node == nil {
	// 		return 0
	// 	}
	// 	return 1 + max(depth(node.Left), depth(node.Right))
	// }
	// return depth(root)
	// ITERATIVE WAY (DFS)
	if root == nil {
		return 0
	}
	type NodeDepth struct {
		Node  *TreeNode
		Depth int
	}
	stack := []NodeDepth{{root, 1}}
	maxD := 0
	for len(stack) > 0 {
		n := len(stack)
		for i := 0; i < n; i++ {
			node := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			if node.Depth > maxD {
				maxD = node.Depth
			}
			if node.Node.Left != nil {
				stack = append(stack, NodeDepth{node.Node.Left, node.Depth + 1})
			}
			if node.Node.Right != nil {
				stack = append(stack, NodeDepth{node.Node.Right, node.Depth + 1})
			}
		}
	}
	return maxD
}

// 111. Minimum Depth of Binary Tree https://leetcode.com/problems/minimum-depth-of-binary-tree/description/
func MinDepth(root *TreeNode) int {
	if root == nil {
		return 0
	}
	minD := 1
	queue := []*TreeNode{root}
	for len(queue) > 0 {
		l := len(queue)
		for i := 0; i < l; i++ {
			n := queue[0]
			queue = queue[1:]
			if n.Left == nil && n.Right == nil {
				return minD
			}
			if n.Left != nil {
				queue = append(queue, n.Left)
			}
			if n.Right != nil {
				queue = append(queue, n.Right)
			}
		}
		minD++
	}
	return minD
}

// 110. Balanced Binary Tree https://leetcode.com/problems/balanced-binary-tree/description/
func IsBalanced(root *TreeNode) bool {
	if root == nil {
		return true
	}
	var checkHeight func(node *TreeNode) int
	checkHeight = func(node *TreeNode) int {
		if node == nil {
			return 0
		}
		leftHeight := checkHeight(node.Left)
		if leftHeight == -1 {
			return -1
		}
		rightHeight := checkHeight(node.Right)
		if rightHeight == -1 {
			return -1
		}
		if math.Abs(float64(leftHeight)-float64(rightHeight)) > 1 {
			return -1
		}
		return 1 + max(leftHeight, rightHeight)
	}
	return checkHeight(root) != -1
}
