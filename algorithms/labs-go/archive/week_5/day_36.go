package week5

import (
	"math"
	"strconv"
	"strings"
)

// 124. Binary Tree Maximum Path Sum https://leetcode.com/problems/binary-tree-maximum-path-sum/description/
func MaxPathSum(root *TreeNode) int {
	maxSum := math.MinInt64
	var dfs func(node *TreeNode) int
	dfs = func(node *TreeNode) int {
		if node == nil {
			return 0
		}
		leftGain := max(0, dfs(node.Left))
		rightGain := max(0, dfs(node.Right))
		currentSum := node.Val + leftGain + rightGain
		if currentSum > maxSum {
			maxSum = currentSum
		}
		return node.Val + max(leftGain, rightGain)
	}
	dfs(root)
	return maxSum
}

// 297. Serialize and Deserialize Binary Tree https://leetcode.com/problems/serialize-and-deserialize-binary-tree/description/
type Codec struct {
}

func Constructor() Codec {
	return Codec{}
}

// Serializes a tree to a single string.
func (this *Codec) serialize(root *TreeNode) string {
	res := []string{}
	if root == nil {
		return ""
	}
	var dfs func(node *TreeNode)
	dfs = func(node *TreeNode) {
		if node == nil {
			res = append(res, "X")
			return
		}
		val := strconv.Itoa(node.Val)
		res = append(res, val)
		dfs(node.Left)
		dfs(node.Right)
	}
	dfs(root)
	return strings.Join(res, ",")
}

// Deserializes your encoded data to tree.
func (this *Codec) deserialize(data string) *TreeNode {
	if data == "" {
		return nil
	}
	strArr := strings.Split(data, ",")
	var dfs func() *TreeNode
	dfs = func() *TreeNode {
		if len(strArr) == 0 {
			return nil
		}
		rootVal := strArr[0]
		strArr = strArr[1:]
		if rootVal == "X" {
			return nil
		}
		val, _ := strconv.Atoi(rootVal)
		root := &TreeNode{Val: val}
		root.Left = dfs()
		root.Right = dfs()
		return root
	}
	return dfs()
}
