# Day 4 Wrap-Up: What You Mastered
Today you tackled two "Medium" problems that are highly frequent in Google interviews.

1.Sliding Window (Variable Size)
- Problem: Longest Substring Without Repeating Characters
- The Pattern: Expand right to find new valid elements. Contract left when the window becomes invalid (duplicates).
- Key Skill: Managing a dynamic range and using a Hash Map/Set for $O(1)$ condition checking.

2.Two Pointers (Greedy Optimization)
- Problem: Container With Most Water
- The Pattern: Start with the widest possible range. Shrink based on the "limiting factor" (the shorter line).
- Key Skill: Proving that the discarded options could not possibly be the answer.

# 🧠 Pattern 1: The Sliding Window (Dynamic Subarray)

### The Mindset: Trading Space for an Optimal Scan
The core idea is to find the longest/shortest contiguous subarray (or substring) that satisfies a specific condition (e.g., no repeating characters, sum less than $K$, etc.).
You want to avoid the $O(N^2)$ brute-force check of every single subarray. The only way to guarantee $O(N)$ is to ensure each element is touched a constant number of times.

**The "Aha!" Moment**

When you see a duplicate or violate the condition (the Invalid State):

- 1.Stop expanding the window with the right pointer.
- 2.Fix the window by moving the left pointer only as far as necessary to restore the condition.

🔍 Recognition Signals
|Signal|Problem Type|
|---|---|
|"Longest/Shortest Substring/Subarray"|Always think Sliding Window first.|
|"Property X must be met"|You need a map/set to track the frequency/count inside the window.|
|"O(N) time complexity is required"|You must use a single pass (or single pass with an inner loop that doesn't cause $O(N^2)$).|

# 🧠 Pattern 2: Two Pointers (Greedy Elimination)
**The Mindset: Proving the Discarded Path is Useless**
This pattern is used to maximize or minimize a value where the calculation depends on two factors that move in opposite directions (like $Area = Width \times Height$).

Instead of checking every pair of elements, we use a Greedy approach: we make the locally optimal choice at every step and prove it won't jeopardize the global maximum.

**The "Aha!" Moment**
In Container With Most Water, the area $A$ is limited by the shorter wall ($H_{\text{min}}$).$$A = W \cdot H_{\text{min}}$$
If we move the taller wall inward, we guarantee two losses:

- 1.Loss of Width ($\downarrow W$)
- 2.No Gain in Height ($\uparrow H_{\text{min}}$) (because the height is still capped by the shorter wall).

Therefore, the only profitable move is to move the shorter wall inward, giving us the only chance to find a new wall that is tall enough to increase $H_{\text{min}}$ and offset the loss of width. You safely eliminate every combination involving that short wall.
🔍 Recognition Signals
|Signal|Problem Type|
|---|---|
|Maximize Area/Volume/Difference|When the formula involves two variables (e.g., $X \cdot Y$).|
|Two variables are inversely linked|Often seen where one variable (like width) decreases, forcing the other (height) to compensate.|
|Unsorted or non-sequential data|Unlike Palindromes, the goal is optimization, not just symmetry checking.|

💡 Key Difference
|Feature|Sliding Window|Two Pointers (Greedy)|
|---|---|---|
|Goal|Find the best contiguous subarray/substring.|Find the best pair of indices.|
|Movement|Pointers move in the same direction (left chases right).|Pointers move toward each other (left and right).|
|Decision|Based on Internal State (Is the window valid?).|Based on External Calculation (Which pointer is the bottleneck?).|