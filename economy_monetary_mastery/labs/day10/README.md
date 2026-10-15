# Lab 10 — Portfolio theory: volatility, Sharpe, minimum variance, the frontier

**Goal:** measure risk-adjusted return, compute portfolio volatility from a covariance matrix, and see diversification and the efficient frontier on SPY, IEF and GLD.   **Time:** ~1.5 h   **Content:** `../../content/day10.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day10 -k "<expression>"`).
4. When all pass: `uv run python -m day10.lab` and inspect the printed summary / `.cache/plots/day10.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `annualize_vol` — sample std (ddof=1) times sqrt(periods). (`-k "vol_and_sharpe"`)
2. `sharpe` — annualized mean/std of excess return, rf given as an annual rate. (`-k "vol_and_sharpe"`)
3. `portfolio_returns` — fixed-weight (daily rebalanced) portfolio return series. (`-k "portfolio_returns"`)
4. `portfolio_vol` — sqrt(w' C w), clipped at zero. (`-k "portfolio_vol"`)
5. `min_variance_weights` — inv(C) 1 / (1' inv(C) 1). (`-k "min_variance"`)
6. `frontier_two_asset` — w1, ret, vol for 101 mixes of two assets. (`-k "frontier"`)

## Success signal
`uv run pytest day10` — all 5 tests pass (the first test covers two functions).

## Explore further (optional)
- Add EFA or TLT to `main()` and rebuild the 60/30/10 table; does the Sharpe ratio move more than the CAGR?
- Split the sample at 2013 and recompute the SPY/IEF frontier from each half; how far do the mean returns, and the best mix, move?
- Call `load_prices([...], live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.

Educational material, not financial advice.
