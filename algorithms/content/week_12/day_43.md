# Day 43 — Backtracking (Phase 2)
Hard 20-25 min timer per problem, no hints until the timer expires and a second attempt also stalls. On a clean solve, log it into `content/spaced_review_deck.md` at Interval 1. If you needed a hint, log it into `content/error_log.md` with a 48h cold-retry date.

## Problem 1: 37. Sudoku Solver — Hard
Link: https://leetcode.com/problems/sudoku-solver/

**Hint 1 (direction):** You're filling in blank cells one at a time, and each fill has to stay consistent with three overlapping constraints at once (its row, its column, its 3x3 box) — think about what "trying a digit" and "giving up on a digit" look like as a single reversible step on the board.
**Hint 2 (technique):** Backtrack over empty cells: at each level the choice is which digit 1-9 to place in the current empty cell, constrained to digits not already present in that cell's row, column, and box.
**Hint 3 (structure):** State = the board itself (mutated in place) + which cell you're currently trying to fill (e.g. the next empty cell in row-major order). Base case = no empty cells remain -> a full valid board is found, propagate success up and stop. For the current empty cell: loop digit 1-9: if digit is valid for this row/col/box, place it, recurse on the next empty cell; if that recursive call succeeds, propagate success (done); otherwise remove the digit (reset cell to blank) and try the next digit.
**Hint 4 (implementation):** The un-choose step is resetting the cell back to blank *specifically* when the recursive call fails, not unconditionally after every recursive call returns — and for efficiency, maintain row/column/box "digit used" sets (booleans or bitmasks) you update on place and revert on un-choose, rather than re-scanning the row/column/box arrays from scratch on every validity check.

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** constraint-satisfaction backtracking over grid cells with row/col/box occupancy tracking.
- **State:** the board (mutated in place) + the position of the next empty cell to fill; validity is checked against three occupancy trackers — one per row, one per column, one per 3x3 box (each indexed 0-8, tracking which digits 1-9 are already used).
- **Base case:** all cells filled (no empty cell left to process) -> solution found, unwind the recursion reporting success without undoing any placements.
- **Pruning:** only attempt digits that pass the row/col/box occupancy check *before* recursing, instead of placing blindly and validating the whole board afterward; maintaining occupancy as sets/bitmasks keeps each check O(1) instead of O(9) rescans.
- **Complexity:** Time worst case exponential (bounded by 9^(number of empty cells)) but the constraint checks prune it to run fast in practice on real puzzles; Space O(1) extra beyond the board and O(81) recursion depth worst case.
- **Gotcha:** Forgetting to revert the row/col/box occupancy trackers (not just the board cell) when backtracking out of a failed digit — the board cell alone getting reset while the occupancy bitmask still marks that digit "used" silently blocks valid placements in siblings.

</details>

---

## Problem 2: 51. N-Queens — Hard
Link: https://leetcode.com/problems/n-queens/

**Hint 1 (direction):** Since no two queens can share a row, column, or diagonal, you can guarantee "one queen per row" for free by deciding column placement one row at a time — think about what you need to remember about columns and diagonals already "claimed" by earlier rows, rather than re-scanning the board for conflicts before every placement.
**Hint 2 (technique):** Backtrack row by row: at each level the choice is which column in the current row to place a queen in, constrained by columns and both diagonal directions already occupied by queens placed in earlier rows.
**Hint 3 (structure):** State = (current row, a record of which columns / diagonals are occupied) rather than a literal board to scan. Base case = row == n -> record the current placement as a solution. Loop `col` from 0 to n-1: if column `col`, diagonal `row-col`, and diagonal `row+col` are all unoccupied, mark them occupied, place queen at (row,col), recurse on row+1, then unmark them (un-choose).
**Hint 4 (implementation):** Track occupancy with three flat structures (a boolean array or bitmask for columns, and two more for the `row-col` and `row+col` diagonal families, offsetting `row-col` by `n-1` so it's never negative) instead of scanning the 2D board for attacks on every placement attempt — that's what keeps each validity check O(1) instead of O(n).

<details>
<summary>Solution & Pattern (open only after solving, or after using all 4 hints and still stuck)</summary>

- **Pattern:** row-by-row constraint backtracking with column/diagonal occupancy tracking (no board rescans).
- **State:** current row index + three occupancy trackers: columns used, `row-col` diagonals used (offset by n-1 to stay non-negative), `row+col` diagonals used; the partial solution is the list of chosen columns per row so far.
- **Base case:** row == n -> every row has a queen with no conflicts; convert the column list into the required board-string output format and record it.
- **Pruning:** a column/diagonal-occupied check happens *before* descending into a row, in O(1) per candidate via the tracker arrays/bitmasks, rather than validating an entire placed board — this is what makes N-Queens tractable well beyond what naive board-scanning backtracking could reach.
- **Complexity:** Time roughly O(n!) worst case (bounded much tighter in practice by the diagonal pruning), Space O(n) recursion depth + O(n) occupancy trackers.
- **Gotcha:** Using a literal 2D board and re-scanning rows/columns/diagonals for attacks on every placement is correct but far too slow for larger n — the column/diagonal-tracker approach is the actual expected solution, not just an optimization.

</details>
