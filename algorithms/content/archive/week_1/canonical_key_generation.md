# 🧠 Pattern: Canonical Key Generation (Advanced Hash Mapping)

The pattern you mastered today is known as **Canonical Key Generation** or **Advanced Hash Keying**.

**The Intuition**

When a problem asks you to group elements based on an intrinsic property that is independent of order (like being an anagram, or having the same digits), you need a Hash Map where the key represents that intrinsic property.

The goal is to find the Canonical Form (the simplest, most standardized representation) of the element.

🔍 Canonical Keying Methods

|Method|When to Use|Time Complexity for Key Generation|Example Key|
|---|---|---|---|
|1. Sorting|General strings (mixed case, symbols).|$O(K \log K)$|"ate" $\rightarrow$ "aet"|
|2. Frequency Array|Fixed, small character set (e.g., only lowercase English letters).|$O(K)$|"ate" $\rightarrow$ "100100...1" (string representation of counts)|
|3. Prime Number Product|For numbers (e.g., if you need a unique hash for a multiset of digits, 2^a * 3^b * 5^c...).|$O(K)$|For digits 1, 2, 2, the key is $2^1 \cdot 3^2$.|