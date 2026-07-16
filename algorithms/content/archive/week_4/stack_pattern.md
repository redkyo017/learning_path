# Stack

A stack is a linear data structure that follows the Last-In, First-Out (LIFO) principle, meaning the last element added is the first one to be removed. Real-world analogies include a stack of plates or a web browser's back button history. 

### Core Operations
The primary operations on a stack are:
- Push: Adds a new element to the top of the stack.
- Pop: Removes and returns the top element from the stack.
- Peek: Returns the top element without removing it.
- IsEmpty: Checks if the stack has any elements. 

### Go Implementation Example
The following code demonstrates a simple, type-safe stack implementation using a custom struct wrapping a Go slice. 

```Go
package main

import (
	"fmt"
)

// Stack represents a stack data structure that holds integers.
type Stack struct {
	elements []int
}

// Push adds an element to the top of the stack.
func (s *Stack) Push(value int) {
	s.elements = append(s.elements, value) // Append adds to the end (top)
}

// Pop removes and returns the top element from the stack.
// It also returns a boolean indicating success or failure.
func (s *Stack) Pop() (int, bool) {
	if s.IsEmpty() {
		return 0, false // Stack is empty, cannot pop
	}
	index := len(s.elements) - 1            // Get the index of the top element
	element := s.elements[index]            // Get the element
	s.elements = s.elements[:index]         // Slice it off the stack
	// Optional: erase the element's memory location to prevent memory leaks in long-running apps
	// s.elements[index] = 0 
	return element, true
}

// Peek returns the top element without removing it.
// It also returns a boolean indicating success or failure.
func (s *Stack) Peek() (int, bool) {
	if s.IsEmpty() {
		return 0, false
	}
	index := len(s.elements) - 1
	return s.elements[index], true
}

// IsEmpty checks if the stack is empty.
func (s *Stack) IsEmpty() bool {
	return len(s.elements) == 0
}

func main() {
	// Initialize a new stack
	myStack := Stack{}

	fmt.Printf("Is stack empty? %v\n", myStack.IsEmpty())

	// Push elements onto the stack
	myStack.Push(10)
	myStack.Push(20)
	myStack.Push(30)
	fmt.Printf("Stack after pushes: %v\n", myStack.elements) // Output: [10 20 30]

	// Peek at the top element
	top, ok := myStack.Peek()
	if ok {
		fmt.Printf("Top element is: %d\n", top) // Output: Top element is: 30
	}

	// Pop elements from the stack
	popped1, ok1 := myStack.Pop()
	if ok1 {
		fmt.Printf("Popped element: %d\n", popped1) // Output: Popped element: 30
	}
	fmt.Printf("Stack after first pop: %v\n", myStack.elements) // Output: [10 20]

	popped2, ok2 := myStack.Pop()
	if ok2 {
		fmt.Printf("Popped element: %d\n", popped2) // Output: Popped element: 20
	}
	fmt.Printf("Stack after second pop: %v\n", myStack.elements) // Output: [10]
	
	fmt.Printf("Is stack empty now? %v\n", myStack.IsEmpty())
}
```

### Key Concepts
- LIFO Principle: Notice how 30 was added last but removed first, followed by 20, demonstrating the LIFO behavior.
- Slice as Backbone: The underlying Go slice (elements) handles the dynamic resizing and storage, making implementation straightforward.
- Time Complexity: Both Push (append) and Pop (slicing) operations have a time complexity of O(1) on average (amortized constant time), which is very efficient. 
