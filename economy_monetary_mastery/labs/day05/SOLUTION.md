# Solution notes — Day 05

## `duration_price_change`
Key idea: modified duration is the percentage price change per unit yield change, so the dollar change on a position is minus duration times the yield move times the position value. Yields up, value down.
Formula: `-mod_duration * dy * value` with `dy` as a decimal (0.02 for 2 points).
Common mistake: passing percent (2) instead of decimal, or dropping the sign. `test_duration_approximation` checks both a rise (-12) and a fall (+6).

## `convexity_price_change`
Key idea: price is a curve, not a line in yield; the duration line over-states losses and under-states gains. The second-order term corrects that and is always positive.
Formula: `-mod_duration * dy * value + 0.5 * convexity * dy**2 * value`.
Common mistake: forgetting the 0.5 or squaring wrongly (`dy*2`). The test expects -12 + 0.8 = -11.2.

## `equity_after_marking`
Key idea: equity is assets minus liabilities, so recognising an asset loss lowers equity one for one. A negative loss is a gain.
Formula: `equity - unrealized_loss`.
Common mistake: also subtracting from liabilities. `test_equity_after_marking` covers the loss (16 - 15.1 = 0.9) and the gain case.

## `drawdown_series`
Key idea: compare every price with the highest price seen so far.
Formula: `prices / prices.cummax() - 1`.
Common mistake: using the global `max()` (that looks into the future) or `pct_change`. The test series `[100,120,90,130]` gives `[0,0,-0.25,0]`.

## `max_drawdown`
Key idea: the worst point of the drawdown series.
Formula: `drawdown_series(prices).min()`.
Common mistake: using `.max()` (always 0) or returning a positive number. The monotonic test requires exactly 0.

## What the output means
Between end-2021 and end-2022 the 10-year yield rose about 2.4 points and the 2-year about 3.7. SVB's disclosed 15.1bn gap between amortized cost (91.3) and fair value (76.2) is 16.5% of the book, which implies a duration near 7 on the 10-year move (the Fed's post-mortem states 6.2 years; plausible reasons for the gap: MBS yields rose more than the 10-year, much of the book was bought in 2020-21 at lower yields, and agency MBS are negatively convex so duration lengthened as rates rose). Marking the HTM book would have cut 16.0bn of equity to about 0.9bn, and the 42bn of withdrawal requests was about a quarter of deposits. TLT, a "risk-free" long Treasury ETF, fell about 48% from its August 2020 peak to its October 2023 trough (adjusted prices, so this is total return).
