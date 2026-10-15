# Solution notes — Lab 24

## `btc_supply(height)`
Closed form per era: every complete 210,000-block era issued `210_000 * (50 BTC >> era)` satoshis, and the unfinished era issued `remainder * subsidy_of_that_era`. Cap `height` at 64 eras (the subsidy is zero afterwards). It is the same function as Day 19's `total_supply`. Most common mistake: looping over every height (too slow for large heights) or using floats for the halving, which loses satoshis. `test_btc_supply_at_halvings` pins 18,375,000 BTC at block 630,000 and 19,687,500 BTC at block 840,000.

## `btc_annual_inflation(height, blocks_per_year=52_560)`
`(supply(h + bpy) - supply(h)) / supply(h)`. When the window sits inside one era this is `bpy * subsidy / supply(h)`, which is what the test checks (52,560 x 3.125 / 19,687,500 = 0.834%). Most common mistake: dividing by the supply after the window instead of before, which understates inflation. If the window straddles a halving, the closed form still works because `btc_supply` handles the era boundary; `test_btc_inflation` uses two clean in-era windows, and the Day 24 exercises use a straddling one.

## `m2_growth(m2)`
`m2.pct_change(12, fill_method=None).dropna()`. The 12 means twelve rows, so it is only year-on-year if the index has no missing month; `main()` reindexes to month starts first for that reason. `fill_method=None` stops pandas forward-filling a gap. Most common mistake: `pct_change()` with the default period (month-on-month). `test_m2_growth` feeds a series growing exactly 6% a year and expects 24 values of 0.06 out of 36 months.

## `compare_issuance(year_heights, m2)`
Take `m2_growth(m2)`, keep the December observations, index them by year, and `reindex` to the requested years so a year without a December (the current one) becomes NaN instead of raising. The BTC column is `btc_annual_inflation(year_heights[year])`. Most common mistake: using the January M2 growth, or building the frame from a dict whose lengths differ. `test_compare_issuance` checks the column order, the index, and the 2020 row (6% M2, 6.25-BTC-era inflation).

## What the output means
On the snapshot, Bitcoin's scheduled issuance falls from about 12% a year in 2013 to about 0.83% in 2025 (0.82% for 2026, no halving until block 1,050,000, about April 2028), while US M2 growth ran between about minus 2.4% and plus 24.5% (December year-on-year) over 2013-2025. Two things stand out. Bitcoin's rate is a known, falling number; M2's is a decision-driven, volatile one (the 2020 surge to 24.5%, then contraction in 2022-2023). And the comparison says nothing about price: supply growth is only one input to what a unit buys. The BTC column also uses the 10-minute ideal of 52,560 blocks a year; the real blocks between the `YEAR_HEIGHTS` entries run from about 52,700 to 63,400 a year (the early years mined faster than 10 minutes a block), so treat the first decimal as indicative.
