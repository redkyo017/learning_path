# Lab 25 — A backtester from scratch

**Goal:** turn prices and a signal into a lag-correct, cost-aware equity curve, and publish it as the shared `common.backtest`.   **Time:** ~1.5 h   **Content:** `../../content/day25.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day25 -k "<expression>"`).
4. When all pass: `uv run python -m day25.lab` and inspect the printed summary / `.cache/plots/day25.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Days 26, 27, 28 and 30 import the finished versions from `common/backtest.py`; once your lab passes, `uv run pytest common/tests/test_backtest.py` checks that copy. Keyword names differ: `common.quant` uses `periods_per_year=`, while the Day 10 lab and `common.risk` use `periods=`. Educational code, not financial advice.

## Functions to implement (in order)
1. `momentum_signal` — 1.0 when the trailing return over `lookback` bars is positive, else 0.0 (NaN warm-up gives 0.0). (`-k "momentum_signal"`)
2. `backtest` — lag the signal one bar, charge cost on turnover, compound the strategy return. (`-k "always_long or costs or flat or lookahead"`; `test_no_lookahead` also needs `momentum_signal`)

## Success signal
`uv run pytest day25` — all 5 tests pass.

## Explore further (optional)
- Replace the long/flat signal with long/short (-1/+1) and check that turnover of a flip is 2.
- Scan lookbacks 50 to 250 on SPY and look at how flat (or not) the Sharpe curve is. Resist picking the best one.
- Remove the `.shift(1)` on purpose and see how much the SPY result "improves".

## Teardown
Nothing billable is created.
