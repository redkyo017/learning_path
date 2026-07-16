package week6

type TreeNode struct {
	Val   int
	Left  *TreeNode
	Right *TreeNode
}

// 450. Delete Node in a BST https://leetcode.com/problems/delete-node-in-a-bst/description/

func DeleteNode(root *TreeNode, key int) *TreeNode {
	if root == nil {
		return nil
	}
	if key < root.Val {
		root.Left = DeleteNode(root.Left, key)
	} else if key > root.Val {
		root.Right = DeleteNode(root.Right, key)
	} else {
		if root.Left == nil && root.Right == nil {
			root = nil
		} else if root.Left == nil {
			root = root.Right
		} else if root.Right == nil {
			root = root.Left
		} else {
			current := root.Right
			for current.Left != nil {
				current = current.Left
			}
			root.Val = current.Val
			root.Right = DeleteNode(root.Right, current.Val)
		}
	}
	return root
}

// 701. Insert into a Binary Search Tree https://leetcode.com/problems/insert-into-a-binary-search-tree/description/
func InsertIntoBST(root *TreeNode, val int) *TreeNode {
	if root == nil {
		return &TreeNode{Val: val}
	}
	if val < root.Val {
		root.Left = InsertIntoBST(root.Left, val)
	} else {
		root.Right = InsertIntoBST(root.Right, val)
	}
	return root
}
