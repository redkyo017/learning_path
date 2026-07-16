package week3

// 61. Rotate List https://leetcode.com/problems/rotate-list/description/
func RotateRight(head *ListNode, k int) *ListNode {
	if head == nil || k == 0 {
		return head
	}
	l := 1
	tail := head
	for tail != nil {
		if tail.Next == nil {
			break
		}
		tail = tail.Next
		l++
	}
	offset := k % l
	if offset == 0 {
		return head
	}
	tail.Next = head
	stepToNewTail := l - offset
	newTail := head
	for i := 1; i < stepToNewTail; i++ {
		newTail = newTail.Next
	}
	newHead := newTail.Next
	newTail.Next = nil
	return newHead
}
