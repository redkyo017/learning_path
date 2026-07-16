# Primer: Advanced Dynamic Programming

**Core idea:** same three-question framework as Week 9's DP Fundamentals primer, but the
state now needs an extra dimension — position in a *second* string/sequence, an interval
`[i, j]`, or a "mode" the state machine is in (holding a stock vs. not, in cooldown vs. not).

**Recognize by:** two strings/sequences in play (edit distance, interleaving strings), interval
language ("split this range", matrix-chain style, burst balloons), or explicit state-machine
phrasing (buy/sell with cooldown, "distinct states you can be in").

**Mental model:** extend Week 9's `state[i]` to `state[i][j]` (two-sequence or interval DP) or
`state[i][mode]` (state machine). Transitions for interval DP usually consider "pick a split
point k between i and j and combine both sides"; transitions for two-string DP usually compare
`s1[i]` vs `s2[j]` and branch on match/mismatch.

**Pitfalls:** state space growth (an O(n²) or O(n³) table is easy to write but check it fits
your constraints); table initialization for two-string DP (row 0 / column 0 base cases are
where most bugs live); confusing "prefix of length i" indexing with "index i" again, now in
two dimensions at once.
