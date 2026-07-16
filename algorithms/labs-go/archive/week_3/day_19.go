package week3

// 19. Remove Nth Node From End of List https://leetcode.com/problems/remove-nth-node-from-end-of-list/description/

func RemoveNthFromEnd(head *ListNode, n int) *ListNode {
	dummy := ListNode{}
	dummy.Next = head
	fast, slow := &dummy, &dummy
	for i := 0; i < n; i++ {
		if fast.Next == nil {
			// Handles case where n is greater than list length (if allowed by problem constraints)
			// though typically constraints guarantee n <= length
			return head
		}
		// Note: We already accounted for the 'n+1' gap by starting both at the dummy node.
		// If we only advance 'fast' n steps, 'slow' will land on the *predecessor*.
		fast = fast.Next
	}
	// The initial advance should be n steps, which your n+1 logic achieves by advancing 3 times for n=2.
	for fast != nil {
		fast = fast.Next
		slow = slow.Next
	}
	if slow.Next != nil {
		slow.Next = slow.Next.Next
	}
	return dummy.Next
}

// 24. Swap Nodes in Pairs https://leetcode.com/problems/swap-nodes-in-pairs/description/
func SwapPairs(head *ListNode) *ListNode {
	if head == nil || head.Next == nil {
		return head
	}
	dummy := ListNode{}
	dummy.Next = head
	prev := &dummy
	for prev != nil && prev.Next != nil && prev.Next.Next != nil {
		first := prev.Next
		second := first.Next
		first.Next = second.Next
		second.Next = first
		prev.Next = second
		prev = second.Next
	}

	return dummy.Next
}
