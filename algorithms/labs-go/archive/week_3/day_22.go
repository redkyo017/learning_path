package week3

// 148. Sort List https://leetcode.com/problems/sort-list/description/
func mergeSortedList(l1 *ListNode, l2 *ListNode) *ListNode {
	dummy := ListNode{}
	current := &dummy
	for l1 != nil && l2 != nil {
		if l1.Val < l2.Val {
			current.Next = l1
			current = l1
			l1 = l1.Next
		} else {
			current.Next = l2
			current = l2
			l2 = l2.Next
		}
	}
	if l1 != nil {
		current.Next = l1
	}
	if l2 != nil {
		current.Next = l2
	}
	return dummy.Next
}
func SortList(head *ListNode) *ListNode {
	if head == nil || head.Next == nil {
		return head
	}
	slow, fast := head, head.Next
	for fast != nil && fast.Next != nil {
		slow = slow.Next
		fast = fast.Next.Next
	}
	mid := slow.Next
	slow.Next = nil
	return mergeSortedList(SortList(head), SortList(mid))
}
