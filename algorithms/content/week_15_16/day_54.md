# Day 54 — Palindrome Pairs + System Design (Weeks 15-16)

**Protocol reminder:** hard 20-25 min timer on the coding problem, hint only after genuinely stuck, log outcome to `content/spaced_review_deck.md` or `content/error_log.md`. The system-design segment below is a lighter, talk-it-through pass — no timer, no hint ladder, just think out loud through the trade-offs for 15-20 min per question.

## Coding: 336. Palindrome Pairs — Hard
Link: https://leetcode.com/problems/palindrome-pairs/

**Hint 1 (direction):** For two words to concatenate into a palindrome, think about what relationship must hold between one word and the *reverse* of the other — this is fundamentally a lookup problem over the word list, not something you should solve by comparing every pair directly.
**Hint 2 (technique):** Recall the Trie from Week 11 — instead of testing all O(n^2) word pairs, insert the *reversed* form of each word into a Trie (or, as a simpler alternative, into a hashmap of `reversed_word -> index`) so you can quickly ask "does the reverse of some substring exist elsewhere in the list?"
**Hint 3 (structure):** For each word, consider every split point into `prefix + suffix`. Case A: if `prefix` is itself a palindrome, check whether `reverse(suffix)` exists in the structure — if so, that word can be placed *before* the current word. Case B: if `suffix` is itself a palindrome, check whether `reverse(prefix)` exists — if so, that word can be placed *after*. The Trie/hashmap turns each existence check into roughly O(length) instead of an O(n) linear scan.
**Hint 4 (implementation):** Handle the empty-prefix and empty-suffix split cases explicitly (they correspond to whole-word palindrome checks) and track original indices so you never pair a word with itself unless it appears twice in the input — duplicate/self-pairing bugs are the most common source of wrong answers here.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Trie-of-reversed-words (or hashmap-of-reversed-words) lookup, replacing the brute-force O(n^2 · k) all-pairs check — same "index the reverse/complement so you can look it up" idea as other Trie-based word problems from Week 11.
- **Core idea:** `word1 + word2` is a palindrome iff, when `word1` is split into `prefix + suffix`, either `prefix` is a palindrome and `reverse(suffix)` is some other word in the list (placed before `word1`), or `suffix` is a palindrome and `reverse(prefix)` is some other word in the list (placed after `word1`).
- **Algorithm:** build a hashmap (or Trie) mapping `reverse(word) -> original index` for every word; for each word `i`, for every split point `k` in `[0, len(word)]`, let `left = word[0:k]`, `right = word[k:]`; if `left` is a palindrome, look up `reverse(right)` and, if found at index `j != i`, record pair `(j, i)`; if `right` is a palindrome, look up `reverse(left)` and, if found at index `j != i`, record pair `(i, j)`.
- **Complexity:** Time O(n · k^2) with the hashmap approach (n words, k = max word length; each split does an O(k) palindrome check and O(k) substring/reverse work) — a full Trie walk that checks palindrome-ness incrementally can tighten this to roughly O(n · k). Space O(n · k) for the stored reversed words.
- **Gotcha:** double-counting or self-pairing — an empty-string split, a word that is itself a palindrome, or two identical words in the input can all cause the same pair to be recorded twice or a word to be paired with its own index; dedupe/guard on index equality carefully.

</details>

---

## System Design Discussion (talk-through, not timed)

For each question, spend 15-20 min talking through: core requirements, a rough high-level
architecture, the one or two hardest trade-offs, and how you'd scale the bottleneck component.
No need to write code — a verbal or whiteboard-style walkthrough is the point.

1. **Design URL Shortener** — the hard part is generating short IDs at scale without collisions (counter-based vs hash-based vs random with retry), plus handling the read-heavy redirect traffic that dwarfs the write path.
2. **Design Chat System** — the hard part is real-time message delivery, keeping message ordering consistent across devices, and syncing missed messages correctly when a client comes back online.
3. **Design News Feed** — the hard part is choosing fan-out-on-write vs fan-out-on-read (or a hybrid) for generating feeds at scale, especially for accounts with very large follower counts.

