# DSA Mastery — 60-Day Execution Plan

Companion to `docs/superpowers/specs/2026-07-16-dsa-mastery-plan-design.md`. That doc has the
full rationale (mistakes to avoid, daily protocol, why each phase is shaped this way) — this
doc is what you actually follow, day by day. Protocol reminder before Day 1: 70% acquisition
(timer, hint-after-struggle; Refresh phase allows hint-if-genuinely-blanked) + 30% spaced
review pulled from `content/spaced_review_deck.md`, logging every hint/fail to
`content/error_log.md`.

## Phase 1 — Refresh Sprint (Days 1-10)

Source: `labs-go/archive/week_1` … `week_7` (what's actually solved from the first pass — 83
problems total, confirmed against the archived code, not the original day-count). Write new
solves under `labs-go/refresh_sprint/day_N.go`; never edit the archive.

| Day | Problems (LeetCode #) | Notes |
|---|---|---|
| 1 | Two Sum (1), Valid Parentheses (20), Best Time to Buy/Sell Stock (121), Valid Palindrome (125), Valid Anagram (242), First Unique Character (387), Longest Substring w/o Repeating (3), Container With Most Water (11), Group Anagrams (49) | Week 1 core patterns |
| 2 | Merge Intervals (56), Product of Array Except Self (238), Minimum Window Substring (76), Longest Palindromic Substring (5), Two Sum II (167), 3Sum (15), Majority Element (169), Ransom Note (383), Intersection of Two Arrays (349) | Finishes Week 1 + starts Week 2 |
| 3 | Happy Number (202), Longest Consecutive Sequence (128), LRU Cache (146), Subarray Sum Equals K (560), First Missing Positive (41), Single Number (136), Merge Two Sorted Lists (21), Remove Duplicates from Sorted List (83), Remove Linked List Elements (203) | Finishes Week 2 + starts Week 3 |
| 4 | Linked List Cycle (141), Intersection of Two Linked Lists (160), Reverse Linked List (206), Palindrome Linked List (234), Add Two Numbers (2), Remove Nth Node From End (19), Swap Nodes in Pairs (24), Rotate List (61), Design Linked List (707) | Core Week 3 |
| 5 | Sort List (148), Min Stack (155), Backspace String Compare (844), Implement Queue using Stacks (232), Implement Stack using Queues (225), Simplify Path (71), Evaluate Reverse Polish Notation (150), Decode String (394), Generate Parentheses (22) | Finishes Week 3 + starts Week 4 |
| 6 | Next Greater Element I (496), Daily Temperatures (739), Next Greater Element II (503), Sliding Window Maximum (239), Largest Rectangle in Histogram (84), Binary Tree Inorder Traversal (94), Same Tree (100), Symmetric Tree (101), Convert Sorted Array to BST (108) | Finishes Week 4 + starts Week 5 |
| 7 | Path Sum (112), Maximum Depth of Binary Tree (104), Minimum Depth of Binary Tree (111), Balanced Binary Tree (110), Flatten Binary Tree to Linked List (114), Populating Next Right Pointers II (116), Construct Binary Tree from Preorder/Inorder (105), Level Order Traversal (102), Zigzag Level Order Traversal (103) | Core Week 5 |
| 8 | Right Side View (199), Binary Tree Maximum Path Sum (124), Serialize/Deserialize Binary Tree (297), Validate BST (98), Lowest Common Ancestor of BST (235), Kth Smallest Element in BST (230), Find First/Last Position (34), First Bad Version (278), Delete Node in BST (450) | Finishes Week 5 + starts Week 6 |
| 9 | Insert into BST (701), Search in Rotated Sorted Array (33), Find Minimum in Rotated Sorted Array (153), Median of Two Sorted Arrays (4), BST Iterator (173), Find Peak Element (162), Sqrt(x) (69), Number of Islands (200), Flood Fill (733), Max Area of Island (695), Clone Graph (133) | Finishes Week 6 + all of Week 7 |
| 10 | Catch-up: re-solve anything logged as a leech on Days 1-9. Then: first weekly self-challenge — 4 problems picked at random across all of Days 1-9, unlabeled, timed, talk-aloud, no notes. Log to `weekly_challenge_log.md`. Close by reviewing every `error_log.md` entry from this phase. | Phase 1 close-out |

At the end of Day 10 you should have: every solved problem seeded into `spaced_review_deck.md`
at Interval 1, an honest error log of what was actually rusty/forgotten, and a real (not
assumed) read on which of the 7 pattern families need extra attention during Phase 2's review
slots.

## Phase 2 — New Acquisition (Days 11-55)

Source: `content/curriculum_reference.md` (Weeks 8-16), curated into a final day-by-day
assignment in `content/curated_problem_list.md` — that file is authoritative for exactly which
problems land on which day; the table below is a summary. Each day's hints + pattern
explanation live in `content/week_N/day_N.md` (mirrors the `labs-go/week_N/day_N.go` you write
your solve into). Each block's last day is that week's self-challenge: unlabeled, mixed across
*everything* covered to date (not just this block), plus the day's 30% spaced-review slot as
usual.

**These patterns are genuinely new to you (unlike Phase 1's refresh), so struggle-first alone
isn't enough — you have no baseline to struggle from yet.** Each block below has a
`content/week_N/_primer.md`: a short (~20-line) read on what the pattern is, how to recognize
it, the mental model, and common pitfalls. Read that primer once, at the start of Day 1 of
each new block, *before* the day's timer starts — this is the one deliberate exception to
"no reading before struggling," because it's priming genuinely absent knowledge, not
pre-empting a struggle you're capable of having. After the primer, the normal protocol
resumes: warm-up, hard timer, hint only after genuinely stuck. Weeks 8-12 each have their own
primer; Weeks 13-14 (Course Schedule / topological sort) and 15-16 (Alien Dictionary) reuse the
existing `content/archive/week_7/topology_sort_pattern.md` — no new primer needed there, since
that theory is already written down from when the concept was first introduced.

| Days | Block (curriculum ref) | Primer | Listed count | Curation note |
|---|---|---|---|---|
| 11-16 | Week 8: Mathematical & Optimization | `content/week_8/_primer.md` | 20 | Curate to ~12-14; drop near-duplicate easy math (e.g. keep one of Power of Two/Three, not both). |
| 17-23 | Week 9: DP Fundamentals | `content/week_9/_primer.md` | 18 | Curate to ~14-16; this is the real new-territory block — don't over-cut. |
| 24-30 | Week 10: Advanced DP | `content/week_10/_primer.md` | 14 | Keep nearly all; Longest Palindromic Substring (5) already solved in Phase 1 Day 2 — treat as a quick DP-lens re-solve, not new. |
| 31-37 | Week 11: System Design & Advanced Structures | `content/week_11/_primer.md` | 13 | LRU Cache (146), Min Stack (155), BST Iterator (173), Implement Stack/Queue via the other (225/232) are **already done** in Phase 1 — skip re-teaching them, just re-solve cold as review if they're due. Genuinely new: Implement Trie (208), Design Add and Search Words (211), Peeking Iterator (284), Flatten Nested List Iterator (341), Insert Delete GetRandom O(1) (380), Find Median from Data Stream (295), Design Tic-Tac-Toe (348), LFU Cache (460) — 8 problems over 7 days, ~1/day since design problems run longer. |
| 38-44 | Week 12: Backtracking & Advanced Algorithms | `content/week_12/_primer.md` | 13 | Generate Parentheses (22) already done in Phase 1 Day 5 — skip. 12 new backtracking problems over 7 days. |
| 45-51 | Weeks 13-14: Google's Most Frequent 20 | `content/archive/week_7/topology_sort_pattern.md` (for Course Schedule) | 20 | Once Weeks 9/11 are done, only Course Schedule (207) and Lowest Common Ancestor of a Binary Tree (236) are actually still new — Word Break/Coin Change/Implement Trie are already covered by then. Days 45-46 take the two new problems; Days 47-50 are pure interleaved timed re-solves of the other 18, no new content. See `curated_problem_list.md` for the exact split. |
| 52-55 | Weeks 15-16: System Design + Final Challenges | same topological-sort doc (for Alien Dictionary) | 6 coding + 8 design questions | Coding: Trapping Rain Water (42), Alien Dictionary (269 — closes the other open Week 7 gap), Palindrome Pairs (336) are new; Largest Rectangle (84), Sliding Window Maximum (239), Find Median from Data Stream (295, from Week 11 block) are review. System-design questions (Design YouTube, Design Chat System, etc.) are conceptual/whiteboard, not timed-coded — spend one lighter session per day talking through 2-3 of them out loud rather than full timer treatment; they're a different skill than algorithmic coding and don't need the same drilling depth for this plan's goal. |

## Phase 3 — Finale Gauntlet (Days 56-60)

No new material. Each day: 4-6 problems pulled at random across all 16 weeks' patterns,
unlabeled, full timer, talk-aloud, no hints, no notes — the interleaving stress test the whole
plan has been building toward. Log every result to `weekly_challenge_log.md`.

- Day 56-59: mixed gauntlet, prioritizing whatever `error_log.md` shows as still-recurring
  leeches (pull those preferentially into the random mix).
- Day 60: full read-through of `error_log.md` end-to-end. Anything that failed more than once
  across the full 60 days gets one final targeted re-drill. This is the plan's actual finish
  line — not a fixed problem count, but an empty (or fully-understood) error log.
