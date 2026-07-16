# Day 53 — Alien Dictionary + System Design (Weeks 15-16)

**Protocol reminder:** hard 20-25 min timer on the coding problem, hint only after genuinely stuck, log outcome to `content/spaced_review_deck.md` or `content/error_log.md`. The system-design segment below is a lighter, talk-it-through pass — no timer, no hint ladder, just think out loud through the trade-offs for 15-20 min per question.

## Coding: 269. Alien Dictionary — Hard
Link: https://leetcode.com/problems/alien-dictionary/

**Hint 1 (direction):** The word list is sorted according to some unknown alien alphabet ordering — think about what a single pair of adjacent words in that list can actually tell you about the relative order of two specific letters (not about the whole alphabet at once).
**Hint 2 (technique):** This is Course-Schedule-style ordering in disguise: build a directed graph where an edge `letterA -> letterB` means "letterA comes before letterB" in the alien alphabet, then topologically sort the letters. See `content/archive/week_7/topology_sort_pattern.md` — Kahn's BFS or the DFS-based approach both apply directly here; nothing about the topo-sort mechanics changes.
**Hint 3 (structure):** The graph-building step is the new part: for each pair of *adjacent* words, walk both words in parallel to find the first index where their characters differ — that single difference gives exactly one edge (earlier char -> later char), and you stop comparing that pair right there. If you reach the end of the shorter word with no difference found, check the invalid edge case: if the *first* word is longer than the second in that scenario (e.g. `["abc", "ab"]`), no valid ordering exists, because "abc" can never come before its own prefix "ab" under any alphabet — return "" immediately.
**Hint 4 (implementation):** Only add each derived edge once (dedupe repeated letter pairs across many word comparisons, or in-degree counts get inflated) and initialize every unique letter appearing anywhere in the input as a graph node with in-degree 0 by default — not just the letters that happen to show up in an edge. After running Kahn's, if the output order contains fewer letters than the total unique-letter count, there's a cycle (or you hit the invalid-prefix case) → return "".

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** topological sort over a graph induced by adjacent-word comparisons — a direct extension of Course Schedule / `topology_sort_pattern.md`, plus a string-comparison preprocessing step.
- **Core idea:** each adjacent word pair contributes at most one ordering edge, taken from the first differing character; a longer word preceding its own prefix is an automatic contradiction with no valid topological order.
- **Algorithm:** collect all unique letters across the input as graph nodes; for each adjacent pair `(w1, w2)`, scan in parallel for the first index `i` where `w1[i] != w2[i]`; if found, add edge `w1[i] -> w2[i]` (if not already present) and increment `w2[i]`'s in-degree; if no differing index is found and `len(w1) > len(w2)`, return "" immediately; otherwise run Kahn's BFS from all in-degree-0 letters, appending to the result as in-degrees hit zero; if the final result's length is less than the number of unique letters, a cycle exists → return "".
- **Complexity:** Time O(C + V + E) where C = total characters across all words (edge derivation, since each adjacent pair only needs one differing-character scan) and V, E are the letters/edges in the derived graph; Space O(V + E) for the adjacency structure and in-degree map.
- **Gotcha:** the invalid-prefix case (`["abc", "ab"]`) produces *no edge at all* from that word pair — it's easy to fall through and treat the input as fine when it's actually unsatisfiable. Also remember to include every letter seen in the input as a node even if it never appears in an edge, or single-letter/no-constraint letters get silently dropped from the output.

</details>

---

## System Design Discussion (talk-through, not timed)

For each question, spend 15-20 min talking through: core requirements, a rough high-level
architecture, the one or two hardest trade-offs, and how you'd scale the bottleneck component.
No need to write code — a verbal or whiteboard-style walkthrough is the point.

1. **Design Google Drive** — the hard part is file chunking and content-addressed deduplication on upload, plus reconciling sync conflicts when the same file is edited offline from multiple devices.
2. **Design Gmail** — the hard part is full-text search at scale over a mailbox with billions of messages, real-time spam/phishing filtering, and tiering storage between hot recent mail and cold archived mail.
3. **Design Google Maps** — the hard part is geospatial indexing (e.g. quad-trees / geohashing) over road-network data, combined with real-time routing that reacts to live traffic conditions at scale.

