# Lab 27 — Costs, sizing and risk

**Goal:** find the cost level at which a strategy stops paying, and implement the sizing rules (Kelly, volatility targeting, drawdown brake) that keep it alive.   **Time:** ~1.5 h   **Content:** `../../content/day27.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day27 -k "<expression>"`).
4. When all pass: `uv run python -m day27.lab` and inspect the printed summary / `.cache/plots/day27.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. `breakeven_cost_bps` and `vol_target_weights` are also published as `common/risk.py` (Day 30 imports them); `uv run pytest common/tests/test_risk.py` checks that copy. `main()` also uses `momentum_signal` and `backtest` from `common.backtest`. Educational code, not financial advice.

## Functions to implement (in order)
1. `kelly_fraction` — full Kelly leverage `mu / sigma^2`, error if sigma is not positive. (`-k "test_kelly"`)
2. `fractional_kelly` — a fraction (default one half) of full Kelly. (`-k "test_kelly"`; the same test covers both)
3. `vol_target_weights` — lagged exposure that scales returns to a target volatility, capped. (`-k "vol_target"`)
4. `breakeven_cost_bps` — the cost per unit of turnover that wipes out the gross return. (`-k "breakeven"`)
5. `drawdown_brake` — lagged scale that halves exposure while drawdown is deeper than a threshold. (`-k "drawdown_brake"`)

## Success signal
`uv run pytest day27` — all 5 tests pass.

## Explore further (optional)
- Sweep the drawdown-brake threshold from 10% to 30% and see how the max drawdown and CAGR move; resist picking the best one (Day 26).
- Replace SPY with BTC-USD and pass `periods=365` to `vol_target_weights`; compare the leverage the cap has to apply.
- Add a funding or borrow cost that accrues per bar on the position and recompute the breakeven.

## Teardown
Nothing billable is created.
