# Lab 08 — Discounting everything: present value, Gordon growth, equity duration, beta

**Goal:** value cash flows, see why distant cash flows fall most when rates rise, and measure beta and correlation on growth vs value ETFs.   **Time:** ~1.5 h   **Content:** `../../content/day08.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day08 -k "<expression>"`).
4. When all pass: `uv run python -m day08.lab` and inspect the printed summary / `.cache/plots/day08.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `pv_cashflows` — sum of cf_k / (1+r)^k, first cash flow at t=1. (`-k "test_pv"`)
2. `gordon_value` — next_cf / (r - g), `ValueError` if r <= g. (`-k "gordon"`)
3. `equity_duration` — 1 / (r - g). (`-k "gordon_and_duration"`)
4. `rate_shock_pct` — percent change in PV for a discount-rate shock. (`-k "long_duration"`)
5. `beta` — aligned cov(asset, market) / var(market). (`-k "beta_and_correlation"`)
6. `correlation` — Pearson correlation of two return series. (`-k "beta_and_correlation"`)

## Success signal
`uv run pytest day08` — all 6 tests pass (5 test functions, one parametrized twice).

## Explore further (optional)
- Add QQQ to `main()` and compare its 2022 beta and rate sensitivity with IWF.
- Compute the SPY vs TLT monthly correlation by year; find the year it flips sign.
- Call `load_fred("DGS10", live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.

Educational material, not financial advice.
