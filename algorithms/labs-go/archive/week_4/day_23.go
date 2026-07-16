package week4

// 155. Min Stack https://leetcode.com/problems/min-stack/description/
//
//	type MinStackNode struct {
//		Val     int
//		PrevMin int
//	}
type MinStack struct {
	// stack []MinStackNode
	Stack    []int
	MinStack []int
}

func Constructor() MinStack {
	// return MinStack{
	// 	stack: []MinStackNode{},
	// }
	return MinStack{
		Stack:    []int{},
		MinStack: []int{},
	}
}

func (this *MinStack) Push(val int) {
	// if len(this.stack) == 0 {
	// 	this.stack = append(this.stack, MinStackNode{Val: val, PrevMin: val})
	// } else {
	// 	top := this.stack[len(this.stack)-1]
	// 	prevMin := min(top.PrevMin, val)
	// 	this.stack = append(this.stack, MinStackNode{Val: val, PrevMin: prevMin})
	// }
	this.Stack = append(this.Stack, val)
	if len(this.MinStack) == 0 {
		this.MinStack = append(this.MinStack, val)
	} else {
		prevMin := this.MinStack[len(this.MinStack)-1]
		if val < prevMin {
			this.MinStack = append(this.MinStack, val)
		}
	}
}

func (this *MinStack) Pop() {
	// this.stack = this.stack[:len(this.stack)-1]
	if len(this.Stack) > 0 {
		this.Stack = this.Stack[:len(this.Stack)-1]
	}
	if len(this.MinStack) > 0 {
		this.MinStack = this.MinStack[:len(this.MinStack)-1]
	}
}

func (this *MinStack) Top() int {
	// return this.stack[len(this.stack)-1].Val
	return this.Stack[len(this.Stack)-1]
}

func (this *MinStack) GetMin() int {
	// top := this.stack[len(this.stack)-1]
	// return top.PrevMin
	return this.MinStack[len(this.MinStack)-1]
}

/**
 * Your MinStack object will be instantiated and called as such:
 * obj := Constructor();
 * obj.Push(val);
 * obj.Pop();
 * param_3 := obj.Top();
 * param_4 := obj.GetMin();
 */

// 844. Backspace String Compare https://leetcode.com/problems/backspace-string-compare/description/
func BackspaceCompare(s string, t string) bool {
	// STACK APPROACH - time O(N) - space O(N)
	// s1 := []rune{}
	// s2 := []rune{}
	// for _, c := range s {
	// 	if c == '#' {
	// 		if len(s1) > 0 {
	// 			s1 = s1[:len(s1)-1]
	// 		}
	// 	} else {
	// 		s1 = append(s1, c)
	// 	}
	// }
	// for _, c := range t {
	// 	if c == '#' {
	// 		if len(s2) > 0 {
	// 			s2 = s2[:len(s2)-1]
	// 		}
	// 	} else {
	// 		s2 = append(s2, c)
	// 	}
	// }
	// if len(s1) != len(s2) {
	// 	return false
	// }
	// for i := range s1 {
	// 	if s1[i] != s2[i] {
	// 		return false
	// 	}
	// }
	// return true
	// 2 POINTERS APPROACH - time O(N) - space O(1)
	lenS, lenT := len(s), len(t)
	skipS, skipT := 0, 0
	i, j := lenS-1, lenT-1
	for i >= 0 || j >= 0 {
		for i >= 0 {
			if s[i] == '#' {
				i--
				skipS++
			} else {
				if skipS > 0 {
					i--
					skipS--
				} else {
					break
				}
			}
		}
		for j >= 0 {
			if t[j] == '#' {
				skipT++
				j--
			} else {
				if skipT > 0 {
					j--
					skipT--
				} else {
					break
				}
			}
		}
		if (i >= 0) != (j >= 0) {
			return false
		}
		if i >= 0 && j >= 0 && s[i] != t[j] {
			return false
		}
		i--
		j--
	}
	return true
}
