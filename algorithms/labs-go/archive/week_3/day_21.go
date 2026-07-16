package week3

// 707. Design Linked List https://leetcode.com/problems/design-linked-list/
/**
 * Your MyLinkedList object will be instantiated and called as such:
 * obj := Constructor();
 * param_1 := obj.Get(index);
 * obj.AddAtHead(val);
 * obj.AddAtTail(val);
 * obj.AddAtIndex(index,val);
 * obj.DeleteAtIndex(index);
 */

type MyLinkedListNode struct {
	Val  int
	Prev *MyLinkedListNode
	Next *MyLinkedListNode
}
type MyLinkedList struct {
	Size int
	Head *MyLinkedListNode
	Tail *MyLinkedListNode
}

func Constructor() MyLinkedList {
	dummyHead := &MyLinkedListNode{}
	dummyTail := &MyLinkedListNode{}
	dummyHead.Next = dummyTail
	dummyTail.Prev = dummyHead
	return MyLinkedList{
		Size: 0,
		Head: dummyHead,
		Tail: dummyTail,
	}
}

func (this *MyLinkedList) Get(index int) int {
	p := this.GetNodeAtIndex(index)
	if p == nil {
		return -1
	}
	return p.Val
}

func (this *MyLinkedList) GetNodeAtIndex(index int) *MyLinkedListNode {
	if index < 0 || index >= this.Size {
		return nil
	}
	var current *MyLinkedListNode
	if index >= this.Size/2 {
		current = this.Head.Next
		for i := 0; i < index; i++ {
			current = current.Next
		}
	} else {
		current = this.Tail.Prev
		for i := 0; i < this.Size-index-1; i++ {
			current = current.Prev
		}
	}

	return current
}

func (this *MyLinkedList) AddAtHead(val int) {
	newNode := &MyLinkedListNode{Val: val}
	prev, next := this.Head, this.Head.Next

	newNode.Prev = prev
	newNode.Next = next
	prev.Next = newNode
	next.Prev = newNode
	this.Size++
}

func (this *MyLinkedList) AddAtTail(val int) {
	newNode := &MyLinkedListNode{Val: val}
	prev, next := this.Tail.Prev, this.Tail
	newNode.Prev = prev
	newNode.Next = next
	prev.Next = newNode
	next.Prev = newNode
	this.Size++
}

func (this *MyLinkedList) AddAtIndex(index int, val int) {
	if index > this.Size {
		return
	}
	if index == this.Size {
		this.AddAtTail(val)
		return
	}
	if index == 0 {
		this.AddAtHead(val)
		return
	}
	p := this.GetNodeAtIndex(index)
	prev := p.Prev
	newNode := &MyLinkedListNode{Val: val}
	newNode.Prev = prev
	newNode.Next = p
	prev.Next = newNode
	p.Prev = newNode
	this.Size++
}

func (this *MyLinkedList) DeleteAtIndex(index int) {
	p := this.GetNodeAtIndex(index)
	if p == nil {
		return
	}
	prev := p.Prev
	next := p.Next
	prev.Next = next
	next.Prev = prev
	this.Size--
}
