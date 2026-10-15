# Lab 09 — A limit order book and the cost curve

**Goal:** build a price-time-priority matching engine, then measure how the average fill price of a market order drifts away from the mid as size grows.   **Time:** ~1.5 h   **Content:** `../../content/day09.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day09 -k "<expression>"`).
4. When all pass: `uv run python -m day09.lab` and inspect the printed summary / `.cache/plots/day09.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. `main()` builds a random book with a fixed numpy seed, so its output is reproducible.

## Functions to implement (in order)
1. `OrderBook.best_bid` — highest resting buy price or `None`. (`-k "resting_orders or empty_book"`)
2. `OrderBook.best_ask` — lowest resting sell price or `None`. (`-k "resting_orders or empty_book"`)
3. `OrderBook.spread` — ask minus bid, `None` if a side is empty. (`-k "resting_orders or empty_book"`)
4. `OrderBook.depth` — total quantity per price level, best first. (`-k "depth or partial"`)
5. `OrderBook.submit` — validate, match against the opposite side at the resting price, FIFO inside a level, rest a limit remainder. (`-k "resting_orders or crossing or partial or priority or sell_side or market or invalid"`)
6. `average_fill_price` — quantity-weighted average of trade prices. (`-k "market_order"`)

## Success signal
`uv run pytest day09` — all 11 tests pass (8 test functions, one parametrized three times).

## Explore further (optional)
- Change `levels` or the per-level size in `build_random_book` and see how the cost curve bends: depth, not spread, drives large-order cost.
- Add a `cancel(order_id)` method and a stop order that turns into a market order when the last trade crosses a trigger.
- Try the same sweep with `side="sell"` and compare slippage against the mid.

## Teardown
Nothing billable is created.
