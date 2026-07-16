package week3

// 206. Reverse Linked List https://leetcode.com/problems/reverse-linked-list/description/
func ReverseList(head *ListNode) *ListNode {
	// ITERATIVE
	// var prev *ListNode
	// current := head

	// for current != nil {
	// 	next := current.Next
	// 	current.Next = prev
	// 	prev = current
	// 	current = next
	// }
	// return prev

	// RECURSIVE
	if head == nil || head.Next == nil {
		return head
	}
	newHead := ReverseList(head.Next)
	head.Next.Next = head
	head.Next = nil
	return newHead
}

// 234. Palindrome Linked List https://leetcode.com/problems/palindrome-linked-list/description/c
func IsPalindrome(head *ListNode) bool {
	if head == nil || head.Next == nil {
		return true
	}

	slow, fast := head, head
	for fast != nil && fast.Next != nil {
		slow = slow.Next
		fast = fast.Next.Next
	}
	// ODD CASES
	if fast != nil {
		slow = slow.Next
	}

	var prev *ListNode

	current := slow
	for current != nil {
		next := current.Next
		current.Next = prev
		prev = current
		current = next
	}
	p1, p2 := head, prev

	for p2 != nil {
		if p1.Val != p2.Val {
			return false
		}
		p1 = p1.Next
		p2 = p2.Next
	}
	return true
}

// 2. Add Two Numbers https://leetcode.com/problems/add-two-numbers/description/
func AddTwoNumbers(l1 *ListNode, l2 *ListNode) *ListNode {
	dummy := &ListNode{}
	current := dummy
	carry := 0
	for l1 != nil || l2 != nil || carry != 0 {
		v1 := 0
		if l1 != nil {
			v1 = l1.Val
			l1 = l1.Next
		}
		v2 := 0
		if l2 != nil {
			v2 = l2.Val
			l2 = l2.Next
		}
		sum := v1 + v2 + carry
		newDigit := sum % 10
		carry = sum / 10

		newNode := &ListNode{Val: newDigit}

		current.Next = newNode
		current = current.Next
	}
	return dummy.Next
}
