# 📐 PART 1: How to Calculate Time & Space Complexity
## Time Complexity - The Step-by-Step Method
#### Step 1: Identify ALL loops and recursive calls
Look for:

for loops
while loops
Recursive function calls
Built-in functions (sort, map, filter, etc.)

#### Step 2: Determine how many times each loop runs
Ask yourself: "As input size n grows, how many iterations?"
#### Step 3: Multiply nested complexities

Sequential operations → Add them
Nested operations → Multiply them

#### Step 4: Keep only the dominant term
Drop constants and lower-order terms.

🔍 Example: Two Sum II Analysis
Let's analyze the Two Pointers solution:
pythondef twoSum(numbers, target):
    left = 0                    # O(1) - constant assignment
    right = len(numbers) - 1    # O(1) - constant assignment
    
    while left < right:         # How many times does this run?
        current_sum = numbers[left] + numbers[right]  # O(1) per iteration
        
        if current_sum == target:
            return [left + 1, right + 1]
        elif current_sum < target:
            left += 1           # O(1) per iteration
        else:
            right -= 1          # O(1) per iteration
Analysis:

The while loop: Each iteration moves AT LEAST one pointer

Left starts at 0, can go up to n-1
Right starts at n-1, can go down to 0
Maximum iterations: n (when pointers meet)


Inside the loop: All operations are O(1)

Array access: O(1)
Arithmetic: O(1)
Comparison: O(1)


Total: O(n) × O(1) = O(n)

Space Complexity:

Only using two pointer variables: left, right
No extra data structures
Space: O(1) (constant extra space)


📊 Common Complexity Patterns
|Code Pattern|Time Complexity|Example|
|---|---|---|
|Single loop through n items|O(n)|for i in range(n)|
|Two nested loops|O(n²)|for i... for j...|
|Binary search / divide by 2|O(log n)|Cutting search space in half|
|Sorted + two pointers|O(n)|Today's problem!|
|Hash map lookup|O(1) average|dict[key]|
|Sorting|O(n log n)|array.sort()|
|Recursive tree (all branches)|O(2ⁿ)|Fibonacci without memoization|
|Dynamic programming|O(n × m)|Usually state dimensions|

💾 Space Complexity - The Mental Checklist
Ask yourself:

Recursive call stack? → O(depth of recursion)
Extra data structures? → O(size of the structure)
In-place modification? → O(1)
Copying the input? → O(n)

Example Questions to Ask:

"Am I creating a new array?" → O(n) space
"Am I using a hash map?" → O(k) where k = unique elements
"Just a few variables?" → O(1) space


🎯 Practice: Quick Complexity Quiz
What's the time complexity of each?
```
python
# Snippet 1
for i in range(n):
    print(i)
# Answer: ?

# Snippet 2
for i in range(n):
    for j in range(i, n):
        print(i, j)
# Answer: ?

# Snippet 3
def binary_search(arr, target):
    left, right = 0, len(arr) - 1
    while left <= right:
        mid = (left + right) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            left = mid + 1
        else:
            right = mid - 1
# Answer: ?
```

<details>
<summary>Click to see answers</summary>

1. **O(n)** - single loop
2. **O(n²)** - nested loop, inner runs n + (n-1) + (n-2) + ... = n²/2 → O(n²)
3. **O(log n)** - halving search space each iteration
</details>

---

## 🧠 **PART 2: The Pattern Recognition Mindset**

### **🎯 The 3-Question Framework**

When you see a NEW problem, ask yourself these **in order**:

#### **Question 1: What's the INPUT structure?**
- Array? → Two pointers, sliding window, binary search
- String? → Two pointers, hash map, sliding window
- Tree? → DFS, BFS, recursion
- Graph? → DFS, BFS, topological sort, Union-Find
- Number? → Math, bit manipulation

#### **Question 2: What's the CONSTRAINT?**
- **"Sorted"** → Binary search or two pointers
- **"In-place"** → Two pointers (slow/fast)
- **"Substring/subarray"** → Sliding window
- **"All combinations"** → Backtracking
- **"Optimal substructure"** → Dynamic Programming
- **"Find cycle"** → Fast/slow pointers or Union-Find

