# Lab 18 — The cross-currency scorecard

**Goal:** compare assets quoted in different currencies on one footing: restate in VND, score on CAGR, volatility, Sharpe and drawdown, and apply a hedge rule.   **Time:** ~1.5 h   **Content:** `../../content/day18.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day18 -k "<expression>"`).
4. When all pass: `uv run python -m day18.lab` and inspect the printed summary / `.cache/plots/day18.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. `VND=X` is VND per USD. The "in VND" rows are cross-currency arithmetic; they do not mean a resident individual may lawfully hold those assets (see Day 17's scope note).

## Functions to implement (in order)
1. `to_vnd_prices` — multiply a USD price series by USD/VND, forward-filling FX holidays. (`-k "to_vnd_prices"`)
2. `scorecard` — one row per name: CAGR, annualized volatility, Sharpe, max drawdown, using `common.quant`. (`-k "scorecard"`)
3. `hedge_decision` — "hedge" only when expected depreciation strictly exceeds the hedge cost. (`-k "hedge_decision"`)

## Success signal
`uv run pytest day18` — all 5 tests pass.

## Explore further (optional)
- Add `TLT` or `EEM` to `main()` and see where it lands in the Sharpe ranking.
- Change `START` to 2020 and compare rankings: how much does the chosen period decide the order?
- Call `load_prices([...], live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.

Educational material, not financial advice.
