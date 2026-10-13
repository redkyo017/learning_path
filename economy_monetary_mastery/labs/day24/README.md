# Lab 24 — Block 4 integration: crypto vs fiat quiz

**Goal:** put Bitcoin's scheduled issuance and US M2 growth on one axis and compare the two supply rules.   **Time:** ~1.5 h   **Content:** `../../content/day24.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day24 -k "<expression>"`).
4. When all pass: `uv run python -m day24.lab` and inspect the printed summary / `.cache/plots/day24.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. `YEAR_HEIGHTS` (block height at each 1 January) is given; the content file cites where it came from. This lab is educational, not financial advice.

## Functions to implement (in order)
1. `btc_supply` — satoshis issued before `height`, closed form per halving era (same as Day 19's `total_supply`). (`-k "supply"`)
2. `btc_annual_inflation` — new supply over the next 52,560 blocks divided by current supply. (`-k "inflation"`)
3. `m2_growth` — year-on-year growth of a monthly series, NaN rows dropped. (`-k "m2_growth"`)
4. `compare_issuance` — one row per year: BTC inflation at 1 January, December YoY M2 growth. (`-k "compare_issuance"`)

## Success signal
`uv run pytest day24` — all 4 tests pass.

## Explore further (optional)
- Replace the 52,560-block approximation with the real block count between consecutive `YEAR_HEIGHTS` and see how far the BTC column moves.
- Add the CPI year-on-year line (`CPIAUCSL`, reindexed to month starts first) and ask in which years BTC's schedule was below both M2 growth and inflation.
- Plot annual BTC price change (Binance snapshot) against the M2 column and look at the sign of the relationship.

## Teardown
Nothing billable is created. The only file written is the plot in `.cache/plots/`, which is gitignored.
