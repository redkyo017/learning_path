# Day 46 — Lowest Common Ancestor of a Binary Tree (Weeks 13-14 consolidation)

**Protocol reminder:** same as always — hard 20-25 min timer, hint only after genuinely stuck, log outcome to `content/spaced_review_deck.md` or `content/error_log.md`.

Deliberate contrast: you've already solved 235 (LCA of a BST), where BST ordering lets you compare `p.val`/`q.val` against the current node to decide which single subtree to descend into. Today's tree is a plain binary tree — that ordering trick is gone. Notice where your instinct to "compare values and pick a side" breaks down before reaching for hints.

## Problem: 236. Lowest Common Ancestor of a Binary Tree — Medium
Link: https://leetcode.com/problems/lowest-common-ancestor-of-a-binary-tree/

**Hint 1 (direction):** There is no ordering property here — nothing about a node's value tells you whether `p` or `q` lives in its left or right subtree, so any approach that compares values against the current node like you did for the BST version will not work.
**Hint 2 (technique):** Since you can't decide direction from values alone, you need to actually search both subtrees and let information flow back *up* the call stack from the children to their parent — think post-order recursion.
**Hint 3 (structure):** Define the recursive function to return: the node itself if the current node equals `p` or `q`; otherwise recurse into left and right children first and inspect what *they* returned before deciding what the current node should return.
**Hint 4 (implementation):** If both the left and right recursive calls return non-null, the current node is the split point — the LCA — so return it; if only one side is non-null, that result hasn't found its "meeting point" yet, so just propagate it upward unchanged.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** Post-order recursion with bottom-up information propagation (no BST property to exploit — contrast with LCA-of-BST's top-down, value-comparison descent).
- **Core idea:** each recursive call answers "does p or q (or both) exist in the subtree rooted here, and if both, where do their paths first meet?" — the answer only becomes knowable after both children have reported back.
- **Algorithm:** base case — if `root == null || root == p || root == q`, return `root`; recurse `left = lca(root.left, p, q)` and `right = lca(root.right, p, q)`; if both `left` and `right` are non-null, `root` is the LCA, return `root`; otherwise return whichever of `left`/`right` is non-null (propagate the found node up).
- **Complexity:** Time O(n) — every node visited once in the worst case, Space O(h) recursion stack where h is tree height.
- **Gotcha:** it's tempting to keep comparing node values like in problem 235 — resist it; a plain binary tree gives you no guarantee about which subtree a smaller/larger value lives in, so the only reliable signal is "did this subtree return p, q, or their already-found LCA."

</details>
