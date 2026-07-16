# 🏛️ Finale Recap: 84. Largest Rectangle in Histogram

This problem is the ultimate test of Monotonic Stack proficiency because it forces you to manage three variables simultaneously: Height, Left Boundary, and Right Boundary.
The Step-by-Step Logic:
1. The "Why": For any bar $i$ to be the "height" of a rectangle, we need to know how far it can stretch left and right. It stops stretching when it hits a bar shorter than itself.
2. The Stack: We keep a Monotonic Increasing stack. This ensures that for any bar we pop, the element below it in the stack is its left limit, and the element currently being processed is its right limit.
3. The Sentinel (0): By adding a 0 to the end of the heights, we ensure the "flushing" of the stack. This forced pop calculates the area for bars that otherwise would have stayed in the stack (like a 1-2-3-4 scenario).
4. The Width Math: * If the stack has elements: $Width = i - stack[top] - 1$
    - If the stack is empty: $Width = i$ (meaning it's the shortest bar seen so far).