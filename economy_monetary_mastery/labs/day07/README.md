# Lab 07 — Bonds, duration and the yield curve

**Goal:** price a bond from its cash flows, measure duration and convexity, and find yield-curve inversions in FRED data.   **Time:** ~1.5 h   **Content:** `../../content/day07.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day07 -k "<expression>"`).
4. When all pass: `uv run python -m day07.lab` and inspect the printed summary / `.cache/plots/day07.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `bond_price` — discounted sum of coupons and face value, semiannual by default. (`-k "known_price or par_and_zero"`)
2. `macaulay_duration` — PV-weighted average time of the cash flows, in years. (`-k "zero_coupon or below_maturity"`)
3. `modified_duration` — Macaulay divided by `1 + ytm/freq`. (`-k "zero_coupon or predicts"`)
4. `convexity` — second-derivative term, in years squared. (`-k "zero_coupon"`)
5. `curve_slope` — long minus short yield, aligned, NaNs dropped. (`-k "inversions"`)
6. `inversion_periods` — inclusive `(start, end)` runs where the slope is negative. (`-k "inversions"`)

Note: functions 2–4 share one test (`test_zero_coupon_durations_and_convexity`) and `inversions` covers both curve functions, so implement them in order and read which assert fails.

## Success signal
`uv run pytest day07` — all 6 tests pass.

## Explore further (optional)
- Compare 10y minus 3m with 10y minus 2y (add `T10Y3M`-style logic with `DGS3MO`): which inverted first in 2022, and which un-inverted first?
- Price a 30y 4% bond at yields 1-8% and overlay the duration-only tangent line: where does the straight line fail?
- Call `load_fred("DGS10", live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.
