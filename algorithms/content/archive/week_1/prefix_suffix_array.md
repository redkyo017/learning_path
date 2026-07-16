# Prefix and suffix arrays
Prefix and suffix arrays are data structures used in string algorithms, with a suffix array being an array of the starting positions of all suffixes of a string, sorted lexicographically. A prefix array, often meaning a prefix sum array, stores the cumulative sum of elements up to each index of a numerical array. The pattern refers to how these structures are used for efficient searching, with suffix arrays helping to quickly find patterns within a text, often in conjunction with a Longest Common Prefix (LCP) array. 
### Suffix array 
- **Definition**: A suffix array is an array of integers that stores the starting positions of all suffixes of a string, sorted in lexicographical (alphabetical) order.
- Example: For the string $"s=abaab"$, the suffixes are:
    - $0:abaab$
    - $1:baab$
    - $2:aab$
    - $3:ab$
    - $4:b$
- The sorted suffixes would be: $aab$ (index 2), $ab$ (index 3), $abaab$ (index 0), $b$ (index 4), and $baab$ (index 1).
- Therefore, the suffix array would be: [2, 3, 0, 4, 1].
- Purpose: Suffix arrays are used for pattern searching, allowing for very fast searches for any pattern within a text. They can also be used for other string-related tasks like finding the longest repeated substring. 
### Prefix array (Prefix Sum Array) 
- Definition: A prefix sum array (or cumulative sum array) is an array where each element stores the sum of all elements up to that index in the original array.
- Example: For the array [1, 2, 3, 4], the prefix sum array would be [1, 3, 6, 10].
    - Index 0: $1$
    - Index 1: $1+2=3$
    - Index 2: $1+2+3=6$
    - Index 3: $1+2+3+4=10$
- Purpose: Prefix sum arrays are used to quickly calculate the sum of any subarray by subtracting the prefix sum at the start index minus one from the prefix sum at the end index. 

#### The pattern: Suffix array and LCP array for pattern matching 
- The most common pattern involves using a suffix array with its companion structure, the LCP (Longest Common Prefix) array.
- The LCP array stores the length of the longest common prefix between consecutive suffixes in the sorted suffix array.
- Benefit: Together, the suffix array and LCP array allow for highly efficient pattern searching. The LCP array helps to avoid redundant comparisons when searching for a pattern, improving the efficiency of the search. 

#### Product except Self at $i$
    {Product Except Self at } i = ({Product of everything to the LEFT of i}) x ({Product of everything to the RIGHT of i))