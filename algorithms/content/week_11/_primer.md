# Primer: Design Problems & Tries

**Core idea:** design problems aren't one trick — they're "pick the right data structure(s) to
hit the required complexity for every method." A Trie is one specific structure worth knowing
cold: a tree where each edge is a character, used for prefix-based lookups (autocomplete,
dictionary search).

**Recognize by:** "design a class with these methods and these complexity requirements" (LRU
Cache, Insert/Delete/GetRandom O(1)), or "prefix" / "autocomplete" / "starts with" language
(Trie problems).

**Mental model:**
- For general design problems: write down every required method and its target complexity
  *first*, then pick the structure(s) that satisfy all of them at once (e.g. LRU Cache = hash
  map for O(1) lookup + doubly linked list for O(1) reorder/evict).
- For Tries: each node holds a `children map[byte]*Node` (or fixed `[26]*Node` array) plus an
  `isWord bool`. Insert/search walk one character at a time from the root.

**Pitfalls:** forgetting to handle re-insert/delete of an already-present key in a design
structure; using a Trie when a `map[string]bool` would do (Tries only pay off for genuine
prefix queries); not clarifying complexity requirements before you start coding — the whole
point of the problem is often hiding in a constraint you skimmed past.
