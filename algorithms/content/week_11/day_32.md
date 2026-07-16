# Day 32 — Design & Tries (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 211. Design Add and Search Words Data Structure — Medium
Link: https://leetcode.com/problems/design-add-and-search-words-data-structure/

**Hint 1 (direction):** `addWord` is exactly yesterday's trie insert. The new twist is `search(word)`, where `.` can stand in for any single letter — think about what has to change in your character-by-character walk once you can't commit to just one child.
**Hint 2 (technique):** Reuse the Trie from Day 31, but make `search` a DFS/backtracking walk: on a literal character follow the one matching child; on `.` try every existing child and recurse.
**Hint 3 (structure):** `TrieNode` fields are unchanged (children map/array + `isEnd`). Give `search` a helper `dfs(node, index)` so it can branch at a `.` and try multiple children, backtracking after each failed attempt. Worst case cost is O(26^d) where d is the number of dots in the query (bounded by word length), since each dot fans out across all children.
**Hint 4 (implementation):** The base case (`index == len(word)`) must check `node.isEnd`, not merely that `node` is non-nil. Also return false immediately if `node` is nil before dereferencing it, and short-circuit the moment one branch under a `.` succeeds — don't keep searching sibling children after a match.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Trie + DFS backtracking over wildcard branches.
- **Core idea:** `addWord` is a plain trie insert; `search` is a trie walk that follows a single child on a literal character but, on `.`, recursively tries every non-nil child at that level — succeeding if any branch reaches the end of the word on an `isEnd` node.
- **Algorithm:**
  1. `addWord(word)`: standard trie insert (see Day 31).
  2. `search(word)`: call `dfs(root, 0)`.
  3. `dfs(node, i)`: if `i == len(word)`, return `node.isEnd`. If `word[i] != '.'`: let `child = node.children[word[i]]`; return `child != nil && dfs(child, i+1)`. Else (`.`): for each non-nil child `c`, if `dfs(c, i+1)` return true; after trying all, return false.
- **Complexity:** Time O(L) average for words without dots; O(26^d · L) worst case for d dots. Space O(N·L) for trie storage, O(L) recursion stack.
- **Gotcha:** A query made entirely of dots (e.g. `"..."`) forces exploring the full branching factor at every level — don't assume dots are rare among the test cases.

</details>