#### **Question 3: What's the GOAL?**
- Find a pair/triplet? → Two pointers or hash map
- Find all substrings? → Sliding window
- Optimize something? → Greedy or DP
- Count something? → DP or math
- Shortest path? → BFS

---

### **🔑 Pattern Recognition for Two Sum II**

Let's apply the framework:

**Question 1: What's the input?**
→ **Sorted array** ← 🚨 HUGE CLUE!

**Question 2: What's the constraint?**
→ Array is **sorted in non-decreasing order**
→ Exactly **one solution** exists

**Question 3: What's the goal?**
→ Find a **pair** that sums to target

**Pattern Match:**
✅ Sorted array + Find a pair = **TWO POINTERS (converging)**

---

### **🎨 Visual Pattern Matching Guide**

Here's how to think about problems:
```
Problem Keywords           →  Think This Pattern
──────────────────────────────────────────────────
"sorted array"            →  Binary search OR Two pointers
"find pair/triplet"       →  Two pointers OR Hash map
"substring/subarray"      →  Sliding window
"in-place"                →  Two pointers (slow/fast)
"palindrome"              →  Two pointers (converging)
"cycle"                   →  Fast/slow pointers
"parentheses"             →  Stack
"all combinations"        →  Backtracking
"optimize/minimize"       →  DP OR Greedy
"shortest path"           →  BFS
"connected components"    →  DFS OR Union-Find
```

---

### **💡 The "Why Two Pointers?" Decision Tree**
```
Is the array sorted? 
    ├─ YES → Two pointers likely!
    │        └─ Finding pairs? → Converging pointers
    │        └─ Removing elements? → Slow/fast pointers
    │
    └─ NO → Can you sort it?
             ├─ YES → Sort first, then two pointers
             └─ NO → Consider hash map or sliding window

🧪 Pattern Recognition Practice
Try to identify the pattern BEFORE coding:

"Given a sorted array, find if any two numbers sum to target"

Pattern: ?


"Given a string, find the longest substring without repeating characters"

Pattern: ?


"Given an array, find all pairs that sum to target (unsorted)"

Pattern: ?



<details>
<summary>Click for answers</summary>

Two Pointers (sorted + pair = converging pointers)
Sliding Window (substring + condition = expanding/shrinking window)
Hash Map (unsorted + all pairs = store complements)

</details>

🎯 Two Sum II - Complete Solution with Analysis
Now let's see the full solution with annotations:
pythondef twoSum(numbers, target):
    """
    Two Pointers (Converging) Pattern
    
    Intuition: Since array is sorted, we can use two pointers:
    - If sum is too small → move left pointer right (increase sum)
    - If sum is too large → move right pointer left (decrease sum)
    - This works because sorted order guarantees direction
    """
    left = 0
    right = len(numbers) - 1
    
    # Pointers meet when answer is found or would cross
    while left < right:
        current_sum = numbers[left] + numbers[right]
        
        if current_sum == target:
            # Problem uses 1-indexed, so add 1 to each
            return [left + 1, right + 1]
        elif current_sum < target:
            # Sum too small, need larger numbers → move left right
            left += 1
        else:
            # Sum too large, need smaller numbers → move right left
            right -= 1
    
    # Problem guarantees exactly one solution, so we'll never reach here
    return []

# Time Complexity: O(n) - visit each element at most once
# Space Complexity: O(1) - only using two pointer variables

📝 Your Mental Checklist for Every Problem
Before coding, always:

✅ Identify the pattern (use the 3-question framework)
✅ Sketch the approach (draw it out!)
✅ Consider edge cases (empty array? one element? all same?)
✅ Think complexity (can I do better than brute force?)
✅ Code cleanly (clear variable names, comments)
✅ Test thoroughly (happy path + edge cases)


🎤 Interview Pro Tip
When explaining complexity in an interview, say it like this:

"The time complexity is O(n) because we use two pointers that each traverse the array at most once. In the worst case, the pointers start at opposite ends and meet in the middle, visiting all n elements. The space complexity is O(1) since we only use two pointer variables regardless of input size."

Not just "O(n)" - explain the REASONING!