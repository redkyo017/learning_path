# Day 34 — Design & Tries (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 380. Insert Delete GetRandom O(1) — Medium
Link: https://leetcode.com/problems/insert-delete-getrandom-o1/

**Hint 1 (direction):** As the primer says, write down each method's target complexity first. `getRandom` needing O(1) *and* uniform-random access is the giveaway that a hash map alone (great for insert/remove) can't carry this by itself — you need something indexable too.
**Hint 2 (technique):** Combine a dynamic array (slice) for O(1) uniform random access with a hash map from value to that value's index in the array, for O(1) lookup.
**Hint 3 (structure):** Fields: `data []int` holding the values, `index map[int]int` mapping value → its position in `data`. `insert(val)`: if `val` is already in `index`, return false; else append to `data`, set `index[val] = len(data)-1`, return true. `remove(val)`: if `val` isn't in `index`, return false; otherwise look up its position and remove it in O(1) (see Hint 4). `getRandom()`: return `data[rand.Intn(len(data))]`.
**Hint 4 (implementation):** O(1) removal from a slice works by swapping the target element with the *last* element in `data` (and updating the moved element's entry in `index`), then truncating the last slot off — never shift the whole array down. Handle the case where the removed value *is* the last element (a self-swap) without corrupting the map.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** array + hash-map-of-indices for O(1) random access with O(1) mutation.
- **Core idea:** `getRandom` demands O(1) uniform access, which only an array's indexing gives you; `insert`/`remove` demand O(1) lookup, which only a hash map gives you. Combining them requires keeping the map's stored index in sync on every array mutation — which is exactly why removal swaps with the last element instead of shifting.
- **Algorithm:** `insert(val)`: if `val` already in `index` map, return false. Append `val` to `data`; set `index[val] = len(data)-1`; return true. `remove(val)`: if `val` not in `index`, return false. Let `i = index[val]`, `last = data[len(data)-1]`. Set `data[i] = last`; update `index[last] = i`. Pop the last element off `data`. Delete `val` from `index`. Return true. `getRandom()`: return `data[rand.Intn(len(data))]`.
- **Complexity:** Time O(1) average for all three methods. Space O(n) for n stored elements.
- **Gotcha:** When the value being removed is itself the last element, the swap is a self-assignment — delete `val` from the index map *after* the swap-and-pop step, not before, or you'll delete the wrong entry.

</details>
