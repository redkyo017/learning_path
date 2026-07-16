package week2

// 146. LRU Cache https://leetcode.com/problems/lru-cache/description/
// KEY INSIGHT - ALWAYS MAINTAIN DUMMY NODE FOR HEAD AND TAIL
type CacheNode struct {
	Key   int
	Value int
	Prev  *CacheNode
	Next  *CacheNode
}
type LRUCache struct {
	CacheMap map[int]*CacheNode
	Capacity int
	Head     *CacheNode
	Tail     *CacheNode
}

func Constructor(capacity int) LRUCache {
	head := &CacheNode{}
	tail := &CacheNode{}
	head.Next = tail
	tail.Prev = head
	return LRUCache{
		CacheMap: map[int]*CacheNode{},
		Head:     head,
		Tail:     tail,
		Capacity: capacity,
	}
}

func (this *LRUCache) moveToHead(node *CacheNode) {
	this.removeNode(node)
	this.addToHead(node)
}

func (this *LRUCache) addToHead(node *CacheNode) {
	nextNode := this.Head.Next

	node.Next = nextNode
	nextNode.Prev = node

	node.Prev = this.Head
	this.Head.Next = node
}

func (this *LRUCache) removeNode(node *CacheNode) {
	node.Prev.Next = node.Next
	node.Next.Prev = node.Prev
}

func (this *LRUCache) Get(key int) int {
	if node, ok := this.CacheMap[key]; ok {
		this.moveToHead(node)
		return node.Value
	}
	return -1
}

func (this *LRUCache) Put(key int, value int) {
	if node, ok := this.CacheMap[key]; ok {
		this.moveToHead(node)
		node.Value = value
	} else {
		node = &CacheNode{key, value, nil, nil}
		this.CacheMap[key] = node
		if len(this.CacheMap) > this.Capacity {
			LRUNode := this.Tail.Prev

			delete(this.CacheMap, LRUNode.Key)
			this.Tail.Prev = LRUNode.Prev
			this.removeNode(LRUNode)
		}
		this.addToHead(node)
	}
}
