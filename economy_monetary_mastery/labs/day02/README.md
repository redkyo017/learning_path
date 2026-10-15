# Lab 02 — Banks create money: loans, ratios, runs and returns

**Goal:** model a bank where loans create deposits, simulate a run with fire sales, and compute simple vs log returns.   **Time:** ~1.5 h   **Content:** `../../content/day02.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day02 -k "<expression>"`).
4. When all pass: `uv run python -m day02.lab` and inspect the printed summary / `.cache/plots/day02.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `Bank.lend` — a loan adds equally to loans and deposits; reserves untouched. (`-k "lending"`)
2. `Bank.capital_ratio` and `Bank.liquidity_ratio` — equity/loans and reserves/deposits. (`-k "ratios"`)
3. `bank_run` — pay from reserves, fire-sell loans for any shortfall, stop at insolvency. (`-k "run or identity"`)
4. `simple_returns` and `log_returns` — price series to return series. (`-k "returns"`)

## Success signal
`uv run pytest day02` — all 6 tests pass.

## Explore further (optional)
- Find, by looping over haircuts, the smallest one that makes the 50% run insolvent and compare with the exact answer in Exercise 1.
- Add a lender-of-last-resort step to `bank_run` that lends the shortfall against loans at a 10% collateral haircut instead of fire-selling them.
- Call `load_prices("SPY", live=True)` to see newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.
