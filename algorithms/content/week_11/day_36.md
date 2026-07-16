# Day 36 — Design & Tries (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 348. Design Tic-Tac-Toe — Medium
Link: https://leetcode.com/problems/design-tic-tac-toe/

**Hint 1 (direction):** Before reaching for a full n×n board, think about what detecting a "win" actually requires — you don't need the board's full contents, only whether one row, column, or diagonal has just become completely one player's.
**Hint 2 (technique):** Track running counts per row, per column, and per diagonal instead of materializing the grid — an O(1)-per-move design, the same "map each method to a structure" move the primer describes.
**Hint 3 (structure):** Fields: `rows []int` and `cols []int` each sized n, plus scalar `diag int` and `antiDiag int`. Encode player 1 as `+1` and player 2 as `-1`. On a move at `(row, col)` by that player, add the delta to `rows[row]` and `cols[col]`; also add it to `diag` if `row == col`, and to `antiDiag` if `row + col == n - 1`. `move()` is O(1).
**Hint 4 (implementation):** After updating, a win is `abs(rows[row]) == n || abs(cols[col]) == n || abs(diag) == n || abs(antiDiag) == n` — return that player's number, else 0. Watch the anti-diagonal condition specifically: it's `row + col == n - 1`, not `n`.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** running row/column/diagonal tallies instead of a materialized board.
- **Core idea:** A win only depends on one row, one column, or (when applicable) one of the two diagonals reaching n marks from a single player, so signed counters per line let `move()` decide the outcome in O(1) instead of rescanning the board.
- **Algorithm:** `move(row, col, player)`: let `delta = +1` if `player == 1` else `-1`. `rows[row] += delta`; `cols[col] += delta`. If `row == col`: `diag += delta`. If `row + col == n - 1`: `antiDiag += delta`. If `abs(rows[row]) == n || abs(cols[col]) == n || abs(diag) == n || abs(antiDiag) == n`: return `player`. Else return `0`.
- **Complexity:** Time O(1) per move. Space O(n).
- **Gotcha:** A cell that lies on neither diagonal must skip updating `diag`/`antiDiag` entirely — updating them unconditionally silently corrupts the tally for unrelated moves.

</details>

---

## Problem 2: 460. LFU Cache — Hard
Link: https://leetcode.com/problems/lfu-cache/

> **Difficulty flag:** this is meaningfully harder than the LRU Cache you already solved earlier in the plan. LRU only tracks recency; LFU tracks recency *within* frequency and evicts by least-frequent-then-least-recent, which needs frequency buckets, not just one hash map + one linked list. Budget extra time and treat this as a fair candidate for a spillover session if the timer expires twice.

**Hint 1 (direction):** Ask what LRU's single hash-map-plus-linked-list is missing here: you no longer evict by recency alone, you evict by lowest access frequency, breaking ties by recency *within* that frequency. That's a second axis LRU never had to track.
**Hint 2 (technique):** Use frequency buckets: a hash map from frequency count to an ordered (doubly linked) list of keys at that frequency, alongside a hash map from key to its node — a "hash map of linked lists," not a single linked list.
**Hint 3 (structure):** `keyMap map[int]*Node` (node holds key, value, freq) gives O(1) value/frequency lookup. `freqMap map[int]*DoublyLinkedList` maps each frequency to a doubly linked list of nodes at that frequency, ordered MRU-to-LRU within the bucket. `minFreq int` tracks the current lowest non-empty frequency bucket, so eviction never has to scan for a minimum. `get`/`put` are both O(1) amortized.
**Hint 4 (implementation):** On every `get`, and on every `put` that touches an existing key, you must: unlink the node from its current frequency bucket's list, increment its frequency, relink it at the front of the new bucket's list, and — if the old bucket is now empty and `minFreq` was pointing at it — increment `minFreq`. On a brand-new `put` at full capacity, evict the tail (least-recent) node of the `minFreq` bucket first, then insert the new key at frequency 1 and reset `minFreq` to 1.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** frequency-bucketed hash map of doubly linked lists (LFU with LRU tiebreak).
- **Core idea:** `get`/`put` both need O(1), which rules out re-sorting by frequency on every access. Instead, each frequency value owns its own doubly linked list (O(1) move-between-buckets, O(1) LRU eviction within a bucket), and `minFreq` is maintained incrementally so eviction never scans for the minimum.
- **Algorithm:** `get(key)`: if `key` not in `keyMap`, return -1. Let `node = keyMap[key]`; `touch(node)` (remove from `freqMap[node.freq]`'s list, increment `node.freq`, insert at the front of `freqMap[node.freq]`'s list, and if the old bucket is now empty and equals `minFreq`, increment `minFreq`); return `node.value`. `put(key, value)`: if capacity is 0, return. If `key` already in `keyMap`: update `node.value`, then `touch(node)`; return. If `len(keyMap) == capacity`: evict the tail node of `freqMap[minFreq]`'s list and delete it from `keyMap`. Create a new node with `freq = 1`, insert it at the front of `freqMap[1]`, set `keyMap[key] = node`, and set `minFreq = 1`.
- **Complexity:** Time O(1) amortized for `get` and `put`. Space O(capacity).
- **Gotcha:** Forgetting to reset `minFreq` to 1 on *every* fresh key insertion (not only on eviction) — a newly inserted key always starts at frequency 1, which is always ≤ the current `minFreq`, so `minFreq` must become 1 every time, not just wherever it happened to be left.

</details>
