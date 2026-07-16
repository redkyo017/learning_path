package week7

// 133. Clone Graph https://leetcode.com/problems/clone-graph/description/

type Node struct {
	Val       int
	Neighbors []*Node
}

func CloneGraph(node *Node) *Node {
	if node == nil {
		return nil
	}
	visited := map[*Node]*Node{}
	var dfs func(node *Node) *Node
	dfs = func(node *Node) *Node {
		if node == nil {
			return nil
		}
		if n, ok := visited[node]; ok {
			return n
		}
		newNode := Node{
			Val:       node.Val,
			Neighbors: []*Node{},
		}
		visited[node] = &newNode
		for _, neighbor := range node.Neighbors {
			n := dfs(neighbor)
			newNode.Neighbors = append(newNode.Neighbors, n)
		}
		return &newNode
	}
	return dfs(node)
}
