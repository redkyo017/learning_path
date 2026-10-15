# Solution notes — Day 04

## `yoy_inflation`
Key idea: inflation is the percentage change of the price level over a year, so with monthly data compare each month with the one 12 rows earlier. The first 12 rows have nothing to compare with and are dropped.
Formula: `cpi.pct_change(periods, fill_method=None).dropna()`.
Common mistake: forgetting `fill_method=None` (pandas may silently carry a value across a gap and hide a missing month) or using `diff()` (index points, not a rate). `test_yoy_inflation` expects 13 values of 2% from 25 months.

## `real_rate`
Key idea: the saver gets paid `1 + i` units of money per unit lent, but each unit buys `1 / (1 + pi)` of what it did. Real return is the ratio, not the difference.
Formula: `(1 + nominal) / (1 + inflation) - 1`, which works unchanged on floats and Series.
Common mistake: `nominal - inflation`. At 5% and 3% the gap is small (1.94% vs 2.00%); at high inflation it is large. `test_real_rate_exact_fisher` compares against `1.05/1.03 - 1`.

## `compound` and `cagr`
Key idea: growth multiplies, so `years` is an exponent. CAGR is the inverse: the constant rate that turns `start` into `end`. A non-positive start makes the ratio meaningless and zero years makes the exponent undefined.
Formula: `value * (1 + rate) ** years`; `(end / start) ** (1 / years) - 1`, raising `ValueError` if `start_value <= 0 or years <= 0`.
Common mistake: dividing the total return by years (simple average) or skipping validation. `test_compound_and_cagr_are_inverses` round-trips 7%; `test_cagr_rejects_bad_inputs` checks both errors.

## `real_cagr`
Key idea: the same Fisher division applied to two annualised rates.
Formula: `(1 + nominal) / (1 + inflation) - 1`.
Common mistake: subtracting. `test_real_cagr` expects `1.08/1.03 - 1`.

## `years_to_double`
Key idea: solve `(1 + r)^t = 2` for `t`.
Formula: `ln 2 / ln(1 + r)`; the rule of 72 (`72 / (100 r)`) is a mental shortcut that is best near 8%.
Common mistake: `log(2) / r`, which is right only for continuous compounding. `test_years_to_double` expects `ln 2 / ln 1.07` (10.24 years).

## What the output means
The most negative real policy rate since 1960 is about -7.7% in March 2022: fed funds averaged 0.2% while CPI ran 8.6% a year. The most positive is +8.6% in June 1981, when a 19% policy rate met 9.7% inflation, the Volcker era. The latest month (Aug 2026) shows the real policy rate slightly positive at about +0.3% (policy 3.6% vs CPI 3.35%; `main()` reindexes CPI to a full monthly calendar because the snapshot has no October 2025 row, otherwise a row-based 12-period change would compare August 2026 with July 2025 and give a wrong 3.7%). SPY's adjusted price compounds at about 10.9% nominal since 2005, but CPI took roughly 2.6% a year of that, leaving about 8.1% real. The two doubling times (10.24 vs 10.29 years at 7%) show the rule of 72 is a fine approximation there.
