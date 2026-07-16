# 🧠 Pattern: Starter Element Optimization (Longest Sequence)

You used this in Longest Consecutive Sequence to avoid the $O(R)$ or $O(N^2)$ trap.

**The Intuition: Avoid Redundancy**

When iterating through a list, if you want to find the longest sequence or chain, you must ensure that you are not re-checking a sequence that has already been counted.
1. Preparation: Store all elements in a Hash Set for $O(1)$ existence checks.
2. The Check: For any element $x$, check if $x-1$ is present.
    - If $x-1$ is present, $x$ is already counted by the sequence that started at $x-1$. $\rightarrow$ SKIP.
    - If $x-1$ is missing, $x$ must be the start of a new, unique sequence. $\rightarrow$ START COUNTING.

This optimization ensures that the total time spent across all inner counting loops adds up to $O(N)$, leading to an overall $O(N)$ complexity.

# 💡 Pattern: Canonical Keying (Grouping Complex Objects)

You used this in Group Anagrams to find a common identity for different strings.

**The Intuition: Normalizing the Data**

When you need to group items (strings, objects, custom data) based on shared underlying data, but their representations are different, you must convert them into a Canonical Form—a single, normalized representation that is identical for all group members.
1. The Key: The canonical form becomes the Hash Map Key.
2. The Value: The list of original items becomes the Hash Map Value.
**Generating the Canonical Key:**
- Strings (Anagrams): Use a Frequency Array (your solution) or a Sorted String (simpler but slower: $O(L \log L)$).
- Objects: Use a combination of immutable properties (e.g., concatenate sorted attributes).

By using a frequency array for characters, you get the absolute best time complexity for strings involving small character sets.