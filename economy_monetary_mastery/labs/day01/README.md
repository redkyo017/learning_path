# Lab 01 — What money is: balance sheets and the FRED format

**Goal:** build a double-entry ledger, settle a cross-bank payment with it, and parse FRED's CSV.   **Time:** ~1.5 h   **Content:** `../../content/day01.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day01 -k "<expression>"`).
4. When all pass: `uv run python -m day01.lab` and inspect the printed summary / `.cache/plots/day01.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `BalanceSheet.apply` — apply signed deltas; reject unbalanced entries before touching state. (`-k "balanced or swap"`)
2. `transfer_deposit` — settle a payment between two banks in reserves. (`-k "transfer"`)
3. `parse_fred_csv` — FRED CSV text to a clean float Series. (`-k "parse_fred"`)

## Success signal
`uv run pytest day01` — all 6 tests pass.

## Explore further (optional)
- Add a `net_worth()` method and show that equity equals assets minus non-equity liabilities.
- Call `load_fred("DFF", live=True)` from `common.data` to see data newer than the snapshot (it writes to `.cache/` only).
- Plot DFF against the 2008 and 2020 episodes and note the units on the y-axis.

## Teardown
Nothing billable is created.
