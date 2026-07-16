package week6

// 173. Binary Search Tree Iterator https://leetcode.com/problems/binary-search-tree-iterator/description/

type BSTIterator struct {
	TreeStack *[]*TreeNode
}

func Constructor(root *TreeNode) BSTIterator {
	stack := []*TreeNode{}
	pushAllLeft(root, &stack)
	return BSTIterator{
		TreeStack: &stack,
	}
}

func (this *BSTIterator) Next() int {
	if !this.HasNext() {
		return -1
	}
	node := (*this.TreeStack)[len(*this.TreeStack)-1]
	(*this.TreeStack) = (*this.TreeStack)[:len(*this.TreeStack)-1]
	if node.Right != nil {
		pushAllLeft(node.Right, this.TreeStack)
	}
	return node.Val
}

func (this *BSTIterator) HasNext() bool {
	return len(*this.TreeStack) > 0
}

func pushAllLeft(root *TreeNode, stack *[]*TreeNode) {
	current := root
	for current != nil {
		*stack = append(*stack, current)
		current = current.Left
	}
}
