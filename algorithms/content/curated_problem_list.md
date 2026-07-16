# Curated Problem List — Weeks 8-16

Source: `curriculum_reference.md` (the original 300-problem, 16-week list). This is the final
day-by-day assignment for Phase 2 — near-duplicates and anything already solved in Phase 1 (or
earlier in Phase 2) are dropped. Each block's last day is that week's self-challenge (mixed,
unlabeled, pulled from everything solved to date, not listed here since it's picked live).

Corrections vs. the original per-block notes in the plan doc: once problems are pinned to
specific days, **Word Break (139), Coin Change (322), and Implement Trie (208)** turn out to
already be covered by Week 9 / Week 11 below — so by the time you reach Weeks 13-14, only
**Course Schedule (207)** and **Lowest Common Ancestor of a Binary Tree (236)** are genuinely
new there (236 is new because Week 6 only covered the BST-specific LCA, #235 — #236 has no BST
property to exploit, so it's a real bridge exercise, not a duplicate).

## Week 8 — Math & Optimization (Days 11-15, Day 16 = self-challenge)

| Day | Problems |
|---|---|
| 11 | 7. Reverse Integer, 9. Palindrome Number, 66. Plus One |
| 12 | 172. Factorial Trailing Zeroes, 231. Power of Two, 8. String to Integer (atoi) |
| 13 | 171. Excel Sheet Column Number, 258. Add Digits, 264. Ugly Number II |
| 14 | 50. Pow(x, n), 43. Multiply Strings, 204. Count Primes |
| 15 | 65. Valid Number, 224. Basic Calculator |

## Week 9 — DP Fundamentals (Days 17-22, Day 23 = self-challenge)

| Day | Problems |
|---|---|
| 17 | 70. Climbing Stairs, 118. Pascal's Triangle, 198. House Robber |
| 18 | 746. Min Cost Climbing Stairs, 55. Jump Game, 62. Unique Paths |
| 19 | 63. Unique Paths II, 64. Minimum Path Sum, 91. Decode Ways |
| 20 | 139. Word Break, 152. Maximum Product Subarray, 213. House Robber II |
| 21 | 279. Perfect Squares, 300. Longest Increasing Subsequence, 322. Coin Change |
| 22 | 32. Longest Valid Parentheses, 72. Edit Distance |

## Week 10 — Advanced DP (Days 24-29, Day 30 = self-challenge)

| Day | Problems |
|---|---|
| 24 | 45. Jump Game II, 97. Interleaving String |
| 25 | 115. Distinct Subsequences, 120. Triangle |
| 26 | 221. Maximal Square, 309. Best Time to Buy/Sell Stock with Cooldown |
| 27 | 377. Combination Sum IV, 416. Partition Equal Subset Sum |
| 28 | 516. Longest Palindromic Subsequence, 10. Regular Expression Matching |
| 29 | 44. Wildcard Matching, 87. Scramble String, 312. Burst Balloons |

(5. Longest Palindromic Substring — already solved Phase 1 Day 2 — is intentionally not
repeated; if it's due in `spaced_review_deck.md` this week, solve it through a DP lens this
time instead of expand-around-center, as a variant, not a new problem.)

## Week 11 — Design & Tries (Days 31-36, Day 37 = self-challenge)

| Day | Problems |
|---|---|
| 31 | 208. Implement Trie (Prefix Tree) |
| 32 | 211. Design Add and Search Words Data Structure |
| 33 | 284. Peeking Iterator, 341. Flatten Nested List Iterator |
| 34 | 380. Insert Delete GetRandom O(1) |
| 35 | 295. Find Median from Data Stream |
| 36 | 348. Design Tic-Tac-Toe, 460. LFU Cache |

(LRU Cache/146, Min Stack/155, BST Iterator/173, Implement Queue-via-Stacks/232, Implement
Stack-via-Queues/225 are already done in Phase 1 — only re-solve them if due for spaced review.)

## Week 12 — Backtracking (Days 38-43, Day 44 = self-challenge)

| Day | Problems |
|---|---|
| 38 | 17. Letter Combinations of a Phone Number, 46. Permutations |
| 39 | 78. Subsets, 90. Subsets II |
| 40 | 39. Combination Sum, 40. Combination Sum II |
| 41 | 47. Permutations II, 131. Palindrome Partitioning |
| 42 | 79. Word Search, 212. Word Search II (builds directly on the Trie from Week 11, Day 31) |
| 43 | 37. Sudoku Solver, 51. N-Queens |

(Generate Parentheses/22 already done in Phase 1 Day 5 — skipped here.)

## Weeks 13-14 — Consolidation + genuinely new (Days 45-50, Day 51 = self-challenge)

| Day | Content |
|---|---|
| 45 | **New:** 207. Course Schedule — use `content/archive/week_7/topology_sort_pattern.md` as the primer, not a new one. |
| 46 | **New:** 236. Lowest Common Ancestor of a Binary Tree — contrast directly against 235 (BST version, already solved): no BST property here, so you can't discard a whole subtree by comparing values; think about what a post-order return value can carry instead. |
| 47-50 | Interleaved timed re-solves of the other 18 "Top 20" problems (146, 200, 3, 76, 56, 15, 297, 128, 33, 49, 102, 133, 5 — all Phase 1; 139, 322 — Week 9; 208 — Week 11; 230 — Phase 1), pulled from `spaced_review_deck.md`/`error_log.md`, ~4-5/day, mixed and unlabeled. No new pattern content needed — this is pure retrieval reinforcement. |

## Weeks 15-16 — Final challenges + system design (Days 52-54, Day 55 = self-challenge)

| Day | Coding (new) | System design (conceptual, lighter pass) |
|---|---|---|
| 52 | 42. Trapping Rain Water | Design Google Search Engine, Design YouTube |
| 53 | 269. Alien Dictionary (topological sort + string parsing — reuse the Week 7 primer) | Design Google Drive, Design Gmail, Design Google Maps |
| 54 | 336. Palindrome Pairs (Trie-based — builds on Week 11) | Design URL Shortener, Design Chat System, Design News Feed |

(84. Largest Rectangle, 239. Sliding Window Maximum, 295. Find Median from Data Stream are
already done — skip unless due for review. System design questions are a talk-it-through
exercise, not a timed-coded one — they're a different skill than DSA and this plan doesn't try
to drill them as deeply.)

## Phase 3 — Finale Gauntlet (Days 56-60)

No fixed list — each day, pull 4-6 problems at random across everything solved in Phases 1-2.
See `docs/superpowers/plans/2026-07-16-dsa-mastery-60-day-plan.md` for the method.
