# Solution notes — Lab 09

## `best_bid`, `best_ask`, `spread`
The bid side stores levels in a dict keyed by price, so the best bid is `max(self.bids)` and the best ask is `min(self.asks)`; both are `None` for an empty side. The spread is `ask - bid`, or `None` when either side is empty. Most common mistake: returning 0 or raising on an empty book. `test_empty_book` catches it.

## `depth`
For each price level sum the `qty` of the queued orders, then sort: bids descending, asks ascending, so index 0 is always the best price. Mistake: sorting both sides the same way, or listing orders instead of aggregating. `test_depth_aggregates_best_first` mixes two orders at 99.0 to catch both.

## `submit`
Validate first (`side` in `{"buy","sell"}`, `qty > 0`, else `ValueError`). Then loop: take the best opposite price; for a limit order stop if it no longer crosses (buy: ask > limit; sell: bid < limit); a market order always crosses. Inside a level, fill the oldest order first (a `deque`, `popleft`), trade `min(remaining, resting.qty)` at the resting order's price, and delete a level as soon as its queue is empty. Afterwards a limit remainder rests at its own limit price; a market remainder is discarded. The solution rests a copy so the caller's `Order` is never mutated.
Common mistakes: trading at the incoming order's limit instead of the resting price (`test_crossing_limit_trades_at_resting_price`), LIFO inside a level (`test_time_priority_at_same_price`), leaving empty levels so `best_ask` returns a price with no quantity (the crossing test asserts `best_ask() is None`), and resting a market order's remainder (`test_market_order_sweeps_levels_and_discards_remainder`).

## `average_fill_price`
`sum(price * qty) / sum(qty)`. Mistake: a plain mean of prices, which weights a 1-share and a 1,000-share fill equally; the market-order test has fills of 2 and 3 shares at 100 and 101 and expects 100.6, not 100.5.

## What the output means
`main()` rebuilds the same seeded random book (levels 1 cent apart, mid 100.00, a 2-cent spread) for each size and sends a market buy. A 100-share order fits in the first level and costs 1.0 bp, exactly half the spread (the entry fee for crossing). As size grows the order walks up the book: 2,000 shares cost about 2.3 bp and 8,000 shares about 6.1 bp. The curve keeps rising (1.6, 2.3, 3.7, 6.1 bp at 1k, 2k, 4k, 8k shares) but is roughly linear or slightly concave here, because this book holds more shares at each deeper level, so the slope flattens. Real impact is similar in spirit: roughly a power of size below one (the square-root law). That rising line is the slippage term the Day 27 backtest charges; a backtest that fills at the mid or the close pays none of it.
