# 🎓 Day 5 Wrap-Up: What You Mastered

Day 5 was crucial, as you conquered two of the most complex "Medium" patterns that combine sorting and advanced data structures.

1.Three Pointers (The "Two Sum" Strategy)
- Problem: 3Sum
- The Logic: Fix one pointer ($A$) and use the Converging Two Pointers pattern on the remainder of the sorted array to find $B$ and $C$.
- Key Skill: Mastering the complex logic to skip duplicates in both the outer loop ($A$) and the inner loop ($B$ and $C$) to achieve a bug-free $O(N^2)$ solution.

2.Canonical Key Generation
- Problem: Group Anagrams
- The Logic: Create a unique, hashable fingerprint for an object based on its intrinsic properties, and use this fingerprint as the key in a map to group related objects.
- Key Skill: Knowing that an $O(1)$ lookup data structure (Hash Map) is the right tool, but optimizing the key generation from $O(K \log K)$ (sorting) to $O(K)$ (frequency counting).