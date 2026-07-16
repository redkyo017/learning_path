🧠 Pattern: Frequency Counting (The "Bucket" Pattern)Formal Name: Hash Map Frequency Counter.The IntuitionWhen the order of elements doesn't matter, but the content (identity and quantity) does, you need a "Census Taker."Imagine a classroom. If you want to know if Class A and Class B have the exact same set of students, you don't line them up (Sort). You just take attendance (Count).🔍 How to Recognize This PatternWatch for these signals:"Rearrange" / "Permutation": The problem asks if one thing is a reshuffling of another."Majority" / "Frequent": The problem asks for the most frequent element or elements that appear $K$ times."Unique": The problem asks for the first non-repeating character (our next problem!).💡 Google Interview Tip: Map vs. ArrayYour solution uses a map. This is perfect if the input contains Unicode characters (like emojis 🚀 or Kanji 漢).However, if a Google interviewer specifies: "The input consists of only lowercase English letters," they are hinting at a specific optimization.Why?Map: Hashing keys takes time. Overhead is higher.Array: Access is instant arr[index].You can replace map[rune]int with [26]int:Go// Optimization for lowercase English only
func IsAnagramOptimized(s string, t string) bool {
    if len(s) != len(t) { return false }
    
    var counts [26]int // Fixed size array = O(1) space technically
    
    for i := 0; i < len(s); i++ {
        counts[s[i] - 'a']++ // 'a' becomes index 0, 'b' index 1...
        counts[t[i] - 'a']--
    }
    
    for _, count := range counts {
        if count != 0 { return false }
    }
    return true
}
Note: Your map solution is more robust (handles all characters), but the array solution is faster for constrained inputs.

## Day 3 wrap up
1. Two Pointers (Sorted Input)
- Problem: Two Sum II
- The Pattern: When the array is sorted, use pointers at both ends (Start, End).
- The Logic:
    - Sum < Target? Data is too small. Move Start up to increase it.
    - Sum > Target? Data is too big. Move End down to decrease it.
- Why Google Loves It: It turns an $O(N^2)$ search into a linear $O(N)$ scan without using extra memory.

2. Frequency Analysis (The "Bucket" Strategy)
- Problems: Valid Anagram, First Unique Character
- The Pattern: Use a fixed-size array (or Hash Map) to count occurrences.
- The Logic:
    - Phase 1 (Pre-process): Build the "Census" (count everything).
    - Phase 2 (Query): Use the counts to validate conditions (is it 0? is it 1?).

Why Google Loves It: It tests your ability to separate Data Gathering (Pass 1) from Decision Making (Pass 2).