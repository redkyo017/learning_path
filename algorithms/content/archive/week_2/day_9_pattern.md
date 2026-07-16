# 🧠 Pattern: Frequency Counting with Array Buckets

You used this pattern in Ransom Note to check the supply of letters against the demand.

The Intuition: Constant-Size Mapping

When dealing with characters from a small, fixed, and known set (like 26 lowercase English letters), an array is a faster, more space-efficient replacement for a Hash Map:

- Hash Map: Requires calculating a hash code, handling collisions, and uses storage for keys and pointers. Space is $O(\text{Key Count})$.
- Array Buckets: The index itself is the key. For the letter 'c', the key is $2$ (since `'c' - 'a' = 2$). This is a direct memory lookup.

The Implementation:

1. Create an integer array of size 26 (e.g., freq := [26]int{}).
2. Map each character c to its index: c - 'a'.
3. First Pass (Supply): Iterate through the magazine (supply), and increment the count at the corresponding index.
4. Second Pass (Demand): Iterate through the ransomNote (demand), and decrement the count. If a count ever drops below zero, you've failed the check.

**Contrast with a General Hash Map**

|Feature|Array Buckets (e.g., [26]int)|General Hash Map (e.g., map[rune]int)|
|---|---|---|
|Complexity|Time: $O(N+M)$, Space: $O(1)$ (constant 26)|Time: $O(N+M)$, Space: $O(k)$ where $k$ is unique chars|
|Lookup|Direct Index Access (fastest)|Hash Function + Collision Resolution (slower)|
|Google Preference|Highly preferred when applicable for its $O(1)$ space optimization and efficiency.|Used when the character set is large (e.g., full Unicode) or keys are complex objects.|

# 💡 Pattern: Boyer-Moore Voting Algorithm

You used this highly specialized pattern in Majority Element to find the answer in $O(1)$ space.

**The Intuition:** The Majority Survives

The core idea is a clever way to exploit the $> \lfloor n/2 \rfloor$ constraint. Imagine the array elements are people in a room, and the majority element is a political party with more members than all other parties combined.

1. We nominate one person as the Candidate.
2. If the next person we see is on the Candidate's side, the Count increases (a vote for the Candidate).
3. If the next person is from the opposition, the Count decreases (a cancellation).
4. If the Count hits 0, it means the previous Candidate has been perfectly cancelled out by the opposition. We then nominate the current person as the New Candidate and reset the count to 1.

Because the true majority element makes up $>50\%$ of the array, it cannot be completely cancelled out. After the entire array is processed, it is guaranteed that the remaining Candidate must be the majority element.

The Benefits:
|Feature|Boyer-Moore Voting Algorithm|Hash Map Counting|
|---|---|---|
|Complexity|Time: $O(N)$, Space: $O(1)$|Time: $O(N)$, Space: $O(N)$ (in the worst case)|
|Applicability|Only when the target appears $> \lfloor n/2 \rfloor$ times.|General purpose for any frequency counting problem.|
|Google Preference|Essential knowledge. Using this algorithm shows a deep understanding of problem constraints and optimization.|The standard, correct, but non-optimal solution for space.|