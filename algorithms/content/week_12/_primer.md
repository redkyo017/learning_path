# Primer: Backtracking

**Core idea:** exhaustive search with pruning. Build a partial solution one choice at a time,
recurse into the next choice, and undo ("backtrack") the last choice once that branch is
exhausted or proven invalid.

**Recognize by:** "generate all...", "find every combination/permutation/subset", or
constraint-satisfaction framing (N-Queens, Sudoku, word search on a grid).

**Mental model:** the recursive shape is always *choose → explore → un-choose*.
- State = the current partial solution + what choices remain.
- Base case = the partial solution is complete (record it) or provably invalid (return early).
- The "un-choose" step is not optional — it's what makes the same recursive call able to try
  the next option after backtracking out of the previous one.

**Pitfalls:** forgetting to un-choose (mutating a shared slice/map without reverting it before
the next sibling call — the single most common backtracking bug); not pruning early (checking
validity only once the solution is fully built instead of at each partial step, which wastes
huge amounts of work); duplicate results when the input has duplicate values (needs a sort
first + a "skip if same as previous sibling" guard).
