# Lab 06 — The plumbing dashboard (Block 1 integration)

**Goal:** merge Fed balance-sheet, rate and CPI data into one monthly dashboard and label each month's policy stance.   **Time:** ~1.5 h   **Content:** `../../content/day06.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day06 -k "<expression>"`).
4. When all pass: `uv run python -m day06.lab` and inspect the printed summary / `.cache/plots/day06.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `stance` — label a real policy rate restrictive, neutral or accommodative around a +/-1 percentage point band. (`-k "stance"`)
2. `plumbing_dashboard` — resample weekly and daily inputs to month-end, fix units, compute CPI YoY and the exact real rate. (`-k "columns or nans"`)

## Success signal
`uv run pytest day06` — all 6 tests pass (3 test functions, one parametrized four times).

## Explore further (optional)
- Change `band` to 0.005 and 0.02 and see how many months of the last decade change label.
- Fetch the TGA (`WTREGEN`, not in the snapshot: needs `live=True`) and check whether reserves track WALCL minus currency in circulation (about $2.3 trillion) minus TGA minus ON RRP.
- Call `load_fred("CPIAUCSL", live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.
