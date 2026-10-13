# Lab 04 — Inflation, real rates and compounding

**Goal:** turn CPI levels into inflation, apply the exact Fisher equation, and master compounding / CAGR.   **Time:** ~1.5 h   **Content:** `../../content/day04.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day04 -k "<expression>"`).
4. When all pass: `uv run python -m day04.lab` and inspect the printed summary / `.cache/plots/day04.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `yoy_inflation` — year-over-year percentage change of a CPI level series, leading NaNs dropped. (`-k "yoy"`)
2. `real_rate` — exact Fisher real rate, for floats or Series. (`-k "real_rate"`)
3. `compound` — future value at a constant annual rate. (`-k "compound"`)
4. `cagr` — compound annual growth rate, rejecting non-positive start value or years. (`-k "compound or rejects"`)
5. `real_cagr` — inflation-adjusted growth from a nominal and an inflation rate. (`-k "real_cagr"`)
6. `years_to_double` — exact doubling time, to compare with the rule of 72. (`-k "double"`)

## Success signal
`uv run pytest day04` — all 6 tests pass.

## Explore further (optional)
- Redo the real-rate series with core CPI (`CPILFESL`, if you add it with `live=True`) and compare the 2021 episode.
- Plot `T5YIE` (breakeven) against realised CPI YoY and look at who led whom in 2021–2022.
- Call `load_fred("CPIAUCSL", live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.
