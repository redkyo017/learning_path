# Day 31 — Design & Tries (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 208. Implement Trie (Prefix Tree) — Medium
Link: https://leetcode.com/problems/implement-trie-prefix-tree/

**Hint 1 (direction):** Notice that `search` and `startsWith` do almost the same work — both walk the word character by character from the same starting point. The only real question is what you check once the walk ends.
**Hint 2 (technique):** Build a Trie (prefix tree), the structure named in this week's primer — a tree where each edge is a single character.
**Hint 3 (structure):** Each `TrieNode` holds `children map[byte]*TrieNode` (or a fixed `[26]*TrieNode` array for lowercase-only inputs) plus an `isEnd bool`. `insert`, `search`, and `startsWith` are each O(L) in the word/prefix length L, advancing one node per character.
**Hint 4 (implementation):** `startsWith` only needs the path to exist; `search` additionally requires `isEnd == true` on the final node reached. Don't let those two conditions leak into each other, and decide up front how you want to handle an empty-string call.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Trie (prefix tree) traversal.
- **Core idea:** `insert`, `search`, and `startsWith` all reduce to walking (or extending) one node per character starting at the root; the children map/array gives O(1)-ish lookup per character, so every operation costs O(L) regardless of how many words are stored.
- **Algorithm:**
  1. `insert(word)`: start at root; for each character, create the child if missing, then descend into it; after the last character, set `isEnd = true` on the final node.
  2. `search(word)`: walk children by character; if any child is missing, return false; after the full walk, return the final node's `isEnd`.
  3. `startsWith(prefix)`: identical walk to `search`, but return true as soon as the full path exists — no `isEnd` check.
- **Complexity:** Time O(L) per operation (L = word/prefix length). Space O(total characters inserted) worst case.
- **Gotcha:** `search("app")` must return false if only `"apple"` was ever inserted, even though the path a→p→p exists — conflating "path exists" with "word ends here" is the classic bug.

</details>
