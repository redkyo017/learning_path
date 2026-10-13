# Lab 28 — Strategy families

**Goal:** build trend, mean-reversion, inverse-volatility, cross-sectional momentum and blending blocks, then compare sleeves on a mixed ETF + BTC universe.   **Time:** ~1.5 h   **Content:** `../../content/day28.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day28 -k "<expression>"`).
4. When all pass: `uv run python -m day28.lab` and inspect the printed summary / `.cache/plots/day28.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Every function uses data up to and including row t; `common.backtest` applies the one-bar lag. `main()` joins ETFs (252 days a year) and BTC-USD (365) on common weekday dates and annualises with 252 on that calendar. Educational code, not financial advice.

## Functions to implement (in order)
1. `trend_signal` — sign of the trailing return per asset: -1, 0 or +1. (`-k "trend"`)
2. `mean_reversion_signal` — fade z-scores beyond a threshold. (`-k "mean_reversion"`)
3. `inverse_vol_weights` — weights proportional to 1 / rolling volatility, rows sum to 1. (`-k "inverse_vol"`)
4. `cross_sectional_momentum` — equal-weight the top N trailing performers. (`-k "cross_sectional"`)
5. `combine_strategies` — weighted blend of strategy return streams. (`-k "combine"`)

## Success signal
`uv run pytest day28` — all 5 tests pass.

## Explore further (optional)
- Swap the trend lookback in `main()` (60, 120, 250) and note how the blend's correlation to buy-and-hold moves; remember Day 26's multiple-testing warning.
- Run `mean_reversion_signal` on SPY through `backtest` with a 20-day window and 2.0 threshold and compare with trend.
- Add `VNM` to the universe and see how much of the history it removes.

## Teardown
Nothing billable is created.
