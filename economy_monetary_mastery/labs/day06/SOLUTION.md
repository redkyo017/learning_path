# Solution notes — Day 06

## `stance`
Key idea: collapse a continuous real rate into three labels. Above +band money is expensive in purchasing-power terms (restrictive), below -band it is cheap (accommodative), in between neutral. A band is needed because the "true" neutral real rate is unobservable, so tiny positive or negative readings carry no information.
Formula: `restrictive` if `real_rate > band`; `accommodative` if `real_rate < -band`; else `neutral`.
Common mistake: using `>=` so the band edge flips to restrictive. `test_stance` includes the case `0.01 -> neutral`, which catches it.

## `plumbing_dashboard`
Key idea: every input has its own frequency and unit, so first bring them to one month-end grid and one unit system, then derive. Levels (assets, reserves, rate) use the monthly mean; CPI is an index level, so take the month-end value and then the 12-month change. The exact Fisher real rate uses the decimal policy rate and decimal CPI YoY.
Formula: `fed.resample("ME").mean()/1000`; `res.resample("ME").mean()`; `rate.resample("ME").mean()/100`; `yoy = cpi.resample("ME").last().pct_change(12, fill_method=None)`; `real = (1+rate)/(1+yoy) - 1`; `pd.concat([...], axis=1).dropna()`.
Common mistake: dividing reserves by 1,000 again inside the function (its input is already billions; only the Fed-assets input is millions), or subtracting `rate - yoy` instead of the Fisher form. `test_columns_units_and_length` checks 8000 and 3000, and the exact `1.05/1.03 - 1`. Forgetting `dropna()` leaves the first 12 months with a NaN `cpi_yoy`, which `test_no_nans` and the length check of 14 catch. A subtle real-data trap: `fill_method=None` keeps a missing CPI month as NaN, so that month is dropped instead of being silently filled.

## What the output means
The last twelve months show a US policy rate drifting down from 4.3 to 3.6 percent while CPI inflation rose from about 2.4 to 4.2 percent in spring 2026, so the real rate went from about +1.2 percent (restrictive) to about -0.5 percent and back to +0.3 percent (neutral). The balance sheet is roughly flat near $6.7 trillion and reserves hover near $3 trillion: the Fed is steering through price (rates), not quantity. The dated case points read as a story of the course: December 2008 neutral (policy rate near zero, CPI YoY about zero), June 2013 accommodative (QE and zero rates), April 2020 neutral, June 2022 sharply accommodative (-7.1 percent real: policy rate averaging 1.2 percent against 9.0 percent CPI inflation), and the latest month (August 2026) neutral, which predates the September 2026 rate move because September CPI is not out yet. A missing month (October 2025 has no CPI print: the 2025 government shutdown cancelled that release) is dropped rather than interpolated.
