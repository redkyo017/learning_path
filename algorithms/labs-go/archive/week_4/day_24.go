package week4

// 232. Implement Queue using Stacks https://leetcode.com/problems/implement-queue-using-stacks/description
type MyQueue struct {
	InputStack  []int
	OutputStack []int
}

func MyQueueConstructor() MyQueue {
	return MyQueue{
		InputStack:  []int{},
		OutputStack: []int{},
	}
}

func (this *MyQueue) Push(x int) {
	this.InputStack = append(this.InputStack, x)
}

func (this *MyQueue) Pop() int {
	this.Peek() // Ensure OutputStack is populated using the logic in Peek

	val := this.OutputStack[len(this.OutputStack)-1]
	this.OutputStack = this.InputStack[:len(this.OutputStack)-1]
	return val
}

func (this *MyQueue) Peek() int {
	if len(this.OutputStack) == 0 {
		for len(this.InputStack) > 0 {
			topIdx := len(this.InputStack) - 1
			val := this.InputStack[topIdx]

			this.OutputStack = append(this.OutputStack, val)
			this.InputStack = this.InputStack[:topIdx]
		}
	}
	return this.OutputStack[len(this.OutputStack)-1]
}

func (this *MyQueue) Empty() bool {
	return len(this.InputStack) == 0 && len(this.OutputStack) == 0
}

/**
 * Your MyQueue object will be instantiated and called as such:
 * obj := Constructor();
 * obj.Push(x);
 * param_2 := obj.Pop();
 * param_3 := obj.Peek();
 * param_4 := obj.Empty();
 */

// 225. Implement Stack using Queues https://leetcode.com/problems/implement-stack-using-queues/description/

type MyStack struct {
	Queue []int
}

func MyStackConstructor() MyStack {
	return MyStack{
		Queue: []int{},
	}
}

func (this *MyStack) Push(x int) {
	size := len(this.Queue)
	this.Queue = append(this.Queue, x)
	for i := size; i >= 0; i-- {
		val := this.Queue[0]
		this.Queue = this.Queue[1:]
		this.Queue = append(this.Queue, val)
	}
}

func (this *MyStack) Pop() int {
	val := this.Queue[0]
	this.Queue = this.Queue[1:]
	return val
}

func (this *MyStack) Top() int {
	return this.Queue[0]
}

func (this *MyStack) Empty() bool {
	return len(this.Queue) == 0
}

/**
 * Your MyStack object will be instantiated and called as such:
 * obj := Constructor();
 * obj.Push(x);
 * param_2 := obj.Pop();
 * param_3 := obj.Top();
 * param_4 := obj.Empty();
 */
