package week3

// 141. Linked List Cycle https://leetcode.com/problems/linked-list-cycle/description/
func HasCycle(head *ListNode) bool {
	fast, slow := head, head

	for fast != nil && fast.Next != nil {
		slow = slow.Next
		fast = fast.Next.Next
		if slow == fast {
			return true
		}
	}
	return false
}

// 160. Intersection of Two Linked Lists https://leetcode.com/problems/intersection-of-two-linked-lists/description/
func GetIntersectionNode(headA, headB *ListNode) *ListNode {
	// APPROACH 1 - COUNT & ALIGN
	// lenA, lenB := 0, 0
	// pA, pB := headA, headB
	// for pA != nil {
	// 	lenA++
	// 	pA = pA.Next
	// }
	// for pB != nil {
	// 	lenB++
	// 	pB = pB.Next
	// }
	// pA, pB = headA, headB
	// if lenA > lenB {
	// 	diff := lenA - lenB
	// 	for i := 0; i < diff; i++ {
	// 		pA = pA.Next
	// 	}
	// } else {
	// 	diff := lenB - lenA
	// 	for i := 0; i < diff; i++ {
	// 		pB = pB.Next
	// 	}
	// }
	// for pA != nil && pB != nil {
	// 	if pA == pB {
	// 		return pA
	// 	}
	// 	pA = pA.Next
	// 	pB = pB.Next
	// }
	// return nil

	// APPROACH 2 - TWO POINTERS ONLY - ELEGANCE
	pA, pB := headA, headB
	for pA != pB {
		if pB == nil {
			pB = headA
		} else {
			pB = pB.Next
		}

		if pA == nil {
			pA = headB
		} else {
			pA = pA.Next
		}
	}
	return pA
}
