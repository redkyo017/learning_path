package week3

// 21. Merge Two Sorted Lists https://leetcode.com/problems/merge-two-sorted-lists/description/
/**
 * Definition for singly-linked list.
 * type ListNode struct {
 *     Val int
 *     Next *ListNode
 * }
 */

type ListNode struct {
	Val  int
	Next *ListNode
}

func MergeTwoLists(list1 *ListNode, list2 *ListNode) *ListNode {
	d := ListNode{}
	current := &d
	for list1 != nil && list2 != nil {
		if list1.Val < list2.Val {
			current.Next = list1
			current = list1
			list1 = list1.Next
		} else {
			current.Next = list2
			current = list2
			list2 = list2.Next
		}
	}
	if list1 != nil {
		current.Next = list1
	}
	if list2 != nil {
		current.Next = list2
	}
	return d.Next
}

// 83. Remove Duplicates from Sorted List https://leetcode.com/problems/remove-duplicates-from-sorted-list/description/
func DeleteDuplicates(head *ListNode) *ListNode {
	current := head
	for current != nil && current.Next != nil {
		if current.Val != current.Next.Val {
			current = current.Next
		} else {
			current.Next = current.Next.Next
		}
	}
	return head
}

// 203. Remove Linked List Elements https://leetcode.com/problems/remove-linked-list-elements/description/
func RemoveElements(head *ListNode, val int) *ListNode {
	d := ListNode{Next: head}
	current := &d

	for current.Next != nil {
		if current.Next.Val == val {
			current.Next = current.Next.Next
		} else {
			current = current.Next
		}
	}

	return &d
}
