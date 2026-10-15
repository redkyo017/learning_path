# Lab 11 — Business cycle, regimes and "priced in"

**Goal:** label each month with a growth/inflation regime and see how SPY, TLT and GLD behaved in each.   **Time:** ~1.5 h   **Content:** `../../content/day11.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day11 -k "<expression>"`).
4. When all pass: `uv run python -m day11.lab` and inspect the printed summary / `.cache/plots/day11.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `surprise_z` — (actual - expected) / std, ValueError if std <= 0. (`-k "surprise_z"`)
2. `rolling_zscore` — (s - rolling mean) / rolling sample std. (`-k "rolling_zscore"`)
3. `classify_regime` — direction of growth and inflation over `lag` periods into four regimes. (`-k "classify_regime or flat_inflation"`)
4. `regime_mean_returns` — inner-join returns with regimes, group, mean. (`-k "regime_mean_returns"`)

## Success signal
`uv run pytest day11` — all 5 tests pass.

## Explore further (optional)
- Shift the regimes forward one month (`reg.shift(1, freq="MS")`) before the table; which averages survive?
- Try `lag=6` or 12 in `classify_regime` and see how the share of months in each regime and the flip rate change.
- Call `load_prices([...], live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.

Educational material, not financial advice.
