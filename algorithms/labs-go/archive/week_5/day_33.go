package week5

// 102. Binary Tree Level Order Traversal https://leetcode.com/problems/binary-tree-level-order-traversal/description/
func LevelOrder(root *TreeNode) [][]int {
	res := [][]int{}
	if root == nil {
		return res
	}
	queue := []*TreeNode{root}
	for len(queue) > 0 {
		l := len(queue)
		layer := []int{}
		for i := 0; i < l; i++ {
			node := queue[0]
			queue = queue[1:]
			layer = append(layer, node.Val)
			if node.Left != nil {
				queue = append(queue, node.Left)
			}
			if node.Right != nil {
				queue = append(queue, node.Right)
			}
		}
		res = append(res, layer)
	}
	return res
}

// 103. Binary Tree Zigzag Level Order Traversal https://leetcode.com/problems/binary-tree-zigzag-level-order-traversal/description/
func ZigzagLevelOrder(root *TreeNode) [][]int {
	res := [][]int{}
	if root == nil {
		return res
	}
	queue := []*TreeNode{root}
	isReverse := false
	for len(queue) > 0 {
		l := len(queue)
		layer := make([]int, l)
		for i := 0; i < l; i++ {
			node := queue[0]
			queue = queue[1:]
			if isReverse == false {
				layer[i] = node.Val
			} else {
				layer[l-i-1] = node.Val
			}
			if node.Left != nil {
				queue = append(queue, node.Left)
			}
			if node.Right != nil {
				queue = append(queue, node.Right)
			}
		}
		isReverse = !isReverse
		res = append(res, layer)
	}
	return res
}

// 199. Binary Tree Right Side View https://leetcode.com/problems/binary-tree-right-side-view/description/
func RightSideView(root *TreeNode) []int {
	res := []int{}
	if root == nil {
		return res
	}
	// BFS
	// queue := []*TreeNode{root}
	// for len(queue) > 0 {
	// 	l := len(queue)
	// 	for i := 0; i < l; i++ {
	// 		node := queue[0]
	// 		queue = queue[1:]
	// 		if i == l-1 {
	// 			res = append(res, node.Val)
	// 		}
	// 		if node.Left != nil {
	// 			queue = append(queue, node.Left)
	// 		}
	// 		if node.Right != nil {
	// 			queue = append(queue, node.Right)
	// 		}
	// 	}
	// }
	// DFS
	var dfs func(root *TreeNode, res *[]int, depth int)
	dfs = func(root *TreeNode, res *[]int, depth int) {
		if root == nil {
			return
		}
		if depth == len(*res) {
			*res = append(*res, root.Val)
		}
		dfs(root.Right, res, depth+1)
		dfs(root.Left, res, depth+1)
	}
	dfs(root, &res, 0)
	return res
}
