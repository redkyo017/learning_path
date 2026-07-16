# Day 52 — Trapping Rain Water + System Design (Weeks 15-16)

**Protocol reminder:** hard 20-25 min timer on the coding problem, hint only after genuinely stuck, log outcome to `content/spaced_review_deck.md` or `content/error_log.md`. The system-design segment below is a lighter, talk-it-through pass — no timer, no hint ladder, just think out loud through the trade-offs for 15-20 min per question.

## Coding: 42. Trapping Rain Water — Hard
Link: https://leetcode.com/problems/trapping-rain-water/

**Hint 1 (direction):** The water sitting above any bar depends only on the tallest walls somewhere to its left and somewhere to its right — think about what actually bounds the water level at a single index, not the whole skyline at once.
**Hint 2 (technique):** For each index i, the water level there is `min(tallest bar to the left of i, tallest bar to the right of i)`; water trapped at i is that level minus `height[i]` (if positive). The brute-force version recomputes both maxima by scanning outward from every index.
**Hint 3 (structure):** You can precompute a `leftMax[]` and `rightMax[]` array in two linear passes and combine them — or notice you don't need to store both arrays at all: track a running `leftMax` and `rightMax` with two pointers, and always process whichever side currently has the smaller running max.
**Hint 4 (implementation):** Two-pointer version: `l=0, r=n-1, leftMax=0, rightMax=0`; if `height[l] < height[r]`, the left side is the limiting side, so update/consume from `l`; otherwise do the symmetric thing from `r`. Whichever pointer moves, add `runningMax - height[pointer]` to the total only after confirming it's non-negative.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** two-pointer with running maxima (equivalent to prefix/suffix max arrays; also solvable with a monotonic decreasing stack).
- **Core idea:** water above index i = `min(maxLeft[i], maxRight[i]) - height[i]`.
- **Algorithm:** maintain `l, r, leftMax, rightMax`; while `l < r`: if `height[l] < height[r]`, then update `leftMax = max(leftMax, height[l])` and add `leftMax - height[l]` to the answer, then `l++`; else do the mirrored operation on `r`.
- **Complexity:** Time O(n), Space O(1) for the two-pointer version (O(n) if you use explicit prefix/suffix max arrays instead).
- **Gotcha:** the two-pointer swap only works because whichever side has the smaller *running* max is guaranteed to be the actual bottleneck — e.g. if `height[l] < height[r]`, then `rightMax >= height[r] > height[l]`, so the true limiting wall for position `l` is `leftMax`, regardless of what lies further past `r`. Skipping this reasoning and just comparing `height[l]` vs `height[r]` without tracking the running maxes gives wrong answers.

</details>

---

## System Design Discussion (talk-through, not timed)

For each question, spend 15-20 min talking through: core requirements, a rough high-level
architecture, the one or two hardest trade-offs, and how you'd scale the bottleneck component.
No need to write code — a verbal or whiteboard-style walkthrough is the point.

1. **Design Google Search Engine** — the hard part isn't the query box, it's web crawling at a scale that keeps a fresh, deduplicated copy of the web, building and updating an inverted index over it efficiently, and ranking billions of candidate pages for relevance in milliseconds.
2. **Design YouTube** — the hard part is the ingest pipeline: chunked upload, multi-resolution transcoding at scale, and then serving that video back through a CDN so playback stays smooth for millions of concurrent viewers worldwide.

