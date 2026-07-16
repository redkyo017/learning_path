# Day 42 — Backtracking (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 79. Word Search — Medium
Link: https://leetcode.com/problems/word-search/

**Hint 1 (direction):** You're tracing a path through the grid one adjacent cell at a time, matching one letter of the word per step — think about what has to be true of a cell before you step onto it, and what has to be undone once you step back off it.
**Hint 2 (technique):** Backtrack over grid cells via DFS from each possible start: at each level the "choice" is which of up to 4 neighboring cells to move into next, constrained to the cell matching the word's next character and not already used in the current path.
**Hint 3 (structure):** State = (current cell (r,c), index into word, the grid itself marked for in-path cells). Base case = index == len(word) -> return true (found). At each call: if out of bounds, or grid[r][c] != word[index], or cell already visited in this path -> return false. Otherwise mark cell visited, try DFS on all 4 neighbors with index+1, un-mark the cell, return whether any neighbor succeeded.
**Hint 4 (implementation):** The un-choose step is unmarking the cell as visited (e.g. restoring its original letter after temporarily overwriting it with a sentinel, or clearing a visited-set entry) immediately after all 4 neighbor attempts return, regardless of whether one succeeded — do this even on the success path if you're propagating the boolean up rather than short-circuiting the whole search.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** grid DFS backtracking with an in-path visited marker.
- **State:** current (row, col), current index into the target word, and a marker for cells already used in the current path (commonly done in-place by swapping the cell's letter for a sentinel like `#` and restoring it afterward, avoiding a separate visited matrix).
- **Base case:** index == len(word) -> match found, return true immediately (short-circuit, no need to keep searching).
- **Pruning:** bail out of a branch the instant the current cell doesn't match `word[index]`, is out of bounds, or is already part of the current path — never descend further on an already-invalid path.
- **Complexity:** Time O(rows·cols·4^L) where L = len(word) (4 directions at each of L steps, tried from every starting cell), Space O(L) recursion depth.
- **Gotcha:** Forgetting to restore the sentinel-marked cell before returning up (especially on the success path, if your code returns early without running the restore) leaves the grid corrupted for any subsequent start-cell attempts in the same search.

</details>

---

## Problem 2: 212. Word Search II — Hard
Link: https://leetcode.com/problems/word-search-ii/

**Hint 1 (direction):** Running the Problem 1 search once per word, for every word in a list, re-walks huge overlapping parts of the grid for words that share prefixes — think back to the Trie you built in Week 11 Day 31: what would it let you check in O(1) per step that you were otherwise checking by scanning?
**Hint 2 (technique):** Build one Trie out of all target words first, then backtrack through the grid *once*, walking the Trie alongside your path: at each level the choice is still "which neighbor to step into," but it's only legal if that neighbor's letter is a child of your *current Trie node* (not a fresh prefix check against every word).
**Hint 3 (structure):** State = (current cell, current Trie node, path so far or an index tracked via the Trie node itself). Base case = current Trie node has `isWord == true` -> record the accumulated string as found (then avoid re-adding it — e.g. clear that flag so you don't record it twice from a different path). Loop over 4 neighbors: if neighbor's letter is a child of the current Trie node and neighbor not already in this path, mark visited, recurse into that child node, un-mark.
**Hint 4 (implementation):** Prune the *Trie*, not just the grid: once a Trie node has no children left and is not itself a word-end (i.e. no remaining word depends on this branch), remove it from its parent so future DFS calls stop descending into dead branches entirely — this is what keeps the Hard-tier input sizes tractable instead of re-hitting the same exhausted subtree from every remaining start cell.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Trie-guided grid DFS backtracking (multi-pattern search sharing a prefix structure).
- **State:** current (row, col), current Trie node (replaces tracking a target-word index), and an in-path visited marker on the grid (sentinel-swap or visited set), same mechanics as Word Search I.
- **Base case:** the Trie node reached has a stored complete word at it -> add that word to results; still continue descending (a word can be a prefix of a longer word also in the list).
- **Pruning:** only step into a neighbor whose letter exists as a child of the current Trie node (kills paths no target word could match); additionally prune the Trie itself by deleting exhausted leaf nodes (no children, already found) so later DFS calls from other start cells don't re-explore dead branches — this is the difference between passing and TLE on this Hard problem.
- **Complexity:** Time roughly O(rows·cols·4^L) bounded by total Trie nodes visited (L = max word length), much better in practice than re-running Word Search per word because shared prefixes are walked once; Space O(sum of word lengths) for the Trie + O(L) recursion depth.
- **Gotcha:** Recording the same word twice because two different paths reach the same Trie word-end node — clear or mark the word slot at that Trie node as "already collected" once found, so a second path to it doesn't duplicate the result.

</details>
