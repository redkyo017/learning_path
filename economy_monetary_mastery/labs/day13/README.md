# Lab 13 — FX mechanics: forwards, covered interest parity, carry

**Goal:** price a forward from spot and two interest rates, measure deviations from covered interest parity, and compute carry-trade and currency-holding returns.   **Time:** ~1.5 h   **Content:** `../../content/day13.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day13 -k "<expression>"`).
4. When all pass: `uv run python -m day13.lab` and inspect the printed summary / `.cache/plots/day13.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Convention throughout: `spot` is quote-currency units per 1 base-currency unit (USD/VND = 25,000 means 1 USD = 25,000 VND).

## Functions to implement (in order)
1. `forward_rate` — S (1 + r_quote t) / (1 + r_base t); raise `ValueError` if t <= 0. (`-k "forward_rate or bad_time"`)
2. `forward_points` — forward minus spot. (`-k "forward_points"`)
3. `cip_deviation_bp` — gap between a quoted forward and the fair one, in basis points. (`-k "cip_deviation"`)
4. `carry_trade_return` — unhedged borrow-low / lend-high return per 1 unit of funding currency. (`-k "carry_trade"`)
5. `fx_return` — return of holding the base currency. (`-k "fx_return"`)

## Success signal
`uv run pytest day13` — all 6 tests pass.

## Explore further (optional)
- Change `R_VND` and `R_USD` in `lab.py` to the online-deposit rates and see how the "predicted" depreciation and the carry history change.
- Add `JPY=X` (USD/JPY) to `main()`: a USD-funded, JPY-invested trade is the reverse of the usual yen carry, so swap the arguments and check the sign.
- Call `load_prices(["VND=X"], live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.

Educational material, not financial advice.
